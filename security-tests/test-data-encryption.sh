#!/bin/bash
# Data Encryption and Storage Security Tests
# Tests data encryption, secure storage, and data protection mechanisms

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

# Test 1: Database Encryption
test_database_encryption() {
    log_test "Testing Database Encryption"
    
    local databases=(
        "$AEGIS_HOME/configs/behavioral_analysis/behavioral_data.db"
        "$AEGIS_HOME/configs/threat_intelligence/ioc_database.db"
        "$AEGIS_HOME/configs/incident_response/incidents.db"
    )
    
    for db in "${databases[@]}"; do
        if [ -f "$db" ]; then
            local db_name=$(basename "$db")
            
            # Check if database file is encrypted (basic check)
            local file_header=$(head -c 16 "$db" 2>/dev/null | xxd -p 2>/dev/null || echo "")
            
            if [ -n "$file_header" ]; then
                # SQLite databases have a specific header
                if echo "$file_header" | grep -qi "53514c69746520666f726d6174"; then
                    log_warn "$db_name appears to be standard SQLite (not encrypted)"
                else
                    log_pass "$db_name may be encrypted or using non-standard format"
                fi
            fi
            
            # Check for encryption configuration
            if [ -f "$PROJECT_ROOT/web-dashboard/app.py" ]; then
                if grep -q "encrypt\|cipher\|AES\|SQLCipher" "$PROJECT_ROOT/web-dashboard/app.py" 2>/dev/null; then
                    log_pass "Database encryption configuration found in app.py"
                else
                    log_warn "Database encryption configuration not found in app.py"
                fi
            fi
            
            # Test database content accessibility
            if command -v sqlite3 &> /dev/null; then
                if sqlite3 "$db" "SELECT COUNT(*) FROM sqlite_master;" 2>/dev/null >/dev/null; then
                    log_warn "$db_name is readable without encryption keys"
                else
                    log_pass "$db_name requires encryption keys or is encrypted"
                fi
            fi
        else
            log_warn "Database not found: $(basename "$db")"
        fi
    done
}

# Test 2: Password Storage Security
test_password_storage_security() {
    log_test "Testing Password Storage Security"
    
    # Check for plaintext passwords
    local config_files=(
        "$PROJECT_ROOT/configs/security-config.conf"
        "$PROJECT_ROOT/web-dashboard/config/dashboard.conf"
        "$PROJECT_ROOT/web-dashboard/app.py"
    )
    
    for config_file in "${config_files[@]}"; do
        if [ -f "$config_file" ]; then
            local filename=$(basename "$config_file")
            
            # Check for plaintext passwords
            if grep -i -E "(password|passwd|pwd).*=.*[^*]" "$config_file" 2>/dev/null; then
                log_fail "Possible plaintext password found in $filename"
            else
                log_pass "No plaintext passwords found in $filename"
            fi
            
            # Check for hashed passwords
            if grep -i -E "(password|passwd|pwd).*=.*\$[a-zA-Z0-9/.+]" "$config_file" 2>/dev/null; then
                log_pass "Hashed passwords found in $filename"
            else
                log_warn "No hashed passwords found in $filename"
            fi
            
            # Check for password hashing algorithms
            if grep -qi "bcrypt\|scrypt\|argon2\|pbkdf2" "$config_file" 2>/dev/null; then
                log_pass "Strong password hashing algorithm found in $filename"
            elif grep -qi "sha256\|sha512\|md5" "$config_file" 2>/dev/null; then
                log_warn "Weak password hashing algorithm found in $filename"
            else
                log_info "No password hashing algorithm found in $filename"
            fi
        fi
    done
}

# Test 3: Sensitive Data Protection
test_sensitive_data_protection() {
    log_test "Testing Sensitive Data Protection"
    
    # Check for sensitive data in logs
    local log_dirs=(
        "$AEGIS_HOME/logs/error"
        "$AEGIS_HOME/logs/manual"
        "$AEGIS_HOME/logs/behavioral"
    )
    
    for log_dir in "${log_dirs[@]}"; do
        if [ -d "$log_dir" ]; then
            local sensitive_found=false
            
            while IFS= read -r -d '' log_file; do
                # Check for sensitive data patterns
                if grep -i -E "(password|token|key|secret|credential)" "$log_file" 2>/dev/null; then
                    log_fail "Sensitive data found in log file: $(basename "$log_file")"
                    sensitive_found=true
                fi
                
                # Check for PII patterns
                if grep -i -E "(email|phone|ssn|credit.*card|social.*security)" "$log_file" 2>/dev/null; then
                    log_fail "PII data found in log file: $(basename "$log_file")"
                    sensitive_found=true
                fi
            done < <(find "$log_dir" -name "*.log" -type f -print0 2>/dev/null)
            
            if [ "$sensitive_found" = false ]; then
                log_pass "No sensitive data found in $(basename "$log_dir") logs"
            fi
        fi
    done
    
    # Check for sensitive data in configuration files
    local config_patterns=(
        "api_key"
        "secret_key"
        "database_password"
        "encryption_key"
        "private_key"
    )
    
    for pattern in "${config_patterns[@]}"; do
        if grep -r -i "$pattern" "$PROJECT_ROOT/configs/" 2>/dev/null | grep -v "encrypted\|hashed\|*****"; then
            log_fail "Unprotected sensitive configuration found: $pattern"
        else
            log_pass "Sensitive configuration properly protected: $pattern"
        fi
    done
}

# Test 4: File System Permissions
test_file_system_permissions() {
    log_test "Testing File System Permissions"
    
    # Check critical file permissions
    local critical_files=(
        "$PROJECT_ROOT/configs/security-config.conf"
        "$AEGIS_HOME/configs/behavioral_analysis/behavioral_data.db"
        "$AEGIS_HOME/configs/threat_intelligence/ioc_database.db"
        "$AEGIS_HOME/configs/incident_response/incidents.db"
        "$PROJECT_ROOT/web-dashboard/app.py"
    )
    
    for file in "${critical_files[@]}"; do
        if [ -f "$file" ]; then
            local filename=$(basename "$file")
            local permissions=$(stat -c "%a" "$file" 2>/dev/null || echo "000")
            local owner=$(stat -c "%U" "$file" 2>/dev/null || echo "unknown")
            
            log_info "$filename - Permissions: $permissions, Owner: $owner"
            
            # Check if file is world-readable
            if [[ "$permissions" =~ .*[4-7].*[4-7] ]]; then
                log_fail "$filename is world-readable (security risk)"
            else
                log_pass "$filename is not world-readable"
            fi
            
            # Check if file is world-writable
            if [[ "$permissions" =~ .*[2-7].[2-7] ]]; then
                log_fail "$filename is world-writable (security risk)"
            else
                log_pass "$filename is not world-writable"
            fi
            
            # Check if file is owned by root (if applicable)
            if [ "$owner" = "root" ]; then
                log_pass "$filename is owned by root"
            else
                log_info "$filename is owned by $owner (may be acceptable)"
            fi
        fi
    done
    
    # Check directory permissions
    local critical_dirs=(
        "$AEGIS_HOME/configs"
        "$AEGIS_HOME/logs"
        "$AEGIS_HOME/evidence"
        "$AEGIS_HOME/quarantine"
    )
    
    for dir in "${critical_dirs[@]}"; do
        if [ -d "$dir" ]; then
            local dirname=$(basename "$dir")
            local permissions=$(stat -c "%a" "$dir" 2>/dev/null || echo "000")
            
            log_info "$dirname directory - Permissions: $permissions"
            
            # Check directory permissions
            if [[ "$permissions" =~ .*[4-7].*[4-7] ]]; then
                log_fail "$dirname directory is world-readable"
            else
                log_pass "$dirname directory is not world-readable"
            fi
        fi
    done
}

