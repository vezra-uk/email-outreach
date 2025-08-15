from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from datetime import datetime, timedelta

from database import get_db
from models import EmailSequence, SequenceStep, LeadSequence, Lead, User
from dependencies import get_current_active_user
from schemas.sequence import (
    EmailSequenceCreate, 
    EmailSequenceResponse, 
    EmailSequenceDetail,
    SequenceStepResponse,
    LeadSequenceCreate,
    LeadSequenceResponse,
    SequenceProgress
)

router = APIRouter(prefix="/sequences", tags=["sequences"])

@router.post("/", response_model=EmailSequenceResponse)
def create_sequence(sequence: EmailSequenceCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    """Create a new email sequence with steps"""
    try:
        # Create the sequence
        db_sequence = EmailSequence(
            name=sequence.name,
            description=sequence.description,
            sending_profile_id=sequence.sending_profile_id,
            status="active"
        )
        db.add(db_sequence)
        db.flush()  # Get the ID without committing
        
        # Create the steps
        for step_data in sequence.steps:
            db_step = SequenceStep(
                sequence_id=db_sequence.id,
                step_number=step_data.step_number,
                name=step_data.name,
                subject=step_data.subject,
                template=step_data.template,
                ai_prompt=step_data.ai_prompt,
                delay_days=step_data.delay_days,
                delay_hours=step_data.delay_hours,
                is_active=True
            )
            db.add(db_step)
        
        db.commit()
        db.refresh(db_sequence)
        return db_sequence
        
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=f"Failed to create sequence: {str(e)}")

