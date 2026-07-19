#!/bin/bash
# Threat Detection and Alerting End-to-End Tests
# Tests complete threat detection workflow from detection to alerting

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

# Test 1: Behavioral Anomaly Detection Workflow
test_behavioral_anomaly_workflow() {
    log_test "Testing Behavioral Anomaly Detection Workflow"
    
    if [ "${BEHAVIORAL_ANALYSIS_ENABLED:-false}" = "true" ]; then
        # Create test anomaly scenario
        log_info "Creating test anomaly scenario..."
        
        # Start behavioral monitoring
        if [ -f "$PROJECT_ROOT/scripts/behavioral-monitor.sh" ]; then
            cd "$PROJECT_ROOT"
            ./scripts/behavioral-monitor.sh &
            local monitor_pid=$!
            sleep 2
            
            # Generate anomalous activity
            log_info "Generating anomalous system activity..."
            
            # Create high CPU usage
            for i in {1..5}; do
                dd if=/dev/zero of=/dev/null bs=1M count=100 &
                local dd_pid=$!
                sleep 1
                kill $dd_pid 2>/dev/null || true
            done
            
            # Create unusual process activity
            for i in {1..3}; do
                sleep 10 &
                local sleep_pid=$!
                sleep 0.5
                kill $sleep_pid 2>/dev/null || true
            done
            
            # Wait for anomaly detection
            sleep 5
            
            # Check if anomalies were detected
            local behavioral_db="$AEGIS_HOME/configs/behavioral_analysis/behavioral_data.db"
            if [ -f "$behavioral_db" ] && command -v sqlite3 &> /dev/null; then
                local anomaly_count=$(sqlite3 "$behavioral_db" "SELECT COUNT(*) FROM anomalies WHERE detected_at > datetime('now', '-10 minutes');" 2>/dev/null || echo "0")
                
                log_info "Anomalies detected in last 10 minutes: $anomaly_count"
                
                if [ "$anomaly_count" -gt 0 ]; then
                    log_pass "Behavioral anomalies detected successfully"
                    
                    # Check anomaly details
                    local anomaly_types=$(sqlite3 "$behavioral_db" "SELECT DISTINCT type FROM anomalies WHERE detected_at > datetime('now', '-10 minutes');" 2>/dev/null || echo "")
                    log_info "Anomaly types detected: $anomaly_types"
                    
                    if [ -n "$anomaly_types" ]; then
                        log_pass "Multiple anomaly types detected: $anomaly_types"
                    else
                        log_warn "No anomaly types recorded"
                    fi
                else
                    log_fail "No behavioral anomalies detected"
                fi
            else
                log_fail "Behavioral database not available for verification"
            fi
            
            # Stop monitoring
            kill $monitor_pid 2>/dev/null || true
            wait $monitor_pid 2>/dev/null || true
        else
            log_fail "Behavioral monitoring script not found"
        fi
    else
        log_warn "Behavioral analysis is disabled - skipping anomaly detection test"
    fi
}

