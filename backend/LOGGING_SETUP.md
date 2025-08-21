# Comprehensive Logging Setup

This document describes the in-depth logging implementation added to the email automation backend.

## Overview

The logging system provides comprehensive tracking of all backend operations including:
- API requests and responses
- Database operations
- Email processing
- Authentication events
- Error tracking and debugging
- Performance monitoring

## Components

### 1. Logger Configuration (`logger_config.py`)
- **Primary Logger**: Configured with rotating file handlers
- **Console Output**: Real-time logging to stdout
- **Error-Specific Logging**: Separate error log file
- **Structured Logging**: JSON-formatted logs with contextual data
- **Log Rotation**: Automatic rotation at 10MB with 5 backup files

### 2. Middleware (`middleware.py`)
- **RequestLoggingMiddleware**: Logs all HTTP requests and responses with timing
- **DatabaseLoggingMiddleware**: Tracks database operation performance
- **Request Tracing**: Unique request IDs for tracking requests across the system

### 3. Enhanced Service Logging
All major services now include comprehensive logging:
- **Email Service**: OpenAI API calls, Gmail operations, email generation
- **Authentication**: Login attempts, token generation, failures
- **Scheduler**: Batch processing, daily limits, email sending
- **Tracking**: Email opens, link clicks, signal processing

## Log Levels

- **DEBUG**: Detailed debugging information (query details, internal state)
- **INFO**: General operational information (successful operations, status)
- **WARNING**: Important events that should be monitored (rate limits, fallbacks)
- **ERROR**: Error conditions that need attention (failures, exceptions)

## Log Files

### Location: `backend/logs/`

1. **`app.log`**: Main application log
   - All log levels (INFO and above by default)
   - Includes timestamps, module names, function names
   - Rotates at 10MB, keeps 5 backups

2. **`errors.log`**: Error-specific log
   - ERROR level and above only
   - Full stack traces for exceptions
   - Critical for debugging issues

## Configuration

### Environment Variables

- `LOG_LEVEL`: Set logging level (DEBUG, INFO, WARNING, ERROR)
  - Default: INFO
  - Example: `export LOG_LEVEL=DEBUG`

### Log Format

```
YYYY-MM-DD HH:MM:SS | LEVEL | module:line | function | message
```

### Structured Data

All log entries include contextual information:
```python
logger.info("User login", extra={
    "user_id": 123,
    "email": "user@example.com",
    "ip_address": "192.168.1.1",
    "success": True
})
```

## Usage Examples

### Basic Logging
```python
from logger_config import get_logger

logger = get_logger(__name__)

logger.info("Operation completed successfully")
logger.error("Failed to process request", exc_info=True)
```

### Structured Logging
```python
logger.info("Email sent", extra={
    "recipient": "user@example.com",
    "campaign_id": 456,
    "template": "welcome",
    "delivery_time_ms": 1200
})
```

### Performance Logging
```python
start_time = time.time()
# ... operation ...
duration = time.time() - start_time

logger.info("Database query completed", extra={
    "query": "SELECT * FROM campaigns",
    "duration_ms": round(duration * 1000, 2),
    "rows_returned": 150
})
```

## Key Features

### 1. Request Tracing
Every HTTP request gets a unique ID that tracks the request through all services:
```
X-Request-ID: 7a4b9c2e
```

### 2. Performance Monitoring
Automatic tracking of:
- API response times
- Database query durations
- Email processing times
- Authentication operations

### 3. Security Logging
Comprehensive logging of:
- Login attempts (successful and failed)
- API key usage
- Rate limiting events
- Authentication failures

### 4. Error Tracking
Enhanced error logging with:
- Full stack traces
- Contextual information
- Error categorization
- Performance impact analysis

## Testing

Run the logging test script to verify functionality:
```bash
cd backend
source venv/bin/activate
python test_logging.py
```

This tests:
- Basic logging levels
- Structured logging
- Exception handling
- Multiple logger instances
- Performance logging

## Monitoring and Alerting

The logs can be integrated with monitoring systems:

### Log Analysis
- **ELK Stack**: Elasticsearch, Logstash, Kibana
- **Grafana**: Dashboard creation
- **Prometheus**: Metrics extraction

### Alert Conditions
Monitor for:
- High error rates
- Slow response times
- Authentication failures
- Database connection issues
- Email delivery failures

## Best Practices

1. **Use appropriate log levels**
   - DEBUG: Development debugging only
   - INFO: Normal operations
   - WARNING: Important events
   - ERROR: Failures requiring attention

2. **Include contextual data**
   - Always include user_id, request_id when available
   - Add operation-specific metadata
   - Include timing information for performance tracking

3. **Avoid logging sensitive data**
   - Never log passwords or tokens
   - Truncate long user inputs
   - Mask email addresses if needed for privacy

4. **Use structured logging**
   - Consistent field names
   - Machine-readable format
   - Easy to query and analyze

## Troubleshooting

### Common Issues

1. **Logs not appearing**: Check LOG_LEVEL environment variable
2. **Permission errors**: Ensure logs/ directory is writable
3. **Disk space**: Log rotation should prevent this, but monitor disk usage
4. **Performance impact**: High DEBUG logging can slow the application

### Log Rotation Issues
If logs aren't rotating:
```bash
# Check permissions
ls -la logs/
# Verify disk space
df -h
```

## Security Considerations

- Log files contain operational data - secure appropriately
- Regular log rotation prevents disk space issues
- Consider encrypting logs in production
- Implement log aggregation for distributed deployments
- Monitor log access and modifications