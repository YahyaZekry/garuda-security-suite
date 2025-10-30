#!/usr/bin/env bats
# Comprehensive Unit Test Suite for Garuda Security Suite
# Following Phase 1 implementation plans (lines 1621-1731)

# Load test helpers
load "test-helper"

setup() {
    setup_test_environment
    mock_external_commands
}

teardown() {
    cleanup_test_environment
}

# Test path resolution for any user
@test "path resolution works for any user" {
    # Mock different users
    export USER="testuser"
    export HOME="/home/testuser"
    
    source "$SCRIPT_DIR/common-functions.sh"
    
    [ "$CURRENT_USER" = "testuser" ]
    [ "$CURRENT_HOME" = "/home/testuser" ]
    [ "$SECURITY_SUITE_HOME" = "/home/testuser/security-suite" ]
}

@test "path resolution works with environment variable override" {
    # Test with SECURITY_SUITE_HOME override
    export USER="testuser"
    export HOME="/home/testuser"
    export SECURITY_SUITE_HOME="/custom/security-suite"
    
    source "$SCRIPT_DIR/common-functions.sh"
    
    [ "$CURRENT_USER" = "testuser" ]
    [ "$CURRENT_HOME" = "/home/testuser" ]
    [ "$SECURITY_SUITE_HOME" = "/custom/security-suite" ]
}

# Test systemd service generation with dynamic paths
@test "systemd service generation uses dynamic paths" {
    export USER="testuser"
    export HOME="/home/testuser"
    
    source "$SCRIPT_DIR/common-functions.sh"
    
    run generate_systemd_service "test-service" "/home/testuser/security-suite/scripts/test.sh"
    
    [ "$status" -eq 0 ]
    [ -f "$HOME/.config/systemd/user/test-service.service" ]
    grep -q "ExecStart=/home/testuser/security-suite/scripts/test.sh" "$HOME/.config/systemd/user/test-service.service"
    grep -q "WorkingDirectory=/home/testuser/security-suite/scripts" "$HOME/.config/systemd/user/test-service.service"
    grep -q "Environment=USER=testuser" "$HOME/.config/systemd/user/test-service.service"
    grep -q "Environment=HOME=/home/testuser" "$HOME/.config/systemd/user/test-service.service"
}

@test "systemd service generation validates paths" {
    source "$SCRIPT_DIR/common-functions.sh"
    
    # Test with invalid path
    run generate_systemd_service "test-service" "relative/path/test.sh"
    
    [ "$status" -eq 1 ]
    [ ! -f "$HOME/.config/systemd/user/test-service.service" ]
}

@test "systemd service generation sets correct permissions" {
    source "$SCRIPT_DIR/common-functions.sh"
    
    generate_systemd_service "test-service" "/home/testuser/security-suite/scripts/test.sh"
    
    local service_file="$HOME/.config/systemd/user/test-service.service"
    [ "$(stat -c %a "$service_file")" = "644" ]
}

# Test security scanner functionality (EICAR detection)
@test "clamav scanner detects EICAR signature" {
    setup_test_environment
    
    # Create EICAR test file
    echo 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > "$TEST_DIR/eicar.com"
    
    source "$TEST_DIR/scripts/scanners/clamav-scanner.sh"
    
    run clamav_scan "$TEST_DIR"
    
    [ "$status" -eq 1 ]  # Should find EICAR and return non-zero
    [ -f "$LOGS_DIR/daily/clamav_*.log" ]
    grep -q "EICAR" "$LOGS_DIR/daily/clamav_*.log"
    grep -q "FOUND" "$LOGS_DIR/daily/clamav_*.log"
    
    cleanup_test_environment
}

@test "clamav scanner completes successfully with clean files" {
    setup_test_environment
    
    # Create clean test file
    echo "Clean file content" > "$TEST_DIR/clean.txt"
    
    source "$TEST_DIR/scripts/scanners/clamav-scanner.sh"
    
    run clamav_scan "$TEST_DIR"
    
    [ "$status" -eq 0 ]  # Should complete successfully
    [ -f "$LOGS_DIR/daily/clamav_*.log" ]
    grep -q "Infected Files: 0" "$LOGS_DIR/daily/clamav_*.log"
    
    cleanup_test_environment
}

