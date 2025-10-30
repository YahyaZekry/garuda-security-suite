#!/bin/bash
# Test Environment Setup Script for Garuda Security Suite
# Installs test dependencies and configures testing environment

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(dirname "$0")"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
declare -A COLORS=(
    ["RED"]='\033[0;31m'
    ["GREEN"]='\033[0;32m'
    ["YELLOW"]='\033[1;33m'
    ["BLUE"]='\033[0;34m'
    ["PURPLE"]='\033[0;35m'
    ["CYAN"]='\033[0;36m'
    ["NC"]='\033[0m'
)

# Logging functions
log_info() {
    echo -e "${COLORS[BLUE]}[INFO]${COLORS[NC]} $1"
}

log_success() {
    echo -e "${COLORS[GREEN]}[SUCCESS]${COLORS[NC]} $1"
}

log_warning() {
    echo -e "${COLORS[YELLOW]}[WARNING]${COLORS[NC]} $1"
}

log_error() {
    echo -e "${COLORS[RED]}[ERROR]${COLORS[NC]} $1"
}

log_header() {
    echo -e "${COLORS[PURPLE]}=== $1 ===${COLORS[NC]}"
}

# Check if running as root for package installation
check_sudo() {
    if [ "$EUID" -eq 0 ]; then
        log_warning "Running as root - This is not recommended for test setup"
        log_info "Consider running as a regular user with sudo access"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Detect package manager
detect_package_manager() {
    if command -v pacman &> /dev/null; then
        echo "pacman"
    elif command -v apt-get &> /dev/null; then
        echo "apt"
    elif command -v dnf &> /dev/null; then
        echo "dnf"
    elif command -v yum &> /dev/null; then
        echo "yum"
    else
        echo "unknown"
    fi
}

# Install packages with pacman
install_with_pacman() {
    local packages=("$@")
    
    log_info "Installing packages with pacman: ${packages[*]}"
    
    # Update package database
    sudo pacman -Sy --noconfirm
    
    # Install packages
    for package in "${packages[@]}"; do
        if ! pacman -Qi "$package" &> /dev/null; then
            log_info "Installing $package..."
            sudo pacman -S --noconfirm "$package"
        else
            log_info "Package $package is already installed"
        fi
    done
}

# Install packages with apt
install_with_apt() {
    local packages=("$@")
    
    log_info "Installing packages with apt: ${packages[*]}"
    
    # Update package database
    sudo apt-get update -qq
    
    # Install packages
    for package in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            log_info "Installing $package..."
            sudo apt-get install -y "$package"
        else
            log_info "Package $package is already installed"
        fi
    done
}

# Install packages with dnf/yum
install_with_dnf() {
    local packages=("$@")
    
    log_info "Installing packages with dnf: ${packages[*]}"
    
    # Update package database
    sudo dnf check-update -qq
    
    # Install packages
    for package in "${packages[@]}"; do
        if ! rpm -q "$package" &> /dev/null; then
            log_info "Installing $package..."
            sudo dnf install -y "$package"
        else
            log_info "Package $package is already installed"
        fi
    done
}

# Install BATS (Bash Automated Testing System)
install_bats() {
    log_header "Installing BATS Testing Framework"
    
    if command -v bats &> /dev/null; then
        log_success "BATS is already installed"
        bats --version
        return 0
    fi
    
    local pkg_manager=$(detect_package_manager)
    
    case "$pkg_manager" in
        "pacman")
            install_with_pacman "bats"
            ;;
        "apt")
            # BATS might not be in default repos, install from GitHub
            log_info "Installing BATS from GitHub..."
            local temp_dir=$(mktemp -d)
            cd "$temp_dir"
            git clone https://github.com/bats-core/bats-core.git
            cd bats-core
            sudo ./install.sh /usr/local
            cd /
            rm -rf "$temp_dir"
            ;;
        "dnf")
            install_with_dnf "bats"
            ;;
        "yum")
            # For older systems, install from GitHub
            log_info "Installing BATS from GitHub..."
            local temp_dir=$(mktemp -d)
            cd "$temp_dir"
            git clone https://github.com/bats-core/bats-core.git
            cd bats-core
            sudo ./install.sh /usr/local
            cd /
            rm -rf "$temp_dir"
            ;;
        *)
            log_error "Unsupported package manager: $pkg_manager"
            log_info "Please install BATS manually from: https://github.com/bats-core/bats-core"
            return 1
            ;;
    esac
    
    # Verify installation
    if command -v bats &> /dev/null; then
        log_success "BATS installed successfully"
        bats --version
    else
        log_error "BATS installation failed"
        return 1
    fi
}

