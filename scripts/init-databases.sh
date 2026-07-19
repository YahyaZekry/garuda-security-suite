#!/bin/bash
# Database Initialization Script
# Initializes all security suite databases with proper permissions

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AEGIS_HOME="$(dirname "$SCRIPT_DIR")"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Load configuration
load_config() {
    print_status "Loading security suite configuration..."
    
    if [ -f "$AEGIS_HOME/configs/security-config.conf" ]; then
        source "$AEGIS_HOME/configs/security-config.conf"
        print_success "Configuration loaded successfully"
    else
        print_error "Configuration file not found: $AEGIS_HOME/configs/security-config.conf"
        return 1
    fi
}

# Create directories with proper permissions
create_directories() {
    print_status "Creating directory structure..."
    
    # Create main directories
    mkdir -p "$AEGIS_HOME/logs"/{daily,weekly,monthly,manual}
    mkdir -p "$AEGIS_HOME/configs"/{behavioral_analysis,incident_response,threat_intelligence}
    mkdir -p "$AEGIS_HOME/evidence"
    mkdir -p "$AEGIS_HOME/quarantine"
    mkdir -p "$AEGIS_HOME/backups"
    mkdir -p "$THREAT_DB_DIR/cache"
    
    # Set proper permissions
    chmod 700 "$AEGIS_HOME/configs"
    chmod 700 "$AEGIS_HOME/evidence"
    chmod 700 "$AEGIS_HOME/quarantine"
    chmod 755 "$AEGIS_HOME/logs"
    chmod 755 "$AEGIS_HOME/backups"
    
    print_success "Directory structure created"
}

# Initialize behavioral analysis database
init_behavioral_db() {
    print_status "Initializing behavioral analysis database..."
    
    if [ ! -f "$BEHAVIORAL_DATABASE" ]; then
        # Create database schema
        sqlite3 "$BEHAVIORAL_DATABASE" << 'EOF'
-- Behavioral Analysis Database Schema
CREATE TABLE IF NOT EXISTS system_metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    cpu_usage REAL NOT NULL,
    memory_usage REAL NOT NULL,
    memory_total REAL NOT NULL,
    load_average REAL NOT NULL,
    active_processes INTEGER NOT NULL,
    network_connections INTEGER NOT NULL,
    disk_io_reads INTEGER DEFAULT 0,
    disk_io_writes INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS process_behavior (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    process_name TEXT NOT NULL,
    process_pid INTEGER NOT NULL,
    cpu_percent REAL NOT NULL,
    memory_percent REAL NOT NULL,
    memory_rss INTEGER NOT NULL,
    file_descriptors INTEGER DEFAULT 0,
    network_connections INTEGER DEFAULT 0,
    parent_pid INTEGER,
    user_name TEXT,
    command_line TEXT
);

CREATE TABLE IF NOT EXISTS network_behavior (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    local_ip TEXT NOT NULL,
    local_port INTEGER NOT NULL,
    remote_ip TEXT NOT NULL,
    remote_port INTEGER NOT NULL,
    protocol TEXT NOT NULL,
    state TEXT NOT NULL,
    process_pid INTEGER,
    process_name TEXT,
    bytes_sent INTEGER DEFAULT 0,
    bytes_received INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS file_access_patterns (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    file_path TEXT NOT NULL,
    access_type TEXT NOT NULL,
    process_pid INTEGER,
    process_name TEXT,
    user_name TEXT,
    file_size INTEGER DEFAULT 0,
    file_hash TEXT
);

CREATE TABLE IF NOT EXISTS baseline_data (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    metric_type TEXT NOT NULL,
    metric_name TEXT NOT NULL,
    baseline_value REAL NOT NULL,
    standard_deviation REAL NOT NULL,
    min_value REAL NOT NULL,
    max_value REAL NOT NULL,
    sample_count INTEGER NOT NULL,
    created_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_updated DATETIME DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT 1
);

CREATE TABLE IF NOT EXISTS anomaly_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    anomaly_type TEXT NOT NULL,
    metric_name TEXT NOT NULL,
    current_value REAL NOT NULL,
    baseline_value REAL NOT NULL,
    deviation_score REAL NOT NULL,
    severity TEXT NOT NULL,
    threat_score INTEGER NOT NULL,
    details TEXT,
    resolved BOOLEAN DEFAULT 0,
    false_positive BOOLEAN DEFAULT 0
);

CREATE TABLE IF NOT EXISTS threat_scores (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    overall_score INTEGER NOT NULL,
    cpu_anomalies INTEGER DEFAULT 0,
    memory_anomalies INTEGER DEFAULT 0,
    network_anomalies INTEGER DEFAULT 0,
    process_anomalies INTEGER DEFAULT 0,
    file_anomalies INTEGER DEFAULT 0,
    triggered_response BOOLEAN DEFAULT 0,
    response_details TEXT
);

CREATE TABLE IF NOT EXISTS behavioral_patterns (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    pattern_type TEXT NOT NULL,
    pattern_name TEXT NOT NULL,
    pattern_data TEXT NOT NULL,
    detection_count INTEGER DEFAULT 0,
    first_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
    severity TEXT DEFAULT 'medium',
    is_whitelisted BOOLEAN DEFAULT 0
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_system_metrics_timestamp ON system_metrics(timestamp);
CREATE INDEX IF NOT EXISTS idx_process_behavior_timestamp ON process_behavior(timestamp);
CREATE INDEX IF NOT EXISTS idx_process_behavior_name ON process_behavior(process_name);
CREATE INDEX IF NOT EXISTS idx_network_behavior_timestamp ON network_behavior(timestamp);
CREATE INDEX IF NOT EXISTS idx_network_behavior_remote_ip ON network_behavior(remote_ip);
CREATE INDEX IF NOT EXISTS idx_file_access_timestamp ON file_access_patterns(timestamp);
CREATE INDEX IF NOT EXISTS idx_file_access_path ON file_access_patterns(file_path);
CREATE INDEX IF NOT EXISTS idx_baseline_data_type_name ON baseline_data(metric_type, metric_name);
CREATE INDEX IF NOT EXISTS idx_anomaly_events_timestamp ON anomaly_events(timestamp);
CREATE INDEX IF NOT EXISTS idx_anomaly_events_resolved ON anomaly_events(resolved);
CREATE INDEX IF NOT EXISTS idx_threat_scores_timestamp ON threat_scores(timestamp);
CREATE INDEX IF NOT EXISTS idx_behavioral_patterns_type ON behavioral_patterns(pattern_type);
EOF
        
        print_success "Behavioral analysis database initialized"
    else
        print_warning "Behavioral analysis database already exists"
    fi
    
    # Set proper permissions
    chmod 600 "$BEHAVIORAL_DATABASE"
    chown "$CURRENT_USER:$CURRENT_USER" "$BEHAVIORAL_DATABASE"
}

# Initialize incident response database
init_incident_db() {
    print_status "Initializing incident response database..."
    
    if [ ! -f "$INCIDENT_DATABASE" ]; then
        # Create database schema
        sqlite3 "$INCIDENT_DATABASE" << 'EOF'
-- Incident Response Database Schema
CREATE TABLE IF NOT EXISTS incidents (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    incident_id TEXT UNIQUE NOT NULL,
    incident_type TEXT NOT NULL,
    incident_details TEXT NOT NULL,
    severity TEXT NOT NULL,
    status TEXT DEFAULT 'open',
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    resolved_timestamp DATETIME,
    actions_taken TEXT,
    evidence_path TEXT,
    false_positive BOOLEAN DEFAULT 0,
    rollback_available BOOLEAN DEFAULT 0,
    rollback_data TEXT
);

CREATE TABLE IF NOT EXISTS quarantine_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    incident_id TEXT NOT NULL,
    original_path TEXT NOT NULL,
    quarantine_path TEXT NOT NULL,
    file_hash TEXT NOT NULL,
    quarantine_timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    restored_timestamp DATETIME,
    restored_by TEXT,
    FOREIGN KEY (incident_id) REFERENCES incidents (incident_id)
);

CREATE TABLE IF NOT EXISTS network_blocks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    incident_id TEXT NOT NULL,
    blocked_ip TEXT NOT NULL,
    block_type TEXT NOT NULL,
    block_timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    unblocked_timestamp DATETIME,
    unblocked_by TEXT,
    rule_id TEXT,
    FOREIGN KEY (incident_id) REFERENCES incidents (incident_id)
);

