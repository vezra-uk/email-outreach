from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List
from datetime import datetime, timedelta

from database import get_db
from models import Campaign, CampaignStep, LeadCampaign, Lead, User, CampaignEmail
from dependencies import get_current_active_user
from schemas.campaign import (
    CampaignCreate, 
    CampaignResponse, 
    CampaignDetail,
    CampaignStepResponse,
    LeadCampaignCreate,
    LeadCampaignResponse,
    CampaignProgress,
    CampaignProgressSummary
)

router = APIRouter(prefix="/campaigns", tags=["campaigns"])

@router.post("", response_model=CampaignResponse)
def create_campaign(campaign: CampaignCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    """Create a new email campaign with steps"""
    try:
        # Create the campaign
        db_campaign = Campaign(
            name=campaign.name,
            description=campaign.description,
            sending_profile_id=campaign.sending_profile_id,
            status="active"
        )
        db.add(db_campaign)
        db.flush()  # Get the ID without committing
        
        # Create the steps
        for step_data in campaign.steps:
            db_step = CampaignStep(
                sequence_id=db_campaign.id,
                step_number=step_data.step_number,
                name=step_data.name,
                subject=step_data.subject,
                template=step_data.template,
                ai_prompt=step_data.ai_prompt,
                delay_days=step_data.delay_days,
                delay_hours=step_data.delay_hours,
                is_active=True,
                include_previous_emails=step_data.include_previous_emails
            )
            db.add(db_step)
        
        db.commit()
        db.refresh(db_campaign)
        return db_campaign
        
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=f"Failed to create campaign: {str(e)}")