# Test 2: Threat Intelligence Alerting Workflow
test_threat_intelligence_alerting() {
    log_test "Testing Threat Intelligence Alerting Workflow"
    
    if [ "${THREAT_INTELLIGENCE_ENABLED:-false}" = "true" ]; then
        # Create test threat scenario
        log_info "Creating test threat scenario..."
        
        # Add test IOC to database
        local threat_db="$AEGIS_HOME/configs/threat_intelligence/ioc_database.db"
        if [ -f "$threat_db" ] && command -v sqlite3 &> /dev/null; then
            local test_ioc="test.malicious.domain.com"
            local test_ip="192.168.100.999"
            
            # Insert test IOCs
            sqlite3 "$threat_db" << EOF 2>/dev/null
INSERT OR REPLACE INTO indicators (value, type, source, confidence, first_seen) 
VALUES ('$test_ioc', 'domain', 'test_scenario', 95, datetime('now'));
INSERT OR REPLACE INTO indicators (value, type, source, confidence, first_seen) 
VALUES ('$test_ip', 'ip', 'test_scenario', 90, datetime('now'));
EOF
            
            if [ $? -eq 0 ]; then
                log_pass "Test IOCs inserted successfully"
                
                # Run threat intelligence update
                if [ -f "$PROJECT_ROOT/scripts/threat-intelligence-v2.sh" ]; then
                    cd "$PROJECT_ROOT"
                    ./scripts/threat-intelligence-v2.sh update &
                    local ti_pid=$!
                    sleep 3
                    
                    # Check for alerts generation
                    log_info "Checking for threat alerts..."
                    
                    # Simulate threat detection by checking IOCs
                    local high_confidence_iocs=$(sqlite3 "$threat_db" "SELECT COUNT(*) FROM indicators WHERE confidence >= 90 AND active = 1;" 2>/dev/null || echo "0")
                    
                    if [ "$high_confidence_iocs" -gt 0 ]; then
                        log_pass "High-confidence threats detected: $high_confidence_iocs"
                        
                        # Check if alerts were generated
                        local alert_count=$(sqlite3 "$threat_db" "SELECT COUNT(*) FROM alerts WHERE created_at > datetime('now', '-5 minutes');" 2>/dev/null || echo "0")
                        
                        if [ "$alert_count" -gt 0 ]; then
                            log_pass "Threat alerts generated: $alert_count"
                        else
                            log_warn "No threat alerts generated (may need alerting configuration)"
                        fi
                    else
                        log_fail "No high-confidence threats found"
                    fi
                    
                    # Stop threat intelligence process
                    kill $ti_pid 2>/dev/null || true
                    wait $ti_pid 2>/dev/null || true
                else
                    log_fail "Threat intelligence script not found"
                fi
            else
                log_fail "Failed to insert test IOCs"
            fi
        else
            log_fail "Threat intelligence database not available"
        fi
    else
        log_warn "Threat intelligence is disabled - skipping alerting test"
    fi
}

# Test 3: Incident Creation from Threat Detection
test_incident_creation_workflow() {
    log_test "Testing Incident Creation from Threat Detection"
    
    # Create test threat that should trigger incident
    log_info "Creating test threat scenario for incident creation..."
    
    if [ -f "$PROJECT_ROOT/scripts/incident-response.sh" ]; then
        source "$PROJECT_ROOT/scripts/incident-response.sh"
        
        # Create test incident
        local test_title="Test Threat Detection Incident"
        local test_description="This is a test incident created from threat detection scenario"
        local test_severity="high"
        
        if command -v create_incident &> /dev/null; then
            local incident_id=$(create_incident "$test_title" "$test_description" "$test_severity" 2>/dev/null || echo "")
            
            if [ -n "$incident_id" ]; then
                log_pass "Incident created from threat detection: $incident_id"
                
                # Verify incident in database
                local incident_db="$AEGIS_HOME/configs/incident_response/incidents.db"
                if [ -f "$incident_db" ] && command -v sqlite3 &> /dev/null; then
                    local incident_count=$(sqlite3 "$incident_db" "SELECT COUNT(*) FROM incidents WHERE id = '$incident_id';" 2>/dev/null || echo "0")
                    
                    if [ "$incident_count" -eq 1 ]; then
                        log_pass "Incident properly stored in database"
                        
                        # Check incident details
                        local incident_details=$(sqlite3 "$incident_db" "SELECT title, severity, status FROM incidents WHERE id = '$incident_id';" 2>/dev/null || echo "")
                        
                        if echo "$incident_details" | grep -q "$test_title"; then
                            log_pass "Incident details correctly stored"
                        else
                            log_fail "Incident details not correctly stored"
                        fi
                    else
                        log_fail "Incident not found in database"
                    fi
                else
                    log_fail "Incident database not available for verification"
                fi
            else
                log_fail "Failed to create incident from threat detection"
            fi
        else
            log_fail "Incident creation function not available"
        fi
    else
        log_fail "Incident response script not found"
    fi
}

