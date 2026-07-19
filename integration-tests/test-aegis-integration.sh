#!/bin/bash
# Security Suite Integration Tests
# Tests integration between all security suite components

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

# Test 1: Configuration Integration
test_configuration_integration() {
    log_test "Testing Configuration Integration"
    
    # Check main configuration file
    if [ -f "$PROJECT_ROOT/configs/security-config.conf" ]; then
        log_pass "Main configuration file exists"
        
        # Check for component configurations
        local component_configs=(
            "BEHAVIORAL_ANALYSIS_ENABLED"
            "THREAT_INTELLIGENCE_ENABLED"
            "INCIDENT_RESPONSE_ENABLED"
            "DASHBOARD_ENABLED"
        )
        
        for config in "${component_configs[@]}"; do
            if [ -n "${!config:-}" ]; then
                log_pass "Component configuration found: $config=${!config}"
            else
                log_warn "Component configuration missing: $config"
            fi
        done
    else
        log_fail "Main configuration file not found"
    fi
    
    # Check component-specific configuration files
    local config_dirs=(
        "$AEGIS_HOME/configs/behavioral_analysis"
        "$AEGIS_HOME/configs/threat_intelligence"
        "$AEGIS_HOME/configs/incident_response"
        "$AEGIS_HOME/web-dashboard/config"
    )
    
    for dir in "${config_dirs[@]}"; do
        if [ -d "$dir" ]; then
            log_pass "Component configuration directory exists: $(basename "$dir")"
        else
            log_warn "Component configuration directory missing: $(basename "$dir")"
        fi
    done
}

# Test 2: Script Integration
test_script_integration() {
    log_test "Testing Script Integration"
    
    # Check for main scripts
    local main_scripts=(
        "behavioral-analysis.sh"
        "behavioral-monitor.sh"
        "threat-intelligence-v2.sh"
        "incident-response.sh"
        "security-daily-scan.sh"
    )
    
    for script in "${main_scripts[@]}"; do
        if [ -f "$PROJECT_ROOT/scripts/$script" ]; then
            log_pass "Main script exists: $script"
            
            # Check if script is executable
            if [ -x "$PROJECT_ROOT/scripts/$script" ]; then
                log_pass "Script is executable: $script"
            else
                log_fail "Script is not executable: $script"
            fi
            
            # Check script syntax
            if bash -n "$PROJECT_ROOT/scripts/$script" 2>/dev/null; then
                log_pass "Script has valid syntax: $script"
            else
                log_fail "Script has syntax errors: $script"
            fi
        else
            log_fail "Main script missing: $script"
        fi
    done
    
    # Check for cross-script integration
    if grep -q "behavioral-analysis.sh" "$PROJECT_ROOT/scripts/security-daily-scan.sh" 2>/dev/null; then
        log_pass "Daily scan integrates with behavioral analysis"
    else
        log_fail "Daily scan missing behavioral analysis integration"
    fi
    
    if grep -q "incident-response.sh" "$PROJECT_ROOT/scripts/behavioral-analysis.sh" 2>/dev/null; then
        log_pass "Behavioral analysis integrates with incident response"
    else
        log_fail "Behavioral analysis missing incident response integration"
    fi
    
    if grep -q "threat-intelligence-v2.sh" "$PROJECT_ROOT/scripts/security-daily-scan.sh" 2>/dev/null; then
        log_pass "Daily scan integrates with threat intelligence"
    else
        log_fail "Daily scan missing threat intelligence integration"
    fi
}

