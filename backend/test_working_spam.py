#!/usr/bin/env python3
"""
Working spam test based on successful PING test
"""
import socket
import time

def test_basic_spam():
    """Test basic spam checking functionality"""
    print("Testing spam check with working connection...")
    
    # Test email
    email_content = """From: sender@example.com
To: recipient@example.com
Subject: FREE MONEY!!! ACT NOW!!!
MIME-Version: 1.0
Content-Type: text/plain; charset=utf-8

CONGRATULATIONS! You have WON $1,000,000!!! CLICK HERE NOW!"""

    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(10)
        sock.connect(('localhost', 783))
        
        # Simple CHECK command like in the logs
        command = f"CHECK SPAMC/1.0\r\nContent-length: {len(email_content)}\r\n\r\n{email_content}"
        sock.sendall(command.encode('utf-8'))
        
        # Read just the header first
        response = b""
        while b"\r\n\r\n" not in response:
            chunk = sock.recv(1024)
            if not chunk:
                break
            response += chunk
        
        sock.close()
        
        response_text = response.decode('utf-8', errors='ignore')
        print("Response received:")
        print(response_text)
        
        # Parse basic result
        if "SPAMD/" in response_text:
            lines = response_text.split('\n')
            for line in lines:
                if line.startswith("Spam:"):
                    print(f"Result: {line}")
                    return True
        
        return False
        
    except Exception as e:
        print(f"Error: {e}")
        return False

def test_clean_email():
    """Test with clean email"""
    print("\nTesting clean email...")
    
    email_content = """From: sender@example.com
To: recipient@example.com
Subject: Quick question
MIME-Version: 1.0
Content-Type: text/plain; charset=utf-8

Hi, I had a quick question about your services. Would you be available for a brief call?

Best regards,
John"""

    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(10)
        sock.connect(('localhost', 783))
        
        command = f"CHECK SPAMC/1.0\r\nContent-length: {len(email_content)}\r\n\r\n{email_content}"
        sock.sendall(command.encode('utf-8'))
        
        response = b""
        while b"\r\n\r\n" not in response:
            chunk = sock.recv(1024)
            if not chunk:
                break
            response += chunk
        
        sock.close()
        
        response_text = response.decode('utf-8', errors='ignore')
        print("Response received:")
        print(response_text)
        
        # Parse result
        if "SPAMD/" in response_text:
            lines = response_text.split('\n')
            for line in lines:
                if line.startswith("Spam:"):
                    print(f"Result: {line}")
                    return True
        
        return False
        
    except Exception as e:
        print(f"Error: {e}")
        return False

if __name__ == "__main__":
    print("Working SpamAssassin Test")
    print("=" * 30)
    
    # Test with spam email
    test_basic_spam()
    
    # Test with clean email  
    test_clean_email()
    
    print("\n" + "=" * 30)
    print("Test completed!")