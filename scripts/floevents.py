import time
import datetime
import os

startTime = time.time()

import requests
import json
import pyodbc
import re

def currentTime():
	return datetime.datetime.strftime(datetime.datetime.now(), "%Y-%m-%d %H:%M:%S")

def loadSQL():
	sql = {}
	sqlPath = "./scripts/sql/floevents"

	if os.path.exists(sqlPath):
		for file in os.listdir(sqlPath):
			with open(f"{ sqlPath }/{ file }", "r") as fileReader:
				sql[os.path.splitext(file)[0]] = fileReader.read()
	
	return sql

def getEventDetails(eventGUID):	
	response = requests.get(f"https://floarena-api.flowrestling.org/events/{ eventGUID }?include=features,scheduleItems,contacts,externalLinks&fields[event]=name,timeZone,startDateTime,endDateTime,isParticipantWaiverRequired,location,approvalStatus,siteId,features,divisions,products,scheduleItems,externalLinks,contacts,isVisible,createdByUserId,createdByUserAccount,stripeAccountId,stripeAccount,maxWrestlerCount,participantAlias,participantAliasPlural,description,websiteUrl,isDual,isSetupComplete,isPresetTeams,mats,resultEmailsSentDateTime,seasons,registrationReceiptMsg", headers=requestHeaders)
	eventInfo = json.loads(response.text)
	location = eventInfo["data"]["attributes"].get("location") if eventInfo.get("data") and eventInfo["data"].get("attributes") and eventInfo["data"]["attributes"].get("location") else None

	return {
		"location": location,
		"city": location.get("city"),
		"state": location.get("state") if location and eventInfo["data"]["attributes"]["location"].get("state") else None,
	}

def loadEvent(eventGUID, eventId):

	output = {
		"divisions": []
	}

	response = requests.get(f"https://arena.flowrestling.org/bracket/{ eventGUID }", headers=requestHeaders)
	divisions = json.loads(response.text)["response"]["divisions"]
	time.sleep(2)

	for divisionIndex, division in enumerate(divisions):
		divisionSave = { "name": division["name"], "weightClasses": [] }

		if len(division["weightClasses"]) == 0:
			continue

		print(f"{ currentTime() }: Division { str(divisionIndex + 1) } of { str(len(divisions)) }: { division['name'] }")

		for weightIndex, weight in enumerate(division["weightClasses"]):
			print(f"{ currentTime() }: Weight { str(weightIndex + 1 )} of { str(len(division['weightClasses'])) }: { weight['name'] }")
			weightSave = { "name": weight["name"], "pools": [] }

			for poolIndex, pool in enumerate(weight["boutPools"]):
				response = requests.get(f"https://arena.flowrestling.org/bracket/{ eventGUID }/bouts/{ weight['guid'] }/pool/{ pool['guid'] }", headers=requestHeaders)
				matches = json.loads(response.text)["response"]
				time.sleep(2)
				poolSave = { "name": pool["name"], "matches": [] }

				for matchIndex, match in enumerate(matches):
					
					sort = int(match["sequenceNumber"]) if match["sequenceNumber"] is not None and (str.isnumeric(str(match["sequenceNumber"])) or str.isdecimal(str(match["sequenceNumber"]))) else None
					if sort is None:
						sort = (divisionIndex + 1) * (weightIndex + 1) * (poolIndex + 1) * (matchIndex + 1)
					
					boutNumber = int(re.search("\d+", match["boutNumber"])[0]) if match["boutNumber"] is not None and len(match["boutNumber"]) > 0 else None

					matchSave = {
						"round": match["roundName"]["displayName"],
						"matchNumber": boutNumber,
						"sort": sort,
						"mat": match["mat"]["name"] if match["mat"] is not None else None,
						"roundNumber": match["trueRound"],
						"roundSpot": match["roundSpot"],
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
							match["topWrestler"]["firstName"].title() + " " + match["topWrestler"]["lastName"].title(), # @WrestlerName
							match["topWrestler"]["team"]["name"], # @TeamName
						))
						topWrestlerId = cur.fetchval()

					if match["bottomWrestler"] is not None:
						# Bottom wrestler
						cur.execute(sql["WrestlerSave"], (
							match["bottomWrestler"]["firstName"].title() + " " + match["bottomWrestler"]["lastName"].title(), # @WrestlerName
							match["bottomWrestler"]["team"]["name"], # @TeamName
						))
						bottomWrestlerId = cur.fetchval()

					cur.execute(sql["MatchSave"], (
							eventId, # @EventID
							division["name"], # @Division
							weight["name"], # @WeightClass
							match["roundName"]["displayName"], # @RoundName
							match["winType"], # @WinType
							sort, # @Sort
						))
					matchId = cur.fetchval()

					if match["topWrestler"] is not None:
						# Save wrestler match
						cur.execute(sql["WrestlerMatchSave"], (
							matchId, # @MatchID
							topWrestlerId, # @WrestlerID
							1 if match["topWrestler"]["guid"] == match["winnerWrestlerGuid"] else 0, # @IsWinner
							match["topWrestler"]["team"]["name"], # @TeamName
							match["topWrestler"]["firstName"].title() + " " + match["topWrestler"]["lastName"].title(), # @WrestlerName
						))

					if match["bottomWrestler"] is not None:
						# Save wrestler match
						cur.execute(sql["WrestlerMatchSave"], (
							matchId, # @MatchID
							bottomWrestlerId, # @WrestlerID
							1 if match["bottomWrestler"]["guid"] == match["winnerWrestlerGuid"] else 0, # @IsWinner
							match["bottomWrestler"]["team"]["name"], # @TeamName
							match["bottomWrestler"]["firstName"].title() + " " + match["bottomWrestler"]["lastName"].title(), # @WrestlerName
						))
					
					poolSave["matches"].append(matchSave)
				weightSave["pools"].append(poolSave)

				time.sleep(3) # Wait to not overload the api

			divisionSave["weightClasses"].append(weightSave)
		output["divisions"].append(divisionSave)
		
	return output

