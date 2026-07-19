#!/bin/bash
# Optimized Behavioral Analysis Engine with Memory Management
# Provides behavioral analysis functions with resource limits

source "$(dirname "$0")/common-functions.sh"

# Get security suite home directory
SCRIPT_DIR="$(dirname "$0")"
AEGIS_HOME="$(dirname "$SCRIPT_DIR")"

# Load configuration
if [ -f "$AEGIS_HOME/configs/security-config.conf" ]; then
    source "$AEGIS_HOME/configs/security-config.conf"
fi

# Optimized behavioral analysis configuration
BEHAVIORAL_DATABASE="${BEHAVIORAL_DATABASE:-$AEGIS_HOME/configs/behavioral_analysis/behavioral_data.db}"
BEHAVIORAL_LEARNING_PERIOD="${BEHAVIORAL_LEARNING_PERIOD:-7}"
BEHAVIORAL_MONITORING_INTERVAL="${BEHAVIORAL_MONITORING_INTERVAL:-30}"
BEHAVIORAL_THREAT_SCORE_THRESHOLD="${BEHAVIORAL_THREAT_SCORE_THRESHOLD:-70}"
MAX_PROCESSES_TO_ANALYZE=50  # Limit process analysis
MAX_NETWORK_CONNECTIONS=100  # Limit network connection analysis
MAX_FILE_ACCESSES=200  # Limit file access pattern analysis
MEMORY_CLEANUP_INTERVAL=20  # Cleanup every 20 operations

# Initialize behavioral analysis system
init_behavioral_analysis() {
    log_info "Initializing optimized behavioral analysis system..."
    
    # Create database directory if it doesn't exist
    mkdir -p "$(dirname "$BEHAVIORAL_DATABASE")"
    
    # Create optimized database schema with indexes
    sqlite3 "$BEHAVIORAL_DATABASE" << 'EOF'
-- Optimized Behavioral Analysis Database Schema
CREATE TABLE IF NOT EXISTS baseline_data (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    metric_name TEXT NOT NULL,
    baseline_value REAL NOT NULL,
    deviation_threshold REAL NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT 1
);

CREATE TABLE IF NOT EXISTS system_metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    cpu_usage REAL,
    memory_usage REAL,
    disk_io REAL,
    network_io REAL,
    process_count INTEGER,
    anomaly_score REAL DEFAULT 0,
    threat_level TEXT DEFAULT 'normal'
);

CREATE TABLE IF NOT EXISTS process_behavior (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    pid INTEGER,
    process_name TEXT,
    cpu_usage REAL,
    memory_usage REAL,
    rss INTEGER,
    status TEXT
);

CREATE TABLE IF NOT EXISTS network_behavior (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    protocol TEXT,
    local_address TEXT,
    remote_address TEXT,
    state TEXT
);

CREATE TABLE IF NOT EXISTS file_access_patterns (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    file_path TEXT,
    file_size INTEGER,
    permissions TEXT,
    access_type TEXT
);

CREATE TABLE IF NOT EXISTS anomaly_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    anomaly_type TEXT NOT NULL,
    metric_name TEXT NOT NULL,
    current_value REAL NOT NULL,
    baseline_value REAL NOT NULL,
    deviation REAL NOT NULL,
    severity TEXT DEFAULT 'medium',
    description TEXT,
    resolved BOOLEAN DEFAULT 0,
    false_positive BOOLEAN DEFAULT 0
);

CREATE TABLE IF NOT EXISTS threat_scores (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    overall_score REAL NOT NULL,
    cpu_score REAL DEFAULT 0,
    memory_score REAL DEFAULT 0,
    network_score REAL DEFAULT 0,
    process_score REAL DEFAULT 0,
    file_score REAL DEFAULT 0,
    threat_level TEXT DEFAULT 'normal'
);

-- Optimized indexes for performance
CREATE INDEX IF NOT EXISTS idx_system_metrics_timestamp ON system_metrics(timestamp);
CREATE INDEX IF NOT EXISTS idx_process_behavior_timestamp ON process_behavior(timestamp);
CREATE INDEX IF NOT EXISTS idx_network_behavior_timestamp ON network_behavior(timestamp);
CREATE INDEX IF NOT EXISTS idx_file_access_timestamp ON file_access_patterns(timestamp);
CREATE INDEX IF NOT EXISTS idx_anomaly_timestamp ON anomaly_events(timestamp);
CREATE INDEX IF NOT EXISTS idx_threat_scores_timestamp ON threat_scores(timestamp);
CREATE INDEX IF NOT EXISTS idx_baseline_active ON baseline_data(is_active);
CREATE INDEX IF NOT EXISTS idx_anomaly_resolved ON anomaly_events(resolved);
EOF

    log_info "Optimized behavioral analysis database initialized successfully"
    return 0
}

# Optimized system metrics collection
collect_system_metrics() {
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    local memory_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    
    # Check if iostat is available, otherwise use fallback
    if command -v iostat >/dev/null 2>&1; then
        local disk_io=$(iostat -x 1 1 | tail -n +4 | awk '{sum+=$10} END {print sum+0}')
    else
        # Fallback: use /proc/diskstats
        local disk_io=$(cat /proc/diskstats | awk '{sum+=$6} END {print sum+0}')
    fi
    
    local network_io=$(cat /proc/net/dev | grep -E "(eth|wlan|enp)" | awk '{sum+=$2+$10} END {print sum+0}')
    local process_count=$(ps aux | wc -l)
    
    # Insert into database with error handling
    sqlite3 "$BEHAVIORAL_DATABASE" 2>/dev/null << EOF
INSERT INTO system_metrics (cpu_usage, memory_usage, disk_io, network_io, process_count)
VALUES ('$cpu_usage', '$memory_usage', '$disk_io', '$network_io', '$process_count');
EOF
}

# Optimized process behavior collection with limits
collect_process_behavior() {
    local max_processes="${1:-$MAX_PROCESSES_TO_ANALYZE}"
    
    # Get top processes by CPU and memory usage
    ps aux --sort=-%cpu,-%mem | head -n "$((max_processes + 1))" | tail -n "$max_processes" | while read -r line; do
        if [ -n "$line" ]; then
            local pid=$(echo "$line" | awk '{print $2}')
            local comm=$(echo "$line" | awk '{print $11}')
            local cpu=$(echo "$line" | awk '{print $3}')
            local mem=$(echo "$line" | awk '{print $4}')
            local rss=$(echo "$line" | awk '{print $6}')
            
            # Skip if essential fields are missing
            if [ -z "$pid" ] || [ -z "$comm" ]; then
                continue
            fi
            
            # Insert into database with error handling
            sqlite3 "$BEHAVIORAL_DATABASE" 2>/dev/null << EOF
INSERT INTO process_behavior (pid, process_name, cpu_usage, memory_usage, rss, status)
VALUES ('$pid', '$comm', '$cpu', '$mem', '$rss', 'running');
EOF
        fi
    done
}

# Optimized network behavior collection with limits
collect_network_behavior() {
    local max_connections="${1:-$MAX_NETWORK_CONNECTIONS}"
    
    # Get network connections with limit
    ss -tn 2>/dev/null | head -n "$max_connections" | while read -r line; do
        if [ -n "$line" ] && [[ ! "$line" =~ ^State ]]; then
            local protocol=$(echo "$line" | awk '{print $1}')
            local local_addr=$(echo "$line" | awk '{print $4}')
            local remote_addr=$(echo "$line" | awk '{print $5}')
            local state=$(echo "$line" | awk '{print $2}')
            
            # Skip if essential fields are missing
            if [ -z "$protocol" ] || [ -z "$local_addr" ]; then
                continue
            fi
            
            # Insert into database with error handling
            sqlite3 "$BEHAVIORAL_DATABASE" 2>/dev/null << EOF
INSERT INTO network_behavior (protocol, local_address, remote_address, state)
VALUES ('$protocol', '$local_addr', '$remote_addr', '$state');
EOF
        fi
    done
}

