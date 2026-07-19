"""
Incident Management API Module for Aegis Security Suite Dashboard
Provides incident creation, tracking, and response endpoints
"""

import os
import sqlite3
import json
import subprocess
import uuid
from datetime import datetime, timedelta
from flask import Blueprint, jsonify, request, g

# Import security utilities
from security_utils import (
    SecurityLogger, InputValidator, rate_limiter,
    require_api_key, rate_limit, validate_input, secure_headers
)
from auth import require_auth, require_role

# Create Blueprint
incidents_bp = Blueprint('incidents', __name__, url_prefix='/api/incidents')

# Database paths
INCIDENT_DB_PATH = os.path.join(os.environ.get('AEGIS_HOME', '/opt/aegis-security-suite'), 
                                'configs', 'incident_response', 'incidents.db')

def ensure_incident_db():
    """Ensure incident database exists and is properly initialized"""
    try:
        if not os.path.exists(os.path.dirname(INCIDENT_DB_PATH)):
            os.makedirs(os.path.dirname(INCIDENT_DB_PATH), exist_ok=True)
        
        conn = sqlite3.connect(INCIDENT_DB_PATH)
        cursor = conn.cursor()
        
        # Create incidents table if it doesn't exist
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS incidents (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            incident_id TEXT UNIQUE NOT NULL,
            incident_type TEXT NOT NULL,
            incident_details TEXT NOT NULL,
            severity TEXT NOT NULL,
            status TEXT DEFAULT 'open',
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
            resolved_timestamp DATETIME,
            actions_taken TEXT,
            evidence_path TEXT,
            false_positive BOOLEAN DEFAULT 0,
            rollback_available BOOLEAN DEFAULT 0,
            rollback_data TEXT,
            assigned_to TEXT
        )
        """)

        # Backward compatibility: add assigned_to to pre-existing DBs
        try:
            cursor.execute("ALTER TABLE incidents ADD COLUMN assigned_to TEXT")
        except sqlite3.OperationalError:
            pass  # Column already exists

        # Create incident_updates table
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS incident_updates (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            incident_id TEXT NOT NULL,
            update_text TEXT NOT NULL,
            update_type TEXT NOT NULL,
            created_by TEXT,
            created_at TEXT NOT NULL,
            FOREIGN KEY (incident_id) REFERENCES incidents (id)
        )
        """)
        
        conn.commit()
        conn.close()
        return True
        
    except Exception as e:
        print(f"Error ensuring incident database: {e}")
        return False

def get_incidents(limit=50, status=None, severity=None, incident_type=None, offset=0):
    """Get incidents with optional filters"""
    try:
        if not ensure_incident_db():
            return {
                'incidents': [],
                'total': 0,
                'error': 'Failed to initialize incident database'
            }
        
        conn = sqlite3.connect(INCIDENT_DB_PATH)
        cursor = conn.cursor()
        
        # Build query
        query = "SELECT id, incident_id, incident_type, incident_details, severity, status, timestamp, resolved_timestamp, actions_taken, assigned_to FROM incidents WHERE 1=1"
        params = []
        
        if status:
            query += " AND status = ?"
            params.append(status)
        
        if severity:
            query += " AND severity = ?"
            params.append(severity)
        
        if incident_type:
            query += " AND incident_type = ?"
            params.append(incident_type)
        
        # Get total count
        count_query = query.replace("SELECT id, incident_id, incident_type, incident_details, severity, status, timestamp, resolved_timestamp, actions_taken, assigned_to", "SELECT COUNT(*)")
        cursor.execute(count_query, params)
        total = cursor.fetchone()[0]
        
        # Add pagination and ordering
        query += " ORDER BY timestamp DESC LIMIT ? OFFSET ?"
        params.extend([limit, offset])
        
        cursor.execute(query, params)
        rows = cursor.fetchall()
        
        # Convert to list of dictionaries
        incidents = []
        for row in rows:
            incidents.append({
                'id': row[1],  # Use incident_id as the public ID
                'title': f"{row[2]} - {row[3][:50]}...",  # Combine type and details for title
                'incident_type': row[2],
                'severity': row[4],
                'status': row[5],
                'description': row[3],  # incident_details maps to description
                'source': 'system',  # Default source
                'created_at': row[6],
                'updated_at': row[6],  # Use timestamp as updated_at
                'resolved_at': row[7],
                'assigned_to': row[9],
                'tags': []  # Default empty tags
            })
        
        conn.close()
        
        return {
            'incidents': incidents,
            'total': total,
            'limit': limit,
            'offset': offset
        }
        
    except Exception as e:
        return {
            'incidents': [],
            'total': 0,
            'error': str(e)
        }

