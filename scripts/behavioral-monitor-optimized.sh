#!/bin/bash
# Optimized Behavioral Monitoring Service with Memory Management
# Runs behavioral analysis monitoring with resource limits and cleanup

# Load configuration and functions
SCRIPT_DIR="$(dirname "$0")"
AEGIS_HOME="$(dirname "$SCRIPT_DIR")"
source "$AEGIS_HOME/configs/security-config.conf"
source "$SCRIPT_DIR/common-functions.sh"

# Load behavioral analysis if enabled
if [ "$BEHAVIORAL_ANALYSIS_ENABLED" = "true" ]; then
    source "$SCRIPT_DIR/behavioral-analysis-optimized.sh"
fi

# Optimized service configuration
MONITORING_DURATION="${1:-1800}"  # Reduced to 30 minutes default
MONITORING_INTERVAL="${2:-$BEHAVIORAL_MONITORING_INTERVAL}"
MAX_PROCESSES_TO_MONITOR=30  # Limit process monitoring
MEMORY_THRESHOLD=80  # Memory threshold for cleanup
CLEANUP_INTERVAL=10  # Cleanup every 10 cycles

# Initialize logging
LOG_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
MONITOR_LOG="$LOGS_DIR/manual/behavioral_monitor_optimized_${LOG_TIMESTAMP}.log"

echo "Optimized Behavioral Monitoring Service - $(date)" > "$MONITOR_LOG"
echo "=========================================" >> "$MONITOR_LOG"
echo "Duration: ${MONITORING_DURATION}s" >> "$MONITOR_LOG"
echo "Interval: ${MONITORING_INTERVAL}s" >> "$MONITOR_LOG"
echo "Max Processes: $MAX_PROCESSES_TO_MONITOR" >> "$MONITOR_LOG"
echo "Memory Threshold: ${MEMORY_THRESHOLD}%" >> "$MONITOR_LOG"
echo "" >> "$MONITOR_LOG"

# Initialize behavioral analysis
if [ "$BEHAVIORAL_ANALYSIS_ENABLED" = "true" ]; then
    log_info "Initializing optimized behavioral analysis for monitoring..."
    
    # Validate configuration
    if [ -z "$BEHAVIORAL_DATABASE" ]; then
        BEHAVIORAL_DATABASE="$AEGIS_HOME/configs/behavioral_analysis/behavioral_data.db"
    fi
    
    # Initialize and validate database connection
    if ! init_behavioral_analysis; then
        log_error "Failed to initialize behavioral analysis system"
        exit 1
    fi
    
    # Check if baseline exists with error handling
    baseline_exists=$(sqlite3 "$BEHAVIORAL_DATABASE" "SELECT COUNT(*) FROM baseline_data WHERE is_active = 1;" 2>/dev/null || echo "0")
    if [ "$baseline_exists" -eq 0 ]; then
        log_warning "No behavioral baseline found - creating initial baseline..."
        if ! create_baseline "$BEHAVIORAL_LEARNING_PERIOD"; then
            log_error "Failed to create behavioral baseline"
            exit 1
        fi
    fi
fi

# Memory management functions
check_memory_usage() {
    local memory_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    echo "$memory_usage"
}

perform_memory_cleanup() {
    log_info "Performing memory cleanup..."
    
    # Clean up old behavioral data
    sqlite3 "$BEHAVIORAL_DATABASE" 2>/dev/null << EOF
DELETE FROM system_metrics WHERE timestamp < datetime('now', '-2 hours');
DELETE FROM process_behavior WHERE timestamp < datetime('now', '-2 hours');
DELETE FROM network_behavior WHERE timestamp < datetime('now', '-2 hours');
DELETE FROM file_access_patterns WHERE timestamp < datetime('now', '-2 hours');
DELETE FROM anomaly_events WHERE timestamp < datetime('now', '-6 hours') AND resolved = 1;
VACUUM;
EOF
    
    # Clear system caches
    sync && echo 2 > /proc/sys/vm/drop_caches 2>/dev/null || true
    
    log_info "Memory cleanup completed"
}

# Optimized process behavior collection
collect_process_behavior_limited() {
    local max_processes="$1"
    
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
INSERT INTO process_behavior (timestamp, pid, process_name, cpu_usage, memory_usage, rss, status)
VALUES (datetime('now'), '$pid', '$comm', '$cpu', '$mem', '$rss', 'running');
EOF
        fi
    done
}

# Optimized network behavior collection
collect_network_behavior_limited() {
    # Limit network connections to monitor
    ss -tn 2>/dev/null | head -n 50 | while read -r line; do
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
INSERT INTO network_behavior (timestamp, protocol, local_address, remote_address, state)
VALUES (datetime('now'), '$protocol', '$local_addr', '$remote_addr', '$state');
EOF
        fi
    done
}

# Optimized file access pattern collection
collect_file_access_patterns_limited() {
    # Monitor only recent file accesses (last 5 minutes)
    find /var/log /tmp /home -type f -mmin -5 2>/dev/null | head -n 20 | while read -r file; do
        if [ -f "$file" ]; then
            local size=$(stat -c%s "$file" 2>/dev/null || echo "0")
            local perms=$(stat -c%A "$file" 2>/dev/null || echo "unknown")
            
            # Insert into database with error handling
            sqlite3 "$BEHAVIORAL_DATABASE" 2>/dev/null << EOF
INSERT INTO file_access_patterns (timestamp, file_path, file_size, permissions, access_type)
VALUES (datetime('now'), '$file', '$size', '$perms', 'access');
EOF
        fi
    done
}

