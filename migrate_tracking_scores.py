#!/usr/bin/env python3
"""
Tracking Confidence Score Migration Script

This script recalculates confidence scores for all existing email tracking data
using the updated ModernOpenTracker scoring mechanism.
"""

import os
import sys
import logging
from datetime import datetime
from typing import Dict, List, Tuple, Optional
import psycopg2
from psycopg2.extras import RealDictCursor
import json

# Add the backend directory to the Python path
backend_path = os.path.join(os.path.dirname(__file__), 'backend')
sys.path.insert(0, backend_path)

from modern_tracking_service import ModernOpenTracker, TrackingSignal

# Database configuration
DB_CONFIG = {
    'host': 'localhost',
    'port': 5432,
    'database': 'email_automation',
    'user': 'user',
    'password': 'password'
}

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(f'tracking_migration_{datetime.now().strftime("%Y%m%d_%H%M%S")}.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

class TrackingMigration:
    def __init__(self):
        self.conn = None
        self.tracker = ModernOpenTracker()
        self.stats = {
            'total_tracking_ids': 0,
            'processed': 0,
            'updated': 0,
            'skipped': 0,
            'errors': 0,
            'opens_before': 0,
            'opens_after': 0,
            'confidence_changes': []
        }
    
    def connect_db(self) -> bool:
        """Connect to PostgreSQL database"""
        try:
            self.conn = psycopg2.connect(**DB_CONFIG)
            logger.info("✅ Connected to database")
            return True
        except Exception as e:
            logger.error(f"❌ Failed to connect to database: {e}")
            return False
    
    def get_tracking_events(self) -> Dict[str, List[dict]]:
        """Fetch all tracking events grouped by tracking_id"""
        logger.info("Fetching tracking events from database...")
        
        query = """
        SELECT tracking_id, event_type, signal_type, ip_address, user_agent, 
               referer, timestamp, delay_from_send, is_prefetch, 
               confidence_score, event_metadata
        FROM email_tracking_events 
        ORDER BY tracking_id, timestamp
        """
        
        tracking_events = {}
        
        with self.conn.cursor(cursor_factory=RealDictCursor) as cursor:
            cursor.execute(query)
            
            for row in cursor:
                tracking_id = row['tracking_id']
                
                if tracking_id not in tracking_events:
                    tracking_events[tracking_id] = []
                
                tracking_events[tracking_id].append(dict(row))
        
        logger.info(f"Found {len(tracking_events)} unique tracking IDs with events")
        self.stats['total_tracking_ids'] = len(tracking_events)
        return tracking_events
    
    def get_send_time(self, tracking_id: str) -> Optional[datetime]:
        """Get send time for a tracking ID from campaign emails"""
        query = """
        SELECT sent_at 
        FROM sequence_emails 
        WHERE tracking_pixel_id = %s 
        AND sent_at IS NOT NULL
        """
        
        with self.conn.cursor() as cursor:
            cursor.execute(query, (tracking_id,))
            result = cursor.fetchone()
            return result[0] if result else None
    
    def convert_to_tracking_signals(self, events: List[dict], send_time: datetime) -> List[TrackingSignal]:
        """Convert database events to TrackingSignal objects"""
        signals = []
        
        for event in events:
            # Parse metadata if it exists
            metadata = event.get('event_metadata', {})
            if isinstance(metadata, str):
                try:
                    metadata = json.loads(metadata)
                except json.JSONDecodeError:
                    metadata = {}
            
            # Create TrackingSignal
            signal = TrackingSignal(
                event_type=event['event_type'],
                signal_type=event['signal_type'],
                confidence=float(event.get('confidence_score', 0.5)),
                metadata={
                    'user_agent': event.get('user_agent', ''),
                    'ip_address': event.get('ip_address', ''),
                    'referer': event.get('referer', ''),
                    'delay_seconds': event.get('delay_from_send', 0),
                    **metadata
                },
                timestamp=event['timestamp']
            )
            signals.append(signal)
        
        return signals
    
    def get_current_analysis(self, tracking_id: str) -> Optional[dict]:
        """Get current analysis record for tracking ID"""
        query = """
        SELECT confidence_score, is_opened, total_signals
        FROM email_open_analysis 
        WHERE tracking_id = %s
        """
        
        with self.conn.cursor(cursor_factory=RealDictCursor) as cursor:
            cursor.execute(query, (tracking_id,))
            result = cursor.fetchone()
            return dict(result) if result else None
    
    def update_analysis(self, tracking_id: str, analysis: Dict) -> bool:
        """Update or insert analysis record"""
        try:
            # Try to update existing record first
            update_query = """
            UPDATE email_open_analysis 
            SET confidence_score = %s,
                is_opened = %s,
                total_signals = %s,
                first_open_at = %s,
                last_activity_at = %s,
                unique_ip_count = %s,
                prefetch_signals = %s,
                human_signals = %s,
                analysis_data = %s,
                updated_at = %s
            WHERE tracking_id = %s
            """
            
            analysis_data = json.dumps({
                'signal_types': analysis.get('signal_types', []),
                'analysis': analysis.get('analysis', ''),
                'recalculated_at': datetime.utcnow().isoformat()
            })
            
            with self.conn.cursor() as cursor:
                cursor.execute(update_query, (
                    float(analysis['confidence_score']),
                    analysis['is_opened'],
                    analysis['total_signals'],
                    analysis.get('first_signal_at'),
                    analysis.get('last_signal_at'),
                    analysis.get('unique_ip_count', 0),
                    analysis.get('prefetch_signals', 0),
                    analysis.get('high_confidence_signals', 0),
                    analysis_data,
                    datetime.utcnow(),
                    tracking_id
                ))
                
                if cursor.rowcount == 0:
                    # Insert new record if update didn't affect any rows
                    insert_query = """
                    INSERT INTO email_open_analysis 
                    (tracking_id, confidence_score, is_opened, total_signals,
                     first_open_at, last_activity_at, unique_ip_count,
                     prefetch_signals, human_signals, analysis_data, created_at, updated_at)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    """
                    
                    cursor.execute(insert_query, (
                        tracking_id,
                        float(analysis['confidence_score']),
                        analysis['is_opened'],
                        analysis['total_signals'],
                        analysis.get('first_signal_at'),
                        analysis.get('last_signal_at'),
                        analysis.get('unique_ip_count', 0),
                        analysis.get('prefetch_signals', 0),
                        analysis.get('high_confidence_signals', 0),
                        analysis_data,
                        datetime.utcnow(),
                        datetime.utcnow()
                    ))
            
            return True
            
        except Exception as e:
            logger.error(f"Error updating analysis for {tracking_id}: {e}")
            return False
    
    def update_campaign_email_opens(self, tracking_id: str, is_opened: bool) -> bool:
        """Update opens count in campaign email"""
        try:
            # Update opens count based on new analysis
            query = """
            UPDATE sequence_emails 
            SET opens = CASE WHEN %s THEN 1 ELSE 0 END
            WHERE tracking_pixel_id = %s
            """
            
            with self.conn.cursor() as cursor:
                cursor.execute(query, (is_opened, tracking_id))
            
            return True
            
        except Exception as e:
            logger.error(f"Error updating campaign email opens for {tracking_id}: {e}")
            return False
    
    def process_tracking_id(self, tracking_id: str, events: List[dict]) -> bool:
        """Process a single tracking ID"""
        try:
            # Get send time
            send_time = self.get_send_time(tracking_id)
            if not send_time:
                logger.warning(f"⚠️  No send time found for {tracking_id}, skipping")
                self.stats['skipped'] += 1
                return False
            
            # Get current analysis for comparison
            current_analysis = self.get_current_analysis(tracking_id)
            old_confidence = current_analysis['confidence_score'] if current_analysis else 0.0
            old_is_opened = current_analysis['is_opened'] if current_analysis else False
            
            # Convert events to tracking signals
            signals = self.convert_to_tracking_signals(events, send_time)
            
            # Calculate new analysis using ModernOpenTracker
            new_analysis = self.tracker.get_open_analysis(tracking_id, send_time)
            
            # Update database
            if self.update_analysis(tracking_id, new_analysis):
                self.update_campaign_email_opens(tracking_id, new_analysis['is_opened'])
                
                # Track statistics
                new_confidence = new_analysis['confidence_score']
                new_is_opened = new_analysis['is_opened']
                
                if old_is_opened:
                    self.stats['opens_before'] += 1
                if new_is_opened:
                    self.stats['opens_after'] += 1
                
                # Log significant changes
                if abs(new_confidence - old_confidence) > 0.2:
                    change = {
                        'tracking_id': tracking_id,
                        'old_confidence': old_confidence,
                        'new_confidence': new_confidence,
                        'old_opened': old_is_opened,
                        'new_opened': new_is_opened
                    }
                    self.stats['confidence_changes'].append(change)
                    logger.info(f"📈 Significant change for {tracking_id}: "
                              f"{old_confidence:.3f}→{new_confidence:.3f} "
                              f"(opened: {old_is_opened}→{new_is_opened})")
                
                self.stats['updated'] += 1
                return True
            else:
                self.stats['errors'] += 1
                return False
                
        except Exception as e:
            logger.error(f"Error processing {tracking_id}: {e}")
            self.stats['errors'] += 1
            return False
    
    def run_migration(self, batch_size: int = 1000) -> bool:
        """Run the complete migration"""
        logger.info("🚀 Starting tracking confidence score migration")
        
        try:
            # Get all tracking events
            tracking_events = self.get_tracking_events()
            
            if not tracking_events:
                logger.info("No tracking events found to process")
                return True
            
            # Process in batches
            tracking_ids = list(tracking_events.keys())
            total_batches = (len(tracking_ids) + batch_size - 1) // batch_size
            
            for batch_num in range(total_batches):
                start_idx = batch_num * batch_size
                end_idx = min(start_idx + batch_size, len(tracking_ids))
                batch_ids = tracking_ids[start_idx:end_idx]
                
                logger.info(f"📦 Processing batch {batch_num + 1}/{total_batches} "
                          f"({len(batch_ids)} tracking IDs)")
                
                for tracking_id in batch_ids:
                    events = tracking_events[tracking_id]
                    self.process_tracking_id(tracking_id, events)
                    self.stats['processed'] += 1
                
                # Commit after each batch
                self.conn.commit()
                
                # Progress update
                progress = (self.stats['processed'] / len(tracking_ids)) * 100
                logger.info(f"Progress: {progress:.1f}% ({self.stats['processed']}/{len(tracking_ids)})")
            
            logger.info("✅ Migration completed successfully!")
            return True
            
        except Exception as e:
            logger.error(f"❌ Migration failed: {e}")
            self.conn.rollback()
            return False
    
    def print_report(self):
        """Print migration summary report"""
        print("\n" + "="*60)
        print("📊 TRACKING CONFIDENCE MIGRATION REPORT")
        print("="*60)
        print(f"Total tracking IDs:     {self.stats['total_tracking_ids']:,}")
        print(f"Processed:              {self.stats['processed']:,}")
        print(f"Updated:                {self.stats['updated']:,}")
        print(f"Skipped:                {self.stats['skipped']:,}")
        print(f"Errors:                 {self.stats['errors']:,}")
        print()
        print(f"Opens before migration: {self.stats['opens_before']:,}")
        print(f"Opens after migration:  {self.stats['opens_after']:,}")
        print(f"Net change in opens:    {self.stats['opens_after'] - self.stats['opens_before']:+,}")
        print()
        
        if self.stats['confidence_changes']:
            print(f"Significant changes (>0.2 confidence): {len(self.stats['confidence_changes'])}")
            
            # Show top 10 biggest changes
            changes = sorted(self.stats['confidence_changes'], 
                           key=lambda x: abs(x['new_confidence'] - x['old_confidence']), 
                           reverse=True)[:10]
            
            print("\nTop confidence score changes:")
            for change in changes:
                print(f"  {change['tracking_id']}: "
                      f"{change['old_confidence']:.3f}→{change['new_confidence']:.3f} "
                      f"(opened: {change['old_opened']}→{change['new_opened']})")
        
        print("="*60)
    
    def close(self):
        """Close database connection"""
        if self.conn:
            self.conn.close()

def main():
    """Main migration function"""
    migration = TrackingMigration()
    
    try:
        if not migration.connect_db():
            sys.exit(1)
        
        # Run migration
        success = migration.run_migration()
        
        # Print report
        migration.print_report()
        
        if success:
            logger.info("🎉 Migration completed successfully!")
            sys.exit(0)
        else:
            logger.error("❌ Migration failed!")
            sys.exit(1)
            
    except KeyboardInterrupt:
        logger.info("\n⚠️  Migration interrupted by user")
        sys.exit(1)
    except Exception as e:
        logger.error(f"❌ Unexpected error: {e}")
        sys.exit(1)
    finally:
        migration.close()

if __name__ == "__main__":
    main()