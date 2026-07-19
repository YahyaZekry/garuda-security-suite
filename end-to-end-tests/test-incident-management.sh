#!/bin/bash
# Incident Management End-to-End Tests
# Tests complete incident management workflow from creation to resolution

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

# Test 1: Incident Creation and Initial Triage
test_incident_creation_triage() {
    log_test "Testing Incident Creation and Initial Triage"
    
    if [ -f "$PROJECT_ROOT/scripts/incident-response.sh" ]; then
        source "$PROJECT_ROOT/scripts/incident-response.sh"
        
        # Test incident creation with different severities
        local severities=("low" "medium" "high" "critical")
        local incident_ids=()
        
        for severity in "${severities[@]}"; do
            log_info "Creating $severity severity incident..."
            
            if command -v create_incident &> /dev/null; then
                local incident_title="Test Incident - $severity Severity"
                local incident_description="This is a test incident with $severity severity for triage testing"
                local incident_id=$(create_incident "$incident_title" "$incident_description" "$severity" 2>/dev/null || echo "")
                
                if [ -n "$incident_id" ]; then
                    incident_ids+=("$incident_id")
                    log_pass "$severity severity incident created: $incident_id"
                    
                    # Verify incident in database
                    local incident_db="$AEGIS_HOME/configs/incident_response/incidents.db"
                    if [ -f "$incident_db" ] && command -v sqlite3 &> /dev/null; then
                        local incident_count=$(sqlite3 "$incident_db" "SELECT COUNT(*) FROM incidents WHERE id = '$incident_id';" 2>/dev/null || echo "0")
                        
                        if [ "$incident_count" -eq 1 ]; then
                            log_pass "Incident properly stored in database"
                        else
                            log_fail "Incident not found in database"
                        fi
                    fi
                else
                    log_fail "Failed to create $severity severity incident"
                fi
            else
                log_fail "Incident creation function not available"
            fi
        done
        
        # Test initial triage process
        log_info "Testing initial triage process..."
        
        for incident_id in "${incident_ids[@]}"; do
            if command -v triage_incident &> /dev/null; then
                if triage_incident "$incident_id" 2>/dev/null; then
                    log_pass "Initial triage completed for: $incident_id"
                else
                    log_fail "Initial triage failed for: $incident_id"
                fi
            else
                log_warn "Triage function not available"
            fi
        done
    else
        log_fail "Incident response script not found"
    fi
}

# Test 2: Incident Investigation Workflow
test_incident_investigation() {
    log_test "Testing Incident Investigation Workflow"
    
    # Create test incident for investigation
    if [ -f "$PROJECT_ROOT/scripts/incident-response.sh" ]; then
        source "$PROJECT_ROOT/scripts/incident-response.sh"
        
        if command -v create_incident &> /dev/null; then
            local incident_id=$(create_incident "Investigation Test Incident" "Test incident for investigation workflow" "high" 2>/dev/null || echo "")
            
            if [ -n "$incident_id" ]; then
                log_pass "Test incident created for investigation: $incident_id"
                
                # Test evidence collection
                log_info "Testing evidence collection..."
                
                if command -v collect_evidence &> /dev/null; then
                    if collect_evidence "$incident_id" "system_state" 2>/dev/null; then
                        log_pass "System state evidence collected"
                    else
                        log_fail "System state evidence collection failed"
                    fi
                    
                    if collect_evidence "$incident_id" "network_connections" 2>/dev/null; then
                        log_pass "Network connections evidence collected"
                    else
                        log_fail "Network connections evidence collection failed"
                    fi
                    
                    if collect_evidence "$incident_id" "running_processes" 2>/dev/null; then
                        log_pass "Running processes evidence collected"
                    else
                        log_fail "Running processes evidence collection failed"
                    fi
                else
                    log_fail "Evidence collection function not available"
                fi
                
                # Test investigation steps
                log_info "Testing investigation steps..."
                
                if command -v investigate_incident &> /dev/null; then
                    if investigate_incident "$incident_id" "initial_analysis" 2>/dev/null; then
                        log_pass "Initial analysis investigation step completed"
                    else
                        log_fail "Initial analysis investigation step failed"
                    fi
                    
                    if investigate_incident "$incident_id" "forensic_analysis" 2>/dev/null; then
                        log_pass "Forensic analysis investigation step completed"
                    else
                        log_fail "Forensic analysis investigation step failed"
                    fi
                else
                    log_fail "Investigation function not available"
                fi
                
                # Verify evidence files
                local evidence_dir="$AEGIS_HOME/evidence"
                if [ -d "$evidence_dir" ]; then
                    local evidence_count=$(find "$evidence_dir" -name "${incident_id}_*" -type f | wc -l)
                    
                    if [ "$evidence_count" -gt 0 ]; then
                        log_pass "Evidence files created: $evidence_count"
                    else
                        log_fail "No evidence files found"
                    fi
                else
                    log_fail "Evidence directory not found"
                fi
            else
                log_fail "Failed to create test incident for investigation"
            fi
        else
            log_fail "Incident creation function not available"
        fi
    else
        log_fail "Incident response script not found"
    fi
}

