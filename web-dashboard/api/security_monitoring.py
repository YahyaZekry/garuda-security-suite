#!/usr/bin/env python3
"""
Security Monitoring Module for Aegis Security Suite Dashboard
Provides real-time security monitoring, alerts, and automated scanning
"""

import os
import json
import sqlite3
import threading
import time
from datetime import datetime, timedelta
from flask import Blueprint, jsonify, request, g
from typing import Dict, List, Optional

# Import security utilities
from security_utils import (
    SecurityLogger, InputValidator, rate_limiter,
    require_api_key, rate_limit, validate_input, secure_headers
)
from auth import require_auth, require_role

# Create Blueprint
security_monitoring_bp = Blueprint('security_monitoring', __name__, url_prefix='/api/security')

# Global variables for monitoring
monitoring_active = False
monitoring_thread = None
last_scan_time = None

class SecurityScanner:
    """Automated security scanner for the dashboard"""
    
    def __init__(self, db_path: str):
        self.db_path = db_path
        self.ensure_db()
    
    def ensure_db(self):
        """Ensure security monitoring database exists"""
        os.makedirs(os.path.dirname(self.db_path), exist_ok=True)
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Security events table
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS security_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            event_type TEXT NOT NULL,
            severity TEXT NOT NULL,
            title TEXT NOT NULL,
            description TEXT,
            source_ip TEXT,
            target TEXT,
            timestamp TEXT NOT NULL,
            resolved BOOLEAN DEFAULT 0,
            resolved_by TEXT,
            resolved_at TEXT,
            details TEXT
        )
        """)
        
        # Security alerts table
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS security_alerts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            alert_type TEXT NOT NULL,
            severity TEXT NOT NULL,
            title TEXT NOT NULL,
            message TEXT NOT NULL,
            source_ip TEXT,
            user_id INTEGER,
            timestamp TEXT NOT NULL,
            acknowledged BOOLEAN DEFAULT 0,
            acknowledged_by TEXT,
            acknowledged_at TEXT,
            auto_resolved BOOLEAN DEFAULT 0
        )
        """)
        
        # Scan results table
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS security_scans (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            scan_type TEXT NOT NULL,
            status TEXT NOT NULL,
            started_at TEXT NOT NULL,
            completed_at TEXT,
            findings_count INTEGER DEFAULT 0,
            high_risk_count INTEGER DEFAULT 0,
            medium_risk_count INTEGER DEFAULT 0,
            low_risk_count INTEGER DEFAULT 0,
            scan_results TEXT
        )
        """)
        
        # Security metrics table
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS security_metrics (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            metric_type TEXT NOT NULL,
            metric_value REAL NOT NULL,
            timestamp TEXT NOT NULL,
            additional_data TEXT
        )
        """)
        
        # Create indexes
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_security_events_timestamp ON security_events(timestamp)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_security_alerts_timestamp ON security_alerts(timestamp)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_security_scans_started_at ON security_scans(started_at)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_security_metrics_timestamp ON security_metrics(timestamp)")
        
        conn.commit()
        conn.close()
    
    def log_security_event(self, event_type: str, severity: str, title: str, 
                          description: str = None, source_ip: str = None, 
                          target: str = None, details: Dict = None):
        """Log a security event"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
        INSERT INTO security_events (event_type, severity, title, description, source_ip, target, timestamp, details)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, (event_type, severity, title, description, source_ip, target, 
               datetime.now().isoformat(), json.dumps(details) if details else None))
        
        conn.commit()
        conn.close()
    
    def create_security_alert(self, alert_type: str, severity: str, title: str, 
                           message: str, source_ip: str = None, user_id: int = None):
        """Create a security alert"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
        INSERT INTO security_alerts (alert_type, severity, title, message, source_ip, user_id, timestamp)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (alert_type, severity, title, message, source_ip, user_id, datetime.now().isoformat()))
        
        conn.commit()
        conn.close()
        
        # Log to security logger as well
        SecurityLogger.log_security_event(f'security_alert_{alert_type}', {
            'title': title,
            'message': message,
            'source_ip': source_ip,
            'user_id': user_id,
            'severity': severity
        }, severity.upper())
    
    def start_security_scan(self, scan_type: str) -> Dict:
        """Start a security scan"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
        INSERT INTO security_scans (scan_type, status, started_at)
        VALUES (?, 'running', ?)
        """, (scan_type, datetime.now().isoformat()))
        
        scan_id = cursor.lastrowid
        conn.commit()
        conn.close()
        
        return {'success': True, 'scan_id': scan_id, 'status': 'running'}
    
    def complete_security_scan(self, scan_id: int, findings: List[Dict]) -> Dict:
        """Complete a security scan with findings"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Categorize findings by risk
        high_risk = len([f for f in findings if f.get('risk_level') == 'high'])
        medium_risk = len([f for f in findings if f.get('risk_level') == 'medium'])
        low_risk = len([f for f in findings if f.get('risk_level') == 'low'])
        
        cursor.execute("""
        UPDATE security_scans 
        SET status = 'completed', completed_at = ?, findings_count = ?, 
            high_risk_count = ?, medium_risk_count = ?, low_risk_count = ?, scan_results = ?
        WHERE id = ?
        """, (datetime.now().isoformat(), len(findings), high_risk, medium_risk, 
               low_risk, json.dumps(findings), scan_id))
        
        conn.commit()
        conn.close()
        
        # Create alerts for high-risk findings
        for finding in findings:
            if finding.get('risk_level') == 'high':
                self.create_security_alert(
                    'scan_finding',
                    'high',
                    f"High Risk Security Finding: {finding.get('title', 'Unknown')}",
                    finding.get('description', 'No description available')
                )
        
        return {
            'success': True,
            'scan_id': scan_id,
            'findings_count': len(findings),
            'high_risk_count': high_risk,
            'medium_risk_count': medium_risk,
            'low_risk_count': low_risk
        }
    
    def get_security_events(self, limit: int = 100, severity: str = None) -> Dict:
        """Get security events"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        query = """
        SELECT id, event_type, severity, title, description, source_ip, target, 
               timestamp, resolved, resolved_by, resolved_at
        FROM security_events
        """
        params = []
        
        if severity:
            query += " WHERE severity = ?"
            params.append(severity)
        
        query += " ORDER BY timestamp DESC LIMIT ?"
        params.append(limit)
        
        cursor.execute(query, params)
        
        events = []
        for row in cursor.fetchall():
            events.append({
                'id': row[0],
                'event_type': row[1],
                'severity': row[2],
                'title': row[3],
                'description': row[4],
                'source_ip': row[5],
                'target': row[6],
                'timestamp': row[7],
                'resolved': bool(row[8]),
                'resolved_by': row[9],
                'resolved_at': row[10]
            })
        
        conn.close()
        
        return {'events': events, 'total': len(events)}
    
    def get_security_alerts(self, limit: int = 50, acknowledged: bool = None) -> Dict:
        """Get security alerts"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        query = """
        SELECT id, alert_type, severity, title, message, source_ip, user_id,
               timestamp, acknowledged, acknowledged_by, acknowledged_at
        FROM security_alerts
        """
        params = []
        
        if acknowledged is not None:
            query += " WHERE acknowledged = ?"
            params.append(acknowledged)
        
        query += " ORDER BY timestamp DESC LIMIT ?"
        params.append(limit)
        
        cursor.execute(query, params)
        
        alerts = []
        for row in cursor.fetchall():
            alerts.append({
                'id': row[0],
                'alert_type': row[1],
                'severity': row[2],
                'title': row[3],
                'message': row[4],
                'source_ip': row[5],
                'user_id': row[6],
                'timestamp': row[7],
                'acknowledged': bool(row[8]),
                'acknowledged_by': row[9],
                'acknowledged_at': row[10]
            })
        
        conn.close()
        
        return {'alerts': alerts, 'total': len(alerts)}
    
    def get_scan_results(self, limit: int = 20) -> Dict:
        """Get security scan results"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
        SELECT id, scan_type, status, started_at, completed_at, findings_count,
               high_risk_count, medium_risk_count, low_risk_count
        FROM security_scans
        ORDER BY started_at DESC LIMIT ?
        """, (limit,))
        
        scans = []
        for row in cursor.fetchall():
            scans.append({
                'id': row[0],
                'scan_type': row[1],
                'status': row[2],
                'started_at': row[3],
                'completed_at': row[4],
                'findings_count': row[5],
                'high_risk_count': row[6],
                'medium_risk_count': row[7],
                'low_risk_count': row[8]
            })
        
        conn.close()
        
        return {'scans': scans, 'total': len(scans)}
    
    def get_security_metrics(self, hours: int = 24) -> Dict:
        """Get security metrics for the specified time period"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        since_time = (datetime.now() - timedelta(hours=hours)).isoformat()
        
        cursor.execute("""
        SELECT metric_type, metric_value, timestamp, additional_data
        FROM security_metrics
        WHERE timestamp > ?
        ORDER BY timestamp DESC
        """, (since_time,))
        
        metrics = []
        for row in cursor.fetchall():
            metrics.append({
                'metric_type': row[0],
                'metric_value': row[1],
                'timestamp': row[2],
                'additional_data': json.loads(row[3]) if row[3] else None
            })
        
        conn.close()
        
        return {'metrics': metrics, 'timeframe_hours': hours}

