# 🔧 Aegis Security Suite - Troubleshooting Guide

### _"Comprehensive troubleshooting solutions for common issues and problems"_

---

## 📋 Table of Contents

1. [Installation Issues](#1-installation-issues)
2. [Service Management Problems](#2-service-management-problems)
3. [Database Connection Issues](#3-database-connection-issues)
4. [Permission Problems](#4-permission-problems)
5. [Network Access Issues](#5-network-access-issues)
6. [Dashboard Login Problems](#6-dashboard-login-problems)
7. [Performance Issues](#7-performance-issues)
8. [Security Tool Problems](#8-security-tool-problems)
9. [Behavioral Analysis Issues](#9-behavioral-analysis-issues)
10. [Incident Response Problems](#10-incident-response-problems)
11. [Advanced Troubleshooting](#11-advanced-troubleshooting)
12. [Emergency Procedures](#12-emergency-procedures)

---

## 1. Installation Issues

### Problem: Installation Script Fails to Start

#### Symptoms
- `setup-aegis.sh` script doesn't execute
- Permission denied errors
- Script not found errors

#### Solutions

##### Solution 1: Check Script Permissions
```bash
# Navigate to the security suite directory
cd aegis-security-suite

# Check script permissions
ls -la setup-aegis.sh

# If permissions are missing, add execute permission
chmod +x setup-aegis.sh

# Try running the script again
./setup-aegis.sh
```

##### Solution 2: Verify Script Location
```bash
# Check if you're in the correct directory
pwd
ls -la setup-aegis.sh

# If script is not found, navigate to correct directory
cd /path/to/aegis-security-suite
./setup-aegis.sh
```

##### Solution 3: Check Shell Compatibility
```bash
# Check if bash is available
which bash
bash --version

# If bash is not available, try with sh
sh setup-aegis.sh
```

### Problem: Installation Fails with Dependency Errors

#### Symptoms
- Missing package errors
- Command not found errors
- Dependency installation failures

#### Solutions

##### Solution 1: Install Missing System Dependencies
```bash
# Update package database
sudo pacman -Sy

# Install essential dependencies
sudo pacman -S --needed base-devel git python python-pip sqlite3

# Install security tools (optional but recommended)
sudo pacman -S --needed clamav rkhunter chkrootkit lynis

# Try installation again
./setup-aegis.sh
```

##### Solution 2: Check Python Installation
```bash
# Check Python version
python3 --version

# If Python is not installed, install it
sudo pacman -S python python-pip

# Verify pip installation
pip3 --version
```

##### Solution 3: Manual Dependency Installation
```bash
# Install Python dependencies manually
pip3 install --user flask flask-login flask-socketio bcrypt

# Install security tools manually
sudo pacman -S clamav rkhunter chkrootkit lynis

# Initialize ClamAV database
sudo freshclam

# Try installation again
./setup-aegis.sh
```

### Problem: Installation Fails with Permission Errors

#### Symptoms
- Permission denied errors during installation
- Unable to create directories
- Unable to write configuration files

#### Solutions

##### Solution 1: Check User Permissions
```bash
# Check current user
whoami

# Check if user has sudo privileges
sudo -l

# Check home directory permissions
ls -la $HOME

# If home directory permissions are incorrect, fix them
chmod 755 $HOME
```

##### Solution 2: Create Installation Directory Manually
```bash
# Create security suite directory
mkdir -p ~/aegis-security-suite

# Set correct permissions
chmod 755 ~/aegis-security-suite

# Try installation again
./setup-aegis.sh
```

##### Solution 3: Check Disk Space
```bash
# Check available disk space
df -h $HOME

# If disk space is low, clean up
# Remove old logs, cache, and temporary files
```

---

## 2. Service Management Problems

### Problem: Services Fail to Start

#### Symptoms
- Services show as failed when checking status
- Timeout errors during service startup
- Service not found errors

#### Solutions

##### Solution 1: Check Service Status
```bash
# Check all security suite services
cd $AEGIS_HOME
./scripts/start-aegis.sh status

# Check individual service status
systemctl --user status security-daily-scan.service
systemctl --user status security-weekly-scan.service
systemctl --user status security-monthly-scan.service
```

##### Solution 2: Check Service Logs
```bash
# Check service logs for errors
journalctl --user -u security-daily-scan.service --no-pager
journalctl --user -u security-weekly-scan.service --no-pager
journalctl --user -u security-monthly-scan.service --no-pager

# Check recent logs
journalctl --user -u security-daily-scan.service --since "1 hour ago" --no-pager
```

##### Solution 3: Restart Services
```bash
# Restart all services
./scripts/start-aegis.sh restart all

# Restart individual service
./scripts/start-aegis.sh restart daily-scan
./scripts/start-aegis.sh restart weekly-scan
./scripts/start-aegis.sh restart monthly-scan
```

##### Solution 4: Reload Systemd
```bash
# Reload systemd user daemon
systemctl --user daemon-reload

# Re-enable services
systemctl --user enable security-daily-scan.timer
systemctl --user enable security-weekly-scan.timer
systemctl --user enable security-monthly-scan.timer

# Start services again
./scripts/start-aegis.sh start all
```

### Problem: Services Start but Stop Immediately

#### Symptoms
- Services show as active for a few seconds then stop
- Services exit with error codes
- Services restart continuously

#### Solutions

##### Solution 1: Check Service Configuration
```bash
# Check service files
cat ~/.config/systemd/user/security-daily-scan.service
cat ~/.config/systemd/user/security-weekly-scan.service
cat ~/.config/systemd/user/security-monthly-scan.service

# Verify paths in service files
ls -la ~/aegis-security-suite/src/core/scripts/security-daily-scan.sh
```

##### Solution 2: Test Scripts Manually
```bash
# Test scripts manually to identify issues
cd $AEGIS_HOME/scripts
./security-daily-scan.sh

# Check for errors in script execution
bash -x ./security-daily-scan.sh
```

##### Solution 3: Check Environment Variables
```bash
# Check if AEGIS_HOME is set
echo $AEGIS_HOME

# If not set, set it manually
export AEGIS_HOME="$HOME/aegis-security-suite"

# Add to .bashrc for persistence
echo 'export AEGIS_HOME="$HOME/aegis-security-suite"' >> ~/.bashrc
source ~/.bashrc
```

### Problem: Timer Services Not Triggering

#### Symptoms
- Scheduled scans don't run automatically
- Timer services show as enabled but not triggering
- No scan logs generated on schedule

#### Solutions

##### Solution 1: Check Timer Status
```bash
# Check timer status
systemctl --user list-timers | grep security

# Check individual timer
systemctl --user status security-daily-scan.timer
```

##### Solution 2: Check Timer Schedule
```bash
# Check timer configuration
cat ~/.config/systemd/user/security-daily-scan.timer
cat ~/.config/systemd/user/security-weekly-scan.timer
cat ~/.config/systemd/user/security-monthly-scan.timer
```

##### Solution 3: Manually Trigger Timer
```bash
# Manually trigger timer to test
systemctl --user start security-daily-scan.timer

# Check if service runs
journalctl --user -u security-daily-scan.service --since "1 minute ago" --no-pager
```

##### Solution 4: Check Systemd User Session
```bash
# Check if systemd user session is running
systemctl --user status

# If not running, enable linger for user
sudo loginctl enable-linger $(whoami)

# Reboot or re-login to apply changes
```

---

## 3. Database Connection Issues

### Problem: Database Files Not Found

#### Symptoms
- Database connection errors
- File not found errors for .db files
- SQLite database errors

#### Solutions

##### Solution 1: Check Database Files
```bash
# Check if database files exist
ls -la ~/aegis-security-suite/configs/behavioral_analysis/behavioral_data.db
ls -la ~/aegis-security-suite/configs/incident_response/incidents.db
ls -la ~/aegis-security-suite/configs/threat_intelligence/ioc_database.db
ls -la ~/aegis-security-suite/web-dashboard/auth.db

# Check database permissions
ls -la ~/aegis-security-suite/configs/*/
```

##### Solution 2: Initialize Databases
```bash
# Initialize behavioral analysis database
cd $AEGIS_HOME/scripts
./behavioral-analysis.sh init

# Initialize incident response database
./incident-response.sh init

# Initialize threat intelligence database
./threat-intelligence.sh init

# Initialize web dashboard authentication
cd $AEGIS_HOME/web-dashboard
python3 -c "
from auth import init_database
init_database()
print('Auth database initialized')
"
```

##### Solution 3: Create Missing Directories
```bash
# Create missing directories
mkdir -p ~/aegis-security-suite/configs/behavioral_analysis
mkdir -p ~/aegis-security-suite/configs/incident_response
mkdir -p ~/aegis-security-suite/configs/threat_intelligence
mkdir -p ~/aegis-security-suite/src/dashboard

# Set correct permissions
chmod 755 ~/aegis-security-suite/configs
chmod 755 ~/aegis-security-suite/configs/behavioral_analysis
chmod 755 ~/aegis-security-suite/configs/incident_response
chmod 755 ~/aegis-security-suite/configs/threat_intelligence
chmod 755 ~/aegis-security-suite/src/dashboard
```

### Problem: Database Permission Errors

#### Symptoms
- Permission denied errors when accessing databases
- Unable to write to database files
- Database lock errors

#### Solutions

##### Solution 1: Check Database Permissions
```bash
# Check current database permissions
ls -la ~/aegis-security-suite/configs/*/*.db

# Fix database permissions
chmod 600 ~/aegis-security-suite/configs/*/*.db
chmod 700 ~/aegis-security-suite/configs/*/
```

##### Solution 2: Check Database Ownership
```bash
# Check database ownership
ls -la ~/aegis-security-suite/configs/*/*.db

# If ownership is incorrect, fix it
sudo chown $(whoami):$(whoami) ~/aegis-security-suite/configs/*/*.db
sudo chown -R $(whoami):$(whoami) ~/aegis-security-suite/configs/
```

##### Solution 3: Remove Database Locks
```bash
# Check for database lock files
ls -la ~/aegis-security-suite/configs/*/*.db-journal

# Remove lock files if they exist
rm -f ~/aegis-security-suite/configs/*/*.db-journal
```

### Problem: Database Corruption

#### Symptoms
- Database integrity check failures
- SQLite errors about malformed database
- Inconsistent query results

#### Solutions

##### Solution 1: Check Database Integrity
```bash
# Check behavioral analysis database
sqlite3 $HOME/aegis-security-suite/configs/behavioral_analysis/behavioral_data.db "PRAGMA integrity_check;"

# Check incident response database
sqlite3 $HOME/aegis-security-suite/configs/incident_response/incidents.db "PRAGMA integrity_check;"

# Check threat intelligence database
sqlite3 $HOME/aegis-security-suite/configs/threat_intelligence/ioc_database.db "PRAGMA integrity_check;"
```

##### Solution 2: Repair Database
```bash
# Export data from corrupted database
sqlite3 $HOME/aegis-security-suite/configs/behavioral_analysis/behavioral_data.db ".dump" > behavioral_backup.sql

# Create new database
rm $HOME/aegis-security-suite/configs/behavioral_analysis/behavioral_data.db
sqlite3 $HOME/aegis-security-suite/configs/behavioral_analysis/behavioral_data.db < behavioral_backup.sql

# Repeat for other databases if needed
```

##### Solution 3: Reinitialize Database
```bash
# Backup existing data
cp $HOME/aegis-security-suite/configs/behavioral_analysis/behavioral_data.db $HOME/aegis-security-suite/configs/behavioral_analysis/behavioral_data.db.backup

# Reinitialize database
cd $AEGIS_HOME/scripts
./behavioral-analysis.sh init

# Restore data if needed (advanced)
```

---

## 4. Permission Problems

### Problem: Sudo Access Issues

#### Symptoms
- Sudo password prompts for every command
- Sudo permission denied errors
- Unable to execute security tools with sudo

#### Solutions

##### Solution 1: Configure Sudoers
```bash
# Edit sudoers file
sudo visudo

# Add these lines at the end (replace username with your username)
username ALL=(ALL) NOPASSWD: /usr/bin/clamscan
username ALL=(ALL) NOPASSWD: /usr/bin/rkhunter
username ALL=(ALL) NOPASSWD: /usr/bin/chkrootkit
username ALL=(ALL) NOPASSWD: /usr/bin/lynis
username ALL=(ALL) NOPASSWD: /usr/bin/freshclam
```

##### Solution 2: Check Sudo Configuration
```bash
# Check current sudo configuration
sudo -l

# Test sudo access
sudo whoami
```

##### Solution 3: Use Sudo Wrapper
```bash
# Use the provided sudo wrapper script
cd ~/aegis-security-suite/src/core/scripts
./sudo-wrapper.sh clamscan --version
./sudo-wrapper.sh rkhunter --version
```

### Problem: File Permission Issues

#### Symptoms
- Unable to read/write configuration files
- Unable to create log files
- Unable to access quarantine directory

#### Solutions

##### Solution 1: Check File Permissions
```bash
# Check security suite directory permissions
ls -la $HOME/aegis-security-suite/

# Check configuration file permissions
ls -la $HOME/aegis-security-suite/configs/
ls -la $HOME/aegis-security-suite/configs/security-config.conf

# Check script permissions
ls -la $HOME/aegis-security-suite/scripts/
```

##### Solution 2: Fix File Permissions
```bash
# Fix directory permissions
chmod -R 755 $HOME/aegis-security-suite/
chmod -R 700 $HOME/aegis-security-suite/configs/
chmod -R 755 $HOME/aegis-security-suite/scripts/

# Fix file permissions
chmod 644 $HOME/aegis-security-suite/configs/security-config.conf
chmod 755 $HOME/aegis-security-suite/scripts/*.sh
```

##### Solution 3: Check Directory Ownership
```bash
# Check directory ownership
ls -la $HOME/aegis-security-suite/

# Fix ownership if needed
sudo chown -R $(whoami):$(whoami) $HOME/aegis-security-suite/
```

### Problem: Systemd User Service Permissions

#### Symptoms
- Unable to start user services
- Permission denied errors from systemd
- Services fail to load

#### Solutions

##### Solution 1: Check Systemd User Session
```bash
# Check if systemd user session is running
systemctl --user status

# If not running, enable linger
sudo loginctl enable-linger $(whoami)

# Reboot or re-login
```

##### Solution 2: Check User Service Directory
```bash
# Check if user service directory exists
ls -la ~/.config/systemd/user/

# Create directory if it doesn't exist
mkdir -p ~/.config/systemd/user/
```

##### Solution 3: Reload Systemd
```bash
# Reload systemd user daemon
systemctl --user daemon-reload

# Reset failed services
systemctl --user reset-failed
```

---

## 5. Network Access Issues

### Problem: Dashboard Not Accessible

#### Symptoms
- Unable to access dashboard via web browser
- Connection refused errors
- Connection timeout errors

#### Solutions

##### Solution 1: Check Dashboard Status
```bash
# Check if dashboard is running
cd $HOME/aegis-security-suite/web-dashboard
./start-dashboard.sh status

# Start dashboard if not running
./start-dashboard.sh start
```

##### Solution 2: Check Port Availability
```bash
# Check if port 8080 is in use
netstat -tlnp | grep 8080
# or
ss -tlnp | grep 8080

# If port is in use by another process, kill it
sudo fuser -k 8080/tcp

# Restart dashboard
./start-dashboard.sh restart
```

##### Solution 3: Check Firewall Settings
```bash
# Check if firewall is blocking port 8080
sudo ufw status
sudo iptables -L -n | grep 8080

# Allow port 8080 if blocked
sudo ufw allow 8080/tcp
# or
sudo iptables -I INPUT -p tcp --dport 8080 -j ACCEPT
```

##### Solution 4: Check Network Interface
```bash
# Check network interfaces
ip addr show

# Check if localhost is working
ping -c 3 127.0.0.1

# Try accessing dashboard via different URLs
curl http://127.0.0.1:8080/
curl http://localhost:8080/
```

### Problem: Remote Access Issues

#### Symptoms
- Unable to access dashboard from remote machines
- Local access works but remote access fails
- Network connectivity issues

#### Solutions

##### Solution 1: Check Dashboard Binding
```bash
# Check dashboard configuration
cat ~/aegis-security-suite/src/dashboard/start-dashboard.sh

# Ensure dashboard binds to 0.0.0.0 instead of 127.0.0.1
# Edit the start-dashboard.sh script if needed
```

##### Solution 2: Check Network Configuration
```bash
# Check if system is listening on all interfaces
netstat -tlnp | grep 8080

# Should show 0.0.0.0:8080 or :::8080 for remote access
```

##### Solution 3: Configure Firewall for Remote Access
```bash
# Allow remote access to port 8080
sudo ufw allow from 192.168.1.0/24 to any port 8080
# or
sudo iptables -I INPUT -s 192.168.1.0/24 -p tcp --dport 8080 -j ACCEPT
```

### Problem: Internet Connectivity Issues

#### Symptoms
- Unable to update threat intelligence
- Unable to download virus definitions
- Network timeout errors

#### Solutions

##### Solution 1: Check Internet Connection
```bash
# Check basic connectivity
ping -c 3 8.8.8.8
ping -c 3 google.com

# Check DNS resolution
nslookup google.com
dig google.com
```

##### Solution 2: Check Proxy Settings
```bash
# Check if proxy is configured
echo $http_proxy
echo $https_proxy

# Configure proxy if needed
export http_proxy=http://proxy.example.com:8080
export https_proxy=http://proxy.example.com:8080
```

##### Solution 3: Update Security Tools Manually
```bash
# Update ClamAV database manually
sudo freshclam

# Update system packages
sudo pacman -Syu
```

---

## 6. Dashboard Login Problems

### Problem: Unable to Login to Dashboard

#### Symptoms
- Invalid username/password errors
- Login page doesn't respond
- Authentication errors

#### Solutions

##### Solution 1: Check Default Credentials
```bash
# Default credentials are:
# Username: admin
# Password: aegis123

# Try logging in with default credentials
```

##### Solution 2: Reset Admin Password
```bash
# Reset admin password
cd $HOME/aegis-security-suite/web-dashboard
python3 -c "
from auth import hash_password, update_password
import sqlite3

# Connect to database
conn = sqlite3.connect('auth.db')
cursor = conn.cursor()

# Update admin password
hashed_password = hash_password('aegis123')
cursor.execute('UPDATE users SET password = ? WHERE username = ?', (hashed_password, 'admin'))
conn.commit()
conn.close()

print('Admin password reset to aegis123')
"
```

##### Solution 3: Check Authentication Database
```bash
# Check if auth database exists
ls -la ~/aegis-security-suite/src/dashboard/auth.db

# Check if admin user exists
sqlite3 ~/aegis-security-suite/src/dashboard/auth.db "SELECT * FROM users;"

# Create admin user if it doesn't exist
cd ~/aegis-security-suite/src/dashboard
python3 -c "
from auth import init_database
init_database()
print('Auth database initialized with admin user')
"
```

### Problem: Dashboard Shows Authentication Errors

#### Symptoms
- Session expired errors
- CSRF token errors
- Authentication middleware errors

#### Solutions

##### Solution 1: Clear Browser Cache
```bash
# Clear browser cache and cookies
# Or try in incognito/private mode
```

##### Solution 2: Check Dashboard Logs
```bash
# Check dashboard logs
cd ~/aegis-security-suite/src/dashboard
tail -n 50 dashboard.log

# Check for authentication errors
grep -i auth dashboard.log
```

##### Solution 3: Restart Dashboard
```bash
# Restart dashboard service
cd ~/aegis-security-suite/src/dashboard
./start-dashboard.sh restart

# Check if errors persist
```

### Problem: Dashboard Features Not Working

#### Symptoms
- Dashboard loads but features don't work
- API endpoints return errors
- Real-time updates not working

#### Solutions

##### Solution 1: Check API Endpoints
```bash
# Test API endpoints
curl -u admin:aegis123 http://localhost:8080/api/system/status
curl -u admin:aegis123 http://localhost:8080/api/behavioral/threat-score
curl -u admin:aegis123 http://localhost:8080/api/incidents/list
```

##### Solution 2: Check WebSocket Connection
```bash
# Check WebSocket connection
# Open browser developer tools and check WebSocket status
# Look for WebSocket connection errors
```

##### Solution 3: Check Database Connections
```bash
# Test database connections
sqlite3 $HOME/aegis-security-suite/configs/behavioral_analysis/behavioral_data.db "SELECT COUNT(*) FROM system_metrics;"
sqlite3 $HOME/aegis-security-suite/configs/incident_response/incidents.db "SELECT COUNT(*) FROM incidents;"
```

---

## 7. Performance Issues

### Problem: High CPU Usage

#### Symptoms
- System becomes slow during scans
- High CPU usage by security processes
- System responsiveness degraded

#### Solutions

##### Solution 1: Check Process Usage
```bash
# Check CPU usage by security processes
top -p $(pgrep -f security-daily-scan)
top -p $(pgrep -f clamscan)
top -p $(pgrep -f rkhunter)

# Check overall system usage
htop
```

##### Solution 2: Adjust Scan Scheduling
```bash
# Edit scan configuration
nano ~/aegis-security-suite/configs/security-config.conf

# Reduce scan frequency or adjust scan times
# Set scans to run during off-peak hours
```

##### Solution 3: Limit Resource Usage
```bash
# Limit ClamAV CPU usage
# Edit /etc/clamav/clamd.conf and add:
# MaxThreads 2
# MaxDirectoryRecursion 15

# Restart ClamAV
sudo systemctl restart clamav-freshclam
sudo systemctl restart clamav-daemon
```

### Problem: High Memory Usage

#### Symptoms
- System runs out of memory during scans
- Memory usage continuously increases
- System becomes unresponsive

#### Solutions

##### Solution 1: Check Memory Usage
```bash
# Check memory usage by security processes
ps aux | grep -E "(security|clamav|rkhunter)" | grep -v grep

# Check overall memory usage
free -h
```

##### Solution 2: Optimize Database Usage
```bash
# Check database sizes
du -sh $HOME/aegis-security-suite/configs/*/*.db

# Clean up old data if needed
sqlite3 $HOME/aegis-security-suite/configs/behavioral_analysis/behavioral_data.db "DELETE FROM system_metrics WHERE timestamp < datetime('now', '-30 days');"
```

##### Solution 3: Adjust Scan Configuration
```bash
# Edit scan configuration to reduce memory usage
nano ~/aegis-security-suite/configs/security-config.conf

# Reduce scan directories or exclude large files
# Limit scan depth and file size
```

### Problem: Slow Dashboard Performance

#### Symptoms
- Dashboard takes long time to load
- Real-time updates are slow
- API responses are slow

#### Solutions

##### Solution 1: Check Database Performance
```bash
# Check database query performance
cd $HOME/aegis-security-suite/configs/behavioral_analysis
sqlite3 behavioral_data.db << EOF
.timer on
EXPLAIN QUERY PLAN SELECT * FROM system_metrics ORDER BY timestamp DESC LIMIT 100;
SELECT * FROM system_metrics ORDER BY timestamp DESC LIMIT 100;
.timer off
EOF
```

##### Solution 2: Optimize Database
```bash
# Create indexes for better performance
sqlite3 $HOME/aegis-security-suite/configs/behavioral_analysis/behavioral_data.db "CREATE INDEX IF NOT EXISTS idx_timestamp ON system_metrics(timestamp);"
sqlite3 $HOME/aegis-security-suite/configs/incident_response/incidents.db "CREATE INDEX IF NOT EXISTS idx_created_at ON incidents(created_at);"
```

##### Solution 3: Clean Up Old Data
```bash
# Clean up old behavioral data
sqlite3 $HOME/aegis-security-suite/configs/behavioral_analysis/behavioral_data.db "DELETE FROM system_metrics WHERE timestamp < datetime('now', '-30 days');"

# Clean up old incidents
sqlite3 $HOME/aegis-security-suite/configs/incident_response/incidents.db "DELETE FROM incidents WHERE created_at < datetime('now', '-90 days');"
```

---

## 8. Security Tool Problems

### Problem: ClamAV Issues

#### Symptoms
- ClamAV scan failures
- Database update failures
- ClamAV service not running

#### Solutions

##### Solution 1: Check ClamAV Service
```bash
# Check ClamAV service status
sudo systemctl status clamav-freshclam
sudo systemctl status clamav-daemon

# Start services if not running
sudo systemctl start clamav-freshclam
sudo systemctl start clamav-daemon

# Enable services to start on boot
sudo systemctl enable clamav-freshclam
sudo systemctl enable clamav-daemon
```

##### Solution 2: Update ClamAV Database
```bash
# Update ClamAV database manually
sudo freshclam

# If update fails, check network connectivity
ping -c 3 database.clamav.net
```

##### Solution 3: Test ClamAV Scan
```bash
# Test ClamAV with EICAR test file
echo 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > /tmp/eicar.txt
clamscan /tmp/eicar.txt

# Clean up test file
rm /tmp/eicar.txt
```

### Problem: Rkhunter Issues

#### Symptoms
- Rkhunter scan failures
- False positive warnings
- Configuration errors

#### Solutions

##### Solution 1: Update Rkhunter Database
```bash
# Update Rkhunter database
sudo rkhunter --update

# Update system properties
sudo rkhunter --propupd
```

##### Solution 2: Check Rkhunter Configuration
```bash
# Check Rkhunter configuration
sudo cat /etc/rkhunter.conf | grep -v "^#" | grep -v "^$"

# Test Rkhunter scan
sudo rkhunter --check --sk --report-warnings-only
```

##### Solution 3: Handle False Positives
```bash
# Allow known false positives
# Edit /etc/rkhunter.conf and add:
# ALLOWDEVFILE=/dev/.udev/rules.d/root.rules
# ALLOWHIDDENDIR=/dev/.udev
# ALLOWHIDDENFILE=/usr/bin/.sshd.hmac
```

### Problem: Lynis Issues

#### Symptoms
- Lynis scan failures
- Permission errors
- Incomplete scans

#### Solutions

##### Solution 1: Check Lynis Installation
```bash
# Check Lynis installation
which lynis
lynis --version

# Install Lynis if not installed
sudo pacman -S lynis
```

##### Solution 2: Run Lynis with Proper Permissions
```bash
# Run Lynis with sudo
sudo lynis audit system --quick

# Check Lynis logs
cat /var/log/lynis.log
```

##### Solution 3: Handle Lynis Warnings
```bash
# Review Lynis suggestions
sudo lynis audit system --quick | grep -E "(suggestion|warning)"

# Implement suggested hardening measures
```

---

## 9. Behavioral Analysis Issues

### Problem: Behavioral Analysis Not Working

#### Symptoms
- Behavioral analysis fails to start
- No data being collected
- Anomaly detection not working

#### Solutions

##### Solution 1: Initialize Behavioral Analysis
```bash
# Initialize behavioral analysis
cd $AEGIS_HOME/scripts
./behavioral-analysis.sh init

# Check if database was created
ls -la $HOME/aegis-security-suite/configs/behavioral_analysis/behavioral_data.db
```

##### Solution 2: Create Baseline
```bash
# Create baseline for analysis
./behavioral-analysis.sh baseline 7

# Check baseline data
sqlite3 $HOME/aegis-security-suite/configs/behavioral_analysis/behavioral_data.db "SELECT * FROM system_metrics LIMIT 5;"
```

##### Solution 3: Test Anomaly Detection
```bash
# Test anomaly detection
./behavioral-analysis.sh detect

# Check for anomalies
sqlite3 $HOME/aegis-security-suite/configs/behavioral_analysis/behavioral_data.db "SELECT * FROM anomaly_events;"
```

### Problem: Behavioral Analysis Performance Issues

#### Symptoms
- Behavioral analysis is slow
- High CPU usage during analysis
- Database growing too large

#### Solutions

##### Solution 1: Optimize Data Collection
```bash
# Reduce data collection frequency
# Edit behavioral analysis script to adjust collection intervals
```

##### Solution 2: Clean Up Old Data
```bash
# Clean up old behavioral data
sqlite3 $HOME/aegis-security-suite/configs/behavioral_analysis/behavioral_data.db "DELETE FROM system_metrics WHERE timestamp < datetime('now', '-30 days');"

# Vacuum database to reclaim space
sqlite3 $HOME/aegis-security-suite/configs/behavioral_analysis/behavioral_data.db "VACUUM;"
```

##### Solution 3: Optimize Database
```bash
# Create indexes for better performance
sqlite3 $HOME/aegis-security-suite/configs/behavioral_analysis/behavioral_data.db "CREATE INDEX IF NOT EXISTS idx_timestamp ON system_metrics(timestamp);"
sqlite3 $HOME/aegis-security-suite/configs/behavioral_analysis/behavioral_data.db "CREATE INDEX IF NOT EXISTS idx_anomaly_timestamp ON anomaly_events(timestamp);"
```

---

## 10. Incident Response Problems

### Problem: Incident Response Not Working

#### Symptoms
- Incident response fails to start
- Incidents not being created
- Response actions not working

#### Solutions

##### Solution 1: Initialize Incident Response
```bash
# Initialize incident response
cd $AEGIS_HOME/scripts
./incident-response.sh init

# Check if database was created
ls -la $HOME/aegis-security-suite/configs/incident_response/incidents.db
```

##### Solution 2: Test Incident Creation
```bash
# Test incident creation
./incident-response.sh response "test_incident" "Test incident details" "low"

# Check if incident was created
sqlite3 $HOME/aegis-security-suite/configs/incident_response/incidents.db "SELECT * FROM incidents;"
```

##### Solution 3: Test Response Actions
```bash
# Test file quarantine
echo "test file" > /tmp/test_file.txt
./incident-response.sh quarantine "TEST_001" "/tmp/test_file.txt"

# Check if file was quarantined
ls -la $HOME/aegis-security-suite/quarantine/
```

### Problem: Incident Response Permission Issues

#### Symptoms
- Unable to quarantine files
- Unable to isolate processes
- Permission denied errors

#### Solutions

##### Solution 1: Check Sudo Configuration
```bash
# Check sudo configuration for incident response
sudo -l

# Ensure sudo access for required commands
sudo visudo
# Add: username ALL=(ALL) NOPASSWD: /bin/mv, /bin/kill, /sbin/iptables
```

##### Solution 2: Check Directory Permissions
```bash
# Check quarantine directory permissions
ls -la $HOME/aegis-security-suite/quarantine/

# Fix permissions if needed
chmod 755 $HOME/aegis-security-suite/quarantine/
```

##### Solution 3: Test Response Actions Manually
```bash
# Test file quarantine manually
sudo mv /tmp/test_file.txt $HOME/aegis-security-suite/quarantine/test_file.txt_$(date +%s)

# Test process isolation manually
sudo kill -STOP 1234  # Replace with actual PID
```

---

## 11. Advanced Troubleshooting

### Problem: System Integration Issues

#### Symptoms
- Components not working together
- Data not flowing between components
- Integration test failures

#### Solutions

##### Solution 1: Run Integration Tests
```bash
# Run comprehensive integration tests
cd $AEGIS_HOME
./tests/test-suite-comprehensive.sh

# Check test results
cat $HOME/aegis-security-suite/test-results/test-report-*.txt
```

##### Solution 2: Check Component Communication
```bash
# Test API communication between components
curl -u admin:aegis123 http://localhost:8080/api/system/status
curl -u admin:aegis123 http://localhost:8080/api/behavioral/threat-score
curl -u admin:aegis123 http://localhost:8080/api/incidents/list
```

##### Solution 3: Check Data Flow
```bash
# Check if data flows between components
# 1. Run security scan
./scripts/security-daily-scan.sh

# 2. Check if incidents were created
sqlite3 $HOME/aegis-security-suite/configs/incident_response/incidents.db "SELECT * FROM incidents ORDER BY created_at DESC LIMIT 5;"

# 3. Check if dashboard shows data
curl -u admin:aegis123 http://localhost:8080/api/incidents/list
```

### Problem: Configuration Conflicts

#### Symptoms
- Configuration changes not taking effect
- Conflicting settings
- Unexpected behavior

#### Solutions

##### Solution 1: Validate Configuration
```bash
# Check configuration syntax
bash -n $HOME/aegis-security-suite/configs/security-config.conf

# Check for duplicate settings
grep -n "SCAN_DIRECTORIES" $HOME/aegis-security-suite/configs/security-config.conf
```

##### Solution 2: Reset Configuration
```bash
# Backup current configuration
cp $HOME/aegis-security-suite/configs/security-config.conf $HOME/aegis-security-suite/configs/security-config.conf.backup

# Reset to default configuration
./setup-aegis.sh

# Reconfigure with desired settings
```

##### Solution 3: Check Environment Variables
```bash
# Check relevant environment variables
echo $AEGIS_HOME
echo $PATH

# Set correct environment variables
export AEGIS_HOME="$HOME/aegis-security-suite"
export PATH="$PATH:$HOME/aegis-security-suite/scripts"
```

---

## 12. Emergency Procedures

### Emergency: Complete System Failure

#### Symptoms
- All services stopped
- System unresponsive
- Critical security functions not working

#### Emergency Procedures

##### Step 1: Immediate Assessment
```bash
# Check system status
systemctl --user status
ps aux | grep -E "(security|clamav|rkhunter)" | grep -v grep

# Check system resources
free -h
df -h
```

##### Step 2: Emergency Restart
```bash
# Restart all security services
cd $AEGIS_HOME
./scripts/start-aegis.sh restart all

# Restart dashboard
cd $HOME/aegis-security-suite/web-dashboard
./start-dashboard.sh restart
```

##### Step 3: Emergency Diagnostics
```bash
# Check recent logs
journalctl --user --since "1 hour ago" --no-pager
tail -n 100 ~/aegis-security-suite/logs/manual/security_scan_*.log

# Check for critical errors
grep -i "error\|critical\|fatal" $HOME/aegis-security-suite/logs/manual/*.log
```

### Emergency: Security Incident

#### Symptoms
- Active security threat detected
- System compromised
- Malicious activity identified

#### Emergency Procedures

##### Step 1: Immediate Isolation
```bash
# Isolate affected systems
./scripts/incident-response.sh isolate "EMERGENCY_001" "malicious_process"

# Block malicious IPs
./scripts/incident-response.sh block "EMERGENCY_002" "malicious_ip"
```

##### Step 2: Evidence Collection
```bash
# Collect evidence
./scripts/incident-response.sh collect "EMERGENCY_003" "system_state"
./scripts/incident-response.sh collect "EMERGENCY_004" "network_connections"
./scripts/incident-response.sh collect "EMERGENCY_005" "running_processes"
```

##### Step 3: System Hardening
```bash
# Run emergency security scan
./scripts/security-daily-scan.sh

# Update all security tools
sudo freshclam
sudo rkhunter --update
sudo pacman -Syu
```

### Emergency: Data Corruption

#### Symptoms
- Database corruption detected
- Data inconsistencies
- Critical data loss

#### Emergency Procedures

##### Step 1: Immediate Backup
```bash
# Backup all data
cp -r $HOME/aegis-security-suite/configs $HOME/aegis-security-suite/configs.backup.$(date +%s)
cp -r $HOME/aegis-security-suite/logs $HOME/aegis-security-suite/logs.backup.$(date +%s)
```

##### Step 2: Database Recovery
```bash
# Attempt database repair
sqlite3 $HOME/aegis-security-suite/configs/behavioral_analysis/behavioral_data.db ".recover" | sqlite3 behavioral_data_recovered.db

# If repair fails, reinitialize
./scripts/behavioral-analysis.sh init
./scripts/incident-response.sh init
```

##### Step 3: System Verification
```bash
# Run comprehensive tests
$AEGIS_HOME/tests/test-suite-comprehensive.sh

# Verify all components are working
./scripts/start-aegis.sh status
```

---

## 📞 Getting Additional Help

### When to Seek Help

- If you've tried all solutions and issues persist
- If you encounter errors not covered in this guide
- If you need assistance with advanced configuration
- If you suspect a security incident beyond your expertise

### Support Resources

#### Documentation
- [Complete Documentation](docs/)
- [API Reference](docs/API.md)
- [User Guide](docs/USER_GUIDE.md)

#### Community Support
- [GitHub Issues](https://github.com/YahyaZekry/aegis-security-suite/issues)
- [GitHub Discussions](https://github.com/YahyaZekry/aegis-security-suite/discussions)

#### Professional Support
- Contact security team for critical incidents
- Escalate to system administrators for system-level issues

### Reporting Issues

When reporting issues, include:

1. **System Information**
   ```bash
   uname -a
   pacman -Q aegis-security-suite
   ```

2. **Error Messages**
   - Complete error messages
   - Relevant log entries
   - Steps to reproduce

3. **System State**
   - Service status
   - Configuration files
   - Recent changes

---

## 🎯 Quick Reference Commands

### Emergency Commands

```bash
# Emergency restart
cd $AEGIS_HOME
./scripts/start-aegis.sh restart all

# Emergency status check
./scripts/start-aegis.sh status

# Emergency log check
tail -n 50 $HOME/aegis-security-suite/logs/manual/security_scan_*.log

# Emergency database check
sqlite3 $HOME/aegis-security-suite/configs/behavioral_analysis/behavioral_data.db "PRAGMA integrity_check;"
```

### Diagnostic Commands

```bash
# System diagnostics
systemctl --user status
ps aux | grep -E "(security|clamav|rkhunter)" | grep -v grep

# Network diagnostics
netstat -tlnp | grep 8080
ping -c 3 8.8.8.8

# Database diagnostics
ls -la $HOME/aegis-security-suite/configs/*/*.db
du -sh $HOME/aegis-security-suite/configs/*/
```

### Recovery Commands

```bash
# Service recovery
systemctl --user daemon-reload
systemctl --user reset-failed

# Database recovery
sqlite3 $HOME/aegis-security-suite/configs/behavioral_analysis/behavioral_data.db ".recover"

# Configuration recovery
cp $HOME/aegis-security-suite/configs/security-config.conf.backup $HOME/aegis-security-suite/configs/security-config.conf
```

---

## 🎉 Troubleshooting Complete!

This troubleshooting guide covers the most common issues you may encounter with the Aegis Security Suite. For issues not covered here, please refer to the additional documentation or seek help from the community.

**Remember to:**
- Keep calm and follow procedures systematically
- Document all steps taken during troubleshooting
- Back up data before making major changes
- Seek help when needed - don't hesitate to ask for assistance

**Stay secure and keep troubleshooting! 🔧🛡️**