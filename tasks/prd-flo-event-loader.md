# Product Requirements Document: Flo Event Loader

## 1. Introduction/Overview

This document outlines the requirements for creating a new Python scraper, `floevents.py`, to replace the existing `flowrestlingScraper.py`. The purpose of this project is to adapt to recent changes in the FloWrestling website's structure and API, ensuring that event and match data for wrestling events in SC, NC, GA, and TN can continue to be collected and stored in the database. The new scraper will fetch event information, download a CSV report for each event, process the data, and load it into the database using existing SQL scripts.

## 2. Goals

*   Develop a Python script that successfully scrapes event and match data from the new FloWrestling API endpoints.
*   Ensure the scraped data is correctly parsed and loaded into the existing SQL Server database.
*   Maintain the existing functionality of the previous scraper, including logging and email notifications for new wrestlers.
*   The script should be robust and handle potential errors gracefully.

## 3. User Stories

*   As a system administrator, I want the script to automatically fetch all relevant wrestling events from FloWrestling for a predefined date range so that the database is always up-to-date.
*   As a system administrator, I want the script to download and process match results from a CSV file for each event so that detailed match data is captured.
*   As a system administrator, I want the script to log its progress and any errors encountered so that I can monitor its execution and troubleshoot issues.
*   As a system administrator, I want to receive an email notification listing newly identified wrestlers so that I can perform data validation and deduplication.

## 4. Functional Requirements

1.  The script must iterate through a range of dates, from two weeks in the past to eight weeks in the future.
2.  For each date, the script must make a POST request to the FloWrestling events API endpoint (`https://prod-web-api.flowrestling.org/api/schedule/events`).
3.  The request body must be configurable to filter events by state (SC, NC, GA, TN).
4.  The script must parse the JSON response to extract the event `id`, `name`, and `location`.
5.	The script must use the following rules based on the event date
	1. Events excluded in the database should be skipped
	2. Events not in SC, NC, GA or TN should be inserted into the database with `date`, `name`, `location`, and `IsExcluded` should be True.
	3. Events in the future that are not excluded in the database, and are in one of the states, SC, NC, GA or TN, should update the database with `date`, `name`, `location`.
	4. Events in the past, with `status.isCompleted` as False should be skipped.
	5. Events in the past, with `status.isCompleted` as True should get the data for the event
		1.  For each event, the script must construct the URL for the CSV report (e.g., `https://prod-web-api.flowrestling.org/api/event-hub/{eventId}/results/csv-report`).
		2.  The script must download the CSV file for each event.
		3.  The script must parse the CSV file, which contains match details. The CSV columns are: `Date`, `Weight`, `Round`, `Winning Wrestler`, `Winning Team`, `Result`, `Win Type`, `Losing Wrestler`, `Losing Team`, `City`, `State`, `Event`.
		4.  The script must use the existing SQL scripts located in `scripts/eventloader/sql/` to save the data into the database.
6.  The script must implement the `logMessage` and `errorLogging` functions from the previous scraper for logging.
7. The script must send an email report of new wrestlers, reusing the existing script and email functionality and HTML template.
8. The script must use tabs for indentation and follow camelCase for variables and functions.

## 5. Non-Goals (Out of Scope)

*   Adding any new features or functionalities not present in the original `flowrestlingScraper.py`.
*   Changing the database schema.
*   Creating new SQL scripts.
*   Supporting states other than SC, NC, GA, and TN.

## 6. Design Considerations (Optional)

*   The script should be structured similarly to `flowrestlingScraper.py` to maintain consistency.
*   Leverage the `requests` library for HTTP requests and the `csv` library for parsing CSV data.

## 7. Technical Considerations (Optional)

*   The script will require the `pyodbc` and `requests` libraries.
*   Credentials and configuration are stored in a `config.json` file, consistent with the existing setup.
*   The script should handle potential API changes and network errors gracefully, with retries or clear error logging.

## 8. Success Metrics

*   The script runs daily without critical errors.
*   Event and match data from FloWrestling is consistently and accurately populated in the database.
*   New wrestler emails are generated and sent correctly when new wrestlers are detected.

## 9. Open Questions

*   None at this time.
