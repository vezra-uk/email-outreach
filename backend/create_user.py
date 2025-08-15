#!/usr/bin/env python3
# backend/create_user.py
"""
CLI script to manually create users for invitation-only system
Usage: python create_user.py
"""

import sys
import os
from getpass import getpass

# Add the backend directory to Python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from database import SessionLocal
from models import User
from services.auth import AuthService

def get_user_input():
    """Get user details from command line input."""
    print("📧 Creating new user account")
    print("=" * 40)
    
    email = input("Email address: ").strip()
    if not email:
        print("❌ Email is required")
        return None
    
    username = input("Username: ").strip()
    if not username:
        print("❌ Username is required")
        return None
    
    full_name = input("Full name (optional): ").strip() or None
    
    # Get password with confirmation
    while True:
        password = getpass("Password: ")
        if len(password) < 6:
            print("❌ Password must be at least 6 characters long")
            continue
            
        password_confirm = getpass("Confirm password: ")
        
        if password == password_confirm:
            break
        else:
            print("❌ Passwords don't match. Please try again.")
    
    # Ask if user should be admin
    is_superuser_input = input("Make this user an admin? (y/N): ").strip().lower()
    is_superuser = is_superuser_input in ['y', 'yes']
    
    is_active_input = input("User active? (Y/n): ").strip().lower()
    is_active = is_active_input not in ['n', 'no']
    
    return {
        'email': email,
        'username': username,
        'full_name': full_name,
        'password': password,
        'is_superuser': is_superuser,
        'is_active': is_active
    }

def create_user(user_data):
    """Create user in database."""
    db = SessionLocal()
    
    try:
        # Check if user already exists
        if db.query(User).filter(User.email == user_data['email']).first():
            print(f"❌ User with email '{user_data['email']}' already exists")
            return False
        
        if db.query(User).filter(User.username == user_data['username']).first():
            print(f"❌ User with username '{user_data['username']}' already exists")
            return False
        
        # Create user
        hashed_password = AuthService.get_password_hash(user_data['password'])
        new_user = User(
            email=user_data['email'],
            username=user_data['username'],
            full_name=user_data['full_name'],
            hashed_password=hashed_password,
            is_active=user_data['is_active'],
            is_superuser=user_data['is_superuser']
        )
        
        db.add(new_user)
        db.commit()
        db.refresh(new_user)
        
        print(f"✅ User created successfully!")
        print(f"   ID: {new_user.id}")
        print(f"   Email: {new_user.email}")
        print(f"   Username: {new_user.username}")
        print(f"   Full Name: {new_user.full_name or 'Not provided'}")
        print(f"   Admin: {'Yes' if new_user.is_superuser else 'No'}")
        print(f"   Active: {'Yes' if new_user.is_active else 'No'}")
        
        return True
        
    except Exception as e:
        print(f"❌ Error creating user: {e}")
        db.rollback()
        return False
    finally:
        db.close()

def list_existing_users():
    """List all existing users."""
    db = SessionLocal()
    try:
        users = db.query(User).all()
        if not users:
            print("No users found in the system")
            return
        
        print(f"\n👥 Existing users ({len(users)}):")
        print("-" * 60)
        for user in users:
            status = []
            if user.is_superuser:
                status.append("ADMIN")
            if not user.is_active:
                status.append("INACTIVE")
            status_str = f" ({', '.join(status)})" if status else ""
            
            print(f"  {user.id}: {user.email} (@{user.username}){status_str}")
            if user.full_name:
                print(f"      Name: {user.full_name}")
        print()
        
    except Exception as e:
        print(f"❌ Error listing users: {e}")
    finally:
        db.close()

def main():
    """Main function."""
    if len(sys.argv) > 1:
        if sys.argv[1] == "list":
            list_existing_users()
            return
        elif sys.argv[1] == "help":
            print("Usage:")
            print("  python create_user.py        - Create a new user")
            print("  python create_user.py list   - List existing users")
            print("  python create_user.py help   - Show this help")
            return
    
    try:
        # Show existing users first
        list_existing_users()
        
        # Get user input
        user_data = get_user_input()
        if not user_data:
            sys.exit(1)
        
        # Confirm creation
        print(f"\n📋 User details:")
        print(f"  Email: {user_data['email']}")
        print(f"  Username: {user_data['username']}")
        print(f"  Full Name: {user_data['full_name'] or 'Not provided'}")
        print(f"  Admin: {'Yes' if user_data['is_superuser'] else 'No'}")
        print(f"  Active: {'Yes' if user_data['is_active'] else 'No'}")
        
        confirm = input("\nCreate this user? (y/N): ").strip().lower()
        if confirm not in ['y', 'yes']:
            print("❌ User creation cancelled")
            return
        
        # Create user
        if create_user(user_data):
            print(f"\n🎉 User '{user_data['email']}' can now log in to the system!")
        else:
            sys.exit(1)
            
    except KeyboardInterrupt:
        print("\n❌ User creation cancelled")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()