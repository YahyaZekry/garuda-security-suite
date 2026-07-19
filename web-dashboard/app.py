"""
Optimized Flask Web Dashboard for Aegis Security Suite
Provides web interface with memory management and performance optimizations
"""

import os
import sys
import json
import time
import psutil
import threading
import gc
import sqlite3
from datetime import datetime, timedelta
from flask import Flask, render_template, request, jsonify, g, session, redirect, url_for, flash
from flask_socketio import SocketIO, emit
from flask_wtf.csrf import CSRFProtect, CSRFError, generate_csrf as generate_csrf_token
import secrets

# Back-compat: an existing install from before the AEGIS_HOME rename
# (2026-07-18) may still have SECURITY_SUITE_HOME set (e.g. baked into an
# already-installed systemd unit's Environment= line). Set AEGIS_HOME from
# it here, before any of the API blueprint modules below read AEGIS_HOME as
# a module-level constant at import time.
if 'AEGIS_HOME' not in os.environ and 'SECURITY_SUITE_HOME' in os.environ:
    os.environ['AEGIS_HOME'] = os.environ['SECURITY_SUITE_HOME']

# Import security utilities and authentication
from security_utils import SecurityLogger, InputValidator, check_password_strength, hash_password, verify_password
from auth import require_auth, login_required, authenticate_user, create_user_session, destroy_session, require_role, AUTH_DB_PATH

# Import API modules
from api.system import system_bp
from api.behavioral import behavioral_bp
from api.threats import threats_bp
from api.incidents import incidents_bp
from api.api_keys import api_keys_bp
from api.config import config_bp, is_single_user_mode
from api.scan import scan_bp
from api.security_monitoring import security_monitoring_bp, start_background_monitoring, stop_background_monitoring

def load_or_create_secret_key():
    """Load a persisted Flask secret key, generating one on first run.
    Regenerating this on every process start (the old behavior) invalidates
    all sessions/CSRF tokens on every restart, and gives each gunicorn
    worker a different key, breaking sessions depending on which worker
    handles a request."""
    key_dir = os.path.join(os.environ.get('AEGIS_HOME', '/opt/aegis-security-suite'),
                            'configs', 'web-dashboard')
    key_file = os.path.join(key_dir, '.flask_secret_key')
    os.makedirs(key_dir, exist_ok=True)
    if os.path.exists(key_file):
        with open(key_file, 'rb') as f:
            return f.read()
    key = os.urandom(64)
    with open(key_file, 'wb') as f:
        f.write(key)
    os.chmod(key_file, 0o600)
    return key

# Create Flask app with optimizations
app = Flask(__name__)
app.config['SECRET_KEY'] = load_or_create_secret_key()
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB max file size
app.config['SEND_FILE_MAX_AGE_DEFAULT'] = 0  # Disable caching for dynamic content
app.config['WTF_CSRF_TIME_LIMIT'] = 3600  # CSRF token valid for 1 hour
app.config['WTF_CSRF_SSL_STRICT'] = True  # Enforce SSL for CSRF
app.config['PERMANENT_SESSION_LIFETIME'] = timedelta(days=30)  # Cookie's outer expiry cap; the
# shorter, configurable idle timeout for non-"remember me" sessions is enforced
# server-side in auth.require_auth(), not by mutating this global setting per-request.

# Initialize CSRF protection
csrf = CSRFProtect(app)

@app.errorhandler(CSRFError)
def handle_csrf_error(e):
    """Central handler for Flask-WTF CSRF failures (expired/missing/invalid
    token) across both HTML form posts and JSON API calls."""
    SecurityLogger.log_security_event('csrf_validation_failed', {
        'ip_address': request.remote_addr,
        'endpoint': request.endpoint,
        'reason': e.description
    }, 'WARNING')
    if request.accept_mimetypes.accept_json and not request.accept_mimetypes.accept_html:
        return jsonify({'error': 'Invalid or missing CSRF token'}), 400
    flash('Your session expired or the request was invalid. Please try again.', 'error')
    return redirect(url_for('login'))

# Configure SocketIO with memory limits and CORS
socketio = SocketIO(app,
                   async_mode='threading',
                   ping_timeout=30,
                   ping_interval=25,
                   cors_allowed_origins="*",
                   logger=True,
                   engineio_logger=True)

# Load configuration from config file
def load_config():
    """Load configuration from dashboard config file"""
    config = {
        'MEMORY_THRESHOLD_WARNING': 85,  # Default values
        'MEMORY_THRESHOLD_CRITICAL': 95,
        'MEMORY_CHECK_INTERVAL': 30,
        'MAX_CONCURRENT_CONNECTIONS': 50,
        'CONNECTION_TIMEOUT': 300
    }
    
    try:
        config_file = os.path.join(os.environ.get('AEGIS_HOME', '/opt/aegis-security-suite'),
                                  'web-dashboard', 'config', 'dashboard.conf')
        if os.path.exists(config_file):
            import configparser
            parser = configparser.ConfigParser()
            parser.read(config_file)
            
            # Load monitoring section
            if parser.has_section('monitoring'):
                config['MAX_CONCURRENT_CONNECTIONS'] = parser.getint('monitoring', 'max_connections', fallback=50)
            
            # Load alerts section
            if parser.has_section('alerts'):
                config['MEMORY_THRESHOLD_WARNING'] = parser.getint('alerts', 'alert_threshold_memory', fallback=85)
            
            # Load performance section
            if parser.has_section('performance'):
                config['CONNECTION_TIMEOUT'] = parser.getint('performance', 'connection_pool_size', fallback=300) * 1
                
    except Exception as e:
        print(f"Warning: Could not load config file: {e}")
    
    return config

