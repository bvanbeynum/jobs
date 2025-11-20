
You are a senior developer with experience working in team environments. Code readabilty is a primary concern, and alignment to the coding standards laid out in the GEMINI instructions are of great importance.

## Goal

Extract wrestlers from SQL server database and use rest API to add them to the Mongo DB.

## Constraints

- Only get wrestlers that have a wrestler match modified in the last week to add/update
- Delete any wrestlers from Mongo that aren't in SQL server

## SQL Data Structure

* Event
* EventMatch
* EventWrestler
* EventWrestlerMatch

## Mongo Data Structure

```json
{
	"sqlId": "Number",
	"name": "String",
	"division": "String",
	"weightClass": "String",
	"rating": "Number",
	"deviation": "Number",
	"events": [{
		"sqlId": "Number",
		"date": "Date",
		"name": "String",
		"team": "String",
		"locationState": "String",
		"matches": [{
			"division": "String",
			"weightClass": "String",
			"round": "String",
			"vs": "String",
			"vsTeam": "String",
			"vsSqlId": "Number",
			"isWinner": "Boolean",
			"winType": "String",
			"sort": "Number"
		}]
	}],
	"lineage": [[{ 
		"wrestler1SqlId": "Number",
		"wrestler1Name": "String",
		"wrestler1Team": "String",
		"wrestler2SqlId": "Number",
		"wrestler2Name": "String",
		"wrestler2Team": "String",
		"isWinner": "Boolean",
		"sort": "Number",
		"eventDate": "Date"
	}]]
}
```

## API Endpoints

GET /data/wrestler
- query options
	- sqlid
	- sqlids (comma separated)
	- id
	- select (comma separated field list)

POST /data/wrestler
DELETE /data/wrestler

## File Strucutre

- Pyton script should be in scripts/datamover
- SQL files should be stored in scripts/datamover/sql

## Python File

Use scripts/datamover/eventloader.py as a guide to structure the code

- Create an inline file.
- Print statements to indicate progress or errors.
- Print statements should always include the date/time
- SQL should always be stored in a separate file for each script.
- SQL files should be loaded at the beginning of the script and stored in a dictionary with the file name as the key
- SQL connection properties are stored in scripts/config.json
- The driver is: ODBC Driver 18 for SQL Server

## Key Principals

- What is the most efficient way to extract and move large volumes of data.
- Strictly follow code guidelines laid out in the GEMINI instructions.
