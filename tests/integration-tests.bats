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
                source "$SCRIPT_DIR/scanners/clamav-scanner.sh"
                clamav_scan "${DAILY_SCAN_DIRS[@]}" || overall_status=$?
                ;;
        esac
        
        echo "" >> "$SCAN_LOG"
    fi
done

# Final summary
scan_end=$(date +%s)
scan_duration=$((scan_end - $(date +%s)))

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
    [ -f "$TEST_LOGS_DIR/daily/security_scan_*.log" ]
    grep -q "Daily Security Scan" "$TEST_LOGS_DIR/daily/security_scan_*.log"
    grep -q "DAILY SCAN SUMMARY" "$TEST_LOGS_DIR/daily/security_scan_*.log"
    
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
    
    # Create mock daily scan script
    cat > "$TEST_DIR/scripts/security-daily-scan.sh" << 'EOF'
#!/bin/bash
# Mock Daily Security Scan Script for Integration Testing

SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/../configs/security-config.conf"
source "$SCRIPT_DIR/common-functions.sh"

DAILY_SCAN_TOOLS=("clamav")
SCAN_TYPE="daily"
LOG_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

SCAN_LOG="$LOGS_DIR/daily/security_scan_${LOG_TIMESTAMP}.log"
echo "Daily Security Scan - $(date)" > "$SCAN_LOG"
echo "=============================" >> "$SCAN_LOG"

send_notification "🛡️ Daily Security Scan" "Starting daily security scan..." "security-high" "normal"

overall_status=0

for tool in "${SELECTED_SECURITY_TOOLS[@]}"; do
    if [[ " ${DAILY_SCAN_TOOLS[@]} " =~ " ${tool} " ]]; then
        log_info "Running $tool daily scan..."
        
        case "$tool" in
            "clamav")
                source "$SCRIPT_DIR/scanners/clamav-scanner.sh"
                clamav_scan "${DAILY_SCAN_DIRS[@]}" || overall_status=$?
                ;;
        esac
        
        echo "" >> "$SCAN_LOG"
    fi
done

echo "=== DAILY SCAN SUMMARY ===" >> "$SCAN_LOG"
echo "Overall Status: $overall_status" >> "$SCAN_LOG"
echo "Scan Completed: $(date)" >> "$SCAN_LOG"

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
    
    [ "$status" -eq 1 ]  # Should detect EICAR and return non-zero
    [ -f "$TEST_LOGS_DIR/daily/security_scan_*.log" ]
    [ -f "$TEST_LOGS_DIR/daily/clamav_*.log" ]
    grep -q "EICAR" "$TEST_LOGS_DIR/daily/clamav_*.log"
    grep -q "FOUND" "$TEST_LOGS_DIR/daily/clamav_*.log"
    
    cleanup_test_environment
}

@test "complete setup workflow with custom user" {
    # Create test user environment
    export USER="testuser"
    export HOME="/tmp/testuser_home"
    mkdir -p "$HOME"
    
    # Create mock setup script
    cat > "$TEST_DIR/setup-security-suite.sh" << 'EOF'
#!/bin/bash
# Mock Setup Script for Integration Testing

USER="${USER:-$(whoami)}"
HOME="${HOME:-$(getent passwd "$USER" | cut -d: -f6)}"
SECURITY_SUITE_HOME="${SECURITY_SUITE_HOME:-$HOME/security-suite}"

# Create directory structure
mkdir -p "$SECURITY_SUITE_HOME"/{scripts,configs,logs/{daily,weekly,monthly,manual,error,audit},backups}

# Create configuration file
cat > "$SECURITY_SUITE_HOME/configs/security-config.conf" << CONFIG
# Test Configuration for Garuda Security Suite
SECURITY_SUITE_HOME="$SECURITY_SUITE_HOME"
SCRIPTS_DIR="$SECURITY_SUITE_HOME/scripts"
LOGS_DIR="$SECURITY_SUITE_HOME/logs"
CONFIGS_DIR="$SECURITY_SUITE_HOME/configs"
BACKUPS_DIR="$SECURITY_SUITE_HOME/backups"
CURRENT_USER="$USER"

# Security Tools Configuration
SELECTED_SECURITY_TOOLS=("clamav" "rkhunter")
DAILY_SCAN_DIRS=("$HOME/Documents" "$HOME/Downloads")
WEEKLY_SCAN_DIRS=("$HOME")
MONTHLY_SCAN_DIRS=("$HOME" "/tmp")

# Schedule Configuration
DAILY_TIME="02:00"
WEEKLY_TIME="03:00"
MONTHLY_TIME="04:00"
WEEKLY_DAY="Sun"
MONTHLY_DAY="1"

# Notification Configuration
NOTIFICATIONS_ENABLED=false
NOTIFICATION_URGENCY="normal"
NOTIFICATION_EXPIRY="5000"
CONFIG

# Generate systemd services
generate_systemd_service() {
    local service_name="$1"
    local script_path="$2"
    local service_file="$HOME/.config/systemd/user/${service_name}.service"
    
    mkdir -p "$(dirname "$service_file")"
    
    cat > "$service_file" << SERVICE
[Unit]
Description=${service_name%.*}
After=network-online.target

[Service]
Type=oneshot
ExecStart=$script_path
WorkingDirectory=$(dirname "$script_path")
StandardOutput=journal
StandardError=journal
Environment=USER=$USER
Environment=HOME=$HOME

[Install]
WantedBy=default.target
SERVICE
    
    chmod 644 "$service_file"
}

# Create systemd services if scheduling is enabled
if [ "$ENABLE_SCHEDULING" = true ]; then
    generate_systemd_service "security-daily-scan" "$SECURITY_SUITE_HOME/scripts/security-daily-scan.sh"
    generate_systemd_service "security-weekly-scan" "$SECURITY_SUITE_HOME/scripts/security-weekly-scan.sh"
    generate_systemd_service "security-monthly-scan" "$SECURITY_SUITE_HOME/scripts/security-monthly-scan.sh"
fi

echo "Setup completed successfully"
exit 0
EOF
    
    chmod +x "$TEST_DIR/setup-security-suite.sh"
    
    # Run setup with custom configuration
    run "$TEST_DIR/setup-security-suite.sh" --non-interactive --defaults
    
    [ "$status" -eq 0 ]
    [ -d "$HOME/security-suite" ]
    [ -f "$HOME/security-suite/configs/security-config.conf" ]
    
    # Check configuration contains correct paths
    grep -q "$HOME/security-suite" "$HOME/security-suite/configs/security-config.conf"
    grep -q "testuser" "$HOME/security-suite/configs/security-config.conf"
    
    # Check systemd services use correct paths
    if [ "$ENABLE_SCHEDULING" = true ]; then
        grep -q "$HOME/security-suite" "$HOME/.config/systemd/user/security-daily-scan.service"
    fi
    
    # Cleanup
    rm -rf "$HOME"
    
    cleanup_test_environment
}

