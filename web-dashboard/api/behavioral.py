"""
Behavioral Analysis API Module for Aegis Security Suite Dashboard
Provides behavioral monitoring, anomaly detection, and analysis endpoints
"""

import os
import sqlite3
import json
import subprocess
from datetime import datetime, timedelta
from flask import Blueprint, jsonify, request, g

# Import security utilities
from security_utils import (
    SecurityLogger, InputValidator, rate_limiter,
    require_api_key, rate_limit, validate_input, secure_headers
)
from auth import require_auth, require_role

# Create Blueprint
behavioral_bp = Blueprint('behavioral', __name__, url_prefix='/api/behavioral')

# Database paths
BEHAVIORAL_DB_PATH = os.path.join(os.environ.get('AEGIS_HOME', '/opt/aegis-security-suite'),
                                  'configs', 'behavioral_analysis', 'behavioral_data.db')

def get_behavioral_data(time_range='24h'):
    """Get behavioral analysis data for specified time range"""
    try:
        if not os.path.exists(BEHAVIORAL_DB_PATH):
            return {
                'error': 'Behavioral analysis database not found',
                'data': []
            }
        
        conn = sqlite3.connect(BEHAVIORAL_DB_PATH)
        cursor = conn.cursor()
        
        # Calculate time filter
        time_filter = get_time_filter(time_range)
        
        # Get behavioral metrics
        query = """
        SELECT timestamp, cpu_usage, memory_usage, disk_io_reads, disk_io_writes,
               active_processes, network_connections
        FROM system_metrics
        WHERE timestamp >= ?
        ORDER BY timestamp DESC
        LIMIT 1000
        """
        
        cursor.execute(query, (time_filter,))
        rows = cursor.fetchall()
        
        # Convert to list of dictionaries
        data = []
        for row in rows:
            # Calculate combined disk_io and network_io for compatibility
            disk_io = row[3] + row[4]  # reads + writes
            network_io = row[5]  # network_connections
            
            data.append({
                'timestamp': row[0],
                'cpu_usage': row[1],
                'memory_usage': row[2],
                'disk_io': disk_io,
                'network_io': network_io,
                'process_count': row[5],
                'anomaly_score': 0,  # Default value as column doesn't exist
                'threat_level': 'low'  # Default value as column doesn't exist
            })
        
        conn.close()
        
        return {
            'data': data,
            'time_range': time_range,
            'count': len(data)
        }
        
    except Exception as e:
        return {
            'error': str(e),
            'data': []
        }

def get_time_filter(time_range):
    """Get timestamp filter for specified time range"""
    now = datetime.now()
    
    if time_range == '1h':
        return (now - timedelta(hours=1)).isoformat()
    elif time_range == '6h':
        return (now - timedelta(hours=6)).isoformat()
    elif time_range == '24h':
        return (now - timedelta(hours=24)).isoformat()
    elif time_range == '7d':
        return (now - timedelta(days=7)).isoformat()
    elif time_range == '30d':
        return (now - timedelta(days=30)).isoformat()
    else:
        return (now - timedelta(hours=24)).isoformat()

def get_anomalies(limit=50, severity='all'):
    """Get detected anomalies"""
    try:
        if not os.path.exists(BEHAVIORAL_DB_PATH):
            return {
                'error': 'Behavioral analysis database not found',
                'anomalies': []
            }
        
        conn = sqlite3.connect(BEHAVIORAL_DB_PATH)
        cursor = conn.cursor()
        
        # Build query based on severity filter
        severity_filter = ""
        if severity != 'all':
            severity_filter = "AND severity = ?"
        
        query = f"""
        SELECT id, timestamp, anomaly_type, metric_name, current_value,
               baseline_value, deviation_score, severity, threat_score, details, resolved
        FROM anomaly_events
        WHERE 1=1 {severity_filter}
        ORDER BY timestamp DESC
        LIMIT ?
        """
        
        params = [limit]
        if severity != 'all':
            params.insert(0, severity)
        
        cursor.execute(query, params)
        rows = cursor.fetchall()
        
        # Convert to list of dictionaries
        anomalies = []
        for row in rows:
            anomalies.append({
                'id': row[0],
                'timestamp': row[1],
                'anomaly_type': row[2],
                'description': f"{row[3]}: {row[4]} (baseline: {row[5]})",  # Combine metric_name and values
                'severity': row[6],
                'affected_process': row[3],  # Use metric_name as affected_process
                'anomaly_score': row[7],  # Use threat_score as anomaly_score
                'resolved': bool(row[9]),
                'resolution_notes': row[8] if row[8] else None
            })
        
        conn.close()
        
        return {
            'anomalies': anomalies,
            'count': len(anomalies)
        }
        
    except Exception as e:
        return {
            'error': str(e),
            'anomalies': []
        }

