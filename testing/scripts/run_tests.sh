#!/bin/bash

# Email Automation Test Runner
# ============================

echo "🧪 Email Automation Test Suite"
echo "================================"

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

# Run health check first
echo ""
echo "🔍 Quick Health Check:"
echo "----------------------"
python3 quick_health_check.py

# Ask user if they want to run full tests
echo ""
read -p "Run full system tests? This will create temporary test data (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "🔬 Running Full System Tests:"
    echo "-----------------------------" 
    python3 system_test.py
else
    echo "✅ Health check complete. Skipping full system tests."
fi

echo ""
echo "Done! 🎉"