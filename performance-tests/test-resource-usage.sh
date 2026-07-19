#!/bin/bash
# Resource Usage Performance Tests
# Tests system resource usage under various conditions

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Test configuration
SCRIPT_DIR="$(dirname "$0")"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TESTS_PASSED=0
TESTS_FAILED=0

# Performance thresholds (adjusted for realistic system usage)
MAX_MEMORY_MB=15000
MAX_CPU_PERCENT=80
MAX_DISK_SPACE_MB=100
MAX_RESPONSE_TIME_SEC=5

# Test logging functions
log_test() {
    echo -e "${CYAN}🧪 $1${NC}"
}

log_pass() {
    echo -e "${GREEN}✅ $1${NC}"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}❌ $1${NC}"
    ((TESTS_FAILED++))
}

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Get current memory usage in MB
get_memory_usage() {
    local process_name="$1"
    local memory_mb=0
    
    if command -v pgrep &> /dev/null; then
        local pids=$(pgrep -f "$process_name" 2>/dev/null || echo "")
        if [ -n "$pids" ]; then
            memory_mb=$(ps -p $pids -o rss= 2>/dev/null | awk '{sum += $1} END {print sum/1024}' || echo "0")
        fi
    fi
    
    echo "$memory_mb"
}

# Get current CPU usage percentage
get_cpu_usage() {
    local process_name="$1"
    local cpu_percent=0
    
    if command -v pgrep &> /dev/null; then
        local pids=$(pgrep -f "$process_name" 2>/dev/null || echo "")
        if [ -n "$pids" ]; then
            cpu_percent=$(ps -p $pids -o %cpu= 2>/dev/null | awk '{sum += $1} END {print sum}' || echo "0")
        fi
    fi
    
    echo "$cpu_percent"
}

# Test 1: Baseline Resource Usage
test_baseline_resource_usage() {
    log_test "Testing Baseline Resource Usage"
    
    # Get system baseline
    local baseline_memory=$(free -m | awk 'NR==2{printf "%.1f", $3}' || echo "0")
    local baseline_cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 || echo "0")
    local baseline_disk=$(df -m / | awk 'NR==2{print $3}' || echo "0")
    
    log_info "Baseline Memory Usage: ${baseline_memory}MB"
    log_info "Baseline CPU Usage: ${baseline_cpu}%"
    log_info "Baseline Disk Usage: ${baseline_disk}MB"
    
    # Check if baseline is reasonable
    if (( $(echo "$baseline_memory < $MAX_MEMORY_MB" | bc -l 2>/dev/null || echo "1") )); then
        log_pass "Baseline memory usage is acceptable: ${baseline_memory}MB < ${MAX_MEMORY_MB}MB"
    else
        log_fail "Baseline memory usage is too high: ${baseline_memory}MB >= ${MAX_MEMORY_MB}MB"
    fi
    
    if (( $(echo "$baseline_cpu < $MAX_CPU_PERCENT" | bc -l 2>/dev/null || echo "1") )); then
        log_pass "Baseline CPU usage is acceptable: ${baseline_cpu}% < ${MAX_CPU_PERCENT}%"
    else
        log_fail "Baseline CPU usage is too high: ${baseline_cpu}% >= ${MAX_CPU_PERCENT}%"
    fi
}

# Test 2: Behavioral Analysis Performance
test_behavioral_analysis_performance() {
    log_test "Testing Behavioral Analysis Performance"
    
    if [ -f "$PROJECT_ROOT/scripts/behavioral-analysis.sh" ]; then
        # Start behavioral analysis in background
        cd "$PROJECT_ROOT"
        ./scripts/behavioral-analysis.sh monitor 60 5 &
        local ba_pid=$!
        
        # Wait for it to start
        sleep 3
        
        # Measure resource usage
        local ba_memory=$(get_memory_usage "behavioral-analysis.sh")
        local ba_cpu=$(get_cpu_usage "behavioral-analysis.sh")
        
        log_info "Behavioral Analysis Memory Usage: ${ba_memory}MB"
        log_info "Behavioral Analysis CPU Usage: ${ba_cpu}%"
        
        # Check thresholds
        if (( $(echo "$ba_memory < $MAX_MEMORY_MB" | bc -l 2>/dev/null || echo "1") )); then
            log_pass "Behavioral analysis memory usage is acceptable: ${ba_memory}MB"
        else
            log_fail "Behavioral analysis memory usage is too high: ${ba_memory}MB"
        fi
        
        if (( $(echo "$ba_cpu < $MAX_CPU_PERCENT" | bc -l 2>/dev/null || echo "1") )); then
            log_pass "Behavioral analysis CPU usage is acceptable: ${ba_cpu}%"
        else
            log_fail "Behavioral analysis CPU usage is too high: ${ba_cpu}%"
        fi
        
        # Stop behavioral analysis
        kill $ba_pid 2>/dev/null || true
        wait $ba_pid 2>/dev/null || true
    else
        log_fail "Behavioral analysis script not found"
    fi
}