def get_incident_by_id(incident_id):
    """Get specific incident by ID"""
    try:
        if not ensure_incident_db():
            return None
        
        conn = sqlite3.connect(INCIDENT_DB_PATH)
        cursor = conn.cursor()
        
        # Get incident details
        cursor.execute("""
        SELECT id, incident_id, incident_type, incident_details, severity, status,
               timestamp, resolved_timestamp, actions_taken, evidence_path, assigned_to
        FROM incidents WHERE incident_id = ?
        """, (incident_id,))

        row = cursor.fetchone()
        if not row:
            conn.close()
            return None

        incident = {
            'id': row[1],  # Use incident_id as the public ID
            'title': f"{row[2]} - {row[3][:50]}...",  # Combine type and details for title
            'incident_type': row[2],
            'severity': row[4],
            'status': row[5],
            'description': row[3],  # incident_details maps to description
            'source': 'system',  # Default source
            'created_at': row[6],
            'updated_at': row[6],  # Use timestamp as updated_at
            'resolved_at': row[7],
            'assigned_to': row[10],
            'tags': [],  # Default empty tags
            'evidence_files': [row[8]] if row[8] else []  # evidence_path as evidence_files
        }
        
        # Get incident updates
        cursor.execute("""
        SELECT id, update_text, update_type, created_by, created_at
        FROM incident_updates 
        WHERE incident_id = ?
        ORDER BY created_at DESC
        """, (incident_id,))
        
        updates = []
        for update_row in cursor.fetchall():
            updates.append({
                'id': update_row[0],
                'update_text': update_row[1],
                'update_type': update_row[2],
                'created_by': update_row[3],
                'created_at': update_row[4]
            })
        
        incident['updates'] = updates
        
        conn.close()
        return incident
        
    except Exception as e:
        print(f"Error getting incident {incident_id}: {e}")
        return None

def create_incident(title, incident_type, severity, description, source='dashboard', tags=None):
    """Create new incident"""
    try:
        if not ensure_incident_db():
            return {
                'success': False,
                'error': 'Failed to initialize incident database'
            }
        
        # Generate unique incident ID
        incident_id = f"INC_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{str(uuid.uuid4())[:8]}"
        
        conn = sqlite3.connect(INCIDENT_DB_PATH)
        cursor = conn.cursor()
        
        now = datetime.now().isoformat()
        
        # Insert incident
        cursor.execute("""
        INSERT INTO incidents (incident_id, incident_type, incident_details, severity, status, timestamp)
        VALUES (?, ?, ?, ?, 'open', ?)
        """, (incident_id, incident_type, description, severity, now))
        
        conn.commit()
        conn.close()
        
        # Trigger incident response script
        trigger_incident_response(incident_id, incident_type, severity)
        
        return {
            'success': True,
            'incident_id': incident_id,
            'message': 'Incident created successfully'
        }
        
    except Exception as e:
        return {
            'success': False,
            'error': str(e)
        }

def update_incident(incident_id, updates):
    """Update incident"""
    try:
        if not ensure_incident_db():
            return {
                'success': False,
                'error': 'Failed to initialize incident database'
            }
        
        conn = sqlite3.connect(INCIDENT_DB_PATH)
        cursor = conn.cursor()
        
        # Build update query
        set_clauses = []
        params = []
        
        for field, value in updates.items():
            if field in ['title', 'incident_type', 'severity', 'status', 'description']:
                # Map title to incident_details
                if field == 'title':
                    set_clauses.append("incident_details = ?")
                    params.append(value)
                elif field == 'description':
                    set_clauses.append("incident_details = ?")
                    params.append(value)
                else:
                    set_clauses.append(f"{field} = ?")
                    params.append(value)
            elif field == 'assigned_to':
                set_clauses.append("assigned_to = ?")
                params.append(value)
            elif field == 'tags':
                # Skip tags as it doesn't exist in the table
                continue
        
        if not set_clauses:
            conn.close()
            return {
                'success': False,
                'error': 'No valid fields to update'
            }
        
        # Add resolved_at if status is being set to resolved
        if 'status' in updates and updates['status'] == 'resolved':
            set_clauses.append("resolved_timestamp = ?")
            params.append(datetime.now().isoformat())
        
        params.append(incident_id)
        
        query = f"UPDATE incidents SET {', '.join(set_clauses)} WHERE incident_id = ?"
        cursor.execute(query, params)
        
        affected_rows = cursor.rowcount
        conn.commit()
        conn.close()
        
        if affected_rows > 0:
            return {
                'success': True,
                'message': f'Incident {incident_id} updated successfully'
            }
        else:
            return {
                'success': False,
                'error': 'Incident not found'
            }
            
    except Exception as e:
        return {
            'success': False,
            'error': str(e)
        }

def add_incident_update(incident_id, update_text, update_type='note', created_by='dashboard'):
    """Add update to incident"""
    try:
        if not ensure_incident_db():
            return {
                'success': False,
                'error': 'Failed to initialize incident database'
            }
        
        conn = sqlite3.connect(INCIDENT_DB_PATH)
        cursor = conn.cursor()
        
        # Insert update
        cursor.execute("""
        INSERT INTO incident_updates (incident_id, update_text, update_type, created_by, created_at)
        VALUES (?, ?, ?, ?, ?)
        """, (incident_id, update_text, update_type, created_by, datetime.now().isoformat()))
        
        # Update incident's updated_at
        cursor.execute("""
        UPDATE incidents SET updated_at = ? WHERE id = ?
        """, (datetime.now().isoformat(), incident_id))
        
        conn.commit()
        conn.close()
        
        return {
            'success': True,
            'message': 'Update added successfully'
        }
        
    except Exception as e:
        return {
            'success': False,
            'error': str(e)
        }

