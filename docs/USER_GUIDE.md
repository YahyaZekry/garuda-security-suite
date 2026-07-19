# Aegis Security Suite - Comprehensive User Guide

## Table of Contents

1. [Getting Started](#1-getting-started)
   - System Requirements
   - Installation Instructions
   - Initial Configuration
   - First-time Setup

2. [Web Dashboard Access](#2-web-dashboard-access)
   - Accessing the Dashboard
   - Dashboard Overview and Navigation
   - Key Features and Usage

3. [Security Operations](#3-security-operations)
   - Running Manual Security Scans
   - Scheduling Automated Scans
   - Interpreting Scan Results
   - Managing Quarantine

4. [Behavioral Analysis](#4-behavioral-analysis)
   - Understanding Baseline Creation
   - Monitoring System Behavior in Real-time
   - Interpreting Anomaly Alerts
   - Managing Threat Scores

5. [Incident Management](#5-incident-management)
   - Creating and Managing Incidents
   - Evidence Collection Procedures
   - Automated Response Actions
   - Incident Resolution Workflow

6. [Threat Intelligence](#6-threat-intelligence)
   - Accessing IOC Database
   - Managing Threat Feeds
   - Importing/Exporting Threat Data
   - Intelligence Update Procedures

7. [Configuration Management](#7-configuration-management)
   - Security Settings Overview
   - Behavioral Analysis Configuration
   - Notification Preferences
   - System Scheduling Options

8. [Troubleshooting](#8-troubleshooting)
   - Common Issues and Solutions
   - Debug Procedures
   - Log File Locations
   - Support Resources

---

## 1. Getting Started

### System Requirements

The Aegis Security Suite is designed specifically for Aegis Linux and requires the following:

- **Operating System**: Aegis Linux (latest stable version)
- **Architecture**: x86_64 (64-bit)
- **Memory**: Minimum 4GB RAM (8GB recommended)
- **Storage**: 2GB free disk space for installation
- **Network**: Internet connection for threat intelligence updates
- **Permissions**: sudo/administrator privileges for installation

### Installation Instructions

#### Option 1: Automated Installation (Recommended)

1. Clone the repository:
   ```bash
   git clone https://github.com/aegis-linux/aegis-security-suite.git
   cd aegis-security-suite
   ```

2. Run the installation script:
   ```bash
   chmod +x setup-aegis.sh
   sudo ./setup-aegis.sh
   ```

3. Follow the on-screen prompts to complete the installation.

#### Option 2: Manual Installation

1. Install required dependencies:
   ```bash
   sudo pacman -S clamav rkhunter chkrootkit lynis python python-pip
   ```

2. Install Python dependencies:
   ```bash
   pip install -r src/dashboard/requirements.txt
   ```

3. Set up the security suite directory:
   ```bash
   sudo mkdir -p $HOME/aegis-security-suite
   sudo cp -r * $HOME/aegis-security-suite/
   sudo chown -R $USER:$USER $HOME/aegis-security-suite
   ```

### Initial Configuration

After installation, perform these initial configuration steps:

1. **Configure Security Tools**:
   ```bash
   sudo freshclam  # Update ClamAV database
   sudo rkhunter --update  # Update rkhunter database
   ```

2. **Set Up Configuration File**:
   ```bash
   cp configs/security-config.conf ~/.config/aegis-security/
   nano ~/.config/aegis-security/security-config.conf
   ```

3. **Create Directories**:
   ```bash
   mkdir -p $HOME/aegis-security-suite/{logs,reports,quarantine,evidence}
   ```

### First-time Setup

1. **Run Initial Security Scan**:
   ```bash
   ./scripts/security-daily-scan.sh
   ```

2. **Start the Web Dashboard**:
   ```bash
   cd web-dashboard
   ./start-dashboard.sh
   ```

3. **Access the Dashboard**:
   Open your web browser and navigate to `http://localhost:8080`

4. **Create Behavioral Baseline**:
   - Navigate to the Behavioral Analysis section
   - Click "Create Baseline" to establish normal system behavior

---

## 2. Web Dashboard Access

### Accessing the Dashboard

The Aegis Security Suite provides a comprehensive web-based dashboard for monitoring and managing security operations.

#### Starting the Dashboard

1. **Automatic Start** (if installed as service):
   ```bash
   sudo systemctl start aegis-dashboard
   sudo systemctl enable aegis-dashboard  # Start on boot
   ```

2. **Manual Start**:
   ```bash
   cd $AEGIS_HOME/web-dashboard
   ./start-dashboard.sh
   ```

3. **Access URL**:
   - Local: `http://localhost:8080`
   - Network: `http://[your-ip]:8080`

#### Login and Authentication

- **Default Credentials**: 
  - Username: `admin`
  - Password: `aegis123` (change immediately after first login)

- **Changing Password**:
  1. Navigate to Configuration → General
  2. Update authentication settings
  3. Restart the dashboard service

### Dashboard Overview and Navigation

The dashboard consists of several main sections accessible via the navigation bar:

#### 1. Main Dashboard
- **System Status**: Real-time system health indicators
- **Threat Level**: Current threat assessment
- **Active Incidents**: Number of ongoing security incidents
- **Last Scan**: Timestamp of the most recent security scan

#### 2. Behavioral Analysis
- **System Metrics**: CPU, memory, network, and process monitoring
- **Anomaly Detection**: Real-time behavioral anomalies
- **Baseline Management**: Create and manage behavioral baselines
- **Threat Timeline**: Historical threat score visualization

#### 3. Incident Management
- **Incident List**: All security incidents with filtering options
- **Incident Details**: Comprehensive information about each incident
- **Response Actions**: Automated and manual response options
- **Incident Statistics**: Visual representation of incident trends

#### 4. Threat Intelligence
- **IOC Database**: Indicators of Compromise database
- **Threat Feeds**: Management of threat intelligence sources
- **IOC Search**: Search and filter IOCs
- **Feed Status**: Status of threat feed updates

#### 5. Configuration
- **General Settings**: Basic system configuration
- **Behavioral Analysis**: Configure monitoring parameters
- **Scanning Settings**: Security scan configuration
- **Notifications**: Alert and notification preferences
- **Scheduling**: Automated scan scheduling

### Key Features and Usage

#### Real-time Monitoring
- **Live System Metrics**: CPU, memory, disk, and network usage
- **Threat Score Updates**: Continuous threat assessment
- **Alert Notifications**: Immediate alerts for security events
- **WebSocket Updates**: Real-time data without page refresh

#### Interactive Charts
- **System Performance**: Historical performance data
- **Threat Timeline**: Threat score evolution over time
- **Incident Statistics**: Visual incident analysis
- **IOC Distribution**: Threat intelligence visualization

#### Quick Actions
- **Start Quick Scan**: Immediate security scan
- **Create Baseline**: Establish behavioral baseline
- **Update Threat Feeds**: Refresh threat intelligence
- **Generate Report**: Create security reports

---

## 3. Security Operations

### Running Manual Security Scans

The Aegis Security Suite provides multiple scanning options to detect various types of security threats.

#### Quick Scan

A quick scan focuses on common threat locations and is ideal for regular checks:

1. **Via Web Dashboard**:
   - Navigate to the main dashboard
   - Click "Start Quick Scan" in the Quick Actions section
   - Monitor progress in real-time

2. **Via Command Line**:
   ```bash
   ./scripts/security-daily-scan.sh --quick
   ```

#### Full System Scan

Comprehensive scan of the entire system:

1. **Via Web Dashboard**:
   - Navigate to Security Operations
   - Select "Full System Scan"
   - Choose scan options and start

2. **Via Command Line**:
   ```bash
   ./scripts/security-daily-scan.sh --full
   ```

#### Custom Scan

Scan specific directories or file types:

1. **Via Command Line**:
   ```bash
   ./scripts/security-daily-scan.sh --directory /path/to/scan
   ```

2. **Scan Configuration**:
   - Edit `configs/security-config.conf`
   - Modify scan directories and options
   - Save and run scan

#### Scan Types and Tools

The suite integrates multiple security scanning tools:

1. **ClamAV** (Antivirus):
   - Malware detection
   - Virus signature matching
   - Heuristic analysis

2. **Rkhunter** (Rootkit Detection):
   - System binary verification
   - Rootkit signature detection
   - System configuration checks

3. **Chkrootkit** (Rootkit Detection):
   - Alternative rootkit scanner
   - Process and memory analysis
   - Network connection verification

4. **Lynis** (System Auditing):
   - System vulnerability assessment
   - Configuration security checks
   - Compliance verification

### Scheduling Automated Scans

Automated scanning ensures continuous security monitoring without manual intervention.

#### Setting Up Scheduled Scans

1. **Via Web Dashboard**:
   - Navigate to Configuration → Scheduling
   - Set scan times for daily, weekly, and monthly scans
   - Enable automated scheduling

2. **Via Command Line**:
   ```bash
   # Enable systemd timers
   sudo systemctl enable aegis-daily-scan.timer
   sudo systemctl enable aegis-weekly-scan.timer
   sudo systemctl enable aegis-monthly-scan.timer
   
   # Start timers
   sudo systemctl start aegis-daily-scan.timer
   sudo systemctl start aegis-weekly-scan.timer
   sudo systemctl start aegis-monthly-scan.timer
   ```

#### Schedule Configuration

Edit the scheduling configuration in `configs/security-config.conf`:

```bash
# Daily scan time (24-hour format)
DAILY_TIME="02:00"

# Weekly scan (day and time)
WEEKLY_DAY="Sun"
WEEKLY_TIME="03:00"

# Monthly scan (day and time)
MONTHLY_DAY="1"
MONTHLY_TIME="04:00"
```

#### Managing Scheduled Scans

1. **View Active Timers**:
   ```bash
   systemctl list-timers --all | grep aegis
   ```

2. **Disable Scheduled Scans**:
   ```bash
   sudo systemctl stop aegis-daily-scan.timer
   sudo systemctl disable aegis-daily-scan.timer
   ```

3. **Run Scheduled Scan Manually**:
   ```bash
   sudo systemctl start aegis-daily-scan.service
   ```

### Interpreting Scan Results

Understanding scan results is crucial for effective security management.

#### Result Categories

1. **Clean**: No threats detected
2. **Suspicious**: Potential threats requiring investigation
3. **Infected**: Confirmed threats detected
4. **Error**: Scan encountered issues

#### Scan Report Components

1. **Summary Statistics**:
   - Files scanned
   - Threats found
   - Scan duration
   - Errors encountered

2. **Threat Details**:
   - File path and name
   - Threat type and severity
   - Detection method
   - Recommended action

3. **System Information**:
   - Scan timestamp
   - System configuration
   - Tool versions
   - Performance metrics

#### Viewing Scan Results

1. **Via Web Dashboard**:
   - Navigate to Security Operations
   - View scan history and results
   - Click on individual scans for details

2. **Via Command Line**:
   ```bash
   # View latest scan report
   cat $HOME/aegis-security-suite/reports/latest_scan_report.txt
   
   # List all scan reports
   ls -la $HOME/aegis-security-suite/reports/
   ```

### Managing Quarantine

Quarantine isolates detected threats to prevent system damage.

#### Quarantine Operations

1. **Quarantine Detected Threats**:
   - Automatic quarantine for high-confidence detections
   - Manual quarantine for suspicious files
   - Custom quarantine rules

2. **View Quarantined Items**:
   ```bash
   ls -la $HOME/aegis-security-suite/quarantine/
   ```

3. **Restore from Quarantine**:
   ```bash
   # List quarantined files
   ./scripts/quarantine-manager.sh --list
   
   # Restore specific file
   ./scripts/quarantine-manager.sh --restore filename
   ```

4. **Delete Quarantined Items**:
   ```bash
   # Delete specific file
   ./scripts/quarantine-manager.sh --delete filename
   
   # Delete all quarantined files
   ./scripts/quarantine-manager.sh --purge
   ```

#### Quarantine Configuration

Configure quarantine behavior in `configs/security-config.conf`:

```bash
# Enable automatic quarantine
AUTO_QUARANTINE=true

# Quarantine directory
QUARANTINE_DIR="$HOME/aegis-security-suite/quarantine"

# Maximum quarantine size (MB)
MAX_QUARANTINE_SIZE=1024

# Quarantine retention period (days)
QUARANTINE_RETENTION=30
```

---

## 4. Behavioral Analysis

### Understanding Baseline Creation

Behavioral analysis establishes a baseline of normal system behavior to detect anomalies that may indicate security threats.

#### What is a Behavioral Baseline?

A behavioral baseline is a profile of normal system activity including:
- CPU and memory usage patterns
- Network connection behavior
- Process execution patterns
- File system access patterns
- User activity patterns

#### Creating a Baseline

1. **Via Web Dashboard**:
   - Navigate to Behavioral Analysis
   - Click "Create Baseline"
   - Select baseline period (recommended: 7 days)
   - Click "Start Baseline Creation"

2. **Via Command Line**:
   ```bash
   ./scripts/behavioral-analysis.sh --create-baseline --days 7
   ```

#### Baseline Configuration

Configure baseline parameters in `configs/security-config.conf`:

```bash
# Baseline learning period (days)
BEHAVIORAL_LEARNING_PERIOD=7

# Monitoring interval (seconds)
BEHAVIORAL_MONITORING_INTERVAL=60

# Sensitivity level (low, medium, high)
BEHAVIORAL_SENSITIVITY_LEVEL=medium

# Threat score threshold (0-100)
BEHAVIORAL_THREAT_SCORE_THRESHOLD=70
```

#### Baseline Management

1. **View Baseline Status**:
   ```bash
   ./scripts/behavioral-analysis.sh --baseline-status
   ```

2. **Update Baseline**:
   ```bash
   ./scripts/behavioral-analysis.sh --update-baseline
   ```

3. **Reset Baseline**:
   ```bash
   ./scripts/behavioral-analysis.sh --reset-baseline
   ```

### Monitoring System Behavior in Real-time

Real-time monitoring continuously analyzes system behavior against the established baseline.

#### Starting Behavioral Monitoring

1. **Via Web Dashboard**:
   - Navigate to Behavioral Analysis
   - Click "Start Monitoring"
   - Adjust sensitivity settings as needed

2. **Via Command Line**:
   ```bash
   ./scripts/behavioral-analysis.sh --start-monitoring
   ```

#### Monitoring Metrics

The system monitors various behavioral metrics:

1. **System Performance**:
   - CPU usage patterns
   - Memory utilization
   - Disk I/O activity
   - Network traffic

2. **Process Behavior**:
   - Process creation patterns
   - Execution frequency
   - Resource consumption
   - Parent-child relationships

3. **Network Activity**:
   - Connection patterns
   - Data transfer volumes
   - Protocol usage
   - Remote endpoints

4. **File System Access**:
   - File creation/deletion
   - Modification patterns
   - Access frequency
   - Permission changes

#### Real-time Alerts

When anomalies are detected, the system generates alerts:

1. **Alert Types**:
   - Low: Minor deviations from baseline
   - Medium: Significant behavioral changes
   - High: Severe anomalies indicating potential threats
   - Critical: Immediate security threats

2. **Alert Delivery**:
   - Dashboard notifications
   - Desktop alerts
   - Email notifications (if configured)
   - System log entries

### Interpreting Anomaly Alerts

Understanding anomaly alerts is essential for effective threat detection.

#### Anomaly Categories

1. **Performance Anomalies**:
   - Unusual CPU spikes
   - Memory usage abnormalities
   - Disk I/O irregularities
   - Network traffic anomalies

2. **Process Anomalies**:
   - Suspicious process execution
   - Unusual process relationships
   - Abnormal resource consumption
   - Hidden or disguised processes

3. **Network Anomalies**:
   - Unexpected connections
   - Unusual data transfer patterns
   - Suspicious protocol usage
   - Connection to known malicious endpoints

4. **File System Anomalies**:
   - Unauthorized file modifications
   - Suspicious file creation
   - Abnormal access patterns
   - Permission changes

#### Alert Investigation

When an anomaly alert is received:

1. **Verify the Alert**:
   - Check alert details and context
   - Review system logs
   - Correlate with other events

2. **Assess Impact**:
   - Determine potential security impact
   - Identify affected systems or data
   - Evaluate business impact

3. **Take Action**:
   - Isolate affected systems if necessary
   - Block suspicious processes or connections
   - Create security incident for tracking

#### False Positive Management

1. **Identify False Positives**:
   - Review alert patterns
   - Analyze system context
   - Consult with system administrators

2. **Whitelist False Positives**:
   ```bash
   # Add to process whitelist
   echo "process_name" >> configs/behavioral_analysis/process_whitelist.txt
   
   # Add to network whitelist
   echo "ip_address" >> configs/behavioral_analysis/network_whitelist.txt
   ```

3. **Tune Sensitivity**:
   - Adjust sensitivity levels
   - Modify threshold values
   - Update baseline if needed

### Managing Threat Scores

Threat scores provide a quantitative assessment of security risk based on behavioral analysis.

#### Threat Score Calculation

The threat score is calculated based on:
- Anomaly frequency and severity
- System impact assessment
- Historical threat patterns
- Intelligence correlation

#### Score Interpretation

- **0-30 (Low Risk)**: Normal system behavior
- **31-70 (Medium Risk)**: Minor anomalies, monitoring required
- **71-90 (High Risk)**: Significant anomalies, investigation needed
- **91-100 (Critical Risk)**: Immediate security threat

#### Threat Score Management

1. **View Current Threat Score**:
   - Dashboard main page
   - Behavioral Analysis section
   - Command line interface

2. **Historical Analysis**:
   - Threat timeline charts
   - Score evolution patterns
   - Correlation with events

3. **Score Threshold Configuration**:
   ```bash
   # Edit configuration
   nano configs/security-config.conf
   
   # Modify threshold
   BEHAVIORAL_THREAT_SCORE_THRESHOLD=70
   ```

---

## 5. Incident Management

### Creating and Managing Incidents

Incident management provides a structured approach to handling security events from detection to resolution.

#### Incident Types

The Aegis Security Suite categorizes incidents into several types:

1. **Malware Detected**: Virus, trojan, or other malicious software
2. **Suspicious Network**: Unusual network activity or connections
3. **Unauthorized Access**: Attempted or successful unauthorized access
4. **Data Breach**: Unauthorized data access or exfiltration
5. **Behavioral Anomaly**: System behavior deviating from baseline
6. **Policy Violation**: Security policy violations
7. **Other**: Security events not fitting other categories

#### Creating Incidents

1. **Automatic Incident Creation**:
   - Security scan detections
   - Behavioral analysis alerts
   - Threat intelligence matches
   - System monitoring events

2. **Manual Incident Creation**:
   - Via Web Dashboard:
     - Navigate to Incident Management
     - Click "Create Incident"
     - Fill in incident details
     - Submit for tracking

   - Via Command Line:
     ```bash
     ./scripts/incident-response.sh --create --type "malware_detected" --severity "high" --details "Suspicious file detected"
     ```

#### Incident Information

Each incident contains the following information:

1. **Basic Information**:
   - Incident ID (unique identifier)
   - Incident type and category
   - Severity level (Critical, High, Medium, Low)
   - Status (Open, Investigating, Resolved, Closed)

2. **Incident Details**:
   - Description and timeline
   - Affected systems and users
   - Evidence and artifacts
   - Impact assessment

3. **Response Actions**:
   - Actions taken
   - Responsible personnel
   - Resolution steps
   - Follow-up requirements

#### Incident Workflow

1. **Detection**: Security event detected
2. **Creation**: Incident created in tracking system
3. **Triage**: Initial assessment and prioritization
4. **Investigation**: Detailed analysis and evidence collection
5. **Response**: Containment and remediation actions
6. **Resolution**: Incident resolved and documented
7. **Review**: Post-incident analysis and improvement

### Evidence Collection Procedures

Proper evidence collection is crucial for incident investigation and potential legal proceedings.

#### Evidence Types

1. **System Evidence**:
   - System logs and audit trails
   - Process and memory dumps
   - Network connection records
   - File system metadata

2. **Security Tool Evidence**:
   - Scan results and reports
   - Detection logs
   - Quarantined files
   - Tool configuration

3. **User Evidence**:
   - User activity logs
   - Authentication records
   - Access control logs
   - Application usage data

#### Evidence Collection Process

1. **Immediate Preservation**:
   ```bash
   # Create evidence directory
   mkdir -p $HOME/aegis-security-suite/evidence/INC_$(date +%Y%m%d_%H%M%S)_$(uuidgen | cut -c1-8)
   
   # Collect system state
   ./scripts/incident-response.sh --collect-evidence --type system_state
   ```

2. **Detailed Collection**:
   ```bash
   # Collect network information
   ./scripts/incident-response.sh --collect-evidence --type network_connections
   
   # Collect process information
   ./scripts/incident-response.sh --collect-evidence --type running_processes
   
   # Collect memory dumps
   ./scripts/incident-response.sh --collect-evidence --type memory_dump
   ```

3. **Evidence Documentation**:
   ```bash
   # Generate evidence report
   ./scripts/incident-response.sh --generate-report --incident-id INC_20251031_092536_9312
   ```

#### Evidence Chain of Custody

Maintain proper chain of custody for all evidence:

1. **Documentation**:
   - Collection timestamp
   - Collector information
   - Collection methods
   - Storage location

2. **Integrity Verification**:
   - Hash calculation
   - Digital signatures
   - Access logs
   - Modification tracking

3. **Secure Storage**:
   - Encrypted storage
   - Access controls
   - Backup procedures
   - Retention policies

### Automated Response Actions

Automated response actions provide immediate containment and mitigation for security incidents.

#### Response Action Types

1. **Containment Actions**:
   - Isolate affected systems
   - Block network connections
   - Suspend user accounts
   - Quarantine malicious files

2. **Mitigation Actions**:
   - Terminate malicious processes
   - Remove malware
   - Patch vulnerabilities
   - Update security configurations

3. **Notification Actions**:
   - Alert security team
   - Notify system administrators
   - Send email notifications
   - Update incident status

#### Configuring Automated Responses

1. **Via Web Dashboard**:
   - Navigate to Configuration → Incident Response
   - Configure response rules
   - Set trigger conditions
   - Define response actions

2. **Via Configuration File**:
   ```bash
   # Edit incident response configuration
   nano configs/incident_response/incident-response.conf
   
   # Example configuration
   AUTO_RESPONSE_ENABLED=true
   AUTO_CONTAINMENT=true
   AUTO_QUARANTINE=true
   AUTO_NOTIFICATION=true
   ```

#### Response Action Examples

1. **Malware Detection Response**:
   ```bash
   # Automatic quarantine
   ./scripts/incident-response.sh --quarantine --file /path/to/malicious/file
   
   # Process termination
   ./scripts/incident-response.sh --terminate-process --pid 12345
   
   # Network isolation
   ./scripts/incident-response.sh --isolate-system --hostname affected-host
   ```

2. **Unauthorized Access Response**:
   ```bash
   # Account suspension
   ./scripts/incident-response.sh --suspend-user --username suspicious_user
   
   # IP blocking
   ./scripts/incident-response.sh --block-ip --address 192.168.1.100
   
   # Session termination
   ./scripts/incident-response.sh --terminate-session --session-id sess_12345
   ```

### Incident Resolution Workflow

Structured incident resolution ensures thorough handling and documentation of security events.

#### Resolution Steps

1. **Initial Assessment**:
   - Verify incident details
   - Assess impact and scope
   - Determine priority level
   - Assign incident owner

2. **Investigation**:
   - Collect and analyze evidence
   - Identify root cause
   - Assess damage extent
   - Document findings

3. **Response Implementation**:
   - Execute containment actions
   - Implement mitigation measures
   - Monitor effectiveness
   - Adjust response as needed

4. **Resolution**:
   - Verify threat elimination
   - Restore normal operations
   - Document resolution steps
   - Update incident status

5. **Post-Incident Activities**:
   - Conduct lessons learned
   - Update security measures
   - Improve detection capabilities
   - Review and refine procedures

#### Resolution Documentation

1. **Incident Report**:
   ```bash
   # Generate comprehensive incident report
   ./scripts/incident-response.sh --generate-report --incident-id INC_20251031_092536_9312 --format detailed
   ```

2. **Executive Summary**:
   - Incident overview
   - Business impact
   - Resolution timeline
   - Recommendations

3. **Technical Details**:
   - Technical analysis
   - Evidence summary
   - Response actions
   - System changes

#### Incident Closure

1. **Closure Criteria**:
   - Threat eliminated
   - Systems restored
   - Evidence documented
   - Lessons learned completed

2. **Closure Process**:
   ```bash
   # Close incident
   ./scripts/incident-response.sh --close-incident --incident-id INC_20251031_092536_9312
   
   # Archive incident
   ./scripts/incident-response.sh --archive-incident --incident-id INC_20251031_092536_9312
   ```

---

## 6. Threat Intelligence

### Accessing IOC Database

The Indicators of Compromise (IOC) database provides a comprehensive repository of threat intelligence data.

#### IOC Types

The Aegis Security Suite maintains several types of IOCs:

1. **IP Addresses**:
   - Malicious IP addresses
   - Command and control servers
   - Known attack sources
   - Suspicious network endpoints

2. **Domain Names**:
   - Malicious domains
   - Phishing websites
   - Botnet domains
   - Suspicious URLs

3. **File Hashes**:
   - Malware file hashes
   - Suspicious executable hashes
   - Known malicious documents
   - Compromised system files

4. **URL Patterns**:
   - Malicious URLs
   - Phishing links
   - Exploit URLs
   - Suspicious web resources

#### Accessing IOCs

1. **Via Web Dashboard**:
   - Navigate to Threat Intelligence
   - Browse IOC database
   - Use search and filter options
   - View IOC details

2. **Via Command Line**:
   ```bash
   # Search IOCs
   ./scripts/threat-intelligence.sh --search --type ip --value 192.168.1.100
   
   # List recent IOCs
   ./scripts/threat-intelligence.sh --list --recent --limit 100
   
   # Get IOC details
   ./scripts/threat-intelligence.sh --details --ioc-id IOC_12345
   ```

3. **Via API**:
   ```bash
   # API endpoint for IOC search
   curl -X GET "http://localhost:8080/api/threats/iocs?search=malicious&type=ip"
   ```

#### IOC Database Structure

Each IOC contains the following information:

1. **Basic Information**:
   - IOC value (IP, domain, hash, URL)
   - IOC type and category
   - First seen and last seen dates
   - Source and confidence level

2. **Threat Information**:
   - Threat type and family
   - Associated malware
   - Attack patterns
   - Campaign information

3. **Contextual Data**:
   - Geographic information
   - Network information
   - Reputation data
   - Related IOCs

### Managing Threat Feeds

Threat feeds provide continuous updates to the IOC database from various intelligence sources.

#### Feed Types

1. **Public Feeds**:
   - Malware Information Sharing Platform (MISP)
   - AlienVault OTX
   - VirusTotal
   - PhishTank

2. **Commercial Feeds**:
   - Recorded Future
   - CrowdStrike
   - FireEye
   - Kaspersky

3. **Internal Feeds**:
   - Internal detection results
   - Incident-derived IOCs
   - Custom threat intelligence
   - Partner sharing

#### Feed Configuration

1. **Via Web Dashboard**:
   - Navigate to Threat Intelligence → Feed Management
   - Configure feed settings
   - Set update schedules
   - Monitor feed status

2. **Via Configuration File**:
   ```bash
   # Edit threat feed configuration
   nano configs/threat_intelligence/feeds.conf
   
   # Example feed configuration
   FEED_URL="https://example.com/threat-feed.json"
   FEED_API_KEY="your-api-key"
   UPDATE_INTERVAL=3600
   ENABLED=true
   ```

#### Feed Management Operations

1. **Add New Feed**:
   ```bash
   ./scripts/threat-intelligence.sh --add-feed --name "Custom Feed" --url "https://example.com/feed.json"
   ```

2. **Update Feeds**:
   ```bash
   # Update all feeds
   ./scripts/threat-intelligence.sh --update-all-feeds
   
   # Update specific feed
   ./scripts/threat-intelligence.sh --update-feed --name "Custom Feed"
   ```

3. **Feed Status**:
   ```bash
   # Check feed status
   ./scripts/threat-intelligence.sh --feed-status
   
   # View feed statistics
   ./scripts/threat-intelligence.sh --feed-stats
   ```

### Importing/Exporting Threat Data

The suite supports various formats for importing and exporting threat intelligence data.

#### Import Formats

1. **STIX (Structured Threat Information eXpression)**:
   ```bash
   ./scripts/threat-intelligence.sh --import --format stix --file threat_data.stix
   ```

2. **JSON (JavaScript Object Notation)**:
   ```bash
   ./scripts/threat-intelligence.sh --import --format json --file threat_data.json
   ```

3. **CSV (Comma-Separated Values)**:
   ```bash
   ./scripts/threat-intelligence.sh --import --format csv --file threat_data.csv
   ```

4. **XML (eXtensible Markup Language)**:
   ```bash
   ./scripts/threat-intelligence.sh --import --format xml --file threat_data.xml
   ```

#### Export Formats

1. **Export All IOCs**:
   ```bash
   # Export to JSON
   ./scripts/threat-intelligence.sh --export --format json --output all_iocs.json
   
   # Export to STIX
   ./scripts/threat-intelligence.sh --export --format stix --output all_iocs.stix
   ```

2. **Export Filtered IOCs**:
   ```bash
   # Export by type
   ./scripts/threat-intelligence.sh --export --type ip --format json --output ip_iocs.json
   
   # Export by date range
   ./scripts/threat-intelligence.sh --export --start-date "2025-01-01" --end-date "2025-12-31" --format json --output recent_iocs.json
   ```

3. **Via Web Dashboard**:
   - Navigate to Threat Intelligence
   - Use export options in the IOC table
   - Select export format and filters
   - Download exported file

#### Data Validation

1. **Import Validation**:
   - Format validation
   - Schema verification
   - Duplicate detection
   - Quality assessment

2. **Export Validation**:
   - Format compliance
   - Data integrity
   - Completeness check
   - Size verification

### Intelligence Update Procedures

Regular updates ensure the threat intelligence database remains current and effective.

#### Update Scheduling

1. **Automatic Updates**:
   ```bash
   # Enable automatic updates
   ./scripts/threat-intelligence.sh --enable-auto-update --interval 3600
   
   # Configure update schedule
   ./scripts/threat-intelligence.sh --schedule-update --time "02:00" --daily
   ```

2. **Manual Updates**:
   ```bash
   # Update all feeds
   ./scripts/threat-intelligence.sh --update-all-feeds
   
   # Update specific feed
   ./scripts/threat-intelligence.sh --update-feed --name "Custom Feed"
   ```

#### Update Process

1. **Feed Retrieval**:
   - Connect to feed sources
   - Authenticate with API keys
   - Retrieve latest data
   - Verify data integrity

2. **Data Processing**:
   - Parse feed data
   - Normalize formats
   - Extract IOCs
   - Validate indicators

3. **Database Update**:
   - Add new IOCs
   - Update existing IOCs
   - Remove expired IOCs
   - Update metadata

4. **Quality Assurance**:
   - Verify data quality
   - Check for duplicates
   - Validate relationships
   - Update statistics

#### Update Monitoring

1. **Update Status**:
   ```bash
   # Check last update time
   ./scripts/threat-intelligence.sh --last-update
   
   # View update history
   ./scripts/threat-intelligence.sh --update-history
   ```

2. **Update Notifications**:
   - Success notifications
   - Failure alerts
   - Statistics reports
   - Performance metrics

#### Update Troubleshooting

1. **Common Issues**:
   - Network connectivity problems
   - API authentication failures
   - Data format errors
   - Database lock issues

2. **Diagnostic Commands**:
   ```bash
   # Test feed connectivity
   ./scripts/threat-intelligence.sh --test-connection --feed "Custom Feed"
   
   # Validate feed format
   ./scripts/threat-intelligence.sh --validate-feed --file feed_data.json
   
   # Check database integrity
   ./scripts/threat-intelligence.sh --check-database
   ```

---

## 7. Configuration Management

### Security Settings Overview

The Aegis Security Suite provides comprehensive configuration options to customize security operations according to your specific requirements.

#### Configuration File Structure

The main configuration file is located at `configs/security-config.conf` and contains the following sections:

1. **General Settings**:
   - System paths and directories
   - User preferences
   - Notification settings
   - Logging configuration

2. **Security Tools Configuration**:
   - Tool selection and parameters
   - Scan settings and options
   - Update schedules
   - Performance tuning

3. **Behavioral Analysis Settings**:
   - Monitoring parameters
   - Baseline configuration
   - Sensitivity levels
   - Alert thresholds

4. **Incident Response Settings**:
   - Response actions
   - Notification preferences
   - Escalation rules
   - Reporting options

#### Accessing Configuration

1. **Via Web Dashboard**:
   - Navigate to Configuration
   - Select appropriate tab
   - Modify settings
   - Save and apply changes

2. **Via Command Line**:
   ```bash
   # Edit main configuration
   nano configs/security-config.conf
   
   # Validate configuration
   ./scripts/config-validator.sh --check
   
   # Apply configuration
   ./scripts/config-applier.sh --apply
   ```

#### Configuration Backup and Restore

1. **Backup Configuration**:
   ```bash
   # Create backup
   ./scripts/config-backup.sh --create
   
   # List backups
   ./scripts/config-backup.sh --list
   
   # Restore from backup
   ./scripts/config-backup.sh --restore --backup-id backup_20251031_120000
   ```

2. **Export Configuration**:
   ```bash
   # Export to file
   ./scripts/config-export.sh --format json --output config_backup.json
   ```

### Behavioral Analysis Configuration

Behavioral analysis settings determine how the system monitors and analyzes system behavior.

#### Monitoring Configuration

1. **System Metrics**:
   ```bash
   # Enable/disable specific metrics
   MONITOR_CPU=true
   MONITOR_MEMORY=true
   MONITOR_DISK=true
   MONITOR_NETWORK=true
   MONITOR_PROCESSES=true
   ```

2. **Monitoring Intervals**:
   ```bash
   # Monitoring frequency (seconds)
   MONITORING_INTERVAL=60
   
   # Data collection intervals
   CPU_COLLECTION_INTERVAL=30
   MEMORY_COLLECTION_INTERVAL=30
   NETWORK_COLLECTION_INTERVAL=60
   PROCESS_COLLECTION_INTERVAL=120
   ```

#### Baseline Settings

1. **Learning Period**:
   ```bash
   # Baseline learning period (days)
   BASELINE_LEARNING_PERIOD=7
   
   # Minimum samples for baseline
   MIN_BASELINE_SAMPLES=1000
   
   # Baseline refresh interval (days)
   BASELINE_REFRESH_INTERVAL=30
   ```

2. **Baseline Metrics**:
   ```bash
   # Metrics to include in baseline
   BASELINE_METRICS="cpu,memory,network,processes,connections"
   
   # Statistical methods
   BASELINE_STATISTICAL_METHOD="mean,stddev,min,max,percentile"
   ```

#### Sensitivity Configuration

1. **Sensitivity Levels**:
   ```bash
   # Global sensitivity level (low, medium, high)
   SENSITIVITY_LEVEL=medium
   
   # Metric-specific sensitivity
   CPU_SENSITIVITY=medium
   MEMORY_SENSITIVITY=medium
   NETWORK_SENSITIVITY=high
   PROCESS_SENSITIVITY=medium
   ```

2. **Threshold Settings**:
   ```bash
   # Anomaly detection thresholds
   CPU_THRESHOLD=2.0  # Standard deviations
   MEMORY_THRESHOLD=2.0
   NETWORK_THRESHOLD=2.5
   PROCESS_THRESHOLD=1.5
   
   # Threat score thresholds
   THREAT_SCORE_THRESHOLD=70
   CRITICAL_THRESHOLD=90
   ```

#### Process and Network Configuration

1. **Process Monitoring**:
   ```bash
   # Process whitelist (comma-separated)
   PROCESS_WHITELIST="systemd,kernelinit,kthreadd"
   
   # Process blacklist (comma-separated)
   PROCESS_BLACKLIST="nc,netcat,telnet,ftp"
   
   # Monitor hidden processes
   MONITOR_HIDDEN_PROCESSES=true
   ```

2. **Network Monitoring**:
   ```bash
   # Network whitelist (comma-separated)
   NETWORK_WHITELIST="127.0.0.1,192.168.1.0/24"
   
   # Network blacklist (comma-separated)
   NETWORK_BLACKLIST=""
   
   # Monitor encrypted traffic
   MONITOR_ENCRYPTED_TRAFFIC=true
   ```

### Notification Preferences

Notification settings control how and when you receive security alerts and system notifications.

#### Notification Types

1. **Security Alerts**:
   - Threat detections
   - Incident notifications
   - Scan results
   - System anomalies

2. **System Notifications**:
   - Update status
   - Performance alerts
   - Maintenance reminders
   - Error messages

#### Notification Channels

1. **Desktop Notifications**:
   ```bash
   # Enable desktop notifications
   DESKTOP_NOTIFICATIONS=true
   
   # Notification urgency (low, normal, critical)
   NOTIFICATION_URGENCY=normal
   
   # Notification duration (seconds)
   NOTIFICATION_DURATION=10
   ```

2. **Email Notifications**:
   ```bash
   # Enable email notifications
   EMAIL_NOTIFICATIONS=false
   
   # Email configuration
   SMTP_SERVER="smtp.example.com"
   SMTP_PORT=587
   SMTP_USERNAME="your-email@example.com"
   SMTP_PASSWORD="your-password"
   
   # Notification recipients
   EMAIL_RECIPIENTS="admin@example.com,security@example.com"
   ```

3. **Webhook Notifications**:
   ```bash
   # Enable webhook notifications
   WEBHOOK_NOTIFICATIONS=false
   
   # Webhook URL
   WEBHOOK_URL="https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"
   
   # Webhook format
   WEBHOOK_FORMAT="json"
   ```

#### Notification Rules

1. **Severity-based Rules**:
   ```bash
   # Critical notifications (always send)
   CRITICAL_NOTIFICATIONS=true
   
   # High severity notifications
   HIGH_NOTIFICATIONS=true
   
   # Medium severity notifications
   MEDIUM_NOTIFICATIONS=true
   
   # Low severity notifications
   LOW_NOTIFICATIONS=false
   ```

2. **Time-based Rules**:
   ```bash
   # Quiet hours (don't send non-critical notifications)
   QUIET_HOURS_ENABLED=true
   QUIET_HOURS_START="22:00"
   QUIET_HOURS_END="07:00"
   
   # Weekend notifications
   WEEKEND_NOTIFICATIONS=false
   ```

#### Notification Filtering

1. **Event Filtering**:
   ```bash
   # Filter by event type
   NOTIFY_MALWARE_DETECTION=true
   NOTIFY_BEHAVIORAL_ANOMALY=true
   NOTIFY_INCIDENT_CREATION=true
   NOTIFY_SCAN_COMPLETION=false
   ```

2. **Frequency Control**:
   ```bash
   # Minimum interval between similar notifications (minutes)
   NOTIFICATION_COOLDOWN=30
   
   # Maximum notifications per hour
   MAX_NOTIFICATIONS_PER_HOUR=20
   
   # Daily notification limit
   MAX_NOTIFICATIONS_PER_DAY=200
   ```

### System Scheduling Options

Scheduling configuration determines when automated security operations are performed.

#### Scan Scheduling

1. **Daily Scans**:
   ```bash
   # Enable daily scans
   DAILY_SCAN_ENABLED=true
   
   # Daily scan time (24-hour format)
   DAILY_SCAN_TIME="02:00"
   
   # Daily scan type (quick, full, custom)
   DAILY_SCAN_TYPE="quick"
   ```

2. **Weekly Scans**:
   ```bash
   # Enable weekly scans
   WEEKLY_SCAN_ENABLED=true
   
   # Weekly scan day (Mon, Tue, Wed, Thu, Fri, Sat, Sun)
   WEEKLY_SCAN_DAY="Sun"
   
   # Weekly scan time
   WEEKLY_SCAN_TIME="03:00"
   
   # Weekly scan type
   WEEKLY_SCAN_TYPE="full"
   ```

3. **Monthly Scans**:
   ```bash
   # Enable monthly scans
   MONTHLY_SCAN_ENABLED=true
   
   # Monthly scan day (1-28)
   MONTHLY_SCAN_DAY="1"
   
   # Monthly scan time
   MONTHLY_SCAN_TIME="04:00"
   
   # Monthly scan type
   MONTHLY_SCAN_TYPE="comprehensive"
   ```

#### Update Scheduling

1. **Threat Intelligence Updates**:
   ```bash
   # Enable automatic updates
   AUTO_UPDATE_THREAT_INTEL=true
   
   # Update interval (hours)
   THREAT_INTEL_UPDATE_INTERVAL=6
   
   # Update time (specific time of day)
   THREAT_INTEL_UPDATE_TIME="01:00"
   ```

2. **Security Tool Updates**:
   ```bash
   # Enable tool updates
   AUTO_UPDATE_TOOLS=true
   
   # Update day (weekly)
   TOOL_UPDATE_DAY="Sat"
   
   # Update time
   TOOL_UPDATE_TIME="05:00"
   ```

#### Maintenance Scheduling

1. **Log Rotation**:
   ```bash
   # Enable log rotation
   LOG_ROTATION_ENABLED=true
   
   # Rotation schedule (daily, weekly, monthly)
   LOG_ROTATION_SCHEDULE="weekly"
   
   # Retention period (days)
   LOG_RETENTION_DAYS=30
   ```

2. **Database Maintenance**:
   ```bash
   # Enable database maintenance
   DB_MAINTENANCE_ENABLED=true
   
   # Maintenance schedule
   DB_MAINTENANCE_DAY="Sun"
   DB_MAINTENANCE_TIME="06:00"
   
   # Maintenance tasks
   DB_VACUUM=true
   DB_REINDEX=true
   DB_ANALYZE=true
   ```

#### Scheduling Management

1. **Systemd Timer Configuration**:
   ```bash
   # List active timers
   systemctl list-timers --all | grep aegis
   
   # Enable/disable timers
   sudo systemctl enable aegis-daily-scan.timer
   sudo systemctl disable aegis-weekly-scan.timer
   
   # Modify timer configuration
   sudo systemctl edit aegis-daily-scan.timer
   ```

2. **Cron Job Configuration**:
   ```bash
   # View cron jobs
   crontab -l
   
   # Edit cron jobs
   crontab -e
   
   # Example cron entries
   0 2 * * * $AEGIS_HOME/scripts/security-daily-scan.sh
   0 3 * * 0 $AEGIS_HOME/scripts/security-weekly-scan.sh
   ```

---

## 8. Troubleshooting

### Common Issues and Solutions

This section addresses common issues that users may encounter while using the Aegis Security Suite.

#### Installation Issues

1. **Permission Denied Errors**:
   - **Problem**: Installation fails with permission errors
   - **Solution**: Ensure you have sudo privileges and run installation with sudo
   - **Command**: `sudo ./setup-aegis.sh`

2. **Missing Dependencies**:
   - **Problem**: Required packages not found
   - **Solution**: Update package database and install dependencies
   - **Command**: 
     ```bash
     sudo pacman -Syu
     sudo pacman -S clamav rkhunter chkrootkit lynis python python-pip
     ```

3. **Python Module Import Errors**:
   - **Problem**: Python modules not found
   - **Solution**: Install required Python packages
   - **Command**: 
     ```bash
     pip install -r src/dashboard/requirements.txt
     ```

#### Dashboard Issues

1. **Dashboard Not Accessible**:
   - **Problem**: Cannot access web dashboard
   - **Solution**: Check if dashboard service is running
   - **Command**: 
     ```bash
     sudo systemctl status aegis-dashboard
     sudo systemctl start aegis-dashboard
     ```

2. **Login Authentication Failures**:
   - **Problem**: Cannot log in to dashboard
   - **Solution**: Reset admin password
   - **Command**: 
     ```bash
     ./web-dashboard/reset-password.sh
     ```

3. **Real-time Updates Not Working**:
   - **Problem**: Dashboard not updating in real-time
   - **Solution**: Check WebSocket configuration
   - **Command**: 
     ```bash
     # Check if WebSocket port is open
     netstat -tlnp | grep :8081
     ```

#### Scanning Issues

1. **Scan Not Starting**:
   - **Problem**: Security scan fails to start
   - **Solution**: Check security tool installation
   - **Command**: 
     ```bash
     which clamscan
     which rkhunter
     which chkrootkit
     which lynis
     ```

2. **Scan Running Slowly**:
   - **Problem**: Scan taking excessive time
   - **Solution**: Limit scan scope or exclude large directories
   - **Configuration**: 
     ```bash
     # Edit scan configuration
     nano configs/security-config.conf
     
     # Exclude directories
     EXCLUDE_DIRECTORIES="/mnt,/media,/tmp"
     ```

3. **False Positives**:
   - **Problem**: Legitimate files flagged as malicious
   - **Solution**: Add files to whitelist
   - **Command**: 
     ```bash
     # Add to whitelist
     echo "/path/to/legitimate/file" >> configs/whitelist.txt
     ```

#### Behavioral Analysis Issues

1. **Baseline Creation Fails**:
   - **Problem**: Unable to create behavioral baseline
   - **Solution**: Check system resources and permissions
   - **Command**: 
     ```bash
     # Check disk space
     df -h
     
     # Check permissions
     ls -la configs/behavioral_analysis/
     ```

2. **Too Many False Alerts**:
   - **Problem**: Excessive anomaly alerts
   - **Solution**: Adjust sensitivity settings
   - **Configuration**: 
     ```bash
     # Edit behavioral analysis configuration
     nano configs/security-config.conf
     
     # Adjust sensitivity
     BEHAVIORAL_SENSITIVITY_LEVEL=low
     BEHAVIORAL_THREAT_SCORE_THRESHOLD=80
     ```

3. **High Resource Usage**:
   - **Problem**: Behavioral analysis consuming excessive resources
   - **Solution**: Increase monitoring interval
   - **Configuration**: 
     ```bash
     # Increase monitoring interval
     BEHAVIORAL_MONITORING_INTERVAL=300
     ```

#### Incident Management Issues

1. **Incident Not Created**:
   - **Problem**: Security events not generating incidents
   - **Solution**: Check incident response configuration
   - **Command**: 
     ```bash
     # Test incident creation
     ./src/core/scripts/incident-response.sh --test --create
     ```

2. **Evidence Collection Fails**:
   - **Problem**: Unable to collect evidence
   - **Solution**: Check permissions and disk space
   - **Command**: 
     ```bash
     # Check evidence directory
     ls -la $HOME/aegis-security-suite/evidence/
     
     # Check permissions
     chmod 755 $HOME/aegis-security-suite/evidence/
     ```

#### Threat Intelligence Issues

1. **Feed Updates Failing**:
   - **Problem**: Threat feeds not updating
   - **Solution**: Check network connectivity and API keys
   - **Command**: 
     ```bash
     # Test network connectivity
     curl -I https://example.com/threat-feed
     
     # Check feed configuration
     ./scripts/threat-intelligence.sh --test-connection
     ```

2. **IOC Database Corruption**:
   - **Problem**: IOC database not accessible
   - **Solution**: Rebuild database from backup
   - **Command**: 
     ```bash
     # Rebuild database
     ./scripts/threat-intelligence.sh --rebuild-database
     ```

### Debug Procedures

When troubleshooting complex issues, follow these systematic debugging procedures.

#### Enable Debug Mode

1. **Global Debug Mode**:
   ```bash
   # Enable debug logging
   export DEBUG=true
   export LOG_LEVEL=DEBUG
   
   # Run with debug
   ./scripts/security-daily-scan.sh --debug
   ```

2. **Component-specific Debug**:
   ```bash
   # Behavioral analysis debug
   ./scripts/behavioral-analysis.sh --debug
   
   # Incident response debug
   ./scripts/incident-response.sh --debug
   
   # Threat intelligence debug
   ./scripts/threat-intelligence.sh --debug
   ```

#### Log Analysis

1. **System Logs**:
   ```bash
   # View system logs
   journalctl -u aegis-dashboard -f
   journalctl -u aegis-daily-scan -f
   ```

2. **Application Logs**:
   ```bash
   # View application logs
   tail -f $HOME/aegis-security-suite/logs/security-suite.log
   tail -f $HOME/aegis-security-suite/logs/behavioral-analysis.log
   tail -f $HOME/aegis-security-suite/logs/incident-response.log
   ```

3. **Error Logs**:
   ```bash
   # View error logs
   tail -f $HOME/aegis-security-suite/logs/errors.log
   grep -i error $HOME/aegis-security-suite/logs/*.log
   ```

#### Diagnostic Commands

1. **System Diagnostics**:
   ```bash
   # Run system diagnostics
   ./scripts/diagnostics.sh --system
   
   # Check dependencies
   ./scripts/diagnostics.sh --dependencies
   
   # Verify configuration
   ./scripts/diagnostics.sh --config
   ```

2. **Component Diagnostics**:
   ```bash
   # Test security tools
   ./scripts/diagnostics.sh --security-tools
   
   # Test behavioral analysis
   ./scripts/diagnostics.sh --behavioral-analysis
   
   # Test threat intelligence
   ./scripts/diagnostics.sh --threat-intelligence
   ```

#### Performance Analysis

1. **Resource Usage**:
   ```bash
   # Monitor resource usage
   top -p $(pgrep -f aegis-security-suite)
   iotop -p $(pgrep -f aegis-security-suite)
   ```

2. **Performance Profiling**:
   ```bash
   # Profile script execution
   time ./scripts/security-daily-scan.sh
   
   # Profile with detailed timing
   ./scripts/security-daily-scan.sh --profile
   ```

### Log File Locations

The Aegis Security Suite maintains comprehensive logs for troubleshooting and analysis.

#### Main Log Directory

All logs are stored in `$HOME/aegis-security-suite/logs/`:

1. **Application Logs**:
   - `security-suite.log` - Main application log
   - `behavioral-analysis.log` - Behavioral analysis log
   - `incident-response.log` - Incident response log
   - `threat-intelligence.log` - Threat intelligence log

2. **System Logs**:
   - `dashboard.log` - Web dashboard log
   - `scanner.log` - Security scanner log
   - `scheduler.log` - Task scheduler log

3. **Error Logs**:
   - `errors.log` - Consolidated error log
   - `critical.log` - Critical error log
   - `warnings.log` - Warning log

#### Log Rotation

1. **Rotated Logs**:
   - `security-suite.log.1` - Previous day's log
   - `security-suite.log.2.gz` - Compressed older logs
   - `archive/` - Directory for archived logs

2. **Log Rotation Configuration**:
   ```bash
   # View log rotation configuration
   cat /etc/logrotate.d/aegis-security-suite
   
   # Force log rotation
   logrotate -f /etc/logrotate.d/aegis-security-suite
   ```

#### Log Analysis Tools

1. **Log Viewer**:
   ```bash
   # View logs with filtering
   ./scripts/log-viewer.sh --file security-suite.log --level ERROR
   
   # Search logs
   ./scripts/log-viewer.sh --search "malware detected" --file *.log
   ```

2. **Log Statistics**:
   ```bash
   # Generate log statistics
   ./scripts/log-analyzer.sh --stats --file security-suite.log
   
   # Error analysis
   ./scripts/log-analyzer.sh --errors --file *.log
   ```

### Support Resources

When encountering issues that cannot be resolved through troubleshooting, utilize these support resources.

#### Documentation

1. **User Guide**: This comprehensive guide
2. **API Documentation**: `docs/API.md`
3. **Installation Guide**: `docs/INSTALLATION.md`
4. **Security Components**: `docs/SECURITY_COMPONENTS.md`

#### Community Support

1. **GitHub Issues**:
   - Report bugs: https://github.com/aegis-linux/aegis-security-suite/issues
   - Feature requests: https://github.com/aegis-linux/aegis-security-suite/issues/new

2. **Forums**:
   - Aegis Linux Forums: https://forum.aegislinux.org
   - Security Section: https://forum.aegislinux.org/c/security

3. **Chat/IRC**:
   - Aegis Linux Discord: https://discord.gg/aegislinux
   - #security channel for security discussions

#### Professional Support

1. **Enterprise Support**:
   - Contact: security@aegislinux.org
   - Response time: 24-48 hours

2. **Security Incident Reporting**:
   - Critical security issues: security@aegislinux.org
   - PGP key available for encrypted communications

#### Contributing

1. **Bug Reports**:
   - Use GitHub issue template
   - Include system information
   - Provide reproduction steps
   - Attach relevant logs

2. **Feature Requests**:
   - Submit via GitHub issues
   - Describe use case
   - Provide implementation suggestions

3. **Code Contributions**:
   - Fork repository
   - Create feature branch
   - Submit pull request
   - Follow coding standards

---

## Quick Start Guide

For users who want to get started quickly, follow these essential steps:

### 1. Installation (5 minutes)

```bash
# Clone repository
git clone https://github.com/aegis-linux/aegis-security-suite.git
cd aegis-security-suite

# Run installation script
sudo ./setup-aegis.sh

# Follow on-screen prompts
```

### 2. Initial Configuration (2 minutes)

```bash
# Update security tools
sudo freshclam
sudo rkhunter --update

# Start web dashboard
cd web-dashboard
./start-dashboard.sh
```

### 3. First Security Scan (1 minute)

1. Open browser to `http://localhost:8080`
2. Login with default credentials (admin/aegis123)
3. Click "Start Quick Scan" on dashboard
4. Wait for scan completion

### 4. Create Behavioral Baseline (5 minutes)

1. Navigate to "Behavioral Analysis"
2. Click "Create Baseline"
3. Set baseline period to 7 days
4. Click "Start Baseline Creation"

### 5. Configure Notifications (2 minutes)

1. Navigate to "Configuration" → "Notifications"
2. Enable desktop notifications
3. Set notification preferences
4. Save configuration

### 6. Schedule Automated Scans (2 minutes)

1. Navigate to "Configuration" → "Scheduling"
2. Set daily scan time to 02:00
3. Enable automated scheduling
4. Apply changes

You're now ready to use the Aegis Security Suite! The system will:
- Monitor your system for security threats
- Perform automated scans daily
- Alert you to any security issues
- Maintain a behavioral baseline for anomaly detection

For detailed information about any feature, refer to the corresponding section in this comprehensive user guide.

---

## Feature Reference

This section provides detailed information about all features and capabilities of the Aegis Security Suite.

### Dashboard Features

#### Real-time Monitoring
- **System Performance**: Live CPU, memory, disk, and network monitoring
- **Threat Assessment**: Continuous threat score calculation and display
- **Incident Tracking**: Real-time incident status updates
- **Alert Notifications**: Immediate notification of security events

#### Interactive Visualizations
- **Performance Charts**: Historical system performance data
- **Threat Timeline**: Visual representation of threat evolution
- **Incident Statistics**: Graphical incident analysis
- **IOC Distribution**: Threat intelligence visualization

#### Quick Actions
- **Security Scans**: Initiate immediate security scans
- **Baseline Management**: Create and update behavioral baselines
- **Threat Intelligence**: Update threat feeds and IOCs
- **Report Generation**: Create comprehensive security reports

### Security Scanning Features

#### Multi-Engine Scanning
- **ClamAV**: Antivirus and malware detection
- **Rkhunter**: Rootkit detection and system integrity
- **Chkrootkit**: Alternative rootkit scanner
- **Lynis**: System vulnerability assessment

#### Scan Types
- **Quick Scan**: Focused scan of high-risk areas
- **Full Scan**: Comprehensive system scan
- **Custom Scan**: User-defined scan parameters
- **Scheduled Scan**: Automated scanning at specified intervals

#### Threat Detection
- **Malware Detection**: Virus, trojan, and spyware detection
- **Rootkit Detection**: Hidden malware and system compromises
- **Vulnerability Assessment**: Security weakness identification
- **Policy Violation**: Security policy compliance checking

### Behavioral Analysis Features

#### Baseline Creation
- **Learning Period**: Configurable baseline learning duration
- **Statistical Analysis**: Advanced statistical modeling
- **Multiple Metrics**: CPU, memory, network, and process baselines
- **Continuous Updates**: Automatic baseline refresh

#### Anomaly Detection
- **Real-time Monitoring**: Continuous behavior analysis
- **Statistical Deviation**: Standard deviation-based detection
- **Pattern Recognition**: Behavioral pattern analysis
- **Threat Scoring**: Quantitative threat assessment

#### Alert Management
- **Severity Levels**: Critical, high, medium, and low alerts
- **Alert Correlation**: Related event grouping
- **False Positive Reduction**: Machine learning-based filtering
- **Alert Triage**: Automated prioritization

### Incident Management Features

#### Incident Lifecycle
- **Detection**: Automatic and manual incident creation
- **Triage**: Initial assessment and prioritization
- **Investigation**: Detailed analysis and evidence collection
- **Response**: Containment and remediation actions
- **Resolution**: Incident closure and documentation

#### Evidence Collection
- **Automated Collection**: Systematic evidence gathering
- **Chain of Custody**: Proper evidence handling
- **Forensic Analysis**: Detailed forensic capabilities
- **Evidence Preservation**: Secure evidence storage

#### Response Automation
- **Containment Actions**: Automatic threat containment
- **Mitigation Measures**: Automated threat mitigation
- **Notification System**: Multi-channel alerting
- **Escalation Procedures**: Automatic incident escalation

### Threat Intelligence Features

#### IOC Management
- **Comprehensive Database**: Extensive IOC repository
- **Multiple Types**: IPs, domains, hashes, and URLs
- **Real-time Updates**: Continuous threat intelligence updates
- **Quality Assurance**: IOC validation and verification

#### Feed Management
- **Multiple Sources**: Public, commercial, and internal feeds
- **Automatic Updates**: Scheduled feed updates
- **Feed Validation**: Quality and integrity checking
- **Custom Feeds**: Support for custom threat feeds

#### Intelligence Analysis
- **Threat Correlation**: IOC relationship analysis
- **Trend Analysis**: Threat evolution tracking
- **Contextual Information**: Enriched threat data
- **Predictive Analysis**: Threat prediction capabilities

### Configuration Features

#### Flexible Configuration
- **Web Interface**: User-friendly configuration management
- **Command Line**: Script-based configuration
- **Configuration Files**: Direct file editing
- **API Access**: Programmatic configuration

#### Security Settings
- **Tool Configuration**: Security tool parameters
- **Scan Settings**: Customizable scan options
- **Monitoring Configuration**: Behavioral analysis settings
- **Response Configuration**: Incident response parameters

#### System Integration
- **Systemd Integration**: Native systemd service support
- **Cron Integration**: Traditional cron job support
- **Log Integration**: System log integration
- **Network Integration**: Network service integration

---

This comprehensive user guide provides all the information needed to effectively use the Aegis Security Suite for comprehensive security monitoring and protection. For additional assistance, refer to the support resources section or contact the Aegis Linux security team.