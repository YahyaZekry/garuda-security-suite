#!/bin/bash
# Database Performance Tests
# Tests database performance under various conditions and loads

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

# Performance thresholds
MAX_QUERY_TIME_MS=100
MAX_INSERT_TIME_MS=50
MAX_BATCH_SIZE=1000
MAX_CONNECTIONS=10

# Load configuration
if [ -f "$PROJECT_ROOT/configs/security-config.conf" ]; then
    source "$PROJECT_ROOT/configs/security-config.conf"
else
    echo -e "${RED}❌ Configuration file not found${NC}"
    exit 1
fi

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

# Test 1: Database Connection Performance
test_connection_performance() {
    log_test "Testing Database Connection Performance"
    
    local databases=(
        "$AEGIS_HOME/configs/behavioral_analysis/behavioral_data.db"
        "$AEGIS_HOME/configs/threat_intelligence/ioc_database.db"
        "$AEGIS_HOME/configs/incident_response/incidents.db"
    )
    
    for db in "${databases[@]}"; do
        if [ -f "$db" ] && command -v sqlite3 &> /dev/null; then
            local db_name=$(basename "$db")
            
            # Test connection time
            local start_time=$(date +%s.%N)
            local result=$(sqlite3 "$db" "SELECT 1;" 2>/dev/null || echo "failed")
            local end_time=$(date +%s.%N)
            local connection_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
            local connection_time_ms=$(echo "$connection_time * 1000" | bc -l 2>/dev/null || echo "0")
            
            if [ "$result" != "failed" ]; then
                log_pass "$db_name connection successful: ${connection_time_ms}ms"
                
                if (( $(echo "$connection_time_ms < 10" | bc -l 2>/dev/null || echo "1") )); then
                    log_pass "$db_name connection time is excellent: ${connection_time_ms}ms"
                else
                    log_warn "$db_name connection time could be better: ${connection_time_ms}ms"
                fi
            else
                log_fail "$db_name connection failed"
            fi
        else
            log_warn "Database not available: $(basename "$db")"
        fi
    done
}

# Test 2: Query Performance
test_query_performance() {
    log_test "Testing Query Performance"
    
    local behavioral_db="$AEGIS_HOME/configs/behavioral_analysis/behavioral_data.db"
    
    if [ -f "$behavioral_db" ] && command -v sqlite3 &> /dev/null; then
        # Test simple queries
        local simple_queries=(
            "SELECT COUNT(*) FROM system_metrics;"
            "SELECT COUNT(*) FROM process_behavior;"
            "SELECT COUNT(*) FROM anomalies;"
        )
        
        for query in "${simple_queries[@]}"; do
            local start_time=$(date +%s.%N)
            local result=$(sqlite3 "$behavioral_db" "$query" 2>/dev/null || echo "0")
            local end_time=$(date +%s.%N)
            local query_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
            local query_time_ms=$(echo "$query_time * 1000" | bc -l 2>/dev/null || echo "0")
            
            log_info "Query: ${query%%;*} - Time: ${query_time_ms}ms - Result: $result"
            
            if (( $(echo "$query_time_ms < $MAX_QUERY_TIME_MS" | bc -l 2>/dev/null || echo "1") )); then
                log_pass "Simple query performance acceptable: ${query_time_ms}ms"
            else
                log_fail "Simple query too slow: ${query_time_ms}ms"
            fi
        done
        
        # Test complex queries
        local complex_queries=(
            "SELECT timestamp, cpu_usage, memory_usage FROM system_metrics ORDER BY timestamp DESC LIMIT 100;"
            "SELECT process_name, AVG(cpu_usage) as avg_cpu FROM process_behavior WHERE timestamp > datetime('now', '-1 hour') GROUP BY process_name;"
            "SELECT type, COUNT(*) as count FROM anomalies WHERE detected_at > datetime('now', '-24 hours') GROUP BY type;"
        )
        
        for query in "${complex_queries[@]}"; do
            local start_time=$(date +%s.%N)
            local result=$(sqlite3 "$behavioral_db" "$query" 2>/dev/null || echo "")
            local end_time=$(date +%s.%N)
            local query_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
            local query_time_ms=$(echo "$query_time * 1000" | bc -l 2>/dev/null || echo "0")
            
            local result_count=$(echo "$result" | wc -l)
            log_info "Complex query returned $result_count rows in ${query_time_ms}ms"
            
            if (( $(echo "$query_time_ms < $MAX_QUERY_TIME_MS * 2" | bc -l 2>/dev/null || echo "1") )); then
                log_pass "Complex query performance acceptable: ${query_time_ms}ms"
            else
                log_fail "Complex query too slow: ${query_time_ms}ms"
            fi
        done
    else
        log_warn "Behavioral database not available for query testing"
    fi
}

