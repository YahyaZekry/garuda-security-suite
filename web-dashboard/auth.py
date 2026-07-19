#!/usr/bin/env python3
"""
Authentication Module for Aegis Security Suite Dashboard
Provides secure user authentication, session management, and role-based access control
"""

import os
import hashlib
import secrets
import sqlite3
import json
import uuid
from datetime import datetime, timedelta
from functools import wraps
from flask import session, request, redirect, url_for, flash, g, current_app
from security_utils import SecurityLogger, InputValidator, rate_limiter, hash_password, verify_password

# Database path
AUTH_DB_PATH = os.path.join(os.environ.get('AEGIS_HOME', '/opt/aegis-security-suite'), 'configs', 'web-dashboard', 'auth.db')

def ensure_auth_db():
    """Ensure authentication database exists and is properly initialized"""
    try:
        if not os.path.exists(os.path.dirname(AUTH_DB_PATH)):
            os.makedirs(os.path.dirname(AUTH_DB_PATH), exist_ok=True)
        
        conn = sqlite3.connect(AUTH_DB_PATH)
        cursor = conn.cursor()
        
        # Create users table
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            email TEXT UNIQUE,
            password_hash TEXT NOT NULL,
            salt TEXT NOT NULL,
            role TEXT NOT NULL DEFAULT 'analyst',
            is_active BOOLEAN DEFAULT 1,
            created_at TEXT NOT NULL,
            last_login TEXT,
            failed_login_attempts INTEGER DEFAULT 0,
            locked_until TEXT,
            password_changed_at TEXT,
            two_factor_enabled BOOLEAN DEFAULT 0,
            two_factor_secret TEXT,
            password_reset_required BOOLEAN DEFAULT 0,
            last_password_change TEXT,
            login_attempts_24h INTEGER DEFAULT 0,
            suspicious_login_count INTEGER DEFAULT 0
        )
        """)
        
        # Create sessions table with enhanced security
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS user_sessions (
            id TEXT PRIMARY KEY,
            user_id INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            expires_at TEXT NOT NULL,
            ip_address TEXT,
            user_agent TEXT,
            device_fingerprint TEXT,
            last_activity TEXT,
            is_active BOOLEAN DEFAULT 1,
            FOREIGN KEY (user_id) REFERENCES users (id)
        )
        """)
        
        # Create session tokens table for additional validation
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS session_tokens (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id TEXT NOT NULL,
            token TEXT NOT NULL,
            created_at TEXT NOT NULL,
            expires_at TEXT NOT NULL,
            is_used BOOLEAN DEFAULT 0,
            FOREIGN KEY (session_id) REFERENCES user_sessions (id)
        )
        """)
        
        # Create audit log table
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS auth_audit (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER,
            action TEXT NOT NULL,
            ip_address TEXT,
            user_agent TEXT,
            timestamp TEXT NOT NULL,
            success BOOLEAN,
            details TEXT,
            FOREIGN KEY (user_id) REFERENCES users (id)
        )
        """)
        
        # Create password reset table
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS password_resets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            token TEXT UNIQUE NOT NULL,
            created_at TEXT NOT NULL,
            expires_at TEXT NOT NULL,
            used BOOLEAN DEFAULT 0,
            ip_address TEXT,
            FOREIGN KEY (user_id) REFERENCES users (id)
        )
        """)
        
        # Create indexes for performance
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id ON user_sessions(user_id)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_user_sessions_expires_at ON user_sessions(expires_at)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_auth_audit_timestamp ON auth_audit(timestamp)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_auth_audit_user_id ON auth_audit(user_id)")
        
        # Create default admin user if no users exist
        cursor.execute("SELECT COUNT(*) FROM users")
        user_count = cursor.fetchone()[0]
        
        if user_count == 0:
            create_default_admin(cursor)
        
        conn.commit()
        conn.close()
        return True
        
    except Exception as e:
        SecurityLogger.log_security_event('database_initialization_failed', {
            'error': str(e)
        }, 'ERROR')
        return False

def create_default_admin(cursor):
    """Create default admin user with enhanced security"""
    try:
        # Generate a secure random password instead of hardcoded one
        default_password = secrets.token_urlsafe(16)  # 16-character secure password
        salt = secrets.token_hex(32)  # Increased salt size
        password_hash = hash_password(default_password, salt)
        
        cursor.execute("""
        INSERT INTO users (username, email, password_hash, salt, role, created_at, password_changed_at, password_reset_required)
        VALUES (?, ?, ?, ?, 'admin', ?, ?, 1)
        """, ('admin', 'admin@aegis.local', password_hash, salt,
               datetime.now().isoformat(), datetime.now().isoformat()))
        
        SecurityLogger.log_security_event('default_admin_created', {
            'username': 'admin',
            'action': 'Default admin user created with secure password - password change required'
        }, 'WARNING')
        
        print("=" * 60)
        print("SECURITY NOTICE: Default admin user created")
        print(f"Username: admin")
        print(f"Password: {default_password}")
        print("Please change the default password immediately after first login.")
        print("Store this password securely - it will not be shown again.")
        print("=" * 60)
        
        # Save password to a secure file for recovery
        try:
            password_file = os.path.join(os.environ.get('AEGIS_HOME', '/opt/aegis-security-suite'), 'configs', 'web-dashboard', 'admin_password.txt')
            os.makedirs(os.path.dirname(password_file), exist_ok=True)
            with open(password_file, 'w') as f:
                f.write(f"Admin Username: admin\n")
                f.write(f"Admin Password: {default_password}\n")
                f.write(f"Created: {datetime.now().isoformat()}\n")
                f.write("IMPORTANT: Change this password immediately after first login!\n")
            os.chmod(password_file, 0o600)  # Secure file permissions
        except Exception as e:
            print(f"Warning: Could not save password to file: {e}")
        
    except Exception as e:
        SecurityLogger.log_security_event('default_admin_creation_failed', {
            'error': str(e)
        }, 'ERROR')
        print(f"Error creating default admin: {e}")

def generate_device_fingerprint(user_agent=None, ip_address=None):
    """Generate device fingerprint for session validation"""
    try:
        fingerprint_data = []
        
        if user_agent:
            fingerprint_data.append(user_agent)
        
        if ip_address:
            # Use first three octets for privacy
            ip_parts = ip_address.split('.')
            if len(ip_parts) >= 3:
                fingerprint_data.append('.'.join(ip_parts[:3]))
        
        # Add some browser characteristics if available
        if user_agent:
            # Extract browser characteristics
            if 'Chrome' in user_agent:
                fingerprint_data.append('chrome')
            elif 'Firefox' in user_agent:
                fingerprint_data.append('firefox')
            elif 'Safari' in user_agent:
                fingerprint_data.append('safari')
            
            if 'Windows' in user_agent:
                fingerprint_data.append('windows')
            elif 'Linux' in user_agent:
                fingerprint_data.append('linux')
            elif 'Mac' in user_agent:
                fingerprint_data.append('mac')
        
        # Generate hash of fingerprint data
        fingerprint_string = '|'.join(fingerprint_data)
        return hashlib.sha256(fingerprint_string.encode()).hexdigest()[:32]
        
    except Exception as e:
        SecurityLogger.log_security_event('fingerprint_generation_failed', {
            'error': str(e)
        }, 'ERROR')
        # Return a random hash as fallback
        return secrets.token_hex(16)

def authenticate_user(username, password, ip_address=None, user_agent=None, mfa_token=None):
    """Authenticate user credentials with enhanced security"""
    try:
        # Validate input
        if not InputValidator.validate_username(username):
            SecurityLogger.log_security_event('authentication_failed', {
                'username': username,
                'ip_address': ip_address,
                'reason': 'Invalid username format'
            }, 'WARNING')
            return {'success': False, 'error': 'Invalid credentials'}
        
        # Check password strength for new logins (prevent weak passwords)
        if password:
            password_check = check_password_strength(password)
            if password_check['strength'] in ['very_weak', 'weak']:
                SecurityLogger.log_security_event('weak_password_attempt', {
                    'username': username,
                    'ip_address': ip_address,
                    'password_strength': password_check['strength']
                }, 'WARNING')
        
        # Enhanced rate limiting with progressive delays
        allowed, rate_info = rate_limiter.is_allowed(ip_address or 'unknown', 'login', 5, 300)  # 5 attempts per 5 minutes
        if not allowed:
            SecurityLogger.log_security_event('login_rate_limit_exceeded', {
                'username': username,
                'ip_address': ip_address,
                'retry_after': rate_info.get('retry_after', 300)
            }, 'WARNING')
            return {'success': False, 'error': 'Too many login attempts. Please try again later.'}
        
        if not ensure_auth_db():
            return {'success': False, 'error': 'Database initialization failed'}
        
        conn = sqlite3.connect(AUTH_DB_PATH)
        cursor = conn.cursor()
        
        # Get user by username
        cursor.execute("""
        SELECT id, username, password_hash, salt, role, is_active,
               failed_login_attempts, locked_until, last_login, two_factor_enabled,
               two_factor_secret, password_reset_required, login_attempts_24h,
               suspicious_login_count, last_password_change
        FROM users WHERE username = ?
        """, (username,))
        
        user = cursor.fetchone()
        
        if not user:
            SecurityLogger.log_security_event('authentication_failed', {
                'username': username,
                'ip_address': ip_address,
                'reason': 'User not found'
            }, 'WARNING')
            conn.close()
            return {'success': False, 'error': 'Invalid credentials'}
        
        (user_id, username, stored_hash, salt, role, is_active, failed_attempts,
         locked_until, last_login, two_factor_enabled, two_factor_secret,
         password_reset_required, login_attempts_24h, suspicious_login_count,
         last_password_change) = user
        
        # Check if account is locked
        if locked_until:
            lock_time = datetime.fromisoformat(locked_until)
            if datetime.now() < lock_time:
                SecurityLogger.log_security_event('authentication_blocked', {
                    'user_id': user_id,
                    'username': username,
                    'ip_address': ip_address,
                    'reason': 'Account locked',
                    'locked_until': locked_until
                }, 'WARNING')
                conn.close()
                return {'success': False, 'error': f'Account locked until {lock_time.strftime("%Y-%m-%d %H:%M:%S")}'}
        
        # Check if account is active
        if not is_active:
            SecurityLogger.log_security_event('authentication_blocked', {
                'user_id': user_id,
                'username': username,
                'ip_address': ip_address,
                'reason': 'Account inactive'
            }, 'WARNING')
            conn.close()
            return {'success': False, 'error': 'Account deactivated'}
        
        # Verify password
        if verify_password(password, stored_hash, salt):
            # Check MFA if enabled
            if two_factor_enabled:
                if not mfa_token:
                    conn.close()
                    return {
                        'success': False,
                        'error': 'MFA token required',
                        'mfa_required': True
                    }
                
                if not verify_mfa_token(two_factor_secret, mfa_token):
                    SecurityLogger.log_security_event('mfa_authentication_failed', {
                        'user_id': user_id,
                        'username': username,
                        'ip_address': ip_address
                    }, 'WARNING')
                    conn.close()
                    return {'success': False, 'error': 'Invalid MFA token'}
            
            # Reset failed attempts on successful login
            cursor.execute("""
            UPDATE users SET failed_login_attempts = 0, locked_until = NULL, last_login = ?,
                            login_attempts_24h = login_attempts_24h + 1
            WHERE id = ?
            """, (datetime.now().isoformat(), user_id))
            
            # Check for suspicious login patterns
            if last_login:
                last_login_time = datetime.fromisoformat(last_login)
                time_since_last_login = datetime.now() - last_login_time
                
                # Alert on very quick successive logins from different IPs
                if time_since_last_login < timedelta(minutes=5) and ip_address:
                    cursor.execute("SELECT ip_address FROM user_sessions WHERE user_id = ? ORDER BY created_at DESC LIMIT 1", (user_id,))
                    last_session = cursor.fetchone()
                    if last_session and last_session[0] != ip_address:
                        SecurityLogger.log_security_event('suspicious_login_pattern', {
                            'user_id': user_id,
                            'username': username,
                            'current_ip': ip_address,
                            'previous_ip': last_session[0],
                            'time_since_last_login': str(time_since_last_login)
                        }, 'WARNING')
                        
                        # Increment suspicious login count
                        cursor.execute("""
                        UPDATE users SET suspicious_login_count = suspicious_login_count + 1
                        WHERE id = ?
                        """, (user_id,))
            
            SecurityLogger.log_security_event('authentication_success', {
                'user_id': user_id,
                'username': username,
                'ip_address': ip_address,
                'user_agent': user_agent,
                'mfa_used': two_factor_enabled
            })
            
            conn.commit()
            conn.close()
            
            return {
                'success': True,
                'user_id': user_id,
                'username': username,
                'role': role,
                'password_reset_required': password_reset_required
            }
        else:
            # Increment failed attempts with progressive lockout
            failed_attempts += 1
            lock_account = False
            lock_until = None
            
            # Progressive lockout: 5 attempts = 30 min, 10 attempts = 2 hours, 15+ attempts = 24 hours
            if failed_attempts >= 15:
                lock_account = True
                lock_until = (datetime.now() + timedelta(hours=24)).isoformat()
            elif failed_attempts >= 10:
                lock_account = True
                lock_until = (datetime.now() + timedelta(hours=2)).isoformat()
            elif failed_attempts >= 5:
                lock_account = True
                lock_until = (datetime.now() + timedelta(minutes=30)).isoformat()
            
            cursor.execute("""
            UPDATE users SET failed_login_attempts = ?, locked_until = ?
            WHERE id = ?
            """, (failed_attempts, lock_until, user_id))
            
            SecurityLogger.log_security_event('authentication_failed', {
                'user_id': user_id,
                'username': username,
                'ip_address': ip_address,
                'failed_attempts': failed_attempts,
                'account_locked': lock_account
            }, 'WARNING')
            
            conn.commit()
            conn.close()
            
            if lock_account:
                return {'success': False, 'error': f'Account locked due to multiple failed attempts until {datetime.fromisoformat(lock_until).strftime("%Y-%m-%d %H:%M:%S")}'}
            else:
                return {'success': False, 'error': 'Invalid credentials'}
                
    except Exception as e:
        SecurityLogger.log_security_event('authentication_error', {
            'username': username,
            'ip_address': ip_address,
            'error': str(e)
        }, 'ERROR')
        return {'success': False, 'error': 'Authentication system error'}

def check_password_strength(password):
    """Check password strength against security policies"""
    if not password:
        return {'strength': 0, 'issues': ['Password is required']}
    
    issues = []
    score = 0
    
    # Length check
    if len(password) < 12:  # Increased minimum length
        issues.append('Password must be at least 12 characters long')
    else:
        score += 1
    
    if len(password) >= 16:
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
    common_passwords = ['password', '123456', 'admin', 'qwerty', 'letmein', 'welcome', 'changeme']
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

def verify_mfa_token(secret, token):
    """Verify multi-factor authentication token"""
    try:
        import pyotp
        totp = pyotp.TOTP(secret)
        return totp.verify(token, valid_window=1)  # Allow 1 step tolerance
    except:
        return False

def create_user_session(user_id, username, role, ip_address=None, user_agent=None):
    """Create secure user session with enhanced security"""
    try:
        # Generate secure session token
        session_id = secrets.token_urlsafe(64)
        session_token = secrets.token_urlsafe(32)
        
        # Set session expiration (24 hours)
        expires_at = (datetime.now() + timedelta(hours=24)).isoformat()
        
        # Get device fingerprint
        device_fingerprint = generate_device_fingerprint(user_agent, ip_address)
        
        conn = sqlite3.connect(AUTH_DB_PATH)
        cursor = conn.cursor()
        
        # Clean up old sessions and expired tokens
        cursor.execute("DELETE FROM user_sessions WHERE expires_at < ?", (datetime.now().isoformat(),))
        
        # Create new session with enhanced security
        cursor.execute("""
        INSERT INTO user_sessions (id, user_id, created_at, expires_at, ip_address, user_agent, device_fingerprint)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (session_id, user_id, datetime.now().isoformat(), expires_at, ip_address, user_agent, device_fingerprint))
        
        # Store session token separately for additional validation
        cursor.execute("""
        INSERT INTO session_tokens (session_id, token, created_at, expires_at)
        VALUES (?, ?, ?, ?)
        """, (session_id, session_token, datetime.now().isoformat(), expires_at))
        
        conn.commit()
        conn.close()
        
        # Log successful session creation
        SecurityLogger.log_security_event('session_created', {
            'user_id': user_id,
            'username': username,
            'ip_address': ip_address,
            'session_id': session_id[:16] + '...'  # Log only partial session ID
        })
        
        return session_id
        
    except Exception as e:
        SecurityLogger.log_security_event('session_creation_failed', {
            'user_id': user_id,
            'error': str(e)
        }, 'ERROR')
        return None

