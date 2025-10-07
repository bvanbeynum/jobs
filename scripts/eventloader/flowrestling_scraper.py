import requests
import pyodbc
import datetime
import time
import json
import os

def current_time():
    return datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

def load_sql():
	sql = {}
	sql_path = "/workspaces/jobs/scripts/eventloader/sql/"

	if os.path.exists(sql_path):
		for file in os.listdir(sql_path):
			with open(f"{ sql_path }/{ file }", "r") as file_reader:
				sql[os.path.splitext(file)[0]] = file_reader.read()
	
	return sql

def get_state_from_location(location):
    if location and ',' in location:
        parts = location.split(',')
        if len(parts) > 1:
            state = parts[-1].strip()
            if len(state) == 2:
                return state
    return None

print(f"{current_time()}: Starting FloWrestling scraper.")

with open("/workspaces/jobs/scripts/config.json", "r") as reader:
	config = json.load(reader)

cn = pyodbc.connect(f"DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={ config['database']['server'] };DATABASE={ config['database']['database'] };ENCRYPT=no;UID={ config['database']['user'] };PWD={ config['database']['password'] }", autocommit=True)
cur = cn.cursor()

sql = load_sql()

api_urls = {
    "schedule": "https://api.flowrestling.org/api/experiences/web/schedule/tab/{date}?version=1.33.2&site_id=2&limit=100&offset=0&tz=America/New_York&showFavoriteIcon=true&isNextGenEventHub=true&enableGeoBlock=true&enableMultiday=true",
    "divisions": "https://nextgen.flowrestling.org/api/event-hub/{event_id}/results/filters/divisionName?limit=1000",
    "weightclasses": "https://nextgen.flowrestling.org/api/event-hub/{event_id}/results?tab=weight&filters=[%7B%22id%22:%22divisionName%22,%22type%22:%22string%22,%22value%22:%22{division_name}%22%7D]&offset=0&limit=1000",
    "results": "https://nextgen.flowrestling.org/api/event-hub/{event_id}/results/group?tab=weight&filters=[%7B%22id%22:%22divisionName%22,%22type%22:%22string%22,%22value%22:%22{division_name}%22%7D]&groupFilter=%7B%22id%22:%22weightClassName%22,%22type%22:%22string%22,%22value%22:%22{weight_class_name}%22%7D"
}

today = datetime.date.today()
start_date = today - datetime.timedelta(weeks=2)
end_date = today + datetime.timedelta(weeks=8)