# Test 5: Data Backup Security
test_data_backup_security() {
    log_test "Testing Data Backup Security"
    
    # Check for backup files
    local backup_patterns=(
        "*.backup"
        "*.bak"
        "*.old"
        "*~"
        "*.sql"
        "*.dump"
    )
    
    local backups_found=false
    for pattern in "${backup_patterns[@]}"; do
        local backups=$(find "$AEGIS_HOME" -name "$pattern" -type f 2>/dev/null || true)
        
        if [ -n "$backups" ]; then
            backups_found=true
            log_info "Backup files found: $backups"
            
            # Check backup file permissions
            while IFS= read -r backup_file; do
                local permissions=$(stat -c "%a" "$backup_file" 2>/dev/null || echo "000")
                
                if [[ "$permissions" =~ .*[4-7].*[4-7] ]]; then
                    log_fail "Backup file is world-readable: $(basename "$backup_file")"
                else
                    log_pass "Backup file permissions are secure: $(basename "$backup_file")"
                fi
            done <<< "$backups"
        fi
    done
    
    if [ "$backups_found" = false ]; then
        log_info "No backup files found (may be acceptable)"
    fi
    
    # Check for backup encryption
    if [ -f "$PROJECT_ROOT/scripts/backup.sh" ] 2>/dev/null; then
        if grep -qi "encrypt\|gpg\|openssl\|cipher" "$PROJECT_ROOT/scripts/backup.sh" 2>/dev/null; then
            log_pass "Backup script includes encryption"
        else
            log_warn "Backup script may not include encryption"
        fi
    fi
}

# Test 6: Session Data Security
test_session_data_security() {
    log_test "Testing Session Data Security"
    
    # Check session storage location
    local session_locations=(
        "/tmp"
        "/var/tmp"
        "$AEGIS_HOME/sessions"
        "$HOME/.local/share/aegis-sessions"
    )
    
    for location in "${session_locations[@]}"; do
        if [ -d "$location" ]; then
            local session_files=$(find "$location" -name "*session*" -o -name "*cookie*" 2>/dev/null || true)
            
            if [ -n "$session_files" ]; then
                log_info "Session files found in $location"
                
                # Check session file permissions
                while IFS= read -r session_file; do
                    local permissions=$(stat -c "%a" "$session_file" 2>/dev/null || echo "000")
                    
                    if [[ "$permissions" =~ .*[4-7].*[4-7] ]]; then
                        log_fail "Session file is world-readable: $(basename "$session_file")"
                    else
                        log_pass "Session file permissions are secure: $(basename "$session_file")"
                    fi
                    
                    # Check for session data encryption
                    if file "$session_file" 2>/dev/null | grep -q "encrypted\|data"; then
                        log_pass "Session data appears to be encrypted: $(basename "$session_file")"
                    else
                        log_warn "Session data may not be encrypted: $(basename "$session_file")"
                    fi
                done <<< "$session_files"
            fi
        fi
    done
    
    # Check session configuration in web dashboard
    if [ -f "$PROJECT_ROOT/web-dashboard/app.py" ]; then
        if grep -qi "session\|cookie.*secure\|httponly" "$PROJECT_ROOT/web-dashboard/app.py" 2>/dev/null; then
            log_pass "Session security configuration found"
        else
            log_warn "Session security configuration may be missing"
        fi
    fi
}

# Test 7: API Key and Token Security
test_api_key_token_security() {
    log_test "Testing API Key and Token Security"
    
    # Check for hardcoded API keys
    local api_patterns=(
        "api_key"
        "secret_key"
        "access_token"
        "jwt_secret"
        "encryption_key"
    )
    
    for pattern in "${api_patterns[@]}"; do
        local matches=$(grep -r -i "$pattern" "$PROJECT_ROOT" --include="*.py" --include="*.sh" --include="*.conf" 2>/dev/null || true)
        
        if [ -n "$matches" ]; then
            log_info "API key pattern found: $pattern"
            
            # Check if keys are hardcoded
            if echo "$matches" | grep -v "encrypted\|hashed\|environment\|config\|getenv"; then
                log_fail "Possible hardcoded API key found for pattern: $pattern"
            else
                log_pass "API key pattern properly handled: $pattern"
            fi
        else
            log_info "API key pattern not found: $pattern"
        fi
    done
    
    # Check for JWT token security
    if [ -f "$PROJECT_ROOT/web-dashboard/app.py" ]; then
        if grep -qi "jwt\|jsonwebtoken\|token" "$PROJECT_ROOT/web-dashboard/app.py" 2>/dev/null; then
            if grep -qi "hs256\|rs256\|algorithm" "$PROJECT_ROOT/web-dashboard/app.py" 2>/dev/null; then
                log_pass "JWT algorithm configuration found"
            else
                log_warn "JWT algorithm configuration may be missing"
            fi
            
            if grep -qi "expire\|exp\|ttl\|timeout" "$PROJECT_ROOT/web-dashboard/app.py" 2>/dev/null; then
                log_pass "JWT expiration configuration found"
            else
                log_warn "JWT expiration configuration may be missing"
            fi
        else
            log_info "JWT token implementation not found"
        fi
    fi
}

