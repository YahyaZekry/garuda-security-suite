#!/bin/bash
#
# Complete Interactive Setup for Aegis Security Suite - Version 6.0
# Enhanced with menu-driven installation, comprehensive dependency checking,
# component installation functions, configuration management, and error handling
#
# All issues fixed: existing detection, proper test execution, scheduling, comprehensive validation
#

# Get current timestamp for script naming
SETUP_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
SETUP_DATE=$(date +"%Y-%m-%d")

# Colors for better UX
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Source common functions for user detection
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/scripts/common-functions.sh" ]; then
    source "$SCRIPT_DIR/scripts/common-functions.sh"
fi

# Setup user environment (will set CURRENT_USER, CURRENT_HOME, AEGIS_HOME)
setup_user_environment

# Installation tracking
INSTALLATION_TYPE=""
INSTALLATION_COMPONENTS=()
DEPLOYMENT_MODE=""
ROLLBACK_ENABLED=true
ERROR_LOG="$AEGIS_HOME/logs/installation_errors.log"

# CLI flags bypass the interactive 2-choice menu: --custom for granular
# component selection, --update to update an existing install.
CLI_MODE=""
for arg in "$@"; do
    case "$arg" in
        --custom) CLI_MODE="custom" ;;
        --update) CLI_MODE="update" ;;
        --help|-h)
            echo "Usage: $0 [--custom|--update]"
            echo ""
            echo "  (no flags)  Interactive menu: Single Home User vs Team/Company/Network"
            echo "  --custom    Interactively pick individual components (advanced)"
            echo "  --update    Update an existing Aegis installation"
            exit 0
            ;;
    esac
done

# Path validation function
validate_path() {
    local path="$1"
    local path_type="$2"
    
    if [[ ! "$path" =~ ^/ ]]; then
        echo "Error: $path_type must be absolute path"
        return 1
    fi
    
    if [[ "$path" =~ \.\. ]]; then
        echo "Error: $path_type cannot contain parent directory references"
        return 1
    fi
    
    # Check for dangerous system paths
    local dangerous_paths=("/etc" "/boot" "/sys" "/proc" "/dev")
    for dangerous_path in "${dangerous_paths[@]}"; do
        if [[ "$path" =~ ^$dangerous_path ]]; then
            echo "Error: $path_type contains dangerous system directory"
            return 1
        fi
    done
    
    return 0
}

# Error handling and logging
log_error() {
    local error_message="$1"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    
    # Create log directory if it doesn't exist
    mkdir -p "$(dirname "$ERROR_LOG")"
    
    echo "[$timestamp] ERROR: $error_message" >> "$ERROR_LOG"
    echo -e "${RED}❌ ERROR: $error_message${NC}"
}

log_info() {
    local info_message="$1"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    
    mkdir -p "$(dirname "$ERROR_LOG")"
    echo "[$timestamp] INFO: $info_message" >> "$ERROR_LOG"
    echo -e "${BLUE}ℹ️  INFO: $info_message${NC}"
}

# Rollback function
rollback_installation() {
    if [ "$ROLLBACK_ENABLED" != "true" ]; then
        echo -e "${YELLOW}⚠️  Rollback is disabled${NC}"
        return 1
    fi
    
    echo -e "${RED}🔄 Rolling back installation...${NC}"
    
    # Stop and disable any services that were created
    for component in "${INSTALLATION_COMPONENTS[@]}"; do
        case "$component" in
            "web-dashboard")
                systemctl --user stop aegis-dashboard.service 2>/dev/null || true
                systemctl --user disable aegis-dashboard.service 2>/dev/null || true
                rm -f "$HOME/.config/systemd/user/aegis-dashboard.service" 2>/dev/null
                ;;
            "behavioral-analysis")
                systemctl --user stop behavioral-monitor.service 2>/dev/null || true
                systemctl --user stop behavioral-monitor.timer 2>/dev/null || true
                systemctl --user disable behavioral-monitor.service 2>/dev/null || true
                systemctl --user disable behavioral-monitor.timer 2>/dev/null || true
                rm -f "$HOME/.config/systemd/user/behavioral-monitor.service" 2>/dev/null
                rm -f "$HOME/.config/systemd/user/behavioral-monitor.timer" 2>/dev/null
                ;;
        esac
    done
    
    systemctl --user daemon-reload 2>/dev/null || true
    
    # Remove created directories
    if [ -d "$AEGIS_HOME" ]; then
        mv "$AEGIS_HOME" "$AEGIS_HOME.failed_$(date +%s)" 2>/dev/null || true
    fi
    
    echo -e "${GREEN}✅ Rollback completed${NC}"
    return 0
}

# Progress indicator with spinner
show_progress_with_spinner() {
    local message="$1"
    local pid=$2
    local delay=0.1
    local spinstr='|/-\'
    
    echo -ne "${YELLOW}⏳ $message... ${NC}"
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]" "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Enhanced validation functions
show_progress() {
    local message=$1
    echo -e "${YELLOW}⏳ $message...${NC}"
}

show_success() {
    local message=$1
    echo -e "${GREEN}✅ $message${NC}"
}

show_warning() {
    local message=$1
    echo -e "${YELLOW}⚠️  $message${NC}"
}

show_error() {
    local message=$1
    log_error "$message"
}

