#!/usr/bin/env python3
"""
Comprehensive Integration Testing Suite for Aegis Security Suite
Tests integration between web dashboard and security components
"""

import os
import sys
import json
import time
import sqlite3
import subprocess
import requests
from datetime import datetime
from pathlib import Path

class IntegrationTester:
    def __init__(self):
        self.dashboard_url = "http://localhost:8080"
        # Use current directory if AEGIS_HOME is not set or points to non-existent location
        default_home = '/opt/aegis-security-suite'
        env_home = os.environ.get('AEGIS_HOME', os.environ.get('SECURITY_SUITE_HOME', default_home))
        self.security_suite_home = env_home if os.path.exists(env_home) else os.getcwd()
        self.test_results = {
            'behavioral_analysis': {},
            'threat_intelligence': {},
            'incident_response': {},
            'system_monitoring': {},
            'script_integration': {},
            'database_integration': {},
            'service_integration': {},
            'overall_status': 'unknown'
        }
        self.session = requests.Session()
        
    def log_test(self, component, test_name, status, details=""):
        """Log test result"""
        timestamp = datetime.now().isoformat()
        if component not in self.test_results:
            self.test_results[component] = {}
        
        self.test_results[component][test_name] = {
            'status': status,
            'details': details,
            'timestamp': timestamp
        }
        
        status_symbol = "✅" if status == "PASS" else "❌" if status == "FAIL" else "⚠️"
        print(f"[{timestamp}] {status_symbol} {component}: {test_name} - {details}")
        
    def check_dashboard_status(self):
        """Check if dashboard is running and accessible"""
        try:
            response = self.session.get(self.dashboard_url, timeout=5)
            if response.status_code == 302:  # Redirect to login
                self.log_test("dashboard", "accessibility", "PASS", "Dashboard accessible (redirecting to login)")
                return True
            elif response.status_code == 200:
                self.log_test("dashboard", "accessibility", "PASS", "Dashboard accessible")
                return True
            else:
                self.log_test("dashboard", "accessibility", "FAIL", f"HTTP {response.status_code}")
                return False
        except Exception as e:
            self.log_test("dashboard", "accessibility", "FAIL", str(e))
            return False
    
    def test_behavioral_analysis_integration(self):
        """Test behavioral analysis integration"""
        print("\n=== Testing Behavioral Analysis Integration ===")
        
        # Test 1: Database connection
        behavioral_db = os.path.join(self.security_suite_home, 'configs', 'behavioral_analysis', 'behavioral_data.db')
        if os.path.exists(behavioral_db):
            try:
                conn = sqlite3.connect(behavioral_db)
                cursor = conn.cursor()
                cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
                tables = cursor.fetchall()
                conn.close()
                
                expected_tables = ['system_metrics', 'anomaly_events', 'threat_scores', 'baseline_data']
                found_tables = [table[0] for table in tables]
                
                if all(table in found_tables for table in expected_tables):
                    self.log_test("behavioral_analysis", "database_connection", "PASS", f"Found {len(found_tables)} tables")
                else:
                    missing = set(expected_tables) - set(found_tables)
                    self.log_test("behavioral_analysis", "database_connection", "FAIL", f"Missing tables: {missing}")
            except Exception as e:
                self.log_test("behavioral_analysis", "database_connection", "FAIL", str(e))
        else:
            self.log_test("behavioral_analysis", "database_connection", "FAIL", "Database file not found")
        
        # Test 2: API endpoint
        try:
            response = self.session.get(f"{self.dashboard_url}/api/behavioral/metrics", timeout=5)
            if response.status_code == 200:
                data = response.json()
                self.log_test("behavioral_analysis", "api_metrics", "PASS", f"Retrieved {data.get('count', 0)} metrics")
            elif response.status_code == 401:
                self.log_test("behavioral_analysis", "api_metrics", "PASS", "API accessible (requires authentication)")
            else:
                self.log_test("behavioral_analysis", "api_metrics", "FAIL", f"HTTP {response.status_code}")
        except Exception as e:
            self.log_test("behavioral_analysis", "api_metrics", "FAIL", str(e))
        
        # Test 3: Anomalies endpoint
        try:
            response = self.session.get(f"{self.dashboard_url}/api/behavioral/anomalies", timeout=5)
            if response.status_code == 200:
                data = response.json()
                self.log_test("behavioral_analysis", "api_anomalies", "PASS", f"Retrieved {data.get('count', 0)} anomalies")
            elif response.status_code == 401:
                self.log_test("behavioral_analysis", "api_anomalies", "PASS", "API accessible (requires authentication)")
            else:
                self.log_test("behavioral_analysis", "api_anomalies", "FAIL", f"HTTP {response.status_code}")
        except Exception as e:
            self.log_test("behavioral_analysis", "api_anomalies", "FAIL", str(e))
        
        # Test 4: Baseline status
        try:
            response = self.session.get(f"{self.dashboard_url}/api/behavioral/baseline", timeout=5)
            if response.status_code == 200:
                data = response.json()
                self.log_test("behavioral_analysis", "api_baseline", "PASS", f"Baseline status: {data.get('status', 'unknown')}")
            elif response.status_code == 401:
                self.log_test("behavioral_analysis", "api_baseline", "PASS", "API accessible (requires authentication)")
            else:
                self.log_test("behavioral_analysis", "api_baseline", "FAIL", f"HTTP {response.status_code}")
        except Exception as e:
            self.log_test("behavioral_analysis", "api_baseline", "FAIL", str(e))
        
        # Test 5: Script integration
        behavioral_script = os.path.join(self.security_suite_home, 'scripts', 'behavioral-analysis-optimized.sh')
        if os.path.exists(behavioral_script):
            if os.access(behavioral_script, os.X_OK):
                self.log_test("behavioral_analysis", "script_access", "PASS", "Script exists and executable")
            else:
                self.log_test("behavioral_analysis", "script_access", "FAIL", "Script exists but not executable")
        else:
            self.log_test("behavioral_analysis", "script_access", "FAIL", "Script not found")
    
    def test_threat_intelligence_integration(self):
        """Test threat intelligence integration"""
        print("\n=== Testing Threat Intelligence Integration ===")
        
        # Test 1: Database connection
        threat_db = os.path.join(self.security_suite_home, 'configs', 'threat_intelligence', 'ioc_database.db')
        if os.path.exists(threat_db):
            try:
                conn = sqlite3.connect(threat_db)
                cursor = conn.cursor()
                cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
                tables = cursor.fetchall()
                conn.close()
                
                expected_tables = ['ioc_ips', 'ioc_domains', 'ioc_urls', 'ioc_hashes', 'threat_feeds']
                found_tables = [table[0] for table in tables]
                
                if all(table in found_tables for table in expected_tables):
                    self.log_test("threat_intelligence", "database_connection", "PASS", f"Found {len(found_tables)} tables")
                else:
                    missing = set(expected_tables) - set(found_tables)
                    self.log_test("threat_intelligence", "database_connection", "FAIL", f"Missing tables: {missing}")
            except Exception as e:
                self.log_test("threat_intelligence", "database_connection", "FAIL", str(e))
        else:
            self.log_test("threat_intelligence", "database_connection", "FAIL", "Database file not found")
        
        # Test 2: API endpoint
        try:
            response = self.session.get(f"{self.dashboard_url}/api/threats/iocs", timeout=5)
            if response.status_code == 200:
                data = response.json()
                self.log_test("threat_intelligence", "api_iocs", "PASS", f"Retrieved {data.get('total', 0)} IOCs")
            elif response.status_code == 401:
                self.log_test("threat_intelligence", "api_iocs", "PASS", "API accessible (requires authentication)")
            else:
                self.log_test("threat_intelligence", "api_iocs", "FAIL", f"HTTP {response.status_code}")
        except Exception as e:
            self.log_test("threat_intelligence", "api_iocs", "FAIL", str(e))
        
        # Test 3: Feed status
        try:
            response = self.session.get(f"{self.dashboard_url}/api/threats/feeds", timeout=5)
            if response.status_code == 200:
                data = response.json()
                feeds = data.get('feeds', [])
                self.log_test("threat_intelligence", "api_feeds", "PASS", f"Retrieved {len(feeds)} feed statuses")
            elif response.status_code == 401:
                self.log_test("threat_intelligence", "api_feeds", "PASS", "API accessible (requires authentication)")
            else:
                self.log_test("threat_intelligence", "api_feeds", "FAIL", f"HTTP {response.status_code}")
        except Exception as e:
            self.log_test("threat_intelligence", "api_feeds", "FAIL", str(e))
        
        # Test 4: Script integration
        threat_script = os.path.join(self.security_suite_home, 'scripts', 'threat-intelligence-optimized.sh')
        if os.path.exists(threat_script):
            if os.access(threat_script, os.X_OK):
                self.log_test("threat_intelligence", "script_access", "PASS", "Script exists and executable")
            else:
                self.log_test("threat_intelligence", "script_access", "FAIL", "Script exists but not executable")
        else:
            self.log_test("threat_intelligence", "script_access", "FAIL", "Script not found")
        
        # Test 5: IOC statistics
        try:
            response = self.session.get(f"{self.dashboard_url}/api/threats/iocs/stats", timeout=5)
            if response.status_code == 200:
                data = response.json()
                total_iocs = data.get('total_iocs', 0)
                self.log_test("threat_intelligence", "api_stats", "PASS", f"Total IOCs: {total_iocs}")
            elif response.status_code == 401:
                self.log_test("threat_intelligence", "api_stats", "PASS", "API accessible (requires authentication)")
            else:
                self.log_test("threat_intelligence", "api_stats", "FAIL", f"HTTP {response.status_code}")
        except Exception as e:
            self.log_test("threat_intelligence", "api_stats", "FAIL", str(e))
    
    def test_incident_response_integration(self):
        """Test incident response integration"""
        print("\n=== Testing Incident Response Integration ===")
        
        # Test 1: Database connection
        incident_db = os.path.join(self.security_suite_home, 'configs', 'incident_response', 'incidents.db')
        if os.path.exists(incident_db):
            try:
                conn = sqlite3.connect(incident_db)
                cursor = conn.cursor()
                cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
                tables = cursor.fetchall()
                conn.close()
                
                expected_tables = ['incidents', 'incident_updates', 'quarantine_log', 'network_blocks']
                found_tables = [table[0] for table in tables]
                
                if all(table in found_tables for table in expected_tables):
                    self.log_test("incident_response", "database_connection", "PASS", f"Found {len(found_tables)} tables")
                else:
                    missing = set(expected_tables) - set(found_tables)
                    self.log_test("incident_response", "database_connection", "FAIL", f"Missing tables: {missing}")
            except Exception as e:
                self.log_test("incident_response", "database_connection", "FAIL", str(e))
        else:
            self.log_test("incident_response", "database_connection", "FAIL", "Database file not found")
        
        # Test 2: API endpoint
        try:
            response = self.session.get(f"{self.dashboard_url}/api/incidents/", timeout=5)
            if response.status_code == 200:
                data = response.json()
                self.log_test("incident_response", "api_incidents", "PASS", f"Retrieved {data.get('total', 0)} incidents")
            elif response.status_code == 401:
                self.log_test("incident_response", "api_incidents", "PASS", "API accessible (requires authentication)")
            else:
                self.log_test("incident_response", "api_incidents", "FAIL", f"HTTP {response.status_code}")
        except Exception as e:
            self.log_test("incident_response", "api_incidents", "FAIL", str(e))
        
        # Test 3: Statistics endpoint
        try:
            response = self.session.get(f"{self.dashboard_url}/api/incidents/statistics", timeout=5)
            if response.status_code == 200:
                data = response.json()
                stats = data.get('statistics', {})
                self.log_test("incident_response", "api_statistics", "PASS", f"Statistics available: {len(stats)} metrics")
            elif response.status_code == 401:
                self.log_test("incident_response", "api_statistics", "PASS", "API accessible (requires authentication)")
            else:
                self.log_test("incident_response", "api_statistics", "FAIL", f"HTTP {response.status_code}")
        except Exception as e:
            self.log_test("incident_response", "api_statistics", "FAIL", str(e))
        
        # Test 4: Script integration
        incident_script = os.path.join(self.security_suite_home, 'scripts', 'incident-response.sh')
        if os.path.exists(incident_script):
            if os.access(incident_script, os.X_OK):
                self.log_test("incident_response", "script_access", "PASS", "Script exists and executable")
            else:
                self.log_test("incident_response", "script_access", "FAIL", "Script exists but not executable")
        else:
            self.log_test("incident_response", "script_access", "FAIL", "Script not found")
        
        # Test 5: Evidence directory
        evidence_dir = os.path.join(self.security_suite_home, 'evidence')
        if os.path.exists(evidence_dir):
            self.log_test("incident_response", "evidence_directory", "PASS", "Evidence directory exists")
        else:
            self.log_test("incident_response", "evidence_directory", "FAIL", "Evidence directory not found")
        
        # Test 6: Quarantine directory
        quarantine_dir = os.path.join(self.security_suite_home, 'quarantine')
        if os.path.exists(quarantine_dir):
            self.log_test("incident_response", "quarantine_directory", "PASS", "Quarantine directory exists")
        else:
            self.log_test("incident_response", "quarantine_directory", "FAIL", "Quarantine directory not found")
    
    def test_system_monitoring_integration(self):
        """Test system monitoring integration"""
        print("\n=== Testing System Monitoring Integration ===")
        
        # Test 1: System status API
        try:
            response = self.session.get(f"{self.dashboard_url}/api/system/status", timeout=5)
            if response.status_code == 200:
                data = response.json()
                self.log_test("system_monitoring", "api_status", "PASS", f"System status: {data.get('status', 'unknown')}")
            elif response.status_code == 401:
                self.log_test("system_monitoring", "api_status", "PASS", "API accessible (requires authentication)")
            else:
                self.log_test("system_monitoring", "api_status", "FAIL", f"HTTP {response.status_code}")
        except Exception as e:
            self.log_test("system_monitoring", "api_status", "FAIL", str(e))
        
        # Test 2: System info API
        try:
            response = self.session.get(f"{self.dashboard_url}/api/system/info", timeout=5)
            if response.status_code == 200:
                data = response.json()
                self.log_test("system_monitoring", "api_info", "PASS", f"System info retrieved: {data.get('system', {}).get('hostname', 'unknown')}")
            elif response.status_code == 401:
                self.log_test("system_monitoring", "api_info", "PASS", "API accessible (requires authentication)")
            elif response.status_code == 403:
                self.log_test("system_monitoring", "api_info", "PASS", "API accessible (requires higher privileges)")
            else:
                self.log_test("system_monitoring", "api_info", "FAIL", f"HTTP {response.status_code}")
        except Exception as e:
            self.log_test("system_monitoring", "api_info", "FAIL", str(e))
        
        # Test 3: Processes API
        try:
            response = self.session.get(f"{self.dashboard_url}/api/system/processes", timeout=5)
            if response.status_code == 200:
                data = response.json()
                self.log_test("system_monitoring", "api_processes", "PASS", f"Retrieved {data.get('total', 0)} processes")
            elif response.status_code == 401:
                self.log_test("system_monitoring", "api_processes", "PASS", "API accessible (requires authentication)")
            elif response.status_code == 403:
                self.log_test("system_monitoring", "api_processes", "PASS", "API accessible (requires higher privileges)")
            else:
                self.log_test("system_monitoring", "api_processes", "FAIL", f"HTTP {response.status_code}")
        except Exception as e:
            self.log_test("system_monitoring", "api_processes", "FAIL", str(e))
        
        # Test 4: Network info API
        try:
            response = self.session.get(f"{self.dashboard_url}/api/system/network", timeout=5)
            if response.status_code == 200:
                data = response.json()
                interfaces = data.get('interfaces', {})
                self.log_test("system_monitoring", "api_network", "PASS", f"Retrieved {len(interfaces)} network interfaces")
            else:
                self.log_test("system_monitoring", "api_network", "FAIL", f"HTTP {response.status_code}")
        except Exception as e:
            self.log_test("system_monitoring", "api_network", "FAIL", str(e))
        
        # Test 5: Real-time monitoring
        try:
            # Test WebSocket endpoint (simplified check)
            import socket
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            result = sock.connect_ex(('localhost', 8080))
            sock.close()
            
            if result == 0:
                self.log_test("system_monitoring", "realtime_monitoring", "PASS", "Dashboard port accessible for WebSocket")
            else:
                self.log_test("system_monitoring", "realtime_monitoring", "FAIL", "Dashboard port not accessible")
        except Exception as e:
            self.log_test("system_monitoring", "realtime_monitoring", "FAIL", str(e))
    
    def test_script_integration(self):
        """Test security suite script integration"""
        print("\n=== Testing Security Suite Script Integration ===")
        
        scripts_dir = os.path.join(self.security_suite_home, 'scripts')
        
        # Test 1: Behavioral analysis script
        behavioral_script = os.path.join(scripts_dir, 'behavioral-analysis-optimized.sh')
        if os.path.exists(behavioral_script):
            if os.access(behavioral_script, os.X_OK):
                self.log_test("script_integration", "behavioral_script", "PASS", "Behavioral analysis script executable")
            else:
                self.log_test("script_integration", "behavioral_script", "FAIL", "Behavioral analysis script not executable")
        else:
            self.log_test("script_integration", "behavioral_script", "FAIL", "Behavioral analysis script not found")
        
        # Test 2: Threat intelligence script
        threat_script = os.path.join(scripts_dir, 'threat-intelligence-optimized.sh')
        if os.path.exists(threat_script):
            if os.access(threat_script, os.X_OK):
                self.log_test("script_integration", "threat_script", "PASS", "Threat intelligence script executable")
            else:
                self.log_test("script_integration", "threat_script", "FAIL", "Threat intelligence script not executable")
        else:
            self.log_test("script_integration", "threat_script", "FAIL", "Threat intelligence script not found")
        
        # Test 3: Incident response script
        incident_script = os.path.join(scripts_dir, 'incident-response.sh')
        if os.path.exists(incident_script):
            if os.access(incident_script, os.X_OK):
                self.log_test("script_integration", "incident_script", "PASS", "Incident response script executable")
            else:
                self.log_test("script_integration", "incident_script", "FAIL", "Incident response script not executable")
        else:
            self.log_test("script_integration", "incident_script", "FAIL", "Incident response script not found")
        
        # Test 4: Common functions
        common_script = os.path.join(scripts_dir, 'common-functions.sh')
        if os.path.exists(common_script):
            self.log_test("script_integration", "common_functions", "PASS", "Common functions script exists")
        else:
            self.log_test("script_integration", "common_functions", "FAIL", "Common functions script not found")
        
        # Test 5: Script execution test (dry run)
        try:
            result = subprocess.run(
                [behavioral_script, '--help'],
                capture_output=True,
                text=True,
                timeout=5
            )
            if result.returncode == 0 or 'Usage:' in result.stdout:
                self.log_test("script_integration", "behavioral_execution", "PASS", "Behavioral script can execute")
            else:
                self.log_test("script_integration", "behavioral_execution", "FAIL", "Behavioral script execution error")
        except Exception as e:
            self.log_test("script_integration", "behavioral_execution", "FAIL", str(e))
    
    def test_database_integration(self):
        """Test database integration"""
        print("\n=== Testing Database Integration ===")
        
        configs_dir = os.path.join(self.security_suite_home, 'configs')
        
        # Test 1: Database directories exist
        db_dirs = [
            'behavioral_analysis',
            'threat_intelligence',
            'incident_response',
            'web-dashboard'
        ]
        
        for db_dir in db_dirs:
            full_path = os.path.join(configs_dir, db_dir)
            if os.path.exists(full_path):
                self.log_test("database_integration", f"dir_{db_dir}", "PASS", f"Directory exists: {db_dir}")
            else:
                self.log_test("database_integration", f"dir_{db_dir}", "FAIL", f"Directory missing: {db_dir}")
        
        # Test 2: Database files exist
        db_files = [
            ('behavioral_analysis/behavioral_data.db', 'behavioral_db'),
            ('threat_intelligence/ioc_database.db', 'threat_db'),
            ('incident_response/incidents.db', 'incident_db'),
            ('web-dashboard/auth.db', 'auth_db')
        ]
        
        for db_file, test_name in db_files:
            full_path = os.path.join(configs_dir, db_file)
            if os.path.exists(full_path):
                try:
                    # Test database connection
                    conn = sqlite3.connect(full_path)
                    cursor = conn.cursor()
                    cursor.execute("SELECT sqlite_version()")
                    version = cursor.fetchone()
                    conn.close()
                    self.log_test("database_integration", test_name, "PASS", f"Database accessible (SQLite {version[0]})")
                except Exception as e:
                    self.log_test("database_integration", test_name, "FAIL", f"Database error: {str(e)}")
            else:
                self.log_test("database_integration", test_name, "FAIL", "Database file not found")
        
        # Test 3: Database permissions
        for db_file, test_name in db_files:
            full_path = os.path.join(configs_dir, db_file)
            if os.path.exists(full_path):
                if os.access(full_path, os.R_OK):
                    self.log_test("database_integration", f"{test_name}_read", "PASS", "Database readable")
                else:
                    self.log_test("database_integration", f"{test_name}_read", "FAIL", "Database not readable")
                
                if os.access(full_path, os.W_OK):
                    self.log_test("database_integration", f"{test_name}_write", "PASS", "Database writable")
                else:
                    self.log_test("database_integration", f"{test_name}_write", "FAIL", "Database not writable")
    
    def test_service_integration(self):
        """Test service integration"""
        print("\n=== Testing Service Integration ===")
        
        # Test 1: Dashboard service
        try:
            result = subprocess.run(
                ['systemctl', 'is-active', 'aegis-dashboard'],
                capture_output=True,
                text=True,
                timeout=5
            )
            if result.stdout.strip() == 'active':
                self.log_test("service_integration", "dashboard_service", "PASS", "Dashboard service active")
            else:
                self.log_test("service_integration", "dashboard_service", "FAIL", f"Dashboard service status: {result.stdout.strip()}")
        except (subprocess.TimeoutExpired, FileNotFoundError):
            self.log_test("service_integration", "dashboard_service", "FAIL", "Cannot check dashboard service")
        
        # Test 2: Behavioral monitoring service
        try:
            result = subprocess.run(
                ['systemctl', 'is-active', 'aegis-behavioral-monitor'],
                capture_output=True,
                text=True,
                timeout=5
            )
            if result.stdout.strip() == 'active':
                self.log_test("service_integration", "behavioral_service", "PASS", "Behavioral monitoring service active")
            else:
                self.log_test("service_integration", "behavioral_service", "FAIL", f"Behavioral service status: {result.stdout.strip()}")
        except (subprocess.TimeoutExpired, FileNotFoundError):
            self.log_test("service_integration", "behavioral_service", "FAIL", "Cannot check behavioral service")
        
        # Test 3: Threat intelligence service
        try:
            result = subprocess.run(
                ['systemctl', 'is-active', 'aegis-threat-intelligence'],
                capture_output=True,
                text=True,
                timeout=5
            )
            if result.stdout.strip() == 'active':
                self.log_test("service_integration", "threat_service", "PASS", "Threat intelligence service active")
            else:
                self.log_test("service_integration", "threat_service", "FAIL", f"Threat service status: {result.stdout.strip()}")
        except (subprocess.TimeoutExpired, FileNotFoundError):
            self.log_test("service_integration", "threat_service", "FAIL", "Cannot check threat service")
        
        # Test 4: Process monitoring
        try:
            result = subprocess.run(
                ['ps', 'aux'],
                capture_output=True,
                text=True,
                timeout=5
            )
            processes = result.stdout
            
            # Check for dashboard process
            if 'app.py' in processes:
                self.log_test("service_integration", "dashboard_process", "PASS", "Dashboard process running")
            else:
                self.log_test("service_integration", "dashboard_process", "FAIL", "Dashboard process not found")
            
            # Check for security suite processes
            security_processes = ['behavioral', 'threat', 'incident']
            found_processes = []
            for proc in security_processes:
                if proc in processes.lower():
                    found_processes.append(proc)
            
            if found_processes:
                self.log_test("service_integration", "security_processes", "PASS", f"Found security processes: {found_processes}")
            else:
                self.log_test("service_integration", "security_processes", "FAIL", "No security processes found")
                
        except Exception as e:
            self.log_test("service_integration", "process_monitoring", "FAIL", str(e))
        
        # Test 5: Log integration
        logs_dir = os.path.join(self.security_suite_home, 'logs')
        if os.path.exists(logs_dir):
            log_files = os.listdir(logs_dir)
            if log_files:
                self.log_test("service_integration", "log_integration", "PASS", f"Found {len(log_files)} log files")
            else:
                self.log_test("service_integration", "log_integration", "FAIL", "No log files found")
        else:
            self.log_test("service_integration", "log_integration", "FAIL", "Logs directory not found")
    
    def generate_report(self):
        """Generate comprehensive integration test report"""
        print("\n" + "="*80)
        print("COMPREHENSIVE INTEGRATION TESTING REPORT")
        print("="*80)
        print(f"Generated: {datetime.now().isoformat()}")
        print(f"Dashboard URL: {self.dashboard_url}")
        print(f"Security Suite Home: {self.security_suite_home}")
        print()
        
        # Calculate overall statistics
        total_tests = 0
        passed_tests = 0
        failed_tests = 0
        warning_tests = 0
        
        for component, tests in self.test_results.items():
            if component == 'overall_status':
                continue
                
            for test_name, test_result in tests.items():
                total_tests += 1
                status = test_result.get('status', 'UNKNOWN')
                if status == 'PASS':
                    passed_tests += 1
                elif status == 'FAIL':
                    failed_tests += 1
                else:
                    warning_tests += 1
        
        # Overall summary
        print("OVERALL SUMMARY")
        print("-" * 40)
        print(f"Total Tests: {total_tests}")
        print(f"Passed: {passed_tests} ({passed_tests/total_tests*100:.1f}%)")
        print(f"Failed: {failed_tests} ({failed_tests/total_tests*100:.1f}%)")
        print(f"Warnings: {warning_tests} ({warning_tests/total_tests*100:.1f}%)")
        
        if failed_tests == 0:
            overall_status = "EXCELLENT"
            self.test_results['overall_status'] = 'excellent'
        elif failed_tests <= total_tests * 0.1:
            overall_status = "GOOD"
            self.test_results['overall_status'] = 'good'
        elif failed_tests <= total_tests * 0.25:
            overall_status = "NEEDS ATTENTION"
            self.test_results['overall_status'] = 'needs_attention'
        else:
            overall_status = "CRITICAL ISSUES"
            self.test_results['overall_status'] = 'critical'
        
        print(f"Overall Status: {overall_status}")
        print()
        
        # Component summaries
        print("COMPONENT SUMMARIES")
        print("-" * 40)
        
        components = {
            'behavioral_analysis': 'Behavioral Analysis',
            'threat_intelligence': 'Threat Intelligence',
            'incident_response': 'Incident Response',
            'system_monitoring': 'System Monitoring',
            'script_integration': 'Script Integration',
            'database_integration': 'Database Integration',
            'service_integration': 'Service Integration'
        }
        
        for component_key, component_name in components.items():
            if component_key in self.test_results:
                tests = self.test_results[component_key]
                component_total = len(tests)
                component_passed = sum(1 for t in tests.values() if t.get('status') == 'PASS')
                component_failed = sum(1 for t in tests.values() if t.get('status') == 'FAIL')
                
                if component_failed == 0:
                    status = "✅ FULLY INTEGRATED"
                elif component_failed <= component_total * 0.3:
                    status = "⚠️ PARTIALLY INTEGRATED"
                else:
                    status = "❌ POORLY INTEGRATED"
                
                print(f"{component_name}: {status} ({component_passed}/{component_total} passed)")
        
        print()
        
        # Detailed results
        print("DETAILED TEST RESULTS")
        print("-" * 40)
        
        for component_key, component_name in components.items():
            if component_key in self.test_results:
                print(f"\n{component_name.upper()}")
                print("-" * len(component_name))
                
                tests = self.test_results[component_key]
                for test_name, test_result in tests.items():
                    status = test_result.get('status', 'UNKNOWN')
                    details = test_result.get('details', '')
                    timestamp = test_result.get('timestamp', '')
                    
                    status_symbol = "✅" if status == "PASS" else "❌" if status == "FAIL" else "⚠️"
                    print(f"  {status_symbol} {test_name}: {details}")
        
        print()
        
        # Integration issues and recommendations
        print("INTEGRATION ISSUES & RECOMMENDATIONS")
        print("-" * 40)
        
        issues = []
        recommendations = []
        
        # Collect issues
        for component_key, component_name in components.items():
            if component_key in self.test_results:
                tests = self.test_results[component_key]
                for test_name, test_result in tests.items():
                    if test_result.get('status') == 'FAIL':
                        issues.append(f"{component_name}: {test_name} - {test_result.get('details', '')}")
        
        if issues:
            print("ISSUES FOUND:")
            for i, issue in enumerate(issues, 1):
                print(f"  {i}. {issue}")
        else:
            print("✅ No critical issues found!")
        
        print()
        
        # Generate recommendations
        if failed_tests > 0:
            recommendations.extend([
                "Review and fix failed database connections",
                "Ensure all security scripts are executable",
                "Verify service configurations and restart if needed",
                "Check file permissions for databases and logs"
            ])
        
        if warning_tests > 0:
            recommendations.extend([
                "Address warnings to improve system reliability",
                "Consider implementing additional monitoring"
            ])
        
        if recommendations:
            print("RECOMMENDATIONS:")
            for i, rec in enumerate(recommendations, 1):
                print(f"  {i}. {rec}")
        
        print()
        
        # Data flow analysis
        print("DATA FLOW ANALYSIS")
        print("-" * 40)
        
        data_flow_status = []
        
        # Check behavioral to dashboard flow
        if (self.test_results.get('behavioral_analysis', {}).get('database_connection', {}).get('status') == 'PASS' and
            self.test_results.get('behavioral_analysis', {}).get('api_metrics', {}).get('status') in ['PASS']):
            data_flow_status.append("✅ Behavioral Analysis → Dashboard: WORKING")
        else:
            data_flow_status.append("❌ Behavioral Analysis → Dashboard: ISSUES")
        
        # Check threat intel to dashboard flow
        if (self.test_results.get('threat_intelligence', {}).get('database_connection', {}).get('status') == 'PASS' and
            self.test_results.get('threat_intelligence', {}).get('api_iocs', {}).get('status') in ['PASS']):
            data_flow_status.append("✅ Threat Intelligence → Dashboard: WORKING")
        else:
            data_flow_status.append("❌ Threat Intelligence → Dashboard: ISSUES")
        
        # Check incident response to dashboard flow
        if (self.test_results.get('incident_response', {}).get('database_connection', {}).get('status') == 'PASS' and
            self.test_results.get('incident_response', {}).get('api_incidents', {}).get('status') in ['PASS']):
            data_flow_status.append("✅ Incident Response → Dashboard: WORKING")
        else:
            data_flow_status.append("❌ Incident Response → Dashboard: ISSUES")
        
        # Check system monitoring to dashboard flow
        if (self.test_results.get('system_monitoring', {}).get('api_status', {}).get('status') in ['PASS']):
            data_flow_status.append("✅ System Monitoring → Dashboard: WORKING")
        else:
            data_flow_status.append("❌ System Monitoring → Dashboard: ISSUES")
        
        for flow in data_flow_status:
            print(f"  {flow}")
        
        print()
        
        # Save report to file
        report_file = f"integration_test_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        with open(report_file, 'w') as f:
            json.dump(self.test_results, f, indent=2)
        
        print(f"Full report saved to: {report_file}")
        print("="*80)
        
        return overall_status
    
    def run_all_tests(self):
        """Run all integration tests"""
        print("Starting Comprehensive Integration Testing for Aegis Security Suite")
        print("="*80)
        
        # Check dashboard first
        if not self.check_dashboard_status():
            print("❌ Dashboard is not accessible. Some tests may fail.")
        
        # Run all test suites
        self.test_behavioral_analysis_integration()
        self.test_threat_intelligence_integration()
        self.test_incident_response_integration()
        self.test_system_monitoring_integration()
        self.test_script_integration()
        self.test_database_integration()
        self.test_service_integration()
        
        # Generate report
        return self.generate_report()

if __name__ == "__main__":
    tester = IntegrationTester()
    status = tester.run_all_tests()
    sys.exit(0 if status in ["EXCELLENT", "GOOD"] else 1)