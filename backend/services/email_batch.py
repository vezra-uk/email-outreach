from datetime import datetime, date, timedelta
from sqlalchemy.orm import Session
import os
import uuid
import time
import random

from database import SessionLocal
from models import (
    Campaign, Lead, DailyStats,
    LeadCampaign, CampaignStep, CampaignEmail, EmailReply,
    SendingProfile
)

def send_campaign_batch():
    """Send campaign emails using the same generation method as preview"""
    return send_sequence_batch()

def send_email_batch():
    """Legacy function - now redirects to sequence batch since campaigns are sequences"""
    return send_sequence_batch()

def send_sequence_batch():
    """Background task to send sequence emails that are due"""
    from email_service import EmailService
    
    db = SessionLocal()
    email_service = EmailService()
    
    emails_sent = 0
    sequences_processed = 0
    errors = []
    
    try:
        # Check daily limit first
        today = date.today()
        daily_stats = db.query(DailyStats).filter(DailyStats.date == today).first()
        if not daily_stats:
            daily_stats = DailyStats(date=today, emails_sent=0)
            db.add(daily_stats)
            db.commit()
        
        daily_limit = int(os.getenv("DAILY_EMAIL_LIMIT", 30))
        remaining_quota = daily_limit - daily_stats.emails_sent
        
        if remaining_quota <= 0:
            print(f"Daily limit of {daily_limit} emails already reached ({daily_stats.emails_sent} sent)")
            return {"emails_sent": 0, "sequences_processed": 0, "errors": ["Daily limit reached"]}
        
        now = datetime.utcnow()
        due_sequences = db.query(LeadCampaign).filter(
            LeadCampaign.status == "active",
            LeadCampaign.next_send_at <= now
        ).order_by(LeadCampaign.next_send_at.asc()).limit(min(remaining_quota, 50)).all()
        
        sequences_processed = len(due_sequences)
        
        # Limit to smaller batches to mimic human sending patterns (max 10 per batch)
        max_batch_size = min(10, remaining_quota)
        if len(due_sequences) > max_batch_size:
            due_sequences = due_sequences[:max_batch_size]
            sequences_processed = len(due_sequences)
            print(f"Limiting batch to {max_batch_size} emails to mimic human sending patterns")
        
        # Sequences are already ordered by next_send_at (oldest first) to prioritize overdue emails
        print(f"Processing {len(due_sequences)} emails in chronological order (oldest first)")
        
        # Add a small initial random delay to spread out batch processing
        initial_delay = random.randint(5, 60)
        print(f"Starting email batch with {initial_delay} second initial delay...")
        time.sleep(initial_delay)
        
        for i, lead_seq in enumerate(due_sequences):
            try:
                current_step = db.query(CampaignStep).filter(
                    CampaignStep.sequence_id == lead_seq.sequence_id,
                    CampaignStep.step_number == lead_seq.current_step,
                    CampaignStep.is_active == "true"
                ).first()
                
                if not current_step:
                    lead_seq.status = "completed"
                    lead_seq.completed_at = now
                    continue
                
                lead = db.query(Lead).filter(Lead.id == lead_seq.lead_id).first()
                sequence = db.query(Campaign).filter(Campaign.id == lead_seq.sequence_id).first()
                
                if not lead or not sequence or lead.status != "active":
                    continue
                
                # Get sending profile for the sequence
                sending_profile = None
                if sequence.sending_profile_id:
                    sending_profile = db.query(SendingProfile).filter(SendingProfile.id == sequence.sending_profile_id).first()
                
                # Check if sending is allowed based on schedule (skip this email if not)
                is_allowed, schedule_reason = email_service.is_sending_allowed(sending_profile)
                if not is_allowed:
                    print(f"Skipping email for lead {lead_seq.lead_id}: {schedule_reason}")
                    continue
                
                reply_check = db.query(EmailReply).filter(
                    EmailReply.lead_id == lead.id,
                    EmailReply.sequence_id == sequence.id
                ).first()
                
                if reply_check:
                    lead_seq.status = "stopped"
                    lead_seq.stop_reason = "replied"
                    continue
                
                sequence_email = CampaignEmail(
                    lead_sequence_id=lead_seq.id,
                    step_id=current_step.id
                )
                db.add(sequence_email)
                db.flush()
                
                # Check if we should include previous emails for context
                previous_emails = None
                if current_step.include_previous_emails and current_step.step_number > 1:
                    # Get previously sent emails from this sequence for this lead
                    previous_sent_emails = db.query(CampaignEmail).join(CampaignStep).filter(
                        CampaignEmail.lead_sequence_id == lead_seq.id,
                        CampaignEmail.status == "sent",
                        CampaignStep.step_number < current_step.step_number
                    ).order_by(CampaignStep.step_number).all()
                    
                    previous_emails = []
                    for prev_email in previous_sent_emails:
                        if prev_email.subject and prev_email.content:
                            previous_emails.append({
                                'subject': prev_email.subject,
                                'content': prev_email.content
                            })
                
                # Generate tracking ID for this email
                import uuid
                tracking_id = str(uuid.uuid4())
                
                # Use email function with spam checking and tracking
                ai_prompt = current_step.ai_prompt or f"Write a professional email. This is step {current_step.step_number} in our sequence."
                success = email_service.send_email(
                    lead=lead,
                    prompt_text=ai_prompt,
                    tracking_id=tracking_id,
                    sending_profile=sending_profile,
                    previous_emails=previous_emails
                )
                
                # For logging purposes, we'll need to get the email data separately for subject/content
                # Generate email data for storage (without sending)
                email_data = None
                if success:
                    generated_email = email_service._generate_ai_email(
                        lead=lead,
                        prompt_text=ai_prompt,
                        sending_profile=sending_profile,
                        is_followup=True,
                        previous_emails=previous_emails
                    )
                    if generated_email:
                        email_data = (generated_email['subject'], generated_email['content'])
                
                if success and email_data:
                    email_subject, email_content = email_data
                    sequence_email.status = "sent"
                    sequence_email.sent_at = now
                    sequence_email.subject = email_subject
                    sequence_email.content = email_content
                    sequence_email.tracking_pixel_id = tracking_id
                    
                    lead_seq.last_sent_at = now
                    lead_seq.current_step += 1
                    
                    next_step = db.query(CampaignStep).filter(
                        CampaignStep.sequence_id == lead_seq.sequence_id,
                        CampaignStep.step_number == lead_seq.current_step,
                        CampaignStep.is_active == "true"
                    ).first()
                    
                    if next_step:
                        lead_seq.next_send_at = now + timedelta(
                            days=next_step.delay_days,
                            hours=next_step.delay_hours
                        )
                    else:
                        lead_seq.status = "completed"
                        lead_seq.completed_at = now
                        lead_seq.next_send_at = None
                        
                    today = date.today()
                    daily_stats = db.query(DailyStats).filter(DailyStats.date == today).first()
                    if not daily_stats:
                        daily_stats = DailyStats(date=today, emails_sent=0)
                        db.add(daily_stats)
                    daily_stats.emails_sent += 1
                    emails_sent += 1
                    
                    # Add human-like delay between sends to avoid being flagged as bulk mail
                    if i < len(due_sequences) - 1:  # Don't delay after the last email
                        # Progressive delays: shorter early on, longer as we send more
                        base_delay = 30 + (i * 10)  # Increase base delay as we send more
                        variation = random.randint(-15, 60)  # Add random variation
                        delay_seconds = max(15, base_delay + variation)  # Minimum 15 seconds
                        delay_seconds = min(delay_seconds, 400)  # Maximum ~6.5 minutes
                        
                        print(f"Email {i+1}/{len(due_sequences)} sent. Waiting {delay_seconds} seconds before next email...")
                        time.sleep(delay_seconds)
                    
                else:
                    sequence_email.status = "failed"
                    errors.append(f"Failed to send email for lead {lead_seq.lead_id}")
                    
            except Exception as e:
                error_msg = f"Failed to send sequence email for lead {lead_seq.lead_id}: {e}"
                print(error_msg)
                errors.append(error_msg)
        
        db.commit()
        
        print(f"Batch completed: {emails_sent} emails sent, {sequences_processed} sequences processed")
        if emails_sent > 0:
            print(f"Daily stats: {daily_stats.emails_sent}/{daily_limit} emails sent today")
        
        return {
            "emails_sent": emails_sent,
            "sequences_processed": sequences_processed,
            "errors": errors,
            "daily_limit_status": f"{daily_stats.emails_sent}/{daily_limit}"
        }
        
    finally:
        db.close()