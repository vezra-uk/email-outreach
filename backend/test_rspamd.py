#!/usr/bin/env python3

from spam_checker import SpamChecker

def test_rspamd_integration():
    """Test Rspamd integration with clean and spam emails"""
    
    print("🔍 Testing Rspamd Integration")
    print("=" * 50)
    
    spam_checker = SpamChecker()
    
    # Test 1: Clean email
    print("\n📧 Test 1: Clean Business Email")
    clean_subject = "Quick question about your services"
    clean_content = """Hi John,

I noticed your company's website and was impressed by your approach to customer service.

I had a quick question about your consulting services. Would you have 5 minutes this week for a brief call?

Best regards,
Alex Johnson
Business Development Manager
Growth Solutions Inc."""
    
    is_spam, score, report = spam_checker.check_email_spam_score(clean_subject, clean_content)
    print(f"Result: Spam={is_spam}, Score={score}, Report: {report}")
    
    # Test 2: Spammy email
    print("\n📧 Test 2: Promotional Email")
    spam_subject = "FREE MONEY!!! ACT NOW!!! LIMITED TIME!!!"
    spam_content = """CONGRATULATIONS!!! YOU HAVE WON $1,000,000!!!

CLICK HERE NOW TO CLAIM YOUR FREE MONEY!!!

THIS IS A LIMITED TIME OFFER!!! ACT FAST!!!

GUARANTEED WINNER!!! NO PURCHASE NECESSARY!!!

CALL NOW: 1-800-FREE-MONEY

URGENT!!! EXPIRES IN 24 HOURS!!!

FREE! FREE! FREE! MONEY! MONEY! MONEY!"""

    is_spam, score, report = spam_checker.check_email_spam_score(spam_subject, spam_content)
    print(f"Result: Spam={is_spam}, Score={score}, Report: {report}")
    
    # Test 3: Detailed report
    print("\n📊 Test 3: Detailed Analysis")
    is_spam, score, report, analysis = spam_checker.get_detailed_spam_report(spam_subject, spam_content)
    print(f"Detailed Result: Spam={is_spam}, Score={score}")
    print(f"Analysis: {len(analysis.get('triggered_rules', []))} rules triggered")
    print(f"Suggestions: {len(analysis.get('suggestions', []))}")
    
    if analysis.get('suggestions'):
        print("Top suggestions:")
        for i, suggestion in enumerate(analysis['suggestions'][:3], 1):
            print(f"  {i}. {suggestion}")
    
    print("\n✅ Rspamd integration test completed!")

if __name__ == "__main__":
    test_rspamd_integration()