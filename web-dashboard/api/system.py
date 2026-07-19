"""
System API Module for Aegis Security Suite Dashboard
Provides system status, metrics, and monitoring endpoints
"""

import psutil
import platform
import subprocess
import json
import os
from datetime import datetime
from flask import Blueprint, jsonify, request, g

# Import security utilities
from security_utils import (
    SecurityLogger, InputValidator, rate_limiter,
    require_api_key, rate_limit, validate_input, secure_headers
)
from auth import require_auth, require_role

# Create Blueprint
system_bp = Blueprint('system', __name__, url_prefix='/api/system')

def get_system_info():
    """Get comprehensive system information"""
    try:
        # Basic system info
        system_info = {
            'hostname': platform.node(),
            'platform': platform.platform(),
            'architecture': platform.architecture()[0],
            'processor': platform.processor(),
            'python_version': platform.python_version(),
            'uptime': get_system_uptime(),
            'timestamp': datetime.now().isoformat()
        }
        
        # CPU information
        cpu_info = {
            'usage': psutil.cpu_percent(interval=1),
            'count': psutil.cpu_count(),
            'count_logical': psutil.cpu_count(logical=True),
            'frequency': psutil.cpu_freq()._asdict() if psutil.cpu_freq() else None,
            'load_avg': os.getloadavg() if hasattr(os, 'getloadavg') else None
        }
        
        # Memory information
        memory = psutil.virtual_memory()
        memory_info = {
            'total': memory.total,
            'available': memory.available,
            'used': memory.used,
            'free': memory.free,
            'percent': memory.percent,
            'active': getattr(memory, 'active', 0),
            'inactive': getattr(memory, 'inactive', 0),
            'buffers': getattr(memory, 'buffers', 0),
            'cached': getattr(memory, 'cached', 0)
        }
        
        # Disk information
        disk_info = []
        for partition in psutil.disk_partitions():
            try:
                usage = psutil.disk_usage(partition.mountpoint)
                disk_info.append({
                    'device': partition.device,
                    'mountpoint': partition.mountpoint,
                    'fstype': partition.fstype,
                    'total': usage.total,
                    'used': usage.used,
                    'free': usage.free,
                    'percent': (usage.used / usage.total) * 100
                })
            except PermissionError:
                continue
        
        # Network information
        network_info = {
            'interfaces': get_network_interfaces(),
            'connections': len(psutil.net_connections()),
            'io_counters': psutil.net_io_counters()._asdict() if psutil.net_io_counters() else None
        }
        
        # Process information
        process_info = {
            'total': len(psutil.pids()),
            'running': len([p for p in psutil.process_iter(['status']) if p.info['status'] == psutil.STATUS_RUNNING]),
            'sleeping': len([p for p in psutil.process_iter(['status']) if p.info['status'] == psutil.STATUS_SLEEPING])
        }
        
        return {
            'system': system_info,
            'cpu': cpu_info,
            'memory': memory_info,
            'disk': disk_info,
            'network': network_info,
            'processes': process_info,
            'status': 'online'
        }
        
    except Exception as e:
        return {
            'error': str(e),
            'status': 'error'
        }

def get_system_uptime():
    """Get system uptime in seconds"""
    try:
        if platform.system() == 'Linux':
            with open('/proc/uptime', 'r') as f:
                uptime_seconds = float(f.readline().split()[0])
                return uptime_seconds
        else:
            # Fallback for other systems
            boot_time = psutil.boot_time()
            return datetime.now().timestamp() - boot_time
    except:
        return 0

def get_network_interfaces():
    """Get network interface information"""
    interfaces = {}
    try:
        net_if_addrs = psutil.net_if_addrs()
        net_if_stats = psutil.net_if_stats()
        
        for interface_name, addresses in net_if_addrs.items():
            interface_info = {
                'addresses': [],
                'is_up': False,
                'speed': 0,
                'mtu': 0
            }
            
            # Get interface stats
            if interface_name in net_if_stats:
                stats = net_if_stats[interface_name]
                interface_info.update({
                    'is_up': stats.isup,
                    'speed': stats.speed,
                    'mtu': stats.mtu
                })
            
            # Get addresses
            for addr in addresses:
                interface_info['addresses'].append({
                    'family': str(addr.family),
                    'address': addr.address,
                    'netmask': addr.netmask,
                    'broadcast': addr.broadcast
                })
            
            interfaces[interface_name] = interface_info
            
    except Exception as e:
        print(f"Error getting network interfaces: {e}")
    
    return interfaces

