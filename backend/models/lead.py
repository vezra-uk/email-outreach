from sqlalchemy import Column, Integer, String, DateTime
from datetime import datetime
from .base import Base

class Lead(Base):
    __tablename__ = "leads"
    
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True)
    first_name = Column(String)
    last_name = Column(String)
    company = Column(String)
    title = Column(String)
    phone = Column(String)
    website = Column(String)
    industry = Column(String)
    status = Column(String, default="active")
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow)