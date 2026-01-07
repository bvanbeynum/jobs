import requests
import pyodbc
import datetime
import time
import json
import os
import re
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.application import MIMEApplication
import smtplib
from difflib import SequenceMatcher

def logMessage(message):
	logTime = datetime.datetime.strftime(datetime.datetime.now(), "%Y-%m-%d %H:%M:%S")
	print(f"{logTime} - {message}")

def errorLogging(errorMessage):
	logMessage(errorMessage)
	try:
		logPayload = {
			"log": {
				"logTime": datetime.datetime.now().isoformat(),
				"lotTypeId": "691e351ab7de6ab54ed121ae",
				"message": errorMessage
			}
		}
		requests.post(f"{ config["apiServer"] }/sys/api/addlog", json=logPayload)
	except Exception as apiError:
		logMessage(f"Failed to log error to API: {apiError}")

def loadSql():
	sql = {}
	sqlPath = "./scripts/eventloader/sql/"

	if os.path.exists(sqlPath):
		for file in os.listdir(sqlPath):
			with open(f"{ sqlPath }/{ file }", "r") as fileReader:
				sql[os.path.splitext(file)[0]] = fileReader.read()
	
	return sql

def getStateFromLocation(location):
	if not location or ',' not in location:
		return None
	parts = location.split(',')
	if len(parts) <= 1:
		return None
	state = parts[-1].strip()
	if len(state) != 2:
		return None
	return state

def getNameDiffHtml(string1, string2):
	string1 = string1.lower()
	string2 = string2.lower()
	
	matcher = SequenceMatcher(None, string1, string2)
	
	output1 = []
	output2 = []
	
	for tag, i1, i2, j1, j2 in matcher.get_opcodes():
		if tag == 'replace':
			output1.append(f'<span class="diff">{string1[i1:i2]}</span>')
			output2.append(f'<span class="diff">{string2[j1:j2]}</span>')
		elif tag == 'delete':
			output1.append(f'<span class="diff">{string1[i1:i2]}</span>')
		elif tag == 'insert':
			output2.append(f'<span class="diff">{string2[j1:j2]}</span>')
		elif tag == 'equal':
			output1.append(string1[i1:i2])
			output2.append(string2[j1:j2])
			
	return ''.join(output1), ''.join(output2)





# *************************** Script Start ***************************


logMessage(f"Starting FloWrestling scraper.")

with open("./scripts/config.json", "r") as reader:
	config = json.load(reader)

cn = pyodbc.connect(f"DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={ config["database"]["server"] };DATABASE={ config["database"]["database"] };ENCRYPT=no;UID={ config["database"]["user"] };PWD={ config["database"]["password"] }", autocommit=True)
cur = cn.cursor()

sql = loadSql()

apiUrls = {
	"base": "https://prod-web-api.flowrestling.org/api/",
	"schedule": "schedule/events",
	"event": "event-hub/{systemId}",
	"information": "/information",
	"divisionWeight": "/brackets/divisions",
	"bracket": "/brackets/{bracketId}"
}

requestHeaders = { "User-Agent": config["userAgent"] }

today = datetime.date.today()
startDate = today - datetime.timedelta(weeks=2)
endDate = today + datetime.timedelta(weeks=8)
dataModified = True

states = ["SC", "NC", "GA", "TN"]

startDate = datetime.datetime.strptime("2025-12-01", "%Y-%m-%d").date()
endDate = datetime.date.today()
# states = ["SC"]
# dataModified = False

cur.execute(sql["ExcludedGet"], (startDate, endDate))
excludedEvents = [row.SystemID for row in cur.fetchall()]

# excludedEvents = []

currentDate = startDate
while currentDate <= endDate:
	for state in states:
		dateStr = currentDate.strftime("%Y-%m-%d")
		# logMessage(f"Fetching details for { dateStr } in { state }")
		
		if dataModified and currentDate <= datetime.date.today():
			# Update Wrestler Name Lookup
			cur.execute(sql["WrestlerLookupCreate"])
			dataModified = False

		payload = {
			"date": dateStr,
			"query": None,
			"filters": [
				{
					"id": "event-location",
					"type": "string-lazy",
					"value": f"29US{state}00000000000"
				}
			],
			"tz": "America/New_York",
			"offset": "0",
			"limit": "100"
		}
		
		response = requests.post(apiUrls["base"] + apiUrls["schedule"], json=payload)
		time.sleep(1)

		if response.status_code != 200:
			errorLogging(f"Error fetching events for {dateStr}. Status code: {response.status_code}")
			currentDate += datetime.timedelta(days=1)
			continue

		eventsData = response.json()
		events = eventsData["data"]["events"]

		# events = [ event for event in events if event["url"].split('/')[5] == "14833369" ]
		
		for event in events:
			systemId = event["url"].split('/')[5]
			if systemId in excludedEvents:
				# Excluded or completed event
				continue

			eventName = event["name"]
			eventAddress = f"{event["location"]["venueName"]}, {event["location"]["city"]}, {event["location"]["region"]}"

			informationUrl = apiUrls["base"] + apiUrls["event"].format(systemId=systemId) + apiUrls["information"]
			informationResponse = requests.get(informationUrl, headers=requestHeaders)
			
			if informationResponse.status_code != 200:
				errorLogging(f"Error fetching information for {eventName}. Status code: {divisionsResponse.status_code}")
				continue

			informationData = informationResponse.json()
			if informationData.get("data") and informationData["data"].get("startDate"):
				eventStartDate = datetime.datetime.strptime(informationData["data"]["startDate"], "%Y-%m-%dT%H:%M:%S.%fZ").date()
				eventEndDate = datetime.datetime.strptime(informationData["data"]["endDate"], "%Y-%m-%dT%H:%M:%S.%fZ").date() if informationData["data"].get("endDate") else eventStartDate
				endDateStr = eventEndDate.strftime("%Y-%m-%d")
			else:
				eventStartDate = currentDate
				eventEndDate = currentDate

			# Update the event details
			cur.execute(sql["EventSave"], (systemId, eventName, dateStr, endDateStr, eventAddress, state, 0, 0))
			eventId = cur.fetchone()[0]
			
			if currentDate >= datetime.date.today() or (eventEndDate and eventEndDate > datetime.date.today()):
				# In the future
				continue
			
			divisionsUrl = apiUrls["base"] + apiUrls["event"].format(systemId=systemId) + apiUrls["divisionWeight"]
			divisionsResponse = requests.get(divisionsUrl, headers=requestHeaders)
			time.sleep(1)

			if divisionsResponse.status_code != 200:
				errorLogging(f"Error fetching divisions for {eventName}. Status code: {divisionsResponse.status_code}")
				continue

			divisionsData = divisionsResponse.json()

			if len(divisionsData["data"]["bracketOptionsContent"]["bracketOptions"]) == 0:
				# Skipping - no brackets
				cur.execute(sql["EventSave"], (systemId, eventName, dateStr, None, eventAddress, state, 1, 0))
				excludedEvents.append(systemId)
				continue
			
			logMessage(f"Fetching details for {eventName} on {dateStr}")
			
			if (not (divisionsData.get("data") and divisionsData["data"].get("divisionContent") and divisionsData["data"]["divisionContent"].get("divisions"))) or len(next(iter(divisionsData["data"]["divisionContent"]["divisions"].values()))) == 0:
				# If there are no divisions returned, load everything as one division
				divisions = [{
					"name": "",
					"weightClasses": next(iter(divisionsData["data"]["bracketOptionsContent"]["bracketOptions"].items()))[1]
				}]
			else:
				divisionItems = next(iter(divisionsData["data"]["divisionContent"]["divisions"].items()))[1]
				divisions = [ {
					"id": division["divisionId"],
					"name": division["text"],
					"weightClasses": divisionsData["data"]["bracketOptionsContent"]["bracketOptions"][division["divisionId"]]
					} for division in divisionItems ]

			batchLoad = []
			for division in divisions:
				divisionName = division["name"]
				
				# logMessage(f"Fetching details for { divisionName }")

				for weightClass in division["weightClasses"]:
					if weightClass["isDisabled"]:
						continue

					weightClassName = weightClass["text"]

					resultsUrl = apiUrls["base"] + apiUrls["event"].format(systemId=systemId) + apiUrls["bracket"].format(bracketId=weightClass["bracketId"])
					resultsResponse = None
					for i in range(3):
						try:
							resultsResponse = requests.get(resultsUrl, headers=requestHeaders)
							break
						except requests.exceptions.ConnectionError as e:
							errorLogging(f"Connection error: event {eventName}, division {divisionName}, weight class {weightClassName}. Retrying in {i*2+2} seconds. Error: {e}")
							time.sleep(i*2+2)
					
					if not resultsResponse or resultsResponse.status_code != 200:
						errorLogging(f"Error fetching event {eventName}, division {divisionName}, weight class {weightClassName}. Status code: {resultsResponse.status_code if resultsResponse else 'N/A'}")
						continue

					resultsData = resultsResponse.json()
					if not (resultsData.get("data") and resultsData["data"].get("matches")):
						continue
					
					for matchIndex, match in enumerate(resultsData["data"]["matches"].values()):
						if not re.search("bye", (match.get("winType") or ""), re.I) and match.get("topParticipant") and match.get("bottomParticipant"):
							
							athlete1Id = match["topParticipant"]["id"]
							athlete1Name = match["topParticipant"]["name"] or ""
							athlete1Team = match["topParticipant"]["teamName"] or ""
							athlete1Winner = 1 if match["topParticipant"]["winner"] else 0
							athlete1Seed = match["topParticipant"]["seed"]
							athlete1Score = match["topParticipant"]["score"]

							athlete2Id = match["bottomParticipant"]["id"]
							athlete2Name = match["bottomParticipant"]["name"] or ""
							athlete2Team = match["bottomParticipant"]["teamName"] or ""
							athlete2Winner = 1 if match["bottomParticipant"]["winner"] else 0
							athlete2Seed = match["bottomParticipant"]["seed"]
							athlete2Score = match["bottomParticipant"]["score"]

							winType = match["winType"] or ""
							matchRound = match.get("roundName")  or ""
							matchId = match["id"]
							sort = match.get("matchNumber") if match.get("matchNumber") and str.isnumeric(str(match.get("matchNumber"))) else (matchIndex + 1)

							batchLoad.append(f"('{ matchId }', { eventId }, '{ divisionName }', '{ weightClassName }', '{ matchRound }', '{ winType }', '{ athlete1Id }', '{ athlete1Name.replace("'", "''") }', '{ athlete1Team.replace("'", "''") }', { athlete1Winner }, '{ athlete2Id }', '{ athlete2Name.replace("'", "''") }', '{ athlete2Team.replace("'", "''") }', { athlete2Winner }, { sort })")

			try:
				# Create the batch load
				if len(batchLoad) > 0:
					# logMessage(f"Loading batch { len(batchLoad) } for { eventName }")
					cur.execute(sql["LoadBatchCreate"])

					for i in range(0, len(batchLoad), 500):
						batch = batchLoad[i:i+500]
						insertSql = "insert #MatchStage (SystemID, EventID, DivisionName, WeightClassName, MatchRound, WinType, Wrestler1SystemID, Wrestler1Name, Wrestler1Team, Wrestler1IsWinner, Wrestler2SystemID, Wrestler2Name, Wrestler2Team, Wrestler2IsWinner, Sort) values " + ", ".join(batch)
						cur.execute(insertSql)

					# Process all the updates
					cur.execute(sql["LoadBatchProcess"])
					dataModified = True
					
				cur.execute(sql["EventSave"], (systemId, eventName, dateStr, None, eventAddress, state, 1, 0))
				excludedEvents.append(systemId)
			except Exception as error:
				errorLogging(f"DB save error: event {eventName}. Error: {error}")

		# Next state

	# Next date
	currentDate += datetime.timedelta(days=1)

logMessage(f"---------- FloWrestling scraper finished.")

logMessage(f"Process Name Updates.")
cur.execute(sql["ProcessWrestlerNames"])

logMessage(f"Process Team Duplicates.")
cur.execute(sql["ProcessTeamDups"])

logMessage(f"Email new wrestlers.")

cur.execute(sql["GetNewWrestlers"])
newWrestlers = cur.fetchall()

if len(newWrestlers) > 0:

	with open("./scripts/eventloader/newwrestlertemplate.html", "r") as reader:
		htmlTemplate = reader.read()

	rows = []
	wrestlerGroups = {}
	for wrestler in newWrestlers:
		if wrestler.MatchGroupID not in wrestlerGroups:
			wrestlerGroups[wrestler.MatchGroupID] = []
		wrestlerGroups[wrestler.MatchGroupID].append(wrestler)

	lastMatchGroupId = None
	groupCounter = 0
	for index, wrestler in enumerate(newWrestlers):
		
		if wrestler.MatchGroupID != lastMatchGroupId:
			groupCounter += 1
			lastMatchGroupId = wrestler.MatchGroupID

		rowClass = []
		if groupCounter % 2 != 0:
			rowClass.append("odd-group")
		
		# Check if the group has more than one wrestler
		if len(wrestlerGroups[wrestler.MatchGroupID]) > 1:
			rowClass.append("group-row")
			
		# Check if it's the last wrestler in the group
		isLastInGroup = (index == len(newWrestlers) - 1) or (newWrestlers[index+1].MatchGroupID != wrestler.MatchGroupID)
		if isLastInGroup:
			rowClass.append("group-end")

		classString = f'class="{" ".join(rowClass)}"' if rowClass else ""

		existingWrestlerHtml, newWrestlerHtml = getNameDiffHtml(wrestler.ExistingWrestler, wrestler.NewWrestler)
		
		addDateStr = wrestler.AddDate.strftime("%m/%d/%Y") if wrestler.AddDate else ""

		script = f"insert into #dedup (saveid, dupid) values({wrestler.ExistingID},{wrestler.NewID});"

		row = f"""
		<tr {classString}>
			<td><input type="checkbox" class="wrestler-checkbox"></td>
			<td>{wrestler.ExistingID}</td>
			<td>{wrestler.NewID}</td>
			<td>{existingWrestlerHtml}</td>
			<td>{newWrestlerHtml}</td>
			<td class="team-col">{wrestler.MatchedTeams}</td>
			<td>{addDateStr}</td>
			<td class="script-cell">{script}</td>
		</tr>
		"""
		rows.append(row)

	htmlBody = htmlTemplate.replace("<NewEmailData>", "\n".join(rows))

	msg = MIMEMultipart()
	msg["From"] = "wrestlingfortmill@gmail.com"
	msg["To"] = "maildrop444@gmail.com"
	msg["Subject"] = "New Wrestler Report - " + datetime.datetime.now().strftime("%Y-%m-%d")

	msg.attach(MIMEText("New wrestler report is attached.", "plain"))

	attachment = MIMEApplication(htmlBody, _subtype="html")
	attachment.add_header("Content-Disposition", "attachment", filename="newWrestlerReport.html")
	msg.attach(attachment)

	try:
		with smtplib.SMTP_SSL("smtp.gmail.com", 465) as smtp:
			smtp.login("wrestlingfortmill@gmail.com", config["googleAppPassword"])
			smtp.send_message(msg)

		logMessage(f"Email sent successfully.")
	except Exception as e:
		errorLogging(f"Failed to send email. Error: {e}")

else:
	logMessage(f"No new wrestlers found.")

logMessage(f"---------- Complete.")
