#!/bin/bash

# Master Database Migration Script
# Runs all database migrations in sequence

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AEGIS_HOME="${AEGIS_HOME:-$(dirname "$SCRIPT_DIR")}"

echo "=========================================="
echo "Aegis Security Suite Database Migration"
echo "=========================================="
echo "Security Suite Home: $AEGIS_HOME"
echo "Timestamp: $(date)"
echo ""

# Function to run migration with error handling
run_migration() {
    local script_name="$1"
    local description="$2"
    
    echo "----------------------------------------"
    echo "Running: $description"
    echo "Script: $script_name"
    echo "----------------------------------------"
    
    if [ ! -f "$SCRIPT_DIR/$script_name" ]; then
        echo "Error: Migration script not found: $SCRIPT_DIR/$script_name"
        return 1
    fi
    
    # Make script executable
    chmod +x "$SCRIPT_DIR/$script_name"
    
    # Run migration
    if bash "$SCRIPT_DIR/$script_name"; then
        echo "✓ $description completed successfully"
        echo ""
        return 0
    else
        echo "✗ $description failed"
        echo ""
        return 1
    fi
}

# Check if running as root (required for database operations)
if [ "$EUID" -ne 0 ]; then
    echo "Warning: Not running as root. Some database operations may fail."
    echo "Consider running with sudo for full compatibility."
    echo ""
fi

# Set environment variable
export AEGIS_HOME="$AEGIS_HOME"

# Track overall success
MIGRATION_SUCCESS=true

# Run migrations in sequence
run_migration "migrate-behavioral-db.sh" "Behavioral Analysis Database Migration" || MIGRATION_SUCCESS=false
run_migration "migrate-threat-intel-db.sh" "Threat Intelligence Database Migration" || MIGRATION_SUCCESS=false
run_migration "migrate-incidents-db.sh" "Incident Management Database Migration" || MIGRATION_SUCCESS=false

# Summary
echo "=========================================="
echo "Migration Summary"
echo "=========================================="

if [ "$MIGRATION_SUCCESS" = true ]; then
    echo "✓ All database migrations completed successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Restart the web dashboard: sudo systemctl restart aegis-dashboard"
    echo "2. Test API endpoints to verify functionality"
    echo "3. Check dashboard logs for any issues"
    exit 0
else
    echo "✗ One or more migrations failed!"
    echo ""
    echo "Troubleshooting:"
    echo "1. Check the error messages above"
    echo "2. Verify database file permissions"
    echo "3. Ensure sufficient disk space"
    echo "4. Check database integrity with: sqlite3 <db_path> 'PRAGMA integrity_check;'"
    echo ""
    echo "Backup files were created before migration attempts."
    exit 1
fi