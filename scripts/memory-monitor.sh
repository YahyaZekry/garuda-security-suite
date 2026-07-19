#!/bin/bash
# Memory Monitoring and Resource Management Script
# Monitors system memory usage and implements resource limits

source "$(dirname "$0")/common-functions.sh"

# Get security suite home directory
SCRIPT_DIR="$(dirname "$0")"
AEGIS_HOME="$(dirname "$SCRIPT_DIR")"

# Load configuration from security-config.conf
CONFIG_FILE="$AEGIS_HOME/configs/security-config.conf"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    # Fallback to default values if config file doesn't exist
    MEMORY_THRESHOLD_WARNING=85
    MEMORY_THRESHOLD_CRITICAL=95
    PROCESS_MEMORY_LIMIT=2000  # MB
fi

# Memory monitoring configuration
CHECK_INTERVAL=30  # seconds

# Log file for memory monitoring
MEMORY_LOG="$AEGIS_HOME/logs/memory-monitor.log"

# Initialize memory monitoring
init_memory_monitoring() {
    log_info "Initializing memory monitoring system..."
    
    # Create logs directory if it doesn't exist
    mkdir -p "$AEGIS_HOME/logs"
    
    # Initialize log file
    echo "Memory Monitor Log - $(date)" > "$MEMORY_LOG"
    echo "=============================" >> "$MEMORY_LOG"
    
    log_info "Memory monitoring initialized - Thresholds: Warning=$MEMORY_THRESHOLD_WARNING% Critical=$MEMORY_THRESHOLD_CRITICAL%"
}

# Get current memory usage
get_memory_usage() {
    local memory_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    echo "$memory_usage"
}

# Get process memory usage
get_process_memory_usage() {
    local process_name="$1"
    local memory_mb=$(ps aux | grep "$process_name" | grep -v grep | awk '{sum+=$6} END {print sum/1024}')
    echo "${memory_mb:-0}"
}

# Check and kill memory-intensive processes
check_memory_intensive_processes() {
    local processes_to_check=("behavioral-monitor" "threat-intelligence" "python.*dashboard")
    
    for process_pattern in "${processes_to_check[@]}"; do
        local memory_mb=$(get_process_memory_usage "$process_pattern")
        
        if [ "$(echo "$memory_mb > $PROCESS_MEMORY_LIMIT" | bc -l)" -eq 1 ]; then
            log_warning "Memory-intensive process detected: $process_pattern using ${memory_mb}MB (limit: ${PROCESS_MEMORY_LIMIT}MB)"
            
            # Get PIDs of matching processes
            local pids=$(ps aux | grep "$process_pattern" | grep -v grep | awk '{print $2}')
            
            for pid in $pids; do
                log_warning "Terminating memory-intensive process PID: $pid"
                kill -TERM "$pid" 2>/dev/null
                
                # If process doesn't terminate after 10 seconds, force kill
                sleep 10
                if kill -0 "$pid" 2>/dev/null; then
                    log_error "Force killing process PID: $pid"
                    kill -KILL "$pid" 2>/dev/null
                fi
            done
            
            # Log the action
            echo "$(date): Killed memory-intensive process: $process_pattern (${memory_mb}MB)" >> "$MEMORY_LOG"
        fi
    done
}

# Monitor system memory
monitor_system_memory() {
    local memory_usage=$(get_memory_usage)
    local memory_int=$(echo "$memory_usage" | cut -d. -f1)
    
    echo "$(date): System memory usage: ${memory_usage}%" >> "$MEMORY_LOG"
    
    if [ "$memory_int" -ge "$MEMORY_THRESHOLD_CRITICAL" ]; then
        log_error "🚨 CRITICAL MEMORY USAGE: ${memory_usage}% (threshold: ${MEMORY_THRESHOLD_CRITICAL}%)"
        
        # Take emergency actions
        emergency_memory_cleanup
        
        # Send critical notification
        send_notification "🚨 Critical Memory Usage" "System memory usage at ${memory_usage}% - Emergency cleanup initiated" "security-critical" "critical"
        
    elif [ "$memory_int" -ge "$MEMORY_THRESHOLD_WARNING" ]; then
        log_warning "⚠️ HIGH MEMORY USAGE: ${memory_usage}% (threshold: ${MEMORY_THRESHOLD_WARNING}%)"
        
        # Take preventive actions
        preventive_memory_cleanup
        
        # Send warning notification
        send_notification "⚠️ High Memory Usage" "System memory usage at ${memory_usage}% - Preventive cleanup initiated" "security-medium" "warning"
    fi
}