# Test 3: Insert Performance
test_insert_performance() {
    log_test "Testing Insert Performance"
    
    local test_db="/tmp/test_db_performance_$$.db"
    
    if command -v sqlite3 &> /dev/null; then
        # Create test database
        sqlite3 "$test_db" << EOF
CREATE TABLE test_table (
    id INTEGER PRIMARY KEY,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    data TEXT,
    value REAL
);
CREATE INDEX idx_timestamp ON test_table(timestamp);
CREATE INDEX idx_value ON test_table(value);
EOF
        
        # Test single insert performance
        local start_time=$(date +%s.%N)
        for i in $(seq 1 100); do
            sqlite3 "$test_db" "INSERT INTO test_table (data, value) VALUES ('test_data_$i', $i);" 2>/dev/null
        done
        local end_time=$(date +%s.%N)
        local insert_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
        local avg_insert_time_ms=$(echo "$insert_time * 1000 / 100" | bc -l 2>/dev/null || echo "0")
        
        log_info "100 single inserts completed in ${insert_time}s (avg: ${avg_insert_time_ms}ms per insert)"
        
        if (( $(echo "$avg_insert_time_ms < $MAX_INSERT_TIME_MS" | bc -l 2>/dev/null || echo "1") )); then
            log_pass "Single insert performance acceptable: ${avg_insert_time_ms}ms"
        else
            log_fail "Single insert too slow: ${avg_insert_time_ms}ms"
        fi
        
        # Test batch insert performance
        local start_time=$(date +%s.%N)
        sqlite3 "$test_db" << EOF
INSERT INTO test_table (data, value) VALUES 
    ('batch_1', 101), ('batch_2', 102), ('batch_3', 103),
    ('batch_4', 104), ('batch_5', 105), ('batch_6', 106),
    ('batch_7', 107), ('batch_8', 108), ('batch_9', 109),
    ('batch_10', 110);
EOF
        local end_time=$(date +%s.%N)
        local batch_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
        local batch_time_ms=$(echo "$batch_time * 1000" | bc -l 2>/dev/null || echo "0")
        
        log_info "Batch insert (10 records) completed in ${batch_time_ms}ms"
        
        if (( $(echo "$batch_time_ms < $MAX_INSERT_TIME_MS * 5" | bc -l 2>/dev/null || echo "1") )); then
            log_pass "Batch insert performance acceptable: ${batch_time_ms}ms"
        else
            log_fail "Batch insert too slow: ${batch_time_ms}ms"
        fi
        
        # Cleanup
        rm -f "$test_db"
    else
        log_warn "SQLite3 not available - cannot test insert performance"
    fi
}

# Test 4: Index Performance
test_index_performance() {
    log_test "Testing Index Performance"
    
    local test_db="/tmp/test_index_performance_$$.db"
    
    if command -v sqlite3 &> /dev/null; then
        # Create test database without indexes
        sqlite3 "$test_db" << EOF
CREATE TABLE test_data (
    id INTEGER PRIMARY KEY,
    category TEXT,
    value REAL,
    timestamp DATETIME
);
EOF
        
        # Insert test data
        for i in $(seq 1 1000); do
            local category="category_$((i % 10))"
            local value=$(echo "scale=2; $i * 1.5" | bc -l 2>/dev/null || echo "$i")
            sqlite3 "$test_db" "INSERT INTO test_data (category, value, timestamp) VALUES ('$category', $value, datetime('now', '-$i minutes'));" 2>/dev/null
        done
        
        # Test query without index
        local start_time=$(date +%s.%N)
        local result_no_index=$(sqlite3 "$test_db" "SELECT COUNT(*) FROM test_data WHERE category = 'category_5';" 2>/dev/null || echo "0")
        local end_time=$(date +%s.%N)
        local query_time_no_index=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
        local query_time_no_index_ms=$(echo "$query_time_no_index * 1000" | bc -l 2>/dev/null || echo "0")
        
        # Create index
        sqlite3 "$test_db" "CREATE INDEX idx_category ON test_data(category);" 2>/dev/null
        
        # Test query with index
        local start_time=$(date +%s.%N)
        local result_with_index=$(sqlite3 "$test_db" "SELECT COUNT(*) FROM test_data WHERE category = 'category_5';" 2>/dev/null || echo "0")
        local end_time=$(date +%s.%N)
        local query_time_with_index=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
        local query_time_with_index_ms=$(echo "$query_time_with_index * 1000" | bc -l 2>/dev/null || echo "0")
        
        log_info "Query without index: ${query_time_no_index_ms}ms (result: $result_no_index)"
        log_info "Query with index: ${query_time_with_index_ms}ms (result: $result_with_index)"
        
        if [ "$result_no_index" = "$result_with_index" ]; then
            if (( $(echo "$query_time_with_index_ms < $query_time_no_index_ms" | bc -l 2>/dev/null || echo "1") )); then
                log_pass "Index improves query performance"
            else
                log_warn "Index may not significantly improve query performance"
            fi
        else
            log_fail "Query results differ between indexed and non-indexed queries"
        fi
        
        # Cleanup
        rm -f "$test_db"
    else
        log_warn "SQLite3 not available - cannot test index performance"
    fi
}

