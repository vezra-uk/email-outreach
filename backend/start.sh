#!/bin/bash

# Create log directories
mkdir -p /var/log/supervisor

# Start supervisor which will manage both API and scheduler
supervisord -c /app/supervisord.conf