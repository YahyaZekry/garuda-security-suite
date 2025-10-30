#!/bin/bash
# Rkhunter Scanner Module
# Provides rootkit detection functionality

source "$(dirname "$(dirname "$0")")/common-functions.sh"

rkhunter_scan() {
    local scan_log="$LOGS_DIR/weekly/rkhunter_$(date +%Y%m%d_%H%M%S).log"
    local scan_start=$(date +%s)
    
    log_info "Starting Rkhunter rootkit scan"
    
    # Check if Rkhunter is installed
    if ! command -v rkhunter &>/dev/null; then
        log_error "Rkhunter is not installed or not in PATH"
        return 1
    fi
    
    # Update rkhunter database
    if [ "$UPDATE_BEFORE_SCAN" = true ]; then
        log_info "Updating Rkhunter database..."
        if ! sudo rkhunter --update --rwo; then
            log_error "Failed to update Rkhunter database"
            return 1
        fi
        log_info "Rkhunter database updated successfully"
        
        # Propagate file properties
        log_info "Updating file properties database..."
        if ! sudo rkhunter --propupd --rwo; then
            log_warning "Failed to update file properties database"
        else
            log_info "File properties database updated successfully"
        fi
    fi
    
    # Perform system check
    log_info "Running Rkhunter system check..."
    if ! sudo rkhunter --check --skip-keypress --report-warnings-only --logfile "$scan_log"; then
        local scan_result=$?
        log_error "Rkhunter scan failed with exit code $scan_result"
        return $scan_result
    fi
    
    local scan_end=$(date +%s)
    local scan_duration=$((scan_end - scan_start))
    
    # Process results
    process_rkhunter_results "$scan_log" "$scan_duration"
    
    return 0
}

process_rkhunter_results() {
    local log_file="$1"
    local duration="$2"
    
    # Check if log file exists
    if [ ! -f "$log_file" ]; then
        log_error "Rkhunter log file not found: $log_file"
        return 1
    fi
    
    local warnings=$(grep -c "Warning:" "$log_file" 2>/dev/null || echo "0")
    local rootkits=$(grep -c "Found" "$log_file" 2>/dev/null || echo "0")
    
    if [ "$warnings" -eq 0 ] && [ "$rootkits" -eq 0 ]; then
        log_success "Rkhunter scan completed - No issues found"
        send_notification "✅ Rkhunter Scan Complete" "No rootkits or warnings found" "security-high" "normal"
    else
        log_warning "Rkhunter found $warnings warnings and $rootkits potential rootkits"
        send_notification "⚠️ Rkhunter Issues Found" "$warnings warnings, $rootkits rootkits detected" "security-medium" "critical"
        
        # Log warnings for easy reference
        if [ "$warnings" -gt 0 ]; then
            log_info "Rkhunter warnings found:"
            grep "Warning:" "$log_file" | while read -r line; do
                log_warning "Warning: $line"
            done
        fi
        
        # Log rootkit findings for easy reference
        if [ "$rootkits" -gt 0 ]; then
            log_info "Rkhunter rootkit findings:"
            grep "Found" "$log_file" | while read -r line; do
                log_error "Rootkit: $line"
            done
        fi
    fi
    
    # Add summary to log
    echo "=== SCAN SUMMARY ===" >> "$log_file"
    echo "Scan Duration: ${duration}s" >> "$log_file"
    echo "Warnings: $warnings" >> "$log_file"
    echo "Rootkits Found: $rootkits" >> "$log_file"
    echo "Scan Completed: $(date)" >> "$log_file"
    
    # Log summary to main log
    log_info "Rkhunter scan summary: Duration=${duration}s, Warnings=${warnings}, Rootkits=${rootkits}"
}

# Quick check function for daily scans (limited scope)
rkhunter_quick_check() {
    local scan_log="$LOGS_DIR/daily/rkhunter_quick_$(date +%Y%m%d_%H%M%S).log"
    local scan_start=$(date +%s)
    
    log_info "Starting Rkhunter quick check"
    
    # Check if Rkhunter is installed
    if ! command -v rkhunter &>/dev/null; then
        log_error "Rkhunter is not installed or not in PATH"
        return 1
    fi
    
    # Perform quick check (only critical system files)
    log_info "Running Rkhunter quick check..."
    if ! sudo rkhunter --check --skip-keypress --report-warnings-only --logfile "$scan_log" \
        --enable "rootkits,malware,properties,apps" --disable "startup_groups,mktemp,os_specific"; then
        local scan_result=$?
        log_error "Rkhunter quick check failed with exit code $scan_result"
        return $scan_result
    fi
    
    local scan_end=$(date +%s)
    local scan_duration=$((scan_end - scan_start))
    
    # Process results
    process_rkhunter_results "$scan_log" "$scan_duration"
    
    return 0
}

# Update function for manual database updates
rkhunter_update() {
    log_info "Updating Rkhunter databases"
    
    # Check if Rkhunter is installed
    if ! command -v rkhunter &>/dev/null; then
        log_error "Rkhunter is not installed or not in PATH"
        return 1
    fi
    
    # Update database
    if ! sudo rkhunter --update --rwo; then
        log_error "Failed to update Rkhunter database"
        return 1
    fi
    
    # Update file properties
    if ! sudo rkhunter --propupd --rwo; then
        log_warning "Failed to update file properties database"
    fi
    
    log_info "Rkhunter databases updated successfully"
    send_notification "✅ Rkhunter Updated" "Databases and file properties updated" "security-high" "normal"
    
    return 0
}

# Export functions for use in main scripts
export -f rkhunter_scan
export -f rkhunter_quick_check
export -f rkhunter_update
export -f process_rkhunter_results