import datetime
import os
import json
import pyodbc
import subprocess
import requests
import sys

def logMessage(message):
	logTime = datetime.datetime.strftime(datetime.datetime.now(), "%Y-%m-%d %H:%M:%S")
	print(f"{logTime} - {message}")

def errorLogging(errorMessage):
	logMessage(errorMessage)
	try:
		logPayload = {
			"log": {
				"logTime": datetime.datetime.now().isoformat(),
				"lotTypeId": "691e351ab7de6ab54ed121ae",
				"message": errorMessage
			}
		}
		requests.post(f"{ config['apiServer'] }/sys/api/addlog", json=logPayload)
	except Exception as apiError:
		logMessage(f"Failed to log error to API: {apiError}")




# *************************** Script Start ***************************

logMessage(f"--------------- Starting Backup Process")

with open("./scripts/config.json", "r") as reader:
	config = json.load(reader)

# --- Backup Configuration ---
# This is the path INSIDE THE DOCKER CONTAINER where the backup file will be created.
sqlServerBackupDir = "/var/opt/mssql/backup"
backupFileName = f"{config['database']['database']}-{datetime.datetime.now().strftime('%Y-%m-%d')}.bak"
sqlServerBackupPath = f"{sqlServerBackupDir}/{backupFileName}"

# This is the path ON THE RASPBERRY PI HOST where the backup file is stored.
remoteHostBackupDir = "/home/bvanbeynum/prod/mssql/backup"
remoteHostBackupPath = f"{remoteHostBackupDir}/{backupFileName}"

# --- SSH Configuration for SQL Server Host (Raspberry Pi) ---
sqlServerHost = config['database']['server']
sshUser = "bvanbeynum"
sshPort = 9501
sshKeyFile = "/home/appuser/.ssh/id_rsa"

# --- SSH Configuration for Cloud Server ---
cloudServerHost = "edisto.beynum.com"
cloudServerBackupDir = "~/prod/data/backup"
cloudServerBackupPath = f"{cloudServerBackupDir}/{backupFileName}"

# --- Local Configuration ---
localTempDir = "/tmp"
localBackupPath = os.path.join(localTempDir, backupFileName)

# --- Backup Retention ---
cloudBackupRetentionDays = 7


logMessage("----------- 1. Trigger SQL Server Backup")
try:
	logMessage(f"Connecting to database on {sqlServerHost}...")
	cnxn = pyodbc.connect(
		(
			f"DRIVER={{ODBC Driver 18 for SQL Server}};"
			f"SERVER={sqlServerHost};"
			f"DATABASE={config['database']['database']};"
			f"UID={config['database']['user']};"
			f"PWD={config['database']['password']};"
			"ENCRYPT=no;"
		),
		autocommit=True
	)
	cursor = cnxn.cursor()
	
	backupCommand = f"backup database [{config['database']['database']}] to disk = '{sqlServerBackupPath}' with format;"
	logMessage(f"Running backup command on SQL Server...")
	
	cursor.execute(backupCommand)
	# Wait for the backup to complete.
	while cursor.nextset():
		pass
	
	logMessage(f"SQL Server backup completed successfully to {sqlServerBackupPath} on {sqlServerHost}")
	
	cursor.close()
	cnxn.close()

except pyodbc.Error as ex:
	sqlstate = ex.args[0]
	errorLogging(f"Database backup operation failed: {sqlstate}")
	sys.exit(1)
except Exception as e:
	errorLogging(f"An unexpected error occurred during backup: {e}")
	sys.exit(1)

logMessage("----------- 2. Copy Backup From SQL Host")
remoteScpPath = f"{sshUser}@{sqlServerHost}:{remoteHostBackupPath}"
scpFromPiCommand = [
	"scp",
	"-o", "StrictHostKeyChecking=no",
	"-o", "UserKnownHostsFile=/dev/null",
	"-P", str(sshPort),
	"-i", sshKeyFile,
	remoteScpPath,
	localBackupPath
]

try:
	logMessage(f"Copying backup from {sqlServerHost} to local path {localBackupPath}...")
	process = subprocess.run(
		scpFromPiCommand,
		check=True,
		capture_output=True,
		text=True
	)
	logMessage(f"Backup file copied locally successfully.")

