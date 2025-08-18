from sqlalchemy import Column, Integer, String, DateTime, Text, ForeignKey, Boolean, Numeric, JSON
from datetime import datetime
from .base import Base

class LinkClick(Base):
    __tablename__ = "link_clicks"
    
    id = Column(Integer, primary_key=True, index=True)
    tracking_id = Column(String, index=True, nullable=False)
    lead_sequence_id = Column(Integer, ForeignKey("lead_sequences.id"), nullable=True)
    sequence_email_id = Column(Integer, ForeignKey("sequence_emails.id"), nullable=True)
    original_url = Column(Text, nullable=False)
    ip_address = Column(String(45))
    user_agent = Column(Text)
    referer = Column(Text)
    clicked_at = Column(DateTime, default=datetime.utcnow)
    created_at = Column(DateTime, default=datetime.utcnow)

class EmailTrackingEvent(Base):
    __tablename__ = "email_tracking_events"
    
    id = Column(Integer, primary_key=True, index=True)
    tracking_id = Column(String, nullable=False, index=True)
    event_type = Column(String, nullable=False)
    signal_type = Column(String, nullable=False)
    ip_address = Column(String)
    user_agent = Column(Text)
    referer = Column(Text)
    timestamp = Column(DateTime, default=datetime.utcnow)
    delay_from_send = Column(Integer)
    is_prefetch = Column(Boolean, default=False)
    confidence_score = Column(Numeric(3, 2), default=0.0)
    event_metadata = Column(JSON)
    created_at = Column(DateTime, default=datetime.utcnow)

class EmailOpenAnalysis(Base):
    __tablename__ = "email_open_analysis"
    
    id = Column(Integer, primary_key=True, index=True)
    tracking_id = Column(String, unique=True, nullable=False)
    lead_sequence_id = Column(Integer, ForeignKey("lead_sequences.id"), nullable=True)
    sequence_email_id = Column(Integer, ForeignKey("sequence_emails.id"), nullable=True)
    total_signals = Column(Integer, default=0)
    confidence_score = Column(Numeric(3, 2), default=0.0)
    is_opened = Column(Boolean, default=False)
    open_method = Column(String)
    first_open_at = Column(DateTime)
    last_activity_at = Column(DateTime)
    unique_ip_count = Column(Integer, default=0)
    prefetch_signals = Column(Integer, default=0)
    human_signals = Column(Integer, default=0)
    analysis_data = Column(JSON)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow)