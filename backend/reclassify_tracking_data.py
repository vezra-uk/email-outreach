#!/usr/bin/env python3
"""
Reclassify Historic Tracking Data Script

This script applies updated confidence scoring logic to existing tracking data
in the database, useful after improving the tracking algorithm.
"""

import sys
import os
from datetime import datetime
from sqlalchemy.orm import sessionmaker
from sqlalchemy import create_engine

# Add backend directory to path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from database import get_db, engine
from models import EmailTrackingEvent, EmailOpenAnalysis, CampaignEmail
from modern_tracking_service import ModernOpenTracker

def reclassify_tracking_events():
    """Reclassify all tracking events using updated logic"""
    
    print("🔄 Starting tracking data reclassification...")
    
    # Create database session
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    db = SessionLocal()
    
    try:
        # Get all tracking events with their campaign email info
        tracking_events = db.query(EmailTrackingEvent).join(
            CampaignEmail, 
            EmailTrackingEvent.tracking_id == CampaignEmail.tracking_pixel_id
        ).all()
        
        if not tracking_events:
            print("❌ No tracking events found to reclassify")
            return
        
        print(f"📊 Found {len(tracking_events)} tracking events to reclassify")
        
        # Initialize tracker with updated logic
        tracker = ModernOpenTracker()
        
        # Group events by tracking_id for batch processing
        tracking_groups = {}
        for event in tracking_events:
            if event.tracking_id not in tracking_groups:
                tracking_groups[event.tracking_id] = []
            tracking_groups[event.tracking_id].append(event)
        
        print(f"🎯 Processing {len(tracking_groups)} unique tracking IDs")
        
        updated_events = 0
        updated_analyses = 0
        newly_opened = 0
        
        for tracking_id, events in tracking_groups.items():
            # Get the campaign email for send time
            campaign_email = db.query(CampaignEmail).filter(
                CampaignEmail.tracking_pixel_id == tracking_id
            ).first()
            
            if not campaign_email or not campaign_email.sent_at:
                print(f"⚠️  Skipping {tracking_id} - no send time found")
                continue
                
            send_time = campaign_email.sent_at
            
            # Recalculate confidence for each event
            for event in events:
                # Apply new timing analysis
                is_prefetch_timing, timing_confidence = tracker.analyze_timing(
                    send_time, event.timestamp
                )
                
                # Apply new user agent analysis
                is_prefetch_ua, ua_confidence = tracker.analyze_user_agent(
                    event.user_agent or ""
                )
                
                # Calculate new confidence score
                base_confidence = 0.8 if not (is_prefetch_ua or is_prefetch_timing) else 0.2
                new_confidence = base_confidence * ua_confidence * timing_confidence
                
                # Update the database record
                old_confidence = float(event.confidence_score) if event.confidence_score else 0.0
                event.confidence_score = new_confidence
                event.is_prefetch = new_confidence < 0.3
                event.delay_from_send = int((event.timestamp - send_time).total_seconds())
                
                if abs(new_confidence - old_confidence) > 0.01:  # Only count significant changes
                    updated_events += 1
                    print(f"  📝 {tracking_id} {event.signal_type}: {old_confidence:.3f} → {new_confidence:.3f}")
            
            # Recalculate aggregated analysis
            # Simulate the tracker's signal format for analysis
            signals = []
            for event in events:
                signal = type('Signal', (), {
                    'signal_type': event.signal_type,
                    'confidence': float(event.confidence_score),
                    'timestamp': event.timestamp,
                    'metadata': event.event_metadata or {}
                })()
                signals.append(signal)
            
            # Calculate overall confidence
            overall_confidence = tracker.calculate_confidence_score(signals, send_time)
            is_opened = overall_confidence > 0.3
            
            # Update or create EmailOpenAnalysis
            analysis = db.query(EmailOpenAnalysis).filter(
                EmailOpenAnalysis.tracking_id == tracking_id
            ).first()
            
            if not analysis:
                analysis = EmailOpenAnalysis(
                    tracking_id=tracking_id,
                    lead_sequence_id=campaign_email.lead_sequence_id,
                    sequence_email_id=campaign_email.id
                )
                db.add(analysis)
            
            old_opened_status = analysis.is_opened
            
            # Update analysis data
            analysis.total_signals = len(signals)
            analysis.confidence_score = overall_confidence
            analysis.is_opened = is_opened
            analysis.first_open_at = min(s.timestamp for s in signals) if signals else None
            analysis.last_activity_at = max(s.timestamp for s in signals) if signals else None
            analysis.prefetch_signals = sum(1 for s in signals if s.confidence < 0.3)
            analysis.human_signals = sum(1 for s in signals if s.confidence > 0.7)
            analysis.updated_at = datetime.utcnow()
            
            updated_analyses += 1
            
            # Check if this became a newly recognized open
            if is_opened and not old_opened_status:
                newly_opened += 1
                # Update campaign email opens counter
                campaign_email.opens = max(campaign_email.opens, 1)
                print(f"  ✅ {tracking_id} now recognized as OPENED (confidence: {overall_confidence:.3f})")
            elif not is_opened and old_opened_status:
                print(f"  ❌ {tracking_id} no longer considered opened (confidence: {overall_confidence:.3f})")
        
        # Commit all changes
        db.commit()
        
        print("\n🎉 Reclassification Complete!")
        print(f"📊 Updated {updated_events} individual tracking events")
        print(f"🔍 Updated {updated_analyses} aggregated analyses")
        print(f"✅ Newly recognized opens: {newly_opened}")
        
        if newly_opened > 0:
            print(f"📈 Your open rate improved by identifying {newly_opened} additional opens!")
            
    except Exception as e:
        print(f"❌ Error during reclassification: {e}")
        db.rollback()
        raise
    finally:
        db.close()

