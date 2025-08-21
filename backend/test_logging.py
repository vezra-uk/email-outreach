#!/usr/bin/env python3
"""
Test script for the comprehensive logging implementation.
This script tests various logging levels and scenarios to ensure proper functionality.
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from logger_config import setup_logging, get_logger
import time

def test_basic_logging():
    """Test basic logging functionality."""
    print("Testing basic logging functionality...")
    
    # Setup logging with INFO level
    setup_logging(log_level="INFO")
    logger = get_logger("test_basic")
    
    logger.debug("This debug message should not appear in INFO level")
    logger.info("This info message should appear")
    logger.warning("This warning message should appear")
    logger.error("This error message should appear")
    
    print("Basic logging test completed. Check logs/ directory for output files.")

def test_structured_logging():
    """Test structured logging with extra data."""
    print("Testing structured logging...")
    
    logger = get_logger("test_structured")
    
    # Test with structured data
    logger.info("User login attempt", extra={
        "user_id": 12345,
        "email": "test@example.com",
        "ip_address": "192.168.1.100",
        "success": True,
        "timestamp": time.time()
    })
    
    logger.error("Database connection failed", extra={
        "database": "email_automation",
        "connection_string": "postgresql://localhost:5432",
        "retry_count": 3,
        "error_code": "CONNECTION_TIMEOUT"
    })
    
    print("Structured logging test completed.")

def test_exception_logging():
    """Test exception logging."""
    print("Testing exception logging...")
    
    logger = get_logger("test_exceptions")
    
    try:
        # Simulate an error
        result = 1 / 0
    except ZeroDivisionError as e:
        logger.error("Mathematical error occurred", extra={
            "operation": "division",
            "dividend": 1,
            "divisor": 0,
            "function": "test_exception_logging"
        }, exc_info=True)
    
    try:
        # Simulate another error
        undefined_variable.some_method()
    except NameError as e:
        logger.error("Variable error occurred", extra={
            "variable_name": "undefined_variable",
            "context": "test function"
        }, exc_info=True)
    
    print("Exception logging test completed.")

def test_different_loggers():
    """Test multiple logger instances."""
    print("Testing multiple logger instances...")
    
    # Create different loggers for different modules
    auth_logger = get_logger("auth_service")
    email_logger = get_logger("email_service")
    api_logger = get_logger("api_handler")
    
    auth_logger.info("User authentication successful", extra={
        "user_id": 789,
        "method": "password",
        "session_id": "sess_abc123"
    })
    
    email_logger.info("Email sent successfully", extra={
        "recipient": "user@example.com",
        "campaign_id": 456,
        "template": "welcome_email",
        "send_time": time.time()
    })
    
    api_logger.warning("Rate limit approaching", extra={
        "endpoint": "/api/campaigns",
        "current_requests": 95,
        "limit": 100,
        "window": "1_hour"
    })
    
    print("Multiple logger test completed.")

def test_performance_logging():
    """Test performance-related logging."""
    print("Testing performance logging...")
    
    logger = get_logger("performance_test")
    
    # Simulate a slow operation
    start_time = time.time()
    time.sleep(0.1)  # Simulate 100ms operation
    end_time = time.time()
    
    logger.info("Database query completed", extra={
        "query_type": "SELECT",
        "table": "campaigns",
        "duration_ms": round((end_time - start_time) * 1000, 2),
        "rows_returned": 150,
        "cache_hit": False
    })
    
    # Simulate API request logging
    logger.info("API request processed", extra={
        "method": "POST",
        "endpoint": "/api/campaigns",
        "status_code": 201,
        "response_time_ms": 45,
        "request_size_bytes": 1024,
        "response_size_bytes": 256
    })
    
    print("Performance logging test completed.")

if __name__ == "__main__":
    print("Starting comprehensive logging tests...\n")
    
    # Run all tests
    test_basic_logging()
    print()
    
    test_structured_logging()
    print()
    
    test_exception_logging()
    print()
    
    test_different_loggers()
    print()
    
    test_performance_logging()
    print()
    
    print("All logging tests completed!")
    print("Check the following files for log output:")
    print("- logs/app.log (main application log)")
    print("- logs/errors.log (error-specific log)")
    print("- Console output (structured logs)")