#!/bin/bash
# Daily Security Scan Script
# Performs quick daily security scans

# Load configuration and functions
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/../configs/security-config.conf"
source "$SCRIPT_DIR/common-functions.sh"

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