# Initialize security scanner
SECURITY_MONITORING_DB = os.path.join(os.environ.get('AEGIS_HOME', '/opt/aegis-security-suite'), 'configs', 'web-dashboard', 'security_monitoring.db')
security_scanner = SecurityScanner(SECURITY_MONITORING_DB)

def run_automated_security_scan():
    """Run automated security scan"""
    try:
        # Start vulnerability scan
        scan_result = security_scanner.start_security_scan('automated_vulnerability')
        scan_id = scan_result['scan_id']
        
        findings = []
        
        # Check for common security issues
        findings.extend(check_session_security())
        findings.extend(check_api_key_security())
        findings.extend(check_authentication_security())
        findings.extend(check_input_validation())
        findings.extend(check_security_headers())
        
        # Complete the scan
        security_scanner.complete_security_scan(scan_id, findings)
        
        # Log metrics
        security_scanner.log_security_event(
            'automated_scan_completed',
            'info',
            'Automated Security Scan Completed',
            f"Scan completed with {len(findings)} findings",
            details={'findings_count': len(findings)}
        )
        
    except Exception as e:
        SecurityLogger.log_security_event('automated_scan_error', {
            'error': str(e)
        }, 'ERROR')

def check_session_security() -> List[Dict]:
    """Check for session security issues"""
    findings = []
    
    try:
        from auth import AUTH_DB_PATH
        
        if os.path.exists(AUTH_DB_PATH):
            conn = sqlite3.connect(AUTH_DB_PATH)
            cursor = conn.cursor()
            
            # Check for sessions older than 24 hours
            cursor.execute("""
            SELECT COUNT(*) FROM user_sessions 
            WHERE created_at < datetime('now', '-24 hours') AND is_active = 1
            """)
            
            old_sessions = cursor.fetchone()[0]
            if old_sessions > 0:
                findings.append({
                    'title': 'Long-lived Sessions',
                    'description': f'Found {old_sessions} sessions older than 24 hours',
                    'risk_level': 'medium',
                    'recommendation': 'Consider implementing shorter session timeouts'
                })
            
            # Check for sessions from multiple IPs for same user
            cursor.execute("""
            SELECT user_id, COUNT(DISTINCT ip_address) as ip_count
            FROM user_sessions 
            WHERE is_active = 1 AND created_at > datetime('now', '-1 hour')
            GROUP BY user_id
            HAVING ip_count > 1
            """)
            
            multi_ip_sessions = cursor.fetchall()
            if multi_ip_sessions:
                findings.append({
                    'title': 'Multiple IP Sessions',
                    'description': f'Found {len(multi_ip_sessions)} users with sessions from multiple IPs',
                    'risk_level': 'high',
                    'recommendation': 'Review for potential session hijacking'
                })
            
            conn.close()
            
    except Exception as e:
        SecurityLogger.log_security_event('session_security_check_error', {
            'error': str(e)
        }, 'ERROR')
    
    return findings

