import datetime
import os
import requests
import json
import pyodbc
import sys

def loadSQL():
	sql = {}
	sqlPath = "./scripts/datamover/sql"

	if os.path.exists(sqlPath):
		for file in os.listdir(sqlPath):
			with open(f"{ sqlPath }/{ file }", "r") as fileReader:
				sql[os.path.splitext(file)[0]] = fileReader.read()
	
	return sql

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

def getSeasonStartDate():
	# Seasons run from 9/1 to 8/31. We want the start date of the past season.
	# If today is after 9/1, past season started on 9/1 of last year.
	# If today is before 8/31, past season started on 9/1 of two years ago.
	today = datetime.datetime.now().date()
	if today.month >= 9:
		year = today.year - 1
	else:
		year = today.year - 2
	return datetime.date(year, 9, 1)

def isBonusPointWin(winType):
	# Bonus points are awarded for Falls, Tech Falls, Major Decisions, Forfeits, Disqualifications, and Injury Defaults.
	if not winType:
		return False
	wt = winType.upper()
	if wt in ["F", "TF", "MD", "DQ", "FF", "DF", "INJ"]:
		return True
	for keyword in ["FALL", "TECH", "MAJOR", "FORFEIT", "DEFAULT", "INJURY", "DISQ", "DQ", "MD", "TF"]:
		if keyword in wt:
			return True
	return False

