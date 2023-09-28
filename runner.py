import time
import datetime

startTime = time.time()

import sys
import subprocess
import json
import requests
from dateutil import parser

def currentTime():
	return datetime.datetime.strftime(datetime.datetime.now(), "%Y-%m-%d %H:%M:%S")

def ServiceLoop():
	sleepTime = sleepLong

	while True:

		# Get list of jobs
		response = requests.get(f"{ serverPath }/sys/api/getjobs")
		jobs = json.loads(response.text)["jobs"]

		# Fix dates
		for job in jobs:

			job["created"] = parser.parse(job["created"])
			job["modified"] = parser.parse(job["modified"])

			for run in job["runs"]:
				run["startTime"] = parser.parse(run["startTime"])
				run["completeTime"] = parser.parse(run["completeTime"]) if run["completeTime"] is not None else None

		# Start jobs
		runningIds = [ job["jobId"] for job in runningJobs ]
		for job in jobs:
			if job["status"] == "inactive":
				continue
			
			completeDates = [ run["completeTime"] for run in job["runs"] if run["completeTime"] is not None ] if len(job["runs"]) > 0 else None
			lastRun = None
			if completeDates is not None and len(completeDates) > 0:
				lastRun = max(completeDates)

			if job["id"] not in runningIds and (lastRun is None or datetime.datetime.now(datetime.timezone.utc) > lastRun + datetime.timedelta(seconds=job["frequencySeconds"])):
				print(f"{ currentTime() }: Starting: { job['name'] }")
				
				sleepTime = sleepShort # Shorten the sleep time to get updates

				run = {
					"startTime": datetime.datetime.strftime(datetime.datetime.now(datetime.timezone.utc), "%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z",
					"completeTime": None,
					"messages": []
				}

				response = requests.post(f"{ serverPath }/sys/api/savejobrun?jobid={ job['id'] }", json={ "jobrun": run })
				run = json.loads(response.text)["run"]

				runningJobs.append({
					"jobId": job["id"],
					"jobName": job["name"],
					"run": run,
					"process": subprocess.Popen([sys.executable, f"./scripts/{ job['scriptName'] }"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
					})

		# Update running jobs
		for runIndex, running in enumerate(runningJobs):
			stopJob = False

			if running["process"].poll() is not None:
				stopJob = True
			else:
				response = requests.get(f"{ serverPath }/sys/api/getrun?jobid={ running['jobId'] }&runid={ running['run']['_id'] }")
				run = json.loads(response.text)["run"]

				if run.get("isKill"):
					stopJob = True
					running["process"].kill()
			
			if stopJob:
				
				run = running["run"]
				run["completeTime"] = datetime.datetime.strftime(datetime.datetime.now(datetime.timezone.utc), "%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"

				run["messages"].extend([ { "severity": 0, "message": str.strip(message.decode("utf-8")) } for message in running["process"].stdout.readlines() ])
				run["messages"].extend([ { "severity": 100, "message": str.strip(message.decode("utf-8")) } for message in running["process"].stderr.readlines() ])

				# If there's a message to not log then don't load the messages
				if len([ message for message in run["messages"] if message["message"] == "no log" ]) > 0:
					run["messages"] = []

				response = requests.post(f"{ serverPath }/sys/api/savejobrun?jobid={ running['jobId'] }", json={ "jobrun": run })

				print(f"{ currentTime() }: Completed: { running['jobName'] }")

				runningJobs.pop(runIndex)

				if len(runningJobs) == 0:
					sleepTime = sleepLong

		time.sleep(sleepTime)

print(f"{ currentTime() }: ----------- Setup")

print(f"{ currentTime() }: Load config")

with open("./scripts/config.json", "r") as reader:
	config = json.load(reader)

jobs = []
runningJobs = []
serverPath = config["apiServer"]
sleepShort = config["sleep"]["short"]
sleepLong = config["sleep"]["long"]

print(f"{ currentTime() }: ----------- Service Loop")

ServiceLoop()