# Test 3: Database Integration
test_database_integration() {
    log_test "Testing Database Integration"
    
    # Check for database files
    local databases=(
        "$AEGIS_HOME/configs/behavioral_analysis/behavioral_data.db"
        "$AEGIS_HOME/configs/threat_intelligence/ioc_database.db"
        "$AEGIS_HOME/configs/incident_response/incidents.db"
    )
    
    for db in "${databases[@]}"; do
        if [ -f "$db" ]; then
            log_pass "Database file exists: $(basename "$db")"
            
            # Test database integrity
            if command -v sqlite3 &> /dev/null; then
                local integrity_check=$(sqlite3 "$db" "PRAGMA integrity_check;" 2>/dev/null || echo "failed")
                if [ "$integrity_check" = "ok" ]; then
                    log_pass "Database integrity check passed: $(basename "$db")"
                else
                    log_fail "Database integrity check failed: $(basename "$db")"
                fi
            else
                log_warn "SQLite3 not available - cannot check database integrity"
            fi
        else
            log_warn "Database file not found: $(basename "$db")"
        fi
    done
    
    # Test database cross-references
    local behavioral_db="$AEGIS_HOME/configs/behavioral_analysis/behavioral_data.db"
    local incident_db="$AEGIS_HOME/configs/incident_response/incidents.db"
    
    if [ -f "$behavioral_db" ] && [ -f "$incident_db" ] && command -v sqlite3 &> /dev/null; then
        # Check if behavioral analysis can create incidents
        local behavioral_tables=$(sqlite3 "$behavioral_db" "SELECT name FROM sqlite_master WHERE type='table';" 2>/dev/null || echo "")
        local incident_tables=$(sqlite3 "$incident_db" "SELECT name FROM sqlite_master WHERE type='table';" 2>/dev/null || echo "")
        
        if echo "$behavioral_tables" | grep -q "anomalies" && echo "$incident_tables" | grep -q "incidents"; then
            log_pass "Database tables support cross-component integration"
        else
            log_fail "Database tables missing cross-component integration support"
        fi
    else
        log_warn "Cannot test database cross-references - databases not available"
    fi
}

# Test 4: Logging Integration
test_logging_integration() {
    log_test "Testing Logging Integration"
    
    # Check for log directories
    local log_dirs=(
        "$AEGIS_HOME/logs/error"
        "$AEGIS_HOME/logs/manual"
        "$AEGIS_HOME/logs/behavioral"
        "$AEGIS_HOME/logs/incidents"
    )
    
    for dir in "${log_dirs[@]}"; do
        if [ -d "$dir" ]; then
            log_pass "Log directory exists: $(basename "$dir")"
        else
            log_warn "Log directory missing: $(basename "$dir")"
        fi
    done
    
    # Check for log files
    local log_files=$(find "$AEGIS_HOME/logs" -name "*.log" -type f 2>/dev/null)
    if [ -n "$log_files" ]; then
        log_pass "Log files found"
        
        # Check log file formats
        local log_count=0
        local formatted_logs=0
        while IFS= read -r -d '' log_file; do
            ((log_count++))
            # Check for standard log format (timestamp, level, message)
            if head -n 5 "$log_file" | grep -q "^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}"; then
                ((formatted_logs++))
            fi
        done < <(find "$AEGIS_HOME/logs" -name "*.log" -type f -print0 2>/dev/null)
        
        if [ "$formatted_logs" -eq "$log_count" ]; then
            log_pass "All log files have proper format"
        else
            log_warn "Some log files may have format issues"
        fi
    else
        log_warn "No log files found"
    fi
    
    # Test logging functions integration
    if [ -f "$PROJECT_ROOT/scripts/common-functions.sh" ]; then
        source "$PROJECT_ROOT/scripts/common-functions.sh"
        
        # Test logging functions
        if command -v log_error &> /dev/null; then
            log_pass "Error logging function available"
        else
            log_fail "Error logging function not available"
        fi
        
        if command -v log_info &> /dev/null; then
            log_pass "Info logging function available"
        else
            log_fail "Info logging function not available"
        fi
        
        if command -v log_success &> /dev/null; then
            log_pass "Success logging function available"
        else
            log_fail "Success logging function not available"
        fi
    else
        log_fail "Common functions script not found"
    fi
}

# Test 5: Notification Integration
test_notification_integration() {
    log_test "Testing Notification Integration"
    
    # Check for notification configuration
    if [ -n "${NOTIFICATION_ENABLED:-}" ]; then
        log_pass "Notification configuration found: $NOTIFICATION_ENABLED"
    else
        log_warn "Notification configuration not found"
    fi
    
    # Check for notification methods
    local notification_methods=("email" "desktop" "webhook" "dashboard")
    local configured_methods=0
    
    for method in "${notification_methods[@]}"; do
        local config_var="${method^^}_NOTIFICATIONS_ENABLED"
        config_var="${config_var//-/_}"
        
        if [ "${!config_var:-false}" = "true" ]; then
            log_pass "Notification method configured: $method"
            ((configured_methods++))
        fi
    done
    
    if [ "$configured_methods" -gt 0 ]; then
        log_pass "Notification methods configured: $configured_methods"
    else
        log_warn "No notification methods configured"
    fi
    
    # Test notification integration across components
    local scripts_with_notifications=(
        "$PROJECT_ROOT/scripts/behavioral-analysis.sh"
        "$PROJECT_ROOT/scripts/incident-response.sh"
        "$PROJECT_ROOT/scripts/security-daily-scan.sh"
    )
    
    local scripts_with_notification_support=0
    for script in "${scripts_with_notifications[@]}"; do
        if [ -f "$script" ]; then
            if grep -q "notification\|notify\|alert" "$script" 2>/dev/null; then
                log_pass "Script supports notifications: $(basename "$script")"
                ((scripts_with_notification_support++))
            else
                log_warn "Script may not support notifications: $(basename "$script")"
            fi
        fi
    done
    
    if [ "$scripts_with_notification_support" -gt 0 ]; then
        log_pass "Scripts with notification support: $scripts_with_notification_support"
    else
        log_fail "No scripts support notifications"
    fi
}