@test "rkhunter scanner completes successfully" {
    setup_test_environment
    
    source "$TEST_DIR/scripts/scanners/rkhunter-scanner.sh"
    
    run rkhunter_scan
    
    [ "$status" -eq 0 ]
    [ -f "$LOGS_DIR/weekly/rkhunter_*.log" ]
    grep -q "Warnings: 0" "$LOGS_DIR/weekly/rkhunter_*.log"
    grep -q "Rootkits Found: 0" "$LOGS_DIR/weekly/rkhunter_*.log"
    
    cleanup_test_environment
}

# Test error handling and logging
@test "error handling logs and recovers properly" {
    setup_test_environment
    
    source "$TEST_DIR/scripts/common-functions.sh"
    
    # Test error logging
    run log_error "Test error message" 1
    
    [ "$status" -eq 0 ]
    
    # Test warning logging
    run log_warning "Test warning message"
    
    [ "$status" -eq 0 ]
    
    # Test info logging
    run log_info "Test info message"
    
    [ "$status" -eq 0 ]
    
    # Test success logging
    run log_success "Test success message"
    
    [ "$status" -eq 0 ]
    
    cleanup_test_environment
}

@test "logging functions use correct colors and formatting" {
    setup_test_environment
    
    source "$TEST_DIR/scripts/common-functions.sh"
    
    # Test that logging functions include proper formatting
    run log_info "Test message"
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ \[INFO\] ]]
    
    run log_warning "Test warning"
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ \[WARNING\] ]]
    
    run log_error "Test error"
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ \[ERROR\] ]]
    
    cleanup_test_environment
}

@test "notification system respects disabled state" {
    setup_test_environment
    
    source "$TEST_DIR/scripts/common-functions.sh"
    
    # Notifications should be disabled in test environment
    run send_notification "Test Title" "Test Message" "normal" "5000"
    
    [ "$status" -eq 0 ]
    [ "$output" = "" ]  # No output when disabled
    
    cleanup_test_environment
}

# Test sudo wrapper security (blocks dangerous commands)
@test "sudo wrapper blocks dangerous commands" {
    source "$SCRIPT_DIR/sudo-wrapper.sh"
    
    # Test valid commands
    run validate_sudo_command "freshclam --quiet"
    [ "$status" -eq 0 ]
    
    run validate_sudo_command "clamscan -r /home"
    [ "$status" -eq 0 ]
    
    run validate_sudo_command "rkhunter --update"
    [ "$status" -eq 0 ]
    
    run validate_sudo_command "loginctl enable-linger testuser"
    [ "$status" -eq 0 ]
    
    # Test invalid commands
    run validate_sudo_command "rm -rf /"
    [ "$status" -eq 1 ]
    
    run validate_sudo_command "dd if=/dev/zero of=/dev/sda"
    [ "$status" -eq 1 ]
    
    run validate_sudo_command "mkfs.ext4 /dev/sda1"
    [ "$status" -eq 1 ]
    
    run validate_sudo_command "pacman -S malicious-package"
    [ "$status" -eq 1 ]
}

@test "sudo wrapper validates command patterns" {
    source "$SCRIPT_DIR/sudo-wrapper.sh"
    
    # Test pattern validation for clamscan
    run validate_sudo_command "clamscan --recursive --detect-pua=yes /home"
    [ "$status" -eq 0 ]
    
    run validate_sudo_command "clamscan --invalid-option /home"
    [ "$status" -eq 1 ]
    
    # Test pattern validation for rkhunter
    run validate_sudo_command "rkhunter --check --skip-keypress"
    [ "$status" -eq 0 ]
    
    run validate_sudo_command "rkhunter --invalid-option"
    [ "$status" -eq 1 ]
}

@test "sudo wrapper audit logging works" {
    setup_test_environment
    
    export LOGS_DIR="$TEST_LOGS_DIR"
    source "$SCRIPT_DIR/sudo-wrapper.sh"
    init_sudo_audit
    
    # Execute sudo operation
    sudo_execute "echo 'test'" "Test operation"
    
    # Check audit log
    [ -f "$TEST_LOGS_DIR/audit/sudo_operations_*.log" ]
    grep -q "sudo echo 'test'" "$TEST_LOGS_DIR/audit/sudo_operations_*.log"
    grep -q "Test operation" "$TEST_LOGS_DIR/audit/sudo_operations_*.log"
    
    cleanup_test_environment
}