def formatDate(dateValue):
	# Formats date/datetime objects to ISO string with milliseconds and Z timezone suffix.
	if dateValue is None:
		return None
	if isinstance(dateValue, datetime.date) and not isinstance(dateValue, datetime.datetime):
		dateValue = datetime.datetime.combine(dateValue, datetime.time.min)
	return datetime.datetime.strftime(dateValue, "%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"

def saveEventsBatch(eventsList, depth=0):
	# Declare errorCount as global to update the global error threshold tracking
	global errorCount
	if not eventsList:
		return True

	# Try posting to the bulk save endpoint with a timeout
	try:
		response = apiSession.post(f"{ millDBURL }/api/eventsbulksave", json={ "events": eventsList }, timeout=95)
		statusCode = response.status_code
		responseText = response.text
	except Exception as apiException:
		statusCode = 504
		responseText = str(apiException)

	if statusCode >= 400:
		# If the server timed out or failed to process the request, and the batch is large enough,
		# split the batch in half and recursively retry to bypass gateway timeout limits.
		if len(eventsList) > 10 and (statusCode == 504 or "timeout" in responseText.lower() or statusCode == 502):
			midIndex = len(eventsList) // 2
			firstHalf = eventsList[:midIndex]
			secondHalf = eventsList[midIndex:]
			logMessage(f"Gateway timeout/error on batch of { len(eventsList) } events. Retrying in two smaller chunks of { len(firstHalf) } and { len(secondHalf) }.")
			successFirst = saveEventsBatch(firstHalf, depth + 1)
			successSecond = saveEventsBatch(secondHalf, depth + 1)
			return successFirst and successSecond
		else:
			# If the batch cannot be split further or it's a non-transient error, log the failure.
			errorCount += 1
			errorLogging(f"Error bulk saving events (size { len(eventsList) }): { statusCode } - { responseText }")
			return False
	else:
		try:
			# Only log successes for sub-chunks (depth > 0) to keep normal output clean.
			if depth > 0:
				saveResult = response.json()
				matched = saveResult.get("matchedCount", 0)
				modified = saveResult.get("modifiedCount", 0)
				upserted = saveResult.get("upsertedCount", 0)
				inserted = saveResult.get("insertedCount", 0)
				logMessage(f"Bulk save completed for chunk of { len(eventsList) }: { matched } matched, { modified } modified, { upserted } upserted, { inserted } inserted")
		except Exception as parseError:
			errorLogging()
			errorLogging(f"Bulk save succeeded for chunk of { len(eventsList) }, but failed to parse response: { parseError }")
		return True

logMessage(f"----------- Setup")

logMessage(f"Load config")

with open("./scripts/config.json", "r") as reader:
	config = json.load(reader)

millDBURL = config["millServer"]

apiSession = requests.Session()

sql = loadSQL()

logMessage(f"DB connect")

try:
	cn = pyodbc.connect(f"DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={ config['database']['server'] };DATABASE={ config['database']['database'] };ENCRYPT=no;UID={ config['database']['user'] };PWD={ config['database']['password'] }", autocommit=True)
	cur = cn.cursor()
except pyodbc.Error as databaseError:
	errorLogging(f"Database connection failed: {databaseError}")
	sys.exit(1)

logMessage(f"----------- Sync")
logMessage(f"Get wrestlers from Mill")

response = apiSession.get(f"{ millDBURL }/data/wrestler?select=sqlId")
mongoWrestlers = json.loads(response.text)["wrestlers"]

# Create a lookup dictionary for mongoWrestlers by sqlId
wrestlerLookup = {wrestler['sqlId']: wrestler['id'] for wrestler in mongoWrestlers}

if len(mongoWrestlers) > 0:
	logMessage(f"Load mill wrestlers to stage")
	cur.execute(sql["WrestlerStageCreate"])
	cur.executemany("insert #WrestlerStage (WrestlerID, MongoID) values (?,?);", [ (wrestler["sqlId"],wrestler["id"]) for wrestler in mongoWrestlers ])
	cur.execute(sql["WrestlersMissing"])

	rowIndex = 0
	errorCount = 0

	logMessage(f"Loop through wrestlers to delete")
	for row in cur:
		response = apiSession.delete(f"{ millDBURL }/data/wrestler?id={ row.MongoID }")

		if response.status_code >= 400:
			errorCount += 1
			errorLogging(f"Error deleting wrestler: {response.status_code} - {response.text}")

		if errorCount > 15:
			logMessage(f"Too many errors ({ errorCount }). Exiting")
			break
		
		rowIndex += 1
		if rowIndex % 1000 == 0:
			logMessage(f"{ rowIndex } wrestlers deleted")

	logMessage(f"{ rowIndex } wrestlers deleted")

logMessage(f"Load wrestlers")

modifiedTimespan = -2
wrestledTimespan = -720
offset = 0
batchSize = 5000  # Adjust batch size as needed
wrestlersCompleted = 0

rowIndex = 0
errorCount = 0

while True:
	cur.execute(sql["WrestlersLoad"], (modifiedTimespan, wrestledTimespan, offset, batchSize))
	wrestlers_batch = cur.fetchall()
	logMessage(f"{ len(wrestlers_batch) } wrestlers loaded")

	if not wrestlers_batch:
		break  # No more wrestlers to fetch

	# Batch load matches
	cur.execute(sql["WrestlerBatchCreate"])
	cur.executemany("insert #WrestlerBatch (WrestlerID) values (?);", [[wrestler.WrestlerID] for wrestler in wrestlers_batch])
	cur.execute(sql["WrestlerMatchesBatchLoad"])
	matches_batch = cur.fetchall()
	logMessage(f"{ len(matches_batch) } matches loaded")

	# Batch load ratings
	cur.execute(sql["WrestlerRatingsBatchLoad"])
	ratings_batch = cur.fetchall()
	logMessage(f"{ len(ratings_batch) } ratings loaded")

	matches_by_wrestler = {}
	for match in matches_batch:
		if match.EventWrestlerID not in matches_by_wrestler:
			matches_by_wrestler[match.EventWrestlerID] = []
		matches_by_wrestler[match.EventWrestlerID].append(match)

	ratings_by_wrestler = {}
	for rating in ratings_batch:
		if rating.EventWrestlerID not in ratings_by_wrestler:
			ratings_by_wrestler[rating.EventWrestlerID] = []
		ratings_by_wrestler[rating.EventWrestlerID].append(rating)

	for wrestlerRow in wrestlers_batch:
		wrestler = {
			"sqlId": wrestlerRow.WrestlerID,
			"name": wrestlerRow.WrestlerName,
			"rating": float(wrestlerRow.Rating) if wrestlerRow.Rating is not None else None,
			"deviation": float(wrestlerRow.Deviation) if wrestlerRow.Deviation is not None else None,
			# "searchNames": wrestlerRow.SearchNames,
			# "searchTeams": wrestlerRow.SearchTeams,
			"events": [],
			"ratingHistory": []
		}

		# Add id if a match is found in wrestlerLookup
		if wrestlerRow.WrestlerID in wrestlerLookup:
			wrestler['id'] = wrestlerLookup[wrestlerRow.WrestlerID]

		matches = matches_by_wrestler.get(wrestlerRow.WrestlerID, [])
		ratings = ratings_by_wrestler.get(wrestlerRow.WrestlerID, [])

		for ratingRow in ratings:
			wrestler["ratingHistory"].append({
				"periodEndDate": datetime.datetime.strftime(ratingRow.PeriodEndDate, "%Y-%m-%d"),
				"rating": float(ratingRow.Rating),
				"deviation": float(ratingRow.Deviation)
			})

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
				"vsRating": float(matchRow.OpponentRating) if matchRow.OpponentRating is not None else None,
				"vsDeviation": float(matchRow.OpponentDeviation) if matchRow.OpponentDeviation is not None else None,
				"isWinner": matchRow.IsWinner,
				"winType": matchRow.WinType,
				"sort": matchRow.MatchSort
			})

		wrestler["events"] = list(events.values())

		response = apiSession.post(f"{ millDBURL }/data/wrestler", json={ "wrestler": wrestler })

		if response.status_code >= 400:
			errorCount += 1
			errorLogging(f"Error saving wrestler: {response.status_code} - {response.text}")

		if errorCount > 15:
			logMessage(f"Too many errors ({ errorCount }). Exiting")
			break

		wrestlersCompleted += 1
		if wrestlersCompleted % 1000 == 0:
			logMessage(f"{ wrestlersCompleted } wrestlers processed")

	offset += batchSize
	if errorCount > 15: # Break outer loop if too many errors
		break