def loadMill(event):
	print(f"{ currentTime() }: Moving { event['name'] } to the wrestling mill")
	
	response = requests.post(f"{ config['millServer'] }/api/floeventsave", json={ "floEvent": event })
	print(f"{ currentTime() }: Complete - { response.text }")

print(f"{ currentTime() }: ----------- Setup")

print(f"{ currentTime() }: Load config")

with open("./scripts/config.json", "r") as reader:
	config = json.load(reader)

requestHeaders = { "User-Agent": config["userAgent"] }

sql = loadSQL()

print(f"{ currentTime() }: DB connect")

cn = pyodbc.connect(f"DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={ config['database']['server'] };DATABASE={ config['database']['database'] };ENCRYPT=no;UID={ config['database']['user'] };PWD={ config['database']['password'] }", autocommit=True)
cur = cn.cursor()

print(f"{ currentTime() }: ----------- Upcoming Events")

cur.execute(sql["UpcomingLoadedGet"])
loaded = [ { "systemId": loaded.SystemID, "name": loaded.EventName, "eventDate": loaded.EventDate, "location": loaded.EventAddress } for loaded in cur.fetchall() ]

response = requests.get(f"https://arena.flowrestling.org/events/upcoming?eventType=tournaments", headers=requestHeaders)
events = json.loads(response.text)["response"]

print(f"{ currentTime() }: { len(events) } upcoming events")

for event in events:
	event["dateConverted"] = datetime.datetime.strptime(event["startDate"], "%Y-%m-%dT%H:%M:%S+%f")

events = sorted(events, key=lambda event: event["dateConverted"])

