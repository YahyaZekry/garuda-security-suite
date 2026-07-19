#!/usr/bin/env python3
"""
Security Utilities Module for Aegis Security Suite Dashboard
Provides comprehensive security functions including input validation, rate limiting,
API key management, and security logging
"""

import os
import re
import hashlib
import secrets
import time
import json
import sqlite3
import logging
import bcrypt
from datetime import datetime, timedelta
from functools import wraps
from flask import request, jsonify, g, current_app
import bleach
from typing import Dict, List, Optional, Tuple, Any

# Configure security logging
security_logger = logging.getLogger('aegis_security')
security_logger.setLevel(logging.INFO)

# Create file handler for security logs
if not security_logger.handlers:
    log_dir = os.path.join(os.environ.get('AEGIS_HOME', '/opt/aegis-security-suite'), 'logs')
    os.makedirs(log_dir, exist_ok=True)
    
    file_handler = logging.FileHandler(os.path.join(log_dir, 'security.log'))
    file_handler.setLevel(logging.INFO)
    formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
    file_handler.setFormatter(formatter)
    security_logger.addHandler(file_handler)

class InputValidator:
    """Comprehensive input validation and sanitization"""
    
    @staticmethod
    def sanitize_string(input_string: str, max_length: int = 1000) -> str:
        """Sanitize string input"""
        if not input_string:
            return ""
        
        # Limit length
        if len(input_string) > max_length:
            input_string = input_string[:max_length]
        
        # Remove potentially dangerous characters
        sanitized = bleach.clean(
            input_string,
            tags=[],
            attributes={},
            strip=True
        )
        
        return sanitized.strip()
    
    @staticmethod
    def validate_email(email: str) -> bool:
        """Validate email format"""
        if not email:
            return False
        
        pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        return re.match(pattern, email) is not None
    
    @staticmethod
    def validate_username(username: str) -> bool:
        """Validate username format"""
        if not username or len(username) < 3 or len(username) > 50:
            return False
        
        # Only allow alphanumeric characters, underscores, and hyphens
        pattern = r'^[a-zA-Z0-9_-]+$'
        return re.match(pattern, username) is not None
    
    @staticmethod
    def validate_ip_address(ip: str) -> bool:
        """Validate IP address format"""
        if not ip:
            return False
        
        # IPv4 validation
        ipv4_pattern = r'^^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'
        if re.match(ipv4_pattern, ip):
            return True
        
        # IPv6 validation (simplified)
        ipv6_pattern = r'^(?:[0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$'
        return re.match(ipv6_pattern, ip) is not None
    
    @staticmethod
    def validate_json_structure(data: Any, required_fields: List[str]) -> Tuple[bool, str]:
        """Validate JSON structure and required fields"""
        if not isinstance(data, dict):
            return False, "Invalid JSON structure"
        
        missing_fields = [field for field in required_fields if field not in data]
        if missing_fields:
            return False, f"Missing required fields: {', '.join(missing_fields)}"
        
        return True, ""
    
    @staticmethod
    def sanitize_filename(filename: str) -> str:
        """Sanitize filename to prevent path traversal"""
        if not filename:
            return ""
        
        # Remove path separators and dangerous characters
        sanitized = re.sub(r'[<>:"/\\|?*]', '', filename)
        sanitized = re.sub(r'\.\.', '', sanitized)  # Remove path traversal
        sanitized = sanitized.strip()
        
        # Limit length
        if len(sanitized) > 255:
            sanitized = sanitized[:255]
        
        return sanitized

