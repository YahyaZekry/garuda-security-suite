# Aegis Security Suite Web Dashboard

A comprehensive web-based interface for monitoring and managing the Aegis Security Suite. This dashboard provides real-time security monitoring, behavioral analysis visualization, threat intelligence management, and incident response capabilities.

## Features

### 🎯 Main Dashboard
- **System Overview**: Real-time CPU, memory, and disk usage monitoring
- **Security Status**: Current threat level and system health indicators
- **Recent Alerts**: Latest security events and notifications
- **Quick Actions**: One-click security scans and monitoring controls

### 📊 Behavioral Analysis
- **Real-time Monitoring**: Live system metrics and anomaly detection
- **Threat Score Visualization**: Interactive charts showing threat trends
- **Baseline Management**: Create and manage behavioral baselines
- **Anomaly Detection**: View and respond to detected anomalies

### 🛡️ Threat Intelligence
- **IOC Database**: Search and manage indicators of compromise
- **Threat Feeds**: Monitor and update threat intelligence sources
- **IOC Statistics**: Visual representation of threat data
- **Import/Export**: Manage IOCs in multiple formats

### 🚨 Incident Management
- **Incident Tracking**: Create, update, and resolve security incidents
- **Evidence Collection**: Automated evidence gathering for incidents
- **Incident Timeline**: Visual timeline of incident events
- **Response Actions**: Quick access to incident response tools

### ⚙️ System Configuration
- **Security Settings**: Configure all security suite components
- **Monitoring Preferences**: Customize behavioral analysis parameters
- **Notification Settings**: Manage alerts and notifications
- **System Scheduling**: Configure automated tasks and scans

## Installation

### Prerequisites
- Python 3.8 or higher
- Aegis Security Suite installed
- System privileges for security operations

### Quick Start

1. **Navigate to the dashboard directory:**
   ```bash
   cd \$AEGIS_HOME/web-dashboard
   ```

2. **Make the startup script executable:**
   ```bash
   chmod +x start-dashboard.sh
   ```

3. **Start the dashboard:**
   ```bash
   ./start-dashboard.sh start
   ```

4. **Access the dashboard:**
   Open your web browser and navigate to `http://localhost:8080`

### Manual Installation

1. **Install Python dependencies:**
   ```bash
   pip3 install -r requirements.txt
   ```

2. **Set up environment:**
   ```bash
   export AEGIS_HOME=\${AEGIS_HOME:-$HOME/aegis-security-suite}
   export FLASK_APP=app.py
   ```

3. **Start the application:**
   ```bash
   python3 app.py
   ```

## Configuration

The dashboard configuration is stored in `src/dashboard/config/dashboard.conf`. Key settings include:

### Basic Settings
- `host`: Server host address (default: 0.0.0.0)
- `port`: Server port (default: 8080)
- `debug`: Enable debug mode (default: false)

### Security Settings
- `enable_auth`: Enable authentication (default: true)
- `session_timeout`: Session timeout in seconds (default: 3600)
- `max_login_attempts`: Maximum login attempts (default: 5)

### Monitoring Settings
- `monitoring_interval`: Real-time update interval in seconds (default: 5)
- `alert_threshold_cpu`: CPU alert threshold (default: 80)
- `alert_threshold_memory`: Memory alert threshold (default: 85)

## Usage

### Authentication
- **Default Credentials**: admin / admin
- **System Authentication**: Can use system user credentials
- **Session Management**: Secure session handling with timeout

### Dashboard Navigation
- **Sidebar Navigation**: Easy access to all sections
- **Real-time Updates**: Live data via WebSocket connections
- **Responsive Design**: Works on desktop and mobile devices

### Real-time Monitoring
- **Start/Stop**: Toggle real-time monitoring
- **Auto-refresh**: Configurable update intervals
- **Alerts**: Real-time threat and system alerts

## API Endpoints

The dashboard provides RESTful API endpoints for integration:

### System APIs
- `GET /api/system/status` - System status and metrics
- `GET /api/system/info` - Detailed system information
- `GET /api/system/processes` - Running processes
- `GET /api/system/network` - Network information

