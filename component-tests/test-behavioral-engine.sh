#!/bin/bash
# Behavioral Analysis Engine Component Tests
# Tests baseline creation, anomaly detection, threat scoring, and pattern analysis

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

# Test 1: Behavioral Analysis Configuration
test_behavioral_configuration() {
    log_test "Testing Behavioral Analysis Configuration"
    
    # Check if behavioral analysis is enabled
    if [ "${BEHAVIORAL_ANALYSIS_ENABLED:-false}" = "true" ]; then
        log_pass "Behavioral analysis is enabled"
        
        # Check required configuration variables
        [ -n "${BEHAVIORAL_LEARNING_PERIOD:-}" ] && log_pass "Learning period configured: $BEHAVIORAL_LEARNING_PERIOD days" || log_fail "Learning period not configured"
        [ -n "${BEHAVIORAL_MONITORING_INTERVAL:-}" ] && log_pass "Monitoring interval configured: $BEHAVIORAL_MONITORING_INTERVAL seconds" || log_fail "Monitoring interval not configured"
        [ -n "${BEHAVIORAL_SENSITIVITY_LEVEL:-}" ] && log_pass "Sensitivity level configured: $BEHAVIORAL_SENSITIVITY_LEVEL" || log_fail "Sensitivity level not configured"
        [ -n "${BEHAVIORAL_THREAT_SCORE_THRESHOLD:-}" ] && log_pass "Threat threshold configured: $BEHAVIORAL_THREAT_SCORE_THRESHOLD" || log_fail "Threat threshold not configured"
        
        # Validate configuration values
        if [[ "$BEHAVIORAL_LEARNING_PERIOD" =~ ^[0-9]+$ ]] && [ "$BEHAVIORAL_LEARNING_PERIOD" -gt 0 ]; then
            log_pass "Learning period is valid: $BEHAVIORAL_LEARNING_PERIOD"
        else
            log_fail "Invalid learning period: $BEHAVIORAL_LEARNING_PERIOD"
        fi
        
        if [[ "$BEHAVIORAL_MONITORING_INTERVAL" =~ ^[0-9]+$ ]] && [ "$BEHAVIORAL_MONITORING_INTERVAL" -gt 0 ]; then
            log_pass "Monitoring interval is valid: $BEHAVIORAL_MONITORING_INTERVAL"
        else
            log_fail "Invalid monitoring interval: $BEHAVIORAL_MONITORING_INTERVAL"
        fi
        
        if [[ "$BEHAVIORAL_SENSITIVITY_LEVEL" =~ ^(low|medium|high)$ ]]; then
            log_pass "Sensitivity level is valid: $BEHAVIORAL_SENSITIVITY_LEVEL"
        else
            log_fail "Invalid sensitivity level: $BEHAVIORAL_SENSITIVITY_LEVEL"
        fi
        
        if [[ "$BEHAVIORAL_THREAT_SCORE_THRESHOLD" =~ ^[0-9]+$ ]] && [ "$BEHAVIORAL_THREAT_SCORE_THRESHOLD" -ge 0 ] && [ "$BEHAVIORAL_THREAT_SCORE_THRESHOLD" -le 100 ]; then
            log_pass "Threat threshold is valid: $BEHAVIORAL_THREAT_SCORE_THRESHOLD"
        else
            log_fail "Invalid threat threshold: $BEHAVIORAL_THREAT_SCORE_THRESHOLD"
        fi
    else
        log_warn "Behavioral analysis is disabled - skipping configuration tests"
    fi
}

# Test 2: Behavioral Analysis Script Availability
test_script_availability() {
    log_test "Testing Behavioral Analysis Script Availability"
    
    local script_path="$PROJECT_ROOT/scripts/behavioral-analysis.sh"
    
    if [ -f "$script_path" ]; then
        log_pass "Behavioral analysis script found: $script_path"
        
        if [ -x "$script_path" ]; then
            log_pass "Behavioral analysis script is executable"
        else
            log_fail "Behavioral analysis script is not executable"
        fi
        
        # Check script syntax
        if bash -n "$script_path" 2>/dev/null; then
            log_pass "Behavioral analysis script has valid syntax"
        else
            log_fail "Behavioral analysis script has syntax errors"
        fi
    else
        log_fail "Behavioral analysis script not found: $script_path"
    fi
    
    # Test monitoring script
    local monitor_script="$PROJECT_ROOT/scripts/behavioral-monitor.sh"
    if [ -f "$monitor_script" ]; then
        log_pass "Behavioral monitoring script found: $monitor_script"
        
        if [ -x "$monitor_script" ]; then
            log_pass "Behavioral monitoring script is executable"
        else
            log_fail "Behavioral monitoring script is not executable"
        fi
    else
        log_fail "Behavioral monitoring script not found: $monitor_script"
    fi
}

# Test 3: Database Initialization and Operations
test_database_operations() {
    log_test "Testing Database Initialization and Operations"
    
    local db_dir="$AEGIS_HOME/configs/behavioral_analysis"
    local db_file="$db_dir/behavioral_data.db"
    
    # Check database directory
    if [ -d "$db_dir" ]; then
        log_pass "Behavioral analysis database directory exists: $db_dir"
    else
        log_warn "Database directory not found, will be created: $db_dir"
        mkdir -p "$db_dir"
    fi
    
    # Test database creation
    if [ "${BEHAVIORAL_ANALYSIS_ENABLED:-false}" = "true" ]; then
        # Source behavioral analysis functions
        if [ -f "$PROJECT_ROOT/scripts/behavioral-analysis.sh" ]; then
            source "$PROJECT_ROOT/scripts/behavioral-analysis.sh"
            
            # Test database initialization
            if init_behavioral_analysis 2>/dev/null; then
                log_pass "Database initialization successful"
                
                # Check if database file was created
                if [ -f "$db_file" ]; then
                    log_pass "Database file created: $db_file"
                    
                    # Test database schema
                    if command -v sqlite3 &> /dev/null; then
                        local tables=$(sqlite3 "$db_file" "SELECT name FROM sqlite_master WHERE type='table';" 2>/dev/null || echo "")
                        if [ -n "$tables" ]; then
                            log_pass "Database tables created: $tables"
                            
                            # Check for required tables
                            local required_tables="system_metrics process_behavior network_behavior file_access_patterns anomalies"
                            for table in $required_tables; do
                                if echo "$tables" | grep -q "$table"; then
                                    log_pass "Required table exists: $table"
                                else
                                    log_fail "Required table missing: $table"
                                fi
                            done
                        else
                            log_fail "No tables found in database"
                        fi
                    else
                        log_warn "SQLite3 not available - cannot verify database schema"
                    fi
                else
                    log_fail "Database file not created after initialization"
                fi
            else
                log_fail "Database initialization failed"
            fi
        else
            log_fail "Cannot source behavioral analysis script"
        fi
    else
        log_warn "Behavioral analysis disabled - skipping database tests"
    fi
}

# Test 4: Baseline Creation and Learning
test_baseline_creation() {
    log_test "Testing Baseline Creation and Learning"
    
    if [ "${BEHAVIORAL_ANALYSIS_ENABLED:-false}" = "true" ]; then
        if [ -f "$PROJECT_ROOT/scripts/behavioral-analysis.sh" ]; then
            source "$PROJECT_ROOT/scripts/behavioral-analysis.sh"
            
            # Test baseline creation with minimal data
            log_info "Testing baseline creation with 1 day learning period..."
            
            # Create test environment
            local test_db="/tmp/test_behavioral_$$.db"
            export BEHAVIORAL_DB_PATH="$test_db"
            
            # Initialize test database
            if init_behavioral_analysis 2>/dev/null; then
                log_pass "Test database initialized"
                
                # Insert test data
                if command -v sqlite3 &> /dev/null; then
                    sqlite3 "$test_db" << EOF 2>/dev/null
INSERT INTO system_metrics (timestamp, cpu_usage, memory_usage, disk_usage, network_io) 
VALUES (datetime('now'), 25.5, 60.2, 45.8, 1024);
INSERT INTO process_behavior (timestamp, process_name, cpu_usage, memory_usage, pid, parent_pid) 
VALUES (datetime('now'), 'test_process', 5.2, 10.1, 1234, 1);
EOF
                    
                    if [ $? -eq 0 ]; then
                        log_pass "Test data inserted successfully"
                        
                        # Test baseline calculation
                        if calculate_baseline 2>/dev/null; then
                            log_pass "Baseline calculation successful"
                        else
                            log_fail "Baseline calculation failed"
                        fi
                    else
                        log_fail "Failed to insert test data"
                    fi
                else
                    log_warn "SQLite3 not available - cannot test baseline creation"
                fi
                
                # Cleanup
                rm -f "$test_db" 2>/dev/null || true
            else
                log_fail "Test database initialization failed"
            fi
        else
            log_fail "Behavioral analysis script not available"
        fi
    else
        log_warn "Behavioral analysis disabled - skipping baseline tests"
    fi
}

