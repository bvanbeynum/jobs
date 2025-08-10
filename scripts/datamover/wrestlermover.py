import datetime
import os
import requests
import json
import pyodbc

def loadSQL():
	sql = {}
	sqlPath = "./scripts/datamover/sql"

	if os.path.exists(sqlPath):
		for file in os.listdir(sqlPath):
			if file.startswith("WrestlerMover"):
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

print(f"{ currentTime() }: ----------- Sync")
print(f"{ currentTime() }: Get wrestlers from Mill")

response = requests.get(f"{ millDBURL }/data/wrestler?select=sqlId")
mongoWrestlers = json.loads(response.text)["wrestlers"]

if len(mongoWrestlers) > 0:
	cur.execute(sql["WrestlerMover_WrestlerStageCreate"])
	cur.executemany("insert #WrestlerStage (WrestlerID) values (?);", [ (wrestler["sqlId"],) for wrestler in mongoWrestlers ])
	cur.execute(sql["WrestlerMover_WrestlersMissing"])

	rowIndex = 0
	errorCount = 0

	for row in cur:
		response = requests.delete(f"{ millDBURL }/data/wrestler?sqlid={ row.WrestlerID }")

		if response.status_code >= 400:
			errorCount += 1
			print(f"{ currentTime() }: Error deleting wrestler: { response.status_code } - { response.text }")

		if errorCount > 15:
			print(f"{ currentTime() }: Too many errors ({ errorCount }). Exiting")
			break
		
		rowIndex += 1
		if rowIndex % 1000 == 0:
			print(f"{ currentTime() }: { rowIndex } wrestlers deleted")

	print(f"{ currentTime() }: { rowIndex } wrestlers deleted")

print(f"{ currentTime() }: Load all wrestlers")
cur.execute(sql["WrestlerMover_WrestlersLoad"])

wrestlers = cur.fetchall()

rowIndex = 0
errorCount = 0

for wrestlerRow in wrestlers:
	wrestler = {
		"sqlId": wrestlerRow.WrestlerID,
		"name": wrestlerRow.WrestlerName,
		"rating": wrestlerRow.Rating,
		"deviation": wrestlerRow.Deviation,
		"events": [],
		"lineage": []
	}

	cur.execute(sql["WrestlerMover_WrestlerMatchesLoad"], (wrestlerRow.WrestlerID,))
	matches = cur.fetchall()

	events = {}
	for matchRow in matches:
		if matchRow.EventID not in events:
			events[matchRow.EventID] = {
				"sqlId": matchRow.EventID,
				"name": matchRow.EventName,
				"date": datetime.datetime.strftime(matchRow.EventDate, "%Y-%m-%dT%H:%M:%S.%f")[:-3] if matchRow.EventDate is not None else None,
				"team": matchRow.TeamName,
				"locationState": matchRow.EventState,
				"matches": []
			}
		
		events[matchRow.EventID]["matches"].append({
			"division": None,
			"weightClass": matchRow.WeightClass,
			"round": matchRow.MatchRound,
			"vs": matchRow.OpponentName,
			"vsTeam": matchRow.OpponentTeamName,
			"vsSqlId": matchRow.OpponentID,
			"isWinner": matchRow.IsWinner,
			"winType": matchRow.WinType,
			"sort": None
		})

	wrestler["events"] = list(events.values())

	if wrestlerRow.LineagePacket:
		wrestler["lineage"] = json.loads(wrestlerRow.LineagePacket)
	else:
		wrestler["lineage"] = []
	
	response = requests.post(f"{ millDBURL }/data/wrestler", json={ "wrestler": wrestler })

	if response.status_code >= 400:
		errorCount += 1
		print(f"{ currentTime() }: Error saving wrestler: { response.status_code } - { response.text }")

	if errorCount > 15:
		print(f"{ currentTime() }: Too many errors ({ errorCount }). Exiting")
		break
	
	rowIndex += 1
	if rowIndex % 1000 == 0:
		print(f"{ currentTime() }: { rowIndex } wrestlers processed")

print(f"{ currentTime() }: { rowIndex } wrestlers processed")

cur.close()
cn.close()

print(f"{ currentTime() }: ----------- End")