def get_security_suite_status():
    """Get Aegis Security Suite status"""
    try:
        # Check if security suite is installed
        security_home = os.environ.get('AEGIS_HOME', '/opt/aegis-security-suite')
        
        if not os.path.exists(security_home):
            return {
                'installed': False,
                'status': 'not_installed'
            }
        
        # Check configuration
        config_file = os.path.join(security_home, 'configs', 'security-config.conf')
        config_exists = os.path.exists(config_file)
        
        # Check scripts
        scripts_dir = os.path.join(security_home, 'scripts')
        scripts_exist = os.path.exists(scripts_dir)
        
        # Check logs
        logs_dir = os.path.join(security_home, 'logs')
        logs_exist = os.path.exists(logs_dir)
        
        # Get service status
        service_status = get_service_status()
        
        return {
            'installed': True,
            'status': 'installed',
            'config_exists': config_exists,
            'scripts_exist': scripts_exist,
            'logs_exist': logs_exist,
            'service_status': service_status,
            'version': get_security_suite_version()
        }
        
    except Exception as e:
        return {
            'installed': False,
            'status': 'error',
            'error': str(e)
        }

def get_service_status():
    """Get status of security suite services"""
    services = {}
    
    # List of services to check
    service_list = [
        'aegis-behavioral-monitor',
        'aegis-threat-intelligence',
        'aegis-incident-response'
    ]
    
    for service in service_list:
        try:
            # Check if service is active
            result = subprocess.run(
                ['systemctl', 'is-active', service],
                capture_output=True,
                text=True,
                timeout=5
            )
            services[service] = {
                'active': result.stdout.strip() == 'active',
                'status': result.stdout.strip()
            }
        except (subprocess.TimeoutExpired, FileNotFoundError):
            services[service] = {
                'active': False,
                'status': 'unknown'
            }
    
    return services

def get_security_suite_version():
    """Get security suite version"""
    try:
        security_home = os.environ.get('AEGIS_HOME', '/opt/aegis-security-suite')
        version_file = os.path.join(security_home, 'VERSION')
        
        if os.path.exists(version_file):
            with open(version_file, 'r') as f:
                return f.read().strip()
        else:
            return '1.0.0'  # Default version
    except:
        return 'unknown'

@system_bp.route('/status')
@require_auth
@rate_limit(limit=30, window=60)  # 30 requests per minute
def get_status():
    """Get current system status"""
    try:
        system_data = get_system_info()
        security_data = get_security_suite_status()
        
        # Calculate overall threat level
        threat_level = calculate_threat_level(system_data, security_data)
        
        # Get open incidents count
        incidents_count = get_open_incidents_count()
        
        response = {
            'timestamp': datetime.now().isoformat(),
            'status': 'online',
            'threat_level': threat_level,
            'cpu_usage': system_data.get('cpu', {}).get('usage', 0),
            'memory_usage': system_data.get('memory', {}).get('percent', 0),
            'disk_usage': system_data.get('disk', [{}])[0].get('percent', 0) if system_data.get('disk') else 0,
            'open_incidents': incidents_count,
            'security_suite': security_data,
            'system_info': system_data.get('system', {}),
            'uptime': system_data.get('system', {}).get('uptime', 0)
        }
        
        SecurityLogger.log_security_event('system_status_accessed', {
            'user_id': g.current_user.get('user_id'),
            'username': g.current_user.get('username'),
            'ip_address': request.remote_addr
        })
        
        return jsonify(response)
        
    except Exception as e:
        SecurityLogger.log_security_event('system_status_error', {
            'user_id': g.current_user.get('user_id') if hasattr(g, 'current_user') else None,
            'error': str(e)
        }, 'ERROR')
        return jsonify({
            'error': 'Internal server error',
            'status': 'error',
            'timestamp': datetime.now().isoformat()
        }), 500

@system_bp.route('/info')
@require_auth
@require_role('analyst')  # Require analyst or higher
@rate_limit(limit=10, window=60)  # 10 requests per minute
def get_info():
    """Get detailed system information"""
    try:
        system_data = get_system_info()
        
        SecurityLogger.log_security_event('system_info_accessed', {
            'user_id': g.current_user.get('user_id'),
            'username': g.current_user.get('username'),
            'ip_address': request.remote_addr
        })
        
        return jsonify(system_data)
    except Exception as e:
        SecurityLogger.log_security_event('system_info_error', {
            'user_id': g.current_user.get('user_id'),
            'error': str(e)
        }, 'ERROR')
        return jsonify({'error': 'Internal server error'}), 500

