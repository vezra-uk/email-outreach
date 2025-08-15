from datetime import datetime, date, timedelta
from sqlalchemy.orm import Session
import os
import uuid

from database import SessionLocal
from models import (
    Campaign, Lead, CampaignLead, DailyStats,
    LeadSequence, SequenceStep, SequenceEmail, EmailReply,
    EmailSequence, SendingProfile
)

def send_email_batch():
    """Background task to send email batch"""
    from email_service import EmailService
    
    db = SessionLocal()
    email_service = EmailService()
    
    try:
        today = date.today()
        daily_stats = db.query(DailyStats).filter(DailyStats.date == today).first()
        daily_limit = int(os.getenv("DAILY_EMAIL_LIMIT", 30))
        
        remaining = daily_limit - (daily_stats.emails_sent if daily_stats else 0)
        if remaining <= 0:
            return
        
        pending = db.query(CampaignLead).join(Campaign).join(Lead).filter(
            CampaignLead.status == "pending",
            Campaign.status == "active",
            Lead.status == "active"
        ).limit(remaining).all()
        
        for campaign_lead in pending:
            try:
                campaign = db.query(Campaign).filter(Campaign.id == campaign_lead.campaign_id).first()
                lead = db.query(Lead).filter(Lead.id == campaign_lead.lead_id).first()
                
                sending_profile = None
                if campaign.sending_profile_id:
                    sending_profile = db.query(SendingProfile).filter(SendingProfile.id == campaign.sending_profile_id).first()
                
                success = email_service.send_personalized_email(
                    lead=lead,
                    campaign=campaign,
                    tracking_id=campaign_lead.tracking_pixel_id,
                    sending_profile=sending_profile
                )
                
                if success:
                    campaign_lead.status = "sent"
                    campaign_lead.sent_at = datetime.utcnow()
                    
                    if not daily_stats:
                        daily_stats = DailyStats(date=today, emails_sent=0)
                        db.add(daily_stats)
                    daily_stats.emails_sent += 1
                else:
                    campaign_lead.status = "failed"
                
            except Exception as e:
                print(f"Failed to send email to {lead.email}: {e}")
                campaign_lead.status = "failed"
        
        db.commit()
        
    finally:
        db.close()

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
        due_sequences = db.query(LeadSequence).filter(
            LeadSequence.status == "active",
            LeadSequence.next_send_at <= now
        ).limit(50).all()
        
        sequences_processed = len(due_sequences)
        
        for lead_seq in due_sequences:
            try:
                current_step = db.query(SequenceStep).filter(
                    SequenceStep.sequence_id == lead_seq.sequence_id,
                    SequenceStep.step_number == lead_seq.current_step,
                    SequenceStep.is_active == "true"
                ).first()
                
                if not current_step:
                    lead_seq.status = "completed"
                    lead_seq.completed_at = now
                    continue
                
                lead = db.query(Lead).filter(Lead.id == lead_seq.lead_id).first()
                sequence = db.query(EmailSequence).filter(EmailSequence.id == lead_seq.sequence_id).first()
                
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
                sequence_email = SequenceEmail(
                    lead_sequence_id=lead_seq.id,
                    step_id=current_step.id,
                    tracking_pixel_id=tracking_id
                )
                db.add(sequence_email)
                db.flush()
                
                success = email_service.send_sequence_email(
                    lead=lead,
                    step=current_step,
                    tracking_id=tracking_id,
                    sending_profile=sending_profile
                )
                
                if success:
                    sequence_email.status = "sent"
                    sequence_email.sent_at = now
                    
                    lead_seq.last_sent_at = now
                    lead_seq.current_step += 1
                    
                    next_step = db.query(SequenceStep).filter(
                        SequenceStep.sequence_id == lead_seq.sequence_id,
                        SequenceStep.step_number == lead_seq.current_step,
                        SequenceStep.is_active == "true"
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