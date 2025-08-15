from pydantic import BaseModel

class DashboardStats(BaseModel):
    total_leads: int
    emails_sent_today: int
    emails_opened_today: int
    active_campaigns: int
    daily_limit: int