except subprocess.CalledProcessError as e:
	errorLogging(f"SCP command failed with exit code {e.returncode}")
	logMessage(f"STDOUT: {e.stdout}")
	logMessage(f"STDERR: {e.stderr}")
	errorLogging(f"Failed to copy backup file from {remoteScpPath}. Check SSH connection and remote path.")
	sys.exit(1)
except Exception as e:
	errorLogging(f"An unexpected error occurred during SCP copy: {e}")
	sys.exit(1)

logMessage("----------- 3. Copy Backup to Cloud Server")
cloudScpPath = f"{sshUser}@{cloudServerHost}:{cloudServerBackupPath}"
scpToCloudCommand = [
	"scp",
	"-o", "StrictHostKeyChecking=no",
	"-o", "UserKnownHostsFile=/dev/null",
	"-P", str(sshPort),
	"-i", sshKeyFile,
	localBackupPath,
	cloudScpPath
]

try:
	logMessage(f"Copying local backup to {cloudServerHost}...")
	process = subprocess.run(
		scpToCloudCommand,
		check=True,
		capture_output=True,
		text=True
	)
	logMessage(f"Backup file copied to cloud server successfully.")

except subprocess.CalledProcessError as e:
	errorLogging(f"SCP command to cloud server failed with exit code {e.returncode}")
	logMessage(f"STDOUT: {e.stdout}")
	logMessage(f"STDERR: {e.stderr}")
	errorLogging(f"Failed to copy backup file to {cloudScpPath}.")
	sys.exit(1)
except Exception as e:
	errorLogging(f"An unexpected error occurred during cloud SCP copy: {e}")
	sys.exit(1)


logMessage("----------- 4. Cleanup Old Backups on Cloud Server")
try:
	databaseName = config['database']['database']
	cleanupCommand = f"find {cloudServerBackupDir} -name '{databaseName}-*.bak' -type f -mtime +{cloudBackupRetentionDays} -delete"
	
	cleanupCloudSshCommand = [
		"ssh",
		"-o", "StrictHostKeyChecking=no",
		"-o", "UserKnownHostsFile=/dev/null",
		"-p", str(sshPort),
		"-i", sshKeyFile,
		f"{sshUser}@{cloudServerHost}",
		cleanupCommand
	]

	logMessage(f"Deleting old backups on {cloudServerHost} (older than {cloudBackupRetentionDays} days)...")
	process = subprocess.run(
		cleanupCloudSshCommand,
		check=True,
		capture_output=True,
		text=True
	)
	logMessage("Old cloud backups deleted successfully.")
except subprocess.CalledProcessError as e:
	errorLogging(f"Warning: Failed to delete old cloud backup files. SSH command failed with exit code {e.returncode}")
	logMessage(f"STDOUT: {e.stdout}")
	logMessage(f"STDERR: {e.stderr}")
except Exception as e:
	errorLogging(f"An unexpected error occurred during old cloud backup cleanup: {e}")


logMessage("----------- 5. Cleanup Remote Backup on SQL Server Host")
cleanupCommandSsh = [
	"ssh",
	"-o", "StrictHostKeyChecking=no",
	"-o", "UserKnownHostsFile=/dev/null",
	"-p", str(sshPort),
	"-i", sshKeyFile,
	f"{sshUser}@{sqlServerHost}",
	f"rm {remoteHostBackupPath}"
]

try:
	logMessage(f"Deleting backup file from {sqlServerHost}...")
	process = subprocess.run(
		cleanupCommandSsh,
		check=True,
		capture_output=True,
		text=True
	)
	logMessage(f"Remote backup file {remoteHostBackupPath} deleted successfully.")
except subprocess.CalledProcessError as e:
	errorLogging(f"Warning: Failed to delete remote backup file. SSH command failed with exit code {e.returncode}")
	logMessage(f"STDOUT: {e.stdout}")
	logMessage(f"STDERR: {e.stderr}")
except Exception as e:
	errorLogging(f"An unexpected error occurred during remote cleanup: {e}")

logMessage("----------- 6. Cleanup Local Temp Backup")
try:
	os.remove(localBackupPath)
	logMessage("--> Local temp file cleaned up.")
except OSError as error:
	errorLogging(f"Error deleting temp file: {error}")

logMessage(f"--------------- Backup Process Complete. Final backup at {cloudServerHost}:{cloudServerBackupPath}")