def validate_session(session_id, ip_address=None):
    """Validate user session with enhanced security checks"""
    try:
        if not session_id:
            return None
        
        conn = sqlite3.connect(AUTH_DB_PATH)
        cursor = conn.cursor()
        
        # Get session with user info and security data
        cursor.execute("""
        SELECT s.id, s.user_id, s.expires_at, s.is_active, s.ip_address, s.user_agent, s.device_fingerprint,
               u.username, u.role, u.is_active as user_active
        FROM user_sessions s
        JOIN users u ON s.user_id = u.id
        WHERE s.id = ? AND s.expires_at > ? AND s.is_active = 1
        """, (session_id, datetime.now().isoformat()))
        
        session_data = cursor.fetchone()
        
        if not session_data:
            SecurityLogger.log_security_event('session_validation_failed', {
                'session_id': session_id[:16] + '...',
                'reason': 'Session not found or expired'
            }, 'WARNING')
            conn.close()
            return None
        
        (session_id, user_id, expires_at, is_active, stored_ip, stored_user_agent,
         stored_fingerprint, username, role, user_active) = session_data
        
        # Check if user is still active
        if not user_active:
            # Deactivate session
            cursor.execute("UPDATE user_sessions SET is_active = 0 WHERE id = ?", (session_id,))
            conn.commit()
            SecurityLogger.log_security_event('session_deactivated', {
                'user_id': user_id,
                'username': username,
                'reason': 'User account deactivated'
            }, 'WARNING')
            conn.close()
            return None
        
        # Enhanced security checks
        current_user_agent = request.headers.get('User-Agent') if request else None
        current_fingerprint = generate_device_fingerprint(current_user_agent, ip_address)
        
        # Check for suspicious activity
        security_issues = []
        risk_score = 0
        
        # IP address change detection (high risk)
        if stored_ip and ip_address and stored_ip != ip_address:
            # Check if it's a private network change (less suspicious)
            if not (is_private_ip(stored_ip) and is_private_ip(ip_address)):
                security_issues.append(f"IP address changed from {stored_ip} to {ip_address}")
                risk_score += 3
        
        # User agent change detection (medium risk)
        if stored_user_agent and current_user_agent and stored_user_agent != current_user_agent:
            # Check if it's just a version update (less suspicious)
            if not is_browser_version_update(stored_user_agent, current_user_agent):
                security_issues.append("User agent changed")
                risk_score += 2
        
        # Device fingerprint change detection (high risk)
        if stored_fingerprint and current_fingerprint and stored_fingerprint != current_fingerprint:
            security_issues.append("Device fingerprint changed")
            risk_score += 3
        
        # Geographic location check (if IP changed significantly)
        if stored_ip and ip_address and stored_ip != ip_address:
            try:
                from security_utils import get_ip_geolocation
                stored_geo = get_ip_geolocation(stored_ip)
                current_geo = get_ip_geolocation(ip_address)
                
                if stored_geo and current_geo:
                    # Calculate distance between locations
                    distance = calculate_geographic_distance(
                        stored_geo.get('latitude'), stored_geo.get('longitude'),
                        current_geo.get('latitude'), current_geo.get('longitude')
                    )
                    
                    # If distance > 1000km in < 1 hour, very suspicious
                    if distance > 1000:
                        security_issues.append(f"Impossible travel detected: {distance:.0f}km")
                        risk_score += 5
            except ImportError:
                # Geolocation not available, skip this check
                pass
        
        # Check for concurrent sessions from different IPs
        cursor.execute("""
        SELECT COUNT(*) FROM user_sessions
        WHERE user_id = ? AND is_active = 1 AND ip_address != ? AND id != ?
        """, (user_id, ip_address, session_id))
        
        concurrent_sessions = cursor.fetchone()[0]
        if concurrent_sessions > 0:
            security_issues.append(f"Concurrent sessions from different IPs detected")
            risk_score += 2
        
        # Log security issues if any
        if security_issues:
            SecurityLogger.log_security_event('session_anomaly_detected', {
                'user_id': user_id,
                'username': username,
                'session_id': session_id[:16] + '...',
                'issues': security_issues,
                'risk_score': risk_score,
                'ip_address': ip_address,
                'stored_ip': stored_ip
            }, 'WARNING')
            
            # For high-risk changes, invalidate session
            if risk_score >= 5:
                cursor.execute("UPDATE user_sessions SET is_active = 0 WHERE id = ?", (session_id,))
                conn.commit()
                conn.close()
                SecurityLogger.log_security_event('session_invalidated_high_risk', {
                    'user_id': user_id,
                    'username': username,
                    'session_id': session_id[:16] + '...',
                    'risk_score': risk_score,
                    'reason': 'High-risk session anomaly detected'
                }, 'CRITICAL')
                return None
        
        # Update session activity
        cursor.execute("""
        UPDATE user_sessions
        SET ip_address = ?, user_agent = ?, last_activity = ?
        WHERE id = ?
        """, (ip_address, current_user_agent, datetime.now().isoformat(), session_id))
        
        conn.commit()
        conn.close()
        
        return {
            'session_id': session_id,
            'user_id': user_id,
            'username': username,
            'role': role,
            'expires_at': expires_at
        }
        
    except Exception as e:
        SecurityLogger.log_security_event('session_validation_error', {
            'session_id': session_id[:16] + '...' if session_id else None,
            'error': str(e)
        }, 'ERROR')
        return None