# Load configuration
config = load_config()

# Memory monitoring configuration
MEMORY_THRESHOLD_WARNING = config['MEMORY_THRESHOLD_WARNING']  # Percentage
MEMORY_THRESHOLD_CRITICAL = config['MEMORY_THRESHOLD_CRITICAL']  # Percentage
MEMORY_CHECK_INTERVAL = config['MEMORY_CHECK_INTERVAL']  # Seconds
MAX_CONCURRENT_CONNECTIONS = config['MAX_CONCURRENT_CONNECTIONS']
CONNECTION_TIMEOUT = config['CONNECTION_TIMEOUT']  # 5 minutes

# Global variables for monitoring
memory_monitor_active = False
last_memory_check = 0
active_connections = 0
connection_lock = threading.Lock()

# Database paths
BEHAVIORAL_DB = os.path.join(os.environ.get('AEGIS_HOME', '/opt/aegis-security-suite'),
                              'configs', 'behavioral_analysis', 'behavioral_data.db')
# AUTH_DB_PATH is imported from auth.py (single source of truth) - this used
# to be redefined here pointing at AEGIS_HOME while auth.py resolves
# it relative to os.getcwd(), so /reset-password silently queried an empty/
# nonexistent database ("no such table: users") whenever the two diverged.

def get_memory_usage():
    """Get current memory usage percentage"""
    try:
        memory = psutil.virtual_memory()
        return memory.percent
    except:
        return 0

def check_memory_usage():
    """Check memory usage and perform cleanup if needed"""
    global last_memory_check
    
    current_time = time.time()
    if current_time - last_memory_check < MEMORY_CHECK_INTERVAL:
        return
    
    last_memory_check = current_time
    memory_usage = get_memory_usage()
    
    if memory_usage >= MEMORY_THRESHOLD_CRITICAL:
        SecurityLogger.log_security_event('critical_memory_usage', {
            'memory_usage': memory_usage,
            'active_connections': active_connections
        }, 'CRITICAL')
        
        # Perform emergency cleanup
        perform_emergency_cleanup()
        
    elif memory_usage >= MEMORY_THRESHOLD_WARNING:
        SecurityLogger.log_security_event('high_memory_usage', {
            'memory_usage': memory_usage,
            'active_connections': active_connections
        }, 'WARNING')
        
        # Perform preventive cleanup
        perform_preventive_cleanup()

def perform_emergency_cleanup():
    """Perform emergency memory cleanup"""
    try:
        # Force garbage collection
        gc.collect()
        
        # Clear Flask session data
        session.clear()
        
        # Close database connections
        close_db_connections()
        
        # Clear any cached data
        if hasattr(app, 'cache'):
            app.cache.clear()
        
        SecurityLogger.log_security_event('emergency_cleanup_performed', {
            'memory_before': get_memory_usage()
        })
        
    except Exception as e:
        SecurityLogger.log_security_event('emergency_cleanup_failed', {
            'error': str(e)
        }, 'ERROR')

def perform_preventive_cleanup():
    """Perform preventive memory cleanup"""
    try:
        # Force garbage collection
        gc.collect()
        
        # Clear old session data
        if hasattr(session, 'modified'):
            session.permanent = True
        
        SecurityLogger.log_security_event('preventive_cleanup_performed', {
            'memory_before': get_memory_usage()
        })
        
    except Exception as e:
        SecurityLogger.log_security_event('preventive_cleanup_failed', {
            'error': str(e)
        }, 'ERROR')

def close_db_connections():
    """Close database connections"""
    try:
        # Close any open database connections
        if hasattr(g, 'db_connection'):
            g.db_connection.close()
            delattr(g, 'db_connection')
        
        # Close SQLite connections in behavioral database
        if os.path.exists(BEHAVIORAL_DB):
            import sqlite3
            conn = sqlite3.connect(BEHAVIORAL_DB)
            conn.execute("PRAGMA wal_checkpoint(TRUNCATE);")
            conn.close()
            
    except Exception as e:
        SecurityLogger.log_security_event('db_cleanup_failed', {
            'error': str(e)
        }, 'ERROR')

def monitor_connections():
    """Monitor active connections"""
    global active_connections
    
    with connection_lock:
        active_connections += 1
        
        # Check connection limit
        if active_connections > MAX_CONCURRENT_CONNECTIONS:
            SecurityLogger.log_security_event('connection_limit_exceeded', {
                'active_connections': active_connections,
                'max_connections': MAX_CONCURRENT_CONNECTIONS
            }, 'WARNING')

def cleanup_connections():
    """Clean up connection tracking"""
    global active_connections
    
    with connection_lock:
        if active_connections > 0:
            active_connections -= 1

@app.before_request
def before_request():
    """Before request handler"""
    # Monitor connections
    monitor_connections()
    
    # Check memory usage
    check_memory_usage()
    
    # Set request timeout
    g.start_time = time.time()

