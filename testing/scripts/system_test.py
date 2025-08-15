#!/usr/bin/env python3
"""
Email Automation System Test Script
==================================

This script performs comprehensive testing of the entire email automation system,
including backend API endpoints, database operations, and frontend functionality.

Usage: python3 system_test.py
"""

import requests
import json
import time
import sys
from datetime import datetime
from typing import Dict, Any, Optional
import subprocess
import os

class SystemTestRunner:
    def __init__(self):
        self.backend_url = "http://localhost:8000"
        self.frontend_url = "http://localhost:3000"
        self.auth_token = None
        self.test_results = []
        self.test_data = {}
        
    def log(self, message: str, level: str = "INFO"):
        """Log test messages with timestamp"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] [{level}] {message}")
        
    def test_result(self, test_name: str, passed: bool, message: str = ""):
        """Record test result"""
        status = "PASS" if passed else "FAIL"
        self.test_results.append({
            "test": test_name,
            "status": status,
            "message": message,
            "timestamp": datetime.now().isoformat()
        })
        self.log(f"{test_name}: {status}" + (f" - {message}" if message else ""))
        
    def check_service_health(self, service_name: str, url: str) -> bool:
        """Check if a service is running and responding"""
        try:
            response = requests.get(url, timeout=5)
            return response.status_code < 500
        except Exception as e:
            self.log(f"{service_name} health check failed: {str(e)}", "ERROR")
            return False
            
    def authenticate(self) -> bool:
        """Authenticate and get JWT token"""
        try:
            # Try to login with default admin credentials
            login_data = {
                "email": "admin@example.com",
                "password": "admin123"
            }
            
            response = requests.post(
                f"{self.backend_url}/api/auth/login",
                json=login_data,
                timeout=10
            )
            
            if response.status_code == 200:
                data = response.json()
                self.auth_token = data.get("access_token")
                return True
            else:
                self.log(f"Authentication failed: {response.status_code} - {response.text}", "ERROR")
                return False
                
        except Exception as e:
            self.log(f"Authentication error: {str(e)}", "ERROR")
            return False
            
    def get_headers(self) -> Dict[str, str]:
        """Get headers with authentication token"""
        headers = {"Content-Type": "application/json"}
        if self.auth_token:
            headers["Authorization"] = f"Bearer {self.auth_token}"
        return headers
        
    def test_backend_endpoints(self):
        """Test all backend API endpoints"""
        endpoints_to_test = [
            # Authentication endpoints
            ("GET", "/api/auth/me", "Get current user"),
            
            # Campaign endpoints
            ("GET", "/api/campaigns/", "List campaigns"),
            ("GET", "/api/campaigns/progress", "Get campaign progress"),
            ("GET", "/api/campaigns/archived", "Get archived campaigns"),
            
            # Lead endpoints
            ("GET", "/api/leads/", "List leads"),
            ("GET", "/api/leads/industries", "Get lead industries"),
            ("GET", "/api/leads/filter", "Filter leads"),
            
            # Group endpoints
            ("GET", "/api/groups/", "List groups"),
            
            # Sequence endpoints
            ("GET", "/api/sequences/", "List sequences"),
            
            # Sending profile endpoints
            ("GET", "/api/sending-profiles/", "List sending profiles"),
            
            # Dashboard endpoint
            ("GET", "/api/dashboard", "Get dashboard stats"),
            
            # Health check
            ("GET", "/api/health", "Health check"),
        ]
        
        for method, endpoint, description in endpoints_to_test:
            try:
                if method == "GET":
                    response = requests.get(
                        f"{self.backend_url}{endpoint}",
                        headers=self.get_headers(),
                        timeout=10
                    )
                elif method == "POST":
                    response = requests.post(
                        f"{self.backend_url}{endpoint}",
                        headers=self.get_headers(),
                        timeout=10
                    )
                
                success = response.status_code < 400
                self.test_result(
                    f"API {method} {endpoint}",
                    success,
                    f"Status: {response.status_code}" + (f" - {response.text[:100]}" if not success else "")
                )
                
            except Exception as e:
                self.test_result(f"API {method} {endpoint}", False, f"Exception: {str(e)}")
                
    def test_crud_operations(self):
        """Test Create, Read, Update, Delete operations"""
        
        # Test lead creation
        try:
            lead_data = {
                "email": f"test-lead-{int(time.time())}@example.com",
                "first_name": "Test",
                "last_name": "Lead",
                "company": "Test Company",
                "title": "Test Title",
                "industry": "Technology"
            }
            
            response = requests.post(
                f"{self.backend_url}/api/leads/",
                json=lead_data,
                headers=self.get_headers(),
                timeout=10
            )
            
            if response.status_code == 200:
                lead = response.json()
                self.test_data["test_lead_id"] = lead["id"]
                self.test_result("Create Lead", True, f"Created lead ID: {lead['id']}")
            else:
                self.test_result("Create Lead", False, f"Status: {response.status_code}")
                
        except Exception as e:
            self.test_result("Create Lead", False, f"Exception: {str(e)}")
            
        # Test lead retrieval
        if "test_lead_id" in self.test_data:
            try:
                response = requests.get(
                    f"{self.backend_url}/api/leads/{self.test_data['test_lead_id']}",
                    headers=self.get_headers(),
                    timeout=10
                )
                
                success = response.status_code == 200
                self.test_result("Read Lead", success, f"Status: {response.status_code}")
                
            except Exception as e:
                self.test_result("Read Lead", False, f"Exception: {str(e)}")
                
        # Test group creation
        try:
            group_data = {
                "name": f"Test Group {int(time.time())}",
                "description": "Test group for system testing"
            }
            
            response = requests.post(
                f"{self.backend_url}/api/groups/",
                json=group_data,
                headers=self.get_headers(),
                timeout=10
            )
            
            if response.status_code == 200:
                group = response.json()
                self.test_data["test_group_id"] = group["id"]
                self.test_result("Create Group", True, f"Created group ID: {group['id']}")
            else:
                self.test_result("Create Group", False, f"Status: {response.status_code}")
                
        except Exception as e:
            self.test_result("Create Group", False, f"Exception: {str(e)}")
            
    def test_csv_upload(self):
        """Test CSV upload functionality"""
        try:
            csv_content = """Email,First Name,Last Name,Company
