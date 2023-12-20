import time
import datetime

startTime = time.time()

import os
import math
import json
import pyodbc
import glicko2

TAU = 0.5  # System constant

def currentTime():
	return datetime.datetime.strftime(datetime.datetime.now(), "%Y-%m-%d %H:%M:%S")

def loadSQL():
	sql = {}
	sqlPath = "./scripts/sql/glickoranking"

	if os.path.exists(sqlPath):
		for file in os.listdir(sqlPath):
			with open(f"{ sqlPath }/{ file }", "r") as fileReader:
				sql[os.path.splitext(file)[0]] = fileReader.read()
	
	return sql

def loadMatches(summaryId):
	cur.execute(sql["GetRunData"], (summaryId,))
	
	wrestlers = dict((
			str(wrestler.WrestlerID), 
			glicko2.Player(rating = float(wrestler.InitialRating), rd = float(wrestler.InitialDeviation), vol = float(wrestler.InitialVolatility))
		) for wrestler in cur.fetchall() )
	cur.nextset()

	matches = [ { 
			"winnerMatch": match.WinnerMatchID, 
			"winnerId": match.WinnerTSID, 
			"loserMatch": match.LoserMatchID, 
			"loserId": match.LoserTSID,
			"winType": match.WinType
		} 
		for match in cur.fetchall() ]
	
	return (wrestlers, matches)

# Calculate the Glicko-2 scale
def scale(phi):
	return 1 / math.sqrt(1 + 3 * phi**2 / math.pi**2)

def calculateProbaility(rating1, rd1, rating2, rd2):

	# Calculate the expected outcome for each player
	expected1 = 1 / (1 + math.exp(-TAU * scale(rd2) * (rating1 - rating2)))
	expected2 = 1 / (1 + math.exp(-TAU * scale(rd1) * (rating2 - rating1)))

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

print(f"{ currentTime() }: ----------- Initialize Runs")

cur.execute(sql["GetRuns"])
runs = cur.fetchall()

for run in runs:
	updates = []
	matchesCompleted = 0

	print(f"{ currentTime() }: running - { run.Title }")
	print(f"{ currentTime() }: initialize data")
	
	cur.execute(sql["Initialize"], (run.SummaryID, 1500.0, 550.0, 0.06))
	matchCount = cur.fetchval()

	print(f"{ currentTime() }: load batch")
	wrestlers, matches = loadMatches(run.SummaryID)

	while len(matches) > 0:
		for match in matches:
			winner = wrestlers[str(match["winnerId"])]
			loser = wrestlers[str(match["loserId"])]

			winnerRating = winner.rating
			winnerDeviation = winner.rd
			winnerVolatility = winner.vol
			
			loserRating = loser.rating
			loserDeviation = loser.rd
			loserVolatility = loser.vol
			
			winnerProbability = calculateProbaility(winnerRating, winnerDeviation, loserRating, loserDeviation)
			loserProbability = calculateProbaility(loserRating, loserDeviation, winnerRating, winnerDeviation)

			winOutcome = 1
			if match["winType"].lower() == "f":
				winOutcome = 1.2

			winner.update_player([loserRating], [loserDeviation], [winOutcome])
			loser.update_player([winnerRating], [winnerDeviation], [0])

			updates.append({
				"matchId": match["winnerMatch"],
				"winProbability": winnerProbability,
				"ratingInitial": winnerRating,
				"deviationInitial": winnerDeviation,
				"volatilityInitial": winnerVolatility,
				"ratingUpdate": winner.rating,
				"deviationUpdate": winner.rd,
				"volatilityUpdate": winner.vol
			})

			updates.append({
				"matchId": match["loserMatch"],
				"winProbability": loserProbability,
				"ratingInitial": loserRating,
				"deviationInitial": loserDeviation,
				"volatilityInitial": loserVolatility,
				"ratingUpdate": loser.rating,
				"deviationUpdate": loser.rd,
				"volatilityUpdate": loser.vol
			})

		matchesCompleted += len(matches)
		print(f"{ currentTime() }: { matchCount } total, { matchesCompleted } completed, { (matchCount - matchesCompleted) } remain")

		cur.execute(sql["CreateStage"])
		
		cur.executemany(sql["StageWrestlers"], [ [ int(key), value.rating, value.rd, value.vol ] for key, value in wrestlers.items() ])
		cur.executemany(sql["StageMatches"], [ [ match["matchId"], match["winProbability"], match["ratingInitial"], match["deviationInitial"], match["volatilityInitial"], match["ratingUpdate"], match["deviationUpdate"], match["volatilityUpdate"] ] for match in updates ])

		cur.execute(sql["UpdateMatches"])

		updates = []
		wrestlers, matches = loadMatches(run.SummaryID)

	cur.execute(sql["CompleteRun"], (run.SummaryID,))

cur.close()
cn.close()

print(f"{ currentTime() }: ----------- End")
