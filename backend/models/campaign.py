from sqlalchemy import Column, Integer, String, DateTime, Text, ForeignKey, Numeric, Date
from datetime import datetime
from .base import Base

class Campaign(Base):
    __tablename__ = "campaigns"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String)
    subject = Column(String)
    template = Column(Text)
    ai_prompt = Column(Text)
    sending_profile_id = Column(Integer, ForeignKey("sending_profiles.id"))
    status = Column(String, default="active")
    daily_limit = Column(Integer, default=30)
    total_leads = Column(Integer, default=0)
    emails_sent = Column(Integer, default=0)
    emails_opened = Column(Integer, default=0)
    emails_clicked = Column(Integer, default=0)
    completion_rate = Column(Numeric(5,2), default=0.00)
    last_sent_at = Column(DateTime)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow)

class CampaignLead(Base):
    __tablename__ = "campaign_leads"
    
    id = Column(Integer, primary_key=True, index=True)
    campaign_id = Column(Integer, ForeignKey("campaigns.id"))
    lead_id = Column(Integer, ForeignKey("leads.id"))
    status = Column(String, default="pending")
    sent_at = Column(DateTime)
    opens = Column(Integer, default=0)
    clicks = Column(Integer, default=0)
    tracking_pixel_id = Column(String, unique=True)
    created_at = Column(DateTime, default=datetime.utcnow)

class DailyStats(Base):
    __tablename__ = "daily_stats"
    
    date = Column(Date, primary_key=True)
    emails_sent = Column(Integer, default=0)
    emails_opened = Column(Integer, default=0)
    links_clicked = Column(Integer, default=0)
    updated_at = Column(DateTime, default=datetime.utcnow)