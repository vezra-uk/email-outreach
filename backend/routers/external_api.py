from fastapi import APIRouter, HTTPException, Depends, Header
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime

from database import get_db
from logger_config import get_logger
from models import Lead, User, Campaign, LeadCampaign, APIKey, CampaignStep
from schemas.lead import LeadCreate, LeadResponse
from schemas.campaign import CampaignCreate, CampaignResponse, CampaignDetail, CampaignStepResponse, CampaignStepUpdate, EnrolledLeadResponse
from services.auth import AuthService

router = APIRouter(prefix="/external", tags=["external-api"])
logger = get_logger(__name__)

async def get_current_user_by_api_key(
    x_api_key: str = Header(..., alias="X-API-Key"),
    db: Session = Depends(get_db)
) -> User:
    """Get current user by API key for external API endpoints."""
    user = AuthService.get_user_by_api_key(db, x_api_key)
    if not user:
        logger.warning(f"Invalid API key attempted: {x_api_key[:8]}...")
        raise HTTPException(
            status_code=401,
            detail="Invalid API key"
        )
    
    if not user.is_active:
        raise HTTPException(
            status_code=403,
            detail="User account is inactive"
        )
    
    logger.info(f"External API access by user {user.id}")
    return user

@router.post("/leads", response_model=LeadResponse)
def create_lead_external(
    lead: LeadCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user_by_api_key)
):
    """
    Create a single lead via external API.
    
    Requires X-API-Key header for authentication.
    Optionally assign the lead to a campaign by providing campaign_id.
    """
    try:
        # Check if lead already exists
        existing_lead = db.query(Lead).filter(Lead.email == lead.email).first()
        if existing_lead:
            raise HTTPException(
                status_code=400,
                detail=f"Lead with email {lead.email} already exists"
            )
        
        # Validate campaign if provided
        if lead.campaign_id:
            campaign = db.query(Campaign).filter(
                Campaign.id == lead.campaign_id,
                Campaign.status == "active"
            ).first()
            if not campaign:
                raise HTTPException(
                    status_code=400,
                    detail=f"Campaign {lead.campaign_id} not found or inactive"
                )
        
        # Create the lead (exclude campaign_id from lead creation)
        lead_data = lead.dict()
        campaign_id = lead_data.pop('campaign_id', None)
        db_lead = Lead(**lead_data)
        db.add(db_lead)
        db.commit()
        db.refresh(db_lead)
        
        # If campaign_id provided, enroll lead in campaign
        if campaign_id:
            # Check if lead is already enrolled in this campaign
            existing_enrollment = db.query(LeadCampaign).filter(
                LeadCampaign.lead_id == db_lead.id,
                LeadCampaign.sequence_id == campaign_id,
                LeadCampaign.status == "active"
            ).first()
            
            if not existing_enrollment:
                # Create campaign enrollment with next_send_at set to now
                lead_campaign = LeadCampaign(
                    lead_id=db_lead.id,
                    sequence_id=campaign_id,
                    current_step=1,
                    status="active",
                    started_at=datetime.utcnow(),
                    next_send_at=datetime.utcnow()  # Set to now so it sends in next batch
                )
                db.add(lead_campaign)
                db.commit()
                
                logger.info(f"External API: Lead {db_lead.id} enrolled in campaign {campaign_id} by user {current_user.id}")
        
        logger.info(f"External API: Lead created successfully: {db_lead.id} by user {current_user.id}")
        return db_lead
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"External API: Error creating lead: {str(e)}", extra={
            "user_id": current_user.id,
            "email": lead.email,
            "error": str(e)
        })
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail="Internal server error while creating lead"
        )

