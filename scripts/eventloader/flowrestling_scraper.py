import requests
import pyodbc
import datetime
import time
import json
import os

def current_time():
    return datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

def main():
    print(f"{current_time()}: Starting FloWrestling scraper.")

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
                                            print(f"Event: {event_name}, Start: {start_date_str}, End: {end_date_str}, Location: {location}")
        else:
            print(f"{current_time()}: Error fetching events for {date_str}. Status code: {response.status_code}")

        current_date += datetime.timedelta(days=1)

    print(f"{current_time()}: FloWrestling scraper finished.")

if __name__ == "__main__":
    main()