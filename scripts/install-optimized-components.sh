#!/bin/bash
# Installation Script for Optimized Aegis Security Suite Components
# Installs optimized versions with memory management and performance improvements

source "$(dirname "$0")/common-functions.sh"

# Setup user environment (will set all necessary variables)
setup_user_environment

# Get script directory
SCRIPT_DIR="$(dirname "$0")"

# Installation configuration
BACKUP_DIR="$AEGIS_HOME/backups/optimized-$(date +%Y%m%d_%H%M%S)"
INSTALL_LOG="$AEGIS_HOME/logs/optimized-install-$(date +%Y%m%d_%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$INSTALL_LOG"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$INSTALL_LOG"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$INSTALL_LOG"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$INSTALL_LOG"
}

# Backup existing files
backup_existing_files() {
    log_info "Creating backup of existing files..."
    
    mkdir -p "$BACKUP_DIR"
    
    # Backup original scripts
    local files_to_backup=(
        "scripts/behavioral-monitor.sh"
        "scripts/behavioral-analysis.sh"
        "scripts/threat-intelligence-v2.sh"
        "scripts/threat-intelligence-v3.sh"
        "web-dashboard/app.py"
    )
    
    for file in "${files_to_backup[@]}"; do
        local source_file="$AEGIS_HOME/$file"
        local backup_file="$BACKUP_DIR/$file"
        
        if [ -f "$source_file" ]; then
            mkdir -p "$(dirname "$backup_file")"
            cp "$source_file" "$backup_file"
            log_success "Backed up: $file"
        fi
    done
    
    log_success "Backup completed: $BACKUP_DIR"
}

# Install optimized behavioral monitoring
install_optimized_behavioral_monitoring() {
    log_info "Installing optimized behavioral monitoring..."
    
    # Make scripts executable
    chmod +x "$SCRIPT_DIR/behavioral-monitor-optimized.sh"
    chmod +x "$SCRIPT_DIR/behavioral-analysis-optimized.sh"
    
    # Update systemd service
    if [ -f "$SCRIPT_DIR/behavioral-monitor.service" ]; then
        cp "$SCRIPT_DIR/behavioral-monitor.service" "$BACKUP_DIR/behavioral-monitor.service.backup"
        
        # Create optimized service file with dynamic user detection
        cat > "$SCRIPT_DIR/behavioral-monitor-optimized.service" << EOF
[Unit]
Description=Optimized Aegis Behavioral Monitoring Service
Documentation=https://github.com/aegis-security-suite/behavioral-monitor
After=network.target
Wants=network.target

[Service]
Type=simple
User=$CURRENT_USER
Group=$CURRENT_USER
ExecStart=$AEGIS_HOME/scripts/behavioral-monitor-optimized.sh
ExecReload=/bin/kill -HUP $MAINPID
KillMode=mixed
KillSignal=SIGTERM
TimeoutStopSec=30
Restart=on-failure
RestartSec=60
StartLimitBurst=3
StartLimitInterval=300

# Security settings
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$AEGIS_HOME/logs
PrivateTmp=true
ProtectKernelTunables=true
ProtectControlGroups=true
RestrictRealtime=true
MemoryMax=256M
CPUQuota=30%

# Environment
Environment=AEGIS_HOME=$AEGIS_HOME
Environment=BEHAVIORAL_ANALYSIS_ENABLED=true
Environment=BEHAVIORAL_MONITORING_INTERVAL=30
Environment=BEHAVIORAL_THREAT_SCORE_THRESHOLD=70

[Install]
WantedBy=multi-user.target
EOF
        
        log_success "Optimized behavioral monitoring service created"
    fi
    
    log_success "Optimized behavioral monitoring installed"
}

# Install optimized threat intelligence
install_optimized_threat_intelligence() {
    log_info "Installing optimized threat intelligence..."
    
    # Make script executable
    chmod +x "$SCRIPT_DIR/threat-intelligence-optimized.sh"
    
    log_success "Optimized threat intelligence installed"
}

