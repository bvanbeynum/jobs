# Product Requirements Document: FloWrestling Scraper (V2)

## 1. Introduction/Overview

This document outlines the requirements for a new Python script to scrape wrestling event data from FloWrestling's updated application. The existing `flo.py` script targets an older version of their system. This new script will ensure we can continue to gather comprehensive event data by interacting with their current APIs.

The primary goal is to scrape both upcoming events and past event results, load them into our database, and correctly handle events based on their geographic location (specifically SC, NC, GA, TN). The script will be designed to run as an automated job.

## 2. Goals

*   **G1:** Scrape all upcoming wrestling events from FloWrestling's schedule API.
*   **G2:** Scrape detailed results (divisions, weight classes, matches) for past events.
*   **G3:** Load all scraped event and result data into the existing database schema (`Event`, `EventMatch`, `EventWrestler`, `EventWrestlerMatch`).
*   **G4:** Implement logic to identify and flag events outside of key states (SC, NC, GA, TN) as `IsExcluded`.
*   **G5:** Efficiently handle data synchronization by inserting new events and updating existing, non-complete events.
*   **G6:** Structure the new script to be consistent with the coding practices and inline style of the existing `flo.py`.

## 3. User Stories

*   **As a data analyst,** I want the most current event and result data from FloWrestling available in our database so that our analytics and reporting are accurate and up-to-date.
*   **As a developer,** I need an automated script that reliably scrapes FloWrestling's new system, handles data updates gracefully, and is easy to maintain and debug.

## 4. Functional Requirements

| ID | Requirement |
| :--- | :--- |
| **FR1** | The script must fetch a list of events by iterating through dates from two weeks in the past to two months in the future, using the schedule API endpoint. |
| **FR2** | For each **upcoming event**, the script must extract the event's name, start/end dates, and location details. |
| **FR3** | For each **past event**, the script must scrape detailed results by fetching divisions, then weight classes for each division, and finally the match results for each weight class. |
| **FR4** | The script must use the event's unique ID (`floId`) to check if it already exists in the `Event` table. |
| **FR5** | If an event does not exist, it must be inserted into the `Event` table. |
| **FR6** | If an event already exists and is **not** marked as `IsComplete`, its details (e.g., name, date) must be updated. |
| **FR7** | Once a past event's results have been fully scraped, the event must be marked as `IsComplete = 1` in the database to prevent future updates. |
| **FR8** | The script must identify the event's state. If the state is not one of 'SC', 'NC', 'GA', or 'TN', the event must be marked as `IsExcluded = 1`. |
| **FR9** | All scraped data must be saved into the correct corresponding tables: `Event`, `EventMatch`, `EventWrestler`, and `EventWrestlerMatch`. |
| **FR10** | The script must use the `requests` library for all API interactions. |
| **FR11** | Database connection properties must be read from the `scripts/config.json` file. |
| **FR12** | All SQL queries must be loaded from their respective files within the `/workspaces/jobs/scripts/eventloader/sql/` directory. |
| **FR13** | The new script file must be created in the `/workspaces/jobs/scripts/eventloader/` directory. |
| **FR14** | The script must log progress and errors to the console, with each log entry prefixed by the current timestamp. |

## 5. Non-Goals (Out of Scope)

*   Scraping any data fields not present in the `Event`, `EventMatch`, `EventWrestler`, and `EventWrestlerMatch` table structures.
*   Scraping wrestler profiles or news articles.
*   Using browser automation tools like Selenium.
*   Creating a separate logging file (console logging is sufficient).

## 6. Technical Considerations

*   **API Endpoints:** The script will use the following API endpoints. The structure of the JSON responses should be inferred from the provided sample files.
    *   **Schedule:** `https://api.flowrestling.org/v2/consumer/events?&page=1&size=50&start_date={date}&sport=wrestling` (from `urls.json`)
    *   **Divisions:** `https://api.flowrestling.org/v2/consumer/events/{floId}/divisions` (from `urls.json`)
    *   **Weight Classes:** `https://api.flowrestling.org/v2/consumer/events/{floId}/divisions/{divisionId}/weight_classes` (from `urls.json`)
    *   **Results:** `https://api.flowrestling.org/v2/consumer/events/{floId}/weight_classes/{weightClassId}/results` (from `urls.json`)
*   **Rate Limiting:** Implement a small delay (e.g., `time.sleep(2)`) between API calls to avoid being blocked.
*   **Code Style:** The script should be an inline script (no `main` function) and use functions only to reduce code duplication, mirroring the style of `/workspaces/jobs/scripts/eventloader/flo.py`. It must use tabs for indentation and camelCase for variable names.
*   **Database:** The script will interact with a SQL Server database using the `pyodbc` library.

## 7. Database Schema

The script will interact with the following tables. Only the fields present in these tables should be scraped and stored.

*   `Event`
*   `EventMatch`
*   `EventWrestler`
*   `EventWrestlerMatch`

## 8. Success Metrics

*   The `Event` table is successfully populated with new and updated events from FloWrestling's current API.
*   Past event results from within the specified date range are accurately loaded into the `EventMatch` and `EventWrestlerMatch` tables.
*   The script runs to completion without critical errors when executed as an automated job.

## 9. Open Questions

*   None at this time.