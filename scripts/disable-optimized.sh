#!/bin/bash
# Disable Optimized Components Script

SCRIPT_DIR="$(dirname "$0")"
AEGIS_HOME="$(dirname "$SCRIPT_DIR")"

echo "Disabling optimized Aegis Security Suite components..."

# Stop optimized services
systemctl --user stop memory-monitor.service 2>/dev/null || true
systemctl --user disable memory-monitor.service 2>/dev/null || true

# Remove memory monitor service file
rm -f "$HOME/.config/systemd/user/memory-monitor.service"

# Restore original components
if [ -f "$SCRIPT_DIR/behavioral-monitor.sh.backup" ]; then
    mv "$SCRIPT_DIR/behavioral-monitor.sh.backup" "$SCRIPT_DIR/behavioral-monitor.sh"
fi

if [ -f "$SCRIPT_DIR/behavioral-analysis.sh.backup" ]; then
    mv "$SCRIPT_DIR/behavioral-analysis.sh.backup" "$SCRIPT_DIR/behavioral-analysis.sh"
fi

if [ -f "$SCRIPT_DIR/threat-intelligence.sh.backup" ]; then
    mv "$SCRIPT_DIR/threat-intelligence.sh.backup" "$SCRIPT_DIR/threat-intelligence.sh"
fi

if [ -f "$AEGIS_HOME/web-dashboard/app.py.backup" ]; then
    mv "$AEGIS_HOME/web-dashboard/app.py.backup" "$AEGIS_HOME/web-dashboard/app.py"
fi

# Restart original services
systemctl --user daemon-reload
systemctl --user start aegis-behavioral-monitor 2>/dev/null || true
systemctl --user start aegis-dashboard 2>/dev/null || true

echo "Optimized components disabled successfully"
echo "Original components restored"
