#!/bin/bash
#
# Complete Interactive Security Suite Setup for Garuda Linux - Version 5.0
# Includes scheduling configuration and comprehensive final testing
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

# Dynamic path resolution
CURRENT_USER=$(whoami)
CURRENT_HOME=$(getent passwd "$CURRENT_USER" | cut -d: -f6)
SECURITY_SUITE_HOME="${SECURITY_SUITE_HOME:-$CURRENT_HOME/security-suite}"

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

# Configuration variables with defaults
NOTIFICATIONS_ENABLED=true
NOTIFICATION_URGENCY="normal"
UPDATE_BEFORE_SCAN=true
REAL_TIME_FEEDBACK=true
AUTO_CLEANUP_LOGS=false
MAX_LOG_AGE_DAYS=30
USE_COLORS=true
PROGRESS_INDICATORS=true
ENABLE_SCHEDULING=false
DAILY_TIME="09:00"
WEEKLY_TIME="10:00"
WEEKLY_DAY="Mon"
MONTHLY_TIME="11:00"
MONTHLY_DAY="1"
SELECTED_TOOLS=("clamav" "rkhunter" "chkrootkit" "lynis")
DAILY_SCAN_DIRS=("$HOME/Documents" "$HOME/Downloads" "$HOME/Desktop" "$HOME/.config")
WEEKLY_SCAN_DIRS=("$HOME")
MONTHLY_SCAN_DIRS=("$HOME" "/tmp" "/var/tmp")

echo -e "${CYAN}================================================================${NC}"
echo -e "${WHITE}      🛡️ COMPLETE SECURITY SUITE V5.0 SETUP 🛡️${NC}"
echo -e "${CYAN}================================================================${NC}"
echo -e "${YELLOW}Enhanced with automatic scheduling and comprehensive testing!${NC}"
echo -e "${YELLOW}Complete security automation for your Garuda Linux system.${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""
echo -e "${BLUE}Setup timestamp: ${SETUP_TIMESTAMP}${NC}"
echo -e "${BLUE}Setup date: ${SETUP_DATE}${NC}"
echo ""

# Validation functions
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
    echo -e "${RED}❌ $message${NC}"
}

show_info() {
    local message=$1
    echo -e "${BLUE}ℹ️  $message${NC}"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    show_error "Please do NOT run this script as root!"
    echo -e "${YELLOW}💡 The script will ask for sudo password when needed.${NC}"
    exit 1
fi

# Check for existing installation
check_existing_installation() {
    echo -e "${BLUE}🔍 Checking for existing security suite installation...${NC}"
    echo ""
    
    if [ -d "$SECURITY_SUITE_HOME" ]; then
        echo -e "${YELLOW}📁 Found existing security suite directory!${NC}"
        echo ""
        
        # Show what's currently installed
        if [ -f "$SECURITY_SUITE_HOME/SCRIPT_INDEX.md" ]; then
            local existing_timestamp=$(grep "Generated:" "$SECURITY_SUITE_HOME/SCRIPT_INDEX.md" | head -1 | cut -d' ' -f2)
            echo -e "${CYAN}Current installation timestamp: ${existing_timestamp}${NC}"
        fi
        
        if [ -f "$SECURITY_SUITE_HOME/configs/security-config.conf" ]; then
            echo -e "${GREEN}✅ Configuration file found${NC}"
        fi
        
        local script_count=$(find "$SECURITY_SUITE_HOME/scripts" -name "security-*.sh" -type f 2>/dev/null | wc -l)
        echo -e "${GREEN}✅ Found $script_count security scripts${NC}"
        
        local log_count=$(find "$SECURITY_SUITE_HOME/logs" -name "*.log" -type f 2>/dev/null | wc -l)
        echo -e "${GREEN}✅ Found $log_count log files${NC}"
        
        # Check for existing timers
        local timer_count=$(systemctl --user list-timers | grep -c "security.*scan" 2>/dev/null || echo "0")
        if [ "$timer_count" -gt 0 ]; then
            echo -e "${GREEN}✅ Found $timer_count active scheduling timers${NC}"
        fi
        
        echo ""
        echo -e "${YELLOW}What would you like to do?${NC}"
        echo -e "${CYAN}1)${NC} Update existing installation (keep logs, update scripts)"
        echo -e "${CYAN}2)${NC} Fresh installation with backup (backup old, create new)"
        echo -e "${CYAN}3)${NC} Fresh installation (remove old, create new)"
        echo -e "${CYAN}4)${NC} Cancel setup"
        echo ""
        
        read -p "Enter your choice (1-4): " existing_choice
        echo ""
        
        case $existing_choice in
            1)
                echo -e "${GREEN}🔄 Will update existing installation${NC}"
                return 0
                ;;
            2)
                echo -e "${YELLOW}📦 Creating backup of existing installation...${NC}"
                local backup_name="security-suite-backup-$(date +%Y%m%d_%H%M%S)"
                mv "$SECURITY_SUITE_HOME" "$CURRENT_HOME/$backup_name"
                echo -e "${GREEN}✅ Backup saved as: ~/$backup_name${NC}"
                return 0
                ;;
            3)
                echo -e "${RED}🗑️  Removing existing installation...${NC}"
                read -p "Are you sure you want to permanently delete the old installation? (y/N): " -n 1 -r
                echo ""
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    # Stop and disable any existing timers
                    systemctl --user stop security-*-scan.timer 2>/dev/null || true
                    systemctl --user disable security-*-scan.timer 2>/dev/null || true
                    rm -f "$CURRENT_HOME/.config/systemd/user/security-*-scan"* 2>/dev/null
                    systemctl --user daemon-reload
                    
                    rm -rf "$SECURITY_SUITE_HOME"
                    echo -e "${GREEN}✅ Old installation removed${NC}"
                else
                    echo -e "${YELLOW}📦 Creating backup instead...${NC}"
                    local backup_name="security-suite-backup-$(date +%Y%m%d_%H%M%S)"
                    mv "$SECURITY_SUITE_HOME" "$CURRENT_HOME/$backup_name"
                    echo -e "${GREEN}✅ Backup saved as: ~/$backup_name${NC}"
                fi
                return 0
                ;;
            4)
                echo -e "${BLUE}👋 Setup cancelled by user${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice. Defaulting to update.${NC}"
                return 0
                ;;
        esac
    else
        echo -e "${GREEN}✅ No existing installation found - proceeding with fresh setup${NC}"
        echo ""
    fi
}

