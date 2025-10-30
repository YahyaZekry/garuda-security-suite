# Installation Guide

## System Requirements

### Minimum Requirements
- **Operating System**: Garuda Linux or Arch-based distribution
- **Bash Version**: 4.0 or higher
- **Systemd**: For automated scheduling (recommended)
- **Sudo Access**: For security tool installation and operations
- **Disk Space**: 2GB free space for installation and logs
- **RAM**: 1GB minimum (2GB recommended)

### Recommended Requirements
- **Operating System**: Latest Garuda Linux release
- **Bash Version**: 5.0 or higher
- **Systemd**: Latest version with user services support
- **Sudo Access**: Configured with timeout and lecture disabled
- **Disk Space**: 5GB free space for full operation
- **RAM**: 4GB or more for optimal performance
- **Network**: Internet connection for updates and definitions

### Supported Security Tools
- **ClamAV**: Antivirus scanning (required)
- **Rkhunter**: Rootkit detection (recommended)
- **Chkrootkit**: Alternative rootkit scanner (optional)
- **Lynis**: Security auditing tool (optional)

## Quick Installation

### 1. Clone Repository

```bash
# Clone the repository
git clone https://github.com/YahyaZekry/garuda-security-suite.git
cd garuda-security-suite

# Or download and extract
wget https://github.com/YahyaZekry/garuda-security-suite/archive/main.zip
unzip main.zip
cd garuda-security-suite-main
```

### 2. Run Setup Script

```bash
# Make setup script executable
chmod +x setup-security-suite.sh

# Run interactive setup
./setup-security-suite.sh

# Or run with default settings
./setup-security-suite.sh --defaults

# Or run non-interactive setup
./setup-security-suite.sh --non-interactive --defaults
```

### 3. Follow Configuration Prompts

The setup script will guide you through:

1. **Security Tools Selection**
   - Choose which security tools to install
   - Configure tool-specific settings
   - Set update preferences

2. **Scan Directories Configuration**
   - Select directories for daily scanning
   - Configure weekly and monthly scan targets
   - Set exclusion patterns if needed

3. **Notification Settings**
   - Enable/disable desktop notifications
   - Configure notification urgency levels
   - Set up email notifications (future feature)

4. **Scheduling Configuration**
   - Set daily scan time
   - Configure weekly scan schedule
   - Set monthly scan schedule
   - Enable/disable automated scheduling

### 4. Complete Installation

The setup script will:
- Install required security tools
- Create configuration files
- Set up directory structure
- Configure systemd timers (if enabled)
- Run comprehensive tests
- Start first security scan

## Custom Installation

### Manual Configuration

If you prefer manual configuration, you can customize the installation:

#### 1. Install Security Tools

```bash
# Update package database
sudo pacman -Sy

# Install ClamAV (required)
sudo pacman -S clamav

# Install Rkhunter (recommended)
sudo pacman -S rkhunter

# Install Chkrootkit (optional)
sudo pacman -S chkrootkit

# Install Lynis (optional)
sudo pacman -S lynis

# Initialize ClamAV database
sudo freshclam

# Initialize Rkhunter database
sudo rkhunter --propupd
```

#### 2. Create Directory Structure

```bash
# Create base directory
mkdir -p ~/security-suite

# Create subdirectories
mkdir -p ~/security-suite/{scripts,configs,logs,backups}
mkdir -p ~/security-suite/logs/{daily,weekly,monthly,manual,error,audit}
mkdir -p ~/security-suite/scripts/scanners

# Set permissions
chmod 700 ~/security-suite
chmod 700 ~/security-suite/scripts
chmod 700 ~/security-suite/configs
chmod 700 ~/security-suite/logs
chmod 700 ~/security-suite/backups
```

#### 3. Copy Files

```bash
# Copy script files
cp -r scripts/* ~/security-suite/scripts/
cp -r configs/* ~/security-suite/configs/

# Set script permissions
chmod 700 ~/security-suite/scripts/*.sh
chmod 700 ~/security-suite/scripts/scanners/*.sh

# Set configuration permissions
chmod 600 ~/security-suite/configs/security-config.conf
```

#### 4. Configure Security Suite

Edit `~/security-suite/configs/security-config.conf`:

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

### Systemd Timer Setup

