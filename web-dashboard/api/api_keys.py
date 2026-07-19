#!/usr/bin/env python3
"""
API Key Management Module for Aegis Security Suite Dashboard
Provides API key creation, management, and authentication endpoints
"""

import os
import json
import sqlite3
from datetime import datetime, timedelta
from flask import Blueprint, jsonify, request, g

# Import security utilities
from security_utils import (
    SecurityLogger, InputValidator, rate_limiter, api_key_manager,
    require_api_key, rate_limit, validate_input, secure_headers
)
from auth import require_auth, require_role

# Create Blueprint
api_keys_bp = Blueprint('api_keys', __name__, url_prefix='/api/keys')

@api_keys_bp.route('/', methods=['GET'])
@require_auth
@require_role('admin')  # Only admins can manage API keys
@rate_limit(limit=10, window=60)  # 10 requests per minute
def list_api_keys():
    """List all API keys"""
    try:
        # Ensure database exists and get connection
        api_key_manager.ensure_db()
        conn = sqlite3.connect(api_key_manager.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
        SELECT key_name, permissions, is_active, created_at, last_used, usage_count
        FROM api_keys
        ORDER BY created_at DESC
        """)
        
        keys = []
        for row in cursor.fetchall():
            keys.append({
                'key_name': row[0],
                'permissions': json.loads(row[1]) if row[1] else [],
                'is_active': bool(row[2]),
                'created_at': row[3],
                'last_used': row[4],
                'usage_count': row[5]
            })
        
        conn.close()
        
        SecurityLogger.log_security_event('api_keys_listed', {
            'user_id': g.current_user.get('user_id'),
            'username': g.current_user.get('username'),
            'ip_address': request.remote_addr
        })
        
        return jsonify({
            'api_keys': keys,
            'total': len(keys)
        })
        
    except Exception as e:
        SecurityLogger.log_security_event('api_keys_list_error', {
            'user_id': g.current_user.get('user_id'),
            'error': str(e)
        }, 'ERROR')
        return jsonify({'error': 'Internal server error'}), 500

@api_keys_bp.route('/', methods=['POST'])
@require_auth
@require_role('admin')  # Only admins can create API keys
@rate_limit(limit=5, window=300)  # 5 API key creations per 5 minutes
@validate_input(required_fields=['key_name', 'permissions'])
def create_api_key():
    """Create new API key"""
    try:
        # Get sanitized input
        key_name = InputValidator.sanitize_string(g.sanitized_data.get('key_name', ''), 100)
        permissions = g.sanitized_data.get('permissions', [])
        expires_in_days = g.sanitized_data.get('expires_in_days', 90)  # Default 90 days
        
        # Validate key name
        if not key_name or len(key_name) < 3:
            return jsonify({
                'success': False,
                'error': 'Key name must be at least 3 characters long'
            }), 400
        
        # Validate expiration
        try:
            expires_in_days = int(expires_in_days)
            if expires_in_days < 1 or expires_in_days > 365:
                return jsonify({
                    'success': False,
                    'error': 'Expiration must be between 1 and 365 days'
                }), 400
        except ValueError:
            return jsonify({
                'success': False,
                'error': 'Invalid expiration value'
            }), 400
        
        # Validate permissions
        valid_permissions = [
            'read_system', 'write_system', 'read_incidents', 'write_incidents',
            'read_threats', 'write_threats', 'read_behavioral', 'write_behavioral',
            'admin_access'
        ]
        
        if not isinstance(permissions, list):
            return jsonify({
                'success': False,
                'error': 'Permissions must be a list'
            }), 400
        
        # Filter and validate permissions
        valid_permissions_list = []
        for perm in permissions:
            if perm in valid_permissions:
                valid_permissions_list.append(perm)
        
        if not valid_permissions_list:
            return jsonify({
                'success': False,
                'error': 'At least one valid permission is required'
            }), 400
        
        # Create API key with expiration
        result = api_key_manager.generate_api_key(
            key_name,
            valid_permissions_list,
            g.current_user.get('username'),
            expires_in_days=expires_in_days
        )
        
        if result['success']:
            SecurityLogger.log_security_event('api_key_created', {
                'user_id': g.current_user.get('user_id'),
                'username': g.current_user.get('username'),
                'ip_address': request.remote_addr,
                'key_name': key_name,
                'permissions': valid_permissions_list,
                'expires_in_days': expires_in_days
            })
            
            return jsonify(result), 201
        else:
            SecurityLogger.log_security_event('api_key_creation_failed', {
                'user_id': g.current_user.get('user_id'),
                'key_name': key_name,
                'error': result.get('error', 'Unknown error')
            }, 'WARNING')
            return jsonify(result), 400
            
    except Exception as e:
        SecurityLogger.log_security_event('api_key_creation_error', {
            'user_id': g.current_user.get('user_id'),
            'key_name': key_name,
            'error': str(e)
        }, 'ERROR')
        return jsonify({'success': False, 'error': 'Internal server error'}), 500

@api_keys_bp.route('/<key_name>', methods=['DELETE'])
@require_auth
@require_role('admin')  # Only admins can revoke API keys
@rate_limit(limit=10, window=60)  # 10 API key revocations per minute
def revoke_api_key(key_name):
    """Revoke API key"""
    try:
        # Validate key name
        key_name = InputValidator.sanitize_string(key_name, 100)
        
        if not key_name:
            return jsonify({
                'success': False,
                'error': 'Invalid key name'
            }), 400
        
        result = api_key_manager.revoke_api_key(key_name)
        
        if result['success']:
            SecurityLogger.log_security_event('api_key_revoked', {
                'user_id': g.current_user.get('user_id'),
                'username': g.current_user.get('username'),
                'ip_address': request.remote_addr,
                'key_name': key_name
            })
            
            return jsonify(result)
        else:
            SecurityLogger.log_security_event('api_key_revocation_failed', {
                'user_id': g.current_user.get('user_id'),
                'key_name': key_name,
                'error': result.get('error', 'Unknown error')
            }, 'WARNING')
            return jsonify(result), 400
            
    except Exception as e:
        SecurityLogger.log_security_event('api_key_revocation_error', {
            'user_id': g.current_user.get('user_id'),
            'key_name': key_name,
            'error': str(e)
        }, 'ERROR')
        return jsonify({'success': False, 'error': 'Internal server error'}), 500

@api_keys_bp.route('/<key_name>/rotate', methods=['POST'])
@require_auth
@require_role('admin')  # Only admins can rotate API keys
@rate_limit(limit=5, window=300)  # 5 API key rotations per 5 minutes
def rotate_api_key(key_name):
    """Rotate API key (generate new key, invalidate old one)"""
    try:
        # Validate key name
        key_name = InputValidator.sanitize_string(key_name, 100)
        
        if not key_name:
            return jsonify({
                'success': False,
                'error': 'Invalid key name'
            }), 400
        
        result = api_key_manager.rotate_api_key(key_name, g.current_user.get('username'))
        
        if result['success']:
            SecurityLogger.log_security_event('api_key_rotated', {
                'user_id': g.current_user.get('user_id'),
                'username': g.current_user.get('username'),
                'ip_address': request.remote_addr,
                'key_name': key_name
            })
            
            return jsonify(result)
        else:
            SecurityLogger.log_security_event('api_key_rotation_failed', {
                'user_id': g.current_user.get('user_id'),
                'key_name': key_name,
                'error': result.get('error', 'Unknown error')
            }, 'WARNING')
            return jsonify(result), 400
            
    except Exception as e:
        SecurityLogger.log_security_event('api_key_rotation_error', {
            'user_id': g.current_user.get('user_id'),
            'key_name': key_name,
            'error': str(e)
        }, 'ERROR')
        return jsonify({'success': False, 'error': 'Internal server error'}), 500

@api_keys_bp.route('/expired', methods=['GET'])
@require_auth
@require_role('admin')  # Only admins can view expired keys
@rate_limit(limit=5, window=60)  # 5 requests per minute
def get_expired_keys():
    """Get expired API keys"""
    try:
        result = api_key_manager.get_expired_keys()
        
        SecurityLogger.log_security_event('expired_keys_accessed', {
            'user_id': g.current_user.get('user_id'),
            'username': g.current_user.get('username'),
            'ip_address': request.remote_addr
        })
        
        return jsonify(result)
            
    except Exception as e:
        SecurityLogger.log_security_event('expired_keys_error', {
            'user_id': g.current_user.get('user_id'),
            'error': str(e)
        }, 'ERROR')
        return jsonify({'success': False, 'error': 'Internal server error'}), 500

@api_keys_bp.route('/usage')
@require_auth
@require_role('admin')  # Only admins can view API key usage
@rate_limit(limit=5, window=60)  # 5 usage requests per minute
def get_api_key_usage():
    """Get API key usage statistics"""
    try:
        # Ensure database exists and get connection
        api_key_manager.ensure_db()
        conn = sqlite3.connect(api_key_manager.db_path)
        cursor = conn.cursor()
        
        # Get recent API key usage
        cursor.execute("""
        SELECT ak.key_name, aku.ip_address, aku.endpoint, aku.user_agent, aku.timestamp
        FROM api_key_usage aku
        JOIN api_keys ak ON aku.api_key_id = ak.id
        WHERE aku.timestamp > datetime('now', '-7 days')
        ORDER BY aku.timestamp DESC
        LIMIT 100
        """)
        
        usage = []
        for row in cursor.fetchall():
            usage.append({
                'key_name': row[0],
                'ip_address': row[1],
                'endpoint': row[2],
                'user_agent': row[3],
                'timestamp': row[4]
            })
        
        # Get usage statistics by key
        cursor.execute("""
        SELECT ak.key_name, COUNT(*) as usage_count, MAX(aku.timestamp) as last_used
        FROM api_keys ak
        LEFT JOIN api_key_usage aku ON ak.id = aku.api_key_id
        WHERE aku.timestamp > datetime('now', '-7 days') OR aku.timestamp IS NULL
        GROUP BY ak.key_name
        ORDER BY usage_count DESC
        """)
        
        stats = {}
        for row in cursor.fetchall():
            stats[row[0]] = {
                'usage_count': row[1],
                'last_used': row[2]
            }
        
        conn.close()
        
        SecurityLogger.log_security_event('api_key_usage_accessed', {
            'user_id': g.current_user.get('user_id'),
            'username': g.current_user.get('username'),
            'ip_address': request.remote_addr
        })
        
        return jsonify({
            'recent_usage': usage,
            'statistics': stats,
            'timestamp': datetime.now().isoformat()
        })
        
    except Exception as e:
        SecurityLogger.log_security_event('api_key_usage_error', {
            'user_id': g.current_user.get('user_id'),
            'error': str(e)
        }, 'ERROR')
        return jsonify({'error': 'Internal server error'}), 500

@api_keys_bp.route('/validate', methods=['POST'])
@rate_limit(limit=20, window=60)  # 20 validations per minute
@validate_input(required_fields=['api_key'])
def validate_api_key_endpoint():
    """Validate API key (for external testing)"""
    try:
        api_key = InputValidator.sanitize_string(g.sanitized_data.get('api_key', ''), 100)
        
        if not api_key:
            return jsonify({
                'valid': False,
                'error': 'API key is required'
            }), 400
        
        # Validate the API key
        key_info = api_key_manager.validate_api_key(api_key)
        
        if key_info:
            return jsonify({
                'valid': True,
                'key_info': {
                    'key_name': key_info['key_name'],
                    'permissions': key_info['permissions']
                }
            })
        else:
            return jsonify({
                'valid': False,
                'error': 'Invalid or expired API key'
            })
            
    except Exception as e:
        SecurityLogger.log_security_event('api_key_validation_error', {
            'error': str(e)
        }, 'ERROR')
        return jsonify({'error': 'Internal server error'}), 500