@router.get("/", response_model=List[EmailSequenceResponse])
def get_sequences(db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    """Get all email sequences"""
    sequences = db.query(EmailSequence).filter(EmailSequence.status == "active").all()
    return sequences

@router.get("/{sequence_id}", response_model=EmailSequenceDetail)
def get_sequence(sequence_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    """Get a specific sequence with its steps"""
    sequence = db.query(EmailSequence).filter(EmailSequence.id == sequence_id).first()
    if not sequence:
        raise HTTPException(status_code=404, detail="Sequence not found")
    
    steps = db.query(SequenceStep).filter(
        SequenceStep.sequence_id == sequence_id
    ).order_by(SequenceStep.step_number).all()
    
    return EmailSequenceDetail(
        id=sequence.id,
        name=sequence.name,
        description=sequence.description,
        status=sequence.status,
        created_at=sequence.created_at,
        steps=[SequenceStepResponse.from_orm(step) for step in steps]
    )

@router.put("/{sequence_id}", response_model=EmailSequenceResponse)
def update_sequence(sequence_id: int, sequence: EmailSequenceCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    """Update an existing sequence"""
    db_sequence = db.query(EmailSequence).filter(EmailSequence.id == sequence_id).first()
    if not db_sequence:
        raise HTTPException(status_code=404, detail="Sequence not found")
    
    try:
        # Update sequence details
        db_sequence.name = sequence.name
        db_sequence.description = sequence.description
        db_sequence.sending_profile_id = sequence.sending_profile_id
        db_sequence.updated_at = datetime.utcnow()
        
        # Delete existing steps
        db.query(SequenceStep).filter(SequenceStep.sequence_id == sequence_id).delete()
        
        # Create new steps
        for step_data in sequence.steps:
            db_step = SequenceStep(
                sequence_id=sequence_id,
                step_number=step_data.step_number,
                name=step_data.name,
                subject=step_data.subject,
                template=step_data.template,
                ai_prompt=step_data.ai_prompt,
                delay_days=step_data.delay_days,
                delay_hours=step_data.delay_hours,
                is_active=True
            )
            db.add(db_step)
        
        db.commit()
        db.refresh(db_sequence)
        return db_sequence
        
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=f"Failed to update sequence: {str(e)}")

@router.delete("/{sequence_id}")
def delete_sequence(sequence_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    """Delete a sequence (soft delete by setting status to inactive)"""
    sequence = db.query(EmailSequence).filter(EmailSequence.id == sequence_id).first()
    if not sequence:
        raise HTTPException(status_code=404, detail="Sequence not found")
    
    # Check if sequence has active lead sequences
    active_leads = db.query(LeadSequence).filter(
        LeadSequence.sequence_id == sequence_id,
        LeadSequence.status == "active"
    ).count()
    
    if active_leads > 0:
        raise HTTPException(
            status_code=400, 
            detail=f"Cannot delete sequence. It has {active_leads} active lead(s) enrolled."
        )
    
    sequence.status = "inactive"
    sequence.updated_at = datetime.utcnow()
    db.commit()
    
    return {"message": "Sequence deleted successfully"}

@router.post("/{sequence_id}/leads", response_model=List[LeadSequenceResponse])
def enroll_leads_in_sequence(
    sequence_id: int, 
    enrollment: LeadSequenceCreate, 
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Enroll leads in a sequence"""
    # Verify sequence exists
    sequence = db.query(EmailSequence).filter(EmailSequence.id == sequence_id).first()
    if not sequence:
        raise HTTPException(status_code=404, detail="Sequence not found")
    
    # Verify all leads exist
    leads = db.query(Lead).filter(Lead.id.in_(enrollment.lead_ids)).all()
    if len(leads) != len(enrollment.lead_ids):
        raise HTTPException(status_code=400, detail="Some leads not found")
    
    created_enrollments = []
    
    try:
        for lead_id in enrollment.lead_ids:
            # Check if lead is already enrolled in this sequence
            existing = db.query(LeadSequence).filter(
                LeadSequence.lead_id == lead_id,
                LeadSequence.sequence_id == sequence_id,
                LeadSequence.status == "active"
            ).first()
            
            if existing:
                continue  # Skip already enrolled leads
            
            # Get first step to calculate next_send_at
            first_step = db.query(SequenceStep).filter(
                SequenceStep.sequence_id == sequence_id,
                SequenceStep.step_number == 1
            ).first()
            
            next_send_at = datetime.utcnow()
            if first_step:
                next_send_at += timedelta(days=first_step.delay_days, hours=first_step.delay_hours)
            
            lead_sequence = LeadSequence(
                lead_id=lead_id,
                sequence_id=sequence_id,
                current_step=1,
                status="active",
                started_at=datetime.utcnow(),
                next_send_at=next_send_at
            )
            db.add(lead_sequence)
            created_enrollments.append(lead_sequence)
        
        db.commit()
        
        # Refresh all created enrollments
        for enrollment in created_enrollments:
            db.refresh(enrollment)
        
        return created_enrollments
        
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=f"Failed to enroll leads: {str(e)}")

@router.get("/{sequence_id}/leads", response_model=List[LeadSequenceResponse])
def get_sequence_leads(sequence_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    """Get all leads enrolled in a sequence"""
    lead_sequences = db.query(LeadSequence).filter(
        LeadSequence.sequence_id == sequence_id
    ).all()
    return lead_sequences

@router.get("/{sequence_id}/progress", response_model=SequenceProgress)
def get_sequence_progress(sequence_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    """Get progress stats for a specific sequence"""
    # Verify sequence exists
    sequence = db.query(EmailSequence).filter(EmailSequence.id == sequence_id).first()
    if not sequence:
        raise HTTPException(status_code=404, detail="Sequence not found")
    
    # Get all lead sequences for this sequence
    lead_sequences = db.query(LeadSequence).filter(
        LeadSequence.sequence_id == sequence_id
    ).all()
    
    total_leads = len(lead_sequences)
    active_leads = sum(1 for ls in lead_sequences if ls.status == "active")
    completed_leads = sum(1 for ls in lead_sequences if ls.status == "completed")
    stopped_leads = sum(1 for ls in lead_sequences if ls.status == "stopped")
    replied_leads = sum(1 for ls in lead_sequences if ls.status == "replied")
    
    # Calculate average step
    avg_step = 0.0
    if lead_sequences:
        total_steps = sum(ls.current_step for ls in lead_sequences)
        avg_step = total_steps / len(lead_sequences)
    
    return SequenceProgress(
        total_leads=total_leads,
        active_leads=active_leads,
        completed_leads=completed_leads,
        stopped_leads=stopped_leads,
        replied_leads=replied_leads,
        avg_step=avg_step
    )

@router.delete("/{sequence_id}/leads/{lead_id}")
def remove_lead_from_sequence(sequence_id: int, lead_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    """Remove a lead from a sequence"""
    lead_sequence = db.query(LeadSequence).filter(
        LeadSequence.sequence_id == sequence_id,
        LeadSequence.lead_id == lead_id,
        LeadSequence.status == "active"
    ).first()
    
    if not lead_sequence:
        raise HTTPException(status_code=404, detail="Lead sequence enrollment not found")
    
    lead_sequence.status = "stopped"
    lead_sequence.stop_reason = "manually_removed"
    lead_sequence.updated_at = datetime.utcnow()
    db.commit()
    
    return {"message": "Lead removed from sequence"}

@router.post("/send")
def trigger_sequence_emails(db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)):
    """Trigger sending of all due sequence emails"""
    # This would typically queue up emails for sending
    # For now, just return a success message
    return {"message": "Sequence emails queued for sending"}