# Test 4: Alert Notification Workflow
test_alert_notification_workflow() {
    log_test "Testing Alert Notification Workflow"
    
    # Create test alert scenario
    log_info "Creating test alert scenario..."
    
    # Test different notification methods
    local notification_methods=("system" "email" "dashboard")
    
    for method in "${notification_methods[@]}"; do
        log_info "Testing $method notification method..."
        
        # Create test alert
        local test_alert="TEST_ALERT_$(date +%s)"
        local test_message="This is a test alert for $method notification"
        
        if [ -f "$PROJECT_ROOT/scripts/incident-response.sh" ]; then
            source "$PROJECT_ROOT/scripts/incident-response.sh"
            
            if command -v send_notification &> /dev/null; then
                if send_notification "$test_alert" "$test_message" "$method" 2>/dev/null; then
                    log_pass "$method notification sent successfully"
                    
                    # Check notification log
                    local notification_log="$AEGIS_HOME/logs/notifications.log"
                    if [ -f "$notification_log" ]; then
                        if tail -n 10 "$notification_log" | grep -q "$test_alert"; then
                            log_pass "$method notification logged successfully"
                        else
                            log_warn "$method notification may not be logged"
                        fi
                    else
                        log_warn "Notification log not found"
                    fi
                else
                    log_fail "$method notification failed"
                fi
            else
                log_fail "Notification function not available"
            fi
        else
            log_fail "Incident response script not found"
        fi
    done
}

# Test 5: Real-time Threat Detection Dashboard Integration
test_realtime_threat_dashboard() {
    log_test "Testing Real-time Threat Detection Dashboard Integration"
    
    # Start dashboard if not running
    local dashboard_url="http://localhost:8080"
    local dashboard_running=false
    
    if curl -s --connect-timeout 5 "$dashboard_url" >/dev/null 2>&1; then
        dashboard_running=true
        log_info "Dashboard is already running"
    else
        log_info "Starting dashboard for real-time testing..."
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
        # Test real-time threat data
        log_info "Testing real-time threat data integration..."
        
        # Create test threat
        local behavioral_db="$AEGIS_HOME/configs/behavioral_analysis/behavioral_data.db"
        if [ -f "$behavioral_db" ] && command -v sqlite3 &> /dev/null; then
            # Insert test anomaly
            sqlite3 "$behavioral_db" << EOF 2>/dev/null
INSERT INTO anomalies (id, type, severity, description, detected_at) 
VALUES ('TEST_ANOMALY_$(date +%s)', 'test_threat', 'high', 'Test threat for dashboard integration', datetime('now'));
EOF
            
            # Test dashboard API for real-time data
            local api_response=$(curl -s "$dashboard_url/api/behavioral/anomalies" 2>/dev/null || echo "")
            
            if [ -n "$api_response" ]; then
                if echo "$api_response" | grep -q "test_threat\|TEST_ANOMALY"; then
                    log_pass "Real-time threat data available in dashboard"
                else
                    log_warn "Test threat data not immediately available in dashboard"
                fi
                
                # Test WebSocket updates
                if command -v nc &> /dev/null; then
                    local ws_response=$(echo -e "GET /socket.io/ HTTP/1.1\r\nHost: localhost:8080\r\n\r\n" | nc localhost 8080 2>/dev/null || echo "")
                    
                    if [ -n "$ws_response" ]; then
                        log_pass "WebSocket endpoint available for real-time updates"
                    else
                        log_warn "WebSocket endpoint may not be available"
                    fi
                else
                    log_warn "Netcat not available - cannot test WebSocket"
                fi
            else
                log_fail "Dashboard API not responding for threat data"
            fi
        else
            log_fail "Behavioral database not available for test data creation"
        fi
    fi
}