# Install optimized web dashboard
install_optimized_web_dashboard() {
    log_info "Installing optimized web dashboard..."
    
    # Create optimized app file
    cp "$SCRIPT_DIR/../web-dashboard/app.py" "$BACKUP_DIR/web-dashboard/app.py"
    
    # Update requirements if needed
    local requirements_file="$SCRIPT_DIR/../web-dashboard/requirements-optimized.txt"
    if [ ! -f "$requirements_file" ]; then
        cat > "$requirements_file" << 'EOF'
Flask==2.3.3
Flask-SocketIO==5.3.6
python-socketio==5.8.0
psutil==5.9.6
Werkzeug==2.3.7
EOF
    fi
    
    # Create optimized systemd service
    if [ -f "$SCRIPT_DIR/../web-dashboard/aegis-dashboard.service" ]; then
        cp "$SCRIPT_DIR/../web-dashboard/aegis-dashboard.service" "$BACKUP_DIR/aegis-dashboard.service.backup"
        
        cat > "$SCRIPT_DIR/../web-dashboard/aegis-dashboard-optimized.service" << EOF
[Unit]
Description=Optimized Aegis Security Suite Dashboard
Documentation=https://github.com/aegis-security-suite/dashboard
After=network.target
Wants=network.target

[Service]
Type=simple
User=$CURRENT_USER
Group=$CURRENT_USER
WorkingDirectory=$AEGIS_HOME/web-dashboard
ExecStart=/usr/bin/python3 $AEGIS_HOME/web-dashboard/app.py
ExecReload=/bin/kill -HUP $MAINPID
KillMode=mixed
KillSignal=SIGTERM
TimeoutStopSec=30
Restart=on-failure
RestartSec=30
StartLimitBurst=3
StartLimitInterval=300

# Security settings
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$AEGIS_HOME/logs
ReadWritePaths=$AEGIS_HOME/configs
ReadWritePaths=$AEGIS_HOME/web-dashboard
PrivateTmp=true
ProtectKernelTunables=true
ProtectControlGroups=true
RestrictRealtime=true
MemoryMax=512M
CPUQuota=50%

# Environment
Environment=AEGIS_HOME=$AEGIS_HOME
Environment=FLASK_ENV=production
Environment=PYTHONPATH=$AEGIS_HOME/web-dashboard

[Install]
WantedBy=multi-user.target
EOF
        
        log_success "Optimized web dashboard service created"
    fi
    
    log_success "Optimized web dashboard installed"
}

# Install memory monitor
install_memory_monitor() {
    log_info "Installing memory monitor..."
    
    # Make script executable
    chmod +x "$SCRIPT_DIR/memory-monitor.sh"
    
    # Install systemd service
    if [ -f "$SCRIPT_DIR/memory-monitor.service" ]; then
        # Create user systemd directory if it doesn't exist
        mkdir -p "$HOME/.config/systemd/user"
        
        # Process service template to replace variables
        sed "s|\${AEGIS_HOME}|$AEGIS_HOME|g" \
            "$SCRIPT_DIR/memory-monitor.service" > "$HOME/.config/systemd/user/memory-monitor.service"
        
        # Reload systemd
        systemctl --user daemon-reload
        
        # Enable and start service
        systemctl --user enable memory-monitor.service
        systemctl --user start memory-monitor.service
        
        log_success "Memory monitor service installed and started"
    fi
    
    log_success "Memory monitor installed"
}

# Install database connection manager
install_db_connection_manager() {
    log_info "Installing database connection manager..."
    
    # Make script executable
    chmod +x "$SCRIPT_DIR/db-connection-manager.sh"
    
    log_success "Database connection manager installed"
}

