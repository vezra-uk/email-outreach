from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List
from datetime import datetime, timedelta

from database import get_db
from logger_config import get_logger
from models import Campaign, CampaignStep, LeadCampaign, Lead, User, CampaignEmail
from dependencies import get_current_active_user
from schemas.campaign import (
    CampaignCreate, 
    CampaignResponse, 
    CampaignDetail,
    CampaignStepResponse,
    CampaignStepUpdate,
    LeadCampaignCreate,
    LeadCampaignResponse,
    CampaignProgress,
    CampaignProgressSummary,
    EnrolledLeadResponse,
    CampaignWithProgress
)
from schemas.common import PaginationParams, PaginatedResponse

router = APIRouter(prefix="/campaigns", tags=["campaigns"])
logger = get_logger(__name__)

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

@router.get("/paginated", response_model=PaginatedResponse[CampaignWithProgress])
def get_campaigns_paginated(
    pagination: PaginationParams = Depends(),
    db: Session = Depends(get_db), 
    current_user: User = Depends(get_current_active_user)
):
    """Get paginated campaigns with embedded progress data (recommended)"""
    try:
        # Get total count
        total = db.query(Campaign).filter(Campaign.status == "active").count()
        
        # Calculate offset
        offset = (pagination.page - 1) * pagination.per_page
        
        # Get paginated campaigns
        campaigns = (
            db.query(Campaign)
            .filter(Campaign.status == "active")
            .offset(offset)
            .limit(pagination.per_page)
            .all()
        )
        
        # Build campaigns with progress data to avoid N+1 queries
        campaigns_with_progress = []
        for campaign in campaigns:
            # Calculate progress stats efficiently
            total_leads = db.query(LeadCampaign).filter(
                LeadCampaign.sequence_id == campaign.id
            ).count() or 0
            
            emails_sent = db.query(func.distinct(CampaignEmail.lead_sequence_id)).filter(
                CampaignEmail.lead_sequence_id.in_(
                    db.query(LeadCampaign.id).filter(LeadCampaign.sequence_id == campaign.id)
                ),
                CampaignEmail.status == "sent"
            ).count() or 0
            
            emails_opened = db.query(func.distinct(CampaignEmail.lead_sequence_id)).filter(
                CampaignEmail.lead_sequence_id.in_(
                    db.query(LeadCampaign.id).filter(LeadCampaign.sequence_id == campaign.id)
                ),
                CampaignEmail.opens > 0
            ).count() or 0
            
            completion_rate = (emails_sent / total_leads * 100) if total_leads > 0 else 0
            open_rate = (emails_opened / emails_sent * 100) if emails_sent > 0 else 0
            
            campaigns_with_progress.append(CampaignWithProgress(
                id=campaign.id,
                name=campaign.name,
                description=campaign.description,
                status=campaign.status,
                created_at=campaign.created_at,
                total_leads=total_leads,
                emails_sent=emails_sent,
                emails_opened=emails_opened,
                completion_rate=round(completion_rate, 1),
                open_rate=round(open_rate, 1)
            ))
        
        return PaginatedResponse.create(
            items=campaigns_with_progress,
            total=total,
            page=pagination.page,
            per_page=pagination.per_page
        )
        
    except Exception as e:
        logger.error(f"Error fetching paginated campaigns: {e}")
        raise HTTPException(status_code=500, detail="Error fetching campaigns")

@router.get("", response_model=List[CampaignResponse])
def get_campaigns(db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    """Get all email campaigns (legacy endpoint)"""
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

@router.patch("/{campaign_id}/steps/{step_id}", response_model=CampaignStepResponse)
def update_campaign_step(
    campaign_id: int, 
    step_id: int, 
    step_update: CampaignStepUpdate,
    db: Session = Depends(get_db), 
    current_user: User = Depends(get_current_active_user)
):
    """Update a specific campaign step"""
    # Verify campaign exists
    campaign = db.query(Campaign).filter(Campaign.id == campaign_id).first()
    if not campaign:
        raise HTTPException(status_code=404, detail="Campaign not found")
    
    # Verify step exists and belongs to this campaign
    step = db.query(CampaignStep).filter(
        CampaignStep.id == step_id,
        CampaignStep.sequence_id == campaign_id
    ).first()
    if not step:
        raise HTTPException(status_code=404, detail="Campaign step not found")
    
    try:
        # Update only provided fields
        update_data = step_update.dict(exclude_unset=True)
        for field, value in update_data.items():
            setattr(step, field, value)
        
        step.updated_at = datetime.utcnow()
        db.commit()
        db.refresh(step)
        
        logger.info(f"Campaign step {step_id} updated by user {current_user.id}")
        return step
        
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=f"Failed to update campaign step: {str(e)}")

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

