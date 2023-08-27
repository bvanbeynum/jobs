import time
from datetime import datetime

startTime = time.time()

def currentTime():
	return datetime.strftime(datetime.now(), "%Y-%m-%d %H:%M:%S")

import requests
import json
import pyodbc

print(f"{ currentTime() }: ----------- Setup")

dbTeams = []
mongoTeams = []

print(f"{ currentTime() }: Load config")

with open("./scripts/config.json", "r") as reader:
	config = json.load(reader)

print(f"{ currentTime() }: Get Wrestling Mill teams")

response = requests.get(f"{ config['devServer'] }/api/externalteamsget")
mongoTeams = json.loads(response.text)["externalTeams"]

print(f"{ currentTime() }: DB connect")

cn = pyodbc.connect(f"DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={ config['database']['server'] };DATABASE={ config['database']['database'] };ENCRYPT=no;UID={ config['database']['user'] };PWD={ config['database']['password'] }", autocommit=True)
cur = cn.cursor()

print(f"{ currentTime() }: ----------- Data Load")

print(f"{ currentTime() }: Pull wrestlers")

cur.execute("""
select	FloWrestler.TeamName
		, FloWrestler.FirstName + ' ' + FloWrestler.LastName Wrestler
from	FloWrestler
join	FloWrestlerMatch
on		FloWrestler.ID = FloWrestlerMatch.FloWrestlerID
join	FloMatch
on		FloWrestlerMatch.FloMatchID = FloMatch.ID
join	FloMeet
on		FloMatch.FloMeetID = FloMeet.ID
where	FloMeet.StartTime > getdate() - 365
		and len(FloWrestler.TeamName) > 2
group by
		FloWrestler.TeamName
		, FloWrestler.FirstName
		, FloWrestler.LastName
order by
		FloWrestler.TeamName
		, FloWrestler.FirstName
		, FloWrestler.LastName
""")

for dbWrestler in cur:
	team = [ team for team in dbTeams if team["name"].lower() == dbWrestler.TeamName.lower() ]

	if len(team) == 0:
		team = { "name": dbWrestler.TeamName, "meets": [], "wrestlers": [] }
		dbTeams.append(team)
	else:
		team = team[0]
	
	wrestler = [ wrestler for wrestler in team["wrestlers"] if wrestler.lower() == dbWrestler.Wrestler.lower() ]

	if len(wrestler) == 0:
		team["wrestlers"].append(dbWrestler.Wrestler)

print(f"{ currentTime() }: Pull meets")

cur.execute("""
select  FloWrestler.TeamName
		, FloMeet.MeetName
from    FloWrestler
join	FloWrestlerMatch
on		FloWrestler.ID = FloWrestlerMatch.FloWrestlerID
join	FloMatch
on		FloWrestlerMatch.FloMatchID = FloMatch.ID
join	FloMeet
on		FloMatch.FloMeetID = FloMeet.ID
where	FloMeet.StartTime > getdate() - 365
		and len(FloWrestler.TeamName) > 2
group by
		FloWrestler.TeamName
		, FloMeet.MeetName
order by
		FloWrestler.TeamName
		, FloMeet.MeetName
""")

for dbMeet in cur:
	team = [ team for team in dbTeams if team["name"].lower() == dbMeet.TeamName.lower() ]

	if len(team) == 0:
		team = { "name": dbMeet.TeamName, "meets": [], "wrestlers": [] }
		dbTeams.append(team)
	else:
		team = team[0]
	
	meet = [ meet for meet in team["meets"] if meet.lower() == dbMeet.MeetName.lower() ]

	if len(meet) == 0:
		team["meets"].append(dbMeet.MeetName)

print(f"{ currentTime() }: Teams in Mongo: { len(mongoTeams) }")
print(f"{ currentTime() }: Teams in DB: { len(dbTeams) }")

print(f"{ currentTime() }: ----------- Compare")

print(f"{ currentTime() }: Calculate updates")

saveTeams = []
for dbTeam in dbTeams:
	mongoTeam = [ team for team in mongoTeams if team["name"].lower() == dbTeam["name"].lower() ]

	if len(mongoTeam) == 0:
		saveTeams.append(dbTeam)
	else:
		mongoTeam = mongoTeam[0]

		mongoTeam["wrestlers"].sort()
		mongoTeam["meets"].sort()
		dbTeam["wrestlers"].sort()
		dbTeam["meets"].sort()

		if mongoTeam["wrestlers"] != dbTeam["wrestlers"] or mongoTeam["meets"] != dbTeam["meets"]:
			saveTeams.append(mongoTeam | dbTeam)

deleteTeams = []
for mongoTeam in mongoTeams:
	dbTeam = [ team for team in dbTeams if team["name"].lower() == mongoTeam["name"].lower() ]

	if len(dbTeam) == 0:
		deleteTeams.append(mongoTeam["id"])

print(f"{ currentTime() }: Updates: { len(saveTeams) }, deletes: { len(deleteTeams) }")

response = requests.post(f"{ config['devServer'] }/api/externalteamssave", json={ "updateTeams": saveTeams, "deleteTeams": deleteTeams })

print(f"{ currentTime() }: Mongo updated: { response.text }")
print(f"{ currentTime() }: ----------- Done")
