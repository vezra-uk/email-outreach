from pydantic import BaseModel
from typing import Optional

class MessagePreviewRequest(BaseModel):
    template: str
    ai_prompt: str
    lead_id: int
    sending_profile_id: Optional[int] = None

class MessagePreviewResponse(BaseModel):
    original_template: str
    personalized_message: str
    subject: str
    lead_info: dict