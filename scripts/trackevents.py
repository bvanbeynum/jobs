import time
import datetime
import os

startTime = time.time()

def currentTime():
	return datetime.datetime.strftime(datetime.datetime.now(), "%Y-%m-%d %H:%M:%S")

def loadSQL(sqlPath):
	sql = {}

	if os.path.exists(sqlPath):
		for file in os.listdir(sqlPath):
			with open(f"{ sqlPath }/{ file }", "r") as fileReader:
				sql[os.path.splitext(file)[0]] = fileReader.read()
	
	return sql

import requests
import json
import pyodbc
from bs4 import BeautifulSoup
import re

print(f"{ currentTime() }: ----------- Setup")

print(f"{ currentTime() }: Load config")

with open("./scripts/config.json", "r") as reader:
	config = json.load(reader)

sql = loadSQL("./scripts/sql/trackevents")
requestHeaders = { "User-Agent": config["userAgent"] }

print(f"{ currentTime() }: DB connect")

cn = pyodbc.connect(f"DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={ config['database']['server'] };DATABASE={ config['database']['database'] };ENCRYPT=no;UID={ config['database']['user'] };PWD={ config['database']['password'] }", autocommit=True)
cur = cn.cursor()

print(f"{ currentTime() }: ----------- Pull Data")

states = [
	{ "id": 41, "name": "SC" },
	{ "id": 34, "name": "NC" },
	{ "id": 43, "name": "TN" },
	{ "id": 13, "name": "GA" }
]

for state in states:

	response = requests.get(f"https://www.trackwrestling.com/Login.jsp?tName=&state={ state['id'] }&sDate=&eDate=&lastName=&firstName=&teamName=&sfvString=&city=&gbId=&camps=false", headers=requestHeaders)
	soup = BeautifulSoup(response.text, "lxml")

	tournamentUL = soup.find("ul", class_="tournament-ul")
	tournamentsLI = tournamentUL.find_all("li")

	print(f"{ currentTime() }: { len(tournamentsLI )} tournaments found in { state['name'] }")

	for tournamentLI in tournamentsLI:
		eventDate = None
		endDate = None
		address = ""

		for section in tournamentLI.find_all("div"):
			if len(section.find_all("span")) > 1:
				linkData = re.findall("eventSelected\(([\d]+),'([^']+)',", section.select("a[href^=\"javascript:eventSelected\"]")[0]["href"], re.DOTALL)[0]

				if len(linkData) == 2:
					eventId = linkData[0]
					eventName = linkData[1]
				
				sourceDate = [ date.text.strip() for date in section.find_all("span") if re.search("[\d]+/[\d]+/[\d]+", date.text.strip())][0]
				if re.search("^[\d]{2}\/[\d]{2}\/[\d]{4}", sourceDate) is not None:
					eventDate = datetime.datetime.strptime(sourceDate, "%m/%d/%Y")

				elif re.search("^([\d]{2}\/[\d]{2}) - [\d]{2}\/[\d]{2}\/([\d]{4})$", sourceDate) is not None:
					eventDate = datetime.datetime.strptime("/".join(re.findall("^([\d]{2}\/[\d]{2}) - [\d]{2}\/[\d]{2}\/([\d]{4})$", sourceDate)[0]), "%m/%d/%Y")
					endDate = datetime.datetime.strptime(re.findall("^[\d]{2}\/[\d]{2} - ([\d]{2}\/[\d]{2}\/[\d]{4})$", sourceDate)[0], "%m/%d/%Y")
			
			elif len(section.select("table")) > 0:
				address = section.get_text(separator="\n").strip()
		
		if len(eventId) > 0 and len(eventName) > 0 and eventDate is not None and len(address) > 0 and re.search("[\s]test[\s,.]", address, re.I | re.DOTALL | re.MULTILINE) is None and (eventDate - datetime.datetime.today()).days < 365:
			cur.execute(sql["TrackSave"], (
				eventId,
				eventName,
				eventDate,
				endDate,
				sourceDate,
				address,
				state["name"],
			))

			cur.execute(sql["TrackIDGet"], (eventId,))
			sqlId = cur.fetchval()

			event = {
				"sqlId": sqlId,
				"trackId": eventId,
				"name": eventName,
				"date": datetime.datetime.strftime(eventDate, "%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z",
				"endDate": datetime.datetime.strftime(endDate, "%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z" if endDate is not None else None,
				"location": address,
				"state": state["name"]
			}
			response = requests.post(f"{ config['millServer'] }/api/trackeventsave", json={ "trackEvent": event })

	print(f"{ currentTime() }: Finished { state['name'] }")

cur.close()
cn.close()

print(f"{ currentTime() }: ----------- End")
