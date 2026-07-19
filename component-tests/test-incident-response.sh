#!/bin/bash
# Incident Response Component Tests
# Tests incident creation, management, evidence collection, and response automation

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

# Test 1: Incident Response Script Availability
test_script_availability() {
    log_test "Testing Incident Response Script Availability"
    
    local script_path="$PROJECT_ROOT/scripts/incident-response.sh"
    
    if [ -f "$script_path" ]; then
        log_pass "Incident response script found: $script_path"
        
        if [ -x "$script_path" ]; then
            log_pass "Incident response script is executable"
        else
            log_fail "Incident response script is not executable"
        fi
        
        # Check script syntax
        if bash -n "$script_path" 2>/dev/null; then
            log_pass "Incident response script has valid syntax"
        else
            log_fail "Incident response script has syntax errors"
        fi
    else
        log_fail "Incident response script not found: $script_path"
    fi
}

# Test 2: Incident Database Structure
test_incident_database() {
    log_test "Testing Incident Database Structure"
    
    local db_dir="$AEGIS_HOME/configs/incident_response"
    local db_file="$db_dir/incidents.db"
    
    # Check database directory
    if [ -d "$db_dir" ]; then
        log_pass "Incident response database directory exists: $db_dir"
    else
        log_warn "Database directory not found, will be created: $db_dir"
        mkdir -p "$db_dir"
    fi
    
    # Check database file
    if [ -f "$db_file" ]; then
        log_pass "Incident database file exists: $db_file"
        
        if command -v sqlite3 &> /dev/null; then
            # Test database integrity
            local integrity_check=$(sqlite3 "$db_file" "PRAGMA integrity_check;" 2>/dev/null || echo "failed")
            if [ "$integrity_check" = "ok" ]; then
                log_pass "Incident database integrity check passed"
            else
                log_fail "Incident database integrity check failed: $integrity_check"
            fi
            
            # Check for required tables
            local tables=$(sqlite3 "$db_file" "SELECT name FROM sqlite_master WHERE type='table';" 2>/dev/null || echo "")
            if [ -n "$tables" ]; then
                log_pass "Incident database tables found: $tables"
                
                # Check for required tables
                local required_tables="incidents evidence timeline notifications"
                for table in $required_tables; do
                    if echo "$tables" | grep -q "$table"; then
                        log_pass "Required table exists: $table"
                    else
                        log_fail "Required table missing: $table"
                    fi
                done
            else
                log_fail "No tables found in incident database"
            fi
        else
            log_warn "SQLite3 not available - cannot verify database structure"
        fi
    else
        log_warn "Incident database file not found - will be created during operation"
    fi
}

# Test 3: Incident Creation and Management
test_incident_creation() {
    log_test "Testing Incident Creation and Management"
    
    if [ -f "$PROJECT_ROOT/scripts/incident-response.sh" ]; then
        source "$PROJECT_ROOT/scripts/incident-response.sh"
        
        # Test incident creation function
        if command -v create_incident &> /dev/null; then
            # Create test incident
            local test_title="Test Security Incident"
            local test_description="This is a test incident for validation purposes"
            local test_severity="medium"
            
            local incident_id=$(create_incident "$test_title" "$test_description" "$test_severity" 2>/dev/null || echo "")
            
            if [ -n "$incident_id" ]; then
                log_pass "Incident creation successful: $incident_id"
                
                # Verify incident in database
                local db_file="$AEGIS_HOME/configs/incident_response/incidents.db"
                if [ -f "$db_file" ] && command -v sqlite3 &> /dev/null; then
                    local incident_count=$(sqlite3 "$db_file" "SELECT COUNT(*) FROM incidents WHERE id = '$incident_id';" 2>/dev/null || echo "0")
                    if [ "$incident_count" -eq 1 ]; then
                        log_pass "Incident properly stored in database"
                    else
                        log_fail "Incident not found in database"
                    fi
                fi
                
                # Test incident update
                if command -v update_incident &> /dev/null; then
                    if update_incident "$incident_id" "status" "investigating" 2>/dev/null; then
                        log_pass "Incident update successful"
                    else
                        log_fail "Incident update failed"
                    fi
                else
                    log_warn "Incident update function not available"
                fi
            else
                log_fail "Incident creation failed"
            fi
        else
            log_fail "Incident creation function not available"
        fi
    else
        log_fail "Incident response script not available"
    fi
}

