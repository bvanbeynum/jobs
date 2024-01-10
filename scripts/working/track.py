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
from bs4 import BeautifulSoup
import re
import copy
import pyodbc

print(f"{ currentTime() }: ----------- Setup")

print(f"{ currentTime() }: Load config")

with open("./scripts/config.json", "r") as reader:
	config = json.load(reader)

sql = loadSQL("./scripts/sql/track")

trackTIM = ""
trackTWSessionId = ""

requestHeaders = { 
	"User-Agent": config["userAgent"],
	"Host": "www.trackwrestling.com",
	"Accept": "*/*",
	"Connection": "keep-alive"
}
postHeaders = copy.deepcopy(requestHeaders)
postHeaders["Content-Type"] = "application/x-www-form-urlencoded"

states = [
	# { "id": 41, "name": "SC" },
	# { "id": 34, "name": "NC" },
	{ "id": 43, "name": "TN" },
	# { "id": 13, "name": "GA" }
]

print(f"{ currentTime() }: Connect to DB")

cn = pyodbc.connect(f"DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={ config['database']['server'] };DATABASE={ config['database']['database'] };ENCRYPT=no;UID={ config['database']['user'] };PWD={ config['database']['password'] }", autocommit=True)
cur = cn.cursor()

print(f"{ currentTime() }: ----------- Pull Data")