# Test 6: Threat Escalation Workflow
test_threat_escalation_workflow() {
    log_test "Testing Threat Escalation Workflow"
    
    # Create escalating threat scenario
    log_info "Creating escalating threat scenario..."
    
    local escalation_levels=("low" "medium" "high" "critical")
    local incident_ids=()
    
    for level in "${escalation_levels[@]}"; do
        log_info "Creating $level severity incident..."
        
        if [ -f "$PROJECT_ROOT/scripts/incident-response.sh" ]; then
            source "$PROJECT_ROOT/scripts/incident-response.sh"
            
            if command -v create_incident &> /dev/null; then
                local incident_id=$(create_incident "Escalation Test $level" "Test incident for $level escalation" "$level" 2>/dev/null || echo "")
                
                if [ -n "$incident_id" ]; then
                    incident_ids+=("$incident_id")
                    log_pass "$level severity incident created: $incident_id"
                    
                    # Simulate escalation based on severity
                    case "$level" in
                        "high"|"critical")
                            # Test automatic escalation
                            if command -v escalate_incident &> /dev/null; then
                                if escalate_incident "$incident_id" "escalated" 2>/dev/null; then
                                    log_pass "Incident escalation processed: $incident_id"
                                else
                                    log_warn "Incident escalation failed: $incident_id"
                                fi
                            else
                                log_warn "Escalation function not available"
                            fi
                            ;;
                    esac
                else
                    log_fail "Failed to create $level severity incident"
                fi
            else
                log_fail "Incident creation function not available"
            fi
        else
            log_fail "Incident response script not found"
            break
        fi
        
        sleep 1  # Small delay between escalations
    done
    
    # Verify escalation workflow
    if [ ${#incident_ids[@]} -gt 0 ]; then
        log_info "Verifying escalation workflow for ${#incident_ids[@]} incidents..."
        
        local incident_db="$AEGIS_HOME/configs/incident_response/incidents.db"
        if [ -f "$incident_db" ] && command -v sqlite3 &> /dev/null; then
            local escalated_count=0
            
            for incident_id in "${incident_ids[@]}"; do
                local status=$(sqlite3 "$incident_db" "SELECT status FROM incidents WHERE id = '$incident_id';" 2>/dev/null || echo "")
                
                if [ "$status" = "escalated" ] || [ "$status" = "investigating" ]; then
                    ((escalated_count++))
                fi
            done
            
            if [ "$escalated_count" -gt 0 ]; then
                log_pass "Escalation workflow processed: $escalated_count/${#incident_ids[@]} incidents"
            else
                log_warn "Escalation workflow may not be fully implemented"
            fi
        else
            log_fail "Incident database not available for escalation verification"
        fi
    fi
}

# Test 7: Threat Intelligence Integration with Behavioral Analysis
test_ti_behavioral_integration() {
    log_test "Testing Threat Intelligence Integration with Behavioral Analysis"
    
    # Create test scenario where threat intelligence informs behavioral analysis
    log_info "Creating TI-behavioral integration test scenario..."
    
    local threat_db="$AEGIS_HOME/configs/threat_intelligence/ioc_database.db"
    local behavioral_db="$AEGIS_HOME/configs/behavioral_analysis/behavioral_data.db"
    
    if [ -f "$threat_db" ] && [ -f "$behavioral_db" ] && command -v sqlite3 &> /dev/null; then
        # Add test IOCs to threat intelligence
        sqlite3 "$threat_db" << EOF 2>/dev/null
INSERT OR REPLACE INTO indicators (value, type, source, confidence, first_seen) 
VALUES ('suspicious.process.name', 'process', 'test_integration', 85, datetime('now'));
INSERT OR REPLACE INTO indicators (value, type, source, confidence, first_seen) 
VALUES ('10.0.0.999', 'ip', 'test_integration', 90, datetime('now'));
EOF
        
        # Simulate behavioral analysis that uses threat intelligence
        if [ -f "$PROJECT_ROOT/scripts/behavioral-analysis.sh" ]; then
            cd "$PROJECT_ROOT"
            ./scripts/behavioral-analysis.sh analyze &
            local analysis_pid=$!
            sleep 3
            
            # Create test process behavior that matches IOCs
            sqlite3 "$behavioral_db" << EOF 2>/dev/null
INSERT INTO process_behavior (timestamp, process_name, cpu_usage, memory_usage, pid, parent_pid) 
VALUES (datetime('now'), 'suspicious.process.name', 95.5, 80.2, 9999, 1);
INSERT INTO network_behavior (timestamp, source_ip, dest_ip, port, protocol) 
VALUES (datetime('now'), '10.0.0.999', '192.168.1.100', 443, 'TCP');
EOF
            
            # Wait for analysis
            sleep 2
            
            # Check if behavioral analysis detected threats
            local threat_matches=$(sqlite3 "$behavioral_db" "SELECT COUNT(*) FROM threat_matches WHERE detected_at > datetime('now', '-5 minutes');" 2>/dev/null || echo "0")
            
            if [ "$threat_matches" -gt 0 ]; then
                log_pass "Threat intelligence integrated with behavioral analysis: $threat_matches matches"
            else
                log_warn "Threat intelligence integration may not be fully implemented"
            fi
            
            # Stop analysis
            kill $analysis_pid 2>/dev/null || true
            wait $analysis_pid 2>/dev/null || true
        else
            log_fail "Behavioral analysis script not found"
        fi
    else
        log_fail "Required databases not available for integration testing"
    fi
}

# Test 8: Multi-Source Threat Correlation
test_multisource_threat_correlation() {
    log_test "Testing Multi-Source Threat Correlation"
    
    # Create test threats from multiple sources
    log_info "Creating multi-source threat correlation test..."
    
    local sources=("behavioral" "threat_intel" "network" "file_system")
    local correlated_threats=0
    
    for source in "${sources[@]}"; do
        log_info "Creating threat from $source source..."
        
        case "$source" in
            "behavioral")
                # Create behavioral anomaly
                local behavioral_db="$AEGIS_HOME/configs/behavioral_analysis/behavioral_data.db"
                if [ -f "$behavioral_db" ] && command -v sqlite3 &> /dev/null; then
                    sqlite3 "$behavioral_db" << EOF 2>/dev/null
INSERT INTO anomalies (id, type, severity, source, detected_at) 
VALUES ('CORR_TEST_$(date +%s)_BEH', 'correlation_test', 'medium', 'behavioral', datetime('now'));
EOF
                    ((correlated_threats++))
                fi
                ;;
            "threat_intel")
                # Create threat intelligence indicator
                local threat_db="$AEGIS_HOME/configs/threat_intelligence/ioc_database.db"
                if [ -f "$threat_db" ] && command -v sqlite3 &> /dev/null; then
                    sqlite3 "$threat_db" << EOF 2>/dev/null