# Install shellcheck
install_shellcheck() {
    log_header "Installing Shellcheck"
    
    if command -v shellcheck &> /dev/null; then
        log_success "Shellcheck is already installed"
        shellcheck --version
        return 0
    fi
    
    local pkg_manager=$(detect_package_manager)
    
    case "$pkg_manager" in
        "pacman")
            install_with_pacman "shellcheck"
            ;;
        "apt")
            install_with_apt "shellcheck"
            ;;
        "dnf")
            install_with_dnf "shellcheck"
            ;;
        "yum")
            # For older systems, might need EPEL
            log_info "Installing EPEL repository for shellcheck..."
            sudo yum install -y epel-release
            install_with_dnf "shellcheck"
            ;;
        *)
            log_error "Unsupported package manager: $pkg_manager"
            log_info "Please install shellcheck manually from: https://github.com/koalaman/shellcheck"
            return 1
            ;;
    esac
    
    # Verify installation
    if command -v shellcheck &> /dev/null; then
        log_success "Shellcheck installed successfully"
        shellcheck --version
    else
        log_error "Shellcheck installation failed"
        return 1
    fi
}

# Install security tools for testing
install_security_tools() {
    log_header "Installing Security Tools for Testing"
    
    local pkg_manager=$(detect_package_manager)
    
    case "$pkg_manager" in
        "pacman")
            install_with_pacman "clamav" "rkhunter" "chkrootkit" "lynis"
            ;;
        "apt")
            install_with_apt "clamav" "rkhunter" "chkrootkit" "lynis"
            ;;
        "dnf")
            install_with_dnf "clamav" "rkhunter" "chkrootkit" "lynis"
            ;;
        "yum")
            install_with_dnf "clamav" "rkhunter" "chkrootkit" "lynis"
            ;;
        *)
            log_warning "Cannot automatically install security tools with package manager: $pkg_manager"
            log_info "Please install manually: clamav, rkhunter, chkrootkit, lynis"
            return 1
            ;;
    esac
    
    log_success "Security tools installed"
}

# Create mock security tools for testing
create_mock_tools() {
    log_header "Creating Mock Security Tools"
    
    local mock_bin_dir="$PROJECT_ROOT/tests/mock-bin"
    mkdir -p "$mock_bin_dir"
    
    # Add mock bin to PATH in test environment
    export PATH="$mock_bin_dir:$PATH"
    
    # Create mock clamscan
    cat > "$mock_bin_dir/clamscan" << 'EOF'
#!/bin/bash
# Mock clamscan for testing
echo "Mock ClamAV Scanner v0.103.2"
echo "Scanning files..."

for arg in "$@"; do
    if [ -f "$arg" ] && grep -q "EICAR" "$arg" 2>/dev/null; then
        echo "$arg: Eicar-Test-Signature FOUND"
        exit_code=1
    elif [ -d "$arg" ]; then
        echo "Scanning directory: $arg"
        # Check for EICAR in directory
        if find "$arg" -type f -exec grep -l "EICAR" {} \; 2>/dev/null | head -1 | grep -q .; then
            echo "EICAR test file found in $arg"
            exit_code=1
        fi
    fi
done

echo "Scan completed"
exit ${exit_code:-0}
EOF
    
    # Create mock rkhunter
    cat > "$mock_bin_dir/rkhunter" << 'EOF'
#!/bin/bash
# Mock rkhunter for testing
echo "Rootkit Hunter 1.4.6"
echo "Running system checks..."

case "$1" in
    "--update")
        echo "Updating rkhunter database..."
        echo "Database updated successfully"
        exit 0
        ;;
    "--check")
        echo "Performing system check..."
        echo "No rootkits found"
        echo "No warnings found"
        exit 0
        ;;
    "--propupd")
        echo "Updating file properties database..."
        echo "Properties database updated"
        exit 0
        ;;
    *)
        echo "Usage: rkhunter [--update|--check|--propupd]"
        exit 1
        ;;
esac
EOF
    
    # Create mock freshclam
    cat > "$mock_bin_dir/freshclam" << 'EOF'
#!/bin/bash
# Mock freshclam for testing
echo "FreshClam v0.103.2"
echo "Updating virus definitions..."
echo "Virus definitions updated successfully"
exit 0
EOF
    
    # Create mock chkrootkit
    cat > "$mock_bin_dir/chkrootkit" << 'EOF'
#!/bin/bash
# Mock chkrootkit for testing
echo "ROOTKIT Hunter 0.55"
echo "Checking for rootkits..."

