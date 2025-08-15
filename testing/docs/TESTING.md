# Email Automation System Testing

This directory contains comprehensive testing scripts for the Email Automation system.

## Testing Scripts

### 🚀 Quick Start

```bash
# Run the full test suite (recommended)
./run_tests.sh
```

### 📝 Available Scripts

#### 1. `run_tests.sh` - Main Test Runner
- **Purpose**: Interactive test runner that guides you through testing options
- **Features**:
  - Checks dependencies
  - Runs quick health check first
  - Optionally runs full system tests
  - Handles test data cleanup

```bash
./run_tests.sh
```

#### 2. `quick_health_check.py` - Health Check
- **Purpose**: Fast health check of all services (no test data created)
- **Tests**:
  - Backend API availability
  - Frontend accessibility  
  - Docker container status
  - Service response times

```bash
python3 quick_health_check.py
```

#### 3. `system_test.py` - Full System Test
- **Purpose**: Comprehensive testing of entire system
- **Tests**:
  - All API endpoints
  - CRUD operations
  - Authentication
  - CSV upload functionality
  - Campaign operations
  - Database connectivity
  - Container status
  - Frontend page accessibility

```bash
python3 system_test.py
```

## Test Coverage

### Backend API Tests
- ✅ Authentication (`/api/auth/*`)
- ✅ Campaigns (`/api/campaigns/*`)
- ✅ Leads (`/api/leads/*`)
- ✅ Groups (`/api/groups/*`)
- ✅ Sequences (`/api/sequences/*`)
- ✅ Sending Profiles (`/api/sending-profiles/*`)
- ✅ Dashboard (`/api/dashboard`)
- ✅ Health Check (`/api/health`)

### CRUD Operations Tests  
- ✅ Create Lead
- ✅ Read Lead
- ✅ Create Group
- ✅ Create Campaign
- ✅ Complete Campaign
- ✅ Archive Campaign

### Frontend Tests
- ✅ Dashboard page (`/`)
- ✅ Campaigns page (`/campaigns`)
- ✅ Leads page (`/leads`)
- ✅ Groups page (`/groups`)
- ✅ Sequences page (`/sequences`)
- ✅ Profiles page (`/profiles`)

### Infrastructure Tests
- ✅ Database connectivity
- ✅ Docker container status
- ✅ Service health checks
- ✅ CSV upload functionality

## Requirements

### System Requirements
- Python 3.6+
- Docker (for container tests)
- Active email-automation services

### Python Dependencies
- `requests` (auto-installed by run_tests.sh)

## Test Data

### Created During Tests
The full system test creates temporary test data:
- Test leads with unique emails
- Test groups
- Test campaigns

### Automatic Cleanup
All test data is automatically cleaned up after testing completes.

## Authentication

Tests use default admin credentials:
- **Email**: `admin@example.com`
- **Password**: `admin123`

Make sure these credentials exist in your system or update the credentials in `system_test.py`.

## Expected Services

The tests expect these services to be running:

| Service | URL | Container |
|---------|-----|-----------|
| Backend API | http://localhost:8000 | email-automation-backend-1 |
| Frontend | http://localhost:3000 | email-automation-frontend-1 |
| Database | localhost:5432 | email-automation-db-1 |

## Test Results

### Quick Health Check Output
```
[HH:MM:SS] === Email Automation Quick Health Check ===

Service Status:
[HH:MM:SS] Backend API          ✅ UP (HTTP 200)
[HH:MM:SS] Frontend             ✅ UP (HTTP 200)

Docker Containers:
[HH:MM:SS]   email-automation-frontend-1   ✅ Up 5 minutes
[HH:MM:SS]   email-automation-backend-1    ✅ Up 5 minutes  
[HH:MM:SS]   email-automation-db-1         ✅ Up 5 minutes (healthy)

Summary:
[HH:MM:SS] 🎉 All services are healthy!
```

### Full System Test Output
```
============================================================
SYSTEM TEST REPORT
============================================================
Total Tests: 25
Passed: 24
Failed: 1
Success Rate: 96.0%
============================================================

FAILED TESTS:
----------------------------------------
❌ Create Campaign: Status: 400 - No sending profiles available

ALL TEST RESULTS:
----------------------------------------
✅ Backend Health Check
✅ Frontend Health Check
✅ Authentication
✅ API GET /api/campaigns/
...
```

## Troubleshooting

### Common Issues

#### Authentication Failed
- **Problem**: `Authentication failed: 401`
- **Solution**: Create admin user with default credentials:
  ```bash
  cd backend
  python3 create_user.py
  ```

#### Services Not Running
- **Problem**: `Connection refused` errors
- **Solution**: Start services:
  ```bash
  docker-compose up -d
  ```

#### Missing Dependencies
- **Problem**: `ModuleNotFoundError: No module named 'requests'`
- **Solution**: Install dependencies:
  ```bash
  pip3 install requests
  ```

### Debug Mode

For detailed debugging, check the logs:
```bash
# Backend logs
docker-compose logs backend

# Frontend logs  
docker-compose logs frontend

# Database logs
docker-compose logs db
```

## CI/CD Integration

### GitHub Actions
Add to `.github/workflows/test.yml`:
```yaml
- name: Run System Tests
  run: |
    chmod +x ./run_tests.sh
    ./run_tests.sh
```

### Manual Testing Schedule
Recommended testing frequency:
- **Quick Health Check**: Before every deployment
- **Full System Test**: Weekly or after major changes
- **Manual Testing**: Before releases

## Contributing

When adding new features:
1. Add corresponding tests to `system_test.py`
2. Update test coverage in this README
3. Ensure all tests pass before submitting PR

## Support

For testing issues:
1. Check service logs: `docker-compose logs`
2. Verify services are running: `docker-compose ps`
3. Run quick health check: `python3 quick_health_check.py`
4. Check database connectivity: Test `/api/health` endpoint