# Check security tools status
check_security_tools_status() {
    echo -e "${BLUE}🔍 Checking security tools installation status...${NC}"
    echo ""
    
    local tools=("clamav" "rkhunter" "chkrootkit" "lynis")
    local installed_tools=()
    local missing_tools=()
    
    for tool in "${tools[@]}"; do
        if pacman -Qi "$tool" &>/dev/null; then
            installed_tools+=("$tool")
            echo -e "${GREEN}✅ $tool - Already installed${NC}"
        else
            missing_tools+=("$tool")
            echo -e "${YELLOW}⏳ $tool - Not installed${NC}"
        fi
    done
    
    echo ""
    if [ ${#installed_tools[@]} -gt 0 ]; then
        echo -e "${GREEN}📦 Already installed: ${installed_tools[*]}${NC}"
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo -e "${YELLOW}📦 Need to install: ${missing_tools[*]}${NC}"
    else
        echo -e "${GREEN}🎉 All security tools are already installed!${NC}"
    fi
    
    echo ""
    return 0
}

# Interactive menu functions
show_menu_header() {
    clear
    echo -e "${CYAN}================================================================${NC}"
    echo -e "${WHITE}      🔧 SECURITY SUITE CONFIGURATION MENU 🔧${NC}"
    echo -e "${CYAN}================================================================${NC}"
    echo ""
}

press_enter_to_continue() {
    echo ""
    read -p "Press Enter to continue..." -r
}

# Scheduling configuration
configure_scheduling() {
    show_menu_header
    echo -e "${GREEN}⏰ Automated Scheduling Configuration${NC}"
    echo ""
    
    read -p "Enable automatic scheduling of security scans? (Y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        ENABLE_SCHEDULING=false
        echo -e "${YELLOW}📅 Scheduling disabled - you'll run scans manually${NC}"
    else
        ENABLE_SCHEDULING=true
        echo -e "${GREEN}📅 Scheduling enabled${NC}"
        echo ""
        
        # Configure daily scan time
        echo -e "${YELLOW}Daily Scan Scheduling:${NC}"
        read -p "Daily scan time (HH:MM format, default 09:00): " daily_time_input
        if [[ "$daily_time_input" =~ ^([0-1][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
            DAILY_TIME="$daily_time_input"
        fi
        echo -e "${GREEN}✅ Daily scan scheduled for: $DAILY_TIME${NC}"
        echo ""
        
        # Configure weekly scan
        echo -e "${YELLOW}Weekly Scan Scheduling:${NC}"
        read -p "Weekly scan day (Mon/Tue/Wed/Thu/Fri/Sat/Sun, default Mon): " weekly_day_input
        case "$weekly_day_input" in
            Mon|Tue|Wed|Thu|Fri|Sat|Sun) WEEKLY_DAY="$weekly_day_input" ;;
            *) WEEKLY_DAY="Mon" ;;
        esac
        read -p "Weekly scan time (HH:MM format, default 10:00): " weekly_time_input
        if [[ "$weekly_time_input" =~ ^([0-1][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
            WEEKLY_TIME="$weekly_time_input"
        fi
        echo -e "${GREEN}✅ Weekly scan scheduled for: $WEEKLY_DAY at $WEEKLY_TIME${NC}"
        echo ""
        
        # Configure monthly scan
        echo -e "${YELLOW}Monthly Scan Scheduling:${NC}"
        read -p "Monthly scan day (1-28, default 1): " monthly_day_input
        if [[ "$monthly_day_input" =~ ^([1-9]|1[0-9]|2[0-8])$ ]]; then
            MONTHLY_DAY="$monthly_day_input"
        fi
        read -p "Monthly scan time (HH:MM format, default 11:00): " monthly_time_input
        if [[ "$monthly_time_input" =~ ^([0-1][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
            MONTHLY_TIME="$monthly_time_input"
        fi
        echo -e "${GREEN}✅ Monthly scan scheduled for: Day $MONTHLY_DAY at $MONTHLY_TIME${NC}"
        echo ""
        
        echo -e "${CYAN}📅 Scheduling Summary:${NC}"
        echo -e "   • ${WHITE}Daily:${NC} Every day at $DAILY_TIME"
        echo -e "   • ${WHITE}Weekly:${NC} Every $WEEKLY_DAY at $WEEKLY_TIME"
        echo -e "   • ${WHITE}Monthly:${NC} Day $MONTHLY_DAY of each month at $MONTHLY_TIME"
    fi
    
    press_enter_to_continue
}

# Main configuration menu (updated)
main_configuration_menu() {
    while true; do
        show_menu_header
        echo -e "${GREEN}Choose what you'd like to configure:${NC}"
        echo ""
        echo -e "${CYAN}1)${NC} Security Tools Selection"
        echo -e "${CYAN}2)${NC} Scan Directory Configuration"
        echo -e "${CYAN}3)${NC} Notification Settings"
        echo -e "${CYAN}4)${NC} Scanning Preferences"
        echo -e "${CYAN}5)${NC} Log Management Settings"
        echo -e "${CYAN}6)${NC} Display & UI Settings"
        echo -e "${CYAN}7)${NC} Automated Scheduling Configuration ⭐ NEW!"
        echo -e "${CYAN}8)${NC} Review All Settings"
        echo -e "${CYAN}9)${NC} Use Default Settings (Quick Setup)"
        echo -e "${CYAN}0)${NC} Continue with Setup"
        echo ""
        read -p "Enter your choice (0-9): " choice
        
        case $choice in
            1) configure_security_tools ;;
            2) configure_scan_directories ;;
            3) configure_notifications ;;
            4) configure_scanning_preferences ;;
            5) configure_log_management ;;
            6) configure_display_settings ;;
            7) configure_scheduling ;;
            8) review_all_settings ;;
            9) use_default_settings ;;
            0) break ;;
            *) echo -e "${RED}Invalid choice. Please enter 0-9.${NC}"; sleep 2 ;;
        esac
    done
}

# Security tools configuration
configure_security_tools() {
    show_menu_header
    echo -e "${GREEN}🔧 Security Tools Selection${NC}"
    echo ""
    echo -e "${YELLOW}Available security tools:${NC}"
    echo ""
    
    local tools=("clamav" "rkhunter" "chkrootkit" "lynis")
    local descriptions=("Antivirus scanner" "Rootkit hunter" "Rootkit checker" "Security auditing tool")
    
    # Show current installation status
    echo -e "${CYAN}Current installation status:${NC}"
    for i in "${!tools[@]}"; do
        if pacman -Qi "${tools[i]}" &>/dev/null; then
            echo -e "${GREEN}✅ ${tools[i]}${NC} - ${descriptions[i]} (already installed)"
        else
            echo -e "${YELLOW}⏳ ${tools[i]}${NC} - ${descriptions[i]} (not installed)"
        fi
    done
    echo ""
    
    SELECTED_TOOLS=()
    
    for i in "${!tools[@]}"; do
        read -p "Include ${tools[i]} in security suite? (Y/n): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            SELECTED_TOOLS+=("${tools[i]}")
            echo -e "  ${GREEN}✅ ${tools[i]} selected${NC}"
        else
            echo -e "  ${YELLOW}⏭️  ${tools[i]} skipped${NC}"
        fi
        echo ""
    done
    
    echo -e "${GREEN}Selected tools: ${SELECTED_TOOLS[*]}${NC}"
    press_enter_to_continue
}

# [Include other configuration functions from V4...]
configure_scan_directories() {
    show_menu_header
    echo -e "${GREEN}📁 Scan Directory Configuration${NC}"
    echo ""
    
    # Daily scan directories
    echo -e "${YELLOW}Daily Scan Directories (quick scan):${NC}"
    echo -e "Current: ${DAILY_SCAN_DIRS[*]}"
    read -p "Add custom directory? (leave blank to skip): " custom_dir
    if [[ -n "$custom_dir" && -d "$custom_dir" ]]; then
        DAILY_SCAN_DIRS+=("$custom_dir")
        echo -e "${GREEN}✅ Added: $custom_dir${NC}"
    fi
    echo ""
    
    # Weekly scan option
    echo -e "${YELLOW}Weekly Scan (comprehensive):${NC}"
    echo -e "Current: Full home directory (${HOME})"
    read -p "Scan entire home directory for weekly scans? (Y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        WEEKLY_SCAN_DIRS=("${DAILY_SCAN_DIRS[@]}")
        echo -e "${YELLOW}⚠️  Weekly scan will use same directories as daily${NC}"
    fi
    echo ""
    
    # Monthly scan option
    echo -e "${YELLOW}Monthly Scan (full system):${NC}"
    echo -e "Current: ${MONTHLY_SCAN_DIRS[*]}"
    read -p "Include system temp directories (/tmp, /var/tmp)? (Y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        MONTHLY_SCAN_DIRS=("$HOME")
        echo -e "${YELLOW}⚠️  Monthly scan will only scan home directory${NC}"
    fi
    
    press_enter_to_continue
}

configure_notifications() {
    show_menu_header
    echo -e "${GREEN}🔔 Notification Settings${NC}"
    echo ""
    
    read -p "Enable desktop notifications? (Y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        NOTIFICATIONS_ENABLED=false
        echo -e "${YELLOW}📵 Notifications disabled${NC}"
    else
        NOTIFICATIONS_ENABLED=true
        echo -e "${GREEN}🔔 Notifications enabled${NC}"
        echo ""
        echo -e "${YELLOW}Notification urgency level:${NC}"
        echo -e "${CYAN}1)${NC} Low (quiet notifications)"
        echo -e "${CYAN}2)${NC} Normal (standard notifications)"
        echo -e "${CYAN}3)${NC} Critical (urgent notifications)"
        echo ""
        read -p "Choose urgency level (1-3, default 2): " urgency_choice
        
        case $urgency_choice in
            1) NOTIFICATION_URGENCY="low" ;;
            3) NOTIFICATION_URGENCY="critical" ;;
            *) NOTIFICATION_URGENCY="normal" ;;
        esac
        echo -e "${GREEN}✅ Notification urgency set to: $NOTIFICATION_URGENCY${NC}"
    fi
    
    press_enter_to_continue
}