### Behavioral Analysis APIs
- `GET /api/behavioral/metrics` - Behavioral metrics
- `GET /api/behavioral/anomalies` - Detected anomalies
- `POST /api/behavioral/baseline/create` - Create baseline
- `POST /api/behavioral/monitoring/start` - Start monitoring

### Threat Intelligence APIs
- `GET /api/threats/iocs` - IOC database
- `POST /api/threats/iocs` - Add new IOC
- `GET /api/threats/feeds` - Threat feed status
- `POST /api/threats/feeds/update` - Update threat feeds

### Incident Management APIs
- `GET /api/incidents` - List incidents
- `POST /api/incidents` - Create incident
- `PUT /api/incidents/<id>` - Update incident
- `POST /api/incidents/<id>/evidence` - Collect evidence

## Security Features

### Authentication & Authorization
- Session-based authentication
- Secure password handling
- Login attempt limiting
- Session timeout management

### Data Protection
- HTTPS support (configurable)
- CSRF protection
- Input validation and sanitization
- Secure session management

### Access Control
- Role-based access control (configurable)
- API rate limiting
- Secure API endpoints
- Audit logging

## Integration

### Security Suite Components
- **Behavioral Analysis**: Integrates with behavioral monitoring
- **Threat Intelligence**: Connects to IOC database and feeds
- **Incident Response**: Manages security incidents
- **Security Scanners**: Triggers and monitors scans

### External Systems
- **SIEM Integration**: Export events to SIEM systems
- **API Access**: RESTful API for third-party integration
- **Webhook Support**: Real-time event notifications
- **Data Export**: Multiple export formats (JSON, CSV, PDF)

## Troubleshooting

### Common Issues

1. **Dashboard won't start:**
   - Check Python dependencies: `pip3 list`
   - Verify security suite installation
   - Check system permissions

2. **Authentication failures:**
   - Verify user credentials
   - Check session configuration
   - Review security settings

3. **Real-time updates not working:**
   - Check WebSocket connection
   - Verify browser compatibility
   - Check network connectivity

4. **API errors:**
   - Check API endpoint permissions
   - Verify request format
   - Review server logs

### Logs

- **Application Log**: `$AEGIS_HOME/logs/web-dashboard.log`
- **Startup Log**: `/tmp/aegis-dashboard-startup.log`
- **Security Suite Logs**: `$AEGIS_HOME/logs/`

### Debug Mode

Enable debug mode for troubleshooting:
```bash
./start-dashboard.sh --debug
```

Or modify `config/dashboard.conf`:
```ini
[dashboard]
debug = true
```

## Development

### Project Structure
```
src/dashboard/
├── app.py                 # Main Flask application
├── requirements.txt        # Python dependencies
├── start-dashboard.sh     # Startup script
├── config/
│   └── dashboard.conf     # Configuration file
├── templates/            # HTML templates
├── static/
│   ├── css/            # Stylesheets
│   ├── js/             # JavaScript files
│   └── images/         # Image assets
└── api/                # API modules
    ├── system.py        # System APIs
    ├── behavioral.py    # Behavioral analysis APIs
    ├── threats.py       # Threat intelligence APIs
    └── incidents.py    # Incident management APIs
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

### Code Style

- Follow PEP 8 Python style guide
- Use meaningful variable names
- Add appropriate comments
- Include error handling
- Write unit tests

## Support

### Documentation
- **User Guide**: See `docs/USER_GUIDE.md`
- **API Documentation**: See `docs/API.md`
- **Security Components**: See `docs/SECURITY_COMPONENTS.md`

### Community
- **Issues**: Report bugs via GitHub issues
- **Features**: Request features via GitHub discussions
- **Security**: Report security issues privately

## License

This project is part of the Aegis Security Suite and follows the same licensing terms.

## Version History

### v1.0.0
- Initial release
- Basic dashboard functionality
- Real-time monitoring
- API endpoints
- Authentication system

---

**Note**: This dashboard is designed to work with the Aegis Security Suite. Ensure the security suite is properly installed and configured before using the dashboard.