@router.post("/leads/bulk")
def create_leads_bulk_external(
    leads: List[LeadCreate],
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user_by_api_key)
):
    """
    Create multiple leads via external API in bulk.
    
    Requires X-API-Key header for authentication.
    Optionally assign leads to campaigns by providing campaign_id in each lead.
    
    Returns:
    - created: Number of leads successfully created
    - errors: List of error messages for leads that failed
    - leads: List of created lead objects
    """
    created_leads = []
    errors = []
    campaign_enrollments = []
    
    try:
        # Validate campaigns upfront if any leads have campaign_id
        campaign_ids = {lead.campaign_id for lead in leads if lead.campaign_id}
        campaigns = {}
        if campaign_ids:
            for campaign_id in campaign_ids:
                campaign = db.query(Campaign).filter(
                    Campaign.id == campaign_id,
                    Campaign.status == "active"
                ).first()
                if not campaign:
                    errors.append(f"Campaign {campaign_id} not found or inactive")
                    continue
                campaigns[campaign_id] = campaign
        
        for lead_data in leads:
            try:
                # Check if lead already exists
                existing_lead = db.query(Lead).filter(Lead.email == lead_data.email).first()
                if existing_lead:
                    errors.append(f"Lead with email {lead_data.email} already exists")
                    continue
                
                # Skip if campaign validation failed
                if lead_data.campaign_id and lead_data.campaign_id not in campaigns:
                    errors.append(f"Skipping lead {lead_data.email} due to invalid campaign {lead_data.campaign_id}")
                    continue
                
                # Create the lead (exclude campaign_id from lead creation)
                lead_dict = lead_data.dict()
                campaign_id = lead_dict.pop('campaign_id', None)
                db_lead = Lead(**lead_dict)
                db.add(db_lead)
                db.flush()
                created_leads.append(db_lead)
                
                # If campaign_id provided, prepare for enrollment
                if campaign_id:
                    campaign_enrollments.append((db_lead.id, campaign_id))
                
            except Exception as e:
                errors.append(f"Error creating lead {lead_data.email}: {str(e)}")
        
        if created_leads:
            db.commit()
            for lead in created_leads:
                db.refresh(lead)
            
            # Now handle campaign enrollments
            for lead_id, campaign_id in campaign_enrollments:
                try:
                    # Check if lead is already enrolled in this campaign
                    existing_enrollment = db.query(LeadCampaign).filter(
                        LeadCampaign.lead_id == lead_id,
                        LeadCampaign.sequence_id == campaign_id,
                        LeadCampaign.status == "active"
                    ).first()
                    
                    if not existing_enrollment:
                        # Create campaign enrollment with next_send_at set to now
                        lead_campaign = LeadCampaign(
                            lead_id=lead_id,
                            sequence_id=campaign_id,
                            current_step=1,
                            status="active",
                            started_at=datetime.utcnow(),
                            next_send_at=datetime.utcnow()  # Set to now so it sends in next batch
                        )
                        db.add(lead_campaign)
                        
                        logger.info(f"External API: Lead {lead_id} enrolled in campaign {campaign_id}")
                except Exception as e:
                    errors.append(f"Error enrolling lead {lead_id} in campaign {campaign_id}: {str(e)}")
            
            # Commit campaign enrollments
            db.commit()
        
        result = {
            "created": len(created_leads),
            "errors": errors,
            "leads": [LeadResponse.from_orm(lead) for lead in created_leads]
        }
        
        logger.info(f"External API: Bulk lead creation completed by user {current_user.id}: {len(created_leads)} created, {len(errors)} errors")
        return result
        
    except Exception as e:
        logger.error(f"External API: Error in bulk lead creation: {str(e)}", extra={
            "user_id": current_user.id,
            "error": str(e)
        })
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail="Internal server error during bulk lead creation"
        )

@router.get("/campaigns", response_model=List[CampaignDetail])
def get_campaigns_external(
    status: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user_by_api_key)
):
    """
    Get list of campaigns with full details including steps.
    
    Requires X-API-Key header for authentication.
    
    Query Parameters:
    - status: Filter by campaign status (active, inactive). Defaults to all.
    """
    try:
        query = db.query(Campaign)
        
        # Filter by status if provided
        if status:
            query = query.filter(Campaign.status == status)
        
        campaigns = query.all()
        
        result = []
        for campaign in campaigns:
            # Get steps for this campaign
            steps = db.query(CampaignStep).filter(
                CampaignStep.sequence_id == campaign.id
            ).order_by(CampaignStep.step_number).all()
            
            campaign_detail = CampaignDetail(
                id=campaign.id,
                name=campaign.name,
                description=campaign.description,
                status=campaign.status,
                created_at=campaign.created_at,
                steps=[CampaignStepResponse.from_orm(step) for step in steps]
            )
            result.append(campaign_detail)
        
        logger.info(f"External API: Campaigns list requested by user {current_user.id} (status: {status}, count: {len(result)})")
        return result
        
    except Exception as e:
        logger.error(f"External API: Error getting campaigns: {str(e)}", extra={
            "user_id": current_user.id,
            "error": str(e)
        })
        raise HTTPException(
            status_code=500,
            detail="Internal server error while fetching campaigns"
        )

