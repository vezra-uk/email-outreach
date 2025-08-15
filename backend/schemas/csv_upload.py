from pydantic import BaseModel
from typing import List

class CSVUploadRequest(BaseModel):
    csv_content: str
    column_mapping: dict
    has_header: bool = True

class CSVPreviewRequest(BaseModel):
    csv_content: str
    has_header: bool = True

class CSVPreviewResponse(BaseModel):
    headers: List[str]
    sample_data: List[List[str]]
    total_rows: int
    detected_columns: dict