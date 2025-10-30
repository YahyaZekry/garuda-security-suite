# User Guide

## Getting Started

Welcome to Garuda Security Suite! This comprehensive security tool provides automated scanning, threat detection, and system monitoring for Garuda Linux and Arch-based systems.

### First Security Scan

After installation, you can run your first security scan immediately:

```bash
# Navigate to scripts directory
cd ~/security-suite/scripts

# Run daily security scan
./security-daily-scan.sh

# Or run comprehensive scan
./security-weekly-scan.sh
```

### Viewing Results

Security scan results are stored in organized log directories:

```bash
# Latest daily scan
ls -la ~/security-suite/logs/daily/
cat ~/security-suite/logs/daily/security_scan_*.log

# Latest weekly scan
ls -la ~/security-suite/logs/weekly/
cat ~/security-suite/logs/weekly/security_scan_*.log

# Latest monthly scan
ls -la ~/security-suite/logs/monthly/
cat ~/security-suite/logs/monthly/security_scan_*.log
```

### Understanding Scan Output

Each scan log contains:
- **Scan Summary**: Overall status and duration
- **Tool Results**: Individual tool outputs
- **Threat Detection**: Any security issues found
- **Performance Metrics**: Resource usage information

Example scan output:
```
Daily Security Scan - Tue Oct 29 14:30:15 UTC 2023
=============================
Log Type: daily
User: username
PID: 12345

[2023-10-29 14:30:15] [INFO] Starting ClamAV scan of directories: /home/user/Documents /home/user/Downloads
[2023-10-29 14:30:16] [INFO] Updating ClamAV virus definitions...
[2023-10-29 14:30:45] [INFO] Virus definitions updated successfully
[2023-10-29 14:30:45] [INFO] Scanning directory: /home/user/Documents
[2023-10-29 14:32:12] [INFO] Scanning directory: /home/user/Downloads
[2023-10-29 14:33:28] [SUCCESS] ClamAV scan completed successfully - No threats found

=== DAILY SCAN SUMMARY ===
Overall Status: 0
Scan Duration: 193s
Scan Completed: Tue Oct 29 14:33:28 UTC 2023
Tools Used: clamav rkhunter
```

## Configuration

### Basic Configuration

The main configuration file is located at `~/security-suite/configs/security-config.conf`. You can edit it with any text editor:

```bash
# Open configuration file
nano ~/security-suite/configs/security-config.conf

# Or use your preferred editor
vim ~/security-suite/configs/security-config.conf
```

### Scan Directories

Configure which directories to scan:

```bash
# Daily scan directories (quick scan)
DAILY_SCAN_DIRS=("$HOME/Documents" "$HOME/Downloads" "$HOME/Desktop")

# Weekly scan directories (comprehensive scan)
WEEKLY_SCAN_DIRS=("$HOME")

# Monthly scan directories (full system scan)
MONTHLY_SCAN_DIRS=("$HOME" "/tmp" "/var/tmp")
```

**Recommended Directory Configuration:**
- **Daily**: High-risk directories (Downloads, Desktop, Documents)
- **Weekly**: User home directory and personal data
- **Monthly**: Entire user space and temporary directories

**Excluding Directories:**
```bash
# Add exclusion patterns (future feature)
SCAN_EXCLUDES=("$HOME/.cache" "$HOME/.local/share/Trash" "$HOME/Videos")
```

### Scheduling

Configure when scans run automatically:

```bash
# Daily scan time (24-hour format)
DAILY_TIME="02:00"

# Weekly scan day and time
WEEKLY_DAY="Sun"
WEEKLY_TIME="03:00"

# Monthly scan day and time (1-28)
MONTHLY_DAY="1"
MONTHLY_TIME="04:00"
```

**Scheduling Best Practices:**
- **Daily**: Early morning when system is idle
- **Weekly**: Weekend morning for comprehensive scan
- **Monthly**: First of month during off-peak hours

