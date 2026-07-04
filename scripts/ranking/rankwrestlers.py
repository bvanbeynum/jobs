import datetime
import os
import requests
import json
import pyodbc
import sys
import traceback
import glicko2

def loadSQL():
	sql = {}
	sqlPath = "./scripts/ranking/sql"

	if os.path.exists(sqlPath):
		for file in os.listdir(sqlPath):
			if file.endswith(".sql"):
				with open(f"{ sqlPath }/{ file }", "r") as fileReader:
					sql[os.path.splitext(file)[0]] = fileReader.read()
	
	return sql

def currentTime():
	return datetime.datetime.strftime(datetime.datetime.now(), "%Y-%m-%d %H:%M:%S")

def errorLogging(errorMessage):
	print(f"{ currentTime() }: { errorMessage }")
	try:
		logPayload = {
			"log": {
				"logTime": datetime.datetime.now().isoformat(),
				"logTypeId": "6a450d2bff0bb2f165b4c81f",
				"message": errorMessage
			}
		}
		apiSession.post(f"{ config['apiServer'] }/sys/api/addlog", json=logPayload)
	except Exception as apiError:
		print(f"{ currentTime() }: Failed to log error to API: { apiError }")

def logException(contextMessage, exception):
	tracebackDetails = traceback.format_exc()
	fullMessage = f"{ contextMessage }: { exception }\n\nTraceback Details:\n{ tracebackDetails }"
	errorLogging(fullMessage)

# ----------- Setup
print(f"{ currentTime() }: ----------- Setup")
print(f"{ currentTime() }: Load config")

try:
	with open("./scripts/config.json", "r") as reader:
		config = json.load(reader)
except Exception as configError:
	print(f"{ currentTime() }: Failed to load config.json: { configError }")
	sys.exit(1)

apiSession = requests.Session()
sql = loadSQL()

print(f"{ currentTime() }: DB connect")
try:
	connection = pyodbc.connect(f"DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={ config['database']['server'] };DATABASE={ config['database']['database'] };ENCRYPT=no;UID={ config['database']['user'] };PWD={ config['database']['password'] }", autocommit=True)
except pyodbc.Error as databaseError:
	logException("Database connection failed", databaseError)
	sys.exit(1)

# ----------- Sync/Process
print(f"{ currentTime() }: ----------- Start Weekly Ratings Process")

try:
	with connection.cursor() as cursor:
		cursor.execute(sql["MatchDateRange"])
		dateRangeResult = cursor.fetchone()
	minDate = dateRangeResult.MinDate
	maxDate = dateRangeResult.MaxDate
except Exception as queryError:
	logException("Failed to retrieve match date range", queryError)
	connection.close()
	sys.exit(1)

try:
	with connection.cursor() as cursor:
		cursor.execute(sql["LastProcessedDate"])
		lastProcessedDateResult = cursor.fetchone()
	lastProcessedDate = lastProcessedDateResult.LastProcessedDate if lastProcessedDateResult and lastProcessedDateResult.LastProcessedDate else None
except Exception as queryError:
	logException("Failed to retrieve last processed date", queryError)
	connection.close()
	sys.exit(1)

currentDate = lastProcessedDate + datetime.timedelta(days = 1) if lastProcessedDate else minDate

# Check if we have weeks to process before querying the database for all wrestler ratings to save resources.
hasWeeksToProcess = False
if currentDate and maxDate and currentDate <= maxDate:
	firstWeekEnd = currentDate + datetime.timedelta(days = 6 - currentDate.weekday())
	if firstWeekEnd <= datetime.datetime.now().date():
		hasWeeksToProcess = True

if not hasWeeksToProcess:
	print(f"{ currentTime() }: No weeks to process. Exiting cleanly.")
	connection.close()
	sys.exit(0)

