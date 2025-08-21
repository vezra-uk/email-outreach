import logging
import requests
import uuid
import time
from typing import Dict, Optional, Tuple
from datetime import datetime
from logger_config import get_logger

logger = get_logger(__name__)

class SpamChecker:
    def __init__(self, rspamd_host="rspamd", rspamd_port=11333):
        self.host = rspamd_host
        self.port = rspamd_port
        self.rspamd_url = f"http://{rspamd_host}:{rspamd_port}"
        
    def check_email_spam_score(self, subject: str, content: str) -> Tuple[bool, float, str]:
        """
        Check email spam score using Rspamd
        Returns: (is_spam, spam_score, detailed_report)
        """
        logger.info("Checking email spam score with Rspamd", extra={
            "subject_length": len(subject),
            "content_length": len(content)
        })
        
        try:
            # Format email for Rspamd
            email_text = self._format_email_for_rspamd(subject, content)
            
            # Send POST request to Rspamd scan endpoint
            response = requests.post(
                f"{self.rspamd_url}/scan",
                data=email_text.encode('utf-8'),
                headers={'Content-Type': 'text/plain'},
                timeout=15
            )
            
            if response.status_code == 200:
                result = response.json()
                scan_result = result.get('default', result)
                
                spam_score = scan_result.get('score', 0.0)
                action = scan_result.get('action', 'no action')
                is_spam_flag = scan_result.get('is_spam', False)
                required_score = scan_result.get('required_score', 15.0)
                
                # Determine if spam based on Rspamd's action and score  
                # Only treat as spam if action is explicitly reject/soft reject or score is very high
                spam_actions = ['reject', 'soft reject']
                adjusted_threshold = 7.5  # Allow for hostname issues in test environment  
                is_spam = action in spam_actions or spam_score >= adjusted_threshold
                
                report = f"Action: {action}, Score: {spam_score}/{required_score}"
                
                logger.info("Rspamd check completed", extra={
                    "is_spam": is_spam,
                    "spam_score": spam_score,
                    "action": action
                })
                
                return is_spam, spam_score, report
            else:
                logger.warning(f"Rspamd returned status {response.status_code}")
                return False, 0.0, f"Rspamd check failed with status {response.status_code}"
            
        except Exception as e:
            logger.error("Failed to check spam score", extra={
                "error": str(e),
                "error_type": type(e).__name__
            }, exc_info=True)
            return False, 0.0, f"Spam check failed: {str(e)}"
    
    def get_detailed_spam_report(self, subject: str, content: str) -> Tuple[bool, float, str, Dict]:
        """
        Get detailed spam report from Rspamd
        Returns: (is_spam, spam_score, detailed_report, analysis_dict)
        """
        logger.info("Getting detailed spam report from Rspamd")
        
        try:
            email_text = self._format_email_for_rspamd(subject, content)
            
            # Use /scan endpoint for detailed analysis
            response = requests.post(
                f"{self.rspamd_url}/scan",
                data=email_text.encode('utf-8'),
                headers={'Content-Type': 'text/plain'},
                timeout=15
            )
            
            if response.status_code == 200:
                result = response.json()
                scan_result = result.get('default', result)
                
                spam_score = scan_result.get('score', 0.0)
                action = scan_result.get('action', 'no action')
                is_spam_flag = scan_result.get('is_spam', False)
                required_score = scan_result.get('required_score', 15.0)
                
                # Determine if spam based on Rspamd's action and score  
                # Only treat as spam if action is explicitly reject/soft reject or score is very high
                spam_actions = ['reject', 'soft reject']
                adjusted_threshold = 7.5  # Allow for hostname issues in test environment  
                is_spam = action in spam_actions or spam_score >= adjusted_threshold
                
                # Get symbols (triggered rules) - they're at the root level
                symbols = {k: v for k, v in scan_result.items() 
                          if k not in ['score', 'action', 'is_spam', 'is_skipped', 'required_score']}
                
                # Create detailed analysis
                analysis = {
                    'triggered_rules': [],
                    'suggestions': [],
                    'content_analysis': {
                        'action': action,
                        'score': spam_score,
                        'symbols_count': len(symbols)
                    }
                }
                
                # Parse symbols into triggered rules
                for symbol_name, symbol_info in symbols.items():
                    if isinstance(symbol_info, dict) and 'score' in symbol_info:
                        analysis['triggered_rules'].append({
                            'rule': symbol_name,
                            'score': symbol_info.get('score', 0.0),
                            'description': symbol_info.get('description', 'No description')
                        })
                    elif isinstance(symbol_info, (int, float)):
                        analysis['triggered_rules'].append({
                            'rule': symbol_name,
                            'score': float(symbol_info),
                            'description': 'No description'
                        })
                
                # Generate suggestions
                analysis['suggestions'] = self._generate_suggestions(analysis['triggered_rules'])
                
                detailed_report = f"Action: {action}, Score: {spam_score}/{required_score}"
                if symbols:
                    top_symbols = list(symbols.items())[:5]
                    detailed_report += f", Top symbols: {', '.join([f'{k}({v})' for k, v in top_symbols])}"
                
                logger.info("Detailed spam report completed", extra={
                    "is_spam": is_spam,
                    "spam_score": spam_score,
                    "rules_triggered": len(analysis['triggered_rules'])
                })
                
                return is_spam, spam_score, detailed_report, analysis
            else:
                logger.warning(f"Rspamd returned status {response.status_code}")
                return False, 0.0, f"Detailed spam check failed with status {response.status_code}", {}
            
        except Exception as e:
            logger.error("Failed to get detailed spam report", extra={
                "error": str(e),
                "error_type": type(e).__name__
            }, exc_info=True)
            return False, 0.0, f"Detailed spam check failed: {str(e)}", {}
    
    def _format_email_for_rspamd(self, subject: str, content: str) -> str:
        """Format email content for Rspamd analysis (RFC2822 format)"""
        email = f"""From: sender@example.com
To: recipient@example.com
Subject: {subject}
Date: {datetime.now().strftime('%a, %d %b %Y %H:%M:%S +0000')}
Message-ID: <{int(time.time())}.{uuid.uuid4().hex[:8]}@example.com>
MIME-Version: 1.0
Content-Type: text/plain; charset=UTF-8

{content}"""
        return email
    
    def _generate_suggestions(self, triggered_rules: list) -> list:
        """Generate improvement suggestions based on triggered Rspamd rules"""
        suggestions = []
        
        # Rspamd rule-based suggestions mapping
        rule_suggestions = {
            'R_SUSPICIOUS_URL': 'Remove suspicious URLs or use reputable domains',
            'R_BAD_CTE_7BIT': 'Fix email encoding issues',
            'SUBJ_ALL_CAPS': 'Use normal capitalization in subject line',
            'UPPERCASE_50_75': 'Reduce ALL CAPS text - use normal capitalization', 
            'MANY_EXCLAMATIONS': 'Reduce excessive exclamation marks',
            'MONEY_MENTIONS': 'Remove or reduce mentions of money and prices',
            'FREE_': 'Replace "free" with alternatives like "complimentary"',
            'URGENT_': 'Remove urgent language and time pressure phrases',
            'CLICK_HERE': 'Replace "click here" with descriptive link text',
            'HTML_': 'Simplify HTML formatting or use plain text',
            'BAYES_SPAM': 'Content appears too promotional - make more conversational',
            'R_SUSPICIOUS_': 'Remove suspicious patterns in content',
            'R_DKIM': 'Email authentication issue - check DKIM setup',
            'R_SPF': 'SPF record issue - check DNS configuration',
            'FORGED_': 'Email headers appear suspicious',
        }
        
        for rule in triggered_rules:
            rule_name = rule['rule']
            score = rule.get('score', 0.0)
            
            # Skip very low scoring rules
            if abs(score) < 0.5:
                continue
                
            for pattern, suggestion in rule_suggestions.items():
                if pattern in rule_name and suggestion not in suggestions:
                    suggestions.append(f"Rule {rule_name} (Score: {score:.1f}): {suggestion}")
        
        # Generic suggestions if score is high but no specific rules matched
        if not suggestions and any(abs(rule.get('score', 0)) > 2.0 for rule in triggered_rules):
            suggestions.extend([
                'Make content more conversational and less sales-focused',
                'Personalize the message with specific recipient details', 
                'Remove promotional language and focus on providing value',
                'Use plain text format instead of HTML',
                'Check email authentication (SPF, DKIM, DMARC)',
            ])
        
        return suggestions[:10]  # Limit to top 10 suggestions