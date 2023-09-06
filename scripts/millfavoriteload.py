import time
import datetime
import os

startTime = time.time()

import requests
import json
import pyodbc
from dateutil import parser

def currentTime():
	return datetime.datetime.strftime(datetime.datetime.now(), "%Y-%m-%d %H:%M:%S")

def loadSQL():
	sql = {}
	sqlPath = "./scripts/sql/millfavoriteload"

	if os.path.exists(sqlPath):
		for file in os.listdir(sqlPath):
			with open(f"{ sqlPath }/{ file }", "r") as fileReader:
				sql[os.path.splitext(file)[0]] = fileReader.read()
	
	return sql

def loadEvent(eventGUID, meetId):

	output = {
		"divisions": []
	}

	response = requests.get(f"https://arena.flowrestling.org/bracket/{ eventGUID }")
	divisions = json.loads(response.text)["response"]["divisions"]

	for divisionIndex, division in enumerate(divisions):
		divisionSave = { "name": division["name"], "weightClasses": [] }

		for weightIndex, weight in enumerate(division["weightClasses"]):
			weightSave = { "name": weight["name"], "pools": [] }

			for poolIndex, pool in enumerate(weight["boutPools"]):
				response = requests.get(f"https://arena.flowrestling.org/bracket/{ eventGUID }/bouts/{ weight['guid'] }/pool/{ pool['guid'] }")
				matches = json.loads(response.text)["response"]
				poolSave = { "name": pool["name"], "matches": [] }

				for matchIndex, match in enumerate(matches):
					
					sort = match["sequenceNumber"]
					if sort is None:
						sort = (divisionIndex + 1) * (weightIndex + 1) * (poolIndex + 1) * (matchIndex + 1)
					
					matchSave = {
						"round": match["roundName"]["displayName"],
						"matchNumber": match["boutNumber"],
						"sort": sort,
						"mat": match["mat"]["name"] if match["mat"] is not None else None,
						"topWrestler": {
							"name": match["topWrestler"]["firstName"].title() + " " + match["topWrestler"]["lastName"].title(),
							"team": match["topWrestler"]["team"]["name"],
							"isWinner": True if match["topWrestler"]["guid"] == match["winnerWrestlerGuid"] else False
						} if match["topWrestler"] is not None else None,
						"bottomWrestler": {
							"name": match["bottomWrestler"]["firstName"].title() + " " + match["bottomWrestler"]["lastName"].title(),
							"team": match["bottomWrestler"]["team"]["name"],
							"isWinner": True if match["bottomWrestler"]["guid"] == match["winnerWrestlerGuid"] else False
						} if match["bottomWrestler"] is not None else None,
						"winType": match["winType"],
						"results": match["result"],
						"nextMatch": {
							"winnerGUID": match["winnerToBoutGuid"],
							"isWinnerTop": match["winnerToTop"],
							"loserGUID": match["loserToBoutGuid"],
							"isLoserTop": match["loserToTop"]
						} if match["winnerToBoutGuid"] is not None else None
					}
					
					if match["topWrestler"] is not None:
						# Top wrestler
						
						cur.execute(sql["WrestlerSave"], (
							match["topWrestler"]["guid"], # @FlowID
							match["topWrestler"]["firstName"].title(), # @FirstName
							match["topWrestler"]["lastName"].title(), # @LastName
							match["topWrestler"]["team"]["name"], # @TeamName
							match["topWrestler"]["team"]["guid"], # @TeamFlowID
						))
						topWrestlerId = cur.fetchval()

					if match["bottomWrestler"] is not None:
						# Bottom wrestler

						cur.execute(sql["WrestlerSave"], (
							match["bottomWrestler"]["guid"], # @FlowID
							match["bottomWrestler"]["firstName"].title(), # @FirstName
							match["bottomWrestler"]["lastName"].title(), # @LastName
							match["bottomWrestler"]["team"]["name"], # @TeamName
							match["bottomWrestler"]["team"]["guid"], # @TeamFlowID
						))
						bottomWrestlerId = cur.fetchval()

					cur.execute(sql["MatchSave"], (
							meetId, # @MeetID
							match["guid"], # @FlowID
							division["name"], # @Division
							weight["name"], # @WeightClass
							pool["name"], # @PoolName
							match["roundName"]["displayName"], # @RoundName
							match["winType"], # @WinType
							match["boutVideoUrl"], # @VideoURL
							sort, # @Sort
							match["boutNumber"], # @MatchNumber
							match["mat"]["name"] if match["mat"] is not None else None, # @Mat
							match["result"], # @Results
							topWrestlerId if match["topWrestler"] is not None else None, # @TopFlowWrestlerID
							bottomWrestlerId if match["bottomWrestler"] is not None else None, # @BottomFlowWrestlerID
							match["winnerToBoutGuid"], # @WinnerMatchFlowID
							match["winnerToTop"], # @WinnerToTop
							match["loserToBoutGuid"], # @LoserMatchFlowID
							match["loserToTop"], # @LoserToTop
							topWrestlerId if match["topWrestler"] is not None and match["topWrestler"]["guid"] == match["winnerWrestlerGuid"] else bottomWrestlerId if match["bottomWrestler"] is not None and match["bottomWrestler"]["guid"] == match["winnerWrestlerGuid"] else None, # @WinnerWrestlerID
						))
					
					matchId = cur.fetchval()

					if match["topWrestler"] is not None:
						# Save wrestler match
						cur.execute(sql["WrestlerMatchSave"], (
							topWrestlerId, # @WrestlerID
							matchId, # @MatchID
							1 if match["topWrestler"]["guid"] == match["winnerWrestlerGuid"] else 0, # @IsWinner
						))

					if match["bottomWrestler"] is not None:
						# Save wrestler match
						cur.execute(sql["WrestlerMatchSave"], (
							bottomWrestlerId, # @WrestlerID
							matchId, # @MatchID
							1 if match["bottomWrestler"]["guid"] == match["winnerWrestlerGuid"] else 0, # @IsWinner
						))
					
					poolSave["matches"].append(matchSave)
				weightSave["pools"].append(poolSave)
			divisionSave["weightClasses"].append(weightSave)
		output["divisions"].append(divisionSave)
		
	cur.execute(sql["WrestlerUpdate"], (meetId,))
	return output

