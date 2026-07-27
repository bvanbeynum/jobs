import datetime
import os
import requests
import json
import sys
import pyodbc
from neo4j import GraphDatabase

def loadQuery():
	query = {}
	queryPath = "./scripts/datamover/networksql"

	if os.path.exists(queryPath):
		for file in os.listdir(queryPath):
			with open(f"{ queryPath }/{ file }", "r") as fileReader:
				query[os.path.splitext(file)[0]] = fileReader.read()
	
	return query

def logMessage(message):
	logTime = datetime.datetime.strftime(datetime.datetime.now(), "%Y-%m-%d %H:%M:%S")
	print(f"{logTime} - {message}")

def errorLogging(errorMessage):
	logMessage(errorMessage)
	try:
		logPayload = {
			"log": {
				"logTime": datetime.datetime.now().isoformat(),
				"logTypeId": "6a43b752ff0bb2f165b4692b",
				"message": errorMessage
			}
		}
		apiSession.post(f"{config['apiServer']}/sys/api/addlog", json=logPayload)
	except Exception as apiError:
		logMessage(f"Failed to log error to API: {apiError}")

def chunkBatch(data, chunkSize):
	for index in range(0, len(data), chunkSize):
		yield data[index:index + chunkSize]





logMessage(f"----------- Setup")

logMessage(f"Load config")

with open("./scripts/config.json", "r") as reader:
	config = json.load(reader)

batchSize = 5000

apiSession = requests.Session()

query = loadQuery()

logMessage(f"DB connect")

try:
	cn = pyodbc.connect(f"DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={ config['database']['server'] };DATABASE={ config['database']['database'] };ENCRYPT=no;UID={ config['database']['user'] };PWD={ config['database']['password'] }", autocommit=True)
	cur = cn.cursor()
except pyodbc.Error as databaseError:
	errorLogging(f"Database connection failed: {databaseError}")
	sys.exit(1)

try:
	memgraphDriver = GraphDatabase.driver(config["memgraph"]["url"], auth=(config["memgraph"]["user"], config["memgraph"]["password"]))
	memgraphSession = memgraphDriver.session()
except Exception as memgraphError:
	errorLogging(f"Memgraph connection failed: {memgraphError}")
	sys.exit(1)

logMessage(f"----------- Sync")

logMessage("Getting wrestlers from SQL")
cur.execute(query["WrestlersGet"])
wrestlerColumns = [ column[0] for column in cur.description ]

wrestlers = []
for row in cur.fetchall():
	wrestlers.append(dict(zip(wrestlerColumns, row)))

logMessage(f"{ len(wrestlers) } wrestlers loaded")

for batch in chunkBatch(wrestlers, batchSize):
	memgraphSession.run(query["WrestlerInsert"], batch=batch)

logMessage("Getting matches from SQL")
cur.execute(query["MatchesGet"])
matchColumns = [ column[0] for column in cur.description ]

matches = []
for row in cur.fetchall():
	matches.append(dict(zip(matchColumns, row)))

logMessage(f"{ len(matches) } matches loaded")

for batch in chunkBatch(matches, batchSize):
	memgraphSession.run(query["MatchInsert"], batch=batch)

logMessage("Completed sync")

memgraphSession.close()
memgraphDriver.close()
cur.close()
cn.close()

logMessage(f"----------- End")
