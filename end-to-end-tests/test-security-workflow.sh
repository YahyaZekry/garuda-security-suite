#!/bin/bash
# End-to-End Security Workflow Tests
# Tests complete security scan workflow from start to finish

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

# Test 1: Complete Security Scan Workflow
test_complete_security_scan() {
    log_test "Testing Complete Security Scan Workflow"
    
    # Create test environment
    local test_dir="/tmp/security_scan_test_$$"
    mkdir -p "$test_dir"
    
    # Create test files (including EICAR for testing)
    echo 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > "$test_dir/eicar.com"
    echo "Clean file content" > "$test_dir/clean.txt"
    echo "Suspicious content" > "$test_dir/suspicious.txt"
    
    # Run security scan
    if [ -f "$PROJECT_ROOT/scripts/security-daily-scan.sh" ]; then
        cd "$PROJECT_ROOT"
        
        # Mock scan directories to use test directory
        local original_dirs=("${DAILY_SCAN_DIRS[@]}")
        DAILY_SCAN_DIRS=("$test_dir")
        
        log_info "Starting security scan workflow..."
        
        # Run the scan
        if ./scripts/security-daily-scan.sh 2>/dev/null; then
            log_pass "Security scan completed successfully"
            
            # Check for scan results
            local scan_log=$(find "$AEGIS_HOME/logs" -name "*daily_scan*" -type f 2>/dev/null | head -n1)
            if [ -f "$scan_log" ]; then
                log_pass "Scan log file created: $(basename "$scan_log")"
                
                # Check log content
                if grep -q "EICAR" "$scan_log" 2>/dev/null; then
                    log_pass "EICAR test file detected in scan"
                else
                    log_fail "EICAR test file not detected in scan"
                fi
                
                if grep -q "behavioral" "$scan_log" 2>/dev/null; then
                    log_pass "Behavioral analysis included in scan"
                else
                    log_fail "Behavioral analysis not included in scan"
                fi
                
                if grep -q "threat" "$scan_log" 2>/dev/null; then
                    log_pass "Threat intelligence included in scan"
                else
                    log_fail "Threat intelligence not included in scan"
                fi
            else
                log_fail "Scan log file not created"
            fi
        else
            log_fail "Security scan failed"
        fi
        
        # Restore original directories
        DAILY_SCAN_DIRS=("${original_dirs[@]}")
    else
        log_fail "Security scan script not found"
    fi
    
    # Cleanup test environment
    rm -rf "$test_dir"
}

# Test 2: Behavioral Analysis Integration Workflow
test_behavioral_integration_workflow() {
    log_test "Testing Behavioral Analysis Integration Workflow"
    
    if [ "${BEHAVIORAL_ANALYSIS_ENABLED:-false}" = "true" ]; then
        # Create test behavioral data
        local test_db="/tmp/test_behavioral_workflow_$$.db"
        mkdir -p "$(dirname "$test_db")"
        
        if [ -f "$PROJECT_ROOT/scripts/behavioral-analysis.sh" ]; then
            source "$PROJECT_ROOT/scripts/behavioral-analysis.sh"
            
            # Override database path for testing
            export BEHAVIORAL_DB_PATH="$test_db"
            
            # Initialize behavioral analysis
            if init_behavioral_analysis 2>/dev/null; then
                log_pass "Behavioral analysis initialized"
                
                # Insert test data
                if command -v sqlite3 &> /dev/null; then
                    sqlite3 "$test_db" << EOF 2>/dev/null
INSERT INTO system_metrics (timestamp, cpu_usage, memory_usage, disk_usage, network_io) 
VALUES (datetime('now'), 85.5, 90.2, 75.8, 5120);

INSERT INTO process_behavior (timestamp, process_name, cpu_usage, memory_usage, pid, parent_pid) 
VALUES (datetime('now'), 'suspicious_process', 95.2, 85.1, 9999, 1);

INSERT INTO network_behavior (timestamp, source_ip, dest_ip, port, protocol) 
VALUES (datetime('now'), '192.168.1.100', '10.0.0.1', 4444, 'TCP');
EOF
                    
                    if [ $? -eq 0 ]; then
                        log_pass "Test behavioral data inserted"
                        
                        # Run anomaly detection
                        if detect_anomalies 2>/dev/null; then
                            log_pass "Anomaly detection completed"
                            
                            # Check if anomalies were detected
                            local anomaly_count=$(sqlite3 "$test_db" "SELECT COUNT(*) FROM anomalies;" 2>/dev/null || echo "0")
                            if [ "$anomaly_count" -gt 0 ]; then
                                log_pass "Anomalies detected: $anomaly_count"
                                
                                # Test incident creation from anomalies
                                local anomaly_ids=$(sqlite3 "$test_db" "SELECT id FROM anomalies LIMIT 1;" 2>/dev/null || echo "")
                                if [ -n "$anomaly_ids" ]; then
                                    if [ -f "$PROJECT_ROOT/scripts/incident-response.sh" ]; then
                                        source "$PROJECT_ROOT/scripts/incident-response.sh"
                                        
                                        local incident_id=$(create_incident "Behavioral Anomaly Detected" "High CPU and memory usage detected" "high" 2>/dev/null || echo "")
                                        if [ -n "$incident_id" ]; then
                                            log_pass "Incident created from behavioral anomaly: $incident_id"
                                        else
                                            log_fail "Failed to create incident from behavioral anomaly"
                                        fi
                                    else
                                        log_fail "Incident response script not available"
                                    fi
                                else
                                    log_fail "No anomaly IDs found for incident creation"
                                fi
                            else
                                log_warn "No anomalies detected (may be expected with test data)"
                            fi
                        else
                            log_fail "Anomaly detection failed"
                        fi
                    else
                        log_fail "Failed to insert test behavioral data"
                    fi
                else
                    log_warn "SQLite3 not available - cannot test behavioral workflow"
                fi
            else
                log_fail "Behavioral analysis initialization failed"
            fi
            
            # Cleanup
            rm -f "$test_db"
        else
            log_fail "Behavioral analysis script not found"
        fi
    else
        log_warn "Behavioral analysis disabled - skipping workflow test"
    fi
}

# Test 3: Threat Intelligence Integration Workflow
test_threat_intelligence_workflow() {
    log_test "Testing Threat Intelligence Integration Workflow"
    
    if [ -f "$PROJECT_ROOT/scripts/threat-intelligence-v2.sh" ]; then
        source "$PROJECT_ROOT/scripts/threat-intelligence-v2.sh"
        
        # Create test threat feed
        local test_feed="/tmp/test_threat_feed_$$.txt"
        cat > "$test_feed" << EOF
# Test threat indicators
192.168.1.100
malicious.example.com
http://evil.site.com/payload
EOF
        
        # Process threat feed
        if process_threat_feed "$test_feed" "test_feed" 2>/dev/null; then
            log_pass "Threat feed processed successfully"
            
            # Check if IOCs were added to database
            local db_file="$AEGIS_HOME/configs/threat_intelligence/ioc_database.db"
            if [ -f "$db_file" ] && command -v sqlite3 &> /dev/null; then
                local ioc_count=$(sqlite3 "$db_file" "SELECT COUNT(*) FROM indicators WHERE source = 'test_feed';" 2>/dev/null || echo "0")
                if [ "$ioc_count" -gt 0 ]; then
                    log_pass "IOCs added to database: $ioc_count"
                    
                    # Test IOC lookup
                    local test_ip="192.168.1.100"
                    local is_malicious=$(check_ioc "$test_ip" 2>/dev/null || echo "false")
                    if [ "$is_malicious" = "true" ]; then
                        log_pass "IOC lookup works correctly for $test_ip"
                    else
                        log_fail "IOC lookup failed for $test_ip"
                    fi
                    
                    # Test integration with behavioral analysis
                    if [ -f "$PROJECT_ROOT/scripts/behavioral-analysis.sh" ]; then
                        if grep -q "threat_intelligence\|ioc_database" "$PROJECT_ROOT/scripts/behavioral-analysis.sh" 2>/dev/null; then
                            log_pass "Behavioral analysis integrates with threat intelligence"
                        else
                            log_fail "Behavioral analysis does not integrate with threat intelligence"
                        fi
                    else
                        log_fail "Behavioral analysis script not found"
                    fi
                else
                    log_fail "No IOCs added to database"
                fi
            else
                log_warn "Threat intelligence database not available"
            fi
        else
            log_fail "Threat feed processing failed"
        fi
        
        # Cleanup
        rm -f "$test_feed"
    else
        log_fail "Threat intelligence script not found"
    fi
}

