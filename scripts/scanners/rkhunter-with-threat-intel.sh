#!/bin/bash
# RKHunter Scanner with Threat Intelligence Integration

IOC_DATABASE="$AEGIS_HOME/configs/threat_intelligence/ioc_database.db"

echo "Starting RKHunter scan with threat intelligence integration"

# Check network connections against IOC database
if [ -f "$IOC_DATABASE" ]; then
    echo "Checking network connections against threat intelligence database..."
    if command -v netstat &>/dev/null; then
        netstat -tn 2>/dev/null | awk '$1=="tcp" && $6=="ESTABLISHED" {print $5}' | cut -d: -f1 | sort -u | while read ip; do
            if [ -n "$ip" ] && [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                result=$(sqlite3 "$IOC_DATABASE" "SELECT ip_address FROM ioc_ips WHERE ip_address = '$ip' LIMIT 1" 2>/dev/null)
                if [ -n "$result" ]; then
                    echo "WARNING: Suspicious connection to malicious IP: $ip"
                fi
            fi
        done
    fi
fi

# Run RKHunter scan
if command -v rkhunter &>/dev/null; then
    echo "Running RKHunter scan..."
    rkhunter --check --skip-keypress --report-warnings-only
else
    echo "RKHunter not found"
    exit 1
fi