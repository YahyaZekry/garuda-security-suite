"""
Configuration Management API Module for Aegis Security Suite Dashboard
Provides configuration management, backup, and history tracking
"""

import os
import json
import shutil
import uuid
from datetime import datetime
from flask import Blueprint, jsonify, request, g, Response

from security_utils import (
    SecurityLogger, InputValidator, rate_limiter,
    require_api_key, rate_limit, validate_input, secure_headers
)
from auth import require_auth, require_role

config_bp = Blueprint('config', __name__, url_prefix='/api/config')

CONFIG_DIR = os.path.join(os.environ.get('AEGIS_HOME', '/opt/aegis-security-suite'), 'configs')
CONFIG_FILE = os.path.join(CONFIG_DIR, 'web-dashboard', 'dashboard.conf')
BACKUP_DIR = os.path.join(CONFIG_DIR, 'web-dashboard', 'backups')
HISTORY_FILE = os.path.join(CONFIG_DIR, 'web-dashboard', 'config_history.json')

DEFAULT_CONFIG = {
    'active_modules': 8,
    'security_level': 'High',
    'last_update': '2h',
    'config_status': 'Valid',
    # 'single_user' (default): one operator, no team-coordination UI/RBAC
    # friction. 'team': multi-analyst RBAC tiers, incident assignment/
    # escalation, and team-status are shown.
    'deployment_mode': 'single_user',
    'general': {
        'system_name': 'Aegis Security Suite',
        'environment': 'production',
        'log_level': 'info',
        'data_retention': 30,
        'backup_schedule': 'weekly',
        'timezone': 'UTC',
        'auto_updates': False,
        'telemetry': False
    },
    'security': {
        'level': 'high',
        'encryption_algorithm': 'AES-256',
        'session_timeout': 30,
        'max_login_attempts': 5,
        'password_policy': 'strong',
        'two_factor_auth': 'required',
        'ip_whitelist': False,
        'rate_limiting': True,
        'audit_logging': True
    },
    'scanning': {
        'frequency': 'daily',
        'intensity': 'medium',
        'max_duration': 4,
        'parallel_scans': 2,
        'directories': '/home,/var/log,/etc,/tmp',
        'exclude_patterns': '*.tmp,*.log,cache/*',
        'real_time': True,
        'heuristic_analysis': True,
        'behavioral_analysis': True
    },
    'notifications': {
        'email_level': 'important',
        'sms_level': 'critical',
        'smtp_server': '',
        'smtp_port': 587,
        'email_username': '',
        'email_password': '',
        'recipients': '',
        'webhook_enabled': False,
        'webhook_url': ''
    },
    'api': {
        'version': 'v2',
        'rate_limit': 100,
        'key_expiry': 30,
        'max_payload_size': 10,
        'cors_origins': '',
        'authentication': True,
        'logging': True,
        'documentation': True
    }
}


def ensure_dirs():
    os.makedirs(os.path.dirname(CONFIG_FILE), exist_ok=True)
    os.makedirs(BACKUP_DIR, exist_ok=True)


def load_config():
    ensure_dirs()
    if not os.path.exists(CONFIG_FILE):
        save_config(DEFAULT_CONFIG)
        return dict(DEFAULT_CONFIG)
    try:
        with open(CONFIG_FILE, 'r') as f:
            data = json.load(f)
            merged = dict(DEFAULT_CONFIG)
            merged.update(data)
            for section in ['general', 'security', 'scanning', 'notifications', 'api']:
                if section in data and isinstance(data[section], dict):
                    merged[section].update(data[section])
            return merged
    except:
        return dict(DEFAULT_CONFIG)


def save_config(config_data):
    ensure_dirs()
    config_dir = os.path.dirname(CONFIG_FILE)
    os.makedirs(config_dir, exist_ok=True)
    with open(CONFIG_FILE, 'w') as f:
        json.dump(config_data, f, indent=2)
    return True


def load_history():
    ensure_dirs()
    if not os.path.exists(HISTORY_FILE):
        return []
    try:
        with open(HISTORY_FILE, 'r') as f:
            return json.load(f)
    except:
        return []


def save_history(history):
    ensure_dirs()
    with open(HISTORY_FILE, 'w') as f:
        json.dump(history, f, indent=2)


def is_single_user_mode():
    """True unless the operator has explicitly switched to 'team' mode in
    Settings. Used to gate RBAC tiers, incident assignment/escalation, and
    team-status UI/endpoints that only make sense with multiple analysts."""
    return load_config().get('deployment_mode', 'single_user') != 'team'


