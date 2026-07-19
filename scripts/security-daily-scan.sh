#!/bin/bash
# Daily Security Scan Script
# Performs quick daily security scans

# Load configuration and functions
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/common-functions.sh"

# Setup user environment (will set AEGIS_HOME and other variables)
setup_user_environment

# Load configuration
if [ -f "$AEGIS_HOME/configs/security-config.conf" ]; then
    source "$AEGIS_HOME/configs/security-config.conf"
fi

# Load behavioral analysis if enabled
if [ "$BEHAVIORAL_ANALYSIS_ENABLED" = "true" ]; then
    source "$SCRIPT_DIR/behavioral-analysis-optimized.sh"
fi

# Daily scan configuration
DAILY_SCAN_TOOLS=("clamav")  # Quick scan tools only
SCAN_TYPE="daily"
LOG_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Initialize scan log
SCAN_LOG="$LOGS_DIR/daily/security_scan_${LOG_TIMESTAMP}.log"
echo "Daily Security Scan - $(date)" > "$SCAN_LOG"
echo "=============================" >> "$SCAN_LOG"

# Initialize logging
init_logging "$SCAN_TYPE"

# Initialize behavioral analysis if enabled
if [ "$BEHAVIORAL_ANALYSIS_ENABLED" = "true" ]; then
    log_info "Initializing behavioral analysis..."
    init_behavioral_analysis
    
    # Check if baseline exists, create if needed
    baseline_exists=$(sqlite3 "$BEHAVIORAL_DATABASE" "SELECT COUNT(*) FROM baseline_data WHERE is_active = 1;" 2>/dev/null || echo "0")
    if [ "$baseline_exists" -eq 0 ]; then
        log_info "Creating behavioral baseline (this may take some time)..."
        create_baseline "$BEHAVIORAL_LEARNING_PERIOD"
    fi
fi

# Send start notification
send_notification "🛡️ Daily Security Scan" "Starting daily security scan..." "security-high" "normal"

# Track overall scan status
overall_status=0

# Load and execute selected scanners
for tool in "${SELECTED_SECURITY_TOOLS[@]}"; do
    if printf '%s\n' "${DAILY_SCAN_TOOLS[@]}" | grep -q "^${tool}$"; then
        log_info "Running $tool daily scan..."
        
        case "$tool" in
            "clamav")
                source "$SCRIPT_DIR/scanners/clamav-scanner.sh"
                clamav_quick_scan "${DAILY_SCAN_DIRS[@]}" || overall_status=$?
                ;;
            "rkhunter")
                # Skip rkhunter in daily scans (too slow)
                log_info "Skipping rkhunter in daily scan (weekly only)"
                ;;
            "chkrootkit")
                if [ -f "$SCRIPT_DIR/scanners/chkrootkit-scanner.sh" ]; then
                    source "$SCRIPT_DIR/scanners/chkrootkit-scanner.sh"
                    chkrootkit_scan "${DAILY_SCAN_DIRS[@]}" || overall_status=$?
                else
                    log_warning "Chkrootkit scanner not available"
                fi
                ;;
            "lynis")
                # Skip lynis in daily scans (too comprehensive)
                log_info "Skipping Lynis in daily scan (monthly only)"
                ;;
        esac
        
        echo "" >> "$SCAN_LOG"
    fi
done

# Run behavioral analysis if enabled
if [ "$BEHAVIORAL_ANALYSIS_ENABLED" = "true" ]; then
    log_info "Running behavioral analysis..."
    
    # Collect current system metrics
    collect_system_metrics
    collect_process_behavior
    collect_network_behavior
    collect_file_access_patterns
    
    # Detect anomalies
    detect_anomalies
    
    # Calculate threat score
    current_threat_score=$(calculate_threat_score)
    log_info "Current behavioral threat score: $current_threat_score"
    
    # Check if threat score exceeds threshold
    if [ "$current_threat_score" -ge "$BEHAVIORAL_THREAT_SCORE_THRESHOLD" ]; then
        log_warning "🚨 HIGH BEHAVIORAL THREAT SCORE DETECTED: $current_threat_score (threshold: $BEHAVIORAL_THREAT_SCORE_THRESHOLD)"
        
        # Get recent anomalies for incident details
        recent_anomalies=$(sqlite3 "$AEGIS_HOME/configs/behavioral_analysis/behavioral_data.db" << EOF
SELECT GROUP_CONCAT(anomaly_type || ':' || metric_name || ' (' || severity || ')', ', ')
FROM anomaly_events
WHERE timestamp > datetime('now', '-10 minutes') AND resolved = 0 AND false_positive = 0
LIMIT 10;
EOF
)
        
        incident_details="Behavioral analysis detected multiple anomalies: $recent_anomalies (Threat Score: $current_threat_score)"
        
        # Trigger incident response if available
        if command -v automated_response &>/dev/null; then
            automated_response "behavioral_anomaly" "$incident_details" "high"
        else
            send_notification "🚨 Behavioral Anomaly Detected" "$incident_details" "security-critical" "critical"
        fi
    fi
    
    # Update behavioral database
    update_behavioral_database
    
    # Generate behavioral report
    report_file=$(generate_behavioral_report "text" "24")
    log_info "Behavioral analysis report generated: $report_file"
fi

# Final summary
scan_end=$(date +%s)
scan_start=$(date -d "$(head -1 "$SCAN_LOG" | cut -d' ' -f4)" +%s 2>/dev/null || echo $(date +%s))
scan_duration=$((scan_end - scan_start))

echo "=== DAILY SCAN SUMMARY ===" >> "$SCAN_LOG"
echo "Overall Status: $overall_status" >> "$SCAN_LOG"
echo "Scan Duration: ${scan_duration}s" >> "$SCAN_LOG"
echo "Scan Completed: $(date)" >> "$SCAN_LOG"
echo "Tools Used: ${SELECTED_SECURITY_TOOLS[*]}" >> "$SCAN_LOG"

# Send completion notification
if [ "$overall_status" -eq 0 ]; then
    send_notification "✅ Daily Scan Complete" "All daily scans completed successfully" "security-high" "normal"
    log_success "Daily security scan completed successfully"
else
    send_notification "⚠️ Daily Scan Issues" "Some scans completed with warnings - Check logs" "security-medium" "normal"
    log_warning "Daily security scan completed with issues (status: $overall_status)"
fi

log_info "Daily security scan completed - Log: $SCAN_LOG"
exit $overall_status