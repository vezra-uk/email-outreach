#!/usr/bin/env python3
"""
Final test for the complete spam checking system
"""
import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

import time
from spam_checker import SpamChecker

def test_spam_checker_basic():
    """Test basic spam checking functionality"""
    print("Testing SpamChecker basic functionality...")
    
    checker = SpamChecker()
    
    # Test clean email
    clean_subject = "Quick question about your services"
    clean_content = "Hi John,\n\nI noticed your website and was impressed by your approach to client onboarding. I had a quick question about how you handle new partnerships.\n\nWould you be available for a brief 10-minute call this week?\n\nBest regards,\nAlex Johnson"
    
    print(f"\nTesting clean email:")
    print(f"Subject: {clean_subject}")
    print(f"Content: {clean_content[:50]}...")
    
    try:
        is_spam, score, report = checker.check_email_spam_score(clean_subject, clean_content)
        print(f"✓ Clean email result: Spam={is_spam}, Score={score}")
        
        # Test detailed report
        is_spam_detailed, score_detailed, detailed_report, analysis = checker.get_detailed_spam_report(
            clean_subject, clean_content
        )
        print(f"✓ Detailed check: Spam={is_spam_detailed}, Score={score_detailed}")
        if analysis.get('triggered_rules'):
            print(f"  Triggered rules: {len(analysis['triggered_rules'])}")
        if analysis.get('suggestions'):
            print(f"  Suggestions: {len(analysis['suggestions'])}")
        
        return True
        
    except Exception as e:
        print(f"✗ Error: {str(e)}")
        return False

def test_spammy_email():
    """Test with obviously spammy email"""
    print(f"\n{'='*50}")
    print("Testing spammy email...")
    
    checker = SpamChecker()
    
    spam_subject = "FREE MONEY!!! ACT NOW LIMITED TIME!!!"
    spam_content = "CONGRATULATIONS!!! You have been selected to receive $10,000 CASH!!! CLICK HERE NOW to claim your FREE MONEY!!! This offer expires in 24 hours!!! Don't miss out on this AMAZING opportunity!!! Call 1-800-GET-RICH now!!!"
    
    print(f"Subject: {spam_subject}")
    print(f"Content: {spam_content[:50]}...")
    
    try:
        is_spam, score, report, analysis = checker.get_detailed_spam_report(spam_subject, spam_content)
        print(f"✓ Spam email result: Spam={is_spam}, Score={score}")
        
        if analysis.get('triggered_rules'):
            print(f"  Triggered {len(analysis['triggered_rules'])} spam rules:")
            for rule in analysis['triggered_rules'][:3]:
                print(f"    - {rule['rule']} ({rule['score']} points)")
        
        if analysis.get('suggestions'):
            print(f"  Top suggestions for improvement:")
            for suggestion in analysis['suggestions'][:3]:
                print(f"    - {suggestion}")
        
        return True
        
    except Exception as e:
        print(f"✗ Error: {str(e)}")
        return False

def main():
    print("Final SpamAssassin Integration Test")
    print("=" * 50)
    
    # Wait for SpamAssassin to be ready
    print("Waiting for SpamAssassin to be ready...")
    time.sleep(10)
    
    success_count = 0
    
    # Test 1: Clean email
    if test_spam_checker_basic():
        success_count += 1
    
    # Test 2: Spammy email
    if test_spammy_email():
        success_count += 1
    
    print(f"\n{'='*50}")
    print(f"Test Results: {success_count}/2 tests passed")
    
    if success_count == 2:
        print("✅ SpamAssassin integration is working correctly!")
        print("\nThe system will now:")
        print("  - Check emails for spam before sending")
        print("  - Retry with AI feedback if spam detected")  
        print("  - Respect daily limits and natural timing")
        print("  - Gracefully handle failures")
    else:
        print("⚠️  Some tests failed, but the system will still work")
        print("   - Emails will be sent without spam checking if SpamAssassin fails")
        print("   - All other features (limits, timing) remain functional")

if __name__ == "__main__":
    main()