def get_incident_statistics():
    """Get incident statistics"""
    try:
        if not ensure_incident_db():
            return {
                'error': 'Failed to initialize incident database',
                'statistics': {}
            }
        
        conn = sqlite3.connect(INCIDENT_DB_PATH)
        cursor = conn.cursor()
        
        # Get incidents by status
        cursor.execute("SELECT status, COUNT(*) FROM incidents GROUP BY status")
        status_stats = dict(cursor.fetchall())
        
        # Get incidents by severity
        cursor.execute("SELECT severity, COUNT(*) FROM incidents GROUP BY severity")
        severity_stats = dict(cursor.fetchall())
        
        # Get incidents by type
        cursor.execute("SELECT incident_type, COUNT(*) FROM incidents GROUP BY incident_type")
        type_stats = dict(cursor.fetchall())
        
        # Get recent incidents (last 7 days)
        cursor.execute("""
        SELECT COUNT(*) FROM incidents
        WHERE timestamp >= datetime('now', '-7 days')
        """)
        recent_count = cursor.fetchone()[0]
        
        # Get resolved incidents (last 30 days)
        cursor.execute("""
        SELECT COUNT(*) FROM incidents
        WHERE status = 'resolved' AND resolved_timestamp >= datetime('now', '-30 days')
        """)
        resolved_count = cursor.fetchone()[0]
        
        # Get average resolution time
        cursor.execute("""
        SELECT AVG(julianday(resolved_timestamp) - julianday(timestamp)) * 24
        FROM incidents
        WHERE status = 'resolved' AND resolved_timestamp IS NOT NULL
        """)
        avg_resolution_time = cursor.fetchone()[0] or 0
        
        conn.close()
        
        statistics = {
            'by_status': status_stats,
            'by_severity': severity_stats,
            'by_type': type_stats,
            'total_incidents': sum(status_stats.values()),
            'open_incidents': status_stats.get('open', 0),
            'recent_incidents_7d': recent_count,
            'resolved_incidents_30d': resolved_count,
            'average_resolution_time_hours': round(avg_resolution_time, 2)
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

def trigger_incident_response(incident_id, incident_type, severity):
    """Trigger incident response script"""
    try:
        security_home = os.environ.get('AEGIS_HOME', '/opt/aegis-security-suite')
        incident_script = os.path.join(security_home, 'scripts', 'incident-response.sh')
        
        if not os.path.exists(incident_script):
            return False
        
        # Run incident response in background
        subprocess.Popen([
            'sudo', incident_script,
            '--incident-id', incident_id,
            '--type', incident_type,
            '--severity', severity
        ])
        
        return True
        
    except Exception as e:
        print(f"Error triggering incident response: {e}")
        return False

@incidents_bp.route('/')
@require_auth
@rate_limit(limit=20, window=60)  # 20 requests per minute
def get_incidents_endpoint():
    """Get incidents with optional filters"""
    try:
        # Validate and sanitize input
        limit = min(request.args.get('limit', 50, type=int), 1000)  # Max 1000 incidents
        status = InputValidator.sanitize_string(request.args.get('status', ''), 20)
        severity = InputValidator.sanitize_string(request.args.get('severity', ''), 20)
        incident_type = InputValidator.sanitize_string(request.args.get('type', ''), 50)
        offset = max(request.args.get('offset', 0, type=int), 0)
        
        # Validate status
        valid_statuses = ['open', 'investigating', 'resolved', 'closed']
        if status and status not in valid_statuses:
            status = ''
        
        # Validate severity
        valid_severities = ['low', 'medium', 'high', 'critical']
        if severity and severity not in valid_severities:
            severity = ''
        
        data = get_incidents(limit, status, severity, incident_type, offset)
        
        SecurityLogger.log_security_event('incidents_accessed', {
            'user_id': g.current_user.get('user_id'),
            'username': g.current_user.get('username'),
            'ip_address': request.remote_addr,
            'status': status,
            'severity': severity,
            'incident_type': incident_type,
            'limit': limit
        })
        
        return jsonify(data)
    except Exception as e:
        SecurityLogger.log_security_event('incidents_access_error', {
            'user_id': g.current_user.get('user_id'),
            'error': str(e)
        }, 'ERROR')
        return jsonify({'error': 'Internal server error'}), 500

@incidents_bp.route('/<incident_id>')
def get_incident_endpoint(incident_id):
    """Get specific incident"""
    try:
        incident = get_incident_by_id(incident_id)
        if incident:
            return jsonify(incident)
        else:
            return jsonify({'error': 'Incident not found'}), 404
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@incidents_bp.route('/', methods=['POST'])
@require_auth
@require_role('analyst')  # Require analyst or higher
@rate_limit(limit=10, window=60)  # 10 incident creations per minute
@validate_input(required_fields=['title', 'incident_type', 'severity', 'description'])
def create_incident_endpoint():
    """Create new incident"""
    try:
        # Get sanitized input
        title = InputValidator.sanitize_string(g.sanitized_data.get('title', ''), 200)
        incident_type = InputValidator.sanitize_string(g.sanitized_data.get('incident_type', ''), 50)
        severity = InputValidator.sanitize_string(g.sanitized_data.get('severity', ''), 20)
        description = InputValidator.sanitize_string(g.sanitized_data.get('description', ''), 2000)
        source = InputValidator.sanitize_string(g.sanitized_data.get('source', 'dashboard'), 100)
        tags = g.sanitized_data.get('tags', [])
        
        # Validate severity
        valid_severities = ['low', 'medium', 'high', 'critical']
        if severity not in valid_severities:
            severity = 'medium'
        
        # Validate and sanitize tags
        if isinstance(tags, list):
            sanitized_tags = []
            for tag in tags[:10]:  # Max 10 tags
                if isinstance(tag, str):
                    sanitized_tag = InputValidator.sanitize_string(tag, 50)
                    if sanitized_tag:
                        sanitized_tags.append(sanitized_tag)
            tags = sanitized_tags
        else:
            tags = []
        
        result = create_incident(title, incident_type, severity, description, source, tags)
        
        if result['success']:
            SecurityLogger.log_security_event('incident_created', {
                'user_id': g.current_user.get('user_id'),
                'username': g.current_user.get('username'),
                'ip_address': request.remote_addr,
                'incident_id': result.get('incident_id'),
                'title': title,
                'incident_type': incident_type,
                'severity': severity
            })
            return jsonify(result), 201
        else:
            SecurityLogger.log_security_event('incident_creation_failed', {
                'user_id': g.current_user.get('user_id'),
                'error': result.get('error', 'Unknown error'),
                'incident_type': incident_type
            }, 'WARNING')
            return jsonify(result), 400
            
    except Exception as e:
        SecurityLogger.log_security_event('incident_creation_error', {
            'user_id': g.current_user.get('user_id'),
            'error': str(e)
        }, 'ERROR')
        return jsonify({'success': False, 'error': 'Internal server error'}), 500

@incidents_bp.route('/<incident_id>', methods=['PUT'])
@require_auth
@require_role('analyst')  # Require analyst or higher
@rate_limit(limit=20, window=60)  # 20 incident updates per minute
def update_incident_endpoint(incident_id):
    """Update incident"""
    try:
        # Validate incident ID
        if not incident_id or not isinstance(incident_id, str):
            return jsonify({
                'success': False,
                'error': 'Invalid incident ID'
            }), 400
        
        data = request.get_json()
        
        if not data:
            return jsonify({
                'success': False,
                'error': 'No update data provided'
            }), 400
        
        # Sanitize update data
        sanitized_data = {}
        for field, value in data.items():
            if field in ['title', 'incident_type', 'severity', 'status', 'description', 'assigned_to']:
                if isinstance(value, str):
                    sanitized_data[field] = InputValidator.sanitize_string(value, 500)
                else:
                    sanitized_data[field] = value
            elif field == 'tags':
                if isinstance(value, list):
                    sanitized_tags = []
                    for tag in value[:10]:  # Max 10 tags
                        if isinstance(tag, str):
                            sanitized_tag = InputValidator.sanitize_string(tag, 50)
                            if sanitized_tag:
                                sanitized_tags.append(sanitized_tag)
                    sanitized_data[field] = sanitized_tags
        
        result = update_incident(incident_id, sanitized_data)
        
        if result['success']:
            SecurityLogger.log_security_event('incident_updated', {
                'user_id': g.current_user.get('user_id'),
                'username': g.current_user.get('username'),
                'ip_address': request.remote_addr,
                'incident_id': incident_id,
                'updated_fields': list(sanitized_data.keys())
            })
            return jsonify(result)
        else:
            SecurityLogger.log_security_event('incident_update_failed', {
                'user_id': g.current_user.get('user_id'),
                'incident_id': incident_id,
                'error': result.get('error', 'Unknown error')
            }, 'WARNING')
            return jsonify(result), 400
            
    except Exception as e:
        SecurityLogger.log_security_event('incident_update_error', {
            'user_id': g.current_user.get('user_id'),
            'incident_id': incident_id,
            'error': str(e)
        }, 'ERROR')
        return jsonify({'success': False, 'error': 'Internal server error'}), 500

@incidents_bp.route('/<incident_id>/updates', methods=['POST'])
def add_update_endpoint(incident_id):
    """Add update to incident"""
    try:
        data = request.get_json()
        
        if not data or 'update_text' not in data:
            return jsonify({
                'success': False,
                'error': 'Missing required field: update_text'
            }), 400
        
        result = add_incident_update(
            incident_id,
            data['update_text'],
            data.get('update_type', 'note'),
            data.get('created_by', 'dashboard')
        )
        
        if result['success']:
            return jsonify(result)
        else:
            return jsonify(result), 400
            
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@incidents_bp.route('/statistics')
def get_statistics_endpoint():
    """Get incident statistics"""
    try:
        data = get_incident_statistics()
        return jsonify(data)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@incidents_bp.route('/<incident_id>/evidence', methods=['POST'])
@require_auth
@require_role('analyst')  # Require analyst or higher
@rate_limit(limit=5, window=300)  # 5 evidence collections per 5 minutes
@validate_input(required_fields=['type'])
def collect_evidence(incident_id):
    """Collect evidence for incident"""
    try:
        # Validate incident ID
        if not incident_id or not isinstance(incident_id, str):
            return jsonify({
                'success': False,
                'error': 'Invalid incident ID'
            }), 400
        
        # Get sanitized input
        evidence_type = InputValidator.sanitize_string(g.sanitized_data.get('type', 'basic'), 20)
        
        # Validate evidence type
        valid_types = ['basic', 'full', 'network', 'memory', 'disk']
        if evidence_type not in valid_types:
            evidence_type = 'basic'
        
        security_home = os.environ.get('AEGIS_HOME', '/opt/aegis-security-suite')
        incident_script = os.path.join(security_home, 'scripts', 'incident-response.sh')
        
        if not os.path.exists(incident_script):
            SecurityLogger.log_security_event('incident_script_not_found', {
                'user_id': g.current_user.get('user_id'),
                'script_path': incident_script
            }, 'ERROR')
            return jsonify({
                'success': False,
                'error': 'Incident response script not found'
            }), 404
        
        # Start evidence collection with security checks
        result = subprocess.run([
            'sudo', incident_script,
            '--collect-evidence',
            '--incident-id', incident_id,
            '--type', evidence_type
        ], capture_output=True, text=True, timeout=300)
        
        if result.returncode == 0:
            SecurityLogger.log_security_event('evidence_collection_started', {
                'user_id': g.current_user.get('user_id'),
                'username': g.current_user.get('username'),
                'ip_address': request.remote_addr,
                'incident_id': incident_id,
                'evidence_type': evidence_type
            })
            
            return jsonify({
                'success': True,
                'message': 'Evidence collection started',
                'output': result.stdout
            })
        else:
            SecurityLogger.log_security_event('evidence_collection_failed', {
                'user_id': g.current_user.get('user_id'),
                'incident_id': incident_id,
                'evidence_type': evidence_type,
                'error': result.stderr
            }, 'ERROR')
            return jsonify({
                'success': False,
                'error': 'Evidence collection failed'
            }), 500
            
    except subprocess.TimeoutExpired:
        SecurityLogger.log_security_event('evidence_collection_timeout', {
            'user_id': g.current_user.get('user_id'),
            'incident_id': incident_id,
            'evidence_type': evidence_type
        }, 'ERROR')
        return jsonify({
            'success': False,
            'error': 'Evidence collection timed out'
        }), 500
    except Exception as e:
        SecurityLogger.log_security_event('evidence_collection_error', {
            'user_id': g.current_user.get('user_id'),
            'incident_id': incident_id,
            'error': str(e)
        }, 'ERROR')
        return jsonify({'success': False, 'error': 'Internal server error'}), 500

@incidents_bp.route('/export')
def export_incidents():
    """Export incidents in various formats"""
    try:
        format_type = request.args.get('format', 'json')
        status = request.args.get('status')
        severity = request.args.get('severity')
        
        # Get incidents
        data = get_incidents(10000, status, severity)
        
        if format_type == 'json':
            return jsonify(data)
        elif format_type == 'csv':
            # Convert to CSV format
            csv_data = "ID,Title,Type,Severity,Status,Description,Source,Created At,Updated At,Resolved At,Assigned To\n"
            for incident in data.get('incidents', []):
                csv_data += f"{incident['id']},{incident['title']},{incident['incident_type']},{incident['severity']},{incident['status']},{incident['description']},{incident['source']},{incident['created_at']},{incident['updated_at']},{incident.get('resolved_at', '')},{incident.get('assigned_to', '')}\n"
            
            from flask import Response
            return Response(
                csv_data,
                mimetype='text/csv',
                headers={'Content-Disposition': 'attachment; filename=incidents_export.csv'}
            )
        else:
            return jsonify({'error': 'Unsupported export format'}), 400
            
    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ---- Stub endpoints for frontend compatibility ----

@incidents_bp.route('/chart-data')
def get_chart_data():
    try:
        range_param = request.args.get('range', '24h')
        import random
        points = 24 if range_param == '24h' else 7
        labels = [f'{i}' for i in range(points)]
        data = {
            'labels': labels,
            'trends': {
                'created': random.randint(0, 10),
                'resolved': random.randint(0, 8),
                'escalated': random.randint(0, 3)
            },
            'datasets': {
                'created': [random.randint(0, 5) for _ in range(points)],
                'resolved': [random.randint(0, 4) for _ in range(points)],
                'escalated': [random.randint(0, 2) for _ in range(points)]
            },
            'severity_counts': {
                'critical': random.randint(0, 2),
                'high': random.randint(1, 5),
                'medium': random.randint(2, 8),
                'low': random.randint(3, 10)
            }
        }
        return jsonify(data)
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@incidents_bp.route('/<incident_id>/assign', methods=['POST'])
@require_auth
@require_role('analyst')
def assign_incident(incident_id):
    try:
        if not ensure_incident_db():
            return jsonify({'success': False, 'message': 'Failed to initialize incident database'}), 500
        data = request.get_json() or {}
        assignee = data.get('assignee', '')
        conn = sqlite3.connect(INCIDENT_DB_PATH)
        cursor = conn.cursor()
        cursor.execute("UPDATE incidents SET status = 'investigating', assigned_to = ? WHERE incident_id = ?",
                       (assignee, incident_id))
        conn.commit()
        affected = cursor.rowcount
        conn.close()
        if affected > 0:
            add_incident_update(incident_id, f'Assigned to {assignee}', 'assignment')
            return jsonify({'success': True, 'message': f'Incident {incident_id} assigned to {assignee}'})
        return jsonify({'success': False, 'message': 'Incident not found'}), 404
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500


@incidents_bp.route('/bulk-assign', methods=['POST'])
@require_auth
@require_role('analyst')
def bulk_assign():
    try:
        if not ensure_incident_db():
            return jsonify({'success': False, 'message': 'Failed to initialize incident database'}), 500
        data = request.get_json() or {}
        incident_ids = data.get('incident_ids', [])[:500]
        assignee = data.get('assignee', '')
        assigned = 0
        conn = sqlite3.connect(INCIDENT_DB_PATH)
        cursor = conn.cursor()
        for inc_id in incident_ids:
            cursor.execute("UPDATE incidents SET status = 'investigating', assigned_to = ? WHERE incident_id = ?",
                           (assignee, inc_id))
            if cursor.rowcount > 0:
                assigned += 1
        conn.commit()
        conn.close()
        return jsonify({'success': True, 'assigned_count': assigned, 'message': f'{assigned} incidents assigned to {assignee}'})
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500


@incidents_bp.route('/bulk-escalate', methods=['POST'])
@require_auth
@require_role('analyst')
def bulk_escalate():
    try:
        data = request.get_json() or {}
        incident_ids = data.get('incident_ids', [])[:500]
        escalated = 0
        conn = sqlite3.connect(INCIDENT_DB_PATH)
        cursor = conn.cursor()
        for inc_id in incident_ids:
            cursor.execute("UPDATE incidents SET status = 'escalated' WHERE incident_id = ? AND status != 'resolved'", (inc_id,))
            if cursor.rowcount > 0:
                escalated += 1
        conn.commit()
        conn.close()
        return jsonify({'success': True, 'escalated_count': escalated, 'message': f'{escalated} incidents escalated'})
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500


@incidents_bp.route('/generate-report', methods=['POST'])
@require_auth
@require_role('analyst')
def generate_report():
    try:
        stats = get_incident_statistics()
        incidents = get_incidents(100)
        report = {
            'generated_at': datetime.now().isoformat(),
            'statistics': stats.get('statistics', {}),
            'incidents': incidents.get('incidents', []),
            'summary': {
                'total': len(incidents.get('incidents', [])),
                'open': stats.get('statistics', {}).get('open_incidents', 0),
                'avg_resolution': stats.get('statistics', {}).get('average_resolution_time_hours', 0)
            }
        }
        return jsonify({'success': True, 'message': 'Report generated', 'report': report})
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500


@incidents_bp.route('/export_data')
def export_incidents_data():
    try:
        data = get_incidents(10000)
        json_data = json.dumps(data, indent=2)
        timestamp = datetime.now().strftime('%Y%m%d')
        from flask import Response as FlaskResponse
        return FlaskResponse(
            json_data,
            mimetype='application/json',
            headers={'Content-Disposition': f'attachment; filename=incidents_{timestamp}.json'}
        )
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@incidents_bp.route('/automate-response', methods=['POST'])
@require_auth
@require_role('analyst')
def automate_response():
    try:
        security_home = os.environ.get('AEGIS_HOME', '/opt/aegis-security-suite')
        script = os.path.join(security_home, 'scripts', 'incident-response.sh')
        if os.path.exists(script):
            subprocess.Popen(['sudo', script, '--auto-respond'])
        return jsonify({'success': True, 'message': 'Automated incident response triggered'})
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500


@incidents_bp.route('/team-status')
@require_auth
def team_status():
    """Team roster backed by registered dashboard users and their real
    session activity (previously a hardcoded fictional roster)."""
    try:
        from auth import AUTH_DB_PATH
        conn = sqlite3.connect(AUTH_DB_PATH)
        cursor = conn.cursor()
        cursor.execute("""
        SELECT u.id, u.username, u.role, MAX(s.last_activity) as last_activity
        FROM users u
        LEFT JOIN user_sessions s ON s.user_id = u.id AND s.is_active = 1 AND s.expires_at > ?
        WHERE u.is_active = 1
        GROUP BY u.id
        ORDER BY u.username
        """, (datetime.now().isoformat(),))
        rows = cursor.fetchall()
        conn.close()

        role_labels = {
            'viewer': 'Viewer', 'analyst': 'Security Analyst',
            'manager': 'Manager', 'admin': 'Administrator'
        }
        members = []
        for user_id, username, role, last_activity in rows:
            status = 'offline'
            if last_activity:
                idle_minutes = (datetime.now() - datetime.fromisoformat(last_activity)).total_seconds() / 60
                status = 'online' if idle_minutes <= 5 else ('busy' if idle_minutes <= 30 else 'offline')
            members.append({
                'id': str(user_id),
                'name': username,
                'role': role_labels.get(role, role),
                'status': status
            })
        return jsonify({'team_members': members, 'team_status': members})
    except Exception as e:
        return jsonify({'error': str(e), 'team_members': []}), 500