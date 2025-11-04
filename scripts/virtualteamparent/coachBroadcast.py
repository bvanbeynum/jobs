
import markdown2
import os
import sys
import json
import base64
import datetime
import requests
from io import BytesIO
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from googleapiclient.http import MediaIoBaseUpload
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.base import MIMEBase
from email import encoders

with open("./scripts/config.json", "r") as reader:
	config = json.load(reader)

def logMessage(message):
	print(f"{datetime.datetime.now().isoformat()} - {message}")

def getTextFromAttachment(driveService, gmailService, messageId, attachmentId, filename, mimeType):
	uploadedFileId = None
	convertedDocId = None
	extractedText = ''

	try:
		logMessage(f"Processing attachment: {filename}")
		attachment = gmailService.users().messages().attachments().get(userId='me', messageId=messageId, id=attachmentId).execute()
		fileData = base64.urlsafe_b64decode(attachment['data'].encode('UTF-8'))
		
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
		logMessage(f"An error occurred: {error}")
		return f"[Error: Could not process attachment: {filename}]"
	finally:
		# Clean up
		if uploadedFileId:
			driveService.files().delete(fileId=uploadedFileId).execute()
		if convertedDocId:
			driveService.files().delete(fileId=convertedDocId).execute()
	
	return extractedText

def convertAttachments(driveService, gmailService, message, emailDetails):
	attachmentText = ""
	if 'parts' in emailDetails['payload']:
		for part in emailDetails['payload']['parts']:
			if part.get('filename') and part.get('body') and part['body'].get('attachmentId'):
				if part['mimeType'] == "application/pdf" or part['mimeType'].startswith("image/"):
					extractedText = getTextFromAttachment(driveService, gmailService, message['id'], part['body']['attachmentId'], part['filename'], part['mimeType'])
					if extractedText and extractedText.strip():
						attachmentText += f"\n----\nAttachment: {part['filename']}\n\n{extractedText}\n\n----\n"
	return attachmentText

def loadDriveData(driveService, sheetsService):
	logMessage("Loading data from Google Sheet 'Team Email'")
	searchResult = driveService.files().list(
		q="name='Team Email' and mimeType='application/vnd.google-apps.spreadsheet'",
		fields="files(id, name)"
	).execute()

	teamEmailSheet = searchResult.get('files', [])[0] if searchResult.get('files') else None

	if not teamEmailSheet:
		raise Exception("Google Sheet 'Team Email' not found in your Google Drive.")

	spreadsheetId = teamEmailSheet['id']
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
user = None

try:
	logMessage(f"Getting user data for vtpUserID: { config['vtpUserEmail'] }")
	clientResponse = requests.get(f"{ config['apiServer'] }/vtp/data/vtpuser?email={ config['vtpUserEmail'] }")
	clientResponse.raise_for_status()
	user = clientResponse.json()['vtpUsers'][0]
except Exception as error:
	logMessage(f"Error getting user data: {error}")
	sys.exit(1)

userConfig = {}
creds = None

try:
	if not user.get('refreshToken') or not user.get('refreshExpireDate'):
		raise Exception("User refresh token or expiry date not found. Please re-authenticate with Google.")

	if datetime.datetime.fromisoformat(user['refreshExpireDate'].replace('Z', '+00:00')) < datetime.datetime.now(datetime.timezone.utc):
		raise Exception("Google refresh token expired. Please re-authenticate with Google.")

	creds = Credentials.from_authorized_user_info({
		"refresh_token": user["refreshToken"],
		"client_id": config["google"]["client_id"],
		"client_secret": config["google"]["client_secret"],
		"token_uri": "https://oauth2.googleapis.com/token"
	})

	driveService = build('drive', 'v3', credentials=creds)
	sheetsService = build('sheets', 'v4', credentials=creds)
	
	driveOutput = loadDriveData(driveService, sheetsService)
	userConfig.update(driveOutput)

except Exception as error:
	logMessage(f"Error loading configuration: {error}")
	sys.exit(1)

try:
	gmailService = build('gmail', 'v1', credentials=creds)
	searchQuery = f"is:unread ({' OR '.join([f'from:{email}' for email in userConfig['coachEmails']])})"
	logMessage(f"Searching for unread emails with query: {searchQuery}")
	
	gmailResponse = gmailService.users().messages().list(userId='me', q=searchQuery).execute()

	if 'messages' not in gmailResponse or not gmailResponse['messages']:
		logMessage("No new coach emails to process.")
		sys.exit(0)

	logMessage(f"Found {len(gmailResponse['messages'])} new emails.")

	for message in gmailResponse['messages']:
		emailDetails = gmailService.users().messages().get(userId='me', id=message['id'], format='full').execute()
		
		headers = emailDetails['payload']['headers']
		subject = next(header['value'] for header in headers if header['name'] == 'Subject')
		
		body = ''
		if 'parts' in emailDetails['payload']:
			part = next((p for p in emailDetails['payload']['parts'] if p['mimeType'] == 'text/plain'), None)
			if part and 'data' in part['body']:
				body = base64.urlsafe_b64decode(part['body']['data']).decode('utf-8')
		elif 'data' in emailDetails['payload']['body']:
			body = base64.urlsafe_b64decode(emailDetails['payload']['body']['data']).decode('utf-8')

		if not body:
			body = emailDetails.get('snippet', '')

		attachmentText = convertAttachments(driveService, gmailService, message, emailDetails)
		rewrittenEmailText = rewriteWithGemini(body, attachmentText, userConfig['coachName'], userConfig['teamName'])
		
		htmlEmailBody = markdown2.markdown(rewrittenEmailText)

		for i in range(0, len(userConfig['parentEmails']), 40):
			emailBatch = userConfig['parentEmails'][i:i+40]
			
			mimeMessage = MIMEMultipart()
			mimeMessage['To'] = f'"{user["googleName"]} " <{user["googleEmail"]}>'
			mimeMessage['Bcc'] = ','.join(emailBatch)
			mimeMessage['Subject'] = subject
			mimeMessage.attach(MIMEText(htmlEmailBody, 'html'))

			if 'parts' in emailDetails['payload']:
				for part in emailDetails['payload']['parts']:
					if part.get('filename') and part.get('body') and part['body'].get('attachmentId'):
						attachment = gmailService.users().messages().attachments().get(userId='me', messageId=message['id'], id=part['body']['attachmentId']).execute()
						fileData = base64.urlsafe_b64decode(attachment['data'].encode('UTF-8'))
						
						mimePart = MIMEBase(part['mimeType'].split('/')[0], part['mimeType'].split('/')[1])
						mimePart.set_payload(fileData)
						encoders.encode_base64(mimePart)
						mimePart.add_header('Content-Disposition', 'attachment', filename=part['filename'])
						mimeMessage.attach(mimePart)

			encodedMessage = base64.urlsafe_b64encode(mimeMessage.as_bytes()).decode()
			createDraftRequest = {'message': {'raw': encodedMessage}}
			
			gmailService.users().drafts().create(userId='me', body=createDraftRequest).execute()
			totalDraftsCreated += 1
			logMessage(f"Created draft for batch {i//40 + 1}")

		gmailService.users().messages().modify(userId='me', id=message['id'], body={'removeLabelIds': ['UNREAD']}).execute()
		logMessage(f"Marked email with subject '{subject}' as read.")

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
			
			encodedMessage = base64.urlsafe_b64encode(notificationMessage.as_bytes()).decode()
			sendMessageRequest = {'raw': encodedMessage}
			
			gmailService.users().messages().send(userId='me', body=sendMessageRequest).execute()
			logMessage("Notification email sent successfully.")
			
		except HttpError as error:
			logMessage(f"An error occurred sending the notification email: {error}")
		except Exception as error:
			logMessage(f"An unexpected error occurred while sending notification: {error}")

	logMessage(f"Successfully created {totalDraftsCreated} drafts.")

except HttpError as error:
	logMessage(f"An error occurred with the Gmail API: {error}")
	sys.exit(1)
except Exception as error:
	logMessage(f"An unexpected error occurred: {error}")
	sys.exit(1)
