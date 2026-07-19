#!/bin/bash

# Aegis Security Suite Web Dashboard Installation Script
# This script installs and configures the web dashboard

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DASHBOARD_NAME="Aegis Security Dashboard"
DASHBOARD_USER="aegis-dashboard"
DASHBOARD_SERVICE="aegis-dashboard"

# Security suite home
AEGIS_HOME="${AEGIS_HOME:-$HOME/aegis-security-suite}"

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

# Function to check dependencies
check_dependencies() {
    print_status "Checking dependencies..."
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is not installed"
        exit 1
    fi
    
    # Check pip
    if ! command -v pip3 &> /dev/null; then
        print_error "pip3 is not installed"
        exit 1
    fi
    
    # Check nginx (optional)
    if command -v nginx &> /dev/null; then
        NGINX_AVAILABLE=true
        print_status "Nginx found - can configure reverse proxy"
    else
        NGINX_AVAILABLE=false
        print_status "Nginx not found - will run standalone"
    fi
    
    print_success "Dependencies check completed"
}

# Function to create dashboard user
create_dashboard_user() {
    print_status "Creating dashboard user..."
    
    if ! id "$DASHBOARD_USER" &>/dev/null; then
        useradd -r -s /bin/false -d "$SCRIPT_DIR" "$DASHBOARD_USER"
        print_success "User $DASHBOARD_USER created"
    else
        print_status "User $DASHBOARD_USER already exists"
    fi
    
    # Set ownership
    chown -R "$DASHBOARD_USER:$DASHBOARD_USER" "$SCRIPT_DIR"
}

# Function to install Python dependencies
install_dependencies() {
    print_status "Installing Python dependencies..."
    
    # Create virtual environment
    sudo -u "$DASHBOARD_USER" python3 -m venv "$SCRIPT_DIR/venv"
    
    # Install requirements
    sudo -u "$DASHBOARD_USER" "$SCRIPT_DIR/venv/bin/pip" install -r "$SCRIPT_DIR/requirements.txt"
    
    print_success "Python dependencies installed"
}

# Function to setup configuration
setup_configuration() {
    print_status "Setting up configuration..."
    
    # Create config directory if it doesn't exist
    mkdir -p "$SCRIPT_DIR/config"
    
    # Update configuration with actual paths
    sed -i "s|/opt/aegis-security-suite|$AEGIS_HOME|g" "$SCRIPT_DIR/config/dashboard.conf"
    
    # Generate secret key
    SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_hex(32))")
    sed -i "s/your-secret-key-change-this-in-production/$SECRET_KEY/g" "$SCRIPT_DIR/config/dashboard.conf"
    
    print_success "Configuration setup completed"
}

# Function to create systemd service
create_systemd_service() {
    print_status "Creating systemd service..."
    
    cat > "/etc/systemd/system/$DASHBOARD_SERVICE.service" << EOF
[Unit]
Description=Aegis Security Suite Web Dashboard
After=network.target

[Service]
Type=simple
User=$DASHBOARD_USER
WorkingDirectory=$SCRIPT_DIR
Environment=AEGIS_HOME=$AEGIS_HOME
Environment=FLASK_APP=app.py
ExecStart=$SCRIPT_DIR/venv/bin/python app.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable "$DASHBOARD_SERVICE"
    
    print_success "Systemd service created"
}

