from sqlalchemy import Column, Integer, String, DateTime, Text, Boolean, Time
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
    
    # Email scheduling fields
    schedule_enabled = Column(Boolean, default=True)
    schedule_days = Column(String, default='1,2,3,4,5')  # Mon-Fri by default (1=Monday, 7=Sunday)
    schedule_time_from = Column(Time, default=datetime.strptime('09:00', '%H:%M').time())
    schedule_time_to = Column(Time, default=datetime.strptime('17:00', '%H:%M').time())
    schedule_timezone = Column(String, default='UTC')
    
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow)