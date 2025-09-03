from sqlalchemy import Column, Integer, String, Float, DateTime, Text, Boolean
from sqlalchemy.sql import func
from .base import Base

class DeliverabilityMetric(Base):
    """Store deliverability metrics from various sources"""
    __tablename__ = "deliverability_metrics"
    
    id = Column(Integer, primary_key=True, index=True)
    source = Column(String(50), nullable=False)  # 'postmaster', 'blacklist', 'dns'
    domain = Column(String(255), nullable=False)
    metric_type = Column(String(100), nullable=False)  # 'reputation', 'spam_rate', 'blacklist_status'
    value = Column(Float)  # Numeric values like reputation score
    status = Column(String(50))  # Text status like 'clean', 'listed', 'good'
    details = Column(Text)  # JSON or detailed information
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class PostmasterMetric(Base):
    """Google Postmaster Tools specific metrics"""
    __tablename__ = "postmaster_metrics"
    
    id = Column(Integer, primary_key=True, index=True)
    domain = Column(String(255), nullable=False)
    date = Column(DateTime, nullable=False)
    reputation = Column(String(20))  # HIGH, MEDIUM, LOW, BAD
    ip_reputation = Column(String(20))
    spam_rate = Column(Float)  # Percentage
    feedback_loop_rate = Column(Float)  # Percentage
    domain_reputation = Column(String(20))
    delivery_errors = Column(Text)  # JSON array of error details
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class BlacklistStatus(Base):
    """Track blacklist status across different providers"""
    __tablename__ = "blacklist_status"
    
    id = Column(Integer, primary_key=True, index=True)
    domain = Column(String(255))
    ip_address = Column(String(45))  # Support IPv6
    blacklist_name = Column(String(100), nullable=False)  # spamhaus, surbl, etc.
    is_listed = Column(Boolean, nullable=False)
    listing_reason = Column(Text)
    first_detected = Column(DateTime, nullable=False)
    last_checked = Column(DateTime(timezone=True), server_default=func.now())
    resolved_at = Column(DateTime)

class DNSAuthRecord(Base):
    """Track DNS authentication record status"""
    __tablename__ = "dns_auth_records"
    
    id = Column(Integer, primary_key=True, index=True)
    domain = Column(String(255), nullable=False)
    record_type = Column(String(10), nullable=False)  # SPF, DKIM, DMARC
    record_value = Column(Text)
    is_valid = Column(Boolean, nullable=False)
    validation_errors = Column(Text)  # JSON array of validation issues
    last_checked = Column(DateTime(timezone=True), server_default=func.now())

class DeliverabilityAlert(Base):
    """Store deliverability alerts and notifications"""
    __tablename__ = "deliverability_alerts"
    
    id = Column(Integer, primary_key=True, index=True)
    alert_type = Column(String(50), nullable=False)  # 'blacklist', 'reputation', 'dns'
    severity = Column(String(20), nullable=False)  # 'low', 'medium', 'high', 'critical'
    title = Column(String(255), nullable=False)
    description = Column(Text, nullable=False)
    domain = Column(String(255))
    is_resolved = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    resolved_at = Column(DateTime)