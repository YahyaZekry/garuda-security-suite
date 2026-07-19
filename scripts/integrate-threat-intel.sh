#!/bin/bash
# Integrate Threat Intelligence with Scanning Components

source "$(dirname "$0")/common-functions.sh"

# Set paths
AEGIS_HOME="$(dirname "$(dirname "$0")")"
THREAT_DB_DIR="$AEGIS_HOME/configs/threat_intelligence"
IOC_DATABASE="$THREAT_DB_DIR/ioc_database.db"

log_info "Integrating threat intelligence with scanning components..."

# Function to check if an IP is in the IOC database
check_ip_ioc() {
    local ip="$1"
    local result=$(sqlite3 "$IOC_DATABASE" "SELECT ip_address, threat_type, confidence FROM ioc_ips WHERE ip_address = '$ip' LIMIT 1")
    if [ -n "$result" ]; then
        echo "WARNING: IP $ip found in threat intelligence database: $result"
        return 1
    fi
    return 0
}

# Function to check if a domain is in the IOC database
check_domain_ioc() {
    local domain="$1"
    local result=$(sqlite3 "$IOC_DATABASE" "SELECT domain, threat_type, confidence FROM ioc_domains WHERE domain = '$domain' LIMIT 1")
    if [ -n "$result" ]; then
        echo "WARNING: Domain $domain found in threat intelligence database: $result"
        return 1
    fi
    return 0
}

# Function to check if a URL is in the IOC database
check_url_ioc() {
    local url="$1"
    local result=$(sqlite3 "$IOC_DATABASE" "SELECT url, threat_type, confidence FROM ioc_urls WHERE url = '$url' LIMIT 1")
    if [ -n "$result" ]; then
        echo "WARNING: URL $url found in threat intelligence database: $result"
        return 1
    fi
    return 0
}

# Function to check if a file hash is in the IOC database
check_hash_ioc() {
    local hash="$1"
    local result=$(sqlite3 "$IOC_DATABASE" "SELECT file_hash, hash_type, threat_type, confidence FROM ioc_hashes WHERE file_hash = '$hash' LIMIT 1")
    if [ -n "$result" ]; then
        echo "WARNING: Hash $hash found in threat intelligence database: $result"
        return 1
    fi
    return 0
}

# Create enhanced scanner scripts with threat intelligence integration

# Enhanced ClamAV scanner
cat > "$AEGIS_HOME/scripts/scanners/clamav-with-threat-intel.sh" << 'EOF'
#!/bin/bash
# ClamAV Scanner with Threat Intelligence Integration

source "$(dirname "$0")/../common-functions.sh"

SCAN_PATH="${1:-$HOME}"
IOC_DATABASE="$AEGIS_HOME/configs/threat_intelligence/ioc_database.db"

log_info "Starting ClamAV scan with threat intelligence integration for: $SCAN_PATH"

# Check if file is in IOC database before scanning
check_file_threat_intel() {
    local file="$1"
    if [ -f "$file" ]; then
        # Calculate file hash
        local file_hash=$(sha256sum "$file" | awk '{print $1}')
        local result=$(sqlite3 "$IOC_DATABASE" "SELECT file_hash, threat_type, confidence FROM ioc_hashes WHERE file_hash = '$file_hash' LIMIT 1")
        
        if [ -n "$result" ]; then
            log_warning "File $file matches known malicious hash: $result"
            echo "THREAT_INTEL: Malicious hash detected"
            return 1
        fi
    fi
    return 0
}

# Export function for use in find command
export -f check_file_threat_intel
export IOC_DATABASE