echo "Checking `amd`... not found"
echo "Checking `basename`... not infected"
echo "Checking `biff`... not found"
echo "Checking `chfn`... not infected"
echo "Checking `chsh`... not infected"
echo "Checking `cron`... not infected"
echo "Checking `crontab`... not infected"
echo "Checking `date`... not infected"
echo "Checking `du`... not infected"
echo "Checking `echo`... not infected"
echo "Checking `env`... not infected"
echo "Checking `find`... not infected"
echo "Checking `fingerd`... not found"
echo "Checking `gpm`... not infected"
echo "Checking `grep`... not infected"
echo "Checking `hdparm`... not infected"
echo "Checking `ifconfig`... not infected"
echo "Checking `inetd`... not infected"
echo "Checking `init`... not infected"
echo "Checking `killall`... not infected"
echo "Checking `ld.so`... not infected"
echo "Checking `login`... not infected"
echo "Checking `ls`... not infected"
echo "Checking `lsof`... not infected"
echo "Checking `mail`... not infected"
echo "Checking `mingetty`... not infected"
echo "Checking `netstat`... not infected"
echo "Checking `named`... not found"
echo "Checking `passwd`... not infected"
echo "Checking `ps`... not infected"
echo "Checking `pstree`... not infected"
echo "Checking `rpc.statd`... not infected"
echo "Checking `rlogind`... not found"
echo "Checking `rshd`... not found"
echo "Checking `slogin`... not infected"
echo "Checking `sendmail`... not infected"
echo "Checking `sshd`... not infected"
echo "Checking `syslogd`... not infected"
echo "Checking `tar`... not infected"
echo "Checking `tcpd`... not infected"
echo "Checking `tcpdump`... not infected"
echo "Checking `top`... not infected"
echo "Checking `telnetd`... not found"
echo "Checking `timed`... not found"
echo "Checking `traceroute`... not infected"
echo "Checking `vdir`... not infected"
echo "Checking `w`... not infected"
echo "Checking `write`... not infected"
echo "Checking `xinetd`... not infected"

echo "No rootkits detected"
exit 0
EOF
    
    # Create mock lynis
    cat > "$mock_bin_dir/lynis" << 'EOF'
#!/bin/bash
# Mock lynis for testing
echo "Lynis 3.0.6"
echo "Authors: CISOfy, https://cisofy.com"

case "$1" in
    "audit")
        echo "Starting system audit..."
        echo "Performing tests..."
        echo "System audit completed"
        echo "No security issues found"
        exit 0
        ;;
    *)
        echo "Usage: lynis audit system"
        exit 1
        ;;
esac
EOF
    
    # Create mock systemctl
    cat > "$mock_bin_dir/systemctl" << 'EOF'
#!/bin/bash
# Mock systemctl for testing
echo "Mock systemctl command executed: $*"
exit 0
EOF
    
    # Create mock loginctl
    cat > "$mock_bin_dir/loginctl" << 'EOF'
#!/bin/bash
# Mock loginctl for testing
echo "Mock loginctl command executed: $*"
exit 0
EOF
    
    # Create mock notify-send
    cat > "$mock_bin_dir/notify-send" << 'EOF'