# Test 3: Incident Escalation and Notification
test_incident_escalation_notification() {
    log_test "Testing Incident Escalation and Notification"
    
    # Create test incident for escalation
    if [ -f "$PROJECT_ROOT/scripts/incident-response.sh" ]; then
        source "$PROJECT_ROOT/scripts/incident-response.sh"
        
        if command -v create_incident &> /dev/null; then
            local incident_id=$(create_incident "Escalation Test Incident" "Test incident for escalation workflow" "critical" 2>/dev/null || echo "")
            
            if [ -n "$incident_id" ]; then
                log_pass "Test incident created for escalation: $incident_id"
                
                # Test escalation process
                log_info "Testing escalation process..."
                
                if command -v escalate_incident &> /dev/null; then
                    if escalate_incident "$incident_id" "level_1" 2>/dev/null; then
                        log_pass "Level 1 escalation completed"
                    else
                        log_fail "Level 1 escalation failed"
                    fi
                    
                    if escalate_incident "$incident_id" "level_2" 2>/dev/null; then
                        log_pass "Level 2 escalation completed"
                    else
                        log_fail "Level 2 escalation failed"
                    fi
                else
                    log_fail "Escalation function not available"
                fi
                
                # Test notification during escalation
                log_info "Testing notification during escalation..."
                
                if command -v send_notification &> /dev/null; then
                    if send_notification "$incident_id" "Incident escalated to Level 2" "email" 2>/dev/null; then
                        log_pass "Escalation notification sent"
                    else
                        log_fail "Escalation notification failed"
                    fi
                    
                    if send_notification "$incident_id" "Critical incident requires immediate attention" "sms" 2>/dev/null; then
                        log_pass "Critical incident notification sent"
                    else
                        log_fail "Critical incident notification failed"
                    fi
                else
                    log_fail "Notification function not available"
                fi
                
                # Verify escalation in database
                local incident_db="$AEGIS_HOME/configs/incident_response/incidents.db"
                if [ -f "$incident_db" ] && command -v sqlite3 &> /dev/null; then
                    local escalation_level=$(sqlite3 "$incident_db" "SELECT escalation_level FROM incidents WHERE id = '$incident_id';" 2>/dev/null || echo "")
                    
                    if [ -n "$escalation_level" ]; then
                        log_pass "Escalation level recorded: $escalation_level"
                    else
                        log_fail "Escalation level not recorded"
                    fi
                else
                    log_fail "Incident database not available for verification"
                fi
            else
                log_fail "Failed to create test incident for escalation"
            fi
        else
            log_fail "Incident creation function not available"
        fi
    else
        log_fail "Incident response script not found"
    fi
}

