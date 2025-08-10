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

# Create a lookup dictionary for mongoWrestlers by sqlId
wrestlerLookup = {wrestler['sqlId']: wrestler['id'] for wrestler in mongoWrestlers}

if len(mongoWrestlers) > 0:
	cur.execute(sql["WrestlerMover_WrestlerStageCreate"])
	cur.executemany("insert #WrestlerStage (WrestlerID, MongoID) values (?,?);", [ (wrestler["sqlId"],wrestler["id"]) for wrestler in mongoWrestlers ])
	cur.execute(sql["WrestlerMover_WrestlersMissing"])

	rowIndex = 0
	errorCount = 0

	for row in cur:
		response = requests.delete(f"{ millDBURL }/data/wrestler?id={ row.MongoID }")

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

print(f"{ currentTime() }: Load wrestlers")

offset = 0
batchSize = 5000  # Adjust batch size as needed
wrestlersCompleted = 0

rowIndex = 0
errorCount = 0

while True:
	cur.execute(sql["WrestlerMover_WrestlersLoad"], (offset, batchSize))
	wrestlers_batch = cur.fetchall()

	if not wrestlers_batch:
		break  # No more wrestlers to fetch

	for wrestlerRow in wrestlers_batch:
		wrestler = {
			"sqlId": wrestlerRow.WrestlerID,
			"name": wrestlerRow.WrestlerName,
			"rating": float(wrestlerRow.Rating) if wrestlerRow.Rating is not None else None,
			"deviation": float(wrestlerRow.Deviation) if wrestlerRow.Deviation is not None else None,
			"events": [],
			"lineage": []
		}

		# Add id if a match is found in wrestlerLookup
		if wrestlerRow.WrestlerID in wrestlerLookup:
			wrestler['id'] = wrestlerLookup[wrestlerRow.WrestlerID]

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
				"division": matchRow.Division,
				"weightClass": matchRow.WeightClass,
				"round": matchRow.MatchRound,
				"vs": matchRow.OpponentName,
				"vsTeam": matchRow.OpponentTeamName,
				"vsSqlId": matchRow.OpponentID,
				"isWinner": matchRow.IsWinner,
				"winType": matchRow.WinType,
				"sort": matchRow.MatchSort
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

		wrestlersCompleted += 1
		if wrestlersCompleted % 1000 == 0:
			print(f"{ currentTime() }: { wrestlersCompleted } wrestlers processed")

	offset += batchSize
	if errorCount > 15: # Break outer loop if too many errors
		break

print(f"{ currentTime() }: { wrestlersCompleted } wrestlers processed")

cur.close()
cn.close()

print(f"{ currentTime() }: ----------- End")