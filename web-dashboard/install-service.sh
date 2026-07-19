#!/bin/bash
# Aegis Security Suite Dashboard Service Installation Script
# Installs the dashboard as a systemd service
#
# NOTE: This script is superseded by the deployment-mode prompt in
# ../setup-aegis.sh, which now branches to the right installer for you:
#   - Single user: setup-aegis.sh's own lightweight `systemctl --user` install
#   - Team/whole-system: install-dashboard.sh (dedicated service account,
#     nginx reverse proxy, firewall rules)
# This script is kept for anyone invoking it directly, but new installs
# should go through setup-aegis.sh instead of running this by hand.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_NAME="aegis-dashboard"
SERVICE_FILE="$SERVICE_NAME.service"
SYSTEMD_DIR="/etc/systemd/system"

# Source common functions for user detection
if [ -f "$SCRIPT_DIR/../scripts/common-functions.sh" ]; then
    source "$SCRIPT_DIR/../scripts/common-functions.sh"
    setup_user_environment
else
    # Fallback if common functions not available
    CURRENT_USER=$(whoami)
    CURRENT_HOME=$(getent passwd "$CURRENT_USER" | cut -d: -f6)
    AEGIS_HOME="${AEGIS_HOME:-$CURRENT_HOME/aegis-security-suite}"
fi

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

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi
}

# Function to validate installation
validate_installation() {
    print_status "Validating dashboard installation..."
    
    # Check if dashboard directory exists
    if [[ ! -d "$AEGIS_HOME/web-dashboard" ]]; then
        print_error "Dashboard directory not found at $AEGIS_HOME/web-dashboard"
        exit 1
    fi
    
    # Check if main app file exists
    if [[ ! -f "$AEGIS_HOME/web-dashboard/app.py" ]]; then
        print_error "Dashboard application file not found"
        exit 1
    fi
    
    # Check if virtual environment exists
    if [[ ! -d "$AEGIS_HOME/web-dashboard/venv" ]]; then
        print_warning "Virtual environment not found, creating..."
        python3 -m venv "$AEGIS_HOME/web-dashboard/venv"
    fi
    
    # Check if requirements are installed
    if [[ -f "$AEGIS_HOME/web-dashboard/requirements.txt" ]]; then
        print_status "Installing Python requirements..."
        source "$AEGIS_HOME/web-dashboard/venv/bin/activate"
        pip install -r "$AEGIS_HOME/web-dashboard/requirements.txt" >/dev/null 2>&1
        deactivate
    fi
    
    print_success "Dashboard installation validated"
}

# Function to create service user
create_service_user() {
    print_status "Creating service user..."
    
    # Use current user instead of creating aegis system user
    print_status "Using current user: $CURRENT_USER"
    
    # Set proper ownership for security suite home
    chown -R "$CURRENT_USER:$CURRENT_USER" "$AEGIS_HOME"
    chmod -R 755 "$AEGIS_HOME"
    
    # Ensure logs and configs directories are writable
    mkdir -p "$AEGIS_HOME/logs"
    mkdir -p "$AEGIS_HOME/configs"
    mkdir -p "$AEGIS_HOME/configs/web-dashboard"
    chown -R "$CURRENT_USER:$CURRENT_USER" "$AEGIS_HOME/logs"
    chown -R "$CURRENT_USER:$CURRENT_USER" "$AEGIS_HOME/configs"
    chmod -R 755 "$AEGIS_HOME/logs"
    chmod -R 755 "$AEGIS_HOME/configs"
    
    # Ensure web-dashboard directory is accessible
    chown -R "$CURRENT_USER:$CURRENT_USER" "$AEGIS_HOME/web-dashboard"
    chmod -R 755 "$AEGIS_HOME/web-dashboard"
}

# Function to install systemd service
install_service() {
    print_status "Installing systemd service..."
    
    # Copy service file
    cp "$SCRIPT_DIR/$SERVICE_FILE" "$SYSTEMD_DIR/"
    
    # Update service file with actual paths
    sed -i "s|/opt/aegis-security-suite|$AEGIS_HOME|g" "$SYSTEMD_DIR/$SERVICE_FILE"
    
    # Reload systemd
    systemctl daemon-reload
    
    print_success "Systemd service installed"
}

# Function to configure service
configure_service() {
    print_status "Configuring service..."
    
    # Enable service to start on boot
    systemctl enable "$SERVICE_NAME"
    
    # Create environment file for service
    cat > "/etc/default/$SERVICE_NAME" << EOF
# Aegis Security Suite Dashboard Environment Configuration
AEGIS_HOME="$AEGIS_HOME"
FLASK_ENV=production
FLASK_APP=app.py
DASHBOARD_PORT=8080
DASHBOARD_HOST=127.0.0.1
EOF
    
    print_success "Service configuration completed"
}

