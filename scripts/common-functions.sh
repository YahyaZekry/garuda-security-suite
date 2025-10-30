#!/bin/bash
# Common Functions and Error Handling Framework
# Version: 2.0 - Enhanced with comprehensive error handling

# Error severity levels
declare -A ERROR_LEVELS=(
    ["DEBUG"]=0
    ["INFO"]=1
    ["WARNING"]=2
    ["ERROR"]=3
    ["CRITICAL"]=4
)

# Current error level (can be configured)
CURRENT_ERROR_LEVEL=${ERROR_LEVELS[INFO]}

# Logging configuration
LOG_FILE=""
ERROR_LOG_FILE=""
AUDIT_LOG_FILE=""

# Color codes for output
declare -A COLORS=(
    ["DEBUG"]='\033[0;36m'
    ["INFO"]='\033[0;32m'
    ["WARNING"]='\033[1;33m'
    ["ERROR"]='\033[0;31m'
    ["CRITICAL"]='\033[1;31m'
    ["NC"]='\033[0m'
)

# Initialize logging system
init_logging() {
    local log_type="$1"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    
    case "$log_type" in
        "daily")
            LOG_FILE="$LOGS_DIR/daily/security_scan_${timestamp}.log"
            ;;
        "weekly")
            LOG_FILE="$LOGS_DIR/weekly/security_scan_${timestamp}.log"
            ;;
        "monthly")
            LOG_FILE="$LOGS_DIR/monthly/security_scan_${timestamp}.log"
            ;;
        "manual")
            LOG_FILE="$LOGS_DIR/manual/security_scan_${timestamp}.log"
            ;;
        *)
            LOG_FILE="$LOGS_DIR/manual/security_scan_${timestamp}.log"
            ;;
    esac
    
    ERROR_LOG_FILE="$LOGS_DIR/error/security_errors_${timestamp}.log"
    AUDIT_LOG_FILE="$LOGS_DIR/audit/security_audit_${timestamp}.log"
    
    # Ensure log directories exist
    mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$ERROR_LOG_FILE")" "$(dirname "$AUDIT_LOG_FILE")"
    
    # Initialize log files
    echo "Security Suite Log - $(date)" > "$LOG_FILE"
    echo "=============================" >> "$LOG_FILE"
    echo "Log Type: $log_type" >> "$LOG_FILE"
    echo "User: $(whoami)" >> "$LOG_FILE"
    echo "PID: $$" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
}

# Enhanced logging function with error handling
log_message() {
    local level="$1"
    local message="$2"
    local exit_code="${3:-0}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Check if we should log this level
    if [ ${ERROR_LEVELS[$level]} -lt $CURRENT_ERROR_LEVEL ]; then
        return 0
    fi
    
    # Format message
    local formatted_message="[$timestamp] [$level] $message"
    
    # Output to console with colors
    if [ -t 1 ]; then
        echo -e "${COLORS[$level]}$formatted_message${COLORS[NC]}"
    else
        echo "$formatted_message"
    fi
    
    # Write to appropriate log files
    if [ -n "$LOG_FILE" ]; then
        echo "$formatted_message" >> "$LOG_FILE"
    fi
    
    # Write errors and critical messages to error log
    if [ "$level" = "ERROR" ] || [ "$level" = "CRITICAL" ]; then
        if [ -n "$ERROR_LOG_FILE" ]; then
            echo "$formatted_message" >> "$ERROR_LOG_FILE"
        fi
        if [ -n "$AUDIT_LOG_FILE" ]; then
            echo "$formatted_message (Exit Code: $exit_code)" >> "$AUDIT_LOG_FILE"
        fi
    fi
    
    # Handle critical errors
    if [ "$level" = "CRITICAL" ]; then
        handle_critical_error "$message" "$exit_code"
    fi
}

# Convenience logging functions
log_debug() { log_message "DEBUG" "$1"; }
log_info() { log_message "INFO" "$1"; }
log_warning() { log_message "WARNING" "$1"; }
log_error() { log_message "ERROR" "$1" "$2"; }
log_critical() { log_message "CRITICAL" "$1" "$2"; }
log_success() { log_message "INFO" "$1"; }

# Error handling and recovery
handle_critical_error() {
    local error_message="$1"
    local exit_code="$2"
    
    # Send critical error notification
    if command -v notify-send &>/dev/null && [ "$NOTIFICATIONS_ENABLED" = true ]; then
        notify-send -u critical -i "security-error" "🚨 Critical Security Suite Error" "$error_message" 2>/dev/null
    fi
    
    # Attempt cleanup
    cleanup_on_error "$exit_code"
    
    # Exit with appropriate code
    exit "${exit_code:-1}"
}

# Cleanup function for error conditions
cleanup_on_error() {
    local exit_code="$1"
    
    log_info "Performing error cleanup (exit code: $exit_code)"
    
    # Remove temporary files
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
        log_info "Cleaned up temporary directory: $TEMP_DIR"
    fi
    
    # Kill any background processes
    jobs -p | xargs -r kill 2>/dev/null
    
    # Log cleanup completion
    log_info "Error cleanup completed"
}

