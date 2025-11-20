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
		requests.post(f"{ config['apiServer'] }/sys/api/addlog", json=logPayload)
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

logMessage(f"Starting FloWrestling scraper.")

with open("./scripts/config.json", "r") as reader:
	config = json.load(reader)

cn = pyodbc.connect(f"DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={ config['database']['server'] };DATABASE={ config['database']['database'] };ENCRYPT=no;UID={ config['database']['user'] };PWD={ config['database']['password'] }", autocommit=True)
cur = cn.cursor()

sql = loadSql()

apiUrls = {
	"schedule": "https://api.flowrestling.org/api/experiences/web/schedule/tab/{date}?version=1.33.2&site_id=2&limit=100&offset=0&tz=America/New_York&showFavoriteIcon=true&isNextGenEventHub=true&enableGeoBlock=true&enableMultiday=true",
	"divisions": "https://nextgen.flowrestling.org/api/event-hub/{systemId}/results/filters/divisionName?limit=1000",
	"weightclasses": "https://nextgen.flowrestling.org/api/event-hub/{systemId}/results?tab=weight&filters=[%7B%22id%22:%22divisionName%22,%22type%22:%22string%22,%22value%22:%22{divisionName}%22%7D]&offset=0&limit=1000",
	"results": "https://nextgen.flowrestling.org/api/event-hub/{systemId}/results/group?tab=weight&filters=[%7B%22id%22:%22divisionName%22,%22type%22:%22string%22,%22value%22:%22{divisionName}%22%7D]&groupFilter=%7B%22id%22:%22weightClassName%22,%22type%22:%22string%22,%22value%22:%22{weightClassName}%22%7D"
}

today = datetime.date.today()
startDate = today - datetime.timedelta(weeks=2)
endDate = today + datetime.timedelta(weeks=8)

