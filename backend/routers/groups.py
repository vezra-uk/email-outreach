from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List

from database import get_db
from models.groups import LeadGroup, LeadGroupMembership
from models.lead import Lead
from models.user import User
from schemas.groups import LeadGroupCreate, LeadGroupUpdate, LeadGroupResponse, LeadGroupDetail, GroupMembershipUpdate
from dependencies import get_current_active_user

router = APIRouter(prefix="/groups", tags=["groups"])

@router.get("/", response_model=List[LeadGroupResponse])
def get_groups(db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    groups = db.query(
        LeadGroup,
        func.count(LeadGroupMembership.lead_id).label('lead_count')
    ).outerjoin(
        LeadGroupMembership, LeadGroup.id == LeadGroupMembership.group_id
    ).group_by(LeadGroup.id).all()
    
    return [
        LeadGroupResponse(
            id=group.id,
            name=group.name,
            description=group.description,
            color=group.color,
            lead_count=lead_count,
            created_at=group.created_at
        )
        for group, lead_count in groups
    ]

@router.post("/", response_model=LeadGroupResponse)
def create_group(group: LeadGroupCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    db_group = LeadGroup(**group.dict())
    db.add(db_group)
    db.commit()
    db.refresh(db_group)
    
    return LeadGroupResponse(
        id=db_group.id,
        name=db_group.name,
        description=db_group.description,
        color=db_group.color,
        lead_count=0,
        created_at=db_group.created_at
    )

@router.get("/{group_id}/leads")
def get_group_leads(group_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    leads = db.query(Lead).join(
        LeadGroupMembership, Lead.id == LeadGroupMembership.lead_id
    ).filter(LeadGroupMembership.group_id == group_id).all()
    
    return leads