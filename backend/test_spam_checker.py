#!/usr/bin/env python3
"""
Test script for spam checking functionality
"""
import os
import sys
from spam_checker import SpamChecker

def test_spam_checker():
    """Test the SpamAssassin integration"""
    print("Testing SpamAssassin integration...")
    
    spam_checker = SpamChecker()
    
    # Test cases
    test_cases = [
        {
            "name": "Clean email",
            "subject": "Quick question about your business",
            "content": "Hi John,\n\nI noticed your website and was impressed by your services. I had a quick question about how you handle client onboarding.\n\nWould you have 5 minutes for a brief chat?\n\nBest regards,\nAlex Johnson"
        },
        {
            "name": "Spam email",
            "subject": "FREE MONEY!!! ACT NOW!!!",
            "content": "CONGRATULATIONS! You have WON $1,000,000!!! CLICK HERE NOW to claim your FREE MONEY!!! This is a LIMITED TIME OFFER!!! Act now before it's too late!!! Call 1-800-GET-RICH!!!"
        },
        {
            "name": "Promotional email",
            "subject": "Limited Time Offer - Save 50%",
            "content": "Don't miss out on this amazing deal! For a limited time only, you can save 50% on all our products. Click here to take advantage of this incredible offer. Free shipping included!"
        }
    ]
    
    for i, test_case in enumerate(test_cases, 1):
        print(f"\n{'='*50}")
        print(f"Test {i}: {test_case['name']}")
        print(f"{'='*50}")
        print(f"Subject: {test_case['subject']}")
        print(f"Content: {test_case['content'][:100]}...")
        
        try:
            # Test basic spam check
            is_spam, spam_score, report = spam_checker.check_email_spam_score(
                test_case['subject'], test_case['content']
            )
            
            print(f"\nBasic Check Results:")
            print(f"  Is Spam: {is_spam}")
            print(f"  Spam Score: {spam_score}")
            
            # Test detailed report
            is_spam_detailed, spam_score_detailed, detailed_report, analysis = spam_checker.get_detailed_spam_report(
                test_case['subject'], test_case['content']
            )
            
            print(f"\nDetailed Check Results:")
            print(f"  Is Spam: {is_spam_detailed}")
            print(f"  Spam Score: {spam_score_detailed}")
            print(f"  Triggered Rules: {len(analysis.get('triggered_rules', []))}")
            print(f"  Suggestions: {len(analysis.get('suggestions', []))}")
            
            if analysis.get('triggered_rules'):
                print(f"\n  Top Triggered Rules:")
                for rule in analysis['triggered_rules'][:3]:
                    print(f"    - {rule['rule']} ({rule['score']} points)")
            
            if analysis.get('suggestions'):
                print(f"\n  Top Suggestions:")
                for suggestion in analysis['suggestions'][:3]:
                    print(f"    - {suggestion}")
                    
        except Exception as e:
            print(f"  ERROR: {str(e)}")
            print(f"  This might be expected if SpamAssassin container is not running")

def test_email_generation_with_spam_check():
    """Test email generation with spam checking (requires OpenAI API)"""
    print(f"\n{'='*60}")
    print("Testing Email Generation with Spam Checking")
    print(f"{'='*60}")
    
    if not os.getenv("OPENAI_API_KEY"):
        print("SKIPPED: No OpenAI API key found")
        return
    
    try:
        from email_service import EmailService
        
        # Mock lead object
        class MockLead:
            def __init__(self):
                self.id = 1
                self.email = "test@example.com"
                self.first_name = "John"
                self.company = "Test Company"
        
        lead = MockLead()
        email_service = EmailService()
        
        # Test with a potentially spammy prompt
        spammy_prompt = "Write a sales email offering free money and limited time deals with lots of exclamation marks"
        
        print("Generating email with potentially spammy prompt...")
        print(f"Prompt: {spammy_prompt}")
        
        result = email_service._generate_ai_email(
            lead=lead,
            prompt_text=spammy_prompt,
            is_followup=False
        )
        
        if result:
            print(f"\nGeneration successful after {result.get('attempts', 1)} attempts")
            print(f"Final spam score: {result.get('spam_score', 'Unknown')}")
            print(f"Subject: {result['subject']}")
            print(f"Content preview: {result['content'][:200]}...")
        else:
            print("\nGeneration failed - email was too spammy even after retries")
            
    except Exception as e:
        print(f"ERROR: {str(e)}")
        print("This might be expected if required services are not available")

if __name__ == "__main__":
    print("SpamAssassin Integration Test")
    print("=" * 50)
    
    # Test 1: Basic spam checker functionality
    test_spam_checker()
    
    # Test 2: Email generation with spam checking
    test_email_generation_with_spam_check()
    
    print(f"\n{'='*50}")
    print("Test completed!")
    print("\nTo run the SpamAssassin container:")
    print("docker-compose up spamassassin -d")
    print("\nThen run this test again to see full functionality.")