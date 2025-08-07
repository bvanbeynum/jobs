import time
import datetime
import os

startTime = time.time()

import requests
import json
import pyodbc
from dateutil import parser
import re

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

	response = requests.get(f"https://arena.flowrestling.org/bracket/{ eventGUID }", headers=requestHeaders)
	divisions = json.loads(response.text)["response"]["divisions"]

	for divisionIndex, division in enumerate(divisions):
		divisionSave = { "name": division["name"], "weightClasses": [] }

		for weightIndex, weight in enumerate(division["weightClasses"]):
			weightSave = { "name": weight["name"], "pools": [] }

			for poolIndex, pool in enumerate(weight["boutPools"]):
				response = requests.get(f"https://arena.flowrestling.org/bracket/{ eventGUID }/bouts/{ weight['guid'] }/pool/{ pool['guid'] }", headers=requestHeaders)
				matches = json.loads(response.text)["response"]
				poolSave = { "name": pool["name"], "matches": [] }

				if len(matches) > 0:
					for matchIndex, match in enumerate(matches):
						
						sort = int(match["sequenceNumber"]) if match["sequenceNumber"] is not None and (str.isnumeric(str(match["sequenceNumber"])) or str.isdecimal(str(match["sequenceNumber"]))) else None
						if sort is None:
							sort = (divisionIndex + 1) * (weightIndex + 1) * (poolIndex + 1) * (matchIndex + 1)
						
						matchSave = {
							"guid": match["guid"],
							"round": match["roundName"]["displayName"],
							"matchNumber": match["boutNumber"],
							"sort": sort,
							"mat": match["mat"]["name"] if match["mat"] is not None else None,
							"roundNumber": match["trueRound"],
							"roundSpot": match["roundSpot"],
							"topWrestler": {
								"guid": match["topWrestler"]["guid"],
								"name": match["topWrestler"]["firstName"].title() + " " + match["topWrestler"]["lastName"].title(),
								"team": match["topWrestler"]["team"]["name"],
								"isWinner": True if match["topWrestler"]["guid"] == match["winnerWrestlerGuid"] else False
							} if match["topWrestler"] is not None else None,
							"bottomWrestler": {
								"guid": match["bottomWrestler"]["guid"],
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

						boutNumber = int(re.search("\d+", match["boutNumber"])[0]) if match["boutNumber"] is not None else None

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
								boutNumber, # @MatchNumber
								match["mat"]["name"] if match["mat"] is not None else None, # @Mat
								match["result"], # @Results
								topWrestlerId if match["topWrestler"] is not None else None, # @TopFlowWrestlerID
								bottomWrestlerId if match["bottomWrestler"] is not None else None, # @BottomFlowWrestlerID
								match["winnerToBoutGuid"], # @WinnerMatchFlowID
								match["winnerToTop"], # @WinnerToTop
								match["loserToBoutGuid"], # @LoserMatchFlowID
								match["loserToTop"], # @LoserToTop
								topWrestlerId if match["topWrestler"] is not None and match["topWrestler"]["guid"] == match["winnerWrestlerGuid"] else bottomWrestlerId if match["bottomWrestler"] is not None and match["bottomWrestler"]["guid"] == match["winnerWrestlerGuid"] else None, # @WinnerWrestlerID
								match["trueRound"], # @RoundNumber
								match["roundSpot"], # @RoundSpot
							))
						
						matchId = cur.fetchval()

						if match["topWrestler"] is not None:
							# Save wrestler match
							cur.execute(sql["WrestlerMatchSave"], (
								topWrestlerId, # @WrestlerID
								matchId, # @MatchID
								1 if match["topWrestler"]["guid"] == match["winnerWrestlerGuid"] else 0, # @IsWinner
								match["topWrestler"]["team"]["name"], # @TeamName
							))

						if match["bottomWrestler"] is not None:
							# Save wrestler match
							cur.execute(sql["WrestlerMatchSave"], (
								bottomWrestlerId, # @WrestlerID
								matchId, # @MatchID
								1 if match["bottomWrestler"]["guid"] == match["winnerWrestlerGuid"] else 0, # @IsWinner
								match["bottomWrestler"]["team"]["name"], # @TeamName
							))
						
						poolSave["matches"].append(matchSave)
					weightSave["pools"].append(poolSave)

				else:
					# No matches posted yet. pull in wrestlers instead
					response = requests.get(f"https://arena.flowrestling.org/bracket/{ eventGUID }/division/{ division['guid'] }/weight/{ weight['guid'] }/athletes", headers=requestHeaders)
					wrestlers = json.loads(response.text)["response"]

					for wrestler in wrestlers:
						cur.execute(sql["WrestlerSave"], (
							wrestler["guid"], # @FlowID
							wrestler["firstName"].title(), # @FirstName
							wrestler["lastName"].title(), # @LastName
							wrestler["team"]["name"], # @TeamName
							wrestler["team"]["guid"], # @TeamFlowID
						))
						wrestlerId = cur.fetchval()

						cur.execute(sql["WrestlerMeetSave"], (
							meetId, # @FloMeetID
							wrestlerId, # @FloWrestlerID
							division["name"], # @Division
							weight["name"], # @WeightClass
							wrestler["team"]["name"], # @TeamName
						))
					
				time.sleep(1) # Wait one second to not overload the api

			divisionSave["weightClasses"].append(weightSave)
		output["divisions"].append(divisionSave)
		
	cur.execute(sql["WrestlerUpdate"], (meetId,))
	return output

