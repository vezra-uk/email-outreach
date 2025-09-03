from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import func, and_
from datetime import date, datetime, timedelta
import os

from database import get_db
from models import Lead, Campaign, DailyStats, User, CampaignEmail, EmailTrackingEvent, LinkClick, LeadCampaign
from schemas.dashboard import DashboardStats, TodayActivity, ActivityEvent, TodaysHighlight
from dependencies import get_current_active_user

router = APIRouter(tags=["dashboard"])

@router.get("/dashboard", response_model=DashboardStats)
def get_dashboard_stats(db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    total_leads = db.query(Lead).filter(Lead.status == "active").count()
    active_campaigns = db.query(Campaign).filter(Campaign.status == "active").count()
    
    today = date.today()
    daily_stats = db.query(DailyStats).filter(DailyStats.date == today).first()
    
    emails_sent_today = daily_stats.emails_sent if daily_stats else 0
    emails_opened_today = daily_stats.emails_opened if daily_stats else 0
    
    return DashboardStats(
        total_leads=total_leads,
        emails_sent_today=emails_sent_today,
        emails_opened_today=emails_opened_today,
        active_campaigns=active_campaigns,
        daily_limit=int(os.getenv("DAILY_EMAIL_LIMIT", 30))
    )

@router.get("/dashboard/today-activity", response_model=TodayActivity)
def get_today_activity(db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    today = date.today()
    today_start = datetime.combine(today, datetime.min.time())
    today_end = datetime.combine(today, datetime.max.time())
    
    # Get recent events from today (last 20 events)
    recent_events = []
    
    # Email sends today
    sent_emails = db.query(CampaignEmail).filter(
        and_(CampaignEmail.sent_at >= today_start, CampaignEmail.sent_at <= today_end)
    ).order_by(CampaignEmail.sent_at.desc()).limit(10).all()
    
    for email in sent_emails:
        lead_campaign = db.query(LeadCampaign).filter(LeadCampaign.id == email.lead_sequence_id).first()
        campaign = None
        if lead_campaign:
            campaign = db.query(Campaign).filter(Campaign.id == lead_campaign.sequence_id).first()
        
        recent_events.append(ActivityEvent(
            id=email.id,
            type="email_sent",
            title="Email Sent",
            description=f"Email sent: {email.subject[:50]}...",
            timestamp=email.sent_at,
            campaign_name=campaign.name if campaign else "Unknown Campaign",
            lead_email=None,
            metadata={"subject": email.subject}
        ))
    
    # Email opens today
    opens_today = db.query(EmailTrackingEvent).filter(
        and_(
            EmailTrackingEvent.event_type == "open",
            EmailTrackingEvent.timestamp >= today_start,
            EmailTrackingEvent.timestamp <= today_end
        )
    ).order_by(EmailTrackingEvent.timestamp.desc()).limit(10).all()
    
    for open_event in opens_today:
        recent_events.append(ActivityEvent(
            id=open_event.id,
            type="email_opened",
            title="Email Opened",
            description="Email was opened",
            timestamp=open_event.timestamp,
            campaign_name=None,
            lead_email=None,
            metadata={"tracking_id": open_event.tracking_id}
        ))
    
    # Link clicks today
    clicks_today = db.query(LinkClick).filter(
        and_(LinkClick.clicked_at >= today_start, LinkClick.clicked_at <= today_end)
    ).order_by(LinkClick.clicked_at.desc()).limit(5).all()
    
    for click in clicks_today:
        recent_events.append(ActivityEvent(
            id=click.id,
            type="email_clicked",
            title="Link Clicked",
            description=f"Clicked: {click.original_url[:50]}...",
            timestamp=click.clicked_at,
            campaign_name=None,
            lead_email=None,
            metadata={"url": click.original_url}
        ))
    
    # Sort all events by timestamp desc
    recent_events.sort(key=lambda x: x.timestamp, reverse=True)
    recent_events = recent_events[:20]  # Keep only the 20 most recent
    
    # Generate highlights
    highlights = []
    
    # Today's stats
    daily_stats = db.query(DailyStats).filter(DailyStats.date == today).first()
    emails_sent_today = daily_stats.emails_sent if daily_stats else 0
    emails_opened_today = daily_stats.emails_opened if daily_stats else 0
    daily_limit = int(os.getenv("DAILY_EMAIL_LIMIT", 30))
    
    # Progress highlight
    if emails_sent_today > 0:
        progress_pct = round((emails_sent_today / daily_limit) * 100)
        highlights.append(TodaysHighlight(
            type="goal_progress",
            title="Daily Progress",
            value=f"{progress_pct}%",
            description=f"{emails_sent_today} of {daily_limit} emails sent",
            is_positive=progress_pct < 90  # Warning if approaching limit
        ))
    
    # Open rate highlight
    if emails_sent_today > 0 and emails_opened_today > 0:
        open_rate = round((emails_opened_today / emails_sent_today) * 100)
        highlights.append(TodaysHighlight(
            type="performance",
            title="Today's Open Rate",
            value=f"{open_rate}%",
            description=f"{emails_opened_today} opens from {emails_sent_today} emails",
            is_positive=open_rate > 20
        ))
    
    # Generate hourly send rate (simplified - could be enhanced with actual hourly data)
    hourly_send_rate = [0] * 24
    for email in sent_emails:
        if email.sent_at:
            hour = email.sent_at.hour
            hourly_send_rate[hour] += 1
    
    # Live metrics
    live_metrics = {
        "emails_remaining": max(0, daily_limit - emails_sent_today),
        "avg_open_time_minutes": 45,  # Could calculate from actual data
        "active_campaigns_today": db.query(Campaign).filter(Campaign.status == "active").count(),
        "response_rate": 3.2  # Could calculate from actual replies
    }
    
    return TodayActivity(
        recent_events=recent_events,
        highlights=highlights,
        hourly_send_rate=hourly_send_rate,
        live_metrics=live_metrics
    )