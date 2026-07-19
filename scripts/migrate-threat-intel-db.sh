#!/bin/bash

# Threat Intelligence Database Migration Script
# Creates unified ioc_data view and improves performance

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AEGIS_HOME="${AEGIS_HOME:-$(dirname "$SCRIPT_DIR")}"
DB_PATH="$AEGIS_HOME/configs/threat_intelligence/ioc_database.db"

echo "Starting threat intelligence database migration..."

# Check if database exists
if [ ! -f "$DB_PATH" ]; then
    echo "Error: Threat intelligence database not found at $DB_PATH"
    exit 1
fi

# Create backup
BACKUP_PATH="${DB_PATH}.backup.$(date +%Y%m%d_%H%M%S)"
echo "Creating backup: $BACKUP_PATH"
cp "$DB_PATH" "$BACKUP_PATH"

# Add missing columns to IOC tables for better API compatibility
echo "Adding missing columns to IOC tables..."
sqlite3 "$DB_PATH" <<EOF
-- Add columns using transaction to handle potential duplicates
BEGIN TRANSACTION;

-- Try to add severity columns
ALTER TABLE ioc_ips ADD COLUMN severity TEXT;
ALTER TABLE ioc_domains ADD COLUMN severity TEXT;
ALTER TABLE ioc_urls ADD COLUMN severity TEXT;
ALTER TABLE ioc_hashes ADD COLUMN severity TEXT;

-- Try to add description columns
ALTER TABLE ioc_ips ADD COLUMN description TEXT;
ALTER TABLE ioc_domains ADD COLUMN description TEXT;
ALTER TABLE ioc_urls ADD COLUMN description TEXT;
ALTER TABLE ioc_hashes ADD COLUMN description TEXT;

-- Try to add created_at columns
ALTER TABLE ioc_ips ADD COLUMN created_at DATETIME;
ALTER TABLE ioc_domains ADD COLUMN created_at DATETIME;
ALTER TABLE ioc_urls ADD COLUMN created_at DATETIME;
ALTER TABLE ioc_hashes ADD COLUMN created_at DATETIME;

-- Try to add updated_at columns
ALTER TABLE ioc_ips ADD COLUMN updated_at DATETIME;
ALTER TABLE ioc_domains ADD COLUMN updated_at DATETIME;
ALTER TABLE ioc_urls ADD COLUMN updated_at DATETIME;
ALTER TABLE ioc_hashes ADD COLUMN updated_at DATETIME;

COMMIT;

-- Update severity based on confidence
UPDATE ioc_ips SET severity = CASE
    WHEN confidence >= 90 THEN 'critical'
    WHEN confidence >= 75 THEN 'high'
    WHEN confidence >= 60 THEN 'medium'
    ELSE 'low'
END WHERE severity IS NULL;

UPDATE ioc_domains SET severity = CASE
    WHEN confidence >= 90 THEN 'critical'
    WHEN confidence >= 75 THEN 'high'
    WHEN confidence >= 60 THEN 'medium'
    ELSE 'low'
END WHERE severity IS NULL;

UPDATE ioc_urls SET severity = CASE
    WHEN confidence >= 90 THEN 'critical'
    WHEN confidence >= 75 THEN 'high'
    WHEN confidence >= 60 THEN 'medium'
    ELSE 'low'
END WHERE severity IS NULL;

UPDATE ioc_hashes SET severity = CASE
    WHEN confidence >= 90 THEN 'critical'
    WHEN confidence >= 75 THEN 'high'
    WHEN confidence >= 60 THEN 'medium'
    ELSE 'low'
END WHERE severity IS NULL;

-- Copy threat_type to description if description is null
UPDATE ioc_ips SET description = threat_type WHERE description IS NULL;
UPDATE ioc_domains SET description = threat_type WHERE description IS NULL;
UPDATE ioc_urls SET description = threat_type WHERE description IS NULL;
UPDATE ioc_hashes SET description = threat_type WHERE description IS NULL;

-- Set default values for created_at and updated_at
UPDATE ioc_ips SET created_at = first_seen WHERE created_at IS NULL;
UPDATE ioc_domains SET created_at = first_seen WHERE created_at IS NULL;
UPDATE ioc_urls SET created_at = first_seen WHERE created_at IS NULL;
UPDATE ioc_hashes SET created_at = first_seen WHERE created_at IS NULL;

UPDATE ioc_ips SET updated_at = last_seen WHERE updated_at IS NULL;
UPDATE ioc_domains SET updated_at = last_seen WHERE updated_at IS NULL;
UPDATE ioc_urls SET updated_at = last_seen WHERE updated_at IS NULL;
UPDATE ioc_hashes SET updated_at = last_seen WHERE updated_at IS NULL;
EOF

# Create unified ioc_data view for easier API access
echo "Creating unified IOC view..."
sqlite3 "$DB_PATH" <<EOF
-- Create unified view for all IOCs
CREATE VIEW IF NOT EXISTS v_ioc_data AS
SELECT 
    id,
    ip_address as ioc_value,
    'ip' as ioc_type,
    description,
    severity,
    source,
    created_at,
    updated_at,
    first_seen,
    last_seen,
    active,
    confidence,
    threat_type