# Optimized file access pattern collection with limits
collect_file_access_patterns() {
    local max_accesses="${1:-$MAX_FILE_ACCESSES}"
    
    # Monitor only recent file accesses (last 5 minutes) with limit
    find /var/log /tmp /home -type f -mmin -5 2>/dev/null | head -n "$max_accesses" | while read -r file; do
        if [ -f "$file" ]; then
            local size=$(stat -c%s "$file" 2>/dev/null || echo "0")
            local perms=$(stat -c%A "$file" 2>/dev/null || echo "unknown")
            
            # Insert into database with error handling
            sqlite3 "$BEHAVIORAL_DATABASE" 2>/dev/null << EOF
INSERT INTO file_access_patterns (file_path, file_size, permissions, access_type)
VALUES ('$file', '$size', '$perms', 'access');
EOF
        fi
    done
}

# Optimized anomaly detection
detect_anomalies() {
    # Detect CPU anomalies
    detect_cpu_anomalies
    
    # Detect memory anomalies
    detect_memory_anomalies
    
    # Detect process anomalies
    detect_process_anomalies
    
    # Detect network anomalies
    detect_network_anomalies
    
    # Detect file access anomalies
    detect_file_access_anomalies
}

# Detect CPU anomalies
detect_cpu_anomalies() {
    local avg_cpu=$(sqlite3 "$BEHAVIORAL_DATABASE" 2>/dev/null << EOF
SELECT AVG(cpu_usage) FROM system_metrics
WHERE timestamp > datetime('now', '-1 hour');
EOF
)
    
    local current_cpu=$(sqlite3 "$BEHAVIORAL_DATABASE" 2>/dev/null << EOF
SELECT cpu_usage FROM system_metrics
ORDER BY timestamp DESC LIMIT 1;
EOF
)
    
    if [ -n "$avg_cpu" ] && [ -n "$current_cpu" ]; then
        local deviation=$(echo "$current_cpu - $avg_cpu" | bc -l 2>/dev/null || echo "0")
        local abs_deviation=$(echo "$deviation" | tr -d '-' | bc -l 2>/dev/null || echo "0")
        
        if [ "$(echo "$abs_deviation > 30" | bc -l 2>/dev/null || echo "0")" -eq 1 ]; then
            local severity="medium"
            if [ "$(echo "$abs_deviation > 50" | bc -l 2>/dev/null || echo "0")" -eq 1 ]; then
                severity="high"
            fi
            
            sqlite3 "$BEHAVIORAL_DATABASE" 2>/dev/null << EOF
INSERT INTO anomaly_events (anomaly_type, metric_name, current_value, baseline_value, deviation, severity, description)
VALUES ('cpu_anomaly', 'cpu_usage', '$current_cpu', '$avg_cpu', '$abs_deviation', '$severity', 'CPU usage deviation detected');
EOF
        fi
    fi
}