for eventIndex, event in enumerate(events):
	eventDB = [ eventDB for eventDB in loaded if eventDB["systemId"] == event["guid"]]
	if len(eventDB) > 0:
		if event["name"] != eventDB[0]["name"] or event["dateConverted"].date() != eventDB[0]["eventDate"]:
			location = getEventDetails(event["guid"])

			print(f"{ currentTime() }: Data Changed { eventIndex + 1 } of { str(len(events)) } - { event['name'] }, state { location['state'] if location['state'] else '--' }")
			cur.execute(sql["EventSave"], (
				event["guid"], # @SystemID
				event["name"], # @EventName
				event["dateConverted"], # @EventDate
				datetime.datetime.strptime(event["endDate"], "%Y-%m-%dT%H:%M:%S+%f"), # @EndDate
				(event.get("locationName", "") or "") + " " + (location.get("city", "") or "") + ", " + (location.get("state", "") or ""), # @EventAddress
				(location.get("state", "") or "")[:2], # @LocationState
				None, # @IsComplete
				None, # @IsExcluded
				))
			eventId = cur.fetchval()
			
			if str.lower(location.get("state", "")) in ["sc", "nc", "ga", "tn"]:
				eventDetails = {
					"sqlId": eventId,
					"floGUID": event["guid"],
					"name": event["name"],
					"location": event["locationName"],
					"city": location.get("city"),
					"state": location["state"],
					"date": event["startDate"],
					"endDate": event["endDate"],
					"hasBrackets": event["isPublishBrackets"],
					"divisions": []
				}
				loadMill(eventDetails)

		continue

	location = getEventDetails(event["guid"])

	if str.lower(location.get("state", "")) in ["sc", "nc", "ga", "tn"]:
		# In state, save
		print(f"{ currentTime() }: Adding { eventIndex + 1 } of { str(len(events)) } - { event['name'] }, state { location['state'] if location['state'] else '--' }")
		cur.execute(sql["EventSave"], (
			event["guid"], # @SystemID
			event["name"], # @EventName
			event["dateConverted"], # @EventDate
			datetime.datetime.strptime(event["endDate"], "%Y-%m-%dT%H:%M:%S+%f"), # @EndDate
			(event.get("locationName", "") or "") + " " + (location.get("city", "") or "") + ", " + (location.get("state", "") or ""), # @EventAddress
			(location.get("state", "") or "")[:2], # @LocationState
			0, # @IsComplete
			0, # @IsExcluded
			))
		eventId = cur.fetchval()
		
		eventDetails = {
			"sqlId": eventId,
			"floGUID": event["guid"],
			"name": event["name"],
			"location": event["locationName"],
			"city": location.get("city"),
			"state": location["state"][:2],
			"date": event["startDate"],
			"endDate": event["endDate"],
			"hasBrackets": event["isPublishBrackets"],
			"divisions": []
		}

		loadMill(eventDetails)

	else:
		# Not in state
		print(f"{ currentTime() }: Exclude { eventIndex + 1 } of { str(len(events)) } - { event['name'] }, state { location['state'] if location['state'] else '--' }")
		cur.execute(sql["EventSave"], (
			event["guid"], # @SystemID
			event["name"], # @EventName
			event["dateConverted"], # @EventDate
			datetime.datetime.strptime(event["endDate"], "%Y-%m-%dT%H:%M:%S+%f"), # @EndDate
			(event.get("locationName", "") or "") + " " + (location.get("city", "") or "") + ", " + (location.get("state", "") or ""), # @EventAddress
			(location.get("state", "") or "")[:2], # @LocationState
			0, # @IsComplete
			1, # @IsExcluded
			))
		
	# End upcoming events

cur.execute(sql["ExcludedGet"])
excluded = [ excluded.SystemID for excluded in cur.fetchall() ]

print(f"{ currentTime() }: Get past events")

response = requests.get(f"https://arena.flowrestling.org/events/past?year={ datetime.datetime.now().year }&eventType=tournaments", headers=requestHeaders)
# response = requests.get(f"https://arena.flowrestling.org/events/past?year={ datetime.datetime.now().year }&month={ datetime.datetime.now().month }&eventType=tournaments", headers=requestHeaders)
events = json.loads(response.text)["response"]
events = [ event for event in events if event["guid"] not in excluded ]

