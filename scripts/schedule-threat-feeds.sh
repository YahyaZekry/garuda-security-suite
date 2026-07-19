#!/bin/bash
# Schedule Automated Threat Feed Updates

source "$(dirname "$0")/common-functions.sh"

AEGIS_HOME="$(dirname "$(dirname "$0")")"
THREAT_INTEL_SCRIPT="$AEGIS_HOME/scripts/threat-intelligence-optimized.sh"

log_info "Setting up automated threat feed updates..."

# Create systemd service for threat intelligence updates
cat > "$AEGIS_HOME/scripts/threat-feed-update.service" << EOF
[Unit]
Description=Aegis Security Suite - Threat Intelligence Feed Updates
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$THREAT_INTEL_SCRIPT update
User=$USER
Group=$USER
StandardOutput=journal
StandardError=journal
EOF

# Create systemd timer for hourly updates
cat > "$AEGIS_HOME/scripts/threat-feed-update.timer" << EOF
[Unit]
Description=Run threat intelligence feed updates every hour
Requires=threat-feed-update.service

[Timer]
OnCalendar=hourly
Persistent=true
RandomizedDelaySec=300

[Install]
WantedBy=timers.target
EOF

# Create systemd timer for daily full updates
cat > "$AEGIS_HOME/scripts/threat-feed-daily.timer" << EOF
[Unit]
Description=Run full threat intelligence feed updates daily
Requires=threat-feed-update.service

[Timer]
OnCalendar=daily
Persistent=true
RandomizedDelaySec=600

[Install]
WantedBy=timers.target
EOF

# Create systemd timer for weekly cleanup
cat > "$AEGIS_HOME/scripts/threat-feed-cleanup.timer" << EOF
[Unit]
Description=Run threat intelligence cleanup weekly
Requires=threat-feed-update.service

[Timer]
OnCalendar=weekly
Persistent=true
RandomizedDelaySec=900

[Install]
WantedBy=timers.target
EOF

# Create cleanup script
cat > "$AEGIS_HOME/scripts/threat-feed-cleanup.sh" << 'EOF'
#!/bin/bash
# Threat Intelligence Cleanup Script

source "$(dirname "$0")/common-functions.sh"

AEGIS_HOME="$(dirname "$(dirname "$0")")"
THREAT_INTEL_SCRIPT="$AEGIS_HOME/scripts/threat-intelligence-optimized.sh"

log_info "Running threat intelligence cleanup..."

# Remove old IOCs (older than 30 days) with low confidence
IOC_DATABASE="$AEGIS_HOME/configs/threat_intelligence/ioc_database.db"
CUTOFF_DATE=$(date -d "30 days ago" +%s)

sqlite3 "$IOC_DATABASE" << EOF
DELETE FROM ioc_ips WHERE first_seen < $CUTOFF_DATE AND confidence < 70;
DELETE FROM ioc_domains WHERE first_seen < $CUTOFF_DATE AND confidence < 70;
DELETE FROM ioc_urls WHERE first_seen < $CUTOFF_DATE AND confidence < 70;
DELETE FROM ioc_hashes WHERE first_seen < $CUTOFF_DATE AND confidence < 70;
EOF

# Clean up old cache files
find "$AEGIS_HOME/configs/threat_intelligence/cache" -type f -mtime +7 -delete 2>/dev/null

# Vacuum database to optimize space
sqlite3 "$IOC_DATABASE" "VACUUM;"

log_success "Threat intelligence cleanup completed"
EOF

chmod +x "$AEGIS_HOME/scripts/threat-feed-cleanup.sh"

# Install systemd services and timers
log_info "Installing systemd services and timers..."

# Copy files to systemd user directory
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
mkdir -p "$SYSTEMD_USER_DIR"

cp "$AEGIS_HOME/scripts/threat-feed-update.service" "$SYSTEMD_USER_DIR/"
cp "$AEGIS_HOME/scripts/threat-feed-update.timer" "$SYSTEMD_USER_DIR/"
cp "$AEGIS_HOME/scripts/threat-feed-daily.timer" "$SYSTEMD_USER_DIR/"
cp "$AEGIS_HOME/scripts/threat-feed-cleanup.timer" "$SYSTEMD_USER_DIR/"

