import time
from datetime import datetime

startTime = time.time()

def currentTime():
	return datetime.strftime(datetime.now(), "%Y-%m-%d %H:%M:%S")

import requests
import json
import pyodbc

print(f"{ currentTime() }: ----------- Setup")

print(f"{ currentTime() }: Load config")

with open("./scripts/config.json", "r") as reader:
	config = json.load(reader)

print(f"{ currentTime() }: DB connect")

cn = pyodbc.connect(f"DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={ config['database']['server'] };DATABASE={ config['database']['database'] };ENCRYPT=no;UID={ config['database']['user'] };PWD={ config['database']['password'] }", autocommit=True)
cur = cn.cursor()

cur.execute("select distinct flowid from FloMeet where isexcluded = 1 or iscomplete = 1")
excluded = [ excluded.flowid for excluded in cur.fetchall() ]

print(f"{ currentTime() }: Get events")

response = requests.get(f"https://arena.flowrestling.org/events/past?year={ datetime.now().year }&month={ datetime.now().month }&eventType=tournaments")
events = json.loads(response.text)["response"]

for event in events:
	event["startDate"] = datetime.strptime(event["startDate"], "%Y-%m-%dT%H:%M:%S+%f")

events = sorted(events, key=lambda event: event["startDate"], reverse=True)

print(f"{ currentTime() }: ----------- Load events: { str(len(events)) }")

