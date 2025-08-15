# backend/schemas/auth.py
from pydantic import BaseModel, EmailStr
from typing import Optional
from datetime import datetime

class UserBase(BaseModel):
    email: EmailStr
    username: str
    full_name: Optional[str] = None
    is_active: bool = True

class UserCreate(UserBase):
    password: str

class UserUpdate(BaseModel):
    email: Optional[EmailStr] = None
    username: Optional[str] = None
    full_name: Optional[str] = None
    is_active: Optional[bool] = None
    password: Optional[str] = None

class UserInDB(UserBase):
    id: int
    is_superuser: bool
    created_at: datetime
    updated_at: Optional[datetime]
    
    class Config:
        from_attributes = True

class User(UserInDB):
    pass

class Token(BaseModel):
    access_token: str
    token_type: str
    expires_in: int

class TokenData(BaseModel):
    email: Optional[str] = None

class LoginRequest(BaseModel):
    email: EmailStr
    password: str

class APIKeyBase(BaseModel):
    name: str

class APIKeyCreate(APIKeyBase):
    pass

class APIKey(APIKeyBase):
    id: int
    key: str
    user_id: int
    is_active: bool
    created_at: datetime
    last_used_at: Optional[datetime]
    
    class Config:
        from_attributes = True

class APIKeyPublic(BaseModel):
    id: int
    name: str
    is_active: bool
    created_at: datetime
    last_used_at: Optional[datetime]
    key_preview: str  # Only show first 8 characters
    
    class Config:
        from_attributes = True