# Test input validation (blocks malicious input)
@test "input validation blocks malicious input" {
    source "$SCRIPT_DIR/input-validation.sh"
    
    # Test valid inputs
    run validate_security_input "testuser" "username" "Username"
    [ "$status" -eq 0 ]
    
    run validate_security_input "/home/user" "directory" "Directory"
    [ "$status" -eq 0 ]
    
    run validate_security_input "09:30" "time" "Time"
    [ "$status" -eq 0 ]
    
    run validate_security_input "user@example.com" "email" "Email"
    [ "$status" -eq 0 ]
    
    # Test malicious inputs
    run validate_security_input "user;rm -rf /" "username" "Username"
    [ "$status" -eq 1 ]
    
    run validate_security_input "../../../etc" "directory" "Directory"
    [ "$status" -eq 1 ]
    
    run validate_security_input "25:00" "time" "Time"
    [ "$status" -eq 1 ]
    
    run validate_security_input "invalid-email" "email" "Email"
    [ "$status" -eq 1 ]
}

@test "input validation sanitizes dangerous patterns" {
    source "$SCRIPT_DIR/input-validation.sh"
    
    # Test directory traversal detection
    run check_dangerous_patterns "/path/../../../etc/passwd"
    [ "$status" -eq 1 ]
    
    # Test command injection detection
    run check_dangerous_patterns "filename;rm -rf /"
    [ "$status" -eq 1 ]
    
    run check_dangerous_patterns "input && dd if=/dev/zero"
    [ "$status" -eq 1 ]
    
    run check_dangerous_patterns "input | rm -rf /"
    [ "$status" -eq 1 ]
    
    run check_dangerous_patterns "input \$(rm -rf /)"
    [ "$status" -eq 1 ]
}

@test "input validation handles edge cases" {
    source "$SCRIPT_DIR/input-validation.sh"
    
    # Test empty input
    run validate_security_input "" "username" "Username" false
    [ "$status" -eq 0 ]  # Should pass when not required
    
    run validate_security_input "" "username" "Username" true
    [ "$status" -eq 1 ]  # Should fail when required
    
    # Test null bytes
    run sanitize_input $'input\0malicious' "text"
    [ "$status" -eq 0 ]
    [[ ! "$output" =~ $'\0' ]]
    
    # Test control characters
    run sanitize_input $'input\x01\x02\x03' "text"
    [ "$status" -eq 0 ]
    [[ ! "$output" =~ $'\x01' ]]
}

@test "path validation prevents dangerous paths" {
    source "$SCRIPT_DIR/common-functions.sh"
    
    # Test valid paths
    run validate_path "/home/user/documents" "Test path"
    [ "$status" -eq 0 ]
    
    run validate_path "/tmp/test" "Test path"
    [ "$status" -eq 0 ]
    
    # Test invalid paths
    run validate_path "relative/path" "Test path"
    [ "$status" -eq 1 ]
    
    run validate_path "/path/../../../etc/passwd" "Test path"
    [ "$status" -eq 1 ]
    
    run validate_path "/etc/passwd" "Test path"
    [ "$status" -eq 1 ]
    
    run validate_path "/boot/grub" "Test path"
    [ "$status" -eq 1 ]
}

@test "configuration validation works correctly" {
    setup_test_environment
    
    source "$SCRIPT_DIR/input-validation.sh"
    
    # Test valid configuration
    run validate_security_config "$TEST_CONFIG_DIR/security-config.conf"
    [ "$status" -eq 0 ]
    
    # Test with invalid configuration
    cat > "$TEST_CONFIG_DIR/invalid-config.conf" << EOF
DAILY_SCAN_DIRS=("../../../etc" "/home")
DAILY_TIME="25:00"
WEEKLY_DAY="InvalidDay"
EOF
    
    run validate_security_config "$TEST_CONFIG_DIR/invalid-config.conf"
    [ "$status" -eq 1 ]
    
    cleanup_test_environment
}

@test "resource monitoring functions work" {
    setup_test_environment
    
    source "$TEST_DIR/scripts/common-functions.sh"
    
    # Test disk space check
    run check_disk_space 100 "$TEST_DIR"
    [ "$status" -eq 0 ]
    
    # Test memory check
    run check_memory_usage 90
    [ "$status" -eq 0 ]  # Should pass unless system is under heavy load
    
    cleanup_test_environment
}

@test "command execution with retry works" {
    setup_test_environment
    
    source "$TEST_DIR/scripts/common-functions.sh"
    
    # Test successful command
    run execute_command "echo 'test'" "Test command" "Command failed" 3 1
    [ "$status" -eq 0 ]
    
    # Test failing command
    run execute_command "false" "Failing command" "Command should fail" 2 1
    [ "$status" -eq 1 ]
    
    cleanup_test_environment
}