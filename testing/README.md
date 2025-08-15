# Email Automation Testing Suite

A comprehensive testing framework for the Email Automation system with functional, performance, security, and stress testing capabilities.

## 📁 Directory Structure

```
testing/
├── README.md                           # This file
├── run_comprehensive_tests.sh          # Main test runner (START HERE)
├── scripts/                           # Test scripts
│   ├── quick_health_check.py          # Fast health check (30s)
│   ├── system_test.py                 # Basic system tests (2-3 min)
│   ├── comprehensive_system_test.py   # Advanced testing (5-10 min)
│   ├── load_test.py                   # Load testing (configurable)
│   ├── security_test.py               # Security testing (10-15 min)
│   └── run_tests.sh                   # Basic test runner
├── reports/                           # Generated test reports
│   ├── security_reports/              # Security scan reports
│   ├── performance_reports/           # Load test results
│   └── test_logs/                     # Execution logs
└── docs/                              # Documentation
    ├── COMPREHENSIVE_TESTING.md       # Detailed documentation
    └── TESTING.md                     # Basic testing guide
```

## 🚀 Quick Start

```bash
# Navigate to testing directory
cd testing

# Run the comprehensive test suite (recommended)
./run_comprehensive_tests.sh
```

## 📝 Available Test Suites

### 1. 🔍 Quick Health Check (30 seconds)
Fast verification that all services are running correctly.
```bash
python3 scripts/quick_health_check.py
```

### 2. 🧪 Basic System Tests (2-3 minutes)
Core functionality testing with basic API endpoint validation.
```bash
python3 scripts/system_test.py
```

### 3. 🔬 Comprehensive Tests (5-10 minutes)
Advanced testing including performance, security, and edge cases.
```bash
# Basic comprehensive tests
python3 scripts/comprehensive_system_test.py

# With performance tests
python3 scripts/comprehensive_system_test.py --performance

# With security tests
python3 scripts/comprehensive_system_test.py --security

# With stress tests
python3 scripts/comprehensive_system_test.py --stress

# All test types
python3 scripts/comprehensive_system_test.py --all
```

### 4. 📈 Load Testing (configurable duration)
Simulate real-world user load and measure system performance.
```bash
# Basic load test (10 users, 60 seconds)
python3 scripts/load_test.py

# Custom configuration
python3 scripts/load_test.py --users 50 --duration 300 --ramp-up 30
```

### 5. 🔒 Security Testing (10-15 minutes)
Comprehensive security vulnerability assessment.
```bash
# Basic security tests
python3 scripts/security_test.py --report-file reports/security_report.json

# Aggressive security testing (may impact performance)
python3 scripts/security_test.py --aggressive --report-file reports/security_report.json
```

## 🎯 Test Categories

### Functional Testing
- ✅ API endpoint validation
- ✅ CRUD operations
- ✅ Authentication flows
- ✅ Business logic verification
- ✅ Data validation
- ✅ Error handling

### Performance Testing
- ✅ Response time measurement
- ✅ Throughput analysis
- ✅ Concurrent user simulation
- ✅ Resource utilization
- ✅ Scalability assessment
- ✅ Bottleneck identification

### Security Testing
- ✅ SQL injection testing
- ✅ XSS vulnerability scanning
- ✅ Authentication bypass attempts
- ✅ Authorization flaws
- ✅ Input validation testing
- ✅ Information disclosure detection
- ✅ Security header analysis

### Edge Case Testing
- ✅ Boundary condition testing
- ✅ Malformed data handling
- ✅ Unicode character support
- ✅ Large dataset processing
- ✅ Error boundary testing

## 📊 Test Results and Reports

### Generated Reports
- **Security Reports**: Detailed vulnerability assessments (JSON format)
- **Performance Reports**: Load testing results with metrics
- **Test Logs**: Execution logs for debugging
- **Coverage Reports**: Test coverage analysis

### Sample Report Locations
```bash
# Security reports
reports/security_reports/scan_2025-08-15_14-30-00.json

# Performance reports  
reports/performance_reports/load_test_2025-08-15_14-30-00.json

# Test execution logs
reports/test_logs/comprehensive_test_2025-08-15_14-30-00.log
```

## ⚙️ Configuration

### Prerequisites
- Python 3.6+
- Docker and Docker Compose
- Email automation services running
- 2GB+ available RAM

### Environment Setup
```bash
# Install dependencies
pip3 install requests

# Ensure services are running
docker-compose up -d

# Verify services
docker-compose ps
```

### Authentication Setup
Tests use default admin credentials:
- **Email**: `admin@example.com`
- **Password**: `admin123`

If these don't exist, create them:
```bash
cd ../backend
python3 create_user.py --email admin@example.com --password admin123 --admin
```

## 🔧 Customization

### Performance Thresholds
Edit test scripts to adjust performance criteria:
```python
# Response time thresholds
FAST_THRESHOLD = 0.5      # 500ms
ACCEPTABLE_THRESHOLD = 2.0 # 2 seconds

# Load test defaults
DEFAULT_USERS = 10
DEFAULT_DURATION = 60
DEFAULT_RAMP_UP = 10
```

### Security Test Aggressiveness
Control security test intensity:
```bash
# Conservative testing
python3 scripts/security_test.py

# Aggressive testing (may impact performance)
python3 scripts/security_test.py --aggressive
```

## 🚨 Troubleshooting

### Common Issues

#### Services Not Running
```bash
# Check service status
cd ..
docker-compose ps

# Start services
docker-compose up -d

# View logs
docker-compose logs backend frontend db
```

#### Authentication Failures
```bash
# Test login endpoint
curl -X POST http://localhost:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@example.com","password":"admin123"}'

# Create admin user if needed
cd ../backend
python3 create_user.py
```

#### Permission Issues
```bash
# Make scripts executable
chmod +x *.sh scripts/*.py

# Install dependencies
pip3 install requests
```

### Debug Mode
```bash
# Run with verbose output
export DEBUG=1
python3 scripts/comprehensive_system_test.py --all

# Save detailed logs
python3 scripts/load_test.py --users 5 --duration 30 > reports/debug.log 2>&1
```

## 📈 Performance Benchmarks

### Response Time Targets
- **Excellent**: < 500ms
- **Good**: < 1 second
- **Acceptable**: < 2 seconds
- **Poor**: > 2 seconds

### Throughput Targets
- **Excellent**: > 100 requests/second
- **Good**: > 50 requests/second
- **Acceptable**: > 20 requests/second
- **Poor**: < 20 requests/second

### Success Rate Targets
- **Excellent**: > 99%
- **Good**: > 95%
- **Acceptable**: > 90%
- **Poor**: < 90%

## 🔒 Security Standards

### Vulnerability Severity Levels
- **CRITICAL**: Immediate system compromise possible
- **HIGH**: Significant security risk (fix within 24-48 hours)
- **MEDIUM**: Moderate risk (fix within 1 week)
- **LOW**: Minor risk (fix in next release)

### Security Test Coverage
- ✅ OWASP Top 10 vulnerabilities
- ✅ Input validation and sanitization
- ✅ Authentication and session management
- ✅ Access control and authorization
- ✅ Data protection and encryption
- ✅ Error handling and logging
- ✅ Security configuration

## 🏆 Best Practices

### Regular Testing Schedule
- **Daily**: Quick health checks
- **Weekly**: Comprehensive system tests
- **Monthly**: Full security assessment
- **Before releases**: Complete test suite

### CI/CD Integration
```yaml
# Example GitHub Action
- name: Run Health Check
  run: cd testing && python3 scripts/quick_health_check.py

- name: Run System Tests
  run: cd testing && python3 scripts/system_test.py

- name: Security Scan
  run: cd testing && python3 scripts/security_test.py --report-file reports/security.json
```

### Test Data Management
- ✅ All test data is automatically cleaned up
- ✅ Tests use unique identifiers to prevent conflicts
- ✅ No impact on production data
- ✅ Isolated test environments

## 📚 Additional Resources

- [`docs/COMPREHENSIVE_TESTING.md`](docs/COMPREHENSIVE_TESTING.md) - Detailed testing guide
- [`docs/TESTING.md`](docs/TESTING.md) - Basic testing documentation

## 🎯 Success Criteria

A successful test run should achieve:
- ✅ All critical services healthy
- ✅ < 1 second average response time
- ✅ > 95% success rate under load
- ✅ No critical or high security vulnerabilities
- ✅ All functional tests passing

---

**Ready to test?** Run `./run_comprehensive_tests.sh` to get started! 🚀