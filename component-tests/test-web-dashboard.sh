#!/bin/bash
# Web Dashboard Component Tests
# Tests dashboard pages, functionality, API endpoints, and UI elements

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
TESTS_PASSED=0
TESTS_FAILED=0

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

# Test 1: Dashboard File Structure
test_dashboard_structure() {
    log_test "Testing Dashboard File Structure"
    
    # Check main application file
    if [ -f "$DASHBOARD_DIR/app.py" ]; then
        log_pass "Main application file exists: app.py"
        
        # Check if it's executable
        if [ -x "$DASHBOARD_DIR/app.py" ]; then
            log_pass "Main application file is executable"
        else
            log_fail "Main application file is not executable"
        fi
        
        # Check Python syntax
        if python3 -m py_compile "$DASHBOARD_DIR/app.py" 2>/dev/null; then
            log_pass "Main application has valid Python syntax"
        else
            log_fail "Main application has syntax errors"
        fi
    else
        log_fail "Main application file not found: app.py"
    fi
    
    # Check directory structure
    local required_dirs=("templates" "static" "api" "config")
    for dir in "${required_dirs[@]}"; do
        if [ -d "$DASHBOARD_DIR/$dir" ]; then
            log_pass "Required directory exists: $dir"
        else
            log_fail "Required directory missing: $dir"
        fi
    done
    
    # Check static subdirectories
    local static_dirs=("static/css" "static/js" "static/images")
    for dir in "${static_dirs[@]}"; do
        if [ -d "$DASHBOARD_DIR/$dir" ]; then
            log_pass "Static directory exists: $dir"
        else
            log_fail "Static directory missing: $dir"
        fi
    done
}

# Test 2: Template Files
test_template_files() {
    log_test "Testing Template Files"
    
    local required_templates=(
        "base.html"
        "login.html"
        "dashboard.html"
        "behavioral.html"
        "threats.html"
        "incidents.html"
        "config.html"
    )
    
    for template in "${required_templates[@]}"; do
        if [ -f "$DASHBOARD_DIR/templates/$template" ]; then
            log_pass "Template exists: $template"
            
            # Basic HTML validation
            if grep -q "<!DOCTYPE html>" "$DASHBOARD_DIR/templates/$template" 2>/dev/null || [ "$template" = "base.html" ]; then
                log_pass "Template has valid HTML structure: $template"
            else
                log_warn "Template may lack HTML structure: $template"
            fi
        else
            log_fail "Template missing: $template"
        fi
    done
    
    # Check template inheritance
    if grep -q "{% extends 'base.html' %}" "$DASHBOARD_DIR/templates/dashboard.html" 2>/dev/null; then
        log_pass "Dashboard template extends base template"
    else
        log_fail "Dashboard template doesn't extend base template"
    fi
    
    if grep -q "{% extends 'base.html' %}" "$DASHBOARD_DIR/templates/login.html" 2>/dev/null; then
        log_pass "Login template extends base template"
    else
        log_fail "Login template doesn't extend base template"
    fi
}

# Test 3: Static Files
test_static_files() {
    log_test "Testing Static Files"
    
    # Check CSS files
    if [ -f "$DASHBOARD_DIR/static/css/dashboard.css" ]; then
        log_pass "Main CSS file exists: dashboard.css"
        
        # Check CSS syntax (basic validation)
        if grep -q "body\|{" "$DASHBOARD_DIR/static/css/dashboard.css" 2>/dev/null; then
            log_pass "CSS file has valid structure"
        else
            log_warn "CSS file may have syntax issues"
        fi
    else
        log_fail "Main CSS file missing: dashboard.css"
    fi
    
    # Check JavaScript files
    if [ -f "$DASHBOARD_DIR/static/js/dashboard.js" ]; then
        log_pass "Main JavaScript file exists: dashboard.js"
        
        # Check JavaScript syntax (basic validation)
        if node -c "$DASHBOARD_DIR/static/js/dashboard.js" 2>/dev/null; then
            log_pass "JavaScript file has valid syntax"
        else
            log_warn "JavaScript file may have syntax issues"
        fi
    else
        log_fail "Main JavaScript file missing: dashboard.js"
    fi
}