### Notification Settings

Configure desktop notifications:

```bash
# Enable/disable notifications
NOTIFICATIONS_ENABLED=true

# Set notification urgency level
NOTIFICATION_URGENCY="normal"  # low, normal, critical

# Real-time feedback during scans
REAL_TIME_FEEDBACK=false
```

**Notification Types:**
- **Scan Start**: Notification when scan begins
- **Scan Complete**: Success notification with summary
- **Threats Detected**: Critical alert for security issues
- **Scan Errors**: Warning for scan failures

### Security Tools Selection

Choose which security tools to use:

```bash
# Enable specific security tools
SELECTED_SECURITY_TOOLS=("clamav" "rkhunter" "chkrootkit" "lynis")

# Minimum recommended configuration
SELECTED_SECURITY_TOOLS=("clamav" "rkhunter")

# Antivirus only (fastest)
SELECTED_SECURITY_TOOLS=("clamav")
```

## Security Tools

### ClamAV (Antivirus)

**Purpose**: Detects viruses, trojans, malware, and other malicious software

**Features**:
- Real-time virus definition updates
- Heuristic detection
- Structured data detection (SSN, credit cards)
- PUA (Potentially Unwanted Applications) detection

**Usage**:
```bash
# Manual ClamAV scan
cd ~/security-suite/scripts
source scanners/clamav-scanner.sh
clamav_scan "/home/user/Documents"

# Quick scan (for daily use)
clamav_quick_scan "/home/user/Downloads"

# Update virus definitions manually
sudo freshclam
```

**ClamAV Log Analysis**:
```bash
# Check for infected files
grep FOUND ~/security-suite/logs/daily/clamav_*.log

# View scan summary
grep "SCAN SUMMARY" ~/security-suite/logs/daily/clamav_*.log

# Check scan statistics
grep "Scanned files" ~/security-suite/logs/daily/clamav_*.log
```

### Rkhunter (Rootkit Detection)

**Purpose**: Detects rootkits, backdoors, and local exploits

**Features**:
- System file integrity checking
- Rootkit detection
- Application configuration checking
- Network interface monitoring

**Usage**:
```bash
# Manual Rkhunter scan
cd ~/security-suite/scripts
source scanners/rkhunter-scanner.sh
rkhunter_scan

# Update Rkhunter database
sudo rkhunter --update

# Update file properties database
sudo rkhunter --propupd
```

**Rkhunter Log Analysis**:
```bash
# Check for warnings
grep Warning ~/security-suite/logs/weekly/rkhunter_*.log

# Check for rootkits
grep "Found" ~/security-suite/logs/weekly/rkhunter_*.log

# View system check results
grep "System checks" ~/security-suite/logs/weekly/rkhunter_*.log
```

### Chkrootkit (Alternative Rootkit Scanner)

**Purpose**: Additional rootkit detection using different methods

**Features**:
- Alternative detection algorithms
- Cross-validation with Rkhunter
- Fast scanning capabilities

**Usage**:
```bash
# Manual Chkrootkit scan
cd ~/security-suite/scripts
source scanners/chkrootkit-scanner.sh
chkrootkit_scan "/home/user"
```

### Lynis (Security Auditing)

**Purpose**: Comprehensive system security audit and hardening recommendations

**Features**:
- Security configuration analysis
- Compliance checking
- Hardening recommendations
- Vulnerability assessment

**Usage**:
```bash
# Manual Lynis audit
cd ~/security-suite/scripts
source scanners/lynis-scanner.sh
lynis_scan

# Generate detailed report
lynis audit system --report-file ~/security-suite/logs/monthly/lynis_report.txt
```

**Lynis Log Analysis**:
```bash
# View security suggestions
grep "suggestion" ~/security-suite/logs/monthly/lynis_*.log

# Check warnings
grep "warning" ~/security-suite/logs/monthly/lynis_*.log

# View scan results summary
grep "Hardening index" ~/security-suite/logs/monthly/lynis_*.log
```

