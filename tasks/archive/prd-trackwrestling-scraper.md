# Product Requirements Document: Trackwrestling Scraper

## 1. Introduction/Overview

This document outlines the requirements for a new Python script designed to scrape wrestling event data from `https://www.trackwrestling.com/`. The primary goal is to capture event information from specific states (SC, NC, GA, TN) that are not available on FloWrestling and load this data into our existing database. The script will handle both upcoming and past events, ensuring our wrestling event database is comprehensive.

## 2. Goals

*   **G1:** Scrape future events from Trackwrestling in SC, NC, GA, and TN, capturing event name, start/end dates, and location.
*   **G2:** Scrape results from past events (within the last year) in the same states, including match, wrestler, and winner details.
*   **G3:** Load all scraped information into the existing database schema, using the `Event`, `EventMatch`, `EventWrestler`, and `EventWrestlerMatch` tables.
*   **G4:** Ensure the script is capable of running headless on an Ubuntu server for automated execution.
*   **G5:** Implement robust logging to both the console and a dedicated log file for monitoring and debugging.

## 3. User Stories

*   **As a data analyst,** I want to see all major wrestling events from SC, NC, GA, and TN in one database, regardless of whether they used FloWrestling or Trackwrestling, so that I can perform comprehensive analysis.
*   **As a developer,** I want a reliable, automated script that can run on a server to keep our event database up-to-date with Trackwrestling data, minimizing manual intervention.

## 4. Functional Requirements

| ID | Requirement |
| :--- | :--- |
| **FR1** | The script must scrape event data from `https://www.trackwrestling.com/`. |
| **FR2** | The script must search for events specifically in the states of South Carolina, North Carolina, Georgia, and Tennessee. |
| **FR3** | For **future** events, the script must extract: Event Name, Start Date, End Date, and Location. |
| **FR4** | For **past** events (no older than one year), the script must extract: <br> - **Event:** Name, Location, Start Date, End Date <br> - **Match:** Division, Weight Class, Round, Win Type <br> - **Wrestler:** Name of the winner. |
| **FR5** | The script must check the `Event` table using the Trackwrestling event ID to prevent inserting events that already exist. |
| **FR6** | Scraped data must be saved into the correct corresponding tables: `Event`, `EventMatch`, `EventWrestler`, and `EventWrestlerMatch`. |
| **FR7** | Database connection properties must be read from the `scripts/config.json` file. |
| **FR8** | All operations, status updates, and errors must be logged to both the console (stdout) and a log file (`track_scraper.log`). |
| **FR9** | The script must be able to run in a headless environment on an Ubuntu server. |
| **FR10** | The code structure, style, and formatting should be consistent with the existing `scripts/eventloader/flo.py` script. |
| **FR11** | All scripts should be stored in the 'scripts/eventloader' directory. |
| **FR12** | All SQL queries should be in their own files and stored in '/scripts/eventloader/sql' directory. |

## 5. Non-Goals (Out of Scope)

*   Scraping events from states other than SC, NC, GA, and TN.
*   Scraping detailed match scores.
*   Attempting to de-duplicate events between FloWrestling and Trackwrestling; the two systems are considered mutually exclusive.
*   Scraping events that occurred more than one year ago.

## 6. Design Considerations

*   The script's architecture should mirror `scripts/eventloader/flo.py`, separating concerns into distinct functions for searching, parsing event details, and loading data into the database.

*	The script should be laid out as an inline script file and not include a main function, and functions should only be used to reduce duplicate code.

## 7. Technical Considerations

*   The target website, `trackwrestling.com`, uses various measures (e.g., session cookies, hidden forms) to prevent automated scraping. A simple HTTP request library will likely be insufficient.
*   A browser automation tool like **Selenium** or a similar library capable of managing sessions and executing JavaScript is the recommended approach.
*   The User-Agent string used for requests should be configurable and stored in `scripts/config.json` to allow for easy updates.

## 8. Implementation

1. Events are available on the search page. Each event has an event type and an eid that can be used to access the event.
https://www.trackwrestling.com/Login.jsp

2. Each event has a direct link to establish the session and obtain the TIM and twSessionId from the html content.
https://www.trackwrestling.com/tw/{event type}/VerifyPassword.jsp?tournamentId={ eId }

3. The main page of the event can be accessed from this URL. This will set the session to the event.
https://www.trackwrestling.com/{ event type }/MainFrame.jsp?newSession=false&TIM={ TIM }&pageName=&twSessionId={ tWSessionId }

4. The details of each match can be obtained from the RoundResults.jsp page. If the page is not found, or says "This information is not being released to the public yet", then it is not yet available.
https://www.trackwrestling.com/{ event type }/RoundResults.jsp?TIM={ TIM }&twSessionId={ tWSessionId }

## 8. Success Metrics

*   The database is successfully populated with Trackwrestling events from the specified states that were not previously present.
*   The script runs to completion without critical errors when executed as part of an automated workflow.
*   The generated log files are clear and provide sufficient detail to debug any issues that arise.

## 9. Open Questions

*   None at this time.