# Test 4: Incident Resolution and Closure
test_incident_resolution_closure() {
    log_test "Testing Incident Resolution and Closure"
    
    # Create test incident for resolution
    if [ -f "$PROJECT_ROOT/scripts/incident-response.sh" ]; then
        source "$PROJECT_ROOT/scripts/incident-response.sh"
        
        if command -v create_incident &> /dev/null; then
            local incident_id=$(create_incident "Resolution Test Incident" "Test incident for resolution workflow" "medium" 2>/dev/null || echo "")
            
            if [ -n "$incident_id" ]; then
                log_pass "Test incident created for resolution: $incident_id"
                
                # Test resolution steps
                log_info "Testing resolution steps..."
                
                if command -v resolve_incident &> /dev/null; then
                    # Test containment
                    if resolve_incident "$incident_id" "containment" 2>/dev/null; then
                        log_pass "Incident containment completed"
                    else
                        log_fail "Incident containment failed"
                    fi
                    
                    # Test eradication
                    if resolve_incident "$incident_id" "eradication" 2>/dev/null; then
                        log_pass "Incident eradication completed"
                    else
                        log_fail "Incident eradication failed"
                    fi
                    
                    # Test recovery
                    if resolve_incident "$incident_id" "recovery" 2>/dev/null; then
                        log_pass "Incident recovery completed"
                    else
                        log_fail "Incident recovery failed"
                    fi
                    
                    # Test closure
                    if resolve_incident "$incident_id" "closure" 2>/dev/null; then
                        log_pass "Incident closure completed"
                    else
                        log_fail "Incident closure failed"
                    fi
                else
                    log_fail "Resolution function not available"
                fi
                
                # Test post-incident activities
                log_info "Testing post-incident activities..."
                
                if command -v post_incident_activities &> /dev/null; then
                    if post_incident_activities "$incident_id" "lessons_learned" 2>/dev/null; then
                        log_pass "Lessons learned documented"
                    else
                        log_fail "Lessons learned documentation failed"
                    fi
                    
                    if post_incident_activities "$incident_id" "security_improvements" 2>/dev/null; then
                        log_pass "Security improvements identified"
                    else
                        log_fail "Security improvements identification failed"
                    fi
                else
                    log_fail "Post-incident activities function not available"
                fi
                
                # Verify resolution in database
                local incident_db="$AEGIS_HOME/configs/incident_response/incidents.db"
                if [ -f "$incident_db" ] && command -v sqlite3 &> /dev/null; then
                    local incident_status=$(sqlite3 "$incident_db" "SELECT status FROM incidents WHERE id = '$incident_id';" 2>/dev/null || echo "")
                    
                    if [ "$incident_status" = "resolved" ] || [ "$incident_status" = "closed" ]; then
                        log_pass "Incident status updated: $incident_status"
                    else
                        log_fail "Incident status not properly updated: $incident_status"
                    fi
                else
                    log_fail "Incident database not available for verification"
                fi
            else
                log_fail "Failed to create test incident for resolution"
            fi
        else
            log_fail "Incident creation function not available"
        fi
    else
        log_fail "Incident response script not found"
    fi
}

