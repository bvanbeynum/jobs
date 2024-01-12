import time
import datetime

startTime = time.time()

import os
import requests
import json
import pyodbc
from dateutil import parser
from bs4 import BeautifulSoup
import re

def loadSQL():
	sql = {}
	sqlPath = "./scripts/sql/scmatload"

	if os.path.exists(sqlPath):
		for file in os.listdir(sqlPath):
			with open(f"{ sqlPath }/{ file }", "r") as fileReader:
				sql[os.path.splitext(file)[0]] = fileReader.read()
	
	return sql

def currentTime():
	return datetime.datetime.strftime(datetime.datetime.now(), "%Y-%m-%d %H:%M:%S")

print(f"{ currentTime() }: ----------- Setup")

print(f"{ currentTime() }: Load config")

with open("./scripts/config.json", "r") as reader:
	config = json.load(reader)

millDBURL = config["millServer"]
requestHeaders = { "User-Agent": config["userAgent"] }

sql = loadSQL()

confrences = [
	{ "name": "5A", "url": "http://scmat.com/scmat5Arank.html" }, 
	{ "name": "4A", "url": "http://scmat.com/scmat4Arank.html" }, 
	{ "name": "3A", "url": "http://scmat.com/scmat3Arank.html" }, 
	{ "name": "2A-1A", "url": "http://scmat.com/scmat2A1Arank.html" }, 
	{ "name": "SCISA", "url": "http://scmat.com/scmatSCISArank.html" }
	]

print(f"{ currentTime() }: DB connect")

cn = pyodbc.connect(f"DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={ config['database']['server'] };DATABASE={ config['database']['database'] };ENCRYPT=no;UID={ config['database']['user'] };PWD={ config['database']['password'] }", autocommit=True)
cur = cn.cursor()

cur.execute(sql["GetLastLoadDate"])
lastLoadDates = cur.fetchone()

print(f"{ currentTime() }: ----------- Get rankings")

hasUpdates = False

for confrenceIndex, confrence in enumerate(confrences):
	print(f"{ currentTime() }: Get rank { confrenceIndex + 1 } of { len(confrences)}: { confrence['name'] }")

	response = requests.get(confrence["url"], headers=requestHeaders)
	soup = BeautifulSoup(response.text, "lxml")

	content = soup.find("div", class_="content-full")
	sections = content.find_all("p")
	
	sourceDate = None

	sourceDateSection = [ section for section in sections if re.search("- (?:pre-season )?team rankings$", section.text, flags=re.IGNORECASE) ]
	if len(sourceDateSection) == 0:
		sourceDateSection = [ section for section in sections if re.search("individual rankings - state qualifiers", section.text, flags=re.IGNORECASE) ]
	
	if len(sourceDateSection) > 0:
		sourceDate = re.search("^[\w]+ [\d]{1,2}, [\d]{4}", sourceDateSection[0].text).group(0).strip()
		sourceDate = parser.parse(sourceDate)

	for sectionIndex, section in enumerate(sections):
		if re.search("- (?:pre-season )?team rankings$", section.text, flags=re.IGNORECASE):

			if lastLoadDates.TeamDate is None or sourceDate > lastLoadDates.TeamDate:
				teams = re.findall("([\d]+). ([^\n]+)\n", sections[sectionIndex + 1].text.strip() + "\n", flags=re.MULTILINE)
				
				print(f"{ currentTime() }: Loading { len(teams) } team rankings. Source: { datetime.datetime.strftime(sourceDate, '%m/%d/%Y') }")
				for team in teams:
					cur.execute(sql["TeamRankSave"], (
						confrence["name"],
						team[1].strip(), # Team Name
						int(team[0]), # Rank
						sourceDate
					))
				
				hasUpdates = True

			else:
				print(f"{ currentTime() }: Team rankings already loaded. Source: { datetime.datetime.strftime(sourceDate, '%m/%d/%Y') }")

		elif re.search("individual rankings by weight class", section.text, flags=re.IGNORECASE):

			if lastLoadDates.WrestlerDate is None or sourceDate > lastLoadDates.WrestlerDate:
				weights = re.findall("\n([\d]+) lbs\.", section.text, flags=re.IGNORECASE)
				# rankings = re.findall("\n([\d])\. ([A-Za-z\.\- ]+) - ([A-Za-z\.\- ]+) \(([A-Za-z]{2})\.", section.text, flags=re.IGNORECASE)
				rankings = re.findall("\n([\d])\. ([A-Za-z\.\- ]+) - ([A-Za-z\.\- ]+) \((([A-Za-z]{2})\.[^\)]*)?\)", section.text, flags=re.IGNORECASE)
				
				weightIndex = 0
				print(f"{ currentTime() }: Loading { len(rankings) } individual rankings. Source: { datetime.datetime.strftime(sourceDate, '%m/%d/%Y') }")
				for rankingIndex, ranking in enumerate(rankings):
					if rankingIndex > 0 and int(rankings[rankingIndex - 1][0]) > int(ranking[0]):
						weightIndex += 1

					cur.execute(sql["WrestlerRankSave"], (
						confrence["name"],
						ranking[1].split(" ")[0].strip(), # First Name
						str.join(" ", ranking[1].split(" ")[1:]).strip(), # Last Name
						ranking[2].strip(), # Team Name
						weights[weightIndex].strip(),
						int(ranking[0]), # Rank
						ranking[4].strip(), # Grade
						sourceDate
					))
				
				hasUpdates = True

			else:
				print(f"{ currentTime() }: Individual rankings already loaded. Source: { datetime.datetime.strftime(sourceDate, '%m/%d/%Y') }")

if hasUpdates:

	cur.execute(sql["GetTeams"])

	teams = []
	for row in cur:
		if len(teams) == 0 or teams[-1]["name"].strip().lower() != row.TeamName.strip().lower():
			teams.append({
				"name": row.TeamName.strip(),
				"confrence": row.Confrence.strip(),
				"rankings": [],
				"wrestlers": []
			})
		
		teams[-1]["rankings"].append({ "ranking": row.Ranking, "date": datetime.datetime.strftime(row.SourceDate, "%Y-%m-%dT%H:%M:%S.%f")[:-3] })
	
	for team in teams:
		cur.execute(sql["GetTeamWrestlers"], (team["name"]))

		for row in cur:
			if len(team["wrestlers"]) == 0 or (team["wrestlers"][-1]["firstName"].strip().lower() != row.FirstName.strip().lower() and team["wrestlers"][-1]["lastName"].strip().lower() != row.LastName.strip().lower()):
				team["wrestlers"].append({
					"firstName": row.FirstName.strip(),
					"lastName": row.LastName.strip(),
					"rankings": []
				})
			
			team["wrestlers"][-1]["rankings"].append({
				"grade": row.Grade.strip() if row.Grade is not None else None,
				"weightClass": row.WeightClass.strip(),
				"ranking": row.Ranking,
				"date": datetime.datetime.strftime(row.SourceDate, "%Y-%m-%dT%H:%M:%S.%f")[:-3]
			})
		
	print(f"{ currentTime() }: Updating teams")
	response = requests.post(f"{ millDBURL }/api/scmatteambulksave", json={ "teamssave": teams })
	
	if response.status_code >= 400:
		print(f"{ currentTime() }: Error saving teams: { response.status_code }")
		data = json.loads(response.text)["teams"]
		print([ row for row in data if row["error"] is not None ])


cur.close()
cn.close()

print(f"{ currentTime() }: ----------- End")