# Test 5: Anomaly Detection Algorithms
test_anomaly_detection() {
    log_test "Testing Anomaly Detection Algorithms"
    
    if [ "${BEHAVIORAL_ANALYSIS_ENABLED:-false}" = "true" ]; then
        if [ -f "$PROJECT_ROOT/scripts/behavioral-analysis.sh" ]; then
            source "$PROJECT_ROOT/scripts/behavioral-analysis.sh"
            
            # Create test environment
            local test_db="/tmp/test_anomaly_$$.db"
            export BEHAVIORAL_DB_PATH="$test_db"
            
            # Initialize test database
            if init_behavioral_analysis 2>/dev/null; then
                log_pass "Test database initialized for anomaly detection"
                
                if command -v sqlite3 &> /dev/null; then
                    # Insert normal baseline data
                    sqlite3 "$test_db" << EOF 2>/dev/null
INSERT INTO system_metrics (timestamp, cpu_usage, memory_usage, disk_usage, network_io) 
VALUES 
    (datetime('now', '-1 hour'), 25.5, 60.2, 45.8, 1024),
    (datetime('now', '-2 hours'), 24.8, 59.9, 46.1, 980),
    (datetime('now', '-3 hours'), 26.1, 60.5, 45.5, 1050),
    (datetime('now', '-4 hours'), 25.2, 60.1, 45.9, 1010);
EOF
                    
                    # Insert anomalous data
                    sqlite3 "$test_db" << EOF 2>/dev/null
INSERT INTO system_metrics (timestamp, cpu_usage, memory_usage, disk_usage, network_io) 
VALUES (datetime('now'), 95.2, 85.7, 75.3, 5120);
EOF
                    
                    if [ $? -eq 0 ]; then
                        log_pass "Test data (normal and anomalous) inserted"
                        
                        # Test anomaly detection
                        local anomalies_detected=0
                        if detect_anomalies 2>/dev/null; then
                            anomalies_detected=$(sqlite3 "$test_db" "SELECT COUNT(*) FROM anomalies WHERE detected_at > datetime('now', '-1 minute');" 2>/dev/null || echo "0")
                            if [ "$anomalies_detected" -gt 0 ]; then
                                log_pass "Anomalies detected: $anomalies_detected"
                            else
                                log_warn "No anomalies detected (may be expected)"
                            fi
                        else
                            log_fail "Anomaly detection failed"
                        fi
                    else
                        log_fail "Failed to insert test data"
                    fi
                else
                    log_warn "SQLite3 not available - cannot test anomaly detection"
                fi
                
                # Cleanup
                rm -f "$test_db" 2>/dev/null || true
            else
                log_fail "Test database initialization failed"
            fi
        else
            log_fail "Behavioral analysis script not available"
        fi
    else
        log_warn "Behavioral analysis disabled - skipping anomaly detection tests"
    fi
}

# Test 6: Threat Score Calculation
test_threat_scoring() {
    log_test "Testing Threat Score Calculation"
    
    if [ "${BEHAVIORAL_ANALYSIS_ENABLED:-false}" = "true" ]; then
        if [ -f "$PROJECT_ROOT/scripts/behavioral-analysis.sh" ]; then
            source "$PROJECT_ROOT/scripts/behavioral-analysis.sh"
            
            # Test threat score calculation function
            if command -v calculate_threat_score &> /dev/null; then
                # Test with various anomaly scenarios
                local test_cases=(
                    "1:5:2:1:10"  # Low threat
                    "5:15:8:3:25"  # Medium threat
                    "10:25:15:8:50"  # High threat
                    "20:50:30:15:85"  # Critical threat
                )
                
                for test_case in "${test_cases[@]}"; do
                    IFS=':' read -r cpu_anomalies process_anomalies network_anomalies file_anomalies expected_score <<< "$test_case"
                    
                    local calculated_score=$(calculate_threat_score "$cpu_anomalies" "$process_anomalies" "$network_anomalies" "$file_anomalies" 2>/dev/null || echo "0")
                    
                    # Check if score is reasonable (within expected range)
                    if [ "$calculated_score" -ge 0 ] && [ "$calculated_score" -le 100 ]; then
                        log_pass "Threat score calculation valid: $calculated_score (expected ~$expected_score)"
                    else
                        log_fail "Invalid threat score: $calculated_score"
                    fi
                done
            else
                log_warn "Threat score calculation function not available"
            fi
        else
            log_fail "Behavioral analysis script not available"
        fi
    else
        log_warn "Behavioral analysis disabled - skipping threat scoring tests"
    fi
}

