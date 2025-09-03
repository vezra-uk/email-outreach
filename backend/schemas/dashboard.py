from pydantic import BaseModel
from datetime import datetime
from typing import List, Optional

class ActivityEvent(BaseModel):
    id: int
    type: str  # 'email_sent', 'email_opened', 'email_clicked', 'campaign_started', 'lead_added'
    title: str
    description: str
    timestamp: datetime
    campaign_name: Optional[str] = None
    lead_email: Optional[str] = None
    metadata: Optional[dict] = None

class TodaysHighlight(BaseModel):
    type: str  # 'top_campaign', 'milestone', 'goal_progress'
    title: str
    value: str
    description: str
    is_positive: bool = True

class DashboardStats(BaseModel):
    total_leads: int
    emails_sent_today: int
    emails_opened_today: int
    active_campaigns: int
    daily_limit: int

class TodayActivity(BaseModel):
    recent_events: List[ActivityEvent]
    highlights: List[TodaysHighlight]
    hourly_send_rate: List[int]  # Array of 24 hours showing sends per hour
    live_metrics: dict  # Real-time stats like current open rate, etc.