# Create a service for cleanup
cat > "$SYSTEMD_USER_DIR/threat-feed-cleanup.service" << EOF
[Unit]
Description=Aegis Security Suite - Threat Intelligence Cleanup
After=network-online.target

[Service]
Type=oneshot
ExecStart=$AEGIS_HOME/scripts/threat-feed-cleanup.sh
User=$USER
Group=$USER
StandardOutput=journal
StandardError=journal
EOF

# Reload systemd daemon
systemctl --user daemon-reload

# Enable and start timers
systemctl --user enable threat-feed-update.timer
systemctl --user start threat-feed-update.timer

systemctl --user enable threat-feed-daily.timer
systemctl --user start threat-feed-daily.timer

systemctl --user enable threat-feed-cleanup.timer
systemctl --user start threat-feed-cleanup.timer

# Create cron fallback for systems without systemd
log_info "Creating cron fallback script..."

cat > "$AEGIS_HOME/scripts/threat-feed-cron.sh" << 'EOF'
#!/bin/bash
# Cron fallback for threat intelligence updates

AEGIS_HOME="$(dirname "$(dirname "$0")")"
THREAT_INTEL_SCRIPT="$AEGIS_HOME/scripts/threat-intelligence-optimized.sh"

# Check if systemd timers are active
if ! systemctl --user is-active --quiet threat-feed-update.timer 2>/dev/null; then
    # Fallback to cron-based updates
    case "$(date +%H)" in
        00|06|12|18)
            # Every 6 hours
            "$THREAT_INTEL_SCRIPT" update
            ;;
        03)
            # Daily cleanup at 3 AM
            "$AEGIS_HOME/scripts/threat-feed-cleanup.sh"
            ;;
    esac
fi
EOF

chmod +x "$AEGIS_HOME/scripts/threat-feed-cron.sh"

# Add to crontab if not already present
CRON_ENTRY="0 */6 * * * $AEGIS_HOME/scripts/threat-feed-cron.sh"
if ! crontab -l 2>/dev/null | grep -q "threat-feed-cron.sh"; then
    (crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -
    log_info "Added cron fallback for threat feed updates"
fi

# Create status check script
cat > "$AEGIS_HOME/scripts/check-threat-feed-status.sh" << 'EOF'
#!/bin/bash
# Check Threat Feed Update Status

AEGIS_HOME="$(dirname "$(dirname "$0")")"
IOC_DATABASE="$AEGIS_HOME/configs/threat_intelligence/ioc_database.db"

echo "=== Threat Intelligence Status ==="
echo

# Check database statistics
echo "IOC Database Statistics:"
sqlite3 "$IOC_DATABASE" << EOF
SELECT 'Total IPs: ' || COUNT(*) FROM ioc_ips;
SELECT 'Total Domains: ' || COUNT(*) FROM ioc_domains;
SELECT 'Total URLs: ' || COUNT(*) FROM ioc_urls;
SELECT 'Total Hashes: ' || COUNT(*) FROM ioc_hashes;
EOF

echo
echo "Feed Update Status:"
sqlite3 "$IOC_DATABASE" << EOF
SELECT feed_name, 
       datetime(last_updated, 'unixepoch') as last_update,
       iocs_added,
       iocs_updated,
       status
FROM threat_feeds
ORDER BY last_updated DESC;
EOF

echo
echo "Systemd Timer Status:"
systemctl --user list-timers --all | grep threat-feed || echo "No systemd timers found"

echo
echo "Last 10 Feed Updates:"
sqlite3 "$IOC_DATABASE" << EOF
SELECT feed_name,
       datetime(timestamp, 'unixepoch') as update_time,
       iocs_processed,
       errors
FROM feed_statistics
ORDER BY timestamp DESC
LIMIT 10;
EOF
EOF

chmod +x "$AEGIS_HOME/scripts/check-threat-feed-status.sh"

log_success "Automated threat feed updates configured"
log_info "Services installed:"
log_info "  - threat-feed-update.timer (hourly updates)"
log_info "  - threat-feed-daily.timer (daily full updates)"
log_info "  - threat-feed-cleanup.timer (weekly cleanup)"
log_info ""
log_info "Status check script: $AEGIS_HOME/scripts/check-threat-feed-status.sh"
log_info ""
log_info "To check timer status: systemctl --user list-timers | grep threat-feed"
log_info "To view logs: journalctl --user -u threat-feed-update.service"