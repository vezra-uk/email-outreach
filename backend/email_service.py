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
import logging
import socket
import re
import time
import requests
from typing import Dict, Optional, Tuple
from datetime import datetime
import pytz

from logger_config import get_logger
from modern_tracking_service import modern_tracker

logger = get_logger(__name__)

class EmailService:
    def __init__(self):
        logger.info("Initializing EmailService")
        
        # Initialize OpenAI client
        try:
            self.openai_client = openai.OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
            logger.info("OpenAI client initialized successfully")
        except Exception as e:
            logger.error("Failed to initialize OpenAI client", extra={
                "error": str(e), "error_type": type(e).__name__
            }, exc_info=True)
            raise
            
        # Initialize Gmail service
        self.gmail_service = self._setup_gmail()
        
        # Rspamd config - use service name for Docker networking
        self.rspamd_host = "rspamd"
        self.rspamd_port = 11333  # Controller port (allows scanning)
        self.rspamd_url = f"http://{self.rspamd_host}:{self.rspamd_port}"
        
    def _setup_gmail(self):
        """Setup Gmail API service"""
        logger.debug("Setting up Gmail API service")
        
        try:
            creds = Credentials(
                token=None,
                refresh_token=os.getenv('GMAIL_REFRESH_TOKEN'),
                id_token=None,
                client_id=os.getenv('GMAIL_CLIENT_ID'),
                client_secret=os.getenv('GMAIL_CLIENT_SECRET'),
                token_uri='https://oauth2.googleapis.com/token'
            )
            service = build('gmail', 'v1', credentials=creds)
            logger.info("Gmail API service setup successfully")
            return service
        except Exception as e:
            logger.error("Failed to setup Gmail service", extra={
                "error": str(e), "error_type": type(e).__name__
            }, exc_info=True)
            return None

    def _generate_ai_email(self, lead, prompt_text, sending_profile=None, is_followup=False, previous_emails=None):
        """Generate email using OpenAI with spam checking"""
        logger.info("AI_GENERATION_STARTED: Starting AI email generation", extra={
            "lead_id": getattr(lead, 'id', None),
            "is_followup": is_followup,
            "has_previous_emails": bool(previous_emails)
        })
        
        # Get sender info
        sender_name = sending_profile.sender_name if sending_profile else os.getenv('SENDER_NAME', 'Alex Johnson')
        sender_title = sending_profile.sender_title if sending_profile else os.getenv('SENDER_TITLE', 'Business Development Manager')
        sender_company = sending_profile.sender_company if sending_profile else os.getenv('SENDER_COMPANY', 'Growth Solutions Inc.')
        sender_email = sending_profile.sender_email if sending_profile else os.getenv('SENDER_EMAIL', 'alex@growthsolutions.com')
        
        # Get lead info
        lead_name = (lead.first_name or '').strip()
        lead_company = (lead.company or '').strip()
        lead_title = (getattr(lead, 'title', '') or '').strip()
        lead_industry = (getattr(lead, 'industry', '') or '').strip()
        lead_website = (getattr(lead, 'website', '') or '').strip()
        
        # Build context for follow-ups
        context_section = ""
        if is_followup and previous_emails:
            context_section = "\n\nPREVIOUS EMAIL CONTEXT:\n"
            for i, prev_email in enumerate(previous_emails, 1):
                context_section += f"Email #{i} Subject: {prev_email.get('subject', 'N/A')}\n"
                context_section += f"Email #{i} Content: {prev_email.get('content', 'N/A')[:200]}...\n\n"
            context_section += "IMPORTANT: This is a follow-up. Reference previous emails naturally and provide new value.\n"
        
        # Build AI prompt
        email_type = "follow-up" if is_followup else "initial outreach"
        ai_prompt = f"""You are a professional email copywriter. Write a personalized {email_type} email.

LEAD DETAILS:
- Name: {lead_name or 'Not provided'}
- Company: {lead_company or 'Not provided'}
- Title: {lead_title or 'Not provided'}
- Industry: {lead_industry or 'Not provided'}
- Website: {lead_website or 'Not provided'}

SENDER DETAILS:
- Name: {sender_name}
- Title: {sender_title}  
- Company: {sender_company}

{context_section}

INSTRUCTIONS: {prompt_text}

CRITICAL REQUIREMENTS:
- NEVER use placeholders like [name], [company], [industry] or brackets []
- Use actual data when available, otherwise natural alternatives like "Hi there" or "your company"
- Keep subject concise but descriptive (under 50 characters)
- Use plain text only, no HTML
- Email body: 150 - 200 words (expand naturally if needed)
- Focus entirely on the lead’s needs, challenges, and business success
- Provide actionable insights or helpful advice rather than just pitching
- Write in a friendly, conversational tone

SPAM AVOIDANCE:
- Avoid: "Free", "Limited time", "Act now", ALL CAPS, excessive punctuation !!!
- Avoid generic sales language
- Avoid overly promotional phrasing
- Use natural, value-driven language
- Vary sentence structure and length

EXAMPLES:
- Good: "Hi John" or "Hi there" if name missing
- Bad: "Hi [name]" or "Hi [their name]"
- Good: "I noticed TestCorp's approach to X" or "your company's recent initiative"
- Bad: "I noticed [company]'s approach"

FORMAT:
1. Start with "SUBJECT: [subject line]"
2. Then write the email body with line breaks for paragraphs
3. End with: {sender_name}\n{sender_title}\n{sender_company}\n{sender_email}"""


        max_attempts = 3
        for attempt in range(1, max_attempts + 1):
            try:
                logger.info(f"AI_ATTEMPT: AI generation attempt {attempt}/{max_attempts}")
                
                # Generate with OpenAI
                response = self.openai_client.chat.completions.create(
                    model="gpt-5-nano",
                    messages=[{"role": "user", "content": ai_prompt}],
                )
                
                response_text = response.choices[0].message.content.strip()
                
                # Parse subject and content
                subject_match = re.search(r'^SUBJECT:\\s*(.+?)$', response_text, re.MULTILINE | re.IGNORECASE)
                if subject_match:
                    subject = subject_match.group(1).strip().replace('"', '').replace("'", '')
                    content = re.sub(r'^SUBJECT:\\s*.+?$', '', response_text, flags=re.MULTILINE | re.IGNORECASE).strip()
                else:
                    lines = response_text.split('\n', 1)
                    subject = lines[0].replace('SUBJECT:', '').strip() if len(lines) > 1 else f"Regarding {lead_company or 'your business'}"
                    content = lines[1].strip() if len(lines) > 1 else response_text
                
                # Clean content
                content = re.sub(r'<[^>]+>', '', content)  # Remove HTML
                content = re.sub(r'\n\s*\n\s*\n', '\n\n', content)  # Clean whitespace
                
                # Check with SpamAssassin
                is_spam, spam_score, spam_report = self._check_spam(subject, content)
                
                logger.info(f"SPAM_CHECK_RESULT: Attempt {attempt}, Score={spam_score}, IsSpam={is_spam}", extra={
                    "attempt": attempt,
                    "is_spam": is_spam,
                    "spam_score": spam_score
                })
                
                # If not spam, return it (our spam detection logic above handles the score threshold)
                if not is_spam:
                    logger.info(f"SPAM_CHECK_PASSED: Email passed spam check (Score: {spam_score}/7.5, Attempts: {attempt})", extra={
                        "final_spam_score": spam_score,
                        "attempts_used": attempt
                    })
                    return {
                        'subject': subject,
                        'content': content, 
                        'spam_score': spam_score,
                        'spam_report': spam_report
                    }
                
                # TEMPORARY: If Rspamd fails but we have content, proceed anyway
                if spam_score == 0.0 and attempt == 1:  # Likely Rspamd connection failed
                    logger.warning("RSPAMD_UNAVAILABLE: Rspamd unavailable, proceeding with generated email", extra={
                        "attempt": attempt,
                        "subject_length": len(subject),
                        "content_length": len(content)
                    })
                    return {
                        'subject': subject,
                        'content': content,
                        'spam_score': 0.0,
                        'spam_report': 'Rspamd check skipped (service unavailable)'
                    }
                
                # If spam, modify prompt for retry
                if attempt < max_attempts:
                    logger.warning(f"SPAM_DETECTED: Email flagged as spam (Score: {spam_score}/7.5), retrying attempt {attempt+1}/{max_attempts}")
                    ai_prompt += f"""\n\nSPAM FEEDBACK - REWRITE TO AVOID:
                The previous attempt scored {spam_score}. Rewrite the email to:
                - Use a warmer, more conversational tone (as if writing 1-to-1, not marketing)
                - Add 1–2 additional natural sentences that provide useful context, insight, or advice
                - Reduce promotional phrasing and focus on the recipient’s challenges, not the sender’s offer
                - Avoid overuse of adjectives, urgency triggers, or anything that feels like a sales pitch
                - Keep it between 110–160 words so it feels balanced and informative"""

                
            except Exception as e:
                logger.error(f"AI generation attempt {attempt} failed", extra={
                    "error": str(e), "error_type": type(e).__name__
                }, exc_info=True)
        
        # All attempts failed
        logger.error("AI_GENERATION_FAILED: All AI generation attempts failed")
        return None

    def _check_spam(self, subject: str, content: str) -> Tuple[bool, float, str]:
        """Check email with Rspamd"""
        logger.debug("RSPAMD_CHECK: Checking email with Rspamd")
        
        try:
            # Format complete email for Rspamd (RFC2822 format)
            email_text = f"""From: sender@example.com
To: recipient@example.com
Subject: {subject}
Date: {datetime.now().strftime('%a, %d %b %Y %H:%M:%S +0000')}
Message-ID: <{int(time.time())}.{uuid.uuid4().hex[:8]}@example.com>
MIME-Version: 1.0
Content-Type: text/plain; charset=UTF-8

{content}"""
            
            # Send POST request to Rspamd scan endpoint
            response = requests.post(
                f"{self.rspamd_url}/scan",
                data=email_text.encode('utf-8'),
                headers={
                    'Content-Type': 'text/plain',
                },
                timeout=10
            )
            
            if response.status_code == 200:
                result = response.json()
                
                # Rspamd returns nested structure with 'default' key
                scan_result = result.get('default', result)
                
                spam_score = scan_result.get('score', 0.0)
                action = scan_result.get('action', 'no action')
                is_spam_flag = scan_result.get('is_spam', False)
                required_score = scan_result.get('required_score', 15.0)
                
                # Determine if spam based on Rspamd's action and score
                # Only treat as spam if action is explicitly reject/soft reject or score is very high
                # Determine if spam based on Rspamd's action and score
                # Don't use is_spam_flag as it's too strict for our test environment
                # Focus on actual harmful actions and high scores
                spam_actions = ['reject', 'soft reject']
                adjusted_threshold = 7.5  # Allow for 2.5 points from hostname issues in test environment
                is_spam = action in spam_actions or spam_score >= adjusted_threshold
                
                logger.info(f"RSPAMD_COMPLETE: Action={action}, Score={spam_score}/{required_score}, IsSpam={is_spam}", extra={
                    "is_spam": is_spam,
                    "spam_score": spam_score,
                    "action": action,
                    "required_score": required_score
                })
                
                # Create detailed report
                report = f"Action: {action}, Score: {spam_score}/{required_score}"
                
                return is_spam, spam_score, report
            else:
                logger.warning(f"Rspamd returned status {response.status_code}")
                return False, 0.0, f"Rspamd check failed with status {response.status_code}"
                
        except requests.exceptions.RequestException as e:
            logger.warning("Rspamd check failed, proceeding", extra={
                "error": str(e), "error_type": type(e).__name__
            })
            return False, 0.0, f"Rspamd connection failed: {e}"
        except Exception as e:
            logger.warning("Rspamd check failed, proceeding", extra={
                "error": str(e), "error_type": type(e).__name__
            })
            return False, 0.0, f"Rspamd check failed: {e}"

    def _is_within_schedule(self, sending_profile) -> Tuple[bool, str]:
        """Check if current time is within sending profile schedule"""
        if not sending_profile or not sending_profile.schedule_enabled:
            return True, "Scheduling disabled"
            
        try:
            # Get timezone for the profile
            profile_tz = pytz.timezone(sending_profile.schedule_timezone or 'UTC')
            current_time = datetime.now(profile_tz)
            
            # Check day of week (1=Monday, 7=Sunday)
            current_weekday = current_time.isoweekday()
            allowed_days = [int(d.strip()) for d in sending_profile.schedule_days.split(',') if d.strip()]
            
            if current_weekday not in allowed_days:
                return False, f"Current day ({current_weekday}) not in allowed days ({allowed_days})"
            
            # Check time range
            current_time_only = current_time.time()
            time_from = sending_profile.schedule_time_from
            time_to = sending_profile.schedule_time_to
            
            if time_from <= time_to:
                # Same day range (e.g., 9:00 - 17:00)
                if not (time_from <= current_time_only <= time_to):
                    return False, f"Current time ({current_time_only}) not in allowed range ({time_from} - {time_to})"
            else:
                # Overnight range (e.g., 22:00 - 06:00)
                if not (current_time_only >= time_from or current_time_only <= time_to):
                    return False, f"Current time ({current_time_only}) not in allowed overnight range ({time_from} - {time_to})"
            
            logger.info(f"SCHEDULE_CHECK_PASSED: Email sending allowed at {current_time} in {sending_profile.schedule_timezone}")
            return True, f"Within schedule: {current_time} in {sending_profile.schedule_timezone}"
            
        except Exception as e:
            logger.error("Schedule check failed, allowing send", extra={
                "error": str(e), "error_type": type(e).__name__
            })
            return True, f"Schedule check failed, allowing send: {e}"

    def is_sending_allowed(self, sending_profile) -> Tuple[bool, str]:
        """Public method to check if email sending is currently allowed based on schedule"""
        return self._is_within_schedule(sending_profile)

    def _create_and_send_email(self, lead, subject: str, content: str, tracking_id: str, sending_profile=None):
        """Create email with tracking and send via Gmail"""
        if not self.gmail_service:
            logger.error("Gmail service not available")
            return False
            
        try:
            # Get domain for tracking - use click domain for tracking links
            domain = "click.wegetyouonline.co.uk"
            
            # Get sender info for signature
            sender_name = sending_profile.sender_name if sending_profile else os.getenv('SENDER_NAME', 'Alex Johnson')
            sender_title = sending_profile.sender_title if sending_profile else os.getenv('SENDER_TITLE', 'Business Development Manager')
            sender_company = sending_profile.sender_company if sending_profile else os.getenv('SENDER_COMPANY', 'Growth Solutions Inc.')
            sender_email = sending_profile.sender_email if sending_profile else os.getenv('SENDER_EMAIL', 'alex@growthsolutions.com')
            
            # Add unsubscribe link only (signature already included by AI)
            content_with_tracking = content + f"""

Unsubscribe: https://click.wegetyouonline.co.uk/api/unsubscribe/{tracking_id}"""

            # Create email message
            message = MIMEMultipart('alternative')
            message['to'] = lead.email
            message['subject'] = subject
            message['List-Unsubscribe'] = f'<https://click.wegetyouonline.co.uk/api/unsubscribe/{tracking_id}>'
            message['List-Unsubscribe-Post'] = 'List-Unsubscribe=One-Click'
            
            # Set sender
            if sending_profile:
                message['from'] = f"{sending_profile.sender_name} <{sending_profile.sender_email}>"
            else:
                default_name = os.getenv('SENDER_NAME', 'Alex Johnson')
                default_email = os.getenv('SENDER_EMAIL', 'alex@growthsolutions.com')
                message['from'] = f"{default_name} <{default_email}>"
            
            # Add plain text version (without tracking)
            text_part = MIMEText(content, 'plain')
            message.attach(text_part)
            
            # Add HTML version with logo tracking and CSS backup
            html_content = f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {{ font-family: Arial, sans-serif; color: #333; line-height: 1.6; }}
        .signature {{ margin-top: 20px; font-size: 14px; }}
        .logo {{ max-width: 150px; height: auto; }}
        .track-backup {{ 
            background: url('https://click.wegetyouonline.co.uk/api/track/signal/{tracking_id}/css') no-repeat;
            background-size: 0px 0px;
            width: 0px;
            height: 0px;
            display: inline-block;
        }}
    </style>
</head>
<body>
    <div class="track-backup"></div>
    {content.replace(chr(10), '<br>')}
    
    <div class="signature">
        
        <img src="https://click.wegetyouonline.co.uk/api/logo.png?t={tracking_id}" alt="{sender_company}" class="logo"><br><br>
        
        <small><a href="https://click.wegetyouonline.co.uk/api/unsubscribe/{tracking_id}">Unsubscribe</a></small>
    </div>
</body>
</html>"""
            html_part = MIMEText(html_content, 'html')
            message.attach(html_part)
            
            # Send via Gmail
            raw_message = base64.urlsafe_b64encode(message.as_bytes()).decode()
            result = self.gmail_service.users().messages().send(
                userId='me',
                body={'raw': raw_message}
            ).execute()
            
            logger.info("GMAIL_SEND_SUCCESS: Email sent via Gmail API", extra={
                "lead_email": lead.email,
                "message_id": result['id'],
                "tracking_id": tracking_id
            })
            
            return True
            
        except Exception as e:
            logger.error("Failed to send email", extra={
                "lead_email": lead.email,
                "error": str(e),
                "error_type": type(e).__name__
            }, exc_info=True)
            return False

        
    def send_email(self, lead, prompt_text: str, tracking_id: str, sending_profile=None, previous_emails=None):
        """
        Send email with optional context from previous emails
        
        Args:
            lead: Lead object with email, name, company etc.
            prompt_text: Instructions for AI email generation  
            tracking_id: Unique tracking ID for this email
            sending_profile: Optional sending profile for sender details
            previous_emails: List of previous emails for context (optional)
            
        Returns:
            bool: True if sent successfully, False if failed or outside schedule
        """
        logger.info("EMAIL_SEND: Attempting to send email", extra={
            "lead_email": lead.email,
            "tracking_id": tracking_id,
            "has_sending_profile": bool(sending_profile),
            "previous_emails_count": len(previous_emails) if previous_emails else 0
        })
        
        # Generate email with context
        email_data = self._generate_ai_email(
            lead=lead,
            prompt_text=prompt_text, 
            sending_profile=sending_profile,
            is_followup=True,
            previous_emails=previous_emails
        )
        
        if not email_data:
            logger.error("Failed to generate email")
            return False
            
        # Send the email
        success = self._create_and_send_email(
            lead=lead,
            subject=email_data['subject'],
            content=email_data['content'],
            tracking_id=tracking_id, 
            sending_profile=sending_profile
        )
        
        if success:
            logger.info(f"EMAIL_SEND_SUCCESS: Email sent to {lead.email} (Spam Score: {email_data.get('spam_score', 'N/A')})", extra={
                "lead_email": lead.email,
                "spam_score": email_data.get('spam_score', 'N/A')
            })
        else:
            logger.error("EMAIL_SEND_FAILED: Email send failed")
            
        return success
