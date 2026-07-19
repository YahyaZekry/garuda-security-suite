#!/bin/bash
# Aegis Security Suite Integration Validation Script
# Validates that all components are working together properly

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AEGIS_HOME="${AEGIS_HOME:-$(dirname "$(dirname "$(readlink -f "$0")")")}"
DASHBOARD_PORT="8080"
VALIDATION_PASSED=0
VALIDATION_FAILED=0

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    ((VALIDATION_PASSED++))
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    ((VALIDATION_FAILED++))
}

print_header() {
    echo -e "${WHITE}========================================${NC}"
    echo -e "${WHITE}$1${NC}"
    echo -e "${WHITE}========================================${NC}"
}

# Function to check if service is running
check_service() {
    local service_name="$1"
    local display_name="$2"
    
    print_status "Checking $display_name service..."
    
    if systemctl is-active --quiet "$service_name" 2>/dev/null; then
        print_success "$display_name service is running"
        return 0
    else
        print_error "$display_name service is not running"
        return 1
    fi
}

# Function to check if port is listening
check_port() {
    local port="$1"
    local service_name="$2"
    
    print_status "Checking $service_name port $port..."
    
    if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
        print_success "$service_name is listening on port $port"
        return 0
    else
        print_error "$service_name is not listening on port $port"
        return 1
    fi
}

# Function to check if dashboard is responding
check_dashboard() {
    print_status "Checking dashboard web interface..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s --connect-timeout 5 "http://localhost:$DASHBOARD_PORT" >/dev/null 2>&1; then
            print_success "Dashboard is responding at http://localhost:$DASHBOARD_PORT"
            return 0
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            print_error "Dashboard failed to respond after $max_attempts attempts"
            return 1
        fi
        
        print_status "Attempt $attempt/$max_attempts - waiting for dashboard to start..."
        sleep 2
        ((attempt++))
    done
}

# Function to test dashboard authentication
test_dashboard_auth() {
    print_status "Testing dashboard authentication..."
    
    # Test login endpoint
    local response=$(curl -s -X POST "http://localhost:$DASHBOARD_PORT/login" \
                   -H "Content-Type: application/x-www-form-urlencoded" \
                   -d "username=admin&password=admin123" \
                   -w "%{http_code}" 2>/dev/null)
    
    if [ "$response" = "302" ] || [ "$response" = "303" ]; then
        print_success "Dashboard authentication is working"
        return 0
    else
        print_error "Dashboard authentication failed (HTTP $response)"
        return 1
    fi
}

