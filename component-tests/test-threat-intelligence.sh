#!/bin/bash
# Threat Intelligence Component Tests
# Tests IOC database, threat feeds, and threat intelligence functionality

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

# Test 1: Threat Intelligence Script Availability
test_script_availability() {
    log_test "Testing Threat Intelligence Script Availability"
    
    local script_path="$PROJECT_ROOT/scripts/threat-intelligence-v2.sh"
    
    if [ -f "$script_path" ]; then
        log_pass "Threat intelligence script found: $script_path"
        
        if [ -x "$script_path" ]; then
            log_pass "Threat intelligence script is executable"
        else
            log_fail "Threat intelligence script is not executable"
        fi
        
        # Check script syntax
        if bash -n "$script_path" 2>/dev/null; then
            log_pass "Threat intelligence script has valid syntax"
        else
            log_fail "Threat intelligence script has syntax errors"
        fi
    else
        log_fail "Threat intelligence script not found: $script_path"
    fi
}

# Test 2: IOC Database Structure
test_ioc_database() {
    log_test "Testing IOC Database Structure"
    
    local db_dir="$AEGIS_HOME/configs/threat_intelligence"
    local db_file="$db_dir/ioc_database.db"
    
    # Check database directory
    if [ -d "$db_dir" ]; then
        log_pass "Threat intelligence database directory exists: $db_dir"
    else
        log_warn "Database directory not found, will be created: $db_dir"
        mkdir -p "$db_dir"
    fi
    
    # Check database file
    if [ -f "$db_file" ]; then
        log_pass "IOC database file exists: $db_file"
        
        if command -v sqlite3 &> /dev/null; then
            # Test database integrity
            local integrity_check=$(sqlite3 "$db_file" "PRAGMA integrity_check;" 2>/dev/null || echo "failed")
            if [ "$integrity_check" = "ok" ]; then
                log_pass "IOC database integrity check passed"
            else
                log_fail "IOC database integrity check failed: $integrity_check"
            fi
            
            # Check for required tables
            local tables=$(sqlite3 "$db_file" "SELECT name FROM sqlite_master WHERE type='table';" 2>/dev/null || echo "")
            if [ -n "$tables" ]; then
                log_pass "IOC database tables found: $tables"
                
                # Check for required tables
                local required_tables="indicators threat_feeds ioc_types sources"
                for table in $required_tables; do
                    if echo "$tables" | grep -q "$table"; then
                        log_pass "Required table exists: $table"
                    else
                        log_fail "Required table missing: $table"
                    fi
                done
            else
                log_fail "No tables found in IOC database"
            fi
        else
            log_warn "SQLite3 not available - cannot verify database structure"
        fi
    else
        log_warn "IOC database file not found - will be created during operation"
    fi
}