@app.after_request
def after_request(response):
    """After request handler"""
    # Clean up connections
    cleanup_connections()
    
    # Add comprehensive security headers
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['X-Frame-Options'] = 'DENY'
    response.headers['X-XSS-Protection'] = '1; mode=block'
    response.headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains; preload'
    response.headers['Content-Security-Policy'] = (
        "default-src 'self'; "
        "script-src 'self' 'unsafe-inline' 'unsafe-eval' https://cdn.jsdelivr.net https://cdn.socket.io; "
        "style-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net https://cdnjs.cloudflare.com https://fonts.googleapis.com; "
        "img-src 'self' data: https:; "
        "font-src 'self' https://cdnjs.cloudflare.com https://fonts.gstatic.com; "
        "connect-src 'self' ws: wss:; "
        "frame-ancestors 'none'; "
        "base-uri 'self'; "
        "form-action 'self'; "
        "upgrade-insecure-requests"
    )
    response.headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
    response.headers['Permissions-Policy'] = (
        'geolocation=(), microphone=(), camera=(), '
        'payment=(), usb=(), magnetometer=(), gyroscope=(), '
        'accelerometer=(), ambient-light-sensor=(), autoplay=(), '
        'encrypted-media=(), fullscreen=(), picture-in-picture=()'
    )
    response.headers['X-Permitted-Cross-Domain-Policies'] = 'none'
    response.headers['X-Download-Options'] = 'noopen'
    response.headers['X-Robots-Tag'] = 'noindex, nofollow, nosnippet, noarchive'
    
    # Remove server information
    response.headers.pop('Server', None)
    
    # Log request completion
    if hasattr(g, 'start_time'):
        duration = time.time() - g.start_time
        if duration > 5.0:  # Log slow requests
            SecurityLogger.log_security_event('slow_request', {
                'endpoint': request.endpoint,
                'duration': duration,
                'memory_usage': get_memory_usage()
            }, 'WARNING')
    
    return response

@app.errorhandler(404)
def not_found(error):
    """Handle 404 errors"""
    if request.accept_mimetypes.accept_json and not request.accept_mimetypes.accept_html:
        return jsonify({'error': 'Resource not found'}), 404
    return render_template('404.html'), 404

@app.errorhandler(500)
def internal_error(error):
    """Handle 500 errors"""
    SecurityLogger.log_security_event('internal_server_error', {
        'error': str(error),
        'endpoint': request.endpoint,
        'memory_usage': get_memory_usage()
    }, 'ERROR')
    
    if request.accept_mimetypes.accept_json and not request.accept_mimetypes.accept_html:
        return jsonify({'error': 'Internal server error'}), 500
    return render_template('500.html'), 500

@app.errorhandler(413)
def too_large(error):
    """Handle file too large errors"""
    if request.accept_mimetypes.accept_json and not request.accept_mimetypes.accept_html:
        return jsonify({'error': 'File too large'}), 413
    return render_template('500.html'), 413

@app.context_processor
def inject_globals():
    """Inject global variables into all templates"""
    return {
        'generate_csrf_token': generate_csrf_token,
        'now': datetime,
        'is_single_user_mode': is_single_user_mode
    }

# Routes
@app.route('/login', methods=['GET', 'POST'])
def login():
    """Login page and authentication"""
    if request.method == 'GET':
        # Generate CSRF token for login form
        csrf_token = generate_csrf_token()
        return render_template('login.html', csrf_token=csrf_token)

    # CSRF token is validated automatically by Flask-WTF's global
    # CSRFProtect before this view runs (see handle_csrf_error above).

    # Handle POST login
    username = InputValidator.sanitize_string(request.form.get('username', ''), 50)
    password = request.form.get('password', '')
    mfa_token = request.form.get('mfa_token', '')  # Optional MFA token
    
    # Authenticate user
    auth_result = authenticate_user(
        username,
        password,
        request.remote_addr,
        request.headers.get('User-Agent'),
        mfa_token
    )
    
    if auth_result['success']:
        # Check if password reset is required
        if auth_result.get('password_reset_required'):
            session['temp_user_id'] = auth_result['user_id']
            session['password_reset_required'] = True
            return redirect(url_for('reset_password'))
        
        # Create session
        session_id = create_user_session(
            auth_result['user_id'],
            auth_result['username'],
            auth_result['role'],
            request.remote_addr,
            request.headers.get('User-Agent')
        )
        
        if session_id:
            # Clear any pre-auth session state before writing the authenticated
            # session (mitigates session fixation; Flask has no session.regenerate()
            # -- the underlying signed cookie is re-issued automatically whenever
            # the session dict content changes).
            session.clear()
            session['session_id'] = session_id
            session['username'] = auth_result['username']
            session['role'] = auth_result['role']
            session['last_activity'] = datetime.now().isoformat()
            # "Remember Me" sessions rely on the cookie's own (30-day) expiry;
            # sessions without it are additionally subject to the configurable
            # idle timeout enforced in auth.require_auth().
            session['remember_me'] = request.form.get('remember') == '1'
            session.permanent = True

            SecurityLogger.log_security_event('user_logged_in', {
                'user_id': auth_result['user_id'],
                'username': auth_result['username'],
                'ip_address': request.remote_addr,
                'user_agent': request.headers.get('User-Agent')
            })
            
            return redirect(url_for('dashboard'))
        else:
            flash('Session creation failed', 'error')
            return render_template('login.html', error='Session creation failed')
    else:
        # Handle MFA requirement
        if auth_result.get('mfa_required'):
            return render_template('login.html',
                               error=auth_result['error'],
                               mfa_required=True,
                               username=username,
                               csrf_token=generate_csrf_token())
        else:
            return render_template('login.html',
                               error=auth_result['error'],
                               csrf_token=generate_csrf_token())