CREATE TABLE IF NOT EXISTS process_isolation (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    incident_id TEXT NOT NULL,
    process_id INTEGER NOT NULL,
    process_name TEXT NOT NULL,
    isolation_timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    isolation_method TEXT NOT NULL,
    killed_timestamp DATETIME,
    killed_by TEXT,
    FOREIGN KEY (incident_id) REFERENCES incidents (incident_id)
);

CREATE TABLE IF NOT EXISTS evidence_collection (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    incident_id TEXT NOT NULL,
    evidence_type TEXT NOT NULL,
    evidence_path TEXT NOT NULL,
    collection_timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    description TEXT,
    hash_value TEXT,
    FOREIGN KEY (incident_id) REFERENCES incidents (incident_id)
);

CREATE TABLE IF NOT EXISTS incident_timeline (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    incident_id TEXT NOT NULL,
    action TEXT NOT NULL,
    details TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    automated BOOLEAN DEFAULT 1,
    FOREIGN KEY (incident_id) REFERENCES incidents (incident_id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_incidents_id ON incidents(incident_id);
CREATE INDEX IF NOT EXISTS idx_incidents_severity ON incidents(severity);
CREATE INDEX IF NOT EXISTS idx_incidents_status ON incidents(status);
CREATE INDEX IF NOT EXISTS idx_incidents_timestamp ON incidents(timestamp);
CREATE INDEX IF NOT EXISTS idx_quarantine_incident ON quarantine_log(incident_id);
CREATE INDEX IF NOT EXISTS idx_network_blocks_incident ON network_blocks(incident_id);
CREATE INDEX IF NOT EXISTS idx_process_isolation_incident ON process_isolation(incident_id);
CREATE INDEX IF NOT EXISTS idx_evidence_incident ON evidence_collection(incident_id);
CREATE INDEX IF NOT EXISTS idx_timeline_incident ON incident_timeline(incident_id);
EOF
        
        print_success "Incident response database initialized"
    else
        print_warning "Incident response database already exists"
    fi
    
    # Set proper permissions
    chmod 600 "$INCIDENT_DATABASE"
    chown "$CURRENT_USER:$CURRENT_USER" "$INCIDENT_DATABASE"
}

# Initialize threat intelligence database
init_threat_db() {
    print_status "Initializing threat intelligence database..."
    
    if [ ! -f "$IOC_DATABASE" ]; then
        # Create database schema
        sqlite3 "$IOC_DATABASE" << 'EOF'
-- Enhanced IOC Database Schema
CREATE TABLE IF NOT EXISTS ioc_ips (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ip_address TEXT UNIQUE NOT NULL,
    source TEXT NOT NULL,
    threat_type TEXT NOT NULL,
    confidence INTEGER DEFAULT 50,
    first_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
    active BOOLEAN DEFAULT 1,
    feed_url TEXT,
    country_code TEXT,
    asn TEXT
);

CREATE TABLE IF NOT EXISTS ioc_domains (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    domain TEXT UNIQUE NOT NULL,
    source TEXT NOT NULL,
    threat_type TEXT NOT NULL,
    confidence INTEGER DEFAULT 50,
    first_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
    active BOOLEAN DEFAULT 1,
    feed_url TEXT
);

CREATE TABLE IF NOT EXISTS ioc_urls (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    url TEXT UNIQUE NOT NULL,
    source TEXT NOT NULL,
    threat_type TEXT NOT NULL,
    confidence INTEGER DEFAULT 50,
    first_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
    active BOOLEAN DEFAULT 1,
    feed_url TEXT
);

CREATE TABLE IF NOT EXISTS ioc_hashes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_hash TEXT UNIQUE NOT NULL,
    hash_type TEXT NOT NULL,
    source TEXT NOT NULL,
    threat_type TEXT NOT NULL,
    confidence INTEGER DEFAULT 50,
    first_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
    active BOOLEAN DEFAULT 1,
    feed_url TEXT
);

CREATE TABLE IF NOT EXISTS threat_feeds (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    feed_name TEXT UNIQUE NOT NULL,
    feed_url TEXT UNIQUE NOT NULL,
    feed_type TEXT NOT NULL,
    last_update DATETIME DEFAULT CURRENT_TIMESTAMP,
    update_frequency INTEGER DEFAULT 86400,
    status TEXT DEFAULT 'active',
    success_count INTEGER DEFAULT 0,
    failure_count INTEGER DEFAULT 0,
    last_success DATETIME,
    last_failure DATETIME,
    active BOOLEAN DEFAULT 1
);

CREATE TABLE IF NOT EXISTS feed_statistics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    feed_name TEXT NOT NULL,
    date DATE NOT NULL,
    items_processed INTEGER DEFAULT 0,
    new_items INTEGER DEFAULT 0,
    duplicates INTEGER DEFAULT 0,
    errors INTEGER DEFAULT 0,
    processing_time REAL DEFAULT 0
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_ioc_ips_address ON ioc_ips(ip_address);
CREATE INDEX IF NOT EXISTS idx_ioc_ips_active ON ioc_ips(active);
CREATE INDEX IF NOT EXISTS idx_ioc_domains_domain ON ioc_domains(domain);
CREATE INDEX IF NOT EXISTS idx_ioc_domains_active ON ioc_domains(active);
CREATE INDEX IF NOT EXISTS idx_ioc_urls_url ON ioc_urls(url);
CREATE INDEX IF NOT EXISTS idx_ioc_urls_active ON ioc_urls(active);
CREATE INDEX IF NOT EXISTS idx_ioc_hashes_hash ON ioc_hashes(file_hash);
CREATE INDEX IF NOT EXISTS idx_ioc_hashes_active ON ioc_hashes(active);
CREATE INDEX IF NOT EXISTS idx_threat_feeds_name ON threat_feeds(feed_name);
CREATE INDEX IF NOT EXISTS idx_feed_statistics_feed_date ON feed_statistics(feed_name, date);
EOF
        
        print_success "Threat intelligence database initialized"
    else
        print_warning "Threat intelligence database already exists"
    fi
    
    # Set proper permissions
    chmod 600 "$IOC_DATABASE"
    chown "$CURRENT_USER:$CURRENT_USER" "$IOC_DATABASE"
}