FROM ioc_ips
UNION ALL
SELECT 
    id,
    domain as ioc_value,
    'domain' as ioc_type,
    description,
    severity,
    source,
    created_at,
    updated_at,
    first_seen,
    last_seen,
    active,
    confidence,
    threat_type
FROM ioc_domains
UNION ALL
SELECT 
    id,
    url as ioc_value,
    'url' as ioc_type,
    description,
    severity,
    source,
    created_at,
    updated_at,
    first_seen,
    last_seen,
    active,
    confidence,
    threat_type
FROM ioc_urls
UNION ALL
SELECT 
    id,
    file_hash as ioc_value,
    'hash' as ioc_type,
    description,
    severity,
    source,
    created_at,
    updated_at,
    first_seen,
    last_seen,
    active,
    confidence,
    threat_type
FROM ioc_hashes;
EOF

# Add performance indexes
echo "Adding performance indexes..."
sqlite3 "$DB_PATH" <<EOF
-- Create composite indexes for common queries
CREATE INDEX IF NOT EXISTS idx_ioc_ips_active_confidence ON ioc_ips(active, confidence);
CREATE INDEX IF NOT EXISTS idx_ioc_ips_first_seen ON ioc_ips(first_seen DESC);
CREATE INDEX IF NOT EXISTS idx_ioc_domains_active_confidence ON ioc_domains(active, confidence);
CREATE INDEX IF NOT EXISTS idx_ioc_domains_first_seen ON ioc_domains(first_seen DESC);
CREATE INDEX IF NOT EXISTS idx_ioc_urls_active_confidence ON ioc_urls(active, confidence);
CREATE INDEX IF NOT EXISTS idx_ioc_urls_first_seen ON ioc_urls(first_seen DESC);
CREATE INDEX IF NOT EXISTS idx_ioc_hashes_active_confidence ON ioc_hashes(active, confidence);
CREATE INDEX IF NOT EXISTS idx_ioc_hashes_first_seen ON ioc_hashes(first_seen DESC);

-- Create index for threat feeds
CREATE INDEX IF NOT EXISTS idx_threat_feeds_active_status ON threat_feeds(active, status);
CREATE INDEX IF NOT EXISTS idx_threat_feeds_last_update ON threat_feeds(last_update DESC);
EOF

# Create triggers to automatically update severity when confidence changes
echo "Creating triggers for automatic severity updates..."
sqlite3 "$DB_PATH" <<EOF
-- Trigger for ioc_ips
CREATE TRIGGER IF NOT EXISTS update_ioc_ips_severity
AFTER UPDATE OF confidence ON ioc_ips
BEGIN
    UPDATE ioc_ips SET severity = CASE 
        WHEN NEW.confidence >= 90 THEN 'critical'
        WHEN NEW.confidence >= 75 THEN 'high'
        WHEN NEW.confidence >= 60 THEN 'medium'
        ELSE 'low'
    END,
    updated_at = CURRENT_TIMESTAMP
    WHERE id = NEW.id;
END;

-- Trigger for ioc_domains
CREATE TRIGGER IF NOT EXISTS update_ioc_domains_severity
AFTER UPDATE OF confidence ON ioc_domains
BEGIN
    UPDATE ioc_domains SET severity = CASE 
        WHEN NEW.confidence >= 90 THEN 'critical'
        WHEN NEW.confidence >= 75 THEN 'high'
        WHEN NEW.confidence >= 60 THEN 'medium'
        ELSE 'low'
    END,
    updated_at = CURRENT_TIMESTAMP
    WHERE id = NEW.id;
END;

-- Trigger for ioc_urls
CREATE TRIGGER IF NOT EXISTS update_ioc_urls_severity
AFTER UPDATE OF confidence ON ioc_urls
BEGIN
    UPDATE ioc_urls SET severity = CASE 
        WHEN NEW.confidence >= 90 THEN 'critical'
        WHEN NEW.confidence >= 75 THEN 'high'
        WHEN NEW.confidence >= 60 THEN 'medium'
        ELSE 'low'
    END,
    updated_at = CURRENT_TIMESTAMP
    WHERE id = NEW.id;
END;

-- Trigger for ioc_hashes
CREATE TRIGGER IF NOT EXISTS update_ioc_hashes_severity
AFTER UPDATE OF confidence ON ioc_hashes
BEGIN
    UPDATE ioc_hashes SET severity = CASE 
        WHEN NEW.confidence >= 90 THEN 'critical'
        WHEN NEW.confidence >= 75 THEN 'high'
        WHEN NEW.confidence >= 60 THEN 'medium'
        ELSE 'low'
    END,
    updated_at = CURRENT_TIMESTAMP
    WHERE id = NEW.id;
END;
EOF

# Optimize database
echo "Optimizing database..."
sqlite3 "$DB_PATH" "VACUUM; ANALYZE;"

echo "Threat intelligence database migration completed successfully!"
echo "Backup saved at: $BACKUP_PATH"