# Run ClamAV scan with threat intelligence pre-check
if command -v clamscan &>/dev/null; then
    log_info "Running ClamAV scan..."
    
    # First check for known malicious hashes
    log_info "Pre-checking files against threat intelligence database..."
    find "$SCAN_PATH" -type f -exec bash -c 'check_file_threat_intel "$0"' {} \; 2>/dev/null
    
    # Then run ClamAV scan
    clamscan --recursive --infected --detect-pua --detect-structured=yes \
             --database="$AEGIS_HOME/configs/clamav" "$SCAN_PATH"
    
    scan_result=$?
    if [ $scan_result -eq 0 ]; then
        log_success "ClamAV scan completed - no threats detected"
    elif [ $scan_result -eq 1 ]; then
        log_warning "ClamAV scan completed - viruses detected"
    else
        log_error "ClamAV scan failed with exit code: $scan_result"
    fi
else
    log_error "ClamAV not found"
    exit 1
fi
EOF

# Enhanced RKHunter scanner
cat > "$AEGIS_HOME/scripts/scanners/rkhunter-with-threat-intel.sh" << 'EOF'
#!/bin/bash
# RKHunter Scanner with Threat Intelligence Integration

source "$(dirname "$0")/../common-functions.sh"

IOC_DATABASE="$AEGIS_HOME/configs/threat_intelligence/ioc_database.db"

log_info "Starting RKHunter scan with threat intelligence integration"

# Check network connections against IOC database
check_network_threat_intel() {
    log_info "Checking network connections against threat intelligence database..."
    
    # Get active network connections
    if command -v netstat &>/dev/null; then
        netstat -tn 2>/dev/null | awk '$1=="tcp" && $6=="ESTABLISHED" {print $5}' | cut -d: -f1 | sort -u | while read ip; do
            if [ -n "$ip" ] && [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                result=$(sqlite3 "$IOC_DATABASE" "SELECT ip_address, threat_type, confidence FROM ioc_ips WHERE ip_address = '$ip' LIMIT 1")
                if [ -n "$result" ]; then
                    log_warning "Suspicious connection to malicious IP: $ip - $result"
                fi
            fi
        done
    fi
}

# Run threat intelligence check
check_network_threat_intel

# Run RKHunter scan
if command -v rkhunter &>/dev/null; then
    log_info "Running RKHunter scan..."
    rkhunter --check --skip-keypress --report-warnings-only
    scan_result=$?
    
    if [ $scan_result -eq 0 ]; then
        log_success "RKHunter scan completed - no warnings"
    else
        log_warning "RKHunter scan completed with warnings"
    fi
else
    log_error "RKHunter not found"
    exit 1
fi
EOF

# Make the enhanced scanners executable
chmod +x "$AEGIS_HOME/scripts/scanners/clamav-with-threat-intel.sh"
chmod +x "$AEGIS_HOME/scripts/scanners/rkhunter-with-threat-intel.sh"

# Update the main scanning scripts to use threat intelligence
log_info "Updating main scanning scripts to use threat intelligence..."

# Update daily scan script
if [ -f "$AEGIS_HOME/scripts/security-daily-scan.sh" ]; then
    # Add threat intelligence check to daily scan
    sed -i '/# Run ClamAV scan/i \
# Check against threat intelligence database\
log_info "Checking system against threat intelligence database..."\
if [ -f "$IOC_DATABASE" ]; then\
    # Check network connections\
    netstat -tn 2>/dev/null | awk '\''$1=="tcp" && $6=="ESTABLISHED" {print $5}'\'' | cut -d: -f1 | sort -u | while read ip; do\
        if [ -n "$ip" ] && [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then\
            result=$(sqlite3 "$IOC_DATABASE" "SELECT ip_address, threat_type, confidence FROM ioc_ips WHERE ip_address = '\''$ip'\'' LIMIT 1")\
            if [ -n "$result" ]; then\
                log_warning "Suspicious connection to malicious IP: $ip - $result"\
            fi\
        fi\
    done\
fi\
' "$AEGIS_HOME/scripts/security-daily-scan.sh"
fi

log_success "Threat intelligence integration completed"
log_info "Enhanced scanners created:"
log_info "  - $AEGIS_HOME/scripts/scanners/clamav-with-threat-intel.sh"
log_info "  - $AEGIS_HOME/scripts/scanners/rkhunter-with-threat-intel.sh"