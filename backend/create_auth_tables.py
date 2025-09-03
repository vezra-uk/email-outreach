#!/usr/bin/env python3
# backend/create_auth_tables.py
"""
Script to create authentication tables and default admin user
Run this after setting up authentication system
"""

import sys
import os
from getpass import getpass
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Add the backend directory to Python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from database import engine, SessionLocal
from models import Base, User
from services.auth import AuthService
from logger_config import get_logger

def create_tables():
    """Create all database tables"""
    logger = get_logger(__name__)
    
    print("Creating authentication tables...")
    logger.info("Creating authentication database tables")
    Base.metadata.create_all(bind=engine)
    print("✅ Authentication tables created successfully!")
    logger.info("Authentication tables created successfully")
    

def create_admin_user():
    """Create default admin user"""
    logger = get_logger(__name__)
    db = SessionLocal()
    
    try:
        # Check if any users exist
        user_count = db.query(User).count()
        if user_count > 0:
            print(f"Users already exist ({user_count} users found)")
            logger.info(f"Skipping admin user creation - {user_count} users already exist")
            return
        
        print("\nCreating admin user...")
        print("This will be the superuser with full access to the system.")
        
        # Get user input
        email = input("Admin email: ").strip()
        username = input("Admin username: ").strip()
        full_name = input("Full name (optional): ").strip() or None
        
        # Get password with confirmation
        while True:
            password = getpass("Password: ")
            password_confirm = getpass("Confirm password: ")
            
            if password == password_confirm:
                break
            else:
                print("❌ Passwords don't match. Please try again.")
        
        # Create admin user
        hashed_password = AuthService.get_password_hash(password)
        admin_user = User(
            email=email,
            username=username,
            full_name=full_name,
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
        print(f"   User ID: {admin_user.id}")
        
        logger.info(f"Admin user created successfully", extra={
            "user_id": admin_user.id,
            "email": admin_user.email,
            "username": admin_user.username
        })
        
    except Exception as e:
        print(f"❌ Error creating admin user: {e}")
        logger.error(f"Failed to create admin user: {e}", extra={
            "error": str(e),
            "error_type": type(e).__name__
        }, exc_info=True)
        db.rollback()
    finally:
        db.close()

def main():
    print("🔐 Setting up authentication system...")
    print("=" * 50)
    
    try:
        # Create tables
        create_tables()
        
        # Create admin user
        create_admin_user()
        
        print("\n🎉 Authentication system setup complete!")
        print("\nNext steps:")
        print("1. Restart your FastAPI server")
        print("2. Visit /docs to see the new auth endpoints")
        print("3. Use POST /api/auth/login to get an access token")
        print("4. Include the token in Authorization header: 'Bearer <token>'")
        print("5. Or create API keys via POST /api/auth/api-keys for programmatic access")
        
    except Exception as e:
        print(f"❌ Setup failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()