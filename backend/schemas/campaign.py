from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

class CampaignCreate(BaseModel):
    name: str
    ai_prompt: str
    sending_profile_id: Optional[int] = None
    lead_ids: List[int]

class CampaignProgress(BaseModel):
    id: int
    name: str
    subject: str
    status: str
    total_leads: int
    emails_sent: int
    emails_opened: int
    emails_clicked: int
    completion_rate: float
    open_rate: float
    click_rate: float
    last_sent_at: Optional[datetime]
    created_at: datetime

class CampaignResponse(BaseModel):
    id: int
    name: str
    subject: str
    template: str
    status: str
    total_leads: int
    emails_sent: int
    emails_opened: int
    completion_rate: float
    created_at: datetime

    class Config:
        from_attributes = True

class CampaignDetail(BaseModel):
    id: int
    name: str
    subject: str
    template: str
    ai_prompt: str
    status: str
    total_leads: int
    emails_sent: int
    emails_opened: int
    emails_clicked: int
    completion_rate: float
    open_rate: float
    click_rate: float
    last_sent_at: Optional[datetime]
    created_at: datetime
    leads: List[dict]