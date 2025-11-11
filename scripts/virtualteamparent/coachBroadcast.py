import markdown2
import os
import sys
import json
import base64
import datetime
import requests
import re
from io import BytesIO
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from googleapiclient.http import MediaIoBaseUpload
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.base import MIMEBase
from email import encoders
import imaplib
import smtplib
import email
from email.header import decode_header
import time

with open("./scripts/config.json", "r") as reader:
	config = json.load(reader)

def logMessage(message):
	print(f"{datetime.datetime.now().isoformat()} - {message}")

def errorLogging(errorMessage):
	logMessage(errorMessage)
	try:
		logPayload = {
			"log": {
				"logTime": datetime.datetime.now().isoformat(),
				"lotTypeId": "69133a239adfdad032f57c70",
				"message": errorMessage
			}
		}
		requests.post(f"{ config['apiServer'] }/sys/api/addlog", json=logPayload)
	except Exception as apiError:
		logMessage(f"Failed to log error to API: {apiError}")

	try:
		if not config.get("googleAppPassword"):
			raise Exception("Missing 'googleAppPassword' in config.json, cannot send error email.")

		msg = MIMEMultipart()
		msg["From"] = user["googleEmail"]
		msg["To"] = config.get("notificationEmail")
		msg["Subject"] = "Coach Broadcast: Script Error"
		body = f"The coach broadcast script encountered an error.\n\nError: {errorMessage}"
		msg.attach(MIMEText(body, "plain"))
		
		with smtplib.SMTP_SSL("smtp.gmail.com", 465) as smtp:
			smtp.login(user["googleEmail"], config["googleAppPassword"])
			smtp.send_message(msg)
		logMessage("Sent error email to test@nomail.com")
	except Exception as emailError:
		logMessage(f"Failed to send error email: {emailError}")

def getTextFromAttachment(driveService, fileData, filename, mimeType):
	uploadedFileId = None
	convertedDocId = None
	extractedText = ''

	try:
		logMessage(f"Processing attachment: {filename}")
		
		# Upload to Drive
		media = MediaIoBaseUpload(BytesIO(fileData), mimetype=mimeType)
		uploadedFile = driveService.files().create(
			body={'name': filename},
			media_body=media,
			fields='id'
		).execute()
		uploadedFileId = uploadedFile.get('id')

		if not uploadedFileId:
			raise Exception('Failed to upload the initial file to Drive.')

		# Copy to Google Doc to trigger OCR
		newDocTitle = os.path.splitext(filename)[0]
		convertedDoc = driveService.files().copy(
			fileId=uploadedFileId,
			body={
				'name': newDocTitle,
				'mimeType': 'application/vnd.google-apps.document'
			}
		).execute()
		convertedDocId = convertedDoc.get('id')

		if not convertedDocId:
			raise Exception('Failed to get an ID for the converted Google Doc.')

		# Export the Google Doc as plain text
		exportedDoc = driveService.files().export_media(
			fileId=convertedDocId,
			mimeType='text/plain'
		).execute()
		
		extractedText = exportedDoc.decode('utf-8')

	except HttpError as error:
		errorMessage = f"An error occurred: {error}"
		errorLogging(errorMessage)
		return f"[Error: Could not process attachment: {filename}]"
	finally:
		# Clean up
		if uploadedFileId:
			driveService.files().delete(fileId=uploadedFileId).execute()
		if convertedDocId:
			driveService.files().delete(fileId=convertedDocId).execute()
	
	return extractedText

def loadDriveData(sheetsService):
	logMessage("Loading data from Google Sheet 'Team Email'")

	vtpUserResponse = requests.get(f"{ config['apiServer'] }/vtp/data/vtpuser?id={ config['vtpId'] }")
	vtpUsers = vtpUserResponse.json()["vtpUsers"]
	indexSheetId = vtpUsers[0]["indexSheetId"]

	indexSheetResponse = sheetsService.spreadsheets().values().get(spreadsheetId=indexSheetId, range="A:B").execute()
	indexSheetData = indexSheetResponse.get('values', [])
	
	teamEmailSheetUrl = None
	for row in indexSheetData:
		if row and row[0] == "Team Email":
			teamEmailSheetUrl = row[1]
			break
	
	if not teamEmailSheetUrl:
		raise Exception("Google Sheet 'Team Email' not found in your index sheet.")

	matches = re.search(r"/spreadsheets/d/([a-zA-Z0-9-_]+)", teamEmailSheetUrl)
	if not matches:
		raise Exception("Could not parse spreadsheet ID from URL.")
	
	spreadsheetId = matches.group(1)

	sheetDetails = sheetsService.spreadsheets().get(spreadsheetId=spreadsheetId).execute()

	parentEmailsSheet = next((s for s in sheetDetails['sheets'] if s['properties']['title'] == "Parent Emails"), None)
	configSheet = next((s for s in sheetDetails['sheets'] if s['properties']['title'] == "Config"), None)

	if not parentEmailsSheet:
		raise Exception("Worksheet 'Parent Emails' not found in 'Team Email' Google Sheet.")
	if not configSheet:
		raise Exception("Worksheet 'Config' not found in 'Team Email' Google Sheet.")

	parentEmailsSheetName = parentEmailsSheet['properties']['title']
	headerResponse = sheetsService.spreadsheets().values().get(spreadsheetId=spreadsheetId, range=f"{parentEmailsSheetName}!A1:Z1").execute()
	header = headerResponse.get('values', [[]])[0]
	emailColumnIndex = header.index("Email Address")
	emailColumn = chr(65 + emailColumnIndex)

	teamEmailResponse = sheetsService.spreadsheets().values().get(spreadsheetId=spreadsheetId, range=f"{parentEmailsSheetName}!{emailColumn}2:{emailColumn}").execute()
	parentEmails = [item for sublist in teamEmailResponse.get('values', []) for item in sublist]

	configValuesResponse = sheetsService.spreadsheets().values().get(spreadsheetId=spreadsheetId, range="Config!A2:B").execute()
	configValues = {row[0]: row[1] for row in configValuesResponse.get('values', []) if len(row) > 1}

	coachEmailResponse = sheetsService.spreadsheets().values().get(spreadsheetId=spreadsheetId, range="Config!D2:D").execute()
	coachEmails = [row[0] for row in coachEmailResponse.get('values', []) if row]

	coachName = configValues.get("Coach Name")
	teamName = configValues.get("Team Name")
	nofityEmail = configValues.get("Notify Email")

	if not coachEmails or not coachName or not teamName:
		raise Exception("Missing configuration values in 'Config' Google Sheet.")

	return {
		"parentEmails": parentEmails,
		"coachEmails": coachEmails,
		"coachName": coachName,
		"teamName": teamName,
		"notifyEmail": nofityEmail
	}

def rewriteWithGemini(body, attachmentText, coachName, teamName):
	logMessage("Rewriting email with Gemini")
	apiKey = config["geminiAPIKey"]
	if not apiKey:
		raise Exception("GEMINI_API_KEY not set.")
	
	url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={apiKey}"

	attachmentPromptSection = f"\n---\nIMPORTANT: Please also incorporate the key information from this attached document:\nATTACHED DOCUMENT TEXT:\n{attachmentText}\n---\n" if attachmentText else ''

	prompt = f"""
You are a helpful parent volunteer for the fort mill high school wrestling team, the {teamName}. Your task is to rewrite an email from Coach {coachName} into a clear, friendly, and concise message for all the other parents.

Here are your instructions:
- Keep the tone positive, encouraging and excited.
- Start with a friendly greeting like "Hi Team Parents,".
- Clearly state the main points (e.g., practice time changes, game location, required gear). Use bullet points for lists if it makes it easier to read.
- Make it fun by adding emoji
- Remove any coach-specific jargon or overly technical language.
- Ensure all key details like dates, times, and locations are present and easy to find.
- Conclude with support for {teamName} and don't sign your name.
- Do not include any place holders. The email should be ready to send without review.
- AVOID call to action. Only provide information in an informative way.
- Don't repeat the subject in the body.
- IMPORTANT: Do not add any information that was not in the original email body or the attached document. Just reformat and rephrase what is there.

**Original Email from Coach {coachName}:**
Body:
---
{body}
---
{attachmentPromptSection}
"""

	requestBody = {"contents": [{"parts": [{"text": prompt}]}]}
	response = requests.post(url, json=requestBody, headers={'Content-Type': 'application/json'})

	if response.status_code == 200:
		return response.json()['candidates'][0]['content']['parts'][0]['text']
	else:
		raise Exception(f"Error calling Gemini API. Status: {response.status_code}. Response: {response.text}")

totalDraftsCreated = 0
user = {
	"googleName": "Fortmill Wrestling",
	"googleEmail": "wrestlingfortmill@gmail.com"
}

try:
	creds = service_account.Credentials.from_service_account_file(
		'./scripts/credentials.json',
		scopes=[
			'https://www.googleapis.com/auth/drive',
			'https://www.googleapis.com/auth/gmail.modify',
			'https://www.googleapis.com/auth/gmail.send',
			'https://www.googleapis.com/auth/spreadsheets.readonly'
		]
	)
except Exception as error:
	errorMessage = f"Error loading service account credentials: {error}"
	errorLogging(errorMessage)
	sys.exit(1)

userConfig = {}

try:
	driveService = build('drive', 'v3', credentials=creds)
	sheetsService = build('sheets', 'v4', credentials=creds)
	
	driveOutput = loadDriveData(sheetsService)
	userConfig.update(driveOutput)

except Exception as error:
	errorMessage = f"Error loading configuration: {error}"
	errorLogging(errorMessage)
	sys.exit(1)

