#!/usr/bin/env python3
# backend/init_auth.py
"""
Simple script to initialize authentication system with default admin user
"""

import sys
import os

# Add the backend directory to Python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from database import engine, SessionLocal
from models import Base, User
from services.auth import AuthService
from logger_config import get_logger

def main():
    logger = get_logger(__name__)
    print("🔐 Initializing authentication system...")
    
    # Create tables
    print("Creating authentication tables...")
    logger.info("Creating authentication database tables")
    Base.metadata.create_all(bind=engine)
    print("✅ Authentication tables created successfully!")
    logger.info("Authentication tables created successfully")
    
    # Create default admin user
    db = SessionLocal()
    try:
        # Check if any users exist
        user_count = db.query(User).count()
        if user_count > 0:
            print(f"Users already exist ({user_count} users found)")
            print("Authentication system already initialized!")
            logger.info(f"Skipping admin user creation - {user_count} users already exist")
            return
        
        print("\nCreating default admin user...")
        
        # Create admin user with default credentials
        email = "admin@example.com"
        username = "admin"
        password = "admin123"  # Default password - CHANGE THIS!
        
        hashed_password = AuthService.get_password_hash(password)
        admin_user = User(
            email=email,
            username=username,
            full_name="System Administrator",
            hashed_password=hashed_password,
            is_active=True,
            is_superuser=True
        )
        
        db.add(admin_user)
        db.commit()
        db.refresh(admin_user)
        
        print(f"✅ Admin user created successfully!")
        print(f"   Email: {admin_user.email}")
        print(f"   Username: {admin_user.username}")
        print(f"   Password: {password}")
        print(f"   ⚠️  IMPORTANT: Change the password after first login!")
        
        logger.info(f"Default admin user created successfully", extra={
            "user_id": admin_user.id,
            "email": admin_user.email,
            "username": admin_user.username
        })
        logger.warning("Default admin password is insecure - change immediately after first login")
        
        print("\n🎉 Authentication system setup complete!")
        print("\nYou can now:")
        print("1. Login at POST /api/auth/login with the credentials above")
        print("2. Get an access token and use it in Authorization header")
        print("3. Create API keys via POST /api/auth/api-keys")
        print("4. Update your password via PUT /api/auth/me")
        
    except Exception as e:
        print(f"❌ Error creating admin user: {e}")
        logger.error(f"Failed to create default admin user: {e}", extra={
            "error": str(e),
            "error_type": type(e).__name__
        }, exc_info=True)
        db.rollback()
        sys.exit(1)
    finally:
        db.close()

if __name__ == "__main__":
    main()