# Test 5: Concurrent Database Access
test_concurrent_access() {
    log_test "Testing Concurrent Database Access"
    
    local test_db="/tmp/test_concurrent_$$.db"
    
    if command -v sqlite3 &> /dev/null; then
        # Create test database
        sqlite3 "$test_db" << EOF
CREATE TABLE concurrent_test (
    id INTEGER PRIMARY KEY,
    thread_id INTEGER,
    operation TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);
EOF
        
        # Test concurrent access
        local pids=()
        for i in $(seq 1 5); do
            (
                for j in $(seq 1 10); do
                    sqlite3 "$test_db" "INSERT INTO concurrent_test (thread_id, operation) VALUES ($i, 'insert_$j');" 2>/dev/null
                    sleep 0.01
                done
            ) &
            pids+=($!)
        done
        
        # Wait for all background processes
        for pid in "${pids[@]}"; do
            wait $pid
        done
        
        # Verify results
        local total_records=$(sqlite3 "$test_db" "SELECT COUNT(*) FROM concurrent_test;" 2>/dev/null || echo "0")
        local expected_records=50
        
        if [ "$total_records" -eq "$expected_records" ]; then
            log_pass "Concurrent database access successful: $total_records/$expected_records records"
        else
            log_fail "Concurrent database access incomplete: $total_records/$expected_records records"
        fi
        
        # Cleanup
        rm -f "$test_db"
    else
        log_warn "SQLite3 not available - cannot test concurrent access"
    fi
}

# Test 6: Database Size and Optimization
test_database_optimization() {
    log_test "Testing Database Size and Optimization"
    
    local databases=(
        "$AEGIS_HOME/configs/behavioral_analysis/behavioral_data.db"
        "$AEGIS_HOME/configs/threat_intelligence/ioc_database.db"
        "$AEGIS_HOME/configs/incident_response/incidents.db"
    )
    
    for db in "${databases[@]}"; do
        if [ -f "$db" ] && command -v sqlite3 &> /dev/null; then
            local db_name=$(basename "$db")
            local db_size=$(stat -c%s "$db" 2>/dev/null || echo "0")
            local db_size_mb=$(echo "scale=2; $db_size / 1024 / 1024" | bc -l 2>/dev/null || echo "0")
            
            log_info "$db_name size: ${db_size_mb}MB"
            
            # Check for fragmentation
            local page_count=$(sqlite3 "$db" "PRAGMA page_count;" 2>/dev/null || echo "0")
            local page_size=$(sqlite3 "$db" "PRAGMA page_size;" 2>/dev/null || echo "0")
            local freelist_count=$(sqlite3 "$db" "PRAGMA freelist_count;" 2>/dev/null || echo "0")
            
            if [ "$page_count" -gt 0 ] && [ "$page_size" -gt 0 ]; then
                local fragmentation_percent=$(echo "scale=2; $freelist_count * 100 / $page_count" | bc -l 2>/dev/null || echo "0")
                log_info "$db_name fragmentation: ${fragmentation_percent}%"
                
                if (( $(echo "$fragmentation_percent < 10" | bc -l 2>/dev/null || echo "1") )); then
                    log_pass "$db_name fragmentation is acceptable"
                else
                    log_warn "$db_name fragmentation is high: ${fragmentation_percent}%"
                fi
            fi
            
            # Test VACUUM performance
            local start_time=$(date +%s.%N)
            sqlite3 "$db" "VACUUM;" 2>/dev/null || true
            local end_time=$(date +%s.%N)
            local vacuum_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
            
            local new_db_size=$(stat -c%s "$db" 2>/dev/null || echo "0")
            local new_db_size_mb=$(echo "scale=2; $new_db_size / 1024 / 1024" | bc -l 2>/dev/null || echo "0")
            local size_reduction=$(echo "scale=2; ($db_size - $new_db_size) / 1024 / 1024" | bc -l 2>/dev/null || echo "0")
            
            log_info "$db_name VACUUM completed in ${vacuum_time}s, reduced size by ${size_reduction}MB"
            
            if (( $(echo "$vacuum_time < 30" | bc -l 2>/dev/null || echo "1") )); then
                log_pass "$db_name VACUUM time is acceptable"
            else
                log_warn "$db_name VACUUM time is long: ${vacuum_time}s"
            fi
        else
            log_warn "Database not available: $(basename "$db")"
        fi
    done
}