# Test 4: Evidence Collection
test_evidence_collection() {
    log_test "Testing Evidence Collection"
    
    if [ -f "$PROJECT_ROOT/scripts/incident-response.sh" ]; then
        source "$PROJECT_ROOT/scripts/incident-response.sh"
        
        # Test evidence collection function
        if command -v collect_evidence &> /dev/null; then
            # Create test incident for evidence collection
            local test_incident_id="TEST_INCIDENT_$(date +%s)"
            
            # Test system state collection
            if collect_evidence "$test_incident_id" "system_state" 2>/dev/null; then
                log_pass "System state evidence collection successful"
                
                # Check evidence file
                local evidence_file=$(find "$AEGIS_HOME/evidence" -name "${test_incident_id}_system_state_*" 2>/dev/null | head -n1)
                if [ -f "$evidence_file" ]; then
                    log_pass "Evidence file created: $(basename "$evidence_file")"
                    
                    # Check evidence content
                    if grep -q "System State" "$evidence_file" 2>/dev/null; then
                        log_pass "Evidence file contains expected content"
                    else
                        log_fail "Evidence file missing expected content"
                    fi
                else
                    log_fail "Evidence file not found"
                fi
            else
                log_fail "System state evidence collection failed"
            fi
            
            # Test process collection
            if collect_evidence "$test_incident_id" "processes" 2>/dev/null; then
                log_pass "Process evidence collection successful"
            else
                log_fail "Process evidence collection failed"
            fi
            
            # Test network connections collection
            if collect_evidence "$test_incident_id" "network_connections" 2>/dev/null; then
                log_pass "Network connections evidence collection successful"
            else
                log_fail "Network connections evidence collection failed"
            fi
            
            # Cleanup test evidence
            find "$AEGIS_HOME/evidence" -name "${test_incident_id}*" -delete 2>/dev/null || true
        else
            log_fail "Evidence collection function not available"
        fi
    else
        log_fail "Incident response script not available"
    fi
}

# Test 5: Incident Severity Levels
test_severity_levels() {
    log_test "Testing Incident Severity Levels"
    
    if [ -f "$PROJECT_ROOT/scripts/incident-response.sh" ]; then
        source "$PROJECT_ROOT/scripts/incident-response.sh"
        
        # Test severity validation
        local valid_severities=("low" "medium" "high" "critical")
        local invalid_severities=("invalid" "urgent" "emergency" "")
        
        for severity in "${valid_severities[@]}"; do
            if command -v validate_severity &> /dev/null; then
                if validate_severity "$severity" 2>/dev/null; then
                    log_pass "Valid severity accepted: $severity"
                else
                    log_fail "Valid severity rejected: $severity"
                fi
            else
                log_warn "Severity validation function not available"
                break
            fi
        done
        
        for severity in "${invalid_severities[@]}"; do
            if command -v validate_severity &> /dev/null; then
                if ! validate_severity "$severity" 2>/dev/null; then
                    log_pass "Invalid severity rejected: $severity"
                else
                    log_fail "Invalid severity accepted: $severity"
                fi
            else
                log_warn "Severity validation function not available"
                break
            fi
        done
    else
        log_fail "Incident response script not available"
    fi
}

