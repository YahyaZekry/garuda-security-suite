#!/usr/bin/env python3
"""
Comprehensive Integration Test Suite for Aegis Security Suite
Tests all integration points between web dashboard and security components
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
        self.base_url = "http://localhost:8080"
        self.session = requests.Session()
        self.test_results = {
            'behavioral_analysis': {},
            'threat_intelligence': {},
            'incident_response': {},
            'system_monitoring': {},
            'script_integration': {},
            'database_integration': {},
            'service_integration': {},
            'overall_status': 'UNKNOWN'
        }
        self.security_suite_home = os.path.dirname(os.path.abspath(__file__))
        
    def login_to_dashboard(self):
        """Login to dashboard and get session"""
        try:
            login_data = {
                'username': 'admin',
                'password': 'admin123'
            }
            response = self.session.post(
                f"{self.base_url}/login",
                data=login_data,
                allow_redirects=False
            )
            
            if response.status_code in [200, 302]:
                print("✓ Successfully logged into dashboard")
                return True
            else:
                print(f"✗ Failed to login: {response.status_code}")
                return False
                
        except Exception as e:
            print(f"✗ Login error: {e}")
            return False
    
    def test_behavioral_analysis_integration(self):
        """Test behavioral analysis integration"""
        print("\n=== Testing Behavioral Analysis Integration ===")
        results = {}
        
        # Test 1: Database connection
        try:
            db_path = os.path.join(self.security_suite_home, 'configs', 'behavioral_analysis', 'behavioral_data.db')
            if os.path.exists(db_path):
                conn = sqlite3.connect(db_path)
                cursor = conn.cursor()
                cursor.execute("SELECT COUNT(*) FROM system_metrics")
                count = cursor.fetchone()[0]
                conn.close()
                results['database_connection'] = {
                    'status': 'PASS',
                    'message': f'Database accessible with {count} metrics records'
                }
                print(f"✓ Database connection: {count} metrics found")
            else:
                results['database_connection'] = {
                    'status': 'FAIL',
                    'message': 'Behavioral analysis database not found'
                }
                print("✗ Database connection: Database not found")
        except Exception as e:
            results['database_connection'] = {
                'status': 'FAIL',
                'message': f'Database error: {str(e)}'
            }
            print(f"✗ Database connection: {str(e)}")
        
        # Test 2: API endpoint
        try:
            response = self.session.get(f"{self.base_url}/api/behavioral/metrics")
            if response.status_code == 200:
                data = response.json()
                if 'error' in data and 'no such column' in data['error']:
                    results['api_endpoint'] = {
                        'status': 'PARTIAL',
                        'message': f'API accessible but schema mismatch: {data["error"]}'
                    }
                    print(f"⚠ API endpoint: Schema mismatch - {data['error']}")
                else:
                    results['api_endpoint'] = {
                        'status': 'PASS',
                        'message': 'API endpoint working correctly'
                    }
                    print("✓ API endpoint: Working correctly")
            else:
                results['api_endpoint'] = {
                    'status': 'FAIL',
                    'message': f'API returned status {response.status_code}'
                }
                print(f"✗ API endpoint: Status {response.status_code}")
        except Exception as e:
            results['api_endpoint'] = {
                'status': 'FAIL',
                'message': f'API error: {str(e)}'
            }
            print(f"✗ API endpoint: {str(e)}")
        
        # Test 3: Baseline status
        try:
            response = self.session.get(f"{self.base_url}/api/behavioral/baseline")
            if response.status_code == 200:
                data = response.json()
                results['baseline_status'] = {
                    'status': 'PASS',
                    'message': f'Baseline status: {data.get("status", "unknown")}'
                }
                print(f"✓ Baseline status: {data.get('status', 'unknown')}")
            else:
                results['baseline_status'] = {
                    'status': 'FAIL',
                    'message': f'Baseline API returned {response.status_code}'
                }
                print(f"✗ Baseline status: {response.status_code}")
        except Exception as e:
            results['baseline_status'] = {
                'status': 'FAIL',
                'message': f'Baseline error: {str(e)}'
            }
            print(f"✗ Baseline status: {str(e)}")
        
        # Test 4: Script integration
        script_path = os.path.join(self.security_suite_home, 'scripts', 'behavioral-analysis-optimized.sh')
        if os.path.exists(script_path) and os.access(script_path, os.X_OK):
            results['script_integration'] = {
                'status': 'PASS',
                'message': 'Behavioral analysis script is executable'
            }
            print("✓ Script integration: Script is executable")
        else:
            results['script_integration'] = {
                'status': 'FAIL',
                'message': 'Behavioral analysis script not found or not executable'
            }
            print("✗ Script integration: Script not found or not executable")
        
        self.test_results['behavioral_analysis'] = results
        return results
    
    def test_threat_intelligence_integration(self):
        """Test threat intelligence integration"""
        print("\n=== Testing Threat Intelligence Integration ===")
        results = {}
        
        # Test 1: Database connection
        try:
            db_path = os.path.join(self.security_suite_home, 'configs', 'threat_intelligence', 'ioc_database.db')
            if os.path.exists(db_path):
                conn = sqlite3.connect(db_path)
                cursor = conn.cursor()
                cursor.execute("SELECT COUNT(*) FROM ioc_data")
                count = cursor.fetchone()[0]
                conn.close()
                results['database_connection'] = {
                    'status': 'PASS',
                    'message': f'Threat database accessible with {count} IOCs'
                }
                print(f"✓ Database connection: {count} IOCs found")
            else:
                results['database_connection'] = {
                    'status': 'FAIL',
                    'message': 'Threat intelligence database not found'
                }
                print("✗ Database connection: Database not found")
        except Exception as e:
            results['database_connection'] = {
                'status': 'FAIL',
                'message': f'Database error: {str(e)}'
            }
            print(f"✗ Database connection: {str(e)}")
        
        # Test 2: API endpoint
        try:
            response = self.session.get(f"{self.base_url}/api/threats/iocs")
            if response.status_code == 200:
                data = response.json()
                results['api_endpoint'] = {
                    'status': 'PASS',
                    'message': 'Threat API endpoint working correctly'
                }
                print("✓ API endpoint: Working correctly")
            else:
                results['api_endpoint'] = {
                    'status': 'FAIL',
                    'message': f'API returned status {response.status_code}'
                }
                print(f"✗ API endpoint: Status {response.status_code}")
        except Exception as e:
            results['api_endpoint'] = {
                'status': 'FAIL',
                'message': f'API error: {str(e)}'
            }
            print(f"✗ API endpoint: {str(e)}")
        
        # Test 3: Script integration
        script_path = os.path.join(self.security_suite_home, 'scripts', 'threat-intelligence-optimized.sh')
        if os.path.exists(script_path) and os.access(script_path, os.X_OK):
            results['script_integration'] = {
                'status': 'PASS',
                'message': 'Threat intelligence script is executable'
            }
            print("✓ Script integration: Script is executable")
        else:
            results['script_integration'] = {
                'status': 'FAIL',
                'message': 'Threat intelligence script not found or not executable'
            }
            print("✗ Script integration: Script not found or not executable")
        
        self.test_results['threat_intelligence'] = results
        return results
    
    def test_incident_response_integration(self):
        """Test incident response integration"""
        print("\n=== Testing Incident Response Integration ===")
        results = {}
        
        # Test 1: Database connection
        try:
            db_path = os.path.join(self.security_suite_home, 'configs', 'incident_response', 'incidents.db')
            if os.path.exists(db_path):
                conn = sqlite3.connect(db_path)
                cursor = conn.cursor()
                cursor.execute("SELECT COUNT(*) FROM incidents")
                count = cursor.fetchone()[0]
                conn.close()
                results['database_connection'] = {
                    'status': 'PASS',
                    'message': f'Incident database accessible with {count} incidents'
                }
                print(f"✓ Database connection: {count} incidents found")
            else:
                results['database_connection'] = {
                    'status': 'FAIL',
                    'message': 'Incident response database not found'
                }
                print("✗ Database connection: Database not found")
        except Exception as e:
            results['database_connection'] = {
                'status': 'FAIL',
                'message': f'Database error: {str(e)}'
            }
            print(f"✗ Database connection: {str(e)}")
        
        # Test 2: API endpoint
        try:
            response = self.session.get(f"{self.base_url}/api/incidents")
            if response.status_code == 200:
                data = response.json()
                results['api_endpoint'] = {
                    'status': 'PASS',
                    'message': 'Incident API endpoint working correctly'
                }
                print("✓ API endpoint: Working correctly")
            else:
                results['api_endpoint'] = {
                    'status': 'FAIL',
                    'message': f'API returned status {response.status_code}'
                }
                print(f"✗ API endpoint: Status {response.status_code}")
        except Exception as e:
            results['api_endpoint'] = {
                'status': 'FAIL',
                'message': f'API error: {str(e)}'
            }
            print(f"✗ API endpoint: {str(e)}")
        
        # Test 3: Script integration
        script_path = os.path.join(self.security_suite_home, 'scripts', 'incident-response.sh')
        if os.path.exists(script_path) and os.access(script_path, os.X_OK):
            results['script_integration'] = {
                'status': 'PASS',
                'message': 'Incident response script is executable'
            }
            print("✓ Script integration: Script is executable")
        else:
            results['script_integration'] = {
                'status': 'FAIL',
                'message': 'Incident response script not found or not executable'
            }
            print("✗ Script integration: Script not found or not executable")
        
        self.test_results['incident_response'] = results
        return results
    
    def test_system_monitoring_integration(self):
        """Test system monitoring integration"""
        print("\n=== Testing System Monitoring Integration ===")
        results = {}
        
        # Test 1: API endpoint
        try:
            response = self.session.get(f"{self.base_url}/api/system/status")
            if response.status_code == 200:
                data = response.json()
                results['api_endpoint'] = {
                    'status': 'PASS',
                    'message': 'System monitoring API working correctly'
                }
                print("✓ API endpoint: Working correctly")
            else:
                results['api_endpoint'] = {
                    'status': 'FAIL',
                    'message': f'API returned status {response.status_code}'
                }
                print(f"✗ API endpoint: Status {response.status_code}")
        except Exception as e:
            results['api_endpoint'] = {
                'status': 'FAIL',
                'message': f'API error: {str(e)}'
            }
            print(f"✗ API endpoint: {str(e)}")
        
        # Test 2: Process monitoring
        try:
            response = self.session.get(f"{self.base_url}/api/system/processes")
            if response.status_code == 200:
                data = response.json()
                results['process_monitoring'] = {
                    'status': 'PASS',
                    'message': 'Process monitoring API working correctly'
                }
                print("✓ Process monitoring: Working correctly")
            else:
                results['process_monitoring'] = {
                    'status': 'FAIL',
                    'message': f'Process API returned {response.status_code}'
                }
                print(f"✗ Process monitoring: {response.status_code}")
        except Exception as e:
            results['process_monitoring'] = {
                'status': 'FAIL',
                'message': f'Process monitoring error: {str(e)}'
            }
            print(f"✗ Process monitoring: {str(e)}")
        
        self.test_results['system_monitoring'] = results
        return results
    
    def test_script_integration(self):
        """Test security suite script integration"""
        print("\n=== Testing Security Suite Script Integration ===")
        results = {}
        
        scripts = [
            ('behavioral-analysis-optimized.sh', 'Behavioral Analysis'),
            ('threat-intelligence-optimized.sh', 'Threat Intelligence'),
            ('incident-response.sh', 'Incident Response')
        ]
        
        for script_name, display_name in scripts:
            script_path = os.path.join(self.security_suite_home, 'scripts', script_name)
            if os.path.exists(script_path):
                if os.access(script_path, os.X_OK):
                    results[script_name] = {
                        'status': 'PASS',
                        'message': f'{display_name} script is executable'
                    }
                    print(f"✓ {display_name}: Script is executable")
                else:
                    results[script_name] = {
                        'status': 'PARTIAL',
                        'message': f'{display_name} script exists but not executable'
                    }
                    print(f"⚠ {display_name}: Script exists but not executable")
            else:
                results[script_name] = {
                    'status': 'FAIL',
                    'message': f'{display_name} script not found'
                }
                print(f"✗ {display_name}: Script not found")
        
        self.test_results['script_integration'] = results
        return results
    
    def test_database_integration(self):
        """Test database integration"""
        print("\n=== Testing Database Integration ===")
        results = {}
        
        databases = [
            ('configs/behavioral_analysis/behavioral_data.db', 'Behavioral Analysis'),
            ('configs/threat_intelligence/ioc_database.db', 'Threat Intelligence'),
            ('configs/incident_response/incidents.db', 'Incident Response'),
            ('configs/web-dashboard/auth.db', 'Authentication')
        ]
        
        for db_path, display_name in databases:
            full_path = os.path.join(self.security_suite_home, db_path)
            if os.path.exists(full_path):
                try:
                    conn = sqlite3.connect(full_path)
                    cursor = conn.cursor()
                    cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
                    tables = cursor.fetchall()
                    conn.close()
                    results[db_path] = {
                        'status': 'PASS',
                        'message': f'{display_name} database accessible with {len(tables)} tables'
                    }
                    print(f"✓ {display_name}: Database accessible with {len(tables)} tables")
                except Exception as e:
                    results[db_path] = {
                        'status': 'FAIL',
                        'message': f'{display_name} database error: {str(e)}'
                    }
                    print(f"✗ {display_name}: Database error - {str(e)}")
            else:
                results[db_path] = {
                    'status': 'FAIL',
                    'message': f'{display_name} database not found'
                }
                print(f"✗ {display_name}: Database not found")
        
        self.test_results['database_integration'] = results
        return results
    
    def test_service_integration(self):
        """Test service integration"""
        print("\n=== Testing Service Integration ===")
        results = {}
        
        # Check if dashboard is running
        try:
            response = requests.get(f"{self.base_url}/", timeout=5)
            if response.status_code == 200:
                results['dashboard_service'] = {
                    'status': 'PASS',
                    'message': 'Dashboard service is running and accessible'
                }
                print("✓ Dashboard service: Running and accessible")
            else:
                results['dashboard_service'] = {
                    'status': 'FAIL',
                    'message': f'Dashboard returned status {response.status_code}'
                }
                print(f"✗ Dashboard service: Status {response.status_code}")
        except Exception as e:
            results['dashboard_service'] = {
                'status': 'FAIL',
                'message': f'Dashboard service error: {str(e)}'
            }
            print(f"✗ Dashboard service: {str(e)}")
        
        # Check for running security processes
        try:
            result = subprocess.run(['ps', 'aux'], capture_output=True, text=True)
            processes = result.stdout
            
            security_processes = []
            if 'behavioral' in processes.lower():
                security_processes.append('behavioral')
            if 'threat' in processes.lower():
                security_processes.append('threat')
            if 'incident' in processes.lower():
                security_processes.append('incident')
            
            if security_processes:
                results['security_processes'] = {
                    'status': 'PASS',
                    'message': f'Security processes running: {", ".join(security_processes)}'
                }
                print(f"✓ Security processes: {', '.join(security_processes)}")
            else:
                results['security_processes'] = {
                    'status': 'PARTIAL',
                    'message': 'No security processes detected'
                }
                print("⚠ Security processes: None detected")
        except Exception as e:
            results['security_processes'] = {
                'status': 'FAIL',
                'message': f'Process check error: {str(e)}'
            }
            print(f"✗ Security processes: {str(e)}")
        
        self.test_results['service_integration'] = results
        return results
    
    def calculate_overall_status(self):
        """Calculate overall integration status"""
        total_tests = 0
        passed_tests = 0
        partial_tests = 0
        
        for category, tests in self.test_results.items():
            if category == 'overall_status':
                continue
                
            if isinstance(tests, dict):
                for test_name, result in tests.items():
                    if isinstance(result, dict) and 'status' in result:
                        total_tests += 1
                        if result['status'] == 'PASS':
                            passed_tests += 1
                        elif result['status'] == 'PARTIAL':
                            partial_tests += 1
        
        pass_rate = (passed_tests / total_tests) * 100 if total_tests > 0 else 0
        
        if pass_rate >= 90:
            overall = 'EXCELLENT'
        elif pass_rate >= 75:
            overall = 'GOOD'
        elif pass_rate >= 50:
            overall = 'NEEDS ATTENTION'
        else:
            overall = 'CRITICAL ISSUES'
        
        self.test_results['overall_status'] = {
            'status': overall,
            'pass_rate': pass_rate,
            'total_tests': total_tests,
            'passed_tests': passed_tests,
            'partial_tests': partial_tests,
            'failed_tests': total_tests - passed_tests - partial_tests
        }
        
        return overall
    
    def generate_report(self):
        """Generate comprehensive integration test report"""
        report = {
            'test_timestamp': datetime.now().isoformat(),
            'dashboard_url': self.base_url,
            'test_results': self.test_results,
            'summary': {
                'overall_status': self.test_results.get('overall_status', {}).get('status', 'UNKNOWN'),
                'pass_rate': self.test_results.get('overall_status', {}).get('pass_rate', 0),
                'recommendations': []
            }
        }
        
        # Generate recommendations based on test results
        recommendations = []
        
        # Check for common issues
        for category, tests in self.test_results.items():
            if category == 'overall_status':
                continue
                
            if isinstance(tests, dict):
                for test_name, result in tests.items():
                    if isinstance(result, dict) and result.get('status') == 'FAIL':
                        if 'database' in test_name.lower():
                            recommendations.append("Initialize missing security databases using the setup scripts")
                        elif 'api' in test_name.lower():
                            recommendations.append("Fix API endpoint configuration and database schema mismatches")
                        elif 'script' in test_name.lower():
                            recommendations.append("Make security scripts executable with chmod +x")
                        elif 'service' in test_name.lower():
                            recommendations.append("Start and configure security services")
        
        # Add specific recommendations for schema issues
        if 'no such column' in str(self.test_results):
            recommendations.append("Update database schema to match API expectations or modify API queries")
        
        # Add authentication recommendation
        recommendations.append("Ensure proper authentication is configured for all API endpoints")
        
        report['summary']['recommendations'] = recommendations
        
        return report
    
    def run_all_tests(self):
        """Run all integration tests"""
        print("Starting Comprehensive Integration Test for Aegis Security Suite")
        print("=" * 70)
        
        # Login first
        if not self.login_to_dashboard():
            print("Failed to login to dashboard. Some tests may fail.")
        
        # Run all test categories
        self.test_behavioral_analysis_integration()
        self.test_threat_intelligence_integration()
        self.test_incident_response_integration()
        self.test_system_monitoring_integration()
        self.test_script_integration()
        self.test_database_integration()
        self.test_service_integration()
        
        # Calculate overall status
        self.calculate_overall_status()
        
        # Generate and return report
        report = self.generate_report()
        
        print("\n" + "=" * 70)
        print("INTEGRATION TEST SUMMARY")
        print("=" * 70)
        print(f"Overall Status: {report['summary']['overall_status']}")
        print(f"Pass Rate: {report['summary']['pass_rate']:.1f}%")
        print(f"Total Tests: {self.test_results['overall_status']['total_tests']}")
        print(f"Passed: {self.test_results['overall_status']['passed_tests']}")
        print(f"Partial: {self.test_results['overall_status']['partial_tests']}")
        print(f"Failed: {self.test_results['overall_status']['failed_tests']}")
        
        print("\nRECOMMENDATIONS:")
        for i, rec in enumerate(report['summary']['recommendations'], 1):
            print(f"{i}. {rec}")
        
        return report

def main():
    """Main function"""
    tester = IntegrationTester()
    report = tester.run_all_tests()
    
    # Save report to file
    report_file = f"integration_test_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    with open(report_file, 'w') as f:
        json.dump(report, f, indent=2)
    
    print(f"\nDetailed report saved to: {report_file}")
    
    # Return appropriate exit code
    if report['summary']['overall_status'] in ['EXCELLENT', 'GOOD']:
        sys.exit(0)
    elif report['summary']['overall_status'] == 'NEEDS ATTENTION':
        sys.exit(1)
    else:
        sys.exit(2)

if __name__ == "__main__":
    main()