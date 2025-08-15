# backend/scheduler.py
import schedule
import time
import os
from datetime import date
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from main import DailyStats, CampaignLead, Campaign, Lead, LeadSequence, SendingProfile, send_sequence_batch
from email_service import EmailService

class EmailScheduler:
    def __init__(self):
        self.engine = create_engine(os.getenv("DATABASE_URL"))
        self.SessionLocal = sessionmaker(bind=self.engine)
        self.email_service = EmailService()
        self.daily_limit = int(os.getenv("DAILY_EMAIL_LIMIT", 30))
    
    def send_daily_batch(self):
        """Send daily batch of emails"""
        db = self.SessionLocal()
        
        try:
            today = date.today()
            daily_stats = db.query(DailyStats).filter(DailyStats.date == today).first()
            
            if not daily_stats:
                daily_stats = DailyStats(date=today, emails_sent=0)
                db.add(daily_stats)
                db.commit()
            
            if daily_stats.emails_sent >= self.daily_limit:
                print(f"Daily limit of {self.daily_limit} emails already reached")
                return
            
            remaining = self.daily_limit - daily_stats.emails_sent
            
            # Get pending campaign leads
            pending = db.query(CampaignLead).join(Campaign).join(Lead).filter(
                CampaignLead.status == "pending",
                Campaign.status == "active",
                Lead.status == "active"
            ).limit(remaining).all()
            
            print(f"Found {len(pending)} pending emails to send")
            
            sent_count = 0
            for campaign_lead in pending:
                try:
                    campaign = db.query(Campaign).filter(Campaign.id == campaign_lead.campaign_id).first()
                    lead = db.query(Lead).filter(Lead.id == campaign_lead.lead_id).first()
                    
                    # Get sending profile if specified
                    sending_profile = None
                    if campaign.sending_profile_id:
                        sending_profile = db.query(SendingProfile).filter(SendingProfile.id == campaign.sending_profile_id).first()
                    
                    success = self.email_service.send_personalized_email(
                        lead=lead,
                        campaign=campaign,
                        tracking_id=campaign_lead.tracking_pixel_id,
                        sending_profile=sending_profile
                    )
                    
                    if success:
                        campaign_lead.status = "sent"
                        campaign_lead.sent_at = datetime.utcnow()
                        sent_count += 1
                    else:
                        campaign_lead.status = "failed"
                        
                except Exception as e:
                    print(f"Failed to send email to {lead.email}: {e}")
                    campaign_lead.status = "failed"
            
            # Update daily stats
            daily_stats.emails_sent += sent_count
            db.commit()
            
            print(f"Successfully sent {sent_count} emails")
            
        finally:
            db.close()
    
    def send_sequence_emails(self):
        """Send sequence emails that are due"""
        try:
            print("Checking for sequence emails to send...")
            send_sequence_batch()
            print("Sequence email batch completed")
        except Exception as e:
            print(f"Error in sequence email batch: {e}")
    
    def start_scheduler(self):
        """Start the email scheduler"""
        print("Starting email scheduler...")
        
        # Schedule daily campaign sends at 9 AM
        schedule.every().day.at("09:00").do(self.send_daily_batch)
        
        # Schedule sequence emails every 30 minutes
        schedule.every(30).minutes.do(self.send_sequence_emails)
        
        # For testing - also allow manual trigger every minute
        # schedule.every(1).minutes.do(self.send_daily_batch)
        # schedule.every(1).minutes.do(self.send_sequence_emails)
        
        while True:
            schedule.run_pending()
            time.sleep(60)

if __name__ == "__main__":
    from datetime import datetime
    scheduler = EmailScheduler()
    scheduler.start_scheduler()