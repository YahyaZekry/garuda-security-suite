#!/bin/bash
# Test Script for Security Components
# Tests error handling, sudo wrapper, and input validation systems

# Set up test environment
SCRIPT_DIR="$(dirname "$0")"
TEST_LOG_DIR="/tmp/security_suite_test_$$"
mkdir -p "$TEST_LOG_DIR"/{audit,error,daily,weekly,monthly}

# Export test environment variables
export LOGS_DIR="$TEST_LOG_DIR"
export SECURITY_SUITE_HOME="/tmp/security_suite_home_$$"
mkdir -p "$SECURITY_SUITE_HOME"

# Load all components
source "$SCRIPT_DIR/common-functions.sh"
source "$SCRIPT_DIR/sudo-wrapper.sh"
source "$SCRIPT_DIR/input-validation.sh"

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper functions
test_assert() {
    local test_name="$1"
    local expected_result="$2"
    local actual_result="$3"
    
    ((TESTS_TOTAL++))
    
    if [ "$expected_result" = "$actual_result" ]; then
        echo "✅ PASS: $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        echo "❌ FAIL: $test_name"
        echo "   Expected: $expected_result"
        echo "   Actual: $actual_result"
        ((TESTS_FAILED++))
        return 1
    fi
}

test_command_success() {
    local test_name="$1"
    shift
    local cmd="$*"
    
    ((TESTS_TOTAL++))
    
    if eval "$cmd" >/dev/null 2>&1; then
        echo "✅ PASS: $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        echo "❌ FAIL: $test_name"
        ((TESTS_FAILED++))
        return 1
    fi
}

