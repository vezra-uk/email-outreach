#!/bin/bash

# Database backup script for PostgreSQL in Docker
# Creates a timestamped backup of the email_automation database

# Set script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$SCRIPT_DIR/database_backups"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Generate timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/email_automation_backup_$TIMESTAMP.sql"

echo "Starting database backup..."
echo "Backup file: $BACKUP_FILE"

# Check if docker-compose is running
if ! docker-compose ps | grep -q "db.*Up"; then
    echo "Error: Database container is not running"
    echo "Please start the services with: docker-compose up -d"
    exit 1
fi

# Create the backup
if docker-compose exec -T db pg_dump -U user -d email_automation > "$BACKUP_FILE"; then
    echo "✅ Backup completed successfully!"
    echo "Backup size: $(du -h "$BACKUP_FILE" | cut -f1)"
    echo "Backup location: $BACKUP_FILE"
    
    # List recent backups
    echo ""
    echo "Recent backups:"
    ls -lht "$BACKUP_DIR"/*.sql 2>/dev/null | head -5 || echo "No previous backups found"
else
    echo "❌ Backup failed!"
    # Remove failed backup file if it exists
    [ -f "$BACKUP_FILE" ] && rm "$BACKUP_FILE"
    exit 1
fi

# Optional: Keep only last 10 backups
BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/*.sql 2>/dev/null | wc -l)
if [ "$BACKUP_COUNT" -gt 10 ]; then
    echo "Cleaning up old backups (keeping last 10)..."
    ls -t "$BACKUP_DIR"/*.sql | tail -n +11 | xargs rm -f
fi

echo "Backup process completed!"