For automated scanning, configure systemd timers:

#### 1. Enable User Linger

```bash
# Enable user linger for background execution
sudo loginctl enable-linger $USER
```

#### 2. Create Systemd Service Files

```bash
# Create systemd user directory
mkdir -p ~/.config/systemd/user

# Create daily scan service
cat > ~/.config/systemd/user/security-daily-scan.service << EOF
[Unit]
Description=Daily Security Scan
After=network-online.target

[Service]
Type=oneshot
ExecStart=$HOME/security-suite/scripts/security-daily-scan.sh
WorkingDirectory=$HOME/security-suite/scripts
StandardOutput=journal
StandardError=journal
Environment=USER=$USER
Environment=HOME=$HOME

[Install]
WantedBy=default.target
EOF

# Create daily scan timer
cat > ~/.config/systemd/user/security-daily-scan.timer << EOF
[Unit]
Description=Run daily security scan
Requires=security-daily-scan.service

[Timer]
OnCalendar=*-*-* 02:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Create weekly scan service
cat > ~/.config/systemd/user/security-weekly-scan.service << EOF
[Unit]
Description=Weekly Security Scan
After=network-online.target

[Service]
Type=oneshot
ExecStart=$HOME/security-suite/scripts/security-weekly-scan.sh
WorkingDirectory=$HOME/security-suite/scripts
StandardOutput=journal
StandardError=journal
Environment=USER=$USER
Environment=HOME=$HOME

[Install]
WantedBy=default.target
EOF

# Create weekly scan timer
cat > ~/.config/systemd/user/security-weekly-scan.timer << EOF
[Unit]
Description=Run weekly security scan
Requires=security-weekly-scan.service

[Timer]
OnCalendar=Sun *-*-* 03:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Create monthly scan service
cat > ~/.config/systemd/user/security-monthly-scan.service << EOF
[Unit]
Description=Monthly Security Scan
After=network-online.target

[Service]
Type=oneshot
ExecStart=$HOME/security-suite/scripts/security-monthly-scan.sh
WorkingDirectory=$HOME/security-suite/scripts
StandardOutput=journal
StandardError=journal
Environment=USER=$USER
Environment=HOME=$HOME

[Install]
WantedBy=default.target
EOF

# Create monthly scan timer
cat > ~/.config/systemd/user/security-monthly-scan.timer << EOF
[Unit]
Description=Run monthly security scan
Requires=security-monthly-scan.service

[Timer]
OnCalendar=*-*-1 04:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF
```

#### 3. Enable and Start Timers

```bash
# Reload systemd daemon
systemctl --user daemon-reload

# Enable timers
systemctl --user enable --now security-daily-scan.timer
systemctl --user enable --now security-weekly-scan.timer
systemctl --user enable --now security-monthly-scan.timer

# Check timer status
systemctl --user list-timers | grep security
```

## Advanced Installation Options

### Custom Installation Directory

To install to a custom directory:

```bash
# Set custom installation directory
export SECURITY_SUITE_HOME="/opt/security-suite"

# Run setup with custom path
./setup-security-suite.sh --install-dir "$SECURITY_SUITE_HOME"
```

### Silent Installation

For automated deployment:

```bash
# Create configuration file
cat > install-config.conf << EOF
INSTALL_TOOLS=("clamav" "rkhunter")
DAILY_SCAN_DIRS=("/home/user/Documents" "/home/user/Downloads")
WEEKLY_SCAN_DIRS=("/home/user")
MONTHLY_SCAN_DIRS=("/home/user" "/tmp" "/var/tmp")
NOTIFICATIONS_ENABLED=true
DAILY_TIME="02:00"
WEEKLY_DAY="Sun"
WEEKLY_TIME="03:00"
MONTHLY_DAY="1"
MONTHLY_TIME="04:00"
EOF

# Run silent installation
./setup-security-suite.sh --config install-config.conf --silent
```

### Development Installation

For developers and testers:

```bash
# Clone development branch
git clone -b develop https://github.com/YahyaZekry/garuda-security-suite.git
cd garuda-security-suite

# Install development dependencies
sudo pacman -S bats shellcheck

# Run tests
./tests/run-all-tests.sh

# Install in development mode
./setup-security-suite.sh --development
```