# Function to setup nginx reverse proxy (optional)
setup_nginx() {
    if [[ "$NGINX_AVAILABLE" == true ]]; then
        print_status "Setting up Nginx reverse proxy..."
        
        cat > "/etc/nginx/sites-available/$DASHBOARD_SERVICE" << EOF
server {
    listen 80;
    server_name _;
    
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    location /socket.io/ {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
        
        # Enable site
        ln -sf "/etc/nginx/sites-available/$DASHBOARD_SERVICE" "/etc/nginx/sites-enabled/"
        nginx -t && systemctl reload nginx
        
        print_success "Nginx reverse proxy configured"
    fi
}

# Function to setup firewall rules
setup_firewall() {
    print_status "Setting up firewall rules..."
    
    # Check if ufw is available
    if command -v ufw &> /dev/null; then
        ufw allow 8080/tcp comment "Aegis Dashboard"
        if [[ "$NGINX_AVAILABLE" == true ]]; then
            ufw allow 80/tcp comment "Aegis Dashboard HTTP"
            ufw allow 443/tcp comment "Aegis Dashboard HTTPS"
        fi
        print_success "UFW rules added"
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-port=8080/tcp
        if [[ "$NGINX_AVAILABLE" == true ]]; then
            firewall-cmd --permanent --add-service=http
            firewall-cmd --permanent --add-service=https
        fi
        firewall-cmd --reload
        print_success "Firewalld rules added"
    else
        print_warning "No supported firewall found - please configure manually"
    fi
}

# Function to setup log rotation
setup_log_rotation() {
    print_status "Setting up log rotation..."
    
    cat > "/etc/logrotate.d/$DASHBOARD_SERVICE" << EOF
$AEGIS_HOME/logs/web-dashboard.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 $DASHBOARD_USER $DASHBOARD_USER
    postrotate
        systemctl reload $DASHBOARD_SERVICE || true
    endscript
}
EOF
    
    print_success "Log rotation configured"
}

# Function to create desktop entry
create_desktop_entry() {
    print_status "Creating desktop entry..."
    
    cat > "/usr/share/applications/$DASHBOARD_SERVICE.desktop" << EOF
[Desktop Entry]
Name=Aegis Security Dashboard
Comment=Security monitoring and management dashboard
Exec=xdg-open http://localhost:8080
Icon=security
Terminal=false
Type=Application
Categories=System;Security;
EOF
    
    print_success "Desktop entry created"
}

# Function to run tests
run_tests() {
    print_status "Running dashboard tests..."
    
    local test_script="$PROJECT_ROOT/tests/test_dashboard.py"
    if [[ -f "$test_script" ]]; then
        # Start dashboard in background for testing
        sudo -u "$DASHBOARD_USER" "$SCRIPT_DIR/venv/bin/python" "$SCRIPT_DIR/app.py" &
        DASHBOARD_PID=$!
        
        # Wait for dashboard to start
        sleep 5
        
        # Run tests
        if sudo -u "$DASHBOARD_USER" "$SCRIPT_DIR/venv/bin/python" "$test_script"; then
            print_success "All tests passed"
        else
            print_warning "Some tests failed - check the output above"
        fi
        
        # Stop test instance
        kill $DASHBOARD_PID 2>/dev/null || true
    else
        print_warning "Test script not found - skipping tests"
    fi
}

# Function to start dashboard
start_dashboard() {
    print_status "Starting dashboard service..."
    
    systemctl start "$DASHBOARD_SERVICE"
    
    # Wait for service to start
    sleep 3
    
    if systemctl is-active --quiet "$DASHBOARD_SERVICE"; then
        print_success "Dashboard service started successfully"
        print_status "Dashboard is available at: http://localhost:8080"
        if [[ "$NGINX_AVAILABLE" == true ]]; then
            print_status "Dashboard is also available at: http://$(hostname -I | awk '{print $1}')"
        fi
    else
        print_error "Failed to start dashboard service"
        systemctl status "$DASHBOARD_SERVICE"
        exit 1
    fi
}

# Function to show help
show_help() {
    echo "Aegis Security Suite Web Dashboard Installation Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --help, -h     Show this help message"
    echo "  --no-nginx      Skip Nginx configuration"
    echo "  --no-firewall   Skip firewall configuration"
    echo "  --no-tests       Skip post-installation tests"
    echo "  --dev           Development installation (no systemd service)"
    echo ""
    echo "Environment Variables:"
    echo "  AEGIS_HOME    Path to security suite installation"
    echo ""
    echo "Examples:"
    echo "  $0                    # Standard installation"
    echo "  $0 --no-nginx         # Install without Nginx"
    echo "  AEGIS_HOME=/opt/security $0  # Custom path"
}

# Main installation function
main() {
    local no_nginx=false
    local no_firewall=false
    local no_tests=false
    local dev_install=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --no-nginx)
                no_nginx=true
                shift
                ;;
            --no-firewall)
                no_firewall=true
                shift
                ;;
            --no-tests)
                no_tests=true
                shift
                ;;
            --dev)
                dev_install=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    echo "🚀 Installing $DASHBOARD_NAME"
    echo "Security Suite Home: $AEGIS_HOME"
    echo "Dashboard Directory: $SCRIPT_DIR"
    echo ""
    
    # Installation steps
    check_root
    check_dependencies
    create_dashboard_user
    install_dependencies
    setup_configuration
    
    if [[ "$dev_install" == false ]]; then
        create_systemd_service
        setup_log_rotation
        create_desktop_entry
        
        if [[ "$no_nginx" == false ]]; then
            setup_nginx
        fi
        
        if [[ "$no_firewall" == false ]]; then
            setup_firewall
        fi
        
        if [[ "$no_tests" == false ]]; then
            run_tests
        fi
        
        start_dashboard
    else
        print_status "Development installation completed"
        print_status "To start dashboard: cd $SCRIPT_DIR && ./start-dashboard.sh"
    fi
    
    echo ""
    print_success "Installation completed successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Open your browser and navigate to the dashboard URL"
    echo "2. Login with default credentials (admin/admin)"
    echo "3. Change the default password"
    echo "4. Configure security settings as needed"
    echo ""
    echo "For support, check the documentation at: $SCRIPT_DIR/README.md"
}

# Run main function with all arguments
main "$@"