def is_private_ip(ip):
    """Check if IP address is private"""
    try:
        import ipaddress
        ip_obj = ipaddress.ip_address(ip)
        return ip_obj.is_private
    except:
        # Fallback to basic checks
        if ip.startswith('192.168.') or ip.startswith('10.') or ip.startswith('172.'):
            return True
        if ip.startswith('127.') or ip == 'localhost':
            return True
        return False

def is_browser_version_update(old_ua, new_ua):
    """Check if user agent change is just a browser version update"""
    try:
        # Extract browser name and version
        import re
        
        # Chrome pattern
        chrome_pattern = r'Chrome/(\d+\.\d+\.\d+\.\d+)'
        old_chrome = re.search(chrome_pattern, old_ua)
        new_chrome = re.search(chrome_pattern, new_ua)
        
        if old_chrome and new_chrome:
            # Check if major version is the same
            old_version = old_chrome.group(1).split('.')[0]
            new_version = new_chrome.group(1).split('.')[0]
            return old_version == new_version
        
        # Firefox pattern
        firefox_pattern = r'Firefox/(\d+\.\d+)'
        old_firefox = re.search(firefox_pattern, old_ua)
        new_firefox = re.search(firefox_pattern, new_ua)
        
        if old_firefox and new_firefox:
            # Check if major version is the same
            old_version = old_firefox.group(1).split('.')[0]
            new_version = new_firefox.group(1).split('.')[0]
            return old_version == new_version
        
        return False
    except:
        return False