# Test 6: Service Integration
test_service_integration() {
    log_test "Testing Service Integration"
    
    # Check for systemd services
    local service_files=(
        "$HOME/.config/systemd/user/behavioral-monitor.service"
        "$HOME/.config/systemd/user/behavioral-monitor.timer"
        "$HOME/.config/systemd/user/security-daily-scan.service"
        "$HOME/.config/systemd/user/security-daily-scan.timer"
    )
    
    for service in "${service_files[@]}"; do
        if [ -f "$service" ]; then
            log_pass "Systemd service file exists: $(basename "$service")"
            
            # Check service file syntax
            if grep -q "\[Unit\]\|\[Service\]\|\[Timer\]" "$service" 2>/dev/null; then
                log_pass "Service file has proper structure: $(basename "$service")"
            else
                log_fail "Service file missing required sections: $(basename "$service")"
            fi
        else
            log_warn "Systemd service file missing: $(basename "$service")"
        fi
    done
    
    # Check service status
    if command -v systemctl &> /dev/null; then
        local active_services=0
        local services=("behavioral-monitor.timer" "security-daily-scan.timer")
        
        for service in "${services[@]}"; do
            if systemctl --user is-active --quiet "$service" 2>/dev/null; then
                log_pass "Service is active: $service"
                ((active_services++))
            else
                log_warn "Service is not active: $service"
            fi
        done
        
        if [ "$active_services" -gt 0 ]; then
            log_pass "Active services: $active_services"
        else
            log_warn "No active services found"
        fi
    else
        log_warn "Systemctl not available - cannot check service status"
    fi
}

# Test 7: Dashboard Integration
test_dashboard_integration() {
    log_test "Testing Dashboard Integration"
    
    # Check dashboard files
    local dashboard_files=(
        "$PROJECT_ROOT/web-dashboard/app.py"
        "$PROJECT_ROOT/web-dashboard/start-dashboard.sh"
        "$PROJECT_ROOT/web-dashboard/requirements.txt"
    )
    
    for file in "${dashboard_files[@]}"; do
        if [ -f "$file" ]; then
            log_pass "Dashboard file exists: $(basename "$file")"
        else
            log_fail "Dashboard file missing: $(basename "$file")"
        fi
    done
    
    # Check dashboard API integration
    local api_files=(
        "$PROJECT_ROOT/web-dashboard/api/system.py"
        "$PROJECT_ROOT/web-dashboard/api/behavioral.py"
        "$PROJECT_ROOT/web-dashboard/api/threats.py"
        "$PROJECT_ROOT/web-dashboard/api/incidents.py"
    )
    
    for file in "${api_files[@]}"; do
        if [ -f "$file" ]; then
            log_pass "Dashboard API file exists: $(basename "$file")"
            
            # Check for database integration
            if grep -q "sqlite3\|database\|AEGIS_HOME" "$file" 2>/dev/null; then
                log_pass "API integrates with security suite: $(basename "$file")"
            else
                log_warn "API may not integrate with security suite: $(basename "$file")"
            fi
        else
            log_fail "Dashboard API file missing: $(basename "$file")"
        fi
    done
    
    # Check dashboard configuration integration
    if [ -f "$PROJECT_ROOT/web-dashboard/config/dashboard.conf" ]; then
        if grep -q "AEGIS_HOME\|security-config.conf" "$PROJECT_ROOT/web-dashboard/config/dashboard.conf" 2>/dev/null; then
            log_pass "Dashboard integrates with security suite configuration"
        else
            log_fail "Dashboard does not integrate with security suite configuration"
        fi
    else
        log_fail "Dashboard configuration file missing"
    fi
}