# Detect memory anomalies
detect_memory_anomalies() {
    local avg_memory=$(sqlite3 "$BEHAVIORAL_DATABASE" 2>/dev/null << EOF
SELECT AVG(memory_usage) FROM system_metrics
WHERE timestamp > datetime('now', '-1 hour');
EOF
)
    
    local current_memory=$(sqlite3 "$BEHAVIORAL_DATABASE" 2>/dev/null << EOF
SELECT memory_usage FROM system_metrics
ORDER BY timestamp DESC LIMIT 1;
EOF
)
    
    if [ -n "$avg_memory" ] && [ -n "$current_memory" ]; then
        local deviation=$(echo "$current_memory - $avg_memory" | bc -l 2>/dev/null || echo "0")
        local abs_deviation=$(echo "$deviation" | tr -d '-' | bc -l 2>/dev/null || echo "0")
        
        if [ "$(echo "$abs_deviation > 25" | bc -l 2>/dev/null || echo "0")" -eq 1 ]; then
            local severity="medium"
            if [ "$(echo "$abs_deviation > 40" | bc -l 2>/dev/null || echo "0")" -eq 1 ]; then
                severity="high"
            fi
            
            sqlite3 "$BEHAVIORAL_DATABASE" 2>/dev/null << EOF
INSERT INTO anomaly_events (anomaly_type, metric_name, current_value, baseline_value, deviation, severity, description)
VALUES ('memory_anomaly', 'memory_usage', '$current_memory', '$avg_memory', '$abs_deviation', '$severity', 'Memory usage deviation detected');
EOF
        fi
    fi
}

# Detect process anomalies
detect_process_anomalies() {
    local process_count=$(sqlite3 "$BEHAVIORAL_DATABASE" 2>/dev/null << EOF
SELECT COUNT(DISTINCT pid) FROM process_behavior
WHERE timestamp > datetime('now', '-10 minutes');
EOF
)
    
    local avg_processes=$(sqlite3 "$BEHAVIORAL_DATABASE" 2>/dev/null << EOF
SELECT AVG(process_count) FROM system_metrics
WHERE timestamp > datetime('now', '-1 hour');
EOF
)
    
    if [ -n "$process_count" ] && [ -n "$avg_processes" ]; then
        local deviation=$(echo "$process_count - $avg_processes" | bc -l 2>/dev/null || echo "0")
        local abs_deviation=$(echo "$deviation" | tr -d '-' | bc -l 2>/dev/null || echo "0")
        
        if [ "$(echo "$abs_deviation > 50" | bc -l 2>/dev/null || echo "0")" -eq 1 ]; then
            local severity="medium"
            if [ "$(echo "$abs_deviation > 100" | bc -l 2>/dev/null || echo "0")" -eq 1 ]; then
                severity="high"
            fi
            
            sqlite3 "$BEHAVIORAL_DATABASE" 2>/dev/null << EOF
INSERT INTO anomaly_events (anomaly_type, metric_name, current_value, baseline_value, deviation, severity, description)
VALUES ('process_anomaly', 'process_count', '$process_count', '$avg_processes', '$abs_deviation', '$severity', 'Process count deviation detected');
EOF
        fi
    fi
}

# Detect network anomalies
detect_network_anomalies() {
    local connection_count=$(sqlite3 "$BEHAVIORAL_DATABASE" 2>/dev/null << EOF
SELECT COUNT(*) FROM network_behavior
WHERE timestamp > datetime('now', '-5 minutes');
EOF
)
    
    if [ -n "$connection_count" ] && [ "$connection_count" -gt 200 ]; then
        local severity="medium"
        if [ "$connection_count" -gt 500 ]; then
            severity="high"
        fi
        
        sqlite3 "$BEHAVIORAL_DATABASE" 2>/dev/null << EOF
INSERT INTO anomaly_events (anomaly_type, metric_name, current_value, baseline_value, deviation, severity, description)
VALUES ('network_anomaly', 'connection_count', '$connection_count', '100', '$((connection_count - 100))', '$severity', 'High network connection count detected');
EOF
    fi
}

# Detect file access anomalies
detect_file_access_anomalies() {
    local access_count=$(sqlite3 "$BEHAVIORAL_DATABASE" 2>/dev/null << EOF
SELECT COUNT(*) FROM file_access_patterns
WHERE timestamp > datetime('now', '-5 minutes');
EOF
)
    
    if [ -n "$access_count" ] && [ "$access_count" -gt 150 ]; then
        local severity="medium"
        if [ "$access_count" -gt 300 ]; then
            severity="high"
        fi
        
        sqlite3 "$BEHAVIORAL_DATABASE" 2>/dev/null << EOF
INSERT INTO anomaly_events (anomaly_type, metric_name, current_value, baseline_value, deviation, severity, description)
VALUES ('file_access_anomaly', 'access_count', '$access_count', '100', '$((access_count - 100))', '$severity', 'High file access count detected');
EOF
    fi
}