@app.route('/reset-password', methods=['GET', 'POST'])
def reset_password():
    """Reset password for users who need to change it. Reachable two ways:
    (1) forced reset right after login, before a full session exists yet
    (session['password_reset_required'] + temp_user_id), or (2) a fully
    logged-in user voluntarily changing their password. @login_required
    can't be used here since it would block case (1) before this view
    ever runs."""
    if session.get('password_reset_required') and session.get('temp_user_id'):
        pass  # forced reset flow, no full session required yet
    elif session.get('session_id'):
        from auth import validate_session
        user_data = validate_session(session['session_id'], request.remote_addr)
        if not user_data:
            session.clear()
            return redirect(url_for('login'))
        g.current_user = user_data
    else:
        return redirect(url_for('login'))

    if request.method == 'GET':
        csrf_token = generate_csrf_token()
        return render_template('reset_password.html', csrf_token=csrf_token)

    # CSRF token is validated automatically by Flask-WTF's global
    # CSRFProtect before this view runs (see handle_csrf_error above).

    # Get and validate new password
    current_password = request.form.get('current_password', '')
    new_password = request.form.get('new_password', '')
    confirm_password = request.form.get('confirm_password', '')
    
    # Validate passwords
    if new_password != confirm_password:
        return render_template('reset_password.html',
                           error='Passwords do not match',
                           csrf_token=generate_csrf_token())
    
    # Check password strength
    password_check = check_password_strength(new_password)
    if password_check['strength'] in ['very_weak', 'weak']:
        return render_template('reset_password.html',
                           error='Password is too weak: ' + ', '.join(password_check['issues']),
                           csrf_token=generate_csrf_token())
    
    # Get user ID
    user_id = session.get('temp_user_id') or g.current_user.get('user_id')
    
    # Update password
    try:
        conn = sqlite3.connect(AUTH_DB_PATH)
        cursor = conn.cursor()
        
        # Get current password hash
        cursor.execute("SELECT password_hash, salt, username, role FROM users WHERE id = ?", (user_id,))
        user_data = cursor.fetchone()

        if not user_data:
            return render_template('reset_password.html',
                               error='User not found',
                               csrf_token=generate_csrf_token())

        stored_hash, salt, username, role = user_data
        
        # Verify current password
        if not verify_password(current_password, stored_hash, salt):
            return render_template('reset_password.html',
                               error='Current password is incorrect',
                               csrf_token=generate_csrf_token())
        
        # Generate new password hash
        new_salt = secrets.token_hex(32)
        new_hash = hash_password(new_password, new_salt)
        
        # Update password
        cursor.execute("""
        UPDATE users
        SET password_hash = ?, salt = ?, password_changed_at = ?,
            password_reset_required = 0, last_password_change = ?
        WHERE id = ?
        """, (new_hash, new_salt, datetime.now().isoformat(),
               datetime.now().isoformat(), user_id))
        
        conn.commit()
        conn.close()
        
        SecurityLogger.log_security_event('password_reset', {
            'user_id': user_id,
            'ip_address': request.remote_addr,
            'user_agent': request.headers.get('User-Agent')
        })
        
        # Clear temporary session data
        session.pop('temp_user_id', None)
        session.pop('password_reset_required', None)

        # Forced-reset flow: no full session exists yet, so create one now
        # rather than bouncing the user back to the login page again.
        if not session.get('session_id'):
            new_session_id = create_user_session(
                user_id, username, role, request.remote_addr, request.headers.get('User-Agent'))
            if new_session_id:
                session['session_id'] = new_session_id
                session['username'] = username
                session['role'] = role
                session['last_activity'] = datetime.now().isoformat()
                session['remember_me'] = False
                session.permanent = True

        flash('Password changed successfully', 'success')
        return redirect(url_for('dashboard'))
        
    except Exception as e:
        SecurityLogger.log_security_event('password_reset_error', {
            'user_id': user_id,
            'error': str(e)
        }, 'ERROR')
        return render_template('reset_password.html',
                           error='An error occurred while resetting password',
                           csrf_token=generate_csrf_token())

@app.route('/logout')
def logout():
    """Logout route"""
    session_id = session.get('session_id')
    if session_id:
        destroy_session(session_id)
    flash('You have been logged out successfully', 'success')
    session.clear()
    return redirect(url_for('login'))

