#!/bin/bash
# Simple Threat Feed Scheduling Setup

AEGIS_HOME="$(dirname "$(dirname "$0")")"
THREAT_INTEL_SCRIPT="$AEGIS_HOME/scripts/threat-intelligence-optimized.sh"

echo "Setting up automated threat feed updates..."

# Create systemd service
mkdir -p "$HOME/.config/systemd/user"

cat > "$HOME/.config/systemd/user/threat-feed-update.service" << EOF
[Unit]
Description=Aegis Security Suite - Threat Intelligence Feed Updates
After=network-online.target

[Service]
Type=oneshot
ExecStart=$THREAT_INTEL_SCRIPT update
User=$USER
StandardOutput=journal
StandardError=journal
EOF

# Create systemd timer
cat > "$HOME/.config/systemd/user/threat-feed-update.timer" << EOF
[Unit]
Description=Run threat intelligence feed updates every hour
Requires=threat-feed-update.service

[Timer]
OnCalendar=hourly
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Reload systemd and enable timer
systemctl --user daemon-reload
systemctl --user enable threat-feed-update.timer
systemctl --user start threat-feed-update.timer

# Add cron fallback
CRON_ENTRY="0 * * * * $THREAT_INTEL_SCRIPT update"
if ! crontab -l 2>/dev/null | grep -q "threat-intelligence-optimized.sh"; then
    (crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -
    echo "Added cron fallback for threat feed updates"
fi

echo "Threat feed scheduling completed"
echo "Timer status: systemctl --user list-timers | grep threat-feed"