try:
	if not config.get("googleAppPassword"):
		raise Exception("Missing 'googleAppPassword' in config.json")

	imap = imaplib.IMAP4_SSL("imap.gmail.com")
	imap.login(user['googleEmail'], config['googleAppPassword'])
	imap.select("INBOX")

	logMessage(f"Searching for unread emails from: {userConfig['coachEmails']}")
	all_message_ids = set()
	for email_address in userConfig['coachEmails']:
		search_query = f'(UNSEEN FROM "{email_address}")'
		logMessage(f"Executing IMAP search with query: {search_query}")
		status, messages = imap.search(None, search_query)
		if status == "OK":
			found_ids = messages[0].split()
			logMessage(f"Found {len(found_ids)} messages for query.")
			for msg_id in found_ids:
				all_message_ids.add(msg_id)
		else:
			logMessage(f"IMAP search failed for query: {search_query} with status: {status}")
	
	all_message_ids = list(all_message_ids)

	if not all_message_ids:
		logMessage("No new coach emails to process.")
		sys.exit(0)

	logMessage(f"Found {len(all_message_ids)} new emails.")

	for msg_id in all_message_ids:
		status, msg_data = imap.fetch(msg_id, "(RFC822)")
		if status != 'OK':
			logMessage(f"Failed to fetch email with id {msg_id}")
			continue
		
		email_message = email.message_from_bytes(msg_data[0][1])

		subject, encoding = decode_header(email_message["Subject"])[0]
		if isinstance(subject, bytes):
			subject = subject.decode(encoding if encoding else "utf-8")

		body = ""
		attachments = []
		if email_message.is_multipart():
			for part in email_message.walk():
				content_type = part.get_content_type()
				content_disposition = str(part.get("Content-Disposition"))
				if "attachment" not in content_disposition:
					if content_type == "text/plain":
						try:
							body = part.get_payload(decode=True).decode()
						except Exception as error:
							errorLogging(f"Error decoding email body part: {error}")
							pass
				else:
					filename = part.get_filename()
					if filename:
						attachments.append({
							"filename": filename,
							"data": part.get_payload(decode=True),
							"mimeType": content_type
						})
		else:
			try:
				body = email_message.get_payload(decode=True).decode()
			except Exception as error:
				errorLogging(f"Error decoding email body: {error}")
				pass

		attachmentText = ""
		for attachment in attachments:
			if attachment['mimeType'] == "application/pdf" or attachment['mimeType'].startswith("image/"):
				extractedText = getTextFromAttachment(driveService, attachment['data'], attachment['filename'], attachment['mimeType'])
				if extractedText and extractedText.strip():
					attachmentText += f"\n----\nAttachment: {attachment['filename']}\n\n{extractedText}\n\n----\n"

		rewrittenEmailText = rewriteWithGemini(body, attachmentText, userConfig['coachName'], userConfig['teamName'])
		htmlEmailBody = markdown2.markdown(rewrittenEmailText)

		for i in range(0, len(userConfig['parentEmails']), 40):
			emailBatch = userConfig['parentEmails'][i:i+40]
			
			mimeMessage = MIMEMultipart()
			mimeMessage['To'] = f'"{user["googleName"]}" <{user["googleEmail"]}>'
			mimeMessage['Bcc'] = ','.join(emailBatch)
			mimeMessage['Subject'] = subject
			mimeMessage.attach(MIMEText(htmlEmailBody, 'html'))

			for attachment in attachments:
				mimePart = MIMEBase(attachment['mimeType'].split('/')[0], attachment['mimeType'].split('/')[1])
				mimePart.set_payload(attachment['data'])
				encoders.encode_base64(mimePart)
				mimePart.add_header('Content-Disposition', 'attachment', filename=attachment['filename'])
				mimeMessage.attach(mimePart)

			imap.append('[Gmail]/Drafts', '', imaplib.Time2Internaldate(time.time()), mimeMessage.as_bytes())
			totalDraftsCreated += 1
			logMessage(f"Created draft for batch {i//40 + 1}")

		imap.store(msg_id, '+FLAGS', '\Seen')
		logMessage(f"Marked email with subject '{subject}' as read.")

	imap.close()
	imap.logout()

	if totalDraftsCreated > 0 and userConfig.get('notifyEmail'):
		try:
			logMessage(f"Sending notification email to {userConfig['notifyEmail']}")
			
			notificationMessage = MIMEMultipart()
			notificationMessage['To'] = userConfig['notifyEmail']
			notificationMessage['Subject'] = f"{userConfig['teamName']} Wrestling - Drafts Ready for Review"
			
			emailBody = (
				f"<p>This is an automated notification to let you know that {totalDraftsCreated} new email draft(s) have been created and are ready for your review in the drafts folder of your Gmail account.</p>"
				f"<p>Please review and send them to the team parents at your convenience.</p>"
				f"<p>Thanks,</p>"
				f"<p>Your Friendly Neighborhood Virtual Team Parent Bot</p>"
			)
			
			notificationMessage.attach(MIMEText(emailBody, 'html'))
			
			with smtplib.SMTP_SSL('smtp.gmail.com', 465) as smtp:
				smtp.login(user['googleEmail'], config['googleAppPassword'])
				smtp.send_message(notificationMessage)

			logMessage("Notification email sent successfully.")
		
		except Exception as error:
			errorMessage = f"An unexpected error occurred while sending notification: {error}"
			errorLogging(errorMessage)

	logMessage(f"Successfully created {totalDraftsCreated} drafts.")

except Exception as error:
	errorMessage = f"An unexpected error occurred: {error}"
	errorLogging(errorMessage)
	sys.exit(1)