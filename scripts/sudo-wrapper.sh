#!/bin/bash
# Secure Sudo Wrapper
# Provides controlled, audited sudo access for security suite operations

# Load common functions
source "$(dirname "$0")/common-functions.sh"

# Allowed sudo commands with validation patterns
declare -A SUDO_COMMANDS=(
    ["freshclam"]="freshclam(--quiet|--no-warnings)?"
    ["clamscan"]="clamscan(-r|--recursive|--detect-pua|--detect-structured|--log).*"
    ["rkhunter"]="rkhunter(--update|--check|--propupd).*"
    ["chkrootkit"]="chkrootkit(-q|--quiet).*"
    ["lynis"]="lynis(audit system|audit dockerfile).*"
    ["loginctl"]="loginctl enable-linger [a-zA-Z0-9_-]+"
    ["pacman"]="pacman(-Sy|-S|-Rns)?(--noconfirm|--needed)? .*"
    ["systemctl"]="systemctl (--user)?(start|stop|restart|enable|disable) .*"
)

# Audit log for sudo operations
SUDO_AUDIT_LOG="$LOGS_DIR/audit/sudo_operations_$(date +%Y%m%d).log"

# Initialize sudo audit log
init_sudo_audit() {
    mkdir -p "$(dirname "$SUDO_AUDIT_LOG")"
    echo "Sudo Operations Audit Log - $(date)" > "$SUDO_AUDIT_LOG"
    echo "=====================================" >> "$SUDO_AUDIT_LOG"
    echo "User: $(whoami)" >> "$SUDO_AUDIT_LOG"
    echo "PID: $$" >> "$SUDO_AUDIT_LOG"
    echo "" >> "$SUDO_AUDIT_LOG"
}

# Validate sudo command against whitelist
validate_sudo_command() {
    local cmd="$1"
    local base_cmd=$(echo "$cmd" | awk '{print $1}')
    
    log_debug "Validating sudo command: $cmd"
    
    # Check if base command is allowed
    if [[ -z "${SUDO_COMMANDS[$base_cmd]}" ]]; then
        log_error "Sudo command not allowed: $base_cmd"
        return 1
    fi
    
    # Check command pattern
    local pattern="${SUDO_COMMANDS[$base_cmd]}"
    if [[ ! "$cmd" =~ ^$pattern$ ]]; then
        log_error "Sudo command pattern not allowed: $cmd (expected: $pattern)"
        return 1
    fi
    
    log_debug "Sudo command validated: $cmd"
    return 0
}

# Execute sudo command with audit trail
sudo_execute() {
    local cmd="$1"
    local description="${2:-Sudo operation}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Validate command before execution
    if ! validate_sudo_command "$cmd"; then
        log_error "Sudo command validation failed: $cmd"
        return 1
    fi
    
    # Log sudo operation
    echo "[$timestamp] User: $(whoami) PID: $$ Command: sudo $cmd Description: $description" >> "$SUDO_AUDIT_LOG"
    
    # Execute with timeout and error handling
    log_info "Executing sudo command: $description"
    
    local output
    local exit_code
    
    if output=$(timeout 300 sudo $cmd 2>&1); then
        exit_code=0
        log_debug "Sudo command succeeded: $description"
        if [ -n "$output" ]; then
            log_debug "Sudo output: $output"
        fi
    else
        exit_code=$?
        log_error "Sudo command failed: $description (exit code: $exit_code)"
        log_error "Sudo error output: $output"
        
        # Log failure to audit
        echo "[$timestamp] FAILED - User: $(whoami) PID: $$ Command: sudo $cmd Exit: $exit_code Output: $output" >> "$SUDO_AUDIT_LOG"
    fi
    
    return $exit_code
}

# Specific sudo functions for common operations
update_virus_definitions() {
    log_info "Updating virus definitions"
    sudo_execute "freshclam --quiet" "Update ClamAV virus definitions"
}

run_clamav_scan() {
    local scan_path="$1"
    local log_file="$2"
    
    sudo_execute "clamscan --recursive --detect-pua=yes --detect-structured=yes --log=$log_file $scan_path" "ClamAV scan of $scan_path"
}

update_rkhunter_database() {
    log_info "Updating Rkhunter database"
    sudo_execute "rkhunter --update --rwo" "Update Rkhunter database"
}

run_rkhunter_check() {
    local log_file="$1"
    
    sudo_execute "rkhunter --check --skip-keypress --report-warnings-only --logfile $log_file" "Rkhunter system check"
}

enable_user_linger() {
    local username="$1"
    
    # Validate username
    if [[ ! "$username" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "Invalid username for linger: $username"
        return 1
    fi
    
    sudo_execute "loginctl enable-linger $username" "Enable user linger for $username"
}

install_security_tools() {
    local tools=("$@")
    
    if [ ${#tools[@]} -eq 0 ]; then
        log_error "No tools specified for installation"
        return 1
    fi
    
    # Validate tool names
    local valid_tools=("clamav" "rkhunter" "chkrootkit" "lynis")
    for tool in "${tools[@]}"; do
        if ! printf '%s\n' "${valid_tools[@]}" | grep -q "^${tool}$"; then
            log_error "Invalid security tool: $tool"
            return 1
        fi
    done
    
    sudo_execute "pacman -Sy --needed --noconfirm ${tools[*]}" "Install security tools: ${tools[*]}"
}

remove_security_tools() {
    local tools=("$@")
    
    if [ ${#tools[@]} -eq 0 ]; then
        log_error "No tools specified for removal"
        return 1
    fi
    
    sudo_execute "pacman -Rns --noconfirm ${tools[*]}" "Remove security tools: ${tools[*]}"
}

# Additional security functions

# Secure file operations with sudo
secure_file_copy() {
    local source="$1"
    local destination="$2"
    
    # Validate paths
    if ! validate_path "$source" "Source path"; then
        return 1
    fi
    
    if ! validate_path "$destination" "Destination path"; then
        return 1
    fi
    
    sudo_execute "cp $source $destination" "Secure file copy from $source to $destination"
}

# Secure directory operations with sudo
secure_directory_create() {
    local directory="$1"
    local permissions="${2:-755}"
    local owner="${3:-root:root}"
    
    # Validate path
    if ! validate_path "$directory" "Directory path"; then
        return 1
    fi
    
    # Create directory with proper permissions
    sudo_execute "mkdir -p $directory" "Create directory: $directory"
    sudo_execute "chmod $permissions $directory" "Set permissions $permissions on $directory"
    sudo_execute "chown $owner $directory" "Set ownership $owner on $directory"
}

# Secure service management
manage_security_service() {
    local action="$1"
    local service_name="$2"
    
    # Validate action
    if [[ ! "$action" =~ ^(start|stop|restart|enable|disable)$ ]]; then
        log_error "Invalid service action: $action"
        return 1
    fi
    
    # Validate service name
    if [[ ! "$service_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "Invalid service name: $service_name"
        return 1
    fi
    
    sudo_execute "systemctl $action $service_name" "Systemctl $action for $service_name"
}

# Export functions
export -f init_sudo_audit validate_sudo_command sudo_execute
export -f update_virus_definitions run_clamav_scan update_rkhunter_database run_rkhunter_check
export -f enable_user_linger install_security_tools remove_security_tools
export -f secure_file_copy secure_directory_create manage_security_service