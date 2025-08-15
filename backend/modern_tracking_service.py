"""
Modern Email Open Detection Service
Multi-signal approach to maximize open tracking accuracy
"""

import time
import json
import re
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
from urllib.parse import unquote
import uuid

@dataclass
class TrackingSignal:
    event_type: str
    signal_type: str
    confidence: float
    metadata: Dict
    timestamp: datetime

class ModernOpenTracker:
    
    # Known email client prefetch patterns
    PREFETCH_USER_AGENTS = [
        'AppleWebKit/605.1.15',  # Apple Mail Privacy Protection
        'Mozilla/5.0 (iPhone; CPU iPhone OS',  # iOS Mail app prefetch
        'Mozilla/5.0 (Macintosh; Intel Mac OS X',  # macOS Mail prefetch
        'outlook',  # Outlook prefetch
        'MailKit',  # Various mail clients
    ]
    
    # Suspicious timing patterns (too fast = prefetch)
    SUSPICIOUS_TIMING_THRESHOLD = 2  # seconds
    
    def __init__(self):
        self.tracking_signals = {}
    
    def generate_multi_signal_tracking(self, tracking_id: str, domain: str) -> Dict[str, str]:
        """Generate multiple tracking elements for comprehensive detection"""
        
        # Primary pixel - immediate load
        primary_pixel = f'''<img src="https://{domain}/api/track/signal/{tracking_id}/primary" width="1" height="1" style="opacity:0;max-height:0;overflow:hidden;" alt="">'''
        
        # Secondary pixel - delayed load via CSS
        secondary_pixel = f'''
        <style>
        .track-secondary-{tracking_id[-8:]} {{
            background-image: url('https://{domain}/api/track/signal/{tracking_id}/secondary');
            width: 0px; height: 0px; opacity: 0;
        }}
        </style>
        <div class="track-secondary-{tracking_id[-8:]}"></div>
        '''
        
        # Tertiary pixel - content-based loading
        content_pixel = f'''<img src="https://{domain}/api/track/signal/{tracking_id}/content" width="1" height="1" style="display:block;visibility:hidden;position:absolute;top:-1px;" alt="">'''
        
        # Interactive element tracking
        interactive_link = f'''<a href="https://{domain}/api/track/view/{tracking_id}" style="color:#f8f9fa;font-size:1px;text-decoration:none;display:block;height:1px;overflow:hidden;">.</a>'''
        
        # JavaScript-based tracking (for clients that support it)
        js_tracking = f'''
        <script type="text/javascript">
        (function() {{
            setTimeout(function() {{
                var img = new Image();
                img.src = 'https://{domain}/api/track/signal/{tracking_id}/js?t=' + Date.now();
            }}, 1000);
        }})();
        </script>
        '''
        
        return {
            'primary': primary_pixel,
            'secondary': secondary_pixel,
            'content': content_pixel,
            'interactive': interactive_link,
            'javascript': js_tracking
        }
    
    def analyze_user_agent(self, user_agent: str) -> Tuple[bool, float]:
        """Analyze user agent to detect prefetch behavior"""
        if not user_agent:
            return True, 0.3  # Suspicious but possible
        
        user_agent_lower = user_agent.lower()
        
        # Check for known prefetch patterns
        for prefetch_pattern in self.PREFETCH_USER_AGENTS:
            if prefetch_pattern.lower() in user_agent_lower:
                return True, 0.1  # Likely prefetch
        
        # Check for automation indicators
        automation_indicators = ['bot', 'crawler', 'spider', 'automated', 'headless']
        for indicator in automation_indicators:
            if indicator in user_agent_lower:
                return True, 0.0  # Definitely automated
        
        # Real user patterns
        real_user_indicators = ['chrome', 'firefox', 'safari', 'edge', 'opera']
        for indicator in real_user_indicators:
            if indicator in user_agent_lower:
                return False, 0.8  # Likely real user
        
        return False, 0.5  # Unknown but assume real
    
    def analyze_timing(self, send_time: datetime, open_time: datetime) -> Tuple[bool, float]:
        """Analyze timing patterns to detect prefetch vs real opens"""
        time_diff = (open_time - send_time).total_seconds()
        
        # Too fast = likely prefetch
        if time_diff < self.SUSPICIOUS_TIMING_THRESHOLD:
            return True, 0.1
        
        # Very fast but not impossible
        if time_diff < 10:
            return False, 0.4
        
        # Normal human timing
        if time_diff < 3600:  # Within an hour
            return False, 0.9
        
        # Delayed but still valid
        return False, 0.7
    
    def calculate_confidence_score(self, signals: List[TrackingSignal], 
                                 send_time: datetime) -> float:
        """Calculate overall confidence that the email was actually opened by a human"""
        if not signals:
            return 0.0
        
        total_confidence = 0.0
        signal_weights = {
            'primary': 0.4,
            'secondary': 0.5,
            'content': 0.5,
            'interactive': 0.8,  # High weight for clicks
            'javascript': 0.7,   # High weight for JS execution
            'view_browser': 0.9  # Very high weight for browser views
        }
        
        # Time-based analysis
        timing_scores = []
        prefetch_indicators = 0
        
        for signal in signals:
            # Weight by signal type
            weight = signal_weights.get(signal.signal_type, 0.1)
            signal_score = signal.confidence * weight
            
            # Timing analysis
            is_prefetch, timing_confidence = self.analyze_timing(send_time, signal.timestamp)
            if is_prefetch:
                prefetch_indicators += 1
                signal_score *= 0.3  # Reduce score for suspicious timing
            else:
                signal_score *= timing_confidence
            
            total_confidence += signal_score
            timing_scores.append(timing_confidence)
        
        # Normalize by number of signals
        base_confidence = total_confidence / len(signals)
        
        # Apply penalties for prefetch indicators
        prefetch_ratio = prefetch_indicators / len(signals)
        prefetch_penalty = 1.0 - (prefetch_ratio * 0.7)
        
        # Bonus for multiple diverse signals
        signal_types = set(s.signal_type for s in signals)
        diversity_bonus = min(len(signal_types) * 0.1, 0.3)
        
        final_confidence = (base_confidence * prefetch_penalty) + diversity_bonus
        
        return min(max(final_confidence, 0.0), 1.0)
    
    def record_tracking_signal(self, tracking_id: str, signal_type: str, 
                             user_agent: str, ip_address: str, 
                             send_time: datetime) -> TrackingSignal:
        """Record and analyze a tracking signal"""
        
        timestamp = datetime.utcnow()
        
        # Analyze user agent
        is_prefetch_ua, ua_confidence = self.analyze_user_agent(user_agent)
        
        # Analyze timing
        is_prefetch_timing, timing_confidence = self.analyze_timing(send_time, timestamp)
        
        # Calculate signal confidence
        base_confidence = 0.8 if not (is_prefetch_ua or is_prefetch_timing) else 0.2
        adjusted_confidence = base_confidence * ua_confidence * timing_confidence
        
        # Create signal
        signal = TrackingSignal(
            event_type='pixel_load',
            signal_type=signal_type,
            confidence=adjusted_confidence,
            metadata={
                'user_agent': user_agent,
                'ip_address': ip_address,
                'is_prefetch_ua': is_prefetch_ua,
                'is_prefetch_timing': is_prefetch_timing,
                'ua_confidence': ua_confidence,
                'timing_confidence': timing_confidence,
                'delay_seconds': (timestamp - send_time).total_seconds()
            },
            timestamp=timestamp
        )
        
        # Store signal
        if tracking_id not in self.tracking_signals:
            self.tracking_signals[tracking_id] = []
        self.tracking_signals[tracking_id].append(signal)
        
        return signal
    
    def get_open_analysis(self, tracking_id: str, send_time: datetime) -> Dict:
        """Get comprehensive open analysis for a tracking ID"""
        signals = self.tracking_signals.get(tracking_id, [])
        
        if not signals:
            return {
                'is_opened': False,
                'confidence_score': 0.0,
                'total_signals': 0,
                'analysis': 'No tracking signals detected'
            }
        
        confidence_score = self.calculate_confidence_score(signals, send_time)
        
        # Determine if opened based on confidence threshold
        is_opened = confidence_score > 0.3
        
        # Detailed analysis
        signal_types = [s.signal_type for s in signals]
        unique_ips = len(set(s.metadata.get('ip_address', '') for s in signals))
        
        analysis = {
            'is_opened': is_opened,
            'confidence_score': confidence_score,
            'total_signals': len(signals),
            'signal_types': signal_types,
            'unique_ip_count': unique_ips,
            'first_signal_at': min(s.timestamp for s in signals),
            'last_signal_at': max(s.timestamp for s in signals),
            'prefetch_signals': sum(1 for s in signals if s.confidence < 0.3),
            'high_confidence_signals': sum(1 for s in signals if s.confidence > 0.7),
            'analysis': self._generate_analysis_text(signals, confidence_score)
        }
        
        return analysis
    
    def _generate_analysis_text(self, signals: List[TrackingSignal], confidence: float) -> str:
        """Generate human-readable analysis"""
        if confidence > 0.8:
            return "High confidence: Multiple indicators suggest genuine human engagement"
        elif confidence > 0.5:
            return "Moderate confidence: Likely opened by human user"
        elif confidence > 0.3:
            return "Low confidence: Possible automated prefetch or brief glimpse"
        else:
            return "Very low confidence: Likely automated system or mail scanner"

# Global tracker instance
modern_tracker = ModernOpenTracker()