# Install performance testing tools
install_performance_tools() {
    log_info "Installing performance testing tools..."
    
    # Make script executable
    chmod +x "$SCRIPT_DIR/performance-test-optimized.sh"
    
    log_success "Performance testing tools installed"
}

# Update configuration
update_configuration() {
    log_info "Updating configuration for optimized components..."
    
    local config_file="$AEGIS_HOME/configs/security-config.conf"
    
    # Backup original config
    if [ -f "$config_file" ]; then
        cp "$config_file" "$BACKUP_DIR/security-config.conf.backup"
    fi
    
    # Add optimized configuration
    cat >> "$config_file" << 'EOF'

# Optimized Configuration Settings
# Added by optimized components installer

# Memory Management
MEMORY_MONITOR_ENABLED=true
MEMORY_THRESHOLD_WARNING=80
MEMORY_THRESHOLD_CRITICAL=90
PROCESS_MEMORY_LIMIT=500

# Behavioral Analysis Optimization
BEHAVIORAL_ANALYSIS_OPTIMIZED=true
MAX_PROCESSES_TO_MONITOR=30
MAX_NETWORK_CONNECTIONS=100
MAX_FILE_ACCESSES=200

# Threat Intelligence Optimization
THREAT_INTELLIGENCE_OPTIMIZED=true
MAX_FEED_SIZE_MB=50
MAX_MEMORY_USAGE_MB=200
MAX_CONCURRENT_DOWNLOADS=3

# Database Optimization
DATABASE_CONNECTION_POOLING=true
MAX_DB_CONNECTIONS=5
QUERY_TIMEOUT=10
MAX_DB_SIZE_MB=500

# Web Dashboard Optimization
DASHBOARD_OPTIMIZED=true
MAX_CONCURRENT_CONNECTIONS=50
CONNECTION_TIMEOUT=300
WEBSOCKET_PING_INTERVAL=25
WEBSOCKET_PING_TIMEOUT=30
EOF
    
    log_success "Configuration updated for optimized components"
}

# Create optimization scripts
create_optimization_scripts() {
    log_info "Creating optimization scripts..."
    
    # Create enable-optimized script
    cat > "$SCRIPT_DIR/enable-optimized.sh" << 'EOF'
#!/bin/bash
# Enable Optimized Components Script

SCRIPT_DIR="$(dirname "$0")"
AEGIS_HOME="$(dirname "$SCRIPT_DIR")"

echo "Enabling optimized Aegis Security Suite components..."

# Stop existing services
systemctl --user stop aegis-behavioral-monitor 2>/dev/null || true
systemctl --user stop aegis-dashboard 2>/dev/null || true

# Start optimized services
systemctl --user daemon-reload
systemctl --user enable memory-monitor.service
systemctl --user start memory-monitor.service

echo "Optimized components enabled successfully"
echo "Run 'systemctl --user status' to check service status"
EOF

    # Create disable-optimized script
    cat > "$SCRIPT_DIR/disable-optimized.sh" << 'EOF'
#!/bin/bash
# Disable Optimized Components Script

SCRIPT_DIR="$(dirname "$0")"
AEGIS_HOME="$(dirname "$SCRIPT_DIR")"

echo "Disabling optimized Aegis Security Suite components..."

# Stop optimized services
systemctl --user stop memory-monitor.service 2>/dev/null || true

# Restore original components
if [ -f "$SCRIPT_DIR/behavioral-monitor.sh.backup" ]; then
    mv "$SCRIPT_DIR/behavioral-monitor.sh.backup" "$SCRIPT_DIR/behavioral-monitor.sh"
fi

if [ -f "$SCRIPT_DIR/behavioral-analysis.sh.backup" ]; then
    mv "$SCRIPT_DIR/behavioral-analysis.sh.backup" "$SCRIPT_DIR/behavioral-analysis.sh"
fi

if [ -f "$SCRIPT_DIR/threat-intelligence.sh.backup" ]; then
    mv "$SCRIPT_DIR/threat-intelligence.sh.backup" "$SCRIPT_DIR/threat-intelligence.sh"
fi

if [ -f "$SCRIPT_DIR/../web-dashboard/app.py.backup" ]; then
    mv "$SCRIPT_DIR/../web-dashboard/app.py.backup" "$SCRIPT_DIR/../web-dashboard/app.py"
fi

# Restart original services
systemctl --user daemon-reload
systemctl --user start aegis-behavioral-monitor 2>/dev/null || true
systemctl --user start aegis-dashboard 2>/dev/null || true

echo "Optimized components disabled successfully"
echo "Original components restored"
EOF

    # Make scripts executable
    chmod +x "$SCRIPT_DIR/enable-optimized.sh"
    chmod +x "$SCRIPT_DIR/disable-optimized.sh"
    
    log_success "Optimization scripts created"
}

