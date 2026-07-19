#!/bin/bash
# Database Connection Manager for Aegis Security Suite
# Provides connection pooling and resource management for SQLite databases

source "$(dirname "$0")/common-functions.sh"

# Get security suite home directory
SCRIPT_DIR="$(dirname "$0")"
AEGIS_HOME="$(dirname "$SCRIPT_DIR")"

# Database connection configuration
MAX_CONNECTIONS=5
CONNECTION_TIMEOUT=30
QUERY_TIMEOUT=10
CLEANUP_INTERVAL=100
MAX_DB_SIZE_MB=500  # Maximum database size before forced cleanup

# Database paths
BEHAVIORAL_DB="$AEGIS_HOME/configs/behavioral_analysis/behavioral_data.db"
THREAT_DB="$AEGIS_HOME/configs/threat_intelligence/ioc_database.db"
INCIDENT_DB="$AEGIS_HOME/configs/incident_response/incidents.db"
AUTH_DB="$AEGIS_HOME/web-dashboard/auth.db"

# Connection tracking
declare -A DB_CONNECTIONS
declare -A DB_LAST_USED
declare -A DB_QUERY_COUNT

# Initialize connection manager
init_db_connection_manager() {
    log_info "Initializing database connection manager..."
    
    # Create connection tracking directory
    mkdir -p "$AEGIS_HOME/.db_connections"
    
    # Set database pragmas for optimization
    setup_database_optimizations
    
    log_info "Database connection manager initialized"
}

# Setup database optimizations
setup_database_optimizations() {
    local databases=("$BEHAVIORAL_DB" "$THREAT_DB" "$INCIDENT_DB" "$AUTH_DB")
    
    for db in "${databases[@]}"; do
        if [ -f "$db" ]; then
            # Apply performance optimizations
            sqlite3 "$db" << EOF 2>/dev/null
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA cache_size = 10000;
PRAGMA temp_store = MEMORY;
PRAGMA mmap_size = 268435456;  -- 256MB
PRAGMA optimize;
EOF
            log_debug "Applied optimizations to database: $db"
        fi
    done
}

# Get database connection with pooling
get_db_connection() {
    local db_path="$1"
    local connection_id="$2"
    
    # Check if database exists
    if [ ! -f "$db_path" ]; then
        log_error "Database not found: $db_path"
        return 1
    fi
    
    # Check database size
    local db_size_mb=$(du -m "$db_path" 2>/dev/null | cut -f1)
    if [ "$db_size_mb" -gt "$MAX_DB_SIZE_MB" ]; then
        log_warning "Database size exceeded limit: ${db_size_mb}MB (limit: ${MAX_DB_SIZE_MB}MB)"
        cleanup_database "$db_path"
    fi
    
    # Check connection count
    local current_connections=${DB_CONNECTIONS[$db_path]:-0}
    if [ "$current_connections" -ge "$MAX_CONNECTIONS" ]; then
        log_warning "Maximum connections reached for database: $db_path"
        cleanup_old_connections "$db_path"
    fi
    
    # Create connection
    local connection_file="$AEGIS_HOME/.db_connections/conn_${connection_id}_$(date +%s).tmp"
    
    # Test connection
    if sqlite3 "$db_path" "SELECT 1;" > /dev/null 2>&1; then
        # Track connection
        DB_CONNECTIONS[$db_path]=$((current_connections + 1))
        DB_LAST_USED[$db_path]=$(date +%s)
        DB_QUERY_COUNT[$db_path]=$((DB_QUERY_COUNT[$db_path]:-0 + 1))
        
        echo "$connection_file"
        return 0
    else
        log_error "Failed to connect to database: $db_path"
        return 1
    fi
}

# Execute database query with timeout and error handling
execute_db_query() {
    local db_path="$1"
    local query="$2"
    local timeout="${3:-$QUERY_TIMEOUT}"
    
    # Validate query
    if [ -z "$query" ]; then
        log_error "Empty query provided"
        return 1
    fi
    
    # Check for dangerous operations
    if [[ "$query" =~ ^(DROP|DELETE|UPDATE|INSERT).*WHERE.*1=1 ]]; then
        log_error "Potentially dangerous query detected: $query"
        return 1
    fi
    
    # Execute query with timeout
    local result
    if command -v timeout >/dev/null 2>&1; then
        result=$(timeout "$timeout" sqlite3 "$db_path" "$query" 2>/dev/null)
        local exit_code=$?
    else
        result=$(sqlite3 "$db_path" "$query" 2>/dev/null)
        local exit_code=$?
    fi
    
    if [ $exit_code -eq 0 ]; then
        echo "$result"
        return 0
    else
        log_error "Database query failed (exit code: $exit_code): $query"
        
        # Check if database is locked
        if [ $exit_code -eq 5 ]; then
            log_warning "Database locked, attempting cleanup: $db_path"
            cleanup_database_locks "$db_path"
        fi
        
        return 1
    fi
}