# Load ALL latest ratings once from the database to initialize our in-memory cache
print(f"{ currentTime() }: Loading initial wrestler ratings cache from DB")
try:
	with connection.cursor() as cursor:
		cursor.execute(sql["LatestRatings"])
		latestRatings = cursor.fetchall()
	
	# Cache ratings in a Python dictionary for O(1) memory lookups
	ratingsCache = {}
	for latestRating in latestRatings:
		ratingsCache[latestRating.EventWrestlerID] = {
			"varsity": glicko2.Player(rating=float(latestRating.Rating), rd=float(latestRating.Deviation)),
			"jv": glicko2.Player(rating=float(latestRating.JVRating), rd=float(latestRating.JVDeviation)) if latestRating.JVRating and latestRating.JVDeviation else glicko2.Player(rating=1500, rd=500, vol=0.06),
			"ms": glicko2.Player(rating=float(latestRating.MSRating), rd=float(latestRating.MSDeviation)) if latestRating.MSRating and latestRating.MSDeviation else glicko2.Player(rating=1500, rd=500, vol=0.06),
			"girls": glicko2.Player(rating=float(latestRating.GirlsRating), rd=float(latestRating.GirlsDeviation)) if latestRating.GirlsRating and latestRating.GirlsDeviation else glicko2.Player(rating=1500, rd=500, vol=0.06),
		}
	print(f"{ currentTime() }: Loaded { len(ratingsCache) } wrestlers into memory cache")
except Exception as queryError:
	logException("Failed to load initial wrestler ratings", queryError)
	connection.close()
	sys.exit(1)

