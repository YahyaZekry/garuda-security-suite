#!/bin/bash
# Enable Optimized Components Script

SCRIPT_DIR="$(dirname "$0")"
AEGIS_HOME="$(dirname "$SCRIPT_DIR")"

echo "Enabling optimized Aegis Security Suite components..."

# Stop existing services
systemctl --user stop aegis-behavioral-monitor 2>/dev/null || true
systemctl --user stop aegis-dashboard 2>/dev/null || true

# Start optimized services
systemctl --user daemon-reload
systemctl --user enable memory-monitor.service
systemctl --user start memory-monitor.service

echo "Optimized components enabled successfully"
echo "Run 'systemctl --user status' to check service status"