@router.get("/campaigns/{campaign_id}", response_model=CampaignDetail)
def get_campaign_external(
    campaign_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user_by_api_key)
):
    """
    Get a single campaign with full details including steps.
    
    Requires X-API-Key header for authentication.
    """
    try:
        campaign = db.query(Campaign).filter(Campaign.id == campaign_id).first()
        if not campaign:
            raise HTTPException(status_code=404, detail="Campaign not found")
        
        # Get steps for this campaign
        steps = db.query(CampaignStep).filter(
            CampaignStep.sequence_id == campaign_id
        ).order_by(CampaignStep.step_number).all()
        
        campaign_detail = CampaignDetail(
            id=campaign.id,
            name=campaign.name,
            description=campaign.description,
            status=campaign.status,
            created_at=campaign.created_at,
            steps=[CampaignStepResponse.from_orm(step) for step in steps]
        )
        
        logger.info(f"External API: Campaign {campaign_id} requested by user {current_user.id}")
        return campaign_detail
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"External API: Error getting campaign {campaign_id}: {str(e)}", extra={
            "user_id": current_user.id,
            "campaign_id": campaign_id,
            "error": str(e)
        })
        raise HTTPException(
            status_code=500,
            detail="Internal server error while fetching campaign"
        )

@router.post("/campaigns", response_model=CampaignResponse)
def create_campaign_external(
    campaign: CampaignCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user_by_api_key)
):
    """
    Create a new campaign with steps.
    
    Requires X-API-Key header for authentication.
    """
    try:
        # Validate sending profile if provided
        if campaign.sending_profile_id:
            from models import SendingProfile
            sending_profile = db.query(SendingProfile).filter(
                SendingProfile.id == campaign.sending_profile_id
            ).first()
            if not sending_profile:
                raise HTTPException(
                    status_code=400,
                    detail=f"Sending profile {campaign.sending_profile_id} not found"
                )
        
        # Validate steps
        if not campaign.steps:
            raise HTTPException(
                status_code=400,
                detail="Campaign must have at least one step"
            )
        
        # Check step numbering
        step_numbers = [step.step_number for step in campaign.steps]
        expected_numbers = list(range(1, len(campaign.steps) + 1))
        if sorted(step_numbers) != expected_numbers:
            raise HTTPException(
                status_code=400,
                detail="Step numbers must be sequential starting from 1"
            )
        
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
        
        logger.info(f"External API: Campaign created successfully: {db_campaign.id} by user {current_user.id}")
        return db_campaign
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"External API: Error creating campaign: {str(e)}", extra={
            "user_id": current_user.id,
            "error": str(e)
        })
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail="Internal server error while creating campaign"
        )

@router.put("/campaigns/{campaign_id}", response_model=CampaignResponse)
def update_campaign_external(
    campaign_id: int,
    campaign: CampaignCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user_by_api_key)
):
    """
    Update an existing campaign and replace all steps.
    
    Requires X-API-Key header for authentication.
    """
    try:
        # Check if campaign exists
        db_campaign = db.query(Campaign).filter(Campaign.id == campaign_id).first()
        if not db_campaign:
            raise HTTPException(status_code=404, detail="Campaign not found")
        
        # Validate sending profile if provided
        if campaign.sending_profile_id:
            from models import SendingProfile
            sending_profile = db.query(SendingProfile).filter(
                SendingProfile.id == campaign.sending_profile_id
            ).first()
            if not sending_profile:
                raise HTTPException(
                    status_code=400,
                    detail=f"Sending profile {campaign.sending_profile_id} not found"
                )
        
        # Validate steps
        if not campaign.steps:
            raise HTTPException(
                status_code=400,
                detail="Campaign must have at least one step"
            )
        
        # Check step numbering
        step_numbers = [step.step_number for step in campaign.steps]
        expected_numbers = list(range(1, len(campaign.steps) + 1))
        if sorted(step_numbers) != expected_numbers:
            raise HTTPException(
                status_code=400,
                detail="Step numbers must be sequential starting from 1"
            )
        
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
        
        logger.info(f"External API: Campaign {campaign_id} updated by user {current_user.id}")
        return db_campaign
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"External API: Error updating campaign {campaign_id}: {str(e)}", extra={
            "user_id": current_user.id,
            "campaign_id": campaign_id,
            "error": str(e)
        })
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail="Internal server error while updating campaign"
        )

@router.delete("/campaigns/{campaign_id}")
def delete_campaign_external(
    campaign_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user_by_api_key)
):
    """
    Delete a campaign (soft delete by setting status to inactive).
    
    Requires X-API-Key header for authentication.
    
    Note: Cannot delete campaigns that have active leads enrolled.
    """
    try:
        # Check if campaign exists
        campaign = db.query(Campaign).filter(Campaign.id == campaign_id).first()
        if not campaign:
            raise HTTPException(status_code=404, detail="Campaign not found")
        
        # Check if campaign has active lead enrollments
        active_leads = db.query(LeadCampaign).filter(
            LeadCampaign.sequence_id == campaign_id,
            LeadCampaign.status == "active"
        ).count()
        
        if active_leads > 0:
            raise HTTPException(
                status_code=400,
                detail=f"Cannot delete campaign. It has {active_leads} active lead(s) enrolled. Remove leads first or wait for campaign completion."
            )
        
        # Soft delete by setting status to inactive
        campaign.status = "inactive"
        campaign.updated_at = datetime.utcnow()
        db.commit()
        
        logger.info(f"External API: Campaign {campaign_id} deleted (soft) by user {current_user.id}")
        return {
            "message": "Campaign deleted successfully",
            "campaign_id": campaign_id,
            "status": "inactive"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"External API: Error deleting campaign {campaign_id}: {str(e)}", extra={
            "user_id": current_user.id,
            "campaign_id": campaign_id,
            "error": str(e)
        })
        raise HTTPException(
            status_code=500,
            detail="Internal server error while deleting campaign"
        )