## Troubleshooting

### Common Issues

#### 1. Permission Denied Errors

**Problem**: Permission denied during installation or operation

**Solutions**:
```bash
# Check sudo access
sudo -v

# Check user permissions
id

# Fix directory permissions
chmod 700 ~/security-suite
chmod 600 ~/security-suite/configs/security-config.conf
chmod 700 ~/security-suite/scripts/*.sh
```

#### 2. Missing Security Tools

**Problem**: Security tools not found or not installed

**Solutions**:
```bash
# Update package database
sudo pacman -Sy

# Install missing tools
sudo pacman -S clamav rkhunter chkrootkit lynis

# Check tool availability
which clamscan
which rkhunter
which chkrootkit
which lynis

# Initialize databases
sudo freshclam
sudo rkhunter --propupd
```

#### 3. Systemd Timer Failures

**Problem**: Systemd timers not working properly

**Solutions**:
```bash
# Check user linger status
loginctl show-user $USER | grep Linger

# Enable user linger if needed
sudo loginctl enable-linger $USER

# Check systemd user service status
systemctl --user status security-daily-scan.timer

# Check journal logs
journalctl --user -u security-daily-scan.service

# Restart systemd user service
systemctl --user restart security-daily-scan.timer
```

#### 4. Notification Problems

**Problem**: Desktop notifications not working

**Solutions**:
```bash
# Check notification service
systemctl --user status notification-daemon

# Install notification daemon if missing
sudo pacman -S dunst

# Test notifications
notify-send "Test" "This is a test notification"

# Check notification settings in config
grep NOTIFICATIONS_ENABLED ~/security-suite/configs/security-config.conf
```

#### 5. Log File Issues

**Problem**: Log files not created or accessible

**Solutions**:
```bash
# Check log directory permissions
ls -la ~/security-suite/logs/

# Create missing directories
mkdir -p ~/security-suite/logs/{daily,weekly,monthly,manual,error,audit}

# Fix permissions
chmod 700 ~/security-suite/logs
chmod 700 ~/security-suite/logs/*

# Test log creation
echo "Test log entry" > ~/security-suite/logs/manual/test.log
```

#### 6. Configuration File Errors

**Problem**: Configuration file syntax errors or missing values

**Solutions**:
```bash
# Check configuration syntax
bash -n ~/security-suite/configs/security-config.conf

# Validate configuration
source ~/security-suite/configs/security-config.conf
echo "Configuration loaded successfully"

# Reset to default configuration
cp configs/security-config.conf ~/security-suite/configs/security-config.conf
```

### Getting Help

#### Check Log Files

```bash
# Check installation log
cat ~/security-suite/logs/manual/installation_*.log

# Check error logs
cat ~/security-suite/logs/error/security_errors_*.log

# Check audit logs
cat ~/security-suite/logs/audit/security_audit_*.log
```

#### Run Test Script

```bash
# Run comprehensive tests
~/security-suite/scripts/test-security-components.sh

# Run specific test
~/security-suite/scripts/test-security-components.sh --test clamav
~/security-suite/scripts/test-security-components.sh --test rkhunter
```

#### Verify Installation

```bash
# Check installation status
~/security-suite/scripts/test-security-components.sh --verify

# Check all components
~/security-suite/scripts/test-security-components.sh --all
```

### Performance Issues

#### High Memory Usage

**Problem**: Security scans using excessive memory

**Solutions**:
```bash
# Configure scan limits
echo "CLAMAV_MEMORY_LIMIT=500" >> ~/security-suite/configs/security-config.conf

# Use quick scan mode
sed -i 's/UPDATE_BEFORE_SCAN=true/UPDATE_BEFORE_SCAN=false/' ~/security-suite/configs/security-config.conf

# Monitor memory usage
free -h
ps aux --sort=-%mem | head -10
```

#### Slow Scan Performance

**Problem**: Security scans taking too long

**Solutions**:
```bash
# Reduce scan directories
sed -i 's|DAILY_SCAN_DIRS=.*|DAILY_SCAN_DIRS=("$HOME/Documents")|' ~/security-suite/configs/security-config.conf

# Exclude large directories
echo "SCAN_EXCLUDES=("$HOME/Videos" "$HOME/Music")" >> ~/security-suite/configs/security-config.conf

# Use quick scan mode
sed -i 's/REAL_TIME_FEEDBACK=false/REAL_TIME_FEEDBACK=true/' ~/security-suite/configs/security-config.conf
```

