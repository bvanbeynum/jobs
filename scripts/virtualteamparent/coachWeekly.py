import os
import sys
import json
import datetime
import requests
import pandas as pd
import sqlalchemy
import premailer
from urllib.parse import quote_plus
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import imaplib
import smtplib
import time

with open("./scripts/config.json", "r") as reader:
	config = json.load(reader)

def logMessage(message):
	logTime = datetime.datetime.strftime(datetime.datetime.now(), "%Y-%m-%d %H:%M:%S")
	print(f"{logTime} - {message}")

def errorLogging(errorMessage):
	logMessage(errorMessage)
	try:
		logPayload = {
			"log": {
				"logTime": datetime.datetime.now().isoformat(),
				"lotTypeId": "69139af80146469461809c36",
				"message": errorMessage
			}
		}
		requests.post(f"{ config['apiServer'] }/sys/api/addlog", json=logPayload)
	except Exception as apiError:
		logMessage(f"Failed to log error to API: {apiError}")

def loadSQL():
	sql = {}
	sqlPath = "./scripts/virtualteamparent/sql"

	if os.path.exists(sqlPath):
		for file in os.listdir(sqlPath):
			with open(f"{ sqlPath }/{ file }", "r") as fileReader:
				sql[os.path.splitext(file)[0]] = fileReader.read()
	
	return sql

logMessage(f"------------- Setup")

sql = loadSQL()
dataDate = "12/8/2024"

logMessage(f"Connecting to DB")

try:
	db = sqlalchemy.create_engine(f"mssql+pyodbc://{config['database']['user']}:{config['database']['password']}@{config['database']['server']}/{config['database']['database']}?driver={quote_plus("ODBC Driver 18 for SQL Server")}&encrypt=no", isolation_level="AUTOCOMMIT")
	
	cn = db.connect()
except Exception as error:
	errorMessage = f"Error connecting to database: {error}"
	errorLogging(errorMessage)
	sys.exit(1)

try:
	logMessage(f"------------- Load Data")

	logMessage(f"Creating temp tables")

	cn.execute(sqlalchemy.text(sql["coachWeekly_CreateTemp"]))
	params = { "loadDate": dataDate }
	cn.execute(sqlalchemy.text(sql["coachWeekly_LoadTemp"]), params)

	logMessage(f"Toughest Tournaments")
	toughTournamentDF = pd.read_sql_query(sqlalchemy.text(sql["coachWeekly_ToughTournament"]), cn)
	
	logMessage(f"Rivalry Tournaments")
	rivalryDF = pd.read_sql_query(sqlalchemy.text(sql["coachWeekly_Rivalry"]), cn)
	
	logMessage(f"Showdown Matches")
	showdownsDF = pd.read_sql_query(sqlalchemy.text(sql["coachWeekly_Showdowns"]), cn)
	
	logMessage(f"Upset Matches")
	upsetDF = pd.read_sql_query(sqlalchemy.text(sql["coachWeekly_Upsets"]), cn)
	
	logMessage(f"Weight Class Heat Map")
	heatMapDF = pd.read_sql_query(sqlalchemy.text(sql["coachWeekly_HeatMap"]), cn)
	
	logMessage(f"Ironman")
	ironmanDF = pd.read_sql_query(sqlalchemy.text(sql["coachWeekly_Ironman"]), cn)
	
	logMessage(f"Bonus Points")
	bonusDF = pd.read_sql_query(sqlalchemy.text(sql["coachWeekly_Bonus"]), cn)

	logMessage(f"Forged in Fire")
	forgedDF = pd.read_sql_query(sqlalchemy.text(sql["coachWeekly_ForgedFire"]), cn)

	logMessage(f"Grinder")
	grinderDF = pd.read_sql_query(sqlalchemy.text(sql["coachWeekly_Grinder"]), cn)

	logMessage(f"Breakout Wrestler")
	breakoutDF = pd.read_sql_query(sqlalchemy.text(sql["coachWeekly_Breakout"]), cn)

except Exception as error:
	errorMessage = f"Error loading data: {error}"
	errorLogging(errorMessage)
	sys.exit(1)

finally:
	cn.close()

logMessage(f"------------- Send Email")

try:
	logMessage(f"AI Email Generation")
	
	with open("./scripts/virtualteamparent/coachWeekly.css", "r") as reader:
		templateCSS = reader.read()

	url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={config['geminiAPIKey']}"

	prompt = f"""
You are an analyst for the coach of the fort mill high school wrestling team, the Fort Mill Yellow Jackets. Your task is to analyze the results from the past week and provide insights for the coach using the data provided.

Here are your instructions:
- Create a well formatted email using HTML.
- The entire response should be a single HTML document.
- In the HTML <head>, you must include a <style> tag and copy the contents of the **Email CSS** section into it. This is critical for correct formatting.
- The HTML should be responsive for both mobile or desktop viewing. Use divs around tables to allow horizontal scrolling.
- Create a section for each dataset.
- For the Rivalry Tournaments, add the class `region-header` to the `<thead>` tag of the table.
- For the Heat Map, apply color coding to the cells based on the values (green for easy, red for tough).
- Each section should build on each other.
- Provide commentary for each section with highlights, callouts, and insights.
- Make it fun by adding emoji
- Conclude with support for the Yellow Jackets and don't sign your name.
- Don't include a subject.

---
** Email CSS **

{templateCSS}

---
** Team Insights **
---
Rivalry Watch
{rivalryDF.to_html(index=False, classes="table")}
---	
Toughest Tournaments
{toughTournamentDF.to_html(index=False, classes="table")}
---
Showdown Matches
{showdownsDF.to_html(index=False, classes="table")}
---
Upset Matches
{upsetDF.to_html(index=False, classes="table")}
---
Weight Class Heat Map
{heatMapDF.to_html(index=False, classes="table")}
---
Breakout Wrestler
{breakoutDF.to_html(index=False, classes="table")}
---
Bonus Points
{bonusDF.to_html(index=False, classes="table")}
---
Forged in Fire
{forgedDF.to_html(index=False, classes="table")}
---
Grinder
{grinderDF.to_html(index=False, classes="table")}
---
Ironman
{ironmanDF.to_html(index=False, classes="table")}
---
"""

	requestBody = {"contents": [{"parts": [{"text": prompt}]}]}
	response = requests.post(url, json=requestBody, headers={"Content-Type": "application/json"})

	if response.status_code == 200:
		geminiResponse = response.json()['candidates'][0]['content']['parts'][0]['text']
	else:
		raise Exception(f"Error calling Gemini API. Status: {response.status_code}. Response: {response.text}")

except Exception as error:
	errorMessage = f"Error during AI generation: {error}"
	errorLogging(errorMessage)
	sys.exit(1)


try:
	logMessage(f"Inlining CSS")
	inlinedHtml = premailer.transform(geminiResponse)

	logMessage(f"Sending Email")

	mimeMessage = MIMEMultipart()
	mimeMessage['To'] = f'"Brett van Beynum" <maildrop444@gmail.com>'
	mimeMessage['Subject'] = f"Weekly Email Analysis - {dataDate}"
	mimeMessage.attach(MIMEText(inlinedHtml, 'html'))

	with smtplib.SMTP_SSL('smtp.gmail.com', 465) as smtp:
		smtp.login("wrestlingfortmill@gmail.com", config['googleAppPassword'])
		smtp.send_message(mimeMessage)

except Exception as error:
	errorMessage = f"Error sending email: {error}"
	errorLogging(errorMessage)
	sys.exit(1)


logMessage(f"------------- Complete")