# Test 4: API Modules
test_api_modules() {
    log_test "Testing API Modules"
    
    local api_modules=(
        "api/__init__.py"
        "api/system.py"
        "api/behavioral.py"
        "api/threats.py"
        "api/incidents.py"
    )
    
    for module in "${api_modules[@]}"; do
        if [ -f "$DASHBOARD_DIR/$module" ]; then
            log_pass "API module exists: $module"
            
            # Check Python syntax
            if python3 -m py_compile "$DASHBOARD_DIR/$module" 2>/dev/null; then
                log_pass "API module has valid Python syntax: $module"
            else
                log_fail "API module has syntax errors: $module"
            fi
        else
            log_fail "API module missing: $module"
        fi
    done
    
    # Check API endpoint definitions
    if [ -f "$DASHBOARD_DIR/api/system.py" ]; then
        if grep -q "@app.route\|def.*status" "$DASHBOARD_DIR/api/system.py" 2>/dev/null; then
            log_pass "System API has route definitions"
        else
            log_fail "System API missing route definitions"
        fi
    fi
    
    if [ -f "$DASHBOARD_DIR/api/behavioral.py" ]; then
        if grep -q "@app.route\|def.*metrics\|def.*anomalies" "$DASHBOARD_DIR/api/behavioral.py" 2>/dev/null; then
            log_pass "Behavioral API has route definitions"
        else
            log_fail "Behavioral API missing route definitions"
        fi
    fi
}

# Test 5: Configuration Files
test_configuration() {
    log_test "Testing Configuration Files"
    
    # Check requirements file
    if [ -f "$DASHBOARD_DIR/requirements.txt" ]; then
        log_pass "Requirements file exists"
        
        # Check for required dependencies
        local required_deps=("flask" "requests")
        for dep in "${required_deps[@]}"; do
            if grep -q "$dep" "$DASHBOARD_DIR/requirements.txt" 2>/dev/null; then
                log_pass "Required dependency found: $dep"
            else
                log_warn "Required dependency missing: $dep"
            fi
        done
    else
        log_fail "Requirements file missing"
    fi
    
    # Check dashboard configuration
    if [ -f "$DASHBOARD_DIR/config/dashboard.conf" ]; then
        log_pass "Dashboard configuration file exists"
        
        # Check configuration format
        if grep -q "HOST\|PORT\|DEBUG" "$DASHBOARD_DIR/config/dashboard.conf" 2>/dev/null; then
            log_pass "Configuration file has required settings"
        else
            log_warn "Configuration file may be missing required settings"
        fi
    else
        log_fail "Dashboard configuration file missing"
    fi
    
    # Check startup script
    if [ -f "$DASHBOARD_DIR/start-dashboard.sh" ]; then
        log_pass "Startup script exists"
        
        if [ -x "$DASHBOARD_DIR/start-dashboard.sh" ]; then
            log_pass "Startup script is executable"
        else
            log_fail "Startup script is not executable"
        fi
    else
        log_fail "Startup script missing"
    fi
}

# Test 6: Authentication and Security
test_authentication() {
    log_test "Testing Authentication and Security"
    
    if [ -f "$DASHBOARD_DIR/app.py" ]; then
        # Check for authentication decorators
        if grep -q "@require_auth\|login_required" "$DASHBOARD_DIR/app.py" 2>/dev/null; then
            log_pass "Authentication decorators found"
        else
            log_fail "Authentication decorators missing"
        fi
        
        # Check for session management
        if grep -q "session\|login\|logout" "$DASHBOARD_DIR/app.py" 2>/dev/null; then
            log_pass "Session management implemented"
        else
            log_fail "Session management missing"
        fi
        
        # Check for password handling
        if grep -q "password\|hash\|verify" "$DASHBOARD_DIR/app.py" 2>/dev/null; then
            log_pass "Password handling implemented"
        else
            log_fail "Password handling missing"
        fi
        
        # Check for CSRF protection
        if grep -q "csrf\|SECRET_KEY\|WTF_CSRF" "$DASHBOARD_DIR/app.py" 2>/dev/null; then
            log_pass "CSRF protection implemented"
        else
            log_warn "CSRF protection may be missing"
        fi
    else
        log_fail "Cannot test authentication - app.py not found"
    fi
}

