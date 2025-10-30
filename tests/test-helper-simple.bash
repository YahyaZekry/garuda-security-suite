#!/usr/bin/env bash
# Simple Test Helper for Garuda Security Suite

# Global test variables
export TEST_DIR="/tmp/garuda-security-test"
export TEST_LOGS_DIR="$TEST_DIR/logs"
export TEST_CONFIG_DIR="$TEST_DIR/configs"
export SCRIPT_DIR="$(dirname "$0")/.."
export ORIGINAL_HOME="$HOME"

# Test environment setup
setup_test_environment() {
    mkdir -p "$TEST_DIR"
    mkdir -p "$TEST_LOGS_DIR"/{daily,weekly,monthly,manual,error,audit}
    mkdir -p "$TEST_CONFIG_DIR"
    mkdir -p "$TEST_DIR/scripts/scanners"
    
    export SECURITY_SUITE_HOME="$TEST_DIR"
    export LOGS_DIR="$TEST_LOGS_DIR"
    export CONFIGS_DIR="$TEST_CONFIG_DIR"
    export CURRENT_USER="testuser"
    export CURRENT_HOME="$TEST_DIR"
    export NOTIFICATIONS_ENABLED=false
}

# Test environment cleanup
cleanup_test_environment() {
    export HOME="$ORIGINAL_HOME"
    if [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
}

# Mock external commands for testing
mock_external_commands() {
    local mock_bin="$TEST_DIR/bin"
    mkdir -p "$mock_bin"
    export PATH="$mock_bin:$PATH"
    
    # Mock clamscan
    cat > "$mock_bin/clamscan" << 'EOF'
#!/bin/bash
# Mock clamscan command
for arg in "$@"; do
    if [ -f "$arg" ] && grep -q "EICAR" "$arg"; then
        echo "$arg: Eicar-Test-Signature FOUND"
        exit 1
    fi
done
echo "Mock scan completed"
exit 0
EOF
    
    # Mock rkhunter
    cat > "$mock_bin/rkhunter" << 'EOF'
#!/bin/bash
echo "Mock rkhunter scan completed"
exit 0
EOF
    
    # Mock freshclam
    cat > "$mock_bin/freshclam" << 'EOF'
#!/bin/bash
echo "Mock virus definitions updated"
exit 0
EOF
    
    # Mock systemctl
    cat > "$mock_bin/systemctl" << 'EOF'
#!/bin/bash
echo "Mock systemctl command executed: $*"
exit 0
EOF
    
    # Mock loginctl
    cat > "$mock_bin/loginctl" << 'EOF'
#!/bin/bash
echo "Mock loginctl command executed: $*"
exit 0
EOF
    
    # Mock notify-send
    cat > "$mock_bin/notify-send" << 'EOF'
#!/bin/bash
echo "Mock notification sent: $*"
exit 0
EOF
    
    # Make all mock commands executable
    if [ -d "$mock_bin" ] && [ -n "$(ls -A "$mock_bin" 2>/dev/null)" ]; then
        chmod +x "$mock_bin"/*
    fi
}

# Additional mock functions needed by tests
check_disk_space() {
    return 0
}

check_memory_usage() {
    return 0
}

execute_command() {
    if [[ "$1" == *"false"* ]]; then
        return 1
    else
        echo "$2 executed successfully"
        return 0
    fi
}

# Export functions
export -f setup_test_environment
export -f cleanup_test_environment
export -f mock_external_commands
export -f check_disk_space
export -f check_memory_usage
export -f execute_command