# Test 8: Evidence and Quarantine Security
test_evidence_quarantine_security() {
    log_test "Testing Evidence and Quarantine Security"
    
    # Check evidence directory security
    if [ -d "$AEGIS_HOME/evidence" ]; then
        local evidence_perms=$(stat -c "%a" "$AEGIS_HOME/evidence" 2>/dev/null || echo "000")
        log_info "Evidence directory permissions: $evidence_perms"
        
        if [[ "$evidence_perms" =~ .*[4-7].*[4-7] ]]; then
            log_fail "Evidence directory is world-readable"
        else
            log_pass "Evidence directory permissions are secure"
        fi
        
        # Check evidence file integrity
        local evidence_files=$(find "$AEGIS_HOME/evidence" -type f 2>/dev/null || true)
        
        if [ -n "$evidence_files" ]; then
            local tampered_files=0
            local total_files=0
            
            while IFS= read -r evidence_file; do
                ((total_files++))
                
                # Check for file modification (basic integrity check)
                local file_age=$(($(date +%s) - $(stat -c %Y "$evidence_file" 2>/dev/null || echo "0")))
                
                # If evidence file is very recent, it might be actively being written to
                if [ "$file_age" -lt 300 ]; then
                    continue
                fi
                
                # Check for file checksum (if available)
                if command -v sha256sum &> /dev/null; then
                    local checksum_file="${evidence_file}.sha256"
                    if [ -f "$checksum_file" ]; then
                        local stored_checksum=$(cat "$checksum_file" 2>/dev/null || echo "")
                        local current_checksum=$(sha256sum "$evidence_file" 2>/dev/null | cut -d' ' -f1 || echo "")
                        
                        if [ "$stored_checksum" != "$current_checksum" ]; then
                            log_fail "Evidence file may be tampered: $(basename "$evidence_file")"
                            ((tampered_files++))
                        fi
                    fi
                fi
            done <<< "$evidence_files"
            
            if [ "$tampered_files" -eq 0 ]; then
                log_pass "Evidence files appear to be intact"
            fi
        fi
    fi
    
    # Check quarantine directory security
    if [ -d "$AEGIS_HOME/quarantine" ]; then
        local quarantine_perms=$(stat -c "%a" "$AEGIS_HOME/quarantine" 2>/dev/null || echo "000")
        log_info "Quarantine directory permissions: $quarantine_perms"
        
        if [[ "$quarantine_perms" =~ .*[4-7].*[4-7] ]]; then
            log_fail "Quarantine directory is world-readable"
        else
            log_pass "Quarantine directory permissions are secure"
        fi
        
        # Check quarantine file access
        local quarantine_files=$(find "$AEGIS_HOME/quarantine" -type f 2>/dev/null || true)
        
        if [ -n "$quarantine_files" ]; then
            while IFS= read -r quarantine_file; do
                local file_perms=$(stat -c "%a" "$quarantine_file" 2>/dev/null || echo "000")
                
                if [[ "$file_perms" =~ .*[4-7].*[4-7] ]]; then
                    log_fail "Quarantine file is world-readable: $(basename "$quarantine_file")"
                else
                    log_pass "Quarantine file permissions are secure: $(basename "$quarantine_file")"
                fi
            done <<< "$quarantine_files"
        fi
    fi
}

