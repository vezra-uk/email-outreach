from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime

from database import get_db
from models import Lead, User
from schemas.lead import LeadCreate, LeadUpdate, LeadResponse
from dependencies import get_current_active_user

router = APIRouter(prefix="/leads", tags=["leads"])

@router.get("/", response_model=List[LeadResponse])
def get_leads(skip: int = 0, limit: int = 100, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    leads = db.query(Lead).offset(skip).limit(limit).all()
    return leads

@router.get("/industries")
def get_industries(db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    industries = db.query(Lead.industry).filter(
        Lead.industry.isnot(None), 
        Lead.industry != ""
    ).distinct().all()
    return [industry[0] for industry in industries if industry[0]]

@router.get("/filter")
def filter_leads(
    industry: Optional[str] = None,
    company: Optional[str] = None,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    query = db.query(Lead)
    
    if industry:
        query = query.filter(Lead.industry.ilike(f"%{industry}%"))
    
    if company:
        query = query.filter(Lead.company.ilike(f"%{company}%"))
    
    leads = query.offset(skip).limit(limit).all()
    return leads

@router.get("/{lead_id}", response_model=LeadResponse)
def get_lead(lead_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    lead = db.query(Lead).filter(Lead.id == lead_id).first()
    if not lead:
        raise HTTPException(status_code=404, detail="Lead not found")
    return lead

@router.post("/", response_model=LeadResponse)
def create_lead(lead: LeadCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    existing_lead = db.query(Lead).filter(Lead.email == lead.email).first()
    if existing_lead:
        raise HTTPException(status_code=400, detail="Lead with this email already exists")
    
    db_lead = Lead(**lead.dict())
    db.add(db_lead)
    db.commit()
    db.refresh(db_lead)
    return db_lead

@router.put("/{lead_id}", response_model=LeadResponse)
def update_lead(lead_id: int, lead_update: LeadUpdate, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    db_lead = db.query(Lead).filter(Lead.id == lead_id).first()
    if not db_lead:
        raise HTTPException(status_code=404, detail="Lead not found")
    
    if lead_update.email and lead_update.email != db_lead.email:
        existing_lead = db.query(Lead).filter(
            Lead.email == lead_update.email,
            Lead.id != lead_id
        ).first()
        if existing_lead:
            raise HTTPException(status_code=400, detail="Lead with this email already exists")
    
    update_data = lead_update.dict(exclude_unset=True)
    for field, value in update_data.items():
        setattr(db_lead, field, value)
    
    db_lead.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(db_lead)
    return db_lead

@router.delete("/{lead_id}")
def delete_lead(lead_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    from models import CampaignLead, Campaign, LeadSequence
    
    db_lead = db.query(Lead).filter(Lead.id == lead_id).first()
    if not db_lead:
        raise HTTPException(status_code=404, detail="Lead not found")
    
    active_campaigns = db.query(CampaignLead).join(Campaign).filter(
        CampaignLead.lead_id == lead_id,
        Campaign.status == "active"
    ).count()
    
    if active_campaigns > 0:
        raise HTTPException(
            status_code=400, 
            detail=f"Cannot delete lead. It is used in {active_campaigns} active campaign(s). Archive the campaigns first or change their status."
        )
    
    active_sequences = db.query(LeadSequence).filter(
        LeadSequence.lead_id == lead_id,
        LeadSequence.status == "active"
    ).count()
    
    if active_sequences > 0:
        raise HTTPException(
            status_code=400,
            detail=f"Cannot delete lead. It is in {active_sequences} active sequence(s). Remove from sequences first."
        )
    
    db.delete(db_lead)
    db.commit()
    return {"message": "Lead deleted successfully"}

@router.post("/bulk")
def create_leads_bulk(leads: List[LeadCreate], db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    created_leads = []
    errors = []
    
    for lead_data in leads:
        try:
            existing_lead = db.query(Lead).filter(Lead.email == lead_data.email).first()
            if existing_lead:
                errors.append(f"Lead with email {lead_data.email} already exists")
                continue
            
            db_lead = Lead(**lead_data.dict())
            db.add(db_lead)
            db.flush()
            created_leads.append(db_lead)
            
        except Exception as e:
            errors.append(f"Error creating lead {lead_data.email}: {str(e)}")
    
    if created_leads:
        db.commit()
        for lead in created_leads:
            db.refresh(lead)
    
    return {
        "created": len(created_leads),
        "errors": errors,
        "leads": created_leads
    }