# Load custom event
# excluded = []
# events = [{ 
# 	"guid": "0feea7ce-0379-426d-93f1-e027b31fc261", 
# 	"startDate": "2024-09-29T13:30:00+0000", 
# 	"endDate": "2024-09-30T03:00:00+0000", 
# 	"name": "Pins in the Park - Carowinds 2024", 
# 	"locationName": "Carowinds", 
# 	"isPublishBrackets": True, 
# 	"hasBrackets": True 
# 	}]

for event in events:
	event["dateConverted"] = datetime.datetime.strptime(event["startDate"], "%Y-%m-%dT%H:%M:%S+%f")

events = sorted(events, key=lambda event: event["dateConverted"], reverse=True)

print(f"{ currentTime() }: ----------- Load events: { str(len(events)) }")

for eventIndex, event in enumerate(events):
	if event["guid"] in excluded:
		continue

	location = getEventDetails(event["guid"])

	if str.lower(location.get("state", "") or "") not in ["sc", "nc", "ga", "tn"]:
		
		# Not in state
		print(f"{ currentTime() }: Exclude { eventIndex + 1 } of { str(len(events)) } - { event['name'] }, state { location['state'] if location['state'] else '--' }")
		cur.execute(sql["EventSave"], (
			event["guid"], # @SystemID
			event["name"], # @EventName
			event["dateConverted"], # @EventDate
			datetime.datetime.strptime(event["endDate"], "%Y-%m-%dT%H:%M:%S+%f"), # @EndDate
			(event.get("locationName", "") or "") + " " + (location.get("city", "") or "") + ", " + (location.get("state", "") or ""), # @EventAddress
			(location.get("state", "") or "")[:2], # @LocationState
			0, # @IsComplete
			1, # @IsExcluded
			))
		continue

	if not event["isPublishBrackets"] or not event["hasBrackets"]:
		# No data
		cur.execute(sql["EventSave"], (
			event["guid"], # @SystemID
			event["name"], # @EventName
			event["dateConverted"], # @EventDate
			datetime.datetime.strptime(event["endDate"], "%Y-%m-%dT%H:%M:%S+%f"), # @EndDate
			(event.get("locationName", "") or "") + " " + (location.get("city", "") or "") + ", " + (location.get("state", "") or ""), # @EventAddress
			(location.get("state", "") or "")[:2], # @LocationState
			0, # @IsComplete
			0, # @IsExcluded
			))
		continue

	print(f"{ currentTime() }: Add { eventIndex + 1 } of { str(len(events)) } - { event['name'] }, state { location['state'] }")
	cur.execute(sql["EventSave"], (
		event["guid"], # @SystemID
		event["name"], # @EventName
		event["dateConverted"], # @EventDate
		datetime.datetime.strptime(event["endDate"], "%Y-%m-%dT%H:%M:%S+%f"), # @EndDate
		(event.get("locationName", "") or "") + " " + (location.get("city", "") or "") + ", " + (location.get("state", "") or ""), # @EventAddress
		(location.get("state", "") or "")[:2], # @LocationState
		0, # @IsComplete
		0, # @IsExcluded
		))
	eventId = cur.fetchval()

	loadEvent(event["guid"], eventId)
	
	cur.execute(sql["EventSave"], (
		event["guid"], # @SystemID
		event["name"], # @EventName
		event["dateConverted"], # @EventDate
		datetime.datetime.strptime(event["endDate"], "%Y-%m-%dT%H:%M:%S+%f"), # @EndDate
		(event.get("locationName", "") or "") + " " + (location.get("city", "") or "") + ", " + (location.get("state", "") or ""), # @EventAddress
		(location.get("state", "") or "")[:2], # @LocationState
		1, # @IsComplete
		0, # @IsExcluded
		))

# End past events 

cur.close()
cn.close()

print(f"{ currentTime() }: ----------- End")