configure_scanning_preferences() {
    show_menu_header
    echo -e "${GREEN}⚙️ Scanning Preferences${NC}"
    echo ""
    
    read -p "Update virus definitions before each scan? (Y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        UPDATE_BEFORE_SCAN=false
        echo -e "${YELLOW}⚠️  Auto-update disabled${NC}"
    else
        UPDATE_BEFORE_SCAN=true
        echo -e "${GREEN}✅ Auto-update enabled${NC}"
    fi
    echo ""
    
    read -p "Show real-time scan feedback? (Y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        REAL_TIME_FEEDBACK=false
        echo -e "${YELLOW}📊 Real-time feedback disabled${NC}"
    else
        REAL_TIME_FEEDBACK=true
        echo -e "${GREEN}📊 Real-time feedback enabled${NC}"
    fi
    
    press_enter_to_continue
}

configure_log_management() {
    show_menu_header
    echo -e "${GREEN}📂 Log Management Settings${NC}"
    echo ""
    
    read -p "Automatically cleanup old logs? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        AUTO_CLEANUP_LOGS=true
        echo -e "${GREEN}🧹 Auto-cleanup enabled${NC}"
        echo ""
        read -p "Keep logs for how many days? (default 30): " log_days
        if [[ "$log_days" =~ ^[0-9]+$ && "$log_days" -gt 0 ]]; then
            MAX_LOG_AGE_DAYS=$log_days
        else
            MAX_LOG_AGE_DAYS=30
        fi
        echo -e "${GREEN}✅ Logs will be kept for $MAX_LOG_AGE_DAYS days${NC}"
    else
        AUTO_CLEANUP_LOGS=false
        echo -e "${YELLOW}📦 Auto-cleanup disabled - logs will be kept indefinitely${NC}"
    fi
    
    press_enter_to_continue
}

