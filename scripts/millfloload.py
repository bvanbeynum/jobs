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

if len(wrestlersMill) > 0: # if the data hasn't been wiped out
	print(f"{ currentTime() }: Get wrestlers to delete")

	cur.execute(sql["WrestlerStageCreate"])
	cur.executemany(sql["WrestlerStageLoad"], [ (wrestler["sqlId"],) for wrestler in wrestlersMill ])
	cur.execute(sql["WrestlersMissing"])

	wrestlersDelete = [ wrestler.WrestlerID for wrestler in cur.fetchall() ]

	if len(wrestlersDelete) > 0:
		print(f"{ currentTime() }: Delete { len(wrestlersDelete) } duplicates")
		response = requests.post(f"{ millDBURL }/api/externalwrestlersbulkdelete", json={ "wrestlerids": wrestlersDelete })

print(f"{ currentTime() }: Load all wrestlers to be moved")
cur.execute(sql["WrestlersLoad"])
cur.execute(sql["CreateBatchTable"])
cur.execute(sql["WrestlerCount"])
totalWrestlers = cur.fetchval()

wrestlerUpdates = []
wrestler = None
event = None
wrestlersSaved = 0
batchSize = 100

print(f"{ currentTime() }: Batch processing { totalWrestlers } wrestlers")

while wrestlersSaved < totalWrestlers:

	cur.execute(sql["WrestlerBatchLoad"], (batchSize,))
	cur.execute(sql["WrestlerMatchesLoad"])

	for row in cur:
		if wrestler == None or row.WrestlerID != wrestler["sqlId"]:
			# New Wrestler

			if event is not None:
				wrestler["events"].append(event)

			if wrestler is not None:
				wrestlerUpdates.append(wrestler)
			
			event = None
			wrestler = [ wrestler for wrestler in wrestlersMill if wrestler["sqlId"] == row.WrestlerID ]

			if len(wrestler) == 1:
				wrestler = wrestler[0]
				wrestler["firstName"] = row.FirstName
				wrestler["lastName"] = row.LastName
				wrestler["name"] = row.FirstName + " " + row.LastName
				wrestler["gRating"] = float(row.gRating) if row.gRating is not None else None
				wrestler["gDeviation"] = float(row.gDeviation) if row.gDeviation is not None else None
				wrestler["events"] = []

			else:
				wrestler = {
					"sqlId": row.WrestlerID,
					"firstName": row.FirstName,
					"lastName": row.LastName,
					"name": row.FirstName + " " + row.LastName,
					"gRating": float(row.gRating) if row.gRating is not None else None,
					"gDeviation": float(row.gDeviation) if row.gDeviation is not None else None,
					"events": []
				}
		
		if event is None or event["sqlId"] != row.EventID:
			if event is not None:
				wrestler["events"].append(event)

			event = {
				"sqlId": row.EventID,
				"date": datetime.datetime.strftime(row.EventDate, "%Y-%m-%dT%H:%M:%S.%f")[:-3],
				"name": row.EventName,
				"team": row.Team,
				"locationState": row.LocationState,
				"matches": []
			}

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
	
	wrestlersSaved += batchSize
	print(f"{ currentTime() }: Loading { wrestlersSaved } of { totalWrestlers }")
	response = requests.post(f"{ millDBURL }/api/externalwrestlersbulksave", json={ "externalwrestlers": wrestlerUpdates })

	if response.status_code >= 400:
		print(f"{ currentTime() }: Error saving external wrestlers: { response.status_code }")
		data = json.loads(response.text)
		print([ row for row in data["externalWrestlers"] if "error" in row and row["error"] is not None ])
		print([ row for row in data["externalTeams"] if "error" in row and row["error"] is not None ])

		time.sleep(20)
	else:
		cur.execute(sql["WrestlerBatchClear"])
		
	wrestlerUpdates = []

cur.close()
cn.close()

print(f"{ currentTime() }: ----------- End")