show_info() {
    local message=$1
    log_info "$message"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    show_error "Please do NOT run this script as root!"
    echo -e "${YELLOW}💡 The script will ask for sudo password when needed.${NC}"
    exit 1
fi

# Comprehensive dependency checking
check_system_dependencies() {
    echo -e "${BLUE}🔍 Checking system dependencies...${NC}"
    echo ""
    
    local system_deps=("systemd" "sqlite3" "curl" "wget" "python3" "python-pip")
    local missing_system_deps=()
    local optional_system_deps=("nginx" "ufw" "firewalld")
    local missing_optional_deps=()
    
    # Check required system dependencies
    for dep in "${system_deps[@]}"; do
        if command -v "$dep" &>/dev/null || pacman -Qi "$dep" &>/dev/null; then
            echo -e "${GREEN}✅ $dep - Available${NC}"
        else
            echo -e "${RED}❌ $dep - Missing${NC}"
            missing_system_deps+=("$dep")
        fi
    done
    
    echo ""
    echo -e "${YELLOW}Optional dependencies:${NC}"
    
    # Check optional system dependencies
    for dep in "${optional_system_deps[@]}"; do
        if command -v "$dep" &>/dev/null || pacman -Qi "$dep" &>/dev/null; then
            echo -e "${GREEN}✅ $dep - Available (optional)${NC}"
        else
            echo -e "${YELLOW}⏳ $dep - Not installed (optional)${NC}"
            missing_optional_deps+=("$dep")
        fi
    done
    
    echo ""
    
    # Install missing required dependencies
    if [ ${#missing_system_deps[@]} -gt 0 ]; then
        echo -e "${RED}❌ Missing required dependencies: ${missing_system_deps[*]}${NC}"
        read -p "Install missing required dependencies? (Y/n): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            show_progress "Installing required system dependencies"
            if sudo pacman -Sy --needed --noconfirm "${missing_system_deps[@]}"; then
                show_success "Required dependencies installed"
            else
                show_error "Failed to install required dependencies"
                return 1
            fi
        else
            show_error "Required dependencies are needed for proper operation"
            return 1
        fi
    fi
    
    # Offer optional dependencies
    if [ ${#missing_optional_deps[@]} -gt 0 ]; then
        echo -e "${YELLOW}Optional dependencies available: ${missing_optional_deps[*]}${NC}"
        read -p "Install optional dependencies? (y/N): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            show_progress "Installing optional dependencies"
            sudo pacman -Sy --needed --noconfirm "${missing_optional_deps[@]}" || true
            show_success "Optional dependencies installation attempted"
        fi
    fi
    
    return 0
}

# Check security tools
check_security_tools_dependencies() {
    echo -e "${BLUE}🔍 Checking security tools...${NC}"
    echo ""
    
    local security_tools=("clamav" "rkhunter" "chkrootkit" "lynis")
    local missing_security_tools=()
    
    for tool in "${security_tools[@]}"; do
        if pacman -Qi "$tool" &>/dev/null; then
            echo -e "${GREEN}✅ $tool - Installed${NC}"
        else
            echo -e "${YELLOW}⏳ $tool - Not installed${NC}"
            missing_security_tools+=("$tool")
        fi
    done
    
    echo ""
    
    if [ ${#missing_security_tools[@]} -gt 0 ]; then
        echo -e "${YELLOW}Missing security tools: ${missing_security_tools[*]}${NC}"
        read -p "Install missing security tools? (Y/n): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            show_progress "Installing security tools"
            if sudo pacman -Sy --needed --noconfirm "${missing_security_tools[@]}"; then
                show_success "Security tools installed"
            else
                show_error "Failed to install security tools"
                return 1
            fi
        fi
    fi
    
    return 0
}

# Check Python dependencies for web dashboard
check_python_dependencies() {
    echo -e "${BLUE}🔍 Checking Python availability...${NC}"
    echo ""

    if ! command -v python3 &>/dev/null; then
        show_error "Python 3 is required but not installed"
        return 1
    fi

    if ! python3 -m venv --help &>/dev/null; then
        show_error "python3's venv module is required but not available (try: sudo pacman -S python)"
        return 1
    fi

    show_success "Python 3 available"

    # Flask/psutil/etc. are installed from web-dashboard/requirements.txt into
    # a dedicated virtual environment further down in install_web_dashboard() -
    # never system-wide. An earlier version of this check tried to `pip
    # install` them directly onto the system Python, which fails with
    # "externally-managed-environment" on any PEP 668 distro (Arch, Debian
    # 12+, Ubuntu 23.04+, Fedora 38+, ...).
    return 0
}

# Menu-driven installation options
# Ask who the install is for and set the global DEPLOYMENT_MODE (single_user
# or team). Shared by the main menu's two choices and by --custom when it
# picks up web-dashboard, so the question is only ever asked one way.
ask_deployment_mode() {
    echo ""
    echo "Is this Aegis dashboard for a single home user, or a team/whole-system deployment?"
    echo "  Single user: simple per-user service, no reverse proxy or firewall changes."
    echo "  Team: dedicated service account, nginx reverse proxy, firewall rules."
    read -p "Team/whole-system deployment? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        DEPLOYMENT_MODE="team"
    else
        DEPLOYMENT_MODE="single_user"
    fi
}

show_installation_menu() {
    clear
    echo -e "${CYAN}================================================================${NC}"
    echo -e "${WHITE}      🛡️ WHO IS THIS AEGIS INSTALLATION FOR? 🛡️${NC}"
    echo -e "${CYAN}================================================================${NC}"
    echo ""
    echo -e "${CYAN}1)${NC} Single Home User"
    echo -e "   • Full feature set: scanning, dashboard, behavioral analysis,"
    echo -e "     incident response, threat intelligence, scheduling"
    echo -e "   • Simple install - no reverse proxy or firewall changes"
    echo ""
    echo -e "${CYAN}2)${NC} Team / Company / Network"
    echo -e "   • Same full feature set"
    echo -e "   • Server-grade install - dedicated service account, nginx"
    echo -e "     reverse proxy, firewall rules"
    echo ""
    echo -e "${CYAN}0)${NC} Exit"
    echo ""
    echo -e "${BLUE}(Run with --custom to pick individual components, --update to update an existing install)${NC}"
    echo ""

    while true; do
        read -p "Enter your choice (0-2): " choice
        case $choice in
            1)
                INSTALLATION_TYPE="complete"
                DEPLOYMENT_MODE="single_user"
                INSTALLATION_COMPONENTS=("security-tools" "web-dashboard" "behavioral-analysis" "incident-response" "threat-intelligence" "scheduling")
                return 0
                ;;
            2)
                INSTALLATION_TYPE="complete"
                DEPLOYMENT_MODE="team"
                INSTALLATION_COMPONENTS=("security-tools" "web-dashboard" "behavioral-analysis" "incident-response" "threat-intelligence" "scheduling")
                return 0
                ;;
            0)
                echo -e "${BLUE}👋 Exiting setup${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice. Please enter 0, 1, or 2.${NC}"
                ;;
        esac
    done
}

# Custom component selection menu
show_custom_component_menu() {
    clear
    echo -e "${CYAN}================================================================${NC}"
    echo -e "${WHITE}      🔧 CUSTOM COMPONENT SELECTION 🔧${NC}"
    echo -e "${CYAN}================================================================${NC}"
    echo ""
    echo -e "${GREEN}Select components to install:${NC}"
    echo ""
    
    local components=(
        "security-tools:Security scanning tools (ClamAV, rkhunter, chkrootkit, Lynis)"
        "web-dashboard:Python Flask web dashboard"
        "behavioral-analysis:Behavioral monitoring and analysis"
        "incident-response:Incident response system"
        "threat-intelligence:Threat intelligence integration"
        "scheduling:Automated scanning schedules"
    )
    
    INSTALLATION_COMPONENTS=()
    
    for component in "${components[@]}"; do
        local name=$(echo "$component" | cut -d: -f1)
        local desc=$(echo "$component" | cut -d: -f2)
        
        read -p "Install $desc? (Y/n): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            INSTALLATION_COMPONENTS+=("$name")
            echo -e "${GREEN}✅ $name selected${NC}"
        else
            echo -e "${YELLOW}⏭️  $name skipped${NC}"
        fi
        echo ""
    done
    
    if [ ${#INSTALLATION_COMPONENTS[@]} -eq 0 ]; then
        echo -e "${RED}❌ No components selected${NC}"
        exit 1
    fi

    echo -e "${GREEN}Selected components: ${INSTALLATION_COMPONENTS[*]}${NC}"

    # Only ask deployment mode if the dashboard is actually part of this
    # custom install - it's meaningless otherwise.
    if [[ " ${INSTALLATION_COMPONENTS[*]} " =~ " web-dashboard " ]]; then
        ask_deployment_mode
    fi
}

# Component installation functions

# Install security tools
install_security_tools() {
    show_progress "Installing security tools component"
    
    # Check dependencies first
    check_security_tools_dependencies || return 1
    
    # Create directory structure
    mkdir -p "$AEGIS_HOME"/{scripts,logs,configs,backups}
    mkdir -p "$AEGIS_HOME/logs"/{daily,weekly,monthly,manual}
    mkdir -p "$AEGIS_HOME/scripts/scanners"
    
    # Install scanner scripts
    local scanners=("clamav-scanner.sh" "rkhunter-scanner.sh")
    for scanner in "${scanners[@]}"; do
        if [ -f "$SCRIPT_DIR/scanners/$scanner" ]; then
            cp "$SCRIPT_DIR/scanners/$scanner" "$AEGIS_HOME/scripts/scanners/"
            chmod +x "$AEGIS_HOME/scripts/scanners/$scanner"
            show_success "Installed $scanner"
        fi
    done
    
    # Create main security scripts
    create_security_scan_scripts
    
    # Create configuration template
    create_security_config_template
    
    show_success "Security tools component installed"
    return 0
}

# Install web dashboard
install_web_dashboard() {
    show_progress "Installing web dashboard component"

    # DEPLOYMENT_MODE is set by the top-level menu (or --custom's
    # ask_deployment_mode call) before we get here - it decides both which
    # service-install path runs below and what the dashboard's own Settings
    # default to. Fall back to asking directly only if this function is
    # somehow reached without it already set.
    if [ -z "$DEPLOYMENT_MODE" ]; then
        ask_deployment_mode
    fi
    local deployment_mode="$DEPLOYMENT_MODE"

    # Check Python dependencies
    check_python_dependencies || return 1

    # Copy web dashboard files BEFORE creating the venv, and always strip
    # any venv/ that comes along with them. A dev venv must never ship
    # inside the source tree, but one did for real here (a years-old,
    # root-owned venv/ sitting in web-dashboard/, left from before the
    # project was even renamed) - it got copied on top of a freshly
    # pip-installed target venv, silently overwriting its pip/pyvenv.cfg
    # with stale ones and causing pip to fall through to the system Python,
    # which then hit PEP 668's "externally-managed-environment" error.
    mkdir -p "$AEGIS_HOME/web-dashboard"
    if [ -d "$SCRIPT_DIR/web-dashboard" ]; then
        cp -r "$SCRIPT_DIR/web-dashboard"/* "$AEGIS_HOME/web-dashboard/"
        rm -rf "$AEGIS_HOME/web-dashboard/venv"
        show_success "Copied web dashboard files"
    fi

    # Create the Python virtual environment fresh every time, now that
    # nothing can land on top of it afterward.
    local venv_path="$AEGIS_HOME/web-dashboard/venv"
    python3 -m venv "$venv_path"
    show_success "Created Python virtual environment"

    # Activate virtual environment and install requirements
    source "$venv_path/bin/activate"

    if [ -f "$SCRIPT_DIR/web-dashboard/requirements.txt" ]; then
        if command -v pip3 &>/dev/null; then
            pip3 install -r "$SCRIPT_DIR/web-dashboard/requirements.txt"
        else
            pip install -r "$SCRIPT_DIR/web-dashboard/requirements.txt"
        fi
        show_success "Installed Python requirements"
    else
        # Install basic requirements
        if command -v pip3 &>/dev/null; then
            pip3 install flask requests psutil
        else
            pip install flask requests psutil
        fi
        show_success "Installed basic Python requirements"
    fi

    # Seed the dashboard's own deployment_mode setting so Settings shows the
    # right default from first boot (api/config.py also defaults to
    # 'single_user' if this is never written, so this is a no-op for that case).
    mkdir -p "$AEGIS_HOME/configs/web-dashboard"
    python3 -c "
import json, os
path = os.path.join('$AEGIS_HOME', 'configs', 'web-dashboard', 'dashboard.conf')
data = {}
if os.path.exists(path):
    with open(path) as f:
        data = json.load(f)
data['deployment_mode'] = '$deployment_mode'
with open(path, 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null || true

    if [ "$deployment_mode" = "team" ] && [ -f "$SCRIPT_DIR/web-dashboard/install-dashboard.sh" ]; then
        show_progress "Team mode selected - running the full server-grade installer (dedicated service account, nginx, firewall)"
        bash "$SCRIPT_DIR/web-dashboard/install-dashboard.sh"
    else
        # Create dashboard configuration
        create_dashboard_config

        # Install systemd service
        install_dashboard_service
    fi

    # Create API endpoints
    create_dashboard_api

    show_success "Web dashboard component installed"
    return 0
}

# Install behavioral analysis
install_behavioral_analysis() {
    show_progress "Installing behavioral analysis component"
    
    # Create behavioral analysis directories
    mkdir -p "$AEGIS_HOME/configs/behavioral_analysis"
    mkdir -p "$AEGIS_HOME/logs/behavioral"
    
    # Copy behavioral analysis scripts
    if [ -f "$SCRIPT_DIR/behavioral-analysis-optimized.sh" ]; then
        cp "$SCRIPT_DIR/behavioral-analysis-optimized.sh" "$AEGIS_HOME/scripts/"
        chmod +x "$AEGIS_HOME/scripts/behavioral-analysis-optimized.sh"
        show_success "Installed behavioral analysis script"
    fi

    if [ -f "$SCRIPT_DIR/behavioral-monitor-optimized.sh" ]; then
        cp "$SCRIPT_DIR/behavioral-monitor-optimized.sh" "$AEGIS_HOME/scripts/"
        chmod +x "$AEGIS_HOME/scripts/behavioral-monitor-optimized.sh"
        show_success "Installed behavioral monitor script"
    fi
    
    # Create behavioral analysis configuration
    create_behavioral_config
    
    # Install systemd service and timer
    install_behavioral_service
    
    show_success "Behavioral analysis component installed"
    return 0
}

# Install incident response
install_incident_response() {
    show_progress "Installing incident response component"
    
    # Create incident response directories
    mkdir -p "$AEGIS_HOME/configs/incident_response"
    mkdir -p "$AEGIS_HOME/logs/incidents"
    mkdir -p "$AEGIS_HOME/evidence"
    
    # Copy incident response scripts
    if [ -f "$SCRIPT_DIR/incident-response.sh" ]; then
        cp "$SCRIPT_DIR/incident-response.sh" "$AEGIS_HOME/scripts/"
        chmod +x "$AEGIS_HOME/scripts/incident-response.sh"
        show_success "Installed incident response script"
    fi
    
    # Create incident response configuration
    create_incident_response_config
    
    show_success "Incident response component installed"
    return 0
}

# Install threat intelligence
install_threat_intelligence() {
    show_progress "Installing threat intelligence component"
    
    # Create threat intelligence directories
    mkdir -p "$AEGIS_HOME/configs/threat_intelligence"
    mkdir -p "$AEGIS_HOME/configs/threat_intelligence/cache"
    mkdir -p "$AEGIS_HOME/logs/threat_intelligence"
    
    # Copy threat intelligence scripts
    if [ -f "$SCRIPT_DIR/threat-intelligence-optimized.sh" ]; then
        cp "$SCRIPT_DIR/threat-intelligence-optimized.sh" "$AEGIS_HOME/scripts/"
        chmod +x "$AEGIS_HOME/scripts/threat-intelligence-optimized.sh"
        show_success "Installed threat intelligence script"
    fi
    
    # Create threat intelligence configuration
    create_threat_intelligence_config
    
    show_success "Threat intelligence component installed"
    return 0
}

# Install scheduling
install_scheduling() {
    show_progress "Installing scheduling component"
    
    # Create systemd timers for automated scanning
    create_systemd_timers
    
    # Enable timers
    enable_systemd_timers
    
    show_success "Scheduling component installed"
    return 0
}

# Configuration management functions

# Create security configuration template
create_security_config_template() {
    local config_file="$AEGIS_HOME/configs/security-config.conf"
    
    cat > "$config_file" << EOF
# Aegis Security Suite Configuration Template
# Generated on: $SETUP_TIMESTAMP

# Dynamic path configuration
AEGIS_HOME="$AEGIS_HOME"
SCRIPTS_DIR="\$AEGIS_HOME/scripts"
LOGS_DIR="\$AEGIS_HOME/logs"
CONFIGS_DIR="\$AEGIS_HOME/configs"
BACKUPS_DIR="\$AEGIS_HOME/backups"
CURRENT_USER="$CURRENT_USER"
CURRENT_HOME="$CURRENT_HOME"

# Security tools configuration
CLAMAV_ENABLED=true
RKHUNTER_ENABLED=true
CHKROOTKIT_ENABLED=true
LYNIS_ENABLED=true

# Scanning preferences
UPDATE_BEFORE_SCAN=true
REAL_TIME_FEEDBACK=true
AUTO_CLEANUP_LOGS=false
MAX_LOG_AGE_DAYS=30

# Notification settings
NOTIFICATIONS_ENABLED=true
NOTIFICATION_URGENCY="normal"

# Scan directories
DAILY_SCAN_DIRS=("$HOME/Documents" "$HOME/Downloads" "$HOME/Desktop" "$HOME/.config")
WEEKLY_SCAN_DIRS=("$HOME")
MONTHLY_SCAN_DIRS=("$HOME" "/tmp" "/var/tmp")

# Scheduling configuration
ENABLE_SCHEDULING=false
DAILY_TIME="09:00"
WEEKLY_TIME="10:00"
WEEKLY_DAY="Mon"
MONTHLY_TIME="11:00"
MONTHLY_DAY="1"
EOF

    chmod 644 "$config_file"
    show_success "Created security configuration template"
}

# Create dashboard configuration
create_dashboard_config() {
    local config_file="$AEGIS_HOME/web-dashboard/config/dashboard.conf"
    
    mkdir -p "$(dirname "$config_file")"
    
    cat > "$config_file" << EOF
# Web Dashboard Configuration
# Generated on: $SETUP_TIMESTAMP

[dashboard]
host = 127.0.0.1
port = 8080
debug = false
secret_key = $(python3 -c "import secrets; print(secrets.token_hex(32))")

[database]
path = $AEGIS_HOME/web-dashboard/dashboard.db
backup_enabled = true
backup_interval = 24

[security]
enable_auth = true
session_timeout = 3600
max_login_attempts = 5

[logging]
level = INFO
file = $AEGIS_HOME/logs/dashboard.log
max_size = 10MB
backup_count = 5
EOF

    chmod 644 "$config_file"
    show_success "Created dashboard configuration"
}

# Create behavioral analysis configuration
create_behavioral_config() {
    local config_file="$AEGIS_HOME/configs/behavioral_analysis/config.conf"
    
    cat > "$config_file" << EOF
# Behavioral Analysis Configuration
# Generated on: $SETUP_TIMESTAMP

[monitoring]
enabled = true
learning_period = 7
monitoring_interval = 60
sensitivity_level = medium
threat_score_threshold = 70
max_baseline_age = 30

[alerts]
enabled = true
notification_methods = ["desktop", "log"]
alert_cooldown = 300

[baseline]
auto_update = true
update_interval = 86400
min_samples = 100
EOF

    chmod 644 "$config_file"
    show_success "Created behavioral analysis configuration"
}

# Create incident response configuration
create_incident_response_config() {
    local config_file="$AEGIS_HOME/configs/incident_response/config.conf"
    
    cat > "$config_file" << EOF
# Incident Response Configuration
# Generated on: $SETUP_TIMESTAMP

[response]
auto_containment = false
evidence_preservation = true
notification_enabled = true

[escalation]
levels = ["low", "medium", "high", "critical"]
auto_escalate = true
escalation_timeout = 3600

[reporting]
template_path = "$AEGIS_HOME/configs/incident_response/templates"
output_format = ["json", "html"]
auto_generate = true
EOF

    chmod 644 "$config_file"
    show_success "Created incident response configuration"
}

# Create threat intelligence configuration
create_threat_intelligence_config() {
    local config_file="$AEGIS_HOME/configs/threat_intelligence/config.conf"
    
    cat > "$config_file" << EOF
# Threat Intelligence Configuration
# Generated on: $SETUP_TIMESTAMP

[sources]
enabled_sources = ["virustotal", "alienvault", "hybrid-analysis"]
update_interval = 3600
cache_duration = 86400

[api_keys]
# Add your API keys here
# virustotal = "your_api_key_here"
# alienault = "your_api_key_here"

[analysis]
enable_reputation_checking = true
enable_ioc_matching = true
threat_score_threshold = 70
EOF

    chmod 644 "$config_file"
    show_success "Created threat intelligence configuration"
}

# Service installation functions

# Install dashboard service
install_dashboard_service() {
    local service_file="$HOME/.config/systemd/user/aegis-dashboard.service"
    local template_file="$SCRIPT_DIR/web-dashboard/aegis-dashboard.service"
    
    mkdir -p "$(dirname "$service_file")"
    
    # Use service template processor if available
    if [ -f "$SCRIPT_DIR/scripts/process-service-template.sh" ]; then
        "$SCRIPT_DIR/scripts/process-service-template.sh" process "$template_file" "$service_file" "$CURRENT_USER"
    else
        # Fallback to manual creation
        cat > "$service_file" << EOF
[Unit]
Description=Aegis Security Dashboard
After=network-online.target

[Service]
Type=simple
User=$CURRENT_USER
WorkingDirectory=$AEGIS_HOME/web-dashboard
ExecStart=$AEGIS_HOME/web-dashboard/venv/bin/python app.py
Restart=always
RestartSec=10
Environment=PYTHONPATH=$AEGIS_HOME/web-dashboard
Environment=FLASK_ENV=production

[Install]
WantedBy=default.target
EOF
    fi

    chmod 644 "$service_file"
    systemctl --user daemon-reload
    show_success "Installed dashboard service"
}

# Install behavioral analysis service
install_behavioral_service() {
    local service_file="$HOME/.config/systemd/user/behavioral-monitor.service"
    local timer_file="$HOME/.config/systemd/user/behavioral-monitor.timer"
    local template_file="$SCRIPT_DIR/scripts/behavioral-monitor-optimized.service"
    
    mkdir -p "$(dirname "$service_file")"
    
    # Use service template processor if available
    if [ -f "$SCRIPT_DIR/scripts/process-service-template.sh" ]; then
        "$SCRIPT_DIR/scripts/process-service-template.sh" process "$template_file" "$service_file" "$CURRENT_USER"
    else
        # Fallback to manual creation
        cat > "$service_file" << EOF
[Unit]
Description=Behavioral Analysis Monitor
After=network-online.target

[Service]
Type=oneshot
ExecStart=$AEGIS_HOME/scripts/behavioral-monitor-optimized.sh
WorkingDirectory=$AEGIS_HOME/scripts
StandardOutput=journal
StandardError=journal
Environment=USER=$CURRENT_USER
Environment=HOME=$CURRENT_HOME
Environment=AEGIS_HOME=$AEGIS_HOME

[Install]
WantedBy=default.target
EOF
    fi

    # Create timer file
    cat > "$timer_file" << EOF
[Unit]
Description=Behavioral Analysis Monitor Timer
Requires=behavioral-monitor.service

[Timer]
OnCalendar=*:*:00/15
Persistent=true

[Install]
WantedBy=timers.target
EOF

    chmod 644 "$service_file"
    chmod 644 "$timer_file"
    systemctl --user daemon-reload
    show_success "Installed behavioral analysis service and timer"
}

# Create security scan scripts
create_security_scan_scripts() {
    # Create daily scan script
    cat > "$AEGIS_HOME/scripts/security-daily-scan.sh" << 'EOF'
#!/bin/bash
# Daily Security Scan Script

# Load configuration
if [ -f "$AEGIS_HOME/configs/security-config.conf" ]; then
    source "$AEGIS_HOME/configs/security-config.conf"
fi

# Load notification functions
if [ -f "$AEGIS_HOME/scripts/notification-functions.sh" ]; then
    source "$AEGIS_HOME/scripts/notification-functions.sh"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

echo -e "${CYAN}==========================================${NC}"
echo -e "${WHITE}  🛡️ Daily Security Scan${NC}"
echo -e "${CYAN}==========================================${NC}"
echo -e "${BLUE}Scan started: $(date)${NC}"
echo ""

# Create log file
timestamp=$(date +"%Y%m%d_%H%M%S")
SCAN_LOG="$AEGIS_HOME/logs/daily/daily_scan_${timestamp}.log"

echo "Daily Security Scan - $(date)" > "$SCAN_LOG"
echo "=================================" >> "$SCAN_LOG"
echo "" >> "$SCAN_LOG"

# Run ClamAV scan if enabled
if [ "$CLAMAV_ENABLED" = "true" ] && command -v clamscan &>/dev/null; then
    echo -e "${YELLOW}🦠 Running ClamAV scan...${NC}"
    for dir in "${DAILY_SCAN_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            echo -e "${BLUE}Scanning: $dir${NC}"
            clamscan -r "$dir" >> "$SCAN_LOG" 2>&1
        fi
    done
    echo -e "${GREEN}✅ ClamAV scan completed${NC}"
fi

# Run rkhunter if enabled
if [ "$RKHUNTER_ENABLED" = "true" ] && command -v rkhunter &>/dev/null; then
    echo -e "${YELLOW}🔍 Running rkhunter scan...${NC}"
    rkhunter --check --skip-keypress --report-warnings-only >> "$SCAN_LOG" 2>&1
    echo -e "${GREEN}✅ rkhunter scan completed${NC}"
fi

echo ""
echo -e "${GREEN}✅ Daily security scan completed${NC}"
echo -e "${BLUE}📂 Log saved to: $(basename "$SCAN_LOG")${NC}"
EOF

    # Create weekly scan script
    cat > "$AEGIS_HOME/scripts/security-weekly-scan.sh" << 'EOF'
#!/bin/bash
# Weekly Security Scan Script

# Load configuration
if [ -f "$AEGIS_HOME/configs/security-config.conf" ]; then
    source "$AEGIS_HOME/configs/security-config.conf"
fi

# Load notification functions
if [ -f "$AEGIS_HOME/scripts/notification-functions.sh" ]; then
    source "$AEGIS_HOME/scripts/notification-functions.sh"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

echo -e "${CYAN}==========================================${NC}"
echo -e "${WHITE}  🛡️ Weekly Security Scan${NC}"
echo -e "${CYAN}==========================================${NC}"
echo -e "${BLUE}Scan started: $(date)${NC}"
echo ""

# Create log file
timestamp=$(date +"%Y%m%d_%H%M%S")
SCAN_LOG="$AEGIS_HOME/logs/weekly/weekly_scan_${timestamp}.log"

echo "Weekly Security Scan - $(date)" > "$SCAN_LOG"
echo "================================" >> "$SCAN_LOG"
echo "" >> "$SCAN_LOG"

# Run comprehensive scan
for dir in "${WEEKLY_SCAN_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo -e "${BLUE}Scanning: $dir${NC}"
        
        # ClamAV scan
        if [ "$CLAMAV_ENABLED" = "true" ] && command -v clamscan &>/dev/null; then
            clamscan -r "$dir" >> "$SCAN_LOG" 2>&1
        fi
        
        # Additional checks can be added here
    fi
done

echo ""
echo -e "${GREEN}✅ Weekly security scan completed${NC}"
echo -e "${BLUE}📂 Log saved to: $(basename "$SCAN_LOG")${NC}"
EOF

    # Create monthly scan script
    cat > "$AEGIS_HOME/scripts/security-monthly-scan.sh" << 'EOF'
#!/bin/bash
# Monthly Security Scan Script

# Load configuration
if [ -f "$AEGIS_HOME/configs/security-config.conf" ]; then
    source "$AEGIS_HOME/configs/security-config.conf"
fi

# Load notification functions
if [ -f "$AEGIS_HOME/scripts/notification-functions.sh" ]; then
    source "$AEGIS_HOME/scripts/notification-functions.sh"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

echo -e "${CYAN}==========================================${NC}"
echo -e "${WHITE}  🛡️ Monthly Security Scan${NC}"
echo -e "${CYAN}==========================================${NC}"
echo -e "${BLUE}Scan started: $(date)${NC}"
echo ""

# Create log file
timestamp=$(date +"%Y%m%d_%H%M%S")
SCAN_LOG="$AEGIS_HOME/logs/monthly/monthly_scan_${timestamp}.log"

echo "Monthly Security Scan - $(date)" > "$SCAN_LOG"
echo "=================================" >> "$SCAN_LOG"
echo "" >> "$SCAN_LOG"

# Run comprehensive system scan
for dir in "${MONTHLY_SCAN_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo -e "${BLUE}Scanning: $dir${NC}"
        
        # ClamAV scan
        if [ "$CLAMAV_ENABLED" = "true" ] && command -v clamscan &>/dev/null; then
            clamscan -r "$dir" >> "$SCAN_LOG" 2>&1
        fi
        
        # rkhunter scan
        if [ "$RKHUNTER_ENABLED" = "true" ] && command -v rkhunter &>/dev/null; then
            rkhunter --check --skip-keypress >> "$SCAN_LOG" 2>&1
        fi
        
        # chkrootkit scan
        if [ "$CHKROOTKIT_ENABLED" = "true" ] && command -v chkrootkit &>/dev/null; then
            chkrootkit >> "$SCAN_LOG" 2>&1
        fi
        
        # Lynis audit
        if [ "$LYNIS_ENABLED" = "true" ] && command -v lynis &>/dev/null; then
            lynis audit system --quick >> "$SCAN_LOG" 2>&1
        fi
    fi
done

echo ""
echo -e "${GREEN}✅ Monthly security scan completed${NC}"
echo -e "${BLUE}📂 Log saved to: $(basename "$SCAN_LOG")${NC}"
EOF

    # Make scripts executable
    chmod +x "$AEGIS_HOME/scripts/security-daily-scan.sh"
    chmod +x "$AEGIS_HOME/scripts/security-weekly-scan.sh"
    chmod +x "$AEGIS_HOME/scripts/security-monthly-scan.sh"
    
    show_success "Created security scan scripts"
}

# Create systemd timers
create_systemd_timers() {
    show_progress "Creating systemd timers"
    
    # Create daily timer
    cat > "$HOME/.config/systemd/user/security-daily-scan.timer" << EOF
[Unit]
Description=Daily Security Scan Timer
Requires=security-daily-scan.service

[Timer]
OnCalendar=*-*-* 09:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # Create weekly timer
    cat > "$HOME/.config/systemd/user/security-weekly-scan.timer" << EOF
[Unit]
Description=Weekly Security Scan Timer
Requires=security-weekly-scan.service

[Timer]
OnCalendar=Mon *-*-* 10:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # Create monthly timer
    cat > "$HOME/.config/systemd/user/security-monthly-scan.timer" << EOF
[Unit]
Description=Monthly Security Scan Timer
Requires=security-monthly-scan.service

[Timer]
OnCalendar=*-*-1 11:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # Create service files
    for scan_type in daily weekly monthly; do
        cat > "$HOME/.config/systemd/user/security-${scan_type}-scan.service" << EOF
[Unit]
Description=${scan_type^} Security Scan

[Service]
Type=oneshot
ExecStart=$AEGIS_HOME/scripts/security-${scan_type}-scan.sh
WorkingDirectory=$AEGIS_HOME/scripts
StandardOutput=journal
StandardError=journal
Environment=USER=$CURRENT_USER
Environment=HOME=$CURRENT_HOME
Environment=AEGIS_HOME=$AEGIS_HOME
EOF
    done

    systemctl --user daemon-reload
    show_success "Created systemd timers"
}

# Enable systemd timers
enable_systemd_timers() {
    show_progress "Enabling systemd timers"
    
    # Enable timers
    systemctl --user enable security-daily-scan.timer
    systemctl --user enable security-weekly-scan.timer
    systemctl --user enable security-monthly-scan.timer
    
    # Start timers
    systemctl --user start security-daily-scan.timer
    systemctl --user start security-weekly-scan.timer
    systemctl --user start security-monthly-scan.timer
    
    show_success "Enabled systemd timers"
}

# Create dashboard API endpoints
create_dashboard_api() {
    local api_dir="$AEGIS_HOME/web-dashboard/api"
    mkdir -p "$api_dir"
    
    # Create system API
    cat > "$api_dir/system.py" << 'EOF'
#!/usr/bin/env python3
"""
System API endpoints for Aegis Security Dashboard
"""

import os
import subprocess
import psutil
from datetime import datetime
from flask import Blueprint, jsonify, request

system_bp = Blueprint('system', __name__)

@system_bp.route('/api/system/info', methods=['GET'])
def get_system_info():
    """Get basic system information"""
    try:
        info = {
            'hostname': os.uname().nodename,
            'platform': os.uname().sysname,
            'release': os.uname().release,
            'architecture': os.uname().machine,
            'cpu_count': psutil.cpu_count(),
            'memory_total': psutil.virtual_memory().total,
            'disk_usage': psutil.disk_usage('/').percent,
            'timestamp': datetime.now().isoformat()
        }
        return jsonify(info)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@system_bp.route('/api/system/processes', methods=['GET'])
def get_processes():
    """Get running processes"""
    try:
        processes = []
        for proc in psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_percent']):
            try:
                processes.append(proc.info)
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue
        return jsonify(processes)
    except Exception as e:
        return jsonify({'error': str(e)}), 500
EOF

    # Create incidents API
    cat > "$api_dir/incidents.py" << 'EOF'
#!/usr/bin/env python3
"""
Incidents API endpoints for Aegis Security Dashboard
"""

import os
import json
from datetime import datetime
from flask import Blueprint, jsonify, request

incidents_bp = Blueprint('incidents', __name__)

@incidents_bp.route('/api/incidents', methods=['GET'])
def get_incidents():
    """Get security incidents"""
    try:
        incidents_dir = os.environ.get('AEGIS_HOME', os.path.expanduser('~/aegis-security-suite'))
        incidents_file = os.path.join(incidents_dir, 'logs', 'incidents.json')
        
        incidents = []
        if os.path.exists(incidents_file):
            with open(incidents_file, 'r') as f:
                incidents = json.load(f)
        
        return jsonify(incidents)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@incidents_bp.route('/api/incidents', methods=['POST'])
def create_incident():
    """Create a new incident"""
    try:
        incident_data = request.get_json()
        
        incidents_dir = os.environ.get('AEGIS_HOME', os.path.expanduser('~/aegis-security-suite'))
        incidents_file = os.path.join(incidents_dir, 'logs', 'incidents.json')
        
        incidents = []
        if os.path.exists(incidents_file):
            with open(incidents_file, 'r') as f:
                incidents = json.load(f)
        
        incident = {
            'id': len(incidents) + 1,
            'timestamp': datetime.now().isoformat(),
            'status': 'open',
            **incident_data
        }
        
        incidents.append(incident)
        
        os.makedirs(os.path.dirname(incidents_file), exist_ok=True)
        with open(incidents_file, 'w') as f:
            json.dump(incidents, f, indent=2)
        
        return jsonify(incident), 201
    except Exception as e:
        return jsonify({'error': str(e)}), 500
EOF

    show_success "Created dashboard API endpoints"
}

# Configuration validation
validate_configuration() {
    show_progress "Validating configuration"
    
    local config_file="$AEGIS_HOME/configs/security-config.conf"
    local validation_errors=()
    
    if [ ! -f "$config_file" ]; then
        validation_errors+=("Configuration file not found: $config_file")
    else
        # Check required configuration variables
        local required_vars=("AEGIS_HOME" "SCRIPTS_DIR" "LOGS_DIR")
        for var in "${required_vars[@]}"; do
            if ! grep -q "^$var=" "$config_file"; then
                validation_errors+=("Missing required variable: $var")
            fi
        done
    fi
    
    if [ ${#validation_errors[@]} -gt 0 ]; then
        show_error "Configuration validation failed:"
        for error in "${validation_errors[@]}"; do
            echo -e "${RED}  • $error${NC}"
        done
        return 1
    fi
    
    show_success "Configuration validation passed"
    return 0
}

# Set proper file permissions
set_file_permissions() {
    show_progress "Setting file permissions"

    # Never run a recursive chmod over a directory that isn't actually the
    # suite. A path-resolution bug once set AEGIS_HOME to the repo's
    # parent directory and this function chmod'ed every sibling project in it.
    # configs/ and scripts/ are unconditionally created early in the main
    # install flow, before any component installs - unlike setup-aegis.sh or
    # common-functions.sh, which this installer never copies into the
    # target directory, so those can't be used as install markers here.
    if [ ! -d "$AEGIS_HOME/configs" ] && [ ! -d "$AEGIS_HOME/scripts" ]; then
        show_error "Refusing to set permissions: $AEGIS_HOME does not look like an Aegis installation"
        return 1
    fi

    # Some mounts (NTFS/exFAT) don't support chmod at all - probe once and
    # skip the pass instead of spamming an error per file.
    if ! chmod u+rw "$AEGIS_HOME" 2>/dev/null; then
        show_warning "Filesystem does not support chmod ($AEGIS_HOME) - skipping permission pass"
        return 0
    fi

    # Scope to the suite's own directories and skip Python virtualenvs -
    # their pip internals are not ours to re-permission.
    find "$AEGIS_HOME" -not -path '*/venv/*' -not -path '*/.venv/*' -not -path '*/.git/*' \
        -type d -exec chmod 755 {} + 2>/dev/null || true
    find "$AEGIS_HOME" -not -path '*/venv/*' -not -path '*/.venv/*' -not -path '*/.git/*' \
        -type f -name "*.sh" -exec chmod 755 {} + 2>/dev/null || true
    find "$AEGIS_HOME" -not -path '*/venv/*' -not -path '*/.venv/*' -not -path '*/.git/*' \
        -type f \( -name "*.conf" -o -name "*.py" \) -exec chmod 644 {} + 2>/dev/null || true

    # Set restrictive permissions on configs/ contents (may contain secrets).
    # Must NOT blindly chmod 600 everything in "configs/*": a directory
    # without the execute bit can't be entered, listed, or written into -
    # even by its own owner - which broke every per-component config
    # subdirectory (behavioral_analysis, incident_response,
    # threat_intelligence, web-dashboard) the first time this line ran,
    # since the glob matches directories along with files.
    find "$AEGIS_HOME/configs" -maxdepth 1 -type f -exec chmod 600 {} + 2>/dev/null || true
    find "$AEGIS_HOME/configs" -maxdepth 1 -type d -exec chmod 700 {} + 2>/dev/null || true

    show_success "File permissions set"
}

# Interactive help for components
show_component_help() {
    local component="$1"
    
    case "$component" in
        "security-tools")
            echo -e "${CYAN}Security Tools Component:${NC}"
            echo -e "• ClamAV: Antivirus scanner for malware detection"
            echo -e "• rkhunter: Rootkit detection tool"
            echo -e "• chkrootkit: Additional rootkit checker"
            echo -e "• Lynis: Security auditing and compliance testing"
            ;;
        "web-dashboard")
            echo -e "${CYAN}Web Dashboard Component:${NC}"
            echo -e "• Flask-based web interface"
            echo -e "• Real-time monitoring dashboard"
            echo -e "• RESTful API endpoints"
            echo -e "• Interactive incident management"
            ;;
        "behavioral-analysis")
            echo -e "${CYAN}Behavioral Analysis Component:${NC}"
            echo -e "• System behavior monitoring"
            echo -e "• Anomaly detection"
            echo -e "• Baseline establishment"
            echo -e "• Threat scoring"
            ;;
        "incident-response")
            echo -e "${CYAN}Incident Response Component:${NC}"
            echo -e "• Automated incident handling"
            echo -e "• Evidence preservation"
            echo -e "• Escalation management"
            echo -e "• Reporting capabilities"
            ;;
        "threat-intelligence")
            echo -e "${CYAN}Threat Intelligence Component:${NC}"
            echo -e "• IOC (Indicators of Compromise) matching"
            echo -e "• Reputation checking"
            echo -e "• Threat feed integration"
            echo -e "• Automated analysis"
            ;;
        "scheduling")
            echo -e "${CYAN}Scheduling Component:${NC}"
            echo -e "• Automated scan scheduling"
            echo -e "• Systemd timer integration"
            echo -e "• Configurable scan intervals"
            echo -e "• Persistent scheduling"
            ;;
    esac
}

# Main installation function
main_installation() {
    echo -e "${CYAN}================================================================${NC}"
    echo -e "${WHITE}      🛡️ AEGIS SECURITY SUITE V6.0 SETUP 🛡️${NC}"
    echo -e "${CYAN}================================================================${NC}"
    echo -e "${YELLOW}Enhanced with menu-driven installation and comprehensive features!${NC}"
    echo -e "${CYAN}================================================================${NC}"
    echo ""
    echo -e "${BLUE}Setup timestamp: ${SETUP_TIMESTAMP}${NC}"
    echo -e "${BLUE}Setup date: ${SETUP_DATE}${NC}"
    echo ""
    
    # CLI flags bypass the interactive 2-choice menu entirely
    case "$CLI_MODE" in
        custom)
            INSTALLATION_TYPE="custom"
            show_custom_component_menu
            ;;
        update)
            INSTALLATION_TYPE="update"
            INSTALLATION_COMPONENTS=("update")
            ;;
        *)
            show_installation_menu
            ;;
    esac

    echo -e "${GREEN}Selected installation type: ${INSTALLATION_TYPE}${NC}"
    echo -e "${GREEN}Components to install: ${INSTALLATION_COMPONENTS[*]}${NC}"
    echo ""
    
    # Show component help
    for component in "${INSTALLATION_COMPONENTS[@]}"; do
        show_component_help "$component"
        echo ""
    done
    
    read -p "Proceed with installation? (Y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo -e "${BLUE}👋 Installation cancelled${NC}"
        exit 0
    fi
    
    # Check system dependencies
    check_system_dependencies || {
        show_error "System dependency check failed"
        exit 1
    }
    
    # Create base directory structure
    show_progress "Creating base directory structure"
    mkdir -p "$AEGIS_HOME"
    mkdir -p "$AEGIS_HOME/logs"
    mkdir -p "$AEGIS_HOME/configs"
    mkdir -p "$AEGIS_HOME/scripts"
    mkdir -p "$AEGIS_HOME/backups"
    
    # Install selected components
    for component in "${INSTALLATION_COMPONENTS[@]}"; do
        echo ""
        echo -e "${BLUE}Installing component: ${component}${NC}"
        
        case "$component" in
            "security-tools")
                install_security_tools || {
                    show_error "Failed to install security tools"
                    rollback_installation
                    exit 1
                }
                ;;
            "web-dashboard")
                install_web_dashboard || {
                    show_error "Failed to install web dashboard"
                    rollback_installation
                    exit 1
                }
                ;;
            "behavioral-analysis")
                install_behavioral_analysis || {
                    show_error "Failed to install behavioral analysis"
                    rollback_installation
                    exit 1
                }
                ;;
            "incident-response")
                install_incident_response || {
                    show_error "Failed to install incident response"
                    rollback_installation
                    exit 1
                }
                ;;
            "threat-intelligence")
                install_threat_intelligence || {
                    show_error "Failed to install threat intelligence"
                    rollback_installation
                    exit 1
                }
                ;;
            "scheduling")
                install_scheduling || {
                    show_error "Failed to install scheduling"
                    rollback_installation
                    exit 1
                }
                ;;
            "update")
                update_existing_installation || {
                    show_error "Failed to update existing installation"
                    exit 1
                }
                ;;
        esac
    done
    
    # Validate configuration
    validate_configuration || {
        show_error "Configuration validation failed"
        rollback_installation
        exit 1
    }
    
    # Set file permissions
    set_file_permissions
    
    # Create notification functions
    create_notification_functions
    
    echo ""
    echo -e "${CYAN}================================================================${NC}"
    echo -e "${WHITE}     🎉 INSTALLATION COMPLETE! 🎉${NC}"
    echo -e "${CYAN}================================================================${NC}"
    echo ""
    echo -e "${GREEN}✅ Installation type: ${INSTALLATION_TYPE}${NC}"
    echo -e "${GREEN}✅ Components installed: ${INSTALLATION_COMPONENTS[*]}${NC}"
    echo -e "${GREEN}✅ Installation directory: ${AEGIS_HOME}${NC}"
    echo ""
    
    # Show next steps based on installed components
    echo -e "${CYAN}🚀 Next Steps:${NC}"
    
    if [[ " ${INSTALLATION_COMPONENTS[*]} " =~ " web-dashboard " ]]; then
        echo -e "${GREEN}• Start web dashboard: ${WHITE}systemctl --user start aegis-dashboard.service${NC}"
        echo -e "${GREEN}• Access dashboard: ${WHITE}http://localhost:8080${NC}"
    fi
    
    if [[ " ${INSTALLATION_COMPONENTS[*]} " =~ " scheduling " ]]; then
        echo -e "${GREEN}• View timers: ${WHITE}systemctl --user list-timers | grep security${NC}"
    fi
    
    echo -e "${GREEN}• Run manual scan: ${WHITE}cd $AEGIS_HOME/scripts && ./security-daily-scan.sh${NC}"
    echo -e "${GREEN}• View logs: ${WHITE}ls -la $AEGIS_HOME/logs/${NC}"
    echo ""
    
    echo -e "${CYAN}================================================================${NC}"
    
    # Mark installation completion
    mkdir -p "$AEGIS_HOME/logs/manual"
    echo "$(date): Installation V6.0 completed successfully - Type: $INSTALLATION_TYPE - Components: ${INSTALLATION_COMPONENTS[*]}" >> "$AEGIS_HOME/logs/manual/setup.log"
    
    return 0
}

# Create notification functions
create_notification_functions() {
    cat > "$AEGIS_HOME/scripts/notification-functions.sh" << 'EOF'
#!/bin/bash
# Notification Support Functions
# Version: 6.0 - Enhanced setup

check_notification_support() {
    if command -v notify-send &>/dev/null; then
        return 0
    else
        return 1
    fi
}

send_notification() {
    local title="$1"
    local message="$2"
    local icon="${3:-security-high}"
    local urgency="${4:-normal}"
    
    if check_notification_support; then
        notify-send -u "$urgency" -i "$icon" "$title" "$message" 2>/dev/null || true
    fi
}

export -f check_notification_support
export -f send_notification
EOF

    chmod +x "$AEGIS_HOME/scripts/notification-functions.sh"
    show_success "Created notification functions"
}

# Update existing installation
update_existing_installation() {
    show_progress "Updating existing installation"
    
    if [ ! -d "$AEGIS_HOME" ]; then
        show_error "No existing installation found"
        return 1
    fi
    
    # Backup existing configuration
    local backup_dir="$AEGIS_HOME.backup.$(date +%s)"
    cp -r "$AEGIS_HOME" "$backup_dir"
    show_success "Created backup: $backup_dir"
    
    # Update scripts
    if [ -d "$SCRIPT_DIR" ]; then
        cp -r "$SCRIPT_DIR"/* "$AEGIS_HOME/scripts/" 2>/dev/null || true
        show_success "Updated scripts"
    fi
    
    # Update configurations
    if [ -d "$SCRIPT_DIR/../configs" ]; then
        cp -r "$SCRIPT_DIR/../configs"/* "$AEGIS_HOME/configs/" 2>/dev/null || true
        show_success "Updated configurations"
    fi
    
    # Reload systemd services
    systemctl --user daemon-reload 2>/dev/null || true
    
    show_success "Installation update completed"
    return 0
}

# Start the installation
main_installation

exit 0