@router.get("/{campaign_id}/leads", response_model=List[EnrolledLeadResponse])
def get_campaign_leads(campaign_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    """Get all leads enrolled in a campaign with full lead details"""
    # Verify campaign exists
    campaign = db.query(Campaign).filter(Campaign.id == campaign_id).first()
    if not campaign:
        raise HTTPException(status_code=404, detail="Campaign not found")
    
    # Join LeadCampaign with Lead to get full lead information
    lead_campaigns = db.query(
        LeadCampaign.id,
        LeadCampaign.lead_id,
        LeadCampaign.sequence_id,
        LeadCampaign.current_step,
        LeadCampaign.status,
        LeadCampaign.started_at,
        LeadCampaign.next_send_at,
        LeadCampaign.last_sent_at,
        Lead.first_name,
        Lead.last_name,
        Lead.email,
        Lead.company,
        Lead.status.label('lead_status')
    ).join(Lead, LeadCampaign.lead_id == Lead.id).filter(
        LeadCampaign.sequence_id == campaign_id
    ).all()
    
    # Convert to response objects
    return [
        EnrolledLeadResponse(
            id=lc.id,
            lead_id=lc.lead_id,
            sequence_id=lc.sequence_id,
            current_step=lc.current_step,
            status=lc.status,
            started_at=lc.started_at,
            next_send_at=lc.next_send_at,
            last_sent_at=lc.last_sent_at,
            first_name=lc.first_name,
            last_name=lc.last_name,
            email=lc.email,
            company=lc.company,
            lead_status=lc.lead_status
        ) for lc in lead_campaigns
    ]

@router.get("/all/progress", response_model=List[CampaignProgressSummary])
def get_campaigns_progress(db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    """Get progress stats for all campaigns (for dashboard)"""
    try:
        campaigns = db.query(Campaign).filter(Campaign.status == "active").all()
        logger.debug(f"Found {len(campaigns)} active campaigns", extra={"campaign_count": len(campaigns)})
        
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
                
                logger.debug(f"Campaign {safe_id}: leads={safe_total_leads}, sent={safe_emails_sent}, opened={safe_emails_opened}", extra={
                    "campaign_id": safe_id,
                    "total_leads": safe_total_leads, 
                    "emails_sent": safe_emails_sent,
                    "emails_opened": safe_emails_opened
                })
                
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
                logger.error(f"Error processing campaign {campaign.id}: {e}", extra={
                    "campaign_id": campaign.id,
                    "error": str(e),
                    "error_type": type(e).__name__
                }, exc_info=True)
                continue
        
        return progress_data
    
    except Exception as e:
        logger.error(f"Error in get_campaigns_progress: {e}", extra={
            "error": str(e),
            "error_type": type(e).__name__
        }, exc_info=True)
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

@router.post("/{campaign_id}/pause")
def pause_campaign(campaign_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    """Pause a campaign - no emails will be sent while paused"""
    campaign = db.query(Campaign).filter(Campaign.id == campaign_id).first()
    if not campaign:
        raise HTTPException(status_code=404, detail="Campaign not found")
    
    if campaign.status == "paused":
        raise HTTPException(status_code=400, detail="Campaign is already paused")
    
    if campaign.status != "active":
        raise HTTPException(status_code=400, detail="Can only pause active campaigns")
    
    campaign.status = "paused"
    campaign.updated_at = datetime.utcnow()
    db.commit()
    
    logger.info(f"Campaign {campaign_id} paused by user {current_user.id}")
    return {"message": "Campaign paused successfully", "status": "paused"}

@router.post("/{campaign_id}/unpause")
def unpause_campaign(campaign_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    """Unpause a campaign - resume sending emails"""
    campaign = db.query(Campaign).filter(Campaign.id == campaign_id).first()
    if not campaign:
        raise HTTPException(status_code=404, detail="Campaign not found")
    
    if campaign.status != "paused":
        raise HTTPException(status_code=400, detail="Campaign is not paused")
    
    campaign.status = "active"
    campaign.updated_at = datetime.utcnow()
    db.commit()
    
    logger.info(f"Campaign {campaign_id} unpaused by user {current_user.id}")
    return {"message": "Campaign unpaused successfully", "status": "active"}

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