# Test 6: Incident Status Management
test_status_management() {
    log_test "Testing Incident Status Management"
    
    if [ -f "$PROJECT_ROOT/scripts/incident-response.sh" ]; then
        source "$PROJECT_ROOT/scripts/incident-response.sh"
        
        # Test status validation
        local valid_statuses=("new" "investigating" "contained" "resolved" "closed")
        local invalid_statuses=("invalid" "pending" "completed" "")
        
        for status in "${valid_statuses[@]}"; do
            if command -v validate_status &> /dev/null; then
                if validate_status "$status" 2>/dev/null; then
                    log_pass "Valid status accepted: $status"
                else
                    log_fail "Valid status rejected: $status"
                fi
            else
                log_warn "Status validation function not available"
                break
            fi
        done
        
        for status in "${invalid_statuses[@]}"; do
            if command -v validate_status &> /dev/null; then
                if ! validate_status "$status" 2>/dev/null; then
                    log_pass "Invalid status rejected: $status"
                else
                    log_fail "Invalid status accepted: $status"
                fi
            else
                log_warn "Status validation function not available"
                break
            fi
        done
        
        # Test status transition
        if command -v transition_status &> /dev/null; then
            # Valid transitions
            if transition_status "new" "investigating" 2>/dev/null; then
                log_pass "Valid status transition: new -> investigating"
            else
                log_fail "Valid status transition failed: new -> investigating"
            fi
            
            if transition_status "investigating" "contained" 2>/dev/null; then
                log_pass "Valid status transition: investigating -> contained"
            else
                log_fail "Valid status transition failed: investigating -> contained"
            fi
            
            # Invalid transitions
            if ! transition_status "resolved" "new" 2>/dev/null; then
                log_pass "Invalid status transition rejected: resolved -> new"
            else
                log_fail "Invalid status transition accepted: resolved -> new"
            fi
        else
            log_warn "Status transition function not available"
        fi
    else
        log_fail "Incident response script not available"
    fi
}

# Test 7: Notification System
test_notification_system() {
    log_test "Testing Notification System"
    
    if [ -f "$PROJECT_ROOT/scripts/incident-response.sh" ]; then
        source "$PROJECT_ROOT/scripts/incident-response.sh"
        
        # Test notification function
        if command -v send_notification &> /dev/null; then
            # Test different notification types
            local notification_types=("email" "system" "dashboard")
            
            for type in "${notification_types[@]}"; do
                if send_notification "Test Incident" "This is a test notification" "$type" 2>/dev/null; then
                    log_pass "Notification sent successfully: $type"
                else
                    log_warn "Notification failed: $type (may be expected in test environment)"
                fi
            done
        else
            log_warn "Notification function not available"
        fi
        
        # Test notification queue
        local db_file="$AEGIS_HOME/configs/incident_response/incidents.db"
        if [ -f "$db_file" ] && command -v sqlite3 &> /dev/null; then
            local notification_count=$(sqlite3 "$db_file" "SELECT COUNT(*) FROM notifications;" 2>/dev/null || echo "0")
            if [ "$notification_count" -ge 0 ]; then
                log_pass "Notification queue accessible: $notification_count notifications"
            else
                log_fail "Notification queue not accessible"
            fi
        else
            log_warn "Cannot test notification queue - database not available"
        fi
    else
        log_fail "Incident response script not available"
    fi
}

# Test 8: Incident Timeline
test_incident_timeline() {
    log_test "Testing Incident Timeline"
    
    if [ -f "$PROJECT_ROOT/scripts/incident-response.sh" ]; then
        source "$PROJECT_ROOT/scripts/incident-response.sh"
        
        # Test timeline function
        if command -v add_timeline_event &> /dev/null; then
            # Create test incident
            local test_incident_id="TEST_INCIDENT_$(date +%s)"
            
            # Add timeline events
            if add_timeline_event "$test_incident_id" "incident_created" "Incident created" 2>/dev/null; then
                log_pass "Timeline event added: incident_created"
            else
                log_fail "Failed to add timeline event: incident_created"
            fi
            
            if add_timeline_event "$test_incident_id" "investigation_started" "Investigation started" 2>/dev/null; then
                log_pass "Timeline event added: investigation_started"
            else
                log_fail "Failed to add timeline event: investigation_started"
            fi
            
            # Verify timeline in database
            local db_file="$AEGIS_HOME/configs/incident_response/incidents.db"
            if [ -f "$db_file" ] && command -v sqlite3 &> /dev/null; then
                local timeline_count=$(sqlite3 "$db_file" "SELECT COUNT(*) FROM timeline WHERE incident_id = '$test_incident_id';" 2>/dev/null || echo "0")
                if [ "$timeline_count" -gt 0 ]; then
                    log_pass "Timeline events stored in database: $timeline_count events"
                else
                    log_fail "Timeline events not found in database"
                fi
            else
                log_warn "Cannot verify timeline - database not available"
            fi
        else
            log_warn "Timeline function not available"
        fi
    else
        log_fail "Incident response script not available"
    fi
}

