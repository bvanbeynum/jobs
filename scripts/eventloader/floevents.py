import requests
import pyodbc
import datetime
import json
import os
import csv
import smtplib

def logMessage(message):
	logTime = datetime.datetime.strftime(datetime.datetime.now(), "%Y-%m-%d %H:%M:%S")
	print(f"{logTime} - {message}")

def errorLogging(errorMessage):
	logMessage(errorMessage)
	try:
		logPayload = {
			"log": {
				"logTime": datetime.datetime.now().isoformat(),
				"lotTypeId": "691e351ab7de6ab54ed121ae",
				"message": errorMessage
			}
		}
		requests.post(f"{ config['apiServer'] }/sys/api/addlog", json=logPayload)
	except Exception as apiError:
		logMessage(f"Failed to log error to API: {apiError}")

def loadConfig():
	with open("./scripts/config.json", "r") as reader:
		return json.load(reader)

def loadSql():
	sql_dir = "/workspaces/jobs/scripts/eventloader/sql/"
	sql_files = [f for f in os.listdir(sql_dir) if f.endswith('.sql')]
	sql_dict = {}
	for f in sql_files:
		with open(os.path.join(sql_dir, f), 'r') as reader:
			sql_dict[f.replace('.sql', '')] = reader.read()
	return sql_dict

config = loadConfig()
cn = pyodbc.connect(f"DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={ config['database']['server'] };DATABASE={ config['database']['database'] };ENCRYPT=no;UID={ config['database']['user'] };PWD={ config['database']['password'] }", autocommit=True)
cur = cn.cursor()
sql = loadSql()
