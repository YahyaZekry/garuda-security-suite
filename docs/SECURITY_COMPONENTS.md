# Security Components Documentation

## Overview

This document describes the comprehensive security components implemented in the Garuda Security Suite to ensure secure operation, input validation, and proper error handling.

## Components

### 1. Enhanced Error Handling Framework (`scripts/common-functions.sh`)

#### Features
- **Comprehensive Logging System**: Multi-level logging with severity levels (DEBUG, INFO, WARNING, ERROR, CRITICAL)
- **Error Recovery Mechanisms**: Automatic retry with exponential backoff for failed operations
- **Resource Monitoring**: Real-time monitoring of disk space and memory usage during operations
- **Graceful Degradation**: Fallback mechanisms when primary tools are unavailable

#### Key Functions

##### `download_with_retry(url, output, max_retries, timeout)`
Downloads files with automatic retry and exponential backoff.
- **Parameters**:
  - `url`: URL to download from
  - `output`: Local file path to save to
  - `max_retries`: Maximum retry attempts (default: 3)
  - `timeout`: Timeout in seconds per attempt (default: 30)
- **Returns**: 0 on success, 1 on failure

##### `run_scanner_with_fallback(primary_tool, fallback_tool, args...)`
Executes security scanner with fallback to alternative tool.
- **Parameters**:
  - `primary_tool`: Preferred scanner to use
  - `fallback_tool`: Alternative scanner if primary unavailable
  - `args`: Arguments to pass to scanner
- **Returns**: Exit code of executed scanner

##### `retry_with_backoff(cmd, max_retries, base_delay, max_delay)`
Executes command with exponential backoff retry logic.
- **Parameters**:
  - `cmd`: Command to execute
  - `max_retries`: Maximum retry attempts (default: 3)
  - `base_delay`: Initial delay in seconds (default: 1)
  - `max_delay`: Maximum delay in seconds (default: 60)
- **Returns**: 0 on success, 1 on failure

##### `monitor_resources_during_operation(operation_cmd, operation_name, max_memory_mb, max_disk_mb)`
Monitors system resources during operation execution.
- **Parameters**:
  - `operation_cmd`: Command to monitor
  - `operation_name`: Description of operation
  - `max_memory_mb`: Memory warning threshold in MB (default: 500)
  - `max_disk_mb`: Disk warning threshold in MB (default: 100)
- **Returns**: Exit code of operation

### 2. Secure Sudo Wrapper System (`scripts/sudo-wrapper.sh`)

#### Features
- **Command Whitelisting**: Only pre-approved sudo commands can be executed
- **Pattern Validation**: Strict regex patterns validate command arguments
- **Audit Logging**: All sudo operations are logged with timestamps and user info
- **Timeout Protection**: All sudo commands have 5-minute timeout
- **Specialized Functions**: Secure wrappers for common security operations

#### Key Functions

##### `validate_sudo_command(cmd)`
Validates sudo command against whitelist and patterns.
- **Parameters**:
  - `cmd`: Complete sudo command to validate
- **Returns**: 0 if valid, 1 if invalid

##### `sudo_execute(cmd, description)`
Executes validated sudo command with audit logging.
- **Parameters**:
  - `cmd`: Validated sudo command to execute
  - `description`: Human-readable description for logging
- **Returns**: Exit code of executed command

##### Specialized Sudo Functions

###### `update_virus_definitions()`
Updates ClamAV virus definitions securely.
- **Returns**: 0 on success, 1 on failure

###### `run_clamav_scan(scan_path, log_file)`
Executes ClamAV scan with secure parameters.
- **Parameters**:
  - `scan_path`: Directory to scan
  - `log_file`: Path to scan log file
- **Returns**: Exit code of scan

###### `update_rkhunter_database()`
Updates Rkhunter database securely.
- **Returns**: 0 on success, 1 on failure

###### `run_rkhunter_check(log_file)`
Executes Rkhunter system check securely.
- **Parameters**:
  - `log_file`: Path to scan log file
- **Returns**: Exit code of check

###### `enable_user_linger(username)`
Enables user linger for background processes.
- **Parameters**:
  - `username`: Validated username
- **Returns**: 0 on success, 1 on failure

###### `install_security_tools(tools...)`
Installs security tools with validation.
- **Parameters**:
  - `tools`: Array of tool names to install
- **Returns**: 0 on success, 1 on failure

###### `remove_security_tools(tools...)`
Removes security tools with validation.
- **Parameters**:
  - `tools`: Array of tool names to remove
- **Returns**: 0 on success, 1 on failure

#### Allowed Sudo Commands

| Command | Pattern | Purpose |
|---------|----------|---------|
| freshclam | `freshclam(--quiet|--no-warnings)?` | Update virus definitions |
| clamscan | `clamscan(-r|--recursive|--detect-pua|--detect-structured|--log).*` | Antivirus scanning |
| rkhunter | `rkhunter(--update|--check|--propupd).*` | Rootkit detection |
| chkrootkit | `chkrootkit(-q|--quiet).*` | Alternative rootkit detection |
| lynis | `lynis(audit system|audit dockerfile).*` | Security auditing |
| loginctl | `loginctl enable-linger [a-zA-Z0-9_-]+` | User session management |
| pacman | `pacman(-Sy|-S|-Rns)?(--noconfirm|--needed)? .*` | Package management |
| systemctl | `systemctl (--user)?(start|stop|restart|enable|disable) .*` | Service management |

### 3. Enhanced Input Validation System (`scripts/input-validation.sh`)

#### Features
- **Security Patterns**: Pre-defined validation patterns for common input types
- **Dangerous Pattern Detection**: Blocks command injection, directory traversal, and other attacks
- **Input Sanitization**: Removes dangerous characters and normalizes input
- **Type-Specific Validation**: Specialized validation for different input types
- **Configuration Validation**: Validates entire configuration files

#### Key Functions

##### `sanitize_input(input, input_type)`
Removes dangerous characters and normalizes input.
- **Parameters**:
  - `input`: Raw input string
  - `input_type`: Type of input (path, filename, text)
- **Returns**: Sanitized input string

##### `check_dangerous_patterns(input)`
Checks input against dangerous pattern blacklist.
- **Parameters**:
  - `input`: Input string to check
- **Returns**: 0 if safe, 1 if dangerous

##### `validate_security_input(input, input_type, field_name, required)`
Comprehensive input validation with sanitization.
- **Parameters**:
  - `input`: Input string to validate
  - `input_type`: Type of input (username, email, time, etc.)
  - `field_name`: Human-readable field name for error messages
  - `required`: Whether input is required (default: true)
- **Returns**: 0 if valid, 1 if invalid

##### `validate_security_config(config_file)`
Validates entire security configuration file.
- **Parameters**:
  - `config_file`: Path to configuration file
- **Returns**: 0 if valid, 1 if invalid

##### `get_validated_input(prompt, input_type, field_name, default_value, required)`
Interactive input with real-time validation.
- **Parameters**:
  - `prompt`: Prompt message for user
  - `input_type`: Type of input expected
  - `field_name`: Field name for validation
  - `default_value`: Default value (optional)
  - `required`: Whether input is required (default: true)
- **Returns**: Validated input string

#### Security Patterns

| Input Type | Pattern | Description |
|------------|----------|-------------|
| username | `^[a-zA-Z0-9_-]{1,32}$` | Usernames 1-32 chars |
| directory | `^[a-zA-Z0-9_/.-]+$` | Directory paths |
| filename | `^[a-zA-Z0-9_.-]+$` | File names |
| email | `^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$` | Email addresses |
| time | `^([0-1][0-9]|2[0-3]):[0-5][0-9]$` | HH:MM format |
| day | `^(Mon|Tue|Wed|Thu|Fri|Sat|Sun)$` | Day names |
| date | `^[0-9]{1,2}$` | Date numbers |
| port | `^[0-9]{1,5}$` | Port numbers |
| url | `^https?://[a-zA-Z0-9.-]+(/[a-zA-Z0-9._/-]*)?$` | HTTP/HTTPS URLs |

#### Dangerous Patterns

| Pattern | Threat | Example |
|---------|---------|---------|
| `\.\./` | Directory traversal | `../../../etc/passwd` |
| `;rm` | Command injection | `test; rm -rf /` |
| `;dd` | Command injection | `test; dd if=/dev/zero` |
| `;mkfs` | Command injection | `test; mkfs /dev/sda` |
| `&& rm` | Command injection | `test && rm -rf /` |
| `&& dd` | Command injection | `test && dd if=/dev/zero` |
| `&& mkfs` | Command injection | `test && mkfs /dev/sda` |
| `|rm` | Pipe injection | `test | rm -rf /` |
| `|dd` | Pipe injection | `test | dd if=/dev/zero` |
| `\`rm` | Backtick injection | `test \`rm -rf /\`` |
| `\$\(` | Command substitution | `test \$(rm -rf /)` |
| `<.*` | HTML/XML injection | `<script>alert('xss')</script>` |
| `javascript:` | JavaScript injection | `javascript:alert('xss')` |
| `data:` | Data URI injection | `data:text/html,<script>alert('xss')</script>` |

## Security Best Practices

### 1. Input Validation
- Always validate user input against strict patterns
- Sanitize input before processing
- Check for dangerous patterns
- Use type-specific validation

### 2. Sudo Operations
- Use whitelist approach for allowed commands
- Validate all command arguments
- Log all privileged operations
- Use timeout protection

### 3. Error Handling
- Implement retry logic with exponential backoff
- Monitor resource usage during operations
- Provide graceful degradation for missing tools
- Log all errors with appropriate severity

### 4. Audit Trail
- Log all security-relevant operations
- Include timestamps, user info, and command details
- Separate audit logs from regular logs
- Protect audit log integrity

## Testing

The security components include comprehensive test suite (`scripts/test-security-components.sh`) that validates:

- Error handling and recovery mechanisms
- Input validation and sanitization
- Sudo command validation and execution
- Integration between components
- Security feature effectiveness

Run tests with:
```bash
./scripts/test-security-components.sh
```

## Integration

To use these security components in your scripts:

```bash
# Load components
source "$(dirname "$0")/common-functions.sh"
source "$(dirname "$0")/sudo-wrapper.sh"
source "$(dirname "$0")/input-validation.sh"

# Initialize logging
init_logging "manual"

# Validate input
if validate_security_input "$user_input" "username" "Username"; then
    # Process valid input
    log_info "Processing username: $user_input"
fi

# Execute sudo command securely
if sudo_execute "freshclam --quiet" "Update virus definitions"; then
    log_info "Virus definitions updated successfully"
fi
```

## Security Considerations

1. **Defense in Depth**: Multiple layers of validation and checking
2. **Principle of Least Privilege**: Minimal sudo access with strict validation
3. **Fail Secure**: Default to secure behavior on errors
4. **Audit Everything**: Comprehensive logging of security operations
5. **Input Validation**: Strict validation and sanitization of all inputs

## Maintenance

- Regularly review and update security patterns
- Monitor audit logs for suspicious activity
- Test components after system updates
- Update dangerous pattern blacklist as new threats emerge