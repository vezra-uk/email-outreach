#!/usr/bin/env python3

import socket
import time

def working_spamassassin_check():
    """Working SpamAssassin implementation based on proper SPAMC protocol"""
    
    print("🔍 Testing Working SpamAssassin Implementation")
    print("=" * 50)
    
    # Test with a simple email
    email_body = """Subject: Hello there
From: sender@example.com
To: recipient@example.com

Hello,

This is a simple test email to check if our system is working properly.

Best regards,
Test Sender"""

    result = check_spam_working(email_body)
    print(f"Clean email result: {result}")
    
    # Test with spammy email  
    spam_email = """Subject: FREE MONEY NOW!!!
From: winner@spam.com
To: victim@target.com

CONGRATULATIONS!!! YOU WON $1000000!!!

CLICK HERE TO CLAIM YOUR FREE MONEY NOW!!!
LIMITED TIME OFFER!!! ACT FAST!!!
GUARANTEED WINNER!!!"""

    result = check_spam_working(spam_email)
    print(f"Spam email result: {result}")

def check_spam_working(email_content):
    """Working implementation of SpamAssassin check"""
    
    try:
        # Connect to SpamAssassin
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(10)
        sock.connect(('spamassassin', 783))
        
        # Prepare the message with proper line endings
        message_length = len(email_content)
        
        # Send SPAMC protocol request
        request = f"CHECK SPAMC/1.5\\r\\nContent-length: {message_length}\\r\\n\\r\\n{email_content}"
        
        sock.sendall(request.encode('utf-8'))
        
        # Read the response
        response_lines = []
        current_line = b""
        
        # Read character by character to properly handle protocol
        start_time = time.time()
        while time.time() - start_time < 8:
            try:
                char = sock.recv(1)
                if not char:
                    break
                    
                if char == b'\\n':
                    line = current_line.decode('utf-8', errors='ignore').strip()
                    response_lines.append(line)
                    current_line = b""
                    
                    # Check if we got the spam status
                    if line.startswith('Spam:'):
                        sock.close()
                        return f"✅ {line}"
                        
                elif char != b'\\r':  # Skip carriage returns
                    current_line += char
                    
            except socket.timeout:
                break
        
        sock.close()
        
        # If we didn't get a spam line, return what we got
        if response_lines:
            return f"⚠️ Partial: {' | '.join(response_lines[:3])}"
        else:
            return "❌ No response received"
            
    except Exception as e:
        return f"❌ Error: {str(e)}"

if __name__ == "__main__":
    working_spamassassin_check()