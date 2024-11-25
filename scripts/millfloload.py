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

print(f"{ currentTime() }: Get wrestlers to delete")

cur.execute(sql["WrestlerStageCreate"])
cur.executemany(sql["WrestlerStageLoad"], [ (wrestler["sqlId"],) for wrestler in wrestlersMill ])
cur.execute(sql["WrestlersMissing"])

wrestlersDelete = [ wrestler.WrestlerID for wrestler in cur.fetchall() ]

if len(wrestlersDelete) > 0:
	print(f"{ currentTime() }: Delete { len(wrestlersDelete) } duplicates")
	response = requests.post(f"{ millDBURL }/api/externalwrestlersbulkdelete", json={ "wrestlerids": wrestlersDelete })

print(f"{ currentTime() }: Get wrestlers from DB")
cur.execute(sql["WrestlersLoad"])

wrestlerUpdates = []
wrestler = None
event = None

print(f"{ currentTime() }: Looping through the database")
for row in cur:

	if wrestler == None or row.WrestlerID != wrestler["sqlId"]:
		# New Wrestler

		if event is not None:
			wrestler["events"].append(event)

		if wrestler is not None:
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

if event is not None:
	wrestler["events"].append(event)

if wrestler is not None:
	wrestlerUpdates.append(wrestler)
	
print(f"{ currentTime() }: Loading final { len(wrestlerUpdates) } wrestlers to mill DB")
response = requests.post(f"{ millDBURL }/api/externalwrestlersbulksave", json={ "externalwrestlers": wrestlerUpdates })

if response.status_code >= 400:
	print(f"{ currentTime() }: Error saving external wrestlers: { response.status_code }")
	data = json.loads(response.text)["externalWrestlers"]
	print([ row for row in data if row["error"] is not None ])

print(f"{ currentTime() }: ----------- Matches")

print(f"{ currentTime() }: Get matches from Mongo")

matchesSave = []

response = requests.get(f"{ millDBURL }/api/flomatchgetbulk")
matchesMill = json.loads(response.text)["floMatches"]
matchesMill = sorted(matchesMill, key=lambda match: match, reverse=True)

print(f"{ currentTime() }: Get matches from SQL")
cur.execute(sql["MatchesLoad"])

print(f"{ currentTime() }: Looping through the database")
for row in cur:
	matchFound = [ match for match in matchesMill if match == row.MatchID ]

	if len(matchFound) == 0:
		matchesSave.append({
			"sqlId": row.MatchID,
			"winnerSqlId": row.WinnerID,
			"winner": row.Winner,
			"winnerTeam": row.WinnerTeam,
			"loserSqlId": row.LoserID,
			"loser": row.Loser,
			"loserTeam": row.LoserTeam,
			"winType": row.WinType,
			"date": datetime.datetime.strftime(row.EventDate, "%Y-%m-%dT%H:%M:%S.%f")[:-3],
			"event": row.EventName
		})
		
		if len(matchesSave) >= 100:
			print(f"{ currentTime() }: Loading { len(matchesSave) } matches to mill")
			response = requests.post(f"{ millDBURL }/api/flomatchsavebulk", json={ "matchessave": matchesSave })

			if response.status_code >= 400:
				print(f"{ currentTime() }: Error saving matches: { response.status_code }")
				data = json.loads(response.text)
				print([ row for row in data["floMatches"] if row["error"] is not None ])

			matchesSave = []

if len(matchesSave) > 0:
	print(f"{ currentTime() }: Loading { len(matchesSave) } matches to mill")
	response = requests.post(f"{ millDBURL }/api/flomatchsavebulk", json={ "matchessave": matchesSave })

	if response.status_code >= 400:
		print(f"{ currentTime() }: Error saving matches: { response.status_code }")
		data = json.loads(response.text)
		print([ row for row in data["floMatches"] if row["error"] is not None ])

cur.close()
cn.close()

print(f"{ currentTime() }: ----------- End")