## Manual Operations

### Running Scans Manually

You can run security scans manually at any time:

```bash
# Navigate to scripts directory
cd ~/security-suite/scripts

# Load configuration
source ../configs/security-config.conf
source common-functions.sh

# Run specific scan types
./security-daily-scan.sh    # Quick scan
./security-weekly-scan.sh   # Comprehensive scan
./security-monthly-scan.sh  # Full system audit
```

### Custom Scanning

Create custom scans for specific needs:

```bash
#!/bin/bash
# Custom scan script example

# Load security suite functions
source ~/security-suite/configs/security-config.conf
source ~/security-suite/scripts/common-functions.sh

# Initialize logging
init_logging "manual"

# Custom scan configuration
CUSTOM_DIRS=("$HOME/Projects" "$HOME/Work")
SCAN_TYPE="custom"

log_info "Starting custom security scan"

# Run ClamAV on custom directories
source ~/security-suite/scripts/scanners/clamav-scanner.sh
clamav_scan "${CUSTOM_DIRS[@]}"

log_info "Custom security scan completed"
```

### On-Demand Scans

Scan specific files or directories immediately:

```bash
# Scan specific directory
cd ~/security-suite/scripts
source scanners/clamav-scanner.sh
clamav_scan "/path/to/suspicious/file"

# Scan downloaded file
clamav_scan "$HOME/Downloads/suspicious_file.exe"

# Quick scan of USB drive
clamav_quick_scan "/media/usb_device"
```

## Scheduling and Automation

### Systemd Timer Management

Manage automated scanning with systemd timers:

```bash
# View active timers
systemctl --user list-timers | grep security

# Check timer status
systemctl --user status security-daily-scan.timer
systemctl --user status security-weekly-scan.timer
systemctl --user status security-monthly-scan.timer

# View next run time
systemctl --user list-timers --all | grep security
```

### Modifying Schedule

Change scan schedules:

```bash
# Edit daily scan time
systemctl --user edit security-daily-scan.timer
# Add: OnCalendar=*-*-* 09:00:00

# Edit weekly scan schedule
systemctl --user edit security-weekly-scan.timer
# Add: OnCalendar=Sat *-*-* 10:00:00

# Reload systemd after changes
systemctl --user daemon-reload
```

### Temporary Disabling

Temporarily disable automated scans:

```bash
# Stop daily scan timer
systemctl --user stop security-daily-scan.timer

# Stop weekly scan timer
systemctl --user stop security-weekly-scan.timer

# Stop monthly scan timer
systemctl --user stop security-monthly-scan.timer

# Re-enable when ready
systemctl --user start security-daily-scan.timer
```

### Manual Trigger

Run scheduled scans immediately:

```bash
# Trigger daily scan now
systemctl --user start security-daily-scan.service

# Trigger weekly scan now
systemctl --user start security-weekly-scan.service

# Trigger monthly scan now
systemctl --user start security-monthly-scan.service
```

## Notifications

### Desktop Notifications

Configure and manage desktop notifications:

```bash
# Test notifications
notify-send "Test" "Security Suite notification test"

# Check notification daemon
systemctl --user status notification-daemon

# Install notification daemon if missing
sudo pacman -S dunst libnotify
```

**Notification Icons**:
- `security-high`: Green shield for success
- `security-medium`: Yellow shield for warnings
- `security-error`: Red shield for errors
- `security-critical`: Critical alert icon

**Notification Urgency Levels**:
- `low`: Informational messages
- `normal`: Standard notifications
- `critical`: Important security alerts

### Email Notifications (Future Feature)

Email notifications will be available in future versions:

```bash
# Future email configuration
EMAIL_NOTIFICATIONS_ENABLED=true
EMAIL_RECIPIENT="user@example.com"
EMAIL_SMTP_SERVER="smtp.example.com"
EMAIL_SMTP_PORT="587"
EMAIL_USERNAME="user@example.com"
EMAIL_PASSWORD="app_password"
```