# Test 7: Database Integration
test_database_integration() {
    log_test "Testing Database Integration"
    
    # Check for database imports
    if [ -f "$DASHBOARD_DIR/app.py" ]; then
        if grep -q "sqlite3\|SQLAlchemy" "$DASHBOARD_DIR/app.py" 2>/dev/null; then
            log_pass "Database library imported"
        else
            log_warn "Database library not imported"
        fi
    fi
    
    # Check API modules for database usage
    for api_file in "$DASHBOARD_DIR/api"/*.py; do
        if [ -f "$api_file" ]; then
            local basename=$(basename "$api_file")
            if grep -q "sqlite3\|database\|db\." "$api_file" 2>/dev/null; then
                log_pass "Database usage found in $basename"
            else
                log_warn "Database usage not found in $basename"
            fi
        fi
    done
    
    # Test database paths
    local db_paths=(
        "$AEGIS_HOME/configs/behavioral_analysis/behavioral_data.db"
        "$AEGIS_HOME/configs/threat_intelligence/ioc_database.db"
        "$AEGIS_HOME/configs/incident_response/incidents.db"
    )
    
    for db_path in "${db_paths[@]}"; do
        if [ -f "$db_path" ]; then
            log_pass "Database file exists: $(basename "$db_path")"
            
            # Test database integrity
            if command -v sqlite3 &> /dev/null; then
                if sqlite3 "$db_path" "PRAGMA integrity_check;" 2>/dev/null | grep -q "ok"; then
                    log_pass "Database integrity check passed: $(basename "$db_path")"
                else
                    log_fail "Database integrity check failed: $(basename "$db_path")"
                fi
            else
                log_warn "SQLite3 not available - cannot check database integrity"
            fi
        else
            log_warn "Database file not found: $(basename "$db_path")"
        fi
    done
}

# Test 8: Real-time Features
test_realtime_features() {
    log_test "Testing Real-time Features"
    
    # Check for WebSocket support
    if [ -f "$DASHBOARD_DIR/app.py" ]; then
        if grep -q "socketio\|websocket\|SocketIO" "$DASHBOARD_DIR/app.py" 2>/dev/null; then
            log_pass "WebSocket support implemented"
        else
            log_warn "WebSocket support may be missing"
        fi
    fi
    
    # Check JavaScript for real-time updates
    if [ -f "$DASHBOARD_DIR/static/js/dashboard.js" ]; then
        if grep -q "socket\|websocket\|setInterval\|fetch" "$DASHBOARD_DIR/static/js/dashboard.js" 2>/dev/null; then
            log_pass "Real-time update logic found in JavaScript"
        else
            log_warn "Real-time update logic may be missing"
        fi
    fi
    
    # Check for auto-refresh mechanisms
    if grep -q "refresh\|update\|interval" "$DASHBOARD_DIR/templates/dashboard.html" 2>/dev/null; then
        log_pass "Auto-refresh mechanisms found in templates"
    else
        log_warn "Auto-refresh mechanisms may be missing"
    fi
}

# Test 9: Responsive Design
test_responsive_design() {
    log_test "Testing Responsive Design"
    
    # Check CSS for responsive design
    if [ -f "$DASHBOARD_DIR/static/css/dashboard.css" ]; then
        if grep -q "@media\|responsive\|mobile\|tablet" "$DASHBOARD_DIR/static/css/dashboard.css" 2>/dev/null; then
            log_pass "Responsive design CSS found"
        else
            log_warn "Responsive design CSS may be missing"
        fi
        
        if grep -q "viewport\|bootstrap\|grid\|flexbox" "$DASHBOARD_DIR/static/css/dashboard.css" 2>/dev/null; then
            log_pass "Modern CSS layout techniques used"
        else
            log_warn "Modern CSS layout techniques may be missing"
        fi
    fi
    
    # Check HTML for responsive meta tags
    if grep -q "viewport.*width.*device-width" "$DASHBOARD_DIR/templates/base.html" 2>/dev/null; then
        log_pass "Responsive viewport meta tag found"
    else
        log_warn "Responsive viewport meta tag may be missing"
    fi
}

# Test 10: Error Handling
test_error_handling() {
    log_test "Testing Error Handling"
    
    if [ -f "$DASHBOARD_DIR/app.py" ]; then
        # Check for error handlers
        if grep -q "@app.errorhandler\|except\|try:" "$DASHBOARD_DIR/app.py" 2>/dev/null; then
            log_pass "Error handling implemented"
        else
            log_warn "Error handling may be incomplete"
        fi
        
        # Check for logging
        if grep -q "log\|logger\|app.logger" "$DASHBOARD_DIR/app.py" 2>/dev/null; then
            log_pass "Logging implemented"
        else
            log_warn "Logging may be missing"
        fi
    fi
    
    # Check API modules for error handling
    for api_file in "$DASHBOARD_DIR/api"/*.py; do
        if [ -f "$api_file" ]; then
            local basename=$(basename "$api_file")
            if grep -q "try:\|except\|error\|Error" "$api_file" 2>/dev/null; then
                log_pass "Error handling found in $basename"
            else
                log_warn "Error handling may be missing in $basename"
            fi
        fi
    done
}

# Main test execution
main() {
    echo -e "${WHITE}========================================${NC}"
    echo -e "${WHITE}🌐 WEB DASHBOARD COMPONENT TESTS 🌐${NC}"
    echo -e "${WHITE}========================================${NC}"
    echo -e "${BLUE}Test started: $(date)${NC}"
    echo ""
    
    # Run all tests
    test_dashboard_structure
    test_template_files
    test_static_files
    test_api_modules
    test_configuration
    test_authentication
    test_database_integration
    test_realtime_features
    test_responsive_design
    test_error_handling
    
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
        echo -e "${GREEN}🎉 ALL WEB DASHBOARD TESTS PASSED!${NC}"
        exit 0
    else
        echo -e "${RED}⚠️ $TESTS_FAILED test(s) failed. Review issues above.${NC}"
        exit 1
    fi
}

# Run main function
main "$@"