# Calculate threat score
calculate_threat_score() {
    local cpu_score=0
    local memory_score=0
    local network_score=0
    local process_score=0
    local file_score=0
    
    # Get recent anomalies and calculate scores
    local recent_anomalies=$(sqlite3 "$BEHAVIORAL_DATABASE" 2>/dev/null << EOF
SELECT anomaly_type, severity FROM anomaly_events
WHERE timestamp > datetime('now', '-30 minutes') AND resolved = 0 AND false_positive = 0;
EOF
)
    
    if [ -n "$recent_anomalies" ]; then
        echo "$recent_anomalies" | while IFS='|' read -r anomaly_type severity; do
            case "$anomaly_type" in
                "cpu_anomaly") cpu_score=20 ;;
                "memory_anomaly") memory_score=25 ;;
                "network_anomaly") network_score=20 ;;
                "process_anomaly") process_score=15 ;;
                "file_access_anomaly") file_score=20 ;;
            esac
            
            # Add severity multiplier
            if [ "$severity" = "high" ]; then
                case "$anomaly_type" in
                    "cpu_anomaly") cpu_score=$((cpu_score * 2)) ;;
                    "memory_anomaly") memory_score=$((memory_score * 2)) ;;
                    "network_anomaly") network_score=$((network_score * 2)) ;;
                    "process_anomaly") process_score=$((process_score * 2)) ;;
                    "file_access_anomaly") file_score=$((file_score * 2)) ;;
                esac
            fi
        done
    fi
    
    # Calculate overall threat score
    local overall_score=$((cpu_score + memory_score + network_score + process_score + file_score))
    
    # Determine threat level
    local threat_level="normal"
    if [ "$overall_score" -ge 80 ]; then
        threat_level="critical"
    elif [ "$overall_score" -ge 60 ]; then
        threat_level="high"
    elif [ "$overall_score" -ge 40 ]; then
        threat_level="medium"
    elif [ "$overall_score" -ge 20 ]; then
        threat_level="low"
    fi
    
    # Store threat score
    sqlite3 "$BEHAVIORAL_DATABASE" 2>/dev/null << EOF
INSERT INTO threat_scores (overall_score, cpu_score, memory_score, network_score, process_score, file_score, threat_level)
VALUES ('$overall_score', '$cpu_score', '$memory_score', '$network_score', '$process_score', '$file_score', '$threat_level');
EOF
    
    echo "$overall_score"
}

# Create baseline
create_baseline() {
    local learning_period="$1"
    log_info "Creating behavioral baseline (learning period: ${learning_period} days)..."
    
    # This is a simplified baseline creation
    # In a real implementation, you'd collect data over the learning period
    
    sqlite3 "$BEHAVIORAL_DATABASE" 2>/dev/null << EOF
INSERT OR REPLACE INTO baseline_data (metric_name, baseline_value, deviation_threshold, is_active)
VALUES
('cpu_usage', 30.0, 20.0, 1),
('memory_usage', 50.0, 25.0, 1),
('process_count', 100.0, 50.0, 1),
('network_connections', 100.0, 100.0, 1),
('file_accesses', 100.0, 100.0, 1);
EOF
    
    log_info "Behavioral baseline created successfully"
    return 0
}