## Log Analysis

### Log File Structure

Security Suite maintains organized log directories:

```
~/security-suite/logs/
├── daily/          # Daily scan results
├── weekly/         # Weekly scan results
├── monthly/        # Monthly scan results
├── manual/         # Manual scan results
├── error/          # Error logs
└── audit/          # Security audit logs
```

### Log File Naming

Log files use timestamp naming:
- `security_scan_YYYYMMDD_HHMMSS.log` - Main scan logs
- `clamav_YYYYMMDD_HHMMSS.log` - ClamAV specific logs
- `rkhunter_YYYYMMDD_HHMMSS.log` - Rkhunter specific logs
- `security_errors_YYYYMMDD_HHMMSS.log` - Error logs
- `sudo_operations_YYYYMMDD.log` - Sudo audit logs

### Searching Logs

Find specific information in log files:

```bash
# Find all errors
grep -r "ERROR" ~/security-suite/logs/

# Find detected threats
grep -r "FOUND\|INFECTED" ~/security-suite/logs/

# Find scan summaries
grep -r "SCAN SUMMARY" ~/security-suite/logs/

# Find recent activity
find ~/security-suite/logs -name "*.log" -mtime -7 -exec grep -l "ERROR\|FOUND" {} \;
```

### Log Analysis Examples

**Daily Security Check**:
```bash
#!/bin/bash
# Daily security status check

TODAY=$(date +%Y%m%d)
ERROR_COUNT=$(grep -c "ERROR" ~/security-suite/logs/*/*$TODAY*.log 2>/dev/null || echo "0")
THREAT_COUNT=$(grep -c "FOUND\|INFECTED" ~/security-suite/logs/*/*$TODAY*.log 2>/dev/null || echo "0")

echo "Daily Security Status - $(date)"
echo "Errors: $ERROR_COUNT"
echo "Threats: $THREAT_COUNT"

if [ "$THREAT_COUNT" -gt 0 ]; then
    echo "⚠️  Threats detected - Check logs immediately"
    notify-send "Security Alert" "$THREAT_COUNT threats detected" "security-error" "critical"
fi
```

**Weekly Security Report**:
```bash
#!/bin/bash
# Weekly security report generation

WEEK_START=$(date -d "1 week ago" +%Y%m%d)
WEEK_END=$(date +%Y%m%d)

echo "Weekly Security Report - $(date)"
echo "Period: $WEEK_START to $WEEK_END"
echo ""

# Scan statistics
DAILY_SCANS=$(find ~/security-suite/logs/daily -name "*$WEEK_START*" -o -name "*$WEEK_END*" | wc -l)
WEEKLY_SCANS=$(find ~/security-suite/logs/weekly -name "*$WEEK_START*" -o -name "*$WEEK_END*" | wc -l)

echo "Scan Statistics:"
echo "  Daily scans: $DAILY_SCANS"
echo "  Weekly scans: $WEEKLY_SCANS"
echo ""

# Threat summary
TOTAL_THREATS=$(grep -c "FOUND\|INFECTED" ~/security-suite/logs/*/*$WEEK_START* ~/security-suite/logs/*/*$WEEK_END* 2>/dev/null || echo "0")
echo "Threat Summary:"
echo "  Total threats detected: $TOTAL_THREATS"
echo ""

# Error summary
TOTAL_ERRORS=$(grep -c "ERROR" ~/security-suite/logs/error/*$WEEK_START* ~/security-suite/logs/error/*$WEEK_END* 2>/dev/null || echo "0")
echo "Error Summary:"
echo "  Total errors: $TOTAL_ERRORS"
```

## Troubleshooting

### Common Problems

#### 1. Scan Takes Too Long

**Symptoms**: Scans running for hours, system slowdown