logMessage(f"{ wrestlersCompleted } wrestlers processed")

logMessage(f"Get Schools from Wrestlingmill")

response = apiSession.get(f"{ millDBURL }/data/school?select=sqlId")
mongoSchools = json.loads(response.text)["schools"]

# Create a lookup dictionary for mongoWrestlers by sqlId
schoolLookup = {school['sqlId']: school['id'] for school in mongoSchools}

cur.execute(sql["SchoolsGet"])
schools = cur.fetchall()

schoolsCompleted = 0

for school in schools:
	schoolSave = {
		"sqlId": school.SchoolID,
		"name": school.SchoolName,
		"classification": school.Classification,
		"region": school.Region,
		"lookupNames": json.loads(school.LookupNames) if school.LookupNames else []
	}
	
	# Add id if a match is found in wrestlerLookup
	if school.SchoolID in schoolLookup:
		schoolSave["id"] = schoolLookup[school.SchoolID]

	response = apiSession.post(f"{ millDBURL }/data/school", json={ "school": schoolSave })

	if response.status_code >= 400:
		errorCount += 1
		errorLogging(f"Error saving school: {response.status_code} - {response.text}")
	
	schoolsCompleted += 1

logMessage(f"{ schoolsCompleted } schools processed")

logMessage(f"----------- Event Sync")

modifiedTimespanDays = -5
seasonStartDate = getSeasonStartDate()
modifiedThreshold = datetime.datetime.now() + datetime.timedelta(days=modifiedTimespanDays)

eventsProcessed = 0
eventBatchSize = 200
eventOffset = 0

