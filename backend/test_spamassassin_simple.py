#!/usr/bin/env python3

import socket
import time
from datetime import datetime

def test_spamassassin_simple():
    """Simple direct test of SpamAssassin functionality"""
    
    print("🔍 Testing SpamAssassin Integration")
    print("=" * 50)
    
    host = "spamassassin"
    port = 783
    
    # Test 1: Clean email
    print("\n📧 Test 1: Clean Business Email")
    
    clean_email = """Subject: Quick question about your services
From: alex@business.com
To: john@company.com
Date: Mon, 19 Aug 2024 18:30:00 +0000

Hi John,

I noticed your company's website and was impressed by your approach to customer service. 

I had a quick question about your consulting services. Would you have 5 minutes this week for a brief call?

Best regards,
Alex Johnson
Business Development Manager
Growth Solutions Inc.
alex@business.com"""

    result = check_with_spamassassin(host, port, clean_email)
    print(f"Result: {result}")
    
    # Test 2: Spammy email
    print("\n📧 Test 2: Promotional Email")
    
    spammy_email = """Subject: FREE MONEY!!! ACT NOW!!!
From: winner@money.com  
To: lucky@winner.com
Date: Mon, 19 Aug 2024 18:30:00 +0000

CONGRATULATIONS!!! You have WON $1,000,000!!!

CLICK HERE NOW to claim your FREE MONEY!!! This is a LIMITED TIME OFFER!!!

ACT NOW!!! DON'T MISS OUT!!!

GUARANTEED WINNER!!!"""

    result = check_with_spamassassin(host, port, spammy_email)
    print(f"Result: {result}")
    
    print("\n✅ SpamAssassin test completed!")

def check_with_spamassassin(host, port, email_text):
    """Send email to SpamAssassin for checking"""
    try:
        # Connect
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(10)
        sock.connect((host, port))
        
        # Send CHECK command
        command = f"CHECK SPAMC/1.0\r\nContent-length: {len(email_text)}\r\nUser: testuser\r\n\r\n{email_text}"
        sock.sendall(command.encode('utf-8'))
        
        # Read response
        response = b""
        start_time = time.time()
        
        while time.time() - start_time < 8:  # 8 second timeout
            try:
                chunk = sock.recv(1024)
                if not chunk:
                    break
                response += chunk
                # Check if we have the spam status line
                if b"Spam:" in response:
                    # Keep reading a bit more to get the full line
                    time.sleep(0.1)
                    try:
                        extra = sock.recv(1024)
                        if extra:
                            response += extra
                    except:
                        pass
                    break
            except socket.timeout:
                break
        
        sock.close()
        
        # Parse response
        response_text = response.decode('utf-8', errors='ignore')
        
        # Extract spam line
        for line in response_text.split('\n'):
            if 'Spam:' in line:
                return f"✅ SpamAssassin Response: {line.strip()}"
        
        return f"⚠️ Partial Response: {response_text[:200]}..."
        
    except Exception as e:
        return f"❌ Error: {e}"

if __name__ == "__main__":
    test_spamassassin_simple()