# Verify database integrity
verify_databases() {
    print_status "Verifying database integrity..."
    
    local errors=0
    
    # Check behavioral database
    if [ -f "$BEHAVIORAL_DATABASE" ]; then
        if sqlite3 "$BEHAVIORAL_DATABASE" "PRAGMA integrity_check;" | grep -q "ok"; then
            print_success "Behavioral database integrity: OK"
        else
            print_error "Behavioral database integrity: FAILED"
            ((errors++))
        fi
    else
        print_error "Behavioral database not found"
        ((errors++))
    fi
    
    # Check incident database
    if [ -f "$INCIDENT_DATABASE" ]; then
        if sqlite3 "$INCIDENT_DATABASE" "PRAGMA integrity_check;" | grep -q "ok"; then
            print_success "Incident database integrity: OK"
        else
            print_error "Incident database integrity: FAILED"
            ((errors++))
        fi
    else
        print_error "Incident database not found"
        ((errors++))
    fi
    
    # Check threat intelligence database
    if [ -f "$IOC_DATABASE" ]; then
        if sqlite3 "$IOC_DATABASE" "PRAGMA integrity_check;" | grep -q "ok"; then
            print_success "Threat intelligence database integrity: OK"
        else
            print_error "Threat intelligence database integrity: FAILED"
            ((errors++))
        fi
    else
        print_error "Threat intelligence database not found"
        ((errors++))
    fi
    
    if [ $errors -eq 0 ]; then
        print_success "All databases verified successfully"
        return 0
    else
        print_error "Database verification failed with $errors errors"
        return 1
    fi
}

# Main execution
main() {
    local action="${1:-init}"
    
    case "$action" in
        "init")
            load_config
            create_directories
            init_behavioral_db
            init_incident_db
            init_threat_db
            verify_databases
            ;;
        "verify")
            load_config
            verify_databases
            ;;
        "repair")
            load_config
            print_status "Attempting to repair databases..."
            
            # Backup existing databases
            for db in "$BEHAVIORAL_DATABASE" "$INCIDENT_DATABASE" "$IOC_DATABASE"; do
                if [ -f "$db" ]; then
                    cp "$db" "${db}.backup.$(date +%s)"
                    print_status "Backed up: $db"
                fi
            done
            
            # Reinitialize databases
            init_behavioral_db
            init_incident_db
            init_threat_db
            verify_databases
            ;;
        *)
            echo "Usage: $0 {init|verify|repair}"
            echo "  init   - Initialize all databases (default)"
            echo "  verify - Verify database integrity"
            echo "  repair - Backup and reinitialize databases"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"