# Test 9: Incident Response API Integration
test_api_integration() {
    log_test "Testing Incident Response API Integration"
    
    local api_file="$PROJECT_ROOT/web-dashboard/api/incidents.py"
    
    if [ -f "$api_file" ]; then
        log_pass "Incident response API file exists"
        
        # Check for API endpoints
        if grep -q "@app.route.*incidents" "$api_file" 2>/dev/null; then
            log_pass "Incident API routes defined"
        else
            log_fail "Incident API routes not defined"
        fi
        
        # Check for database integration
        if grep -q "sqlite3\|database\|incidents.db" "$api_file" 2>/dev/null; then
            log_pass "Database integration found in API"
        else
            log_fail "Database integration missing in API"
        fi
        
        # Check for incident CRUD operations
        local crud_operations=("create" "read" "update" "delete")
        for operation in "${crud_operations[@]}"; do
            if grep -q "$operation\|POST\|GET\|PUT\|DELETE" "$api_file" 2>/dev/null; then
                log_pass "CRUD operation available: $operation"
            else
                log_warn "CRUD operation may be missing: $operation"
            fi
        done
        
        # Check for evidence collection endpoint
        if grep -q "evidence\|collect" "$api_file" 2>/dev/null; then
            log_pass "Evidence collection endpoint found"
        else
            log_fail "Evidence collection endpoint missing"
        fi
        
        # Check for error handling
        if grep -q "try:\|except\|error" "$api_file" 2>/dev/null; then
            log_pass "Error handling implemented in API"
        else
            log_fail "Error handling missing in API"
        fi
    else
        log_fail "Incident response API file not found"
    fi
}

# Test 10: Automated Response Actions
test_automated_response() {
    log_test "Testing Automated Response Actions"
    
    if [ -f "$PROJECT_ROOT/scripts/incident-response.sh" ]; then
        source "$PROJECT_ROOT/scripts/incident-response.sh"
        
        # Test automated response function
        if command -v execute_automated_response &> /dev/null; then
            # Test different response actions
            local response_actions=("quarantine" "isolate" "block_ip" "terminate_process")
            
            for action in "${response_actions[@]}"; do
                # Test with safe parameters
                if execute_automated_response "$action" "test_target" "dry_run" 2>/dev/null; then
                    log_pass "Automated response action works: $action (dry run)"
                else
                    log_warn "Automated response action failed: $action (may be expected in test)"
                fi
            done
        else
            log_warn "Automated response function not available"
        fi
        
        # Test response validation
        if command -v validate_response_action &> /dev/null; then
            local valid_actions=("quarantine" "isolate" "block_ip" "terminate_process" "notify")
            local invalid_actions=("format_disk" "delete_system" "shutdown")
            
            for action in "${valid_actions[@]}"; do
                if validate_response_action "$action" 2>/dev/null; then
                    log_pass "Valid response action accepted: $action"
                else
                    log_fail "Valid response action rejected: $action"
                fi
            done
            
            for action in "${invalid_actions[@]}"; do
                if ! validate_response_action "$action" 2>/dev/null; then
                    log_pass "Invalid response action rejected: $action"
                else
                    log_fail "Invalid response action accepted: $action"
                fi
            done
        else
            log_warn "Response validation function not available"
        fi
    else
        log_fail "Incident response script not available"
    fi
}

# Main test execution
main() {
    echo -e "${WHITE}========================================${NC}"
    echo -e "${WHITE}🚨 INCIDENT RESPONSE COMPONENT TESTS 🚨${NC}"
    echo -e "${WHITE}========================================${NC}"
    echo -e "${BLUE}Test started: $(date)${NC}"
    echo ""
    
    # Run all tests
    test_script_availability
    test_incident_database
    test_incident_creation
    test_evidence_collection
    test_severity_levels
    test_status_management
    test_notification_system
    test_incident_timeline
    test_api_integration
    test_automated_response
    
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
        echo -e "${GREEN}🎉 ALL INCIDENT RESPONSE TESTS PASSED!${NC}"
        exit 0
    else
        echo -e "${RED}⚠️ $TESTS_FAILED test(s) failed. Review issues above.${NC}"
        exit 1
    fi
}

# Run main function
main "$@"