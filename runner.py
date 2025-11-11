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

def errorLogging(message, code):
	logData = {
		"logTime": datetime.datetime.now().isoformat(),
		"logTypeId": "69135c779adfdad032f57fbf",
		"message": f"Runner Error {code}: {message}"
	}
	try:
		requests.post(f"{serverPath}/sys/api/addlog", json=logData)
	except Exception as e:
		print(f"{currentTime()}: Exception in errorLogging: {e}")

def ServiceLoop():
	sleepTime = sleepLong

	while True:

		try:
			# Get list of jobs
			response = requests.get(f"{ serverPath }/sys/api/getjobs")

			if response.status_code != 200:
				errorMessage = f"Error getting jobs. Status code: { response.status_code }. Response: { response.text }"
				print(f"{ currentTime() }: {errorMessage}")
				errorLogging(errorMessage, 550)
				time.sleep(sleepTime)
				continue
		except Exception as e:
			errorMessage = f"Exception getting jobs: { e }"
			print(f"{ currentTime() }: {errorMessage}")
			errorLogging(errorMessage, 551)
			time.sleep(sleepTime)
			continue

		try:
			jobs = json.loads(response.text)["jobs"]
		except Exception as e:
			errorMessage = f"Exception parsing jobs json: { e }"
			print(f"{ currentTime() }: {errorMessage}")
			errorLogging(errorMessage, 552)
			time.sleep(sleepTime)
			continue
			
		jobs = [ job for job in jobs if job["status"] == "active" ]

		# Fix dates
		for job in jobs:
			try:
				job["created"] = parser.parse(job["created"])
				job["modified"] = parser.parse(job["modified"])

				for run in job["runs"]:
					run["startTime"] = parser.parse(run["startTime"])
					run["completeTime"] = parser.parse(run["completeTime"]) if run["completeTime"] is not None else None
			except Exception as e:
				errorMessage = f"Exception parsing dates for job {job.get('id', 'N/A')}: {e}"
				print(f"{currentTime()}: {errorMessage}")
				errorLogging(errorMessage, 553)
				continue

		# Start jobs
		runningIds = [ job["jobId"] for job in runningJobs ]
		for job in jobs:
		
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
				try:
					response = requests.post(f"{ serverPath }/sys/api/savejobrun?jobid={ job['id'] }", json={ "jobrun": run })
					if response.status_code != 200:
						errorMessage = f"Error saving job run for job {job['id']}. Status: {response.status_code}. Response: {response.text}"
						print(f"{currentTime()}: {errorMessage}")
						errorLogging(errorMessage, 554)
						continue
					run = json.loads(response.text)["run"]

					runningJobs.append({
						"jobId": job["id"],
						"jobName": job["name"],
						"run": run,
						"process": subprocess.Popen([sys.executable, f"./scripts/{ job['scriptName'] }"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, encoding="utf-8")
						})
				except Exception as e:
					errorMessage = f"Exception starting job {job.get('id', 'N/A')}: {e}"
					print(f"{currentTime()}: {errorMessage}")
					errorLogging(errorMessage, 555)
					continue

		# Update running jobs
		for runIndex, running in enumerate(runningJobs):
			stopJob = False
			try:
				if running["process"].poll() is not None:
					stopJob = True
				else:
					response = requests.get(f"{ serverPath }/sys/api/getrun?jobid={ running['jobId'] }&runid={ running['run']['_id'] }")
					if response.status_code != 200:
						errorMessage = f"Error getting run for job {running['jobId']}. Status: {response.status_code}. Response: {response.text}"
						print(f"{currentTime()}: {errorMessage}")
						errorLogging(errorMessage, 556)
						continue

					run = json.loads(response.text)["run"]

					if run.get("isKill"):
						stopJob = True
						running["process"].kill()
				
				if stopJob:
					
					run = running["run"]
					run["completeTime"] = datetime.datetime.strftime(datetime.datetime.now(datetime.timezone.utc), "%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"

					# Are there messages
					if running["process"].stdout:
						for line in iter(running["process"].stdout.readline, ""):
							run["messages"].append({ "severity": 0, "message": str.strip(line) })

					if running["process"].stderr:
						for line in iter(running["process"].stderr.readline, ""):
							run["messages"].append({ "severity": 100, "message": str.strip(line) })
					
					# If there's a message to not log then don't load the messages
					if len([ message for message in run["messages"] if message["message"] == "no log" ]) > 0:
						run["messages"] = []

					response = requests.post(f"{ serverPath }/sys/api/savejobrun?jobid={ running['jobId'] }", json={ "jobrun": run })
					if response.status_code != 200:
						errorMessage = f"Error saving job run for job {running['jobId']} after completion. Status: {response.status_code}. Response: {response.text}"
						print(f"{currentTime()}: {errorMessage}")
						errorLogging(errorMessage, 557)
						continue

					print(f"{ currentTime() }: Completed: { running['jobName'] }")

					runningJobs.pop(runIndex)

					if len(runningJobs) == 0:
						sleepTime = sleepLong
			except Exception as e:
				errorMessage = f"Exception updating job {running.get('jobId', 'N/A')}: {e}"
				print(f"{currentTime()}: {errorMessage}")
				errorLogging(errorMessage, 558)
				continue

		time.sleep(sleepTime)

try:
	print(f"{ currentTime() }: ----------- Setup")

	print(f"{ currentTime() }: Load config")

	with open("./scripts/config.json", "r") as reader:
		config = json.load(reader)

	jobs = []
	runningJobs = []
	serverPath = config["apiServer"]
	sleepShort = config["sleep"]["short"]
	sleepLong = config["sleep"]["long"]
except Exception as e:
	print(f"{currentTime()}: Could not load config: {e}")
	exit()

print(f"{ currentTime() }: ----------- Service Loop")

ServiceLoop()