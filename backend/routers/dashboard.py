from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from datetime import date
import os

from database import get_db
from models import Lead, Campaign, DailyStats, User
from schemas.dashboard import DashboardStats
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