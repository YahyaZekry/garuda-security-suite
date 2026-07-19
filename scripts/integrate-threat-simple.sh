#!/bin/bash
# Simple Threat Intelligence Integration

AEGIS_HOME="$(dirname "$(dirname "$0")")"
IOC_DATABASE="$AEGIS_HOME/configs/threat_intelligence/ioc_database.db"

echo "Integrating threat intelligence with scanning components..."

# Create enhanced ClamAV scanner with threat intelligence
cat > "$AEGIS_HOME/scripts/scanners/clamav-with-threat-intel.sh" << 'EOF'
#!/bin/bash
# ClamAV Scanner with Threat Intelligence Integration

SCAN_PATH="${1:-$HOME}"
IOC_DATABASE="$AEGIS_HOME/configs/threat_intelligence/ioc_database.db"

echo "Starting ClamAV scan with threat intelligence integration for: $SCAN_PATH"

# Check if file is in IOC database before scanning
if [ -f "$IOC_DATABASE" ]; then
    echo "Checking files against threat intelligence database..."
    find "$SCAN_PATH" -type f -exec sha256sum {} \; 2>/dev/null | while read hash file; do
        result=$(sqlite3 "$IOC_DATABASE" "SELECT file_hash FROM ioc_hashes WHERE file_hash = '$hash' LIMIT 1" 2>/dev/null)
        if [ -n "$result" ]; then
            echo "WARNING: File $file matches known malicious hash: $hash"
        fi
    done
fi

# Run ClamAV scan
if command -v clamscan &>/dev/null; then
    echo "Running ClamAV scan..."
    clamscan --recursive --infected --detect-pua --detect-structured=yes "$SCAN_PATH"
else
    echo "ClamAV not found"
    exit 1
fi
EOF

# Create enhanced RKHunter scanner with threat intelligence
cat > "$AEGIS_HOME/scripts/scanners/rkhunter-with-threat-intel.sh" << 'EOF'
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
EOF

# Make the enhanced scanners executable
chmod +x "$AEGIS_HOME/scripts/scanners/clamav-with-threat-intel.sh"
chmod +x "$AEGIS_HOME/scripts/scanners/rkhunter-with-threat-intel.sh"

echo "Threat intelligence integration completed"
echo "Enhanced scanners created:"
echo "  - $AEGIS_HOME/scripts/scanners/clamav-with-threat-intel.sh"
echo "  - $AEGIS_HOME/scripts/scanners/rkhunter-with-threat-intel.sh"