# Input validation functions
validate_input() {
    local input="$1"
    input_type="$2"
    local validation_pattern="$3"
    local error_message="$4"
    
    case "$input_type" in
        "path")
            validate_path "$input" "$error_message"
            ;;
        "time")
            validate_time "$input" "$error_message"
            ;;
        "email")
            validate_email "$input" "$error_message"
            ;;
        "pattern")
            validate_pattern "$input" "$validation_pattern" "$error_message"
            ;;
        *)
            log_error "Unknown input validation type: $input_type"
            return 1
            ;;
    esac
}

validate_path() {
    local path="$1"
    local error_message="${2:-Invalid path format}"
    
    # Check if path is absolute
    if [[ ! "$path" =~ ^/ ]]; then
        log_error "$error_message: Path must be absolute"
        return 1
    fi
    
    # Check for directory traversal
    if [[ "$path" =~ \.\. ]]; then
        log_error "$error_message: Path cannot contain parent directory references"
        return 1
    fi
    
    # Check for dangerous paths
    local dangerous_paths=("/etc" "/boot" "/sys" "/proc" "/dev")
    for dangerous_path in "${dangerous_paths[@]}"; do
        if [[ "$path" =~ ^$dangerous_path ]]; then
            log_error "$error_message: Path contains dangerous system directory"
            return 1
        fi
    done
    
    return 0
}