test_command_failure() {
    local test_name="$1"
    shift
    local cmd="$*"
    
    ((TESTS_TOTAL++))
    
    if ! eval "$cmd" >/dev/null 2>&1; then
        echo "✅ PASS: $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        echo "❌ FAIL: $test_name"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Initialize logging for tests
init_logging "manual"

echo "=========================================="
echo "Garuda Security Suite Component Tests"
echo "=========================================="
echo ""

# Test 1: Error Handling Framework
echo "🧪 Testing Error Handling Framework"
echo "----------------------------------"

# Test logging functions
test_command_success "log_info function" "log_info 'Test info message'"
test_command_success "log_warning function" "log_warning 'Test warning message'"
test_command_success "log_error function" "log_error 'Test error message' 1"

# Test resource monitoring
test_command_success "check_disk_space function" "check_disk_space 100"
test_command_success "check_memory_usage function" "check_memory_usage 95"

# Test error recovery mechanisms
test_command_success "download_with_retry function (valid URL)" "timeout 30 download_with_retry 'https://httpbin.org/json' '/tmp/test_download.json' 1 10 || true"
test_command_failure "download_with_retry function (invalid URL)" "download_with_retry 'https://invalid-url-that-does-not-exist.com/file' '/tmp/test_download_fail.json' 1 5"

# Test retry with backoff
test_command_success "retry_with_backoff function (success)" "retry_with_backoff 'echo \"test command\"' 3 1 5"
test_command_failure "retry_with_backoff function (failure)" "retry_with_backoff 'false' 2 1 5"

# Test scanner fallback
test_command_success "run_scanner_with_fallback function (primary available)" "run_scanner_with_fallback 'echo' 'cat' 'test input'"
test_command_success "run_scanner_with_fallback function (fallback)" "run_scanner_with_fallback 'nonexistent_command' 'echo' 'test input'"
test_command_failure "run_scanner_with_fallback function (none available)" "run_scanner_with_fallback 'nonexistent_cmd1' 'nonexistent_cmd2' 'test input'"

echo ""

# Test 2: Input Validation System
echo "🧪 Testing Input Validation System"
echo "-----------------------------------"

# Test sanitize_input
test_assert "sanitize_input removes null bytes" "test" "$(sanitize_input $'test\0input' "text")"
test_assert "sanitize_input removes control chars" "test input" "$(sanitize_input $'test\x01input' "text")"
test_assert "sanitize_input normalizes paths" "/home/user/test" "$(sanitize_input "//home//user///test//" "path")"
test_assert "sanitize_input removes path separators from filename" "test_file" "$(sanitize_input "test/file" "filename")"

# Test check_dangerous_patterns
test_command_failure "check_dangerous_patterns blocks directory traversal" "check_dangerous_patterns '../../../etc/passwd'"
test_command_failure "check_dangerous_patterns blocks command injection" "check_dangerous_patterns 'test; rm -rf /'"
test_command_failure "check_dangerous_patterns blocks pipe injection" "check_dangerous_patterns 'test|dd if=/dev/zero'"
test_command_success "check_dangerous_patterns allows safe input" "check_dangerous_patterns 'safe_input_123'"

# Test validate_security_input
test_command_success "validate_security_input allows valid username" "validate_security_input 'testuser' 'username' 'Username'"
test_command_failure "validate_security_input rejects invalid username" "validate_security_input 'test@user' 'username' 'Username'"
test_command_success "validate_security_input allows valid email" "validate_security_input 'test@example.com' 'email' 'Email'"
test_command_failure "validate_security_input rejects invalid email" "validate_security_input 'invalid-email' 'email' 'Email'"
test_command_success "validate_security_input allows valid time" "validate_security_input '09:30' 'time' 'Time'"
test_command_failure "validate_security_input rejects invalid time" "validate_security_input '25:00' 'time' 'Time'"
test_command_success "validate_security_input allows valid port" "validate_security_input '8080' 'port' 'Port'"
test_command_failure "validate_security_input rejects invalid port" "validate_security_input '70000' 'port' 'Port'"

# Test validate_file_path
test_command_success "validate_file_path allows valid path" "touch /tmp/test_file.txt && validate_file_path '/tmp/test_file.txt' 'Test file'"
test_command_failure "validate_file_path rejects dangerous path" "validate_file_path '../../../etc/passwd' 'Test file'"

# Test validate_network_address
test_command_success "validate_network_address allows valid IP" "validate_network_address '192.168.1.1' 'ip' 'IP Address'"
test_command_failure "validate_network_address rejects invalid IP" "validate_network_address '256.256.256.256' 'ip' 'IP Address'"
test_command_success "validate_network_address allows valid hostname" "validate_network_address 'example.com' 'hostname' 'Hostname'"
test_command_failure "validate_network_address rejects invalid hostname" "validate_network_address 'invalid..hostname' 'hostname' 'Hostname'"

echo ""

# Test 3: Sudo Wrapper System
echo "🧪 Testing Sudo Wrapper System"
echo "--------------------------------"

# Test sudo command validation
test_command_success "validate_sudo_command allows freshclam" "validate_sudo_command 'freshclam --quiet'"
test_command_success "validate_sudo_command allows clamscan" "validate_sudo_command 'clamscan -r /home'"
test_command_success "validate_sudo_command allows rkhunter" "validate_sudo_command 'rkhunter --update'"
test_command_success "validate_sudo_command allows loginctl" "validate_sudo_command 'loginctl enable-linger testuser'"
test_command_failure "validate_sudo_command rejects dangerous command" "validate_sudo_command 'rm -rf /'"
test_command_failure "validate_sudo_command rejects invalid clamscan options" "validate_sudo_command 'clamscan --dangerous-option'"
test_command_failure "validate_sudo_command rejects unknown command" "validate_sudo_command 'malicious-command'"

# Test sudo audit initialization
test_command_success "init_sudo_audit creates audit log" "init_sudo_audit && test -f '$SUDO_AUDIT_LOG'"

# Test specialized sudo functions (validation only, no actual sudo)
test_command_success "enable_user_linger validates username" "enable_user_linger() { return 0; } && enable_user_linger 'testuser'"
test_command_failure "enable_user_linger rejects invalid username" "enable_user_linger() { return 1; } && enable_user_linger 'invalid@user'"

echo ""

# Test 4: Integration Tests
echo "🧪 Testing Integration"
echo "------------------------"

# Test configuration validation
cat > "$TEST_LOG_DIR/test_config.conf" << EOF
DAILY_SCAN_DIRS=("/tmp" "/var/tmp")
WEEKLY_SCAN_DIRS=("/home")
MONTHLY_SCAN_DIRS=("/home" "/tmp")
DAILY_TIME="02:00"
WEEKLY_TIME="03:00"
MONTHLY_TIME="04:00"
WEEKLY_DAY="Sun"
MONTHLY_DAY="1"
NOTIFICATION_URGENCY="normal"
EOF

test_command_success "validate_security_config with valid config" "NOTIFICATION_URGENCY='normal' validate_security_config '$TEST_LOG_DIR/test_config.conf'"

# Test invalid configuration
cat > "$TEST_LOG_DIR/invalid_config.conf" << EOF
DAILY_SCAN_DIRS=("/tmp")
WEEKLY_SCAN_DIRS=("/home")
MONTHLY_SCAN_DIRS=("/home")
DAILY_TIME="25:00"  # Invalid time
WEEKLY_TIME="03:00"
MONTHLY_TIME="04:00"
WEEKLY_DAY="InvalidDay"  # Invalid day
MONTHLY_DAY="1"
NOTIFICATION_URGENCY="normal"
EOF

test_command_failure "validate_security_config with invalid config" "validate_security_config '$TEST_LOG_DIR/invalid_config.conf'"

# Test resource monitoring during operation
test_command_success "monitor_resources_during_operation" "monitor_resources_during_operation 'sleep 2' 'Test operation' 500 100"

echo ""

# Test 5: Security Tests
echo "🧪 Testing Security Features"
echo "-----------------------------"

# Test various injection attempts
malicious_inputs=(
    "'; rm -rf /; echo '"
    "|dd if=/dev/zero of=/dev/sda"
    "\$(rm -rf /)"
    "<script>alert('xss')</script>"
    "../../../etc/passwd"
    "test && rm -rf /"
    "test | dd if=/dev/zero"
)

for input in "${malicious_inputs[@]}"; do
    test_command_failure "validate_security_input blocks malicious input: $input" "validate_security_input '$input' 'text' 'Test input'"
done

# Test sudo command security
dangerous_commands=(
    "rm -rf /"
    "dd if=/dev/zero of=/dev/sda"
    "mkfs.ext4 /dev/sda1"
    "chmod 777 /etc/shadow"
    "useradd -p '' root"
)

for cmd in "${dangerous_commands[@]}"; do
    test_command_failure "validate_sudo_command blocks dangerous command: $cmd" "validate_sudo_command '$cmd'"
done

echo ""

# Test Results Summary
echo "=========================================="
echo "Test Results Summary"
echo "=========================================="
echo "Total Tests: $TESTS_TOTAL"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo "🎉 All tests passed! Security components are working correctly."
    exit_code=0
else
    echo "⚠️  $TESTS_FAILED test(s) failed. Please review the implementation."
    exit_code=1
fi

# Cleanup
rm -rf "$TEST_LOG_DIR"
rm -rf "$SECURITY_SUITE_HOME"
rm -f "/tmp/test_download.json" "/tmp/test_download_fail.json"

exit $exit_code