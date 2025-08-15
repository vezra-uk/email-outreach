from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

class SequenceStepCreate(BaseModel):
    step_number: int
    name: str
    subject: Optional[str] = None
    template: Optional[str] = None
    ai_prompt: Optional[str] = None
    delay_days: int = 0
    delay_hours: int = 0

class SequenceStepResponse(BaseModel):
    id: int
    step_number: int
    name: str
    subject: Optional[str] = None
    template: Optional[str] = None
    ai_prompt: Optional[str] = None
    delay_days: int
    delay_hours: int
    is_active: bool
    
    class Config:
        from_attributes = True

class EmailSequenceCreate(BaseModel):
    name: str
    description: Optional[str] = None
    sending_profile_id: Optional[int] = None
    steps: List[SequenceStepCreate]

class EmailSequenceResponse(BaseModel):
    id: int
    name: str
    description: Optional[str]
    status: str
    created_at: datetime
    
    class Config:
        from_attributes = True

class EmailSequenceDetail(BaseModel):
    id: int
    name: str
    description: Optional[str]
    status: str
    created_at: datetime
    steps: List[SequenceStepResponse]
    
    class Config:
        from_attributes = True

class LeadSequenceCreate(BaseModel):
    lead_ids: List[int]
    sequence_id: int

class LeadSequenceResponse(BaseModel):
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

class SequenceProgress(BaseModel):
    total_leads: int
    active_leads: int
    completed_leads: int
    stopped_leads: int
    replied_leads: int
    avg_step: float