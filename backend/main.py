# backend/main.py
from fastapi import FastAPI, HTTPException, Depends, BackgroundTasks, APIRouter
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import create_engine, Column, Integer, String, DateTime, Text, Date, ForeignKey
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session, relationship
from pydantic import BaseModel
from typing import List, Optional
import os
from datetime import datetime, date
from dotenv import load_dotenv

load_dotenv()

app = FastAPI(title="Email Automation API", version="1.0.0")

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "https://outreach.vezra.co.uk"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

api_router = APIRouter(prefix="/api")

# Database setup
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://user:password@localhost:5432/email_automation")
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# Database Models
class Lead(Base):
    __tablename__ = "leads"
    
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True)
    first_name = Column(String)
    last_name = Column(String)
    company = Column(String)
    title = Column(String)
    phone = Column(String)
    status = Column(String, default="active")
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow)

class Campaign(Base):
    __tablename__ = "campaigns"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String)
    subject = Column(String)
    template = Column(Text)
    ai_prompt = Column(Text)
    status = Column(String, default="active")
    daily_limit = Column(Integer, default=30)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow)

class CampaignLead(Base):
    __tablename__ = "campaign_leads"
    
    id = Column(Integer, primary_key=True, index=True)
    campaign_id = Column(Integer, ForeignKey("campaigns.id"))
    lead_id = Column(Integer, ForeignKey("leads.id"))
    status = Column(String, default="pending")
    sent_at = Column(DateTime)
    opens = Column(Integer, default=0)
    clicks = Column(Integer, default=0)
    tracking_pixel_id = Column(String, unique=True)
    created_at = Column(DateTime, default=datetime.utcnow)

class DailyStats(Base):
    __tablename__ = "daily_stats"
    
    date = Column(Date, primary_key=True)
    emails_sent = Column(Integer, default=0)
    emails_opened = Column(Integer, default=0)
    links_clicked = Column(Integer, default=0)
    updated_at = Column(DateTime, default=datetime.utcnow)

# Pydantic models
class LeadCreate(BaseModel):
    email: str
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    company: Optional[str] = None
    title: Optional[str] = None
    phone: Optional[str] = None

class LeadResponse(BaseModel):
    id: int
    email: str
    first_name: Optional[str]
    last_name: Optional[str]
    company: Optional[str]
    title: Optional[str]
    status: str
    created_at: datetime

    class Config:
        from_attributes = True

class CampaignCreate(BaseModel):
    name: str
    subject: str
    template: str
    ai_prompt: str
    lead_ids: List[int]

class CampaignResponse(BaseModel):
    id: int
    name: str
    subject: str
    template: str
    status: str
    created_at: datetime

    class Config:
        from_attributes = True

class DashboardStats(BaseModel):
    total_leads: int
    emails_sent_today: int
    emails_opened_today: int
    active_campaigns: int
    daily_limit: int

# Database dependency
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# API Routes
@api_router.get("/")
def read_root():
    return {"message": "Email Automation API", "version": "1.0.0"}

@api_router.get("/health")
def health_check():
    return {"status": "healthy"}

@api_router.get("/dashboard", response_model=DashboardStats)
def get_dashboard_stats(db: Session = Depends(get_db)):
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

