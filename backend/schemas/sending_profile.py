from pydantic import BaseModel
from typing import Optional
from datetime import datetime, time

class SendingProfileCreate(BaseModel):
    name: str
    sender_name: str
    sender_title: Optional[str] = None
    sender_company: Optional[str] = None
    sender_email: str
    sender_phone: Optional[str] = None
    sender_website: Optional[str] = None
    signature: Optional[str] = None
    is_default: bool = False
    
    # Scheduling fields
    schedule_enabled: bool = True
    schedule_days: str = '1,2,3,4,5'  # Mon-Fri by default
    schedule_time_from: time = time(9, 0)  # 9:00 AM
    schedule_time_to: time = time(17, 0)   # 5:00 PM
    schedule_timezone: str = 'UTC'

class SendingProfileUpdate(BaseModel):
    name: Optional[str] = None
    sender_name: Optional[str] = None
    sender_title: Optional[str] = None
    sender_company: Optional[str] = None
    sender_email: Optional[str] = None
    sender_phone: Optional[str] = None
    sender_website: Optional[str] = None
    signature: Optional[str] = None
    is_default: Optional[bool] = None
    
    # Scheduling fields
    schedule_enabled: Optional[bool] = None
    schedule_days: Optional[str] = None
    schedule_time_from: Optional[time] = None
    schedule_time_to: Optional[time] = None
    schedule_timezone: Optional[str] = None

class SendingProfileResponse(BaseModel):
    id: int
    name: str
    sender_name: str
    sender_title: Optional[str]
    sender_company: Optional[str]
    sender_email: str
    sender_phone: Optional[str]
    sender_website: Optional[str]
    signature: Optional[str]
    is_default: bool
    
    # Scheduling fields
    schedule_enabled: bool
    schedule_days: str
    schedule_time_from: time
    schedule_time_to: time
    schedule_timezone: str
    
    created_at: datetime

    class Config:
        from_attributes = True