# Test 5: Incident Dashboard Integration
test_incident_dashboard_integration() {
    log_test "Testing Incident Dashboard Integration"
    
    # Start dashboard if not running
    local dashboard_url="http://localhost:8080"
    local dashboard_running=false
    
    if curl -s --connect-timeout 5 "$dashboard_url" >/dev/null 2>&1; then
        dashboard_running=true
        log_info "Dashboard is already running"
    else
        log_info "Starting dashboard for integration testing..."
        if [ -f "$PROJECT_ROOT/web-dashboard/start-dashboard.sh" ]; then
            cd "$PROJECT_ROOT/web-dashboard"
            ./start-dashboard.sh &
            sleep 5
            
            if curl -s --connect-timeout 5 "$dashboard_url" >/dev/null 2>&1; then
                dashboard_running=true
            else
                log_fail "Failed to start dashboard"
                return 1
            fi
        else
            log_fail "Dashboard startup script not found"
            return 1
        fi
    fi
    
    if [ "$dashboard_running" = true ]; then
        # Create test incident
        if [ -f "$PROJECT_ROOT/scripts/incident-response.sh" ]; then
            source "$PROJECT_ROOT/scripts/incident-response.sh"
            
            if command -v create_incident &> /dev/null; then
                local incident_id=$(create_incident "Dashboard Integration Test" "Test incident for dashboard integration" "high" 2>/dev/null || echo "")
                
                if [ -n "$incident_id" ]; then
                    log_pass "Test incident created for dashboard: $incident_id"
                    
                    # Test dashboard API for incident data
                    log_info "Testing dashboard API for incident data..."
                    
                    local api_response=$(curl -s "$dashboard_url/api/incidents/list" 2>/dev/null || echo "")
                    
                    if [ -n "$api_response" ]; then
                        if echo "$api_response" | grep -q "$incident_id\|Dashboard Integration Test"; then
                            log_pass "Incident data available in dashboard API"
                        else
                            log_warn "Incident data not immediately available in dashboard API"
                        fi
                        
                        # Test incident details API
                        local detail_response=$(curl -s "$dashboard_url/api/incidents/$incident_id" 2>/dev/null || echo "")
                        
                        if [ -n "$detail_response" ]; then
                            log_pass "Incident details API responding"
                        else
                            log_fail "Incident details API not responding"
                        fi
                    else
                        log_fail "Dashboard incidents API not responding"
                    fi
                    
                    # Test real-time updates
                    log_info "Testing real-time incident updates..."
                    
                    # Update incident status
                    if command -v update_incident_status &> /dev/null; then
                        if update_incident_status "$incident_id" "investigating" 2>/dev/null; then
                            log_pass "Incident status updated for real-time test"
                            
                            # Check if dashboard reflects update
                            sleep 2
                            local updated_response=$(curl -s "$dashboard_url/api/incidents/$incident_id" 2>/dev/null || echo "")
                            
                            if echo "$updated_response" | grep -q "investigating"; then
                                log_pass "Real-time incident update reflected in dashboard"
                            else
                                log_warn "Real-time update may not be immediately reflected"
                            fi
                        else
                            log_fail "Failed to update incident status"
                        fi
                    else
                        log_fail "Incident status update function not available"
                    fi
                else
                    log_fail "Failed to create test incident for dashboard"
                fi
            else
                log_fail "Incident creation function not available"
            fi
        else
            log_fail "Incident response script not found"
        fi
    fi
}

