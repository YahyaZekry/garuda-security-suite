# Security Documentation

## Security Model

The Garuda Security Suite follows the principle of least privilege and defense in depth to provide comprehensive security protection while maintaining system usability.

### Core Security Principles

1. **Least Privilege**: Each component operates with minimum necessary permissions
2. **Defense in Depth**: Multiple layers of security controls
3. **Fail Secure**: System defaults to secure state on errors
4. **Audit Everything**: All security-relevant operations are logged
5. **Input Validation**: All external inputs are validated and sanitized

### Security Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    User Interface                         │
├─────────────────────────────────────────────────────────────┤
│                  Input Validation                         │
├─────────────────────────────────────────────────────────────┤
│                 Security Controls                         │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────┐   │
│  │   Sudo      │ │   File      │ │    Audit        │   │
│  │   Wrapper   │ │ Permissions │ │    Logging      │   │
│  └─────────────┘ └─────────────┘ └─────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│                Security Scanners                          │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────┐   │
│  │   ClamAV    │ │  Rkhunter   │ │   Chkrootkit   │   │
│  │ (Antivirus) │ │(Rootkit)    │ │ (Rootkit)      │   │
│  └─────────────┘ └─────────────┘ └─────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│                 System Resources                          │
└─────────────────────────────────────────────────────────────┘
```

## Threat Model

### Protected Against

#### Command Injection Attacks
- **Protection**: Input validation and command whitelisting
- **Implementation**: All user inputs validated against strict patterns
- **Coverage**: All sudo operations and external command executions

#### Path Traversal Attacks
- **Protection**: Path validation and sanitization
- **Implementation**: Absolute path requirement and dangerous path blocking
- **Coverage**: File operations and directory scanning

#### Privilege Escalation
- **Protection**: Sudo wrapper with command validation
- **Implementation**: Whitelist-based sudo command validation
- **Coverage**: All privileged operations

#### Information Disclosure
- **Protection**: Secure file permissions and audit logging
- **Implementation**: Restrictive file permissions and access controls
- **Coverage**: Configuration files, log files, and temporary files

#### Malicious Input Processing
- **Protection**: Input sanitization and pattern matching
- **Implementation**: Dangerous pattern detection and removal
- **Coverage**: All user inputs and external data

### Limitations

#### System Dependencies
- **Scope**: Security suite depends on underlying security tools
- **Impact**: Vulnerabilities in external tools may affect security
- **Mitigation**: Regular updates and validation of tool integrity

#### Zero-Day Vulnerabilities
- **Scope**: Limited protection against unknown attack vectors
- **Impact**: Novel attack techniques may bypass existing controls
- **Mitigation**: Regular security updates and monitoring

#### Physical Access
- **Scope**: Limited protection against physical system access
- **Impact**: Physical access may bypass software security controls
- **Mitigation**: System hardening and physical security measures

## Security Controls

### Input Validation

#### Validation Framework
All user inputs undergo comprehensive validation:

```bash
# Example input validation process
validate_security_input() {
    local input="$1"
    local input_type="$2"
    local field_name="$3"
    
    # 1. Required field check
    if [ -z "$input" ] && [ "$required" = true ]; then
        log_error "$field_name is required"
        return 1
    fi
    
    # 2. Sanitization
    local sanitized_input=$(sanitize_input "$input" "$input_type")
    
    # 3. Dangerous pattern detection
    if ! check_dangerous_patterns "$sanitized_input"; then
        log_error "$field_name contains dangerous patterns"
        return 1
    fi
    
    # 4. Pattern validation
    if [[ ! "$sanitized_input" =~ ^$pattern$ ]]; then
        log_error "$field_name format is invalid"
        return 1
    fi
    
    return 0
}
```

#### Validation Patterns

**Username Validation**
- Pattern: `^[a-zA-Z0-9_-]{1,32}$`
- Purpose: Prevent injection in user contexts

**Directory Path Validation**
- Pattern: `^[a-zA-Z0-9_/.-]+$`
- Purpose: Prevent path traversal and injection

**Email Validation**
- Pattern: `^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`
- Purpose: Prevent email-based attacks

**Time Validation**
- Pattern: `^([0-1][0-9]|2[0-3]):[0-5][0-9]$`
- Purpose: Prevent time-based attacks

#### Dangerous Pattern Detection

The system blocks these dangerous patterns:
- Directory traversal: `../`
- Command injection: `;rm `, `&& rm`, `|rm `
- Disk destruction: `;dd `, `&& dd`, `|dd `
- Filesystem formatting: `;mkfs`, `&& mkfs`
- Command substitution: `$(`, backticks
- HTML/XML injection: `<.*`
- JavaScript injection: `javascript:`
- Data URI injection: `data:`

### Sudo Operations

#### Command Whitelisting

All sudo operations are validated against an approved command list:

```bash
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
```

#### Audit Trail

All sudo operations are logged with:
- Timestamp
- User information
- Process ID
- Command executed
- Description
- Exit code
- Output (on failure)

**Audit Log Format:**
```
[2023-10-29 14:30:15] User: username PID: 12345 Command: sudo freshclam --quiet Description: Update ClamAV virus definitions
[2023-10-29 14:30:45] FAILED - User: username PID: 12345 Command: sudo rm -rf / Exit: 1 Output: rm: it is dangerous to operate recursively on '/'
```

#### Timeout Protection

All sudo operations have:
- 300-second timeout limit
- Automatic termination on timeout
- Error logging for timeout conditions

### File Permissions

#### Permission Matrix

| File Type | Permissions | Owner | Purpose |
|-----------|-------------|--------|---------|
| Configuration files | 600 | user | User read/write only |
| Scripts | 700 | user | User read/write/execute only |
| Log files | 600 | user | User read/write only |
| Audit logs | 600 | user | User read/write only |
| Temporary files | 600 | user | User read/write only |
| Directories | 700 | user | User full access |

#### Secure File Creation

All file creation follows secure practices:

```bash
# Secure file creation example
create_secure_file() {
    local file_path="$1"
    local content="$2"
    
    # Create with restricted permissions
    umask 077
    echo "$content" > "$file_path"
    
    # Verify permissions
    chmod 600 "$file_path"
    
    # Log creation
    log_info "Secure file created: $file_path"
}
```

#### Directory Protection

Critical directories are protected:
- Configuration directory: User access only
- Log directory: User access only
- Backup directory: User access only
- Script directory: User execute permission

### Audit Trail

#### Comprehensive Logging

All security-relevant operations are logged to multiple locations:

**Operation Logs**
- Location: `$LOGS_DIR/manual/security_scan_*.log`
- Content: Scan operations and results
- Rotation: Daily

**Error Logs**
- Location: `$LOGS_DIR/error/security_errors_*.log`
- Content: Error conditions and failures
- Rotation: Daily

**Audit Logs**
- Location: `$LOGS_DIR/audit/security_audit_*.log`
- Content: Security-relevant events
- Rotation: Daily

**Sudo Logs**
- Location: `$LOGS_DIR/audit/sudo_operations_*.log`
- Content: All sudo operations
- Rotation: Monthly

#### Log Integrity

Log files are protected with:
- Restricted file permissions (600)
- Append-only writing where possible
- Regular integrity checks
- Secure backup procedures

#### Log Analysis

The system provides log analysis capabilities:
- Error pattern detection
- Threat identification
- Performance monitoring
- Usage statistics

## Security Recommendations

### System Hardening

#### 1. Keep System Updated
```bash
# Regular system updates
sudo pacman -Syu

# Security updates only
sudo pacman -Sy --needed archlinux-keyring
```

#### 2. Use Strong Passwords
- Minimum 12 characters
- Mix of uppercase, lowercase, numbers, symbols
- Regular password changes
- Avoid dictionary words

#### 3. Enable Firewall
```bash
# Enable UFW firewall
sudo ufw enable
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow specific services
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

#### 4. Regular Security Audits
```bash
# Run comprehensive security audit
lynis audit system

# Check for open ports
ss -tulpn

# Monitor system processes
ps aux --forest
```

### Security Suite Configuration

#### 1. Review Scan Directories
Configure appropriate scan directories in `security-config.conf`:

```bash
# Secure directory configuration
DAILY_SCAN_DIRS=("$HOME/Documents" "$HOME/Downloads")
WEEKLY_SCAN_DIRS=("$HOME")
MONTHLY_SCAN_DIRS=("$HOME" "/tmp" "/var/tmp")

# Exclude sensitive directories
# Avoid scanning: /etc, /boot, /sys, /proc, /dev
```

#### 2. Configure Notification Settings
```bash
# Enable security notifications
NOTIFICATIONS_ENABLED=true
NOTIFICATION_URGENCY="normal"

# Critical alerts for threats
send_notification "🚨 Security Alert" "Threat detected" "security-error" "critical"
```

#### 3. Monitor Log Files Regularly
```bash
# Check recent security events
tail -f $HOME/security-suite/logs/audit/security_audit_*.log

# Find errors in logs
grep ERROR $HOME/security-suite/logs/*/*.log

# Check for threats
grep FOUND $HOME/security-suite/logs/*/*.log
```

#### 4. Update Virus Definitions Frequently
```bash
# Enable automatic updates
UPDATE_BEFORE_SCAN=true

# Manual update
sudo freshclam

# Check update status
freshclam --version
```

### Incident Response

#### 1. Review Security Scan Results
```bash
# Check latest scan results
ls -la $HOME/security-suite/logs/daily/
cat $HOME/security-suite/logs/daily/security_scan_*.log

# Look for threats
grep -i "threat\|found\|infected" $HOME/security-suite/logs/*/*.log
```

#### 2. Investigate Warnings and Errors
```bash
# Find recent warnings
grep WARNING $HOME/security-suite/logs/*/*.log

# Check error details
grep ERROR $HOME/security-suite/logs/error/security_errors_*.log

# Analyze audit trail
grep "FAILED\|DENIED" $HOME/security-suite/logs/audit/sudo_operations_*.log
```

#### 3. Take Appropriate Action on Detected Threats

**Malware Detection**
1. Isolate infected files
2. Update virus definitions
3. Run full system scan
4. Remove or quarantine threats
5. Monitor system behavior

**Rootkit Detection**
1. Disconnect from network
2. Backup important data
3. Reinstall system if necessary
4. Change all passwords
5. Review system integrity

**Suspicious Activity**
1. Review audit logs
2. Identify affected systems
3. Contain potential breaches
4. Document findings
5. Report to security team

#### 4. Document Security Incidents
```bash
# Create incident report
cat > $HOME/security-suite/logs/incident_$(date +%Y%m%d_%H%M%S).log << EOF
Incident Type: Security Threat
Date: $(date)
Description: [Detailed description]
Impact: [System impact assessment]
Actions Taken: [Response actions]
Status: [Current status]
EOF
```

## Security Testing

### Vulnerability Assessment

#### 1. Input Validation Testing
```bash
# Test malicious inputs
echo "../../../etc/passwd" | ./security-scanner.sh
echo "user;rm -rf /" | ./security-scanner.sh
echo "<script>alert('xss')</script>" | ./security-scanner.sh
```

#### 2. Permission Testing
```bash
# Check file permissions
find $HOME/security-suite -type f -exec ls -la {} \;

# Test directory access
ls -la $HOME/security-suite/configs/
ls -la $HOME/security-suite/logs/
```

#### 3. Sudo Operation Testing
```bash
# Test sudo command validation
./sudo-wrapper.sh "rm -rf /"  # Should fail
./sudo-wrapper.sh "clamscan /home"  # Should succeed
```

### Penetration Testing

#### 1. Command Injection Attempts
```bash
# Test various injection techniques
'; rm -rf /'
'&& rm -rf /'
'|rm -rf /'
'$(rm -rf /)'
'`rm -rf /`'
```

#### 2. Path Traversal Attempts
```bash
# Test path traversal
'../../../etc/passwd'
'..\\..\\..\\windows\\system32'
'....//....//....//etc/passwd'
```

#### 3. Privilege Escalation Attempts
```bash
# Test privilege escalation
'sudo su -'
'sudo bash'
'sudo -i'
```

## Security Best Practices

### Development Security

#### 1. Secure Coding Practices
- Validate all inputs
- Use parameterized commands
- Implement proper error handling
- Follow principle of least privilege
- Regular security reviews

#### 2. Code Review Checklist
- [ ] Input validation implemented
- [ ] Output encoding applied
- [ ] Error handling secure
- [ ] File permissions correct
- [ ] Audit logging complete
- [ ] Sudo operations validated

### Operational Security

#### 1. Regular Maintenance
- Update security tools
- Review log files
- Monitor system performance
- Backup configuration
- Test recovery procedures

#### 2. Monitoring and Alerting
- Configure log monitoring
- Set up alert thresholds
- Review security reports
- Investigate anomalies
- Document findings

#### 3. Backup and Recovery
- Regular configuration backups
- Secure backup storage
- Test restore procedures
- Document recovery process
- Maintain offline backups

## Compliance Considerations

### Security Standards

The Security Suite helps address requirements for:
- **ISO 27001**: Information security management
- **NIST Cybersecurity Framework**: Security controls
- **CIS Controls**: Critical security controls
- **PCI DSS**: Payment card industry standards

### Audit Requirements

The system provides audit trails for:
- User access and authentication
- Security tool execution
- Configuration changes
- Error conditions
- System modifications

### Reporting

Standard security reports include:
- Daily scan summaries
- Weekly security status
- Monthly compliance reports
- Incident response reports
- Trend analysis reports

## Security Updates

### Update Process

1. **Monitor Security Advisories**
   - Subscribe to security mailing lists
   - Monitor vendor security updates
   - Review vulnerability databases

2. **Test Updates**
   - Apply updates to test systems
   - Validate functionality
   - Check for regressions

3. **Deploy Updates**
   - Schedule maintenance windows
   - Backup current configuration
   - Apply updates systematically

4. **Verify Updates**
   - Test all functionality
   - Review log files
   - Confirm security improvements

### Update Sources

- **Arch Linux Security Advisories**: https://security.archlinux.org/
- **ClamAV Security Updates**: https://www.clamav.net/
- **Rkhunter Updates**: https://rkhunter.sourceforge.net/
- **Lynis Security Updates**: https://cisofy.com/lynis/

## Contact and Reporting

### Security Issues

To report security vulnerabilities:
1. **Do not use public issue trackers**
2. **Email security team directly**
3. **Provide detailed vulnerability information**
4. **Allow reasonable response time**
5. **Follow responsible disclosure**

### Security Team Contact

- **Email**: security@garuda-linux.org
- **PGP Key**: Available on request
- **Response Time**: Within 48 hours
- **Disclosure Policy**: Responsible disclosure

### Security Resources

- **Security Blog**: https://garuda-linux.org/security
- **Security Advisories**: https://garuda-linux.org/advisories
- **Security Documentation**: https://garuda-linux.org/docs/security
- **Community Forum**: https://forum.garuda-linux.org/