class RateLimiter:
    """Rate limiting implementation for API endpoints"""
    
    def __init__(self, db_path: str):
        self.db_path = db_path
        self.ensure_db()
    
    def ensure_db(self):
        """Ensure rate limiting database exists"""
        os.makedirs(os.path.dirname(self.db_path), exist_ok=True)
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS rate_limits (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ip_address TEXT NOT NULL,
            endpoint TEXT NOT NULL,
            request_count INTEGER DEFAULT 1,
            window_start TEXT NOT NULL,
            created_at TEXT NOT NULL
        )
        """)
        
        cursor.execute("""
        CREATE INDEX IF NOT EXISTS idx_rate_limits_ip_endpoint 
        ON rate_limits(ip_address, endpoint)
        """)
        
        conn.commit()
        conn.close()
    
    def is_allowed(self, ip_address: str, endpoint: str, limit: int = 100, window: int = 60) -> Tuple[bool, Dict]:
        """Check if request is allowed based on rate limit"""
        now = datetime.now()
        window_start = (now - timedelta(seconds=window)).isoformat()
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Clean old entries
        cursor.execute("DELETE FROM rate_limits WHERE window_start < ?", (window_start,))
        
        # Check current rate
        cursor.execute("""
        SELECT request_count, window_start FROM rate_limits 
        WHERE ip_address = ? AND endpoint = ? AND window_start >= ?
        ORDER BY window_start DESC LIMIT 1
        """, (ip_address, endpoint, window_start))
        
        result = cursor.fetchone()
        
        if result:
            request_count, current_window_start = result
            if request_count >= limit:
                conn.close()
                return False, {
                    'error': 'Rate limit exceeded',
                    'limit': limit,
                    'window': window,
                    'current_count': request_count,
                    'retry_after': window
                }
            else:
                # Atomic increment guarded by the count check in the WHERE
                # clause, so a concurrent request that already pushed the
                # count to the limit is not double-admitted (TOCTOU-safe).
                cursor.execute("""
                UPDATE rate_limits SET request_count = request_count + 1
                WHERE ip_address = ? AND endpoint = ? AND window_start = ? AND request_count < ?
                """, (ip_address, endpoint, current_window_start, limit))
                if cursor.rowcount == 0:
                    conn.close()
                    return False, {
                        'error': 'Rate limit exceeded',
                        'limit': limit,
                        'window': window,
                        'current_count': limit,
                        'retry_after': window
                    }
                new_count = request_count + 1
        else:
            # Create new record
            cursor.execute("""
            INSERT INTO rate_limits (ip_address, endpoint, request_count, window_start, created_at)
            VALUES (?, ?, 1, ?, ?)
            """, (ip_address, endpoint, now.isoformat(), now.isoformat()))
            new_count = 1

        conn.commit()
        conn.close()

        return True, {'remaining': limit - new_count}

class APIKeyManager:
    """API key management for external integrations"""
    
    def __init__(self, db_path: str):
        self.db_path = db_path
        self.ensure_db()
    
    def ensure_db(self):
        """Ensure API keys database exists"""
        os.makedirs(os.path.dirname(self.db_path), exist_ok=True)
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS api_keys (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            key_name TEXT NOT NULL UNIQUE,
            api_key TEXT NOT NULL UNIQUE,
            permissions TEXT NOT NULL,
            is_active BOOLEAN DEFAULT 1,
            created_at TEXT NOT NULL,
            expires_at TEXT,
            last_used TEXT,
            usage_count INTEGER DEFAULT 0,
            created_by TEXT,
            rotation_required BOOLEAN DEFAULT 0
        )
        """)
        
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS api_key_usage (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            api_key_id INTEGER NOT NULL,
            ip_address TEXT,
            endpoint TEXT,
            user_agent TEXT,
            timestamp TEXT NOT NULL,
            FOREIGN KEY (api_key_id) REFERENCES api_keys (id)
        )
        """)
        
        # Add new columns if they don't exist (for backward compatibility)
        try:
            cursor.execute("ALTER TABLE api_keys ADD COLUMN expires_at TEXT")
        except sqlite3.OperationalError:
            pass  # Column already exists
        
        try:
            cursor.execute("ALTER TABLE api_keys ADD COLUMN rotation_required BOOLEAN DEFAULT 0")
        except sqlite3.OperationalError:
            pass  # Column already exists
        
        conn.commit()
        conn.close()
    
    def generate_api_key(self, key_name: str, permissions: List[str], created_by: str, expires_in_days: int = 90) -> Dict:
        """Generate new API key with expiration"""
        api_key = f"aegis_{secrets.token_urlsafe(32)}"
        expires_at = (datetime.now() + timedelta(days=expires_in_days)).isoformat()
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        try:
            cursor.execute("""
            INSERT INTO api_keys (key_name, api_key, permissions, created_at, expires_at, created_by)
            VALUES (?, ?, ?, ?, ?, ?)
            """, (key_name, api_key, json.dumps(permissions), datetime.now().isoformat(), expires_at, created_by))
            
            conn.commit()
            
            return {
                'success': True,
                'api_key': api_key,
                'key_name': key_name,
                'permissions': permissions,
                'expires_at': expires_at
            }
        except sqlite3.IntegrityError:
            return {'success': False, 'error': 'Key name already exists'}
        finally:
            conn.close()
    
    def validate_api_key(self, api_key: str, required_permission: str = None) -> Optional[Dict]:
        """Validate API key and check permissions"""
        if not api_key or not api_key.startswith('aegis_'):
            return None
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
        SELECT id, key_name, permissions, is_active, usage_count, expires_at, rotation_required
        FROM api_keys
        WHERE api_key = ? AND is_active = 1
        """, (api_key,))
        
        result = cursor.fetchone()
        
        if not result:
            conn.close()
            return None
        
        key_id, key_name, permissions_json, is_active, usage_count, expires_at, rotation_required = result
        permissions = json.loads(permissions_json)
        
        # Check expiration
        if expires_at:
            expiration_time = datetime.fromisoformat(expires_at)
            if datetime.now() > expiration_time:
                # Deactivate expired key
                cursor.execute("UPDATE api_keys SET is_active = 0 WHERE id = ?", (key_id,))
                conn.commit()
                conn.close()
                SecurityLogger.log_security_event('api_key_expired', {
                    'key_id': key_id,
                    'key_name': key_name,
                    'expired_at': expires_at
                }, 'WARNING')
                return None
        
        # Check if rotation is required
        if rotation_required:
            conn.close()
            SecurityLogger.log_security_event('api_key_rotation_required', {
                'key_id': key_id,
                'key_name': key_name
            }, 'WARNING')
            return None
        
        # Check specific permission if required
        if required_permission and required_permission not in permissions:
            conn.close()
            return None
        
        # Update usage
        cursor.execute("""
        UPDATE api_keys SET last_used = ?, usage_count = usage_count + 1
        WHERE id = ?
        """, (datetime.now().isoformat(), key_id))
        
        # Log usage
        cursor.execute("""
        INSERT INTO api_key_usage (api_key_id, ip_address, endpoint, user_agent, timestamp)
        VALUES (?, ?, ?, ?, ?)
        """, (key_id, request.remote_addr if request else None,
               request.endpoint if request else None,
               request.headers.get('User-Agent') if request else None,
               datetime.now().isoformat()))
        
        conn.commit()
        conn.close()
        
        return {
            'key_id': key_id,
            'key_name': key_name,
            'permissions': permissions
        }
    
    def revoke_api_key(self, key_name: str) -> Dict:
        """Revoke API key"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("UPDATE api_keys SET is_active = 0 WHERE key_name = ?", (key_name,))
        affected_rows = cursor.rowcount
        
        conn.commit()
        conn.close()
        
        if affected_rows > 0:
            return {'success': True, 'message': 'API key revoked'}
        else:
            return {'success': False, 'error': 'API key not found'}
    
    def rotate_api_key(self, key_name: str, rotated_by: str) -> Dict:
        """Rotate API key (generate new key, invalidate old one)"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Get existing key info
        cursor.execute("""
        SELECT id, permissions, expires_at, created_by
        FROM api_keys
        WHERE key_name = ? AND is_active = 1
        """, (key_name,))
        
        result = cursor.fetchone()
        
        if not result:
            conn.close()
            return {'success': False, 'error': 'API key not found'}
        
        key_id, permissions_json, expires_at, created_by = result
        permissions = json.loads(permissions_json)
        
        # Generate new API key
        new_api_key = f"aegis_{secrets.token_urlsafe(32)}"
        
        # Calculate new expiration (extend from current expiration)
        if expires_at:
            current_expiration = datetime.fromisoformat(expires_at)
            if datetime.now() > current_expiration:
                # If already expired, set new expiration from now
                new_expires_at = (datetime.now() + timedelta(days=90)).isoformat()
            else:
                # Extend current expiration by 90 days
                new_expires_at = (current_expiration + timedelta(days=90)).isoformat()
        else:
            new_expires_at = (datetime.now() + timedelta(days=90)).isoformat()
        
        try:
            # Update existing key to inactive
            cursor.execute("""
            UPDATE api_keys
            SET is_active = 0, rotation_required = 0
            WHERE id = ?
            """, (key_id,))
            
            # Create new key entry
            cursor.execute("""
            INSERT INTO api_keys (key_name, api_key, permissions, created_at, expires_at, created_by)
            VALUES (?, ?, ?, ?, ?, ?)
            """, (key_name, new_api_key, json.dumps(permissions),
                   datetime.now().isoformat(), new_expires_at, rotated_by))
            
            conn.commit()
            
            return {
                'success': True,
                'api_key': new_api_key,
                'key_name': key_name,
                'permissions': permissions,
                'expires_at': new_expires_at,
                'message': 'API key rotated successfully'
            }
        except Exception as e:
            conn.rollback()
            return {'success': False, 'error': str(e)}
        finally:
            conn.close()
    
    def get_expired_keys(self) -> Dict:
        """Get expired API keys"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
        SELECT key_name, created_at, expires_at, usage_count, created_by
        FROM api_keys
        WHERE expires_at < ? AND is_active = 1
        ORDER BY expires_at DESC
        """, (datetime.now().isoformat(),))
        
        expired_keys = []
        for row in cursor.fetchall():
            expired_keys.append({
                'key_name': row[0],
                'created_at': row[1],
                'expires_at': row[2],
                'usage_count': row[3],
                'created_by': row[4]
            })
        
        conn.close()
        
        return {
            'success': True,
            'expired_keys': expired_keys,
            'total': len(expired_keys)
        }
    
    def cleanup_expired_keys(self) -> Dict:
        """Deactivate expired API keys"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
        UPDATE api_keys
        SET is_active = 0
        WHERE expires_at < ? AND is_active = 1
        """, (datetime.now().isoformat(),))
        
        deactivated_count = cursor.rowcount
        conn.commit()
        conn.close()
        
        if deactivated_count > 0:
            SecurityLogger.log_security_event('expired_keys_cleaned_up', {
                'deactivated_count': deactivated_count
            }, 'INFO')
        
        return {
            'success': True,
            'deactivated_count': deactivated_count
        }
    
    def require_rotation(self, key_name: str) -> Dict:
        """Mark API key as requiring rotation"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
        UPDATE api_keys
        SET rotation_required = 1
        WHERE key_name = ? AND is_active = 1
        """, (key_name,))
        
        affected_rows = cursor.rowcount
        conn.commit()
        conn.close()
        
        if affected_rows > 0:
            return {'success': True, 'message': 'API key marked for rotation'}
        else:
            return {'success': False, 'error': 'API key not found'}