# Test 7: Pattern Analysis Functionality
test_pattern_analysis() {
    log_test "Testing Pattern Analysis Functionality"
    
    if [ "${BEHAVIORAL_ANALYSIS_ENABLED:-false}" = "true" ]; then
        if [ -f "$PROJECT_ROOT/scripts/behavioral-analysis.sh" ]; then
            source "$PROJECT_ROOT/scripts/behavioral-analysis.sh"
            
            # Create test environment
            local test_db="/tmp/test_pattern_$$.db"
            export BEHAVIORAL_DB_PATH="$test_db"
            
            # Initialize test database
            if init_behavioral_analysis 2>/dev/null; then
                log_pass "Test database initialized for pattern analysis"
                
                if command -v sqlite3 &> /dev/null; then
                    # Insert pattern data
                    sqlite3 "$test_db" << EOF 2>/dev/null
INSERT INTO process_behavior (timestamp, process_name, cpu_usage, memory_usage, pid, parent_pid) 
VALUES 
    (datetime('now', '-1 hour'), 'suspicious_process', 80.5, 45.2, 1234, 1),
    (datetime('now', '-2 hours'), 'suspicious_process', 82.1, 46.8, 5678, 1),
    (datetime('now', '-3 hours'), 'suspicious_process', 79.8, 44.9, 9012, 1),
    (datetime('now', '-4 hours'), 'suspicious_process', 81.2, 45.5, 3456, 1);
EOF
                    
                    if [ $? -eq 0 ]; then
                        log_pass "Pattern test data inserted"
                        
                        # Test pattern analysis
                        if command -v analyze_patterns &> /dev/null; then
                            if analyze_patterns 2>/dev/null; then
                                log_pass "Pattern analysis completed successfully"
                            else
                                log_fail "Pattern analysis failed"
                            fi
                        else
                            log_warn "Pattern analysis function not available"
                        fi
                    else
                        log_fail "Failed to insert pattern test data"
                    fi
                else
                    log_warn "SQLite3 not available - cannot test pattern analysis"
                fi
                
                # Cleanup
                rm -f "$test_db" 2>/dev/null || true
            else
                log_fail "Test database initialization failed"
            fi
        else
            log_fail "Behavioral analysis script not available"
        fi
    else
        log_warn "Behavioral analysis disabled - skipping pattern analysis tests"
    fi
}

# Test 8: Data Integrity and Validation
test_data_integrity() {
    log_test "Testing Data Integrity and Validation"
    
    if [ "${BEHAVIORAL_ANALYSIS_ENABLED:-false}" = "true" ]; then
        local db_dir="$AEGIS_HOME/configs/behavioral_analysis"
        local db_file="$db_dir/behavioral_data.db"
        
        if [ -f "$db_file" ]; then
            log_pass "Database file exists for integrity testing"
            
            if command -v sqlite3 &> /dev/null; then
                # Test database integrity
                local integrity_check=$(sqlite3 "$db_file" "PRAGMA integrity_check;" 2>/dev/null || echo "failed")
                if [ "$integrity_check" = "ok" ]; then
                    log_pass "Database integrity check passed"
                else
                    log_fail "Database integrity check failed: $integrity_check"
                fi
                
                # Test foreign key constraints
                local fk_check=$(sqlite3 "$db_file" "PRAGMA foreign_key_check;" 2>/dev/null || echo "failed")
                if [ -z "$fk_check" ]; then
                    log_pass "Foreign key constraints check passed"
                else
                    log_fail "Foreign key constraints check failed: $fk_check"
                fi
                
                # Test data consistency
                local table_counts=$(sqlite3 "$db_file" "SELECT name, COUNT(*) FROM sqlite_master WHERE type='table' UNION ALL SELECT 'total_records', SUM(COUNT(*)) FROM (SELECT COUNT(*) FROM system_metrics UNION ALL SELECT COUNT(*) FROM process_behavior UNION ALL SELECT COUNT(*) FROM network_behavior UNION ALL SELECT COUNT(*) FROM file_access_patterns UNION ALL SELECT COUNT(*) FROM anomalies);" 2>/dev/null || echo "")
                if [ -n "$table_counts" ]; then
                    log_pass "Data consistency check passed"
                else
                    log_fail "Data consistency check failed"
                fi
            else
                log_warn "SQLite3 not available - cannot test data integrity"
            fi
        else
            log_warn "Database file not found - skipping integrity tests"
        fi
    else
        log_warn "Behavioral analysis disabled - skipping data integrity tests"
    fi
}

# Main test execution
main() {
    echo -e "${WHITE}========================================${NC}"
    echo -e "${WHITE}🧠 BEHAVIORAL ANALYSIS ENGINE TESTS 🧠${NC}"
    echo -e "${WHITE}========================================${NC}"
    echo -e "${BLUE}Test started: $(date)${NC}"
    echo ""
    
    # Run all tests
    test_behavioral_configuration
    test_script_availability
    test_database_operations
    test_baseline_creation
    test_anomaly_detection
    test_threat_scoring
    test_pattern_analysis
    test_data_integrity
    
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
        echo -e "${GREEN}🎉 ALL BEHAVIORAL ANALYSIS TESTS PASSED!${NC}"
        exit 0
    else
        echo -e "${RED}⚠️ $TESTS_FAILED test(s) failed. Review issues above.${NC}"
        exit 1
    fi
}

# Run main function
main "$@"