@api_router.get("/leads", response_model=List[LeadResponse])
def get_leads(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    leads = db.query(Lead).offset(skip).limit(limit).all()
    return leads

@api_router.post("/leads", response_model=LeadResponse)
def create_lead(lead: LeadCreate, db: Session = Depends(get_db)):
    # Check if lead already exists
    existing_lead = db.query(Lead).filter(Lead.email == lead.email).first()
    if existing_lead:
        raise HTTPException(status_code=400, detail="Lead with this email already exists")
    
    db_lead = Lead(**lead.dict())
    db.add(db_lead)
    db.commit()
    db.refresh(db_lead)
    return db_lead

@api_router.get("/campaigns", response_model=List[CampaignResponse])
def get_campaigns(db: Session = Depends(get_db)):
    campaigns = db.query(Campaign).all()
    return campaigns

@api_router.post("/campaigns", response_model=CampaignResponse)
def create_campaign(campaign: CampaignCreate, db: Session = Depends(get_db)):
    # Create campaign
    db_campaign = Campaign(
        name=campaign.name,
        subject=campaign.subject,
        template=campaign.template,
        ai_prompt=campaign.ai_prompt
    )
    db.add(db_campaign)
    db.flush()  # Get the ID without committing
    
    # Add leads to campaign
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

@api_router.post("/send-emails")
def trigger_email_send(background_tasks: BackgroundTasks, db: Session = Depends(get_db)):
    from email_service import EmailService
    
    # Check daily limit
    today = date.today()
    daily_stats = db.query(DailyStats).filter(DailyStats.date == today).first()
    if not daily_stats:
        daily_stats = DailyStats(date=today)
        db.add(daily_stats)
        db.commit()
    
    daily_limit = int(os.getenv("DAILY_EMAIL_LIMIT", 30))
    if daily_stats.emails_sent >= daily_limit:
        raise HTTPException(status_code=400, detail="Daily email limit reached")
    
    # Add background task
    background_tasks.add_task(send_email_batch)
    return {"message": "Email sending started", "remaining": daily_limit - daily_stats.emails_sent}

def send_email_batch():
    """Background task to send email batch"""
    from email_service import EmailService
    
    db = SessionLocal()
    email_service = EmailService()
    
    try:
        today = date.today()
        daily_stats = db.query(DailyStats).filter(DailyStats.date == today).first()
        daily_limit = int(os.getenv("DAILY_EMAIL_LIMIT", 30))
        
        remaining = daily_limit - (daily_stats.emails_sent if daily_stats else 0)
        if remaining <= 0:
            return
        
        # Get pending campaign leads
        pending = db.query(CampaignLead).join(Campaign).join(Lead).filter(
            CampaignLead.status == "pending",
            Campaign.status == "active",
            Lead.status == "active"
        ).limit(remaining).all()
        
        for campaign_lead in pending:
            try:
                # Get campaign and lead data
                campaign = db.query(Campaign).filter(Campaign.id == campaign_lead.campaign_id).first()
                lead = db.query(Lead).filter(Lead.id == campaign_lead.lead_id).first()
                
                # Generate and send email
                success = email_service.send_personalized_email(
                    lead=lead,
                    campaign=campaign,
                    tracking_id=campaign_lead.tracking_pixel_id
                )
                
                if success:
                    campaign_lead.status = "sent"
                    campaign_lead.sent_at = datetime.utcnow()
                    
                    # Update daily stats
                    if not daily_stats:
                        daily_stats = DailyStats(date=today, emails_sent=0)
                        db.add(daily_stats)
                    daily_stats.emails_sent += 1
                else:
                    campaign_lead.status = "failed"
                
            except Exception as e:
                print(f"Failed to send email to {lead.email}: {e}")
                campaign_lead.status = "failed"
        
        db.commit()
        
    finally:
        db.close()

@api_router.get("/track/open/{pixel_id}")
def track_email_open(pixel_id: str, db: Session = Depends(get_db)):
    """Track email opens via pixel"""
    campaign_lead = db.query(CampaignLead).filter(
        CampaignLead.tracking_pixel_id == pixel_id
    ).first()
    
    if campaign_lead:
        campaign_lead.opens += 1
        
        # Update daily stats
        today = date.today()
        daily_stats = db.query(DailyStats).filter(DailyStats.date == today).first()
        if daily_stats:
            daily_stats.emails_opened += 1
        
        db.commit()
    
    # Return 1x1 transparent pixel
    from fastapi.responses import Response
    pixel_data = bytes.fromhex('47494638396101000100800000000000ffffff21f90401000000002c000000000100010000020144003b')
    return Response(content=pixel_data, media_type="image/gif")
app.include_router(api_router)
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
