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
    
    def generate_personalized_email_and_subject(self, lead, ai_prompt, sending_profile=None):
        """Generate personalized email content and subject using OpenAI"""
        try:
            # Get sender information for the AI prompt
            sender_name = sending_profile.sender_name if sending_profile else os.getenv('SENDER_NAME', 'Alex Johnson')
            sender_title = sending_profile.sender_title if sending_profile else os.getenv('SENDER_TITLE', 'Business Development Manager')
            sender_company = sending_profile.sender_company if sending_profile else os.getenv('SENDER_COMPANY', 'Growth Solutions Inc.')
            sender_email = sending_profile.sender_email if sending_profile else os.getenv('SENDER_EMAIL', 'alex@growthsolutions.com')
            sender_phone = sending_profile.sender_phone if sending_profile else os.getenv('SENDER_PHONE', '')
            sender_contact = f"{sender_email}" + (f" | {sender_phone}" if sender_phone else "")
            sender_signature = sending_profile.signature if sending_profile and sending_profile.signature else f"{sender_name}<br>{sender_title}<br>{sender_company}<br>{sender_contact}"

            # Clean and prepare lead data
            lead_name = (lead.first_name or '').strip()
            lead_company = (lead.company or '').strip()
            lead_title = (getattr(lead, 'title', '') or '').strip()
            lead_industry = (getattr(lead, 'industry', '') or '').strip()
            lead_website = (getattr(lead, 'website', '') or '').strip()

            prompt = f"""You are a professional email copywriter. Write a personalized cold email with subject line.

LEAD DETAILS:
- Name: {lead_name if lead_name else 'there'}
- Company: {lead_company if lead_company else 'their company'}
- Title: {lead_title}
- Industry: {lead_industry}
- Website: {lead_website}

SENDER DETAILS:
- Name: {sender_name}
- Title: {sender_title}
- Company: {sender_company}

INSTRUCTIONS: {ai_prompt}

FORMAT REQUIREMENTS:
1. Start with "SUBJECT: [your subject line]"
2. Then write the email body
3. Keep it professional and personalized
4. Use HTML formatting for the body
5. End with the sender signature

SUBJECT LINE GUIDELINES:
- Be specific and relevant to {lead_company if lead_company else 'their business'}
- Avoid generic phrases like "Quick question"
- Make it personal and intriguing
- Keep under 60 characters

EMAIL BODY GUIDELINES:
- Address {lead_name if lead_name else 'them'} personally
- Reference {lead_company if lead_company else 'their company'} specifically
- Keep it concise (under 120 words)
- Include a clear call-to-action
- Be professional but conversational

End with this signature:
{sender_signature}"""

            response = self.openai_client.chat.completions.create(
                model="gpt-4",
                messages=[{"role": "user", "content": prompt}],
                max_tokens=500,
                temperature=0.7
            )
            
            response_text = response.choices[0].message.content.strip()
            
            # Extract subject line and content more reliably
            import re
            
            # Look for SUBJECT: at the start of a line
            subject_match = re.search(r'^SUBJECT:\s*(.+?)$', response_text, re.MULTILINE | re.IGNORECASE)
            
            if subject_match:
                subject_line = subject_match.group(1).strip()
                # Remove the SUBJECT line from content
                email_content = re.sub(r'^SUBJECT:\s*.+?$', '', response_text, flags=re.MULTILINE | re.IGNORECASE).strip()
            else:
                # If no SUBJECT found, split on first line
                lines = response_text.split('\n', 1)
                if len(lines) > 1:
                    subject_line = lines[0].replace('SUBJECT:', '').strip()
                    email_content = lines[1].strip()
                else:
                    subject_line = f"Regarding {lead_company if lead_company else 'your business'}"
                    email_content = response_text
            
            # Clean up subject line
            subject_line = subject_line.replace('"', '').replace("'", '').strip()
            if not subject_line or len(subject_line) < 3:
                subject_line = f"Regarding {lead_company if lead_company else 'your business'}"
            
            # Clean up email content and ensure proper HTML formatting
            email_content = email_content.strip()
            
            # If content doesn't have HTML tags, convert line breaks to HTML
            if '<p>' not in email_content and '<br>' not in email_content:
                # Convert double line breaks to paragraph breaks
                email_content = email_content.replace('\n\n', '\n<p></p>\n')
                # Convert single line breaks to <br> tags
                email_content = email_content.replace('\n', '<br>\n')
                # Wrap in paragraph tags
                email_content = f'<p>{email_content}</p>'
            
            # Clean up any double paragraph tags
            email_content = re.sub(r'<p></p>', '</p><p>', email_content)
            email_content = re.sub(r'<p>\s*<p>', '<p>', email_content)
            email_content = re.sub(r'</p>\s*</p>', '</p>', email_content)
            
            return {
                'subject': subject_line,
                'content': email_content
            }
            
        except Exception as e:
            print(f"Failed to generate email with AI: {e}")
            # Improved fallback with better personalization
            fallback_subject = f"Partnership opportunity with {lead.company}" if lead.company else "Business partnership opportunity"
            fallback_content = f"""<p>Hi {lead.first_name or 'there'},</p>
<p>I hope this message finds you well. I noticed your work at {lead.company or 'your company'} and wanted to reach out about a potential partnership opportunity.</p>
<p>Would you be open to a brief conversation about how we might be able to help you achieve your business goals?</p>
<p>Best regards,<br>{sender_name}<br>{sender_title}<br>{sender_company}</p>"""
            
            return {
                'subject': fallback_subject,
                'content': fallback_content
            }
    
    def send_personalized_email(self, lead, campaign, tracking_id, sending_profile=None):
        """Send personalized email via Gmail API"""
        if not self.gmail_service:
            print("Gmail service not available")
            return False
        print(tracking_id)
        try:
            # Generate personalized content and subject
            email_data = self.generate_personalized_email_and_subject(
                lead, campaign.ai_prompt, sending_profile
            )
            email_body = email_data['content']
            email_subject = email_data['subject']
            
            # Modern multi-signal tracking
            domain = os.getenv("DOMAIN", "localhost:8000")
            
            from modern_tracking_service import modern_tracker
            tracking_elements = modern_tracker.generate_multi_signal_tracking(tracking_id, domain)
            
            # Replace any links with tracked versions
            import re
            def replace_links(match):
                original_url = match.group(1)
                tracked_url = f"https://{domain}/api/track/click/{tracking_id}?url={original_url}"
                return f'href="{tracked_url}"'
            
            # First, convert plain URLs to clickable links, then track all links
            # Convert plain URLs to anchor tags (excluding already linked URLs)
            url_pattern = r'(?<!href=["\'\'`])(?<!src=["\'\'`])(https?://[^\s<>"]+)'
            email_body = re.sub(url_pattern, r'<a href="\1">\1</a>', email_body)
            
            # Track all links in the email (both existing and newly created)
            email_body_with_tracking = re.sub(r'href="([^"]+)"', replace_links, email_body)
            
            # Add multi-signal tracking elements
            email_body_with_tracking += f'''
            <!-- Multi-Signal Open Tracking -->
            {tracking_elements['primary']}
            {tracking_elements['secondary']}
            {tracking_elements['content']}
            
            <!-- View in browser link with tracking -->
            <div style="text-align:center;margin:20px 0;padding:10px;border-top:1px solid #eee;">
                <p style="font-size:11px;color:#666;margin:0;">
                    <a href="https://{domain}/api/track/view/{tracking_id}" style="color:#666;text-decoration:none;">
                        View this email in your browser
                    </a>
                </p>
                {tracking_elements['interactive']}
            </div>
            
            {tracking_elements['javascript']}
            '''
            
            # Create email message
            message = MIMEMultipart('alternative')
            message['to'] = lead.email
            message['subject'] = email_subject
            
            # Set From header using sending profile or default
            if sending_profile:
                from_name = sending_profile.sender_name
                from_email = sending_profile.sender_email
                message['from'] = f"{from_name} <{from_email}>"
            else:
                # Use default sender from environment
                default_name = os.getenv('SENDER_NAME', 'Alex Johnson')
                default_email = os.getenv('SENDER_EMAIL', 'alex@growthsolutions.com')
                message['from'] = f"{default_name} <{default_email}>"
            
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
    
    def send_sequence_email(self, lead, step, tracking_id, sending_profile=None):
        """Send sequence step email via Gmail API"""
        if not self.gmail_service:
            print("Gmail service not available")
            return False
        
        try:
            # Generate personalized content and subject for sequence step
            email_data = self.generate_personalized_email_and_subject(
                lead, step.ai_prompt or f"Write a professional follow-up email. This is step {step.step_number} in our sequence.", sending_profile
            )
            email_body = email_data['content']
            email_subject = email_data['subject']
            
            # Modern multi-signal tracking
            domain = os.getenv("DOMAIN", "localhost:8000")
            
            from modern_tracking_service import modern_tracker
            tracking_elements = modern_tracker.generate_multi_signal_tracking(tracking_id, domain)
            
            # Replace any links with tracked versions
            import re
            def replace_links(match):
                original_url = match.group(1)
                tracked_url = f"https://{domain}/api/track/click/{tracking_id}?url={original_url}"
                return f'href="{tracked_url}"'
            
            # First, convert plain URLs to clickable links, then track all links
            # Convert plain URLs to anchor tags (excluding already linked URLs)
            url_pattern = r'(?<!href=["\'\'`])(?<!src=["\'\'`])(https?://[^\s<>"]+)'
            email_body = re.sub(url_pattern, r'<a href="\1">\1</a>', email_body)
            
            # Track all links in the email (both existing and newly created)
            email_body_with_tracking = re.sub(r'href="([^"]+)"', replace_links, email_body)
            
            # Add multi-signal tracking elements
            email_body_with_tracking += f'''
            <!-- Multi-Signal Open Tracking -->
            {tracking_elements['primary']}
            {tracking_elements['secondary']}
            {tracking_elements['content']}
            
            <!-- View in browser link with tracking -->
            <div style="text-align:center;margin:20px 0;padding:10px;border-top:1px solid #eee;">
                <p style="font-size:11px;color:#666;margin:0;">
                    <a href="https://{domain}/api/track/view/{tracking_id}" style="color:#666;text-decoration:none;">
                        View this email in your browser
                    </a>
                </p>
                {tracking_elements['interactive']}
            </div>
            
            {tracking_elements['javascript']}
            '''
            
            # Create email message
            message = MIMEMultipart('alternative')
            message['to'] = lead.email
            message['subject'] = email_subject
            
            # Set From header using sending profile or default
            if sending_profile:
                from_name = sending_profile.sender_name
                from_email = sending_profile.sender_email
                message['from'] = f"{from_name} <{from_email}>"
            else:
                # Use default sender from environment
                default_name = os.getenv('SENDER_NAME', 'Alex Johnson')
                default_email = os.getenv('SENDER_EMAIL', 'alex@growthsolutions.com')
                message['from'] = f"{default_name} <{default_email}>"
            
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
            
            print(f"Sequence email sent successfully to {lead.email}. Message ID: {result['id']}")
            return True
            
        except HttpError as error:
            print(f"Gmail API error sending sequence email to {lead.email}: {error}")
            return False
        except Exception as e:
            print(f"Failed to send sequence email to {lead.email}: {e}")
            return False
    
    def generate_sequence_email_with_context(self, lead, current_step, sending_profile=None, previous_emails=None):
        """Generate personalized sequence email with context from previous emails"""
        try:
            # Get sender information
            sender_name = sending_profile.sender_name if sending_profile else os.getenv('SENDER_NAME', 'Alex Johnson')
            sender_title = sending_profile.sender_title if sending_profile else os.getenv('SENDER_TITLE', 'Business Development Manager')
            sender_company = sending_profile.sender_company if sending_profile else os.getenv('SENDER_COMPANY', 'Growth Solutions Inc.')
            sender_email = sending_profile.sender_email if sending_profile else os.getenv('SENDER_EMAIL', 'alex@growthsolutions.com')
            sender_phone = sending_profile.sender_phone if sending_profile else os.getenv('SENDER_PHONE', '')
            sender_contact = f"{sender_email}" + (f" | {sender_phone}" if sender_phone else "")
            sender_signature = sending_profile.signature if sending_profile and sending_profile.signature else f"{sender_name}<br>{sender_title}<br>{sender_company}<br>{sender_contact}"

            # Prepare lead data
            lead_name = (lead.first_name or '').strip()
            lead_company = (lead.company or '').strip()
            lead_title = (getattr(lead, 'title', '') or '').strip()
            lead_industry = (getattr(lead, 'industry', '') or '').strip()
            lead_website = (getattr(lead, 'website', '') or '').strip()

            # Build context from previous emails if this is not the first step
            context_section = ""
            if current_step.step_number > 1 and previous_emails:
                context_section = "\n\nPREVIOUS EMAIL CONTEXT:\n"
                for i, prev_email in enumerate(previous_emails, 1):
                    context_section += f"Email #{i} Subject: {prev_email.get('subject', 'N/A')}\n"
                    context_section += f"Email #{i} Content: {prev_email.get('content', 'N/A')}\n\n"
                context_section += "IMPORTANT: This is a follow-up email. Reference the previous emails naturally and provide new value. The recipient hasn't responded to previous emails yet.\n"

            prompt = f"""You are a professional email copywriter. Write a personalized email for step {current_step.step_number} of an email sequence.

LEAD DETAILS:
- Name: {lead_name if lead_name else 'there'}
- Company: {lead_company if lead_company else 'their company'}
- Title: {lead_title}
- Industry: {lead_industry}
- Website: {lead_website}

SENDER DETAILS:
- Name: {sender_name}
- Title: {sender_title}
- Company: {sender_company}

{context_section}

STEP INSTRUCTIONS: {current_step.ai_prompt}

FORMAT REQUIREMENTS:
1. Start with "SUBJECT: [your subject line]"
2. Then write the email body
3. Keep it professional and personalized
4. Use HTML formatting for the body
5. End with the sender signature

SUBJECT LINE GUIDELINES:
- Be specific and relevant to {lead_company if lead_company else 'their business'}
- For follow-ups, reference previous contact subtly or try a different angle
- Make it personal and intriguing
- Keep under 60 characters

EMAIL BODY GUIDELINES:
- Address {lead_name if lead_name else 'them'} personally
- Reference {lead_company if lead_company else 'their company'} specifically
{"- This is a follow-up email - reference previous emails naturally" if current_step.step_number > 1 else "- This is the first email in the sequence"}
- Keep it concise (under 120 words)
- Include a clear call-to-action
- Be professional but conversational
- Provide value and avoid being pushy

End with this signature:
{sender_signature}"""

            response = self.openai_client.chat.completions.create(
                model="gpt-4",
                messages=[{"role": "user", "content": prompt}],
                max_tokens=500,
                temperature=0.7
            )
            
            response_text = response.choices[0].message.content.strip()
            
            # Extract subject line and content
            import re
            subject_match = re.search(r'^SUBJECT:\s*(.+?)$', response_text, re.MULTILINE | re.IGNORECASE)
            
            if subject_match:
                subject_line = subject_match.group(1).strip()
                email_content = re.sub(r'^SUBJECT:\s*.+?$', '', response_text, flags=re.MULTILINE | re.IGNORECASE).strip()
            else:
                lines = response_text.split('\n', 1)
                if len(lines) > 1:
                    subject_line = lines[0].replace('SUBJECT:', '').strip()
                    email_content = lines[1].strip()
                else:
                    subject_line = f"Following up on {lead_company if lead_company else 'our conversation'}" if current_step.step_number > 1 else f"Regarding {lead_company if lead_company else 'your business'}"
                    email_content = response_text

            # Clean up subject line
            subject_line = subject_line.replace('"', '').replace("'", '').strip()
            if not subject_line or len(subject_line) < 3:
                subject_line = f"Following up on {lead_company if lead_company else 'our conversation'}" if current_step.step_number > 1 else f"Regarding {lead_company if lead_company else 'your business'}"
            
            # Format email content as HTML
            email_content = email_content.strip()
            if '<p>' not in email_content and '<br>' not in email_content:
                email_content = email_content.replace('\n\n', '\n<p></p>\n')
                email_content = email_content.replace('\n', '<br>\n')
                email_content = f'<p>{email_content}</p>'
            
            # Clean up HTML
            email_content = re.sub(r'<p></p>', '</p><p>', email_content)
            email_content = re.sub(r'<p>\s*<p>', '<p>', email_content)
            email_content = re.sub(r'</p>\s*</p>', '</p>', email_content)
            
            return {
                'subject': subject_line,
                'content': email_content
            }
            
        except Exception as e:
            print(f"Error generating sequence email: {e}")
            # Fallback
            return {
                'subject': f"Following up on {lead.company if lead.company else 'our conversation'}" if current_step.step_number > 1 else f"Regarding {lead.company if lead.company else 'your business'}",
                'content': f"<p>Hi {lead.first_name if lead.first_name else 'there'},</p><p>I wanted to follow up on my previous message.</p><p>Best regards,<br>{sender_name if 'sender_name' in locals() else 'Alex Johnson'}</p>"
            }
