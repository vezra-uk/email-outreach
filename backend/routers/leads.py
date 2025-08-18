from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime

from database import get_db
from models import Lead, User, CampaignEmail, LeadCampaign, Campaign
from schemas.lead import LeadCreate, LeadUpdate, LeadResponse
from dependencies import get_current_active_user

router = APIRouter(prefix="/leads", tags=["leads"])

@router.get("", response_model=List[LeadResponse])
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

@router.get("/opened-emails")  
def get_leads_who_opened_emails(
    sequence_id: Optional[int] = None,
    campaign_id: Optional[int] = None,
    days: Optional[int] = 30,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    try:
        from datetime import datetime, timedelta
        
        print(f"get_leads_who_opened_emails called with: sequence_id={sequence_id}, campaign_id={campaign_id}, days={days}")
        
        result = []
        cutoff_date = None
        if days:
            cutoff_date = datetime.utcnow() - timedelta(days=days)
        
        # Get sequence opens
        if not campaign_id:  # Include sequences unless specifically asking for campaigns
            sequence_emails = db.query(CampaignEmail).filter(CampaignEmail.opens > 0)
            if cutoff_date:
                sequence_emails = sequence_emails.filter(CampaignEmail.sent_at >= cutoff_date)
            
            for se in sequence_emails.all():
                # Get lead sequence info
                lead_campaign = db.query(LeadCampaign).filter(LeadCampaign.id == se.lead_sequence_id).first()
                if not lead_campaign:
                    continue
                    
                # Filter by sequence_id if specified
                if sequence_id and lead_campaign.sequence_id != sequence_id:
                    continue
                
                # Get lead info
                lead = db.query(Lead).filter(Lead.id == lead_campaign.lead_id).first()
                if not lead:
                    continue
                
                # Get sequence info
                sequence_info = db.query(Campaign).filter(Campaign.id == lead_campaign.sequence_id).first()
                
                # Check if lead already in results
                existing_lead = next((r for r in result if r["id"] == lead.id), None)
                if existing_lead:
                    existing_lead["opens_data"].append({
                        "type": "sequence",
                        "name": sequence_info.name if sequence_info else "Unknown",
                        "id": lead_campaign.sequence_id,
                        "opens": se.opens,
                        "sent_at": se.sent_at.isoformat() if se.sent_at else None,
                        "tracking_id": se.tracking_pixel_id
                    })
                    existing_lead["total_opens"] += se.opens
                else:
                    result.append({
                        "id": lead.id,
                        "email": lead.email,
                        "first_name": lead.first_name,
                        "last_name": lead.last_name,
                        "company": lead.company,
                        "title": lead.title,
                        "industry": lead.industry,
                        "opens_data": [{
                            "type": "sequence",
                            "name": sequence_info.name if sequence_info else "Unknown",
                            "id": lead_campaign.sequence_id,
                            "opens": se.opens,
                            "sent_at": se.sent_at.isoformat() if se.sent_at else None,
                            "tracking_id": se.tracking_pixel_id
                        }],
                        "total_opens": se.opens
                    })
        
        # Note: campaigns are now just sequences, no need for separate campaign opens handling
        
        # Apply pagination
        total = len(result)
        result = result[skip:skip + limit]
        
        return {
            "leads": result,
            "total": total
        }
        
    except Exception as e:
        import traceback
        print(f"Error in get_leads_who_opened_emails: {str(e)}")
        print(f"Traceback: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@router.get("/{lead_id}", response_model=LeadResponse)
def get_lead(lead_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    lead = db.query(Lead).filter(Lead.id == lead_id).first()
    if not lead:
        raise HTTPException(status_code=404, detail="Lead not found")
    return lead

@router.post("", response_model=LeadResponse)
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
    db_lead = db.query(Lead).filter(Lead.id == lead_id).first()
    if not db_lead:
        raise HTTPException(status_code=404, detail="Lead not found")
    
    # Check if lead is in any active campaigns (which are now sequences)
    active_campaigns = db.query(LeadCampaign).join(Campaign).filter(
        LeadCampaign.lead_id == lead_id,
        Campaign.status == "active"
    ).count()
    
    if active_campaigns > 0:
        raise HTTPException(
            status_code=400,
            detail=f"Cannot delete lead. It is in {active_campaigns} active campaign(s). Remove from campaigns first."
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