# Test 4: Incident Response Workflow
test_incident_response_workflow() {
    log_test "Testing Incident Response Workflow"
    
    if [ -f "$PROJECT_ROOT/scripts/incident-response.sh" ]; then
        source "$PROJECT_ROOT/scripts/incident-response.sh"
        
        # Create test incident
        local test_title="Test Security Incident"
        local test_description="This is a test incident for workflow validation"
        local test_severity="high"
        
        local incident_id=$(create_incident "$test_title" "$test_description" "$test_severity" 2>/dev/null || echo "")
        
        if [ -n "$incident_id" ]; then
            log_pass "Incident created: $incident_id"
            
            # Add timeline events
            if add_timeline_event "$incident_id" "incident_detected" "Incident detected by system" 2>/dev/null; then
                log_pass "Timeline event added: incident_detected"
            else
                log_fail "Failed to add timeline event"
            fi
            
            if add_timeline_event "$incident_id" "investigation_started" "Investigation started" 2>/dev/null; then
                log_pass "Timeline event added: investigation_started"
            else
                log_fail "Failed to add timeline event"
            fi
            
            # Collect evidence
            if collect_evidence "$incident_id" "system_state" 2>/dev/null; then
                log_pass "System state evidence collected"
                
                # Check evidence file
                local evidence_file=$(find "$AEGIS_HOME/evidence" -name "${incident_id}_system_state_*" 2>/dev/null | head -n1)
                if [ -f "$evidence_file" ]; then
                    log_pass "Evidence file created: $(basename "$evidence_file")"
                else
                    log_fail "Evidence file not found"
                fi
            else
                log_fail "Failed to collect system state evidence"
            fi
            
            if collect_evidence "$incident_id" "processes" 2>/dev/null; then
                log_pass "Process evidence collected"
            else
                log_fail "Failed to collect process evidence"
            fi
            
            if collect_evidence "$incident_id" "network_connections" 2>/dev/null; then
                log_pass "Network connections evidence collected"
            else
                log_fail "Failed to collect network connections evidence"
            fi
            
            # Update incident status
            if update_incident "$incident_id" "status" "investigating" 2>/dev/null; then
                log_pass "Incident status updated: investigating"
            else
                log_fail "Failed to update incident status"
            fi
            
            # Test automated response
            if execute_automated_response "isolate" "test_target" "dry_run" 2>/dev/null; then
                log_pass "Automated response executed: isolate (dry run)"
            else
                log_fail "Failed to execute automated response"
            fi
            
            # Send notification
            if send_notification "Test Incident" "Incident $incident_id requires attention" "dashboard" 2>/dev/null; then
                log_pass "Notification sent for incident"
            else
                log_warn "Notification may have failed (expected in test environment)"
            fi
            
            # Resolve incident
            if update_incident "$incident_id" "status" "resolved" 2>/dev/null; then
                log_pass "Incident status updated: resolved"
            else
                log_fail "Failed to resolve incident"
            fi
            
            # Add resolution timeline event
            if add_timeline_event "$incident_id" "incident_resolved" "Incident resolved" 2>/dev/null; then
                log_pass "Timeline event added: incident_resolved"
            else
                log_fail "Failed to add resolution timeline event"
            fi
        else
            log_fail "Failed to create incident"
        fi
    else
        log_fail "Incident response script not found"
    fi
}

# Test 5: Dashboard Integration Workflow
test_dashboard_integration_workflow() {
    log_test "Testing Dashboard Integration Workflow"
    
    # Start dashboard if not running
    local dashboard_url="http://localhost:8080"
    local dashboard_running=false
    
    if curl -s --connect-timeout 5 "$dashboard_url" >/dev/null 2>&1; then
        dashboard_running=true
        log_pass "Dashboard is already running"
    else
        log_info "Starting dashboard for workflow test..."
        if [ -f "$PROJECT_ROOT/web-dashboard/start-dashboard.sh" ]; then
            cd "$PROJECT_ROOT/web-dashboard"
            ./start-dashboard.sh &
            local dashboard_pid=$!
            
            # Wait for dashboard to start
            sleep 5
            
            if curl -s --connect-timeout 5 "$dashboard_url" >/dev/null 2>&1; then
                dashboard_running=true
                log_pass "Dashboard started successfully"
                echo "$dashboard_pid" > /tmp/dashboard_workflow_test.pid
            else
                log_fail "Failed to start dashboard"
            fi
        else
            log_fail "Dashboard startup script not found"
        fi
    fi
    
    if [ "$dashboard_running" = true ]; then
        # Test dashboard API endpoints
        local endpoints=(
            "/api/system/status"
            "/api/behavioral/metrics"
            "/api/threats/iocs"
            "/api/incidents"
        )
        
        for endpoint in "${endpoints[@]}"; do
            local response=$(curl -s "$dashboard_url$endpoint" 2>/dev/null || echo "")
            if [ -n "$response" ]; then
                log_pass "Dashboard API responds: $endpoint"
                
                # Validate JSON response
                if echo "$response" | python3 -m json.tool >/dev/null 2>&1; then
                    log_pass "API returns valid JSON: $endpoint"
                else
                    log_fail "API returns invalid JSON: $endpoint"
                fi
            else
                log_fail "Dashboard API not responding: $endpoint"
            fi
        done
        
        # Test real-time updates
        local events_response=$(curl -s "$dashboard_url/api/events" 2>/dev/null || echo "")
        if [ -n "$events_response" ]; then
            log_pass "Real-time events endpoint responds"
        else
            log_fail "Real-time events endpoint not responding"
        fi
    else
        log_fail "Dashboard not available for workflow testing"
    fi
}

# Test 6: Notification Workflow
test_notification_workflow() {
    log_test "Testing Notification Workflow"
    
    # Create test incident for notification
    if [ -f "$PROJECT_ROOT/scripts/incident-response.sh" ]; then
        source "$PROJECT_ROOT/scripts/incident-response.sh"
        
        local test_incident_id="NOTIFICATION_TEST_$(date +%s)"
        local test_title="Notification Test Incident"
        local test_description="This is a test incident for notification workflow"
        
        # Create incident
        local incident_id=$(create_incident "$test_title" "$test_description" "medium" 2>/dev/null || echo "")
        
        if [ -n "$incident_id" ]; then
            log_pass "Test incident created for notification: $incident_id"
            
            # Test different notification types
            local notification_types=("email" "system" "dashboard")
            
            for type in "${notification_types[@]}"; do
                if send_notification "$test_title" "Incident $incident_id: $test_description" "$type" 2>/dev/null; then
                    log_pass "Notification sent successfully: $type"
                else
                    log_warn "Notification may have failed: $type (expected in test environment)"
                fi
            done
            
            # Test notification queue
            local db_file="$AEGIS_HOME/configs/incident_response/incidents.db"
            if [ -f "$db_file" ] && command -v sqlite3 &> /dev/null; then
                local notification_count=$(sqlite3 "$db_file" "SELECT COUNT(*) FROM notifications WHERE incident_id = '$incident_id';" 2>/dev/null || echo "0")
                if [ "$notification_count" -gt 0 ]; then
                    log_pass "Notifications queued: $notification_count"
                else
                    log_warn "No notifications found in queue"
                fi
            else
                log_warn "Cannot check notification queue - database not available"
            fi
        else
            log_fail "Failed to create test incident for notification"
        fi
    else
        log_fail "Incident response script not found"
    fi
}

