# backend/dependencies.py
from typing import Optional
from fastapi import Depends, HTTPException, status, Header, Query
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session

from database import get_db
from models import User
from services.auth import AuthService

security = HTTPBearer(auto_error=False)

async def get_current_user_flexible(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    x_api_key: Optional[str] = Header(None),
    api_key: Optional[str] = Query(None),
    db: Session = Depends(get_db)
) -> User:
    """
    Flexible authentication that supports:
    1. JWT token in Authorization header
    2. API key in X-API-Key header
    3. API key as query parameter
    """
    user = None
    
    # Try API key from header first
    if x_api_key:
        user = AuthService.get_user_by_api_key(db, x_api_key)
        if user and user.is_active:
            return user
    
    # Try API key from query parameter
    if api_key:
        user = AuthService.get_user_by_api_key(db, api_key)
        if user and user.is_active:
            return user
    
    # Try JWT token
    if credentials:
        token_data = AuthService.verify_token(credentials.credentials)
        if token_data and token_data.email:
            user = AuthService.get_user_by_email(db, email=token_data.email)
            if user and user.is_active:
                return user
    
    # No valid authentication found
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials. Provide either a valid JWT token or API key.",
        headers={"WWW-Authenticate": "Bearer"},
    )

async def get_current_active_user(
    current_user: User = Depends(get_current_user_flexible)
) -> User:
    """Ensure the current user is active."""
    if not current_user.is_active:
        raise HTTPException(status_code=400, detail="Inactive user")
    return current_user

async def get_current_superuser(
    current_user: User = Depends(get_current_user_flexible)
) -> User:
    """Ensure the current user is a superuser."""
    if not current_user.is_superuser:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions"
        )
    return current_user

# Optional auth for public endpoints that can benefit from user context
async def get_current_user_optional(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    x_api_key: Optional[str] = Header(None),
    api_key: Optional[str] = Query(None),
    db: Session = Depends(get_db)
) -> Optional[User]:
    """
    Optional authentication - returns None if no valid credentials provided.
    Useful for endpoints that can work without auth but provide extra features when authenticated.
    """
    try:
        return await get_current_user_flexible(credentials, x_api_key, api_key, db)
    except HTTPException:
        return None