#!/bin/bash

# Incident Management Database Migration Script
# Adds missing columns and improves performance

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AEGIS_HOME="${AEGIS_HOME:-$(dirname "$SCRIPT_DIR")}"
DB_PATH="$AEGIS_HOME/configs/incident_response/incidents.db"

echo "Starting incident management database migration..."

# Check if database exists
if [ ! -f "$DB_PATH" ]; then
    echo "Error: Incident management database not found at $DB_PATH"
    exit 1
fi

# Create backup
BACKUP_PATH="${DB_PATH}.backup.$(date +%Y%m%d_%H%M%S)"
echo "Creating backup: $BACKUP_PATH"
cp "$DB_PATH" "$BACKUP_PATH"

# Add missing columns to incidents table for better API compatibility
echo "Adding missing columns to incidents table..."
sqlite3 "$DB_PATH" <<EOF
-- Add columns using transaction to handle potential duplicates
BEGIN TRANSACTION;

-- Try to add title column
ALTER TABLE incidents ADD COLUMN title TEXT;

-- Try to add source column
ALTER TABLE incidents ADD COLUMN source TEXT;

-- Try to add assigned_to column
ALTER TABLE incidents ADD COLUMN assigned_to TEXT;

-- Try to add updated_at column
ALTER TABLE incidents ADD COLUMN updated_at DATETIME;

-- Try to add tags column
ALTER TABLE incidents ADD COLUMN tags TEXT;

COMMIT;

-- Update title based on incident_type and incident_details if title is null
UPDATE incidents SET title = incident_type || ' - ' || substr(incident_details, 1, 50) || '...'
WHERE title IS NULL OR title = '';

-- Update source to default value if null
UPDATE incidents SET source = 'system' WHERE source IS NULL;

-- Update updated_at to match timestamp for existing records
UPDATE incidents SET updated_at = timestamp WHERE updated_at IS NULL;

-- Update tags to default value if null
UPDATE incidents SET tags = '[]' WHERE tags IS NULL;
EOF

# Fix foreign key constraint in incident_updates table
echo "Fixing foreign key constraint in incident_updates table..."
sqlite3 "$DB_PATH" <<EOF
-- Drop and recreate incident_updates table with correct foreign key
DROP TABLE IF EXISTS incident_updates_new;

CREATE TABLE incident_updates_new (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    incident_id TEXT NOT NULL,
    update_text TEXT NOT NULL,
    update_type TEXT NOT NULL,
    created_by TEXT,
    created_at TEXT NOT NULL,
    FOREIGN KEY (incident_id) REFERENCES incidents (incident_id)
);

-- Copy data from old table
INSERT INTO incident_updates_new 
SELECT id, incident_id, update_text, update_type, created_by, created_at 
FROM incident_updates;

-- Drop old table and rename new one
DROP TABLE incident_updates;
ALTER TABLE incident_updates_new RENAME TO incident_updates;
EOF

# Add performance indexes
echo "Adding performance indexes..."
sqlite3 "$DB_PATH" <<EOF
-- Create composite indexes for common queries
CREATE INDEX IF NOT EXISTS idx_incidents_status_timestamp ON incidents(status, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_incidents_severity_timestamp ON incidents(severity, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_incidents_type_timestamp ON incidents(incident_type, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_incidents_updated_at ON incidents(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_incident_updates_incident_created ON incident_updates(incident_id, created_at DESC);

-- Create index for assigned_to if it exists
CREATE INDEX IF NOT EXISTS idx_incidents_assigned_to ON incidents(assigned_to);
EOF

# Create views for easier API access
echo "Creating API-friendly views..."
sqlite3 "$DB_PATH" <<EOF
-- Create view for incidents with mapped columns
CREATE VIEW IF NOT EXISTS v_incidents AS
SELECT 
    id,
    incident_id,
    COALESCE(title, incident_type || ' - ' || substr(incident_details, 1, 50) || '...') as title,
    incident_type,
    incident_details as description,
    severity,
    status,
    COALESCE(source, 'system') as source,
    timestamp as created_at,
    COALESCE(updated_at, timestamp) as updated_at,
    resolved_timestamp as resolved_at,
    assigned_to,
    COALESCE(tags, '[]') as tags,
    actions_taken,
    evidence_path,
    false_positive,
    rollback_available,
    rollback_data
FROM incidents;

-- Create view for incident updates with proper mapping
CREATE VIEW IF NOT EXISTS v_incident_updates AS
SELECT 
    u.id,
    u.incident_id,
    u.update_text,
    u.update_type,
    u.created_by,
    u.created_at,
    i.incident_type,
    i.severity,
    i.status
FROM incident_updates u
JOIN incidents i ON u.incident_id = i.incident_id
ORDER BY u.created_at DESC;
EOF

# Create triggers for automatic timestamp updates
echo "Creating triggers for automatic updates..."
sqlite3 "$DB_PATH" <<EOF
-- Trigger to update updated_at when incident is modified
CREATE TRIGGER IF NOT EXISTS update_incident_timestamp
AFTER UPDATE ON incidents
BEGIN
    UPDATE incidents SET updated_at = CURRENT_TIMESTAMP 
    WHERE id = NEW.id AND (
        OLD.incident_type != NEW.incident_type OR
        OLD.incident_details != NEW.incident_details OR
        OLD.severity != NEW.severity OR
        OLD.status != NEW.status OR
        OLD.assigned_to != NEW.assigned_to OR
        OLD.actions_taken != NEW.actions_taken
    );
END;

-- Trigger to update title when incident_type or incident_details change
CREATE TRIGGER IF NOT EXISTS update_incident_title
AFTER UPDATE OF incident_type, incident_details ON incidents
BEGIN
    UPDATE incidents SET 
        title = NEW.incident_type || ' - ' || substr(NEW.incident_details, 1, 50) || '...'
    WHERE id = NEW.id AND (
        OLD.incident_type != NEW.incident_type OR
        OLD.incident_details != NEW.incident_details
    );
END;

-- Trigger to update parent incident's updated_at when update is added
CREATE TRIGGER IF NOT EXISTS update_incident_on_update
AFTER INSERT ON incident_updates
BEGIN
    UPDATE incidents SET updated_at = NEW.created_at 
    WHERE incident_id = NEW.incident_id;
END;
EOF

# Optimize database
echo "Optimizing database..."
sqlite3 "$DB_PATH" "VACUUM; ANALYZE;"

echo "Incident management database migration completed successfully!"
echo "Backup saved at: $BACKUP_PATH"