# Send start notification
send_notification "🧠 Optimized Behavioral Monitoring Started" "Starting memory-efficient behavioral monitoring..." "security-high" "normal"

# Main monitoring loop with memory management
log_info "Starting optimized behavioral monitoring (duration: ${MONITORING_DURATION}s, interval: ${MONITORING_INTERVAL}s)"

end_time=$(( $(date +%s) + MONITORING_DURATION ))
monitoring_active=true
cycle_count=0

while [ "$monitoring_active" = true ]; do
    current_time=$(date +%s)
    
    # Check if monitoring duration has elapsed
    if [ "$current_time" -ge "$end_time" ]; then
        log_info "Monitoring duration completed, stopping..."
        monitoring_active=false
        break
    fi
    
    cycle_start=$(date +%s)
    
    # Collect current system metrics
    collect_system_metrics
    
    # Collect limited process behavior
    collect_process_behavior_limited "$MAX_PROCESSES_TO_MONITOR"
    
    # Collect limited network behavior
    collect_network_behavior_limited
    
    # Collect limited file access patterns
    collect_file_access_patterns_limited
    
    # Detect anomalies
    detect_anomalies
    
    # Calculate threat score
    current_threat_score=$(calculate_threat_score)
    log_info "Current behavioral threat score: $current_threat_score"
    
    # Check if threat score exceeds threshold
    if [ "$current_threat_score" -ge "$BEHAVIORAL_THREAT_SCORE_THRESHOLD" ]; then
        log_warning "🚨 HIGH BEHAVIORAL THREAT SCORE DETECTED: $current_threat_score (threshold: $BEHAVIORAL_THREAT_SCORE_THRESHOLD)"
        
        # Get recent anomalies for incident details (limited query)
        recent_anomalies=$(sqlite3 "$BEHAVIORAL_DATABASE" 2>/dev/null << EOF
SELECT GROUP_CONCAT(substr(anomaly_type || ':' || metric_name || ' (' || severity || ')', 1, 50), ', ')
FROM anomaly_events
WHERE timestamp > datetime('now', '-10 minutes') AND resolved = 0 AND false_positive = 0
LIMIT 5;
EOF
)
        
        incident_details="Behavioral analysis detected anomalies: $recent_anomalies (Threat Score: $current_threat_score)"
        
        # Trigger incident response if available
        if command -v automated_response &>/dev/null; then
            automated_response "behavioral_anomaly" "$incident_details" "high"
        else
            send_notification "🚨 Behavioral Anomaly Detected" "$incident_details" "security-critical" "critical"
        fi
        
        echo "$(date): HIGH THREAT SCORE DETECTED - $current_threat_score" >> "$MONITOR_LOG"
        echo "Anomalies: $recent_anomalies" >> "$MONITOR_LOG"
    fi
    
    # Update behavioral database
    update_behavioral_database
    
    # Memory management - check every CLEANUP_INTERVAL cycles
    if [ $((cycle_count % CLEANUP_INTERVAL)) -eq 0 ]; then
        current_memory=$(check_memory_usage)
        memory_int=$(echo "$current_memory" | cut -d. -f1)
        
        echo "$(date): Memory check - ${current_memory}%" >> "$MONITOR_LOG"
        
        if [ "$memory_int" -gt "$MEMORY_THRESHOLD" ]; then
            log_warning "High memory usage detected: ${current_memory}% - Performing cleanup"
            perform_memory_cleanup
        fi
    fi
    
    # Calculate cycle duration and sleep
    cycle_end=$(date +%s)
    cycle_duration=$((cycle_end - cycle_start))
    
    # Log monitoring status
    echo "$(date): Monitoring cycle $((cycle_count + 1)) completed - Threat score: $current_threat_score, Duration: ${cycle_duration}s" >> "$MONITOR_LOG"
    
    # Sleep for next cycle
    if [ $cycle_duration -lt $MONITORING_INTERVAL ]; then
        sleep_time=$((MONITORING_INTERVAL - cycle_duration))
        sleep "$sleep_time"
    fi
    
    ((cycle_count++))
done

# Final cleanup
log_info "Performing final cleanup before exit..."
perform_memory_cleanup

# Final summary
echo "" >> "$MONITOR_LOG"
echo "=== MONITORING SUMMARY ===" >> "$MONITOR_LOG"
echo "Completed: $(date)" >> "$MONITOR_LOG"
echo "Total Duration: ${MONITORING_DURATION}s" >> "$MONITOR_LOG"
echo "Total Cycles: $cycle_count" >> "$MONITOR_LOG"
echo "Final Threat Score: $current_threat_score" >> "$MONITOR_LOG"

# Send completion notification
send_notification "✅ Optimized Behavioral Monitoring Complete" "Memory-efficient behavioral monitoring completed ($cycle_count cycles)" "security-high" "normal"

log_info "Optimized behavioral monitoring completed - Log: $MONITOR_LOG"
exit 0
