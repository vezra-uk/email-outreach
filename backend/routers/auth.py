# backend/routers/auth.py
from datetime import timedelta
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPBearer
from sqlalchemy.orm import Session

from database import get_db
from models import User, APIKey
from schemas.auth import (
    UserCreate, UserUpdate, User as UserSchema, 
    Token, LoginRequest,
    APIKeyCreate, APIKey as APIKeySchema, APIKeyPublic
)
from services.auth import AuthService, get_current_active_user, get_current_superuser

router = APIRouter(prefix="/auth", tags=["authentication"])

# Public registration removed - invitation only system
# Users must be created by administrators

@router.post("/login", response_model=Token)
def login(login_data: LoginRequest, db: Session = Depends(get_db)):
    """Login and get access token."""
    user = AuthService.authenticate_user(db, login_data.email, login_data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Inactive user"
        )
    
    access_token_expires = timedelta(minutes=30 * 24 * 60)  # 30 days
    access_token = AuthService.create_access_token(
        data={"sub": user.email}, 
        expires_delta=access_token_expires
    )
    
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "expires_in": int(access_token_expires.total_seconds())
    }

@router.get("/me", response_model=UserSchema)
def read_users_me(current_user: User = Depends(get_current_active_user)):
    """Get current user info."""
    return current_user

@router.put("/me", response_model=UserSchema)
def update_user_me(
    user_update: UserUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Update current user."""
    update_data = user_update.dict(exclude_unset=True)
    
    # Handle password update
    if "password" in update_data:
        update_data["hashed_password"] = AuthService.get_password_hash(update_data.pop("password"))
    
    # Check for email conflicts
    if "email" in update_data and update_data["email"] != current_user.email:
        existing_user = AuthService.get_user_by_email(db, update_data["email"])
        if existing_user:
            raise HTTPException(status_code=400, detail="Email already registered")
    
    # Check for username conflicts
    if "username" in update_data and update_data["username"] != current_user.username:
        existing_user = db.query(User).filter(User.username == update_data["username"]).first()
        if existing_user:
            raise HTTPException(status_code=400, detail="Username already taken")
    
    for field, value in update_data.items():
        setattr(current_user, field, value)
    
    db.commit()
    db.refresh(current_user)
    return current_user

# API Key management
@router.post("/api-keys", response_model=APIKeySchema)
def create_api_key(
    api_key_data: APIKeyCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Create a new API key."""
    api_key = APIKey(
        key=AuthService.generate_api_key(),
        name=api_key_data.name,
        user_id=current_user.id
    )
    
    db.add(api_key)
    db.commit()
    db.refresh(api_key)
    
    return api_key

@router.get("/api-keys", response_model=List[APIKeyPublic])
def list_api_keys(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """List user's API keys."""
    api_keys = db.query(APIKey).filter(APIKey.user_id == current_user.id).all()
    
    # Convert to public format (hide full key)
    public_keys = []
    for key in api_keys:
        public_key = APIKeyPublic(
            id=key.id,
            name=key.name,
            is_active=key.is_active,
            created_at=key.created_at,
            last_used_at=key.last_used_at,
            key_preview=key.key[:8] + "..." if len(key.key) > 8 else key.key
        )
        public_keys.append(public_key)
    
    return public_keys

@router.delete("/api-keys/{key_id}")
def delete_api_key(
    key_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Delete an API key."""
    api_key = db.query(APIKey).filter(
        APIKey.id == key_id,
        APIKey.user_id == current_user.id
    ).first()
    
    if not api_key:
        raise HTTPException(status_code=404, detail="API key not found")
    
    db.delete(api_key)
    db.commit()
    
    return {"message": "API key deleted successfully"}

@router.put("/api-keys/{key_id}/toggle")
def toggle_api_key(
    key_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Toggle API key active status."""
    api_key = db.query(APIKey).filter(
        APIKey.id == key_id,
        APIKey.user_id == current_user.id
    ).first()
    
    if not api_key:
        raise HTTPException(status_code=404, detail="API key not found")
    
    api_key.is_active = not api_key.is_active
    db.commit()
    
    return {"message": f"API key {'activated' if api_key.is_active else 'deactivated'} successfully"}

# Admin endpoints
@router.post("/admin/create-user", response_model=UserSchema)
def create_user_admin(
    user_data: UserCreate, 
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_superuser)
):
    """Create a new user (admin only)."""
    # Check if user already exists
    if AuthService.get_user_by_email(db, user_data.email):
        raise HTTPException(
            status_code=400,
            detail="Email already registered"
        )
    
    # Check if username already exists
    existing_user = db.query(User).filter(User.username == user_data.username).first()
    if existing_user:
        raise HTTPException(
            status_code=400,
            detail="Username already taken"
        )
    
    # Create user
    hashed_password = AuthService.get_password_hash(user_data.password)
    db_user = User(
        email=user_data.email,
        username=user_data.username,
        full_name=user_data.full_name,
        hashed_password=hashed_password,
        is_active=user_data.is_active,
        is_superuser=False  # Only existing superusers can create new superusers via update
    )
    
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    
    return db_user

@router.get("/users", response_model=List[UserSchema])
def list_users(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_superuser)
):
    """List all users (admin only)."""
    return db.query(User).all()

@router.put("/users/{user_id}", response_model=UserSchema)
def update_user(
    user_id: int,
    user_update: UserUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_superuser)
):
    """Update a user (admin only)."""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    update_data = user_update.dict(exclude_unset=True)
    
    if "password" in update_data:
        update_data["hashed_password"] = AuthService.get_password_hash(update_data.pop("password"))
    
    for field, value in update_data.items():
        setattr(user, field, value)
    
    db.commit()
    db.refresh(user)
    return user