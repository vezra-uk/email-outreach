from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

class LinkClickResponse(BaseModel):
    id: int
    tracking_id: str
    original_url: str
    ip_address: str
    user_agent: str
    referer: str
    clicked_at: datetime
    campaign_info: Optional[dict] = None
    sequence_info: Optional[dict] = None
    lead_info: Optional[dict] = None
    
    class Config:
        from_attributes = True

class ClickAnalytics(BaseModel):
    total_clicks: int
    unique_clicks: int
    click_rate: float
    most_clicked_links: List[dict]
    recent_clicks: List[LinkClickResponse]