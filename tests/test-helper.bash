#!/usr/bin/env bash
# Test Helper Utilities for Garuda Security Suite
# Provides common testing functions and environment setup

# Global test variables
export TEST_DIR="/tmp/garuda-security-test"
export TEST_LOGS_DIR="$TEST_DIR/logs"
export TEST_CONFIG_DIR="$TEST_DIR/configs"
export SCRIPT_DIR="$(dirname "$0")/.."
export ORIGINAL_HOME="$HOME"

# Test environment setup
setup_test_environment() {
    # Create test directories
    mkdir -p "$TEST_DIR"
    mkdir -p "$TEST_LOGS_DIR"/{daily,weekly,monthly,manual,error,audit}
    mkdir -p "$TEST_CONFIG_DIR"
    mkdir -p "$TEST_DIR/scripts/scanners"
    
    # Create mock test files
    echo 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > "$TEST_DIR/eicar.com"
    echo "Test file content" > "$TEST_DIR/test.txt"
    
    # Set test environment variables
    export SECURITY_SUITE_HOME="$TEST_DIR"
    export LOGS_DIR="$TEST_LOGS_DIR"
    export CONFIGS_DIR="$TEST_CONFIG_DIR"
    export CURRENT_USER="testuser"
    export CURRENT_HOME="$TEST_DIR"
    
    # Disable notifications for testing
    export NOTIFICATIONS_ENABLED=false
    
    # Create test configuration
    cat > "$TEST_CONFIG_DIR/security-config.conf" << EOF
# Test Configuration for Garuda Security Suite
SECURITY_SUITE_HOME="$TEST_DIR"
SCRIPTS_DIR="$TEST_DIR/scripts"
LOGS_DIR="$TEST_LOGS_DIR"
CONFIGS_DIR="$TEST_CONFIG_DIR"
BACKUPS_DIR="$TEST_DIR/backups"
CURRENT_USER="testuser"

# Security Tools Configuration
SELECTED_SECURITY_TOOLS=("clamav" "rkhunter")
DAILY_SCAN_DIRS=("$TEST_DIR" "$HOME/Documents")
WEEKLY_SCAN_DIRS=("$HOME")
MONTHLY_SCAN_DIRS=("$HOME" "/tmp" "/var/tmp")

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

# Performance Configuration
MAX_MEMORY_USAGE="500"
MAX_LOG_SIZE="10"
UPDATE_BEFORE_SCAN=false
REAL_TIME_FEEDBACK=false

# Logging Configuration
LOG_LEVEL="INFO"
ROTATE_LOGS=true
COMPRESS_OLD_LOGS=true
LOG_RETENTION_DAYS="30"
EOF
    
    # Create mock scanner scripts
    cat > "$TEST_DIR/scripts/scanners/clamav-scanner.sh" << 'EOF'
#!/bin/bash
# Mock ClamAV Scanner for Testing
source "$(dirname "$0")/../../common-functions.sh"

clamav_scan() {
    local scan_dirs=("$@")
    local scan_log="$LOGS_DIR/daily/clamav_$(date +%Y%m%d_%H%M%S).log"
    
    log_info "Mock ClamAV scan of directories: ${scan_dirs[*]}"
    
    # Check for EICAR test file
    local found_eicar=false
    for dir in "${scan_dirs[@]}"; do
        if [ -f "$dir/eicar.com" ]; then
            echo "EICAR test file detected in $dir/eicar.com" >> "$scan_log"
            echo "EICAR test file: Eicar-Test-Signature FOUND" >> "$scan_log"
            found_eicar=true
        fi
    done
    
    echo "=== SCAN SUMMARY ===" >> "$scan_log"
    echo "Scan Duration: 1s" >> "$scan_log"
    echo "Infected Files: $([ "$found_eicar" = true ] && echo "1" || echo "0")" >> "$scan_log"
    echo "Exit Code: $([ "$found_eicar" = true ] && echo "1" || echo "0")" >> "$scan_log"
    echo "Scan Completed: $(date)" >> "$scan_log"
    
    [ "$found_eicar" = true ] && return 1 || return 0
}

process_clamav_results() {
    local log_file="$1"
    local duration="$2"
    local exit_code="$3"
    
    local infected_count=$(grep -c "FOUND" "$log_file" 2>/dev/null || echo "0")
    
    if [ "$exit_code" -eq 0 ] && [ "$infected_count" -eq 0 ]; then
        log_success "ClamAV scan completed successfully - No threats found"
    elif [ "$infected_count" -gt 0 ]; then
        log_warning "ClamAV scan found $infected_count potential threats"
    else
        log_error "ClamAV scan failed with exit code $exit_code"
    fi
}

export -f clamav_scan
export -f process_clamav_results
EOF

    cat > "$TEST_DIR/scripts/scanners/rkhunter-scanner.sh" << 'EOF'
#!/bin/bash
# Mock Rkhunter Scanner for Testing
source "$(dirname "$0")/../../common-functions.sh"

rkhunter_scan() {
    local scan_log="$LOGS_DIR/weekly/rkhunter_$(date +%Y%m%d_%H%M%S).log"
    
    log_info "Mock Rkhunter rootkit scan"
    
    echo "=== SCAN SUMMARY ===" >> "$scan_log"
    echo "Scan Duration: 2s" >> "$scan_log"
    echo "Warnings: 0" >> "$scan_log"
    echo "Rootkits Found: 0" >> "$scan_log"
    echo "Scan Completed: $(date)" >> "$scan_log"
    
    return 0
}

process_rkhunter_results() {
    local log_file="$1"
    local duration="$2"
    
    local warnings=$(grep -c "Warning:" "$log_file" 2>/dev/null || echo "0")
    local rootkits=$(grep -c "Found" "$log_file" 2>/dev/null || echo "0")
    
    if [ "$warnings" -eq 0 ] && [ "$rootkits" -eq 0 ]; then
        log_success "Rkhunter scan completed - No issues found"
    else
        log_warning "Rkhunter found $warnings warnings and $rootkits potential rootkits"
    fi
}

export -f rkhunter_scan
export -f process_rkhunter_results
EOF

    # Make mock scripts executable
    if [ -d "$TEST_DIR/scripts/scanners/" ]; then
        chmod +x "$TEST_DIR/scripts/scanners/"*.sh
    fi
    
    # Create mock common functions
    cat > "$TEST_DIR/scripts/common-functions.sh" << 'EOF'
#!/bin/bash
# Mock Common Functions for Testing

# Error severity levels
declare -A ERROR_LEVELS=(
    ["DEBUG"]=0
    ["INFO"]=1
    ["WARNING"]=2
    ["ERROR"]=3
    ["CRITICAL"]=4
)

# Color codes for output
declare -A COLORS=(
    ["DEBUG"]='\033[0;36m'
    ["INFO"]='\033[0;32m'
    ["WARNING"]='\033[1;33m'
    ["ERROR"]='\033[0;31m'
    ["CRITICAL"]='\033[1;31m'
    ["NC"]='\033[0m'
)

# Mock logging functions
log_debug() { echo -e "${COLORS[DEBUG]}[DEBUG] $1${COLORS[NC]}"; }
log_info() { echo -e "${COLORS[INFO]}[INFO] $1${COLORS[NC]}"; }
log_warning() { echo -e "${COLORS[WARNING]}[WARNING] $1${COLORS[NC]}"; }
log_error() { echo -e "${COLORS[ERROR]}[ERROR] $1${COLORS[NC]}"; }
log_critical() { echo -e "${COLORS[CRITICAL]}[CRITICAL] $1${COLORS[NC]}"; }
log_success() { echo -e "${COLORS[INFO]}[SUCCESS] $1${COLORS[NC]}"; }

# Mock notification function
send_notification() {
    local title="$1"
    local message="$2"
    local urgency="$3"
    local expiry="$4"
    
    if [ "$NOTIFICATIONS_ENABLED" = true ]; then
        echo "NOTIFICATION: $title - $message"
    fi
}

# Mock path validation
validate_path() {
    local path="$1"
    local error_message="${2:-Invalid path format}"
    
    if [[ ! "$path" =~ ^/ ]]; then
        echo "Error: $error_message: Path must be absolute"
        return 1
    fi
    
    if [[ "$path" =~ \.\. ]]; then
        echo "Error: $error_message: Path cannot contain parent directory references"
        return 1
    fi
    
    return 0
}

# Mock systemd service generation
generate_systemd_service() {
    local service_name="$1"
    local script_path="$2"
    local service_file="$CURRENT_HOME/.config/systemd/user/${service_name}.service"
    
    mkdir -p "$(dirname "$service_file")"
    
    cat > "$service_file" <<EOFSERVICE
[Unit]
Description=${service_name%.*}
After=network-online.target

[Service]
Type=oneshot
ExecStart=$script_path
WorkingDirectory=$(dirname "$script_path")
StandardOutput=journal
StandardError=journal
Environment=USER=$CURRENT_USER
Environment=HOME=$CURRENT_HOME

[Install]
WantedBy=default.target
EOFSERVICE
    
    chmod 644 "$service_file" 2>/dev/null || true
    
    # Make mock scripts executable
    if [ -f "$TEST_DIR/scripts/common-functions.sh" ]; then
        chmod +x "$TEST_DIR/scripts/common-functions.sh"
    fi
    if [ -d "$TEST_DIR/scripts/scanners/" ]; then
        find "$TEST_DIR/scripts/scanners/" -name "*.sh" -exec chmod +x {} \;
    fi
    
    return 0
}
# Test environment cleanup
cleanup_test_environment() {
    # Restore original environment
    export HOME="$ORIGINAL_HOME"
    
    # Remove test directory
    if [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
    
    # Clean up any background processes
    jobs -p | xargs -r kill 2>/dev/null
}

# Mock external commands for testing
mock_external_commands() {
    # Create mock directory for external commands
    local mock_bin="$TEST_DIR/bin"
    mkdir -p "$mock_bin"
    
    # Add mock bin to PATH
    export PATH="$mock_bin:$PATH"
    
    # Mock clamscan
    cat > "$mock_bin/clamscan" << 'EOF'
#!/bin/bash
# Mock clamscan command
for arg in "$@"; do
    if [ -f "$arg" ] && grep -q "EICAR" "$arg"; then
        echo "$arg: Eicar-Test-Signature FOUND"
        exit 1
    fi
done
echo "Mock scan completed"
exit 0
EOF
    
    # Mock rkhunter
    cat > "$mock_bin/rkhunter" << 'EOF'
#!/bin/bash
# Mock rkhunter command
echo "Mock rkhunter scan completed"
exit 0
EOF
    
    # Mock freshclam
    cat > "$mock_bin/freshclam" << 'EOF'
#!/bin/bash
# Mock freshclam command
echo "Mock virus definitions updated"
exit 0
EOF
    
    # Mock systemctl
    cat > "$mock_bin/systemctl" << 'EOF'
#!/bin/bash
# Mock systemctl command
echo "Mock systemctl command executed: $*"
exit 0
EOF
    
    # Mock loginctl
    cat > "$mock_bin/loginctl" << 'EOF'
#!/bin/bash
# Mock loginctl command
echo "Mock loginctl command executed: $*"
exit 0
EOF
    
    # Mock notify-send
    cat > "$mock_bin/notify-send" << 'EOF'
#!/bin/bash
# Mock notify-send command
echo "Mock notification sent: $*"
exit 0
EOF
    
    # Make all mock commands executable
    if [ -d "$mock_bin" ] && [ -n "$(ls -A "$mock_bin" 2>/dev/null)" ]; then
        chmod +x "$mock_bin"/*
    fi
}

# Check if BATS is available
check_bats() {
    if ! command -v bats &> /dev/null; then
        echo "Error: BATS (Bash Automated Testing System) is not installed"
        echo "Install BATS with: sudo pacman -S bats"
        echo "Or download from: https://github.com/bats-core/bats-core"
        return 1
    fi
    return 0
}

# Run shellcheck on scripts
run_shellcheck() {
    local script_dir="$1"
    local exit_code=0
    
    if command -v shellcheck &> /dev/null; then
        echo "Running shellcheck on scripts..."
        find "$script_dir" -name "*.sh" -exec shellcheck {} \; || exit_code=$?
        
        if [ $exit_code -eq 0 ]; then
            echo "Shellcheck passed - No issues found"
        else
            echo "Shellcheck found issues - See output above"
        fi
    else
        echo "Shellcheck not available - Skipping static analysis"
    fi
    
    return $exit_code
}

# Generate test coverage report
generate_coverage_report() {
    local test_results="$1"
    local coverage_file="$TEST_DIR/coverage-report.txt"
    
    echo "=== Test Coverage Report ===" > "$coverage_file"
    echo "Generated: $(date)" >> "$coverage_file"
    echo "" >> "$coverage_file"
    
    # Count total tests
    local total_tests=$(grep -c "^ok\|^not ok" "$test_results" 2>/dev/null || echo "0")
    local passed_tests=$(grep -c "^ok" "$test_results" 2>/dev/null || echo "0")
    local failed_tests=$(grep -c "^not ok" "$test_results" 2>/dev/null || echo "0")
    
    echo "Total Tests: $total_tests" >> "$coverage_file"
    echo "Passed: $passed_tests" >> "$coverage_file"
    echo "Failed: $failed_tests" >> "$coverage_file"
    
    if [ "$total_tests" -gt 0 ]; then
        local coverage_percent=$((passed_tests * 100 / total_tests))
        echo "Coverage: ${coverage_percent}%" >> "$coverage_file"
    fi
    
    echo "" >> "$coverage_file"
    echo "=== Test Details ===" >> "$coverage_file"
    cat "$test_results" >> "$coverage_file" 2>/dev/null
    
    echo "Coverage report generated: $coverage_file"
}

# Performance monitoring helpers
start_memory_monitor() {
    local monitor_file="$TEST_DIR/memory-monitor.log"
    echo "Starting memory monitoring..." > "$monitor_file"
    
    (
        while true; do
            local memory_usage=$(free -m | awk 'NR==2{print $3}')
            local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
            echo "$timestamp,$memory_usage" >> "$monitor_file"
            sleep 1
        done
    ) &
    
    echo $! > "$TEST_DIR/memory-monitor.pid"
}

stop_memory_monitor() {
    if [ -f "$TEST_DIR/memory-monitor.pid" ]; then
        local pid=$(cat "$TEST_DIR/memory-monitor.pid")
        kill "$pid" 2>/dev/null
        rm -f "$TEST_DIR/memory-monitor.pid"
    fi
}

get_max_memory_usage() {
    local monitor_file="$TEST_DIR/memory-monitor.log"
    if [ -f "$monitor_file" ]; then
        awk -F',' 'NR>1 && $2>max {max=$2} END {print max+0}' "$monitor_file"
    else
        echo "0"
    fi
}

# Export helper functions
export -f setup_test_environment
export -f cleanup_test_environment
export -f mock_external_commands
export -f check_bats
export -f run_shellcheck
export -f generate_coverage_report
export -f start_memory_monitor
export -f stop_memory_monitor
export -f get_max_memory_usage
