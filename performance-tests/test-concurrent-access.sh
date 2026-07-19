#!/bin/bash
# Concurrent User Access Performance Tests
# Tests system performance under multiple concurrent user access

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
DASHBOARD_DIR="$PROJECT_ROOT/web-dashboard"
DASHBOARD_URL="http://localhost:8080"
TESTS_PASSED=0
TESTS_FAILED=0

# Performance thresholds
MAX_CONCURRENT_USERS=50
MAX_RESPONSE_TIME_MS=2000
MAX_ERROR_RATE_PERCENT=5
MIN_THROUGHPUT_RPS=10

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

# Test 1: Dashboard Concurrent Access
test_dashboard_concurrent_access() {
    log_test "Testing Dashboard Concurrent Access"
    
    # Check if dashboard is running
    if ! curl -s --connect-timeout 5 "$DASHBOARD_URL" >/dev/null 2>&1; then
        log_warn "Dashboard not running - starting for test"
        if [ -f "$DASHBOARD_DIR/start-dashboard.sh" ]; then
            cd "$DASHBOARD_DIR"
            ./start-dashboard.sh &
            sleep 5
        else
            log_fail "Cannot start dashboard - startup script not found"
            return 1
        fi
    fi
    
    # Test concurrent access with different user counts
    local user_counts=(5 10 20)
    
    for user_count in "${user_counts[@]}"; do
        log_info "Testing with $user_count concurrent users"
        
        local pids=()
        local start_time=$(date +%s.%N)
        local successful_requests=0
        local failed_requests=0
        
        # Launch concurrent requests
        for i in $(seq 1 $user_count); do
            (
                # Make multiple requests per user
                for j in $(seq 1 3); do
                    local response=$(curl -s -o /dev/null -w "%{http_code}" "$DASHBOARD_URL/" 2>/dev/null || echo "000")
                    if [ "$response" = "200" ]; then
                        echo "SUCCESS" >> "/tmp/concurrent_test_${i}_${j}.txt"
                    else
                        echo "FAILED:$response" >> "/tmp/concurrent_test_${i}_${j}.txt"
                    fi
                    sleep 0.1
                done
            ) &
            pids+=($!)
        done
        
        # Wait for all processes
        for pid in "${pids[@]}"; do
            wait $pid
        done
        
        local end_time=$(date +%s.%N)
        local total_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
        
        # Count results
        for i in $(seq 1 $user_count); do
            for j in $(seq 1 3); do
                local result_file="/tmp/concurrent_test_${i}_${j}.txt"
                if [ -f "$result_file" ]; then
                    if grep -q "SUCCESS" "$result_file"; then
                        ((successful_requests++))
                    else
                        ((failed_requests++))
                    fi
                    rm -f "$result_file"
                fi
            done
        done
        
        local total_requests=$((successful_requests + failed_requests))
        local error_rate=$(echo "scale=2; $failed_requests * 100 / $total_requests" | bc -l 2>/dev/null || echo "0")
        local throughput=$(echo "scale=2; $successful_requests / $total_time" | bc -l 2>/dev/null || echo "0")
        
        log_info "Users: $user_count, Requests: $total_requests, Successful: $successful_requests, Failed: $failed_requests"
        log_info "Error rate: ${error_rate}%, Throughput: ${throughput} RPS, Time: ${total_time}s"
        
        # Evaluate performance
        if (( $(echo "$error_rate < $MAX_ERROR_RATE_PERCENT" | bc -l 2>/dev/null || echo "1") )); then
            log_pass "Error rate acceptable for $user_count users: ${error_rate}%"
        else
            log_fail "Error rate too high for $user_count users: ${error_rate}%"
        fi
        
        if (( $(echo "$throughput >= $MIN_THROUGHPUT_RPS" | bc -l 2>/dev/null || echo "1") )); then
            log_pass "Throughput acceptable for $user_count users: ${throughput} RPS"
        else
            log_fail "Throughput too low for $user_count users: ${throughput} RPS"
        fi
    done
}

# Test 2: API Concurrent Access
test_api_concurrent_access() {
    log_test "Testing API Concurrent Access"
    
    local api_endpoints=(
        "/api/system/status"
        "/api/behavioral/metrics"
        "/api/threats/iocs"
        "/api/incidents"
    )
    
    for endpoint in "${api_endpoints[@]}"; do
        log_info "Testing concurrent access to $endpoint"
        
        local pids=()
        local start_time=$(date +%s.%N)
        local successful_requests=0
        local failed_requests=0
        
        # Launch 10 concurrent requests
        for i in $(seq 1 10); do
            (
                local response=$(curl -s -o /dev/null -w "%{http_code}" "$DASHBOARD_URL$endpoint" 2>/dev/null || echo "000")
                if [ "$response" = "200" ]; then
                    echo "SUCCESS" >> "/tmp/api_test_${i}_${endpoint//\//_}.txt"
                else
                    echo "FAILED:$response" >> "/tmp/api_test_${i}_${endpoint//\//_}.txt"
                fi
            ) &
            pids+=($!)
        done
        
        # Wait for all processes
        for pid in "${pids[@]}"; do
            wait $pid
        done
        
        local end_time=$(date +%s.%N)
        local total_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
        
        # Count results
        for i in $(seq 1 10); do
            local result_file="/tmp/api_test_${i}_${endpoint//\//_}.txt"
            if [ -f "$result_file" ]; then
                if grep -q "SUCCESS" "$result_file"; then
                    ((successful_requests++))
                else
                    ((failed_requests++))
                fi
                rm -f "$result_file"
            fi
        done
        
        local total_requests=$((successful_requests + failed_requests))
        local error_rate=$(echo "scale=2; $failed_requests * 100 / $total_requests" | bc -l 2>/dev/null || echo "0")
        local avg_response_time=$(echo "scale=2; $total_time / 10" | bc -l 2>/dev/null || echo "0")
        local avg_response_time_ms=$(echo "$avg_response_time * 1000" | bc -l 2>/dev/null || echo "0")
        
        log_info "Endpoint: $endpoint, Success: $successful_requests/10, Error rate: ${error_rate}%, Avg time: ${avg_response_time_ms}ms"
        
        # Evaluate performance
        if (( $(echo "$error_rate < $MAX_ERROR_RATE_PERCENT" | bc -l 2>/dev/null || echo "1") )); then
            log_pass "API error rate acceptable: ${error_rate}%"
        else
            log_fail "API error rate too high: ${error_rate}%"
        fi
        
        if (( $(echo "$avg_response_time_ms < $MAX_RESPONSE_TIME_MS" | bc -l 2>/dev/null || echo "1") )); then
            log_pass "API response time acceptable: ${avg_response_time_ms}ms"
        else
            log_fail "API response time too slow: ${avg_response_time_ms}ms"
        fi
    done
}

# Test 3: Session Management Under Load
test_session_management_load() {
    log_test "Testing Session Management Under Load"
    
    # Test concurrent login attempts
    local pids=()
    local start_time=$(date +%s.%N)
    local successful_logins=0
    local failed_logins=0
    
    # Launch 20 concurrent login attempts
    for i in $(seq 1 20); do
        (
            local response=$(curl -s -X POST \
                -H "Content-Type: application/json" \
                -d "{\"username\":\"testuser$i\",\"password\":\"testpass$i\"}" \
                -o /dev/null -w "%{http_code}" \
                "$DASHBOARD_URL/login" 2>/dev/null || echo "000")
            
            if [ "$response" = "200" ] || [ "$response" = "302" ]; then
                echo "SUCCESS" >> "/tmp/login_test_${i}.txt"
            else
                echo "FAILED:$response" >> "/tmp/login_test_${i}.txt"
            fi
        ) &
        pids+=($!)
    done
    
    # Wait for all processes
    for pid in "${pids[@]}"; do
        wait $pid
    done
    
    local end_time=$(date +%s.%N)
    local total_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    
    # Count results
    for i in $(seq 1 20); do
        local result_file="/tmp/login_test_${i}.txt"
        if [ -f "$result_file" ]; then
            if grep -q "SUCCESS" "$result_file"; then
                ((successful_logins++))
            else
                ((failed_logins++))
            fi
            rm -f "$result_file"
        fi
    done
    
    local total_logins=$((successful_logins + failed_logins))
    local login_rate=$(echo "scale=2; $successful_logins / $total_time" | bc -l 2>/dev/null || echo "0")
    
    log_info "Concurrent logins: $successful_logins/20 successful, Rate: ${login_rate} logins/sec"
    
    if [ "$successful_logins" -gt 0 ]; then
        log_pass "Session management handles concurrent logins"
    else
        log_fail "Session management fails with concurrent logins"
    fi
}

# Test 4: Database Concurrent Access
test_database_concurrent_access() {
    log_test "Testing Database Concurrent Access"
    
    local behavioral_db="$AEGIS_HOME/configs/behavioral_analysis/behavioral_data.db"
    
    if [ -f "$behavioral_db" ] && command -v sqlite3 &> /dev/null; then
        # Create test table for concurrent access
        sqlite3 "$behavioral_db" << EOF 2>/dev/null
CREATE TABLE IF NOT EXISTS concurrent_test (
    id INTEGER PRIMARY KEY,
    thread_id INTEGER,
    operation TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);
EOF
        
        local pids=()
        local start_time=$(date +%s.%N)
        
        # Launch 10 concurrent database operations
        for i in $(seq 1 10); do
            (
                for j in $(seq 1 5); do
                    sqlite3 "$behavioral_db" "INSERT INTO concurrent_test (thread_id, operation) VALUES ($i, 'operation_$j');" 2>/dev/null || true
                    sleep 0.01
                done
            ) &
            pids+=($!)
        done
        
        # Wait for all processes
        for pid in "${pids[@]}"; do
            wait $pid
        done
        
        local end_time=$(date +%s.%N)
        local total_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
        
        # Verify results
        local total_records=$(sqlite3 "$behavioral_db" "SELECT COUNT(*) FROM concurrent_test;" 2>/dev/null || echo "0")
        local expected_records=50
        
        log_info "Database concurrent operations: $total_records/$expected_records completed in ${total_time}s"
        
        if [ "$total_records" -eq "$expected_records" ]; then
            log_pass "Database handles concurrent access correctly"
        else
            log_fail "Database concurrent access incomplete: $total_records/$expected_records"
        fi
        
        # Cleanup test table
        sqlite3 "$behavioral_db" "DROP TABLE concurrent_test;" 2>/dev/null || true
    else
        log_warn "Behavioral database not available for concurrent testing"
    fi
}

# Test 5: Resource Usage Under Load
test_resource_usage_load() {
    log_test "Testing Resource Usage Under Load"
    
    # Get baseline resource usage
    local baseline_cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 || echo "0")
    local baseline_memory=$(free -m | awk 'NR==2{printf "%.1f", $3}' || echo "0")
    
    log_info "Baseline CPU: ${baseline_cpu}%, Memory: ${baseline_memory}MB"
    
    # Generate load with concurrent processes
    local pids=()
    for i in $(seq 1 20); do
        (
            # Simulate dashboard load
            for j in $(seq 1 10); do
                curl -s "$DASHBOARD_URL/api/system/status" >/dev/null 2>&1 || true
                sleep 0.1
            done
        ) &
        pids+=($!)
    done
    
    # Measure resource usage during load
    sleep 2
    local load_cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 || echo "0")
    local load_memory=$(free -m | awk 'NR==2{printf "%.1f", $3}' || echo "0")
    
    log_info "Load CPU: ${load_cpu}%, Memory: ${load_memory}MB"
    
    # Wait for all processes
    for pid in "${pids[@]}"; do
        wait $pid
    done
    
    # Check resource usage
    local cpu_increase=$(echo "$load_cpu - $baseline_cpu" | bc -l 2>/dev/null || echo "0")
    local memory_increase=$(echo "$load_memory - $baseline_memory" | bc -l 2>/dev/null || echo "0")
    
    log_info "CPU increase: ${cpu_increase}%, Memory increase: ${memory_increase}MB"
    
    if (( $(echo "$cpu_increase < 50" | bc -l 2>/dev/null || echo "1") )); then
        log_pass "CPU usage increase is acceptable"
    else
        log_fail "CPU usage increase is too high: ${cpu_increase}%"
    fi
    
    if (( $(echo "$memory_increase < 100" | bc -l 2>/dev/null || echo "1") )); then
        log_pass "Memory usage increase is acceptable"
    else
        log_fail "Memory usage increase is too high: ${memory_increase}MB"
    fi
}

# Test 6: WebSocket Concurrent Connections
test_websocket_concurrent() {
    log_test "Testing WebSocket Concurrent Connections"
    
    if command -v nc &> /dev/null; then
        local pids=()
        local successful_connections=0
        
        # Test 5 concurrent WebSocket connections
        for i in $(seq 1 5); do
            (
                local ws_response=$(echo -e "GET /socket.io/ HTTP/1.1\r\nHost: localhost:8080\r\n\r\n" | nc localhost 8080 2>/dev/null || echo "")
                
                if [ -n "$ws_response" ]; then
                    echo "SUCCESS" >> "/tmp/ws_test_${i}.txt"
                else
                    echo "FAILED" >> "/tmp/ws_test_${i}.txt"
                fi
            ) &
            pids+=($!)
        done
        
        # Wait for all connections
        for pid in "${pids[@]}"; do
            wait $pid
        done
        
        # Count results
        for i in $(seq 1 5); do
            local result_file="/tmp/ws_test_${i}.txt"
            if [ -f "$result_file" ]; then
                if grep -q "SUCCESS" "$result_file"; then
                    ((successful_connections++))
                fi
                rm -f "$result_file"
            fi
        done
        
        log_info "WebSocket concurrent connections: $successful_connections/5 successful"
        
        if [ "$successful_connections" -ge 3 ]; then
            log_pass "WebSocket handles concurrent connections"
        else
            log_fail "WebSocket concurrent connection handling insufficient"
        fi
    else
        log_warn "Netcat not available - cannot test WebSocket concurrency"
    fi
}

# Test 7: File Upload Concurrent Access
test_file_upload_concurrent() {
    log_test "Testing File Upload Concurrent Access"
    
    # Create test files
    local test_files=()
    for i in $(seq 1 5); do
        local test_file="/tmp/test_upload_${i}.txt"
        echo "Test file content $i" > "$test_file"
        test_files+=("$test_file")
    done
    
    local pids=()
    local successful_uploads=0
    
    # Test concurrent file uploads
    for i in "${!test_files[@]}"; do
        (
            local response=$(curl -s -X POST \
                -F "file=@${test_files[$i]}" \
                -o /dev/null -w "%{http_code}" \
                "$DASHBOARD_URL/api/upload" 2>/dev/null || echo "000")
            
            if [ "$response" = "200" ] || [ "$response" = "201" ]; then
                echo "SUCCESS" >> "/tmp/upload_test_${i}.txt"
            else
                echo "FAILED:$response" >> "/tmp/upload_test_${i}.txt"
            fi
        ) &
        pids+=($!)
    done
    
    # Wait for all uploads
    for pid in "${pids[@]}"; do
        wait $pid
    done
    
    # Count results
    for i in "${!test_files[@]}"; do
        local result_file="/tmp/upload_test_${i}.txt"
        if [ -f "$result_file" ]; then
            if grep -q "SUCCESS" "$result_file"; then
                ((successful_uploads++))
            fi
            rm -f "$result_file"
        fi
    done
    
    log_info "Concurrent file uploads: $successful_uploads/${#test_files[@]} successful"
    
    if [ "$successful_uploads" -ge 3 ]; then
        log_pass "File upload handles concurrent access"
    else
        log_fail "File upload concurrent handling insufficient"
    fi
    
    # Cleanup test files
    for test_file in "${test_files[@]}"; do
        rm -f "$test_file"
    done
}

# Cleanup function
cleanup() {
    log_info "Cleaning up concurrent access test environment..."
    
    # Clean up temporary files
    find /tmp -name "concurrent_test_*.txt" -delete 2>/dev/null || true
    find /tmp -name "api_test_*.txt" -delete 2>/dev/null || true
    find /tmp -name "login_test_*.txt" -delete 2>/dev/null || true
    find /tmp -name "ws_test_*.txt" -delete 2>/dev/null || true
    find /tmp -name "upload_test_*.txt" -delete 2>/dev/null || true
    find /tmp -name "test_upload_*.txt" -delete 2>/dev/null || true
}

# Main test execution
main() {
    echo -e "${WHITE}========================================${NC}"
    echo -e "${WHITE}👥 CONCURRENT USER ACCESS TESTS 👥${NC}"
    echo -e "${WHITE}========================================${NC}"
    echo -e "${BLUE}Test started: $(date)${NC}"
    echo ""
    
    # Set up cleanup trap
    trap cleanup EXIT
    
    # Run all tests
    test_dashboard_concurrent_access
    test_api_concurrent_access
    test_session_management_load
    test_database_concurrent_access
    test_resource_usage_load
    test_websocket_concurrent
    test_file_upload_concurrent
    
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
        echo -e "${GREEN}🎉 ALL CONCURRENT USER ACCESS TESTS PASSED!${NC}"
        exit 0
    else
        echo -e "${RED}⚠️ $TESTS_FAILED test(s) failed. Review issues above.${NC}"
        exit 1
    fi
}

# Run main function
main "$@"