# Security Suite API Documentation

## Overview

This document describes the internal APIs and functions used by the Garuda Security Suite. The API is organized into several modules that provide logging, security, scanning, and system management functionality.

## Core Functions

### Logging Functions

The logging system provides comprehensive message handling with severity levels and multiple output destinations.

#### `init_logging(log_type)`

Initializes the logging system for a specific scan type.

**Parameters:**
- `log_type` (string): Type of log ("daily", "weekly", "monthly", "manual")

**Returns:** None

**Example:**
```bash
init_logging "daily"
```

#### `log_message(level, message, exit_code)`

Core logging function with severity levels and file output.

**Parameters:**
- `level` (string): Log level ("DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL")
- `message` (string): Log message content
- `exit_code` (int, optional): Exit code for error conditions

**Returns:** None

**Example:**
```bash
log_message "INFO" "Starting security scan"
log_message "ERROR" "Scan failed" 1
```

#### Convenience Logging Functions

- `log_debug(message)` - Debug level messages
- `log_info(message)` - Informational messages
- `log_warning(message)` - Warning messages
- `log_error(message, exit_code)` - Error messages with optional exit code
- `log_critical(message, exit_code)` - Critical errors that trigger exit
- `log_success(message)` - Success messages (alias for log_info)

**Example:**
```bash
log_info "Scan completed successfully"
log_warning "Directory not found: /path/to/dir"
log_error "Permission denied" 13
```

### Security Functions

Security functions provide input validation, command execution, and secure operations.

#### `validate_input(input, type, validation_pattern, error_message)`

Validates user input against specified patterns and types.

**Parameters:**
- `input` (string): Input value to validate
- `type` (string): Input type ("path", "time", "email", "pattern")
- `validation_pattern` (string): Regex pattern for validation
- `error_message` (string): Error message for validation failures

**Returns:** 0 on success, 1 on failure

**Example:**
```bash
validate_input "/home/user" "path" "" "Invalid path"
validate_input "09:30" "time" "" "Invalid time format"
```

#### `validate_path(path, error_message)`

Validates file system paths for security and format.

**Parameters:**
- `path` (string): File system path to validate
- `error_message` (string): Custom error message

**Returns:** 0 on success, 1 on failure

**Security Checks:**
- Path must be absolute
- No directory traversal (../)
- No dangerous system directories (/etc, /boot, /sys, /proc, /dev)

**Example:**
```bash
validate_path "/home/user/documents" "Invalid document path"
```

#### `validate_time(time, error_message)`

Validates time format in HH:MM 24-hour format.

**Parameters:**
- `time` (string): Time string to validate
- `error_message` (string): Custom error message

**Returns:** 0 on success, 1 on failure

**Example:**
```bash
validate_time "14:30" "Invalid time format"
```

#### `validate_email(email, error_message)`

Validates email address format.

**Parameters:**
- `email` (string): Email address to validate
- `error_message` (string): Custom error message

**Returns:** 0 on success, 1 on failure

**Example:**
```bash
validate_email "user@example.com" "Invalid email format"
```

#### `execute_command(cmd, description, error_message, max_retries, retry_delay)`

Executes commands with retry logic and error handling.

**Parameters:**
- `cmd` (string): Command to execute
- `description` (string): Human-readable description
- `error_message` (string): Error message for failures
- `max_retries` (int, optional): Maximum retry attempts (default: 3)
- `retry_delay` (int, optional): Delay between retries in seconds (default: 5)

**Returns:** 0 on success, non-zero on failure

**Example:**
```bash
execute_command "pacman -Sy" "Update package database" "Package update failed" 3 5
```

### Scanner Functions

Scanner functions provide interfaces to various security tools.

#### `clamav_scan(directories...)`

Performs comprehensive ClamAV antivirus scanning.

**Parameters:**
- `directories...` (string): One or more directories to scan

**Returns:** 0 on success, non-zero on failure

**Features:**
- Updates virus definitions before scanning (if configured)
- Recursive scanning with PUA detection
- Structured data detection (SSN, credit cards)
- Detailed logging and result processing