def calculate_geographic_distance(lat1, lon1, lat2, lon2):
    """Calculate distance between two geographic coordinates in kilometers"""
    try:
        from math import radians, cos, sin, asin, sqrt
        
        # Convert decimal degrees to radians
        lat1, lon1, lat2, lon2 = map(radians, [lat1, lon1, lat2, lon2])
        
        # Haversine formula
        dlat = lat2 - lat1
        dlon = lon2 - lon1
        a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
        c = 2 * asin(sqrt(a))
        
        # Radius of earth in kilometers
        r = 6371
        return c * r
    except:
        return 0

def destroy_session(session_id):
    """Destroy user session securely"""
    try:
        if not session_id:
            return False
        
        conn = sqlite3.connect(AUTH_DB_PATH)
        cursor = conn.cursor()
        
        # Get session info before destruction for logging
        cursor.execute("""
        SELECT user_id, ip_address FROM user_sessions WHERE id = ?
        """, (session_id,))
        session_info = cursor.fetchone()
        
        # Mark session as inactive
        cursor.execute("UPDATE user_sessions SET is_active = 0 WHERE id = ?", (session_id,))
        
        # Remove associated tokens
        cursor.execute("DELETE FROM session_tokens WHERE session_id = ?", (session_id,))
        
        conn.commit()
        conn.close()
        
        # Log session destruction
        if session_info:
            SecurityLogger.log_security_event('session_destroyed', {
                'user_id': session_info[0],
                'session_id': session_id[:16] + '...',
                'ip_address': session_info[1]
            })
        
        return True
        
    except Exception as e:
        SecurityLogger.log_security_event('session_destruction_error', {
            'session_id': session_id[:16] + '...' if session_id else None,
            'error': str(e)
        }, 'ERROR')
        return False