@app.route('/')
@login_required
def dashboard():
    """Main dashboard page"""
    try:
        # Get system status with memory check
        memory_usage = get_memory_usage()
        
        # Get threat score from database
        threat_score = 0
        if os.path.exists(BEHAVIORAL_DB):
            try:
                import sqlite3
                conn = sqlite3.connect(BEHAVIORAL_DB, timeout=5)
                cursor = conn.cursor()
                cursor.execute("SELECT overall_score FROM threat_scores ORDER BY timestamp DESC LIMIT 1")
                result = cursor.fetchone()
                if result:
                    threat_score = result[0]
                conn.close()
            except:
                threat_score = 0
        
        # Get system metrics from API
        from api.system import get_system_info, get_security_suite_status
        system_data = get_system_info()
        security_data = get_security_suite_status()
        
        # Get recent incidents
        from api.incidents import get_incidents
        incidents_data = get_incidents(limit=10)
        recent_incidents = incidents_data.get('incidents', [])
        
        # Get recent threats
        from api.threats import get_recent_threats
        threats_data = get_recent_threats(limit=10)
        recent_threats = threats_data.get('threats', [])
        
        # Get behavioral statistics
        from api.behavioral import get_behavioral_statistics
        behavioral_stats = get_behavioral_statistics()
        
        # Get incident statistics
        from api.incidents import get_incident_statistics
        incident_stats = get_incident_statistics()
        
        return render_template('dashboard.html',
                           memory_usage=memory_usage,
                           threat_score=threat_score,
                           active_connections=active_connections,
                           system_data=system_data,
                           security_data=security_data,
                           recent_incidents=recent_incidents,
                           recent_threats=recent_threats,
                           behavioral_stats=behavioral_stats.get('statistics', {}),
                           incident_stats=incident_stats.get('statistics', {}))
    except Exception as e:
        SecurityLogger.log_security_event('dashboard_error', {
            'error': str(e),
            'memory_usage': get_memory_usage()
        }, 'ERROR')
        return render_template('dashboard.html',
                           memory_usage=0,
                           threat_score=0,
                           active_connections=0,
                           system_data={},
                           security_data={},
                           recent_incidents=[],
                           recent_threats=[],
                           behavioral_stats={},
                           incident_stats={})

@app.route('/behavioral')
@login_required
def behavioral():
    """Behavioral analysis page"""
    try:
        # Get behavioral data with memory limits
        behavioral_data = []
        if os.path.exists(BEHAVIORAL_DB):
            try:
                import sqlite3
                conn = sqlite3.connect(BEHAVIORAL_DB, timeout=5)
                cursor = conn.cursor()
                cursor.execute("""
                    SELECT timestamp, anomaly_type, severity, description
                    FROM anomaly_events
                    WHERE timestamp > datetime('now', '-24 hours')
                    ORDER BY timestamp DESC
                    LIMIT 50
                """)
                behavioral_data = cursor.fetchall()
                conn.close()
            except:
                behavioral_data = []
        
        # Get comprehensive behavioral data from API
        from api.behavioral import get_behavioral_data, get_anomalies, get_baseline_status, get_behavioral_statistics
        
        # Get behavioral metrics for different time ranges
        metrics_24h = get_behavioral_data('24h')
        metrics_7d = get_behavioral_data('7d')
        metrics_30d = get_behavioral_data('30d')
        
        # Get anomalies
        anomalies_data = get_anomalies(limit=100)
        anomalies = anomalies_data.get('anomalies', [])
        
        # Get baseline status
        baseline_status = get_baseline_status()
        
        # Get behavioral statistics
        statistics = get_behavioral_statistics()
        
        return render_template('behavioral.html',
                           behavioral_data=behavioral_data,
                           metrics_24h=metrics_24h,
                           metrics_7d=metrics_7d,
                           metrics_30d=metrics_30d,
                           anomalies=anomalies,
                           baseline_status=baseline_status,
                           statistics=statistics.get('statistics', {}))
    except Exception as e:
        SecurityLogger.log_security_event('behavioral_page_error', {
            'error': str(e),
            'memory_usage': get_memory_usage()
        }, 'ERROR')
        return render_template('behavioral.html',
                           behavioral_data=[],
                           metrics_24h={'data': []},
                           metrics_7d={'data': []},
                           metrics_30d={'data': []},
                           anomalies=[],
                           baseline_status={},
                           statistics={})

@app.route('/threats')
@login_required
def threats():
    """Threat intelligence page"""
    try:
        # Get comprehensive threat data from API
        from api.threats import get_ioc_database_stats, get_threat_feeds_status, get_recent_threats, search_iocs
        
        # Get IOC database statistics
        ioc_stats = get_ioc_database_stats()
        
        # Get threat feeds status
        feeds_status = get_threat_feeds_status()
        
        # Get recent threats
        recent_threats = get_recent_threats(limit=20)
        
        # Get IOCs for display
        iocs_data = search_iocs(limit=50)
        
        return render_template('threats.html',
                           ioc_stats=ioc_stats,
                           feeds_status=feeds_status,
                           recent_threats=recent_threats.get('threats', []),
                           iocs_data=iocs_data.get('iocs', []))
    except Exception as e:
        SecurityLogger.log_security_event('threats_page_error', {
            'error': str(e),
            'memory_usage': get_memory_usage()
        }, 'ERROR')
        return render_template('threats.html',
                           ioc_stats={},
                           feeds_status={'feeds': []},
                           recent_threats=[],
                           iocs_data=[])

@app.route('/incidents')
@login_required
def incidents():
    """Incident response page"""
    try:
        # Get comprehensive incident data from API
        from api.incidents import get_incidents, get_incident_statistics
        
        # Get incidents list
        incidents_data = get_incidents(limit=50)
        incidents_list = incidents_data.get('incidents', [])
        
        # Get incident statistics
        statistics = get_incident_statistics()
        
        return render_template('incidents.html',
                           incidents=incidents_list,
                           statistics=statistics.get('statistics', {}),
                           total_incidents=incidents_data.get('total', 0))
    except Exception as e:
        SecurityLogger.log_security_event('incidents_page_error', {
            'error': str(e),
            'memory_usage': get_memory_usage()
        }, 'ERROR')
        return render_template('incidents.html',
                           incidents=[],
                           statistics={},
                           total_incidents=0)

