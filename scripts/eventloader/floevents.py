import requests
import pyodbc
import datetime
import json
import os
import sys
import csv
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

def loadConfig():
	with open("./scripts/config.json", "r") as reader:
		return json.load(reader)

def loadSql():
	sql_dir = "/workspaces/jobs/scripts/eventloader/sql/"
	sql_files = [f for f in os.listdir(sql_dir) if f.endswith('.sql')]
	sql_dict = {}
	for f in sql_files:
		with open(os.path.join(sql_dir, f), 'r') as reader:
			sql_dict[f.replace('.sql', '')] = reader.read()
	return sql_dict

config = loadConfig()
cn = pyodbc.connect(f"DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={ config['database']['server'] };DATABASE={ config['database']['database'] };ENCRYPT=no;UID={ config['database']['user'] };PWD={ config['database']['password'] }", autocommit=True)
cur = cn.cursor()
sql = loadSql()

startDate = datetime.datetime.now() - datetime.timedelta(weeks=2)
endDate = datetime.datetime.now() + datetime.timedelta(weeks=8)

logMessage("Fetching excluded events")
try:
	cur.execute(sql['ExcludedGet'], (startDate, endDate))
	excludedEvents = [row.SystemID for row in cur.fetchall()]
	logMessage(f"Found {len(excludedEvents)} excluded events")
	  
except Exception as e:
	errorLogging(f"Error fetching excluded events: {e}")
	sys.exit(1)

logMessage("Fetching events from FloWrestling API")
states = ["SC", "NC", "GA", "TN"]
currentDate = startDate

for state in states:
	while currentDate <= endDate:

		logMessage(f"Fetching events for {state} on {currentDate.strftime('%Y-%m-%d')}")
		payload = {
			"date": currentDate.strftime('%Y-%m-%d'),
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

		try:
			response = requests.post("https://prod-web-api.flowrestling.org/api/schedule/events", json=payload)
			response.raise_for_status()
			events = response.json()
			logMessage(f"Found {len(events)} events for {state} on {currentDate.strftime('%Y-%m-%d')}")

			for event in events:
				try:
					eventId = event['url'].split('/')[3]
					if eventId in excludedEvents:
						logMessage(f"Skipping excluded event: {event['name']}")
						continue

					eventName = event['name']
					eventDate = event['date']
					eventAddress = f"{event['location']['venueName']}, {event['location']['city']}, {event['location']['region']}"
					eventState = event['location']['region']
					isCompleted = event['status']['isCompleted']

					if eventState not in states:
						cur.execute(sql['EventSave'], (eventId, eventName, eventDate, None, eventAddress, eventState, 0, 1))
						continue
					
					if not isCompleted:
						cur.execute(sql['EventSave'], (eventId, eventName, eventDate, None, eventAddress, eventState, 0, 0))
					else:
						# TODO: Handle past events


				except Exception as e:
					errorLogging(f"Error processing event: {e}")

		except requests.exceptions.RequestException as e:
			errorLogging(f"Error fetching events for {state} on {currentDate.strftime('%Y-%m-%d')}: {e}")
			
	currentDate += datetime.timedelta(days=1)