print(f"{ currentTime() }: ----------- Setup")

print(f"{ currentTime() }: Load config")

with open("./scripts/config.json", "r") as reader:
	config = json.load(reader)

sql = loadSQL()

print(f"{ currentTime() }: DB connect")

cn = pyodbc.connect(f"DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={ config['database']['server'] };DATABASE={ config['database']['database'] };ENCRYPT=no;UID={ config['database']['user'] };PWD={ config['database']['password'] }", autocommit=True)
cur = cn.cursor()

print(f"{ currentTime() }: ----------- Load data")

response = requests.get(f"{ config['devServer'] }/api/floeventfavorites")
events = json.loads(response.text)["floEvents"]

favoriteIds = "".join([ "|" + str(event["sqlId"]) + "|" for event in events ])

cur.execute(sql["UpdateFavorites"], (favoriteIds,))
cur.execute(sql["RemoveFavorites"], (favoriteIds,))

cur.execute(sql["GetFavorites"])
favorites = cur.fetchall()

print(f"{ currentTime() }: Review favorites: { len(favorites) }")

updates = []
for favorite in favorites:
	startTime = favorite.StartTime

	timeToStart = favorite.StartTime - datetime.datetime.now()
	timeSinceUpdate = datetime.datetime.now() - favorite.LastUpdate if favorite.LastUpdate is not None else None
	
	if favorite.LastUpdate is None:
		print(f"{ currentTime() }: Update { favorite.MeetName }, no update")
		updates.append(favorite)

	elif timeToStart.days <= 0 and timeSinceUpdate.seconds > 90:
		print(f"{ currentTime() }: Update { favorite.MeetName }, start date { str(timeToStart.days) } days, last update { str(timeSinceUpdate.seconds) }")
		updates.append(favorite)

	elif timeToStart.days == 1 and timeSinceUpdate.seconds > 600:
		print(f"{ currentTime() }: Update { favorite.MeetName }, start date { str(timeToStart.days) } days, last update { str(timeSinceUpdate.seconds) }")
		updates.append(favorite)

	elif timeToStart.days >= 2 and timeToStart.days <= 7 and timeSinceUpdate.seconds > 60 * 60 * 24:
		print(f"{ currentTime() }: Update { favorite.MeetName }, start date { str(timeToStart.days) } days, last update { str(timeSinceUpdate.seconds) }")
		updates.append(favorite)

for update in updates:
	eventDetails = loadEvent(update.FlowID, update.ID)
	response = requests.post(f"{ config['devServer'] }/api/floeventsave", json={ "floEvent": eventDetails })
	cur.execute(sql["MeetLastUpdateSet"], (update.ID))

	isComplete = False
	if update.EndTime is not None:
		timeSinceComplete = datetime.datetime.now() - update.EndTime
		
		if timeSinceComplete.days > 0:
			isComplete = True
	else:
		timeSinceStart = datetime.datetime.now() - update.StartTime

		if timeSinceStart.days > 1:
			isComplete = True
	
	if isComplete:
		cur.execute(sql["MeetComplete"], (update.ID))

	print(f"{ currentTime() }: Completed { update.MeetName }")

cur.close()
cn.close()

print(f"{ currentTime() }: ----------- End")
