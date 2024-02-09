import time
import datetime

startTime = time.time()

import os
import math
import json
import pyodbc

TAU = 0.5  # System constant

def currentTime():
	return datetime.datetime.strftime(datetime.datetime.now(), "%Y-%m-%d %H:%M:%S")

def loadSQL():
	sql = {}
	sqlPath = "./scripts/sql/glickopredict"

	if os.path.exists(sqlPath):
		for file in os.listdir(sqlPath):
			with open(f"{ sqlPath }/{ file }", "r") as fileReader:
				sql[os.path.splitext(file)[0]] = fileReader.read()
	
	return sql

# Calculate the Glicko-2 scale
def scale(phi):
	return 1 / math.sqrt(1 + 3 * phi**2 / math.pi**2)

def calculateProbaility(rating1, rating2, rd1, rd2):

	# Get 1 SD
	rating1Adjusted = rating1 - rd1
	rating2Adjusted = rating2 - rd2

	# Calculate the expected outcome for each player
	expected1 = 1 / (1 + math.exp(-TAU * scale(rd2) * (rating1Adjusted - rating2Adjusted)))
	expected2 = 1 / (1 + math.exp(-TAU * scale(rd1) * (rating2Adjusted - rating1Adjusted)))

	# Calculate the win probability for Player 1
	winProbability = expected1 / (expected1 + expected2)

	return winProbability

print(f"{ currentTime() }: ----------- Setup")

print(f"{ currentTime() }: Load config")

with open("./scripts/config.json", "r") as reader:
	config = json.load(reader)

millDBURL = config["millServer"]

sql = loadSQL()

print(f"{ currentTime() }: DB connect")

cn = pyodbc.connect(f"DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={ config['database']['server'] };DATABASE={ config['database']['database'] };ENCRYPT=no;UID={ config['database']['user'] };PWD={ config['database']['password'] }", autocommit=True)
cur = cn.cursor()

print(f"{ currentTime() }: ----------- Load Team Data")

cur.execute(sql["GetTeams"])
teamData = cur.fetchall()

teams = list(set([ team.TeamName for team in teamData ]))

print(f"{ currentTime() }: { len(teams) } teams")

for teamName in teams:
	weightClasses = [ { 
		"teamId": team.TeamID,
		"teamName": team.TeamName,
		"weightClass": team.WeightClass,
		"fmMean": float(team.FMMean),
		"fmSD": float(team.FMSD),
		"vsMean": float(team.OpponentMean),
		"vsSD": float(team.OpponentSD)
	} for team in teamData if team.TeamName == teamName ]
	
	for weightClass in weightClasses:
		probability = calculateProbaility(weightClass["vsMean"], weightClass["fmMean"], weightClass["vsSD"], weightClass["fmSD"])
		cur.execute(sql["SavePrediction"], (weightClass["teamId"], probability))

print(f"{ currentTime() }: ----------- Run Wrestler Probabilities")

cur.execute(sql["CreateStage"])
cur.execute(sql["GetWrestlers"])
wrestlers = cur.fetchall()

rowIndex = 0
wrestlerCount = len(wrestlers)
updates = []

print(f"{ currentTime() }: Looping through wrestlers")

for wrestler in wrestlers:
	probability = calculateProbaility(float(wrestler.Wrestler1Rating), float(wrestler.Wrestler2Rating), float(wrestler.Wrestler1Deviation), float(wrestler.Wrestler2Deviation))
	updates.append([wrestler.Wrester1ID, wrestler.Wrester2ID, probability])

	rowIndex += 1

	if len(updates) >= 10000:
		print(f"{ currentTime() }: { wrestlerCount } total, { rowIndex } completed, { (wrestlerCount - rowIndex) } remain")

		cur.executemany(sql["StageWrestlers"], updates)

		updates = []

if len(updates) > 0:
	print(f"{ currentTime() }: { wrestlerCount } total, { rowIndex } completed, { (wrestlerCount - rowIndex) } remain")
	cur.executemany(sql["StageWrestlers"], updates)

cur.execute(sql["UpdateProbability"])

cur.close()
cn.close()

print(f"{ currentTime() }: ----------- End")