@router.post("/campaigns/{campaign_id}/pause")
def pause_campaign_external(
    campaign_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user_by_api_key)
):
    """
    Pause a campaign - no emails will be sent while paused.
    
    Requires X-API-Key header for authentication.
    """
    try:
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
        
        logger.info(f"External API: Campaign {campaign_id} paused by user {current_user.id}")
        return {
            "message": "Campaign paused successfully",
            "campaign_id": campaign_id,
            "status": "paused"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"External API: Error pausing campaign {campaign_id}: {str(e)}", extra={
            "user_id": current_user.id,
            "campaign_id": campaign_id,
            "error": str(e)
        })
        raise HTTPException(
            status_code=500,
            detail="Internal server error while pausing campaign"
        )

@router.post("/campaigns/{campaign_id}/unpause")
def unpause_campaign_external(
    campaign_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user_by_api_key)
):
    """
    Unpause a campaign - resume sending emails.
    
    Requires X-API-Key header for authentication.
    """
    try:
        campaign = db.query(Campaign).filter(Campaign.id == campaign_id).first()
        if not campaign:
            raise HTTPException(status_code=404, detail="Campaign not found")
        
        if campaign.status != "paused":
            raise HTTPException(status_code=400, detail="Campaign is not paused")
        
        campaign.status = "active"
        campaign.updated_at = datetime.utcnow()
        db.commit()
        
        logger.info(f"External API: Campaign {campaign_id} unpaused by user {current_user.id}")
        return {
            "message": "Campaign unpaused successfully",
            "campaign_id": campaign_id,
            "status": "active"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"External API: Error unpausing campaign {campaign_id}: {str(e)}", extra={
            "user_id": current_user.id,
            "campaign_id": campaign_id,
            "error": str(e)
        })
        raise HTTPException(
            status_code=500,
            detail="Internal server error while unpausing campaign"
        )

@router.patch("/campaigns/{campaign_id}/steps/{step_id}", response_model=CampaignStepResponse)
def update_campaign_step_external(
    campaign_id: int,
    step_id: int,
    step_update: CampaignStepUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user_by_api_key)
):
    """
    Update a specific campaign step.
    
    Requires X-API-Key header for authentication.
    
    Allows partial updates - only provided fields will be updated.
    """
    try:
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
        
        # Update only provided fields
        update_data = step_update.dict(exclude_unset=True)
        if not update_data:
            raise HTTPException(status_code=400, detail="No fields to update provided")
        
        for field, value in update_data.items():
            setattr(step, field, value)
        
        step.updated_at = datetime.utcnow()
        db.commit()
        db.refresh(step)
        
        logger.info(f"External API: Campaign step {step_id} updated by user {current_user.id}")
        return step
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"External API: Error updating step {step_id} in campaign {campaign_id}: {str(e)}", extra={
            "user_id": current_user.id,
            "campaign_id": campaign_id,
            "step_id": step_id,
            "error": str(e)
        })
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail="Internal server error while updating campaign step"
        )

@router.get("/campaigns/{campaign_id}/leads", response_model=List[EnrolledLeadResponse])
def get_campaign_leads_external(
    campaign_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user_by_api_key)
):
    """
    Get all leads enrolled in a campaign with full lead details.
    
    Requires X-API-Key header for authentication.
    """
    try:
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
        result = [
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
        
        logger.info(f"External API: Campaign {campaign_id} leads requested by user {current_user.id} (count: {len(result)})")
        return result
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"External API: Error getting leads for campaign {campaign_id}: {str(e)}", extra={
            "user_id": current_user.id,
            "campaign_id": campaign_id,
            "error": str(e)
        })
        raise HTTPException(
            status_code=500,
            detail="Internal server error while fetching campaign leads"
        )

@router.get("/status")
def api_status(
    current_user: User = Depends(get_current_user_by_api_key)
):
    """
    Check API status and validate API key.
    
    Requires X-API-Key header for authentication.
    """
    return {
        "status": "active",
        "message": "External API is operational",
        "authenticated_user": current_user.email,
        "timestamp": datetime.utcnow().isoformat()
    }