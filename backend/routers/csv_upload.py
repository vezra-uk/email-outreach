from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session
import csv
import io

from database import get_db
from models import Lead
from models.user import User
from models.groups import LeadGroup, LeadGroupMembership
from schemas.csv_upload import CSVUploadRequest, CSVPreviewRequest, CSVPreviewResponse
from schemas.lead import LeadCreate, LeadResponse
from schemas.groups import LeadGroupCreate
from dependencies import get_current_active_user

router = APIRouter(prefix="/leads/csv", tags=["csv"])

@router.post("/preview", response_model=CSVPreviewResponse)
def preview_csv(csv_request: CSVPreviewRequest, current_user: User = Depends(get_current_active_user)):
    csv_reader = csv.reader(io.StringIO(csv_request.csv_content))
    rows = list(csv_reader)
    
    if not rows:
        raise HTTPException(status_code=400, detail="CSV file is empty")
    
    headers = []
    sample_data = []
    start_row = 0
    
    if csv_request.has_header:
        headers = rows[0] if rows else []
        start_row = 1
    else:
        if rows:
            headers = [f"Column {i+1}" for i in range(len(rows[0]))]
    
    sample_data = rows[start_row:start_row + 5]
    
    detected_columns = {}
    for i, header in enumerate(headers):
        header_lower = header.lower().strip()
        
        if any(keyword in header_lower for keyword in ['email', 'mail', 'e-mail']):
            detected_columns[header] = 'email'
        elif any(keyword in header_lower for keyword in ['first', 'fname', 'firstname', 'given']):
            detected_columns[header] = 'first_name'
        elif any(keyword in header_lower for keyword in ['last', 'lname', 'lastname', 'surname', 'family']):
            detected_columns[header] = 'last_name'
        elif any(keyword in header_lower for keyword in ['company', 'organization', 'org', 'business', 'employer']):
            detected_columns[header] = 'company'
        elif any(keyword in header_lower for keyword in ['title', 'position', 'job', 'role']):
            detected_columns[header] = 'title'
        elif any(keyword in header_lower for keyword in ['phone', 'tel', 'mobile', 'cell']):
            detected_columns[header] = 'phone'
        elif any(keyword in header_lower for keyword in ['website', 'web', 'url', 'site', 'domain']):
            detected_columns[header] = 'website'
        elif any(keyword in header_lower for keyword in ['industry', 'sector', 'field', 'vertical']):
            detected_columns[header] = 'industry'
        elif 'name' in header_lower and 'first_name' not in detected_columns.values() and 'last_name' not in detected_columns.values():
            detected_columns[header] = 'first_name'
    
    return CSVPreviewResponse(
        headers=headers,
        sample_data=sample_data,
        total_rows=len(rows) - (1 if csv_request.has_header else 0),
        detected_columns=detected_columns
    )

@router.post("/upload")
def upload_csv_leads(csv_request: CSVUploadRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    csv_reader = csv.reader(io.StringIO(csv_request.csv_content))
    rows = list(csv_reader)
    
    if not rows:
        raise HTTPException(status_code=400, detail="CSV file is empty")
    
    headers = []
    data_rows = rows
    
    if csv_request.has_header:
        headers = rows[0] if rows else []
        data_rows = rows[1:]
    else:
        if rows:
            headers = [f"Column {i+1}" for i in range(len(rows[0]))]
    
    email_column = None
    for csv_col, db_field in csv_request.column_mapping.items():
        if db_field == 'email':
            email_column = csv_col
            break
    
    if not email_column:
        raise HTTPException(status_code=400, detail="Email column mapping is required")
    
    if email_column not in headers:
        raise HTTPException(status_code=400, detail=f"Email column '{email_column}' not found in CSV headers")
    
    # Handle group assignment
    target_group_id = None
    errors = []
    
    if csv_request.new_group_name:
        # Create new group
        existing_group = db.query(LeadGroup).filter(LeadGroup.name == csv_request.new_group_name).first()
        if existing_group:
            errors.append(f"Group '{csv_request.new_group_name}' already exists")
            return {
                "created": 0,
                "errors": errors,
                "skipped": 0,
                "total_processed": len(data_rows),
                "leads": []
            }
        
        new_group_data = LeadGroupCreate(name=csv_request.new_group_name)
        new_group = LeadGroup(**new_group_data.dict())
        db.add(new_group)
        db.flush()
        target_group_id = new_group.id
        
    elif csv_request.group_id:
        # Verify existing group exists
        existing_group = db.query(LeadGroup).filter(LeadGroup.id == csv_request.group_id).first()
        if not existing_group:
            errors.append(f"Group with ID {csv_request.group_id} not found")
            return {
                "created": 0,
                "errors": errors,
                "skipped": 0,
                "total_processed": len(data_rows),
                "leads": []
            }
        target_group_id = csv_request.group_id

    created_leads = []
    skipped = 0
    
    for row_index, row in enumerate(data_rows, start=1):
        try:
            if not row or all(cell.strip() == '' for cell in row):
                skipped += 1
                continue
            
            row_data = {}
            for i, cell in enumerate(row):
                if i < len(headers):
                    header = headers[i]
                    if header in csv_request.column_mapping:
                        db_field = csv_request.column_mapping[header]
                        if db_field in ['email', 'first_name', 'last_name', 'company', 'title', 'phone', 'website', 'industry']:
                            row_data[db_field] = cell.strip() if cell else None
            
            if not row_data.get('email'):
                errors.append(f"Row {row_index}: Email is required")
                continue
            
            existing_lead = db.query(Lead).filter(Lead.email == row_data['email']).first()
            if existing_lead:
                errors.append(f"Row {row_index}: Lead with email {row_data['email']} already exists")
                continue
            
            if row_data.get('website'):
                website = row_data['website'].strip()
                if website and not website.startswith('http') and not website.startswith('www.'):
                    website = 'https://' + website
                row_data['website'] = website
            
            lead_data = LeadCreate(**row_data)
            db_lead = Lead(**lead_data.dict())
            db.add(db_lead)
            db.flush()
            created_leads.append(db_lead)
            
        except Exception as e:
            errors.append(f"Row {row_index}: {str(e)}")
    
    if created_leads:
        db.commit()
        for lead in created_leads:
            db.refresh(lead)
        
        # Assign leads to group if specified
        if target_group_id and created_leads:
            for lead in created_leads:
                membership = LeadGroupMembership(group_id=target_group_id, lead_id=lead.id)
                db.add(membership)
            db.commit()
    
    return {
        "created": len(created_leads),
        "errors": errors,
        "skipped": skipped,
        "total_processed": len(data_rows),
        "leads": [LeadResponse.from_orm(lead) for lead in created_leads]
    }