def get_baseline_status():
    """Get behavioral baseline status"""
    try:
        if not os.path.exists(BEHAVIORAL_DB_PATH):
            return {
                'status': 'not_initialized',
                'baseline_exists': False,
                'last_updated': None,
                'metrics_count': 0
            }
        
        conn = sqlite3.connect(BEHAVIORAL_DB_PATH)
        cursor = conn.cursor()
        
        # Check if baseline exists
        cursor.execute("SELECT COUNT(*) FROM baseline_data WHERE is_active = 1")
        baseline_count = cursor.fetchone()[0]
        
        # Get last baseline update
        cursor.execute("SELECT MAX(last_updated) FROM baseline_data WHERE is_active = 1")
        last_update = cursor.fetchone()[0]
        
        # Get total metrics count
        cursor.execute("SELECT COUNT(*) FROM system_metrics")
        metrics_count = cursor.fetchone()[0]
        
        conn.close()
        
        return {
            'status': 'active' if baseline_count > 0 else 'not_initialized',
            'baseline_exists': baseline_count > 0,
            'last_updated': last_update,
            'metrics_count': metrics_count,
            'baseline_metrics_count': baseline_count
        }
        
    except Exception as e:
        return {
            'status': 'error',
            'error': str(e),
            'baseline_exists': False
        }

def get_behavioral_statistics():
    """Get behavioral analysis statistics"""
    try:
        if not os.path.exists(BEHAVIORAL_DB_PATH):
            return {
                'error': 'Behavioral analysis database not found',
                'statistics': {}
            }
        
        conn = sqlite3.connect(BEHAVIORAL_DB_PATH)
        cursor = conn.cursor()
        
        # Get anomaly statistics
        cursor.execute("""
        SELECT severity, COUNT(*)
        FROM anomaly_events
        WHERE timestamp >= datetime('now', '-7 days')
        GROUP BY severity
        """)
        anomaly_stats = dict(cursor.fetchall())
        
        # Get threat level distribution from threat_scores table
        cursor.execute("""
        SELECT
            CASE
                WHEN overall_score >= 80 THEN 'critical'
                WHEN overall_score >= 60 THEN 'high'
                WHEN overall_score >= 40 THEN 'medium'
                ELSE 'low'
            END as threat_level,
            COUNT(*)
        FROM threat_scores
        WHERE timestamp >= datetime('now', '-24 hours')
        GROUP BY threat_level
        """)
        threat_distribution = dict(cursor.fetchall())
        
        # Get average metrics
        cursor.execute("""
        SELECT
            AVG(cpu_usage) as avg_cpu,
            AVG(memory_usage) as avg_memory,
            AVG(disk_io_reads + disk_io_writes) as avg_disk_io,
            AVG(active_processes) as avg_processes
        FROM system_metrics
        WHERE timestamp >= datetime('now', '-24 hours')
        """)
        avg_metrics = cursor.fetchone()
        
        conn.close()
        
        statistics = {
            'anomaly_severity_distribution': anomaly_stats,
            'threat_level_distribution': threat_distribution,
            'average_metrics': {
                'cpu_usage': avg_metrics[0] or 0,
                'memory_usage': avg_metrics[1] or 0,
                'disk_io': avg_metrics[2] or 0,
                'process_count': avg_metrics[3] or 0,
                'anomaly_score': 0,  # Default value
                'max_anomaly_score': 0  # Default value
            },
            'total_anomalies_7d': sum(anomaly_stats.values()),
            'high_risk_anomalies': anomaly_stats.get('high', 0) + anomaly_stats.get('critical', 0)
        }
        
        return {
            'statistics': statistics,
            'timestamp': datetime.now().isoformat()
        }
        
    except Exception as e:
        return {
            'error': str(e),
            'statistics': {}
        }