@app.route('/config')
@login_required
def config():
    """Configuration page"""
    try:
        # Get configuration data from various sources
        from api.system import get_system_info, get_security_suite_status
        from api.api_keys import api_key_manager
        
        # Get system information
        system_data = get_system_info()
        
        # Get security suite status
        security_data = get_security_suite_status()
        
        # Get API keys (if available)
        api_keys = []
        try:
            conn = api_key_manager.ensure_db()
            if conn:
                cursor = conn.cursor()
                cursor.execute("""
                SELECT key_name, permissions, is_active, created_at, last_used, usage_count
                FROM api_keys
                ORDER BY created_at DESC
                """)
                
                for row in cursor.fetchall():
                    api_keys.append({
                        'key_name': row[0],
                        'permissions': json.loads(row[1]) if row[1] else [],
                        'is_active': bool(row[2]),
                        'created_at': row[3],
                        'last_used': row[4],
                        'usage_count': row[5]
                    })
                conn.close()
        except:
            api_keys = []
        
        # Get current configuration
        current_config = {
            'memory_threshold_warning': MEMORY_THRESHOLD_WARNING,
            'memory_threshold_critical': MEMORY_THRESHOLD_CRITICAL,
            'memory_check_interval': MEMORY_CHECK_INTERVAL,
            'max_concurrent_connections': MAX_CONCURRENT_CONNECTIONS,
            'connection_timeout': CONNECTION_TIMEOUT
        }
        
        return render_template('config.html',
                           system_data=system_data,
                           security_data=security_data,
                           api_keys=api_keys,
                           current_config=current_config)
    except Exception as e:
        SecurityLogger.log_security_event('config_page_error', {
            'error': str(e),
            'memory_usage': get_memory_usage()
        }, 'ERROR')
        return render_template('config.html',
                           system_data={},
                           security_data={},
                           api_keys=[],
                           current_config={})

@app.route('/security-dashboard')
@login_required
@require_role('admin')
def security_dashboard():
    """Security monitoring dashboard page"""
    try:
        return render_template('security_dashboard.html')
    except Exception as e:
        SecurityLogger.log_security_event('security_dashboard_error', {
            'error': str(e),
            'memory_usage': get_memory_usage()
        }, 'ERROR')
        return render_template('security_dashboard.html')

# WebSocket events with memory management
@socketio.on('connect')
def handle_connect():
    """Handle client connection with authentication"""
    try:
        # Check connection limit
        if active_connections >= MAX_CONCURRENT_CONNECTIONS:
            SecurityLogger.log_security_event('connection_rejected', {
                'active_connections': active_connections,
                'max_connections': MAX_CONCURRENT_CONNECTIONS
            }, 'WARNING')
            return False
        
        # Authenticate WebSocket connection - every client must have a
        # valid authenticated Flask session, regardless of source address.
        session_id = session.get('session_id')
        if not session_id:
            SecurityLogger.log_security_event('unauthorized_connection', {
                'remote_addr': request.remote_addr
            }, 'WARNING')
            return False
        
        emit('status', {'message': 'Connected to Aegis Security Suite'})
        SecurityLogger.log_security_event('client_connected', {
            'active_connections': active_connections,
            'session_id': session_id
        })
    except Exception as e:
        SecurityLogger.log_security_event('connection_error', {
            'error': str(e)
        }, 'ERROR')

@socketio.on('disconnect')
def handle_disconnect():
    """Handle client disconnection"""
    try:
        SecurityLogger.log_security_event('client_disconnected', {
            'active_connections': active_connections
        })
    except Exception as e:
        SecurityLogger.log_security_event('disconnection_error', {
            'error': str(e)
        }, 'ERROR')

@socketio.on('subscribe_system')
def handle_subscribe_system():
    """Handle system status subscription"""
    try:
        # Join system room
        from flask_socketio import join_room
        join_room('system')
        
        emit('status', {'message': 'Subscribed to system updates'})
    except Exception as e:
        SecurityLogger.log_security_event('subscribe_error', {
            'error': str(e),
            'room': 'system'
        }, 'ERROR')

@socketio.on('subscribe_behavioral')
def handle_subscribe_behavioral():
    """Handle behavioral analysis subscription"""
    try:
        from flask_socketio import join_room
        join_room('behavioral')
        
        emit('status', {'message': 'Subscribed to behavioral analysis updates'})
    except Exception as e:
        SecurityLogger.log_security_event('subscribe_error', {
            'error': str(e),
            'room': 'behavioral'
        }, 'ERROR')

@socketio.on('subscribe_threats')
def handle_subscribe_threats():
    """Handle threat intelligence subscription"""
    try:
        from flask_socketio import join_room
        join_room('threats')
        
        emit('status', {'message': 'Subscribed to threat intelligence updates'})
    except Exception as e:
        SecurityLogger.log_security_event('subscribe_error', {
            'error': str(e),
            'room': 'threats'
        }, 'ERROR')

@socketio.on('subscribe_incidents')
def handle_subscribe_incidents():
    """Handle incident management subscription"""
    try:
        from flask_socketio import join_room
        join_room('incidents')
        
        emit('status', {'message': 'Subscribed to incident management updates'})
    except Exception as e:
        SecurityLogger.log_security_event('subscribe_error', {
            'error': str(e),
            'room': 'incidents'
        }, 'ERROR')