# Test 7: Evidence Collection Workflow
test_evidence_collection_workflow() {
    log_test "Testing Evidence Collection Workflow"
    
    if [ -f "$PROJECT_ROOT/scripts/incident-response.sh" ]; then
        source "$PROJECT_ROOT/scripts/incident-response.sh"
        
        local test_incident_id="EVIDENCE_TEST_$(date +%s)"
        
        # Test all evidence types
        local evidence_types=(
            "system_state"
            "processes"
            "network_connections"
            "running_services"
            "system_logs"
            "file_system"
        )
        
        local collected_evidence=0
        for evidence_type in "${evidence_types[@]}"; do
            if collect_evidence "$test_incident_id" "$evidence_type" 2>/dev/null; then
                log_pass "Evidence collected: $evidence_type"
                ((collected_evidence++))
                
                # Check evidence file
                local evidence_file=$(find "$AEGIS_HOME/evidence" -name "${test_incident_id}_${evidence_type}_*" 2>/dev/null | head -n1)
                if [ -f "$evidence_file" ]; then
                    log_pass "Evidence file exists: $(basename "$evidence_file")"
                    
                    # Check evidence file content
                    if [ -s "$evidence_file" ]; then
                        log_pass "Evidence file has content: $(basename "$evidence_file")"
                    else
                        log_fail "Evidence file is empty: $(basename "$evidence_file")"
                    fi
                else
                    log_fail "Evidence file not found: $evidence_type"
                fi
            else
                log_fail "Failed to collect evidence: $evidence_type"
            fi
        done
        
        if [ "$collected_evidence" -gt 0 ]; then
            log_pass "Evidence collection workflow completed: $collected_evidence/${#evidence_types[@]} types"
        else
            log_fail "Evidence collection workflow failed"
        fi
        
        # Test evidence packaging
        if command -v package_evidence &> /dev/null; then
            if package_evidence "$test_incident_id" 2>/dev/null; then
                log_pass "Evidence packaging completed"
                
                # Check for evidence package
                local package_file=$(find "$AEGIS_HOME/evidence" -name "${test_incident_id}_package_*" 2>/dev/null | head -n1)
                if [ -f "$package_file" ]; then
                    log_pass "Evidence package created: $(basename "$package_file")"
                else
                    log_fail "Evidence package not found"
                fi
            else
                log_fail "Evidence packaging failed"
            fi
        else
            log_warn "Evidence packaging function not available"
        fi
        
        # Cleanup test evidence
        find "$AEGIS_HOME/evidence" -name "${test_incident_id}*" -delete 2>/dev/null || true
    else
        log_fail "Incident response script not found"
    fi
}

# Test 8: Configuration Management Workflow
test_configuration_workflow() {
    log_test "Testing Configuration Management Workflow"
    
    # Test configuration loading
    if [ -f "$PROJECT_ROOT/configs/security-config.conf" ]; then
        source "$PROJECT_ROOT/configs/security-config.conf"
        log_pass "Configuration loaded successfully"
        
        # Test configuration validation
        if command -v validate_security_config &> /dev/null; then
            if validate_security_config "$PROJECT_ROOT/configs/security-config.conf" 2>/dev/null; then
                log_pass "Configuration validation passed"
            else
                log_fail "Configuration validation failed"
            fi
        else
            log_warn "Configuration validation function not available"
        fi
        
        # Test configuration update
        local test_config="/tmp/test_security_config_$$.conf"
        cp "$PROJECT_ROOT/configs/security-config.conf" "$test_config"
        
        # Modify configuration
        sed -i 's/BEHAVIORAL_ANALYSIS_ENABLED=.*/BEHAVIORAL_ANALYSIS_ENABLED=true/' "$test_config"
        
        if [ -f "$test_config" ]; then
            log_pass "Configuration file updated"
            
            # Test updated configuration
            source "$test_config"
            if [ "$BEHAVIORAL_ANALYSIS_ENABLED" = "true" ]; then
                log_pass "Configuration update applied successfully"
            else
                log_fail "Configuration update not applied"
            fi
        else
            log_fail "Failed to update configuration file"
        fi
        
        # Cleanup
        rm -f "$test_config"
    else
        log_fail "Configuration file not found"
    fi
}

# Test 9: Service Management Workflow
test_service_management_workflow() {
    log_test "Testing Service Management Workflow"
    
    # Test service status
    if command -v systemctl &> /dev/null; then
        local services=("behavioral-monitor.timer" "security-daily-scan.timer")
        local active_services=0
        
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
        
        # Test service restart
        for service in "${services[@]}"; do
            if systemctl --user is-active --quiet "$service" 2>/dev/null; then
                if systemctl --user restart "$service" 2>/dev/null; then
                    log_pass "Service restarted successfully: $service"
                    
                    # Check if service is still active after restart
                    sleep 2
                    if systemctl --user is-active --quiet "$service" 2>/dev/null; then
                        log_pass "Service is active after restart: $service"
                    else
                        log_fail "Service failed to start after restart: $service"
                    fi
                else
                    log_fail "Failed to restart service: $service"
                fi
            fi
        done
    else
        log_warn "Systemctl not available - cannot test service management"
    fi
}