**Solutions**:
```bash
# Reduce scan directories
nano ~/security-suite/configs/security-config.conf
# Change: DAILY_SCAN_DIRS=("$HOME/Documents")

# Use quick scan mode
sed -i 's/REAL_TIME_FEEDBACK=false/REAL_TIME_FEEDBACK=true/' ~/security-suite/configs/security-config.conf

# Exclude large directories
echo "SCAN_EXCLUDES=(\"$HOME/Videos\" \"$HOME/Music\")" >> ~/security-suite/configs/security-config.conf
```

#### 2. Too Many False Positives

**Symptoms**: Legitimate files flagged as threats

**Solutions**:
```bash
# Update virus definitions
sudo freshclam

# Exclude safe files/directories (future feature)
echo "CLAMAV_EXCLUDES=(\"/path/to/safe/file\")" >> ~/security-suite/configs/security-config.conf

# Use less sensitive scanning
sed -i 's/--detect-pua=yes/--detect-pua=no/' ~/security-suite/scripts/scanners/clamav-scanner.sh
```

#### 3. Missing Notifications

**Symptoms**: No desktop notifications for scan results

**Solutions**:
```bash
# Check notification settings
grep NOTIFICATIONS_ENABLED ~/security-suite/configs/security-config.conf

# Test notification daemon
notify-send "Test" "Notification test"

# Install notification daemon
sudo pacman -S dunst libnotify

# Restart notification service
systemctl --user restart notification-daemon
```

#### 4. Permission Errors

**Symptoms**: Permission denied during scans

**Solutions**:
```bash
# Check sudo access
sudo -v

# Fix file permissions
chmod 700 ~/security-suite
chmod 600 ~/security-suite/configs/security-config.conf
chmod 700 ~/security-suite/scripts/*.sh

# Check directory ownership
ls -la ~/security-suite/
```

#### 5. Scan Failures

**Symptoms**: Scans not completing or failing with errors

**Solutions**:
```bash
# Check error logs
cat ~/security-suite/logs/error/security_errors_*.log

# Check disk space
df -h ~/security-suite/

# Check memory usage
free -h

# Test individual components
~/security-suite/scripts/test-security-components.sh --all
```

### Log Analysis Examples

**Find Recent Errors**:
```bash
# Find errors in last 24 hours
find ~/security-suite/logs -name "*.log" -mtime -1 -exec grep -H "ERROR" {} \;

# Find errors in last week
find ~/security-suite/logs -name "*.log" -mtime -7 -exec grep -H "ERROR" {} \;
```

**Find Threats**:
```bash
# Find all detected threats
grep -r "FOUND\|INFECTED" ~/security-suite/logs/

# Find recent threats
find ~/security-suite/logs -name "*.log" -mtime -7 -exec grep -H "FOUND\|INFECTED" {} \;
```

**Performance Analysis**:
```bash
# Find scan durations
grep "Scan Duration" ~/security-suite/logs/*/*.log

# Find resource usage
grep "Resource usage" ~/security-suite/logs/*/*.log

# Generate performance report
awk '/Scan Duration:/ {sum+=$3; count++} END {print "Average scan duration:", sum/count, "seconds"}' ~/security-suite/logs/*/*.log
```

### Getting Help

**Self-Diagnosis**:
```bash
# Run comprehensive test
~/security-suite/scripts/test-security-components.sh --all

# Check configuration
bash -n ~/security-suite/configs/security-config.conf

# Verify installation
~/security-suite/scripts/test-security-components.sh --verify
```