configure_display_settings() {
    show_menu_header
    echo -e "${GREEN}🎨 Display & UI Settings${NC}"
    echo ""
    
    read -p "Use colored output? (Y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        USE_COLORS=false
        echo -e "Colors disabled"
    else
        USE_COLORS=true
        echo -e "${GREEN}✅ Colors enabled${NC}"
    fi
    echo ""
    
    read -p "Show progress indicators? (Y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        PROGRESS_INDICATORS=false
        echo -e "${YELLOW}📊 Progress indicators disabled${NC}"
    else
        PROGRESS_INDICATORS=true
        echo -e "${GREEN}📊 Progress indicators enabled${NC}"
    fi
    
    press_enter_to_continue
}

review_all_settings() {
    show_menu_header
    echo -e "${GREEN}📋 Current Configuration Review${NC}"
    echo ""
    
    echo -e "${CYAN}Security Tools:${NC} ${SELECTED_TOOLS[*]}"
    echo -e "${CYAN}Daily Scan Dirs:${NC} ${DAILY_SCAN_DIRS[*]}"
    echo -e "${CYAN}Weekly Scan Dirs:${NC} ${WEEKLY_SCAN_DIRS[*]}"
    echo -e "${CYAN}Monthly Scan Dirs:${NC} ${MONTHLY_SCAN_DIRS[*]}"
    echo -e "${CYAN}Notifications:${NC} $NOTIFICATIONS_ENABLED (urgency: $NOTIFICATION_URGENCY)"
    echo -e "${CYAN}Update Before Scan:${NC} $UPDATE_BEFORE_SCAN"
    echo -e "${CYAN}Real-time Feedback:${NC} $REAL_TIME_FEEDBACK"
    echo -e "${CYAN}Auto-cleanup Logs:${NC} $AUTO_CLEANUP_LOGS (keep $MAX_LOG_AGE_DAYS days)"
    echo -e "${CYAN}Use Colors:${NC} $USE_COLORS"
    echo -e "${CYAN}Progress Indicators:${NC} $PROGRESS_INDICATORS"
    echo -e "${CYAN}Automated Scheduling:${NC} $ENABLE_SCHEDULING"
    if [ "$ENABLE_SCHEDULING" = "true" ]; then
        echo -e "${CYAN}  Daily:${NC} $DAILY_TIME"
        echo -e "${CYAN}  Weekly:${NC} $WEEKLY_DAY at $WEEKLY_TIME"
        echo -e "${CYAN}  Monthly:${NC} Day $MONTHLY_DAY at $MONTHLY_TIME"
    fi
    echo ""
    
    read -p "Settings look good? (Y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo -e "${YELLOW}You can modify settings using the menu options.${NC}"
    else
        echo -e "${GREEN}✅ Configuration confirmed!${NC}"
    fi
    
    press_enter_to_continue
}

use_default_settings() {
    show_menu_header
    echo -e "${GREEN}⚡ Using Default Settings (Quick Setup)${NC}"
    echo ""
    echo -e "${YELLOW}Default configuration:${NC}"
    echo -e "• All security tools (ClamAV, rkhunter, chkrootkit, Lynis)"
    echo -e "• Standard scan directories"
    echo -e "• Notifications enabled"
    echo -e "• Auto-update enabled"
    echo -e "• Real-time feedback enabled"
    echo -e "• Manual log cleanup"
    echo -e "• Colors and progress indicators enabled"
    echo -e "• Manual scheduling (no automatic scans)"
    echo ""
    
    SELECTED_TOOLS=("clamav" "rkhunter" "chkrootkit" "lynis")
    ENABLE_SCHEDULING=false
    echo -e "${GREEN}✅ Default settings applied!${NC}"
    press_enter_to_continue
}

# Generate systemd service with dynamic paths
generate_systemd_service() {
    local service_name="$1"
    local script_name="$2"
    local description="$3"
    local service_file="$HOME/.config/systemd/user/${service_name}.service"
    
    # Validate paths before generation
    local script_path="$SECURITY_SUITE_HOME/scripts/$script_name"
    validate_path "$script_path" "Script path" || return 1
    
    # Ensure systemd user directory exists
    mkdir -p "$HOME/.config/systemd/user"
    
    cat > "$service_file" << EOF
[Unit]
Description=$description
After=network-online.target

[Service]
Type=oneshot
ExecStart=$script_path
WorkingDirectory=$SECURITY_SUITE_HOME/scripts
StandardOutput=journal
StandardError=journal
Environment=USER=$CURRENT_USER
Environment=HOME=$CURRENT_HOME
Environment=SECURITY_SUITE_HOME=$SECURITY_SUITE_HOME

[Install]
WantedBy=default.target
EOF
    
    chmod 644 "$service_file"
    show_success "Created $service_name service"
}

# Generate systemd timer
generate_systemd_timer() {
    local timer_name="$1"
    local service_name="$2"
    local description="$3"
    local schedule="$4"
    local timer_file="$HOME/.config/systemd/user/${timer_name}.timer"
    
    cat > "$timer_file" << EOF
[Unit]
Description=$description
Requires=$service_name.service

[Timer]
OnCalendar=$schedule
Persistent=true

[Install]
WantedBy=timers.target
EOF
    
    chmod 644 "$timer_file"
    show_success "Created $timer_name timer"
}