# Function to setup firewall
setup_firewall() {
    print_status "Configuring firewall..."
    
    # Check if firewall is active
    if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
        # UFW is active
        ufw allow 8080/tcp comment "Aegis Security Dashboard"
        print_success "Firewall configured (UFW)"
    elif command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld; then
        # firewalld is active
        firewall-cmd --permanent --add-port=8080/tcp
        firewall-cmd --reload
        print_success "Firewall configured (firewalld)"
    else
        print_warning "No active firewall detected or unsupported firewall"
        print_status "Please manually allow port 8080/tcp for dashboard access"
    fi
}

# Function to start service
start_service() {
    print_status "Starting dashboard service..."
    
    # Start the service
    systemctl start "$SERVICE_NAME"
    
    # Wait a moment and check status
    sleep 3
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        print_success "Dashboard service started successfully"
        print_status "Service status: $(systemctl is-active "$SERVICE_NAME")"
        print_status "Dashboard URL: http://localhost:8080"
        
        # Show service status
        echo ""
        systemctl status "$SERVICE_NAME" --no-pager -l
    else
        print_error "Failed to start dashboard service"
        print_status "Checking service logs:"
        journalctl -u "$SERVICE_NAME" --no-pager -n 20
        exit 1
    fi
}

# Function to show service info
show_service_info() {
    print_status "Service Information:"
    echo "  Service Name: $SERVICE_NAME"
    echo "  Service File: $SYSTEMD_DIR/$SERVICE_FILE"
    echo "  Dashboard URL: http://localhost:8080"
    echo "  Log Command: journalctl -u $SERVICE_NAME -f"
    echo "  Status Command: systemctl status $SERVICE_NAME"
    echo ""
    print_status "Service Management:"
    echo "  Start: systemctl start $SERVICE_NAME"
    echo "  Stop: systemctl stop $SERVICE_NAME"
    echo "  Restart: systemctl restart $SERVICE_NAME"
    echo "  Enable: systemctl enable $SERVICE_NAME"
    echo "  Disable: systemctl disable $SERVICE_NAME"
    echo "  Status: systemctl status $SERVICE_NAME"
    echo "  Logs: journalctl -u $SERVICE_NAME -f"
}

# Function to uninstall service
uninstall_service() {
    print_status "Uninstalling dashboard service..."
    
    # Stop and disable service
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        systemctl stop "$SERVICE_NAME"
    fi
    
    if systemctl is-enabled --quiet "$SERVICE_NAME"; then
        systemctl disable "$SERVICE_NAME"
    fi
    
    # Remove service file
    rm -f "$SYSTEMD_DIR/$SERVICE_FILE"
    
    # Remove environment file
    rm -f "/etc/default/$SERVICE_NAME"
    
    # Reload systemd
    systemctl daemon-reload
    
    print_success "Service uninstalled successfully"
}

# Function to show help
show_help() {
    echo "Aegis Security Suite Dashboard Service Installation Script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  install     Install and configure the dashboard service"
    echo "  start       Start the dashboard service"
    echo "  stop        Stop the dashboard service"
    echo "  restart     Restart the dashboard service"
    echo "  status      Show service status"
    echo "  logs        Show service logs"
    echo "  uninstall   Uninstall the dashboard service"
    echo "  info        Show service information"
    echo "  help        Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  AEGIS_HOME    Path to security suite installation (default: \$HOME/aegis-security-suite)"
    echo ""
    echo "Examples:"
    echo "  $0 install              # Install service"
    echo "  $0 start               # Start service"
    echo "  AEGIS_HOME=/opt/security $0 install  # Install with custom path"
}

# Main script logic
main() {
    local command="${1:-install}"
    
    case "$command" in
        "install")
            check_root
            validate_installation
            create_service_user
            install_service
            configure_service
            setup_firewall
            start_service
            show_service_info
            ;;
        "start")
            check_root
            systemctl start "$SERVICE_NAME"
            print_success "Dashboard service started"
            ;;
        "stop")
            check_root
            systemctl stop "$SERVICE_NAME"
            print_success "Dashboard service stopped"
            ;;
        "restart")
            check_root
            systemctl restart "$SERVICE_NAME"
            print_success "Dashboard service restarted"
            ;;
        "status")
            systemctl status "$SERVICE_NAME" --no-pager
            ;;
        "logs")
            journalctl -u "$SERVICE_NAME" -f
            ;;
        "uninstall")
            check_root
            uninstall_service
            ;;
        "info")
            show_service_info
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Trap signals for cleanup
trap 'print_status "Cleaning up..."; exit 0' INT TERM

# Run main function with all arguments
main "$@"