#!/usr/bin/env bats
# Performance Tests for Resource Usage
# Following Phase 1 implementation plans (lines 1802-1857)

load "test-helper"

setup() {
    setup_test_environment
    mock_external_commands
}

teardown() {
    cleanup_test_environment
}

@test "memory usage stays within limits" {
    setup_test_environment
    
    # Monitor memory usage during scan
    local memory_before=$(free -m | awk 'NR==2{print $3}')
    
    # Start memory monitoring
    start_memory_monitor
    
    # Create mock daily scan script that simulates memory usage
    cat > "$TEST_DIR/scripts/security-daily-scan.sh" << 'EOF'
#!/bin/bash
# Mock Daily Security Scan Script with Memory Simulation

SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/../configs/security-config.conf"
source "$SCRIPT_DIR/common-functions.sh"

# Simulate memory usage during scan
simulate_memory_usage() {
    # Create some data to simulate memory usage
    local temp_data=""
    for i in {1..1000}; do
        temp_data+="This is test data to simulate memory usage during security scan $i\n"
    done
    
    # Simulate processing time
    sleep 2
    
    # Clean up
    unset temp_data
}

log_info "Starting security scan with memory monitoring"
simulate_memory_usage
log_info "Security scan completed"

exit 0
EOF
    
    chmod +x "$TEST_DIR/scripts/security-daily-scan.sh"
    
    # Run scan
    "$TEST_DIR/scripts/security-daily-scan.sh" &
    local scan_pid=$!
    
    # Monitor memory during scan
    local max_memory=0
    while kill -0 $scan_pid 2>/dev/null; do
        local current_memory=$(free -m | awk 'NR==2{print $3}')
        [ "$current_memory" -gt "$max_memory" ] && max_memory=$current_memory
        sleep 0.5
    done
    
    wait $scan_pid
    local memory_after=$(free -m | awk 'NR==2{print $3}')
    
    # Stop memory monitoring
    stop_memory_monitor
    
    # Memory usage should be reasonable (less than 500MB increase)
    local memory_increase=$((max_memory - memory_before))
    [ "$memory_increase" -lt 500 ]
    
    # Also check our monitor
    local monitored_memory=$(get_max_memory_usage)
    [ "$monitored_memory" -lt 500 ]
    
    cleanup_test_environment
}

@test "disk space usage is reasonable" {
    setup_test_environment
    
    local disk_before=$(du -sm "$TEST_DIR" | cut -f1)
    
    # Create mock daily scan script that generates logs
    cat > "$TEST_DIR/scripts/security-daily-scan.sh" << 'EOF'
#!/bin/bash
# Mock Daily Security Scan Script with Log Generation

SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/../configs/security-config.conf"
source "$SCRIPT_DIR/common-functions.sh"

SCAN_TYPE="daily"
LOG_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Initialize scan log
SCAN_LOG="$LOGS_DIR/daily/security_scan_${LOG_TIMESTAMP}.log"
echo "Daily Security Scan - $(date)" > "$SCAN_LOG"
echo "=============================" >> "$SCAN_LOG"

# Generate some log content
for i in {1..100}; do
    echo "Scan entry $i: Processing file for security analysis" >> "$SCAN_LOG"
    echo "Scan result $i: No threats detected in file $i" >> "$SCAN_LOG"
done

echo "=== DAILY SCAN SUMMARY ===" >> "$SCAN_LOG"
echo "Overall Status: 0" >> "$SCAN_LOG"
echo "Scan Duration: 5s" >> "$SCAN_LOG"
echo "Scan Completed: $(date)" >> "$SCAN_LOG"

# Create scanner-specific logs
CLAMAV_LOG="$LOGS_DIR/daily/clamav_${LOG_TIMESTAMP}.log"
echo "ClamAV Scan Log - $(date)" > "$CLAMAV_LOG"
echo "=========================" >> "$CLAMAV_LOG"

for i in {1..50}; do
    echo "Scanning file $i: Clean" >> "$CLAMAV_LOG"
done

echo "=== SCAN SUMMARY ===" >> "$CLAMAV_LOG"
echo "Scan Duration: 3s" >> "$CLAMAV_LOG"
echo "Infected Files: 0" >> "$CLAMAV_LOG"
echo "Exit Code: 0" >> "$CLAMAV_LOG"
echo "Scan Completed: $(date)" >> "$CLAMAV_LOG"

log_info "Daily security scan completed - Log: $SCAN_LOG"

exit 0
EOF
    
    chmod +x "$TEST_DIR/scripts/security-daily-scan.sh"
    
    # Run scan
    run "$TEST_DIR/scripts/security-daily-scan.sh"
    
    [ "$status" -eq 0 ]
    
    local disk_after=$(du -sm "$TEST_DIR" | cut -f1)
    local log_size=$(du -sm "$TEST_LOGS_DIR" | cut -f1)
    
    # Log size should be reasonable (less than 10MB)
    [ "$log_size" -lt 10 ]
    
    # Total disk usage should be reasonable
    local disk_increase=$((disk_after - disk_before))
    [ "$disk_increase" -lt 15 ]
    
    cleanup_test_environment
}

@test "scan completion within expected timeframes" {
    setup_test_environment
    
    # Create mock daily scan script with timing
    cat > "$TEST_DIR/scripts/security-daily-scan.sh" << 'EOF'
#!/bin/bash
# Mock Daily Security Scan Script with Timing

SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/../configs/security-config.conf"
source "$SCRIPT_DIR/common-functions.sh"

# Record start time
scan_start=$(date +%s)

log_info "Starting daily security scan"

# Simulate scan work (should complete quickly)
for i in {1..10}; do
    log_info "Processing scan item $i"
    sleep 0.1  # Simulate minimal work
done

# Record end time
scan_end=$(date +%s)
scan_duration=$((scan_end - scan_start))

log_info "Daily scan completed in ${scan_duration} seconds"

# Daily scan should complete within 60 seconds
if [ "$scan_duration" -gt 60 ]; then
    log_error "Daily scan exceeded time limit: ${scan_duration}s > 60s"
    exit 1
fi

exit 0
EOF
    
    chmod +x "$TEST_DIR/scripts/security-daily-scan.sh"
    
    # Time the scan execution
    local start_time=$(date +%s)
    
    run "$TEST_DIR/scripts/security-daily-scan.sh"
    
    local end_time=$(date +%s)
    local execution_time=$((end_time - start_time))
    
    [ "$status" -eq 0 ]
    [ "$execution_time" -lt 60 ]
    
    cleanup_test_environment
}

@test "concurrent scan performance" {
    setup_test_environment
    
    # Create mock scan script that can run concurrently
    cat > "$TEST_DIR/scripts/security-scan.sh" << 'EOF'
#!/bin/bash
# Mock Security Scan Script for Concurrent Testing

SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/../configs/security-config.conf"
source "$SCRIPT_DIR/common-functions.sh"

SCAN_TYPE="$1"
SCAN_ID="$2"

log_info "Starting $SCAN_TYPE scan (ID: $SCAN_ID)"

# Simulate scan work
for i in {1..5}; do
    log_info "$SCAN_TYPE scan $SCAN_ID: Processing item $i"
    sleep 0.2
done

log_info "Completed $SCAN_TYPE scan (ID: $SCAN_ID)"

exit 0
EOF
    
    chmod +x "$TEST_DIR/scripts/security-scan.sh"
    
    # Start multiple concurrent scans
    local start_time=$(date +%s)
    
    "$TEST_DIR/scripts/security-scan.sh" "daily" "1" &
    local pid1=$!
    
    "$TEST_DIR/scripts/security-scan.sh" "weekly" "1" &
    local pid2=$!
    
    "$TEST_DIR/scripts/security-scan.sh" "monthly" "1" &
    local pid3=$!
    
    # Wait for all scans to complete
    wait $pid1
    local status1=$?
    
    wait $pid2
    local status2=$?
    
    wait $pid3
    local status3=$?
    
    local end_time=$(date +%s)
    local total_time=$((end_time - start_time))
    
    # All scans should complete successfully
    [ "$status1" -eq 0 ]
    [ "$status2" -eq 0 ]
    [ "$status3" -eq 0 ]
    
    # Concurrent scans should complete within reasonable time
    [ "$total_time" -lt 30 ]
    
    cleanup_test_environment
}

@test "resource cleanup after scan completion" {
    setup_test_environment
    
    # Create mock scan script that creates temporary files
    cat > "$TEST_DIR/scripts/security-daily-scan.sh" << 'EOF'
#!/bin/bash
# Mock Daily Security Scan Script with Resource Cleanup

SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/../configs/security-config.conf"
source "$SCRIPT_DIR/common-functions.sh"

# Create temporary files and processes
TEMP_DIR="$TEST_DIR/temp_$$"
mkdir -p "$TEMP_DIR"

# Create some temporary data
for i in {1..10}; do
    echo "Temporary data $i" > "$TEMP_DIR/temp_$i.txt"
done

# Start a background process (that we'll clean up)
(
    sleep 5
    echo "Background process completed"
) &
bg_pid=$!

log_info "Starting scan with temporary resources"

# Simulate scan work
sleep 1

log_info "Cleaning up temporary resources"

# Clean up temporary files
rm -rf "$TEMP_DIR"

# Clean up background process
kill $bg_pid 2>/dev/null
wait $bg_pid 2>/dev/null

log_info "Resource cleanup completed"

exit 0
EOF
    
    chmod +x "$TEST_DIR/scripts/security-daily-scan.sh"
    
    # Count processes before scan
    local processes_before=$(ps aux | grep -c "security-scan")
    
    # Run scan
    run "$TEST_DIR/scripts/security-daily-scan.sh"
    
    [ "$status" -eq 0 ]
    
    # Wait a moment for cleanup
    sleep 2
    
    # Count processes after scan
    local processes_after=$(ps aux | grep -c "security-scan")
    
    # Should not have leftover processes
    [ "$processes_after" -le "$processes_before" ]
    
    # Should not have leftover temporary files
    [ ! -d "$TEST_DIR/temp_"* ]
    
    cleanup_test_environment
}

@test "performance under load" {
    setup_test_environment
    
    # Create mock scan script that handles load
    cat > "$TEST_DIR/scripts/security-daily-scan.sh" << 'EOF'
#!/bin/bash
# Mock Daily Security Scan Script with Load Testing

SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/../configs/security-config.conf"
source "$SCRIPT_DIR/common-functions.sh"

# Record start time
scan_start=$(date +%s)

log_info "Starting scan under load simulation"

# Simulate system load by creating multiple processes
for i in {1..5}; do
    (
        # Simulate work
        for j in {1..10}; do
            echo "Load simulation process $i, iteration $j" >/dev/null
            sleep 0.1
        done
    ) &
done

# Wait for background processes
wait

# Continue with scan
for i in {1..20}; do
    log_info "Processing scan item $i under load"
    sleep 0.05
done

# Record end time
scan_end=$(date +%s)
scan_duration=$((scan_end - scan_start))

log_info "Scan under load completed in ${scan_duration} seconds"

# Scan should still complete within reasonable time even under load
if [ "$scan_duration" -gt 120 ]; then
    log_error "Scan under load exceeded time limit: ${scan_duration}s > 120s"
    exit 1
fi

exit 0
EOF
    
    chmod +x "$TEST_DIR/scripts/security-daily-scan.sh"
    
    # Start memory monitoring
    start_memory_monitor
    
    # Time the scan execution under load
    local start_time=$(date +%s)
    
    run "$TEST_DIR/scripts/security-daily-scan.sh"
    
    local end_time=$(date +%s)
    local execution_time=$((end_time - start_time))
    
    # Stop memory monitoring
    stop_memory_monitor
    
    [ "$status" -eq 0 ]
    [ "$execution_time" -lt 120 ]
    
    # Memory usage should still be reasonable under load
    local max_memory=$(get_max_memory_usage)
    [ "$max_memory" -lt 500 ]
    
    cleanup_test_environment
}

@test "log rotation performance" {
    setup_test_environment
    
    # Create mock scan script that generates many logs
    cat > "$TEST_DIR/scripts/security-daily-scan.sh" << 'EOF'
#!/bin/bash
# Mock Daily Security Scan Script with Log Generation

SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/../configs/security-config.conf"
source "$SCRIPT_DIR/common-functions.sh"

SCAN_TYPE="daily"
LOG_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Generate multiple log files to test rotation performance
for log_num in {1..5}; do
    SCAN_LOG="$LOGS_DIR/daily/security_scan_${LOG_TIMESTAMP}_${log_num}.log"
    echo "Daily Security Scan $log_num - $(date)" > "$SCAN_LOG"
    echo "=============================" >> "$SCAN_LOG"
    
    # Generate substantial log content
    for i in {1..200}; do
        echo "Scan entry $i: Processing file for security analysis in log $log_num" >> "$SCAN_LOG"
        echo "Detailed scan information for file $i with extensive data to simulate real log content" >> "$SCAN_LOG"
        echo "Scan result $i: No threats detected in file $i after comprehensive analysis" >> "$SCAN_LOG"
        echo "Additional metadata for scan entry $i including timestamps and resource usage" >> "$SCAN_LOG"
    done
    
    echo "=== SCAN SUMMARY ===" >> "$SCAN_LOG"
    echo "Overall Status: 0" >> "$SCAN_LOG"
    echo "Scan Duration: 10s" >> "$SCAN_LOG"
    echo "Files Scanned: 200" >> "$SCAN_LOG"
    echo "Threats Found: 0" >> "$SCAN_LOG"
    echo "Scan Completed: $(date)" >> "$SCAN_LOG"
done

log_info "Generated 5 log files for rotation testing"

exit 0
EOF
    
    chmod +x "$TEST_DIR/scripts/security-daily-scan.sh"
    
    # Measure disk space before
    local disk_before=$(du -sm "$TEST_LOGS_DIR" | cut -f1)
    
    # Time the log generation
    local start_time=$(date +%s)
    
    run "$TEST_DIR/scripts/security-daily-scan.sh"
    
    local end_time=$(date +%s)
    local execution_time=$((end_time - start_time))
    
    # Measure disk space after
    local disk_after=$(du -sm "$TEST_LOGS_DIR" | cut -f1)
    local log_size=$((disk_after - disk_before))
    
    [ "$status" -eq 0 ]
    
    # Log generation should be efficient
    [ "$execution_time" -lt 30 ]
    
    # Log size should be reasonable even with multiple files
    [ "$log_size" -lt 10 ]
    
    # Check that all log files were created
    local log_count=$(find "$TEST_LOGS_DIR/daily" -name "security_scan_*.log" | wc -l)
    [ "$log_count" -eq 5 ]
    
    cleanup_test_environment
}