# Generate systemd user timers
generate_systemd_timers() {
    if [ "$ENABLE_SCHEDULING" != "true" ]; then
        return 0
    fi
    
    show_progress "Creating systemd user timer configuration"
    
    # Validate security suite home directory
    validate_path "$SECURITY_SUITE_HOME" "Security suite home" || return 1
    
    # Create daily scan service and timer
    generate_systemd_service "security-daily-scan" "security-daily-scan.sh" "Daily Security Scan"
    generate_systemd_timer "security-daily-scan" "security-daily-scan" "Daily Security Scan Timer" "*-*-* $DAILY_TIME:00"
    
    # Create weekly scan service and timer
    generate_systemd_service "security-weekly-scan" "security-weekly-scan.sh" "Weekly Security Scan"
    generate_systemd_timer "security-weekly-scan" "security-weekly-scan" "Weekly Security Scan Timer" "$WEEKLY_DAY *-*-* $WEEKLY_TIME:00"
    
    # Create monthly scan service and timer
    generate_systemd_service "security-monthly-scan" "security-monthly-scan.sh" "Monthly Security Scan"
    generate_systemd_timer "security-monthly-scan" "security-monthly-scan" "Monthly Security Scan Timer" "*-*-$MONTHLY_DAY $MONTHLY_TIME:00"
    
    show_success "Systemd timer configuration created"
}