@socketio.on('start_monitoring')
def handle_start_monitoring():
    """Handle start monitoring request"""
    try:
        emit('status', {'message': 'Real-time monitoring started'})
        SecurityLogger.log_security_event('monitoring_started', {
            'session_id': session.get('session_id')
        })
    except Exception as e:
        SecurityLogger.log_security_event('monitoring_error', {
            'error': str(e)
        }, 'ERROR')

@socketio.on('stop_monitoring')
def handle_stop_monitoring():
    """Handle stop monitoring request"""
    try:
        emit('status', {'message': 'Real-time monitoring stopped'})
        SecurityLogger.log_security_event('monitoring_stopped', {
            'session_id': session.get('session_id')
        })
    except Exception as e:
        SecurityLogger.log_security_event('monitoring_error', {
            'error': str(e)
        }, 'ERROR')

@socketio.on('heartbeat')
def handle_heartbeat():
    """Handle client heartbeat"""
    try:
        emit('heartbeat_response', {'timestamp': datetime.now().isoformat()})
    except Exception as e:
        SecurityLogger.log_security_event('heartbeat_error', {
            'error': str(e)
        }, 'ERROR')

@socketio.on('unsubscribe_system')
def handle_unsubscribe_system():
    """Handle system status unsubscription"""
    try:
        from flask_socketio import leave_room
        leave_room('system')
        
        emit('status', {'message': 'Unsubscribed from system updates'})
    except Exception as e:
        SecurityLogger.log_security_event('unsubscribe_error', {
            'error': str(e),
            'room': 'system'
        }, 'ERROR')

@socketio.on('unsubscribe_behavioral')
def handle_unsubscribe_behavioral():
    """Handle behavioral analysis unsubscription"""
    try:
        from flask_socketio import leave_room
        leave_room('behavioral')
        
        emit('status', {'message': 'Unsubscribed from behavioral analysis updates'})
    except Exception as e:
        SecurityLogger.log_security_event('unsubscribe_error', {
            'error': str(e),
            'room': 'behavioral'
        }, 'ERROR')

@socketio.on('unsubscribe_threats')
def handle_unsubscribe_threats():
    """Handle threat intelligence unsubscription"""
    try:
        from flask_socketio import leave_room
        leave_room('threats')
        
        emit('status', {'message': 'Unsubscribed from threat intelligence updates'})
    except Exception as e:
        SecurityLogger.log_security_event('unsubscribe_error', {
            'error': str(e),
            'room': 'threats'
        }, 'ERROR')

@socketio.on('unsubscribe_incidents')
def handle_unsubscribe_incidents():
    """Handle incident management unsubscription"""
    try:
        from flask_socketio import leave_room
        leave_room('incidents')
        
        emit('status', {'message': 'Unsubscribed from incident management updates'})
    except Exception as e:
        SecurityLogger.log_security_event('unsubscribe_error', {
            'error': str(e),
            'room': 'incidents'
        }, 'ERROR')

# Optimized real-time monitoring with memory limits
def background_monitoring():
    """Background monitoring with memory management"""
    global memory_monitor_active
    
    while memory_monitor_active:
        try:
            # Check memory usage
            memory_usage = get_memory_usage()
            
            # Get system metrics
            cpu_usage = psutil.cpu_percent(interval=1)
            
            # Get threat score
            threat_score = 0
            if os.path.exists(BEHAVIORAL_DB):
                try:
                    import sqlite3
                    conn = sqlite3.connect(BEHAVIORAL_DB, timeout=5)
                    cursor = conn.cursor()
                    cursor.execute("SELECT overall_score FROM threat_scores ORDER BY timestamp DESC LIMIT 1")
                    result = cursor.fetchone()
                    if result:
                        threat_score = result[0]
                    conn.close()
                except:
                    threat_score = 0

            # Detailed resource metrics for the dashboard's System Metrics panel
            vm = psutil.virtual_memory()
            disk = psutil.disk_usage('/')
            try:
                load_avg = os.getloadavg()[0]
            except (AttributeError, OSError):
                load_avg = 0
            from api.system import get_network_rate_kbps
            network_in_kbps, network_out_kbps = get_network_rate_kbps()

            # Emit system metrics updates
            socketio.emit('system_update', {
                'timestamp': datetime.now().isoformat(),
                'memory_usage': memory_usage,
                'cpu_usage': cpu_usage,
                'cpu_count': psutil.cpu_count() or 0,
                'load_avg': load_avg,
                'memory_used_gb': round(vm.used / (1024 ** 3), 2),
                'memory_total_gb': round(vm.total / (1024 ** 3), 2),
                'disk_usage': disk.percent,
                'disk_used_gb': round(disk.used / (1024 ** 3), 2),
                'disk_total_gb': round(disk.total / (1024 ** 3), 2),
                'network_in_kbps': network_in_kbps,
                'network_out_kbps': network_out_kbps,
                'threat_score': threat_score,
                'active_connections': active_connections
            }, room='system')
            
            # Check for behavioral analysis alerts
            check_behavioral_alerts()
            
            # Check for new threat intelligence
            check_threat_intelligence_updates()
            
            # Check for incident status changes
            check_incident_updates()
            
            # Check security suite status
            check_security_suite_status()
            
            # Perform cleanup if needed
            if memory_usage > MEMORY_THRESHOLD_WARNING:
                perform_preventive_cleanup()
            
            # Sleep with memory check
            for i in range(30):  # 30 seconds with 1-second intervals
                if not memory_monitor_active:
                    break
                time.sleep(1)
                
                # Check memory during sleep
                if i % 10 == 0:  # Every 10 seconds
                    current_memory = get_memory_usage()
                    if current_memory > MEMORY_THRESHOLD_CRITICAL:
                        perform_emergency_cleanup()
                        break
            
        except Exception as e:
            SecurityLogger.log_security_event('monitoring_error', {
                'error': str(e),
                'memory_usage': get_memory_usage()
            }, 'ERROR')
            time.sleep(5)  # Wait before retrying