# Verify installation
verify_installation() {
    log_info "Verifying installation..."
    
    local verification_passed=true
    
    # Check optimized scripts exist
    local scripts=(
        "behavioral-monitor-optimized.sh"
        "behavioral-analysis-optimized.sh"
        "threat-intelligence-optimized.sh"
        "memory-monitor.sh"
        "db-connection-manager.sh"
        "performance-test-optimized.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [ -f "$SCRIPT_DIR/$script" ]; then
            log_success "✓ $script installed"
        else
            log_error "✗ $script missing"
            verification_passed=false
        fi
    done
    
    # Check optimized web dashboard
    if [ -f "$SCRIPT_DIR/../web-dashboard/app.py" ]; then
        log_success "✓ Optimized web dashboard installed"
    else
        log_error "✗ Optimized web dashboard missing"
        verification_passed=false
    fi
    
    # Check services
    if systemctl --user list-unit-files | grep -q "memory-monitor.service"; then
        log_success "✓ Memory monitor service installed"
    else
        log_error "✗ Memory monitor service missing"
        verification_passed=false
    fi
    
    if [ "$verification_passed" = true ]; then
        log_success "Installation verification passed"
        return 0
    else
        log_error "Installation verification failed"
        return 1
    fi
}

# Main installation function
main() {
    log_info "Starting installation of optimized Aegis Security Suite components..."
    log_info "Installation log: $INSTALL_LOG"
    log_info "Backup directory: $BACKUP_DIR"
    
    # Create logs directory
    mkdir -p "$AEGIS_HOME/logs"
    
    # Backup existing files
    backup_existing_files
    
    # Install optimized components
    install_optimized_behavioral_monitoring
    install_optimized_threat_intelligence
    install_optimized_web_dashboard
    install_memory_monitor
    install_db_connection_manager
    install_performance_tools
    
    # Update configuration
    update_configuration
    
    # Create optimization scripts
    create_optimization_scripts
    
    # Verify installation
    if verify_installation; then
        log_success "Optimized components installation completed successfully!"
        echo ""
        echo "Next steps:"
        echo "1. Run '$SCRIPT_DIR/enable-optimized.sh' to enable optimized components"
        echo "2. Run '$SCRIPT_DIR/performance-test-optimized.sh all' to test performance"
        echo "3. Monitor logs in $AEGIS_HOME/logs/"
        echo "4. Check service status with 'systemctl --user status'"
        echo ""
        echo "Backup of original files available at: $BACKUP_DIR"
    else
        log_error "Installation verification failed!"
        echo "Check the installation log: $INSTALL_LOG"
        exit 1
    fi
}

# Handle command line arguments
case "${1:-install}" in
    "install")
        main
        ;;
    "verify")
        verify_installation
        ;;
    "backup")
        backup_existing_files
        ;;
    *)
        echo "Usage: $0 {install|verify|backup}"
        echo "  install - Install optimized components (default)"
        echo "  verify  - Verify installation"
        echo "  backup  - Backup existing files only"
        exit 1
        ;;
esac