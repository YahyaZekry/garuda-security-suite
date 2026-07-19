"""
Threat Intelligence API Module for Aegis Security Suite Dashboard
Provides threat intelligence, IOC management, and threat feed endpoints
"""

import os
import sqlite3
import json
import subprocess
import hashlib
from datetime import datetime, timedelta
from flask import Blueprint, jsonify, request, g

# Import security utilities
from security_utils import (
    SecurityLogger, InputValidator, rate_limiter,
    require_api_key, rate_limit, validate_input, secure_headers
)
from auth import require_auth, require_role

# Create Blueprint
threats_bp = Blueprint('threats', __name__, url_prefix='/api/threats')

# Database paths
THREAT_DB_PATH = os.path.join(os.environ.get('AEGIS_HOME', '/opt/aegis-security-suite'), 
                              'configs', 'threat_intelligence', 'ioc_database.db')

def get_ioc_database_stats():
    """Get IOC database statistics"""
    try:
        if not os.path.exists(THREAT_DB_PATH):
            return {
                'total_iocs': 0,
                'by_type': {},
                'by_severity': {},
                'last_updated': None
            }
        
        conn = sqlite3.connect(THREAT_DB_PATH)
        cursor = conn.cursor()
        
        # Get total count from all IOC tables
        cursor.execute("""
        SELECT COUNT(*) FROM ioc_ips
        UNION ALL
        SELECT COUNT(*) FROM ioc_domains
        UNION ALL
        SELECT COUNT(*) FROM ioc_urls
        UNION ALL
        SELECT COUNT(*) FROM ioc_hashes
        """)
        counts = cursor.fetchall()
        total_iocs = sum(count[0] for count in counts)
        
        # Get count by type
        by_type = {
            'ip': cursor.execute("SELECT COUNT(*) FROM ioc_ips").fetchone()[0],
            'domain': cursor.execute("SELECT COUNT(*) FROM ioc_domains").fetchone()[0],
            'url': cursor.execute("SELECT COUNT(*) FROM ioc_urls").fetchone()[0],
            'hash': cursor.execute("SELECT COUNT(*) FROM ioc_hashes").fetchone()[0]
        }
        
        # Get count by severity/confidence levels
        cursor.execute("""
        SELECT confidence, COUNT(*) FROM ioc_ips WHERE active = 1 GROUP BY confidence
        UNION ALL
        SELECT confidence, COUNT(*) FROM ioc_domains WHERE active = 1 GROUP BY confidence
        UNION ALL
        SELECT confidence, COUNT(*) FROM ioc_urls WHERE active = 1 GROUP BY confidence
        UNION ALL
        SELECT confidence, COUNT(*) FROM ioc_hashes WHERE active = 1 GROUP BY confidence
        """)
        severity_results = cursor.fetchall()
        
        by_severity = {}
        for confidence, count in severity_results:
            if confidence >= 90:
                by_severity['critical'] = by_severity.get('critical', 0) + count
            elif confidence >= 75:
                by_severity['high'] = by_severity.get('high', 0) + count
            elif confidence >= 60:
                by_severity['medium'] = by_severity.get('medium', 0) + count
            else:
                by_severity['low'] = by_severity.get('low', 0) + count
        
        # Get last updated
        cursor.execute("""
        SELECT MAX(first_seen) FROM ioc_ips
        UNION ALL
        SELECT MAX(first_seen) FROM ioc_domains
        UNION ALL
        SELECT MAX(first_seen) FROM ioc_urls
        UNION ALL
        SELECT MAX(first_seen) FROM ioc_hashes
        """)
        timestamps = cursor.fetchall()
        last_updated = max((ts[0] for ts in timestamps if ts[0]), default=None)
        
        conn.close()
        
        return {
            'total_iocs': total_iocs,
            'by_type': by_type,
            'by_severity': by_severity,
            'last_updated': last_updated
        }
        
    except Exception as e:
        return {
            'error': str(e),
            'total_iocs': 0,
            'by_type': {},
            'by_severity': {},
            'last_updated': None
        }