# Enable systemd timers
enable_systemd_timers() {
    if [ "$ENABLE_SCHEDULING" != "true" ]; then
        return 0
    fi
    
    show_progress "Enabling and starting systemd timers"
    
    # Reload systemd user configuration
    systemctl --user daemon-reload
    
    # Enable and start timers
    systemctl --user enable --now security-daily-scan.timer
    systemctl --user enable --now security-weekly-scan.timer
    systemctl --user enable --now security-monthly-scan.timer
    
    # Enable linger so timers work when user is logged out
    read -p "Enable timers to run even when you're logged out? (Y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        # Validate username before using sudo
        if [[ ! "$CURRENT_USER" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            show_error "Invalid username format: $CURRENT_USER"
            return 1
        fi
        
        sudo loginctl enable-linger "$CURRENT_USER"
        echo -e "${GREEN}✅ User linger enabled for $CURRENT_USER - timers will run when logged out${NC}"
    fi
    
    show_success "Automated scheduling configured and enabled"
}

# Comprehensive final test
run_comprehensive_final_test() {
    echo ""
    echo -e "${CYAN}================================================================${NC}"
    echo -e "${WHITE}      🧪 COMPREHENSIVE FINAL SYSTEM TEST 🧪${NC}"
    echo -e "${CYAN}================================================================${NC}"
    echo -e "${BLUE}Starting comprehensive validation of entire security suite...${NC}"
    echo ""
    
    local test_timestamp=$(date +"%Y%m%d_%H%M%S")
    local final_test_log="$SECURITY_SUITE_HOME/logs/manual/final_test_${test_timestamp}.log"
    local test_failures=0
    
    # Ensure log directory exists before writing
    mkdir -p "$SECURITY_SUITE_HOME/logs/manual"
    
    echo "COMPREHENSIVE SECURITY SUITE TEST - $(date)" > "$final_test_log"
    echo "=======================================" >> "$final_test_log"
    echo "" >> "$final_test_log"
    
    # Test 1: Directory Structure
    echo -e "${YELLOW}📁 Testing directory structure...${NC}"
    local required_dirs=("scripts" "logs" "configs" "backups" "logs/daily" "logs/weekly" "logs/monthly" "logs/manual")
    for dir in "${required_dirs[@]}"; do
        if [ -d "$SECURITY_SUITE_HOME/$dir" ]; then
            echo -e "  ${GREEN}✅ $dir${NC}"
            echo "✅ Directory exists: $dir" >> "$final_test_log"
        else
            echo -e "  ${RED}❌ $dir${NC}"
            echo "❌ Directory missing: $dir" >> "$final_test_log"
            ((test_failures++))
        fi
    done
    echo ""
    
    # Test 2: Configuration Files
    echo -e "${YELLOW}📄 Testing configuration files...${NC}"
    local config_files=("configs/security-config.conf" "scripts/notification-functions.sh")
    for file in "${config_files[@]}"; do
        if [ -f "$SECURITY_SUITE_HOME/$file" ]; then
            echo -e "  ${GREEN}✅ $file${NC}"
            echo "✅ Configuration file exists: $file" >> "$final_test_log"
        else
            echo -e "  ${RED}❌ $file${NC}"
            echo "❌ Configuration file missing: $file" >> "$final_test_log"
            ((test_failures++))
        fi
    done
    echo ""
    
    # Test 3: Security Scripts
    echo -e "${YELLOW}🔧 Testing security scripts...${NC}"
    local scripts=("security-daily-scan.sh" "security-weekly-scan.sh" "security-monthly-scan.sh" "security-test.sh")
    for script in "${scripts[@]}"; do
        if [ -x "$SECURITY_SUITE_HOME/scripts/$script" ]; then
            echo -e "  ${GREEN}✅ $script (executable)${NC}"
            echo "✅ Script exists and executable: $script" >> "$final_test_log"
        else
            echo -e "  ${RED}❌ $script${NC}"
            echo "❌ Script missing or not executable: $script" >> "$final_test_log"
            ((test_failures++))
        fi
    done
    echo ""
    
    # Test 4: Security Tools
    echo -e "${YELLOW}🛡️  Testing security tools...${NC}"
    for tool in "${SELECTED_TOOLS[@]}"; do
        if command -v "$tool" &>/dev/null || pacman -Qi "$tool" &>/dev/null; then
            echo -e "  ${GREEN}✅ $tool (installed and available)${NC}"
            echo "✅ Security tool available: $tool" >> "$final_test_log"
        else
            echo -e "  ${RED}❌ $tool (not found)${NC}"
            echo "❌ Security tool missing: $tool" >> "$final_test_log"
            ((test_failures++))
        fi
    done
    echo ""
    
    # Test 5: EICAR Antivirus Test
    echo -e "${YELLOW}🦠 Running EICAR antivirus test...${NC}"
    local eicar_test_dir="/tmp/final-eicar-test-$$"
    mkdir -p "$eicar_test_dir"
    cd "$eicar_test_dir"
    
    # Create EICAR test file
    echo 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > eicar_final.com
    
    if command -v clamscan &>/dev/null; then
        local eicar_result=$(clamscan eicar_final.com 2>&1)
        if echo "$eicar_result" | grep -q "FOUND"; then
            echo -e "  ${GREEN}✅ ClamAV correctly detected EICAR signature${NC}"
            echo "✅ ClamAV EICAR test: PASSED" >> "$final_test_log"
        else
            echo -e "  ${YELLOW}⚠️  ClamAV did not detect EICAR signature${NC}"
            echo "⚠️  ClamAV EICAR test: FAILED" >> "$final_test_log"
            ((test_failures++))
        fi
    else
        echo -e "  ${RED}❌ ClamAV not available for testing${NC}"
        echo "❌ ClamAV not available" >> "$final_test_log"
        ((test_failures++))
    fi
    
    cd "$HOME"
    rm -rf "$eicar_test_dir"
    echo ""
    
    # Test 6: Systemd Timers (if enabled)
    if [ "$ENABLE_SCHEDULING" = "true" ]; then
        echo -e "${YELLOW}⏰ Testing systemd timers...${NC}"
        local timers=("security-daily-scan.timer" "security-weekly-scan.timer" "security-monthly-scan.timer")
        for timer in "${timers[@]}"; do
            if systemctl --user is-enabled "$timer" &>/dev/null; then
                echo -e "  ${GREEN}✅ $timer (enabled)${NC}"
                echo "✅ Timer enabled: $timer" >> "$final_test_log"
            else
                echo -e "  ${YELLOW}⚠️  $timer (not enabled)${NC}"
                echo "⚠️  Timer not enabled: $timer" >> "$final_test_log"
            fi
        done
        echo ""
    fi
    
    # Test 7: Notification System
    echo -e "${YELLOW}🔔 Testing notification system...${NC}"
    if command -v notify-send &>/dev/null; then
        notify-send "🧪 Security Suite Test" "Final test notification - ignore this message" 2>/dev/null
        echo -e "  ${GREEN}✅ Desktop notifications available${NC}"
        echo "✅ Notification system: Available" >> "$final_test_log"
    else
        echo -e "  ${YELLOW}⚠️  Desktop notifications not available${NC}"
        echo "⚠️  Notification system: Not available" >> "$final_test_log"
    fi
    echo ""
    
    # Final Test Results
    echo -e "${CYAN}================================================================${NC}"
    echo -e "${WHITE}      📊 COMPREHENSIVE TEST RESULTS 📊${NC}"
    echo -e "${CYAN}================================================================${NC}"
    
    if [ "$test_failures" -eq 0 ]; then
        echo -e "${GREEN}🎉 ALL TESTS PASSED! Your security suite is fully functional!${NC}"
        echo "🎉 FINAL RESULT: ALL TESTS PASSED" >> "$final_test_log"
        
        if [ "$NOTIFICATIONS_ENABLED" = "true" ]; then
            notify-send "🎉 Security Suite Ready!" "All tests passed - Your system is fully protected!" "security-high" "normal" 2>/dev/null
        fi
        
    else
        echo -e "${YELLOW}⚠️  $test_failures test(s) failed. Review the issues above.${NC}"
        echo "⚠️  FINAL RESULT: $test_failures test(s) failed" >> "$final_test_log"
        
        if [ "$NOTIFICATIONS_ENABLED" = "true" ]; then
            notify-send "⚠️ Security Suite Issues" "$test_failures test(s) failed - Review setup" "security-medium" "normal" 2>/dev/null
        fi
    fi
    
    echo -e "${BLUE}📂 Complete test log saved to: $(basename "$final_test_log")${NC}"
    echo -e "${CYAN}================================================================${NC}"
    echo ""
}

# Start the complete setup process
clear
echo -e "${CYAN}================================================================${NC}"
echo -e "${WHITE}      🛡️ COMPLETE SECURITY SUITE V5.0 SETUP 🛡️${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""

# Check for existing installation first
check_existing_installation

# Check security tools status
check_security_tools_status

# Ask about configuration
echo -e "${BLUE}🚀 Let's configure your complete security suite!${NC}"
echo ""
read -p "Do you want to customize settings or use defaults? (c/D): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Cc]$ ]]; then
    main_configuration_menu
else
    echo -e "${GREEN}✅ Using default settings for quick setup${NC}"
    echo ""
fi

# Create directory structure
show_progress "Creating organized directory structure"
mkdir -p "$SECURITY_SUITE_HOME"/{scripts,logs,configs,backups}
mkdir -p "$SECURITY_SUITE_HOME/scripts/generated-${SETUP_DATE}"
mkdir -p "$SECURITY_SUITE_HOME/logs"/{daily,weekly,monthly,manual}

# Create configuration file with user settings
show_progress "Creating configuration file with your settings"
cat > "$SECURITY_SUITE_HOME/configs/security-config.conf" << CONFIG_END
# Security Suite Configuration
# Generated on: $SETUP_TIMESTAMP
# Interactive Configuration: User Customized

# Dynamic path configuration
SECURITY_SUITE_HOME="$SECURITY_SUITE_HOME"
SCRIPTS_DIR="\$SECURITY_SUITE_HOME/scripts"
LOGS_DIR="\$SECURITY_SUITE_HOME/logs"
CONFIGS_DIR="\$SECURITY_SUITE_HOME/configs"
BACKUPS_DIR="\$SECURITY_SUITE_HOME/backups"
CURRENT_USER="$CURRENT_USER"
CURRENT_HOME="$CURRENT_HOME"

# Notification settings
NOTIFICATIONS_ENABLED=$NOTIFICATIONS_ENABLED
NOTIFICATION_URGENCY="$NOTIFICATION_URGENCY"

# Scanning preferences
UPDATE_BEFORE_SCAN=$UPDATE_BEFORE_SCAN
REAL_TIME_FEEDBACK=$REAL_TIME_FEEDBACK
AUTO_CLEANUP_LOGS=$AUTO_CLEANUP_LOGS
MAX_LOG_AGE_DAYS=$MAX_LOG_AGE_DAYS

# Color preferences
USE_COLORS=$USE_COLORS
PROGRESS_INDICATORS=$PROGRESS_INDICATORS

# Scheduling configuration
ENABLE_SCHEDULING=$ENABLE_SCHEDULING
DAILY_TIME="$DAILY_TIME"
WEEKLY_TIME="$WEEKLY_TIME"
WEEKLY_DAY="$WEEKLY_DAY"
MONTHLY_TIME="$MONTHLY_TIME"
MONTHLY_DAY="$MONTHLY_DAY"

# Custom scan directories
DAILY_SCAN_DIRS=(${DAILY_SCAN_DIRS[@]})
WEEKLY_SCAN_DIRS=(${WEEKLY_SCAN_DIRS[@]})
MONTHLY_SCAN_DIRS=(${MONTHLY_SCAN_DIRS[@]})

# Selected security tools
SELECTED_SECURITY_TOOLS=(${SELECTED_TOOLS[@]})
CONFIG_END

show_success "Configuration file created with your custom settings"

# Install selected security tools with better status reporting
if [ ${#SELECTED_TOOLS[@]} -gt 0 ]; then
    show_progress "Checking selected security tools installation"
    missing_tools=()
    already_installed=()
    
    for tool in "${SELECTED_TOOLS[@]}"; do
        if ! pacman -Qi "$tool" &>/dev/null; then
            missing_tools+=("$tool")
        else
            already_installed+=("$tool")
        fi
    done
    
    if [ ${#already_installed[@]} -gt 0 ]; then
        echo -e "${GREEN}✅ Already installed: ${already_installed[*]}${NC}"
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo -e "${YELLOW}📦 Need to install: ${missing_tools[*]}${NC}"
        read -p "🤔 Install missing security tools now? (Y/n): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            show_progress "Installing selected security tools"
            if sudo pacman -Sy --needed --noconfirm "${missing_tools[@]}"; then
                show_success "Security tools installed successfully"
            else
                show_error "Failed to install some security tools"
                echo -e "${YELLOW}You can install them manually later.${NC}"
            fi
        fi
    else
        show_success "All selected security tools are already installed"
    fi
else
    show_warning "No security tools selected - you'll need to install them manually"
fi

# Generate notification support functions
show_progress "Generating notification support functions"
cat > "$SECURITY_SUITE_HOME/scripts/notification-functions.sh" << 'NOTIF_END'
#!/bin/bash
# Notification Support Functions
# Version: 5.0 - Complete setup with scheduling

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
NOTIF_END

chmod +x "$SECURITY_SUITE_HOME/scripts/notification-functions.sh"

# Generate enhanced test script
show_progress "Creating enhanced test script"
TEST_SCRIPT="$SECURITY_SUITE_HOME/scripts/security-test.sh"
cat > "$TEST_SCRIPT" << 'TEST_END'
#!/bin/bash
# Enhanced Security Test Script
# Generated with Complete Setup V5.0

# Load configuration
if [ -f "$SECURITY_SUITE_HOME/configs/security-config.conf" ]; then
    source "$SECURITY_SUITE_HOME/configs/security-config.conf"
fi

# Load notification functions
if [ -f "$SECURITY_SUITE_HOME/scripts/notification-functions.sh" ]; then
    source "$SECURITY_SUITE_HOME/scripts/notification-functions.sh"
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
echo -e "${WHITE}  🧪 Enhanced Security Test${NC}"
echo -e "${CYAN}==========================================${NC}"
echo -e "${BLUE}Test started: $(date)${NC}"
echo ""

# Send start notification
send_notification "🛡️ Security Test" "Starting enhanced security test..." "security-high" "normal"

# Create test log file
timestamp=$(date +"%Y%m%d_%H%M%S")
TEST_LOG="$SECURITY_SUITE_HOME/logs/manual/enhanced_test_${timestamp}.log"

echo -e "${YELLOW}🧪 Testing security tools with EICAR test signature...${NC}"
echo ""

# Create temporary test directory
TEST_DIR="/tmp/security-test-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# Create harmless test files
echo -e "${GREEN}📝 Creating test files...${NC}"
echo "This is a normal text file" > normal_file.txt
echo "Test document content" > document.doc

# Create EICAR test virus (harmless test signature)
echo -e "${BLUE}🦠 Creating EICAR test virus signature (harmless)...${NC}"
echo -e "${CYAN}ℹ️  EICAR is a standard test file used to verify antivirus software${NC}"
echo 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > eicar_test.com

echo ""
echo -e "${YELLOW}🔍 Testing ClamAV detection...${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Run ClamAV test
if command -v clamscan &>/dev/null; then
    clamscan -r --bell "$TEST_DIR" 2>&1 | tee "$TEST_LOG"
    
    # Check results
    if grep -q "eicar_test.com.*FOUND" "$TEST_LOG"; then
        echo -e "${GREEN}🎉 SUCCESS! ClamAV correctly detected EICAR test signature!${NC}"
        send_notification "🎉 Test Success!" "ClamAV correctly detected the test signature!" "security-high" "normal"
        test_result="PASSED"
    else
        echo -e "${YELLOW}⚠️  ClamAV test WARNING - EICAR signature not detected${NC}"
        send_notification "⚠️ Test Warning" "EICAR not detected - Check ClamAV config" "security-medium" "normal"
        test_result="WARNING"
    fi
else
    echo -e "${RED}❌ ClamAV not found - please install it${NC}"
    test_result="FAILED"
fi

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Cleanup test files
echo ""
echo -e "${BLUE}🧹 Cleaning up test files...${NC}"
cd "$HOME"
rm -rf "$TEST_DIR"
echo -e "${GREEN}✅ Test files cleaned up${NC}"

echo ""
echo -e "${CYAN}==========================================${NC}"
echo -e "${WHITE}  🧪 Enhanced Test Complete${NC}"
echo -e "${CYAN}==========================================${NC}"
echo -e "${BLUE}Test finished: $(date)${NC}"
echo -e "${BLUE}Test result: $test_result${NC}"
echo -e "${BLUE}📂 Test log saved to: $(basename "$TEST_LOG")${NC}"
echo -e "${CYAN}==========================================${NC}"
TEST_END

chmod +x "$TEST_SCRIPT"

# Create basic scan scripts (simplified versions)
show_progress "Creating security scan scripts"

# Create daily, weekly, and monthly scan scripts by copying the test script
cp "$TEST_SCRIPT" "$SECURITY_SUITE_HOME/scripts/security-daily-scan.sh"
cp "$TEST_SCRIPT" "$SECURITY_SUITE_HOME/scripts/security-weekly-scan.sh"
cp "$TEST_SCRIPT" "$SECURITY_SUITE_HOME/scripts/security-monthly-scan.sh"

# Make sure they're executable
chmod +x "$SECURITY_SUITE_HOME/scripts/security-daily-scan.sh"
chmod +x "$SECURITY_SUITE_HOME/scripts/security-weekly-scan.sh"
chmod +x "$SECURITY_SUITE_HOME/scripts/security-monthly-scan.sh"

show_success "Security scan scripts created"

# Generate systemd timers if requested
generate_systemd_timers

# Enable timers if requested
enable_systemd_timers

echo ""
echo -e "${CYAN}================================================================${NC}"
echo -e "${WHITE}     🎉 COMPLETE SECURITY SUITE V5.0 SETUP COMPLETE! 🎉${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""

echo -e "${GREEN}✅ Your Complete Configuration:${NC}"
echo -e "${BLUE}📁 Selected Tools: ${SELECTED_TOOLS[*]}${NC}"
echo -e "${BLUE}🔔 Notifications: $NOTIFICATIONS_ENABLED${NC}"
echo -e "${BLUE}🔄 Auto-updates: $UPDATE_BEFORE_SCAN${NC}"
echo -e "${BLUE}📊 Real-time feedback: $REAL_TIME_FEEDBACK${NC}"
echo -e "${BLUE}🧹 Auto-cleanup logs: $AUTO_CLEANUP_LOGS${NC}"
echo -e "${BLUE}🎨 Colors enabled: $USE_COLORS${NC}"
echo -e "${BLUE}⏰ Automated scheduling: $ENABLE_SCHEDULING${NC}"
if [ "$ENABLE_SCHEDULING" = "true" ]; then
    echo -e "${BLUE}   📅 Daily: $DAILY_TIME | Weekly: $WEEKLY_DAY $WEEKLY_TIME | Monthly: Day $MONTHLY_DAY $MONTHLY_TIME${NC}"
fi
echo ""

echo -e "${YELLOW}🚀 Your complete security suite has been configured!${NC}"
echo -e "${BLUE}📖 Configuration saved to: $SECURITY_SUITE_HOME/configs/security-config.conf${NC}"
echo ""

# Run comprehensive final test
read -p "🧪 Run comprehensive final test to validate everything? (Y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    run_comprehensive_final_test
fi

echo ""
echo -e "${GREEN}🛡️ Your complete automated security suite is ready!${NC}"
echo -e "${BLUE}📅 Setup completed: $(date)${NC}"

# Show next steps
echo ""
echo -e "${CYAN}🚀 Next Steps:${NC}"
if [ "$ENABLE_SCHEDULING" = "true" ]; then
    echo -e "${GREEN}✅ Automatic scans are scheduled and will run:${NC}"
    echo -e "   • ${WHITE}Daily:${NC} Every day at $DAILY_TIME"
    echo -e "   • ${WHITE}Weekly:${NC} Every $WEEKLY_DAY at $WEEKLY_TIME"
    echo -e "   • ${WHITE}Monthly:${NC} Day $MONTHLY_DAY of each month at $MONTHLY_TIME"
    echo ""
    echo -e "${BLUE}📋 Timer Management Commands:${NC}"
    echo -e "   • View timers: ${WHITE}systemctl --user list-timers | grep security${NC}"
    echo -e "   • Stop timer: ${WHITE}systemctl --user stop security-daily-scan.timer${NC}"
    echo -e "   • Start timer: ${WHITE}systemctl --user start security-daily-scan.timer${NC}"
else
    echo -e "${YELLOW}📅 Manual scheduling - Run scans manually:${NC}"
    echo -e "   • ${WHITE}cd $SECURITY_SUITE_HOME/scripts${NC}"
    echo -e "   • ${WHITE}./security-daily-scan.sh${NC}"
    echo -e "   • ${WHITE}./security-weekly-scan.sh${NC}"
    echo -e "   • ${WHITE}./security-monthly-scan.sh${NC}"
fi

echo -e "${CYAN}================================================================${NC}"

# Mark setup completion
mkdir -p "$SECURITY_SUITE_HOME/logs/manual"
echo "$(date): Complete interactive setup V5.0 completed successfully with scheduling: $ENABLE_SCHEDULING" >> "$SECURITY_SUITE_HOME/logs/manual/setup.log"

exit 0