def preview_changes():
    """Preview what changes would be made without applying them"""
    
    print("👀 Previewing potential changes...")
    
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    db = SessionLocal()
    
    try:
        # Get sample of current data
        events = db.query(EmailTrackingEvent).join(
            CampaignEmail,
            EmailTrackingEvent.tracking_id == CampaignEmail.tracking_pixel_id
        ).limit(10).all()
        
        if not events:
            print("❌ No tracking events found")
            return
        
        tracker = ModernOpenTracker()
        
        print(f"📋 Sample of {len(events)} events:")
        print("Tracking ID | Signal | Old Conf | New Conf | Change")
        print("-" * 60)
        
        for event in events:
            campaign_email = db.query(CampaignEmail).filter(
                CampaignEmail.tracking_pixel_id == event.tracking_id
            ).first()
            
            if campaign_email and campaign_email.sent_at:
                is_prefetch_timing, timing_confidence = tracker.analyze_timing(
                    campaign_email.sent_at, event.timestamp
                )
                is_prefetch_ua, ua_confidence = tracker.analyze_user_agent(
                    event.user_agent or ""
                )
                
                base_confidence = 0.8 if not (is_prefetch_ua or is_prefetch_timing) else 0.2
                new_confidence = base_confidence * ua_confidence * timing_confidence
                
                old_conf = float(event.confidence_score) if event.confidence_score else 0.0
                change = new_confidence - old_conf
                
                print(f"{event.tracking_id[:12]}... | {event.signal_type:6s} | {old_conf:8.3f} | {new_confidence:8.3f} | {change:+7.3f}")
                
    except Exception as e:
        print(f"❌ Error during preview: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Reclassify historic tracking data")
    parser.add_argument("--preview", action="store_true", help="Preview changes without applying")
    parser.add_argument("--apply", action="store_true", help="Apply changes to database")
    
    args = parser.parse_args()
    
    if args.preview:
        preview_changes()
    elif args.apply:
        response = input("⚠️  This will modify your database. Continue? (yes/no): ")
        if response.lower() == 'yes':
            reclassify_tracking_events()
        else:
            print("Cancelled.")
    else:
        print("Use --preview to see potential changes or --apply to execute")
        print("Example: python reclassify_tracking_data.py --preview")