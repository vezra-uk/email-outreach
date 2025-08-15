from pydantic import BaseModel
from typing import Optional
from datetime import datetime

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
    created_at: datetime

    class Config:
        from_attributes = True