#### Disk Space Issues

**Problem**: Log files consuming too much disk space

**Solutions**:
```bash
# Check log sizes
du -sh ~/security-suite/logs/*

# Clean old logs
find ~/security-suite/logs -name "*.log" -mtime +30 -delete

# Configure log rotation
echo "LOG_RETENTION_DAYS=30" >> ~/security-suite/configs/security-config.conf
```

## Migration and Upgrades

### From Previous Versions

```bash
# Backup current configuration
cp ~/security-suite/configs/security-config.conf ~/security-suite/configs/security-config.conf.backup

# Stop running services
systemctl --user stop security-daily-scan.timer
systemctl --user stop security-weekly-scan.timer
systemctl --user stop security-monthly-scan.timer

# Update to latest version
git pull origin main

# Run upgrade script
./setup-security-suite.sh --upgrade

# Restart services
systemctl --user start security-daily-scan.timer
systemctl --user start security-weekly-scan.timer
systemctl --user start security-monthly-scan.timer
```

### Configuration Migration

```bash
# Export current configuration
~/security-suite/scripts/export-config.sh > current-config.txt

# Install new version
./setup-security-suite.sh --fresh-install

# Import configuration
~/security-suite/scripts/import-config.sh current-config.txt
```

### Backup and Restore

```bash
# Create backup
~/security-suite/scripts/backup-config.sh

# Restore from backup
~/security-suite/scripts/restore-config.sh backup_20231029_120000.tar.gz
```

## Uninstallation

### Complete Removal

```bash
# Stop all services
systemctl --user stop security-daily-scan.timer
systemctl --user stop security-weekly-scan.timer
systemctl --user stop security-monthly-scan.timer

# Disable services
systemctl --user disable security-daily-scan.timer
systemctl --user disable security-weekly-scan.timer
systemctl --user disable security-monthly-scan.timer

# Remove systemd files
rm -f ~/.config/systemd/user/security-*.service
rm -f ~/.config/systemd/user/security-*.timer

# Reload systemd
systemctl --user daemon-reload

# Remove security suite directory
rm -rf ~/security-suite

# Remove security tools (optional)
sudo pacman -Rns clamav rkhunter chkrootkit lynis

# Disable user linger (optional)
sudo loginctl disable-linger $USER
```

### Partial Removal

```bash
# Remove specific tools
sudo pacman -Rns chkrootkit lynis

# Remove configuration only
rm -rf ~/security-suite/configs

# Remove logs only
rm -rf ~/security-suite/logs
```

## Support and Community

### Getting Help

- **Documentation**: [docs/](https://github.com/YahyaZekry/garuda-security-suite/tree/main/docs)
- **Issues**: [GitHub Issues](https://github.com/YahyaZekry/garuda-security-suite/issues)
- **Discussions**: [GitHub Discussions](https://github.com/YahyaZekry/garuda-security-suite/discussions)
- **Wiki**: [GitHub Wiki](https://github.com/YahyaZekry/garuda-security-suite/wiki)

### Contributing

- **Contributing Guide**: [CONTRIBUTING.md](https://github.com/YahyaZekry/garuda-security-suite/blob/main/CONTRIBUTING.md)
- **Code of Conduct**: [CODE_OF_CONDUCT.md](https://github.com/YahyaZekry/garuda-security-suite/blob/main/CODE_OF_CONDUCT.md)
- **Development Setup**: See [Development Installation](#development-installation)

### Reporting Issues

When reporting issues, please include:

1. **System Information**
   ```bash
   uname -a
   pacman -Q garuda-security-suite
   ```

2. **Configuration**
   ```bash
   cat ~/security-suite/configs/security-config.conf
   ```

3. **Error Logs**
   ```bash
   cat ~/security-suite/logs/error/security_errors_*.log
   ```

4. **Steps to Reproduce**
   - Detailed description of the issue
   - Commands executed
   - Expected vs actual behavior

5. **Environment Details**
   - Desktop environment
   - Security tools installed
   - Custom configurations