from pydantic import BaseModel
from typing import List, Optional

class CSVUploadRequest(BaseModel):
    csv_content: str
    column_mapping: dict
    has_header: bool = True
    group_id: Optional[int] = None
    new_group_name: Optional[str] = None

class CSVPreviewRequest(BaseModel):
    csv_content: str
    has_header: bool = True

class CSVPreviewResponse(BaseModel):
    headers: List[str]
    sample_data: List[List[str]]
    total_rows: int
    detected_columns: dict