def check_api_key_security() -> List[Dict]:
    """Check for API key security issues"""
    findings = []
    
    try:
        from security_utils import API_KEY_DB
        
        if os.path.exists(API_KEY_DB):
            conn = sqlite3.connect(API_KEY_DB)
            cursor = conn.cursor()
            
            # Check for API keys without expiration
            cursor.execute("""
            SELECT COUNT(*) FROM api_keys 
            WHERE is_active = 1 AND (expires_at IS NULL OR expires_at = '')
            """)
            
            non_expiring_keys = cursor.fetchone()[0]
            if non_expiring_keys > 0:
                findings.append({
                    'title': 'API Keys Without Expiration',
                    'description': f'Found {non_expiring_keys} API keys without expiration',
                    'risk_level': 'high',
                    'recommendation': 'Set expiration dates for all API keys'
                })
            
            # Check for API keys with high usage
            cursor.execute("""
            SELECT COUNT(*) FROM api_keys 
            WHERE is_active = 1 AND usage_count > 1000
            """)
            
            high_usage_keys = cursor.fetchone()[0]
            if high_usage_keys > 0:
                findings.append({
                    'title': 'High Usage API Keys',
                    'description': f'Found {high_usage_keys} API keys with usage > 1000',
                    'risk_level': 'medium',
                    'recommendation': 'Review high usage API keys for rotation'
                })
            
            conn.close()
            
    except Exception as e:
        SecurityLogger.log_security_event('api_key_security_check_error', {
            'error': str(e)
        }, 'ERROR')
    
    return findings

def check_authentication_security() -> List[Dict]:
    """Check for authentication security issues"""
    findings = []
    
    try:
        from auth import AUTH_DB_PATH
        
        if os.path.exists(AUTH_DB_PATH):
            conn = sqlite3.connect(AUTH_DB_PATH)
            cursor = conn.cursor()
            
            # Check for users with weak passwords
            cursor.execute("""
            SELECT COUNT(*) FROM users 
            WHERE password_changed_at < datetime('now', '-90 days')
            """)
            
            old_passwords = cursor.fetchone()[0]
            if old_passwords > 0:
                findings.append({
                    'title': 'Old Passwords',
                    'description': f'Found {old_passwords} users with passwords older than 90 days',
                    'risk_level': 'medium',
                    'recommendation': 'Enforce regular password changes'
                })
            
            # Check for users without MFA
            cursor.execute("""
            SELECT COUNT(*) FROM users 
            WHERE is_active = 1 AND two_factor_enabled = 0 AND role = 'admin'
            """)
            
            admin_no_mfa = cursor.fetchone()[0]
            if admin_no_mfa > 0:
                findings.append({
                    'title': 'Admin Users Without MFA',
                    'description': f'Found {admin_no_mfa} admin users without MFA',
                    'risk_level': 'high',
                    'recommendation': 'Enable MFA for all admin users'
                })
            
            conn.close()
            
    except Exception as e:
        SecurityLogger.log_security_event('auth_security_check_error', {
            'error': str(e)
        }, 'ERROR')
    
    return findings

def check_input_validation() -> List[Dict]:
    """Check for input validation issues"""
    findings = []
    
    # This would typically involve checking application code
    # For now, we'll add a placeholder finding
    findings.append({
        'title': 'Input Validation Review',
        'description': 'Regular review of input validation recommended',
        'risk_level': 'low',
        'recommendation': 'Conduct regular input validation audits'
    })
    
    return findings

def check_security_headers() -> List[Dict]:
    """Check for security header issues"""
    findings = []
    
    # This would typically involve checking HTTP responses
    # For now, we'll add a placeholder finding
    findings.append({
        'title': 'Security Headers Review',
        'description': 'Regular review of security headers recommended',
        'risk_level': 'low',
        'recommendation': 'Conduct regular security header audits'
    })
    
    return findings

# API Routes
@security_monitoring_bp.route('/events', methods=['GET'])
@require_auth
@require_role('admin')
@rate_limit(limit=10, window=60)
def get_security_events():
    """Get security events"""
    try:
        limit = request.args.get('limit', 100, type=int)
        severity = request.args.get('severity')
        
        result = security_scanner.get_security_events(limit, severity)
        
        SecurityLogger.log_security_event('security_events_accessed', {
            'user_id': g.current_user.get('user_id'),
            'username': g.current_user.get('username'),
            'ip_address': request.remote_addr
        })
        
        return jsonify(result)
        
    except Exception as e:
        SecurityLogger.log_security_event('security_events_error', {
            'user_id': g.current_user.get('user_id'),
            'error': str(e)
        }, 'ERROR')
        return jsonify({'error': 'Internal server error'}), 500

@security_monitoring_bp.route('/alerts', methods=['GET'])
@require_auth
@require_role('admin')
@rate_limit(limit=10, window=60)
def get_security_alerts():
    """Get security alerts"""
    try:
        limit = request.args.get('limit', 50, type=int)
        acknowledged = request.args.get('acknowledged')
        
        if acknowledged is not None:
            acknowledged = acknowledged.lower() == 'true'
        
        result = security_scanner.get_security_alerts(limit, acknowledged)
        
        SecurityLogger.log_security_event('security_alerts_accessed', {
            'user_id': g.current_user.get('user_id'),
            'username': g.current_user.get('username'),
            'ip_address': request.remote_addr
        })
        
        return jsonify(result)
        
    except Exception as e:
        SecurityLogger.log_security_event('security_alerts_error', {
            'user_id': g.current_user.get('user_id'),
            'error': str(e)
        }, 'ERROR')
        return jsonify({'error': 'Internal server error'}), 500

@security_monitoring_bp.route('/alerts/<int:alert_id>/acknowledge', methods=['POST'])
@require_auth
@require_role('admin')
@rate_limit(limit=20, window=60)
def acknowledge_alert(alert_id):
    """Acknowledge a security alert"""
    try:
        conn = sqlite3.connect(SECURITY_MONITORING_DB)
        cursor = conn.cursor()
        
        cursor.execute("""
        UPDATE security_alerts 
        SET acknowledged = 1, acknowledged_by = ?, acknowledged_at = ?
        WHERE id = ?
        """, (g.current_user.get('username'), datetime.now().isoformat(), alert_id))
        
        affected_rows = cursor.rowcount
        conn.commit()
        conn.close()
        
        if affected_rows > 0:
            SecurityLogger.log_security_event('security_alert_acknowledged', {
                'user_id': g.current_user.get('user_id'),
                'username': g.current_user.get('username'),
                'alert_id': alert_id,
                'ip_address': request.remote_addr
            })
            
            return jsonify({'success': True, 'message': 'Alert acknowledged'})
        else:
            return jsonify({'success': False, 'error': 'Alert not found'}), 404
            
    except Exception as e:
        SecurityLogger.log_security_event('alert_acknowledge_error', {
            'user_id': g.current_user.get('user_id'),
            'alert_id': alert_id,
            'error': str(e)
        }, 'ERROR')
        return jsonify({'error': 'Internal server error'}), 500

@security_monitoring_bp.route('/scans', methods=['GET'])
@require_auth
@require_role('admin')
@rate_limit(limit=10, window=60)
def get_scan_results():
    """Get security scan results"""
    try:
        limit = request.args.get('limit', 20, type=int)
        
        result = security_scanner.get_scan_results(limit)
        
        SecurityLogger.log_security_event('scan_results_accessed', {
            'user_id': g.current_user.get('user_id'),
            'username': g.current_user.get('username'),
            'ip_address': request.remote_addr
        })
        
        return jsonify(result)
        
    except Exception as e:
        SecurityLogger.log_security_event('scan_results_error', {
            'user_id': g.current_user.get('user_id'),
            'error': str(e)
        }, 'ERROR')
        return jsonify({'error': 'Internal server error'}), 500

@security_monitoring_bp.route('/scans/start', methods=['POST'])
@require_auth
@require_role('admin')
@rate_limit(limit=5, window=300)
def start_security_scan():
    """Start a security scan"""
    try:
        scan_type = request.json.get('scan_type', 'automated_vulnerability')
        
        result = security_scanner.start_security_scan(scan_type)
        
        SecurityLogger.log_security_event('security_scan_started', {
            'user_id': g.current_user.get('user_id'),
            'username': g.current_user.get('username'),
            'scan_type': scan_type,
            'ip_address': request.remote_addr
        })
        
        return jsonify(result), 201
        
    except Exception as e:
        SecurityLogger.log_security_event('scan_start_error', {
            'user_id': g.current_user.get('user_id'),
            'error': str(e)
        }, 'ERROR')
        return jsonify({'error': 'Internal server error'}), 500

@security_monitoring_bp.route('/metrics', methods=['GET'])
@require_auth
@require_role('admin')
@rate_limit(limit=10, window=60)
def get_security_metrics():
    """Get security metrics"""
    try:
        hours = request.args.get('hours', 24, type=int)
        
        result = security_scanner.get_security_metrics(hours)
        
        SecurityLogger.log_security_event('security_metrics_accessed', {
            'user_id': g.current_user.get('user_id'),
            'username': g.current_user.get('username'),
            'ip_address': request.remote_addr
        })
        
        return jsonify(result)
        
    except Exception as e:
        SecurityLogger.log_security_event('security_metrics_error', {
            'user_id': g.current_user.get('user_id'),
            'error': str(e)
        }, 'ERROR')
        return jsonify({'error': 'Internal server error'}), 500

@security_monitoring_bp.route('/dashboard', methods=['GET'])
@require_auth
@require_role('admin')
@rate_limit(limit=5, window=60)
def get_security_dashboard():
    """Get security dashboard data"""
    try:
        # Get recent events
        events_result = security_scanner.get_security_events(10)
        
        # Get unacknowledged alerts
        alerts_result = security_scanner.get_security_alerts(10, acknowledged=False)
        
        # Get recent scans
        scans_result = security_scanner.get_scan_results(5)
        
        # Get metrics for last 24 hours
        metrics_result = security_scanner.get_security_metrics(24)
        
        dashboard_data = {
            'recent_events': events_result['events'],
            'unacknowledged_alerts': alerts_result['alerts'],
            'recent_scans': scans_result['scans'],
            'metrics': metrics_result['metrics'],
            'summary': {
                'total_events': len(events_result['events']),
                'unacknowledged_alerts_count': len(alerts_result['alerts']),
                'recent_scans_count': len(scans_result['scans']),
                'high_risk_findings': sum(scan['high_risk_count'] for scan in scans_result['scans'])
            },
            'timestamp': datetime.now().isoformat()
        }
        
        SecurityLogger.log_security_event('security_dashboard_accessed', {
            'user_id': g.current_user.get('user_id'),
            'username': g.current_user.get('username'),
            'ip_address': request.remote_addr
        })
        
        return jsonify(dashboard_data)
        
    except Exception as e:
        SecurityLogger.log_security_event('security_dashboard_error', {
            'user_id': g.current_user.get('user_id'),
            'error': str(e)
        }, 'ERROR')
        return jsonify({'error': 'Internal server error'}), 500

def start_background_monitoring():
    """Start background security monitoring"""
    global monitoring_active, monitoring_thread
    
    if monitoring_active:
        return
    
    monitoring_active = True
    
    def monitoring_loop():
        while monitoring_active:
            try:
                # Run automated scan every hour
                run_automated_security_scan()
                
                # Sleep for 1 hour
                for _ in range(3600):  # 3600 seconds = 1 hour
                    if not monitoring_active:
                        break
                    time.sleep(1)
                    
            except Exception as e:
                SecurityLogger.log_security_event('background_monitoring_error', {
                    'error': str(e)
                }, 'ERROR')
                time.sleep(300)  # Wait 5 minutes before retrying
    
    monitoring_thread = threading.Thread(target=monitoring_loop, daemon=True)
    monitoring_thread.start()
    
    SecurityLogger.log_security_event('background_monitoring_started', {
        'timestamp': datetime.now().isoformat()
    })

def stop_background_monitoring():
    """Stop background security monitoring"""
    global monitoring_active
    monitoring_active = False
    
    SecurityLogger.log_security_event('background_monitoring_stopped', {
        'timestamp': datetime.now().isoformat()
    })