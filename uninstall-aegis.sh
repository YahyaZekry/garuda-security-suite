#!/bin/bash
#
# Aegis Security Suite Uninstaller - Version 1.0
# Complete removal utility with selective options
#

# Colors for better UX
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Uninstall configuration
REMOVE_SYSTEMD_TIMERS=""
REMOVE_SECURITY_SUITE_DIR=""
REMOVE_SECURITY_TOOLS=""
REMOVE_SYSTEM_WIDE_DASHBOARD=""
REMOVE_DASHBOARD_USER=""
CREATE_BACKUP=""
BACKUP_LOCATION=""

# Set by scan_installation() if a team-mode (system-wide) dashboard install
# is detected - i.e. install-dashboard.sh or install-service.sh, not the
# default systemctl --user path.
SYSTEM_WIDE_DASHBOARD_FOUND=false

# Status tracking
ISSUES_FOUND=0
ACTIONS_TAKEN=0

echo -e "${CYAN}================================================================${NC}"
echo -e "${WHITE}      🗑️ AEGIS SECURITY SUITE UNINSTALLER 🗑️${NC}"
echo -e "${CYAN}================================================================${NC}"
echo -e "${YELLOW}Safe and complete removal of your security suite installation${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}❌ Please do NOT run this uninstaller as root!${NC}"
    echo -e "${YELLOW}💡 The script will ask for sudo password when needed.${NC}"
    exit 1
fi

# Utility functions
show_progress() {
    local message=$1
    echo -e "${YELLOW}⏳ $message...${NC}"
}

show_success() {
    local message=$1
    echo -e "${GREEN}✅ $message${NC}"
    ((ACTIONS_TAKEN++))
}

show_warning() {
    local message=$1
    echo -e "${YELLOW}⚠️  $message${NC}"
}

show_error() {
    local message=$1
    echo -e "${RED}❌ $message${NC}"
    ((ISSUES_FOUND++))
}

show_info() {
    local message=$1
    echo -e "${BLUE}ℹ️  $message${NC}"
}

