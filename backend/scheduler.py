# backend/scheduler.py
import os
# os.environ["DISABLE_FILE_LOGGING"] = "1"  # Commented out to enable file logging

import schedule
import time
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
    
    
    def send_sequence_emails(self):
        """Send sequence emails that are due"""
        logger.info("Starting sequence email batch job")
        
        try:
            send_sequence_batch()
            logger.info("Sequence email batch completed successfully")
        except Exception as e:
            logger.error("Failed to process sequence email batch", extra={
                "error": str(e),
                "error_type": type(e).__name__
            }, exc_info=True)
            raise
    
    def start_scheduler(self):
        """Start the email scheduler"""
        logger.info("Starting email scheduler")
        
        # Schedule sequence emails every 5 minutes
        schedule.every(5).minutes.do(self.send_sequence_emails)
        
        logger.info("Email scheduler configured", extra={
            "sequence_interval_minutes": 5,
            "sleep_interval_seconds": 60
        })
        
        try:
            while True:
                schedule.run_pending()
                time.sleep(60)
        except KeyboardInterrupt:
            logger.info("Email scheduler stopped by user")
        except Exception as e:
            logger.error("Email scheduler crashed", extra={
                "error": str(e),
                "error_type": type(e).__name__
            }, exc_info=True)
            raise

if __name__ == "__main__":
    try:
        logger.info("Email scheduler starting up")
        scheduler = EmailScheduler()
        scheduler.start_scheduler()
    except Exception as e:
        logger.error("Failed to start email scheduler", extra={
            "error": str(e),
            "error_type": type(e).__name__
        }, exc_info=True)
        raise