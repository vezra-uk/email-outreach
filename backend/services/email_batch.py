from datetime import datetime, date, timedelta
from sqlalchemy.orm import Session
import os
import uuid

from database import SessionLocal
from models import (
    Campaign, Lead, DailyStats,
    LeadCampaign, CampaignStep, CampaignEmail, EmailReply,
    SendingProfile
)

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
        now = datetime.utcnow()
        due_sequences = db.query(LeadCampaign).filter(
            LeadCampaign.status == "active",
            LeadCampaign.next_send_at <= now
        ).limit(50).all()
        
        sequences_processed = len(due_sequences)
        
        for lead_seq in due_sequences:
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
                
                reply_check = db.query(EmailReply).filter(
                    EmailReply.lead_id == lead.id,
                    EmailReply.sequence_id == sequence.id
                ).first()
                
                if reply_check:
                    lead_seq.status = "stopped"
                    lead_seq.stop_reason = "replied"
                    continue
                
                tracking_id = f"seq_{lead_seq.id}_{current_step.id}_{uuid.uuid4().hex[:8]}"
                sequence_email = CampaignEmail(
                    lead_sequence_id=lead_seq.id,
                    step_id=current_step.id,
                    tracking_pixel_id=tracking_id
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
                
                success, email_data = email_service.send_sequence_email_with_context(
                    lead=lead,
                    step=current_step,
                    tracking_id=tracking_id,
                    sending_profile=sending_profile,
                    previous_emails=previous_emails
                )
                
                if success and email_data:
                    email_subject, email_content = email_data
                    sequence_email.status = "sent"
                    sequence_email.sent_at = now
                    sequence_email.subject = email_subject
                    sequence_email.content = email_content
                    
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
                    
                else:
                    sequence_email.status = "failed"
                    errors.append(f"Failed to send email for lead {lead_seq.lead_id}")
                    
            except Exception as e:
                error_msg = f"Failed to send sequence email for lead {lead_seq.lead_id}: {e}"
                print(error_msg)
                errors.append(error_msg)
        
        db.commit()
        
        return {
            "emails_sent": emails_sent,
            "sequences_processed": sequences_processed,
            "errors": errors
        }
        
    finally:
        db.close()