test1@example.com,John,Doe,Acme Corp
test2@example.com,Jane,Smith,Tech Inc"""
            
            preview_data = {
                "csv_content": csv_content,
                "has_header": True
            }
            
            response = requests.post(
                f"{self.backend_url}/api/leads/csv/preview",
                json=preview_data,
                headers=self.get_headers(),
                timeout=10
            )
            
            success = response.status_code == 200
            self.test_result("CSV Preview", success, f"Status: {response.status_code}")
            
        except Exception as e:
            self.test_result("CSV Preview", False, f"Exception: {str(e)}")
            
    def test_campaign_operations(self):
        """Test campaign-related operations"""
        
        # Create a test campaign if we have leads
        if "test_lead_id" in self.test_data:
            try:
                # First, get sending profiles
                response = requests.get(
                    f"{self.backend_url}/api/sending-profiles/",
                    headers=self.get_headers(),
                    timeout=10
                )
                
                if response.status_code == 200:
                    profiles = response.json()
                    if profiles:
                        profile_id = profiles[0]["id"]
                        
                        campaign_data = {
                            "name": f"Test Campaign {int(time.time())}",
                            "ai_prompt": "Write a professional introduction email",
                            "lead_ids": [self.test_data["test_lead_id"]],
                            "sending_profile_id": profile_id
                        }
                        
                        response = requests.post(
                            f"{self.backend_url}/api/campaigns/",
                            json=campaign_data,
                            headers=self.get_headers(),
                            timeout=10
                        )
                        
                        if response.status_code == 200:
                            campaign = response.json()
                            self.test_data["test_campaign_id"] = campaign["id"]
                            self.test_result("Create Campaign", True, f"Created campaign ID: {campaign['id']}")
                            
                            # Test campaign completion
                            response = requests.put(
                                f"{self.backend_url}/api/campaigns/{campaign['id']}/complete",
                                headers=self.get_headers(),
                                timeout=10
                            )
                            
                            success = response.status_code == 200
                            self.test_result("Complete Campaign", success, f"Status: {response.status_code}")
                            
                            # Test campaign archival
                            response = requests.put(
                                f"{self.backend_url}/api/campaigns/{campaign['id']}/archive",
                                headers=self.get_headers(),
                                timeout=10
                            )
                            
                            success = response.status_code == 200
                            self.test_result("Archive Campaign", success, f"Status: {response.status_code}")
                            
                        else:
                            self.test_result("Create Campaign", False, f"Status: {response.status_code}")
                    else:
                        self.test_result("Create Campaign", False, "No sending profiles available")
                else:
                    self.test_result("Get Sending Profiles", False, f"Status: {response.status_code}")
                    
            except Exception as e:
                self.test_result("Campaign Operations", False, f"Exception: {str(e)}")
                
    def test_frontend_accessibility(self):
        """Test if frontend pages are accessible"""
        pages_to_test = [
            "/",
            "/campaigns",
            "/leads", 
            "/groups",
            "/sequences",
            "/profiles"
        ]
        
        for page in pages_to_test:
            try:
                response = requests.get(f"{self.frontend_url}{page}", timeout=10)
                success = response.status_code == 200
                self.test_result(f"Frontend {page}", success, f"Status: {response.status_code}")
            except Exception as e:
                self.test_result(f"Frontend {page}", False, f"Exception: {str(e)}")
                
    def test_database_connectivity(self):
        """Test database connectivity through health endpoint"""
        try:
            response = requests.get(f"{self.backend_url}/api/health", timeout=5)
            success = response.status_code == 200
            self.test_result("Database Connectivity", success, f"Status: {response.status_code}")
        except Exception as e:
            self.test_result("Database Connectivity", False, f"Exception: {str(e)}")
            
    def test_docker_containers(self):
        """Test Docker container status"""
        try:
            result = subprocess.run(
                ["docker", "ps", "--format", "table {{.Names}}\t{{.Status}}"],
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if result.returncode == 0:
                container_status = result.stdout
                required_containers = [
                    "email-automation-frontend-1",
                    "email-automation-backend-1", 
                    "email-automation-db-1"
                ]
                
                for container in required_containers:
                    if container in container_status and "Up" in container_status:
                        self.test_result(f"Container {container}", True, "Running")
                    else:
                        self.test_result(f"Container {container}", False, "Not running or not found")
            else:
                self.test_result("Docker Status", False, "Could not check Docker status")
                
        except Exception as e:
            self.test_result("Docker Status", False, f"Exception: {str(e)}")
            
    def cleanup_test_data(self):
        """Clean up any test data created during testing"""
        # Delete test lead if created
        if "test_lead_id" in self.test_data:
            try:
                response = requests.delete(
                    f"{self.backend_url}/api/leads/{self.test_data['test_lead_id']}",
                    headers=self.get_headers(),
                    timeout=10
                )
                self.log(f"Cleaned up test lead: {response.status_code}")
            except Exception as e:
                self.log(f"Failed to clean up test lead: {str(e)}", "WARNING")
                
    def generate_report(self):
        """Generate and display test report"""
        passed = len([r for r in self.test_results if r["status"] == "PASS"])
        failed = len([r for r in self.test_results if r["status"] == "FAIL"])
        total = len(self.test_results)
        
        print("\n" + "="*60)
        print("SYSTEM TEST REPORT")
        print("="*60)
        print(f"Total Tests: {total}")
        print(f"Passed: {passed}")
        print(f"Failed: {failed}")
        print(f"Success Rate: {(passed/total)*100:.1f}%" if total > 0 else "No tests run")
        print("="*60)
        
        if failed > 0:
            print("\nFAILED TESTS:")
            print("-" * 40)
            for result in self.test_results:
                if result["status"] == "FAIL":
                    print(f"❌ {result['test']}: {result['message']}")
                    
        print("\nALL TEST RESULTS:")
        print("-" * 40)
        for result in self.test_results:
            icon = "✅" if result["status"] == "PASS" else "❌"
            print(f"{icon} {result['test']}")
            if result["message"]:
                print(f"   {result['message']}")
                
        return failed == 0
        
    def run_all_tests(self):
        """Run the complete system test suite"""
        self.log("Starting Email Automation System Tests")
        
        # Pre-flight checks
        self.log("Running pre-flight checks...")
        
        backend_healthy = self.check_service_health("Backend", f"{self.backend_url}/api/health")
        self.test_result("Backend Health Check", backend_healthy)
        
        frontend_healthy = self.check_service_health("Frontend", self.frontend_url)
        self.test_result("Frontend Health Check", frontend_healthy)
        
        if not backend_healthy:
            self.log("Backend is not healthy. Skipping API tests.", "WARNING")
            return self.generate_report()
            
        # Authentication
        self.log("Authenticating...")
        auth_success = self.authenticate()
        self.test_result("Authentication", auth_success)
        
        if not auth_success:
            self.log("Authentication failed. Skipping authenticated tests.", "WARNING")
        else:
            # Core functionality tests
            self.log("Testing backend endpoints...")
            self.test_backend_endpoints()
            
            self.log("Testing CRUD operations...")
            self.test_crud_operations()
            
            self.log("Testing CSV upload...")
            self.test_csv_upload()
            
            self.log("Testing campaign operations...")
            self.test_campaign_operations()
            
        # Infrastructure tests
        self.log("Testing Docker containers...")
        self.test_docker_containers()
        
        self.log("Testing database connectivity...")
        self.test_database_connectivity()
        
        if frontend_healthy:
            self.log("Testing frontend accessibility...")
            self.test_frontend_accessibility()
            
        # Cleanup
        self.log("Cleaning up test data...")
        self.cleanup_test_data()
        
        # Generate report
        return self.generate_report()

if __name__ == "__main__":
    print("Email Automation System Test")
    print("=" * 40)
    
    runner = SystemTestRunner()
    success = runner.run_all_tests()
    
    sys.exit(0 if success else 1)