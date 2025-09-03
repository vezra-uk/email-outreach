import os
import requests
import dns.resolver
import re
from typing import Dict, List, Optional, Tuple
from datetime import datetime, timedelta
from sqlalchemy.orm import Session
from logger_config import get_logger

from models import (
    DeliverabilityMetric, PostmasterMetric, BlacklistStatus, 
    DNSAuthRecord, DeliverabilityAlert
)

logger = get_logger(__name__)

class DeliverabilityMonitor:
    """Monitor email deliverability using free APIs and services"""
    
    def __init__(self):
        self.domain = os.getenv('EMAIL_DOMAIN', 'wegetyouonline.co.uk')
        self.sending_ip = os.getenv('SENDING_IP')
        
        # Free blacklist APIs
        self.blacklist_providers = [
            {'name': 'Spamhaus', 'query_format': '{ip}.zen.spamhaus.org'},
            {'name': 'SURBL', 'query_format': '{domain}.multi.surbl.org'},
            {'name': 'URIBL', 'query_format': '{domain}.multi.uribl.com'},
            {'name': 'Barracuda', 'query_format': '{ip}.b.barracudacentral.org'},
            {'name': 'SpamCop', 'query_format': '{ip}.bl.spamcop.net'}
        ]

    def check_google_postmaster_reputation(self, db: Session) -> bool:
        """
        Check Gmail reputation using Google Postmaster Tools API with OAuth2
        """
        try:
            logger.info("Checking Google Postmaster reputation with OAuth2")
            
            # Try to get postmaster data using existing OAuth2 credentials
            postmaster_data = self._get_postmaster_data_oauth2()
            
            if postmaster_data:
                # Store the postmaster metrics
                for data in postmaster_data:
                    postmaster_metric = PostmasterMetric(
                        domain=data.get('domain', self.domain),
                        date=datetime.fromisoformat(data.get('date', datetime.now().isoformat())),
                        reputation=data.get('reputation'),
                        ip_reputation=data.get('ip_reputation'), 
                        spam_rate=data.get('spam_rate'),
                        feedback_loop_rate=data.get('feedback_loop_rate'),
                        domain_reputation=data.get('domain_reputation'),
                        delivery_errors=str(data.get('delivery_errors', []))
                    )
                    db.add(postmaster_metric)
                
                # Create summary metric
                metric = DeliverabilityMetric(
                    source='postmaster',
                    domain=self.domain,
                    metric_type='reputation_data',
                    value=len(postmaster_data),
                    status='success',
                    details=f'Retrieved {len(postmaster_data)} postmaster data points'
                )
                db.add(metric)
                db.commit()
                
                logger.info(f"Google Postmaster data retrieved successfully: {len(postmaster_data)} records")
                return True
            else:
                # Create placeholder metric indicating setup needed
                metric = DeliverabilityMetric(
                    source='postmaster',
                    domain=self.domain,
                    metric_type='reputation_check',
                    status='setup_required',
                    details='Domain verification required in Google Postmaster Tools or OAuth2 scope needs postmaster.readonly'
                )
                db.add(metric)
                db.commit()
                
                logger.info("Google Postmaster check recorded (domain verification or scope required)")
                return True
            
        except Exception as e:
            logger.error(f"Failed to check Google Postmaster reputation: {e}")
            # Create error metric but don't fail the whole check
            try:
                metric = DeliverabilityMetric(
                    source='postmaster',
                    domain=self.domain,
                    metric_type='reputation_check',
                    status='error',
                    details=f'Error accessing postmaster data: {str(e)}'
                )
                db.add(metric)
                db.commit()
            except:
                pass
            return False

    def _get_postmaster_data_oauth2(self) -> Optional[List[Dict]]:
        """Get postmaster data using OAuth2 credentials"""
        try:
            from google.oauth2.credentials import Credentials
            from googleapiclient.discovery import build
            
            # Check if we have the required credentials
            refresh_token = os.getenv('GMAIL_REFRESH_TOKEN')
            client_id = os.getenv('GMAIL_CLIENT_ID')
            client_secret = os.getenv('GMAIL_CLIENT_SECRET')
            
            if not all([refresh_token, client_id, client_secret]):
                logger.warning("Missing OAuth2 credentials for Postmaster Tools")
                return None
            
            # Use existing Gmail OAuth2 credentials with postmaster scope
            creds = Credentials(
                token=None,
                refresh_token=refresh_token,
                id_token=None,
                client_id=client_id,
                client_secret=client_secret,
                token_uri='https://oauth2.googleapis.com/token',
                scopes=['https://www.googleapis.com/auth/postmaster.readonly']
            )
            
            # Build the Postmaster Tools service
            service = build('gmailpostmastertools', 'v1', credentials=creds)
            
            # List domains that the user has access to
            domains_result = service.domains().list().execute()
            domains = domains_result.get('domains', [])
            
            if not domains:
                logger.warning("No verified domains found in Google Postmaster Tools")
                return None
            
            # Get traffic stats for the first domain (or matching domain)
            target_domain = None
            for domain_info in domains:
                domain_name = domain_info.get('name', '').replace('domains/', '')
                if domain_name == self.domain or not target_domain:
                    target_domain = domain_info.get('name')
                    break
            
            if not target_domain:
                logger.warning(f"Domain {self.domain} not found in verified domains: {[d.get('name', '').replace('domains/', '') for d in domains]}")
                return None
            
            # Get recent traffic stats (last 7 days)
            from datetime import timedelta
            end_date = datetime.now()
            start_date = end_date - timedelta(days=7)
            
            traffic_stats = service.domains().trafficStats().list(
                parent=target_domain,
                startDate={
                    'year': start_date.year,
                    'month': start_date.month,
                    'day': start_date.day
                },
                endDate={
                    'year': end_date.year,
                    'month': end_date.month,
                    'day': end_date.day
                }
            ).execute()
            
            stats = traffic_stats.get('trafficStats', [])
            
            # Convert to our format
            postmaster_data = []
            for stat in stats:
                date_info = stat.get('date', {})
                date_str = f"{date_info.get('year', end_date.year)}-{date_info.get('month', end_date.month):02d}-{date_info.get('day', end_date.day):02d}"
                
                postmaster_data.append({
                    'domain': target_domain.replace('domains/', ''),
                    'date': date_str,
                    'reputation': stat.get('domainReputation'),
                    'ip_reputation': stat.get('ipReputations', [{}])[0].get('reputation') if stat.get('ipReputations') else None,
                    'spam_rate': stat.get('spamRate'),
                    'feedback_loop_rate': stat.get('feedbackLoopRate'), 
                    'domain_reputation': stat.get('domainReputation'),
                    'delivery_errors': stat.get('deliveryErrors', [])
                })
            
            logger.info(f"Retrieved {len(postmaster_data)} postmaster data points for domain {target_domain.replace('domains/', '')}")
            return postmaster_data
            
        except ImportError:
            logger.error("Google API client not available. Install with: pip install google-api-python-client google-auth")
            return None
        except Exception as e:
            logger.warning(f"Failed to get postmaster data via OAuth2: {e}")
            return None

    def check_blacklists(self, db: Session) -> bool:
        """Check domain and IP against major free blacklists"""
        try:
            logger.info(f"Checking blacklists for domain: {self.domain}")
            
            for provider in self.blacklist_providers:
                try:
                    # Check domain-based blacklists
                    if '{domain}' in provider['query_format']:
                        query_host = provider['query_format'].format(domain=self.domain)
                        is_listed = self._dns_blacklist_check(query_host)
                        
                        self._record_blacklist_status(
                            db, self.domain, None, provider['name'], is_listed
                        )
                    
                    # Check IP-based blacklists if we have sending IP
                    elif self.sending_ip and '{ip}' in provider['query_format']:
                        # Reverse IP for DNS lookup
                        reversed_ip = '.'.join(reversed(self.sending_ip.split('.')))
                        query_host = provider['query_format'].format(ip=reversed_ip)
                        is_listed = self._dns_blacklist_check(query_host)
                        
                        self._record_blacklist_status(
                            db, None, self.sending_ip, provider['name'], is_listed
                        )
                        
                except Exception as e:
                    logger.error(f"Failed to check {provider['name']} blacklist: {e}")
                    continue
            
            logger.info("Blacklist checks completed")
            return True
            
        except Exception as e:
            logger.error(f"Failed to run blacklist checks: {e}")
            return False

    def _dns_blacklist_check(self, query_host: str) -> bool:
        """Perform DNS lookup to check blacklist status"""
        try:
            dns.resolver.resolve(query_host, 'A')
            return True  # If DNS resolves, it's listed
        except dns.resolver.NXDOMAIN:
            return False  # Not listed
        except Exception as e:
            logger.warning(f"DNS lookup failed for {query_host}: {e}")
            return False

    def _record_blacklist_status(self, db: Session, domain: Optional[str], 
                                ip: Optional[str], blacklist_name: str, is_listed: bool):
        """Record blacklist status in database"""
        try:
            # Check if we already have a record
            existing = db.query(BlacklistStatus).filter(
                BlacklistStatus.domain == domain,
                BlacklistStatus.ip_address == ip,
                BlacklistStatus.blacklist_name == blacklist_name,
                BlacklistStatus.resolved_at.is_(None)
            ).first()
            
            if existing:
                # Update existing record
                existing.is_listed = is_listed
                existing.last_checked = datetime.utcnow()
                
                # If previously listed but now clean, mark as resolved
                if existing.is_listed and not is_listed:
                    existing.resolved_at = datetime.utcnow()
                    
            else:
                # Create new record
                status = BlacklistStatus(
                    domain=domain,
                    ip_address=ip,
                    blacklist_name=blacklist_name,
                    is_listed=is_listed,
                    first_detected=datetime.utcnow() if is_listed else None
                )
                db.add(status)
            
            # Create alert if newly listed
            if is_listed and (not existing or not existing.is_listed):
                alert = DeliverabilityAlert(
                    alert_type='blacklist',
                    severity='high',
                    title=f'Blacklisted by {blacklist_name}',
                    description=f'{"Domain" if domain else "IP"} {domain or ip} has been listed on {blacklist_name}',
                    domain=domain or ip
                )
                db.add(alert)
                
            db.commit()
            
        except Exception as e:
            logger.error(f"Failed to record blacklist status: {e}")

    def check_dns_authentication(self, db: Session) -> bool:
        """Check SPF, DKIM, and DMARC records"""
        try:
            logger.info(f"Checking DNS authentication records for {self.domain}")
            
            # Check SPF record
            spf_valid, spf_record, spf_errors = self._check_spf_record()
            self._record_dns_auth(db, 'SPF', spf_record, spf_valid, spf_errors)
            
            # Check DMARC record
            dmarc_valid, dmarc_record, dmarc_errors = self._check_dmarc_record()
            self._record_dns_auth(db, 'DMARC', dmarc_record, dmarc_valid, dmarc_errors)
            
            # Note: DKIM checking requires knowing the selector, which varies
            # We'll add a placeholder for now
            self._record_dns_auth(db, 'DKIM', 'Requires selector configuration', False, ['DKIM selector not configured'])
            
            logger.info("DNS authentication checks completed")
            return True
            
        except Exception as e:
            logger.error(f"Failed to check DNS authentication: {e}")
            return False

    def _check_spf_record(self) -> Tuple[bool, Optional[str], List[str]]:
        """Check SPF record validity"""
        try:
            answers = dns.resolver.resolve(self.domain, 'TXT')
            spf_record = None
            
            for answer in answers:
                record = str(answer).strip('"')
                if record.startswith('v=spf1'):
                    spf_record = record
                    break
            
            if not spf_record:
                return False, None, ['No SPF record found']
            
            # Basic SPF validation
            errors = []
            if not spf_record.endswith(('~all', '-all', '?all', '+all')):
                errors.append('SPF record should end with all mechanism')
            
            return len(errors) == 0, spf_record, errors
            
        except Exception as e:
            return False, None, [f'SPF check failed: {str(e)}']

    def _check_dmarc_record(self) -> Tuple[bool, Optional[str], List[str]]:
        """Check DMARC record validity"""
        try:
            answers = dns.resolver.resolve(f'_dmarc.{self.domain}', 'TXT')
            dmarc_record = None
            
            for answer in answers:
                record = str(answer).strip('"')
                if record.startswith('v=DMARC1'):
                    dmarc_record = record
                    break
            
            if not dmarc_record:
                return False, None, ['No DMARC record found']
            
            # Basic DMARC validation
            errors = []
            if 'p=' not in dmarc_record:
                errors.append('DMARC record missing policy (p=)')
            
            return len(errors) == 0, dmarc_record, errors
            
        except Exception as e:
            return False, None, [f'DMARC check failed: {str(e)}']

    def _record_dns_auth(self, db: Session, record_type: str, record_value: Optional[str], 
                        is_valid: bool, errors: List[str]):
        """Record DNS authentication status"""
        try:
            # Update or create DNS auth record
            auth_record = db.query(DNSAuthRecord).filter(
                DNSAuthRecord.domain == self.domain,
                DNSAuthRecord.record_type == record_type
            ).first()
            
            if auth_record:
                auth_record.record_value = record_value
                auth_record.is_valid = is_valid
                auth_record.validation_errors = str(errors) if errors else None
                auth_record.last_checked = datetime.utcnow()
            else:
                auth_record = DNSAuthRecord(
                    domain=self.domain,
                    record_type=record_type,
                    record_value=record_value,
                    is_valid=is_valid,
                    validation_errors=str(errors) if errors else None
                )
                db.add(auth_record)
            
            # Create alert for invalid records
            if not is_valid:
                alert = DeliverabilityAlert(
                    alert_type='dns',
                    severity='medium',
                    title=f'{record_type} Record Issue',
                    description=f'{record_type} record for {self.domain} has validation errors: {", ".join(errors)}',
                    domain=self.domain
                )
                db.add(alert)
            
            db.commit()
            
        except Exception as e:
            logger.error(f"Failed to record DNS auth status: {e}")

    def run_full_check(self, db: Session) -> Dict[str, bool]:
        """Run all deliverability checks"""
        logger.info("Starting full deliverability check")
        
        results = {
            'postmaster': False,
            'blacklists': False,
            'dns_auth': False
        }
        
        try:
            results['postmaster'] = self.check_google_postmaster_reputation(db)
            results['blacklists'] = self.check_blacklists(db)
            results['dns_auth'] = self.check_dns_authentication(db)
            
            # Record overall metric
            overall_metric = DeliverabilityMetric(
                source='monitor',
                domain=self.domain,
                metric_type='full_check',
                value=sum(results.values()),
                status='completed',
                details=f'Completed checks: {", ".join([k for k, v in results.items() if v])}'
            )
            db.add(overall_metric)
            db.commit()
            
            logger.info(f"Full deliverability check completed: {results}")
            return results
            
        except Exception as e:
            logger.error(f"Failed to run full deliverability check: {e}")
            return results

    def get_deliverability_summary(self, db: Session) -> Dict:
        """Get current deliverability status summary"""
        try:
            # Get latest blacklist status
            blacklist_issues = db.query(BlacklistStatus).filter(
                BlacklistStatus.domain == self.domain,
                BlacklistStatus.is_listed == True,
                BlacklistStatus.resolved_at.is_(None)
            ).count()
            
            # Get DNS auth status
            dns_issues = db.query(DNSAuthRecord).filter(
                DNSAuthRecord.domain == self.domain,
                DNSAuthRecord.is_valid == False
            ).count()
            
            # Get unresolved alerts
            open_alerts = db.query(DeliverabilityAlert).filter(
                DeliverabilityAlert.domain == self.domain,
                DeliverabilityAlert.is_resolved == False
            ).count()
            
            # Calculate overall health score
            total_checks = 3  # blacklists, dns, alerts
            issues = min(blacklist_issues + dns_issues, total_checks)
            health_score = ((total_checks - issues) / total_checks) * 100
            
            return {
                'health_score': health_score,
                'blacklist_issues': blacklist_issues,
                'dns_issues': dns_issues,
                'open_alerts': open_alerts,
                'status': 'good' if health_score >= 80 else 'warning' if health_score >= 60 else 'critical'
            }
            
        except Exception as e:
            logger.error(f"Failed to get deliverability summary: {e}")
            return {
                'health_score': 0,
                'blacklist_issues': 0,
                'dns_issues': 0,
                'open_alerts': 0,
                'status': 'unknown'
            }