current_date = start_date
while current_date <= end_date:
    date_str = current_date.strftime("%Y-%m-%d")
    url = api_urls["schedule"].format(date=date_str)
    print(f"{current_time()}: Fetching events for {date_str} from {url}")
    response = requests.get(url)
    time.sleep(2)
    if response.status_code == 200:
        events_data = response.json()
        if events_data.get("tabs"):
            for tab in events_data["tabs"]:
                if tab.get("content") and tab["content"].get("data"):
                    for item in tab["content"]["data"]:
                        if item.get("items"):
                            for event_item in item["items"]:
                                if event_item.get("rows"):
                                    for row in event_item["rows"]:
                                        event_name = row["cells"][3]["data"]["text"]
                                        start_date_str = row["cells"][0]["data"]["textParts"]["startDateTime"]
                                        end_date_str = row["cells"][0]["data"]["textParts"]["endDateTime"]
                                        location = row["cells"][4]["data"]["text"]
                                        event_id = row["action"]["url"].split("/")[-1]

                                        cur.execute(sql['FloEventExistsGet'], (event_id))
                                        existing_event = cur.fetchone()

                                        state = get_state_from_location(location)
                                        is_excluded = 1 if state not in ['SC', 'NC', 'GA', 'TN'] else 0

                                        if not existing_event:
                                            print(f"{current_time()}: New event found: {event_name} ({event_id}). Inserting into database.")
                                            cur.execute(sql['EventSave'], (event_id, 'flo', event_name, start_date_str, end_date_str, location, 0, is_excluded, state, None, None))
                                        elif existing_event and not existing_event[0]:
                                            print(f"{current_time()}: Event {event_name} ({event_id}) already exists and is not complete. Updating.")
                                            cur.execute(sql['EventSave'], (event_id, 'flo', event_name, start_date_str, end_date_str, location, 0, is_excluded, state, None, None))
                                        
                                        if start_date_str.endswith('Z'):
                                            start_date_str = start_date_str.replace('Z', '+00:00')
                                        else:
                                            start_date_str = start_date_str[:-2] + ':' + start_date_str[-2:]
                                        start_date_obj = datetime.datetime.fromisoformat(start_date_str)
                                        
                                        if start_date_obj.date() < today:
                                            if existing_event and existing_event[0]:
                                                print(f"{current_time()}: Event {event_name} ({event_id}) already exists and is complete. Skipping.")
                                                continue

                                            print(f"Fetching divisions for past event: {event_name} ({event_id})")
                                            divisions_url = api_urls["divisions"].format(event_id=event_id)
                                            divisions_response = requests.get(divisions_url)
                                            time.sleep(2)
                                            if divisions_response.status_code == 200:
                                                divisions_data = divisions_response.json()
                                                if divisions_data.get("data") and divisions_data["data"].get("options"):
                                                    for division in divisions_data["data"]["options"]:
                                                        division_name = division['label']
                                                        print(f"  Division: {division_name}")
                                                        weightclasses_url = api_urls["weightclasses"].format(event_id=event_id, division_name=division_name)
                                                        weightclasses_response = requests.get(weightclasses_url)
                                                        time.sleep(2)
                                                        if weightclasses_response.status_code == 200:
                                                            weightclasses_data = weightclasses_response.json()
                                                            if weightclasses_data.get("data") and weightclasses_data["data"].get("results"):
                                                                for weight_class in weightclasses_data["data"]["results"]:
                                                                    weight_class_name = weight_class['title']
                                                                    print(f"    Weight Class: {weight_class_name}")
                                                                    results_url = api_urls["results"].format(event_id=event_id, division_name=division_name, weight_class_name=weight_class_name)
                                                                    results_response = None
                                                                    for i in range(3):
                                                                        try:
                                                                            results_response = requests.get(results_url)
                                                                            break
                                                                        except requests.exceptions.ConnectionError as e:
                                                                            print(f"{current_time()}: Connection error fetching results for event {event_id}, division {division_name}, weight class {weight_class_name}. Retrying in {i*2+2} seconds. Error: {e}")
                                                                            time.sleep(i*2+2)
                                                                    
                                                                    if results_response and results_response.status_code == 200:
                                                                        results_data = results_response.json()
                                                                        if results_data.get("data") and results_data["data"].get("results"):
                                                                            for round_data in results_data["data"]["results"]:
                                                                                print(f"      Round: {round_data['title']}")
                                                                                for match in round_data["items"]:
                                                                                    athlete1_name = match['athlete1']['name']
                                                                                    athlete1_team = match['athlete1']['team']['name']
                                                                                    athlete1_winner = match['athlete1']['isWinner']
                                                                                    athlete2_name = match['athlete2']['name']
                                                                                    athlete2_team = match['athlete2']['team']['name']
                                                                                    athlete2_winner = match['athlete2']['isWinner']
                                                                                    win_type = match['winType']
                                                                                    match_round = match.get('round')
                                                                                    match_id = match['id']

                                                                                    cur.execute(sql['WrestlerSave'], (athlete1_name, athlete1_team))
                                                                                    wrestler1_id = cur.fetchone()[0]
                                                                                    cur.execute(sql['WrestlerSave'], (athlete2_name, athlete2_team))
                                                                                    wrestler2_id = cur.fetchone()[0]

                                                                                    cur.execute(sql['MatchSave'], (event_id, division_name, weight_class_name, round_data['title'], win_type, match.get('sort')))
                                                                                    match_db_id = cur.fetchone()[0]

                                                                                    cur.execute(sql['WrestlerMatchSave'], (match_db_id, wrestler1_id, athlete1_winner, athlete1_team, athlete1_name))
                                                                                    cur.execute(sql['WrestlerMatchSave'], (match_db_id, wrestler2_id, athlete2_winner, athlete2_team, athlete2_name))
                                                                    else:
                                                                        print(f"{current_time()}: Error fetching results for event {event_id}, division {division_name}, weight class {weight_class_name}. Status code: {results_response.status_code}")
                                                        else:
                                                            print(f"{current_time()}: Error fetching weight classes for event {event_id}, division {division_name}. Status code: {weightclasses_response.status_code}")
                                            else:
                                                print(f"{current_time()}: Error fetching divisions for event {event_id}. Status code: {divisions_response.status_code}")
                                            cur.execute(sql['EventSave'], (event_id, 'flo', event_name, start_date_str, end_date_str, location, 1, is_excluded, state, None, None))
    else:
        print(f"{current_time()}: Error fetching events for {date_str}. Status code: {response.status_code}")

    current_date += datetime.timedelta(days=1)

print(f"{current_time()}: FloWrestling scraper finished.")