@system_bp.route('/processes')
@require_auth
@require_role('analyst')  # Require analyst or higher
@rate_limit(limit=5, window=60)  # 5 requests per minute
def get_processes():
    """Get running processes information"""
    try:
        # Validate and sanitize input
        limit = min(request.args.get('limit', 50, type=int), 100)  # Max 100 processes
        sort_by = InputValidator.sanitize_string(request.args.get('sort', 'cpu'), 20)
        
        # Validate sort field
        valid_sort_fields = ['cpu', 'memory_percent', 'memory_mb', 'name', 'pid']
        if sort_by not in valid_sort_fields:
            sort_by = 'cpu'
        
        processes = []
        for proc in psutil.process_iter(['pid', 'name', 'username', 'cpu_percent', 'memory_percent', 'status', 'create_time']):
            try:
                pinfo = proc.info
                pinfo['cpu_percent'] = proc.cpu_percent()
                pinfo['memory_mb'] = proc.memory_info().rss / 1024 / 1024
                pinfo['create_time'] = datetime.fromtimestamp(pinfo['create_time']).isoformat()
                
                # Sanitize process information
                if pinfo.get('username'):
                    pinfo['username'] = InputValidator.sanitize_string(pinfo['username'], 100)
                if pinfo.get('name'):
                    pinfo['name'] = InputValidator.sanitize_string(pinfo['name'], 100)
                
                processes.append(pinfo)
            except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                continue
        
        # Sort processes
        if sort_by in ['cpu', 'memory_percent', 'memory_mb']:
            processes.sort(key=lambda x: x.get(sort_by, 0), reverse=True)
        else:
            processes.sort(key=lambda x: x.get(sort_by, ''))
        
        # Limit results
        processes = processes[:limit]
        
        SecurityLogger.log_security_event('processes_accessed', {
            'user_id': g.current_user.get('user_id'),
            'username': g.current_user.get('username'),
            'ip_address': request.remote_addr,
            'limit': limit,
            'sort_by': sort_by
        })
        
        return jsonify({
            'processes': processes,
            'total': len(processes),
            'timestamp': datetime.now().isoformat()
        })
        
    except Exception as e:
        SecurityLogger.log_security_event('processes_error', {
            'user_id': g.current_user.get('user_id'),
            'error': str(e)
        }, 'ERROR')
        return jsonify({'error': 'Internal server error'}), 500

@system_bp.route('/network')
def get_network_info():
    """Get network information"""
    try:
        system_data = get_system_info()
        return jsonify(system_data.get('network', {}))
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@system_bp.route('/logs')
@require_auth
@require_role('manager')  # Require manager or higher for logs
@rate_limit(limit=3, window=60)  # 3 requests per minute
def get_system_logs():
    """Get system logs"""
    try:
        # Validate and sanitize input
        lines = min(request.args.get('lines', 100, type=int), 1000)  # Max 1000 lines
        log_type = InputValidator.sanitize_string(request.args.get('type', 'system'), 20)
        
        # Validate log type
        valid_log_types = ['system', 'security', 'auth', 'error']
        if log_type not in valid_log_types:
            return jsonify({'error': 'Invalid log type'}), 400
        
        if log_type == 'system':
            # Get system logs (simplified)
            logs = get_system_logs_lines(lines)
        elif log_type == 'security':
            # Get security suite logs
            logs = get_security_logs_lines(lines)
        elif log_type == 'auth':
            # Get authentication logs
            logs = get_auth_logs_lines(lines)
        elif log_type == 'error':
            # Get error logs
            logs = get_error_logs_lines(lines)
        
        SecurityLogger.log_security_event('logs_accessed', {
            'user_id': g.current_user.get('user_id'),
            'username': g.current_user.get('username'),
            'ip_address': request.remote_addr,
            'log_type': log_type,
            'lines': lines
        })
        
        return jsonify({
            'logs': logs,
            'type': log_type,
            'timestamp': datetime.now().isoformat()
        })
        
    except Exception as e:
        SecurityLogger.log_security_event('logs_error', {
            'user_id': g.current_user.get('user_id'),
            'error': str(e)
        }, 'ERROR')
        return jsonify({'error': 'Internal server error'}), 500