validate_time() {
    local time="$1"
    local error_message="${2:-Invalid time format}"
    
    # Check HH:MM format
    if [[ ! "$time" =~ ^([0-1][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
        log_error "$error_message: Time must be in HH:MM format (24-hour)"
        return 1
    fi
    
    return 0
}

validate_email() {
    local email="$1"
    local error_message="${2:-Invalid email format}"
    
    # Basic email validation
    if [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        log_error "$error_message: Invalid email format"
        return 1
    fi
    
    return 0
}

validate_pattern() {
    local input="$1"
    local pattern="$2"
    local error_message="$3"
    
    if [[ ! "$input" =~ $pattern ]]; then
        log_error "$error_message: Input does not match required pattern"
        return 1
    fi
    
    return 0
}

# Command execution with error handling
execute_command() {
    local cmd="$1"
    local description="${2:-Command execution}"
    local error_message="${3:-Command failed}"
    local max_retries="${4:-3}"
    local retry_delay="${5:-5}"
    
    local attempt=1
    local exit_code=0
    
    log_debug "Executing: $cmd"
    
    while [ $attempt -le $max_retries ]; do
        log_info "$description (attempt $attempt/$max_retries)"
        
        # Execute command and capture output
        local output
        if output=$(eval "$cmd" 2>&1); then
            exit_code=0
            log_debug "$description succeeded"
            if [ -n "$output" ]; then
                log_debug "Command output: $output"
            fi
            break
        else
            exit_code=$?
            log_warning "$description failed (attempt $attempt/$max_retries): $output"
            
            if [ $attempt -lt $max_retries ]; then
                log_info "Retrying in $retry_delay seconds..."
                sleep $retry_delay
            fi
        fi
        
        ((attempt++))
    done
    
    if [ $exit_code -ne 0 ]; then
        log_error "$error_message after $max_retries attempts" $exit_code
        return $exit_code
    fi
    
    return 0
}

# Resource monitoring
check_disk_space() {
    local required_mb="$1"
    local path="${2:-$SECURITY_SUITE_HOME}"
    
    local available_mb=$(df -m "$path" | awk 'NR==2 {print $4}')
    
    if [ "$available_mb" -lt "$required_mb" ]; then
        log_error "Insufficient disk space: ${available_mb}MB available, ${required_mb}MB required"
        return 1
    fi
    
    log_debug "Disk space check passed: ${available_mb}MB available"
    return 0
}

check_memory_usage() {
    local max_percent="${1:-80}"
    
    local memory_percent=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    
    if [ "$memory_percent" -gt "$max_percent" ]; then
        log_warning "High memory usage: ${memory_percent}% (threshold: ${max_percent}%)"
        return 1
    fi
    
    log_debug "Memory usage check passed: ${memory_percent}%"
    return 0
}

# Notification system
send_notification() {
    local title="$1"
    local message="$2"
    local icon="${3:-security-high}"
    local urgency="${4:-normal}"
    
    # Only send if notifications are enabled
    if [ "$NOTIFICATIONS_ENABLED" != true ]; then
        return 0
    fi
    
    # Try desktop notification first
    if command -v notify-send &>/dev/null; then
        notify-send -u "$urgency" -i "$icon" "$title" "$message" 2>/dev/null
        log_debug "Desktop notification sent: $title - $message"
    else
        log_debug "Desktop notifications not available"
    fi
    
    # Log the notification
    log_info "Notification: $title - $message"
}

# Error recovery mechanisms

# Network operation with retry
download_with_retry() {
    local url="$1"
    local output="$2"
    local max_retries="${3:-3}"
    local timeout="${4:-30}"
    
    for ((i=1; i<=max_retries; i++)); do
        log_info "Downloading $url (attempt $i/$max_retries)"
        
        if wget --timeout="$timeout" --tries=1 -O "$output" "$url" 2>/dev/null; then
            log_info "Download successful"
            return 0
        else
            log_warning "Download failed (attempt $i/$max_retries)"
            rm -f "$output"  # Remove partial download
            
            if [ $i -lt $max_retries ]; then
                local backoff=$((i * 5))
                log_info "Retrying in $backoff seconds..."
                sleep $backoff
            fi
        fi
    done
    
    log_error "Failed to download after $max_retries attempts"
    return 1
}

# Graceful degradation for missing tools
run_scanner_with_fallback() {
    local primary_tool="$1"
    local fallback_tool="$2"
    local scan_args=("${@:3}")
    
    if command -v "$primary_tool" &>/dev/null; then
        log_info "Using primary scanner: $primary_tool"
        "$primary_tool" "${scan_args[@]}"
    elif command -v "$fallback_tool" &>/dev/null; then
        log_warning "Primary tool $primary_tool not available, using fallback: $fallback_tool"
        "$fallback_tool" "${scan_args[@]}"
    else
        log_error "Neither $primary_tool nor $fallback_tool available"
        return 1
    fi
}

# Exponential backoff retry function
retry_with_backoff() {
    local cmd="$1"
    local max_retries="${2:-3}"
    local base_delay="${3:-1}"
    local max_delay="${4:-60}"
    
    local attempt=1
    local exit_code=0
    
    while [ $attempt -le $max_retries ]; do
        log_info "Executing command (attempt $attempt/$max_retries): $cmd"
        
        if eval "$cmd"; then
            exit_code=0
            log_debug "Command succeeded on attempt $attempt"
            return 0
        else
            exit_code=$?
            log_warning "Command failed on attempt $attempt/$max_retries"
            
            if [ $attempt -lt $max_retries ]; then
                local delay=$((base_delay * (2 ** (attempt - 1))))
                # Cap the delay at max_delay
                [ "$delay" -gt "$max_delay" ] && delay=$max_delay
                
                log_info "Retrying in $delay seconds (exponential backoff)..."
                sleep $delay
            fi
        fi
        
        ((attempt++))
    done
    
    log_error "Command failed after $max_retries attempts with exponential backoff"
    return $exit_code
}

# Resource monitoring during operations
monitor_resources_during_operation() {
    local operation_cmd="$1"
    local operation_name="${2:-Operation}"
    local max_memory_mb="${3:-500}"
    local max_disk_mb="${4:-100}"
    
    # Start resource monitoring in background
    local monitor_pid=""
    local temp_monitor_file="/tmp/resource_monitor_$$"
    
    (
        while true; do
            local memory_usage=$(free -m | awk 'NR==2{print $3}')
            local disk_usage=$(df -m "$SECURITY_SUITE_HOME" | awk 'NR==2 {print $3}')
            
            echo "$(date '+%Y-%m-%d %H:%M:%S') MEMORY:$memory_usage DISK:$disk_usage" >> "$temp_monitor_file"
            
            if [ "$memory_usage" -gt "$max_memory_mb" ]; then
                log_warning "High memory usage during $operation_name: ${memory_usage}MB (threshold: ${max_memory_mb}MB)"
            fi
            
            if [ "$disk_usage" -gt "$max_disk_mb" ]; then
                log_warning "High disk usage during $operation_name: ${disk_usage}MB (threshold: ${max_disk_mb}MB)"
            fi
            
            sleep 5
        done
    ) &
    monitor_pid=$!
    
    # Execute the operation
    log_info "Starting $operation_name with resource monitoring"
    local operation_result=0
    eval "$operation_cmd" || operation_result=$?
    
    # Stop monitoring
    kill $monitor_pid 2>/dev/null
    wait $monitor_pid 2>/dev/null
    
    # Log resource usage summary
    if [ -f "$temp_monitor_file" ]; then
        local max_memory=$(awk -F: '{print $2}' "$temp_monitor_file" | sort -n | tail -1)
        local max_disk=$(awk -F: '{print $3}' "$temp_monitor_file" | sort -n | tail -1)
        
        log_info "Resource usage summary for $operation_name - Max Memory: ${max_memory}MB, Max Disk: ${max_disk}MB"
        rm -f "$temp_monitor_file"
    fi
    
    return $operation_result
}

# Export all functions
export -f log_message log_debug log_info log_warning log_error log_critical log_success
export -f init_logging handle_critical_error cleanup_on_error
export -f validate_input validate_path validate_time validate_email validate_pattern
export -f execute_command check_disk_space check_memory_usage
export -f send_notification download_with_retry run_scanner_with_fallback
export -f retry_with_backoff monitor_resources_during_operation