# Emergency memory cleanup
emergency_memory_cleanup() {
    log_info "Performing emergency memory cleanup..."
    
    # Clear system caches
    sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
    
    # Kill memory-intensive security processes
    check_memory_intensive_processes
    
    # Restart behavioral monitoring if it's using too much memory
    local behavioral_memory=$(get_process_memory_usage "behavioral-monitor")
    if [ "$(echo "$behavioral_memory > 200" | bc -l)" -eq 1 ]; then
        log_info "Restarting behavioral monitoring due to high memory usage"
        systemctl --user restart aegis-behavioral-monitor 2>/dev/null || true
    fi
    
    # Clean up old log files
    find "$AEGIS_HOME/logs" -name "*.log" -mtime +7 -delete 2>/dev/null || true
    
    # Clean up temporary files
    find "$AEGIS_HOME/configs" -name "*.tmp" -mtime +1 -delete 2>/dev/null || true
    find "$AEGIS_HOME/configs" -name "cache/*" -mtime +3 -delete 2>/dev/null || true
    
    log_info "Emergency memory cleanup completed"
}

# Preventive memory cleanup
preventive_memory_cleanup() {
    log_info "Performing preventive memory cleanup..."
    
    # Clean up old cache files
    find "$AEGIS_HOME/configs" -name "cache/*" -mtime +1 -delete 2>/dev/null || true
    
    # Vacuum databases to reclaim space
    local databases=(
        "$AEGIS_HOME/configs/behavioral_analysis/behavioral_data.db"
        "$AEGIS_HOME/configs/threat_intelligence/ioc_database.db"
        "$AEGIS_HOME/configs/incident_response/incidents.db"
    )
    
    for db in "${databases[@]}"; do
        if [ -f "$db" ]; then
            sqlite3 "$db" "VACUUM;" 2>/dev/null || true
        fi
    done
    
    log_info "Preventive memory cleanup completed"
}

# Monitor specific security processes
monitor_security_processes() {
    local processes=("behavioral-monitor" "threat-intelligence" "python.*dashboard")
    
    for process in "${processes[@]}"; do
        local memory_mb=$(get_process_memory_usage "$process")
        echo "$(date): Process $process: ${memory_mb}MB" >> "$MEMORY_LOG"
        
        # Check if process is using excessive memory
        if [ "$(echo "$memory_mb > $PROCESS_MEMORY_LIMIT" | bc -l)" -eq 1 ]; then
            log_warning "Process $process using excessive memory: ${memory_mb}MB"
            check_memory_intensive_processes
        fi
    done
}

# Generate memory usage report
generate_memory_report() {
    local report_file="$AEGIS_HOME/logs/memory-report-$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "Memory Usage Report - $(date)"
        echo "=========================="
        echo ""
        echo "System Memory Usage:"
        free -h
        echo ""
        echo "Top Memory-Consuming Processes:"
        ps aux --sort=-%mem | head -20
        echo ""
        echo "Security Suite Processes:"
        ps aux | grep -E "(behavioral|threat|dashboard)" | grep -v grep
        echo ""
        echo "Database Sizes:"
        find "$AEGIS_HOME/configs" -name "*.db" -exec ls -lh {} \;
        echo ""
        echo "Cache Directory Sizes:"
        du -sh "$AEGIS_HOME/configs"/*/cache 2>/dev/null || echo "No cache directories found"
    } > "$report_file"
    
    log_info "Memory report generated: $report_file"
    echo "$report_file"
}

# Main monitoring loop
start_memory_monitoring() {
    init_memory_monitoring
    
    log_info "Starting memory monitoring (interval: ${CHECK_INTERVAL}s)"
    
    while true; do
        monitor_system_memory
        monitor_security_processes
        
        # Sleep for the specified interval
        sleep "$CHECK_INTERVAL"
    done
}

# Handle signals
trap 'log_info "Memory monitoring stopped"; exit 0' TERM INT

# Main execution
case "${1:-start}" in
    "start")
        start_memory_monitoring
        ;;
    "check")
        monitor_system_memory
        monitor_security_processes
        ;;
    "report")
        generate_memory_report
        ;;
    "cleanup")
        emergency_memory_cleanup
        ;;
    *)
        echo "Usage: $0 {start|check|report|cleanup}"
        exit 1
        ;;
esac