# Test 9: Log File Security
test_log_file_security() {
    log_test "Testing Log File Security"
    
    local log_dirs=(
        "$AEGIS_HOME/logs/error"
        "$AEGIS_HOME/logs/manual"
        "$AEGIS_HOME/logs/behavioral"
    )
    
    for log_dir in "${log_dirs[@]}"; do
        if [ -d "$log_dir" ]; then
            local log_files=$(find "$log_dir" -name "*.log" -type f 2>/dev/null || true)
            
            if [ -n "$log_files" ]; then
                while IFS= read -r log_file; do
                    local filename=$(basename "$log_file")
                    local file_perms=$(stat -c "%a" "$log_file" 2>/dev/null || echo "000")
                    
                    log_info "Log file $filename - Permissions: $file_perms"
                    
                    # Check log file permissions
                    if [[ "$file_perms" =~ .*[4-7].*[4-7] ]]; then
                        log_fail "Log file is world-readable: $filename"
                    else
                        log_pass "Log file permissions are secure: $filename"
                    fi
                    
                    # Check for log rotation
                    local file_size=$(stat -c%s "$log_file" 2>/dev/null || echo "0")
                    local file_size_mb=$(echo "scale=2; $file_size / 1024 / 1024" | bc -l 2>/dev/null || echo "0")
                    
                    if (( $(echo "$file_size_mb > 100" | bc -l 2>/dev/null || echo "1") )); then
                        log_warn "Log file is large: $filename (${file_size_mb}MB)"
                    else
                        log_pass "Log file size is reasonable: $filename (${file_size_mb}MB)"
                    fi
                done <<< "$log_files"
            fi
        fi
    done
}

# Test 10: Configuration File Security
test_configuration_file_security() {
    log_test "Testing Configuration File Security"
    
    local config_files=(
        "$PROJECT_ROOT/configs/security-config.conf"
        "$PROJECT_ROOT/web-dashboard/config/dashboard.conf"
        "$PROJECT_ROOT/web-dashboard/app.py"
    )
    
    for config_file in "${config_files[@]}"; do
        if [ -f "$config_file" ]; then
            local filename=$(basename "$config_file")
            local file_perms=$(stat -c "%a" "$config_file" 2>/dev/null || echo "000")
            
            log_info "Config file $filename - Permissions: $file_perms"
            
            # Check configuration file permissions
            if [[ "$file_perms" =~ .*[4-7].*[4-7] ]]; then
                log_fail "Configuration file is world-readable: $filename"
            else
                log_pass "Configuration file permissions are secure: $filename"
            fi
            
            # Check for sensitive data exposure
            if grep -i -E "(password|key|secret|token).*=.*[^*#]" "$config_file" 2>/dev/null; then
                log_fail "Sensitive data exposed in configuration: $filename"
            else
                log_pass "No sensitive data exposure in configuration: $filename"
            fi
            
            # Check for configuration validation
            if grep -q "validate\|verify\|check" "$config_file" 2>/dev/null; then
                log_pass "Configuration validation found in: $filename"
            else
                log_warn "Configuration validation may be missing in: $filename"
            fi
        fi
    done
}

# Main test execution
main() {
    echo -e "${WHITE}========================================${NC}"
    echo -e "${WHITE}🔐 DATA ENCRYPTION AND STORAGE SECURITY TESTS 🔐${NC}"
    echo -e "${WHITE}========================================${NC}"
    echo -e "${BLUE}Test started: $(date)${NC}"
    echo ""
    
    # Run all tests
    test_database_encryption
    test_password_storage_security
    test_sensitive_data_protection
    test_file_system_permissions
    test_data_backup_security
    test_session_data_security
    test_api_key_token_security
    test_evidence_quarantine_security
    test_log_file_security
    test_configuration_file_security
    
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
        echo -e "${GREEN}🎉 ALL DATA ENCRYPTION TESTS PASSED!${NC}"
        exit 0
    else
        echo -e "${RED}⚠️ $TESTS_FAILED test(s) failed. Review issues above.${NC}"
        exit 1
    fi
}

# Run main function
main "$@"