# Execute multiple database queries in transaction
execute_db_transaction() {
    local db_path="$1"
    local queries_file="$2"
    
    if [ ! -f "$queries_file" ]; then
        log_error "Queries file not found: $queries_file"
        return 1
    fi
    
    # Begin transaction
    execute_db_query "$db_path" "BEGIN TRANSACTION;" || return 1
    
    # Execute queries
    while IFS= read -r query; do
        if [ -n "$query" ] && [[ ! "$query" =~ ^-- ]]; then
            if ! execute_db_query "$db_path" "$query"; then
                execute_db_query "$db_path" "ROLLBACK;"
                return 1
            fi
        fi
    done < "$queries_file"
    
    # Commit transaction
    execute_db_query "$db_path" "COMMIT;" || return 1
    
    return 0
}

# Cleanup old connections
cleanup_old_connections() {
    local db_path="$1"
    local current_time=$(date +%s)
    local max_age=300  # 5 minutes
    
    # Find and remove old connection files
    find "$AEGIS_HOME/.db_connections" -name "conn_*" -type f -mmin +5 -delete 2>/dev/null || true
    
    # Update connection count
    local active_connections=$(find "$AEGIS_HOME/.db_connections" -name "conn_*" -type f -mmin -5 | wc -l)
    DB_CONNECTIONS[$db_path]=$active_connections
}

# Cleanup database locks
cleanup_database_locks() {
    local db_path="$1"
    local db_dir=$(dirname "$db_path")
    local db_name=$(basename "$db_path" .db)
    
    # Remove lock files
    rm -f "$db_dir/$db_name.db-wal" "$db_dir/$db_name.db-shm" 2>/dev/null || true
    
    # Force unlock
    sqlite3 "$db_path" "PRAGMA wal_checkpoint(TRUNCATE);" 2>/dev/null || true
    
    log_info "Database locks cleaned for: $db_path"
}

# Cleanup database
cleanup_database() {
    local db_path="$1"
    
    log_info "Performing database cleanup: $db_path"
    
    # Get database size before cleanup
    local size_before=$(du -m "$db_path" 2>/dev/null | cut -f1)
    
    # Perform cleanup operations
    sqlite3 "$db_path" << EOF 2>/dev/null
-- Delete old data based on database type
DELETE FROM system_metrics WHERE timestamp < datetime('now', '-7 days');
DELETE FROM process_behavior WHERE timestamp < datetime('now', '-7 days');
DELETE FROM network_behavior WHERE timestamp < datetime('now', '-7 days');
DELETE FROM file_access_patterns WHERE timestamp < datetime('now', '-7 days');
DELETE FROM anomaly_events WHERE timestamp < datetime('now', '-30 days') AND resolved = 1;
DELETE FROM threat_scores WHERE timestamp < datetime('now', '-7 days');

-- Optimize database
VACUUM;
ANALYZE;
PRAGMA optimize;
EOF
    
    # Get database size after cleanup
    local size_after=$(du -m "$db_path" 2>/dev/null | cut -f1)
    local space_saved=$((size_before - size_after))
    
    log_info "Database cleanup completed: $db_path (saved ${space_saved}MB)"
}

# Get database statistics
get_db_stats() {
    local db_path="$1"
    
    if [ ! -f "$db_path" ]; then
        echo "Database not found: $db_path"
        return 1
    fi
    
    local size_mb=$(du -m "$db_path" 2>/dev/null | cut -f1)
    local page_count=$(sqlite3 "$db_path" "PRAGMA page_count;" 2>/dev/null || echo "0")
    local page_size=$(sqlite3 "$db_path" "PRAGMA page_size;" 2>/dev/null || echo "0")
    local cache_size=$(sqlite3 "$db_path" "PRAGMA cache_size;" 2>/dev/null || echo "0")
    
    echo "Database Statistics for: $db_path"
    echo "Size: ${size_mb}MB"
    echo "Pages: $page_count"
    echo "Page Size: $page_size bytes"
    echo "Cache Size: $cache_size pages"
    echo "Active Connections: ${DB_CONNECTIONS[$db_path]:-0}"
    echo "Query Count: ${DB_QUERY_COUNT[$db_path]:-0}"
    echo "Last Used: ${DB_LAST_USED[$db_path]:-Never}"
}

# Check database integrity
check_db_integrity() {
    local db_path="$1"
    
    if [ ! -f "$db_path" ]; then
        echo "Database not found: $db_path"
        return 1
    fi
    
    log_info "Checking database integrity: $db_path"
    
    local integrity_check=$(sqlite3 "$db_path" "PRAGMA integrity_check;" 2>/dev/null)
    
    if [ "$integrity_check" = "ok" ]; then
        log_info "Database integrity check passed: $db_path"
        return 0
    else
        log_error "Database integrity check failed: $db_path"
        log_error "Integrity check result: $integrity_check"
        return 1
    fi
}

