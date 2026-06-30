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

print(f"{ currentTime() }: ----------- Process")
print(f"{ currentTime() }: Get wrestlers from Mill")

response = requests.get(f"{ millDBURL }/data/event?select=sqlId")
events = json.loads(response.text)["events"]

if len(events) > 0: # if the data hasn't been wiped out
	cur.execute(sql["EventStageCreate"])
	cur.executemany("insert #EventStage (EventID) values (?);", [ (event["sqlId"],) for event in events ])
	cur.execute(sql["EventsDeleted"])

	rowIndex = 0
	errorCount = 0

	for row in cur:
		response = requests.delete(f"{ millDBURL }/data/event?sqlid={ row.EventID }")

		if response.status_code >= 400:
			errorCount += 1
			print(f"{ currentTime() }: Error deleting event: { response.status_code } - { response.text }")

			if errorCount > 15:
				print(f"{ currentTime() }: Too many errors ({ errorCount }). Exiting")
				break
		
		rowIndex += 1
		if rowIndex % 1000 == 0:
			print(f"{ currentTime() }: { rowIndex } events deleted")

	print(f"{ currentTime() }: { rowIndex } events deleted")

print(f"{ currentTime() }: Load all events")
cur.execute(sql["EventGet"], (100))

rowIndex = 0
errorCount = 0

for row in cur:
	event = {
		"sqlId": row.EventID,
		"eventSystem": row.EventSystem,
		"systemId": row.SystemID,
		"eventType": row.EventType,
		"name": row.EventName,
		"date": datetime.datetime.strftime(row.EventDate, "%Y-%m-%dT%H:%M:%S.%f")[:-3] if row.EventDate is not None else None,
		"endDate": datetime.datetime.strftime(row.EndDate, "%Y-%m-%dT%H:%M:%S.%f")[:-3] if row.EndDate is not None else None,
		"location": row.EventAddress,
		"state": row.EventState
	}
	response = requests.post(f"{ millDBURL }/data/event", json={ "event": event })

	if response.status_code >= 400:
		errorCount += 1
		print(f"{ currentTime() }: Error saving event: { response.status_code } - { response.text }")

		if errorCount > 15:
			print(f"{ currentTime() }: Too many errors ({ errorCount }). Exiting")
			break
	
	rowIndex += 1
	if rowIndex % 1000 == 0:
		print(f"{ currentTime() }: { rowIndex } events processed")

print(f"{ currentTime() }: { rowIndex } events processed")

cur.close()
cn.close()

print(f"{ currentTime() }: ----------- End")