@test "complete setup workflow with systemd services" {
    # Create test user environment
    export USER="testuser"
    export HOME="/tmp/testuser_home"
    mkdir -p "$HOME"
    
    # Enable scheduling for this test
    export ENABLE_SCHEDULING=true
    
    # Create mock setup script
    cat > "$TEST_DIR/setup-security-suite.sh" << 'EOF'
#!/bin/bash
# Mock Setup Script for Integration Testing

USER="${USER:-$(whoami)}"
HOME="${HOME:-$(getent passwd "$USER" | cut -d: -f6)}"
SECURITY_SUITE_HOME="${SECURITY_SUITE_HOME:-$HOME/security-suite}"

# Create directory structure
mkdir -p "$SECURITY_SUITE_HOME"/{scripts,configs,logs/{daily,weekly,monthly,manual,error,audit},backups}

# Create configuration file
cat > "$SECURITY_SUITE_HOME/configs/security-config.conf" << CONFIG
SECURITY_SUITE_HOME="$SECURITY_SUITE_HOME"
SCRIPTS_DIR="$SECURITY_SUITE_HOME/scripts"
LOGS_DIR="$SECURITY_SUITE_HOME/logs"
CONFIGS_DIR="$SECURITY_SUITE_HOME/configs"
BACKUPS_DIR="$SECURITY_SUITE_HOME/backups"
CURRENT_USER="$USER"
CONFIG

# Generate systemd services
generate_systemd_service() {
    local service_name="$1"
    local script_path="$2"
    local service_file="$HOME/.config/systemd/user/${service_name}.service"
    
    mkdir -p "$(dirname "$service_file")"
    
    cat > "$service_file" << SERVICE
[Unit]
Description=${service_name%.*}
After=network-online.target

[Service]
Type=oneshot
ExecStart=$script_path
WorkingDirectory=$(dirname "$script_path")
StandardOutput=journal
StandardError=journal
Environment=USER=$USER
Environment=HOME=$HOME

[Install]
WantedBy=default.target
SERVICE
    
    chmod 644 "$service_file"
}

# Create systemd services
generate_systemd_service "security-daily-scan" "$SECURITY_SUITE_HOME/scripts/security-daily-scan.sh"
generate_systemd_service "security-weekly-scan" "$SECURITY_SUITE_HOME/scripts/security-weekly-scan.sh"
generate_systemd_service "security-monthly-scan" "$SECURITY_SUITE_HOME/scripts/security-monthly-scan.sh"

echo "Setup completed successfully"
exit 0
EOF
    
    chmod +x "$TEST_DIR/setup-security-suite.sh"
    
    # Run setup
    run "$TEST_DIR/setup-security-suite.sh"
    
    [ "$status" -eq 0 ]
    [ -d "$HOME/security-suite" ]
    
    # Check systemd services are created
    [ -f "$HOME/.config/systemd/user/security-daily-scan.service" ]
    [ -f "$HOME/.config/systemd/user/security-weekly-scan.service" ]
    [ -f "$HOME/.config/systemd/user/security-monthly-scan.service" ]
    
    # Check service content
    grep -q "ExecStart=$HOME/security-suite/scripts/security-daily-scan.sh" "$HOME/.config/systemd/user/security-daily-scan.service"
    grep -q "WorkingDirectory=$HOME/security-suite/scripts" "$HOME/.config/systemd/user/security-daily-scan.service"
    grep -q "Environment=USER=testuser" "$HOME/.config/systemd/user/security-daily-scan.service"
    grep -q "Environment=HOME=$HOME" "$HOME/.config/systemd/user/security-daily-scan.service"
    
    # Check service permissions
    [ "$(stat -c %a "$HOME/.config/systemd/user/security-daily-scan.service")" = "644" ]
    
    # Cleanup
    rm -rf "$HOME"
    
    cleanup_test_environment
}

@test "error recovery during scan failure" {
    setup_test_environment
    
    # Configure for testing
    export SELECTED_SECURITY_TOOLS=("clamav")
    export DAILY_SCAN_DIRS=("/nonexistent/directory")
    export LOGS_DIR="$TEST_LOGS_DIR"
    export NOTIFICATIONS_ENABLED=false
    
    # Create mock daily scan script with error handling
    cat > "$TEST_DIR/scripts/security-daily-scan.sh" << 'EOF'
#!/bin/bash
# Mock Daily Security Scan Script with Error Handling

SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/../configs/security-config.conf"
source "$SCRIPT_DIR/common-functions.sh"

DAILY_SCAN_TOOLS=("clamav")
SCAN_TYPE="daily"
LOG_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

SCAN_LOG="$LOGS_DIR/daily/security_scan_${LOG_TIMESTAMP}.log"
echo "Daily Security Scan - $(date)" > "$SCAN_LOG"
echo "=============================" >> "$SCAN_LOG"

send_notification "🛡️ Daily Security Scan" "Starting daily security scan..." "security-high" "normal"

overall_status=0

for tool in "${SELECTED_SECURITY_TOOLS[@]}"; do
    if [[ " ${DAILY_SCAN_TOOLS[@]} " =~ " ${tool} " ]]; then
        log_info "Running $tool daily scan..."
        
        case "$tool" in
            "clamav")
                source "$SCRIPT_DIR/scanners/clamav-scanner.sh"
                
                # Check if scan directories exist
                for dir in "${DAILY_SCAN_DIRS[@]}"; do
                    if [ ! -d "$dir" ]; then
                        log_warning "Directory does not exist: $dir"
                        overall_status=1
                    fi
                done
                
                # Attempt scan anyway
                clamav_scan "${DAILY_SCAN_DIRS[@]}" || overall_status=$?
                ;;
        esac
        
        echo "" >> "$SCAN_LOG"
    fi
done

echo "=== DAILY SCAN SUMMARY ===" >> "$SCAN_LOG"
echo "Overall Status: $overall_status" >> "$SCAN_LOG"
echo "Scan Completed: $(date)" >> "$SCAN_LOG"

if [ "$overall_status" -eq 0 ]; then
    send_notification "✅ Daily Scan Complete" "All daily scans completed successfully" "security-high" "normal"
else
    send_notification "⚠️ Daily Scan Issues" "Some scans completed with warnings - Check logs" "security-medium" "normal"
fi

log_info "Daily security scan completed - Log: $SCAN_LOG"
exit $overall_status
EOF
    
    chmod +x "$TEST_DIR/scripts/security-daily-scan.sh"
    
    # Run scan with failure
    run "$TEST_DIR/scripts/security-daily-scan.sh"
    
    # Should handle error gracefully
    [ "$status" -ne 0 ]
    [ -f "$TEST_LOGS_DIR/daily/security_scan_*.log" ]
    [ -f "$TEST_LOGS_DIR/error/security_errors_*.log" ]
    grep -q "Directory does not exist" "$TEST_LOGS_DIR/daily/security_scan_*.log"
    grep -q "WARNING" "$TEST_LOGS_DIR/daily/security_scan_*.log"
    
    cleanup_test_environment
}

@test "error recovery with missing security tools" {
    setup_test_environment
    
    # Configure with missing tool
    export SELECTED_SECURITY_TOOLS=("nonexistent-tool")
    export LOGS_DIR="$TEST_LOGS_DIR"
    export NOTIFICATIONS_ENABLED=false
    
    # Create mock daily scan script with graceful degradation
    cat > "$TEST_DIR/scripts/security-daily-scan.sh" << 'EOF'
#!/bin/bash
# Mock Daily Security Scan Script with Graceful Degradation

SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/../configs/security-config.conf"
source "$SCRIPT_DIR/common-functions.sh"

DAILY_SCAN_TOOLS=("clamav")
SCAN_TYPE="daily"
LOG_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

SCAN_LOG="$LOGS_DIR/daily/security_scan_${LOG_TIMESTAMP}.log"
echo "Daily Security Scan - $(date)" > "$SCAN_LOG"
echo "=============================" >> "$SCAN_LOG"

send_notification "🛡️ Daily Security Scan" "Starting daily security scan..." "security-high" "normal"

overall_status=0

for tool in "${SELECTED_SECURITY_TOOLS[@]}"; do
    if [[ " ${DAILY_SCAN_TOOLS[@]} " =~ " ${tool} " ]]; then
        log_info "Running $tool daily scan..."
        
        case "$tool" in
            "clamav")
                if [ -f "$SCRIPT_DIR/scanners/clamav-scanner.sh" ]; then
                    source "$SCRIPT_DIR/scanners/clamav-scanner.sh"
                    clamav_scan "${DAILY_SCAN_DIRS[@]}" || overall_status=$?
                else
                    log_warning "ClamAV scanner not available - Skipping"
                    overall_status=1
                fi
                ;;
            "nonexistent-tool")
                log_warning "Scanner $tool not found - Skipping"
                overall_status=1
                ;;
        esac
        
        echo "" >> "$SCAN_LOG"
    fi
done

echo "=== DAILY SCAN SUMMARY ===" >> "$SCAN_LOG"
echo "Overall Status: $overall_status" >> "$SCAN_LOG"
echo "Scan Completed: $(date)" >> "$SCAN_LOG"

if [ "$overall_status" -eq 0 ]; then
    send_notification "✅ Daily Scan Complete" "All daily scans completed successfully" "security-high" "normal"
else
    send_notification "⚠️ Daily Scan Issues" "Some scans completed with warnings - Check logs" "security-medium" "normal"
fi

log_info "Daily security scan completed - Log: $SCAN_LOG"
exit $overall_status
EOF
    
    chmod +x "$TEST_DIR/scripts/security-daily-scan.sh"
    
    # Run scan with missing tool
    run "$TEST_DIR/scripts/security-daily-scan.sh"
    
    # Should handle missing tool gracefully
    [ "$status" -ne 0 ]
    [ -f "$TEST_LOGS_DIR/daily/security_scan_*.log" ]
    grep -q "not found" "$TEST_LOGS_DIR/daily/security_scan_*.log"
    grep -q "WARNING" "$TEST_LOGS_DIR/daily/security_scan_*.log"
    
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