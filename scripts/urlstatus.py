import time
import datetime

startTime = time.time()

def currentTime():
	return datetime.datetime.strftime(datetime.datetime.now(), "%Y-%m-%d %H:%M")

import requests
import json

print(f"{ currentTime() }: ----------- Setup")

sysBaseURL = "http://beynum.com/sys/api"
success = 0
fail = 0

response = requests.get(f"{sysBaseURL}/geturlstatuslist")
urls = json.loads(response.text)["urlStatusList"]

print(f"{ currentTime() }: { str(len(urls)) } urls")

for url in urls:
	isFail = False
	log = None
	
	try:
		response = requests.get(url["url"])
		response.raise_for_status()  # Raises an HTTPError if the response has an error status code
		success += 1
	except requests.exceptions.HTTPError as exception:
		isFail = True
		log = {
			 "log": {
			 	"logTime": datetime.datetime.strftime(datetime.datetime.now(), "%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z",
				"logTypeId": "640b7d7d15810b471fff65ca",
				"message": f"Failed: { url['name']} ({ url['url'] }) - { exception.response.status_code }: { exception.response.reason }"
			}
		}
		
	except requests.exceptions.ConnectionError as exception:
		isFail = True
		log = {
			 "log": {
			 	"logTime": datetime.datetime.strftime(datetime.datetime.now(), "%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z",
				"logTypeId": "640b7d7d15810b471fff65ca",
				"message": f"Failed: { url['name']} ({ url['url'] }) - Couldn't connect to server" 
			}
		}
	
	except requests.exceptions.Timeout as exception:
		isFail = True
		log = {
			 "log": {
			 	"logTime": datetime.datetime.strftime(datetime.datetime.now(), "%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z",
				"logTypeId": "640b7d7d15810b471fff65ca",
				"message": f"Failed: { url['name']} ({ url['url'] }) - Request timed out" 
			}
		}
	
	except requests.exceptions.RequestException as exception:
		isFail = True
		log = {
			 "log": {
			 	"logTime": datetime.datetime.strftime(datetime.datetime.now(), "%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z",
				"logTypeId": "640b7d7d15810b471fff65ca",
				"message": f"Failed: { url['name']} ({ url['url'] }) - General request error"
			}
		}
	
	except Exception as exception:
		isFail = True
		log = {
			 "log": {
			 	"logTime": datetime.datetime.strftime(datetime.datetime.now(), "%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z",
				"logTypeId": "640b7d7d15810b471fff65ca",
				"message": f"Failed: { url['name']} ({ url['url'] }) - General error"
			}
		}
	
	if isFail:
		response = requests.post(f"{ sysBaseURL }/addlog", json=log)
		fail += 1
	
	print(f"{ currentTime() }: { url['name'] }: { ' failed -' if isFail else 'succeeded -' } { url['url'] }")
		
print(f"{ currentTime() }: { success } succeeded, { fail } failed")

print(f"{ currentTime() }: ----------- Complete")