while True:
	# Load a batch of events directly from SQL to minimize peak memory usage
	cur.execute(sql["EventsLoad"], (seasonStartDate, modifiedThreshold, modifiedThreshold, modifiedThreshold, eventOffset, eventBatchSize))
	eventsRows = cur.fetchall()
	
	if not eventsRows:
		break # No more events to sync
		
	# Load matches for the batch using a temp table to avoid passing large parameter lists
	cur.execute(sql["EventBatchCreate"])
	cur.executemany("insert #EventBatch (EventID) values (?);", [[eventRow.SqlID] for eventRow in eventsRows])
	
	cur.execute(sql["EventMatchesBatchLoad"])
	matchesRows = cur.fetchall()
	
	# Group matches by event to map them into their respective parents efficiently
	matchesByEvent = {}
	for matchRow in matchesRows:
		if matchRow.EventID not in matchesByEvent:
			matchesByEvent[matchRow.EventID] = []
		matchesByEvent[matchRow.EventID].append(matchRow)
		
	eventsPayload = []
	for eventRow in eventsRows:
		matchesList = []
		eventMatches = matchesByEvent.get(eventRow.SqlID, [])
		
		# Collect ratings to compute the event average and check for upsets
		eventRatings = []
		upsetCount = 0
		
		for matchRow in eventMatches:
			winnerRating = float(matchRow.WinnerRating) if matchRow.WinnerRating is not None else None
			winnerDeviation = float(matchRow.WinnerDeviation) if matchRow.WinnerDeviation is not None else None
			loserRating = float(matchRow.LoserRating) if matchRow.LoserRating is not None else None
			loserDeviation = float(matchRow.LoserDeviation) if matchRow.LoserDeviation is not None else None
			
			if winnerRating is not None:
				eventRatings.append(winnerRating)
			if loserRating is not None:
				eventRatings.append(loserRating)
				
			isUpset = False
			if winnerRating is not None and loserRating is not None and loserRating > winnerRating:
				isUpset = True
				upsetCount += 1
				
			matchesList.append({
				"matchSqlId": matchRow.MatchSqlID,
				"division": matchRow.Division,
				"weightClass": matchRow.WeightClass,
				"roundName": matchRow.RoundName,
				"winType": matchRow.WinType,
				"isUpset": isUpset,
				"sort": matchRow.MatchSort,
				"winner": {
					"wrestlerSqlId": matchRow.WinnerWrestlerSqlID,
					"name": matchRow.WinnerName,
					"team": matchRow.WinnerTeam,
					"rating": winnerRating,
					"deviation": winnerDeviation
				},
				"loser": {
					"wrestlerSqlId": matchRow.LoserWrestlerSqlID,
					"name": matchRow.LoserName,
					"team": matchRow.LoserTeam,
					"rating": loserRating,
					"deviation": loserDeviation
				}
			})
			
		eventSave = {
			"sqlId": eventRow.SqlID,
			"eventSystem": eventRow.EventSystem,
			"systemId": eventRow.SystemID,
			"eventType": eventRow.EventType,
			"name": eventRow.EventName,
			"date": formatDate(eventRow.EventDate),
			"endDate": formatDate(eventRow.EndDate),
			"location": eventRow.Location,
			"state": eventRow.EventState,
			"created": formatDate(eventRow.Created),
			"modified": formatDate(eventRow.Modified),
			"matches": matchesList
		}
		eventsPayload.append(eventSave)
		
	# Post current batch to the bulk save endpoint using retry/split logic
	saveEventsBatch(eventsPayload)
			
	if errorCount > 15:
		errorLogging(f"Too many errors ({ errorCount }). Exiting")
		break
		
	eventsProcessed += len(eventsPayload)
	if eventsProcessed % 1000 == 0:
		logMessage(f"{ eventsProcessed } events processed")
	eventOffset += eventBatchSize

cur.close()
cn.close()

logMessage(f"{ eventsProcessed } events processed")
logMessage(f"----------- End")