# Test 10: Cleanup and Recovery Workflow
test_cleanup_workflow() {
    log_test "Testing Cleanup and Recovery Workflow"
    
    # Test log cleanup
    local log_dirs=(
        "$AEGIS_HOME/logs/error"
        "$AEGIS_HOME/logs/manual"
        "$AEGIS_HOME/logs/behavioral"
    )
    
    for dir in "${log_dirs[@]}"; do
        if [ -d "$dir" ]; then
            local log_count=$(find "$dir" -name "*.log" -type f 2>/dev/null | wc -l)
            if [ "$log_count" -gt 0 ]; then
                log_pass "Log files found in $(basename "$dir"): $log_count"
                
                # Test log rotation
                local old_logs=$(find "$dir" -name "*.log" -mtime +30 -type f 2>/dev/null)
                if [ -n "$old_logs" ]; then
                    log_pass "Old logs found for cleanup: $(echo "$old_logs" | wc -l)"
                else
                    log_warn "No old logs found for cleanup"
                fi
            else
                log_warn "No log files found in $(basename "$dir")"
            fi
        else
            log_warn "Log directory not found: $(basename "$dir")"
        fi
    done
    
    # Test database cleanup
    local databases=(
        "$AEGIS_HOME/configs/behavioral_analysis/behavioral_data.db"
        "$AEGIS_HOME/configs/threat_intelligence/ioc_database.db"
        "$AEGIS_HOME/configs/incident_response/incidents.db"
    )
    
    for db in "${databases[@]}"; do
        if [ -f "$db" ] && command -v sqlite3 &> /dev/null; then
            # Check database size
            local db_size=$(stat -c%s "$db" 2>/dev/null || echo "0")
            if [ "$db_size" -gt 0 ]; then
                log_pass "Database file exists: $(basename "$db") (${db_size} bytes)"
                
                # Test database optimization
                if sqlite3 "$db" "VACUUM;" 2>/dev/null; then
                    log_pass "Database optimization completed: $(basename "$db")"
                else
                    log_fail "Database optimization failed: $(basename "$db")"
                fi
            else
                log_warn "Database file is empty: $(basename "$db")"
            fi
        else
            log_warn "Database not available: $(basename "$db")"
        fi
    done
    
    # Test temporary file cleanup
    local temp_dirs=(
        "/tmp"
        "$AEGIS_HOME/tmp"
    )
    
    for dir in "${temp_dirs[@]}"; do
        if [ -d "$dir" ]; then
            local temp_files=$(find "$dir" -name "*aegis*" -o -name "*security*" -o -name "*behavioral*" 2>/dev/null)
            if [ -n "$temp_files" ]; then
                log_pass "Temporary files found for cleanup: $(echo "$temp_files" | wc -l)"
            else
                log_info "No temporary files to cleanup in $dir"
            fi
        fi
    done
}

# Cleanup function
cleanup() {
    log_info "Cleaning up workflow test environment..."
    
    # Stop dashboard if we started it
    if [ -f /tmp/dashboard_workflow_test.pid ]; then
        local dashboard_pid=$(cat /tmp/dashboard_workflow_test.pid)
        kill $dashboard_pid 2>/dev/null || true
        rm -f /tmp/dashboard_workflow_test.pid
    fi
    
    # Clean up any test files
    find /tmp -name "*security_test_*" -delete 2>/dev/null || true
    find /tmp -name "*test_*" -delete 2>/dev/null || true
}

# Main test execution
main() {
    echo -e "${WHITE}========================================${NC}"
    echo -e "${WHITE}🔄 END-TO-END SECURITY WORKFLOW TESTS 🔄${NC}"
    echo -e "${WHITE}========================================${NC}"
    echo -e "${BLUE}Test started: $(date)${NC}"
    echo ""
    
    # Set up cleanup trap
    trap cleanup EXIT
    
    # Run all tests
    test_complete_security_scan
    test_behavioral_integration_workflow
    test_threat_intelligence_workflow
    test_incident_response_workflow
    test_dashboard_integration_workflow
    test_notification_workflow
    test_evidence_collection_workflow
    test_configuration_workflow
    test_service_management_workflow
    test_cleanup_workflow
    
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
        echo -e "${GREEN}🎉 ALL END-TO-END WORKFLOW TESTS PASSED!${NC}"
        exit 0
    else
        echo -e "${RED}⚠️ $TESTS_FAILED test(s) failed. Review issues above.${NC}"
        exit 1
    fi
}

# Run main function
main "$@"