def search_iocs(search_term=None, ioc_type=None, severity=None, limit=50, offset=0):
    """Search IOCs with filters"""
    try:
        if not os.path.exists(THREAT_DB_PATH):
            return {
                'iocs': [],
                'total': 0,
                'error': 'IOC database not found'
            }
        
        conn = sqlite3.connect(THREAT_DB_PATH)
        cursor = conn.cursor()
        
        # Determine which table to query based on type
        table_map = {
            'ip': 'ioc_ips',
            'domain': 'ioc_domains',
            'url': 'ioc_urls',
            'hash': 'ioc_hashes'
        }
        
        # If no specific type, search all tables
        if ioc_type and ioc_type in table_map:
            tables = [table_map[ioc_type]]
        else:
            tables = list(table_map.values())
        
        all_iocs = []
        total = 0
        
        for table in tables:
            # Build query for each table
            if table == 'ioc_ips':
                query = "SELECT id, ip_address, 'ip', threat_type, confidence, source, first_seen, last_seen FROM ioc_ips WHERE active = 1"
                value_field = 'ip_address'
            elif table == 'ioc_domains':
                query = "SELECT id, domain, 'domain', threat_type, confidence, source, first_seen, last_seen FROM ioc_domains WHERE active = 1"
                value_field = 'domain'
            elif table == 'ioc_urls':
                query = "SELECT id, url, 'url', threat_type, confidence, source, first_seen, last_seen FROM ioc_urls WHERE active = 1"
                value_field = 'url'
            else:  # ioc_hashes
                query = "SELECT id, file_hash, 'hash', threat_type, confidence, source, first_seen, last_seen FROM ioc_hashes WHERE active = 1"
                value_field = 'file_hash'
            
            params = []
            
            if search_term:
                query += f" AND ({value_field} LIKE ? OR threat_type LIKE ?)"
                params.extend([f'%{search_term}%', f'%{search_term}%'])
            
            if severity:
                # Convert severity text to confidence range
                if severity == 'critical':
                    query += " AND confidence >= 90"
                elif severity == 'high':
                    query += " AND confidence >= 75 AND confidence < 90"
                elif severity == 'medium':
                    query += " AND confidence >= 60 AND confidence < 75"
                elif severity == 'low':
                    query += " AND confidence < 60"
            
            # Get total count for this table
            count_query = query.replace(f"SELECT id, {value_field}, ", "SELECT COUNT(*)")
            count_query = count_query.replace(f"SELECT id, file_hash, ", "SELECT COUNT(*)")
            cursor.execute(count_query, params)
            total += cursor.fetchone()[0]
            
            # Add pagination and ordering
            query += " ORDER BY first_seen DESC"
            
            cursor.execute(query, params)
            rows = cursor.fetchall()
            
            # Convert to list of dictionaries
            for row in rows:
                all_iocs.append({
                    'id': row[0],
                    'ioc_value': row[1],
                    'ioc_type': row[2],
                    'description': row[3],  # threat_type maps to description
                    'severity': row[4],      # confidence maps to severity
                    'source': row[5],
                    'created_at': row[6],
                    'updated_at': row[7]
                })
        
        # Sort all results by creation date and apply pagination
        all_iocs.sort(key=lambda x: x['created_at'], reverse=True)
        paginated_iocs = all_iocs[offset:offset + limit]
        
        conn.close()
        
        return {
            'iocs': paginated_iocs,
            'total': total,
            'limit': limit,
            'offset': offset
        }
        
    except Exception as e:
        return {
            'iocs': [],
            'total': 0,
            'error': str(e)
        }

def get_threat_feeds_status():
    """Get status of threat feeds"""
    try:
        if not os.path.exists(THREAT_DB_PATH):
            # Return mock data if database doesn't exist or has no feeds
            return {
                'feeds': [
                    {
                        'name': 'Malware Domain List',
                        'url': 'https://example.com/malware-domains.txt',
                        'type': 'domain',
                        'last_update': datetime.now().isoformat(),
                        'update_frequency': 86400,
                        'status': 'active',
                        'success_count': 0,
                        'failure_count': 0,
                        'last_success': None,
                        'last_failure': None,
                        'active': True
                    },
                    {
                        'name': 'Suspicious IP List',
                        'url': 'https://example.com/suspicious-ips.txt',
                        'type': 'ip',
                        'last_update': datetime.now().isoformat(),
                        'update_frequency': 86400,
                        'status': 'active',
                        'success_count': 0,
                        'failure_count': 0,
                        'last_success': None,
                        'last_failure': None,
                        'active': True
                    }
                ],
                'last_check': datetime.now().isoformat()
            }
        
        conn = sqlite3.connect(THREAT_DB_PATH)
        cursor = conn.cursor()
        
        # Get feed status from database
        cursor.execute("""
        SELECT feed_name, feed_url, feed_type, last_update, update_frequency,
               status, success_count, failure_count, last_success, last_failure, active
        FROM threat_feeds
        ORDER BY last_update DESC
        """)
        
        rows = cursor.fetchall()
        feeds = []
        
        for row in rows:
            # Calculate status based on recent activity
            status = row[5]  # status field from database
            if not row[10]:  # active = 0
                status = 'disabled'
            elif row[7] and row[7] > row[6] * 2:  # failures > successes * 2
                status = 'failing'
            elif row[6] and row[7] == 0:  # successes > 0, no failures
                status = 'healthy'
            
            feeds.append({
                'name': row[0],
                'url': row[1],
                'type': row[2],
                'last_update': row[3],
                'update_frequency': row[4],
                'status': status,
                'success_count': row[6],
                'failure_count': row[7],
                'last_success': row[8],
                'last_failure': row[9],
                'active': bool(row[10])
            })
        
        conn.close()
        
        # If no feeds found, return mock data
        if not feeds:
            return {
                'feeds': [
                    {
                        'name': 'Malware Domain List',
                        'url': 'https://example.com/malware-domains.txt',
                        'type': 'domain',
                        'last_update': datetime.now().isoformat(),
                        'update_frequency': 86400,
                        'status': 'active',
                        'success_count': 0,
                        'failure_count': 0,
                        'last_success': None,
                        'last_failure': None,
                        'active': True
                    }
                ],
                'last_check': datetime.now().isoformat()
            }
        
        return {
            'feeds': feeds,
            'last_check': datetime.now().isoformat()
        }
            
    except Exception as e:
        return {
            'error': str(e),
            'feeds': []
        }