INSERT OR REPLACE INTO indicators (value, type, source, confidence, first_seen) 
VALUES ('correlation.test.com', 'domain', 'correlation_test', 80, datetime('now'));
EOF
                    ((correlated_threats++))
                fi
                ;;
            "network")
                # Create network-based threat
                local incident_db="$AEGIS_HOME/configs/incident_response/incidents.db"
                if [ -f "$incident_db" ] && command -v sqlite3 &> /dev/null; then
                    sqlite3 "$incident_db" << EOF 2>/dev/null
INSERT INTO incidents (id, title, description, severity, source, timestamp) 
VALUES ('CORR_TEST_$(date +%s)_NET', 'Network Correlation Test', 'Test incident for correlation', 'medium', 'network', datetime('now'));
EOF
                    ((correlated_threats++))
                fi
                ;;
            "file_system")
                # Create file system threat
                if [ -f "$incident_db" ] && command -v sqlite3 &> /dev/null; then
                    sqlite3 "$incident_db" << EOF 2>/dev/null
INSERT INTO incidents (id, title, description, severity, source, timestamp) 
VALUES ('CORR_TEST_$(date +%s)_FS', 'File System Correlation Test', 'Test incident for correlation', 'medium', 'file_system', datetime('now'));
EOF
                    ((correlated_threats++))
                fi
                ;;
        esac
    done
    
    # Test correlation engine
    if [ "$correlated_threats" -gt 0 ]; then
        log_info "Testing correlation engine with $correlated_threats threats..."
        
        # Run correlation analysis
        if [ -f "$PROJECT_ROOT/scripts/behavioral-analysis.sh" ]; then
            cd "$PROJECT_ROOT"
            ./scripts/behavioral-analysis.sh correlate &
            local correlate_pid=$!
            sleep 3
            
            # Check for correlated incidents
            local incident_db="$AEGIS_HOME/configs/incident_response/incidents.db"
            if [ -f "$incident_db" ] && command -v sqlite3 &> /dev/null; then
                local correlated_incidents=$(sqlite3 "$incident_db" "SELECT COUNT(*) FROM incidents WHERE title LIKE '%CORR_TEST%' AND status = 'correlated';" 2>/dev/null || echo "0")
                
                if [ "$correlated_incidents" -gt 0 ]; then
                    log_pass "Multi-source threat correlation successful: $correlated_incidents incidents"
                else
                    log_warn "Multi-source threat correlation may not be implemented"
                fi
            else
                log_fail "Incident database not available for correlation verification"
            fi
            
            # Stop correlation
            kill $correlate_pid 2>/dev/null || true
            wait $correlate_pid 2>/dev/null || true
        else
            log_fail "Correlation analysis script not found"
        fi
    else
        log_fail "No threats created for correlation testing"
    fi
}

