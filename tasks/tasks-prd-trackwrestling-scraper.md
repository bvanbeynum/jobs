## Relevant Files

- `scripts/eventloader/track_event.py` - The primary script for scraping data from Trackwrestling.
- `scripts/eventloader/tests/test_track_event.py` - Unit tests for the scraper script.
- `scripts/config.json` - Contains database connection details and other configuration.
- `scripts/eventloader/track_scraper.log` - Log file for the scraper's output.

### Notes

- The script's structure and style should follow `scripts/eventloader/flo.py`.
- The script must be executable in a headless environment on an Ubuntu server.
- Database credentials and other sensitive data should be managed via `scripts/config.json` and not be hardcoded.

## Tasks

- [ ] 1.0 Project Setup & Configuration
  - [ ] 1.1 Create the main script file `scripts/eventloader/track_event.py`.
  - [ ] 1.2 Add required Python packages (`requests`, `BeautifulSoup`, `selenium`, `pyodbc`) to `requirements.txt`.
  - [ ] 1.3 Implement logging configuration to output to both the console and `scripts/eventloader/track_scraper.log`.
- [ ] 2.0 Core Scraping Logic
  - [ ] 2.1 Initialize a headless Selenium WebDriver (Chromium) that can run on Ubuntu.
  - [ ] 2.2 Navigate to the search page: `https://www.trackwrestling.com/Login.jsp`.
  - [ ] 2.3 Implement a function to search for events by state (SC, NC, GA, TN).
  - [ ] 2.4 Parse the search results page to extract links to individual event pages.
  - [ ] 2.5 Implement logic to handle pagination in search results, if present.
- [ ] 3.0 Event Data Extraction
  - [ ] 3.1 For each event link, navigate to the event's page.
  - [ ] 3.2 Determine if the event is in the past (completed) or in the future.
  - [ ] 3.3 If the event is in the future, scrape the Event Name, Start Date, End Date, and Location.
  - [ ] 3.4 If the event is in the past (within 1 year), scrape the final results, including: Match (Division, Weight Class, Round, Win Type) and the Winner's Name.
- [ ] 4.0 Database Interaction
  - [ ] 4.1 Implement a function to securely read database connection info from `scripts/config.json`.
  - [ ] 4.2 Create a function to check if an event already exists in the `Event` table by its Trackwrestling ID to prevent duplicates.
  - [ ] 4.3 Implement a function to save a new event's data to the `Event` table.
  - [ ] 4.4 Implement functions to save match and wrestler data into the `EventMatch`, `EventWrestler`, and `EventWrestlerMatch` tables.
- [ ] 5.0 Finalization & Testing
  - [ ] 5.1 Create unit tests in `scripts/eventloader/tests/test_track_event.py` for key functions (e.g., database connection, data parsing).
  - [ ] 5.2 Add robust error handling for network issues, missing data, and database errors.
  - [ ] 5.3 Conduct a full end-to-end test run to verify the script scrapes data and populates the database correctly.
  - [ ] 5.4 Ensure all code is commented where necessary and follows the style of `scripts/eventloader/flo.py`.
