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