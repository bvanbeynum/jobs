## Relevant Files

- `scripts/eventloader/floevents.py` - The new scraper script to be created, replacing `flowrestlingScraper.py`.
- `scripts/eventloader/sql/EventSave.sql` - Used to save or update event information.
- `scripts/eventloader/sql/ExcludedGet.sql` - Used to check if an event should be skipped.
- `scripts/eventloader/sql/WrestlerSave.sql` - Used to save wrestler information and retrieve their IDs.
- `scripts/eventloader/sql/MatchSave.sql` - Used to save match details and retrieve a match ID.
- `scripts/eventloader/sql/WrestlerMatchSave.sql` - Used to associate wrestlers with a specific match.
- `scripts/eventloader/sql/GetNewWrestlers.sql` - Used to retrieve data for the new wrestler email report.
- `scripts/config.json` - Contains database credentials, API keys, and other configurations.
- `scripts/eventloader/newwrestlertemplate.html` - The HTML template for the new wrestler email report.
- `scripts/eventloader/urls.json` - Examples for the URL responses
- `scripts/eventloader/KTownThrowdown.csv` - Example event CSV

### Notes

- The new script, `floevents.py`, will replace the functionality of the outdated `flowrestlingScraper.py`.
- All SQL scripts are pre-existing and should be used as is.
- The script must adhere to the coding standards mentioned in the PRD: tabs for indentation and camelCase for naming.

## Tasks

- [x] 1.0 Setup `floevents.py` script
  - [x] 1.1 Create the file `scripts/eventloader/floevents.py`.
  - [x] 1.2 Add necessary imports: `requests`, `pyodbc`, `datetime`, `json`, `os`, `csv`, and `smtplib`.
  - [x] 1.3 Copy the `logMessage` and `errorLogging` functions from `flowrestlingScraper.py` to the new script for consistent logging.
  - [x] 1.4 Implement a function to load configurations from `scripts/config.json`.
  - [x] 1.5 Establish a `pyodbc` database connection using the loaded credentials.
  - [x] 1.6 Implement a `loadSql` function to read all `.sql` files from `scripts/eventloader/sql/` into a dictionary.
- [x] 2.0 Pre-fetch Excluded Events
  - [x] 2.1 Define the date range for fetching events: from two weeks in the past to eight weeks in the future.
  - [x] 2.2 Execute `ExcludedGet.sql` with the start and end dates of the range to get all excluded or completed events.
  - [x] 2.3 Store the resulting `SystemID`s in a Python list for quick lookups.
- [x] 3.0 Fetch Events from FloWrestling API
  - [x] 3.1 Implement robust error handling for the API request, including status code checks and connection error retries.
  - [x] 3.2 Create a loop to iterate through each of the states (SC, NC, GA, TN).
  - [x] 3.3 Create a loop to iterate through each date in the defined range.
  - [x] 3.4 For each state/date, construct and execute a POST request to the new API endpoint: `https://prod-web-api.flowrestling.org/api/schedule/events`.
  - [x] 3.5 Create the request payload to filter events by state (SC, NC, GA, TN) and date using the following format.

    ```
    {
      "date": "{DATE: 2025-11-14}",
      "query": null,
      "filters": [
        {
          "id": "event-location",
          "type": "string-lazy",
          "value": "29US{STATE}00000000000"
        }
      ],
      "tz": "America/New_York",
      "offset": "0",
      "limit": "100"
    }
    ```

- [x] 4.0 Process and Filter Events
  - [x] 4.1 Parse the JSON response to extract event details: `url`, `name`, `location.venueName`, `location.city`, `location.region` and `status.isCompleted`.
  - [x] 4.2 Parse the `url` to extract the event's id (e.g. `https://www.flowrestling.org/nextgen/events/{eventId}/information`).
  - [x] 4.3 For each event, check if its `id` is in the pre-fetched list of excluded system IDs. If it is, skip the event.
  - [x] 4.4 Extract the state from the event's `location.region` field.
  - [x] 4.5 If the state is not one of the target states (SC, NC, GA, TN), insert the event into the database with `IsExcluded` set to `True` using `EventSave.sql` and skip further processing.
- [x] 5.0 Handle Future Events
  - [x] 5.1 If an event is in the future and within a target state, use `EventSave.sql` to insert it if it's new or update the existing record's `date`, `name`, and `location`.
- [x] 6.0 Process Past Events
  - [x] 6.1 If an event is in the past, check if `status.isCompleted` is `True`. If not, skip it.
  - [x] 6.2 Construct the URL for the CSV report: `https://prod-web-api.flowrestling.org/api/event-hub/{eventId}/results/csv-report`.
  - [x] 6.3 Download the CSV file and parse it using the `csv` module.
- [ ] 7.0 Load Data into Database
  - [ ] 7.1 Iterate through each row of the parsed CSV file.
  - [ ] 7.2 For each match, use `WrestlerSave.sql` to save the winning and losing wrestlers and get their database IDs.
  - [ ] 7.3 Use `MatchSave.sql` to save the match details (division, weight, round, win type) and get the match ID.
  - [ ] 7.4 Use `WrestlerMatchSave.sql` twice to link both wrestlers to the newly created match record.
  - [ ] 7.5 After processing all matches for an event, update the event's record in the database to mark it as completed using `EventSave.sql`.
- [ ] 8.0 Email New Wrestlers Report
  - [ ] 8.1 After the main processing loop is complete, execute `GetNewWrestlers.sql` to identify any new wrestlers added during the run.
  - [ ] 8.2 If new wrestlers are found, read the `newwrestlertemplate.html` file.
  - [ ] 8.3 Populate the HTML template with the new wrestler data.
  - [ ] 8.4 Reuse the email sending logic from `flowrestlingScraper.py` to send the HTML report to the configured notification email address.
- [ ] 9.0 Finalize and Test
  - [ ] 9.1 Conduct a full review of the script to ensure it meets all functional requirements and adheres to the specified coding standards.
  - [ ] 9.2 Add comments to clarify complex sections of the code.
