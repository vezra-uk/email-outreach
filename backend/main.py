# backend/main.py - Refactored modular version
from fastapi import FastAPI, APIRouter, BackgroundTasks, Depends, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response, HTMLResponse, RedirectResponse
from sqlalchemy import text
from sqlalchemy.orm import Session
from datetime import datetime, date
from urllib.parse import unquote
from typing import Optional
import os

from database import get_db
from models import *
from schemas import *
from dependencies import get_current_active_user, get_current_user_optional

app = FastAPI(title="Email Automation API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "https://outreach.vezra.co.uk"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

api_router = APIRouter(prefix="/api")

@api_router.get("/")
def read_root():
    return {"message": "Email Automation API", "version": "1.0.0"}

@api_router.get("/health")
def health_check():
    return {"status": "healthy"}

# Import and include routers
from routers.leads import router as leads_router
from routers.csv_upload import router as csv_router
from routers.dashboard import router as dashboard_router
from routers.campaigns import router as campaigns_router
from routers.groups import router as groups_router
from routers.sending_profiles import router as sending_profiles_router
from routers.auth import router as auth_router

api_router.include_router(auth_router)
api_router.include_router(leads_router)
api_router.include_router(csv_router)
api_router.include_router(dashboard_router)
api_router.include_router(campaigns_router)
api_router.include_router(groups_router)
api_router.include_router(sending_profiles_router)

# Message Preview Endpoint
@api_router.post("/preview-message", response_model=MessagePreviewResponse)
def preview_personalized_message(preview_request: MessagePreviewRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    from email_service import EmailService
    
    lead = db.query(Lead).filter(Lead.id == preview_request.lead_id).first()
    if not lead:
        raise HTTPException(status_code=404, detail="Lead not found")
    
    sending_profile = None
    if preview_request.sending_profile_id:
        sending_profile = db.query(SendingProfile).filter(SendingProfile.id == preview_request.sending_profile_id).first()
    
    email_service = EmailService()
    
    try:
        email_data = email_service.generate_personalized_email_and_subject(
            lead=lead,
            ai_prompt=preview_request.ai_prompt,
            sending_profile=sending_profile
        )
        personalized_message = email_data['content']
        subject = email_data['subject']
    except Exception as e:
        personalized_message = preview_request.template.replace(
            "{first_name}", lead.first_name or "there"
        ).replace(
            "{company}", lead.company or "your company"
        ).replace(
            "{last_name}", lead.last_name or ""
        ).replace(
            "{email}", lead.email
        )
        subject = f"Quick question about {lead.company or 'your business'}"
    
    lead_info = {
        "id": lead.id,
        "email": lead.email,
        "first_name": lead.first_name,
        "last_name": lead.last_name,
        "company": lead.company,
        "title": lead.title
    }
    
    return MessagePreviewResponse(
        original_template=preview_request.template,
        personalized_message=personalized_message,
        subject=subject,
        lead_info=lead_info
    )

# Tracking Endpoints (keeping these in main.py for now as they're complex)
@api_router.get("/track/signal/{tracking_id}/{signal_type}")
def track_signal(
    tracking_id: str, 
    signal_type: str,
    request: Request,
    db: Session = Depends(get_db)
):
    from modern_tracking_service import modern_tracker
    
    user_agent = request.headers.get("user-agent", "")
    ip_address = request.client.host if request.client else ""
    
    print(f"Tracking signal for ID: {tracking_id}, type: {signal_type}")
    
    send_time = None
    campaign_email = db.query(CampaignEmail).filter(
        CampaignEmail.tracking_pixel_id == tracking_id
    ).first()
    
    print(f"Found campaign_email: {campaign_email is not None}")
    
    if campaign_email and campaign_email.sent_at:
        send_time = campaign_email.sent_at
    else:
        send_time = datetime.utcnow()
    
    signal = modern_tracker.record_tracking_signal(
        tracking_id, signal_type, user_agent, ip_address, send_time
    )
    
    analysis = modern_tracker.get_open_analysis(tracking_id, send_time)
    print(f"Open analysis confidence: {analysis['confidence_score']}")
    
    if analysis['confidence_score'] > 0.3:
        if campaign_email:
            campaign_email.opens = max(campaign_email.opens, 1)
            print(f"Updated campaign_email opens to: {campaign_email.opens}")
            today = date.today()
            daily_stats = db.query(DailyStats).filter(DailyStats.date == today).first()
            if not daily_stats:
                daily_stats = DailyStats(date=today, emails_opened=1)
                db.add(daily_stats)
            else:
                daily_stats.emails_opened += 1
        
        db.commit()
        print("Database committed tracking changes")
    
    if signal_type in ['primary', 'secondary', 'content']:
        pixel_data = bytes.fromhex('47494638396101000100800000000000ffffff21f90401000000002c000000000100010000020144003b')
        return Response(
            content=pixel_data, 
            media_type="image/gif",
            headers={
                "Cache-Control": "no-cache, no-store, must-revalidate",
                "Pragma": "no-cache", 
                "Expires": "0",
                "Access-Control-Allow-Origin": "*"
            }
        )
    elif signal_type == 'js':
        return Response(
            content='{"status":"tracked"}',
            media_type="application/json",
            headers={
                "Cache-Control": "no-cache, no-store, must-revalidate",
                "Access-Control-Allow-Origin": "*"
            }
        )
    else:
        return {"status": "tracked", "confidence": analysis['confidence_score']}

@api_router.get("/track/click/{tracking_id}")
def track_link_click(tracking_id: str, url: str, request: Request, db: Session = Depends(get_db)):
    from modern_tracking_service import modern_tracker
    
    user_agent = request.headers.get("user-agent", "")
    ip_address = request.client.host if request.client else ""
    referer = request.headers.get("referer", "")
    original_url = unquote(url)
    
    campaign_email = db.query(CampaignEmail).filter(
        CampaignEmail.tracking_pixel_id == tracking_id
    ).first()
    
    send_time = datetime.utcnow()
    
    if campaign_email:
        send_time = campaign_email.sent_at if campaign_email.sent_at else send_time
        campaign_email.clicks += 1
        
        link_click = LinkClick(
            tracking_id=tracking_id,
            campaign_email_id=campaign_email.id,
            original_url=original_url,
            ip_address=ip_address,
            user_agent=user_agent,
            referer=referer
        )
        db.add(link_click)
    
    db.commit()
    
    signal = modern_tracker.record_tracking_signal(
        tracking_id, 'interactive', user_agent, ip_address, send_time
    )
    
    return RedirectResponse(url=original_url, status_code=302)

# Legacy endpoint for backwards compatibility
@api_router.get("/track/open/{pixel_id}")
def track_email_open_legacy(pixel_id: str, request: Request, db: Session = Depends(get_db)):
    return track_signal(pixel_id, "primary", request, db)

# Sequences endpoints moved to sequences router

app.include_router(api_router)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)