print(f"{ currentTime() }: ----------- Setup")

print(f"{ currentTime() }: Load config")

with open("./scripts/config.json", "r") as reader:
	config = json.load(reader)

requestHeaders = { "User-Agent": config["userAgent"] }

sql = loadSQL()

print(f"{ currentTime() }: DB connect")

cn = pyodbc.connect(f"DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={ config['database']['server'] };DATABASE={ config['database']['database'] };ENCRYPT=no;UID={ config['database']['user'] };PWD={ config['database']['password'] }", autocommit=True)
cur = cn.cursor()

print(f"{ currentTime() }: ----------- Load data")

response = requests.get(f"{ config['millServer'] }/api/floeventfavorites")
events = json.loads(response.text)["floEvents"]

updates = []
for event in events:
	if "isComplete" in event and event["isComplete"]:
		continue

	startDate = parser.parse(str(event["date"]))
	lastUpdate = parser.parse(event["lastUpdate"]) if "lastUpdate" in event and event["lastUpdate"] is not None else None

	timeToStart = startDate - datetime.datetime.now(datetime.timezone.utc)
	timeSinceUpdate = datetime.datetime.now(datetime.timezone.utc) - lastUpdate if lastUpdate is not None else None
	
	if lastUpdate is None:
		print(f"{ currentTime() }: Update { event['name'] }, no update")
		updates.append(event)
	
	elif 0 <= datetime.datetime.now().time().hour <= 5:
		# Don't update during the middle of the night
		continue

	elif timeToStart.days <= 0 and datetime.datetime.now(datetime.timezone.utc).date().day >= startDate.date().day  and timeSinceUpdate.seconds > 120:
		print(f"{ currentTime() }: Update { event['name'] }, start date { str(timeToStart.days) } days, last update { str(timeSinceUpdate.seconds) }s - active event, every 2 minutes")
		updates.append(event)

	elif timeToStart.days <= 1 and timeSinceUpdate.seconds > (60 * 30):
		print(f"{ currentTime() }: Update { event['name'] }, start date { str(timeToStart.days) } days, last update { str(timeSinceUpdate.seconds // 60) }m - one day away, every 30 min")
		updates.append(event)

	elif timeToStart.days >= 2 and timeToStart.days <= 7 and timeSinceUpdate.seconds > 60 * 60 * 24:
		print(f"{ currentTime() }: Update { event['name'] }, start date { str(timeToStart.days) } days, last update { str(timeSinceUpdate.seconds // 60 // 60) }h - between 2 & 7 days, once per day")
		updates.append(event)

if len(updates) == 0:
	print("no log") # Don't log anything if no updates
else:
	print(f"{ currentTime() }: Update: { len(updates) }")

	for update in updates:
		eventDetails = loadEvent(update["floGUID"], update["sqlId"])
		eventDetails["sqlId"] = update["sqlId"]
		eventDetails["lastUpdate"] = datetime.datetime.strftime(datetime.datetime.now(datetime.timezone.utc), "%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"

		startDate = parser.parse(str(update["date"]))
		endDate = parser.parse(str(update["endDate"]))

		isComplete = False
		if endDate is not None:
			timeSinceComplete = datetime.datetime.now(datetime.timezone.utc) - endDate
			
			if timeSinceComplete.days > 0:
				isComplete = True
		else:
			timeSinceStart = datetime.datetime.now(datetime.timezone.utc) - startDate

			if timeSinceStart.days > 1:
				isComplete = True
		
		if isComplete:
			cur.execute(sql["MeetComplete"], (update["sqlId"]))
			eventDetails["isComplete"] = True
		else:
			eventDetails["isComplete"] = False

		response = requests.post(f"{ config['millServer'] }/api/floeventsave", json={ "floEvent": eventDetails })
		cur.execute(sql["MeetLastUpdateSet"], (update["sqlId"]))

		print(f"{ currentTime() }: Completed { update['name'] }")

cur.close()
cn.close()

print(f"{ currentTime() }: ----------- End")