# Test 8: Workflow Integration
test_workflow_integration() {
    log_test "Testing Workflow Integration"
    
    # Test daily scan workflow
    if [ -f "$PROJECT_ROOT/scripts/security-daily-scan.sh" ]; then
        # Check if daily scan includes all components
        local components_in_scan=0
        
        if grep -q "behavioral-analysis.sh" "$PROJECT_ROOT/scripts/security-daily-scan.sh" 2>/dev/null; then
            log_pass "Daily scan includes behavioral analysis"
            ((components_in_scan++))
        else
            log_fail "Daily scan missing behavioral analysis"
        fi
        
        if grep -q "threat-intelligence-v2.sh" "$PROJECT_ROOT/scripts/security-daily-scan.sh" 2>/dev/null; then
            log_pass "Daily scan includes threat intelligence"
            ((components_in_scan++))
        else
            log_fail "Daily scan missing threat intelligence"
        fi
        
        if grep -q "incident-response.sh" "$PROJECT_ROOT/scripts/security-daily-scan.sh" 2>/dev/null; then
            log_pass "Daily scan includes incident response"
            ((components_in_scan++))
        else
            log_fail "Daily scan missing incident response"
        fi
        
        if [ "$components_in_scan" -eq 3 ]; then
            log_pass "Daily scan workflow is complete"
        else
            log_fail "Daily scan workflow is incomplete"
        fi
    else
        log_fail "Daily scan script not found"
    fi
    
    # Test incident response workflow
    if [ -f "$PROJECT_ROOT/scripts/incident-response.sh" ]; then
        # Check if incident response integrates with other components
        local integrations_in_ir=0
        
        if grep -q "behavioral-analysis.sh" "$PROJECT_ROOT/scripts/incident-response.sh" 2>/dev/null; then
            log_pass "Incident response integrates with behavioral analysis"
            ((integrations_in_ir++))
        else
            log_fail "Incident response missing behavioral analysis integration"
        fi
        
        if grep -q "threat-intelligence-v2.sh" "$PROJECT_ROOT/scripts/incident-response.sh" 2>/dev/null; then
            log_pass "Incident response integrates with threat intelligence"
            ((integrations_in_ir++))
        else
            log_fail "Incident response missing threat intelligence integration"
        fi
        
        if [ "$integrations_in_ir" -ge 1 ]; then
            log_pass "Incident response workflow has integrations"
        else
            log_fail "Incident response workflow lacks integrations"
        fi
    else
        log_fail "Incident response script not found"
    fi
}

# Test 9: Data Flow Integration
test_data_flow_integration() {
    log_test "Testing Data Flow Integration"
    
    # Test behavioral analysis to incident response data flow
    local behavioral_db="$AEGIS_HOME/configs/behavioral_analysis/behavioral_data.db"
    local incident_db="$AEGIS_HOME/configs/incident_response/incidents.db"
    
    if [ -f "$behavioral_db" ] && [ -f "$incident_db" ] && command -v sqlite3 &> /dev/null; then
        # Check if behavioral analysis can trigger incidents
        local behavioral_anomalies=$(sqlite3 "$behavioral_db" "SELECT COUNT(*) FROM anomalies;" 2>/dev/null || echo "0")
        local incident_count=$(sqlite3 "$incident_db" "SELECT COUNT(*) FROM incidents;" 2>/dev/null || echo "0")
        
        log_pass "Behavioral anomalies: $behavioral_anomalies"
        log_pass "Incident count: $incident_count"
        
        # Test data flow by creating a test anomaly
        local test_anomaly_id="TEST_ANOMALY_$(date +%s)"
        sqlite3 "$behavioral_db" "INSERT INTO anomalies (id, type, severity, detected_at) VALUES ('$test_anomaly_id', 'test', 'high', datetime('now'));" 2>/dev/null || true
        
        # Check if anomaly can be processed by incident response
        if [ -f "$PROJECT_ROOT/scripts/behavioral-analysis.sh" ]; then
            source "$PROJECT_ROOT/scripts/behavioral-analysis.sh"
            
            if command -v process_anomaly &> /dev/null; then
                if process_anomaly "$test_anomaly_id" 2>/dev/null; then
                    log_pass "Anomaly processing works"
                else
                    log_fail "Anomaly processing failed"
                fi
            else
                log_warn "Anomaly processing function not available"
            fi
        fi
        
        # Cleanup test anomaly
        sqlite3 "$behavioral_db" "DELETE FROM anomalies WHERE id = '$test_anomaly_id';" 2>/dev/null || true
    else
        log_warn "Cannot test data flow - databases not available"
    fi
    
    # Test threat intelligence to behavioral analysis data flow
    local threat_db="$AEGIS_HOME/configs/threat_intelligence/ioc_database.db"
    
    if [ -f "$threat_db" ] && [ -f "$behavioral_db" ] && command -v sqlite3 &> /dev/null; then
        # Check if threat intelligence provides data to behavioral analysis
        local ioc_count=$(sqlite3 "$threat_db" "SELECT COUNT(*) FROM indicators;" 2>/dev/null || echo "0")
        
        if [ "$ioc_count" -gt 0 ]; then
            log_pass "Threat intelligence provides IOCs: $ioc_count"
            
            # Test if behavioral analysis can use threat intelligence
            if [ -f "$PROJECT_ROOT/scripts/behavioral-analysis.sh" ]; then
                if grep -q "threat_intelligence\|ioc_database" "$PROJECT_ROOT/scripts/behavioral-analysis.sh" 2>/dev/null; then
                    log_pass "Behavioral analysis uses threat intelligence data"
                else
                    log_fail "Behavioral analysis does not use threat intelligence data"
                fi
            fi
        else
            log_warn "No IOCs found in threat intelligence database"
        fi
    else
        log_warn "Cannot test threat intelligence data flow - databases not available"
    fi
}