for eventIndex, event in enumerate(events):
	if event["guid"] in excluded:
		continue

	if not event["isPublishBrackets"] or not event["hasBrackets"]:
		# No data
		cur.execute("""
			set nocount on;
			declare @output int;
			exec dbo.MeetSave @MeetID = @output output
				, @FlowID = ?
				, @MeetName = ?
				, @IsExcluded = ?
				, @IsComplete = ?;
			select @output as OutputValue;
			""", (event["guid"], event["name"], 1, 0,))
		continue

	response = requests.get(f"https://floarena-api.flowrestling.org/events/{ event['guid'] }?include=features,scheduleItems,contacts,externalLinks&fields[event]=name,timeZone,startDateTime,endDateTime,isParticipantWaiverRequired,location,approvalStatus,siteId,features,divisions,products,scheduleItems,externalLinks,contacts,isVisible,createdByUserId,createdByUserAccount,stripeAccountId,stripeAccount,maxWrestlerCount,participantAlias,participantAliasPlural,description,websiteUrl,isDual,isSetupComplete,isPresetTeams,mats,resultEmailsSentDateTime,seasons,registrationReceiptMsg")
	eventInfo = json.loads(response.text)
	location = eventInfo["data"]["attributes"].get("location") if eventInfo.get("data") and eventInfo["data"].get("attributes") and eventInfo["data"]["attributes"].get("location") else None
	state = location.get("state") if location and eventInfo["data"]["attributes"]["location"].get("state") else None

	if state is None or str.lower(state) not in ["sc", "nc", "ga", "tn"]:
		
		# Not in state
		print(f"{ currentTime() }: Exclude { eventIndex + 1 } of { str(len(events)) } - { event['name'] }, state { state if state else '--' }")
		cur.execute("""
			set nocount on;
			declare @output int;
			exec dbo.MeetSave @MeetID = @output output
				, @FlowID = ?
				, @MeetName = ?
				, @IsExcluded = ?
				, @IsComplete = ?
				, @LocationName = ?
				, @LocationCity = ?
				, @LocationState = ?;
			select @output as OutputValue;
			""", (event["guid"], event["name"], 1, 0, event["locationName"], None, state,))
		continue

	print(f"{ currentTime() }: Add { eventIndex + 1 } of { str(len(events)) } - { event['name'] }, state { state }")

	cur.execute("""
		set nocount on;
		declare @output int;
		exec dbo.MeetSave @MeetID = @output output
			, @FlowID = ?
			, @MeetName = ?
			, @IsExcluded = ?
			, @IsComplete = ?
			, @LocationName = ?
			, @LocationCity = ?
			, @LocationState = ?
			, @StartTime = ?
			, @EndTime = ?;
		select @output as OutputValue;
		""", (event["guid"], event["name"], 0, 0, event["locationName"], location.get("city"), state, event["startDate"], datetime.strptime(event["endDate"], "%Y-%m-%dT%H:%M:%S+%f"),))
	
	meetId = cur.fetchval()

	response = requests.get(f"https://arena.flowrestling.org/bracket/{ event['guid'] }")
	divisions = json.loads(response.text)["response"]["divisions"]

	for divisionIndex, division in enumerate(divisions):
		if len(division["weightClasses"]) == 0:
			continue

		print(f"{ currentTime() }: Division { str(divisionIndex + 1) } of { str(len(divisions)) }: { division['name'] }")

		for weightIndex, weight in enumerate(division["weightClasses"]):
			print(f"{ currentTime() }: Weight { str(weightIndex + 1 )} of { str(len(division['weightClasses'])) }: { weight['name'] }")

			for poolIndex, pool in enumerate(weight["boutPools"]):
				response = requests.get(f"https://arena.flowrestling.org/bracket/{ event['guid'] }/bouts/{ weight['guid'] }/pool/{ pool['guid'] }")
				matches = json.loads(response.text)["response"]

				for matchIndex, match in enumerate(matches):
					# if match["topWrestler"] is None or match["bottomWrestler"] is None or (match["winType"] is not None and str.lower(match["winType"]) == "bye"): # match["winType"] is None or 
					# 	continue
					
					if match["topWrestler"] is not None:
						# Top wrestler
						
						cur.execute("""
							set nocount on;
							declare @output int;
							exec dbo.WrestlerSave @WrestlerID = @output output
								, @FlowID = ?
								, @FirstName = ?
								, @LastName = ?
								, @TeamName = ?
								, @TeamFlowID = ?;
							select @output as OutputValue;
							""", (match["topWrestler"]["guid"], match["topWrestler"]["firstName"].title(), match["topWrestler"]["lastName"].title(), match["topWrestler"]["team"]["name"], match["topWrestler"]["team"]["guid"],))
						topWrestlerId = cur.fetchval()

					if match["bottomWrestler"] is not None:
						# Bottom wrestler

						cur.execute("""
							set nocount on;
							declare @output int;
							exec dbo.WrestlerSave @WrestlerID = @output output
								, @FlowID = ?
								, @FirstName = ?
								, @LastName = ?
								, @TeamName = ?
								, @TeamFlowID = ?;
							select @output as OutputValue;
							""", (match["bottomWrestler"]["guid"], match["bottomWrestler"]["firstName"], match["bottomWrestler"]["lastName"], match["bottomWrestler"]["team"]["name"], match["bottomWrestler"]["team"]["guid"],))
						bottomWrestlerId = cur.fetchval()

					sort = match["sequenceNumber"]
					if sort is None:
						sort = (divisionIndex + 1) * (weightIndex + 1) * (poolIndex + 1) * (matchIndex + 1)
					
					cur.execute("""
						set nocount on;
						declare @output int;
						exec dbo.MatchSave @MatchID = @output output
							, @MeetID = ?
							, @FlowID = ?
							, @Division = ?
							, @WeightClass = ?
							, @PoolName = ?
							, @RoundName = ?
							, @WINType = ?
							, @VideoURL = ?
							, @Sort = ?
							, @MatchNumber = ?
							, @Mat = ?
							, @Results = ?
							, @TopFlowWrestlerID = ?
							, @BottomFlowWrestlerID = ?
							, @WinnerMatchFlowID = ?
							, @WinnerToTop = ?
							, @LoserMatchFlowID = ?
							, @LoserToTop = ?
		 					, @WinnerWrestlerID = ?;
						select @output as OutputValue;
						""", (
							meetId,
							match["guid"],
							division["name"], 
							weight["name"], 
							pool["name"], 
							match["roundName"]["displayName"], 
							match["winType"], 
							match["boutVideoUrl"], 
							sort,
							match["boutNumber"],
							match["mat"]["name"] if match["mat"] is not None else None,
							match["result"],
							topWrestlerId if match["topWrestler"] is not None else None,
							bottomWrestlerId if match["bottomWrestler"] is not None else None,
							match["winnerToBoutGuid"],
							match["winnerToTop"],
							match["loserToBoutGuid"],
							match["loserToTop"],
							topWrestlerId if match["topWrestler"]["guid"] == match["winnerWrestlerGuid"] else bottomWrestlerId if match["bottomWrestler"]["guid"] == match["winnerWrestlerGuid"] else None,
						))
					
					matchId = cur.fetchval()

					if match["topWrestler"] is not None:
						# Save wrestler match
						cur.execute("""
							set nocount on;
							declare @output int;
							exec dbo.WrestlerMatchSave @WrestlerMatchID = @output output
								, @WrestlerID = ?
								, @MatchID = ?
								, @IsWinner = ?;
							select @output as OutputValue;
							""", (topWrestlerId, matchId, 1 if match["topWrestler"]["guid"] == match["winnerWrestlerGuid"] else 0,))

					if match["bottomWrestler"] is not None:
						# Save wrestler match
						cur.execute("""
							set nocount on;
							declare @output int;
							exec dbo.WrestlerMatchSave @WrestlerMatchID = @output output
								, @WrestlerID = ?
								, @MatchID = ?
								, @IsWinner = ?;
							select @output as OutputValue;
							""", (bottomWrestlerId, matchId, 1 if match["bottomWrestler"]["guid"] == match["winnerWrestlerGuid"] else 0,))

	cur.execute("""
		set nocount on;
		exec dbo.WrestlerUpdate @MeetID = ?;
		""", (meetId,))
	
	cur.execute("""
		set nocount on;
		declare @output int;
		exec dbo.MeetSave @MeetID = @output output
			, @FlowID = ?
			, @MeetName = ?
			, @IsExcluded = ?
			, @IsComplete;
		select @output as OutputValue;
		""", (event["guid"], event["name"], 0, 1,))