**Example:**
```bash
clamav_scan "/home/user/Documents" "/home/user/Downloads"
```

#### `clamav_quick_scan(directories...)`

Performs faster ClamAV scanning for daily scans.

**Parameters:**
- `directories...` (string): One or more directories to scan

**Returns:** 0 on success, non-zero on failure

**Features:**
- Limited file size scanning (50MB max)
- Faster scan options
- Suitable for daily automated scans

**Example:**
```bash
clamav_quick_scan "/home/user/Desktop"
```

#### `rkhunter_scan()`

Performs rootkit detection using Rkhunter.

**Parameters:** None

**Returns:** 0 on success, non-zero on failure

**Features:**
- Updates Rkhunter database before scanning
- System file integrity checking
- Rootkit and backdoor detection
- Warning-only reporting mode

**Example:**
```bash
rkhunter_scan
```

#### `process_clamav_results(log_file, duration, exit_code)`

Processes ClamAV scan results and generates notifications.

**Parameters:**
- `log_file` (string): Path to ClamAV log file
- `duration` (int): Scan duration in seconds
- `exit_code` (int): ClamAV exit code

**Returns:** None

**Example:**
```bash
process_clamav_results "/path/to/clamav.log" 120 0
```

### Sudo Wrapper Functions

Secure sudo operations with validation and audit logging.

#### `sudo_execute(cmd, description)`

Executes sudo commands with validation and audit logging.

**Parameters:**
- `cmd` (string): Command to execute with sudo
- `description` (string): Human-readable description

**Returns:** 0 on success, non-zero on failure

**Security Features:**
- Command validation against whitelist
- Audit logging of all operations
- Timeout protection (300 seconds)
- Error handling and logging

**Example:**
```bash
sudo_execute "freshclam --quiet" "Update virus definitions"
```

#### `validate_sudo_command(cmd)`

Validates sudo commands against allowed patterns.

**Parameters:**
- `cmd` (string): Command to validate

**Returns:** 0 on success, 1 on failure

**Allowed Commands:**
- `freshclam` (with limited options)
- `clamscan` (with security options)
- `rkhunter` (update/check operations)
- `chkrootkit` (with quiet option)
- `lynis` (audit operations)
- `loginctl` (linger operations)
- `pacman` (package management)
- `systemctl` (service management)

**Example:**
```bash
validate_sudo_command "freshclam --quiet"
```

#### `init_sudo_audit()`

Initializes sudo audit logging system.

**Parameters:** None

**Returns:** None

**Example:**
```bash
init_sudo_audit
```

### Notification Functions

Desktop notification system for user feedback.

#### `send_notification(title, message, icon, urgency)`

Sends desktop notifications to the user.

**Parameters:**
- `title` (string): Notification title
- `message` (string): Notification message
- `icon` (string, optional): Icon name (default: "security-high")
- `urgency` (string, optional): Urgency level ("low", "normal", "critical")

**Returns:** None

**Example:**
```bash
send_notification "Scan Complete" "Security scan finished successfully" "security-high" "normal"
```

### Resource Monitoring Functions

System resource monitoring and management.

#### `check_disk_space(required_mb, path)`

Checks available disk space.

**Parameters:**
- `required_mb` (int): Required disk space in MB
- `path` (string, optional): Path to check (default: $SECURITY_SUITE_HOME)

**Returns:** 0 on success, 1 on failure

**Example:**
```bash
check_disk_space 100 "/home/user/security-suite"
```

#### `check_memory_usage(max_percent)`

Checks current memory usage.

**Parameters:**
- `max_percent` (int, optional): Maximum allowed memory percentage (default: 80)

**Returns:** 0 on success, 1 on failure

**Example:**
```bash
check_memory_usage 85
```

#### `monitor_resources_during_operation(operation_cmd, operation_name, max_memory_mb, max_disk_mb)`

Monitors resource usage during operations.

**Parameters:**
- `operation_cmd` (string): Command to monitor
- `operation_name` (string): Operation description
- `max_memory_mb` (int, optional): Memory threshold in MB (default: 500)
- `max_disk_mb` (int, optional): Disk threshold in MB (default: 100)

**Returns:** Exit code of the operation

**Example:**
```bash
monitor_resources_during_operation "clamav_scan /home" "ClamAV Scan" 500 100
```

### Error Recovery Functions

Error handling and recovery mechanisms.

#### `handle_critical_error(error_message, exit_code)`

Handles critical errors with cleanup and exit.

**Parameters:**
- `error_message` (string): Error description
- `exit_code` (int): Exit code for termination

**Returns:** None (exits program)

**Example:**
```bash
handle_critical_error "Configuration file not found" 2
```

#### `cleanup_on_error(exit_code)`

Performs cleanup operations during error conditions.

**Parameters:**
- `exit_code` (int): Exit code that triggered cleanup

**Returns:** None

**Cleanup Actions:**
- Remove temporary directories
- Kill background processes
- Log cleanup completion

**Example:**
```bash
cleanup_on_error 1
```

#### `download_with_retry(url, output, max_retries, timeout)`

Downloads files with retry logic and exponential backoff.

**Parameters:**
- `url` (string): URL to download
- `output` (string): Output file path
- `max_retries` (int, optional): Maximum retry attempts (default: 3)
- `timeout` (int, optional): Download timeout in seconds (default: 30)

**Returns:** 0 on success, 1 on failure

**Example:**
```bash
download_with_retry "https://example.com/file.tar.gz" "/tmp/file.tar.gz" 3 30
```

#### `retry_with_backoff(cmd, max_retries, base_delay, max_delay)`

Retries commands with exponential backoff.

**Parameters:**
- `cmd` (string): Command to execute
- `max_retries` (int, optional): Maximum retry attempts (default: 3)
- `base_delay` (int, optional): Base delay in seconds (default: 1)
- `max_delay` (int, optional): Maximum delay in seconds (default: 60)

**Returns:** 0 on success, 1 on failure

**Example:**
```bash
retry_with_backoff "wget https://example.com/data" 5 2 30
```

## Configuration

### Environment Variables

The following environment variables control the behavior of the Security Suite:

#### Core Paths
- `SECURITY_SUITE_HOME` - Base directory for security suite installation
- `SCRIPTS_DIR` - Directory containing script files
- `LOGS_DIR` - Directory for log files
- `CONFIGS_DIR` - Directory for configuration files
- `BACKUPS_DIR` - Directory for backup files

#### User Information
- `CURRENT_USER` - Current username (auto-detected)
- `CURRENT_HOME` - Current user home directory (auto-detected)

#### Notification Settings
- `NOTIFICATIONS_ENABLED` - Enable/disable desktop notifications (true/false)
- `NOTIFICATION_URGENCY` - Default notification urgency level

#### Scanning Preferences
- `UPDATE_BEFORE_SCAN` - Update security tools before scanning (true/false)
- `REAL_TIME_FEEDBACK` - Enable real-time scan feedback (true/false)

#### Security Tools Selection
- `SELECTED_SECURITY_TOOLS` - Array of enabled security tools

#### Scan Directories
- `DAILY_SCAN_DIRS` - Array of directories for daily scanning
- `WEEKLY_SCAN_DIRS` - Array of directories for weekly scanning
- `MONTHLY_SCAN_DIRS` - Array of directories for monthly scanning

#### Schedule Settings
- `DAILY_TIME` - Daily scan time (HH:MM format)
- `WEEKLY_DAY` - Weekly scan day (Sun/Mon/Tue/Wed/Thu/Fri/Sat)
- `WEEKLY_TIME` - Weekly scan time (HH:MM format)
- `MONTHLY_DAY` - Monthly scan day (1-28)
- `MONTHLY_TIME` - Monthly scan time (HH:MM format)

### Configuration File Format

The main configuration file is located at `configs/security-config.conf` and follows bash variable syntax:

