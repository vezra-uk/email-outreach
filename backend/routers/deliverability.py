from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import desc, func, and_
from datetime import date, datetime, timedelta
from typing import List, Dict, Any

from database import get_db
from models import (
    DeliverabilityMetric, PostmasterMetric, BlacklistStatus, 
    DNSAuthRecord, DeliverabilityAlert, User
)
from dependencies import get_current_active_user
from services.deliverability_monitor import DeliverabilityMonitor

router = APIRouter(prefix="/deliverability", tags=["deliverability"])

@router.get("/summary")
def get_deliverability_summary(
    db: Session = Depends(get_db), 
    current_user: User = Depends(get_current_active_user)
):
    """Get overall deliverability health summary"""
    monitor = DeliverabilityMonitor()
    summary = monitor.get_deliverability_summary(db)
    return summary

@router.get("/blacklist-status")
def get_blacklist_status(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get current blacklist status across all providers"""
    blacklist_status = db.query(BlacklistStatus).filter(
        BlacklistStatus.resolved_at.is_(None)
    ).order_by(desc(BlacklistStatus.last_checked)).all()
    
    # Group by provider
    status_by_provider = {}
    for status in blacklist_status:
        provider = status.blacklist_name
        if provider not in status_by_provider:
            status_by_provider[provider] = []
        
        status_by_provider[provider].append({
            'domain': status.domain,
            'ip_address': status.ip_address,
            'is_listed': status.is_listed,
            'first_detected': status.first_detected,
            'last_checked': status.last_checked,
            'listing_reason': status.listing_reason
        })
    
    return status_by_provider

@router.get("/dns-auth")
def get_dns_auth_status(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get DNS authentication record status"""
    dns_records = db.query(DNSAuthRecord).order_by(
        DNSAuthRecord.domain, 
        DNSAuthRecord.record_type,
        desc(DNSAuthRecord.last_checked)
    ).all()
    
    # Group by domain and get latest record for each type
    auth_status = {}
    for record in dns_records:
        domain = record.domain
        if domain not in auth_status:
            auth_status[domain] = {}
        
        if record.record_type not in auth_status[domain]:
            auth_status[domain][record.record_type] = {
                'record_value': record.record_value,
                'is_valid': record.is_valid,
                'validation_errors': record.validation_errors,
                'last_checked': record.last_checked
            }
    
    return auth_status

@router.get("/alerts")
def get_deliverability_alerts(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
    include_resolved: bool = False
):
    """Get deliverability alerts"""
    query = db.query(DeliverabilityAlert)
    
    if not include_resolved:
        query = query.filter(DeliverabilityAlert.is_resolved == False)
    
    alerts = query.order_by(desc(DeliverabilityAlert.created_at)).limit(50).all()
    
    return [{
        'id': alert.id,
        'alert_type': alert.alert_type,
        'severity': alert.severity,
        'title': alert.title,
        'description': alert.description,
        'domain': alert.domain,
        'is_resolved': alert.is_resolved,
        'created_at': alert.created_at,
        'resolved_at': alert.resolved_at
    } for alert in alerts]

@router.post("/alerts/{alert_id}/resolve")
def resolve_alert(
    alert_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Mark an alert as resolved"""
    alert = db.query(DeliverabilityAlert).filter(
        DeliverabilityAlert.id == alert_id
    ).first()
    
    if not alert:
        raise HTTPException(status_code=404, detail="Alert not found")
    
    alert.is_resolved = True
    alert.resolved_at = datetime.utcnow()
    db.commit()
    
    return {"message": "Alert resolved successfully"}

@router.get("/metrics/trend")
def get_deliverability_trend(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
    days: int = 30
):
    """Get deliverability trend data over time"""
    start_date = datetime.utcnow() - timedelta(days=days)
    
    # Get daily counts of issues
    blacklist_trend = db.query(
        func.date(BlacklistStatus.first_detected).label('date'),
        func.count(BlacklistStatus.id).label('new_blacklists')
    ).filter(
        BlacklistStatus.first_detected >= start_date,
        BlacklistStatus.is_listed == True
    ).group_by(func.date(BlacklistStatus.first_detected)).all()
    
    dns_trend = db.query(
        func.date(DNSAuthRecord.last_checked).label('date'),
        func.count(DNSAuthRecord.id).label('dns_issues')
    ).filter(
        DNSAuthRecord.last_checked >= start_date,
        DNSAuthRecord.is_valid == False
    ).group_by(func.date(DNSAuthRecord.last_checked)).all()
    
    alert_trend = db.query(
        func.date(DeliverabilityAlert.created_at).label('date'),
        func.count(DeliverabilityAlert.id).label('new_alerts')
    ).filter(
        DeliverabilityAlert.created_at >= start_date
    ).group_by(func.date(DeliverabilityAlert.created_at)).all()
    
    # Combine trends into daily data points
    trend_data = {}
    current_date = start_date.date()
    end_date = datetime.utcnow().date()
    
    while current_date <= end_date:
        trend_data[current_date.isoformat()] = {
            'date': current_date.isoformat(),
            'blacklist_issues': 0,
            'dns_issues': 0,
            'new_alerts': 0
        }
        current_date += timedelta(days=1)
    
    # Fill in actual data
    for date_obj, count in blacklist_trend:
        if date_obj.isoformat() in trend_data:
            trend_data[date_obj.isoformat()]['blacklist_issues'] = count
    
    for date_obj, count in dns_trend:
        if date_obj.isoformat() in trend_data:
            trend_data[date_obj.isoformat()]['dns_issues'] = count
    
    for date_obj, count in alert_trend:
        if date_obj.isoformat() in trend_data:
            trend_data[date_obj.isoformat()]['new_alerts'] = count
    
    return list(trend_data.values())

@router.post("/check/run")
def run_deliverability_check(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Manually trigger a full deliverability check"""
    monitor = DeliverabilityMonitor()
    results = monitor.run_full_check(db)
    
    return {
        "message": "Deliverability check completed",
        "results": results,
        "timestamp": datetime.utcnow()
    }

@router.get("/postmaster/data")
def get_postmaster_data(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
    days: int = 30
):
    """Get Google Postmaster Tools data"""
    start_date = datetime.utcnow() - timedelta(days=days)
    
    postmaster_data = db.query(PostmasterMetric).filter(
        PostmasterMetric.date >= start_date
    ).order_by(PostmasterMetric.date).all()
    
    return [{
        'date': metric.date,
        'domain': metric.domain,
        'reputation': metric.reputation,
        'ip_reputation': metric.ip_reputation,
        'spam_rate': metric.spam_rate,
        'feedback_loop_rate': metric.feedback_loop_rate,
        'domain_reputation': metric.domain_reputation,
        'delivery_errors': metric.delivery_errors
    } for metric in postmaster_data]

@router.get("/health-score")
def get_health_score(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get current deliverability health score and breakdown"""
    monitor = DeliverabilityMonitor()
    summary = monitor.get_deliverability_summary(db)
    
    # Get detailed breakdown
    total_blacklists = len(monitor.blacklist_providers)
    listed_blacklists = db.query(BlacklistStatus).filter(
        BlacklistStatus.is_listed == True,
        BlacklistStatus.resolved_at.is_(None)
    ).count()
    
    dns_records_checked = db.query(DNSAuthRecord).count()
    dns_records_valid = db.query(DNSAuthRecord).filter(
        DNSAuthRecord.is_valid == True
    ).count()
    
    return {
        'overall_score': summary['health_score'],
        'status': summary['status'],
        'breakdown': {
            'blacklist_health': {
                'score': max(0, ((total_blacklists - listed_blacklists) / total_blacklists) * 100) if total_blacklists > 0 else 100,
                'listed_count': listed_blacklists,
                'total_checked': total_blacklists
            },
            'dns_health': {
                'score': (dns_records_valid / dns_records_checked * 100) if dns_records_checked > 0 else 0,
                'valid_records': dns_records_valid,
                'total_records': dns_records_checked
            },
            'alert_health': {
                'open_alerts': summary['open_alerts'],
                'score': max(0, 100 - (summary['open_alerts'] * 10))  # Each alert reduces score by 10
            }
        },
        'last_updated': datetime.utcnow()
    }