# Update behavioral database
update_behavioral_database() {
    # Perform periodic cleanup
    local operation_count=$(sqlite3 "$BEHAVIORAL_DATABASE" 2>/dev/null << EOF
SELECT COUNT(*) FROM system_metrics;
EOF
)
    
    # Cleanup every MEMORY_CLEANUP_INTERVAL operations
    if [ $((operation_count % MEMORY_CLEANUP_INTERVAL)) -eq 0 ]; then
        log_info "Performing database cleanup..."
        
        sqlite3 "$BEHAVIORAL_DATABASE" 2>/dev/null << EOF
DELETE FROM system_metrics WHERE timestamp < datetime('now', '-2 hours');
DELETE FROM process_behavior WHERE timestamp < datetime('now', '-2 hours');
DELETE FROM network_behavior WHERE timestamp < datetime('now', '-2 hours');
DELETE FROM file_access_patterns WHERE timestamp < datetime('now', '-2 hours');
DELETE FROM anomaly_events WHERE timestamp < datetime('now', '-6 hours') AND resolved = 1;
VACUUM;
EOF
    fi
}

# Cleanup behavioral data
cleanup_behavioral_data() {
    log_info "Cleaning up behavioral data..."
    
    sqlite3 "$BEHAVIORAL_DATABASE" 2>/dev/null << EOF
DELETE FROM system_metrics WHERE timestamp < datetime('now', '-1 hour');
DELETE FROM process_behavior WHERE timestamp < datetime('now', '-1 hour');
DELETE FROM network_behavior WHERE timestamp < datetime('now', '-1 hour');
DELETE FROM file_access_patterns WHERE timestamp < datetime('now', '-1 hour');
DELETE FROM anomaly_events WHERE timestamp < datetime('now', '-3 hours') AND resolved = 1;
VACUUM;
EOF
    
    log_info "Behavioral data cleanup completed"
}

# Generate behavioral report
generate_behavioral_report() {
    local format="$1"
    local period="$2"
    
    local report_file="$AEGIS_HOME/configs/behavioral_analysis/behavioral_report_optimized_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "Optimized Behavioral Analysis Report"
        echo "================================="
        echo "Generated: $(date)"
        echo "Period: Last $period hours"
        echo ""
        
        echo "System Metrics Summary:"
        sqlite3 "$BEHAVIORAL_DATABASE" 2>/dev/null << EOF
SELECT
    'Average CPU Usage: ' || ROUND(AVG(cpu_usage), 2) || '%',
    'Average Memory Usage: ' || ROUND(AVG(memory_usage), 2) || '%',
    'Average Process Count: ' || ROUND(AVG(process_count), 0)
FROM system_metrics
WHERE timestamp > datetime('now', '-$period hours');
EOF
        
        echo ""
        echo "Recent Anomalies:"
        sqlite3 "$BEHAVIORAL_DATABASE" 2>/dev/null << EOF
SELECT
    timestamp || ' - ' || anomaly_type || ' (' || severity || ')' || ': ' || description
FROM anomaly_events
WHERE timestamp > datetime('now', '-$period hours')
ORDER BY timestamp DESC
LIMIT 10;
EOF
        
        echo ""
        echo "Threat Score Summary:"
        sqlite3 "$BEHAVIORAL_DATABASE" 2>/dev/null << EOF
SELECT
    'Latest Threat Score: ' || MAX(overall_score),
    'Average Threat Score: ' || ROUND(AVG(overall_score), 2),
    'Threat Level: ' || threat_level
FROM threat_scores
WHERE timestamp > datetime('now', '-$period hours')
ORDER BY timestamp DESC
LIMIT 1;
EOF
        
    } > "$report_file"
    
    log_info "Optimized behavioral report generated: $report_file"
    echo "$report_file"
}

# Export functions for use by other scripts
export -f init_behavioral_analysis collect_system_metrics
export -f collect_process_behavior collect_network_behavior collect_file_access_patterns
export -f detect_anomalies detect_cpu_anomalies detect_memory_anomalies
export -f detect_process_anomalies detect_network_anomalies detect_file_access_anomalies
export -f calculate_threat_score create_baseline update_behavioral_database
export -f cleanup_behavioral_data generate_behavioral_report