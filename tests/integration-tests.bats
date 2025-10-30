#!/usr/bin/env bats
# Integration Tests for Complete Workflows
# Following Phase 1 implementation plans (lines 1733-1801)

load "test-helper"

setup() {
    setup_test_environment
    mock_external_commands
}

teardown() {
    cleanup_test_environment
}

@test "complete daily scan workflow" {
    setup_test_environment
    
    # Configure for testing
    export SELECTED_SECURITY_TOOLS=("clamav")
    export DAILY_SCAN_DIRS=("$TEST_DIR")
    export LOGS_DIR="$TEST_LOGS_DIR"
    export NOTIFICATIONS_ENABLED=false
    
    # Create mock daily scan script
    cat > "$TEST_DIR/scripts/security-daily-scan.sh" << 'EOF'
#!/bin/bash
# Mock Daily Security Scan Script for Integration Testing

# Load configuration and functions
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/../configs/security-config.conf"
source "$SCRIPT_DIR/common-functions.sh"

# Daily scan configuration
DAILY_SCAN_TOOLS=("clamav")
SCAN_TYPE="daily"
LOG_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Initialize scan log
SCAN_LOG="$LOGS_DIR/daily/security_scan_${LOG_TIMESTAMP}.log"
echo "Daily Security Scan - $(date)" > "$SCAN_LOG"
echo "=============================" >> "$SCAN_LOG"

# Send start notification
send_notification "🛡️ Daily Security Scan" "Starting daily security scan..." "security-high" "normal"

# Track overall scan status
overall_status=0

# Load and execute selected scanners
for tool in "${SELECTED_SECURITY_TOOLS[@]}"; do
    if [[ " ${DAILY_SCAN_TOOLS[@]} " =~ " ${tool} " ]]; then
        log_info "Running $tool daily scan..."
        
        case "$tool" in
            "clamav")
                clamav_scan "${DAILY_SCAN_DIRS[@]}"
                scan_result=$?
                if [ "$scan_result" -ne 0 ]; then
                    overall_status=$scan_result
                fi
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

# Send completion notification
if [ "$overall_status" -eq 0 ]; then
    send_notification "✅ Daily Scan Complete" "All daily scans completed successfully" "security-high" "normal"
else
    send_notification "⚠️ Daily Scan Issues" "Some scans completed with warnings - Check logs" "security-medium" "normal"
fi

log_info "Daily security scan completed - Log: $SCAN_LOG"
exit $overall_status
EOF
    
    chmod +x "$TEST_DIR/scripts/security-daily-scan.sh"
    
    # Run daily scan
    run "$TEST_DIR/scripts/security-daily-scan.sh"
    
    [ "$status" -eq 0 ]
    # Find the actual log file that was created
    local log_file=$(find "$TEST_LOGS_DIR/daily" -name "security_scan_*.log" | head -1)
    [ -f "$log_file" ]
    grep -q "Daily Security Scan" "$log_file"
    grep -q "DAILY SCAN SUMMARY" "$log_file"
    
    cleanup_test_environment
}

@test "complete daily scan workflow with EICAR detection" {
    setup_test_environment
    
    # Configure for testing
    export SELECTED_SECURITY_TOOLS=("clamav")
    export DAILY_SCAN_DIRS=("$TEST_DIR")
    export LOGS_DIR="$TEST_LOGS_DIR"
    export NOTIFICATIONS_ENABLED=false
    
    # Create EICAR test file
    echo 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > "$TEST_DIR/eicar.com"
    
    # Test clamav_scan directly
    run clamav_scan "$TEST_DIR"
    
    # Should detect EICAR and return non-zero
    [ "$status" -eq 1 ]
    
    # Check that EICAR was detected in logs
    local clamav_log=$(find "$TEST_LOGS_DIR/daily" -name "clamav_*.log" | head -1)
    [ -f "$clamav_log" ]
    grep -q "EICAR" "$clamav_log"
    grep -q "FOUND" "$clamav_log"
    
    cleanup_test_environment
}

@test "complete workflow with configuration validation" {
    setup_test_environment
    
    # Create configuration with validation errors
    cat > "$TEST_CONFIG_DIR/security-config.conf" << EOF
SECURITY_SUITE_HOME="$TEST_DIR"
SCRIPTS_DIR="$TEST_DIR/scripts"
LOGS_DIR="$TEST_LOGS_DIR"
CONFIGS_DIR="$TEST_CONFIG_DIR"
BACKUPS_DIR="$TEST_DIR/backups"
CURRENT_USER="testuser"

# Invalid configuration for testing
SELECTED_SECURITY_TOOLS=("clamav")
DAILY_SCAN_DIRS=("../etc" "/home")  # Dangerous path
WEEKLY_SCAN_DIRS=("$HOME")
MONTHLY_SCAN_DIRS=("$HOME" "/tmp")

DAILY_TIME="25:00"  # Invalid time
WEEKLY_TIME="03:00"
MONTHLY_TIME="04:00"
WEEKLY_DAY="Sun"
MONTHLY_DAY="1"

NOTIFICATIONS_ENABLED=false
EOF
    
    # Create mock setup script with configuration validation
    cat > "$TEST_DIR/setup-security-suite.sh" << 'EOF'
#!/bin/bash
# Mock Setup Script with Configuration Validation

SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/../configs/security-config.conf"
source "$SCRIPT_DIR/common-functions.sh"
source "$SCRIPT_DIR/input-validation.sh"

# Validate configuration
if ! validate_security_config "$CONFIGS_DIR/security-config.conf"; then
    echo "Configuration validation failed"
    exit 1
fi

echo "Setup completed successfully"
exit 0
EOF
    
    chmod +x "$TEST_DIR/setup-security-suite.sh"
    
    # Run setup with invalid configuration
    run "$TEST_DIR/setup-security-suite.sh"
    
    # Should fail configuration validation
    [ "$status" -eq 1 ]
    
    cleanup_test_environment
}
