#!/bin/bash
# Install Behavioral Monitor Service and Timer

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions for user detection
if [ -f "$SCRIPT_DIR/common-functions.sh" ]; then
    source "$SCRIPT_DIR/common-functions.sh"
fi

# Setup user environment (will set CURRENT_USER, CURRENT_HOME, AEGIS_HOME)
setup_user_environment

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root for system-wide installation
check_permissions() {
    if [[ $EUID -eq 0 ]]; then
        print_warning "Running as root. Installing system-wide service."
        SERVICE_DIR="/etc/systemd/system"
        USER_CMD=""
    else
        print_status "Installing user service."
        SERVICE_DIR="$HOME/.config/systemd/user"
        USER_CMD="--user"
        mkdir -p "$SERVICE_DIR"
    fi
}

# Install service and timer
install_service() {
    print_status "Installing behavioral monitor service and timer..."
    
    # Update service file with correct paths
    sed "s|/opt/aegis-security-suite|$AEGIS_HOME|g" \
        "$SCRIPT_DIR/behavioral-monitor.service" > "$SERVICE_DIR/behavioral-monitor.service"
    
    # Copy timer file
    cp "$SCRIPT_DIR/behavioral-monitor.timer" "$SERVICE_DIR/"
    
    # Reload systemd
    systemctl $USER_CMD daemon-reload
    
    print_success "Service and timer installed successfully"
}

# Enable and start service
enable_service() {
    print_status "Enabling behavioral monitor timer..."
    systemctl $USER_CMD enable behavioral-monitor.timer
    
    print_status "Starting behavioral monitor timer..."
    systemctl $USER_CMD start behavioral-monitor.timer
    
    print_success "Behavioral monitor service enabled and started"
}

# Show status
show_status() {
    print_status "Service status:"
    systemctl $USER_CMD status behavioral-monitor.timer --no-pager
    systemctl $USER_CMD status behavioral-monitor.service --no-pager
    
    print_status "Timer list:"
    systemctl $USER_CMD list-timers | grep behavioral
}

# Main execution
main() {
    local action="${1:-install}"
    
    case "$action" in
        "install")
            check_permissions
            install_service
            enable_service
            show_status
            ;;
        "status")
            check_permissions
            show_status
            ;;
        "uninstall")
            check_permissions
            print_status "Stopping and disabling behavioral monitor..."
            systemctl $USER_CMD stop behavioral-monitor.timer 2>/dev/null || true
            systemctl $USER_CMD stop behavioral-monitor.service 2>/dev/null || true
            systemctl $USER_CMD disable behavioral-monitor.timer 2>/dev/null || true
            
            print_status "Removing service files..."
            rm -f "$SERVICE_DIR/behavioral-monitor.service"
            rm -f "$SERVICE_DIR/behavioral-monitor.timer"
            
            systemctl $USER_CMD daemon-reload
            print_success "Behavioral monitor service uninstalled"
            ;;
        *)
            echo "Usage: $0 [install|status|uninstall]"
            echo "  install   - Install and enable the service (default)"
            echo "  status    - Show service status"
            echo "  uninstall - Remove the service"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"