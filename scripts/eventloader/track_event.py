import logging
import sys

# Setup logging
log_formatter = logging.Formatter("%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Console handler
stream_handler = logging.StreamHandler(sys.stdout)
stream_handler.setFormatter(log_formatter)
logger.addHandler(stream_handler)

# File handler
file_handler = logging.FileHandler("scripts/eventloader/track_scraper.log")
file_handler.setFormatter(log_formatter)
logger.addHandler(file_handler)

logger.info("Logging setup complete.")

import json
import os
import pyodbc

def load_config():
	config_path = "./scripts/config.json"
	if not os.path.exists(config_path):
		logger.error(f"Config file not found at {config_path}")
		return None
	with open(config_path, "r") as reader:
		config = json.load(reader)
	logger.info("Configuration loaded successfully.")
	return config

# Load config at the beginning of the script
config = load_config()
if not config:
	logger.error("Failed to load configuration. Exiting.")
	exit()

# DB connect
try:
	cn = pyodbc.connect(f"DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={config['database']['server']};DATABASE={config['database']['database']};ENCRYPT=no;UID={config['database']['user']};PWD={config['database']['password']}", autocommit=True)
	cur = cn.cursor()
	logger.info("Database connection established.")
except Exception as e:
	logger.error(f"Error connecting to database: {e}")
	exit()

# Function to load SQL queries (from flo.py)
def load_sql_queries():
	sql_queries = {}
	sql_path = "./scripts/eventloader/sql"
	if os.path.exists(sql_path):
		for file in os.listdir(sql_path):
			with open(f"{sql_path}/{file}", "r") as file_reader:
				sql_queries[os.path.splitext(file)[0]] = file_reader.read()
	return sql_queries

sql_queries = load_sql_queries()

from selenium import webdriver
from selenium.webdriver.chrome.service import Service as ChromeService
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import Select # Import Select class
from bs4 import BeautifulSoup
import re
from datetime import datetime
from urllib.parse import urlparse, parse_qs

# Setup headless Chrome options
chrome_options = Options()
chrome_options.add_argument("--headless")
chrome_options.add_argument("--no-sandbox")
chrome_options.add_argument("--disable-dev-shm-usage")
chrome_options.binary_location = "/usr/bin/chromium" # Specify Chromium binary location

# Initialize WebDriver
try:
	service = ChromeService("/usr/bin/chromedriver") # Path to chromium-driver
	driver = webdriver.Chrome(service=service, options=chrome_options)
	logger.info("Selenium WebDriver initialized successfully.")
except Exception as e:
	logger.error(f"Error initializing Selenium WebDriver: {e}")
	# Exit or handle the error appropriately
	exit()

# Navigate to the search page
search_url = "https://www.trackwrestling.com/Login.jsp"
logger.info(f"Navigating to {search_url}")
driver.get(search_url)

def search_events_by_state(driver, state):
	logger.info(f"Searching for events in state: {state}")
	try:
		# Click the "Search Events" button to open the search modal
		search_events_button = WebDriverWait(driver, 10).until(
			EC.element_to_be_clickable((By.ID, "eventSearchButton"))
		)
		search_events_button.click()
		logger.info("Clicked 'Search Events' button.")

		# Select the state from the dropdown
		state_select_element = WebDriverWait(driver, 10).until(
			EC.presence_of_element_located((By.ID, "stateBox"))
		)
		state_select = Select(state_select_element)
		state_select.select_by_visible_text(state) # Select by visible text, e.g., "South Carolina"
		logger.info(f"Selected state: {state}")

		# Click the search button within the modal
		search_button = WebDriverWait(driver, 10).until(
			EC.element_to_be_clickable((By.XPATH, "//div[@id='searchEventsFrame']//input[@value='Search']"))
		)
		search_button.click()
		logger.info(f"Search initiated for state: {state}")

		# Wait for the results to load (assuming results are displayed on the same page or a new section)
		# For now, let's wait for a common element on the results page, e.g., the tournament list
		WebDriverWait(driver, 10).until(
			EC.presence_of_element_located((By.CLASS_NAME, "tournament-ul"))
		)
		logger.info("Search results loaded.")
		return True
	except Exception as e:
		logger.error(f"Error searching for events in state {state}: {e}")
		return False

def parse_search_results(driver):
	logger.info("Parsing search results.")
	events = []
	try:
		page_source = driver.page_source
		soup = BeautifulSoup(page_source, 'html.parser')
		
		tournament_list = soup.find('ul', class_='tournament-ul')
		if tournament_list:
			for li in tournament_list.find_all('li'):
				location = "N/A"
				# Find the div containing the location information.
				# It's usually identifiable by a link to Google Maps.
				map_link = li.find('a', href=re.compile(r'maps.google.com|google.com/maps'))
				if map_link:
					# The location text is in the parent div of the map link.
					location_container = map_link.find_parent('div')
					if location_container:
						location = location_container.get_text(separator=' ', strip=True)

				href = li.find('a', id=re.compile(r'anchor_\d+'))
				if href and 'href' in href.attrs:
					href_val = href['href']
					# Corrected regex to capture eId, event_name, and event_type
					match = re.search(r'eventSelected\((\d+),\s*\'([^\']*)\'',href_val)
					if match:
						eId = match.group(1)
						event_name = match.group(2)
						# event_type = match.group(3) # This group is not captured in the provided regex
						
						# Extract date from the list item's text
						li_text = li.get_text()
						date_str = "N/A"
						date_match = re.search(r'(\d{1,2}/\d{1,2}/\d{4}(\s*-\s*\d{1,2}/\d{1,2}/\d{4})?)', li_text)
						if date_match:
							date_str = date_match.group(1).strip()

						events.append({"eId": eId, "event_name": event_name, "event_type": "N/A", "location": location, "event_date": date_str})
		logger.info(f"Found {len(events)} events in search results.")
	except Exception as e:
		logger.error(f"Error parsing search results: {e}")
	return events

def navigate_next_page(driver):
	logger.info("Attempting to navigate to the next page.")
	try:
		next_button = WebDriverWait(driver, 10).until(
			EC.element_to_be_clickable((By.XPATH, "//a[contains(@href, 'javascript:nextTournaments()')]" ))
		)
		next_button.click()
		logger.info("Navigated to the next page.")
		return True
	except Exception as e:
		logger.info(f"No more pages or error navigating to next page: {e}")
		return False

def navigate_to_event_page(driver, eId, event_type):
	logger.info(f"Navigating to event page for eId: {eId}, event_type: {event_type}")
	event_type_map = {
		"1": "predefinedtournaments",
		"2": "opentournaments",
		"3": "teamtournaments",
		"4": "freestyletournaments",
		"5": "seasontournaments"
	}
	
	event_type_str = event_type_map.get(str(event_type), "predefinedtournaments")

	verify_url = f"https://www.trackwrestling.com/tw/{event_type_str}/VerifyPassword.jsp?tournamentId={eId}"
	logger.info(f"Navigating to verify URL: {verify_url}")
	driver.get(verify_url)

	try:
		WebDriverWait(driver, 20).until(
			EC.url_contains("MainFrame.jsp")
		)
		current_url = driver.current_url
		page_source = driver.page_source
		logger.info(f"Redirected to: {current_url}")

		tim_match = re.search(r'TIM=(\d+)', current_url)
		tim = tim_match.group(1) if tim_match else None

		tw_session_id_match = re.search(r'twMenuSessionId\s*=\s*"([^"]+)"', page_source)
		twSessionId = tw_session_id_match.group(1) if tw_session_id_match else None

		if not twSessionId:
			tw_session_id_match_url = re.search(r'twSessionId=([^&]+)', current_url)
			twSessionId = tw_session_id_match_url.group(1) if tw_session_id_match_url else None

		if tim and twSessionId:
			logger.info(f"Extracted TIM: {tim}, twSessionId: {twSessionId}")
			return tim, twSessionId
		else:
			logger.error(f"Could not extract TIM or twSessionId. TIM from URL: {tim}, twSessionId from body/URL: {twSessionId}")
			return None, None
	except Exception as e:
		logger.error(f"Error navigating to event main page or extracting session IDs: {e}")
		return None, None

def scrape_match_results(driver, event_type, tim, twSessionId):
	logger.info(f"Scraping match results for event TIM: {tim}, twSessionId: {twSessionId}")
	matches = []
	event_type_map = {
		"1": "predefinedtournaments",
		"2": "opentournaments",
		"3": "teamtournaments",
		"4": "freestyletournaments",
		"5": "seasontournaments"
	}
	event_type_str = event_type_map.get(str(event_type), "predefinedtournaments")

	round_results_url = f"https://www.trackwrestling.com/tw/{event_type_str}/RoundResults.jsp?TIM={tim}&twSessionId={twSessionId}"
	logger.info(f"Navigating to RoundResults URL: {round_results_url}")
	driver.get(round_results_url)

	try:
		WebDriverWait(driver, 10).until(EC.presence_of_element_located((By.ID, "theForm")))
		page_source = driver.page_source
		soup = BeautifulSoup(page_source, 'html.parser')

		if soup.find('div', class_='message', string='This information is not being released to the public yet.'):
			logger.info("Match results are not public for this event.")
			return matches

		weight_class_select_element = driver.find_element(By.ID, "groupIdBox")
		weight_class_select = Select(weight_class_select_element)
		weight_classes = [option for option in weight_class_select.options if option.get_attribute("value") != "0"]
		weight_class_data = [(option.get_attribute("value"), option.text) for option in weight_classes if option.get_attribute("value") is not None and len(option.get_attribute("value")) > 0]

		for weightIndex, (weight_class_value, weight_class_text) in enumerate(weight_class_data):
			logger.info(f"Scraping results for weight class: {weight_class_text}")

			if weightIndex > 0:
				# Click the 'Filter' button to make the filter boxes appear
				driver.find_element(By.XPATH, "//input[@value='Filter']").click()
				WebDriverWait(driver, 10).until(EC.presence_of_element_located((By.ID, "fontSizeBox")))

			weight_class_select = Select(driver.find_element(By.ID, "groupIdBox"))
			weight_class_select.select_by_value(weight_class_value)
			
			# Click the 'Go' button to load the results for the selected weight class
			driver.find_element(By.XPATH, "//input[@value='Go']").click()

			# Wait for either results or the "no results" message
			try:
				wait_condition = EC.presence_of_element_located(
					(By.XPATH, "//section[@class='tw-list'] | //center[contains(text(), 'No results are available for this round')]" )
				)
				element = WebDriverWait(driver, 10).until(wait_condition)

				if element.tag_name == 'center':
					logger.info(f"No results for weight class: {weight_class_text}")
					continue
			except:
				logger.info(f"No results for weight class: {weight_class_text}")
				continue

			# If we are here, it means results are present.
			results_page_source = driver.page_source
			results_soup = BeautifulSoup(results_page_source, 'html.parser')

			if " " in weight_class_text:
				division, weight_class = weight_class_text.split(" ", 1)
			else:
				division = "High School"
				weight_class = weight_class_text

			sections = results_soup.find_all('section', class_='tw-list')
			for section in sections:
				round_name_h1 = section.find('h1')
				if not round_name_h1:
					continue

				match_list = section.find('ul')
				if not match_list:
					continue
				
				for li in match_list.find_all('li'):
					if re.search(" bye", li.string, re.I) is None \
						and re.search(" forfeit", li.string, re.I) is None \
						and re.search("[\(]?(dff|ddq)", li.string, re.I) is None \
						and re.search("\(\)", li.string, re.I) is None:

						sub_round = re.search("^([^-]+)", li.string, re.I)[1].strip()
						wrestler1_name = re.search(" - ([^(]+)\( " , li.string, re.I)[1].strip()
						wrestler1_team = re.search(" - [^(]+\(([^)]+)\)", li.string, re.I)[1].strip()
						win_type = re.search(" over[^)]+[\)]+[ ]+([^$]+)$", li.string, re.I)[1].strip()
						wrestler2_name = re.search(" over[ ]+([^(]+)\( " , li.string, re.I)[1].strip()
						wrestler2_team = re.search(" over[ ]+[^(]+\(([^)]+)\)", li.string, re.I)[1].strip()
						winner_name = wrestler1_name

						matches.append({
							"division": division,
							"weight_class": weight_class,
							"round": sub_round,
							"win_type": win_type,
							"winner_name": winner_name,
							"wrestler1_name": wrestler1_name,
							"wrestler1_team": wrestler1_team,
							"wrestler2_name": wrestler2_name,
							"wrestler2_team": wrestler2_team
						})

		logger.info(f"Scraped {len(matches)} matches across all weight classes.")

	except Exception as e:
		logger.error(f"Error scraping match results: {e}")
	
	return matches

def check_event_exists(system_id):
	logger.info(f"Checking if event with SystemID {system_id} exists.")
	try:
		cur.execute(sql_queries["EventGet"], system_id)
		result = cur.fetchone()
		if result:
			event_id, is_complete = result
			logger.info(f"Event {system_id} found. ID: {event_id}, IsComplete: {is_complete}")
			return {"id": event_id, "is_complete": is_complete}
		else:
			logger.info(f"Event {system_id} not found.")
			return None
	except Exception as e:
		logger.error(f"Error checking event existence for SystemID {system_id}: {e}")
		return None

def save_event(event_data, is_complete=False):
	logger.info(f"Saving event: {event_data['event_name']}")
	try:
		params = (
			"Track",
			event_data["eId"],
			event_data.get("event_type_str", ""),
			event_data["event_name"],
			event_data.get("start_date"),
			event_data.get("end_date"),
			event_data.get("location", ""),
			event_data.get("state", ""),
			1 if is_complete else 0,
			0
		)
		cur.execute(sql_queries["EventSave"], params)
		event_id = cur.fetchone()[0]
		logger.info(f"Event {event_data['event_name']} saved with ID: {event_id}")
		return event_id
	except Exception as e:
		logger.error(f"Error saving event {event_data['event_name']}: {e}")
		return None

def save_wrestler(wrestler_name, team_name):
	logger.info(f"Saving wrestler: {wrestler_name} ({team_name})")
	try:
		cur.execute(sql_queries["WrestlerSave"], (wrestler_name, team_name))
		wrestler_id = cur.fetchone()[0]
		logger.info(f"Wrestler {wrestler_name} saved with ID: {wrestler_id}")
		return wrestler_id
	except Exception as e:
		logger.error(f"Error saving wrestler {wrestler_name}: {e}")
		return None

def save_match(event_id, match_data):
	logger.info(f"Saving match for EventID {event_id}: {match_data['division']} - {match_data['weight_class']}")
	try:
		params = (
			event_id,
			match_data["division"],
			match_data["weight_class"],
			match_data["round"],
			match_data["win_type"],
			0
		)
		cur.execute(sql_queries["MatchSave"], params)
		match_id = cur.fetchone()[0]
		logger.info(f"Match saved with ID: {match_id}")
		return match_id
	except Exception as e:
		logger.error(f"Error saving match for EventID {event_id}: {e}")
		return None

def save_wrestler_match(match_id, wrestler_id, is_winner, team, wrestler_name):
	logger.info(f"Saving wrestler match: MatchID {match_id}, WrestlerID {wrestler_id}, Winner: {is_winner}")
	try:
		params = (
			match_id,
			wrestler_id,
			1 if is_winner else 0,
			team,
			wrestler_name
		)
		cur.execute(sql_queries["WrestlerMatchSave"], params)
		wrestler_match_id = cur.fetchone()[0]
		logger.info(f"WrestlerMatch saved with ID: {wrestler_match_id}")
		return wrestler_match_id
	except Exception as e:
		logger.error(f"Error saving wrestler match for MatchID {match_id}, WrestlerID {wrestler_id}: {e}")
		return None

all_events = []
states_to_search = ["South Carolina", "North Carolina", "Georgia", "Tennessee"]
state_map = {
	"South Carolina": "SC",
	"North Carolina": "NC",
	"Georgia": "GA",
	"Tennessee": "TN"
}

for state in states_to_search:
	if search_events_by_state(driver, state):
		page_count = 0
		while page_count < 10:
			page_count += 1
			events_on_page = parse_search_results(driver)
			search_results_url = driver.current_url # Save the search results URL
			
			for event in events_on_page:
				existing_event = check_event_exists(event["eId"])
				if existing_event and existing_event["is_complete"] == 1:
					logger.info(f"Event {event['event_name']} (ID: {event['eId']}) already exists and is complete. Skipping.")
					continue

				event_date_str = event.get("event_date", "N/A")
				start_date = None
				end_date = None
				is_past = False

				if event_date_str != "N/A":
					try:
						if "-" in event_date_str:
							start_date_str, end_date_str = [d.strip() for d in event_date_str.split("-")]
						else:
							start_date_str = end_date_str = event_date_str
						
						start_date = datetime.strptime(start_date_str, "%m/%d/%Y")
						end_date = datetime.strptime(end_date_str, "%m/%d/%Y")
						
						event["start_date"] = start_date.strftime("%Y-%m-%d")
						event["end_date"] = end_date.strftime("%Y-%m-%d")
					
						if end_date.date() < datetime.now().date():
							is_past = True
							event['status'] = 'past'
						else:
							event['status'] = 'future'
					except ValueError:
						logger.error(f"Error parsing event date: {event_date_str}")
						event["start_date"] = None
						event["end_date"] = None
						event['status'] = 'unknown'
				
				event_type_map = {
					"1": "predefinedtournaments",
					"2": "opentournaments",
					"3": "teamtournaments",
					"4": "freestyletournaments",
					"5": "seasontournaments"
				}
				event["event_type_str"] = event_type_map.get(str(event["event_type"] ), "predefinedtournaments")
				event["state"] = state_map.get(state)

				event_id = save_event(event, is_complete=False)

				if event_id and is_past:
					logger.info(f"Event {event['event_name']} is in the past, scraping matches.")
					tim, twSessionId = navigate_to_event_page(driver, event["eId"], event["event_type"])

					if tim and twSessionId:
						event['matches'] = scrape_match_results(driver, event["event_type"], tim, twSessionId)
						matches_scraped = len(event.get('matches', [])) > 0
						logger.info(f"Scraped {len(event.get('matches', []))} matches for past event {event['event_name']}")
						
						for match_data in event['matches']:
							match_id = save_match(event_id, match_data)
						
							wrestler1_id = save_wrestler(match_data.get("wrestler1_name", ""), match_data.get("wrestler1_team", ""))
							wrestler2_id = save_wrestler(match_data.get("wrestler2_name", ""), match_data.get("wrestler2_team", ""))

							if wrestler1_id:
								is_winner = match_data.get("winner_name") == match_data.get("wrestler1_name")
								save_wrestler_match(match_id, wrestler1_id, is_winner, match_data.get("wrestler1_team", ""), match_data.get("wrestler1_name", ""))
						
							if wrestler2_id:
								is_winner = match_data.get("winner_name") == match_data.get("wrestler2_name")
								save_wrestler_match(match_id, wrestler2_id, is_winner, match_data.get("wrestler2_team", ""), match_data.get("wrestler2_name", ""))
										
						if matches_scraped:
							logger.info(f"Marking event {event['event_name']} as complete.")
							save_event(event, is_complete=True)
					
					else:
						logger.info(f"Can't access event. Marking event {event['event_name']} as complete.")
						save_event(event, is_complete=True)
						
					# After scraping, navigate back to the search results page
					logger.info("Navigating back to search. results page.")
					driver.get(search_results_url)

				all_events.append(event)
			
			if not navigate_next_page(driver):
				break
	
	logger.info(f"Finished scraping events for {state}. Navigating back to search page.")
	driver.get(search_url)

logger.info(f"Total events found across all states: {len(all_events)}")
logger.info("Closing WebDriver.")
driver.quit()