for pageIndex in range(0, 5):

	response = requests.get(f"https://www.trackwrestling.com/Login.jsp?tName=&state={ states[0]['id'] }&tournamentIndex={ pageIndex }&sDate=&eDate=&lastName=&firstName=&teamName=&sfvString=&city=&gbId=&camps=false", headers=requestHeaders)
	soup = BeautifulSoup(response.text, "lxml")

	tournamentUL = soup.find("ul", class_="tournament-ul")
	tournamentsLI = tournamentUL.find_all("li")

	print(f"{ currentTime() }: { len(tournamentsLI )} tournaments found in { states[0]['name'] }")

	for tournamentLI in tournamentsLI:
		eventId = None
		eventDate = None
		endDate = None
		sourceDate = None
		eventType = None
		address = ""

		for section in tournamentLI.find_all("div"):
			if len(section.find_all("span")) > 1:
				linkData = re.findall("eventSelected\(([\d]+),'([^']+)',([\d]),", section.select("a[href^=\"javascript:eventSelected\"]")[0]["href"], re.DOTALL)[0]

				if len(linkData) == 3:
					eventId = linkData[0]
					eventName = linkData[1]
					eventType = int(linkData[2])
				
				sourceDate = [ date.text.strip() for date in section.find_all("span") if re.search("[\d]+/[\d]+/[\d]+", date.text.strip())][0]
				if re.search("^[\d]{2}\/[\d]{2}\/[\d]{4}", sourceDate) is not None:
					eventDate = datetime.datetime.strptime(sourceDate, "%m/%d/%Y")

				elif re.search("^([\d]{2}\/[\d]{2}) - [\d]{2}\/[\d]{2}\/([\d]{4})$", sourceDate) is not None:
					eventDate = datetime.datetime.strptime("/".join(re.findall("^([\d]{2}\/[\d]{2}) - [\d]{2}\/[\d]{2}\/([\d]{4})$", sourceDate)[0]), "%m/%d/%Y")
					endDate = datetime.datetime.strptime(re.findall("^[\d]{2}\/[\d]{2} - ([\d]{2}\/[\d]{2}\/[\d]{4})$", sourceDate)[0], "%m/%d/%Y")
			
			elif len(section.select("a[href^=http\:\/\/maps\.google\.com]")) > 0:
				address = section.get_text(separator="\n").strip()
		
		if eventId is not None and eventDate is not None and eventDate < datetime.datetime.today() and eventType is not None:
			cur.execute(sql["EventGet"], (eventId,))
			isComplete = cur.fetchval()

			if isComplete == 1:
				continue

			print(f"{ currentTime() }: Event { eventName } - { sourceDate }")

			division = None
			updates = []

			session = requests.Session()

			tournamentLink = ""
			if eventType == 1:
				tournamentLink = "predefinedtournaments"
			elif eventType == 2:
				tournamentLink = "opentournaments"
			elif eventType == 3:
				tournamentLink = "teamtournaments"
			elif eventType == 4:
				tournamentLink = "freestyletournaments"
			elif eventType == 5:
				tournamentLink = "seasontournaments"

			cur.execute(sql["EventSave"], (
				eventId,
				tournamentLink,
				eventName,
				eventDate,
				endDate,
				sourceDate,
				address,
				states[0]["name"],
				0
			))
			trackId = cur.fetchval()

			response = session.get(f"https://www.trackwrestling.com/tw/{ tournamentLink }/VerifyPassword.jsp?tournamentId={ eventId }", headers=requestHeaders)
			time.sleep(2)
			
			trackTIM = re.search("TIM=([\d]+)", response.text)[1]
			trackTWSessionId = re.search("twSessionId=([^\"&]+)", response.text)[1]
			
			response = session.get(f"https://www.trackwrestling.com/{ tournamentLink }/MainFrame.jsp?newSession=false&TIM={ trackTIM }&pageName=&twSessionId={ trackTWSessionId }", headers=requestHeaders)
			time.sleep(2)

			response = session.get(f"https://www.trackwrestling.com/{ tournamentLink }/RoundResults.jsp?TIM={ trackTIM }&twSessionId={ trackTWSessionId }", headers=requestHeaders)

			if response.status_code == 404 or re.search("This information is not being released to the public yet", response.text, re.I) is not None:
				cur.execute(sql["EventSave"], (
					eventId,
					tournamentLink,
					eventName,
					eventDate,
					endDate,
					sourceDate,
					address,
					states[0]["name"],
					1
				))
				continue

			time.sleep(2)

			soup = BeautifulSoup(response.text, "lxml")

			for weightHTML in soup.find(id="groupIdBox").descendants:
				if weightHTML.name == "optgroup":
					division = weightHTML["label"]
				
				elif weightHTML.name == "option" and len(weightHTML["value"]) > 0:
					weightClass = weightHTML.string
					weightClassId = weightHTML["value"]
				
					postData = {
						"existingFormatBox": "",
						"displayFormatBox": 1,
						"roundIdBox": "",
						"includeByesBox": "Y",
						"fontSizeBox": 10,
						"patternBox": 1,
						"format": "[boutType] - [wFName] [wLName] ([wTeam]) [winType] [lFName] [lLName] ([lTeam]) [scoreSummary]",
						"groupIdBox": weightClassId
					}

					response = session.post(f"https://www.trackwrestling.com/{ tournamentLink }/RoundResults.jsp?TIM={ trackTIM }&twSessionId={ trackTWSessionId}&displayResult=Y&roundId=&groupId={ weightClassId }", data=postData, headers=postHeaders)
					time.sleep(1)
					soup = BeautifulSoup(response.text, "lxml")

					matches = []
					for section in soup.find_all("section", class_="tw-list"):
						for match in section.find_all("li"):
							if re.search(" bye", match.string, re.I) is None \
								and re.search(" forfeit", match.string, re.I) is None \
								and re.search("[\(]?(dff|ddq)", match.string, re.I) is None \
								and re.search("\(\)", match.string, re.I) is None:

								matches.append({
									"roundName": re.search("^([^-]+)", match.string, re.I)[1].strip(),
									"winType": re.search("over[^)]+\)[ ]*([^$]+)$", match.string, re.I)[1].strip(),
									"winnerWrestler": re.search(" - ([^(]+)\(", match.string, re.I)[1].strip(),
									"winnerTeam": re.search(" - [^(]+\(([^)]+)\)", match.string, re.I)[1].strip(),
									"loserWrestler": re.search("over[ ]*([^(]+)", match.string, re.I)[1].strip(),
									"loserTeam": re.search("over[ ]*[^(]+\(([^)]+)\)", match.string, re.I)[1].strip()
								})

					weightSort = 0

					for match in reversed(matches):
						weightSort += 1

						# Match save
						cur.execute(sql["MatchSave"], (
							trackId,
							division,
							weightClass,
							match["roundName"],
							match["winType"],
							weightSort
						))
						matchId = cur.fetchval()
						
						# Winner save
						cur.execute(sql["WrestlerSave"], (
							match["winnerWrestler"],
							match["winnerTeam"]
						))
						winnerWrestlerId = cur.fetchval()
						
						# Winner Match save
						cur.execute(sql["WrestlerMatchSave"], (
							matchId,
							winnerWrestlerId,
							1,
							match["winnerTeam"]
						))
						
						# Loser save
						cur.execute(sql["WrestlerSave"], (
							match["loserWrestler"],
							match["loserTeam"]
						))
						loserWrestlerId = cur.fetchval()
						
						# Loser Match save
						cur.execute(sql["WrestlerMatchSave"], (
							matchId,
							loserWrestlerId,
							0,
							match["loserTeam"]
						))

			cur.execute(sql["EventSave"], (
				eventId,
				tournamentLink,
				eventName,
				eventDate,
				endDate,
				sourceDate,
				address,
				states[0]["name"],
				1
			))
							
	print(f"{ currentTime() }: Finished { states[0]['name'] }")

print(f"{ currentTime() }: ----------- End")
