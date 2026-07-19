# 🖥️ Aegis Security Suite - Dashboard Access Guide

### _"Complete guide to accessing and using the Aegis Security Dashboard"_

---

## 📋 Table of Contents

1. [Dashboard Overview](#1-dashboard-overview)
2. [Accessing the Dashboard](#2-accessing-the-dashboard)
3. [First-Time Login](#3-first-time-login)
4. [Dashboard Navigation](#4-dashboard-navigation)
5. [Main Dashboard Features](#5-main-dashboard-features)
6. [Real-Time Monitoring](#6-real-time-monitoring)
7. [Behavioral Analysis View](#7-behavioral-analysis-view)
8. [Threat Intelligence View](#8-threat-intelligence-view)
9. [Incident Response View](#9-incident-response-view)
10. [Configuration Management](#10-configuration-management)
11. [Mobile Access](#11-mobile-access)
12. [Dashboard Troubleshooting](#12-dashboard-troubleshooting)

---

## 1. Dashboard Overview

### What is the Aegis Security Dashboard?

The Aegis Security Dashboard is a web-based interface that provides:

- **Real-time Security Monitoring**: Live view of your system's security status
- **Behavioral Analysis**: Visual representation of system behavior and anomalies
- **Threat Intelligence**: Current threat levels and security alerts
- **Incident Management**: Overview of security incidents and response actions
- **Configuration Access**: Easy access to security suite configuration
- **System Health**: Overall system health and performance metrics

### Dashboard Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Aegis Security Dashboard                │
├─────────────────────────────────────────────────────────────┤
│  Web Frontend (Flask + Socket.IO)                           │
│  ├── Authentication System                                   │
│  ├── Real-time Updates (WebSocket)                          │
│  ├── API Endpoints                                          │
│  └── Responsive UI Design                                   │
├─────────────────────────────────────────────────────────────┤
│  Backend Integration                                         │
│  ├── Behavioral Analysis Engine                              │
│  ├── Incident Response System                               │
│  ├── Threat Intelligence                                    │
│  └── Security Scanning Results                              │
├─────────────────────────────────────────────────────────────┤
│  Data Sources                                               │
│  ├── SQLite Databases                                       │
│  ├── System Metrics                                         │
│  ├── Security Logs                                          │
│  └── Real-time Data Streams                                │
└─────────────────────────────────────────────────────────────┘
```

### Key Features

#### 🔐 **Secure Authentication**
- bcrypt password hashing
- Session management
- Role-based access control
- CSRF protection

#### 📊 **Real-time Monitoring**
- Live system metrics
- WebSocket updates
- Auto-refreshing data
- Alert notifications

#### 🎯 **Behavioral Analysis**
- System behavior visualization
- Anomaly detection display
- Threat scoring
- Historical trend analysis

#### 🚨 **Incident Management**
- Active incident overview
- Response action tracking
- Evidence collection status
- Incident timeline

#### 🛡️ **Threat Intelligence**
- Current threat levels
- IOC database status
- Security alerts
- Threat feed updates

#### ⚙️ **Configuration Management**
- Security suite configuration
- Scan scheduling
- Notification settings
- System preferences

---

## 2. Accessing the Dashboard

### Prerequisites

Before accessing the dashboard, ensure:

1. **Security Suite Installed**: Complete installation of Aegis Security Suite
2. **Dashboard Service Running**: Dashboard service must be started
3. **Network Access**: Network connectivity to the dashboard server
4. **Modern Browser**: Updated web browser with JavaScript enabled

### Starting the Dashboard Service

#### Method 1: Using the Service Management Script
```bash
# Navigate to security suite directory
cd ~/aegis-security-suite

# Start the dashboard
./src/core/scripts/start-aegis.sh start web-dashboard

# Check dashboard status
./src/core/scripts/start-aegis.sh status
```

#### Method 2: Using the Dashboard Script
```bash
# Navigate to dashboard directory
cd ~/aegis-security-suite/src/dashboard

# Start the dashboard
./start-dashboard.sh start

# Check dashboard status
./start-dashboard.sh status
```

#### Method 3: Manual Start
```bash
# Navigate to dashboard directory
cd ~/aegis-security-suite/src/dashboard

# Install Python dependencies (if not already installed)
pip3 install --user -r requirements.txt

# Start the dashboard manually
python3 app.py
```

### Verifying Dashboard is Running

#### Check Service Status
```bash
# Using service management script
./src/core/scripts/start-aegis.sh status

# Expected output should show:
# ✅ Web Dashboard: Running (PID: 12345, Port: 8080)
```

#### Check Port Availability
```bash
# Check if port 8080 is listening
netstat -tlnp | grep 8080
# or
ss -tlnp | grep 8080

# Expected output should show:
# tcp 0 0 0.0.0.0:8080 0.0.0.0:* LISTEN 12345/python3
```

#### Test HTTP Connection
```bash
# Test HTTP connection
curl -I http://localhost:8080/

# Expected output should show:
# HTTP/1.1 200 OK
# Server: Werkzeug/...
# Date: ...
# Content-Type: text/html; charset=utf-8
```

### Accessing the Dashboard

#### Local Access
```
http://localhost:8080
```

#### Network Access (from other machines)
```
http://[SERVER_IP]:8080
```

Replace `[SERVER_IP]` with the actual IP address of the machine running the dashboard.

#### Finding Your IP Address
```bash
# Find your IP address
ip addr show | grep "inet " | grep -v 127.0.0.1

# Or use
hostname -I
```

---

## 3. First-Time Login

### Default Credentials

The dashboard comes with default credentials for first-time access:

- **Username**: `admin`
- **Password**: `aegis123`

⚠️ **Security Warning**: Change the default password immediately after first login!

### Login Process

#### Step 1: Open Login Page
1. Open your web browser
2. Navigate to `http://localhost:8080` (or `http://[SERVER_IP]:8080`)
3. You should see the login page

#### Step 2: Enter Credentials
1. Enter username: `admin`
2. Enter password: `aegis123`
3. Click "Login" button

#### Step 3: First-Time Setup
1. After successful login, you'll be redirected to the main dashboard
2. You may see a welcome message or setup wizard
3. Follow any on-screen instructions

### Changing Default Password

#### Method 1: Through Dashboard UI
1. Click on your username in the top-right corner
2. Select "Change Password" from the dropdown
3. Enter current password: `aegis123`
4. Enter new password (minimum 8 characters, include numbers and symbols)
5. Confirm new password
6. Click "Change Password"

#### Method 2: Using Command Line
```bash
# Navigate to dashboard directory
cd ~/aegis-security-suite/src/dashboard

# Reset admin password
python3 -c "
from auth import hash_password, update_password
import getpass

# Get new password
new_password = getpass.getpass('Enter new password: ')
hashed_password = hash_password(new_password)

# Update password in database
import sqlite3
conn = sqlite3.connect('auth.db')
cursor = conn.cursor()
cursor.execute('UPDATE users SET password = ? WHERE username = ?', (hashed_password, 'admin'))
conn.commit()
conn.close()

print('Password updated successfully')
"
```

### Creating Additional Users

#### Method 1: Through Dashboard UI (if available)
1. Navigate to "Configuration" section
2. Look for "User Management"
3. Click "Add User"
4. Fill in user details
5. Assign appropriate permissions

#### Method 2: Using Command Line
```bash
# Navigate to dashboard directory
cd ~/aegis-security-suite/src/dashboard

# Create new user
python3 -c "
from auth import hash_password
import sqlite3
import getpass

# Get user details
username = input('Enter username: ')
password = getpass.getpass('Enter password: ')
email = input('Enter email (optional): ')

# Hash password
hashed_password = hash_password(password)

# Add user to database
conn = sqlite3.connect('auth.db')
cursor = conn.cursor()
cursor.execute('INSERT INTO users (username, password, email) VALUES (?, ?, ?)', 
               (username, hashed_password, email))
conn.commit()
conn.close()

print(f'User {username} created successfully')
"
```

---

## 4. Dashboard Navigation

### Main Layout

```
┌─────────────────────────────────────────────────────────────┐
│  Header: Logo | Navigation | User Menu | Notifications      │
├─────────────────────────────────────────────────────────────┤
│  Sidebar:                                                   │
│  ├── Dashboard                                              │
│  ├── Behavioral Analysis                                    │
│  ├── Threat Intelligence                                     │
│  ├── Incident Response                                      │
│  ├── Configuration                                          │
│  └── System Status                                          │
├─────────────────────────────────────────────────────────────┤
│  Main Content Area:                                         │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Dynamic content based on selected page              │   │
│  └─────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│  Footer: Status | Last Update | Version                   │
└─────────────────────────────────────────────────────────────┘
```

### Navigation Menu

#### 🏠 **Dashboard**
- Main overview page
- System health summary
- Recent security events
- Quick access to key metrics

#### 🧠 **Behavioral Analysis**
- System behavior monitoring
- Anomaly detection results
- Threat scoring visualization
- Historical trend analysis

#### 🛡️ **Threat Intelligence**
- Current threat levels
- IOC database status
- Security alerts
- Threat feed updates

#### 🚨 **Incident Response**
- Active incidents overview
- Response action tracking
- Evidence collection status
- Incident timeline

#### ⚙️ **Configuration**
- Security suite settings
- Scan scheduling
- Notification preferences
- User management

#### 📊 **System Status**
- Service status overview
- Resource usage metrics
- Database statistics
- Log file information

### User Menu

#### 👤 **User Profile**
- View user information
- Change password
- Update preferences

#### 🔔 **Notifications**
- View recent notifications
- Configure alert settings
- Clear notification history

#### 🚪 **Logout**
- Secure logout
- Session termination
- Return to login page

---

## 5. Main Dashboard Features

### Overview Section

#### System Health Status
```
┌─────────────────────────────────────────────────────────────┐
│                    System Health Status                     │
├─────────────────────────────────────────────────────────────┤
│  🟢 Security Services: All Running                          │
│  🟡 Behavioral Analysis: Monitoring Active                 │
│  🟢 Incident Response: Ready                                │
│  🟢 Threat Intelligence: Updated                            │
│  🟢 Database Connections: All Connected                     │
└─────────────────────────────────────────────────────────────┘
```

#### Quick Stats
```
┌─────────────────────────────────────────────────────────────┐
│                      Quick Statistics                       │
├─────────────────────────────────────────────────────────────┤
│  📊 System Metrics: 1,234 records collected                │
│  🚨 Active Incidents: 2                                      │
│  🎯 Threat Score: 3.2/10 (Low)                              │
│  🛡️ Last Scan: 2 hours ago                                 │
│  📈 Anomalies Detected: 5 (last 24h)                        │
└─────────────────────────────────────────────────────────────┘
```

#### Recent Activity
```
┌─────────────────────────────────────────────────────────────┐
│                      Recent Activity                        │
├─────────────────────────────────────────────────────────────┤
│  ✅ Security scan completed - 0 threats found               │
│  ⚠️  Anomaly detected: High CPU usage                       │
│  🚨 Incident created: Suspicious network activity           │
│  📊 Behavioral baseline updated                              │
│  🔄 Threat intelligence database updated                    │
└─────────────────────────────────────────────────────────────┘
```

### Real-time Updates

#### WebSocket Connection
- **Status Indicator**: Shows connection status (Connected/Disconnected)
- **Auto-refresh**: Data updates automatically every 5 seconds
- **Manual Refresh**: Click refresh button to update immediately
- **Connection Recovery**: Automatically reconnects if connection lost

#### Live Metrics
- **CPU Usage**: Current CPU utilization
- **Memory Usage**: Current memory utilization
- **Disk Usage**: Current disk utilization
- **Network Activity**: Current network I/O
- **Process Count**: Number of running processes
- **Active Connections**: Number of network connections

### Alert System

#### Alert Types
- **🔴 Critical**: Immediate attention required
- **🟡 Warning**: Potential issue detected
- **🔵 Info**: Informational message
- **🟢 Success**: Operation completed successfully

#### Alert Actions
- **View Details**: Click alert to see more information
- **Acknowledge**: Mark alert as acknowledged
- **Dismiss**: Remove alert from view
- **Create Incident**: Convert alert to security incident

---

## 6. Real-Time Monitoring

### System Metrics Dashboard

#### CPU Monitoring
```
┌─────────────────────────────────────────────────────────────┐
│                      CPU Usage                              │
├─────────────────────────────────────────────────────────────┤
│  Current: 25% ████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
│  Average (1h): 18% ██████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
│  Peak (24h): 85% ████████████████████████████████░░░░░░░░░ │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ CPU Usage History (Last Hour)                       │   │
│  │ 100% ┤                                              │   │
│  │  80% ┤     ████                                     │   │
│  │  60% ┤   ██    ██                                   │   │
│  │  40% ┤ ██        ███                               │   │
│  │  20% ┤██            ████████████                    │   │
│  │   0% └───────────────────────────────────────────── │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

#### Memory Monitoring
```
┌─────────────────────────────────────────────────────────────┐
│                     Memory Usage                            │
├─────────────────────────────────────────────────────────────┤
│  Total: 8.0 GB                                              │
│  Used: 4.2 GB (52%) ████████████████░░░░░░░░░░░░░░░░░░░░░ │
│  Free: 3.8 GB (48%) ░░░░░░░░░░░░░░░░░░░░░░░░░░░███████████ │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Memory Breakdown                                   │   │
│  │ Applications: 2.8 GB ████████████░░░░░░░░░░░░░░░░░ │   │
│  │ System:       1.2 GB ██████░░░░░░░░░░░░░░░░░░░░░░░ │   │
│  │ Cache:        0.2 GB ██░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

#### Network Monitoring
```
┌─────────────────────────────────────────────────────────────┐
│                    Network Activity                          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Network I/O (Last Hour)                            │   │
│  │ 10 MB/s ┤                                           │   │
│  │  8 MB/s ┤     ██                                   │   │
│  │  6 MB/s ┤   ██  ██                                  │   │
│  │  4 MB/s ┤ ██      ██                                │   │
│  │  2 MB/s ┤██          ████████████                   │   │
│  │  0 MB/s └──────────────────────────────────────────── │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  Active Connections: 45                                    │
│  Listening Ports: 12                                        │
│  Established Connections: 33                               │
└─────────────────────────────────────────────────────────────┘
```

### Process Monitoring

#### Top Processes
```
┌─────────────────────────────────────────────────────────────┐
│                      Top Processes                          │
├─────────────────────────────────────────────────────────────┤
│  PID  │ Process Name    │ CPU  │ Memory │ User    │ Status   │
├─────────────────────────────────────────────────────────────┤
│ 1234 │ python3         │ 15%  │ 8.2%   │ user    │ Running  │
│ 5678 │ clamav          │ 12%  │ 5.1%   │ root    │ Running  │
│ 9012 │ firefox         │ 8%   │ 12.3%  │ user    │ Running  │
│ 3456 │ systemd         │ 2%   │ 0.8%   │ root    │ Running  │
│ 7890 │ Xorg            │ 1%   │ 2.1%   │ user    │ Running  │
└─────────────────────────────────────────────────────────────┘
```

#### Service Status
```
┌─────────────────────────────────────────────────────────────┐
│                    Service Status                            │
├─────────────────────────────────────────────────────────────┤
│  🟢 security-daily-scan    │ Running  │ Last: 2 hours ago   │
│  🟢 behavioral-monitor     │ Running  │ Uptime: 5 days       │
│  🟢 web-dashboard          │ Running  │ Uptime: 1 hour       │
│  🟡 threat-intelligence    │ Stopped  │ Last: 1 day ago      │
│  🟢 incident-response      │ Ready    │ Last incident: None  │
└─────────────────────────────────────────────────────────────┘
```

---

## 7. Behavioral Analysis View

### Anomaly Detection Dashboard

#### Current Threat Score
```
┌─────────────────────────────────────────────────────────────┐
│                  Current Threat Score                        │
├─────────────────────────────────────────────────────────────┤
│  Overall Score: 3.2/10 (Low Risk)                           │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Threat Score Gauge                                  │   │
│  │ 10 ┤ ████████████████████████████████████████████   │   │
│  │  8 ┤ ████████████████████████████░░░░░░░░░░░░░░░   │   │
│  │  6 ┤ ████████████████████░░░░░░░░░░░░░░░░░░░░░░░   │   │
│  │  4 ┤ ████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░   │
│  │  2 ┤ ████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░   │   │
│  │  0 └───────────────────────────────────────────── │   │
│  │           ▲ Current: 3.2                             │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

#### Anomaly Categories
```
┌─────────────────────────────────────────────────────────────┐
│                  Anomaly Categories                          │
├─────────────────────────────────────────────────────────────┤
│  🖥️  System Performance: 2 anomalies detected              │
│     • High CPU usage spike (85% for 5 minutes)              │
│     • Memory usage above threshold (85%)                   │
│                                                             │
│  🌐 Network Activity: 1 anomaly detected                   │
│     • Unusual outbound connection to 192.168.1.100        │
│                                                             │
│  📁 File System: 0 anomalies detected                       │
│                                                             │
│  🔐 Authentication: 0 anomalies detected                    │
│                                                             │
│  🚀 Process Activity: 2 anomalies detected                 │
│     • New process: suspicious_process.sh                   │
│     • Process termination: system_monitor                   │
└─────────────────────────────────────────────────────────────┘
```

### Historical Trends

#### Threat Score History
```
┌─────────────────────────────────────────────────────────────┐
│                Threat Score History (7 Days)                │
├─────────────────────────────────────────────────────────────┤
│  10 ┤                                                      │
│   8 ┤               ████                                    │
│   6 ┤     ██       ██  ██      ██                          │
│   4 ┤   ██  ██   ██      ██  ██  ██                        │
│   2 ┤ ██      ████          ████    ██                     │
│   0 └───────────────────────────────────────────────────── │
│     Mon  Tue  Wed  Thu  Fri  Sat  Sun                      │
└─────────────────────────────────────────────────────────────┘
```

#### Anomaly Frequency
```
┌─────────────────────────────────────────────────────────────┐
│                Anomaly Frequency (24 Hours)                  │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐   │
│  │ 5 ┤     █                                           │   │
│  │ 4 ┤ █   █ █                                         │   │
│  │ 3 ┤ █ █ █ █ █                                       │   │
│  │ 2 ┤ █ █ █ █ █ █ █                                   │   │
│  │ 1 ┤ █ █ █ █ █ █ █ █ █ █                             │   │
│  │ 0 └───────────────────────────────────────────── │   │
│  │   00  04  08  12  16  20  24                       │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  Total Anomalies: 15                                        │
│  Peak Time: 14:00 (3 anomalies)                            │
│  Average: 0.6 anomalies per hour                           │
└─────────────────────────────────────────────────────────────┘
```

### Baseline Comparison

#### Current vs Baseline Metrics
```
┌─────────────────────────────────────────────────────────────┐
│              Current vs Baseline Metrics                     │
├─────────────────────────────────────────────────────────────┤
│  Metric          │ Current │ Baseline │ Deviation │ Status  │
├─────────────────────────────────────────────────────────────┤
│  CPU Usage       │ 25%     │ 18%      │ +7%       │ ⚠️ High │
│  Memory Usage    │ 52%     │ 45%      │ +7%       │ ⚠️ High │
│  Process Count   │ 145     │ 132      │ +13       │ ⚠️ High │
│  Network I/O     │ 2.1 MB/s│ 1.8 MB/s │ +0.3 MB/s │ Normal  │
│  Disk I/O        │ 15 MB/s │ 12 MB/s  │ +3 MB/s   │ Normal  │
│  Login Attempts  │ 3       │ 2        │ +1        │ Normal  │
└─────────────────────────────────────────────────────────────┘
```

---

## 8. Threat Intelligence View

### Current Threat Landscape

#### Global Threat Level
```
┌─────────────────────────────────────────────────────────────┐
│                  Global Threat Level                         │
├─────────────────────────────────────────────────────────────┤
│  Overall: 🟡 MEDIUM (6.2/10)                               │
│                                                             │
│  🦠 Malware:        🟡 MEDIUM (5.8/10)                     │
│  🎯 Phishing:       🟠 HIGH (7.2/10)                       │
│  🌐 Network:        🟢 LOW (3.1/10)                        │
│  🔐 Authentication:  🟢 LOW (2.9/10)                        │
│  📁 File System:    🟡 MEDIUM (6.5/10)                     │
└─────────────────────────────────────────────────────────────┘
```

#### Recent Threat Alerts
```
┌─────────────────────────────────────────────────────────────┐
│                    Recent Threat Alerts                      │
├─────────────────────────────────────────────────────────────┤
│  🚨 [HIGH] New ransomware variant detected in wild          │
│     First seen: 2 hours ago                                 │
│     Affected systems: 127                                   │
│     Recommendation: Update antivirus signatures             │
│                                                             │
│  ⚠️  [MEDIUM] Phishing campaign targeting financial         │
│     institutions                                           │
│     First seen: 6 hours ago                                 │
│     Targeted regions: North America, Europe                 │
│     Recommendation: User awareness training                 │
│                                                             │
│  🔵 [INFO] Microsoft security patches released              │
│     Release date: Yesterday                                 │
│     Critical patches: 3                                     │
│     Recommendation: Apply patches within 7 days             │
└─────────────────────────────────────────────────────────────┘
```

### IOC Database Status

#### Database Overview
```
┌─────────────────────────────────────────────────────────────┐
│                  IOC Database Status                         │
├─────────────────────────────────────────────────────────────┤
│  Total IOCs: 1,234,567                                       │
│  Last Update: 2 hours ago                                    │
│  Next Update: In 6 hours                                     │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ IOC Breakdown                                       │   │
│  │ Malware Hashes:    456,789 ████████████████████░░░░ │   │
│  │ IP Addresses:      234,567 ████████████░░░░░░░░░░░░ │   │
│  │ Domains:           345,678 █████████████████░░░░░░░░ │   │
│  │ URLs:              123,456 ████████░░░░░░░░░░░░░░░░░ │   │
│  │ Email Addresses:   74,077  ████░░░░░░░░░░░░░░░░░░░░░ │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

#### Recent IOC Updates
```
┌─────────────────────────────────────────────────────────────┐
│                  Recent IOC Updates                          │
├─────────────────────────────────────────────────────────────┤
│  🦠 Malware Hashes: +1,234 new entries                     │
│     • Trojan.GenericKD.456789                               │
│     • Backdoor.Linux.12345                                  │
│     • Ransomware.Win32.67890                                │
│                                                             │
│  🌐 IP Addresses: +567 new entries                          │
│     • 192.168.1.100 (C2 Server)                            │
│     • 10.0.0.50 (Malicious Host)                            │
│     • 172.16.0.25 (Botnet Node)                             │
│                                                             │
│  🌐 Domains: +890 new entries                               │
│     • malicious-domain.com                                  │
│     • phishing-site.net                                     │
│     • botnet-control.org                                    │
└─────────────────────────────────────────────────────────────┘
```

### Threat Feed Management

#### Active Threat Feeds
```
┌─────────────────────────────────────────────────────────────┐
│                  Active Threat Feeds                         │
├─────────────────────────────────────────────────────────────┤
│  ✅ MalwarePatrol.io     │ Last sync: 1 hour ago   │ 1.2M IOCs │
│  ✅ PhishTank            │ Last sync: 2 hours ago  │ 45K IOCs  │
│  ✅ Abuse.ch             │ Last sync: 30 min ago   │ 234K IOCs │
│  ✅ OpenPhish            │ Last sync: 3 hours ago  │ 67K IOCs  │
│  ⚠️  Custom Feed         │ Last sync: 1 day ago    │ 12K IOCs  │
│  ❌ Deprecated Feed      │ Not syncing             │ 0 IOCs    │
└─────────────────────────────────────────────────────────────┘
```

#### Feed Configuration
```
┌─────────────────────────────────────────────────────────────┐
│                  Feed Configuration                          │
├─────────────────────────────────────────────────────────────┤
│  Auto-update: ✅ Enabled                                     │
│  Update Frequency: Every 6 hours                             │
│  Retry Attempts: 3                                           │
│  Timeout: 30 seconds                                         │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Update Schedule                                     │   │
│  │ Next Update: In 4 hours                             │   │
│  │ Last Successful: 2 hours ago                        │   │
│  │ Last Failed: None                                   │   │
│  │ Total Updates: 1,234                                │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## 9. Incident Response View

### Active Incidents

#### Incident Overview
```
┌─────────────────────────────────────────────────────────────┐
│                    Active Incidents                          │
├─────────────────────────────────────────────────────────────┤
│  🚨 INC_20251101_001 │ HIGH   │ Suspicious Network Activity │
│     Created: 2 hours ago │ Status: Investigating           │
│     Assigned: admin      │ Priority: High                   │
│                                                             │
│  ⚠️  INC_20251101_002 │ MEDIUM │ Unauthorized Login Attempt │
│     Created: 4 hours ago │ Status: Contained                │
│     Assigned: analyst    │ Priority: Medium                 │
│                                                             │
│  🔵 INC_20251101_003 │ LOW    │ File Integrity Violation    │
│     Created: 6 hours ago │ Status: Resolved                 │
│     Assigned: admin      │ Priority: Low                    │
└─────────────────────────────────────────────────────────────┘
```

#### Incident Details
```
┌─────────────────────────────────────────────────────────────┐
│                Incident Details: INC_20251101_001            │
├─────────────────────────────────────────────────────────────┤
│  Title: Suspicious Network Activity                          │
│  Severity: HIGH                                              │
│  Status: Investigating                                       │
│  Created: 2025-11-01 05:30:00 UTC                           │
│  Assigned: admin                                             │
│                                                             │
│  Description:                                               │
│  Unusual outbound network traffic detected from             │
│  system process PID 1234 to IP address 192.168.1.100        │
│  on port 443. Traffic pattern consistent with               │
│  command and control communication.                          │
│                                                             │
│  Response Actions:                                           │
│  ✅ Isolate affected process (PID: 1234)                     │
│  ✅ Block IP address (192.168.1.100)                         │
│  🔄 Collect network evidence                                 │
│  ⏳ Analyze process memory                                   │
│  ⏳ Create containment strategy                              │
└─────────────────────────────────────────────────────────────┘
```

### Incident Timeline

#### Timeline View
```
┌─────────────────────────────────────────────────────────────┐
│                  Incident Timeline                           │
├─────────────────────────────────────────────────────────────┤
│  05:30 │ 🚨 Incident created by behavioral analysis         │
│  05:32 │ 👤 Assigned to admin                               │
│  05:35 │ 🔍 Investigation started                            │
│  05:40 │ 🛡️ Process isolated (PID: 1234)                     │
│  05:42 │ 🚫 IP address blocked (192.168.1.100)              │
│  05:45 │ 📁 Evidence collection initiated                    │
│  05:50 │ 📊 Network analysis in progress                     │
│  06:00 │ ⏳ Awaiting memory analysis results                 │
└─────────────────────────────────────────────────────────────┘
```

### Response Actions

#### Available Actions
```
┌─────────────────────────────────────────────────────────────┐
│                  Available Response Actions                  │
├─────────────────────────────────────────────────────────────┤
│  🛡️ Isolation Actions                                       │
│     • Isolate Process: Stop and contain suspicious process   │
│     • Isolate Network: Disconnect from network               │
│     • Isolate User: Disable user account                     │
│                                                             │
│  🚫 Blocking Actions                                         │
│     • Block IP: Block malicious IP addresses                 │
│     • Block Domain: Block malicious domains                  │
│     • Block Process: Prevent process execution              │
│                                                             │
│  📁 Evidence Collection                                       │
│     • Collect System State: Capture system snapshot         │
│     • Collect Memory: Dump process memory                   │
│     • Collect Network: Capture network traffic              │
│     • Collect Files: Preserve suspicious files              │
│                                                             │
│  🔄 Remediation Actions                                      │
│     • Quarantine File: Move suspicious file to quarantine    │
│     • Clean System: Remove malware artifacts                │
│     • Restore Backup: Restore from clean backup             │
│     • Update Signatures: Update security tool signatures    │
└─────────────────────────────────────────────────────────────┘
```

---

## 10. Configuration Management

### Security Suite Configuration

#### Main Configuration
```
┌─────────────────────────────────────────────────────────────┐
│                  Security Suite Configuration                │
├─────────────────────────────────────────────────────────────┤
│  📁 Scan Directories                                         │
│     • /home/user/Documents                                   │
│     • /home/user/Downloads                                   │
│     • /var/www                                               │
│     • /tmp                                                   │
│                                                             │
│  🛡️ Security Tools                                          │
│     ✅ ClamAV Antivirus                                      │
│     ✅ Rkhunter Rootkit Detection                            │
│     ✅ Chkrootkit Alternative Scanner                        │
│     ✅ Lynis Security Auditing                               │
│                                                             │
│  ⏰ Scheduling                                               │
│     • Daily Scan: 02:00 AM                                  │
│     • Weekly Scan: Sunday 03:00 AM                          │
│     • Monthly Scan: 1st of month 04:00 AM                   │
│     • Behavioral Monitoring: Continuous                     │
└─────────────────────────────────────────────────────────────┘
```

#### Notification Settings
```
┌─────────────────────────────────────────────────────────────┐
│                  Notification Settings                      │
├─────────────────────────────────────────────────────────────┤
│  📧 Email Notifications                                      │
│     ✅ Critical Alerts: admin@example.com                   │
│     ✅ Daily Reports: admin@example.com                     │
│     ⚠️  Warnings: admin@example.com                         │
│     ❌ Info Messages: Disabled                              │
│                                                             │
│  🔔 Browser Notifications                                   │
│     ✅ Critical Alerts: Enabled                             │
│     ✅ Warnings: Enabled                                     │
│     ⚠️  Info Messages: Disabled                              │
│                                                             │
│  📱 Mobile Notifications                                     │
│     ❌ Not configured                                        │
│                                                             │
│  🔊 Sound Alerts                                             │
│     ✅ Critical Alerts: Enabled                             │
│     ⚠️  Warnings: Disabled                                  │
│     ❌ Info Messages: Disabled                              │
└─────────────────────────────────────────────────────────────┘
```

### User Management

#### User Accounts
```
┌─────────────────────────────────────────────────────────────┐
│                      User Accounts                          │
├─────────────────────────────────────────────────────────────┤
│  👤 admin                                                    │
│     Role: Administrator                                      │
│     Email: admin@example.com                                │
│     Last Login: 2 hours ago                                  │
│     Status: Active                                          │
│                                                             │
│  👤 analyst                                                  │
│     Role: Analyst                                           │
│     Email: analyst@example.com                              │
│     Last Login: 1 day ago                                   │
│     Status: Active                                          │
│                                                             │
│  👤 viewer                                                   │
│     Role: Viewer                                            │
│     Email: viewer@example.com                               │
│     Last Login: 3 days ago                                  │
│     Status: Active                                          │
└─────────────────────────────────────────────────────────────┘
```

#### Role Permissions
```
┌─────────────────────────────────────────────────────────────┐
│                    Role Permissions                          │
├─────────────────────────────────────────────────────────────┤
│  Administrator:                                             │
│     ✅ Full system access                                   │
│     ✅ User management                                       │
│     ✅ Configuration changes                                │
│     ✅ Incident response actions                             │
│     ✅ System shutdown/restart                              │
│                                                             │
│  Analyst:                                                   │
│     ✅ View all security data                               │
│     ✅ Create and manage incidents                          │
│     ✅ Execute response actions                              │
│     ❌ User management                                       │
│     ❌ System configuration                                  │
│                                                             │
│  Viewer:                                                    │
│     ✅ View dashboard and reports                           │
│     ✅ View incidents (read-only)                            │
│     ❌ Create incidents                                      │
│     ❌ Execute response actions                             │
│     ❌ Configuration changes                                │
└─────────────────────────────────────────────────────────────┘
```

---

## 11. Mobile Access

### Responsive Design

The Aegis Security Dashboard is fully responsive and works on:

- 📱 **Smartphones**: iOS and Android devices
- 📟 **Tablets**: iPad, Android tablets, and similar devices
- 💻 **Laptops**: All screen sizes and resolutions
- 🖥️ **Desktops**: Large screens and multiple monitors

### Mobile Features

#### Touch-Friendly Interface
- **Large Touch Targets**: Buttons and controls sized for touch interaction
- **Swipe Gestures**: Navigate between pages with swipe gestures
- **Pull to Refresh**: Refresh data by pulling down on the screen
- **Pinch to Zoom**: Zoom in on charts and graphs for detailed viewing

#### Mobile-Optimized Layout
- **Collapsible Sidebar**: Sidebar collapses to hamburger menu on small screens
- **Vertical Navigation**: Navigation adapts to vertical layout on mobile
- **Simplified Charts**: Charts optimized for small screen viewing
- **Condensed Tables**: Tables adapt to mobile with horizontal scrolling

#### Mobile Performance
- **Optimized Loading**: Faster loading times on mobile networks
- **Reduced Data Usage**: Minimized data transfer for mobile connections
- **Offline Support**: Basic functionality available offline
- **Background Updates**: Efficient background data updates

### Accessing on Mobile Devices

#### Step 1: Connect to Network
- Ensure your mobile device is connected to the same network as the dashboard server
- For remote access, configure VPN or port forwarding as needed

#### Step 2: Open Browser
- Open any modern web browser (Chrome, Safari, Firefox, Edge)
- Enter the dashboard URL: `http://[SERVER_IP]:8080`

#### Step 3: Login
- Enter your credentials
- The interface will automatically adapt to your screen size

#### Step 4: Navigate
- Use the hamburger menu (☰) to access navigation
- Swipe left/right to navigate between sections
- Use pull-to-refresh to update data

### Mobile Limitations

#### Reduced Functionality
- **Limited Screen Space**: Some complex visualizations may be simplified
- **Touch Limitations**: Precise interactions may be challenging
- **Performance**: Some real-time updates may be less frequent
- **Battery Usage**: Continuous monitoring may impact battery life

#### Recommended Usage
- **Monitoring**: Ideal for quick status checks and alert monitoring
- **Incident Response**: Suitable for basic incident management
- **Configuration**: Limited configuration changes recommended
- **Detailed Analysis**: Better suited for desktop/laptop

---

## 12. Dashboard Troubleshooting

### Common Dashboard Issues

#### Problem: Dashboard Won't Load

**Symptoms:**
- Blank page or error message
- Connection timeout
- "Server not found" error

**Solutions:**

1. **Check Dashboard Service**
   ```bash
   cd ~/aegis-security-suite/src/dashboard
   ./start-dashboard.sh status
   ```

2. **Restart Dashboard Service**
   ```bash
   ./start-dashboard.sh restart
   ```

3. **Check Port Availability**
   ```bash
   netstat -tlnp | grep 8080
   ```

4. **Check Firewall Settings**
   ```bash
   sudo ufw status
   sudo ufw allow 8080/tcp
   ```

#### Problem: Login Issues

**Symptoms:**
- Invalid credentials error
- Login page not responding
- Authentication errors

**Solutions:**

1. **Reset Admin Password**
   ```bash
   cd ~/aegis-security-suite/src/dashboard
   python3 -c "
   from auth import hash_password, update_password
   import sqlite3
   
   hashed_password = hash_password('aegis123')
   conn = sqlite3.connect('auth.db')
   cursor = conn.cursor()
   cursor.execute('UPDATE users SET password = ? WHERE username = ?', (hashed_password, 'admin'))
   conn.commit()
   conn.close()
   print('Password reset to aegis123')
   "
   ```

2. **Check Authentication Database**
   ```bash
   ls -la ~/aegis-security-suite/src/dashboard/auth.db
   sqlite3 ~/aegis-security-suite/src/dashboard/auth.db "SELECT * FROM users;"
   ```

3. **Clear Browser Cache**
   - Clear browser cookies and cache
   - Try in incognito/private mode

#### Problem: Real-time Updates Not Working

**Symptoms:**
- Data not updating automatically
- WebSocket connection errors
- "Disconnected" status indicator

**Solutions:**

1. **Check WebSocket Connection**
   - Open browser developer tools
   - Check console for WebSocket errors
   - Look for connection status messages

2. **Restart Dashboard Service**
   ```bash
   cd ~/aegis-security-suite/src/dashboard
   ./start-dashboard.sh restart
   ```

3. **Check Network Connectivity**
   ```bash
   ping -c 3 localhost
   netstat -tlnp | grep 8080
   ```

#### Problem: Slow Dashboard Performance

**Symptoms:**
- Slow page loading
- Laggy interface
- High resource usage

**Solutions:**

1. **Check System Resources**
   ```bash
   top -p $(pgrep -f python3)
   free -h
   df -h
   ```

2. **Optimize Database**
   ```bash
   cd ~/aegis-security-suite/configs/behavioral_analysis
   sqlite3 behavioral_data.db "VACUUM;"
   sqlite3 behavioral_data.db "ANALYZE;"
   ```

3. **Clean Up Old Data**
   ```bash
   # Clean up old behavioral data
   sqlite3 ~/aegis-security-suite/configs/behavioral_analysis/behavioral_data.db "DELETE FROM system_metrics WHERE timestamp < datetime('now', '-30 days');"
   ```

### Advanced Troubleshooting

#### Debug Mode

Enable debug mode for detailed error information:

```bash
cd ~/aegis-security-suite/src/dashboard
export FLASK_ENV=development
export FLASK_DEBUG=1
python3 app.py
```

#### Log Analysis

Check dashboard logs for errors:

```bash
cd ~/aegis-security-suite/src/dashboard
tail -n 100 dashboard.log
grep -i error dashboard.log
```

#### Database Diagnostics

Check database integrity:

```bash
# Check behavioral analysis database
sqlite3 ~/aegis-security-suite/configs/behavioral_analysis/behavioral_data.db "PRAGMA integrity_check;"

# Check incident response database
sqlite3 ~/aegis-security-suite/configs/incident_response/incidents.db "PRAGMA integrity_check;"

# Check authentication database
sqlite3 ~/aegis-security-suite/src/dashboard/auth.db "PRAGMA integrity_check;"
```

### Getting Help

If you continue to experience issues:

1. **Check Documentation**
   - [Quick Start Guide](QUICK_START.md)
   - [Troubleshooting Guide](TROUBLESHOOTING.md)
   - [User Guide](USER_GUIDE.md)

2. **Check Logs**
   - Dashboard logs: `~/aegis-security-suite/src/dashboard/dashboard.log`
   - System logs: `journalctl --user -u security-*`
   - Application logs: `~/aegis-security-suite/logs/`

3. **Report Issues**
   - GitHub Issues: [Report a problem](https://github.com/YahyaZekry/aegis-security-suite/issues)
   - Include error messages, logs, and system information

---

## 🎯 Quick Reference

### Essential Commands

```bash
# Start dashboard
cd ~/aegis-security-suite
./src/core/scripts/start-aegis.sh start web-dashboard

# Check status
./src/core/scripts/start-aegis.sh status

# Access dashboard
http://localhost:8080
# or
http://[SERVER_IP]:8080

# Default credentials
Username: admin
Password: aegis123

# Reset password
cd ~/aegis-security-suite/src/dashboard
python3 -c "
from auth import hash_password, update_password
import sqlite3
hashed_password = hash_password('new_password')
conn = sqlite3.connect('auth.db')
cursor = conn.cursor()
cursor.execute('UPDATE users SET password = ? WHERE username = ?', (hashed_password, 'admin'))
conn.commit()
conn.close()
"
```

### Dashboard URLs

- **Main Dashboard**: `http://localhost:8080/`
- **Login Page**: `http://localhost:8080/login`
- **API Status**: `http://localhost:8080/api/system/status`
- **Behavioral Analysis**: `http://localhost:8080/behavioral`
- **Threat Intelligence**: `http://localhost:8080/threats`
- **Incident Response**: `http://localhost:8080/incidents`
- **Configuration**: `http://localhost:8080/config`

### Emergency Procedures

```bash
# Emergency restart
cd ~/aegis-security-suite
./src/core/scripts/start-aegis.sh restart all

# Emergency status check
./src/core/scripts/start-aegis.sh status

# Emergency log check
tail -n 50 ~/aegis-security-suite/src/dashboard/dashboard.log
```

---

## 🎉 Dashboard Access Complete!

You now have comprehensive knowledge of accessing and using the Aegis Security Dashboard. The dashboard provides a powerful, user-friendly interface for monitoring and managing your security suite.

**Remember to:**
- Change default passwords immediately
- Keep your browser updated
- Monitor dashboard performance
- Report issues promptly

**Stay secure and keep monitoring! 🖥️🛡️**