while currentDate <= maxDate:
	weekEnd = currentDate + datetime.timedelta(days=6 - currentDate.weekday())
	activityStartDate = currentDate - datetime.timedelta(days=365)

	if weekEnd > datetime.datetime.now().date():
		break

	print(f"{ currentTime() }: Processing matches for week ending { weekEnd.strftime('%Y-%m-%d') }")

	try:
		# 1. Get active wrestlers
		with connection.cursor() as cursor:
			cursor.execute(sql["ActiveWrestlers"], (weekEnd, activityStartDate))
			activeWrestlerRows = cursor.fetchall()
		activeWrestlers = { activeWrestlerRow.EventWrestlerID for activeWrestlerRow in activeWrestlerRows }

		# 2. Retrieve ratings from memory cache (no database query!)
		players = {}
		for wrestlerId in activeWrestlers:
			if wrestlerId in ratingsCache:
				# Use a copy/new Player instance referencing the cached values
				cached = ratingsCache[wrestlerId]
				players[wrestlerId] = {
					"varsity": glicko2.Player(rating=cached["varsity"].rating, rd=cached["varsity"].rd),
					"jv": glicko2.Player(rating=cached["jv"].rating, rd=cached["jv"].rd),
					"ms": glicko2.Player(rating=cached["ms"].rating, rd=cached["ms"].rd),
					"girls": glicko2.Player(rating=cached["girls"].rating, rd=cached["girls"].rd),
				}
			else:
				# Initialize new wrestler with defaults
				players[wrestlerId] = {
					"varsity": glicko2.Player(rating=1500, rd=500, vol=0.06),
					"jv": glicko2.Player(rating=1500, rd=500, vol=0.06),
					"ms": glicko2.Player(rating=1500, rd=500, vol=0.06),
					"girls": glicko2.Player(rating=1500, rd=500, vol=0.06)
				}

		# 3. Get weekly match outcomes
		with connection.cursor() as cursor:
			cursor.execute(sql["WeeklyOutcomes"], (currentDate, weekEnd))
			weeklyMatchOutcomes = cursor.fetchall()

		# 4. Map match outcomes
		playerResults = { playerId: { "varsity": [], "jv": [], "ms": [], "girls": [] } for playerId in players.keys() }
		for outcome in weeklyMatchOutcomes:
			winnerId = outcome.WinnerID
			loserId = outcome.LoserID

			if winnerId in activeWrestlers and loserId in activeWrestlers:
				winner = players[winnerId]
				loser = players[loserId]

				winType = outcome.WinType.lower()
				if "fall" in winType or "f" == winType:
					scoreRank = 1.0
				elif "tf" in winType:
					scoreRank = 1.0
				else:
					scoreRank = 0.7
				
				if outcome.Division == "HS":
					playerResults[winnerId]["varsity"].append((loser["varsity"].rating, loser["varsity"].rd, scoreRank))
					playerResults[loserId]["varsity"].append((winner["varsity"].rating, winner["varsity"].rd, 1 - scoreRank))
				elif outcome.Division == "JV":
					playerResults[winnerId]["jv"].append((loser["jv"].rating, loser["jv"].rd, scoreRank))
					playerResults[loserId]["jv"].append((winner["jv"].rating, winner["jv"].rd, 1 - scoreRank))
				elif outcome.Division == "MS":
					playerResults[winnerId]["ms"].append((loser["ms"].rating, loser["ms"].rd, scoreRank))
					playerResults[loserId]["ms"].append((winner["ms"].rating, winner["ms"].rd, 1 - scoreRank))
				elif outcome.Division == "Girls":
					playerResults[winnerId]["girls"].append((loser["girls"].rating, loser["girls"].rd, scoreRank))
					playerResults[loserId]["girls"].append((winner["girls"].rating, winner["girls"].rd, 1 - scoreRank))

		# 5. Update Glicko-2 ratings
		for playerId, player in players.items():
			player["varsity"]._preRatingRD()
			player["jv"]._preRatingRD()
			player["ms"]._preRatingRD()
			player["girls"]._preRatingRD()

		for playerId, resultType in playerResults.items():
			if resultType["varsity"] and len(resultType["varsity"]) > 0:
				ratings, rds, outcomes = zip(*resultType["varsity"])
				players[playerId]["varsity"].update_player(ratings, rds, outcomes)
			
			if resultType["jv"] and len(resultType["jv"]) > 0:
				ratings, rds, outcomes = zip(*resultType["jv"])
				players[playerId]["jv"].update_player(ratings, rds, outcomes)

			if resultType["ms"] and len(resultType["ms"]) > 0:
				ratings, rds, outcomes = zip(*resultType["ms"])
				players[playerId]["ms"].update_player(ratings, rds, outcomes)

			if resultType["girls"] and len(resultType["girls"]) > 0:
				ratings, rds, outcomes = zip(*resultType["girls"])
				players[playerId]["girls"].update_player(ratings, rds, outcomes)

		# 6. Save updates and synchronize ratingsCache in memory
		insertWrestlerRatingParams = []
		updateEventWrestlerParams = []
		for playerId, player in players.items():
			# Update the in-memory cache with the new ratings so they are immediately available for subsequent weeks
			ratingsCache[playerId] = {
				"varsity": player["varsity"],
				"jv": player["jv"],
				"ms": player["ms"],
				"girls": player["girls"]
			}

			insertWrestlerRatingParams.append((
				playerId, 
				weekEnd, 
				player["varsity"].rating, 
				player["varsity"].rd,
				player["jv"].rating,
				player["jv"].rd,
				player["ms"].rating,
				player["ms"].rd,
				player["girls"].rating,
				player["girls"].rd
			))

			updateEventWrestlerParams.append((
				player["varsity"].rating, 
				player["varsity"].rd, 
				player["jv"].rating, 
				player["jv"].rd, 
				player["ms"].rating, 
				player["ms"].rd, 
				player["girls"].rating, 
				player["girls"].rd,
				playerId
			))

		# Write batch updates using fast_executemany
		with connection.cursor() as cursor:
			cursor.fast_executemany = True  # Enable pyodbc high-speed batching
			cursor.executemany(sql["InsertRating"], insertWrestlerRatingParams)
			cursor.executemany(sql["UpdateWrestler"], updateEventWrestlerParams)

		print(f"{ currentTime() }: Finished processing for week ending { weekEnd.strftime('%Y-%m-%d') }")

	except Exception as processError:
		logException(f"Error occurred while processing week ending { weekEnd.strftime('%Y-%m-%d') }", processError)
		connection.close()
		sys.exit(1)

	currentDate = weekEnd + datetime.timedelta(days=1)

connection.close()
print(f"{ currentTime() }: ----------- End")