# Test 10: Error Handling Integration
test_error_handling_integration() {
    log_test "Testing Error Handling Integration"
    
    # Check for common error handling patterns
    local scripts=(
        "$PROJECT_ROOT/scripts/behavioral-analysis.sh"
        "$PROJECT_ROOT/scripts/incident-response.sh"
        "$PROJECT_ROOT/scripts/security-daily-scan.sh"
        "$PROJECT_ROOT/scripts/threat-intelligence-v2.sh"
    )
    
    local scripts_with_error_handling=0
    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            if grep -q "set -e\|trap\|error\|exit" "$script" 2>/dev/null; then
                log_pass "Script has error handling: $(basename "$script")"
                ((scripts_with_error_handling++))
            else
                log_fail "Script lacks error handling: $(basename "$script")"
            fi
        fi
    done
    
    if [ "$scripts_with_error_handling" -gt 0 ]; then
        log_pass "Scripts with error handling: $scripts_with_error_handling"
    else
        log_fail "No scripts have error handling"
    fi
    
    # Test error propagation
    if [ -f "$PROJECT_ROOT/scripts/common-functions.sh" ]; then
        source "$PROJECT_ROOT/scripts/common-functions.sh"
        
        # Test error logging function
        if command -v log_error &> /dev/null; then
            log_pass "Error logging function available"
            
            # Test error logging
            local test_log="/tmp/test_error_$$.log"
            if log_error "Test error message" 2>"$test_log"; then
                if grep -q "Test error message" "$test_log" 2>/dev/null; then
                    log_pass "Error logging works correctly"
                else
                    log_fail "Error logging does not work correctly"
                fi
                rm -f "$test_log"
            else
                log_fail "Error logging function failed"
            fi
        else
            log_fail "Error logging function not available"
        fi
    else
        log_fail "Common functions script not found"
    fi
}

# Main test execution
main() {
    echo -e "${WHITE}========================================${NC}"
    echo -e "${WHITE}🔗 SECURITY SUITE INTEGRATION TESTS 🔗${NC}"
    echo -e "${WHITE}========================================${NC}"
    echo -e "${BLUE}Test started: $(date)${NC}"
    echo ""
    
    # Run all tests
    test_configuration_integration
    test_script_integration
    test_database_integration
    test_logging_integration
    test_notification_integration
    test_service_integration
    test_dashboard_integration
    test_workflow_integration
    test_data_flow_integration
    test_error_handling_integration
    
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
        echo -e "${GREEN}🎉 ALL SECURITY SUITE INTEGRATION TESTS PASSED!${NC}"
        exit 0
    else
        echo -e "${RED}⚠️ $TESTS_FAILED test(s) failed. Review issues above.${NC}"
        exit 1
    fi
}

# Run main function
main "$@"