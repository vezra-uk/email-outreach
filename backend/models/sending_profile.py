from sqlalchemy import Column, Integer, String, DateTime, Text, Boolean
from datetime import datetime
from .base import Base

class SendingProfile(Base):
    __tablename__ = "sending_profiles"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String)
    sender_name = Column(String)
    sender_title = Column(String)
    sender_company = Column(String)
    sender_email = Column(String)
    sender_phone = Column(String)
    sender_website = Column(String)
    signature = Column(Text)
    is_default = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow)