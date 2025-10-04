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
    # Main logic will go here
    print(f"{current_time()}: FloWrestling scraper finished.")

if __name__ == "__main__":
    main()