# Function to test API endpoints
test_api_endpoints() {
    print_status "Testing dashboard API endpoints..."
    
    local api_endpoints=(
        "/api/system/status"
        "/api/behavioral/metrics"
        "/api/threats/iocs"
        "/api/incidents"
        "/api/auth/status"
    )
    
    local endpoints_passed=0
    local endpoints_total=${#api_endpoints[@]}
    
    for endpoint in "${api_endpoints[@]}"; do
        print_status "Testing endpoint: $endpoint"
        
        local response=$(curl -s -w "%{http_code}" "http://localhost:$DASHBOARD_PORT$endpoint" 2>/dev/null)
        
        if [ "$response" = "401" ]; then
            print_success "Endpoint $endpoint requires authentication (expected)"
            ((endpoints_passed++))
        elif [ "$response" = "200" ]; then
            print_success "Endpoint $endpoint is accessible"
            ((endpoints_passed++))
        else
            print_warning "Endpoint $endpoint returned HTTP $response"
        fi
    done
    
    if [ $endpoints_passed -eq $endpoints_total ]; then
        print_success "All API endpoints are properly configured"
    else
        print_warning "Some API endpoints may have issues ($endpoints_passed/$endpoints_total passed)"
    fi
}

# Function to test database connectivity
test_databases() {
    print_status "Testing database connectivity..."
    
    local databases=(
        "$AEGIS_HOME/configs/behavioral_analysis/behavioral_data.db"
        "$AEGIS_HOME/configs/incident_response/incidents.db"
        "$AEGIS_HOME/configs/threat_intelligence/ioc_database.db"
        "$AEGIS_HOME/configs/web-dashboard/auth.db"
    )
    
    local db_passed=0
    local db_total=${#databases[@]}
    
    for db in "${databases[@]}"; do
        if [ -f "$db" ]; then
            # Test if database is readable and not corrupted
            if sqlite3 "$db" "SELECT 1;" >/dev/null 2>&1; then
                print_success "Database $(basename "$db") is accessible"
                ((db_passed++))
            else
                print_error "Database $(basename "$db") is corrupted or inaccessible"
            fi
        else
            print_warning "Database $(basename "$db") does not exist"
        fi
    done
    
    if [ $db_passed -eq $db_total ]; then
        print_success "All databases are accessible"
    else
        print_warning "Some databases have issues ($db_passed/$db_total accessible)"
    fi
}

# Function to test script functionality
test_scripts() {
    print_status "Testing security suite scripts..."
    
    local scripts=(
        "behavioral-analysis.sh"
        "behavioral-monitor.sh"
        "threat-intelligence-v2.sh"
        "incident-response.sh"
        "security-daily-scan.sh"
    )
    
    local scripts_passed=0
    local scripts_total=${#scripts[@]}
    
    for script in "${scripts[@]}"; do
        local script_path="$AEGIS_HOME/scripts/$script"
        
        if [ -f "$script_path" ]; then
            # Test script syntax
            if bash -n "$script_path" >/dev/null 2>&1; then
                print_success "Script $script has valid syntax"
                ((scripts_passed++))
            else
                print_error "Script $script has syntax errors"
            fi
        else
            print_warning "Script $script not found"
        fi
    done
    
    if [ $scripts_passed -eq $scripts_total ]; then
        print_success "All scripts have valid syntax"
    else
        print_warning "Some scripts have issues ($scripts_passed/$scripts_total valid)"
    fi
}

# Function to test configuration files
test_configuration() {
    print_status "Testing configuration files..."
    
    local config_files=(
        "$AEGIS_HOME/configs/security-config.conf"
        "$AEGIS_HOME/web-dashboard/config/dashboard.conf"
    )
    
    local config_passed=0
    local config_total=${#config_files[@]}
    
    for config in "${config_files[@]}"; do
        if [ -f "$config" ]; then
            # Test if configuration is readable and has required settings
            if [ -r "$config" ] && [ -s "$config" ]; then
                print_success "Configuration $(basename "$config") is accessible"
                ((config_passed++))
            else
                print_error "Configuration $(basename "$config") is not accessible"
            fi
        else
            print_warning "Configuration $(basename "$config") does not exist"
        fi
    done
    
    if [ $config_passed -eq $config_total ]; then
        print_success "All configuration files are accessible"
    else
        print_warning "Some configuration files have issues ($config_passed/$config_total accessible)"
    fi
}

# Function to test log directories
test_logging() {
    print_status "Testing logging infrastructure..."
    
    local log_dirs=(
        "$AEGIS_HOME/logs"
        "/var/log/aegis-security-suite"
    )
    
    local log_dirs_passed=0
    local log_dirs_total=${#log_dirs[@]}
    
    for log_dir in "${log_dirs[@]}"; do
        if [ -d "$log_dir" ]; then
            # Test if log directory is writable
            if [ -w "$log_dir" ]; then
                print_success "Log directory $log_dir is writable"
                ((log_dirs_passed++))
            else
                print_error "Log directory $log_dir is not writable"
            fi
        else
            print_warning "Log directory $log_dir does not exist"
        fi
    done
    
    if [ $log_dirs_passed -eq $log_dirs_total ]; then
        print_success "All log directories are accessible"
    else
        print_warning "Some log directories have issues ($log_dirs_passed/$log_dirs_total accessible)"
    fi
}

# Function to test real-time monitoring
test_realtime_monitoring() {
    print_status "Testing real-time monitoring..."
    
    # Test WebSocket connection
    if command -v nc >/dev/null 2>&1; then
        local ws_response=$(echo -e "GET /socket.io/ HTTP/1.1\r\nHost: localhost:$DASHBOARD_PORT\r\n\r\n" | nc localhost $DASHBOARD_PORT 2>/dev/null)
        
        if echo "$ws_response" | grep -q "101\|WebSocket\|socket.io"; then
            print_success "WebSocket endpoint is available"
            return 0
        else
            print_warning "WebSocket endpoint may not be available"
            return 1
        fi
    else
        print_warning "Netcat not available - cannot test WebSocket"
        return 1
    fi
}

# Function to test security features
test_security_features() {
    print_status "Testing security features..."
    
    # Test CSRF protection
    local csrf_response=$(curl -s -X POST "http://localhost:$DASHBOARD_PORT/api/config/update" \
                         -H "Content-Type: application/json" \
                         -d '{"test": "data"}' \
                         -w "%{http_code}" 2>/dev/null)
    
    if [ "$csrf_response" = "403" ]; then
        print_success "CSRF protection is active"
    else
        print_warning "CSRF protection may not be active"
    fi
    
    # Test security headers
    local headers_response=$(curl -s -I "http://localhost:$DASHBOARD_PORT/" 2>/dev/null)
    
    if echo "$headers_response" | grep -qi "x-frame-options\|x-xss-protection\|x-content-type-options"; then
        print_success "Security headers are present"
    else
        print_warning "Some security headers may be missing"
    fi
}

# Function to generate integration report
generate_report() {
    local report_file="$AEGIS_HOME/test-results/integration-validation-$(date +%Y%m%d_%H%M%S).txt"
    
    mkdir -p "$(dirname "$report_file")"
    
    cat > "$report_file" << EOF
Aegis Security Suite Integration Validation Report
Generated: $(date)
===============================================

SUMMARY:
--------
Tests Passed: $VALIDATION_PASSED
Tests Failed: $VALIDATION_FAILED
Success Rate: $(( VALIDATION_PASSED * 100 / (VALIDATION_PASSED + VALIDATION_FAILED) ))%

COMPONENT STATUS:
----------------
Dashboard Service: $(systemctl is-active --quiet aegis-dashboard 2>/dev/null && echo "Running" || echo "Stopped")
Dashboard Port: $(netstat -tlnp 2>/dev/null | grep ":$DASHBOARD_PORT " && echo "Listening" || echo "Not Listening")
Authentication: $(curl -s -w "%{http_code}" "http://localhost:$DASHBOARD_PORT/login" -X POST -d "username=admin&password=admin123" 2>/dev/null | grep -E "302|303" >/dev/null && echo "Working" || echo "Failed")
API Endpoints: $(curl -s "http://localhost:$DASHBOARD_PORT/api/system/status" -w "%{http_code}" 2>/dev/null | grep -E "200|401" >/dev/null && echo "Working" || echo "Failed")
Databases: $(sqlite3 "$AEGIS_HOME/configs/web-dashboard/auth.db" "SELECT 1;" >/dev/null 2>&1 && echo "Accessible" || echo "Issues")

RECOMMENDATIONS:
----------------
1. Ensure all services are running: systemctl start aegis-dashboard
2. Check logs for issues: journalctl -u aegis-dashboard -f
3. Verify configuration: cat $AEGIS_HOME/configs/security-config.conf
4. Test dashboard manually: curl http://localhost:$DASHBOARD_PORT
5. Monitor system resources: htop, iotop

NEXT STEPS:
-----------
1. Run comprehensive test suite: ./tests/test-suite-comprehensive.sh
2. Verify all components are operational
3. Check real-time monitoring functionality
4. Validate user authentication and permissions
5. Test incident response workflow
EOF
    
    print_success "Integration report generated: $report_file"
}

# Main validation function
run_validation() {
    print_header "Aegis Security Suite Integration Validation"
    
    # Check if security suite is installed
    if [ ! -d "$AEGIS_HOME" ]; then
        print_error "Security suite not found at $AEGIS_HOME"
        exit 1
    fi
    
    # Run all validation tests
    test_configuration
    test_databases
    test_scripts
    test_logging
    
    # Check dashboard service
    check_service "aegis-dashboard" "Dashboard"
    check_port "$DASHBOARD_PORT" "Dashboard"
    
    if check_service "aegis-dashboard" "Dashboard"; then
        check_dashboard
        test_dashboard_auth
        test_api_endpoints
        test_realtime_monitoring
        test_security_features
    fi
    
    # Generate report
    generate_report
    
    # Final summary
    print_header "Validation Summary"
    
    local total_tests=$((VALIDATION_PASSED + VALIDATION_FAILED))
    
    echo -e "${BLUE}Total Tests: $total_tests${NC}"
    echo -e "${GREEN}Passed: $VALIDATION_PASSED${NC}"
    echo -e "${RED}Failed: $VALIDATION_FAILED${NC}"
    
    if [ $VALIDATION_FAILED -eq 0 ]; then
        echo -e "${GREEN}🎉 ALL VALIDATIONS PASSED!${NC}"
        echo -e "${GREEN}Aegis Security Suite is fully operational${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  $VALIDATION_FAILED validation(s) failed${NC}"
        echo -e "${YELLOW}Please review the issues above${NC}"
        return 1
    fi
}

# Function to show help
show_help() {
    echo "Aegis Security Suite Integration Validation Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -q, --quiet         Quiet mode (minimal output)"
    echo "  -v, --verbose       Verbose mode (detailed output)"
    echo "  -p, --port PORT     Dashboard port (default: 8080)"
    echo "  -d, --dir PATH      Security suite home directory"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Run validation with defaults"
    echo "  $0 -p 8080 -d /opt/security     # Custom port and directory"
    echo "  $0 --verbose                          # Verbose output"
}

# Parse command line arguments
QUIET=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -p|--port)
            DASHBOARD_PORT="$2"
            shift 2
            ;;
        -d|--dir)
            AEGIS_HOME="$2"
            shift 2
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Trap signals for cleanup
trap 'print_status "Cleaning up..."; exit 0' INT TERM

# Run main validation
run_validation