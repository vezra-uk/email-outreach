from fastapi import APIRouter, HTTPException, Depends, BackgroundTasks
from sqlalchemy.orm import Session
from sqlalchemy import text
from typing import List
from datetime import date, datetime
import os

from database import get_db
from models import Campaign, CampaignLead, DailyStats, Lead
from models.user import User
from schemas.campaign import CampaignCreate, CampaignProgress, CampaignResponse, CampaignDetail
from dependencies import get_current_active_user

router = APIRouter(prefix="/campaigns", tags=["campaigns"])

@router.get("/", response_model=List[CampaignResponse])
def get_campaigns(db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    campaigns = db.query(Campaign).all()
    return campaigns

@router.get("/progress", response_model=List[CampaignProgress])
def get_campaigns_progress(db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    query = text("""
        SELECT 
            c.id,
            c.name,
            c.subject,
            c.status,
            c.created_at,
            COALESCE(COUNT(cl.id), 0) as total_leads,
            COALESCE(COUNT(CASE WHEN cl.status = 'sent' THEN 1 END), 0) as emails_sent,
            COALESCE(COUNT(CASE WHEN cl.opens > 0 THEN 1 END), 0) as emails_opened,
            COALESCE(COUNT(CASE WHEN cl.clicks > 0 THEN 1 END), 0) as emails_clicked,
            CASE 
                WHEN COUNT(cl.id) > 0 THEN 
                    ROUND((COUNT(CASE WHEN cl.status = 'sent' THEN 1 END) * 100.0 / COUNT(cl.id)), 2)
                ELSE 0 
            END as completion_rate,
            CASE 
                WHEN COUNT(CASE WHEN cl.status = 'sent' THEN 1 END) > 0 THEN 
                    ROUND((COUNT(CASE WHEN cl.opens > 0 THEN 1 END) * 100.0 / COUNT(CASE WHEN cl.status = 'sent' THEN 1 END)), 2)
                ELSE 0 
            END as open_rate,
            CASE 
                WHEN COUNT(CASE WHEN cl.status = 'sent' THEN 1 END) > 0 THEN 
                    ROUND((COUNT(CASE WHEN cl.clicks > 0 THEN 1 END) * 100.0 / COUNT(CASE WHEN cl.status = 'sent' THEN 1 END)), 2)
                ELSE 0 
            END as click_rate,
            MAX(cl.sent_at) as last_sent_at
        FROM campaigns c
        LEFT JOIN campaign_leads cl ON c.id = cl.campaign_id
        WHERE c.status = 'active'
        GROUP BY c.id, c.name, c.subject, c.status, c.created_at
        ORDER BY c.created_at DESC
    """)
    
    result = db.execute(query).fetchall()
    
    campaigns = []
    for row in result:
        campaigns.append(CampaignProgress(
            id=row.id,
            name=row.name,
            subject=row.subject,
            status=row.status,
            total_leads=row.total_leads,
            emails_sent=row.emails_sent,
            emails_opened=row.emails_opened,
            emails_clicked=row.emails_clicked,
            completion_rate=float(row.completion_rate),
            open_rate=float(row.open_rate),
            click_rate=float(row.click_rate),
            last_sent_at=row.last_sent_at,
            created_at=row.created_at
        ))
    
    return campaigns

@router.get("/{campaign_id}/detail", response_model=CampaignDetail)
def get_campaign_detail(campaign_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    campaign = db.query(Campaign).filter(Campaign.id == campaign_id).first()
    if not campaign:
        raise HTTPException(status_code=404, detail="Campaign not found")
    
    query = text("""
        SELECT 
            COALESCE(COUNT(cl.id), 0) as total_leads,
            COALESCE(COUNT(CASE WHEN cl.status = 'sent' THEN 1 END), 0) as emails_sent,
            COALESCE(COUNT(CASE WHEN cl.opens > 0 THEN 1 END), 0) as emails_opened,
            COALESCE(COUNT(CASE WHEN cl.clicks > 0 THEN 1 END), 0) as emails_clicked,
            CASE 
                WHEN COUNT(cl.id) > 0 THEN 
                    ROUND((COUNT(CASE WHEN cl.status = 'sent' THEN 1 END) * 100.0 / COUNT(cl.id)), 2)
                ELSE 0 
            END as completion_rate,
            CASE 
                WHEN COUNT(CASE WHEN cl.status = 'sent' THEN 1 END) > 0 THEN 
                    ROUND((COUNT(CASE WHEN cl.opens > 0 THEN 1 END) * 100.0 / COUNT(CASE WHEN cl.status = 'sent' THEN 1 END)), 2)
                ELSE 0 
            END as open_rate,
            CASE 
                WHEN COUNT(CASE WHEN cl.status = 'sent' THEN 1 END) > 0 THEN 
                    ROUND((COUNT(CASE WHEN cl.clicks > 0 THEN 1 END) * 100.0 / COUNT(CASE WHEN cl.status = 'sent' THEN 1 END)), 2)
                ELSE 0 
            END as click_rate,
            MAX(cl.sent_at) as last_sent_at
        FROM campaign_leads cl
        WHERE cl.campaign_id = :campaign_id
    """)
    
    stats = db.execute(query, {"campaign_id": campaign_id}).fetchone()
    
    leads_query = text("""
        SELECT 
            l.id,
            l.email,
            l.first_name,
            l.last_name,
            l.company,
            l.title,
            cl.status as campaign_status,
            cl.sent_at,
            cl.opens,
            cl.clicks
        FROM campaign_leads cl
        JOIN leads l ON cl.lead_id = l.id
        WHERE cl.campaign_id = :campaign_id
        ORDER BY cl.created_at DESC
    """)
    
    leads_result = db.execute(leads_query, {"campaign_id": campaign_id}).fetchall()
    
    leads = []
    for lead in leads_result:
        leads.append({
            "id": lead.id,
            "email": lead.email,
            "first_name": lead.first_name,
            "last_name": lead.last_name,
            "company": lead.company,
            "title": lead.title,
            "status": lead.campaign_status,
            "sent_at": lead.sent_at,
            "opens": lead.opens,
            "clicks": lead.clicks
        })
    
    return CampaignDetail(
        id=campaign.id,
        name=campaign.name,
        subject=campaign.subject,
        template=campaign.template,
        ai_prompt=campaign.ai_prompt,
        status=campaign.status,
        total_leads=stats.total_leads if stats else 0,
        emails_sent=stats.emails_sent if stats else 0,
        emails_opened=stats.emails_opened if stats else 0,
        emails_clicked=stats.emails_clicked if stats else 0,
        completion_rate=float(stats.completion_rate) if stats else 0,
        open_rate=float(stats.open_rate) if stats else 0,
        click_rate=float(stats.click_rate) if stats else 0,
        last_sent_at=stats.last_sent_at if stats else None,
        created_at=campaign.created_at,
        leads=leads
    )

@router.post("/", response_model=CampaignResponse)
def create_campaign(campaign: CampaignCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    db_campaign = Campaign(
        name=campaign.name,
        subject="",
        template="",
        ai_prompt=campaign.ai_prompt,
        sending_profile_id=campaign.sending_profile_id,
        total_leads=len(campaign.lead_ids)
    )
    db.add(db_campaign)
    db.flush()
    
    for lead_id in campaign.lead_ids:
        campaign_lead = CampaignLead(
            campaign_id=db_campaign.id,
            lead_id=lead_id,
            tracking_pixel_id=f"pixel_{db_campaign.id}_{lead_id}"
        )
        db.add(campaign_lead)
    
    db.commit()
    db.refresh(db_campaign)
    return db_campaign

@router.post("/send")
def trigger_email_send(background_tasks: BackgroundTasks, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    from services.email_batch import send_email_batch
    
    today = date.today()
    daily_stats = db.query(DailyStats).filter(DailyStats.date == today).first()
    if not daily_stats:
        daily_stats = DailyStats(date=today)
        db.add(daily_stats)
        db.commit()
    
    daily_limit = int(os.getenv("DAILY_EMAIL_LIMIT", 30))
    if daily_stats.emails_sent >= daily_limit:
        raise HTTPException(status_code=400, detail="Daily email limit reached")
    
    background_tasks.add_task(send_email_batch)
    return {"message": "Email sending started", "remaining": daily_limit - daily_stats.emails_sent}

@router.put("/{campaign_id}/complete")
def mark_campaign_complete(campaign_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    """Mark a campaign as completed"""
    campaign = db.query(Campaign).filter(Campaign.id == campaign_id).first()
    if not campaign:
        raise HTTPException(status_code=404, detail="Campaign not found")
    
    campaign.status = "completed"
    campaign.updated_at = datetime.utcnow()
    db.commit()
    
    return {"message": "Campaign marked as completed"}

@router.put("/{campaign_id}/archive")
def archive_campaign(campaign_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    """Archive a campaign (removes from main dashboard)"""
    campaign = db.query(Campaign).filter(Campaign.id == campaign_id).first()
    if not campaign:
        raise HTTPException(status_code=404, detail="Campaign not found")
    
    campaign.status = "archived"
    campaign.updated_at = datetime.utcnow()
    db.commit()
    
    return {"message": "Campaign archived"}

@router.put("/{campaign_id}/reactivate")
def reactivate_campaign(campaign_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    """Reactivate a completed or archived campaign"""
    campaign = db.query(Campaign).filter(Campaign.id == campaign_id).first()
    if not campaign:
        raise HTTPException(status_code=404, detail="Campaign not found")
    
    campaign.status = "active"
    campaign.updated_at = datetime.utcnow()
    db.commit()
    
    return {"message": "Campaign reactivated"}

@router.get("/archived", response_model=List[CampaignProgress])
def get_archived_campaigns(db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    """Get completed and archived campaigns"""
    query = text("""
        SELECT 
            c.id,
            c.name,
            c.subject,
            c.status,
            c.created_at,
            COALESCE(COUNT(cl.id), 0) as total_leads,
            COALESCE(COUNT(CASE WHEN cl.status = 'sent' THEN 1 END), 0) as emails_sent,
            COALESCE(COUNT(CASE WHEN cl.opens > 0 THEN 1 END), 0) as emails_opened,
            COALESCE(COUNT(CASE WHEN cl.clicks > 0 THEN 1 END), 0) as emails_clicked,
            CASE 
                WHEN COUNT(cl.id) > 0 THEN 
                    ROUND((COUNT(CASE WHEN cl.status = 'sent' THEN 1 END) * 100.0 / COUNT(cl.id)), 2)
                ELSE 0 
            END as completion_rate,
            CASE 
                WHEN COUNT(CASE WHEN cl.status = 'sent' THEN 1 END) > 0 THEN 
                    ROUND((COUNT(CASE WHEN cl.opens > 0 THEN 1 END) * 100.0 / COUNT(CASE WHEN cl.status = 'sent' THEN 1 END)), 2)
                ELSE 0 
            END as open_rate,
            CASE 
                WHEN COUNT(CASE WHEN cl.status = 'sent' THEN 1 END) > 0 THEN 
                    ROUND((COUNT(CASE WHEN cl.clicks > 0 THEN 1 END) * 100.0 / COUNT(CASE WHEN cl.status = 'sent' THEN 1 END)), 2)
                ELSE 0 
            END as click_rate,
            MAX(cl.sent_at) as last_sent_at
        FROM campaigns c
        LEFT JOIN campaign_leads cl ON c.id = cl.campaign_id
        WHERE c.status IN ('completed', 'archived')
        GROUP BY c.id, c.name, c.subject, c.status, c.created_at
        ORDER BY c.updated_at DESC
    """)
    
    result = db.execute(query).fetchall()
    
    campaigns = []
    for row in result:
        campaigns.append(CampaignProgress(
            id=row.id,
            name=row.name,
            subject=row.subject,
            status=row.status,
            created_at=row.created_at,
            total_leads=row.total_leads,
            emails_sent=row.emails_sent,
            emails_opened=row.emails_opened,
            emails_clicked=row.emails_clicked,
            completion_rate=row.completion_rate,
            open_rate=row.open_rate,
            click_rate=row.click_rate,
            last_sent_at=row.last_sent_at
        ))
    
    return campaigns