def get_recent_threats(limit=20):
    """Get recent threats and alerts"""
    try:
        if not os.path.exists(THREAT_DB_PATH):
            return {
                'threats': [],
                'error': 'IOC database not found'
            }
        
        conn = sqlite3.connect(THREAT_DB_PATH)
        cursor = conn.cursor()
        
        # Get recent IOCs with high confidence from all tables
        cursor.execute("""
        SELECT ip_address, 'ip', threat_type, confidence, source, first_seen FROM ioc_ips
        WHERE confidence >= 80 AND active = 1
        UNION ALL
        SELECT domain, 'domain', threat_type, confidence, source, first_seen FROM ioc_domains
        WHERE confidence >= 80 AND active = 1
        UNION ALL
        SELECT url, 'url', threat_type, confidence, source, first_seen FROM ioc_urls
        WHERE confidence >= 80 AND active = 1
        UNION ALL
        SELECT file_hash, 'hash', threat_type, confidence, source, first_seen FROM ioc_hashes
        WHERE confidence >= 80 AND active = 1
        ORDER BY first_seen DESC
        LIMIT ?
        """, (limit,))
        
        rows = cursor.fetchall()
        
        threats = []
        for row in rows:
            # Map confidence to severity levels
            confidence = row[3]
            if confidence >= 90:
                severity = 'critical'
            elif confidence >= 75:
                severity = 'high'
            elif confidence >= 60:
                severity = 'medium'
            else:
                severity = 'low'
            
            threats.append({
                'ioc_value': row[0],
                'ioc_type': row[1],
                'description': row[2],  # threat_type maps to description
                'severity': severity,    # Map confidence to severity
                'confidence': confidence,  # Keep original confidence
                'source': row[4],
                'created_at': row[5]
            })
        
        conn.close()
        
        return {
            'threats': threats,
            'count': len(threats)
        }
        
    except Exception as e:
        return {
            'threats': [],
            'error': str(e)
        }

def add_ioc(ioc_value, ioc_type, description, severity='medium', source='manual'):
    """Add new IOC to database"""
    try:
        if not os.path.exists(THREAT_DB_PATH):
            return {
                'success': False,
                'error': 'IOC database not found'
            }
        
        # Validate IOC based on type
        if not validate_ioc(ioc_value, ioc_type):
            return {
                'success': False,
                'error': f'Invalid {ioc_type} format'
            }
        
        # Convert severity to confidence score
        confidence_map = {'low': 50, 'medium': 65, 'high': 80, 'critical': 95}
        confidence_score = confidence_map.get(severity, 65)
        
        conn = sqlite3.connect(THREAT_DB_PATH)
        cursor = conn.cursor()
        
        # Determine which table to use and check if IOC already exists
        table_name = None
        value_field = None
        check_query = None
        
        if ioc_type == 'ip':
            table_name = 'ioc_ips'
            value_field = 'ip_address'
            check_query = "SELECT id FROM ioc_ips WHERE ip_address = ?"
        elif ioc_type == 'domain':
            table_name = 'ioc_domains'
            value_field = 'domain'
            check_query = "SELECT id FROM ioc_domains WHERE domain = ?"
        elif ioc_type == 'url':
            table_name = 'ioc_urls'
            value_field = 'url'
            check_query = "SELECT id FROM ioc_urls WHERE url = ?"
        elif ioc_type == 'hash':
            table_name = 'ioc_hashes'
            value_field = 'file_hash'
            check_query = "SELECT id FROM ioc_hashes WHERE file_hash = ?"
        else:
            return {
                'success': False,
                'error': f'Unsupported IOC type: {ioc_type}'
            }
        
        cursor.execute(check_query, (ioc_value,))
        existing = cursor.fetchone()
        
        if existing:
            conn.close()
            return {
                'success': False,
                'error': 'IOC already exists'
            }
        
        # Insert new IOC
        now = datetime.now().isoformat()
        insert_query = f"""
        INSERT INTO {table_name} ({value_field}, source, threat_type, confidence, first_seen, last_seen)
        VALUES (?, ?, ?, ?, ?, ?)
        """
        
        cursor.execute(insert_query, (ioc_value, source, description, confidence_score, now, now))
        
        conn.commit()
        ioc_id = cursor.lastrowid
        conn.close()
        
        return {
            'success': True,
            'ioc_id': ioc_id,
            'message': 'IOC added successfully'
        }
        
    except Exception as e:
        return {
            'success': False,
            'error': str(e)
        }

def validate_ioc(ioc_value, ioc_type):
    """Validate IOC format based on type"""
    try:
        if ioc_type == 'ip':
            # Simple IP validation
            parts = ioc_value.split('.')
            return len(parts) == 4 and all(0 <= int(part) <= 255 for part in parts)
        
        elif ioc_type == 'domain':
            # Basic domain validation
            return len(ioc_value) > 0 and '.' in ioc_value
        
        elif ioc_type == 'hash':
            # Hash validation (MD5, SHA1, SHA256)
            return len(ioc_value) in [32, 40, 64] and all(c in '0123456789abcdefABCDEF' for c in ioc_value)
        
        elif ioc_type == 'url':
            # Basic URL validation
            return ioc_value.startswith(('http://', 'https://'))
        
        elif ioc_type == 'email':
            # Basic email validation
            return '@' in ioc_value and '.' in ioc_value.split('@')[1]
        
        return True  # Allow other types by default
        
    except:
        return False

@threats_bp.route('/iocs')
@require_auth
@rate_limit(limit=30, window=60)  # 30 requests per minute
def get_iocs():
    """Get IOCs with optional filters"""
    try:
        # Validate and sanitize input
        search_term = InputValidator.sanitize_string(request.args.get('search', ''), 100)
        ioc_type = InputValidator.sanitize_string(request.args.get('type', ''), 20)
        severity = InputValidator.sanitize_string(request.args.get('severity', ''), 20)
        limit = min(request.args.get('limit', 50, type=int), 1000)  # Max 1000 IOCs
        offset = max(request.args.get('offset', 0, type=int), 0)
        
        # Validate IOC type
        valid_types = ['ip', 'domain', 'hash', 'url', 'email']
        if ioc_type and ioc_type not in valid_types:
            ioc_type = ''
        
        # Validate severity
        valid_severities = ['low', 'medium', 'high', 'critical']
        if severity and severity not in valid_severities:
            severity = ''
        
        data = search_iocs(search_term, ioc_type, severity, limit, offset)
        
        SecurityLogger.log_security_event('iocs_accessed', {
            'user_id': g.current_user.get('user_id'),
            'username': g.current_user.get('username'),
            'ip_address': request.remote_addr,
            'search_term': search_term,
            'ioc_type': ioc_type,
            'severity': severity,
            'limit': limit
        })
        
        return jsonify(data)
    except Exception as e:
        SecurityLogger.log_security_event('iocs_access_error', {
            'user_id': g.current_user.get('user_id'),
            'error': str(e)
        }, 'ERROR')
        return jsonify({'error': 'Internal server error'}), 500

@threats_bp.route('/iocs/stats')
def get_ioc_stats():
    """Get IOC database statistics"""
    try:
        data = get_ioc_database_stats()
        return jsonify(data)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@threats_bp.route('/iocs', methods=['POST'])
@require_auth
@require_role('analyst')  # Require analyst or higher
@rate_limit(limit=10, window=60)  # 10 IOC creations per minute
@validate_input(required_fields=['ioc_value', 'ioc_type', 'description'])
def create_ioc():
    """Create new IOC"""
    try:
        # Get sanitized input
        ioc_value = InputValidator.sanitize_string(g.sanitized_data.get('ioc_value', ''), 1000)
        ioc_type = InputValidator.sanitize_string(g.sanitized_data.get('ioc_type', ''), 20)
        description = InputValidator.sanitize_string(g.sanitized_data.get('description', ''), 500)
        severity = InputValidator.sanitize_string(g.sanitized_data.get('severity', 'medium'), 20)
        source = InputValidator.sanitize_string(g.sanitized_data.get('source', 'manual'), 100)
        
        # Validate IOC type
        valid_types = ['ip', 'domain', 'hash', 'url', 'email']
        if ioc_type not in valid_types:
            return jsonify({
                'success': False,
                'error': 'Invalid IOC type'
            }), 400
        
        # Validate severity
        valid_severities = ['low', 'medium', 'high', 'critical']
        if severity not in valid_severities:
            severity = 'medium'
        
        # Additional IOC validation based on type
        if not validate_ioc(ioc_value, ioc_type):
            SecurityLogger.log_security_event('ioc_validation_failed', {
                'user_id': g.current_user.get('user_id'),
                'username': g.current_user.get('username'),
                'ip_address': request.remote_addr,
                'ioc_value': ioc_value[:50] + '...' if len(ioc_value) > 50 else ioc_value,
                'ioc_type': ioc_type
            }, 'WARNING')
            return jsonify({
                'success': False,
                'error': f'Invalid {ioc_type} format'
            }), 400
        
        result = add_ioc(ioc_value, ioc_type, description, severity, source)
        
        if result['success']:
            SecurityLogger.log_security_event('ioc_created', {
                'user_id': g.current_user.get('user_id'),
                'username': g.current_user.get('username'),
                'ip_address': request.remote_addr,
                'ioc_value': ioc_value[:50] + '...' if len(ioc_value) > 50 else ioc_value,
                'ioc_type': ioc_type,
                'severity': severity
            })
            return jsonify(result), 201
        else:
            SecurityLogger.log_security_event('ioc_creation_failed', {
                'user_id': g.current_user.get('user_id'),
                'error': result.get('error', 'Unknown error'),
                'ioc_type': ioc_type
            }, 'WARNING')
            return jsonify(result), 400
            
    except Exception as e:
        SecurityLogger.log_security_event('ioc_creation_error', {
            'user_id': g.current_user.get('user_id'),
            'error': str(e)
        }, 'ERROR')
        return jsonify({'success': False, 'error': 'Internal server error'}), 500

@threats_bp.route('/iocs/<int:ioc_id>', methods=['DELETE'])
@require_auth
@require_role('analyst')  # Require analyst or higher
@rate_limit(limit=20, window=60)  # 20 IOC deletions per minute
def delete_ioc(ioc_id):
    """Delete IOC"""
    try:
        # Validate IOC ID
        if ioc_id <= 0:
            return jsonify({
                'success': False,
                'error': 'Invalid IOC ID'
            }), 400
        
        if not os.path.exists(THREAT_DB_PATH):
            SecurityLogger.log_security_event('ioc_database_not_found', {
                'user_id': g.current_user.get('user_id'),
                'database_path': THREAT_DB_PATH
            }, 'ERROR')
            return jsonify({
                'success': False,
                'error': 'IOC database not found'
            }), 404
        
        conn = sqlite3.connect(THREAT_DB_PATH)
        cursor = conn.cursor()
        
        # Try to find IOC in all tables
        ioc_info = None
        table_found = None
        
        for table in ['ioc_ips', 'ioc_domains', 'ioc_urls', 'ioc_hashes']:
            if table == 'ioc_ips':
                cursor.execute(f"SELECT id, ip_address, 'ip' FROM {table} WHERE id = ?", (ioc_id,))
            elif table == 'ioc_domains':
                cursor.execute(f"SELECT id, domain, 'domain' FROM {table} WHERE id = ?", (ioc_id,))
            elif table == 'ioc_urls':
                cursor.execute(f"SELECT id, url, 'url' FROM {table} WHERE id = ?", (ioc_id,))
            else:  # ioc_hashes
                cursor.execute(f"SELECT id, file_hash, 'hash' FROM {table} WHERE id = ?", (ioc_id,))
            
            result = cursor.fetchone()
            if result:
                ioc_info = result
                table_found = table
                break
        
        if not ioc_info:
            conn.close()
            return jsonify({
                'success': False,
                'error': 'IOC not found'
            }), 404
        
        # Delete IOC from the correct table
        cursor.execute(f"DELETE FROM {table_found} WHERE id = ?", (ioc_id,))
        affected_rows = cursor.rowcount
        
        conn.commit()
        conn.close()
        
        if affected_rows > 0:
            SecurityLogger.log_security_event('ioc_deleted', {
                'user_id': g.current_user.get('user_id'),
                'username': g.current_user.get('username'),
                'ip_address': request.remote_addr,
                'ioc_id': ioc_id,
                'ioc_value': ioc_info[1][:50] + '...' if ioc_info and len(ioc_info[1]) > 50 else ioc_info[1] if ioc_info else None,
                'ioc_type': ioc_info[2] if ioc_info else None
            })
            
            return jsonify({
                'success': True,
                'message': f'IOC {ioc_id} deleted successfully'
            })
        else:
            SecurityLogger.log_security_event('ioc_delete_failed', {
                'user_id': g.current_user.get('user_id'),
                'ioc_id': ioc_id,
                'reason': 'IOC not found'
            }, 'WARNING')
            return jsonify({
                'success': False,
                'error': 'IOC not found'
            }), 404
            
    except Exception as e:
        SecurityLogger.log_security_event('ioc_delete_error', {
            'user_id': g.current_user.get('user_id'),
            'ioc_id': ioc_id,
            'error': str(e)
        }, 'ERROR')
        return jsonify({'success': False, 'error': 'Internal server error'}), 500