ask_yes_no() {
    local prompt=$1
    local default=${2:-"n"}
    local response
    
    if [ "$default" = "y" ]; then
        read -p "$prompt (Y/n): " -n 1 -r response
    else
        read -p "$prompt (y/N): " -n 1 -r response
    fi
    echo ""
    
    if [ -z "$response" ]; then
        response=$default
    fi
    
    if [[ $response =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Scan current installation
scan_installation() {
    echo -e "${BLUE}🔍 Scanning current security suite installation...${NC}"
    echo ""
    
    local found_components=()
    local missing_components=()
    
    # Get security suite home directory
    AEGIS_HOME="${AEGIS_HOME:-$HOME/aegis-security-suite}"
    
    # Check main directory
    if [ -d "$AEGIS_HOME" ]; then
        found_components+=("Aegis Security Suite directory ($AEGIS_HOME)")
        
        # Count files in subdirectories
        local script_count=$(find "$AEGIS_HOME/scripts" -type f 2>/dev/null | wc -l)
        local log_count=$(find "$AEGIS_HOME/logs" -type f 2>/dev/null | wc -l)
        
        if [ "$script_count" -gt 0 ]; then
            found_components+=("$script_count security script files")
        fi
        
        if [ "$log_count" -gt 0 ]; then
            found_components+=("$log_count log files")
        fi
        
        if [ -f "$AEGIS_HOME/configs/security-config.conf" ]; then
            found_components+=("Configuration file")
        fi
    else
        missing_components+=("Aegis Security Suite directory")
    fi
    
    # Check systemd timers
    local timer_count=$(systemctl --user list-unit-files | grep -c "security.*timer" 2>/dev/null || echo "0")
    local service_count=$(systemctl --user list-unit-files | grep -c "security.*service" 2>/dev/null || echo "0")
    
    if [ "$timer_count" -gt 0 ]; then
        found_components+=("$timer_count systemd timers")
    fi
    
    if [ "$service_count" -gt 0 ]; then
        found_components+=("$service_count systemd services")
    fi
    
    # Check systemd unit files
    local unit_files=$(find ~/.config/systemd/user -name "*security*" 2>/dev/null | wc -l)
    if [ "$unit_files" -gt 0 ]; then
        found_components+=("$unit_files systemd unit files")
    fi

    # Check for a team-mode (system-wide) dashboard install - created by
    # install-dashboard.sh or install-service.sh, not the default
    # systemctl --user path, and not otherwise touched by this uninstaller.
    if [ -f "/etc/systemd/system/aegis-dashboard.service" ]; then
        found_components+=("System-wide dashboard service (/etc/systemd/system/aegis-dashboard.service, requires sudo to remove)")
        SYSTEM_WIDE_DASHBOARD_FOUND=true
    fi
    if id "aegis-dashboard" &>/dev/null; then
        found_components+=("Dedicated 'aegis-dashboard' system user account")
        SYSTEM_WIDE_DASHBOARD_FOUND=true
    fi
    if [ -f "/etc/nginx/sites-available/aegis-dashboard" ] || [ -L "/etc/nginx/sites-enabled/aegis-dashboard" ]; then
        found_components+=("Nginx reverse proxy config")
        SYSTEM_WIDE_DASHBOARD_FOUND=true
    fi
    if [ -f "/etc/logrotate.d/aegis-dashboard" ]; then
        found_components+=("Logrotate config for the dashboard")
        SYSTEM_WIDE_DASHBOARD_FOUND=true
    fi
    if [ -f "/etc/default/aegis-dashboard" ]; then
        found_components+=("Dashboard systemd environment file (/etc/default/aegis-dashboard)")
        SYSTEM_WIDE_DASHBOARD_FOUND=true
    fi

    # Display results
    if [ ${#found_components[@]} -gt 0 ]; then
        echo -e "${GREEN}📦 Found components to remove:${NC}"
        for component in "${found_components[@]}"; do
            echo -e "   • ${WHITE}$component${NC}"
        done
        echo ""
        return 0
    else
        echo -e "${YELLOW}🤷 No Aegis Security Suite installation found${NC}"
        echo -e "${BLUE}Nothing to uninstall!${NC}"
        echo ""
        return 1
    fi
}

# Create backup if requested
create_backup() {
    if [ "$CREATE_BACKUP" = "y" ]; then
        show_progress "Creating backup of security suite"
        
        local timestamp=$(date +"%Y%m%d_%H%M%S")
        BACKUP_LOCATION="$HOME/aegis-security-suite-backup-$timestamp"
        
        if [ -d "$AEGIS_HOME" ]; then
            if cp -r "$AEGIS_HOME" "$BACKUP_LOCATION"; then
                show_success "Backup created at: $BACKUP_LOCATION"
            else
                show_error "Failed to create backup"
                return 1
            fi
        fi
        
        # Backup systemd files separately
        local systemd_backup="$BACKUP_LOCATION/systemd-files"
        mkdir -p "$systemd_backup"
        
        if find ~/.config/systemd/user -name "*security*" -exec cp {} "$systemd_backup/" \; 2>/dev/null; then
            show_success "Systemd files backed up"
        fi
    fi
}

# Remove systemd timers and services
remove_systemd_components() {
    if [ "$REMOVE_SYSTEMD_TIMERS" = "y" ]; then
        show_progress "Removing systemd timers and services"
        
        # Stop and disable all security timers (including scan timers)
        local timers=("security-daily.timer" "security-weekly.timer" "security-monthly.timer"
                      "security-daily-scan.timer" "security-weekly-scan.timer" "security-monthly-scan.timer"
                      "behavioral-monitor.timer" "memory-monitor.timer" "threat-feed-update.timer"
                      "threat-feed-daily.timer" "threat-feed-cleanup.timer")
        local services=("security-daily.service" "security-weekly.service" "security-monthly.service"
                       "security-daily-scan.service" "security-weekly-scan.service" "security-monthly-scan.service"
                       "behavioral-monitor.service" "memory-monitor.service" "threat-feed-update.service"
                       "aegis-dashboard.service" "aegis-behavioral-monitor.service")
        
        for timer in "${timers[@]}"; do
            if systemctl --user list-unit-files | grep -q "^$timer" 2>/dev/null; then
                if systemctl --user is-active "$timer" &>/dev/null; then
                    systemctl --user stop "$timer" 2>/dev/null
                fi
                if systemctl --user is-enabled "$timer" &>/dev/null; then
                    systemctl --user disable "$timer" 2>/dev/null
                fi
                show_success "Stopped and disabled $timer"
            fi
        done
        
        for service in "${services[@]}"; do
            if systemctl --user list-unit-files | grep -q "^$service" 2>/dev/null; then
                if systemctl --user is-active "$service" &>/dev/null; then
                    systemctl --user stop "$service" 2>/dev/null
                fi
                if systemctl --user is-enabled "$service" &>/dev/null; then
                    systemctl --user disable "$service" 2>/dev/null
                fi
                show_success "Stopped and disabled $service"
            fi
        done
        
        # Remove unit files
        local removed_files=0
        while IFS= read -r -d '' file; do
            rm -f "$file"
            ((removed_files++))
        done < <(find ~/.config/systemd/user -name "*security*" -print0 2>/dev/null)
        
        # Also remove timer and service files that might not have "security" in the name
        while IFS= read -r -d '' file; do
            rm -f "$file"
            ((removed_files++))
        done < <(find ~/.config/systemd/user -name "*behavioral*" -print0 2>/dev/null)
        
        while IFS= read -r -d '' file; do
            rm -f "$file"
            ((removed_files++))
        done < <(find ~/.config/systemd/user -name "*memory-monitor*" -print0 2>/dev/null)
        
        while IFS= read -r -d '' file; do
            rm -f "$file"
            ((removed_files++))
        done < <(find ~/.config/systemd/user -name "*threat*" -print0 2>/dev/null)
        
        while IFS= read -r -d '' file; do
            rm -f "$file"
            ((removed_files++))
        done < <(find ~/.config/systemd/user -name "*aegis*" -print0 2>/dev/null)
        
        if [ "$removed_files" -gt 0 ]; then
            show_success "Removed $removed_files systemd unit files"
        fi
        
        # Reload systemd daemon
        systemctl --user daemon-reload
        show_success "Reloaded systemd user daemon"
    fi
}

# Remove team-mode (system-wide) dashboard components: the systemd service,
# env file, nginx config, logrotate config, and firewall rules created by
# install-dashboard.sh / install-service.sh. Requires sudo since none of
# this lives under the current user's own systemd --user scope.
remove_system_wide_dashboard() {
    show_progress "Removing system-wide dashboard components (requires sudo)"

    if [ -f "/etc/systemd/system/aegis-dashboard.service" ]; then
        sudo systemctl stop aegis-dashboard 2>/dev/null
        sudo systemctl disable aegis-dashboard 2>/dev/null
        sudo rm -f /etc/systemd/system/aegis-dashboard.service
        show_success "Removed system-wide dashboard service"
    fi

    if [ -f "/etc/default/aegis-dashboard" ]; then
        sudo rm -f /etc/default/aegis-dashboard
        show_success "Removed dashboard environment file"
    fi

    if [ -L "/etc/nginx/sites-enabled/aegis-dashboard" ] || [ -f "/etc/nginx/sites-available/aegis-dashboard" ]; then
        sudo rm -f /etc/nginx/sites-enabled/aegis-dashboard
        sudo rm -f /etc/nginx/sites-available/aegis-dashboard
        if command -v nginx &>/dev/null && sudo systemctl is-active --quiet nginx 2>/dev/null; then
            sudo nginx -t 2>/dev/null && sudo systemctl reload nginx 2>/dev/null
        fi
        show_success "Removed nginx reverse proxy config"
    fi

    if [ -f "/etc/logrotate.d/aegis-dashboard" ]; then
        sudo rm -f /etc/logrotate.d/aegis-dashboard
        show_success "Removed logrotate config"
    fi

    if [ -f "/usr/share/applications/aegis-dashboard.desktop" ]; then
        sudo rm -f /usr/share/applications/aegis-dashboard.desktop
        show_success "Removed desktop entry"
    fi

    # Best-effort firewall rule cleanup - safe to attempt even if the rule
    # was never added or the tool isn't in use.
    if command -v ufw &>/dev/null; then
        sudo ufw delete allow 8080/tcp 2>/dev/null
        sudo ufw delete allow 80/tcp comment "Aegis Dashboard HTTP" 2>/dev/null
        sudo ufw delete allow 443/tcp comment "Aegis Dashboard HTTPS" 2>/dev/null
    elif command -v firewall-cmd &>/dev/null; then
        sudo firewall-cmd --permanent --remove-port=8080/tcp 2>/dev/null
        sudo firewall-cmd --reload 2>/dev/null
    fi

    sudo systemctl daemon-reload 2>/dev/null
    show_success "System-wide dashboard components removed"
}

# Removing the dedicated system user is kept separate from
# remove_system_wide_dashboard() and asked about individually, since
# deleting a system account is a more sensitive action than removing
# config/unit files.
remove_dashboard_system_user() {
    if id "aegis-dashboard" &>/dev/null; then
        show_progress "Removing 'aegis-dashboard' system user account"
        if sudo userdel aegis-dashboard 2>/dev/null; then
            show_success "Removed aegis-dashboard system user"
        else
            show_warning "Could not remove aegis-dashboard user (it may still own running processes or files)"
        fi
    fi
}

# Remove security suite directory
remove_security_suite_directory() {
    if [ "$REMOVE_SECURITY_SUITE_DIR" = "y" ]; then
        show_progress "Removing security suite directory"
        
        if [ -d "$AEGIS_HOME" ]; then
            local dir_size=$(du -sh "$AEGIS_HOME" 2>/dev/null | cut -f1)
            
            if rm -rf "$AEGIS_HOME"; then
                show_success "Removed $AEGIS_HOME directory ($dir_size)"
            else
                show_error "Failed to remove $AEGIS_HOME directory"
                return 1
            fi
        else
            show_info "Aegis Security Suite directory not found (already removed?)"
        fi
    fi
}

# Remove security tools
remove_security_tools() {
    if [ "$REMOVE_SECURITY_TOOLS" = "y" ]; then
        show_progress "Checking security tools for removal"
        
        local tools=("clamav" "rkhunter" "chkrootkit" "lynis")
        local installed_tools=()
        
        # Check which tools are installed
        for tool in "${tools[@]}"; do
            if pacman -Qi "$tool" &>/dev/null; then
                installed_tools+=("$tool")
            fi
        done
        
        if [ ${#installed_tools[@]} -gt 0 ]; then
            echo -e "${YELLOW}🔧 Found installed security tools: ${installed_tools[*]}${NC}"
            
            if ask_yes_no "Remove these security tools with pacman?"; then
                show_progress "Removing security tools"
                
                if sudo pacman -Rns --noconfirm "${installed_tools[@]}"; then
                    show_success "Security tools removed: ${installed_tools[*]}"
                else
                    show_error "Failed to remove some security tools"
                fi
            else
                show_info "Security tools kept installed"
            fi
        else
            show_info "No security tools found to remove"
        fi
    fi
}

# Terminate running processes
terminate_running_processes() {
    show_progress "Terminating running security suite processes"
    
    # Get the current user's security suite directory (if it exists)
    local security_suite_dir=""
    if [ -n "$AEGIS_HOME" ] && [ -d "$AEGIS_HOME" ]; then
        security_suite_dir="$AEGIS_HOME"
    elif [ -d "$HOME/aegis-security-suite" ]; then
        security_suite_dir="$HOME/aegis-security-suite"
    elif [ -d "$HOME/security-suite" ]; then
        # Pre-rename (before 2026-07-18) default install directory
        security_suite_dir="$HOME/security-suite"
    elif [ -d "/opt/aegis-security-suite" ]; then
        security_suite_dir="/opt/aegis-security-suite"
    fi
    
    # Terminate memory-monitor.sh process
    local memory_monitor_pids=$(pgrep -f "memory-monitor.sh" 2>/dev/null)
    if [ -n "$memory_monitor_pids" ]; then
        for pid in $memory_monitor_pids; do
            if kill -0 "$pid" 2>/dev/null; then
                # Check if this is a security suite memory monitor
                local cmd=$(ps -p "$pid" -o cmd= 2>/dev/null)
                if [ -n "$security_suite_dir" ] && echo "$cmd" | grep -q "$security_suite_dir" 2>/dev/null; then
                    kill -TERM "$pid" 2>/dev/null
                    show_success "Terminated memory-monitor.sh process (PID: $pid)"
                    
                    # Wait a moment and check if it's still running
                    sleep 2
                    if kill -0 "$pid" 2>/dev/null; then
                        kill -KILL "$pid" 2>/dev/null
                        show_success "Force killed memory-monitor.sh process (PID: $pid)"
                    fi
                elif [ -z "$security_suite_dir" ]; then
                    # If we can't determine the security suite directory, terminate all memory-monitor.sh processes
                    kill -TERM "$pid" 2>/dev/null
                    show_success "Terminated memory-monitor.sh process (PID: $pid)"
                    
                    # Wait a moment and check if it's still running
                    sleep 2
                    if kill -0 "$pid" 2>/dev/null; then
                        kill -KILL "$pid" 2>/dev/null
                        show_success "Force killed memory-monitor.sh process (PID: $pid)"
                    fi
                fi
            fi
        done
    else
        show_info "No memory-monitor.sh processes found running"
    fi
    
    # Terminate other security suite processes
    local security_processes=("behavioral-monitor" "threat-intelligence" "aegis-dashboard" "python.*dashboard")
    
    for process_pattern in "${security_processes[@]}"; do
        local pids=$(pgrep -f "$process_pattern" 2>/dev/null)
        if [ -n "$pids" ]; then
            for pid in $pids; do
                if kill -0 "$pid" 2>/dev/null; then
                    # Check if the process is related to the security suite
                    local cmd=$(ps -p "$pid" -o cmd= 2>/dev/null)
                    if [ -n "$security_suite_dir" ] && echo "$cmd" | grep -q "$security_suite_dir" 2>/dev/null; then
                        kill -TERM "$pid" 2>/dev/null
                        show_success "Terminated security process (PID: $pid): $process_pattern"
                        
                        # Wait a moment and check if it's still running
                        sleep 2
                        if kill -0 "$pid" 2>/dev/null; then
                            kill -KILL "$pid" 2>/dev/null
                            show_success "Force killed security process (PID: $pid): $process_pattern"
                        fi
                    elif [ -z "$security_suite_dir" ] && echo "$cmd" | grep -q -E "(security-suite|aegis|behavioral|threat)" 2>/dev/null; then
                        # If we can't determine the security suite directory, use pattern matching
                        kill -TERM "$pid" 2>/dev/null
                        show_success "Terminated security process (PID: $pid): $process_pattern"
                        
                        # Wait a moment and check if it's still running
                        sleep 2
                        if kill -0 "$pid" 2>/dev/null; then
                            kill -KILL "$pid" 2>/dev/null
                            show_success "Force killed security process (PID: $pid): $process_pattern"
                        fi
                    fi
                fi
            done
        fi
    done
}

# Main uninstall process
main_uninstall_process() {
    echo -e "${YELLOW}🤔 What would you like to remove?${NC}"
    echo ""
    
    # Ask about each component
    if ask_yes_no "Remove systemd timers and services?"; then
        REMOVE_SYSTEMD_TIMERS="y"
    fi
    
    if ask_yes_no "Remove security suite directory and all files?"; then
        REMOVE_SECURITY_SUITE_DIR="y"
    fi
    
    if ask_yes_no "Remove security tools (ClamAV, rkhunter, chkrootkit, Lynis)?"; then
        REMOVE_SECURITY_TOOLS="y"
    fi

    # Team-mode (system-wide) dashboard install: only ask if scan_installation()
    # actually found one - meaningless otherwise, and it needs sudo, so it's
    # kept as its own explicit opt-in rather than folded into the systemd-timers
    # question above (which only ever touches the current user's own units).
    if [ "$SYSTEM_WIDE_DASHBOARD_FOUND" = true ]; then
        echo ""
        echo -e "${YELLOW}A team-mode (system-wide) dashboard install was detected.${NC}"
        if ask_yes_no "Remove system-wide dashboard components (systemd service, nginx, firewall rules - requires sudo)?"; then
            REMOVE_SYSTEM_WIDE_DASHBOARD="y"
        fi
        if ask_yes_no "Also remove the dedicated 'aegis-dashboard' system user account?"; then
            REMOVE_DASHBOARD_USER="y"
        fi
    fi

    # Ask about backup
    if [ "$REMOVE_SECURITY_SUITE_DIR" = "y" ]; then
        if ask_yes_no "Create backup before removal?"; then
            CREATE_BACKUP="y"
        fi
    fi

    echo ""

    # Confirm removal
    echo -e "${CYAN}📋 Removal Summary:${NC}"
    [ "$REMOVE_SYSTEMD_TIMERS" = "y" ] && echo -e "   • ${WHITE}Systemd timers and services${NC}"
    [ "$REMOVE_SECURITY_SUITE_DIR" = "y" ] && echo -e "   • ${WHITE}Aegis Security Suite directory${NC}"
    [ "$REMOVE_SECURITY_TOOLS" = "y" ] && echo -e "   • ${WHITE}Security tools packages${NC}"
    [ "$REMOVE_SYSTEM_WIDE_DASHBOARD" = "y" ] && echo -e "   • ${WHITE}System-wide dashboard components (sudo)${NC}"
    [ "$REMOVE_DASHBOARD_USER" = "y" ] && echo -e "   • ${WHITE}Dedicated 'aegis-dashboard' system user${NC}"
    [ "$CREATE_BACKUP" = "y" ] && echo -e "   • ${WHITE}Create backup first${NC}"
    echo ""

    if ! ask_yes_no "Proceed with removal?"; then
        echo -e "${BLUE}👋 Uninstall cancelled by user${NC}"
        exit 0
    fi

    echo ""
    echo -e "${CYAN}🗑️ Starting removal process...${NC}"
    echo ""

    # Execute removal steps
    [ "$CREATE_BACKUP" = "y" ] && create_backup
    [ "$REMOVE_SYSTEMD_TIMERS" = "y" ] && remove_systemd_components
    terminate_running_processes
    [ "$REMOVE_SYSTEM_WIDE_DASHBOARD" = "y" ] && remove_system_wide_dashboard
    [ "$REMOVE_DASHBOARD_USER" = "y" ] && remove_dashboard_system_user
    [ "$REMOVE_SECURITY_SUITE_DIR" = "y" ] && remove_security_suite_directory
    [ "$REMOVE_SECURITY_TOOLS" = "y" ] && remove_security_tools
}

# Final verification
verify_removal() {
    echo ""
    echo -e "${BLUE}🔍 Verifying removal...${NC}"
    echo ""
    
    local remaining_items=()
    
    # Check for remaining components
    AEGIS_HOME="${AEGIS_HOME:-$HOME/aegis-security-suite}"
    if [ -d "$AEGIS_HOME" ]; then
        remaining_items+=("Aegis Security Suite directory still exists")
    fi
    
    # Check for specific security scan timers mentioned in the test report
    local scan_timers=("security-daily-scan.timer" "security-weekly-scan.timer" "security-monthly-scan.timer")
    for timer in "${scan_timers[@]}"; do
        if systemctl --user list-timers | grep -q "$timer" 2>/dev/null; then
            remaining_items+=("$timer still active")
        fi
    done
    
    # Check for any remaining security-related timers
    local remaining_timers=$(systemctl --user list-timers | grep -E "(security|behavioral|threat|aegis)" 2>/dev/null | wc -l)
    if [ "$remaining_timers" -gt 0 ]; then
        remaining_items+=("$remaining_timers security-related timers still active")
    fi
    
    # Check for memory-monitor.sh process
    local memory_monitor_pids=$(pgrep -f "memory-monitor.sh" 2>/dev/null)
    if [ -n "$memory_monitor_pids" ]; then
        remaining_items+=("memory-monitor.sh process still running")
    fi
    
    # Check for other security suite processes
    local security_processes=$(pgrep -f "(behavioral-monitor|threat-intelligence|aegis-dashboard)" 2>/dev/null)
    if [ -n "$security_processes" ]; then
        remaining_items+=("Aegis Security Suite processes still running")
    fi
    
    # Check for remaining systemd unit files
    local remaining_security_units=$(find ~/.config/systemd/user -name "*security*" 2>/dev/null | wc -l)
    if [ "$remaining_security_units" -gt 0 ]; then
        remaining_items+=("$remaining_security_units security systemd unit files remaining")
    fi
    
    local remaining_behavioral_units=$(find ~/.config/systemd/user -name "*behavioral*" 2>/dev/null | wc -l)
    if [ "$remaining_behavioral_units" -gt 0 ]; then
        remaining_items+=("$remaining_behavioral_units behavioral systemd unit files remaining")
    fi
    
    local remaining_aegis_units=$(find ~/.config/systemd/user -name "*aegis*" 2>/dev/null | wc -l)
    if [ "$remaining_aegis_units" -gt 0 ]; then
        remaining_items+=("$remaining_aegis_units aegis systemd unit files remaining")
    fi

    # Check for remaining system-wide (team-mode) dashboard artifacts
    if [ "$REMOVE_SYSTEM_WIDE_DASHBOARD" = "y" ]; then
        [ -f "/etc/systemd/system/aegis-dashboard.service" ] && remaining_items+=("System-wide dashboard service still present")
        [ -f "/etc/nginx/sites-available/aegis-dashboard" ] || [ -L "/etc/nginx/sites-enabled/aegis-dashboard" ] && remaining_items+=("Nginx reverse proxy config still present")
        [ -f "/etc/logrotate.d/aegis-dashboard" ] && remaining_items+=("Dashboard logrotate config still present")
    fi
    if [ "$REMOVE_DASHBOARD_USER" = "y" ] && id "aegis-dashboard" &>/dev/null; then
        remaining_items+=("'aegis-dashboard' system user account still exists")
    fi

    # Report results
    if [ ${#remaining_items[@]} -eq 0 ]; then
        show_success "All selected components successfully removed!"
    else
        echo -e "${YELLOW}⚠️  Some items may still remain:${NC}"
        for item in "${remaining_items[@]}"; do
            echo -e "   • ${WHITE}$item${NC}"
        done
    fi
}

# Start uninstall process
if ! scan_installation; then
    exit 0
fi

echo ""
if ! ask_yes_no "Proceed with uninstaller?"; then
    echo -e "${BLUE}👋 Uninstaller cancelled${NC}"
    exit 0
fi

echo ""
main_uninstall_process

echo ""
echo -e "${CYAN}================================================================${NC}"
echo -e "${WHITE}      🎉 UNINSTALL PROCESS COMPLETE 🎉${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""

# Show final summary
verify_removal

echo ""
echo -e "${GREEN}📊 Summary:${NC}"
echo -e "${BLUE}   • Actions completed: $ACTIONS_TAKEN${NC}"
echo -e "${BLUE}   • Issues encountered: $ISSUES_FOUND${NC}"

if [ "$CREATE_BACKUP" = "y" ] && [ -n "$BACKUP_LOCATION" ]; then
    echo -e "${BLUE}   • Backup location: $BACKUP_LOCATION${NC}"
fi

echo ""
if [ "$ISSUES_FOUND" -eq 0 ]; then
    echo -e "${GREEN}🎉 Aegis Security Suite successfully uninstalled!${NC}"
else
    echo -e "${YELLOW}⚠️  Uninstall completed with $ISSUES_FOUND issue(s)${NC}"
    echo -e "${BLUE}💡 Check the messages above for details${NC}"
fi

echo -e "${CYAN}================================================================${NC}"

# Log completion
timestamp=$(date +"%Y-%m-%d %H:%M:%S")
echo "$timestamp: Aegis Security Suite uninstall completed - Actions: $ACTIONS_TAKEN, Issues: $ISSUES_FOUND" >> "$HOME/aegis-security-suite-uninstall.log" 2>/dev/null

exit 0