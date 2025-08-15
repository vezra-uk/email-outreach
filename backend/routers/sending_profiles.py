from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List

from database import get_db
from models.sending_profile import SendingProfile
from models import User
from schemas.sending_profile import SendingProfileCreate, SendingProfileUpdate, SendingProfileResponse
from dependencies import get_current_active_user

router = APIRouter(prefix="/sending-profiles", tags=["sending-profiles"])

@router.get("/", response_model=List[SendingProfileResponse])
def get_sending_profiles(db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    profiles = db.query(SendingProfile).all()
    return profiles

@router.get("/{profile_id}", response_model=SendingProfileResponse)
def get_sending_profile(profile_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    profile = db.query(SendingProfile).filter(SendingProfile.id == profile_id).first()
    if not profile:
        raise HTTPException(status_code=404, detail="Sending profile not found")
    return profile

@router.post("/", response_model=SendingProfileResponse)
def create_sending_profile(profile: SendingProfileCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    db_profile = SendingProfile(**profile.dict())
    db.add(db_profile)
    db.commit()
    db.refresh(db_profile)
    return db_profile

@router.put("/{profile_id}", response_model=SendingProfileResponse)
def update_sending_profile(profile_id: int, profile_update: SendingProfileUpdate, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    db_profile = db.query(SendingProfile).filter(SendingProfile.id == profile_id).first()
    if not db_profile:
        raise HTTPException(status_code=404, detail="Sending profile not found")
    
    update_data = profile_update.dict(exclude_unset=True)
    for field, value in update_data.items():
        setattr(db_profile, field, value)
    
    db.commit()
    db.refresh(db_profile)
    return db_profile

@router.delete("/{profile_id}")
def delete_sending_profile(profile_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    db_profile = db.query(SendingProfile).filter(SendingProfile.id == profile_id).first()
    if not db_profile:
        raise HTTPException(status_code=404, detail="Sending profile not found")
    
    db.delete(db_profile)
    db.commit()
    return {"message": "Sending profile deleted successfully"}