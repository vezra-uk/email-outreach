#!/bin/bash

# Email Automation Comprehensive Test Runner
# ==========================================

echo "🧪 Email Automation Comprehensive Test Suite"
echo "=============================================="

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is required but not installed"
    exit 1
fi

# Check if pip is installed
if ! command -v pip3 &> /dev/null; then
    echo "❌ pip3 is required but not installed"
    exit 1
fi

# Install required packages
echo "📦 Installing test dependencies..."
pip3 install requests --quiet

# Check if Docker is running
if ! command -v docker &> /dev/null; then
    echo "⚠️  Docker not found - container tests will be skipped"
elif ! docker info &> /dev/null; then
    echo "⚠️  Docker daemon not running - container tests will be skipped"
fi

# Display test options
echo ""
echo "Available Test Suites:"
echo "======================"
echo "1. 🔍 Quick Health Check (30 seconds)"
echo "2. 🧪 Basic System Tests (2-3 minutes)"
echo "3. 🔬 Comprehensive Tests (5-10 minutes)"
echo "4. 📈 Load Testing (configurable duration)"
echo "5. 🔒 Security Testing (10-15 minutes)"
echo "6. 🚀 Full Test Suite (20-30 minutes)"
echo "0. Exit"

echo ""
read -p "Select test suite [1-6, 0 to exit]: " choice

case $choice in
    1)
        echo ""
        echo "🔍 Running Quick Health Check:"
        echo "------------------------------"
        python3 scripts/quick_health_check.py
        ;;
    2)
        echo ""
        echo "🧪 Running Basic System Tests:"
        echo "------------------------------"
        python3 scripts/system_test.py
        ;;
    3)
        echo ""
        echo "🔬 Running Comprehensive Tests:"
        echo "------------------------------"
        echo "This includes performance, security, and stress testing."
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            python3 scripts/comprehensive_system_test.py --performance --security
        else
            echo "Test cancelled."
        fi
        ;;
    4)
        echo ""
        echo "📈 Load Testing Configuration:"
        echo "-----------------------------"
        read -p "Number of concurrent users [10]: " users
        read -p "Test duration in seconds [60]: " duration
        read -p "Ramp-up time in seconds [10]: " rampup
        
        users=${users:-10}
        duration=${duration:-60}
        rampup=${rampup:-10}
        
        echo "Starting load test with $users users for ${duration}s..."
        python3 scripts/load_test.py --users $users --duration $duration --ramp-up $rampup
        ;;
    5)
        echo ""
        echo "🔒 Security Testing:"
        echo "-------------------"
        echo "⚠️  This will test for security vulnerabilities"
        read -p "Include aggressive tests? (may impact performance) (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            python3 scripts/security_test.py --aggressive --report-file reports/security_report.json
        else
            python3 scripts/security_test.py --report-file reports/security_report.json
        fi
        ;;
    6)
        echo ""
        echo "🚀 Full Test Suite:"
        echo "------------------"
        echo "This will run ALL tests and may take 20-30 minutes."
        echo "⚠️  This includes aggressive testing that may impact system performance."
        read -p "Are you sure you want to continue? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo ""
            echo "Phase 1: Health Check"
            python3 scripts/quick_health_check.py
            
            echo ""
            echo "Phase 2: Basic System Tests"
            python3 scripts/system_test.py
            
            echo ""
            echo "Phase 3: Comprehensive Tests"
            python3 scripts/comprehensive_system_test.py --all
            
            echo ""
            echo "Phase 4: Load Testing"
            python3 scripts/load_test.py --users 20 --duration 120 --ramp-up 20
            
            echo ""
            echo "Phase 5: Security Testing"
            python3 scripts/security_test.py --aggressive --report-file reports/security_report_full.json
            
            echo ""
            echo "✅ Full test suite completed!"
            echo "📄 Security report saved to: reports/security_report_full.json"
        else
            echo "Test cancelled."
        fi
        ;;
    0)
        echo "Goodbye! 👋"
        exit 0
        ;;
    *)
        echo "❌ Invalid selection. Please choose 1-6 or 0."
        exit 1
        ;;
esac

echo ""
echo "Done! 🎉"