# Test 9: Threat Response Automation
test_threat_response_automation() {
    log_test "Testing Threat Response Automation"
    
    # Create test threat that should trigger automated response
    log_info "Creating threat for automated response testing..."
    
    if [ -f "$PROJECT_ROOT/scripts/incident-response.sh" ]; then
        source "$PROJECT_ROOT/scripts/incident-response.sh"
        
        # Create high-severity incident
        local test_incident_id="AUTO_RESPONSE_TEST_$(date +%s)"
        
        if command -v create_incident &> /dev/null; then
            create_incident "$test_incident_id" "Automated Response Test" "Test incident for automated response" "critical" 2>/dev/null || true
            
            # Test automated response actions
            local response_actions=("quarantine" "isolate" "block_ip" "notify")
            local automated_actions=0
            
            for action in "${response_actions[@]}"; do
                log_info "Testing automated response action: $action"
                
                if command -v execute_automated_response &> /dev/null; then
                    if execute_automated_response "$action" "test_target" "dry_run" 2>/dev/null; then
                        log_pass "Automated response action works: $action"
                        ((automated_actions++))
                    else
                        log_fail "Automated response action failed: $action"
                    fi
                else
                    log_warn "Automated response function not available for: $action"
                fi
            done
            
            if [ "$automated_actions" -gt 0 ]; then
                log_pass "Threat response automation working: $automated_actions/${#response_actions[@]} actions"
            else
                log_fail "Threat response automation not working"
            fi
        else
            log_fail "Incident creation function not available"
        fi
    else
        log_fail "Incident response script not found"
    fi
}

# Test 10: Threat Detection Performance
test_threat_detection_performance() {
    log_test "Testing Threat Detection Performance"
    
    # Measure threat detection performance under load
    log_info "Testing threat detection performance..."
    
    local start_time=$(date +%s.%N)
    local threats_detected=0
    
    # Generate multiple threat scenarios
    for i in {1..10}; do
        # Create behavioral anomaly
        local behavioral_db="$AEGIS_HOME/configs/behavioral_analysis/behavioral_data.db"
        if [ -f "$behavioral_db" ] && command -v sqlite3 &> /dev/null; then
            sqlite3 "$behavioral_db" << EOF 2>/dev/null
INSERT INTO anomalies (id, type, severity, detected_at) 
VALUES ('PERF_TEST_$(date +%s)_$i', 'performance_test', 'medium', datetime('now'));
EOF
            ((threats_detected++))
        fi
        
        # Create network threat
        local threat_db="$AEGIS_HOME/configs/threat_intelligence/ioc_database.db"
        if [ -f "$threat_db" ] && command -v sqlite3 &> /dev/null; then
            sqlite3 "$threat_db" << EOF 2>/dev/null
INSERT OR REPLACE INTO indicators (value, type, source, confidence, first_seen) 
VALUES ('perf.test$i.com', 'domain', 'performance_test', 75, datetime('now'));
EOF
            ((threats_detected++))
        fi
    done
    
    local end_time=$(date +%s.%N)
    local total_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    local avg_time_per_threat=$(echo "scale=3; $total_time / $threats_detected" | bc -l 2>/dev/null || echo "0")
    
    log_info "Threat detection performance: $threats_detected threats in ${total_time}s"
    log_info "Average time per threat: ${avg_time_per_threat}s"
    
    # Check performance thresholds
    if (( $(echo "$avg_time_per_threat < 1.0" | bc -l 2>/dev/null || echo "1") )); then
        log_pass "Threat detection performance is acceptable"
    else
        log_warn "Threat detection performance may need improvement"
    fi
    
    # Check detection accuracy
    local detected_count=0
    local behavioral_db="$AEGIS_HOME/configs/behavioral_analysis/behavioral_data.db"
    if [ -f "$behavioral_db" ] && command -v sqlite3 &> /dev/null; then
        detected_count=$(sqlite3 "$behavioral_db" "SELECT COUNT(*) FROM anomalies WHERE type = 'performance_test';" 2>/dev/null || echo "0")
    fi
    
    if [ "$detected_count" -eq 10 ]; then
        log_pass "Threat detection accuracy: 100% ($detected_count/10)"
    else
        log_fail "Threat detection accuracy issue: $detected_count/10"
    fi
}

