from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List

from database import get_db
from models.sending_profile import SendingProfile
from models import User
from schemas.sending_profile import SendingProfileCreate, SendingProfileUpdate, SendingProfileResponse
from dependencies import get_current_active_user

router = APIRouter(prefix="/sending-profiles", tags=["sending-profiles"])

@router.get("", response_model=List[SendingProfileResponse])
def get_sending_profiles(db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    profiles = db.query(SendingProfile).all()
    return profiles

@router.get("/{profile_id}", response_model=SendingProfileResponse)
def get_sending_profile(profile_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    profile = db.query(SendingProfile).filter(SendingProfile.id == profile_id).first()
    if not profile:
        raise HTTPException(status_code=404, detail="Sending profile not found")
    return profile

@router.post("", response_model=SendingProfileResponse)
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
    from models import Campaign, EmailSequence
    
    db_profile = db.query(SendingProfile).filter(SendingProfile.id == profile_id).first()
    if not db_profile:
        raise HTTPException(status_code=404, detail="Sending profile not found")
    
    # Check for campaigns using this sending profile (any status)
    campaigns_count = db.query(Campaign).filter(
        Campaign.sending_profile_id == profile_id
    ).count()
    
    if campaigns_count > 0:
        # Get campaign details for better error message
        campaigns = db.query(Campaign).filter(Campaign.sending_profile_id == profile_id).limit(5).all()
        campaign_info = [f"{c.name} (status: {c.status})" for c in campaigns]
        raise HTTPException(
            status_code=400, 
            detail=f"Cannot delete sending profile. It is used in {campaigns_count} campaign(s): {', '.join(campaign_info[:3])}{'...' if len(campaign_info) > 3 else ''}. Change their sending profile first or delete them."
        )
    
    # Check for sequences using this sending profile (any status)
    sequences_count = db.query(EmailSequence).filter(
        EmailSequence.sending_profile_id == profile_id
    ).count()
    
    if sequences_count > 0:
        # Get sequence details for better error message
        sequences = db.query(EmailSequence).filter(EmailSequence.sending_profile_id == profile_id).limit(5).all()
        sequence_info = [f"{s.name} (status: {s.status})" for s in sequences]
        raise HTTPException(
            status_code=400,
            detail=f"Cannot delete sending profile. It is used in {sequences_count} sequence(s): {', '.join(sequence_info[:3])}{'...' if len(sequence_info) > 3 else ''}. Change their sending profile first or delete them."
        )
    
    db.delete(db_profile)
    db.commit()
    return {"message": "Sending profile deleted successfully"}

@router.post("/{profile_id}/remove-from-archived")
def remove_from_archived_campaigns_and_sequences(profile_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    """Remove sending profile from archived campaigns and sequences to allow deletion"""
    from models import Campaign, EmailSequence
    
    # Update archived campaigns to use NULL sending profile
    archived_campaigns = db.query(Campaign).filter(
        Campaign.sending_profile_id == profile_id,
        Campaign.status.in_(["archived", "completed"])
    ).all()
    
    for campaign in archived_campaigns:
        campaign.sending_profile_id = None
    
    # Update inactive sequences to use NULL sending profile  
    inactive_sequences = db.query(EmailSequence).filter(
        EmailSequence.sending_profile_id == profile_id,
        EmailSequence.status.in_(["inactive", "completed"])
    ).all()
    
    for sequence in inactive_sequences:
        sequence.sending_profile_id = None
    
    db.commit()
    
    return {
        "message": f"Removed sending profile from {len(archived_campaigns)} archived campaigns and {len(inactive_sequences)} inactive sequences",
        "campaigns_updated": len(archived_campaigns),
        "sequences_updated": len(inactive_sequences)
    }