currentDate = startDate
while currentDate <= endDate:
	dateStr = currentDate.strftime("%Y-%m-%d")
	url = apiUrls["schedule"].format(date=dateStr)
	response = requests.get(url)
	time.sleep(2)

	if response.status_code != 200:
		errorLogging(f"Error fetching events for {dateStr}. Status code: {response.status_code}")
		currentDate += datetime.timedelta(days=1)
		continue

	eventsData = response.json()
	if not eventsData.get("tabs"):
		currentDate += datetime.timedelta(days=1)
		continue

	for tab in eventsData["tabs"]:
		if not (tab.get("content") and tab["content"].get("data")):
			continue
		for item in tab["content"]["data"]:
			if not item.get("items"):
				continue
			for eventItem in item["items"]:
				if not eventItem.get("rows"):
					continue
				for row in eventItem["rows"]:
					eventName = row["cells"][3]["data"]["text"]
					startDateStr = row["cells"][0]["data"]["textParts"]["startDateTime"]
					endDateStr = row["cells"][0]["data"]["textParts"]["endDateTime"]
					location = row["cells"][4]["data"]["text"]
					systemId = row["action"]["url"].split("/")[-1]

					if startDateStr.endswith('Z'):
						startDateStr_parsed = startDateStr.replace('Z', '+00:00')
					else:
						startDateStr_parsed = startDateStr[:-2] + ':' + startDateStr[-2:]
					startDateObj = datetime.datetime.fromisoformat(startDateStr_parsed).date()
					
					if endDateStr.endswith('Z'):
						endDateStr_parsed = endDateStr.replace('Z', '+00:00')
					else:
						endDateStr_parsed = endDateStr[:-2] + ':' + endDateStr[-2:]
					endDateObj = datetime.datetime.fromisoformat(endDateStr_parsed).date()

					cur.execute(sql['FloEventExistsGet'], (systemId))
					existingEvent = cur.fetchone()

					if existingEvent and existingEvent[0]:
						# Event is excluded in the database
						continue

					state = getStateFromLocation(location)
					isExcluded = 1 if state not in ['SC', 'NC', 'GA', 'TN'] else 0

					eventId = None
					if isExcluded:
						if not existingEvent:
							# State is in the excluded list
							cur.execute(sql['EventSave'], ('flo', systemId, None, eventName, startDateObj, endDateObj, location, state, 1, isExcluded))

						continue
					elif not existingEvent:
						logMessage(f"New event found: {eventName}. Inserting into database.")
						cur.execute(sql['EventSave'], ('flo', systemId, None, eventName, startDateObj, endDateObj, location, state, 0, isExcluded))
						eventId = cur.fetchone()[0]
					elif existingEvent and not existingEvent[0]:
						# Not completed
						cur.execute(sql['EventSave'], ('flo', systemId, None, eventName, startDateObj, endDateObj, location, state, 0, isExcluded))
						eventId = cur.fetchone()[0]
					
					if startDateObj >= today:
						continue

					if existingEvent and existingEvent[0]:
						# Event is completed
						continue

					logMessage(f"Fetching details for {eventName} on {dateStr}")
					divisionsUrl = apiUrls["divisions"].format(systemId=systemId)
					divisionsResponse = requests.get(divisionsUrl)
					time.sleep(2)

					if divisionsResponse.status_code != 200:
						errorLogging(f"Error fetching divisions for event {eventId}. Status code: {divisionsResponse.status_code}")
						continue
					
					divisionsData = divisionsResponse.json()
					if not (divisionsData.get("data") and divisionsData["data"].get("options")):
						cur.execute(sql['EventSave'], ('flo', systemId, None, eventName, startDateObj, endDateObj, location, state, 1, isExcluded))
						continue

					for division in divisionsData["data"]["options"]:
						divisionName = division['label']
						weightclassesUrl = apiUrls["weightclasses"].format(systemId=systemId, divisionName=divisionName)
						weightclassesResponse = requests.get(weightclassesUrl)
						time.sleep(2)

						if weightclassesResponse.status_code != 200:
							errorLogging(f"Error fetching weight classes for event {eventId}, division {divisionName}. Status code: {weightclassesResponse.status_code}")
							continue

						weightclassesData = weightclassesResponse.json()
						if not (weightclassesData.get("data") and weightclassesData["data"].get("results")):
							continue

						for weightClass in weightclassesData["data"]["results"]:
							weightClassName = weightClass['title']
							resultsUrl = apiUrls["results"].format(systemId=systemId, divisionName=divisionName, weightClassName=weightClassName)
							resultsResponse = None
							for i in range(3):
								try:
									resultsResponse = requests.get(resultsUrl)
									break
								except requests.exceptions.ConnectionError as e:
									errorLogging(f"Connection error: event {eventId}, division {divisionName}, weight class {weightClassName}. Retrying in {i*2+2} seconds. Error: {e}")
									time.sleep(i*2+2)
							
							if not resultsResponse or resultsResponse.status_code != 200:
								errorLogging(f"Error fetching event {eventId}, division {divisionName}, weight class {weightClassName}. Status code: {resultsResponse.status_code if resultsResponse else 'N/A'}")
								continue

							resultsData = resultsResponse.json()
							if not (resultsData.get("data") and resultsData["data"].get("results")):
								continue

							for roundData in resultsData["data"]["results"]:
								for matchIndex, match in enumerate(roundData["items"]):

									if len(match['athlete1']['name']) > 0 and len(match['athlete2']['name']) > 0:
										# No name, don't save
										athlete1Name = match['athlete1']['name']
										athlete1Team = match['athlete1']['team']['name']
										athlete1Winner = match['athlete1']['isWinner']
										athlete2Name = match['athlete2']['name']
										athlete2Team = match['athlete2']['team']['name']
										athlete2Winner = match['athlete2']['isWinner']
										winType = match['winType']
										matchRound = match.get('round') if match.get('round') else None
										matchId = match['id']
										sort = match.get("boutNumber") if match.get("boutNumber") and str.isnumeric(str(match.get("boutNumber"))) else (matchIndex + 1)

										if not re.search("bye", winType, re.I):

											cur.execute(sql['WrestlerSave'], (athlete1Name, athlete1Team))
											wrestler1Id = cur.fetchone()[0]
											cur.execute(sql['WrestlerSave'], (athlete2Name, athlete2Team))
											wrestler2Id = cur.fetchone()[0]

											cur.execute(sql['MatchSave'], (eventId, divisionName, weightClassName, matchRound, winType, sort))
											matchDbId = cur.fetchone()[0]

											cur.execute(sql['WrestlerMatchSave'], (matchDbId, wrestler1Id, athlete1Winner, athlete1Team, athlete1Name))
											cur.execute(sql['WrestlerMatchSave'], (matchDbId, wrestler2Id, athlete2Winner, athlete2Team, athlete2Name))

					cur.execute(sql['EventSave'], ('flo', systemId, None, eventName, startDateObj, endDateObj, location, state, 1, isExcluded))


	currentDate += datetime.timedelta(days=1)

logMessage(f"---------- FloWrestling scraper finished.")

logMessage(f"Email new wrestlers.")

cur.execute(sql["GetNewWrestlers"])
newWrestlers = cur.fetchall()

if len(newWrestlers) > 0:

	with open("./scripts/eventloader/newwrestlertemplate.html", "r") as reader:
		htmlTemplate = reader.read()

	rows = ""
	lastMatchGroupId = -1
	for wrestler in newWrestlers:
		isNewGroup = lastMatchGroupId != wrestler.MatchGroupID
		lastMatchGroupId = wrestler.MatchGroupID
		
		rowClass = "group-divider" if isNewGroup else ""

		rows += f"""<tr class="{rowClass}">
			<td>{wrestler.MatchGroupID}</td>
			<td class="new-record">{wrestler.NewWrestler}<br><small>ID: {wrestler.NewID}</small></td>
			<td class="existing-record">{wrestler.ExistingWrestler}<br><small>ID: {wrestler.ExistingID}</small></td>
			<td class="teams-col">{wrestler.MatchedTeams}</td>
			<td>{wrestler.LastEvent}</td>
		</tr>"""

	htmlBody = htmlTemplate.replace("<NewEmailData>", rows)

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
