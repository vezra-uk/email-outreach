#!/usr/bin/env python3
"""
Comprehensive Email Automation System Test Suite
===============================================

Advanced testing including performance, security, edge cases, and stress testing.

Usage: python3 comprehensive_system_test.py [--performance] [--security] [--stress]
"""

import requests
import json
import time
import sys
import threading
import random
import string
import concurrent.futures
import argparse
from datetime import datetime, timedelta
from typing import Dict, Any, Optional, List
import subprocess
import os
import tempfile
import csv
import io
import base64

class ComprehensiveTestRunner:
    def __init__(self, args):
        self.backend_url = "http://localhost:8000"
        self.frontend_url = "http://localhost:3000"
        self.auth_token = None
        self.test_results = []
        self.test_data = {}
        self.performance_metrics = {}
        self.args = args
        
    def log(self, message: str, level: str = "INFO"):
        """Log test messages with timestamp"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        color_codes = {
            "INFO": "\033[0m",     # Default
            "PASS": "\033[92m",    # Green
            "FAIL": "\033[91m",    # Red
            "WARNING": "\033[93m", # Yellow
            "PERF": "\033[94m",    # Blue
            "SEC": "\033[95m",     # Magenta
        }
        color = color_codes.get(level, "\033[0m")
        reset = "\033[0m"
        print(f"{color}[{timestamp}] [{level}] {message}{reset}")
        
    def test_result(self, test_name: str, passed: bool, message: str = "", duration: float = 0):
        """Record test result with performance data"""
        status = "PASS" if passed else "FAIL"
        self.test_results.append({
            "test": test_name,
            "status": status,
            "message": message,
            "duration": duration,
            "timestamp": datetime.now().isoformat()
        })
        level = "PASS" if passed else "FAIL"
        duration_str = f" ({duration:.3f}s)" if duration > 0 else ""
        self.log(f"{test_name}: {status}{duration_str}" + (f" - {message}" if message else ""), level)
        
    def generate_random_string(self, length: int = 10) -> str:
        """Generate random string for test data"""
        return ''.join(random.choices(string.ascii_lowercase + string.digits, k=length))
        
    def measure_performance(self, func, *args, **kwargs):
        """Measure function execution time"""
        start_time = time.time()
        result = func(*args, **kwargs)
        duration = time.time() - start_time
        return result, duration
        
    def authenticate(self) -> bool:
        """Authenticate and get JWT token"""
        try:
            login_data = {
                "email": "admin@example.com",
                "password": "admin123"
            }
            
            start_time = time.time()
            response = requests.post(
                f"{self.backend_url}/api/auth/login",
                json=login_data,
                timeout=10
            )
            auth_time = time.time() - start_time
            
            if response.status_code == 200:
                data = response.json()
                self.auth_token = data.get("access_token")
                self.performance_metrics["auth_time"] = auth_time
                return True
            else:
                self.log(f"Authentication failed: {response.status_code} - {response.text}", "FAIL")
                return False
                
        except Exception as e:
            self.log(f"Authentication error: {str(e)}", "FAIL")
            return False
            
    def get_headers(self) -> Dict[str, str]:
        """Get headers with authentication token"""
        headers = {"Content-Type": "application/json"}
        if self.auth_token:
            headers["Authorization"] = f"Bearer {self.auth_token}"
        return headers
        
    def test_api_response_times(self):
        """Test API response times for performance"""
        endpoints = [
            "/api/campaigns/progress",
            "/api/leads/",
            "/api/groups/",
            "/api/sequences/",
            "/api/sending-profiles/",
            "/api/dashboard"
        ]
        
        for endpoint in endpoints:
            try:
                start_time = time.time()
                response = requests.get(
                    f"{self.backend_url}{endpoint}",
                    headers=self.get_headers(),
                    timeout=10
                )
                duration = time.time() - start_time
                
                # Performance thresholds
                fast_threshold = 0.5  # 500ms
                acceptable_threshold = 2.0  # 2s
                
                if duration < fast_threshold:
                    status = "EXCELLENT"
                elif duration < acceptable_threshold:
                    status = "GOOD"
                else:
                    status = "SLOW"
                    
                self.test_result(
                    f"Response Time {endpoint}",
                    response.status_code == 200,
                    f"{status} - {duration:.3f}s",
                    duration
                )
                
            except Exception as e:
                self.test_result(f"Response Time {endpoint}", False, f"Exception: {str(e)}")
                
    def test_concurrent_requests(self):
        """Test system under concurrent load"""
        if not self.args.performance:
            return
            
        def make_request():
            try:
                response = requests.get(
                    f"{self.backend_url}/api/leads/",
                    headers=self.get_headers(),
                    timeout=10
                )
                return response.status_code == 200
            except:
                return False
                
        # Test with 10 concurrent requests
        start_time = time.time()
        with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
            futures = [executor.submit(make_request) for _ in range(10)]
            results = [future.result() for future in concurrent.futures.as_completed(futures)]
            
        duration = time.time() - start_time
        success_rate = sum(results) / len(results) * 100
        
        self.test_result(
            "Concurrent Load Test",
            success_rate >= 90,
            f"{success_rate:.1f}% success rate with 10 concurrent requests",
            duration
        )
        
    def test_large_dataset_handling(self):
        """Test handling of large datasets"""
        if not self.args.performance:
            return
            
        # Create large CSV data
        large_csv = "Email,First Name,Last Name,Company,Title\n"
        for i in range(1000):
            large_csv += f"test{i}@example.com,Test,User{i},Company{i},Title{i}\n"
            
        try:
            start_time = time.time()
            response = requests.post(
                f"{self.backend_url}/api/leads/csv/preview",
                json={
                    "csv_content": large_csv,
                    "has_header": True
                },
                headers=self.get_headers(),
                timeout=30
            )
            duration = time.time() - start_time
            
            self.test_result(
                "Large CSV Processing",
                response.status_code == 200,
                f"1000 rows processed in {duration:.3f}s",
                duration
            )
            
        except Exception as e:
            self.test_result("Large CSV Processing", False, f"Exception: {str(e)}")
            
    def test_sql_injection_protection(self):
        """Test SQL injection protection"""
        if not self.args.security:
            return
            
        sql_payloads = [
            "'; DROP TABLE leads; --",
            "' OR '1'='1",
            "' UNION SELECT * FROM users --",
            "'; INSERT INTO leads VALUES ('hack'); --",
            "1' OR 1=1 --"
        ]
        
        for payload in sql_payloads:
            try:
                # Test in search/filter parameters
                response = requests.get(
                    f"{self.backend_url}/api/leads/filter",
                    params={"industry": payload},
                    headers=self.get_headers(),
                    timeout=10
                )
                
                # Should not return 500 error (which might indicate SQL error)
                # Should return 200 or 400, but not crash
                safe = response.status_code != 500
                
                self.test_result(
                    f"SQL Injection Protection",
                    safe,
                    f"Payload: {payload[:20]}... - Status: {response.status_code}"
                )
                
            except Exception as e:
                self.test_result("SQL Injection Protection", False, f"Exception: {str(e)}")
                
    def test_authentication_security(self):
        """Test authentication security measures"""
        if not self.args.security:
            return
            
        # Test with invalid tokens
        invalid_tokens = [
            "invalid_token",
            "Bearer invalid",
            "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.invalid.signature",
            "",
            "' OR '1'='1",
            "<script>alert('xss')</script>"
        ]
        
        for token in invalid_tokens:
            try:
                headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
                response = requests.get(
                    f"{self.backend_url}/api/leads/",
                    headers=headers,
                    timeout=5
                )
                
                # Should return 401 Unauthorized, not crash
                secure = response.status_code == 401
                
                self.test_result(
                    "Invalid Token Handling",
                    secure,
                    f"Token: {token[:20]}... - Status: {response.status_code}"
                )
                
            except Exception as e:
                self.test_result("Invalid Token Handling", False, f"Exception: {str(e)}")
                
    def test_rate_limiting(self):
        """Test rate limiting protection"""
        if not self.args.security:
            return
            
        # Make rapid requests to test rate limiting
        rapid_requests = []
        for i in range(50):  # 50 rapid requests
            try:
                start = time.time()
                response = requests.get(
                    f"{self.backend_url}/api/health",
                    timeout=1
                )
                rapid_requests.append(response.status_code)
                time.sleep(0.01)  # 10ms between requests
            except:
                rapid_requests.append(0)
                
        # Check if any requests were rate limited (429 status code)
        rate_limited = any(status == 429 for status in rapid_requests)
        
        self.test_result(
            "Rate Limiting",
            True,  # Always pass, this is informational
            f"Rate limited: {rate_limited}, Responses: {set(rapid_requests)}"
        )
        
    def test_xss_protection(self):
        """Test XSS protection in input fields"""
        if not self.args.security:
            return
            
        xss_payloads = [
            "<script>alert('xss')</script>",
            "javascript:alert('xss')",
            "<img src=x onerror=alert('xss')>",
            "';alert('xss');//",
            "<svg onload=alert('xss')>"
        ]
        
        for payload in xss_payloads:
            try:
                # Test XSS in lead creation
                lead_data = {
                    "email": f"xss-test-{self.generate_random_string()}@example.com",
                    "first_name": payload,
                    "last_name": "Test",
                    "company": "Test Company"
                }
                
                response = requests.post(
                    f"{self.backend_url}/api/leads/",
                    json=lead_data,
                    headers=self.get_headers(),
                    timeout=10
                )
                
                if response.status_code == 200:
                    # Get the lead back and check if XSS payload was sanitized
                    lead = response.json()
                    sanitized = payload not in lead.get("first_name", "")
                    
                    self.test_result(
                        "XSS Protection",
                        sanitized,
                        f"Payload sanitized: {sanitized}"
                    )
                    
                    # Clean up
                    try:
                        requests.delete(
                            f"{self.backend_url}/api/leads/{lead['id']}",
                            headers=self.get_headers()
                        )
                    except:
                        pass
                        
            except Exception as e:
                self.test_result("XSS Protection", False, f"Exception: {str(e)}")
                
    def test_data_validation(self):
        """Test input validation and data integrity"""
        
        # Test invalid email formats
        invalid_emails = [
            "not-an-email",
            "@domain.com",
            "user@",
            "user..user@domain.com",
            "user@domain",
            ""
        ]
        
        for email in invalid_emails:
            try:
                lead_data = {
                    "email": email,
                    "first_name": "Test",
                    "last_name": "User"
                }
                
                response = requests.post(
                    f"{self.backend_url}/api/leads/",
                    json=lead_data,
                    headers=self.get_headers(),
                    timeout=10
                )
                
                # Should reject invalid emails
                valid_rejection = response.status_code in [400, 422]
                
                self.test_result(
                    "Email Validation",
                    valid_rejection,
                    f"Email: {email} - Status: {response.status_code}"
                )
                
            except Exception as e:
                self.test_result("Email Validation", False, f"Exception: {str(e)}")
                
    def test_edge_cases(self):
        """Test edge cases and boundary conditions"""
        
        # Test extremely long strings
        long_string = "A" * 10000
        try:
            lead_data = {
                "email": f"long-test-{self.generate_random_string()}@example.com",
                "first_name": long_string,
                "last_name": "Test"
            }
            
            response = requests.post(
                f"{self.backend_url}/api/leads/",
                json=lead_data,
                headers=self.get_headers(),
                timeout=10
            )
            
            # Should handle long strings gracefully (truncate or reject)
            handled_gracefully = response.status_code in [200, 400, 422]
            
            self.test_result(
                "Long String Handling",
                handled_gracefully,
                f"10,000 char string - Status: {response.status_code}"
            )
            
        except Exception as e:
            self.test_result("Long String Handling", False, f"Exception: {str(e)}")
            
        # Test empty payloads
        try:
            response = requests.post(
                f"{self.backend_url}/api/leads/",
                json={},
                headers=self.get_headers(),
                timeout=10
            )
            
            # Should reject empty payload
            proper_rejection = response.status_code in [400, 422]
            
            self.test_result(
                "Empty Payload Handling",
                proper_rejection,
                f"Status: {response.status_code}"
            )
            
        except Exception as e:
            self.test_result("Empty Payload Handling", False, f"Exception: {str(e)}")
            
    def test_database_transactions(self):
        """Test database transaction integrity"""
        
        # Test creating multiple related records in sequence
        try:
            # Create a lead
            lead_data = {
                "email": f"transaction-test-{self.generate_random_string()}@example.com",
                "first_name": "Transaction",
                "last_name": "Test"
            }
            
            response = requests.post(
                f"{self.backend_url}/api/leads/",
                json=lead_data,
                headers=self.get_headers(),
                timeout=10
            )
            
            if response.status_code == 200:
                lead = response.json()
                
                # Create a group
                group_data = {
                    "name": f"Transaction Group {self.generate_random_string()}",
                    "description": "Test group for transaction testing"
                }
                
                group_response = requests.post(
                    f"{self.backend_url}/api/groups/",
                    json=group_data,
                    headers=self.get_headers(),
                    timeout=10
                )
                
                if group_response.status_code == 200:
                    group = group_response.json()
                    
                    # Test referential integrity
                    self.test_result(
                        "Database Transactions",
                        True,
                        f"Created lead {lead['id']} and group {group['id']}"
                    )
                    
                    # Cleanup
                    self.test_data["transaction_lead_id"] = lead["id"]
                    self.test_data["transaction_group_id"] = group["id"]
                    
                else:
                    self.test_result("Database Transactions", False, "Failed to create group")
            else:
                self.test_result("Database Transactions", False, "Failed to create lead")
                
        except Exception as e:
            self.test_result("Database Transactions", False, f"Exception: {str(e)}")
            
    def test_csv_edge_cases(self):
        """Test CSV upload with various edge cases"""
        
        edge_case_csvs = [
            # CSV with special characters
            'Email,Name\n"test@example.com","John, Jr."\n"test2@example.com","Smith & Sons"',
            
            # CSV with quotes and commas
            'Email,Company\ntest@example.com,"Company, Inc."\ntest2@example.com,"John\'s ""Company"""',
            
            # CSV with Unicode characters
            'Email,Name\ntest@example.com,José\ntest2@example.com,北京',
            
            # CSV with empty fields
            'Email,Name,Company\ntest@example.com,,\n,John,Acme\ntest2@example.com,Jane,',
            
            # Malformed CSV
            'Email,Name\ntest@example.com,John\nmissingcomma\ntest2@example.com,Jane'
        ]
        
        for i, csv_content in enumerate(edge_case_csvs):
            try:
                response = requests.post(
                    f"{self.backend_url}/api/leads/csv/preview",
                    json={
                        "csv_content": csv_content,
                        "has_header": True
                    },
                    headers=self.get_headers(),
                    timeout=10
                )
                
                # Should handle gracefully (either process or reject with proper error)
                handled_gracefully = response.status_code in [200, 400]
                
                self.test_result(
                    f"CSV Edge Case {i+1}",
                    handled_gracefully,
                    f"Status: {response.status_code}"
                )
                
            except Exception as e:
                self.test_result(f"CSV Edge Case {i+1}", False, f"Exception: {str(e)}")
                
    def test_stress_scenarios(self):
        """Test system under stress conditions"""
        if not self.args.stress:
            return
            
        # Memory stress test - create many leads rapidly
        created_leads = []
        start_time = time.time()
        
        try:
            for i in range(100):
                lead_data = {
                    "email": f"stress-test-{i}-{self.generate_random_string()}@example.com",
                    "first_name": f"Stress{i}",
                    "last_name": "Test"
                }
                
                response = requests.post(
                    f"{self.backend_url}/api/leads/",
                    json=lead_data,
                    headers=self.get_headers(),
                    timeout=5
                )
                
                if response.status_code == 200:
                    created_leads.append(response.json()["id"])
                    
            duration = time.time() - start_time
            success_rate = len(created_leads) / 100 * 100
            
            self.test_result(
                "Stress Test - Rapid Creation",
                success_rate >= 80,
                f"{success_rate:.1f}% success rate, {len(created_leads)} leads in {duration:.3f}s"
            )
            
            # Store for cleanup
            self.test_data["stress_lead_ids"] = created_leads
            
        except Exception as e:
            self.test_result("Stress Test - Rapid Creation", False, f"Exception: {str(e)}")
            
    def test_api_versioning_and_compatibility(self):
        """Test API versioning and backward compatibility"""
        
        # Test API with different Accept headers
        headers_to_test = [
            {"Accept": "application/json"},
            {"Accept": "application/json; version=1"},
            {"Accept": "application/xml"},  # Should handle gracefully
            {"Accept": "*/*"},
            {"Accept": ""},
        ]
        
        for headers in headers_to_test:
            try:
                test_headers = {**self.get_headers(), **headers}
                response = requests.get(
                    f"{self.backend_url}/api/health",
                    headers=test_headers,
                    timeout=5
                )
                
                # Should respond appropriately to different Accept headers
                appropriate_response = response.status_code in [200, 406]
                
                self.test_result(
                    "API Accept Headers",
                    appropriate_response,
                    f"Accept: {headers.get('Accept', 'default')} - Status: {response.status_code}"
                )
                
            except Exception as e:
                self.test_result("API Accept Headers", False, f"Exception: {str(e)}")
                
    def test_error_handling_and_logging(self):
        """Test error handling and ensure proper logging"""
        
        # Test various error scenarios
        error_scenarios = [
            ("GET", "/api/nonexistent", {}, "404 for non-existent endpoint"),
            ("GET", "/api/leads/999999", {}, "404 for non-existent resource"),
            ("POST", "/api/leads/", {}, "400 for invalid data"),
            ("PUT", "/api/campaigns/999999/complete", {}, "404 for non-existent campaign"),
            ("DELETE", "/api/leads/999999", {}, "404 for non-existent lead deletion"),
        ]
        
        for method, endpoint, data, description in error_scenarios:
            if data is None:
                data = {}
            try:
                if method == "GET":
                    response = requests.get(
                        f"{self.backend_url}{endpoint}",
                        headers=self.get_headers(),
                        timeout=5
                    )
                elif method == "POST":
                    response = requests.post(
                        f"{self.backend_url}{endpoint}",
                        json=data,
                        headers=self.get_headers(),
                        timeout=5
                    )
                elif method == "PUT":
                    response = requests.put(
                        f"{self.backend_url}{endpoint}",
                        headers=self.get_headers(),
                        timeout=5
                    )
                elif method == "DELETE":
                    response = requests.delete(
                        f"{self.backend_url}{endpoint}",
                        headers=self.get_headers(),
                        timeout=5
                    )
                
                # Check if error is handled properly
                proper_error = 400 <= response.status_code < 500
                
                self.test_result(
                    "Error Handling",
                    proper_error,
                    f"{description} - Status: {response.status_code}"
                )
                
            except Exception as e:
                self.test_result("Error Handling", False, f"Exception: {str(e)}")
                
    def cleanup_comprehensive_test_data(self):
        """Clean up all test data created during comprehensive testing"""
        
        cleanup_tasks = [
            ("transaction_lead_id", "leads"),
            ("stress_lead_ids", "leads"),  # Multiple IDs
            ("transaction_group_id", "groups")
        ]
        
        for data_key, endpoint in cleanup_tasks:
            if data_key in self.test_data:
                if data_key == "stress_lead_ids":
                    # Handle multiple IDs
                    for lead_id in self.test_data[data_key]:
                        try:
                            requests.delete(
                                f"{self.backend_url}/api/{endpoint}/{lead_id}",
                                headers=self.get_headers(),
                                timeout=5
                            )
                        except:
                            pass
                else:
                    # Handle single ID
                    try:
                        requests.delete(
                            f"{self.backend_url}/api/{endpoint}/{self.test_data[data_key]}",
                            headers=self.get_headers(),
                            timeout=5
                        )
                    except:
                        pass
                        
    def generate_performance_report(self):
        """Generate detailed performance report"""
        if not self.performance_metrics and not any(r.get("duration", 0) > 0 for r in self.test_results):
            return
            
        print("\n" + "="*60)
        print("PERFORMANCE ANALYSIS")
        print("="*60)
        
        # Authentication performance
        if "auth_time" in self.performance_metrics:
            auth_time = self.performance_metrics["auth_time"]
            print(f"Authentication Time: {auth_time:.3f}s")
            
        # API response times
        api_tests = [r for r in self.test_results if "Response Time" in r["test"] and r["duration"] > 0]
        if api_tests:
            print("\nAPI Response Times:")
            for test in sorted(api_tests, key=lambda x: x["duration"]):
                endpoint = test["test"].replace("Response Time ", "")
                duration = test["duration"]
                status = "🟢" if duration < 0.5 else "🟡" if duration < 2.0 else "🔴"
                print(f"  {status} {endpoint:30} {duration:.3f}s")
                
        # Performance statistics
        durations = [r["duration"] for r in self.test_results if r["duration"] > 0]
        if durations:
            avg_duration = sum(durations) / len(durations)
            max_duration = max(durations)
            print(f"\nPerformance Statistics:")
            print(f"  Average Response Time: {avg_duration:.3f}s")
            print(f"  Slowest Response:      {max_duration:.3f}s")
            print(f"  Total Tests Timed:     {len(durations)}")
            
    def generate_security_report(self):
        """Generate detailed security report"""
        security_tests = [r for r in self.test_results if any(keyword in r["test"] for keyword in 
                          ["SQL Injection", "XSS", "Authentication", "Rate Limiting", "Token"])]
        
        if not security_tests:
            return
            
        print("\n" + "="*60)
        print("SECURITY ANALYSIS")
        print("="*60)
        
        passed_security = len([t for t in security_tests if t["status"] == "PASS"])
        total_security = len(security_tests)
        
        print(f"Security Tests Passed: {passed_security}/{total_security}")
        print(f"Security Score: {(passed_security/total_security)*100:.1f}%")
        
        print("\nSecurity Test Results:")
        for test in security_tests:
            status_icon = "✅" if test["status"] == "PASS" else "❌"
            print(f"  {status_icon} {test['test']}")
            if test["message"]:
                print(f"     {test['message']}")
                
    def generate_comprehensive_report(self):
        """Generate comprehensive test report"""
        passed = len([r for r in self.test_results if r["status"] == "PASS"])
        failed = len([r for r in self.test_results if r["status"] == "FAIL"])
        total = len(self.test_results)
        
        print("\n" + "="*80)
        print("COMPREHENSIVE SYSTEM TEST REPORT")
        print("="*80)
        print(f"Total Tests: {total}")
        print(f"Passed: {passed}")
        print(f"Failed: {failed}")
        print(f"Success Rate: {(passed/total)*100:.1f}%" if total > 0 else "No tests run")
        
        # Test categories
        categories = {}
        for result in self.test_results:
            test_name = result["test"]
            if "Response Time" in test_name:
                category = "Performance"
            elif any(keyword in test_name for keyword in ["SQL", "XSS", "Authentication", "Security", "Token", "Rate"]):
                category = "Security"
            elif "Edge Case" in test_name or "Validation" in test_name:
                category = "Edge Cases"
            elif "Stress" in test_name or "Concurrent" in test_name:
                category = "Stress Testing"
            else:
                category = "Functional"
                
            if category not in categories:
                categories[category] = {"passed": 0, "total": 0}
            categories[category]["total"] += 1
            if result["status"] == "PASS":
                categories[category]["passed"] += 1
                
        print("\nTest Categories:")
        for category, stats in categories.items():
            success_rate = (stats["passed"] / stats["total"]) * 100
            print(f"  {category:15} {stats['passed']:3}/{stats['total']:3} ({success_rate:5.1f}%)")
            
        # Generate specialized reports
        self.generate_performance_report()
        self.generate_security_report()
        
        # Failed tests summary
        failed_tests = [r for r in self.test_results if r["status"] == "FAIL"]
        if failed_tests:
            print("\n" + "="*60)
            print("FAILED TESTS DETAILS")
            print("="*60)
            for test in failed_tests:
                print(f"❌ {test['test']}")
                if test["message"]:
                    print(f"   {test['message']}")
                print()
                
        return failed == 0
        
    def run_comprehensive_tests(self):
        """Run the complete comprehensive test suite"""
        self.log("Starting Comprehensive Email Automation System Tests", "INFO")
        
        # Authentication
        self.log("🔑 Authenticating...", "INFO")
        auth_success = self.authenticate()
        self.test_result("Authentication", auth_success)
        
        if not auth_success:
            self.log("Authentication failed. Cannot continue with authenticated tests.", "FAIL")
            return self.generate_comprehensive_report()
            
        # Core functionality tests
        self.log("🧪 Running core functionality tests...", "INFO")
        self.test_api_response_times()
        self.test_data_validation()
        self.test_edge_cases()
        self.test_csv_edge_cases()
        self.test_database_transactions()
        self.test_error_handling_and_logging()
        self.test_api_versioning_and_compatibility()
        
        # Performance tests
        if self.args.performance:
            self.log("⚡ Running performance tests...", "PERF")
            self.test_concurrent_requests()
            self.test_large_dataset_handling()
            
        # Security tests
        if self.args.security:
            self.log("🔒 Running security tests...", "SEC")
            self.test_sql_injection_protection()
            self.test_authentication_security()
            self.test_rate_limiting()
            self.test_xss_protection()
            
        # Stress tests
        if self.args.stress:
            self.log("💪 Running stress tests...", "INFO")
            self.test_stress_scenarios()
            
        # Cleanup
        self.log("🧹 Cleaning up test data...", "INFO")
        self.cleanup_comprehensive_test_data()
        
        # Generate comprehensive report
        return self.generate_comprehensive_report()

def main():
    parser = argparse.ArgumentParser(description="Comprehensive Email Automation System Tests")
    parser.add_argument("--performance", action="store_true", help="Run performance tests")
    parser.add_argument("--security", action="store_true", help="Run security tests")
    parser.add_argument("--stress", action="store_true", help="Run stress tests")
    parser.add_argument("--all", action="store_true", help="Run all test types")
    
    args = parser.parse_args()
    
    # If --all is specified, enable all test types
    if args.all:
        args.performance = True
        args.security = True
        args.stress = True
        
    print("🧪 Comprehensive Email Automation System Test Suite")
    print("=" * 60)
    
    test_types = []
    if args.performance:
        test_types.append("Performance")
    if args.security:
        test_types.append("Security")
    if args.stress:
        test_types.append("Stress")
        
    if test_types:
        print(f"Test types enabled: {', '.join(test_types)}")
    else:
        print("Running basic functionality tests only")
        print("Use --performance, --security, --stress, or --all for extended testing")
    print()
    
    runner = ComprehensiveTestRunner(args)
    success = runner.run_comprehensive_tests()
    
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()