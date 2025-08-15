from sqlalchemy import Column, Integer, String, DateTime, Text, ForeignKey, Boolean
from datetime import datetime
from .base import Base

class EmailSequence(Base):
    __tablename__ = "email_sequences"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String)
    description = Column(Text)
    sending_profile_id = Column(Integer, ForeignKey("sending_profiles.id"))
    status = Column(String, default="active")
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow)

class SequenceStep(Base):
    __tablename__ = "sequence_steps"
    
    id = Column(Integer, primary_key=True, index=True)
    sequence_id = Column(Integer, ForeignKey("email_sequences.id"))
    step_number = Column(Integer)
    name = Column(String)
    subject = Column(String)
    template = Column(Text)
    ai_prompt = Column(Text)
    delay_days = Column(Integer, default=0)
    delay_hours = Column(Integer, default=0)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)

class LeadSequence(Base):
    __tablename__ = "lead_sequences"
    
    id = Column(Integer, primary_key=True, index=True)
    lead_id = Column(Integer, ForeignKey("leads.id"))
    sequence_id = Column(Integer, ForeignKey("email_sequences.id"))
    current_step = Column(Integer, default=1)
    status = Column(String, default="active")
    started_at = Column(DateTime, default=datetime.utcnow)
    last_sent_at = Column(DateTime)
    next_send_at = Column(DateTime)
    completed_at = Column(DateTime)
    stop_reason = Column(String)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow)

class SequenceEmail(Base):
    __tablename__ = "sequence_emails"
    
    id = Column(Integer, primary_key=True, index=True)
    lead_sequence_id = Column(Integer, ForeignKey("lead_sequences.id"))
    step_id = Column(Integer, ForeignKey("sequence_steps.id"))
    status = Column(String, default="pending")
    sent_at = Column(DateTime)
    opens = Column(Integer, default=0)
    clicks = Column(Integer, default=0)
    tracking_pixel_id = Column(String, unique=True)
    created_at = Column(DateTime, default=datetime.utcnow)

class EmailReply(Base):
    __tablename__ = "email_replies"
    
    id = Column(Integer, primary_key=True, index=True)
    lead_id = Column(Integer, ForeignKey("leads.id"))
    sequence_id = Column(Integer, ForeignKey("email_sequences.id"))
    reply_email_id = Column(String)
    reply_content = Column(Text)
    reply_date = Column(DateTime)
    created_at = Column(DateTime, default=datetime.utcnow)