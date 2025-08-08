# backend/email_service.py
import os
import openai
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
import base64
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import uuid

class EmailService:
    def __init__(self):
        self.openai_client = openai.OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
        self.gmail_service = self._setup_gmail()
        
    def _setup_gmail(self):
        """Setup Gmail API service"""
        try:
            creds = Credentials(
                token=None,
                refresh_token=os.getenv('GMAIL_REFRESH_TOKEN'),
                id_token=None,
                client_id=os.getenv('GMAIL_CLIENT_ID'),
                client_secret=os.getenv('GMAIL_CLIENT_SECRET'),
                token_uri='https://oauth2.googleapis.com/token'
            )
            return build('gmail', 'v1', credentials=creds)
        except Exception as e:
            print(f"Failed to setup Gmail service: {e}")
            return None
    
    def generate_personalized_email(self, lead, template, ai_prompt):
        """Generate personalized email using OpenAI"""
        try:
            prompt = f"""
            {ai_prompt}
            
            Lead information:
            - Name: {lead.first_name or 'there'}
            - Company: {lead.company or 'your company'}
            - Email: {lead.email}
            - Title: {lead.title or ''}
            
            Email template: {template}
            
            Generate a personalized email based on the template and lead info. Keep it professional and engaging.
            """
            
            response = self.openai_client.chat.completions.create(
                model="gpt-3.5-turbo",
                messages=[{"role": "user", "content": prompt}],
                max_tokens=500,
                temperature=0.7
            )
            
            return response.choices[0].message.content
            
        except Exception as e:
            print(f"Failed to generate email with AI: {e}")
            # Fallback to template with basic substitution
            return template.replace("{first_name}", lead.first_name or "there").replace("{company}", lead.company or "your company")
    
    def send_personalized_email(self, lead, campaign, tracking_id):
        """Send personalized email via Gmail API"""
        if not self.gmail_service:
            print("Gmail service not available")
            return False
            
        try:
            # Generate personalized content
            email_body = self.generate_personalized_email(
                lead, campaign.template, campaign.ai_prompt
            )
            
            # Add tracking pixel
            domain = os.getenv("DOMAIN", "localhost:8000")
            tracking_pixel = f'<img src="http://{domain}/track/open/{tracking_id}" width="1" height="1" style="display:none;">'
            email_body_with_tracking = email_body + tracking_pixel
            
            # Create email message
            message = MIMEMultipart('alternative')
            message['to'] = lead.email
            message['subject'] = campaign.subject
            
            # Add HTML part
            html_part = MIMEText(email_body_with_tracking, 'html')
            message.attach(html_part)
            
            # Encode message
            raw_message = base64.urlsafe_b64encode(message.as_bytes()).decode()
            
            # Send email
            result = self.gmail_service.users().messages().send(
                userId='me',
                body={'raw': raw_message}
            ).execute()
            
            print(f"Email sent successfully to {lead.email}. Message ID: {result['id']}")
            return True
            
        except HttpError as error:
            print(f"Gmail API error sending to {lead.email}: {error}")
            return False
        except Exception as e:
            print(f"Failed to send email to {lead.email}: {e}")
            return False