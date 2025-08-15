from sqlalchemy import Column, Integer, String, DateTime, Text, ForeignKey
from datetime import datetime
from .base import Base

class LeadGroup(Base):
    __tablename__ = "lead_groups"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, index=True)
    description = Column(Text)
    color = Column(String, default="#3B82F6")
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow)

class LeadGroupMembership(Base):
    __tablename__ = "lead_group_memberships"
    
    id = Column(Integer, primary_key=True, index=True)
    lead_id = Column(Integer, ForeignKey("leads.id"))
    group_id = Column(Integer, ForeignKey("lead_groups.id"))
    created_at = Column(DateTime, default=datetime.utcnow)