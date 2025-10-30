#!/bin/bash
# ClamAV Scanner Module
# Provides comprehensive antivirus scanning functionality

source "$(dirname "$(dirname "$0")")/common-functions.sh"

clamav_scan() {
    local scan_dirs=("$@")
    local scan_log="$LOGS_DIR/daily/clamav_$(date +%Y%m%d_%H%M%S).log"
    local scan_start=$(date +%s)
    
    log_info "Starting ClamAV scan of directories: ${scan_dirs[*]}"
    
    # Check if ClamAV is installed
    if ! command -v clamscan &>/dev/null; then
        log_error "ClamAV is not installed or not in PATH"
        return 1
    fi
    
    # Update virus definitions if enabled
    if [ "$UPDATE_BEFORE_SCAN" = true ]; then
        log_info "Updating ClamAV virus definitions..."
        if ! sudo freshclam --quiet; then
            log_error "Failed to update virus definitions"
            return 1
        fi
        log_info "Virus definitions updated successfully"
    fi
    
    # Perform scan with appropriate options
    local clam_options=(
        "--recursive"
        "--detect-pua=yes"
        "--detect-structured=yes"
        "--structured-cc-count=5"
        "--structured-ssn-count=5"
        "--log=$scan_log"
    )
    
    if [ "$REAL_TIME_FEEDBACK" = true ]; then
        clam_options+=("--bell")
    fi
    
    # Execute scan
    local scan_result=0
    for dir in "${scan_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            log_warning "Directory does not exist: $dir"
            continue
        fi
        
        log_info "Scanning directory: $dir"
        if ! sudo clamscan "${clam_options[@]}" "$dir"; then
            scan_result=$?
        fi
    done
    
    local scan_end=$(date +%s)
    local scan_duration=$((scan_end - scan_start))
    
    # Process results
    process_clamav_results "$scan_log" "$scan_duration" "$scan_result"
    
    return $scan_result
}

process_clamav_results() {
    local log_file="$1"
    local duration="$2"
    local exit_code="$3"
    
    # Check if log file exists
    if [ ! -f "$log_file" ]; then
        log_error "ClamAV log file not found: $log_file"
        return 1
    fi
    
    local infected_count=$(grep -c "FOUND" "$log_file" 2>/dev/null || echo "0")
    local scanned_count=$(grep -c "SCAN SUMMARY" "$log_file" 2>/dev/null && echo "Scanned" || echo "Unknown")
    
    if [ "$exit_code" -eq 0 ] && [ "$infected_count" -eq 0 ]; then
        log_success "ClamAV scan completed successfully - No threats found"
        send_notification "✅ ClamAV Scan Complete" "No threats found in $duration seconds" "security-high" "normal"
    elif [ "$infected_count" -gt 0 ]; then
        log_warning "ClamAV scan found $infected_count potential threats"
        send_notification "⚠️ ClamAV Threats Detected" "$infected_count threats found - Check logs" "security-medium" "critical"
        
        # Log infected files for easy reference
        log_info "Infected files found:"
        grep "FOUND" "$log_file" | while read -r line; do
            log_warning "Threat: $line"
        done
    else
        log_error "ClamAV scan failed with exit code $exit_code"
        send_notification "❌ ClamAV Scan Failed" "Scan failed - Check logs for details" "security-error" "critical"
    fi
    
    # Add summary to log
    echo "=== SCAN SUMMARY ===" >> "$log_file"
    echo "Scan Duration: ${duration}s" >> "$log_file"
    echo "Infected Files: $infected_count" >> "$log_file"
    echo "Exit Code: $exit_code" >> "$log_file"
    echo "Scan Completed: $(date)" >> "$log_file"
    
    # Log summary to main log
    log_info "ClamAV scan summary: Duration=${duration}s, Infected=${infected_count}, Exit Code=${exit_code}"
}

# Quick scan function for daily scans
clamav_quick_scan() {
    local scan_dirs=("$@")
    local scan_log="$LOGS_DIR/daily/clamav_quick_$(date +%Y%m%d_%H%M%S).log"
    local scan_start=$(date +%s)
    
    log_info "Starting ClamAV quick scan of directories: ${scan_dirs[*]}"
    
    # Check if ClamAV is installed
    if ! command -v clamscan &>/dev/null; then
        log_error "ClamAV is not installed or not in PATH"
        return 1
    fi
    
    # Quick scan options (less thorough but faster)
    local clam_options=(
        "--recursive"
        "--max-scansize=50M"
        "--max-filesize=25M"
        "--log=$scan_log"
    )
    
    # Execute quick scan
    local scan_result=0
    for dir in "${scan_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            log_warning "Directory does not exist: $dir"
            continue
        fi
        
        log_info "Quick scanning directory: $dir"
        if ! sudo clamscan "${clam_options[@]}" "$dir"; then
            scan_result=$?
        fi
    done
    
    local scan_end=$(date +%s)
    local scan_duration=$((scan_end - scan_start))
    
    # Process results
    process_clamav_results "$scan_log" "$scan_duration" "$scan_result"
    
    return $scan_result
}

# Export functions for use in main scripts
export -f clamav_scan
export -f clamav_quick_scan
export -f process_clamav_results