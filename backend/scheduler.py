# backend/scheduler.py
import schedule
import time
import os
from datetime import date
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from main import DailyStats, Campaign, Lead, LeadCampaign, SendingProfile
from services.email_batch import send_sequence_batch
from email_service import EmailService
import logging

from logger_config import get_logger

logger = get_logger(__name__)

class EmailScheduler:
    def __init__(self):
        logger.info("Initializing EmailScheduler")
        
        try:
            self.engine = create_engine(os.getenv("DATABASE_URL"))
            self.SessionLocal = sessionmaker(bind=self.engine)
            self.email_service = EmailService()
            self.daily_limit = int(os.getenv("DAILY_EMAIL_LIMIT", 30))
            
            logger.info("EmailScheduler initialized successfully", extra={
                "daily_limit": self.daily_limit,
                "has_database_url": bool(os.getenv("DATABASE_URL"))
            })
        except Exception as e:
            logger.error("Failed to initialize EmailScheduler", extra={
                "error": str(e),
                "error_type": type(e).__name__
            }, exc_info=True)
            raise
    
    def send_daily_batch(self):
        """Send daily batch of emails"""
        logger.info("Starting daily email batch job")
        
        db = self.SessionLocal()
        
        try:
            today = date.today()
            daily_stats = db.query(DailyStats).filter(DailyStats.date == today).first()
            
            if not daily_stats:
                daily_stats = DailyStats(date=today, emails_sent=0)
                db.add(daily_stats)
                db.commit()
                logger.info("Created new daily stats record", extra={"date": today.isoformat()})
            
            logger.info("Daily batch processing started", extra={
                "date": today.isoformat(),
                "emails_already_sent": daily_stats.emails_sent,
                "daily_limit": self.daily_limit,
                "remaining_quota": self.daily_limit - daily_stats.emails_sent
            })
            
            if daily_stats.emails_sent >= self.daily_limit:
                print(f"Daily limit of {self.daily_limit} emails already reached")
                return
            
            remaining = self.daily_limit - daily_stats.emails_sent
            
            # Note: Campaign functionality removed - all emails now sent via sequences
            print("All email sending now handled by sequence batch processing")
            
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
        
        # Schedule sequence emails every 5 minutes
        schedule.every(5).minutes.do(self.send_sequence_emails)
        
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