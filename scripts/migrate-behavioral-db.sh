#!/bin/bash

# Behavioral Analysis Database Migration Script
# Adds missing columns and improves indexes for better performance

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AEGIS_HOME="${AEGIS_HOME:-$(dirname "$SCRIPT_DIR")}"
DB_PATH="$AEGIS_HOME/configs/behavioral_analysis/behavioral_data.db"

echo "Starting behavioral analysis database migration..."

# Check if database exists
if [ ! -f "$DB_PATH" ]; then
    echo "Error: Behavioral analysis database not found at $DB_PATH"
    exit 1
fi

# Create backup
BACKUP_PATH="${DB_PATH}.backup.$(date +%Y%m%d_%H%M%S)"
echo "Creating backup: $BACKUP_PATH"
cp "$DB_PATH" "$BACKUP_PATH"

# Add computed columns to system_metrics table for better API compatibility
echo "Adding computed columns to system_metrics table..."
sqlite3 "$DB_PATH" <<EOF
-- Add computed columns if they don't exist (SQLite doesn't support IF NOT EXISTS for columns)
-- We'll try to add them and ignore errors if they already exist
BEGIN TRANSACTION;

-- Try to add disk_io column
ALTER TABLE system_metrics ADD COLUMN disk_io INTEGER;

-- Try to add network_io column
ALTER TABLE system_metrics ADD COLUMN network_io INTEGER;

-- Try to add process_count column
ALTER TABLE system_metrics ADD COLUMN process_count INTEGER;

-- Try to add anomaly_score column
ALTER TABLE system_metrics ADD COLUMN anomaly_score REAL;

-- Try to add threat_level column
ALTER TABLE system_metrics ADD COLUMN threat_level TEXT;

COMMIT;

-- Update existing records with computed values
UPDATE system_metrics SET
    disk_io = disk_io_reads + disk_io_writes,
    network_io = network_connections,
    process_count = active_processes
WHERE (disk_io IS NULL OR disk_io = 0)
   OR (network_io IS NULL OR network_io = 0)
   OR (process_count IS NULL OR process_count = 0);

-- Set default values for anomaly_score and threat_level
UPDATE system_metrics SET
    anomaly_score = 0,
    threat_level = 'low'
WHERE anomaly_score IS NULL OR threat_level IS NULL;
EOF

# Add performance indexes
echo "Adding performance indexes..."
sqlite3 "$DB_PATH" <<EOF
-- Create composite indexes for common queries
CREATE INDEX IF NOT EXISTS idx_system_metrics_timestamp_cpu ON system_metrics(timestamp, cpu_usage);
CREATE INDEX IF NOT EXISTS idx_system_metrics_timestamp_memory ON system_metrics(timestamp, memory_usage);
CREATE INDEX IF NOT EXISTS idx_anomaly_events_timestamp_severity ON anomaly_events(timestamp, severity);
CREATE INDEX IF NOT EXISTS idx_anomaly_events_threat_score ON anomaly_events(threat_score);
CREATE INDEX IF NOT EXISTS idx_threat_scores_overall ON threat_scores(overall_score);
CREATE INDEX IF NOT EXISTS idx_process_behavior_timestamp_cpu ON process_behavior(timestamp, cpu_percent);
CREATE INDEX IF NOT EXISTS idx_network_behavior_timestamp_remote ON network_behavior(timestamp, remote_ip);
EOF

# Create a view for easier API access
echo "Creating API-friendly views..."
sqlite3 "$DB_PATH" <<EOF
-- Create view for behavioral metrics with computed columns
CREATE VIEW IF NOT EXISTS v_behavioral_metrics AS
SELECT 
    id,
    timestamp,
    cpu_usage,
    memory_usage,
    disk_io_reads + disk_io_writes as disk_io,
    network_connections as network_io,
    active_processes as process_count,
    0 as anomaly_score,
    'low' as threat_level,
    memory_total,
    load_average
FROM system_metrics;

-- Create view for anomaly events with mapped columns
CREATE VIEW IF NOT EXISTS v_anomaly_events AS
SELECT 
    id,
    timestamp,
    anomaly_type,
    metric_name as affected_process,
    current_value,
    baseline_value,
    deviation_score,
    severity,
    threat_score as anomaly_score,
    details as resolution_notes,
    resolved
FROM anomaly_events;
EOF

# Optimize database
echo "Optimizing database..."
sqlite3 "$DB_PATH" "VACUUM; ANALYZE;"

echo "Behavioral analysis database migration completed successfully!"
echo "Backup saved at: $BACKUP_PATH"