```bash
# Security Suite Configuration

# Dynamic path configuration
SECURITY_SUITE_HOME="$HOME/security-suite"
SCRIPTS_DIR="$SECURITY_SUITE_HOME/scripts"
LOGS_DIR="$SECURITY_SUITE_HOME/logs"
CONFIGS_DIR="$SECURITY_SUITE_HOME/configs"
BACKUPS_DIR="$SECURITY_SUITE_HOME/backups"
CURRENT_USER="$(whoami)"
CURRENT_HOME="$HOME"

# Notification settings
NOTIFICATIONS_ENABLED=true
NOTIFICATION_URGENCY="normal"

# Scanning preferences
UPDATE_BEFORE_SCAN=true
REAL_TIME_FEEDBACK=false

# Security tools selection
SELECTED_SECURITY_TOOLS=("clamav" "rkhunter")

# Scan directories
DAILY_SCAN_DIRS=("$HOME/Documents" "$HOME/Downloads" "$HOME/Desktop")
WEEKLY_SCAN_DIRS=("$HOME")
MONTHLY_SCAN_DIRS=("$HOME" "/tmp" "/var/tmp")

# Schedule settings
DAILY_TIME="02:00"
WEEKLY_DAY="Sun"
WEEKLY_TIME="03:00"
MONTHLY_DAY="1"
MONTHLY_TIME="04:00"
```

## Error Codes

The Security Suite uses standardized exit codes:

- `0` - Success
- `1` - General error
- `2` - Configuration error
- `3` - Permission denied
- `4` - File not found
- `5` - Invalid input
- `6` - Network error
- `7` - Security tool not found
- `8` - Insufficient resources
- `9` - Critical system error

## Logging Levels

The logging system supports the following severity levels:

- `DEBUG` (0) - Detailed debugging information
- `INFO` (1) - General information messages
- `WARNING` (2) - Warning messages
- `ERROR` (3) - Error messages
- `CRITICAL` (4) - Critical errors that require immediate attention

## Usage Examples

### Basic Scanning

```bash
#!/bin/bash
# Load configuration and functions
source "$HOME/security-suite/configs/security-config.conf"
source "$HOME/security-suite/scripts/common-functions.sh"

# Initialize logging
init_logging "manual"

# Perform ClamAV scan
source "$HOME/security-suite/scripts/scanners/clamav-scanner.sh"
clamav_scan "/home/user/Documents"

# Check result
if [ $? -eq 0 ]; then
    log_info "Scan completed successfully"
else
    log_error "Scan failed" $?
fi
```

### Custom Scanner Integration

```bash
#!/bin/bash
# Custom scanner integration example

source "$HOME/security-suite/scripts/common-functions.sh"

# Initialize logging
init_logging "manual")

# Custom scan function
custom_security_scan() {
    local scan_dir="$1"
    
    log_info "Starting custom security scan of: $scan_dir"
    
    # Check disk space
    if ! check_disk_space 100 "$scan_dir"; then
        log_error "Insufficient disk space for scan"
        return 1
    fi
    
    # Monitor resources during scan
    monitor_resources_during_operation "find $scan_dir -type f" "Custom Scan" 200 50
    
    log_info "Custom scan completed"
    return 0
}

# Run scan
custom_security_scan "/home/user/Documents"
```

### Error Handling

```bash
#!/bin/bash
# Error handling example

source "$HOME/security-suite/scripts/common-functions.sh"

# Set up error handling
set -e
trap 'handle_critical_error "Script interrupted" 130' INT TERM

# Risky operation with retry
if ! retry_with_backoff "wget https://example.com/important-file" 3 2 10; then
    log_error "Failed to download important file after retries"
    exit 1
fi

log_info "Operation completed successfully"
```

## Integration Guidelines

When integrating with the Security Suite API:

1. **Always load configuration first** using the source command
2. **Initialize logging** before any operations
3. **Validate all inputs** using the validation functions
4. **Use sudo wrapper** for privileged operations
5. **Handle errors gracefully** with proper error codes
6. **Log all operations** with appropriate severity levels
7. **Monitor resources** for long-running operations
8. **Clean up properly** in error conditions

## Security Considerations

- All user inputs must be validated before processing
- Use the sudo wrapper for all privileged operations
- Log all security-relevant operations
- Implement proper error handling and cleanup
- Follow the principle of least privilege
- Regularly update security tools and definitions
- Monitor system resources during operations