from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
from .lead import LeadResponse

class LeadGroupCreate(BaseModel):
    name: str
    description: Optional[str] = None
    color: Optional[str] = "#3B82F6"

class LeadGroupUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    color: Optional[str] = None

class LeadGroupResponse(BaseModel):
    id: int
    name: str
    description: Optional[str]
    color: str
    lead_count: int
    created_at: datetime
    
    class Config:
        from_attributes = True

class LeadGroupDetail(BaseModel):
    id: int
    name: str
    description: Optional[str]
    color: str
    created_at: datetime
    leads: List[LeadResponse]
    
    class Config:
        from_attributes = True

class GroupMembershipUpdate(BaseModel):
    lead_ids: List[int]