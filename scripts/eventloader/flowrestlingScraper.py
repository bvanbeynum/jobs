import requests
import pyodbc
import datetime
import time
import json
import os
import re
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
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
	"event": "event-hub/{systemId}/results",
	"divisions": "/filters/divisionName?limit=1000",
	"divisionFilter": "&filters=[%7B%22id%22:%22divisionName%22,%22type%22:%22string%22,%22value%22:%22{divisionName}%22%7D]",
	"weightclasses": "?tab=weight{divisionFilter}&offset=0&limit=1000",
	"results": "/group?tab=weight{divisionFilter}&groupFilter=%7B%22id%22:%22weightClassName%22,%22type%22:%22string%22,%22value%22:%22{weightClassName}%22%7D"
}

today = datetime.date.today()
startDate = today - datetime.timedelta(weeks=2)
endDate = today + datetime.timedelta(weeks=8)

states = ["SC", "NC", "GA", "TN"]

# startDate = datetime.datetime.strptime("2025-11-14", "%Y-%m-%d").date()

cur.execute(sql["ExcludedGet"], (startDate, endDate))
excludedEvents = [row.SystemID for row in cur.fetchall()]

currentDate = startDate
while currentDate <= endDate:
	for state in states:
		dateStr = currentDate.strftime("%Y-%m-%d")
		
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
		
		for event in events:
			systemId = event["url"].split('/')[5]
			if systemId in excludedEvents:
				# Excluded or completed event
				continue

			eventName = event["name"]
			eventAddress = f"{event["location"]["venueName"]}, {event["location"]["city"]}, {event["location"]["region"]}"
			eventState = event["location"]["region"]

			# Update the event details
			cur.execute(sql["EventSave"], (systemId, eventName, dateStr, None, eventAddress, eventState, 0, 0))
			eventId = cur.fetchone()[0]

			if currentDate >= datetime.date.today():
				# In the future, or Flo says it's not completed
				continue
			
			logMessage(f"Fetching details for {eventName} on {dateStr}")
			divisionsUrl = apiUrls["base"] + apiUrls["event"].format(systemId=systemId) + apiUrls["divisions"]
			divisionsResponse = requests.get(divisionsUrl)
			time.sleep(1)

			if divisionsResponse.status_code != 200:
				errorLogging(f"Error fetching divisions for {eventName}. Status code: {divisionsResponse.status_code}")
				continue
			
			divisionsData = divisionsResponse.json()
			if not (divisionsData.get("data") and divisionsData["data"].get("options")):
				# If there are no divisions returned, load everything as one division
				divisions = [{"label": ""}]
			else:
				divisions = divisionsData["data"]["options"]

			for division in divisions:
				divisionName = division["label"]

				if len(divisionName) > 0:
					divisionFilter = apiUrls["divisionFilter"].format(divisionName=divisionName)
				else:
					# Don't invlude division filter if no division name
					divisionFilter = ""

				weightclassesUrl = apiUrls["base"] + apiUrls["event"].format(systemId=systemId) + apiUrls["weightclasses"].format(divisionFilter=divisionFilter)
				weightclassesResponse = requests.get(weightclassesUrl)
				time.sleep(1)

				if weightclassesResponse.status_code != 200:
					errorLogging(f"Error fetching weight classes for {eventName}, division {divisionName}. Status code: {weightclassesResponse.status_code}")
					continue

				weightclassesData = weightclassesResponse.json()
				if not (weightclassesData.get("data") and weightclassesData["data"].get("results")):
					continue

				for weightClass in weightclassesData["data"]["results"]:
					weightClassName = weightClass["title"]

					resultsUrl = apiUrls["base"] + apiUrls["event"].format(systemId=systemId) + apiUrls["results"].format(divisionFilter=divisionFilter, weightClassName=weightClassName)
					resultsResponse = None
					for i in range(3):
						try:
							resultsResponse = requests.get(resultsUrl)
							break
						except requests.exceptions.ConnectionError as e:
							errorLogging(f"Connection error: event {eventName}, division {divisionName}, weight class {weightClassName}. Retrying in {i*2+2} seconds. Error: {e}")
							time.sleep(i*2+2)
					
					if not resultsResponse or resultsResponse.status_code != 200:
						errorLogging(f"Error fetching event {eventName}, division {divisionName}, weight class {weightClassName}. Status code: {resultsResponse.status_code if resultsResponse else 'N/A'}")
						continue

					resultsData = resultsResponse.json()
					if not (resultsData.get("data") and resultsData["data"].get("results")):
						continue

					for roundData in resultsData["data"]["results"]:
						for matchIndex, match in enumerate(roundData["items"]):

							if len(match["athlete1"]["name"]) > 0 and len(match["athlete2"]["name"]) > 0:
								# No name, don't save
								athlete1Name = match["athlete1"]["name"]
								athlete1Team = match["athlete1"]["team"]["name"]
								athlete1Winner = match["athlete1"]["isWinner"]
								athlete2Name = match["athlete2"]["name"]
								athlete2Team = match["athlete2"]["team"]["name"]
								athlete2Winner = match["athlete2"]["isWinner"]
								winType = match["winType"]
								matchRound = match.get('round') if match.get('round') else None
								matchId = match["id"]
								sort = match.get("boutNumber") if match.get("boutNumber") and str.isnumeric(str(match.get("boutNumber"))) else (matchIndex + 1)

								if not re.search("bye", winType, re.I):

									cur.execute(sql["WrestlerSave"], (athlete1Name, athlete1Team))
									wrestler1Id = cur.fetchone()[0]
									cur.execute(sql["WrestlerSave"], (athlete2Name, athlete2Team))
									wrestler2Id = cur.fetchone()[0]

									cur.execute(sql["ExistingMatch"], (eventId, divisionName, weightClassName, matchRound, winType, wrestler1Id, wrestler2Id))
									existingMatches = cur.fetchone()[0]

									if existingMatches == 0:
										# If the match is duplicated in Flo don't add it
										cur.execute(sql["MatchSave"], (eventId, divisionName, weightClassName, matchRound, winType, sort))
										matchDbId = cur.fetchone()[0]

										cur.execute(sql["WrestlerMatchSave"], (matchDbId, wrestler1Id, athlete1Winner, athlete1Team, athlete1Name))
										cur.execute(sql["WrestlerMatchSave"], (matchDbId, wrestler2Id, athlete2Winner, athlete2Team, athlete2Name))

			cur.execute(sql["EventSave"], (systemId, eventName, dateStr, None, eventAddress, eventState, 1, 0))

		# Next state

	# Next date
	currentDate += datetime.timedelta(days=1)