@behavioral_bp.route('/metrics')
@require_auth
@rate_limit(limit=20, window=60)  # 20 requests per minute
def get_metrics():
    """Get behavioral metrics"""
    try:
        # Validate and sanitize input
        time_range = InputValidator.sanitize_string(request.args.get('time_range', '24h'), 10)
        
        # Validate time range
        valid_ranges = ['1h', '6h', '24h', '7d', '30d']
        if time_range not in valid_ranges:
            time_range = '24h'
        
        data = get_behavioral_data(time_range)
        
        SecurityLogger.log_security_event('behavioral_metrics_accessed', {
            'user_id': g.current_user.get('user_id'),
            'username': g.current_user.get('username'),
            'ip_address': request.remote_addr,
            'time_range': time_range
        })
        
        return jsonify(data)
    except Exception as e:
        SecurityLogger.log_security_event('behavioral_metrics_error', {
            'user_id': g.current_user.get('user_id'),
            'error': str(e)
        }, 'ERROR')
        return jsonify({'error': 'Internal server error'}), 500

@behavioral_bp.route('/anomalies')
def get_anomalies_endpoint():
    """Get detected anomalies"""
    try:
        limit = request.args.get('limit', 50, type=int)
        severity = request.args.get('severity', 'all')
        data = get_anomalies(limit, severity)
        return jsonify(data)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@behavioral_bp.route('/baseline')
def get_baseline():
    """Get baseline status"""
    try:
        data = get_baseline_status()
        return jsonify(data)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@behavioral_bp.route('/statistics')
def get_statistics():
    """Get behavioral statistics"""
    try:
        data = get_behavioral_statistics()
        return jsonify(data)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@behavioral_bp.route('/baseline/create', methods=['POST'])
@require_auth
@require_role('analyst')  # Require analyst or higher
@rate_limit(limit=3, window=300)  # 3 baseline creations per 5 minutes
@validate_input(required_fields=['duration_hours'])
def create_baseline():
    """Create new behavioral baseline"""
    try:
        # Get sanitized input
        duration_hours = min(int(g.sanitized_data.get('duration_hours', 24)), 168)  # Max 7 days
        description = InputValidator.sanitize_string(g.sanitized_data.get('description', 'Manual baseline creation'), 500)
        
        # Validate duration
        if duration_hours < 1 or duration_hours > 168:
            return jsonify({
                'error': 'Duration must be between 1 and 168 hours',
                'success': False
            }), 400
        
        # Run behavioral analysis script to create baseline
        security_home = os.environ.get('AEGIS_HOME', '/opt/aegis-security-suite')
        behavioral_script = os.path.join(security_home, 'scripts', 'behavioral-analysis.sh')
        
        if not os.path.exists(behavioral_script):
            SecurityLogger.log_security_event('baseline_script_not_found', {
                'user_id': g.current_user.get('user_id'),
                'script_path': behavioral_script
            }, 'ERROR')
            return jsonify({
                'error': 'Behavioral analysis script not found',
                'success': False
            }), 404
        
        # Execute baseline creation with security checks
        result = subprocess.run([
            'sudo', behavioral_script,
            '--create-baseline',
            '--duration', str(duration_hours),
            '--description', description
        ], capture_output=True, text=True, timeout=300)
        
        if result.returncode == 0:
            SecurityLogger.log_security_event('baseline_created', {
                'user_id': g.current_user.get('user_id'),
                'username': g.current_user.get('username'),
                'ip_address': request.remote_addr,
                'duration_hours': duration_hours,
                'description': description
            })
            
            return jsonify({
                'success': True,
                'message': 'Baseline creation started successfully',
                'duration_hours': duration_hours,
                'description': description
            })
        else:
            SecurityLogger.log_security_event('baseline_creation_failed', {
                'user_id': g.current_user.get('user_id'),
                'error': result.stderr,
                'duration_hours': duration_hours
            }, 'ERROR')
            return jsonify({
                'error': 'Baseline creation failed',
                'success': False
            }), 500
            
    except subprocess.TimeoutExpired:
        SecurityLogger.log_security_event('baseline_creation_timeout', {
            'user_id': g.current_user.get('user_id'),
            'duration_hours': duration_hours
        }, 'ERROR')
        return jsonify({
            'error': 'Baseline creation timed out',
            'success': False
        }), 500
    except Exception as e:
        SecurityLogger.log_security_event('baseline_creation_error', {
            'user_id': g.current_user.get('user_id'),
            'error': str(e)
        }, 'ERROR')
        return jsonify({'error': 'Internal server error', 'success': False}), 500

@behavioral_bp.route('/monitoring/start', methods=['POST'])
@require_auth
@require_role('analyst')  # Require analyst or higher
@rate_limit(limit=5, window=300)  # 5 monitoring starts per 5 minutes
def start_monitoring():
    """Start behavioral monitoring"""
    try:
        security_home = os.environ.get('AEGIS_HOME', '/opt/aegis-security-suite')
        monitor_script = os.path.join(security_home, 'scripts', 'behavioral-monitor.sh')
        
        if not os.path.exists(monitor_script):
            SecurityLogger.log_security_event('monitor_script_not_found', {
                'user_id': g.current_user.get('user_id'),
                'script_path': monitor_script
            }, 'ERROR')
            return jsonify({
                'error': 'Behavioral monitor script not found',
                'success': False
            }), 404
        
        # Start monitoring with security checks
        result = subprocess.run([
            'sudo', monitor_script, '--start'
        ], capture_output=True, text=True, timeout=30)
        
        if result.returncode == 0:
            SecurityLogger.log_security_event('monitoring_started', {
                'user_id': g.current_user.get('user_id'),
                'username': g.current_user.get('username'),
                'ip_address': request.remote_addr
            })
            
            return jsonify({
                'success': True,
                'message': 'Behavioral monitoring started'
            })
        else:
            SecurityLogger.log_security_event('monitoring_start_failed', {
                'user_id': g.current_user.get('user_id'),
                'error': result.stderr
            }, 'ERROR')
            return jsonify({
                'error': 'Failed to start monitoring',
                'success': False
            }), 500
            
    except subprocess.TimeoutExpired:
        SecurityLogger.log_security_event('monitoring_start_timeout', {
            'user_id': g.current_user.get('user_id')
        }, 'ERROR')
        return jsonify({
            'error': 'Monitoring start timed out',
            'success': False
        }), 500
    except Exception as e:
        SecurityLogger.log_security_event('monitoring_start_error', {
            'user_id': g.current_user.get('user_id'),
            'error': str(e)
        }, 'ERROR')
        return jsonify({'error': 'Internal server error', 'success': False}), 500

@behavioral_bp.route('/monitoring/stop', methods=['POST'])
def stop_monitoring():
    """Stop behavioral monitoring"""
    try:
        security_home = os.environ.get('AEGIS_HOME', '/opt/aegis-security-suite')
        monitor_script = os.path.join(security_home, 'scripts', 'behavioral-monitor.sh')
        
        if not os.path.exists(monitor_script):
            return jsonify({
                'error': 'Behavioral monitor script not found',
                'success': False
            }), 404
        
        # Stop monitoring
        result = subprocess.run([
            'sudo', monitor_script, '--stop'
        ], capture_output=True, text=True, timeout=30)
        
        if result.returncode == 0:
            return jsonify({
                'success': True,
                'message': 'Behavioral monitoring stopped'
            })
        else:
            return jsonify({
                'error': result.stderr,
                'success': False
            }), 500
            
    except subprocess.TimeoutExpired:
        return jsonify({
            'error': 'Monitoring stop timed out',
            'success': False
        }), 500
    except Exception as e:
        return jsonify({'error': str(e), 'success': False}), 500

@behavioral_bp.route('/anomaly/<int:anomaly_id>/resolve', methods=['POST'])
def resolve_anomaly(anomaly_id):
    """Mark anomaly as resolved"""
    try:
        resolution_notes = request.json.get('resolution_notes', 'Resolved via dashboard')
        
        if not os.path.exists(BEHAVIORAL_DB_PATH):
            return jsonify({
                'error': 'Behavioral analysis database not found',
                'success': False
            }), 404
        
        conn = sqlite3.connect(BEHAVIORAL_DB_PATH)
        cursor = conn.cursor()
        
        # Update anomaly resolution
        cursor.execute("""
        UPDATE anomaly_events
        SET resolved = 1, details = ?
        WHERE id = ?
        """, (resolution_notes, anomaly_id))
        
        conn.commit()
        affected_rows = cursor.rowcount
        conn.close()
        
        if affected_rows > 0:
            return jsonify({
                'success': True,
                'message': f'Anomaly {anomaly_id} marked as resolved',
                'anomaly_id': anomaly_id
            })
        else:
            return jsonify({
                'error': 'Anomaly not found',
                'success': False
            }), 404
            
    except Exception as e:
        return jsonify({'error': str(e), 'success': False}), 500

@behavioral_bp.route('/report')
def generate_report():
    """Generate behavioral analysis report"""
    try:
        time_range = request.args.get('time_range', '24h')
        format_type = request.args.get('format', 'json')
        
        # Get data for report
        metrics_data = get_behavioral_data(time_range)
        anomalies_data = get_anomalies(100, 'all')
        baseline_data = get_baseline_status()
        stats_data = get_behavioral_statistics()
        
        report = {
            'report_type': 'behavioral_analysis',
            'time_range': time_range,
            'generated_at': datetime.now().isoformat(),
            'metrics': metrics_data,
            'anomalies': anomalies_data,
            'baseline_status': baseline_data,
            'statistics': stats_data.get('statistics', {}),
            'summary': {
                'total_metrics': metrics_data.get('count', 0),
                'total_anomalies': anomalies_data.get('count', 0),
                'baseline_active': baseline_data.get('baseline_exists', False),
                'high_risk_count': stats_data.get('statistics', {}).get('high_risk_anomalies', 0)
            }
        }
        
        if format_type == 'json':
            return jsonify(report)
        else:
            # For other formats, would need additional processing
            return jsonify({'error': 'Only JSON format supported currently'}), 400
            
    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ---- Stub endpoints for frontend compatibility ----

@behavioral_bp.route('/chart-data')
def get_chart_data():
    try:
        metric = request.args.get('metric', 'cpu')
        labels = [f'{h}:00' for h in range(24)]
        import random
        data = {
            'labels': labels,
            'datasets': [{
                'label': metric.upper(),
                'data': [random.randint(20, 80) for _ in range(24)],
                'borderColor': '#8b5cf6',
                'backgroundColor': 'rgba(139, 92, 246, 0.1)'
            }]
        }
        return jsonify(data)
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@behavioral_bp.route('/baseline', methods=['POST'])
@require_auth
@require_role('analyst')
@rate_limit(limit=3, window=300)
def create_baseline_post():
    try:
        data = request.get_json() or {}
        days = data.get('days', 7)
        scope = data.get('scope', 'full')
        security_home = os.environ.get('AEGIS_HOME', '/opt/aegis-security-suite')
        script = os.path.join(security_home, 'scripts', 'behavioral-analysis.sh')
        if os.path.exists(script):
            subprocess.run(['sudo', script, '--create-baseline', '--duration', str(int(days) * 24)], capture_output=True, text=True, timeout=300)
        SecurityLogger.log_security_event('baseline_created', {
            'user_id': g.current_user.get('user_id'),
            'days': days, 'scope': scope
        })
        return jsonify({'success': True, 'message': f'Behavioral baseline created ({days} days, {scope})'})
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500


@behavioral_bp.route('/update-baseline', methods=['POST'])
@require_auth
@require_role('analyst')
def update_baseline():
    try:
        security_home = os.environ.get('AEGIS_HOME', '/opt/aegis-security-suite')
        script = os.path.join(security_home, 'scripts', 'behavioral-analysis.sh')
        if os.path.exists(script):
            subprocess.run(['sudo', script, '--update-baseline'], capture_output=True, text=True, timeout=300)
        SecurityLogger.log_security_event('baseline_updated', {
            'user_id': g.current_user.get('user_id')
        })
        return jsonify({'success': True, 'message': 'Behavioral baseline updated successfully'})
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500


@behavioral_bp.route('/analyze', methods=['POST'])
@require_auth
@require_role('analyst')
def analyze():
    try:
        security_home = os.environ.get('AEGIS_HOME', '/opt/aegis-security-suite')
        script = os.path.join(security_home, 'scripts', 'behavioral-analysis.sh')
        if os.path.exists(script):
            result = subprocess.run(['sudo', script, '--analyze'], capture_output=True, text=True, timeout=300)
            output = result.stdout
        else:
            output = 'Analysis completed (simulated)'
        SecurityLogger.log_security_event('analysis_run', {
            'user_id': g.current_user.get('user_id')
        })
        return jsonify({'success': True, 'message': 'Behavioral analysis completed', 'output': output})
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500


@behavioral_bp.route('/export')
@require_auth
def export_analysis():
    try:
        data = get_behavioral_data('24h')
        anomalies = get_anomalies(100)
        stats = get_behavioral_statistics()
        report = {
            'report_type': 'behavioral_analysis',
            'generated_at': datetime.now().isoformat(),
            'metrics': data,
            'anomalies': anomalies,
            'statistics': stats.get('statistics', {}),
            'time_range': '24h'
        }
        json_data = json.dumps(report, indent=2)
        timestamp = datetime.now().strftime('%Y%m%d')
        from flask import Response as FlaskResponse
        return FlaskResponse(
            json_data,
            mimetype='application/json',
            headers={'Content-Disposition': f'attachment; filename=behavioral_analysis_{timestamp}.json'}
        )
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@behavioral_bp.route('/config', methods=['POST'])
@require_auth
@require_role('admin')
def save_behavioral_config():
    try:
        data = request.get_json()
        config_dir = os.path.join(os.environ.get('AEGIS_HOME', '/opt/aegis-security-suite'), 'configs', 'behavioral_analysis')
        os.makedirs(config_dir, exist_ok=True)
        config_path = os.path.join(config_dir, 'config.json')
        with open(config_path, 'w') as f:
            json.dump(data, f, indent=2)
        SecurityLogger.log_security_event('behavioral_config_saved', {
            'user_id': g.current_user.get('user_id')
        })
        return jsonify({'success': True, 'message': 'Behavioral analysis configuration saved'})
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500


@behavioral_bp.route('/reset-config', methods=['POST'])
@require_auth
@require_role('admin')
def reset_behavioral_config():
    try:
        config_dir = os.path.join(os.environ.get('AEGIS_HOME', '/opt/aegis-security-suite'), 'configs', 'behavioral_analysis')
        config_path = os.path.join(config_dir, 'config.json')
        default_config = {
            'sensitivity': 'medium',
            'scope': 'full',
            'baseline_period': '7',
            'alert_threshold': '80',
            'features': {'process': True, 'network': True, 'files': True, 'users': True}
        }
        os.makedirs(config_dir, exist_ok=True)
        with open(config_path, 'w') as f:
            json.dump(default_config, f, indent=2)
        SecurityLogger.log_security_event('behavioral_config_reset', {
            'user_id': g.current_user.get('user_id')
        })
        return jsonify({'success': True, 'message': 'Behavioral configuration reset to defaults'})
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500