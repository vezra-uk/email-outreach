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
import logging

from logger_config import setup_logging, get_logger
from middleware import RequestLoggingMiddleware, DatabaseLoggingMiddleware
from database import get_db
from models import *
from schemas import *
from dependencies import get_current_active_user, get_current_user_optional

# Initialize logging
setup_logging(log_level=os.getenv("LOG_LEVEL", "INFO"))
logger = get_logger(__name__)

app = FastAPI(title="Email Automation API", version="1.0.0")

# Add logging middleware
app.add_middleware(RequestLoggingMiddleware)
app.add_middleware(DatabaseLoggingMiddleware)

logger.info("Starting Email Automation API", extra={
    "app_name": "Email Automation API",
    "version": "1.0.0",
    "log_level": os.getenv("LOG_LEVEL", "INFO")
})

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "https://outreach.vezra.co.uk"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

logger.info("CORS middleware configured", extra={
    "allowed_origins": ["http://localhost:3000", "https://outreach.vezra.co.uk"]
})

api_router = APIRouter(prefix="/api")

@api_router.get("/")
def read_root():
    logger.info("Root endpoint accessed")
    return {"message": "Email Automation API", "version": "1.0.0"}

@api_router.get("/health")
def health_check():
    logger.debug("Health check endpoint accessed")
    return {"status": "healthy"}

# Import and include routers
from routers.leads import router as leads_router
from routers.csv_upload import router as csv_router
from routers.dashboard import router as dashboard_router
from routers.campaigns import router as campaigns_router
from routers.groups import router as groups_router
from routers.sending_profiles import router as sending_profiles_router
from routers.auth import router as auth_router
from routers.external_api import router as external_api_router
from routers.deliverability import router as deliverability_router

api_router.include_router(auth_router)
api_router.include_router(leads_router)
api_router.include_router(csv_router)
api_router.include_router(dashboard_router)
api_router.include_router(campaigns_router)
api_router.include_router(groups_router)
api_router.include_router(sending_profiles_router)
api_router.include_router(external_api_router)
api_router.include_router(deliverability_router)

logger.info("All routers included in API", extra={
    "routers": ["auth", "leads", "csv_upload", "dashboard", "campaigns", "groups", "sending_profiles", "external_api", "deliverability"]
})