# Test 3: Threat Feed Configuration
test_threat_feed_configuration() {
    log_test "Testing Threat Feed Configuration"
    
    # Check for threat feed configuration
    if [ -n "${THREAT_FEED_URLS:-}" ]; then
        log_pass "Threat feed URLs configured"
        
        # Validate URL format
        local url_count=0
        local valid_urls=0
        for url in $THREAT_FEED_URLS; do
            ((url_count++))
            if [[ "$url" =~ ^https?:// ]]; then
                ((valid_urls++))
                log_pass "Valid threat feed URL: $url"
            else
                log_fail "Invalid threat feed URL: $url"
            fi
        done
        
        if [ "$valid_urls" -eq "$url_count" ] && [ "$url_count" -gt 0 ]; then
            log_pass "All threat feed URLs are valid"
        else
            log_fail "Some threat feed URLs are invalid"
        fi
    else
        log_warn "Threat feed URLs not configured"
    fi
    
    # Check for cache directory
    local cache_dir="$AEGIS_HOME/configs/threat_intelligence/cache"
    if [ -d "$cache_dir" ]; then
        log_pass "Threat feed cache directory exists: $cache_dir"
        
        # Check for cached files
        local cache_files=$(find "$cache_dir" -name "*.txt" -o -name "*.json" 2>/dev/null | wc -l)
        if [ "$cache_files" -gt 0 ]; then
            log_pass "Cached threat feed files found: $cache_files"
        else
            log_warn "No cached threat feed files found"
        fi
    else
        log_warn "Threat feed cache directory not found"
    fi
}

# Test 4: IOC Types and Validation
test_ioc_types() {
    log_test "Testing IOC Types and Validation"
    
    local db_file="$AEGIS_HOME/configs/threat_intelligence/ioc_database.db"
    
    if [ -f "$db_file" ] && command -v sqlite3 &> /dev/null; then
        # Check for IOC types
        local ioc_types=$(sqlite3 "$db_file" "SELECT DISTINCT type FROM indicators;" 2>/dev/null || echo "")
        if [ -n "$ioc_types" ]; then
            log_pass "IOC types found in database"
            
            # Check for common IOC types
            local common_types="ip domain url hash email"
            for type in $common_types; do
                if echo "$ioc_types" | grep -q "$type"; then
                    log_pass "Common IOC type found: $type"
                else
                    log_warn "Common IOC type not found: $type"
                fi
            done
        else
            log_warn "No IOC types found in database"
        fi
        
        # Test IOC validation function
        if [ -f "$PROJECT_ROOT/scripts/threat-intelligence-v2.sh" ]; then
            source "$PROJECT_ROOT/scripts/threat-intelligence-v2.sh"
            
            # Test IP validation
            if command -v validate_ip_ioc &> /dev/null; then
                if validate_ip_ioc "192.168.1.1" 2>/dev/null; then
                    log_pass "IP validation works for valid IP"
                else
                    log_fail "IP validation failed for valid IP"
                fi
                
                if ! validate_ip_ioc "invalid.ip" 2>/dev/null; then
                    log_pass "IP validation rejects invalid IP"
                else
                    log_fail "IP validation accepts invalid IP"
                fi
            else
                log_warn "IP validation function not available"
            fi
            
            # Test domain validation
            if command -v validate_domain_ioc &> /dev/null; then
                if validate_domain_ioc "example.com" 2>/dev/null; then
                    log_pass "Domain validation works for valid domain"
                else
                    log_fail "Domain validation failed for valid domain"
                fi
                
                if ! validate_domain_ioc "invalid..domain" 2>/dev/null; then
                    log_pass "Domain validation rejects invalid domain"
                else
                    log_fail "Domain validation accepts invalid domain"
                fi
            else
                log_warn "Domain validation function not available"
            fi
        else
            log_fail "Threat intelligence script not available for validation testing"
        fi
    else
        log_warn "Cannot test IOC types - database not available"
    fi
}

# Test 5: Threat Feed Processing
test_threat_feed_processing() {
    log_test "Testing Threat Feed Processing"
    
    if [ -f "$PROJECT_ROOT/scripts/threat-intelligence-v2.sh" ]; then
        source "$PROJECT_ROOT/scripts/threat-intelligence-v2.sh"
        
        # Test threat feed download function
        if command -v download_threat_feed &> /dev/null; then
            # Create test feed file
            local test_feed="/tmp/test_threat_feed_$$.txt"
            echo -e "192.168.1.100\nmalicious.example.com\nhttp://evil.site.com" > "$test_feed"
            
            if [ -f "$test_feed" ]; then
                log_pass "Test threat feed created"
                
                # Test feed processing
                if process_threat_feed "$test_feed" "test_feed" 2>/dev/null; then
                    log_pass "Threat feed processing successful"
                else
                    log_fail "Threat feed processing failed"
                fi
                
                # Cleanup
                rm -f "$test_feed"
            else
                log_fail "Failed to create test threat feed"
            fi
        else
            log_warn "Threat feed download function not available"
        fi
        
        # Test IOC extraction
        if command -v extract_iocs &> /dev/null; then
            local test_data="Suspicious IP: 192.168.1.200, Domain: bad.site.com, URL: http://malware.example.com/payload"
            local extracted_iocs=$(extract_iocs "$test_data" 2>/dev/null || echo "")
            
            if [[ "$extracted_iocs" =~ 192\.168\.1\.200 ]] && [[ "$extracted_iocs" =~ bad\.site\.com ]]; then
                log_pass "IOC extraction works correctly"
            else
                log_fail "IOC extraction failed"
            fi
        else
            log_warn "IOC extraction function not available"
        fi
    else
        log_fail "Threat intelligence script not available"
    fi
}

# Test 6: Database Operations
test_database_operations() {
    log_test "Testing Database Operations"
    
    local db_file="$AEGIS_HOME/configs/threat_intelligence/ioc_database.db"
    
    if [ -f "$db_file" ] && command -v sqlite3 &> /dev/null; then
        # Test IOC insertion
        local test_ioc="test.malicious.domain.com"
        local insert_result=$(sqlite3 "$db_file" "INSERT OR IGNORE INTO indicators (value, type, source, confidence) VALUES ('$test_ioc', 'domain', 'test', 100);" 2>/dev/null || echo "failed")
        
        if [ "$insert_result" != "failed" ]; then
            log_pass "IOC insertion successful"
            
            # Test IOC retrieval
            local retrieved_ioc=$(sqlite3 "$db_file" "SELECT value FROM indicators WHERE value = '$test_ioc';" 2>/dev/null || echo "")
            if [ "$retrieved_ioc" = "$test_ioc" ]; then
                log_pass "IOC retrieval successful"
            else
                log_fail "IOC retrieval failed"
            fi
            
            # Test IOC deletion
            local delete_result=$(sqlite3 "$db_file" "DELETE FROM indicators WHERE value = '$test_ioc';" 2>/dev/null || echo "failed")
            if [ "$delete_result" != "failed" ]; then
                log_pass "IOC deletion successful"
            else
                log_fail "IOC deletion failed"
            fi
        else
            log_fail "IOC insertion failed"
        fi
        
        # Test database query performance
        local start_time=$(date +%s.%N)
        local query_result=$(sqlite3 "$db_file" "SELECT COUNT(*) FROM indicators;" 2>/dev/null || echo "0")
        local end_time=$(date +%s.%N)
        local query_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
        
        if [ "$query_time" != "0" ]; then
            local query_time_ms=$(echo "$query_time * 1000" | bc -l 2>/dev/null || echo "0")
            if (( $(echo "$query_time_ms < 100" | bc -l 2>/dev/null || echo "1") )); then
                log_pass "Database query performance acceptable: ${query_time_ms}ms"
            else
                log_warn "Database query performance slow: ${query_time_ms}ms"
            fi
        else
            log_warn "Cannot measure query performance"
        fi
    else
        log_warn "Cannot test database operations - database not available"
    fi
}

# Test 7: Threat Intelligence API Integration
test_api_integration() {
    log_test "Testing Threat Intelligence API Integration"
    
    local api_file="$PROJECT_ROOT/web-dashboard/api/threats.py"
    
    if [ -f "$api_file" ]; then
        log_pass "Threat intelligence API file exists"
        
        # Check for API endpoints
        if grep -q "@app.route.*threats" "$api_file" 2>/dev/null; then
            log_pass "Threat API routes defined"
        else
            log_fail "Threat API routes not defined"
        fi
        
        # Check for database integration
        if grep -q "sqlite3\|database\|ioc_database" "$api_file" 2>/dev/null; then
            log_pass "Database integration found in API"
        else
            log_fail "Database integration missing in API"
        fi
        
        # Check for IOC search functionality
        if grep -q "search\|query\|filter" "$api_file" 2>/dev/null; then
            log_pass "IOC search functionality found"
        else
            log_fail "IOC search functionality missing"
        fi
        
        # Check for error handling
        if grep -q "try:\|except\|error" "$api_file" 2>/dev/null; then
            log_pass "Error handling implemented in API"
        else
            log_fail "Error handling missing in API"
        fi
    else
        log_fail "Threat intelligence API file not found"
    fi
}

# Test 8: Cache Management
test_cache_management() {
    log_test "Testing Cache Management"
    
    local cache_dir="$AEGIS_HOME/configs/threat_intelligence/cache"
    
    if [ -d "$cache_dir" ]; then
        log_pass "Cache directory exists"
        
        # Check cache files
        local cache_files=$(find "$cache_dir" -type f 2>/dev/null)
        if [ -n "$cache_files" ]; then
            log_pass "Cache files found"
            
            # Check cache file ages
            local old_files=0
            local total_files=0
            while IFS= read -r -d '' file; do
                ((total_files++))
                local file_age=$(($(date +%s) - $(stat -c %Y "$file" 2>/dev/null || echo "0")))
                local max_age=86400  # 24 hours
                
                if [ "$file_age" -gt "$max_age" ]; then
                    ((old_files++))
                fi
            done < <(find "$cache_dir" -type f -print0 2>/dev/null)
            
            if [ "$total_files" -gt 0 ]; then
                if [ "$old_files" -eq 0 ]; then
                    log_pass "All cache files are recent"
                else
                    log_warn "$old_files of $total_files cache files are old"
                fi
            fi
        else
            log_warn "No cache files found"
        fi
        
        # Test cache cleanup function
        if [ -f "$PROJECT_ROOT/scripts/threat-intelligence-v2.sh" ]; then
            source "$PROJECT_ROOT/scripts/threat-intelligence-v2.sh"
            
            if command -v cleanup_cache &> /dev/null; then
                if cleanup_cache 2>/dev/null; then
                    log_pass "Cache cleanup function works"
                else
                    log_fail "Cache cleanup function failed"
                fi
            else
                log_warn "Cache cleanup function not available"
            fi
        else
            log_fail "Threat intelligence script not available"
        fi
    else
        log_warn "Cache directory not found"
    fi
}

# Main test execution
main() {
    echo -e "${WHITE}========================================${NC}"
    echo -e "${WHITE}🛡️ THREAT INTELLIGENCE COMPONENT TESTS 🛡️${NC}"
    echo -e "${WHITE}========================================${NC}"
    echo -e "${BLUE}Test started: $(date)${NC}"
    echo ""
    
    # Run all tests
    test_script_availability
    test_ioc_database
    test_threat_feed_configuration
    test_ioc_types
    test_threat_feed_processing
    test_database_operations
    test_api_integration
    test_cache_management
    
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
        echo -e "${GREEN}🎉 ALL THREAT INTELLIGENCE TESTS PASSED!${NC}"
        exit 0
    else
        echo -e "${RED}⚠️ $TESTS_FAILED test(s) failed. Review issues above.${NC}"
        exit 1
    fi
}

# Run main function
main "$@"