#!/bin/bash
# Mock notify-send for testing
echo "Mock notification sent: $*"
exit 0
EOF
    
    # Make all mock tools executable
    chmod +x "$mock_bin_dir"/*
    
    log_success "Mock security tools created in $mock_bin_dir"
}

# Configure test environment
configure_test_env() {
    log_header "Configuring Test Environment"
    
    # Create test directories
    mkdir -p "$PROJECT_ROOT/tests/test-results"
    mkdir -p "$PROJECT_ROOT/tests/logs"
    
    # Set environment variables for testing
    export BATS_TMPDIR="$PROJECT_ROOT/tests/tmp"
    mkdir -p "$BATS_TMPDIR"
    
    # Create test configuration
    cat > "$PROJECT_ROOT/tests/test-config.env" << EOF
# Test Environment Configuration
export PROJECT_ROOT="$PROJECT_ROOT"
export SCRIPT_DIR="$PROJECT_ROOT/scripts"
export CONFIGS_DIR="$PROJECT_ROOT/configs"
export LOGS_DIR="$PROJECT_ROOT/tests/logs"
export TEST_RESULTS_DIR="$PROJECT_ROOT/tests/test-results"
export BATS_TMPDIR="$BATS_TMPDIR"

# Mock tools path
export PATH="$PROJECT_ROOT/tests/mock-bin:\$PATH"

# Test settings
export NOTIFICATIONS_ENABLED=false
export SECURITY_SUITE_HOME="$PROJECT_ROOT/tests/security-suite"
export CURRENT_USER="testuser"
export CURRENT_HOME="$HOME"
EOF
    
    log_success "Test environment configured"
    log_info "Test configuration: $PROJECT_ROOT/tests/test-config.env"
}

# Verify test environment
verify_test_env() {
    log_header "Verifying Test Environment"
    
    local verification_failed=0
    
    # Check BATS
    if ! command -v bats &> /dev/null; then
        log_error "BATS is not installed or not in PATH"
        verification_failed=1
    else
        log_success "BATS is available: $(bats --version)"
    fi
    
    # Check shellcheck
    if ! command -v shellcheck &> /dev/null; then
        log_error "Shellcheck is not installed or not in PATH"
        verification_failed=1
    else
        log_success "Shellcheck is available: $(shellcheck --version)"
    fi
    
    # Check mock tools
    local mock_tools=("clamscan" "rkhunter" "freshclam" "chkrootkit" "lynis" "systemctl" "loginctl" "notify-send")
    for tool in "${mock_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "Mock tool $tool is not available"
            verification_failed=1
        else
            log_success "Mock tool $tool is available"
        fi
    done
    
    # Check test directories
    local test_dirs=("$PROJECT_ROOT/tests/test-results" "$PROJECT_ROOT/tests/logs" "$BATS_TMPDIR")
    for dir in "${test_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            log_error "Test directory $dir does not exist"
            verification_failed=1
        else
            log_success "Test directory $dir exists"
        fi
    done
    
    # Check test files
    local test_files=(
        "$PROJECT_ROOT/tests/test-helper.bash"
        "$PROJECT_ROOT/tests/test-suite.bats"
        "$PROJECT_ROOT/tests/integration-tests.bats"
        "$PROJECT_ROOT/tests/performance-tests.bats"
        "$PROJECT_ROOT/tests/security-tests.bats"
        "$PROJECT_ROOT/tests/run-all-tests.sh"
    )
    
    for file in "${test_files[@]}"; do
        if [ ! -f "$file" ]; then
            log_error "Test file $file does not exist"
            verification_failed=1
        else
            log_success "Test file $file exists"
        fi
    done
    
    if [ $verification_failed -eq 0 ]; then
        log_success "Test environment verification passed"
        return 0
    else
        log_error "Test environment verification failed"
        return 1
    fi
}

# Run a quick test to verify everything works
run_quick_test() {
    log_header "Running Quick Test"
    
    # Source test configuration
    source "$PROJECT_ROOT/tests/test-config.env"
    
    # Run a simple BATS test
    echo "Testing BATS functionality..."
    
    cat > "$BATS_TMPDIR/quick-test.bats" << 'EOF'
#!/usr/bin/env bats

@test "quick test - basic functionality" {
    [ true ]
}

@test "quick test - test helper loading" {
    load "test-helper"
    [ -n "$TEST_DIR" ]
}
EOF
    
    if bats "$BATS_TMPDIR/quick-test.bats"; then
        log_success "Quick test passed"
        rm -f "$BATS_TMPDIR/quick-test.bats"
        return 0
    else
        log_error "Quick test failed"
        rm -f "$BATS_TMPDIR/quick-test.bats"
        return 1
    fi
}

# Main execution
main() {
    log_header "Garuda Security Suite Test Environment Setup"
    log_info "Setting up test environment for: $PROJECT_ROOT"
    
    # Check sudo access
    check_sudo
    
    # Install dependencies
    if ! install_bats; then
        log_error "Failed to install BATS"
        exit 1
    fi
    
    if ! install_shellcheck; then
        log_error "Failed to install Shellcheck"
        exit 1
    fi
    
    # Install security tools (optional)
    if [ "${1:-}" != "--no-security-tools" ]; then
        log_info "Installing security tools (this may take a while)..."
        install_security_tools || log_warning "Security tools installation failed - will use mocks"
    fi
    
    # Create mock tools
    create_mock_tools
    
    # Configure environment
    configure_test_env
    
    # Verify setup
    if ! verify_test_env; then
        log_error "Test environment setup failed"
        exit 1
    fi
    
    # Run quick test
    if ! run_quick_test; then
        log_error "Quick test failed"
        exit 1
    fi
    
    log_header "Setup Complete"
    log_success "Test environment is ready!"
    log_info "To run tests:"
    log_info "  cd $PROJECT_ROOT"
    log_info "  source tests/test-config.env"
    log_info "  tests/run-all-tests.sh"
    log_info ""
    log_info "To run specific test suites:"
    log_info "  tests/run-all-tests.sh --unit"
    log_info "  tests/run-all-tests.sh --integration"
    log_info "  tests/run-all-tests.sh --performance"
    log_info "  tests/run-all-tests.sh --security"
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "Garuda Security Suite Test Environment Setup"
        echo ""
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --help, -h              Show this help message"
        echo "  --no-security-tools      Skip installation of security tools (use mocks only)"
        echo ""
        echo "This script will install BATS, Shellcheck, and security tools"
        echo "required for testing the Garuda Security Suite."
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac