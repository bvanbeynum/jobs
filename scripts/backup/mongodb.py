import subprocess
import datetime
import os
import sys
import requests
import json

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




# *************************** Script Start ***************************


logMessage(f"--------------- Starting Backup Process")

with open("./scripts/config.json", "r") as reader:
	config = json.load(reader)

# Local Network Config (Raspberry Pi)
backupServer = "10.21.0.130"
backupUser = "bvanbeynum"
backupFolder = "~/prod/data/backup"

# Local Jobs Box Config
localTemp = "/tmp" # Where to store the dump temporarily on 110
today = datetime.date.today().strftime("%Y-%m-%d")

# ---------------------

for databaseName in config["mongo"]["backupDBs"]:

	# 1. Generate Filename based on today's date
	filename = f"{databaseName}_backup_{today}.dump"
	localFilepath = os.path.join(localTemp, filename)

	logMessage(f"Starting backup for {filename}")

	# 2. Construct the Docker Mongodump command
	# We use --archive to output a single file instead of a directory
	# We use --gzip to compress the 900MB data down significantly
	mongoUri = f"mongodb://{config['mongo']['user']}:{config['mongo']['pass']}@{config['mongo']['server']}/{databaseName}?authSource={config['mongo']['authDB']}"

	dumpCommand = [
		"mongodump",
		f"--uri={mongoUri}",
		f"--archive={localFilepath}",
		"--gzip"
	]

	try:
		logMessage("--> Dumping data from Cloud (this may take a moment)...")
		subprocess.run(dumpCommand, check=True)
		logMessage("--> Dump successful.")
	except subprocess.CalledProcessError as e:
		errorLogging(f"Error dumping data: {e}")
		sys.exit(1)

	# 3. SCP the file to the Raspberry Pi (130)
	containerKeyPath = "/home/appuser/.ssh/id_rsa"
	scpCommand = [
		"scp",
		"-o", "StrictHostKeyChecking=no",
		"-o", "UserKnownHostsFile=/dev/null",
		"-P",
		"9501",
		"-i",
		containerKeyPath,
		localFilepath,
		f"{backupUser}@{backupServer}:{backupFolder}/{filename}"
	]

	try:
		logMessage(f"Transferring file to {backupServer}...")
		subprocess.run(scpCommand, check=True)
		logMessage(f"Transfer successful.")
	except subprocess.CalledProcessError as error:
		errorLogging(f"Error transferring file: {error}")
		sys.exit(1)

	# 4. Clean up local temp file on Jobs Box
	try:
		os.remove(localFilepath)
		logMessage("--> Local temp file cleaned up.")
	except OSError as error:
		errorLogging(f"Error deleting temp file: {error}")

	logMessage(f"Backup is at {backupServer}:{backupFolder}/{filename}")

logMessage(f"--------------- Backup Process Complete")
