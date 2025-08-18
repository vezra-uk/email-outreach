from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

class CampaignStepCreate(BaseModel):
    step_number: int
    name: str
    subject: Optional[str] = None
    template: Optional[str] = None
    ai_prompt: Optional[str] = None
    delay_days: int = 0
    delay_hours: int = 0
    include_previous_emails: bool = False

class CampaignStepResponse(BaseModel):
    id: int
    step_number: int
    name: str
    subject: Optional[str] = None
    template: Optional[str] = None
    ai_prompt: Optional[str] = None
    delay_days: int
    delay_hours: int
    is_active: bool
    include_previous_emails: bool = False
    
    class Config:
        from_attributes = True

class CampaignCreate(BaseModel):
    name: str
    description: Optional[str] = None
    sending_profile_id: Optional[int] = None
    steps: List[CampaignStepCreate]

class CampaignResponse(BaseModel):
    id: int
    name: str
    description: Optional[str]
    status: str
    created_at: datetime
    
    class Config:
        from_attributes = True

class CampaignDetail(BaseModel):
    id: int
    name: str
    description: Optional[str]
    status: str
    created_at: datetime
    steps: List[CampaignStepResponse]
    
    class Config:
        from_attributes = True

class LeadCampaignCreate(BaseModel):
    lead_ids: List[int]
    sequence_id: int

class LeadCampaignResponse(BaseModel):
    id: int
    lead_id: int
    sequence_id: int
    current_step: int
    status: str
    started_at: datetime
    next_send_at: Optional[datetime]
    last_sent_at: Optional[datetime]
    
    class Config:
        from_attributes = True

class CampaignProgress(BaseModel):
    total_leads: int
    active_leads: int
    completed_leads: int
    stopped_leads: int
    replied_leads: int
    avg_step: float

class CampaignProgressSummary(BaseModel):
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