# Test 7: Transaction Performance
test_transaction_performance() {
    log_test "Testing Transaction Performance"
    
    local test_db="/tmp/test_transaction_$$.db"
    
    if command -v sqlite3 &> /dev/null; then
        # Create test database
        sqlite3 "$test_db" "CREATE TABLE transaction_test (id INTEGER PRIMARY KEY, data TEXT, value REAL);" 2>/dev/null
        
        # Test without transaction
        local start_time=$(date +%s.%N)
        for i in $(seq 1 100); do
            sqlite3 "$test_db" "INSERT INTO transaction_test (data, value) VALUES ('no_tx_$i', $i);" 2>/dev/null
        done
        local end_time=$(date +%s.%N)
        local no_tx_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
        local no_tx_time_ms=$(echo "$no_tx_time * 1000" | bc -l 2>/dev/null || echo "0")
        
        # Test with transaction
        local start_time=$(date +%s.%N)
        sqlite3 "$test_db" "BEGIN TRANSACTION;" 2>/dev/null
        for i in $(seq 101 200); do
            sqlite3 "$test_db" "INSERT INTO transaction_test (data, value) VALUES ('with_tx_$i', $i);" 2>/dev/null
        done
        sqlite3 "$test_db" "COMMIT;" 2>/dev/null
        local end_time=$(date +%s.%N)
        local with_tx_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
        local with_tx_time_ms=$(echo "$with_tx_time * 1000" | bc -l 2>/dev/null || echo "0")
        
        log_info "100 inserts without transaction: ${no_tx_time_ms}ms"
        log_info "100 inserts with transaction: ${with_tx_time_ms}ms"
        
        if (( $(echo "$with_tx_time_ms < $no_tx_time_ms" | bc -l 2>/dev/null || echo "1") )); then
            log_pass "Transaction improves insert performance"
        else
            log_warn "Transaction may not significantly improve insert performance"
        fi
        
        # Cleanup
        rm -f "$test_db"
    else
        log_warn "SQLite3 not available - cannot test transaction performance"
    fi
}

# Test 8: Database Backup Performance
test_backup_performance() {
    log_test "Testing Database Backup Performance"
    
    local behavioral_db="$AEGIS_HOME/configs/behavioral_analysis/behavioral_data.db"
    
    if [ -f "$behavioral_db" ] && command -v sqlite3 &> /dev/null; then
        local backup_file="/tmp/backup_test_$$.db"
        
        # Test backup performance
        local start_time=$(date +%s.%N)
        sqlite3 "$behavioral_db" ".backup $backup_file" 2>/dev/null || true
        local end_time=$(date +%s.%N)
        local backup_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
        
        if [ -f "$backup_file" ]; then
            local original_size=$(stat -c%s "$behavioral_db" 2>/dev/null || echo "0")
            local backup_size=$(stat -c%s "$backup_file" 2>/dev/null || echo "0")
            
            if [ "$original_size" -eq "$backup_size" ]; then
                log_pass "Database backup successful and complete"
                log_info "Backup completed in ${backup_time}s for ${original_size} bytes"
                
                if (( $(echo "$backup_time < 60" | bc -l 2>/dev/null || echo "1") )); then
                    log_pass "Backup time is acceptable"
                else
                    log_warn "Backup time is long: ${backup_time}s"
                fi
            else
                log_fail "Backup size mismatch: original=$original_size, backup=$backup_size"
            fi
            
            # Cleanup
            rm -f "$backup_file"
        else
            log_fail "Backup file not created"
        fi
    else
        log_warn "Behavioral database not available for backup testing"
    fi
}

# Main test execution
main() {
    echo -e "${WHITE}========================================${NC}"
    echo -e "${WHITE}🗄️ DATABASE PERFORMANCE TESTS 🗄️${NC}"
    echo -e "${WHITE}========================================${NC}"
    echo -e "${BLUE}Test started: $(date)${NC}"
    echo ""
    
    # Run all tests
    test_connection_performance
    test_query_performance
    test_insert_performance
    test_index_performance
    test_concurrent_access
    test_database_optimization
    test_transaction_performance
    test_backup_performance
    
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
        echo -e "${GREEN}🎉 ALL DATABASE PERFORMANCE TESTS PASSED!${NC}"
        exit 0
    else
        echo -e "${RED}⚠️ $TESTS_FAILED test(s) failed. Review issues above.${NC}"
        exit 1
    fi
}

# Run main function
main "$@"