def log_auth_event(user_id, action, ip_address, user_agent, success, details=None):
    """Log authentication events"""
    try:
        conn = sqlite3.connect(AUTH_DB_PATH)
        cursor = conn.cursor()
        
        cursor.execute("""
        INSERT INTO auth_audit (user_id, action, ip_address, user_agent, timestamp, success, details)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (user_id, action, ip_address, user_agent, datetime.now().isoformat(), success, details))
        
        conn.commit()
        conn.close()
        
    except Exception as e:
        print(f"Auth logging error: {e}")

def get_session_idle_timeout_minutes():
    """Read the configurable idle-session timeout (Settings > Security >
    Session Timeout), falling back to 30 minutes if unset/unreadable."""
    try:
        from api.config import load_config as load_dashboard_config
        return int(load_dashboard_config().get('security', {}).get('session_timeout', 30))
    except Exception:
        return 30

def require_auth(f):
    """Authentication decorator for Flask routes. Enforces an idle
    timeout for sessions that weren't created with "Remember Me" —
    "Remember Me" sessions rely solely on the cookie's own expiry."""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        # Check for session in Flask session
        session_id = session.get('session_id')

        if not session_id:
            return redirect(url_for('login'))

        # Validate session
        user_data = validate_session(session_id, request.remote_addr)

        if not user_data:
            session.clear()
            return redirect(url_for('login'))

        # Enforce idle timeout for non-"remember me" sessions
        if not session.get('remember_me'):
            last_activity = session.get('last_activity')
            if last_activity:
                idle_minutes = (datetime.now() - datetime.fromisoformat(last_activity)).total_seconds() / 60
                if idle_minutes > get_session_idle_timeout_minutes():
                    destroy_session(session_id)
                    session.clear()
                    flash('Your session has expired due to inactivity. Please log in again.', 'info')
                    return redirect(url_for('login'))
        session['last_activity'] = datetime.now().isoformat()

        # Store user data in Flask g object
        g.current_user = user_data

        return f(*args, **kwargs)

    return decorated_function

def require_role(required_role):
    """Role-based access control decorator. In single-user deployment mode
    there's only one operator, so role-tier checks are skipped entirely -
    any authenticated user has full access."""
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            if not hasattr(g, 'current_user'):
                return redirect(url_for('login'))

            try:
                from api.config import is_single_user_mode
                if is_single_user_mode():
                    return f(*args, **kwargs)
            except Exception:
                pass

            user_role = g.current_user.get('role', 'analyst')
            
            # Role hierarchy: admin > manager > analyst > viewer
            role_hierarchy = {
                'viewer': 0,
                'analyst': 1,
                'manager': 2,
                'admin': 3
            }
            
            if role_hierarchy.get(user_role, 0) < role_hierarchy.get(required_role, 0):
                return {'error': 'Insufficient permissions'}, 403
            
            return f(*args, **kwargs)
        
        return decorated_function
    return decorator
# login_required was a byte-for-byte duplicate of require_auth; kept as
# an alias since both names are used across the codebase.
login_required = require_auth

def get_user_permissions(user_role):
    """Get permissions for user role"""
    permissions = {
        'viewer': [
            'view_dashboard', 'view_incidents', 'view_threats', 'view_behavioral',
            'view_reports', 'view_config'
        ],
        'analyst': [
            'view_dashboard', 'view_incidents', 'view_threats', 'view_behavioral',
            'view_reports', 'view_config',
            'create_incidents', 'update_incidents', 'add_evidence',
            'run_scans', 'create_baseline'
        ],
        'manager': [
            'view_dashboard', 'view_incidents', 'view_threats', 'view_behavioral',
            'view_reports', 'view_config',
            'create_incidents', 'update_incidents', 'add_evidence',
            'run_scans', 'create_baseline',
            'manage_incidents', 'assign_incidents', 'escalate_incidents',
            'manage_users', 'view_audit_logs'
        ],
        'admin': [
            'view_dashboard', 'view_incidents', 'view_threats', 'view_behavioral',
            'view_reports', 'view_config',
            'create_incidents', 'update_incidents', 'add_evidence',
            'run_scans', 'create_baseline',
            'manage_incidents', 'assign_incidents', 'escalate_incidents',
            'manage_users', 'view_audit_logs',
            'system_config', 'manage_threat_feeds', 'system_maintenance'
        ]
    }
    
    return permissions.get(user_role, permissions['viewer'])

def check_permission(permission):
    """Check if current user has specific permission"""
    if not hasattr(g, 'current_user'):
        return False
    
    user_role = g.current_user.get('role', 'viewer')
    user_permissions = get_user_permissions(user_role)
    
    return permission in user_permissions

def get_auth_statistics():
    """Get authentication statistics"""
    try:
        conn = sqlite3.connect(AUTH_DB_PATH)
        cursor = conn.cursor()
        
        # Get user count by role
        cursor.execute("SELECT role, COUNT(*) FROM users WHERE is_active = 1 GROUP BY role")
        role_stats = dict(cursor.fetchall())
        
        # Get active sessions
        cursor.execute("SELECT COUNT(*) FROM user_sessions WHERE is_active = 1 AND expires_at > ?", 
                     (datetime.now().isoformat(),))
        active_sessions = cursor.fetchone()[0]
        
        # Get recent login attempts
        cursor.execute("""
        SELECT action, COUNT(*) FROM auth_audit 
        WHERE timestamp > datetime('now', '-24 hours')
        GROUP BY action
        """)
        recent_activity = dict(cursor.fetchall())
        
        conn.close()
        
        return {
            'users_by_role': role_stats,
            'active_sessions': active_sessions,
            'recent_activity': recent_activity,
            'timestamp': datetime.now().isoformat()
        }
        
    except Exception as e:
        print(f"Auth statistics error: {e}")
        return {}

def cleanup_expired_sessions():
    """Clean up expired sessions"""
    try:
        conn = sqlite3.connect(AUTH_DB_PATH)
        cursor = conn.cursor()
        
        cursor.execute("DELETE FROM user_sessions WHERE expires_at < ?", (datetime.now().isoformat(),))
        deleted_count = cursor.rowcount
        
        conn.commit()
        conn.close()
        
        return deleted_count
        
    except Exception as e:
        print(f"Session cleanup error: {e}")
        return 0

# Export functions for use by other modules
__all__ = ['authenticate_user', 'create_user_session', 'validate_session', 'destroy_session',
           'log_auth_event', 'require_auth', 'require_role', 'get_user_permissions',
           'check_permission', 'get_auth_statistics', 'cleanup_expired_sessions']