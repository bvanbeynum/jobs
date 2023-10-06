import time
import datetime

startTime = time.time()

import os
import requests
import json
import pyodbc
from dateutil import parser

def loadSQL():
	sql = {}
	sqlPath = "./scripts/sql/millfloload"

	if os.path.exists(sqlPath):
		for file in os.listdir(sqlPath):
			with open(f"{ sqlPath }/{ file }", "r") as fileReader:
				sql[os.path.splitext(file)[0]] = fileReader.read()
	
	return sql

def currentTime():
	return datetime.datetime.strftime(datetime.datetime.now(), "%Y-%m-%d %H:%M:%S")

print(f"{ currentTime() }: ----------- Setup")

print(f"{ currentTime() }: Load config")

with open("./scripts/config.json", "r") as reader:
	config = json.load(reader)

millDBURL = config["millServer"]

sql = loadSQL()

print(f"{ currentTime() }: DB connect")

cn = pyodbc.connect(f"DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={ config['database']['server'] };DATABASE={ config['database']['database'] };ENCRYPT=no;UID={ config['database']['user'] };PWD={ config['database']['password'] }", autocommit=True)
cur = cn.cursor()

print(f"{ currentTime() }: ----------- Wrestlers")

print(f"{ currentTime() }: Get wrestlers from Mill")

response = requests.get(f"{ millDBURL }/api/externalwrestlersbulk")
wrestlersMill = json.loads(response.text)["externalWrestlers"]

print(f"{ currentTime() }: Get wrestlers from DB")
cur.execute(sql["WrestlersLoad"])

wrestlerUpdates = []
wrestler = None
event = None
updateWrestler = False

print(f"{ currentTime() }: Looping through the database")
for row in cur:

	if wrestler == None or row.WrestlerID != wrestler["sqlId"]:
		# New Wrestler

		if event is not None and updateWrestler:
			wrestler["events"].append(event)

		if wrestler is not None and updateWrestler:
			wrestlerUpdates.append(wrestler)
		
		if len(wrestlerUpdates) >= 100:
			print(f"{ currentTime() }: Loading { len(wrestlerUpdates) } wrestlers to mill DB")
			response = requests.post(f"{ millDBURL }/api/externalwrestlersbulksave", json={ "externalwrestlers": wrestlerUpdates })

			if response.status_code >= 400:
				print(f"{ currentTime() }: Error saving external wrestlers: { response.status_code }")
				data = json.loads(response.text)
				print([ row for row in data["externalWrestlers"] if row["error"] is not None ])
				print([ row for row in data["externalTeams"] if row["error"] is not None ])

			wrestlerUpdates = []

		updateWrestler = False
		event = None
		wrestler = [ wrestler for wrestler in wrestlersMill if wrestler["sqlId"] == row.WrestlerID ]

		if len(wrestler) == 1:
			wrestler = wrestler[0]

		else:
			wrestler = {
				"sqlId": row.WrestlerID,
				"firstName": row.FirstName,
				"lastName": row.LastName,
				"name": row.FirstName + " " + row.LastName,
				"events": []
			}
			updateWrestler = True
	
	if event is None or event["sqlId"] != row.EventID:
		# New Event

		if event is not None and updateWrestler:
			# This is a new event, if we already had an event, add it to the wrestler
			wrestler["events"].append(event)

		event = [ event for event in wrestler["events"] if event["sqlId"] == row.EventID ]
		if len(event) != 1:
			# Event not found, create new event
			updateWrestler = True

			event = {
				"sqlId": row.EventID,
				"date": datetime.datetime.strftime(row.EventDate, "%Y-%m-%dT%H:%M:%S.%f")[:-3],
				"name": row.EventName,
				"team": row.Team,
				"matches": []
			}
		else:
			# Event already exists, no need to update
			event = None
	
	if event is not None and updateWrestler:
		# If this hasn't been set, then it's an existing event
		event["matches"].append({
			"division": row.Division,
			"weightClass": row.WeightClass,
			"round": row.RoundName,
			"vs": row.vs,
			"vsTeam": row.vsTeam,
			"vsSqlId": row.vsID,
			"isWinner": bool(row.IsWinner),
			"winType": row.WinType,
			"sort": row.Sort
		})

if event is not None and updateWrestler:
	wrestler["events"].append(event)

if wrestler is not None and updateWrestler:
	wrestlerUpdates.append(wrestler)
	
print(f"{ currentTime() }: Loading final { len(wrestlerUpdates) } wrestlers to mill DB")
response = requests.post(f"{ millDBURL }/api/externalwrestlersbulksave", json={ "externalwrestlers": wrestlerUpdates })

if response.status_code >= 400:
	print(f"{ currentTime() }: Error saving external wrestlers: { response.status_code }")
	data = json.loads(response.text)["externalWrestlers"]
	print([ row for row in data if row["error"] is not None ])

cur.close()
cn.close()

print(f"{ currentTime() }: ----------- End")
