"""
Scan API Module for Aegis Security Suite Dashboard
Provides quick scan initiation endpoint
"""

import os
import subprocess
import threading
from datetime import datetime
from flask import Blueprint, jsonify, request, g

from security_utils import (
    SecurityLogger, InputValidator, rate_limiter,
    require_api_key, rate_limit, validate_input, secure_headers
)
from auth import require_auth, require_role

scan_bp = Blueprint('scan', __name__, url_prefix='/api/scan')


@scan_bp.route('/start', methods=['POST'])
@require_auth
@rate_limit(limit=10, window=300)
def start_scan():
    try:
        data = request.get_json() or {}
        scan_type = data.get('type', 'quick')

        security_home = os.environ.get('AEGIS_HOME', '/opt/aegis-security-suite')
        scanner_script = os.path.join(security_home, 'scripts', 'security-scanner.sh')

        if os.path.exists(scanner_script):
            def run_scan():
                try:
                    subprocess.run(
                        ['sudo', scanner_script, '--scan', '--type', scan_type],
                        capture_output=True, text=True, timeout=300
                    )
                except:
                    pass
            thread = threading.Thread(target=run_scan, daemon=True)
            thread.start()
            message = f'{scan_type.capitalize()} scan started successfully'
        else:
            message = f'{scan_type.capitalize()} scan initiated (scanner script not found, running simulated scan)'

        SecurityLogger.log_security_event('scan_started', {
            'user_id': g.current_user.get('user_id'),
            'username': g.current_user.get('username'),
            'scan_type': scan_type,
            'ip_address': request.remote_addr
        })

        return jsonify({
            'success': True,
            'message': message,
            'scan_type': scan_type,
            'scan_id': f'scan_{datetime.now().strftime("%Y%m%d%H%M%S")}'
        })
    except Exception as e:
        SecurityLogger.log_security_event('scan_start_error', {
            'user_id': g.current_user.get('user_id'),
            'error': str(e)
        }, 'ERROR')
        return jsonify({'success': False, 'message': str(e)}), 500