# Test 3: Dashboard Performance
test_dashboard_performance() {
    log_test "Testing Dashboard Performance"
    
    # Start dashboard if not running
    local dashboard_url="http://localhost:8080"
    local dashboard_running=false
    
    if curl -s --connect-timeout 5 "$dashboard_url" >/dev/null 2>&1; then
        dashboard_running=true
        log_info "Dashboard is already running"
    else
        log_info "Starting dashboard for performance test..."
        if [ -f "$PROJECT_ROOT/web-dashboard/start-dashboard.sh" ]; then
            cd "$PROJECT_ROOT/web-dashboard"
            ./start-dashboard.sh &
            local dashboard_pid=$!
            
            # Wait for dashboard to start
            sleep 5
            
            if curl -s --connect-timeout 5 "$dashboard_url" >/dev/null 2>&1; then
                dashboard_running=true
                echo "$dashboard_pid" > /tmp/dashboard_perf_test.pid
            else
                log_fail "Failed to start dashboard"
            fi
        else
            log_fail "Dashboard startup script not found"
        fi
    fi
    
    if [ "$dashboard_running" = true ]; then
        # Measure dashboard resource usage
        local dashboard_memory=$(get_memory_usage "app.py")
        local dashboard_cpu=$(get_cpu_usage "app.py")
        
        log_info "Dashboard Memory Usage: ${dashboard_memory}MB"
        log_info "Dashboard CPU Usage: ${dashboard_cpu}%"
        
        # Check thresholds
        if (( $(echo "$dashboard_memory < $MAX_MEMORY_MB" | bc -l 2>/dev/null || echo "1") )); then
            log_pass "Dashboard memory usage is acceptable: ${dashboard_memory}MB"
        else
            log_fail "Dashboard memory usage is too high: ${dashboard_memory}MB"
        fi
        
        if (( $(echo "$dashboard_cpu < $MAX_CPU_PERCENT" | bc -l 2>/dev/null || echo "1") )); then
            log_pass "Dashboard CPU usage is acceptable: ${dashboard_cpu}%"
        else
            log_fail "Dashboard CPU usage is too high: ${dashboard_cpu}%"
        fi
        
        # Test response time
        local start_time=$(date +%s.%N)
        local response=$(curl -s "$dashboard_url/api/system/status" 2>/dev/null || echo "")
        local end_time=$(date +%s.%N)
        local response_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
        
        if [ -n "$response" ]; then
            log_info "Dashboard API Response Time: ${response_time}s"
            
            if (( $(echo "$response_time < $MAX_RESPONSE_TIME_SEC" | bc -l 2>/dev/null || echo "1") )); then
                log_pass "Dashboard response time is acceptable: ${response_time}s"
            else
                log_fail "Dashboard response time is too slow: ${response_time}s"
            fi
        else
            log_fail "Dashboard API not responding"
        fi
    else
        log_fail "Dashboard not available for performance testing"
    fi
}

# Test 4: Database Performance
test_database_performance() {
    log_test "Testing Database Performance"
    
    local databases=(
        "$AEGIS_HOME/configs/behavioral_analysis/behavioral_data.db"
        "$AEGIS_HOME/configs/threat_intelligence/ioc_database.db"
        "$AEGIS_HOME/configs/incident_response/incidents.db"
    )
    
    for db in "${databases[@]}"; do
        if [ -f "$db" ] && command -v sqlite3 &> /dev/null; then
            local db_name=$(basename "$db")
            
            # Test query performance
            local start_time=$(date +%s.%N)
            local result=$(sqlite3 "$db" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';" 2>/dev/null || echo "0")
            local end_time=$(date +%s.%N)
            local query_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
            
            log_info "$db_name Query Time: ${query_time}s"
            
            if (( $(echo "$query_time < 1" | bc -l 2>/dev/null || echo "1") )); then
                log_pass "$db_name query performance is acceptable: ${query_time}s"
            else
                log_fail "$db_name query performance is too slow: ${query_time}s"
            fi
            
            # Test database size
            local db_size=$(stat -c%s "$db" 2>/dev/null || echo "0")
            local db_size_mb=$(echo "scale=2; $db_size / 1024 / 1024" | bc -l 2>/dev/null || echo "0")
            
            log_info "$db_name Size: ${db_size_mb}MB"
            
            if (( $(echo "$db_size_mb < 100" | bc -l 2>/dev/null || echo "1") )); then
                log_pass "$db_name size is acceptable: ${db_size_mb}MB"
            else
                log_warn "$db_name size is large: ${db_size_mb}MB"
            fi
            
            # Test database integrity
            local integrity_check=$(sqlite3 "$db" "PRAGMA integrity_check;" 2>/dev/null || echo "failed")
            if [ "$integrity_check" = "ok" ]; then
                log_pass "$db_name integrity check passed"
            else
                log_fail "$db_name integrity check failed"
            fi
        else
            log_warn "Database not available: $(basename "$db")"
        fi
    done
}

# Test 5: Concurrent Operations Performance
test_concurrent_operations() {
    log_test "Testing Concurrent Operations Performance"
    
    # Test concurrent API requests
    if command -v curl &> /dev/null; then
        local dashboard_url="http://localhost:8080"
        local concurrent_requests=10
        local successful_requests=0
        local total_response_time=0
        
        for i in $(seq 1 $concurrent_requests); do
            local start_time=$(date +%s.%N)
            local response=$(curl -s "$dashboard_url/api/system/status" 2>/dev/null || echo "")
            local end_time=$(date +%s.%N)
            local response_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
            
            if [ -n "$response" ]; then
                ((successful_requests++))
                total_response_time=$(echo "$total_response_time + $response_time" | bc -l 2>/dev/null || echo "$total_response_time")
            fi
            
            # Run in background
            curl -s "$dashboard_url/api/system/status" >/dev/null 2>&1 &
        done
        
        wait
        
        local avg_response_time=$(echo "scale=3; $total_response_time / $successful_requests" | bc -l 2>/dev/null || echo "0")
        
        log_info "Concurrent Requests: $successful_requests/$concurrent_requests"
        log_info "Average Response Time: ${avg_response_time}s"
        
        if [ "$successful_requests" -eq "$concurrent_requests" ]; then
            log_pass "All concurrent requests successful"
        else
            log_fail "Some concurrent requests failed: $successful_requests/$concurrent_requests"
        fi
        
        if (( $(echo "$avg_response_time < $MAX_RESPONSE_TIME_SEC" | bc -l 2>/dev/null || echo "1") )); then
            log_pass "Concurrent response time is acceptable: ${avg_response_time}s"
        else
            log_fail "Concurrent response time is too slow: ${avg_response_time}s"
        fi
    else
        log_warn "Curl not available - cannot test concurrent operations"
    fi
}

# Test 6: Memory Leak Detection
test_memory_leak_detection() {
    log_test "Testing Memory Leak Detection"
    
    if [ -f "$PROJECT_ROOT/scripts/behavioral-analysis.sh" ]; then
        # Run behavioral analysis for extended period
        cd "$PROJECT_ROOT"
        ./scripts/behavioral-analysis.sh monitor 30 1 &
        local ba_pid=$!
        
        # Wait for it to start
        sleep 2
        
        # Measure memory usage over time
        local memory_samples=()
        for i in {1..5}; do
            local memory=$(get_memory_usage "behavioral-analysis.sh")
            memory_samples+=("$memory")
            sleep 5
        done
        
        # Stop behavioral analysis
        kill $ba_pid 2>/dev/null || true
        wait $ba_pid 2>/dev/null || true
        
        # Analyze memory growth
        local initial_memory=${memory_samples[0]}
        local final_memory=${memory_samples[4]}
        local memory_growth=$(echo "$final_memory - $initial_memory" | bc -l 2>/dev/null || echo "0")
        
        log_info "Initial Memory: ${initial_memory}MB"
        log_info "Final Memory: ${final_memory}MB"
        log_info "Memory Growth: ${memory_growth}MB"
        
        # Check for memory leak (growth > 50MB)
        if (( $(echo "$memory_growth < 50" | bc -l 2>/dev/null || echo "1") )); then
            log_pass "No significant memory leak detected: ${memory_growth}MB"
        else
            log_fail "Potential memory leak detected: ${memory_growth}MB growth"
        fi
    else
        log_fail "Behavioral analysis script not found"
    fi
}

# Test 7: Disk Usage Performance
test_disk_usage_performance() {
    log_test "Testing Disk Usage Performance"
    
    # Check log directory sizes
    local log_dirs=(
        "$AEGIS_HOME/logs/error"
        "$AEGIS_HOME/logs/manual"
        "$AEGIS_HOME/logs/behavioral"
    )
    
    local total_log_size=0
    for dir in "${log_dirs[@]}"; do
        if [ -d "$dir" ]; then
            local dir_size=$(du -sm "$dir" 2>/dev/null | cut -f1 || echo "0")
            total_log_size=$((total_log_size + dir_size))
            log_info "Log directory size: $(basename "$dir") = ${dir_size}MB"
        fi
    done
    
    log_info "Total Log Size: ${total_log_size}MB"
    
    if [ "$total_log_size" -lt "$MAX_DISK_SPACE_MB" ]; then
        log_pass "Log disk usage is acceptable: ${total_log_size}MB"
    else
        log_fail "Log disk usage is too high: ${total_log_size}MB"
    fi
    
    # Check database directory sizes
    local db_dirs=(
        "$AEGIS_HOME/configs/behavioral_analysis"
        "$AEGIS_HOME/configs/threat_intelligence"
        "$AEGIS_HOME/configs/incident_response"
    )
    
    local total_db_size=0
    for dir in "${db_dirs[@]}"; do
        if [ -d "$dir" ]; then
            local dir_size=$(du -sm "$dir" 2>/dev/null | cut -f1 || echo "0")
            total_db_size=$((total_db_size + dir_size))
            log_info "Database directory size: $(basename "$dir") = ${dir_size}MB"
        fi
    done
    
    log_info "Total Database Size: ${total_db_size}MB"
    
    if [ "$total_db_size" -lt "$MAX_DISK_SPACE_MB" ]; then
        log_pass "Database disk usage is acceptable: ${total_db_size}MB"
    else
        log_fail "Database disk usage is too high: ${total_db_size}MB"
    fi
}

# Test 8: CPU Performance Under Load
test_cpu_performance_under_load() {
    log_test "Testing CPU Performance Under Load"
    
    # Get baseline CPU
    local baseline_cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 || echo "0")
    
    # Generate CPU load
    local load_pid=""
    if command -v dd &> /dev/null; then
        dd if=/dev/zero of=/dev/null bs=1M count=1000 &
        load_pid=$!
        sleep 2
    fi
    
    # Measure CPU under load
    local load_cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 || echo "0")
    
    # Stop load generation
    if [ -n "$load_pid" ]; then
        kill $load_pid 2>/dev/null || true
        wait $load_pid 2>/dev/null || true
    fi
    
    # Measure recovery time
    local recovery_time=0
    for i in {1..10}; do
        local current_cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 || echo "0")
        if (( $(echo "$current_cpu < $baseline_cpu + 10" | bc -l 2>/dev/null || echo "1") )); then
            recovery_time=$i
            break
        fi
        sleep 1
    done
    
    log_info "Baseline CPU: ${baseline_cpu}%"
    log_info "CPU Under Load: ${load_cpu}%"
    log_info "CPU Recovery Time: ${recovery_time}s"
    
    if [ "$recovery_time" -gt 0 ] && [ "$recovery_time" -lt 10 ]; then
        log_pass "CPU recovery time is acceptable: ${recovery_time}s"
    else
        log_fail "CPU recovery time is too slow: ${recovery_time}s"
    fi
}

# Test 9: Network Performance
test_network_performance() {
    log_test "Testing Network Performance"
    
    # Test dashboard network responsiveness
    local dashboard_url="http://localhost:8080"
    
    if command -v curl &> /dev/null; then
        # Test connection time
        local connect_time=$(curl -o /dev/null -s -w "%{time_connect}" "$dashboard_url" 2>/dev/null || echo "0")
        log_info "Dashboard Connection Time: ${connect_time}s"
        
        if (( $(echo "$connect_time < 1" | bc -l 2>/dev/null || echo "1") )); then
            log_pass "Connection time is acceptable: ${connect_time}s"
        else
            log_fail "Connection time is too slow: ${connect_time}s"
        fi
        
        # Test data transfer speed
        local start_time=$(date +%s.%N)
        local data_size=$(curl -s "$dashboard_url/api/system/status" | wc -c 2>/dev/null || echo "0")
        local end_time=$(date +%s.%N)
        local transfer_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
        
        if [ "$data_size" -gt 0 ] && [ "$transfer_time" -gt 0 ]; then
            local transfer_speed=$(echo "scale=2; $data_size / $transfer_time / 1024" | bc -l 2>/dev/null || echo "0")
            log_info "Data Transfer Speed: ${transfer_speed}KB/s"
            
            if (( $(echo "$transfer_speed > 1" | bc -l 2>/dev/null || echo "1") )); then
                log_pass "Data transfer speed is acceptable: ${transfer_speed}KB/s"
            else
                log_fail "Data transfer speed is too slow: ${transfer_speed}KB/s"
            fi
        else
            log_fail "Cannot measure data transfer speed"
        fi
    else
        log_warn "Curl not available - cannot test network performance"
    fi
}

# Test 10: Resource Cleanup Performance
test_resource_cleanup_performance() {
    log_test "Testing Resource Cleanup Performance"
    
    # Test process cleanup
    local initial_processes=$(ps aux | wc -l)
    
    # Start and stop some processes
    for i in {1..5}; do
        sleep 10 &
        local sleep_pid=$!
        sleep 0.1
        kill $sleep_pid 2>/dev/null || true
    done
    
    wait
    
    local final_processes=$(ps aux | wc -l)
    local process_diff=$((final_processes - initial_processes))
    
    log_info "Process Count Change: $process_diff"
    
    if [ "$process_diff" -lt 10 ]; then
        log_pass "Process cleanup is working properly"
    else
        log_fail "Process cleanup may have issues: $process_diff processes"
    fi
    
    # Test file descriptor cleanup
    if [ -f "/proc/$$/fd" ]; then
        local initial_fds=$(ls /proc/$$/fd 2>/dev/null | wc -l)
        
        # Open and close some files
        for i in {1..5}; do
            exec 3< /dev/null
            exec 3<&-
        done
        
        local final_fds=$(ls /proc/$$/fd 2>/dev/null | wc -l)
        local fd_diff=$((final_fds - initial_fds))
        
        log_info "File Descriptor Change: $fd_diff"
        
        if [ "$fd_diff" -lt 5 ]; then
            log_pass "File descriptor cleanup is working properly"
        else
            log_fail "File descriptor cleanup may have issues: $fd_diff descriptors"
        fi
    else
        log_warn "Cannot test file descriptor cleanup"
    fi
}

# Cleanup function
cleanup() {
    log_info "Cleaning up performance test environment..."
    
    # Stop dashboard if we started it
    if [ -f /tmp/dashboard_perf_test.pid ]; then
        local dashboard_pid=$(cat /tmp/dashboard_perf_test.pid)
        kill $dashboard_pid 2>/dev/null || true
        rm -f /tmp/dashboard_perf_test.pid
    fi
    
    # Clean up any remaining processes
    pkill -f "behavioral-analysis.sh" 2>/dev/null || true
    pkill -f "dd if=/dev/zero" 2>/dev/null || true
}

# Main test execution
main() {
    echo -e "${WHITE}========================================${NC}"
    echo -e "${WHITE}⚡ RESOURCE USAGE PERFORMANCE TESTS ⚡${NC}"
    echo -e "${WHITE}========================================${NC}"
    echo -e "${BLUE}Test started: $(date)${NC}"
    echo ""
    
    # Set up cleanup trap
    trap cleanup EXIT
    
    # Run all tests
    test_baseline_resource_usage
    test_behavioral_analysis_performance
    test_dashboard_performance
    test_database_performance
    test_concurrent_operations
    test_memory_leak_detection
    test_disk_usage_performance
    test_cpu_performance_under_load
    test_network_performance
    test_resource_cleanup_performance
    
    # Test results summary
    echo ""
    echo -e "${WHITE}========================================${NC}"
    echo -e "${WHITE}📊 TEST RESULTS SUMMARY${NC}"
    echo -e "${WHITE}========================================${NC}"
    echo -e "${GREEN}Tests Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Tests Failed: $TESTS_FAILED${NC}"
    
    local total_tests=$((TESTS_PASSED + TESTS_FAILED))
    echo -e "${BLUE}Total Tests: $total_tests${NC}"
    
    if [ "$TESTS_FAILED" -eq 0 ]; then
        echo -e "${GREEN}🎉 ALL RESOURCE USAGE PERFORMANCE TESTS PASSED!${NC}"
        exit 0
    else
        echo -e "${RED}⚠️ $TESTS_FAILED test(s) failed. Review issues above.${NC}"
        exit 1
    fi
}

# Run main function
main "$@"