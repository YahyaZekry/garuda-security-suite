#!/bin/bash
#
# Garuda Security Suite Uninstaller - Version 1.0
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
CREATE_BACKUP=""
BACKUP_LOCATION=""

# Status tracking
ISSUES_FOUND=0
ACTIONS_TAKEN=0

echo -e "${CYAN}================================================================${NC}"
echo -e "${WHITE}      🗑️ GARUDA SECURITY SUITE UNINSTALLER 🗑️${NC}"
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
    
    # Check main directory
    if [ -d "$HOME/security-suite" ]; then
        found_components+=("Security suite directory (~$HOME/security-suite)")
        
        # Count files in subdirectories
        local script_count=$(find "$HOME/security-suite/scripts" -type f 2>/dev/null | wc -l)
        local log_count=$(find "$HOME/security-suite/logs" -type f 2>/dev/null | wc -l)
        
        if [ "$script_count" -gt 0 ]; then
            found_components+=("$script_count security script files")
        fi
        
        if [ "$log_count" -gt 0 ]; then
            found_components+=("$log_count log files")
        fi
        
        if [ -f "$HOME/security-suite/configs/security-config.conf" ]; then
            found_components+=("Configuration file")
        fi
    else
        missing_components+=("Security suite directory")
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
    
    # Display results
    if [ ${#found_components[@]} -gt 0 ]; then
        echo -e "${GREEN}📦 Found components to remove:${NC}"
        for component in "${found_components[@]}"; do
            echo -e "   • ${WHITE}$component${NC}"
        done
        echo ""
        return 0
    else
        echo -e "${YELLOW}🤷 No Garuda Security Suite installation found${NC}"
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
        BACKUP_LOCATION="$HOME/security-suite-backup-$timestamp"
        
        if [ -d "$HOME/security-suite" ]; then
            if cp -r "$HOME/security-suite" "$BACKUP_LOCATION"; then
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
        
        # Stop and disable all security timers
        local timers=("security-daily.timer" "security-weekly.timer" "security-monthly.timer")
        local services=("security-daily.service" "security-weekly.service" "security-monthly.service")
        
        for timer in "${timers[@]}"; do
            if systemctl --user is-enabled "$timer" &>/dev/null; then
                systemctl --user stop "$timer" 2>/dev/null
                systemctl --user disable "$timer" 2>/dev/null
                show_success "Stopped and disabled $timer"
            fi
        done
        
        for service in "${services[@]}"; do
            if systemctl --user is-active "$service" &>/dev/null; then
                systemctl --user stop "$service" 2>/dev/null
                show_success "Stopped $service"
            fi
        done
        
        # Remove unit files
        local removed_files=0
        while IFS= read -r -d '' file; do
            rm -f "$file"
            ((removed_files++))
        done < <(find ~/.config/systemd/user -name "*security*" -print0 2>/dev/null)
        
        if [ "$removed_files" -gt 0 ]; then
            show_success "Removed $removed_files systemd unit files"
        fi
        
        # Reload systemd daemon
        systemctl --user daemon-reload
        show_success "Reloaded systemd user daemon"
    fi
}

# Remove security suite directory
remove_security_suite_directory() {
    if [ "$REMOVE_SECURITY_SUITE_DIR" = "y" ]; then
        show_progress "Removing security suite directory"
        
        if [ -d "$HOME/security-suite" ]; then
            local dir_size=$(du -sh "$HOME/security-suite" 2>/dev/null | cut -f1)
            
            if rm -rf "$HOME/security-suite"; then
                show_success "Removed ~/security-suite directory ($dir_size)"
            else
                show_error "Failed to remove ~/security-suite directory"
                return 1
            fi
        else
            show_info "Security suite directory not found (already removed?)"
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
    [ "$REMOVE_SECURITY_SUITE_DIR" = "y" ] && echo -e "   • ${WHITE}Security suite directory${NC}"
    [ "$REMOVE_SECURITY_TOOLS" = "y" ] && echo -e "   • ${WHITE}Security tools packages${NC}"
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
    if [ -d "$HOME/security-suite" ]; then
        remaining_items+=("Security suite directory still exists")
    fi
    
    local remaining_timers=$(systemctl --user list-timers | grep -c security 2>/dev/null || echo "0")
    if [ "$remaining_timers" -gt 0 ]; then
        remaining_items+=("$remaining_timers systemd timers still active")
    fi
    
    local remaining_units=$(find ~/.config/systemd/user -name "*security*" 2>/dev/null | wc -l)
    if [ "$remaining_units" -gt 0 ]; then
        remaining_items+=("$remaining_units systemd unit files remaining")
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
    echo -e "${GREEN}🎉 Garuda Security Suite successfully uninstalled!${NC}"
else
    echo -e "${YELLOW}⚠️  Uninstall completed with $ISSUES_FOUND issue(s)${NC}"
    echo -e "${BLUE}💡 Check the messages above for details${NC}"
fi

echo -e "${CYAN}================================================================${NC}"

# Log completion
timestamp=$(date +"%Y-%m-%d %H:%M:%S")
echo "$timestamp: Security suite uninstall completed - Actions: $ACTIONS_TAKEN, Issues: $ISSUES_FOUND" >> "$HOME/security-suite-uninstall.log" 2>/dev/null

exit 0