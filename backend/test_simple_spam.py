#!/usr/bin/env python3
"""
Simple test for SpamAssassin connection without dependencies
"""
import socket
import re

def test_spamassassin_connection():
    """Test basic connection to SpamAssassin"""
    print("Testing SpamAssassin connection...")
    
    try:
        # Simple email to test
        subject = "Test Subject"
        content = "Hello, this is a test email."
        
        # Format email for SpamAssassin
        email_text = f"""From: sender@example.com
To: recipient@example.com
Subject: {subject}
MIME-Version: 1.0
Content-Type: text/plain; charset=utf-8

{content}"""
        
        # Connect to SpamAssassin daemon
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(10)
        print("Attempting to connect to localhost:783...")
        sock.connect(("localhost", 783))
        print("Connected successfully!")
        
        # Send check command
        command = f"CHECK SPAMC/1.0\r\nContent-length: {len(email_text)}\r\n\r\n{email_text}"
        print(f"Sending command ({len(command)} bytes)...")
        sock.sendall(command.encode('utf-8'))
        
        # Read response
        print("Reading response...")
        response = b""
        attempts = 0
        while attempts < 50:  # Max 5 seconds at 0.1s intervals
            try:
                chunk = sock.recv(4096)
                if not chunk:
                    break
                response += chunk
                print(f"Received {len(chunk)} bytes, total: {len(response)}")
                # Check if we have a complete response
                if b"Content-length:" in response:
                    # Look for the content length and see if we have it all
                    import re
                    length_match = re.search(rb'Content-length:\s*(\d+)', response, re.IGNORECASE)
                    if length_match:
                        expected_length = int(length_match.group(1))
                        header_end = response.find(b'\r\n\r\n')
                        if header_end != -1:
                            body_length = len(response) - (header_end + 4)
                            if body_length >= expected_length:
                                print("Complete response received")
                                break
            except socket.timeout:
                attempts += 1
                continue
            except Exception as e:
                print(f"Error reading: {e}")
                break
        
        sock.close()
        
        response_text = response.decode('utf-8', errors='ignore')
        print("✓ Successfully connected to SpamAssassin!")
        print(f"Response preview: {response_text[:200]}...")
        
        # Parse response
        spam_match = re.search(r'Spam: (True|False) ; (-?\d+\.?\d*) / (-?\d+\.?\d*)', response_text)
        if spam_match:
            is_spam = spam_match.group(1) == 'True'
            score = float(spam_match.group(2))
            threshold = float(spam_match.group(3))
            print(f"✓ Spam check result: {is_spam} (score: {score}, threshold: {threshold})")
        else:
            print("? Could not parse spam result, but connection worked")
        
        return True
        
    except Exception as e:
        print(f"✗ Connection failed: {str(e)}")
        return False

def test_spam_vs_clean():
    """Test with both clean and spammy emails"""
    print("\nTesting clean vs spam detection...")
    
    test_cases = [
        {
            "name": "Clean email",
            "subject": "Quick question about your business",
            "content": "Hi John,\n\nI noticed your website and was impressed by your services. I had a quick question about how you handle client onboarding.\n\nWould you have 5 minutes for a brief chat?\n\nBest regards,\nAlex Johnson"
        },
        {
            "name": "Spam email", 
            "subject": "FREE MONEY!!! ACT NOW!!!",
            "content": "CONGRATULATIONS! You have WON $1,000,000!!! CLICK HERE NOW to claim your FREE MONEY!!! This is a LIMITED TIME OFFER!!! Act now before it's too late!!!"
        }
    ]
    
    for test_case in test_cases:
        print(f"\nTesting: {test_case['name']}")
        print(f"Subject: {test_case['subject']}")
        
        try:
            # Format email
            email_text = f"""From: sender@example.com
To: recipient@example.com
Subject: {test_case['subject']}
MIME-Version: 1.0
Content-Type: text/plain; charset=utf-8

{test_case['content']}"""
            
            # Connect and check
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(10)
            sock.connect(("localhost", 783))
            
            command = f"CHECK SPAMC/1.0\r\nContent-length: {len(email_text)}\r\n\r\n{email_text}"
            sock.send(command.encode('utf-8'))
            
            response = b""
            while True:
                chunk = sock.recv(4096)
                if not chunk:
                    break
                response += chunk
                if b"\r\n\r\n" in response:
                    break
            
            sock.close()
            
            response_text = response.decode('utf-8', errors='ignore')
            
            # Parse result
            spam_match = re.search(r'Spam: (True|False) ; (-?\d+\.?\d*) / (-?\d+\.?\d*)', response_text)
            if spam_match:
                is_spam = spam_match.group(1) == 'True'
                score = float(spam_match.group(2))
                threshold = float(spam_match.group(3))
                
                status = "SPAM" if is_spam else "CLEAN"
                print(f"Result: {status} (score: {score}, threshold: {threshold})")
            else:
                print("Could not parse result")
                
        except Exception as e:
            print(f"Error: {str(e)}")

if __name__ == "__main__":
    print("Simple SpamAssassin Test")
    print("=" * 30)
    
    # Test connection
    if test_spamassassin_connection():
        # Test spam detection
        test_spam_vs_clean()
    
    print("\n" + "=" * 30)
    print("Test completed!")