print(f"{ currentTime() }: ----------- Upcoming Events")

cur.execute("select FlowID from FloMeet where StartTime > getdate()")
loaded = [ loaded.FlowID for loaded in cur.fetchall() ]

response = requests.get(f"https://arena.flowrestling.org/events/upcoming?eventType=tournaments")
events = json.loads(response.text)["response"]

print(f"{ currentTime() }: ")

for event in events:
	event["startDate"] = datetime.strptime(event["startDate"], "%Y-%m-%dT%H:%M:%S+%f")

events = sorted(events, key=lambda event: event["startDate"])

for eventIndex, event in enumerate(events):
	if event["guid"] in loaded:
		continue

	response = requests.get(f"https://floarena-api.flowrestling.org/events/{ event['guid'] }?include=features,scheduleItems,contacts,externalLinks&fields[event]=name,timeZone,startDateTime,endDateTime,isParticipantWaiverRequired,location,approvalStatus,siteId,features,divisions,products,scheduleItems,externalLinks,contacts,isVisible,createdByUserId,createdByUserAccount,stripeAccountId,stripeAccount,maxWrestlerCount,participantAlias,participantAliasPlural,description,websiteUrl,isDual,isSetupComplete,isPresetTeams,mats,resultEmailsSentDateTime,seasons,registrationReceiptMsg")
	eventInfo = json.loads(response.text)
	location = eventInfo["data"]["attributes"].get("location") if eventInfo.get("data") and eventInfo["data"].get("attributes") and eventInfo["data"]["attributes"].get("location") else None
	state = location.get("state") if location and eventInfo["data"]["attributes"]["location"].get("state") else None

	if state is not None and str.lower(state) in ["sc", "nc", "ga", "tn"]:	
		# In state, save
		print(f"{ currentTime() }: Adding { eventIndex + 1 } of { str(len(events)) } - { event['name'] }, state { state if state else '--' }")
		cur.execute("""
set nocount on;
declare @output int;
exec dbo.MeetSave @MeetID = @output output
	, @FlowID = ?
	, @MeetName = ?
	, @IsExcluded = ?
	, @IsComplete = ?
	, @LocationName = ?
	, @LocationCity = ?
	, @LocationState = ?
	, @StartTime = ?
	, @EndTime = ?;
""", (event["guid"], event["name"], 0, 0, event["locationName"], location.get("city"), state, event["startDate"], datetime.strptime(event["endDate"], "%Y-%m-%dT%H:%M:%S+%f"),))

	else:
		# Not in state
		print(f"{ currentTime() }: Exclude { eventIndex + 1 } of { str(len(events)) } - { event['name'] }, state { state if state else '--' }")
		cur.execute("""
set nocount on;
declare @output int;
exec dbo.MeetSave @MeetID = @output output
	, @FlowID = ?
	, @MeetName = ?
	, @IsExcluded = ?
	, @IsComplete = ?
	, @LocationName = ?
	, @LocationCity = ?
	, @LocationState = ?
	, @StartTime = ?
	, @EndTime = ?;
select @output as OutputValue;
""", (event["guid"], event["name"], 1, 0, event["locationName"], None, state, event["startDate"], datetime.strptime(event["endDate"], "%Y-%m-%dT%H:%M:%S+%f"),))

cur.close()
cn.close()

print(f"{ currentTime() }: ----------- End")
