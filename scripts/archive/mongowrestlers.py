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

print(f"{ currentTime() }: Get db wrestlers")

cur.execute("""
select	FloWrestler.ID
from	FloWrestler
join	FloWrestlerMatch
on		FloWrestler.ID = FloWrestlerMatch.FloWrestlerID
join	FloMatch
on		FloWrestlerMatch.FloMatchID = FloMatch.ID
join	FloMeet
on		FloMatch.FloMeetID = FloMeet.ID
group by
		FloWrestler.ID
		, FloWrestler.TeamName
		, FloWrestler.MongoSyncDate
		, FloWrestler.ModifiedDate
having	FloWrestler.ModifiedDate > FloWrestler.MongoSyncDate
		or max(FloWrestlerMatch.ModifiedDate) > FloWrestler.MongoSyncDate
order by
		case when FloWrestler.TeamName like '%fort mill%' then 0 else 1 end
		, min(case when FloMeet.LocationState = 'sc' then 0 else 1 end)
		, FloWrestler.TeamName
		, max(FloMeet.StartTime) desc
		, FloWrestler.ID
""")
dbWrestlers = cur.fetchall()

for dbIndex, dbWrestler in enumerate(dbWrestlers):

	response = requests.get(f"{ config['apiServer'] }/wrestling/data/wrestler?dbid={ dbWrestler.ID }")
	mongoWrestler = json.loads(response.text)["wrestlers"]

	if len(mongoWrestler) == 1:
		requests.delete(f"{ config['apiServer'] }/wrestling/data/wrestler?id={ mongoWrestler[0]['id'] }")

	cur.execute(f"""
select	FloWrestler.ID
		, FloWrestler.FlowID WrestlerFlowID
		, FloWrestler.FirstName
		, FloWrestler.LastName
		, FloWrestler.TeamName
		, FloWrestler.[State]
		, FloWrestler.Division WrestlerDivision
		, FloWrestler.WeightClass WrestlerWeight
		, WrestlerRank.Ranking
		, FloMeet.FlowID
		, FloMeet.MeetName
		, FloMeet.LocationName
		, FloMeet.LocationCity
		, FloMeet.LocationState
		, FloMeet.StartTime
		, FloMeet.EndTime
		, FloMatch.Division
		, FloMatch.WeightClass
		, FloMatch.RoundName
		, FloWrestlerMatch.IsWinner
		, FloMatch.WinType
		, vs.ID vsID
		, vs.FirstName + ' ' + vs.LastName vsName
		, vs.TeamName vsTeam
		, vs.FlowID vsFlowID
		, FloMatch.Sort
from	FloWrestler with (nolock)
join	FloWrestlerMatch with (nolock)
on		FloWrestler.id = FloWrestlerMatch.FloWrestlerID
join	FloMatch with (nolock)
on		FloWrestlerMatch.FloMatchID = FloMatch.ID
join	FloMeet with (nolock)
on		FloMatch.FloMeetID = FloMeet.ID
join	FloWrestlerMatch vsMatch with (nolock)
on		FloWrestlerMatch.FloMatchID = vsMatch.FloMatchID
		and FloWrestlerMatch.FloWrestlerID <> vsMatch.FloWrestlerID
join	FloWrestler vs with (nolock)
on		vsMatch.FloWrestlerID = vs.ID
left join
		WrestlerRank
on		replace(replace(FloWrestler.FirstName + FloWrestler.LastName, '-', ''), ' ', '') = replace(replace(WrestlerRank.FirstName + WrestlerRank.LastName, '-', ''), ' ', '')
		and WrestlerRank.SourceDate = (select max(SourceDate) from WrestlerRank)
where	FloWrestler.id = { dbWrestler.ID }
order by
		FloMeet.StartTime
		, FloMeet.ID
		, FloMatch.Sort
		, FloMatch.ID
	""")

	meet = {}
	for matchIndex, match in enumerate(cur):
		if matchIndex == 0:
			print(f"{ currentTime() }: Build wrestler { dbIndex } of { str(len(dbWrestlers)) }: { str(match.FirstName).title() } { str(match.LastName).title() }")
			wrestlerMongo = {
				"dbId": match.ID,
				"flowId": match.WrestlerFlowID,
				"firstName": str(match.FirstName).title(),
				"lastName": str(match.LastName).title(),
				"team": match.TeamName,
				"state": match.State,
				"division": match.WrestlerDivision,
				"weightClass": match.WrestlerWeight,
				"ranking": match.Ranking,
				"meets": []
			}

		if meet.get("flowId") is None or meet["flowId"] != match.FlowID:
			if meet.get("flowId"):
				wrestlerMongo["meets"].append(meet)

			meet = {
				"flowId": match.FlowID,
				"name": match.MeetName,
				"location": {
					"name": match.LocationName,
					"city": match.LocationCity,
					"state": match.LocationState
				},
				"startDate": datetime.strftime(match.StartTime, "%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z",
				"endDate": datetime.strftime(match.EndTime, "%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z",
				"division": match.Division,
				"weightClass": match.WeightClass,
				"matches": []
			}
		
		meet["matches"].append({
			"round": match.RoundName,
			"vs": {
				"dbId": match.vsID,
				"name": match.vsName,
				"team": match.vsTeam,
				"flowId": match.vsFlowID
			},
			"isWin": match.IsWinner == 1,
			"winType": match.WinType,
			"sort": match.Sort
		})

	wrestlerMongo["meets"].append(meet)

	# Update mongo
	try:
		requests.post(f"{ config['apiServer'] }/wrestling/data/wrestler", json={ "wrestler": wrestlerMongo })
	except:
		print(f"{ currentTime() }: Error saving { dbIndex } of { str(len(dbWrestlers)) }: { str(match.FirstName).title() } { str(match.LastName).title() }")
	else:
		cur.execute(f"update FloWrestler set MongoSyncDate = getdate() where id = { match.ID }")

cur.close()
cn.close()

print(f"{ currentTime() }: ----------- End")