**Community Support**:
- [GitHub Issues](https://github.com/YahyaZekry/garuda-security-suite/issues)
- [GitHub Discussions](https://github.com/YahyaZekry/garuda-security-suite/discussions)
- [Garuda Linux Forums](https://forum.garuda-linux.org/)

**Bug Reports**:
When reporting issues, include:
1. System information: `uname -a`
2. Security suite version: `pacman -Q garuda-security-suite`
3. Configuration file: `cat ~/security-suite/configs/security-config.conf`
4. Error logs: `cat ~/security-suite/logs/error/security_errors_*.log`
5. Steps to reproduce

## Advanced Usage

### Custom Scanner Integration

Add your own security scanners:

```bash
#!/bin/bash
# Custom scanner example
# ~/security-suite/scripts/scanners/custom-scanner.sh

source "$(dirname "$(dirname "$0")")/common-functions.sh"

custom_scan() {
    local scan_dirs=("$@")
    local scan_log="$LOGS_DIR/daily/custom_$(date +%Y%m%d_%H%M%S).log"
    
    log_info "Starting custom security scan"
    
    for dir in "${scan_dirs[@]}"; do
        log_info "Scanning directory: $dir"
        # Add your custom scanning logic here
        find "$dir" -type f -name "*.sh" -exec grep -l "password" {} \; >> "$scan_log"
    done
    
    log_info "Custom scan completed"
}

export -f custom_scan
```

### Script Automation

Create custom automation scripts:

```bash
#!/bin/bash
# Automated security response script

SECURITY_LOG="$HOME/security-suite/logs/daily/security_scan_$(date +%Y%m%d).log"
THREAT_COUNT=$(grep -c "FOUND\|INFECTED" "$SECURITY_LOG" 2>/dev/null || echo "0")

if [ "$THREAT_COUNT" -gt 0 ]; then
    # Take automated response actions
    echo "Threats detected - Initiating response protocol"
    
    # Isolate infected files
    grep "FOUND" "$SECURITY_LOG" | awk '{print $1}' | xargs -I {} mv {} ~/quarantine/
    
    # Send alert
    notify-send "Security Alert" "$THREAT_COUNT threats quarantined" "security-error" "critical"
    
    # Run full system scan
    ~/security-suite/scripts/security-weekly-scan.sh
fi
```

### Integration with Other Tools

**Integration with Rclone** (for cloud storage scanning):
```bash
#!/bin/bash
# Cloud storage scanning

# Mount cloud storage
rclone mount cloud: ~/cloud-storage &

# Scan mounted storage
~/security-suite/scripts/security-daily-scan.sh

# Unmount
fusermount -u ~/cloud-storage
```

**Integration with Backup Systems**:
```bash
#!/bin/bash
# Pre-backup security scan

# Run quick scan before backup
~/security-suite/scripts/security-daily-scan.sh

# Check scan result
if [ $? -eq 0 ]; then
    # Proceed with backup
    rsync -av ~/Documents/ /backup/location/
else
    echo "Security scan failed - Backup aborted"
    exit 1
fi
```

## Best Practices

### Regular Maintenance

1. **Daily**: Check scan results and notifications
2. **Weekly**: Review log files and system performance
3. **Monthly**: Update security tools and review configuration
4. **Quarterly**: Comprehensive security audit and cleanup

### Security Hygiene

1. **Keep system updated**: Regular system updates
2. **Use strong passwords**: Unique, complex passwords
3. **Scan downloads**: Scan all downloaded files
4. **Review logs**: Regular log analysis
5. **Backup regularly**: Secure backup procedures

### Performance Optimization

1. **Schedule wisely**: Run scans during off-peak hours
2. **Optimize directories**: Scan only necessary locations
3. **Monitor resources**: Track memory and disk usage
4. **Clean logs**: Regular log file cleanup
5. **Update definitions**: Keep security tools current

### Incident Response

1. **Immediate action**: Isolate and contain threats
2. **Investigation**: Analyze logs and scan results
3. **Documentation**: Record incidents and responses
4. **Prevention**: Update configurations and procedures
5. **Recovery**: Restore from clean backups if needed

This user guide provides comprehensive information for using Garuda Security Suite effectively. For additional help, consult the [API Documentation](API.md), [Security Documentation](SECURITY.md), and [Installation Guide](INSTALLATION.md).