def check_behavioral_alerts():
    """Check for new behavioral analysis alerts"""
    try:
        if os.path.exists(BEHAVIORAL_DB):
            import sqlite3
            conn = sqlite3.connect(BEHAVIORAL_DB, timeout=5)
            cursor = conn.cursor()
            
            # Get recent anomalies from last 5 minutes
            cursor.execute("""
                SELECT timestamp, anomaly_type, severity, description
                FROM anomaly_events
                WHERE timestamp > datetime('now', '-5 minutes')
                ORDER BY timestamp DESC
                LIMIT 10
            """)
            
            anomalies = cursor.fetchall()
            conn.close()
            
            if anomalies:
                for anomaly in anomalies:
                    socketio.emit('behavioral_alert', {
                        'timestamp': anomaly[0],
                        'anomaly_type': anomaly[1],
                        'severity': anomaly[2],
                        'description': anomaly[3]
                    }, room='behavioral')
                    
    except Exception as e:
        SecurityLogger.log_security_event('behavioral_check_error', {
            'error': str(e)
        }, 'ERROR')

def check_threat_intelligence_updates():
    """Check for new threat intelligence"""
    try:
        # Get threat feeds status
        from api.threats import get_threat_feeds_status
        feeds_status = get_threat_feeds_status()
        
        # Emit threat intelligence updates
        socketio.emit('threat_intelligence_update', {
            'timestamp': datetime.now().isoformat(),
            'feeds_status': feeds_status
        }, room='threats')
        
    except Exception as e:
        SecurityLogger.log_security_event('threat_check_error', {
            'error': str(e)
        }, 'ERROR')

def check_incident_updates():
    """Check for incident status changes"""
    try:
        from api.incidents import get_incidents
        incidents_data = get_incidents(limit=10)
        
        # Emit incident updates
        socketio.emit('incident_update', {
            'timestamp': datetime.now().isoformat(),
            'incidents': incidents_data.get('incidents', [])
        }, room='incidents')
        
    except Exception as e:
        SecurityLogger.log_security_event('incident_check_error', {
            'error': str(e)
        }, 'ERROR')

def check_security_suite_status():
    """Check security suite component status"""
    try:
        from api.system import get_security_suite_status
        security_status = get_security_suite_status()
        
        # Emit security suite status updates
        socketio.emit('security_status_update', {
            'timestamp': datetime.now().isoformat(),
            'security_status': security_status
        }, room='system')
        
    except Exception as e:
        SecurityLogger.log_security_event('security_status_check_error', {
            'error': str(e)
        }, 'ERROR')

# Register blueprints
app.register_blueprint(system_bp)
app.register_blueprint(behavioral_bp)
app.register_blueprint(threats_bp)
app.register_blueprint(incidents_bp)
app.register_blueprint(api_keys_bp)
app.register_blueprint(config_bp)
app.register_blueprint(scan_bp)
app.register_blueprint(security_monitoring_bp)

# Start background monitoring
def start_background_monitoring():
    """Start background monitoring thread"""
    global memory_monitor_active
    memory_monitor_active = True
    
    monitoring_thread = threading.Thread(target=background_monitoring, daemon=True)
    monitoring_thread.start()
    
    SecurityLogger.log_security_event('background_monitoring_started', {
        'memory_threshold_warning': MEMORY_THRESHOLD_WARNING,
        'memory_threshold_critical': MEMORY_THRESHOLD_CRITICAL
    })

# Graceful shutdown
def signal_handler(signum, frame):
    """Handle shutdown signals"""
    global memory_monitor_active
    memory_monitor_active = False
    
    SecurityLogger.log_security_event('shutdown_initiated', {
        'signal': signum,
        'memory_usage': get_memory_usage()
    })
    
    # Perform final cleanup
    perform_emergency_cleanup()
    
    # Exit gracefully
    sys.exit(0)

if __name__ == '__main__':
    import signal
    
    # Register signal handlers
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # Start background monitoring
    start_background_monitoring()
    
    # Run the app with optimizations
    try:
        SecurityLogger.log_security_event('dashboard_started', {
            'memory_threshold_warning': MEMORY_THRESHOLD_WARNING,
            'memory_threshold_critical': MEMORY_THRESHOLD_CRITICAL,
            'max_connections': MAX_CONCURRENT_CONNECTIONS
        })
        
        socketio.run(app, 
                    host='0.0.0.0', 
                    port=8080, 
                    debug=False,
                    allow_unsafe_werkzeug=True)
                    
    except Exception as e:
        SecurityLogger.log_security_event('dashboard_startup_failed', {
            'error': str(e),
            'memory_usage': get_memory_usage()
        }, 'CRITICAL')
        sys.exit(1)