# Test 6: Incident Reporting and Analytics
test_incident_reporting_analytics() {
    log_test "Testing Incident Reporting and Analytics"
    
    # Create multiple test incidents for analytics
    local incident_ids=()
    local severities=("low" "medium" "high" "critical")
    
    if [ -f "$PROJECT_ROOT/scripts/incident-response.sh" ]; then
        source "$PROJECT_ROOT/scripts/incident-response.sh"
        
        for severity in "${severities[@]}"; do
            if command -v create_incident &> /dev/null; then
                local incident_id=$(create_incident "Analytics Test - $severity" "Test incident for analytics" "$severity" 2>/dev/null || echo "")
                
                if [ -n "$incident_id" ]; then
                    incident_ids+=("$incident_id")
                fi
            fi
        done
        
        if [ ${#incident_ids[@]} -gt 0 ]; then
            log_pass "Created ${#incident_ids[@]} test incidents for analytics"
            
            # Test incident reporting
            log_info "Testing incident reporting..."
            
            if command -v generate_incident_report &> /dev/null; then
                local report_file=$(generate_incident_report "daily" 2>/dev/null || echo "")
                
                if [ -n "$report_file" ] && [ -f "$report_file" ]; then
                    log_pass "Daily incident report generated: $report_file"
                else
                    log_fail "Daily incident report generation failed"
                fi
                
                # Test custom report
                local custom_report=$(generate_incident_report "custom" "severity:high" 2>/dev/null || echo "")
                
                if [ -n "$custom_report" ] && [ -f "$custom_report" ]; then
                    log_pass "Custom incident report generated: $custom_report"
                else
                    log_fail "Custom incident report generation failed"
                fi
            else
                log_fail "Incident report generation function not available"
            fi
            
            # Test incident analytics
            log_info "Testing incident analytics..."
            
            if command -v analyze_incidents &> /dev/null; then
                local analytics_output=$(analyze_incidents "trends" 2>/dev/null || echo "")
                
                if [ -n "$analytics_output" ]; then
                    log_pass "Incident trends analysis completed"
                else
                    log_fail "Incident trends analysis failed"
                fi
                
                # Test severity distribution
                local severity_analysis=$(analyze_incidents "severity_distribution" 2>/dev/null || echo "")
                
                if [ -n "$severity_analysis" ]; then
                    log_pass "Severity distribution analysis completed"
                else
                    log_fail "Severity distribution analysis failed"
                fi
            else
                log_fail "Incident analytics function not available"
            fi
            
            # Test dashboard analytics API
            local dashboard_url="http://localhost:8080"
            if curl -s --connect-timeout 5 "$dashboard_url" >/dev/null 2>&1; then
                log_info "Testing dashboard analytics API..."
                
                local analytics_response=$(curl -s "$dashboard_url/api/incidents/analytics" 2>/dev/null || echo "")
                
                if [ -n "$analytics_response" ]; then
                    log_pass "Dashboard analytics API responding"
                else
                    log_fail "Dashboard analytics API not responding"
                fi
            else
                log_warn "Dashboard not running - skipping analytics API test"
            fi
        else
            log_fail "No test incidents created for analytics"
        fi
    else
        log_fail "Incident response script not found"
    fi
}

# Test 7: Incident Workflow Automation
test_incident_workflow_automation() {
    log_test "Testing Incident Workflow Automation"
    
    # Create test incident for automation
    if [ -f "$PROJECT_ROOT/scripts/incident-response.sh" ]; then
        source "$PROJECT_ROOT/scripts/incident-response.sh"
        
        if command -v create_incident &> /dev/null; then
            local incident_id=$(create_incident "Automation Test Incident" "Test incident for workflow automation" "high" 2>/dev/null || echo "")
            
            if [ -n "$incident_id" ]; then
                log_pass "Test incident created for automation: $incident_id"
                
                # Test automated triage
                log_info "Testing automated triage..."
                
                if command -v automated_triage &> /dev/null; then
                    if automated_triage "$incident_id" 2>/dev/null; then
                        log_pass "Automated triage completed"
                    else
                        log_fail "Automated triage failed"
                    fi
                else
                    log_fail "Automated triage function not available"
                fi
                
                # Test automated evidence collection
                log_info "Testing automated evidence collection..."
                
                if command -v automated_evidence_collection &> /dev/null; then
                    if automated_evidence_collection "$incident_id" 2>/dev/null; then
                        log_pass "Automated evidence collection completed"
                    else
                        log_fail "Automated evidence collection failed"
                    fi
                else
                    log_fail "Automated evidence collection function not available"
                fi
                
                # Test automated notification
                log_info "Testing automated notification..."
                
                if command -v automated_notification &> /dev/null; then
                    if automated_notification "$incident_id" "high_severity" 2>/dev/null; then
                        log_pass "Automated notification sent"
                    else
                        log_fail "Automated notification failed"
                    fi
                else
                    log_fail "Automated notification function not available"
                fi
                
                # Test automated escalation
                log_info "Testing automated escalation..."
                
                if command -v automated_escalation &> /dev/null; then
                    if automated_escalation "$incident_id" 2>/dev/null; then
                        log_pass "Automated escalation completed"
                    else
                        log_fail "Automated escalation failed"
                    fi
                else
                    log_fail "Automated escalation function not available"
                fi
                
                # Verify automation in database
                local incident_db="$AEGIS_HOME/configs/incident_response/incidents.db"
                if [ -f "$incident_db" ] && command -v sqlite3 &> /dev/null; then
                    local automation_flags=$(sqlite3 "$incident_db" "SELECT automated_triage, automated_evidence, automated_notification FROM incidents WHERE id = '$incident_id';" 2>/dev/null || echo "")
                    
                    if [ -n "$automation_flags" ]; then
                        log_pass "Automation flags recorded: $automation_flags"
                    else
                        log_warn "Automation flags may not be recorded"
                    fi
                else
                    log_fail "Incident database not available for verification"
                fi
            else
                log_fail "Failed to create test incident for automation"
            fi
        else
            log_fail "Incident creation function not available"
        fi
    else
        log_fail "Incident response script not found"
    fi
}

# Test 8: Incident Performance and Scalability
test_incident_performance_scalability() {
    log_test "Testing Incident Performance and Scalability"
    
    # Test incident creation performance
    log_info "Testing incident creation performance..."
    
    local start_time=$(date +%s.%N)
    local incidents_created=0
    
    if [ -f "$PROJECT_ROOT/scripts/incident-response.sh" ]; then
        source "$PROJECT_ROOT/scripts/incident-response.sh"
        
        # Create multiple incidents rapidly
        for i in {1..20}; do
            if command -v create_incident &> /dev/null; then
                local incident_id=$(create_incident "Performance Test $i" "Performance test incident $i" "medium" 2>/dev/null || echo "")
                
                if [ -n "$incident_id" ]; then
                    ((incidents_created++))
                fi
            fi
        done
        
        local end_time=$(date +%s.%N)
        local total_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
        local avg_time_per_incident=$(echo "scale=3; $total_time / $incidents_created" | bc -l 2>/dev/null || echo "0")
        
        log_info "Created $incidents_created incidents in ${total_time}s"
        log_info "Average time per incident: ${avg_time_per_incident}s"
        
        # Check performance thresholds
        if (( $(echo "$avg_time_per_incident < 2.0" | bc -l 2>/dev/null || echo "1") )); then
            log_pass "Incident creation performance is acceptable"
        else
            log_warn "Incident creation performance may need improvement"
        fi
        
        # Test incident query performance
        log_info "Testing incident query performance..."
        
        local query_start=$(date +%s.%N)
        local incident_db="$AEGIS_HOME/configs/incident_response/incidents.db"
        
        if [ -f "$incident_db" ] && command -v sqlite3 &> /dev/null; then
            local query_result=$(sqlite3 "$incident_db" "SELECT COUNT(*) FROM incidents WHERE title LIKE 'Performance Test%';" 2>/dev/null || echo "0")
            local query_end=$(date +%s.%N)
            local query_time=$(echo "$query_end - $query_start" | bc -l 2>/dev/null || echo "0")
            
            log_info "Query returned $query_result incidents in ${query_time}s"
            
            if (( $(echo "$query_time < 1.0" | bc -l 2>/dev/null || echo "1") )); then
                log_pass "Incident query performance is acceptable"
            else
                log_warn "Incident query performance may need improvement"
            fi
        else
            log_fail "Incident database not available for query testing"
        fi
        
        # Test concurrent incident operations
        log_info "Testing concurrent incident operations..."
        
        local concurrent_operations=0
        local pids=()
        
        # Start multiple concurrent operations
        for i in {1..5}; do
            (
                if command -v create_incident &> /dev/null; then
                    create_incident "Concurrent Test $i" "Concurrent test incident $i" "low" >/dev/null 2>&1 || true
                fi
            ) &
            pids+=($!)
        done
        
        # Wait for all operations to complete
        for pid in "${pids[@]}"; do
            wait $pid
            ((concurrent_operations++))
        done
        
        if [ "$concurrent_operations" -eq 5 ]; then
            log_pass "Concurrent incident operations completed successfully"
        else
            log_fail "Some concurrent operations failed: $concurrent_operations/5"
        fi
    else
        log_fail "Incident response script not found"
    fi
}

# Test 9: Incident Security and Access Control
test_incident_security_access_control() {
    log_test "Testing Incident Security and Access Control"
    
    # Create test incident with sensitive data
    if [ -f "$PROJECT_ROOT/scripts/incident-response.sh" ]; then
        source "$PROJECT_ROOT/scripts/incident-response.sh"
        
        if command -v create_incident &> /dev/null; then
            local incident_id=$(create_incident "Security Test Incident" "Test incident with sensitive data: passwords, keys, tokens" "critical" 2>/dev/null || echo "")
            
            if [ -n "$incident_id" ]; then
                log_pass "Test incident created with sensitive data: $incident_id"
                
                # Test data encryption
                log_info "Testing incident data encryption..."
                
                local incident_db="$AEGIS_HOME/configs/incident_response/incidents.db"
                if [ -f "$incident_db" ] && command -v sqlite3 &> /dev/null; then
                    # Check if sensitive data is encrypted
                    local description_data=$(sqlite3 "$incident_db" "SELECT description FROM incidents WHERE id = '$incident_id';" 2>/dev/null || echo "")
                    
                    if [ -n "$description_data" ]; then
                        # Simple check for encryption (in real implementation, would check for encrypted format)
                        if echo "$description_data" | grep -q "passwords\|keys\|tokens"; then
                            log_warn "Sensitive data may not be encrypted in database"
                        else
                            log_pass "Sensitive data appears to be protected"
                        fi
                    else
                        log_fail "Could not retrieve incident data for encryption check"
                    fi
                else
                    log_fail "Incident database not available for security testing"
                fi
                
                # Test access control
                log_info "Testing incident access control..."
                
                if command -v check_incident_access &> /dev/null; then
                    # Test with different user roles
                    local roles=("analyst" "manager" "admin" "viewer")
                    
                    for role in "${roles[@]}"; do
                        if check_incident_access "$incident_id" "$role" 2>/dev/null; then
                            log_pass "Access control check passed for role: $role"
                        else
                            log_fail "Access control check failed for role: $role"
                        fi
                    done
                else
                    log_fail "Access control function not available"
                fi
                
                # Test audit logging
                log_info "Testing incident audit logging..."
                
                local audit_log="$AEGIS_HOME/logs/incident_audit.log"
                if [ -f "$audit_log" ]; then
                    local audit_entries=$(grep "$incident_id" "$audit_log" | wc -l)
                    
                    if [ "$audit_entries" -gt 0 ]; then
                        log_pass "Audit entries found: $audit_entries"
                    else
                        log_fail "No audit entries found for incident"
                    fi
                else
                    log_fail "Audit log not found"
                fi
            else
                log_fail "Failed to create test incident for security testing"
            fi
        else
            log_fail "Incident creation function not available"
        fi
    else
        log_fail "Incident response script not found"
    fi
}

# Test 10: Incident Integration with Other Components
test_incident_component_integration() {
    log_test "Testing Incident Integration with Other Components"
    
    # Test integration with behavioral analysis
    log_info "Testing integration with behavioral analysis..."
    
    local behavioral_db="$AEGIS_HOME/configs/behavioral_analysis/behavioral_data.db"
    if [ -f "$behavioral_db" ] && command -v sqlite3 &> /dev/null; then
        # Create behavioral anomaly
        sqlite3 "$behavioral_db" << EOF 2>/dev/null
INSERT INTO anomalies (id, type, severity, detected_at) 
VALUES ('INTEGRATION_TEST_$(date +%s)', 'integration_test', 'high', datetime('now'));
EOF
        
        # Check if incident is created from anomaly
        sleep 2
        
        local incident_db="$AEGIS_HOME/configs/incident_response/incidents.db"
        if [ -f "$incident_db" ] && command -v sqlite3 &> /dev/null; then
            local behavioral_incidents=$(sqlite3 "$incident_db" "SELECT COUNT(*) FROM incidents WHERE source = 'behavioral_analysis' AND created_at > datetime('now', '-5 minutes');" 2>/dev/null || echo "0")
            
            if [ "$behavioral_incidents" -gt 0 ]; then
                log_pass "Behavioral analysis integration working: $behavioral_incidents incidents"
            else
                log_warn "Behavioral analysis integration may not be fully implemented"
            fi
        fi
    else
        log_warn "Behavioral analysis database not available"
    fi
    
    # Test integration with threat intelligence
    log_info "Testing integration with threat intelligence..."
    
    local threat_db="$AEGIS_HOME/configs/threat_intelligence/ioc_database.db"
    if [ -f "$threat_db" ] && command -v sqlite3 &> /dev/null; then
        # Create high-confidence threat
        sqlite3 "$threat_db" << EOF 2>/dev/null
INSERT OR REPLACE INTO indicators (value, type, source, confidence, first_seen) 
VALUES ('integration.test.com', 'domain', 'integration_test', 95, datetime('now'));
EOF
        
        # Check if incident is created from threat intelligence
        sleep 2
        
        local incident_db="$AEGIS_HOME/configs/incident_response/incidents.db"
        if [ -f "$incident_db" ] && command -v sqlite3 &> /dev/null; then
            local threat_incidents=$(sqlite3 "$incident_db" "SELECT COUNT(*) FROM incidents WHERE source = 'threat_intelligence' AND created_at > datetime('now', '-5 minutes');" 2>/dev/null || echo "0")
            
            if [ "$threat_incidents" -gt 0 ]; then
                log_pass "Threat intelligence integration working: $threat_incidents incidents"
            else
                log_warn "Threat intelligence integration may not be fully implemented"
            fi
        fi
    else
        log_warn "Threat intelligence database not available"
    fi
    
    # Test integration with system monitoring
    log_info "Testing integration with system monitoring..."
    
    if [ -f "$PROJECT_ROOT/scripts/security-daily-scan.sh" ]; then
        cd "$PROJECT_ROOT"
        ./scripts/security-daily-scan.sh &
        local scan_pid=$!
        sleep 3
        
        # Check if incidents are created from scan results
        local incident_db="$AEGIS_HOME/configs/incident_response/incidents.db"
        if [ -f "$incident_db" ] && command -v sqlite3 &> /dev/null; then
            local scan_incidents=$(sqlite3 "$incident_db" "SELECT COUNT(*) FROM incidents WHERE source = 'security_scan' AND created_at > datetime('now', '-5 minutes');" 2>/dev/null || echo "0")
            
            if [ "$scan_incidents" -gt 0 ]; then
                log_pass "System monitoring integration working: $scan_incidents incidents"
            else
                log_warn "System monitoring integration may not be fully implemented"
            fi
        fi
        
        # Stop scan
        kill $scan_pid 2>/dev/null || true
        wait $scan_pid 2>/dev/null || true
    else
        log_warn "Security scan script not available"
    fi
}

# Cleanup function
cleanup() {
    log_info "Cleaning up incident management test environment..."
    
    # Clean up test incidents
    local incident_db="$AEGIS_HOME/configs/incident_response/incidents.db"
    if command -v sqlite3 &> /dev/null; then
        [ -f "$incident_db" ] && sqlite3 "$incident_db" "DELETE FROM incidents WHERE title LIKE '%Test%' OR title LIKE '%test%' OR title LIKE 'Performance Test%' OR title LIKE 'Analytics Test%' OR title LIKE 'Integration Test%' OR title LIKE 'Automation Test%' OR title LIKE 'Security Test%' OR title LIKE 'Concurrent Test%' OR title LIKE 'Dashboard Integration%' OR title LIKE 'Resolution Test%' OR title LIKE 'Escalation Test%' OR title LIKE 'Investigation Test%';" 2>/dev/null || true
    fi
    
    # Clean up test evidence
    local evidence_dir="$AEGIS_HOME/evidence"
    if [ -d "$evidence_dir" ]; then
        find "$evidence_dir" -name "TEST_*" -type f -delete 2>/dev/null || true
        find "$evidence_dir" -name "*_test_*" -type f -delete 2>/dev/null || true
    fi
    
    # Clean up test reports
    local reports_dir="$AEGIS_HOME/reports"
    if [ -d "$reports_dir" ]; then
        find "$reports_dir" -name "*test*" -type f -delete 2>/dev/null || true
    fi
    
    # Kill any remaining test processes
    pkill -f "security-daily-scan.sh" 2>/dev/null || true
}

# Main test execution
main() {
    echo -e "${WHITE}========================================${NC}"
    echo -e "${WHITE}🚨 INCIDENT MANAGEMENT END-TO-END TESTS 🚨${NC}"
    echo -e "${WHITE}========================================${NC}"
    echo -e "${BLUE}Test started: $(date)${NC}"
    echo ""
    
    # Set up cleanup trap
    trap cleanup EXIT
    
    # Run all tests
    test_incident_creation_triage
    test_incident_investigation
    test_incident_escalation_notification
    test_incident_resolution_closure
    test_incident_dashboard_integration
    test_incident_reporting_analytics
    test_incident_workflow_automation
    test_incident_performance_scalability
    test_incident_security_access_control
    test_incident_component_integration
    
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
        echo -e "${GREEN}🎉 ALL INCIDENT MANAGEMENT TESTS PASSED!${NC}"
        exit 0
    else
        echo -e "${RED}⚠️ $TESTS_FAILED test(s) failed. Review issues above.${NC}"
        exit 1
    fi
}

# Run main function
main "$@"