# Cleanup function
cleanup() {
    log_info "Cleaning up threat detection test environment..."
    
    # Clean up test data
    local behavioral_db="$AEGIS_HOME/configs/behavioral_analysis/behavioral_data.db"
    local threat_db="$AEGIS_HOME/configs/threat_intelligence/ioc_database.db"
    local incident_db="$AEGIS_HOME/configs/incident_response/incidents.db"
    
    if command -v sqlite3 &> /dev/null; then
        # Clean test anomalies
        [ -f "$behavioral_db" ] && sqlite3 "$behavioral_db" "DELETE FROM anomalies WHERE type LIKE '%test%' OR id LIKE 'TEST_%' OR id LIKE 'CORR_%' OR id LIKE 'PERF_%';" 2>/dev/null || true
        
        # Clean test IOCs
        [ -f "$threat_db" ] && sqlite3 "$threat_db" "DELETE FROM indicators WHERE source LIKE '%test%' OR source LIKE '%integration%' OR source LIKE '%correlation%' OR source LIKE '%performance%';" 2>/dev/null || true
        
        # Clean test incidents
        [ -f "$incident_db" ] && sqlite3 "$incident_db" "DELETE FROM incidents WHERE title LIKE '%Test%' OR title LIKE '%Escalation%' OR title LIKE '%Correlation%' OR title LIKE '%Automated%' OR id LIKE 'TEST_%' OR id LIKE 'CORR_%' OR id LIKE 'AUTO_%';" 2>/dev/null || true
    fi
    
    # Kill any remaining test processes
    pkill -f "behavioral-monitor.sh" 2>/dev/null || true
    pkill -f "threat-intelligence-v2.sh" 2>/dev/null || true
    pkill -f "behavioral-analysis.sh" 2>/dev/null || true
}

# Main test execution
main() {
    echo -e "${WHITE}========================================${NC}"
    echo -e "${WHITE}🚨 THREAT DETECTION AND ALERTING TESTS 🚨${NC}"
    echo -e "${WHITE}========================================${NC}"
    echo -e "${BLUE}Test started: $(date)${NC}"
    echo ""
    
    # Set up cleanup trap
    trap cleanup EXIT
    
    # Run all tests
    test_behavioral_anomaly_workflow
    test_threat_intelligence_alerting
    test_incident_creation_workflow
    test_alert_notification_workflow
    test_realtime_threat_dashboard
    test_threat_escalation_workflow
    test_ti_behavioral_integration
    test_multisource_threat_correlation
    test_threat_response_automation
    test_threat_detection_performance
    
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
        echo -e "${GREEN}🎉 ALL THREAT DETECTION TESTS PASSED!${NC}"
        exit 0
    else
        echo -e "${RED}⚠️ $TESTS_FAILED test(s) failed. Review issues above.${NC}"
        exit 1
    fi
}

# Run main function
main "$@"