def add_history_entry(title, description, type='info'):
    history = load_history()
    entry = {
        'id': str(uuid.uuid4())[:8],
        'title': title,
        'description': description,
        'timestamp': datetime.now().isoformat(),
        'type': type,
        'can_rollback': type != 'error'
    }
    history.insert(0, entry)
    if len(history) > 100:
        history = history[:100]
    save_history(history)


@config_bp.route('')
@require_auth
@rate_limit(limit=20, window=60)
def get_config():
    try:
        data = load_config()
        return jsonify(data)
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@config_bp.route('', methods=['POST'])
@require_auth
@require_role('admin')
@rate_limit(limit=10, window=60)
def save_config_endpoint():
    try:
        data = request.get_json()
        if not data:
            return jsonify({'success': False, 'message': 'No configuration data provided'}), 400
        current = load_config()
        for section in ['general', 'security', 'scanning', 'notifications', 'api']:
            if section in data and isinstance(data[section], dict):
                current[section].update(data[section])
        for key in ['active_modules', 'security_level', 'last_update', 'config_status', 'deployment_mode']:
            if key in data:
                current[key] = data[key]
        save_config(current)
        add_history_entry('Configuration Updated', 'System configuration was updated via dashboard')
        SecurityLogger.log_security_event('config_updated', {
            'user_id': g.current_user.get('user_id'),
            'username': g.current_user.get('username'),
            'ip_address': request.remote_addr
        })
        return jsonify({'success': True, 'message': 'Configuration saved successfully'})
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500


@config_bp.route('/backup', methods=['POST'])
@require_auth
@require_role('admin')
@rate_limit(limit=5, window=300)
def backup_config():
    try:
        ensure_dirs()
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        backup_file = os.path.join(BACKUP_DIR, f'dashboard_config_{timestamp}.json')
        if os.path.exists(CONFIG_FILE):
            shutil.copy2(CONFIG_FILE, backup_file)
        else:
            save_config(DEFAULT_CONFIG)
            shutil.copy2(CONFIG_FILE, backup_file)
        add_history_entry('Configuration Backup', f'Configuration backed up to {backup_file}')
        SecurityLogger.log_security_event('config_backup_created', {
            'user_id': g.current_user.get('user_id'),
            'username': g.current_user.get('username')
        })
        return jsonify({'success': True, 'message': 'Configuration backup created successfully'})
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500


@config_bp.route('/export')
@require_auth
@rate_limit(limit=10, window=60)
def export_config():
    try:
        data = load_config()
        json_data = json.dumps(data, indent=2)
        timestamp = datetime.now().strftime('%Y%m%d')
        return Response(
            json_data,
            mimetype='application/json',
            headers={'Content-Disposition': f'attachment; filename=aegis-config-{timestamp}.json'}
        )
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@config_bp.route('/history')
@require_auth
@rate_limit(limit=20, window=60)
def get_history():
    try:
        history = load_history()
        return jsonify({'history': history})
    except Exception as e:
        return jsonify({'history': [], 'error': str(e)}), 500


@config_bp.route('/history/clear', methods=['DELETE'])
@require_auth
@require_role('admin')
@rate_limit(limit=3, window=300)
def clear_history():
    try:
        save_history([])
        SecurityLogger.log_security_event('config_history_cleared', {
            'user_id': g.current_user.get('user_id'),
            'username': g.current_user.get('username')
        })
        return jsonify({'success': True, 'message': 'Configuration history cleared successfully'})
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500


@config_bp.route('/import', methods=['POST'])
@require_auth
@require_role('admin')
@rate_limit(limit=5, window=300)
def import_config():
    try:
        if 'config_file' not in request.files:
            return jsonify({'success': False, 'message': 'No file provided'}), 400
        file = request.files['config_file']
        if file.filename == '':
            return jsonify({'success': False, 'message': 'No file selected'}), 400
        content = file.read().decode('utf-8')
        imported = json.loads(content)
        merge = request.form.get('merge', 'false').lower() == 'true'
        do_backup = request.form.get('backup', 'true').lower() == 'true'
        if do_backup:
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            backup_file = os.path.join(BACKUP_DIR, f'pre_import_backup_{timestamp}.json')
            current = load_config()
            with open(backup_file, 'w') as f:
                json.dump(current, f, indent=2)
        if merge:
            current = load_config()
            for section in ['general', 'security', 'scanning', 'notifications', 'api']:
                if section in imported and isinstance(imported[section], dict):
                    current[section].update(imported[section])
            save_config(current)
        else:
            save_config(imported)
        add_history_entry('Configuration Imported', f'Configuration imported from {file.filename} (merge={merge})')
        SecurityLogger.log_security_event('config_imported', {
            'user_id': g.current_user.get('user_id'),
            'username': g.current_user.get('username'),
            'filename': file.filename
        })
        return jsonify({'success': True, 'message': 'Configuration imported successfully'})
    except json.JSONDecodeError:
        return jsonify({'success': False, 'message': 'Invalid JSON file'}), 400
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500