# Message Preview Endpoint
@api_router.post("/preview-message", response_model=MessagePreviewResponse)
def preview_personalized_message(preview_request: MessagePreviewRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    from email_service import EmailService
    
    logger.info("Message preview requested", extra={
        "user_id": current_user.id,
        "lead_id": preview_request.lead_id,
        "sending_profile_id": preview_request.sending_profile_id,
        "has_ai_prompt": bool(preview_request.ai_prompt)
    })
    
    lead = db.query(Lead).filter(Lead.id == preview_request.lead_id).first()
    if not lead:
        logger.warning("Lead not found for preview", extra={
            "user_id": current_user.id,
            "lead_id": preview_request.lead_id
        })
        raise HTTPException(status_code=404, detail="Lead not found")
    
    sending_profile = None
    if preview_request.sending_profile_id:
        sending_profile = db.query(SendingProfile).filter(SendingProfile.id == preview_request.sending_profile_id).first()
        logger.debug("Sending profile loaded", extra={
            "sending_profile_id": preview_request.sending_profile_id,
            "profile_found": sending_profile is not None
        })
    
    email_service = EmailService()
    
    try:
        logger.debug("Generating personalized email with AI")
        email_data = email_service._generate_ai_email(
            lead=lead,
            prompt_text=preview_request.ai_prompt,
            sending_profile=sending_profile,
            is_followup=False
        )
        
        if email_data:
            personalized_message = email_data['content']
            subject = email_data['subject']
            logger.info("AI email generation successful", extra={
                "user_id": current_user.id,
                "lead_id": preview_request.lead_id,
                "spam_score": email_data.get('spam_score', 'N/A')
            })
        else:
            raise Exception("Failed to generate email content")
    except Exception as e:
        logger.error("AI email generation failed, falling back to template", extra={
            "user_id": current_user.id,
            "lead_id": preview_request.lead_id,
            "error": str(e),
            "error_type": type(e).__name__
        }, exc_info=True)
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
    
    logger.info("Message preview completed successfully", extra={
        "user_id": current_user.id,
        "lead_id": preview_request.lead_id,
        "subject_generated": bool(subject),
        "message_length": len(personalized_message)
    })
    
    return MessagePreviewResponse(
        original_template=preview_request.template,
        personalized_message=personalized_message,
        subject=subject,
        lead_info=lead_info
    )

# Tracking Endpoints (keeping these in main.py for now as they're complex)
@api_router.get("/logo.png")
def serve_logo_with_tracking(
    t: str = None,  # tracking_id parameter
    request: Request = None,
    db: Session = Depends(get_db)
):
    # If tracking parameter provided, record the tracking
    if t and db:
        from modern_tracking_service import modern_tracker
        
        user_agent = request.headers.get("user-agent", "") if request else ""
        ip_address = request.client.host if request and request.client else ""
        
        logger.info(f"LOGO_TRACKING: Logo loaded for tracking_id {t} from {ip_address}", extra={
            "tracking_id": t,
            "signal_type": "LOGO",
            "ip_address": ip_address,
            "user_agent": user_agent[:100] if user_agent else "",
            "timestamp": datetime.utcnow().isoformat()
        })
        
        # Record tracking (similar to existing tracking logic)
        try:
            campaign_email = db.query(CampaignEmail).filter(
                CampaignEmail.tracking_pixel_id == t
            ).first()
            
            if campaign_email:
                send_time = campaign_email.sent_at or datetime.utcnow()
                
                # Record tracking signal
                signal = modern_tracker.record_tracking_signal(
                    tracking_id=t,
                    signal_type='logo',
                    user_agent=user_agent,
                    ip_address=ip_address,
                    send_time=send_time
                )
                
                # Update database tracking
                analysis = modern_tracker.get_open_analysis(t, send_time)
                
                if analysis['is_opened'] and campaign_email.opens == 0:
                    campaign_email.opens = 1
                    
                    # Update campaign stats - get campaign through lead_sequence
                    lead_sequence = db.query(LeadCampaign).filter(
                        LeadCampaign.id == campaign_email.lead_sequence_id
                    ).first()
                    
                    if lead_sequence:
                        campaign = db.query(Campaign).filter(
                            Campaign.id == lead_sequence.sequence_id
                        ).first()
                        
                        if campaign:
                            campaign.email_opens = (campaign.email_opens or 0) + 1
                    
                    db.commit()
                    
        except Exception as e:
            logger.error("Failed to process logo tracking", extra={
                "tracking_id": t,
                "error": str(e)
            })
            db.rollback()
    
    # Serve the actual logo file
    try:
        with open('/app/logo.png', 'rb') as f:
            logo_data = f.read()
        return Response(
            content=logo_data,
            media_type="image/png",
            headers={
                "Cache-Control": "no-cache, no-store, must-revalidate",
                "Pragma": "no-cache", 
                "Expires": "0"
            }
        )
    except FileNotFoundError:
        raise HTTPException(status_code=404, detail="Logo not found")

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
    
    logger.info(f"TRACKING_SIGNAL: {signal_type.upper()} triggered for {tracking_id} from {ip_address}", extra={
        "tracking_id": tracking_id,
        "signal_type": signal_type.upper(),
        "ip_address": ip_address,
        "user_agent": user_agent[:100] if user_agent else "",
        "timestamp": datetime.utcnow().isoformat(),
        "tracking_element": f"{signal_type} tracking element fired"
    })
    
    # Additional debug logging for tracking element identification  
    signal_descriptions = {
        "primary": "PRIMARY_PIXEL: Basic image pixel loaded immediately",
        "secondary": "SECONDARY_PIXEL: CSS background image loaded with delay", 
        "content": "CONTENT_PIXEL: Content-based image loaded",
        "interactive": "INTERACTIVE_LINK: User clicked tracking link", 
        "javascript": "JAVASCRIPT_TRACKING: JS execution after 1s delay",
        "view": "BROWSER_VIEW: Direct browser view tracking"
    }
    
    description = signal_descriptions.get(signal_type, f"UNKNOWN_SIGNAL_TYPE: {signal_type}")
    logger.info(f"TRACKING_DETAILS: {description}", extra={
        "signal_type": signal_type,
        "element_description": description
    })
    
    send_time = None
    campaign_email = db.query(CampaignEmail).filter(
        CampaignEmail.tracking_pixel_id == tracking_id
    ).first()
    
    logger.debug("Campaign email lookup", extra={
        "tracking_id": tracking_id,
        "campaign_email_found": campaign_email is not None,
        "campaign_email_id": campaign_email.id if campaign_email else None
    })
    
    if campaign_email and campaign_email.sent_at:
        send_time = campaign_email.sent_at
    else:
        send_time = datetime.utcnow()
        logger.warning("No send time found, using current time", extra={
            "tracking_id": tracking_id,
            "fallback_time": send_time.isoformat()
        })
    
    try:
        signal = modern_tracker.record_tracking_signal(
            tracking_id, signal_type, user_agent, ip_address, send_time
        )
        
        # Save to database
        db_event = EmailTrackingEvent(
            tracking_id=tracking_id,
            event_type='pixel_load',
            signal_type=signal_type,
            ip_address=ip_address,
            user_agent=user_agent,
            timestamp=signal.timestamp,
            delay_from_send=int((signal.timestamp - send_time).total_seconds()),
            is_prefetch=signal.confidence < 0.3,
            confidence_score=signal.confidence,
            event_metadata=signal.metadata
        )
        db.add(db_event)
        db.commit()
        
        logger.debug("Tracking signal recorded successfully", extra={
            "tracking_id": tracking_id,
            "signal_type": signal_type
        })
    except Exception as e:
        logger.error("Failed to record tracking signal", extra={
            "tracking_id": tracking_id,
            "signal_type": signal_type,
            "error": str(e),
            "error_type": type(e).__name__
        }, exc_info=True)
        db.rollback()
        raise HTTPException(status_code=500, detail="Failed to record tracking signal")
    
    analysis = modern_tracker.get_open_analysis(tracking_id, send_time)
    
    # Save/update aggregated analysis
    db_analysis = db.query(EmailOpenAnalysis).filter(
        EmailOpenAnalysis.tracking_id == tracking_id
    ).first()
    
    if not db_analysis:
        db_analysis = EmailOpenAnalysis(
            tracking_id=tracking_id,
            lead_sequence_id=campaign_email.lead_sequence_id if campaign_email else None,
            sequence_email_id=campaign_email.id if campaign_email else None
        )
        db.add(db_analysis)
    
    # Update analysis data
    db_analysis.total_signals = analysis['total_signals']
    db_analysis.confidence_score = analysis['confidence_score'] 
    db_analysis.is_opened = analysis['is_opened']
    db_analysis.first_open_at = analysis.get('first_signal_at')
    db_analysis.last_activity_at = analysis.get('last_signal_at')
    db_analysis.prefetch_signals = analysis.get('prefetch_signals', 0)
    db_analysis.human_signals = analysis.get('high_confidence_signals', 0)
    db_analysis.analysis_data = analysis
    db_analysis.updated_at = datetime.utcnow()
    
    db.commit()
    
    confidence_level = "HIGH" if analysis['confidence_score'] > 0.7 else \
                      "MEDIUM" if analysis['confidence_score'] > 0.3 else "LOW"
    confidence_emoji = "✅" if analysis['confidence_score'] > 0.7 else \
                      "⚠️" if analysis['confidence_score'] > 0.3 else "❌"
    
    logger.info(f"CONFIDENCE_ANALYSIS: {confidence_level} confidence {analysis['confidence_score']:.3f} for {tracking_id} ({analysis['total_signals']} signals)", extra={
        "tracking_id": tracking_id,
        "confidence_score": analysis['confidence_score'],
        "confidence_level": confidence_level,
        "threshold_met": analysis['confidence_score'] > 0.3,
        "total_signals": analysis['total_signals'],
        "signal_types": analysis.get('signal_types', [])
    })
    
    if analysis['confidence_score'] > 0.3:
        if campaign_email:
            previous_opens = campaign_email.opens
            campaign_email.opens = max(campaign_email.opens, 1)
            
            logger.info("Campaign email opens updated", extra={
                "tracking_id": tracking_id,
                "campaign_email_id": campaign_email.id,
                "previous_opens": previous_opens,
                "new_opens": campaign_email.opens
            })
            
            today = date.today()
            daily_stats = db.query(DailyStats).filter(DailyStats.date == today).first()
            if not daily_stats:
                daily_stats = DailyStats(date=today, emails_opened=1)
                db.add(daily_stats)
                logger.info("Created new daily stats record", extra={"date": today.isoformat()})
            else:
                daily_stats.emails_opened += 1
                logger.debug("Updated existing daily stats", extra={
                    "date": today.isoformat(),
                    "new_opens_count": daily_stats.emails_opened
                })
        
        try:
            db.commit()
            logger.info("Database changes committed successfully", extra={
                "tracking_id": tracking_id,
                "confidence_score": analysis['confidence_score']
            })
        except Exception as e:
            logger.error("Failed to commit database changes", extra={
                "tracking_id": tracking_id,
                "error": str(e),
                "error_type": type(e).__name__
            }, exc_info=True)
            db.rollback()
            raise HTTPException(status_code=500, detail="Failed to update tracking data")
    
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
    
    logger.info("Link click tracked", extra={
        "tracking_id": tracking_id,
        "original_url": original_url,
        "ip_address": ip_address,
        "user_agent": user_agent[:100] if user_agent else "",
        "referer": referer
    })
    
    campaign_email = db.query(CampaignEmail).filter(
        CampaignEmail.tracking_pixel_id == tracking_id
    ).first()
    
    send_time = datetime.utcnow()
    
    if campaign_email:
        send_time = campaign_email.sent_at if campaign_email.sent_at else send_time
        previous_clicks = campaign_email.clicks
        campaign_email.clicks += 1
        
        logger.info("Campaign email click count updated", extra={
            "tracking_id": tracking_id,
            "campaign_email_id": campaign_email.id,
            "previous_clicks": previous_clicks,
            "new_clicks": campaign_email.clicks
        })
        
        link_click = LinkClick(
            tracking_id=tracking_id,
            campaign_email_id=campaign_email.id,
            original_url=original_url,
            ip_address=ip_address,
            user_agent=user_agent,
            referer=referer
        )
        db.add(link_click)
        logger.debug("Link click record created", extra={
            "tracking_id": tracking_id,
            "campaign_email_id": campaign_email.id,
            "url": original_url
        })
    else:
        logger.warning("No campaign email found for link click", extra={
            "tracking_id": tracking_id,
            "url": original_url
        })
    
    try:
        db.commit()
        logger.info("Link click data committed successfully", extra={
            "tracking_id": tracking_id
        })
    except Exception as e:
        logger.error("Failed to commit link click data", extra={
            "tracking_id": tracking_id,
            "error": str(e),
            "error_type": type(e).__name__
        }, exc_info=True)
        db.rollback()
        raise HTTPException(status_code=500, detail="Failed to record link click")
    
    try:
        signal = modern_tracker.record_tracking_signal(
            tracking_id, 'interactive', user_agent, ip_address, send_time
        )
        logger.debug("Interactive tracking signal recorded", extra={
            "tracking_id": tracking_id
        })
    except Exception as e:
        logger.error("Failed to record interactive signal", extra={
            "tracking_id": tracking_id,
            "error": str(e),
            "error_type": type(e).__name__
        }, exc_info=True)
    
    logger.info("Redirecting user to original URL", extra={
        "tracking_id": tracking_id,
        "redirect_url": original_url
    })
    
    return RedirectResponse(url=original_url, status_code=302)

# Legacy endpoint for backwards compatibility
@api_router.get("/track/open/{pixel_id}")
def track_email_open_legacy(pixel_id: str, request: Request, db: Session = Depends(get_db)):
    return track_signal(pixel_id, "primary", request, db)

@api_router.get("/track/view/{tracking_id}")
def view_email_in_browser(tracking_id: str, request: Request, db: Session = Depends(get_db)):
    """Handle 'View this email in your browser' clicks"""
    logger.info("Browser view requested", extra={"tracking_id": tracking_id})
    
    # Record view signal
    from modern_tracking_service import modern_tracker
    user_agent = request.headers.get("user-agent", "")
    ip_address = request.client.host if request.client else ""
    
    try:
        # Find campaign email to get send time
        campaign_email = db.query(CampaignEmail).filter(
            CampaignEmail.tracking_pixel_id == tracking_id
        ).first()
        
        send_time = campaign_email.sent_at if campaign_email and campaign_email.sent_at else datetime.utcnow()
        
        signal = modern_tracker.record_tracking_signal(
            tracking_id, 'view_browser', user_agent, ip_address, send_time
        )
        
        if campaign_email:
            campaign_email.opens = max(campaign_email.opens, 1)
            db.commit()
            
    except Exception as e:
        logger.error("Failed to record browser view", extra={
            "tracking_id": tracking_id,
            "error": str(e)
        })
    
    # Return simple HTML page with email content if available
    if campaign_email and campaign_email.content:
        html_content = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>Email View</title>
            <style>
                body {{ font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; }}
            </style>
        </head>
        <body>
            <div style="border: 1px solid #ddd; padding: 20px; border-radius: 5px;">
                <h3>Subject: {campaign_email.subject}</h3>
                <hr>
                {campaign_email.content}
            </div>
        </body>
        </html>
        """
        return HTMLResponse(content=html_content)
    else:
        return HTMLResponse(content="<html><body><h2>Email not found</h2></body></html>")

@api_router.get("/unsubscribe/{tracking_id}")
@api_router.post("/unsubscribe/{tracking_id}")
def unsubscribe_from_emails(tracking_id: str, db: Session = Depends(get_db)):
    """Handle unsubscribe requests"""
    logger.info("Unsubscribe request", extra={"tracking_id": tracking_id})
    
    try:
        # Find the campaign email to get the lead
        campaign_email = db.query(CampaignEmail).filter(
            CampaignEmail.tracking_pixel_id == tracking_id
        ).first()
        
        if campaign_email:
            lead_sequence = db.query(LeadCampaign).filter(
                LeadCampaign.id == campaign_email.lead_sequence_id
            ).first()
            
            if lead_sequence:
                # Mark lead as unsubscribed
                lead = db.query(Lead).filter(Lead.id == lead_sequence.lead_id).first()
                if lead:
                    lead.status = "unsubscribed"
                    lead_sequence.status = "stopped" 
                    lead_sequence.stop_reason = "unsubscribed"
                    db.commit()
                    
                    logger.info("Lead unsubscribed successfully", extra={
                        "tracking_id": tracking_id,
                        "lead_id": lead.id
                    })
        
        html_content = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <title>Unsubscribed</title>
            <style>
                body { font-family: Arial, sans-serif; max-width: 600px; margin: 50px auto; padding: 20px; text-align: center; }
            </style>
        </head>
        <body>
            <h2>Successfully Unsubscribed</h2>
            <p>You have been removed from our mailing list.</p>
            <p>You will no longer receive emails from us.</p>
        </body>
        </html>
        """
        return HTMLResponse(content=html_content)
        
    except Exception as e:
        logger.error("Failed to process unsubscribe", extra={
            "tracking_id": tracking_id,
            "error": str(e)
        })
        return HTMLResponse(content="<html><body><h2>Error processing unsubscribe</h2></body></html>")

# Sequences endpoints moved to sequences router

app.include_router(api_router)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)