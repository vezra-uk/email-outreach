#!/usr/bin/env python3
"""
Quick Health Check Script
========================

Performs a rapid health check of all services without creating test data.

Usage: python3 quick_health_check.py
"""

import requests
import subprocess
import sys
from datetime import datetime

def log(message, level="INFO"):
    timestamp = datetime.now().strftime("%H:%M:%S")
    print(f"[{timestamp}] {message}")

def check_service(name, url, timeout=5):
    try:
        response = requests.get(url, timeout=timeout)
        status = "✅ UP" if response.status_code < 500 else "⚠️  DEGRADED"
        log(f"{name:20} {status} (HTTP {response.status_code})")
        return response.status_code < 500
    except requests.exceptions.ConnectionError:
        log(f"{name:20} ❌ DOWN (Connection refused)")
        return False
    except requests.exceptions.Timeout:
        log(f"{name:20} ❌ TIMEOUT")
        return False
    except Exception as e:
        log(f"{name:20} ❌ ERROR ({str(e)})")
        return False

def check_docker_containers():
    log("Docker Containers:")
    try:
        result = subprocess.run(
            ["docker", "ps", "--filter", "name=email-automation", "--format", "{{.Names}}\t{{.Status}}"],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode == 0:
            lines = result.stdout.strip().split('\n')
            containers_found = False
            for line in lines:
                if line.strip() and 'email-automation' in line:
                    containers_found = True
                    parts = line.split('\t')
                    name = parts[0] if len(parts) > 0 else "Unknown"
                    status = parts[1] if len(parts) > 1 else "Unknown"
                    
                    if 'Up' in status:
                        log(f"  {name:30} ✅ {status}")
                    else:
                        log(f"  {name:30} ❌ {status}")
            
            if not containers_found:
                log("  ⚠️  No email-automation containers found")
        else:
            log("  ❌ Could not check Docker status")
            
    except Exception as e:
        log(f"  ❌ Docker check failed: {str(e)}")

def main():
    log("=== Email Automation Quick Health Check ===")
    
    # Check services
    log("\nService Status:")
    backend_ok = check_service("Backend API", "http://localhost:8000/api/health")
    frontend_ok = check_service("Frontend", "http://localhost:3000")
    
    # Check Docker containers
    log("")
    check_docker_containers()
    
    # Summary
    log(f"\nSummary:")
    if backend_ok and frontend_ok:
        log("🎉 All services are healthy!")
        return True
    else:
        log("⚠️  Some services have issues")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)