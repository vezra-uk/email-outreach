#!/usr/bin/env python3
"""
Advanced Load Testing Suite
===========================

Simulates real-world usage patterns and measures system performance under load.

Usage: python3 load_test.py [--users N] [--duration N] [--ramp-up N]
"""

import requests
import time
import threading
import statistics
import random
import json
import argparse
from datetime import datetime, timedelta
from typing import List, Dict
import queue
import sys

class LoadTestMetrics:
    def __init__(self):
        self.response_times = []
        self.status_codes = []
        self.errors = []
        self.requests_per_second = []
        self.start_time = None
        self.end_time = None
        self.lock = threading.Lock()
        
    def record_request(self, response_time: float, status_code: int, error: str = None):
        with self.lock:
            self.response_times.append(response_time)
            self.status_codes.append(status_code)
            if error:
                self.errors.append(error)
                
    def get_stats(self):
        with self.lock:
            if not self.response_times:
                return {}
                
            total_requests = len(self.response_times)
            success_requests = len([s for s in self.status_codes if 200 <= s < 400])
            error_requests = len([s for s in self.status_codes if s >= 400])
            
            # Calculate duration dynamically
            duration = getattr(self, 'duration', None)
            if duration is None and self.start_time:
                current_time = self.end_time if self.end_time else time.time()
                duration = current_time - self.start_time
            if duration is None or duration <= 0:
                duration = 1  # Fallback to prevent division by zero
            
            return {
                "total_requests": total_requests,
                "successful_requests": success_requests,
                "error_requests": error_requests,
                "success_rate": (success_requests / total_requests) * 100 if total_requests > 0 else 0,
                "avg_response_time": statistics.mean(self.response_times),
                "min_response_time": min(self.response_times),
                "max_response_time": max(self.response_times),
                "p50_response_time": statistics.median(self.response_times),
                "p95_response_time": self.percentile(self.response_times, 95),
                "p99_response_time": self.percentile(self.response_times, 99),
                "requests_per_second": total_requests / duration,
                "errors": len(self.errors),
                "error_rate": (len(self.errors) / total_requests) * 100 if total_requests > 0 else 0
            }
            
    def percentile(self, data: List[float], p: int) -> float:
        if not data:
            return 0
        return statistics.quantiles(sorted(data), n=100)[p-1] if len(data) > 1 else data[0]

class LoadTestUser:
    def __init__(self, user_id: int, base_url: str, auth_token: str, metrics: LoadTestMetrics, duration: int):
        self.user_id = user_id
        self.base_url = base_url
        self.auth_token = auth_token
        self.metrics = metrics
        self.duration = duration
        self.session = requests.Session()
        self.session.headers.update({
            "Authorization": f"Bearer {auth_token}",
            "Content-Type": "application/json"
        })
        
    def get_headers(self):
        return {
            "Authorization": f"Bearer {self.auth_token}",
            "Content-Type": "application/json"
        }
        
    def make_request(self, method: str, endpoint: str, **kwargs):
        """Make a request and record metrics"""
        start_time = time.time()
        error = None
        
        try:
            if method.upper() == "GET":
                response = self.session.get(f"{self.base_url}{endpoint}", timeout=30, **kwargs)
            elif method.upper() == "POST":
                response = self.session.post(f"{self.base_url}{endpoint}", timeout=30, **kwargs)
            elif method.upper() == "PUT":
                response = self.session.put(f"{self.base_url}{endpoint}", timeout=30, **kwargs)
            elif method.upper() == "DELETE":
                response = self.session.delete(f"{self.base_url}{endpoint}", timeout=30, **kwargs)
            else:
                raise ValueError(f"Unsupported method: {method}")
                
            response_time = time.time() - start_time
            self.metrics.record_request(response_time, response.status_code)
            return response
            
        except requests.exceptions.Timeout:
            response_time = time.time() - start_time
            self.metrics.record_request(response_time, 408, "Timeout")
            return None
        except Exception as e:
            response_time = time.time() - start_time
            self.metrics.record_request(response_time, 0, str(e))
            return None
            
    def simulate_user_journey(self):
        """Simulate a typical user journey"""
        scenarios = [
            self.dashboard_browsing,
            self.lead_management,
            self.campaign_creation,
            self.data_export
        ]
        
        # Randomly select and execute scenarios
        scenario = random.choice(scenarios)
        scenario()
        
    def dashboard_browsing(self):
        """Simulate dashboard browsing behavior"""
        # View dashboard
        self.make_request("GET", "/api/dashboard")
        
        # View campaigns
        self.make_request("GET", "/api/campaigns/progress")
        time.sleep(random.uniform(1, 3))  # User reading time
        
        # View leads
        self.make_request("GET", "/api/leads/")
        time.sleep(random.uniform(0.5, 2))
        
    def lead_management(self):
        """Simulate lead management activities"""
        # List leads
        self.make_request("GET", "/api/leads/")
        
        # Filter leads
        industries = ["Technology", "Healthcare", "Finance", "Retail"]
        self.make_request("GET", "/api/leads/filter", params={"industry": random.choice(industries)})
        
        # Get industries
        self.make_request("GET", "/api/leads/industries")
        
        time.sleep(random.uniform(2, 5))  # User thinking time
        
    def campaign_creation(self):
        """Simulate campaign creation workflow"""
        # Get sending profiles
        self.make_request("GET", "/api/sending-profiles/")
        
        # Get leads for campaign
        self.make_request("GET", "/api/leads/")
        
        # Get groups
        self.make_request("GET", "/api/groups/")
        
        time.sleep(random.uniform(5, 10))  # User designing campaign
        
    def data_export(self):
        """Simulate data export activities"""
        # Create sample CSV data for preview
        csv_data = {
            "csv_content": "Email,Name\ntest@example.com,Test User",
            "has_header": True
        }
        self.make_request("POST", "/api/leads/csv/preview", json=csv_data)
        
        time.sleep(random.uniform(1, 3))
        
    def run(self):
        """Run the user simulation for the specified duration"""
        end_time = time.time() + self.duration
        
        while time.time() < end_time:
            self.simulate_user_journey()
            # Random pause between actions
            time.sleep(random.uniform(0.1, 1.0))