def get_system_logs_lines(lines):
    """Get system log lines"""
    try:
        # This is a simplified implementation
        # In production, you'd want to read from actual log files
        logs = [
            {
                'timestamp': datetime.now().isoformat(),
                'level': 'INFO',
                'message': 'System operating normally'
            }
        ]
        return logs[-lines:]
    except:
        return []

def get_security_logs_lines(lines):
    """Get security suite logs"""
    try:
        security_home = os.environ.get('AEGIS_HOME', '/opt/aegis-security-suite')
        logs_dir = os.path.join(security_home, 'logs')
        
        if not os.path.exists(logs_dir):
            return []
        
        # Find the most recent log file
        log_files = [f for f in os.listdir(logs_dir) if f.endswith('.log')]
        if not log_files:
            return []
        
        log_files.sort(reverse=True)
        latest_log = os.path.join(logs_dir, log_files[0])
        
        logs = []
        with open(latest_log, 'r') as f:
            for line in f.readlines()[-lines:]:
                if line.strip():
                    logs.append({
                        'timestamp': datetime.now().isoformat(),
                        'level': 'INFO',
                        'message': line.strip()
                    })
        
        return logs
    except:
        return []

def calculate_threat_level(system_data, security_data):
    """Calculate overall threat level"""
    try:
        threat_score = 0
        
        # CPU usage contribution
        cpu_usage = system_data.get('cpu', {}).get('usage', 0)
        if cpu_usage > 90:
            threat_score += 30
        elif cpu_usage > 80:
            threat_score += 20
        elif cpu_usage > 70:
            threat_score += 10
        
        # Memory usage contribution
        memory_usage = system_data.get('memory', {}).get('percent', 0)
        if memory_usage > 90:
            threat_score += 30
        elif memory_usage > 80:
            threat_score += 20
        elif memory_usage > 70:
            threat_score += 10
        
        # Security suite status contribution
        if not security_data.get('installed', False):
            threat_score += 50
        
        service_status = security_data.get('service_status', {})
        inactive_services = sum(1 for s in service_status.values() if not s.get('active', False))
        threat_score += inactive_services * 10
        
        # Determine threat level
        if threat_score >= 70:
            return 'Critical'
        elif threat_score >= 50:
            return 'High'
        elif threat_score >= 30:
            return 'Medium'
        elif threat_score >= 10:
            return 'Low'
        else:
            return 'Minimal'
            
    except:
        return 'Unknown'

def get_open_incidents_count():
    """Get count of open incidents"""
    try:
        # This would integrate with the incident response system
        # For now, return a placeholder
        return 0
    except:
        return 0

def get_auth_logs_lines(lines):
    """Get authentication log lines"""
    try:
        security_home = os.environ.get('AEGIS_HOME', '/opt/aegis-security-suite')
        logs_dir = os.path.join(security_home, 'logs')
        
        if not os.path.exists(logs_dir):
            return []
        
        # Find most recent auth log file
        log_files = [f for f in os.listdir(logs_dir) if 'auth' in f and f.endswith('.log')]
        if not log_files:
            return []
        
        log_files.sort(reverse=True)
        latest_log = os.path.join(logs_dir, log_files[0])
        
        logs = []
        with open(latest_log, 'r') as f:
            for line in f.readlines()[-lines:]:
                if line.strip():
                    logs.append({
                        'timestamp': datetime.now().isoformat(),
                        'level': 'INFO',
                        'message': line.strip()
                    })
        
        return logs
    except:
        return []

def get_error_logs_lines(lines):
    """Get error log lines"""
    try:
        security_home = os.environ.get('AEGIS_HOME', '/opt/aegis-security-suite')
        logs_dir = os.path.join(security_home, 'logs')
        
        if not os.path.exists(logs_dir):
            return []
        
        # Find most recent error log file
        log_files = [f for f in os.listdir(logs_dir) if 'error' in f and f.endswith('.log')]
        if not log_files:
            return []
        
        log_files.sort(reverse=True)
        latest_log = os.path.join(logs_dir, log_files[0])
        
        logs = []
        with open(latest_log, 'r') as f:
            for line in f.readlines()[-lines:]:
                if line.strip():
                    logs.append({
                        'timestamp': datetime.now().isoformat(),
                        'level': 'ERROR',
                        'message': line.strip()
                    })
        
        return logs
    except:
        return []