@router.get("", response_model=List[CampaignResponse])
def get_campaigns(db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    """Get all email campaigns"""
    campaigns = db.query(Campaign).filter(Campaign.status == "active").all()
    return campaigns

@router.get("/{campaign_id}", response_model=CampaignDetail)
def get_campaign(campaign_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    """Get a specific campaign with its steps"""
    campaign = db.query(Campaign).filter(Campaign.id == campaign_id).first()
    if not campaign:
        raise HTTPException(status_code=404, detail="Sequence not found")
    
    steps = db.query(CampaignStep).filter(
        CampaignStep.sequence_id == campaign_id
    ).order_by(CampaignStep.step_number).all()
    
    return CampaignDetail(
        id=campaign.id,
        name=campaign.name,
        description=campaign.description,
        status=campaign.status,
        created_at=campaign.created_at,
        steps=[CampaignStepResponse.from_orm(step) for step in steps]
    )

@router.put("/{campaign_id}", response_model=CampaignResponse)
def update_campaign(campaign_id: int, campaign: CampaignCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    """Update an existing campaign"""
    db_campaign = db.query(Campaign).filter(Campaign.id == campaign_id).first()
    if not db_campaign:
        raise HTTPException(status_code=404, detail="Sequence not found")
    
    try:
        # Update campaign details
        db_campaign.name = campaign.name
        db_campaign.description = campaign.description
        db_campaign.sending_profile_id = campaign.sending_profile_id
        db_campaign.updated_at = datetime.utcnow()
        
        # Delete existing steps
        db.query(CampaignStep).filter(CampaignStep.sequence_id == campaign_id).delete()
        
        # Create new steps
        for step_data in campaign.steps:
            db_step = CampaignStep(
                sequence_id=campaign_id,
                step_number=step_data.step_number,
                name=step_data.name,
                subject=step_data.subject,
                template=step_data.template,
                ai_prompt=step_data.ai_prompt,
                delay_days=step_data.delay_days,
                delay_hours=step_data.delay_hours,
                is_active=True,
                include_previous_emails=step_data.include_previous_emails
            )
            db.add(db_step)
        
        db.commit()
        db.refresh(db_campaign)
        return db_campaign
        
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=f"Failed to update campaign: {str(e)}")

@router.delete("/{campaign_id}")
def delete_campaign(campaign_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    """Delete a campaign (soft delete by setting status to inactive)"""
    campaign = db.query(Campaign).filter(Campaign.id == campaign_id).first()
    if not campaign:
        raise HTTPException(status_code=404, detail="Sequence not found")
    
    # Check if campaign has active lead campaigns
    active_leads = db.query(LeadCampaign).filter(
        LeadCampaign.sequence_id == campaign_id,
        LeadCampaign.status == "active"
    ).count()
    
    if active_leads > 0:
        raise HTTPException(
            status_code=400, 
            detail=f"Cannot delete campaign. It has {active_leads} active lead(s) enrolled."
        )
    
    campaign.status = "inactive"
    campaign.updated_at = datetime.utcnow()
    db.commit()
    
    return {"message": "Sequence deleted successfully"}

@router.post("/{campaign_id}/leads", response_model=List[LeadCampaignResponse])
def enroll_leads_in_campaign(
    campaign_id: int, 
    enrollment: LeadCampaignCreate, 
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Enroll leads in a campaign"""
    # Verify campaign exists
    campaign = db.query(Campaign).filter(Campaign.id == campaign_id).first()
    if not campaign:
        raise HTTPException(status_code=404, detail="Sequence not found")
    
    # Verify all leads exist
    leads = db.query(Lead).filter(Lead.id.in_(enrollment.lead_ids)).all()
    if len(leads) != len(enrollment.lead_ids):
        raise HTTPException(status_code=400, detail="Some leads not found")
    
    created_enrollments = []
    
    try:
        for lead_id in enrollment.lead_ids:
            # Check if lead is already enrolled in this campaign
            existing = db.query(LeadCampaign).filter(
                LeadCampaign.lead_id == lead_id,
                LeadCampaign.sequence_id == campaign_id,
                LeadCampaign.status == "active"
            ).first()
            
            if existing:
                continue  # Skip already enrolled leads
            
            # Get first step to calculate next_send_at
            first_step = db.query(CampaignStep).filter(
                CampaignStep.sequence_id == campaign_id,
                CampaignStep.step_number == 1
            ).first()
            
            next_send_at = datetime.utcnow()
            if first_step:
                next_send_at += timedelta(days=first_step.delay_days, hours=first_step.delay_hours)
            
            lead_campaign = LeadCampaign(
                lead_id=lead_id,
                sequence_id=campaign_id,
                current_step=1,
                status="active",
                started_at=datetime.utcnow(),
                next_send_at=next_send_at
            )
            db.add(lead_campaign)
            created_enrollments.append(lead_campaign)
        
        db.commit()
        
        # Refresh all created enrollments
        for enrollment in created_enrollments:
            db.refresh(enrollment)
        
        return created_enrollments
        
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=f"Failed to enroll leads: {str(e)}")

@router.get("/{campaign_id}/leads", response_model=List[LeadCampaignResponse])
def get_campaign_leads(campaign_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    """Get all leads enrolled in a campaign"""
    lead_campaigns = db.query(LeadCampaign).filter(
        LeadCampaign.sequence_id == campaign_id
    ).all()
    return lead_campaigns

@router.get("/all/progress", response_model=List[CampaignProgressSummary])
def get_campaigns_progress(db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    """Get progress stats for all campaigns (for dashboard)"""
    try:
        campaigns = db.query(Campaign).filter(Campaign.status == "active").all()
        print(f"Found {len(campaigns)} active campaigns")
        
        progress_data = []
        for campaign in campaigns:
            try:
                # Get total leads enrolled - ensure it's an integer
                total_leads = db.query(LeadCampaign).filter(
                    LeadCampaign.sequence_id == campaign.id
                ).count() or 0
                
                # Get total leads who have received emails - ensure it's an integer
                emails_sent = db.query(func.distinct(CampaignEmail.lead_sequence_id)).filter(
                    CampaignEmail.lead_sequence_id.in_(
                        db.query(LeadCampaign.id).filter(LeadCampaign.sequence_id == campaign.id)
                    ),
                    CampaignEmail.status == "sent"
                ).count() or 0
                
                # Get total leads who opened and clicked - ensure they're integers
                emails_opened = db.query(func.distinct(CampaignEmail.lead_sequence_id)).filter(
                    CampaignEmail.lead_sequence_id.in_(
                        db.query(LeadCampaign.id).filter(LeadCampaign.sequence_id == campaign.id)
                    ),
                    CampaignEmail.opens > 0
                ).count() or 0
                
                emails_clicked = db.query(func.distinct(CampaignEmail.lead_sequence_id)).filter(
                    CampaignEmail.lead_sequence_id.in_(
                        db.query(LeadCampaign.id).filter(LeadCampaign.sequence_id == campaign.id)
                    ),
                    CampaignEmail.clicks > 0
                ).count() or 0
                
                # Calculate rates
                completion_rate = (emails_sent / total_leads * 100) if total_leads > 0 else 0
                open_rate = (emails_opened / emails_sent * 100) if emails_sent > 0 else 0
                click_rate = (emails_clicked / emails_sent * 100) if emails_sent > 0 else 0
                
                # Get last sent at
                last_sent_email = db.query(CampaignEmail).filter(
                    CampaignEmail.lead_sequence_id.in_(
                        db.query(LeadCampaign.id).filter(LeadCampaign.sequence_id == campaign.id)
                    ),
                    CampaignEmail.status == "sent"
                ).order_by(CampaignEmail.sent_at.desc()).first()
                
                last_sent_at = last_sent_email.sent_at if last_sent_email else None
                
                # Get first step subject as the campaign "subject"
                first_step = db.query(CampaignStep).filter(
                    CampaignStep.sequence_id == campaign.id,
                    CampaignStep.step_number == 1
                ).first()
                subject = first_step.subject if first_step and first_step.subject else "No subject"
                
                # Ensure all fields have safe values and correct types
                safe_name = campaign.name or "Unnamed Campaign"
                safe_status = campaign.status or "unknown"
                safe_id = int(campaign.id) if campaign.id is not None else 0
                safe_total_leads = int(total_leads) if total_leads is not None else 0
                safe_emails_sent = int(emails_sent) if emails_sent is not None else 0
                safe_emails_opened = int(emails_opened) if emails_opened is not None else 0
                safe_emails_clicked = int(emails_clicked) if emails_clicked is not None else 0
                
                # Also ensure created_at is valid
                safe_created_at = campaign.created_at if campaign.created_at is not None else datetime.utcnow()
                
                print(f"Campaign {safe_id}: leads={safe_total_leads}, sent={safe_emails_sent}, opened={safe_emails_opened}")
                
                progress_data.append(CampaignProgressSummary(
                    id=safe_id,
                    name=safe_name,
                    subject=subject,
                    status=safe_status,
                    total_leads=safe_total_leads,
                    emails_sent=safe_emails_sent,
                    emails_opened=safe_emails_opened,
                    emails_clicked=safe_emails_clicked,
                    completion_rate=float(completion_rate),
                    open_rate=float(open_rate),
                    click_rate=float(click_rate),
                    last_sent_at=last_sent_at,
                    created_at=safe_created_at
                ))
            except Exception as e:
                print(f"Error processing campaign {campaign.id}: {e}")
                continue
        
        return progress_data
    
    except Exception as e:
        print(f"Error in get_campaigns_progress: {e}")
        return []

@router.get("/{campaign_id}/progress", response_model=CampaignProgress)
def get_campaign_progress(campaign_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    """Get progress stats for a specific campaign"""
    # Verify campaign exists
    campaign = db.query(Campaign).filter(Campaign.id == campaign_id).first()
    if not campaign:
        raise HTTPException(status_code=404, detail="Sequence not found")
    
    # Get all lead campaigns for this campaign
    lead_campaigns = db.query(LeadCampaign).filter(
        LeadCampaign.sequence_id == campaign_id
    ).all()
    
    total_leads = len(lead_campaigns)
    active_leads = sum(1 for ls in lead_campaigns if ls.status == "active")
    completed_leads = sum(1 for ls in lead_campaigns if ls.status == "completed")
    stopped_leads = sum(1 for ls in lead_campaigns if ls.status == "stopped")
    replied_leads = sum(1 for ls in lead_campaigns if ls.status == "replied")
    
    # Calculate average step
    avg_step = 0.0
    if lead_campaigns:
        total_steps = sum(ls.current_step for ls in lead_campaigns)
        avg_step = total_steps / len(lead_campaigns)
    
    return CampaignProgress(
        total_leads=total_leads,
        active_leads=active_leads,
        completed_leads=completed_leads,
        stopped_leads=stopped_leads,
        replied_leads=replied_leads,
        avg_step=avg_step
    )

@router.delete("/{campaign_id}/leads/{lead_id}")
def remove_lead_from_campaign(campaign_id: int, lead_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    """Remove a lead from a campaign"""
    lead_campaign = db.query(LeadCampaign).filter(
        LeadCampaign.sequence_id == campaign_id,
        LeadCampaign.lead_id == lead_id,
        LeadCampaign.status == "active"
    ).first()
    
    if not lead_campaign:
        raise HTTPException(status_code=404, detail="Lead campaign enrollment not found")
    
    lead_campaign.status = "stopped"
    lead_campaign.stop_reason = "manually_removed"
    lead_campaign.updated_at = datetime.utcnow()
    db.commit()
    
    return {"message": "Lead removed from campaign"}

@router.post("/send")
def trigger_campaign_emails(db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    """Trigger sending of all due campaign emails"""
    from services.email_batch import send_campaign_batch
    
    try:
        result = send_campaign_batch()
        return {
            "message": "Sequence emails processed successfully",
            "emails_sent": result.get("emails_sent", 0),
            "campaigns_processed": result.get("campaigns_processed", 0),
            "errors": result.get("errors", [])
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to send campaign emails: {str(e)}")