class LoadTestRunner:
    def __init__(self, args):
        self.base_url = "http://localhost:8000"
        self.users = args.users
        self.duration = args.duration
        self.ramp_up = args.ramp_up
        self.auth_token = None
        self.metrics = LoadTestMetrics()
        
    def authenticate(self) -> bool:
        """Get authentication token"""
        try:
            response = requests.post(
                f"{self.base_url}/api/auth/login",
                json={"email": "admin@example.com", "password": "admin123"},
                timeout=10
            )
            
            if response.status_code == 200:
                data = response.json()
                self.auth_token = data.get("access_token")
                return True
            else:
                print(f"❌ Authentication failed: {response.status_code}")
                return False
                
        except Exception as e:
            print(f"❌ Authentication error: {str(e)}")
            return False
            
    def run_load_test(self):
        """Execute the load test"""
        print(f"🚀 Starting load test with {self.users} users for {self.duration}s")
        print(f"⏱️  Ramp-up time: {self.ramp_up}s")
        
        if not self.authenticate():
            return False
            
        self.metrics.start_time = time.time()
        
        # Create and start user threads
        threads = []
        for user_id in range(self.users):
            user = LoadTestUser(user_id, self.base_url, self.auth_token, self.metrics, self.duration)
            thread = threading.Thread(target=user.run)
            threads.append(thread)
            
            # Ramp up users gradually
            thread.start()
            if self.ramp_up > 0:
                time.sleep(self.ramp_up / self.users)
                
        # Monitor progress
        self.monitor_progress()
        
        # Wait for all threads to complete
        for thread in threads:
            thread.join()
            
        self.metrics.end_time = time.time()
        self.metrics.duration = self.metrics.end_time - self.metrics.start_time
        
        return True
        
    def monitor_progress(self):
        """Monitor and display progress during the test"""
        start_time = time.time()
        
        while time.time() - start_time < self.duration:
            time.sleep(5)  # Update every 5 seconds
            elapsed = time.time() - start_time
            progress = (elapsed / self.duration) * 100
            
            current_stats = self.metrics.get_stats()
            if current_stats:
                print(f"⏳ Progress: {progress:.1f}% | "
                      f"Requests: {current_stats['total_requests']} | "
                      f"Success Rate: {current_stats['success_rate']:.1f}% | "
                      f"Avg Response: {current_stats['avg_response_time']:.3f}s")
                      
    def generate_report(self):
        """Generate detailed load test report"""
        stats = self.metrics.get_stats()
        
        print("\n" + "="*80)
        print("LOAD TEST REPORT")
        print("="*80)
        
        if not stats:
            print("❌ No data collected")
            return False
            
        # Summary statistics
        print(f"📊 Test Summary:")
        print(f"   Duration:           {self.metrics.duration:.1f}s")
        print(f"   Virtual Users:      {self.users}")
        print(f"   Total Requests:     {stats['total_requests']}")
        print(f"   Successful:         {stats['successful_requests']}")
        print(f"   Failed:             {stats['error_requests']}")
        print(f"   Success Rate:       {stats['success_rate']:.2f}%")
        print(f"   Requests/Second:    {stats['requests_per_second']:.2f}")
        
        # Response time statistics
        print(f"\n⚡ Response Times:")
        print(f"   Average:            {stats['avg_response_time']:.3f}s")
        print(f"   Minimum:            {stats['min_response_time']:.3f}s")
        print(f"   Maximum:            {stats['max_response_time']:.3f}s")
        print(f"   50th Percentile:    {stats['p50_response_time']:.3f}s")
        print(f"   95th Percentile:    {stats['p95_response_time']:.3f}s")
        print(f"   99th Percentile:    {stats['p99_response_time']:.3f}s")
        
        # Error analysis
        if stats['errors'] > 0:
            print(f"\n❌ Errors:")
            print(f"   Total Errors:       {stats['errors']}")
            print(f"   Error Rate:         {stats['error_rate']:.2f}%")
            
        # Performance assessment
        print(f"\n🎯 Performance Assessment:")
        
        # Response time assessment
        if stats['avg_response_time'] < 0.5:
            response_grade = "Excellent"
        elif stats['avg_response_time'] < 1.0:
            response_grade = "Good"
        elif stats['avg_response_time'] < 2.0:
            response_grade = "Fair"
        else:
            response_grade = "Poor"
            
        print(f"   Response Time:      {response_grade}")
        
        # Throughput assessment
        if stats['requests_per_second'] > 100:
            throughput_grade = "Excellent"
        elif stats['requests_per_second'] > 50:
            throughput_grade = "Good"
        elif stats['requests_per_second'] > 20:
            throughput_grade = "Fair"
        else:
            throughput_grade = "Poor"
            
        print(f"   Throughput:         {throughput_grade}")
        
        # Success rate assessment
        if stats['success_rate'] >= 99:
            reliability_grade = "Excellent"
        elif stats['success_rate'] >= 95:
            reliability_grade = "Good"
        elif stats['success_rate'] >= 90:
            reliability_grade = "Fair"
        else:
            reliability_grade = "Poor"
            
        print(f"   Reliability:        {reliability_grade}")
        
        # Recommendations
        print(f"\n💡 Recommendations:")
        
        if stats['avg_response_time'] > 2.0:
            print("   - Consider optimizing database queries")
            print("   - Review API endpoint performance")
            print("   - Check server resources (CPU, Memory)")
            
        if stats['success_rate'] < 95:
            print("   - Investigate error patterns")
            print("   - Review error handling")
            print("   - Consider rate limiting adjustments")
            
        if stats['requests_per_second'] < 20:
            print("   - Consider scaling server resources")
            print("   - Review connection pooling")
            print("   - Optimize application code")
            
        # Overall grade
        grades = [response_grade, throughput_grade, reliability_grade]
        if all(g == "Excellent" for g in grades):
            overall_grade = "🟢 Excellent"
        elif all(g in ["Excellent", "Good"] for g in grades):
            overall_grade = "🟡 Good"
        elif all(g in ["Excellent", "Good", "Fair"] for g in grades):
            overall_grade = "🟠 Fair"
        else:
            overall_grade = "🔴 Poor"
            
        print(f"\n🏆 Overall Performance: {overall_grade}")
        
        return stats['success_rate'] >= 90 and stats['avg_response_time'] < 5.0

def main():
    parser = argparse.ArgumentParser(description="Advanced Load Testing Suite")
    parser.add_argument("--users", type=int, default=10, help="Number of concurrent users (default: 10)")
    parser.add_argument("--duration", type=int, default=60, help="Test duration in seconds (default: 60)")
    parser.add_argument("--ramp-up", type=int, default=10, help="Ramp-up time in seconds (default: 10)")
    
    args = parser.parse_args()
    
    print("📈 Advanced Load Testing Suite")
    print("=" * 40)
    
    runner = LoadTestRunner(args)
    
    try:
        success = runner.run_load_test()
        if success:
            test_passed = runner.generate_report()
            sys.exit(0 if test_passed else 1)
        else:
            sys.exit(1)
    except KeyboardInterrupt:
        print("\n\n⚠️  Test interrupted by user")
        runner.generate_report()
        sys.exit(1)

if __name__ == "__main__":
    main()