## Context

-   Example JSON responses are stored in `/workspaces/jobs/tasks/context`.
-   `/workspaces/jobs/tasks/context/urls.json` provides the mapping of URL to JSON response.

## Relevant Files

-   `/workspaces/jobs/scripts/eventloader/flowrestling_scraper.py` - The new script for scraping FloWrestling.
-   `/workspaces/jobs/scripts/eventloader/sql/EventSave.sql` - SQL query to save an event.
-   `/workspaces/jobs/scripts/eventloader/sql/EventExistsGet.sql` - SQL query to check if an event exists.
-   `/workspaces/jobs/scripts/eventloader/sql/MatchSave.sql` - SQL query to save a match.
-   `/workspaces/jobs/scripts/eventloader/sql/WrestlerSave.sql` - SQL query to save a wrestler.
-   `/workspaces/jobs/scripts/eventloader/sql/WrestlerMatchSave.sql` - SQL query to save a wrestler-match link.
-   `/workspaces/jobs/scripts/config.json` - Database connection properties.

### Notes

-   The new script should follow the inline style and conventions of `/workspaces/jobs/scripts/eventloader/flo.py`.
-   Use `python /workspaces/jobs/scripts/eventloader/flowrestling_scraper.py` to run the script for testing.

## Tasks

-   [x] 1.0 **Project Setup**
    -   [x] 1.1 Create the file `/workspaces/jobs/scripts/eventloader/flowrestling_scraper.py`.
    -   [x] 1.2 Add basic script structure: imports (`requests`, `pyodbc`, `datetime`, `time`, `json`, `os`), timestamped logging, and placeholders for main logic.
    -   [x] 1.3 Run the script to ensure the basic structure is executable without errors.
-   [x] 2.0 **Scraping Implementation: Upcoming Events**
    -   [x] 2.1 Store the API endpoint URLs as an array or dictionary within the Python script.
    -   [x] 2.2 Implement a loop to iterate through dates from two weeks in the past to two months in the future.
    -   [x] 2.3 Fetch the list of events for each date using the schedule API.
    -   [x] 2.4 For each upcoming event, extract the event's name, start/end dates, and location details.
    -   [x] 2.5 Add a `time.sleep(2)` between API calls.
    -   [x] 2.6 Run the script to test and print the scraped upcoming event data to the console.
-   [ ] 3.0 **Scraping Implementation: Past Event Results**
    -   [ ] 3.1 For each past event, fetch its divisions using the divisions API endpoint.
    -   [ ] 3.2 For each division, fetch the weight classes using the weight classes API endpoint.
    -   [ ] 3.3 For each weight class, fetch the match results using the results API endpoint.
    -   [ ] 3.4 Extract all relevant match data, including wrestler information.
    -   [ ] 3.5 Run the script to test and print the scraped past event results (divisions, weight classes, matches) to the console.
-   [ ] 4.0 **Database Implementation**
    -   [ ] 4.1 Implement logic to read database connection properties from `scripts/config.json`.
    -   [ ] 4.2 Implement a function to load all SQL files from the `/workspaces/jobs/scripts/eventloader/sql/` directory into a dictionary, using the file names as keys (similar to `loadSQL` in `flo.py`).
    -   [ ] 4.3 For each scraped event, use the `EventExistsGet` SQL query to check if it's already in the `Event` table.
    -   [ ] 4.4 If the event is new, insert it using the `EventSave` SQL query.
    -   [ ] 4.5 If the event exists and is not complete, update its details.
    -   [ ] 4.6 Implement the logic to identify the event's state and mark it as `IsExcluded = 1` if it's not in 'SC', 'NC', 'GA', or 'TN'.
    -   [ ] 4.7 Save all scraped match and wrestler data into `EventMatch`, `EventWrestler`, and `EventWrestlerMatch` tables using their respective SQL queries.
    -   [ ] 4.8 After all results for a past event are saved, mark the event as `IsComplete = 1`.