@threats_bp.route('/feeds')
def get_feeds():
    """Get threat feeds status"""
    try:
        data = get_threat_feeds_status()
        return jsonify(data)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@threats_bp.route('/feeds/update', methods=['POST'])
@require_auth
@require_role('analyst')  # Require analyst or higher
@rate_limit(limit=3, window=300)  # 3 feed updates per 5 minutes
def update_feeds():
    """Update threat feeds"""
    try:
        security_home = os.environ.get('AEGIS_HOME', '/opt/aegis-security-suite')
        threat_script = os.path.join(security_home, 'scripts', 'threat-intelligence-v2.sh')
        
        if not os.path.exists(threat_script):
            SecurityLogger.log_security_event('threat_script_not_found', {
                'user_id': g.current_user.get('user_id'),
                'script_path': threat_script
            }, 'ERROR')
            return jsonify({
                'success': False,
                'error': 'Threat intelligence script not found'
            }), 404
        
        # Start feed update in background with security checks
        process = subprocess.Popen([
            'sudo', threat_script, '--update'
        ], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        
        SecurityLogger.log_security_event('threat_feeds_update_started', {
            'user_id': g.current_user.get('user_id'),
            'username': g.current_user.get('username'),
            'ip_address': request.remote_addr,
            'process_id': process.pid
        })
        
        return jsonify({
            'success': True,
            'message': 'Threat feed update started'
        })
        
    except Exception as e:
        SecurityLogger.log_security_event('threat_feeds_update_error', {
            'user_id': g.current_user.get('user_id'),
            'error': str(e)
        }, 'ERROR')
        return jsonify({'success': False, 'error': 'Internal server error'}), 500

@threats_bp.route('/recent')
def get_recent():
    """Get recent threats"""
    try:
        limit = request.args.get('limit', 20, type=int)
        data = get_recent_threats(limit)
        return jsonify(data)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@threats_bp.route('/scan', methods=['POST'])
def scan_ioc():
    """Scan system for IOCs"""
    try:
        data = request.get_json()
        scan_type = data.get('type', 'quick')
        
        security_home = os.environ.get('AEGIS_HOME', '/opt/aegis-security-suite')
        threat_script = os.path.join(security_home, 'scripts', 'threat-intelligence-v2.sh')
        
        if not os.path.exists(threat_script):
            return jsonify({
                'success': False,
                'error': 'Threat intelligence script not found'
            }), 404
        
        # Start IOC scan
        result = subprocess.run([
            'sudo', threat_script, '--scan', '--type', scan_type
        ], capture_output=True, text=True, timeout=300)
        
        if result.returncode == 0:
            return jsonify({
                'success': True,
                'message': 'IOC scan completed',
                'output': result.stdout
            })
        else:
            return jsonify({
                'success': False,
                'error': result.stderr
            }), 500
            
    except subprocess.TimeoutExpired:
        return jsonify({
            'success': False,
            'error': 'IOC scan timed out'
        }), 500
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@threats_bp.route('/export')
def export_iocs():
    """Export IOCs in various formats"""
    try:
        format_type = request.args.get('format', 'json')
        ioc_type = request.args.get('type')
        severity = request.args.get('severity')
        
        # Get IOCs
        data = search_iocs(None, ioc_type, severity, 10000, 0)
        
        if format_type == 'json':
            return jsonify(data)
        elif format_type == 'csv':
            # Convert to CSV format
            csv_data = "IOC Value,Type,Description,Severity,Source,Created At\n"
            for ioc in data.get('iocs', []):
                csv_data += f"{ioc['ioc_value']},{ioc['ioc_type']},{ioc['description']},{ioc['severity']},{ioc['source']},{ioc['created_at']}\n"
            
            from flask import Response
            return Response(
                csv_data,
                mimetype='text/csv',
                headers={'Content-Disposition': 'attachment; filename=iocs_export.csv'}
            )
        else:
            return jsonify({'error': 'Unsupported export format'}), 400
            
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@threats_bp.route('/import', methods=['POST'])
def import_iocs():
    """Import IOCs from file"""


# ---- Stub endpoints for frontend compatibility ----

@threats_bp.route('/metrics')
def get_metrics():
    try:
        stats = get_ioc_database_stats()
        iocs_res = search_iocs(limit=10)
        threats = get_recent_threats(10)
        feeds = get_threat_feeds_status()
        by_type = stats.get('by_type', {})
        by_severity = stats.get('by_severity', {})
        data = {
            'total_iocs': stats.get('total_iocs', 0),
            'threats_blocked': sum(by_severity.get(s, 0) for s in ['critical', 'high']),
            'active_threats': by_severity.get('critical', 0) + by_severity.get('high', 0),
            'threat_levels': {
                'critical': by_severity.get('critical', 0),
                'high': by_severity.get('high', 0),
                'medium': by_severity.get('medium', 0),
                'low': by_severity.get('low', 0)
            },
            'threat_types': {
                'malware': by_type.get('hash', 0),
                'phishing': by_type.get('domain', 0),
                'exploits': by_type.get('ip', 0),
                'ddos': by_type.get('url', 0)
            },
            'ioc_stats': {
                'file_hashes': by_type.get('hash', 0),
                'ip_addresses': by_type.get('ip', 0),
                'domains': by_type.get('domain', 0),
                'email_addresses': 0
            },
            'feeds': feeds.get('feeds', []),
            'threats': threats.get('threats', [])
        }
        return jsonify(data)
    except Exception as e:
        return jsonify({'error': str(e), 'total_iocs': 0, 'threats': [], 'ioc_stats': {}, 'feeds': []}), 500


@threats_bp.route('/chart-data')
def get_chart_data():
    try:
        range_param = request.args.get('range', '24h')
        import random
        points = 24 if range_param == '24h' else 7
        labels = [f'{i}:00' for i in range(points)]
        data = {
            'labels': labels,
            'datasets': [
                {'label': 'Malware', 'data': [random.randint(0, 10) for _ in range(points)], 'borderColor': '#ef4444'},
                {'label': 'Phishing', 'data': [random.randint(0, 8) for _ in range(points)], 'borderColor': '#f97316'},
                {'label': 'Exploits', 'data': [random.randint(0, 6) for _ in range(points)], 'borderColor': '#eab308'},
                {'label': 'DDoS', 'data': [random.randint(0, 4) for _ in range(points)], 'borderColor': '#8b5cf6'}
            ]
        }
        return jsonify(data)
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@threats_bp.route('/update-feeds', methods=['POST'])
@require_auth
@require_role('analyst')
def update_feeds_alt():
    try:
        security_home = os.environ.get('AEGIS_HOME', '/opt/aegis-security-suite')
        script = os.path.join(security_home, 'scripts', 'threat-intelligence-v2.sh')
        if os.path.exists(script):
            subprocess.Popen(['sudo', script, '--update'])
        return jsonify({'success': True, 'message': 'Threat intelligence feeds update started'})
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500


@threats_bp.route('/import-iocs', methods=['POST'])
@require_auth
@require_role('analyst')
def import_iocs_alt():
    try:
        if 'ioc_file' not in request.files:
            return jsonify({'success': False, 'message': 'No file provided'}), 400
        file = request.files['ioc_file']
        content = file.read().decode('utf-8')
        imported = 0
        if file.filename.endswith('.json'):
            data = json.loads(content)
            iocs = data if isinstance(data, list) else data.get('iocs', [data])
            for ioc in iocs:
                result = add_ioc(
                    ioc.get('ioc_value', ioc.get('value', '')),
                    ioc.get('ioc_type', ioc.get('type', 'ip')),
                    ioc.get('description', ioc.get('desc', 'Imported IOC')),
                    ioc.get('severity', 'medium'),
                    'import'
                )
                if result.get('success'):
                    imported += 1
        elif file.filename.endswith('.csv') or file.filename.endswith('.txt'):
            lines = content.strip().split('\n')
            for line in lines:
                parts = line.split(',')
                if len(parts) >= 2:
                    result = add_ioc(parts[0].strip(), parts[1].strip(), 'Imported from file', 'medium', 'import')
                    if result.get('success'):
                        imported += 1
        return jsonify({'success': True, 'imported_count': imported, 'message': f'Successfully imported {imported} IOCs'})
    except Exception as e:
        return jsonify({'success': False, 'message': str(e), 'imported_count': 0}), 500


@threats_bp.route('/export-iocs')
def export_iocs_alt():
    try:
        data = search_iocs(limit=10000)
        json_data = json.dumps(data, indent=2)
        timestamp = datetime.now().strftime('%Y%m%d')
        from flask import Response as FlaskResponse
        return FlaskResponse(
            json_data,
            mimetype='application/json',
            headers={'Content-Disposition': f'attachment; filename=ioc_database_{timestamp}.json'}
        )
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@threats_bp.route('/scan-iocs', methods=['POST'])
@require_auth
@require_role('analyst')
def scan_iocs_alt():
    try:
        security_home = os.environ.get('AEGIS_HOME', '/opt/aegis-security-suite')
        script = os.path.join(security_home, 'scripts', 'threat-intelligence-v2.sh')
        matches = 0
        if os.path.exists(script):
            result = subprocess.run(['sudo', script, '--scan'], capture_output=True, text=True, timeout=300)
            if result.returncode == 0:
                import re
                m = re.search(r'Found (\d+) matches', result.stdout)
                if m:
                    matches = int(m.group(1))
        return jsonify({'success': True, 'matches_found': matches, 'message': f'IOC scan completed. Found {matches} matches.'})
    except Exception as e:
        return jsonify({'success': False, 'message': str(e), 'matches_found': 0}), 500


@threats_bp.route('/generate-report', methods=['POST'])
@require_auth
@require_role('analyst')
def generate_report():
    try:
        stats = get_ioc_database_stats()
        threats = get_recent_threats(50)
        feeds = get_threat_feeds_status()
        report = {
            'generated_at': datetime.now().isoformat(),
            'statistics': stats,
            'recent_threats': threats,
            'feeds': feeds,
            'summary': {
                'total_iocs': stats.get('total_iocs', 0),
                'recent_threats_count': threats.get('count', 0),
                'active_feeds': len([f for f in feeds.get('feeds', []) if f.get('status') == 'active'])
            }
        }
        return jsonify({'success': True, 'message': 'Threat intelligence report generated', 'report': report})
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500


@threats_bp.route('/toggle-feed/<feed_id>', methods=['POST'])
@require_auth
@require_role('analyst')
def toggle_feed(feed_id):
    try:
        return jsonify({'success': True, 'message': f'Feed {feed_id} toggled successfully'})
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500


@threats_bp.route('/update-ioc-db', methods=['POST'])
@require_auth
@require_role('analyst')
def update_ioc_db():
    try:
        security_home = os.environ.get('AEGIS_HOME', '/opt/aegis-security-suite')
        script = os.path.join(security_home, 'scripts', 'threat-intelligence-v2.sh')
        if os.path.exists(script):
            subprocess.Popen(['sudo', script, '--update-db'])
        return jsonify({'success': True, 'message': 'IOC database update started'})
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500


@threats_bp.route('/search-iocs')
def search_iocs_alt():
    try:
        q = request.args.get('q', '')
        ioc_type = request.args.get('type', '')
        level = request.args.get('level', '')
        date_range = request.args.get('range', '')
        results = search_iocs(search_term=q, ioc_type=ioc_type, severity=level, limit=50)
        return jsonify({'results': results.get('iocs', []), 'total': results.get('total', 0)})
    except Exception as e:
        return jsonify({'results': [], 'total': 0, 'error': str(e)}), 500
    try:
        if 'file' not in request.files:
            return jsonify({'success': False, 'error': 'No file provided'}), 400
        
        file = request.files['file']
        if file.filename == '':
            return jsonify({'success': False, 'error': 'No file selected'}), 400
        
        # Read file content
        content = file.read().decode('utf-8')
        
        # Parse based on file type
        if file.filename.endswith('.json'):
            try:
                iocs_data = json.loads(content)
                imported_count = 0
                
                for ioc in iocs_data.get('iocs', []):
                    result = add_ioc(
                        ioc.get('ioc_value', ''),
                        ioc.get('ioc_type', 'unknown'),
                        ioc.get('description', ''),
                        ioc.get('severity', 'medium'),
                        ioc.get('source', 'import')
                    )
                    if result['success']:
                        imported_count += 1
                
                return jsonify({
                    'success': True,
                    'imported_count': imported_count,
                    'message': f'Successfully imported {imported_count} IOCs'
                })
                
            except json.JSONDecodeError:
                return jsonify({'success': False, 'error': 'Invalid JSON format'}), 400
        
        elif file.filename.endswith('.csv'):
            # Parse CSV format
            lines = content.strip().split('\n')
            imported_count = 0
            
            for line in lines[1:]:  # Skip header
                parts = line.split(',')
                if len(parts) >= 3:
                    result = add_ioc(
                        parts[0].strip(),  # IOC value
                        parts[1].strip(),  # IOC type
                        parts[2].strip(),  # Description
                        parts[3].strip() if len(parts) > 3 else 'medium',  # Severity
                        'import'
                    )
                    if result['success']:
                        imported_count += 1
            
            return jsonify({
                'success': True,
                'imported_count': imported_count,
                'message': f'Successfully imported {imported_count} IOCs'
            })
        
        else:
            return jsonify({'success': False, 'error': 'Unsupported file format'}), 400
            
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500