# Optimize database
optimize_database() {
    local db_path="$1"
    
    if [ ! -f "$db_path" ]; then
        log_error "Database not found: $db_path"
        return 1
    fi
    
    log_info "Optimizing database: $db_path"
    
    sqlite3 "$db_path" << EOF 2>/dev/null
-- Analyze query patterns
ANALYZE;

-- Rebuild indexes
REINDEX;

-- Optimize storage
VACUUM;

-- Update statistics
PRAGMA optimize;

-- Set performance pragmas
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA cache_size = 10000;
PRAGMA temp_store = MEMORY;
PRAGMA mmap_size = 268435456;
EOF
    
    log_info "Database optimization completed: $db_path"
}

# Backup database
backup_database() {
    local db_path="$1"
    local backup_dir="${2:-$AEGIS_HOME/backups}"
    
    if [ ! -f "$db_path" ]; then
        log_error "Database not found: $db_path"
        return 1
    fi
    
    # Create backup directory
    mkdir -p "$backup_dir"
    
    local db_name=$(basename "$db_path" .db)
    local backup_file="$backup_dir/${db_name}_backup_$(date +%Y%m%d_%H%M%S).db"
    
    # Create backup
    sqlite3 "$db_path" ".backup $backup_file" 2>/dev/null
    
    if [ $? -eq 0 ] && [ -f "$backup_file" ]; then
        log_info "Database backup created: $backup_file"
        echo "$backup_file"
        return 0
    else
        log_error "Failed to create database backup: $db_path"
        return 1
    fi
}

# Restore database from backup
restore_database() {
    local backup_file="$1"
    local target_db="$2"
    
    if [ ! -f "$backup_file" ]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi
    
    # Create target directory
    mkdir -p "$(dirname "$target_db")"
    
    # Verify backup integrity
    local integrity_check=$(sqlite3 "$backup_file" "PRAGMA integrity_check;" 2>/dev/null)
    if [ "$integrity_check" != "ok" ]; then
        log_error "Backup file integrity check failed: $backup_file"
        return 1
    fi
    
    # Restore database
    cp "$backup_file" "$target_db"
    
    if [ $? -eq 0 ]; then
        log_info "Database restored from backup: $backup_file -> $target_db"
        return 0
    else
        log_error "Failed to restore database from backup: $backup_file"
        return 1
    fi
}

# Monitor database performance
monitor_db_performance() {
    local db_path="$1"
    local duration="${2:-60}"  # Default 1 minute
    
    log_info "Monitoring database performance: $db_path (duration: ${duration}s)"
    
    local start_time=$(date +%s)
    local query_count=0
    local total_time=0
    
    while [ $(($(date +%s) - start_time)) -lt $duration ]; do
        local query_start=$(date +%s.%N)
        
        # Execute test query
        sqlite3 "$db_path" "SELECT COUNT(*) FROM sqlite_master;" > /dev/null 2>&1
        
        local query_end=$(date +%s.%N)
        local query_time=$(echo "$query_end - $query_start" | bc -l 2>/dev/null || echo "0")
        
        total_time=$(echo "$total_time + $query_time" | bc -l 2>/dev/null || echo "$total_time")
        ((query_count++))
        
        sleep 1
    done
    
    local avg_time=$(echo "scale=3; $total_time / $query_count" | bc -l 2>/dev/null || echo "0")
    
    echo "Database Performance Report for: $db_path"
    echo "Monitoring Duration: ${duration}s"
    echo "Total Queries: $query_count"
    echo "Average Query Time: ${avg_time}s"
    echo "Queries Per Second: $(echo "scale=2; $query_count / $duration" | bc -l 2>/dev/null || echo "0")"
}

# Cleanup connection manager
cleanup_connection_manager() {
    log_info "Cleaning up database connection manager..."
    
    # Remove all connection files
    rm -f "$AEGIS_HOME/.db_connections/conn_*.tmp" 2>/dev/null || true
    
    # Remove connection tracking directory
    rmdir "$AEGIS_HOME/.db_connections" 2>/dev/null || true
    
    log_info "Database connection manager cleanup completed"
}

# Export functions for use by other scripts
export -f init_db_connection_manager get_db_connection execute_db_query
export -f execute_db_transaction cleanup_old_connections cleanup_database_locks
export -f cleanup_database get_db_stats check_db_integrity optimize_database
export -f backup_database restore_database monitor_db_performance cleanup_connection_manager

# Main execution
case "${1:-init}" in
    "init")
        init_db_connection_manager
        ;;
    "stats")
        get_db_stats "$2"
        ;;
    "check")
        check_db_integrity "$2"
        ;;
    "optimize")
        optimize_database "$2"
        ;;
    "backup")
        backup_database "$2" "$3"
        ;;
    "restore")
        restore_database "$2" "$3"
        ;;
    "monitor")
        monitor_db_performance "$2" "$3"
        ;;
    "cleanup")
        cleanup_connection_manager
        ;;
    *)
        echo "Usage: $0 {init|stats|check|optimize|backup|restore|monitor|cleanup}"
        exit 1
        ;;
esac