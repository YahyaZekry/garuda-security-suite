#!/usr/bin/env python3
"""
Initialize authentication database for Aegis Security Suite
"""

import os
import sys

# Add the web-dashboard directory to Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'web-dashboard'))

# Set environment variable (honor a pre-rename SECURITY_SUITE_HOME if set)
os.environ['AEGIS_HOME'] = os.environ.get(
    'AEGIS_HOME',
    os.environ.get('SECURITY_SUITE_HOME', os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

# Import and initialize
from auth import ensure_auth_db

if ensure_auth_db():
    print("Authentication database initialized successfully")
else:
    print("Failed to initialize authentication database")
    sys.exit(1)