@config_bp.route('/reset', methods=['POST'])
@require_auth
@require_role('admin')
@rate_limit(limit=3, window=300)
def reset_config():
    try:
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        backup_file = os.path.join(BACKUP_DIR, f'pre_reset_backup_{timestamp}.json')
        if os.path.exists(CONFIG_FILE):
            shutil.copy2(CONFIG_FILE, backup_file)
        save_config(DEFAULT_CONFIG)
        add_history_entry('Configuration Reset', 'Configuration reset to factory defaults')
        SecurityLogger.log_security_event('config_reset', {
            'user_id': g.current_user.get('user_id'),
            'username': g.current_user.get('username')
        })
        return jsonify({'success': True, 'message': 'Configuration reset to defaults successfully'})
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500


@config_bp.route('/test', methods=['POST'])
@require_auth
@require_role('admin')
@rate_limit(limit=5, window=60)
def test_config():
    try:
        config = load_config()
        issues = []
        if config.get('security', {}).get('level') == 'low':
            issues.append('Security level is set to low')
        if config.get('notifications', {}).get('smtp_server') and not config.get('notifications', {}).get('recipients'):
            issues.append('SMTP configured but no recipients specified')
        if config.get('api', {}).get('authentication') == False:
            issues.append('API authentication is disabled')
        if issues:
            return jsonify({'success': True, 'message': 'Configuration test completed with warnings', 'warnings': issues, 'issues': issues})
        return jsonify({'success': True, 'message': 'Configuration test passed successfully', 'warnings': [], 'issues': []})
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500


@config_bp.route('/validate', methods=['POST'])
@require_auth
@require_role('admin')
@rate_limit(limit=5, window=60)
def validate_config():
    try:
        config = load_config()
        errors = []
        warnings = []
        if config.get('security', {}).get('session_timeout', 0) < 5:
            errors.append('Session timeout must be at least 5 minutes')
        if config.get('security', {}).get('max_login_attempts', 0) < 1:
            errors.append('Max login attempts must be at least 1')
        if config.get('scanning', {}).get('max_duration', 0) < 1:
            errors.append('Max scan duration must be at least 1 hour')
        if config.get('notifications', {}).get('smtp_port', 0) and (config['notifications']['smtp_port'] < 1 or config['notifications']['smtp_port'] > 65535):
            errors.append('SMTP port must be between 1 and 65535')
        if config.get('security', {}).get('level') == 'low':
            warnings.append('Security level is set to low - this reduces protection')
        if errors:
            return jsonify({'valid': False, 'message': 'Configuration validation failed', 'errors': errors, 'warnings': warnings})
        return jsonify({'valid': True, 'message': 'Configuration is valid', 'errors': [], 'warnings': warnings})
    except Exception as e:
        return jsonify({'valid': False, 'message': str(e), 'errors': [str(e)], 'warnings': []}), 500


@config_bp.route('/rollback/<change_id>', methods=['POST'])
@require_auth
@require_role('admin')
@rate_limit(limit=5, window=300)
def rollback_config(change_id):
    try:
        history = load_history()
        entry = None
        for h in history:
            if h.get('id') == change_id:
                entry = h
                break
        if not entry:
            return jsonify({'success': False, 'message': 'Configuration change not found'}), 404
        if not entry.get('can_rollback', False):
            return jsonify({'success': False, 'message': 'This change cannot be rolled back'}), 400
        backups = sorted(os.listdir(BACKUP_DIR), reverse=True) if os.path.exists(BACKUP_DIR) else []
        if backups:
            latest_backup = os.path.join(BACKUP_DIR, backups[0])
            shutil.copy2(latest_backup, CONFIG_FILE)
            add_history_entry('Configuration Rollback', f'Configuration rolled back to change {change_id}')
            SecurityLogger.log_security_event('config_rollback', {
                'user_id': g.current_user.get('user_id'),
                'username': g.current_user.get('username'),
                'change_id': change_id
            })
            return jsonify({'success': True, 'message': 'Configuration rolled back successfully'})
        else:
            save_config(DEFAULT_CONFIG)
            return jsonify({'success': True, 'message': 'No backup found, reset to defaults'})
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500