logMessage(f"---------- FloWrestling scraper finished.")

logMessage(f"Email new wrestlers.")

cur.execute(sql["GetNewWrestlers"])
newWrestlers = cur.fetchall()

if len(newWrestlers) > 0:

	with open("./scripts/eventloader/newwrestlertemplate.html", "r") as reader:
		htmlTemplate = reader.read()

	rows = []
	wrestler_groups = {}
	for wrestler in newWrestlers:
		if wrestler.MatchGroupID not in wrestler_groups:
			wrestler_groups[wrestler.MatchGroupID] = []
		wrestler_groups[wrestler.MatchGroupID].append(wrestler)

	last_match_group_id = None
	group_counter = 0
	for index, wrestler in enumerate(newWrestlers):
		
		if wrestler.MatchGroupID != last_match_group_id:
			group_counter += 1
			last_match_group_id = wrestler.MatchGroupID

		row_class = []
		if group_counter % 2 != 0:
			row_class.append("odd-group")
		
		# Check if the group has more than one wrestler
		if len(wrestler_groups[wrestler.MatchGroupID]) > 1:
			row_class.append("group-row")
			
		# Check if it's the last wrestler in the group
		is_last_in_group = (index == len(newWrestlers) - 1) or (newWrestlers[index+1].MatchGroupID != wrestler.MatchGroupID)
		if is_last_in_group:
			row_class.append("group-end")

		class_string = f'class="{" ".join(row_class)}"' if row_class else ""

		existing_wrestler_html, new_wrestler_html = getNameDiffHtml(wrestler.ExistingWrestler, wrestler.NewWrestler)
		
		last_event_date = wrestler.LastEvent.strftime("%Y-%m-%d") if wrestler.LastEvent else ""

		script = f"insert into #dedup (saveid, dupid) values({wrestler.ExistingID},{wrestler.NewID});"

		row = f"""
		<tr {class_string}>
			<td>{wrestler.ExistingID}</td>
			<td>{wrestler.NewID}</td>
			<td>{existing_wrestler_html}</td>
			<td>{new_wrestler_html}</td>
			<td class="team-col">{wrestler.MatchedTeams}</td>
			<td>{last_event_date}</td>
			<td>{script}</td>
		</tr>
		"""
		rows.append(row)

	htmlBody = htmlTemplate.replace("<NewEmailData>", "\n".join(rows))

	msg = MIMEMultipart()
	msg["From"] = "wrestlingfortmill@gmail.com"
	msg["To"] = "maildrop444@gmail.com"
	msg["Subject"] = "New Wrestler Report - " + datetime.datetime.now().strftime("%Y-%m-%d")

	msg.attach(MIMEText(htmlBody, 'html'))

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