class SecurityLogger:
    """Comprehensive security event logging"""
    
    @staticmethod
    def log_security_event(event_type: str, details: Dict, severity: str = 'INFO'):
        """Log security event"""
        # Safely get request context
        ip_address = None
        user_agent = None
        user_id = None
        
        try:
            if request:
                ip_address = request.remote_addr
                user_agent = request.headers.get('User-Agent')
        except RuntimeError:
            # Working outside of application context
            pass
        
        try:
            if hasattr(g, 'current_user'):
                user_id = getattr(g, 'current_user', {}).get('user_id')
        except RuntimeError:
            # Working outside of application context
            pass
        
        log_entry = {
            'timestamp': datetime.now().isoformat(),
            'event_type': event_type,
            'severity': severity,
            'ip_address': ip_address,
            'user_agent': user_agent,
            'user_id': user_id,
            'details': details
        }
        
        # Log to file
        security_logger.info(f"{event_type}: {json.dumps(log_entry)}")
        
        # Log to database if available
        try:
            auth_db_path = os.path.join(os.environ.get('AEGIS_HOME', '/opt/aegis-security-suite'), 'configs', 'web-dashboard', 'auth.db')

            if os.path.exists(auth_db_path):
                conn = sqlite3.connect(auth_db_path)
                cursor = conn.cursor()
                
                cursor.execute("""
                INSERT INTO auth_audit (user_id, action, ip_address, user_agent, timestamp, success, details)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """, (
                    log_entry['user_id'],
                    event_type,
                    log_entry['ip_address'],
                    log_entry['user_agent'],
                    log_entry['timestamp'],
                    severity != 'ERROR',
                    json.dumps(details)
                ))
                
                conn.commit()
                conn.close()
        except Exception as e:
            security_logger.error(f"Failed to log to database: {e}")

# Initialize rate limiter and API key manager
RATE_LIMIT_DB = os.path.join(os.environ.get('AEGIS_HOME', '/opt/aegis-security-suite'), 'configs', 'web-dashboard', 'rate_limits.db')
API_KEY_DB = os.path.join(os.environ.get('AEGIS_HOME', '/opt/aegis-security-suite'), 'configs', 'web-dashboard', 'api_keys.db')

rate_limiter = RateLimiter(RATE_LIMIT_DB)
api_key_manager = APIKeyManager(API_KEY_DB)

# Decorators for security
def require_api_key(required_permission: str = None):
    """Decorator to require valid API key"""
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            api_key = request.headers.get('X-API-Key')
            
            if not api_key:
                SecurityLogger.log_security_event('api_key_missing', {
                    'endpoint': request.endpoint,
                    'method': request.method
                }, 'WARNING')
                return jsonify({'error': 'API key required'}), 401
            
            key_info = api_key_manager.validate_api_key(api_key, required_permission)
            
            if not key_info:
                SecurityLogger.log_security_event('api_key_invalid', {
                    'endpoint': request.endpoint,
                    'method': request.method,
                    'api_key_prefix': api_key[:10] + '...' if api_key else None
                }, 'WARNING')
                return jsonify({'error': 'Invalid or insufficient API key'}), 401
            
            # Store key info in Flask g
            g.api_key_info = key_info
            
            return f(*args, **kwargs)
        return decorated_function
    return decorator

def rate_limit(limit: int = 100, window: int = 60):
    """Decorator to apply rate limiting"""
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            ip_address = request.remote_addr
            endpoint = request.endpoint or 'unknown'
            
            allowed, info = rate_limiter.is_allowed(ip_address, endpoint, limit, window)
            
            if not allowed:
                SecurityLogger.log_security_event('rate_limit_exceeded', {
                    'endpoint': endpoint,
                    'ip_address': ip_address,
                    'limit': limit,
                    'window': window
                }, 'WARNING')
                
                return jsonify({
                    'error': 'Rate limit exceeded',
                    'retry_after': info.get('retry_after', window)
                }), 429
            
            return f(*args, **kwargs)
        return decorated_function
    return decorator

def validate_input(required_fields: List[str] = None, optional_fields: List[str] = None):
    """Decorator to validate and sanitize input"""
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            if request.is_json:
                data = request.get_json()
            elif request.form:
                data = request.form.to_dict()
            else:
                data = {}
            
            # Validate required fields
            if required_fields:
                for field in required_fields:
                    if field not in data or not data[field]:
                        SecurityLogger.log_security_event('input_validation_failed', {
                            'endpoint': request.endpoint,
                            'missing_field': field,
                            'provided_data': list(data.keys())
                        }, 'WARNING')
                        return jsonify({'error': f'Missing required field: {field}'}), 400
            
            # Sanitize all string inputs
            sanitized_data = {}
            for key, value in data.items():
                if isinstance(value, str):
                    sanitized_data[key] = InputValidator.sanitize_string(value)
                else:
                    sanitized_data[key] = value
            
            # Store sanitized data in Flask g
            g.sanitized_data = sanitized_data
            
            return f(*args, **kwargs)
        return decorated_function
    return decorator

def secure_headers(f):
    """Decorator to add security headers"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        response = f(*args, **kwargs)
        
        if hasattr(response, 'headers'):
            # Add comprehensive security headers
            response.headers['X-Content-Type-Options'] = 'nosniff'
            response.headers['X-Frame-Options'] = 'DENY'
            response.headers['X-XSS-Protection'] = '1; mode=block'
            response.headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains; preload'
            response.headers['Content-Security-Policy'] = (
                "default-src 'self'; "
                "script-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net https://cdn.socket.io; "
                "style-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net https://cdnjs.cloudflare.com https://fonts.googleapis.com; "
                "img-src 'self' data: https:; "
                "font-src 'self' https://cdnjs.cloudflare.com https://fonts.gstatic.com; "
                "connect-src 'self' ws: wss:; "
                "frame-ancestors 'none'; "
                "base-uri 'self'; "
                "form-action 'self'"
            )
            response.headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
            response.headers['Permissions-Policy'] = (
                'geolocation=(), microphone=(), camera=(), '
                'payment=(), usb=(), magnetometer=(), gyroscope=()'
            )
            response.headers['X-Permitted-Cross-Domain-Policies'] = 'none'
            response.headers['X-Download-Options'] = 'noopen'
        
        return response
    return decorated_function

def get_ip_geolocation(ip_address):
    """Get geolocation data for IP address (simplified implementation)"""
    try:
        import ipaddress
        import requests
        
        # Skip private IPs
        ip_obj = ipaddress.ip_address(ip_address)
        if ip_obj.is_private:
            return None
        
        # Use a free geolocation API (in production, consider using a paid service)
        try:
            response = requests.get(f"http://ip-api.com/json/{ip_address}", timeout=2)
            if response.status_code == 200:
                data = response.json()
                if data.get('status') == 'success':
                    return {
                        'country': data.get('country'),
                        'region': data.get('regionName'),
                        'city': data.get('city'),
                        'latitude': data.get('lat'),
                        'longitude': data.get('lon'),
                        'isp': data.get('isp')
                    }
        except:
            pass
        
        return None
    except:
        return None

def check_password_strength(password):
    """Check password strength against security policies"""
    if not password:
        return {'strength': 0, 'issues': ['Password is required']}
    
    issues = []
    score = 0
    
    # Length check
    if len(password) < 8:
        issues.append('Password must be at least 8 characters long')
    else:
        score += 1
    
    if len(password) >= 12:
        score += 1
    
    # Complexity checks
    if not any(c.islower() for c in password):
        issues.append('Password must contain lowercase letters')
    else:
        score += 1
    
    if not any(c.isupper() for c in password):
        issues.append('Password must contain uppercase letters')
    else:
        score += 1
    
    if not any(c.isdigit() for c in password):
        issues.append('Password must contain numbers')
    else:
        score += 1
    
    if not any(c in '!@#$%^&*()_+-=[]{}|;:,.<>?' for c in password):
        issues.append('Password must contain special characters')
    else:
        score += 1
    
    # Common password check
    common_passwords = ['password', '123456', 'admin', 'qwerty', 'letmein']
    if password.lower() in common_passwords:
        issues.append('Password is too common')
        score = max(0, score - 2)
    
    # Determine strength
    if score >= 6:
        strength = 'very_strong'
    elif score >= 5:
        strength = 'strong'
    elif score >= 4:
        strength = 'medium'
    elif score >= 2:
        strength = 'weak'
    else:
        strength = 'very_weak'
    
    return {
        'strength': strength,
        'score': score,
        'issues': issues
    }

def generate_mfa_secret():
    """Generate secret for multi-factor authentication"""
    import pyotp
    return pyotp.random_base32()

def verify_mfa_token(secret, token):
    """Verify multi-factor authentication token"""
    try:
        import pyotp
        totp = pyotp.TOTP(secret)
        return totp.verify(token, valid_window=1)  # Allow 1 step tolerance
    except:
        return False

def generate_mfa_qr_code(secret, username):
    """Generate QR code for MFA setup"""
    try:
        import pyotp
        import qrcode
        from io import BytesIO
        import base64
        
        totp_uri = pyotp.totp.TOTP(secret).provisioning_uri(
            name=username,
            issuer_name="Aegis Security Suite"
        )
        
        qr = qrcode.QRCode(version=1, box_size=10, border=5)
        qr.add_data(totp_uri)
        qr.make(fit=True)
        
        img = qr.make_image(fill_color="black", back_color="white")
        buffer = BytesIO()
        img.save(buffer, format='PNG')
        img_str = base64.b64encode(buffer.getvalue()).decode()
        
        return f"data:image/png;base64,{img_str}"
    except:
        return None

def hash_password(password, salt=None):
    """Hash a password with bcrypt. bcrypt embeds its own salt in the
    returned hash, so the `salt` argument is accepted (for call-site
    compatibility with the users.salt column) but not used to derive
    the hash."""
    return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

def verify_password(password, stored_hash, salt=None):
    """Verify a password against a bcrypt hash. The salt embedded in
    stored_hash is used automatically; the `salt` argument is accepted
    for call-site compatibility but not used."""
    try:
        return bcrypt.checkpw(password.encode('utf-8'), stored_hash.encode('utf-8'))
    except Exception:
        return False