#!/bin/bash
# Automated Incident Response System
# Integrates with threat intelligence for automated security incident handling

# Source common functions
source "$(dirname "$0")/common-functions.sh"

# Load behavioral analysis if available
if [ -f "$(dirname "$0")/behavioral-analysis-optimized.sh" ]; then
    source "$(dirname "$0")/behavioral-analysis-optimized.sh"
fi

# Get security suite home directory
SCRIPT_DIR="$(dirname "$0")"
AEGIS_HOME="$(dirname "$SCRIPT_DIR")"

# Load configuration to get database paths
source "$AEGIS_HOME/configs/security-config.conf" 2>/dev/null || {
    # Fallback if config not available
    INCIDENT_DB_DIR="$AEGIS_HOME/configs/incident_response"
    INCIDENT_DATABASE="$INCIDENT_DB_DIR/incidents.db"
    QUARANTINE_DIR="$AEGIS_HOME/quarantine"
    EVIDENCE_DIR="$AEGIS_HOME/evidence"
}

# Incident response configuration
declare -A SEVERITY_LEVELS=(
    ["critical"]=4
    ["high"]=3
    ["medium"]=2
    ["low"]=1
)

declare -A RESPONSE_ACTIONS=(
    ["critical"]="quarantine_file,isolate_process,block_network,collect_evidence,notify_admin"
    ["high"]="quarantine_file,block_network,collect_evidence,notify_admin"
    ["medium"]="quarantine_file,collect_evidence,log_incident"
    ["low"]="log_incident,monitor"
)

# Initialize incident response system
init_incident_response() {
    log_info "Initializing automated incident response system..."
    
    # Create directories
    mkdir -p "$INCIDENT_DB_DIR" "$QUARANTINE_DIR" "$EVIDENCE_DIR"
    
    # Set proper permissions
    chmod 700 "$INCIDENT_DB_DIR"
    chmod 700 "$QUARANTINE_DIR"
    chmod 700 "$EVIDENCE_DIR"
    
    # Initialize incident database
    if [ ! -f "$INCIDENT_DATABASE" ]; then
        create_incident_database
    fi
    
    log_info "Incident response system initialized successfully"
}

# Create incident database
create_incident_database() {
    log_info "Creating incident database..."
    
    sqlite3 "$INCIDENT_DATABASE" << 'EOF'
-- Incident Response Database Schema
CREATE TABLE IF NOT EXISTS incidents (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    incident_id TEXT UNIQUE NOT NULL,
    incident_type TEXT NOT NULL,
    incident_details TEXT NOT NULL,
    severity TEXT NOT NULL,
    status TEXT DEFAULT 'open',
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    resolved_timestamp DATETIME,
    actions_taken TEXT,
    evidence_path TEXT,
    false_positive BOOLEAN DEFAULT 0,
    rollback_available BOOLEAN DEFAULT 0,
    rollback_data TEXT
);

CREATE TABLE IF NOT EXISTS quarantine_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    incident_id TEXT NOT NULL,
    original_path TEXT NOT NULL,
    quarantine_path TEXT NOT NULL,
    file_hash TEXT NOT NULL,
    quarantine_timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    restored_timestamp DATETIME,
    restored_by TEXT,
    FOREIGN KEY (incident_id) REFERENCES incidents (incident_id)
);

CREATE TABLE IF NOT EXISTS network_blocks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    incident_id TEXT NOT NULL,
    blocked_ip TEXT NOT NULL,
    block_type TEXT NOT NULL,
    block_timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    unblocked_timestamp DATETIME,
    unblocked_by TEXT,
    rule_id TEXT,
    FOREIGN KEY (incident_id) REFERENCES incidents (incident_id)
);

CREATE TABLE IF NOT EXISTS process_isolation (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    incident_id TEXT NOT NULL,
    process_id INTEGER NOT NULL,
    process_name TEXT NOT NULL,
    isolation_timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    isolation_method TEXT NOT NULL,
    killed_timestamp DATETIME,
    killed_by TEXT,
    FOREIGN KEY (incident_id) REFERENCES incidents (incident_id)
);

CREATE TABLE IF NOT EXISTS evidence_collection (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    incident_id TEXT NOT NULL,
    evidence_type TEXT NOT NULL,
    evidence_path TEXT NOT NULL,
    collection_timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    description TEXT,
    hash_value TEXT,
    FOREIGN KEY (incident_id) REFERENCES incidents (incident_id)
);

CREATE TABLE IF NOT EXISTS incident_timeline (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    incident_id TEXT NOT NULL,
    action TEXT NOT NULL,
    details TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    automated BOOLEAN DEFAULT 1,
    FOREIGN KEY (incident_id) REFERENCES incidents (incident_id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_incidents_id ON incidents(incident_id);
CREATE INDEX IF NOT EXISTS idx_incidents_severity ON incidents(severity);
CREATE INDEX IF NOT EXISTS idx_incidents_status ON incidents(status);
CREATE INDEX IF NOT EXISTS idx_incidents_timestamp ON incidents(timestamp);
CREATE INDEX IF NOT EXISTS idx_quarantine_incident ON quarantine_log(incident_id);
CREATE INDEX IF NOT EXISTS idx_network_blocks_incident ON network_blocks(incident_id);
CREATE INDEX IF NOT EXISTS idx_process_isolation_incident ON process_isolation(incident_id);
CREATE INDEX IF NOT EXISTS idx_evidence_incident ON evidence_collection(incident_id);
CREATE INDEX IF NOT EXISTS idx_timeline_incident ON incident_timeline(incident_id);
EOF

    log_info "Incident database created successfully"
}

# Main automated response function
automated_response() {
    local incident_type="$1"
    local incident_details="$2"
    local severity="$3"
    
    # Validate inputs
    if [ -z "$incident_type" ] || [ -z "$incident_details" ] || [ -z "$severity" ]; then
        log_error "automated_response: Missing required parameters"
        return 1
    fi
    
    # Validate severity level
    if [ -z "${SEVERITY_LEVELS[$severity]}" ]; then
        log_error "automated_response: Invalid severity level: $severity"
        return 1
    fi
    
    # Generate unique incident ID
    local incident_id="INC_$(date +%Y%m%d_%H%M%S)_$(shuf -i 1000-9999 -n 1)"
    
    log_info "🚨 INCIDENT RESPONSE TRIGGERED: $incident_id"
    log_info "  Type: $incident_type"
    log_info "  Severity: $severity"
    log_info "  Details: $incident_details"
    
    # Create incident record
    create_incident_record "$incident_id" "$incident_type" "$incident_details" "$severity"
    
    # Get response actions for severity level
    local actions="${RESPONSE_ACTIONS[$severity]}"
    
    # Execute response actions
    local actions_taken=""
    local action_success=true
    
    IFS=',' read -ra action_array <<< "$actions"
    for action in "${action_array[@]}"; do
        action=$(echo "$action" | xargs)  # Trim whitespace
        
        log_info "Executing response action: $action"
        
        case "$action" in
            "quarantine_file")
                if execute_quarantine_action "$incident_id" "$incident_details"; then
                    actions_taken="${actions_taken}quarantine_file,"
                else
                    action_success=false
                fi
                ;;
            "isolate_process")
                if execute_process_isolation "$incident_id" "$incident_details"; then
                    actions_taken="${actions_taken}isolate_process,"
                else
                    action_success=false
                fi
                ;;
            "block_network")
                if execute_network_blocking "$incident_id" "$incident_details"; then
                    actions_taken="${actions_taken}block_network,"
                else
                    action_success=false
                fi
                ;;
            "collect_evidence")
                if execute_evidence_collection "$incident_id" "$incident_details"; then
                    actions_taken="${actions_taken}collect_evidence,"
                else
                    action_success=false
                fi
                ;;
            "notify_admin")
                if execute_admin_notification "$incident_id" "$incident_type" "$severity"; then
                    actions_taken="${actions_taken}notify_admin,"
                else
                    action_success=false
                fi
                ;;
            "log_incident")
                actions_taken="${actions_taken}log_incident,"
                ;;
            "monitor")
                if execute_monitoring "$incident_id" "$incident_details"; then
                    actions_taken="${actions_taken}monitor,"
                else
                    action_success=false
                fi
                ;;
            *)
                log_warning "Unknown response action: $action"
                ;;
        esac
        
        # Add to timeline
        add_timeline_entry "$incident_id" "action_executed" "Action: $action" true
    done
    
    # Update incident record with actions taken
    update_incident_actions "$incident_id" "$actions_taken"
    
    # Send notification
    send_notification "🚨 Security Incident: $incident_id" "Type: $incident_type, Severity: $severity" "security-critical" "critical"
    
    # Log completion
    if [ "$action_success" = true ]; then
        log_info "✅ Incident response completed successfully: $incident_id"
    else
        log_warning "⚠️ Incident response completed with some failures: $incident_id"
    fi
    
    return 0
}

# Create incident record in database
create_incident_record() {
    local incident_id="$1"
    local incident_type="$2"
    local incident_details="$3"
    local severity="$4"
    
    sqlite3 "$INCIDENT_DATABASE" << EOF
INSERT INTO incidents (incident_id, incident_type, incident_details, severity, status)
VALUES ('$incident_id', '$incident_type', '$incident_details', '$severity', 'open');
EOF

    # Add initial timeline entry
    add_timeline_entry "$incident_id" "incident_created" "Incident created with severity: $severity" true
}

# Update incident with actions taken
update_incident_actions() {
    local incident_id="$1"
    local actions_taken="$2"
    
    sqlite3 "$INCIDENT_DATABASE" << EOF
UPDATE incidents 
SET actions_taken = '$actions_taken'
WHERE incident_id = '$incident_id';
EOF
}

# Add timeline entry
add_timeline_entry() {
    local incident_id="$1"
    local action="$2"
    local details="$3"
    local automated="${4:-true}"
    
    sqlite3 "$INCIDENT_DATABASE" << EOF
INSERT INTO incident_timeline (incident_id, action, details, automated)
VALUES ('$incident_id', '$action', '$details', $automated);
EOF
}

# Execute file quarantine action
execute_quarantine_action() {
    local incident_id="$1"
    local incident_details="$2"
    
    # Extract file path from incident details
    local file_path=""
    if [[ "$incident_details" =~ file:[^,]+ ]]; then
        file_path=$(echo "$incident_details" | grep -o 'file:[^,]*' | cut -d: -f2 | xargs)
    fi
    
    if [ -z "$file_path" ] || [ ! -f "$file_path" ]; then
        log_warning "No valid file path found for quarantine: $file_path"
        return 1
    fi
    
    quarantine_file "$incident_id" "$file_path"
}

# Quarantine file function
quarantine_file() {
    local incident_id="$1"
    local file_path="$2"
    
    log_info "Quarantining file: $file_path"
    
    # Validate file path
    if ! validate_path "$file_path" "Invalid file path for quarantine"; then
        return 1
    fi
    
    # Check if file exists
    if [ ! -f "$file_path" ]; then
        log_error "File not found for quarantine: $file_path"
        return 1
    fi
    
    # Generate quarantine path
    local file_name=$(basename "$file_path")
    local quarantine_path="$QUARANTINE_DIR/${file_name}_$(date +%Y%m%d_%H%M%S)_$(shuf -i 1000-9999 -n 1)"
    
    # Calculate file hash
    local file_hash=$(sha256sum "$file_path" | awk '{print $1}')
    
    # Move file to quarantine
    if mv "$file_path" "$quarantine_path"; then
        # Set restrictive permissions
        chmod 000 "$quarantine_path" 2>/dev/null || true
        
        # Log quarantine action
        log_info "File quarantined: $file_path -> $quarantine_path"
        
        # Record in database
        sqlite3 "$INCIDENT_DATABASE" << EOF
INSERT INTO quarantine_log (incident_id, original_path, quarantine_path, file_hash)
VALUES ('$incident_id', '$file_path', '$quarantine_path', '$file_hash');
EOF
        
        # Add to timeline
        add_timeline_entry "$incident_id" "file_quarantined" "File: $file_path, Hash: $file_hash" true
        
        # Update incident with rollback capability
        sqlite3 "$INCIDENT_DATABASE" << EOF
UPDATE incidents 
SET rollback_available = 1,
    rollback_data = '{"original_path": "$file_path", "quarantine_path": "$quarantine_path", "file_hash": "$file_hash"}'
WHERE incident_id = '$incident_id';
EOF
        
        return 0
    else
        log_error "Failed to quarantine file: $file_path"
        return 1
    fi
}

# Execute process isolation action
execute_process_isolation() {
    local incident_id="$1"
    local incident_details="$2"
    
    # Extract process information from incident details
    local process_info=""
    if [[ "$incident_details" =~ process:[^,]+ ]]; then
        process_info=$(echo "$incident_details" | grep -o 'process:[^,]*' | cut -d: -f2 | xargs)
    fi
    
    if [ -z "$process_info" ]; then
        log_warning "No process information found for isolation"
        return 1
    fi
    
    # Try to extract PID if it's a number
    local process_id=""
    if [[ "$process_info" =~ ^[0-9]+$ ]]; then
        process_id="$process_info"
    else
        # Try to find PID by process name
        process_id=$(pgrep -f "$process_info" | head -1)
    fi
    
    if [ -z "$process_id" ]; then
        log_warning "Could not determine process ID for: $process_info"
        return 1
    fi
    
    isolate_process "$incident_id" "$process_id" "$process_info"
}

# Isolate process function
isolate_process() {
    local incident_id="$1"
    local process_id="$2"
    local process_name="$3"
    
    log_info "Isolating process: $process_id ($process_name)"
    
    # Validate process ID
    if ! [[ "$process_id" =~ ^[0-9]+$ ]]; then
        log_error "Invalid process ID: $process_id"
        return 1
    fi
    
    # Check if process exists
    if ! kill -0 "$process_id" 2>/dev/null; then
        log_warning "Process not found: $process_id"
        return 1
    fi
    
    # Get process details
    local process_cmd=$(ps -p "$process_id" -o comm= 2>/dev/null)
    local process_parent=$(ps -p "$process_id" -o ppid= 2>/dev/null | xargs)
    
    # Isolate process using multiple methods
    local isolation_method=""
    local isolation_success=false
    
    # Method 1: Stop the process (SIGSTOP)
    if kill -STOP "$process_id" 2>/dev/null; then
        isolation_method="SIGSTOP"
        isolation_success=true
        log_info "Process stopped with SIGSTOP: $process_id"
    fi
    
    # Method 2: If SIGSTOP fails, try to terminate
    if [ "$isolation_success" = false ]; then
        if kill -TERM "$process_id" 2>/dev/null; then
            isolation_method="SIGTERM"
            isolation_success=true
            log_info "Process terminated with SIGTERM: $process_id"
            
            # Wait a moment and check if it's still running
            sleep 2
            if kill -0 "$process_id" 2>/dev/null; then
                # Force kill if still running
                kill -KILL "$process_id" 2>/dev/null
                isolation_method="SIGKILL"
                log_info "Process force killed with SIGKILL: $process_id"
            fi
        fi
    fi
    
    if [ "$isolation_success" = true ]; then
        # Record in database
        sqlite3 "$INCIDENT_DATABASE" << EOF
INSERT INTO process_isolation (incident_id, process_id, process_name, isolation_method)
VALUES ('$incident_id', '$process_id', '$process_name', '$isolation_method');
EOF
        
        # Add to timeline
        add_timeline_entry "$incident_id" "process_isolated" "Process: $process_id ($process_name), Method: $isolation_method" true
        
        return 0
    else
        log_error "Failed to isolate process: $process_id"
        return 1
    fi
}

# Execute network blocking action
execute_network_blocking() {
    local incident_id="$1"
    local incident_details="$2"
    
    # Extract IP addresses from incident details
    local ips_to_block=""
    if [[ "$incident_details" =~ blocked_ips:[^,]+ ]]; then
        ips_to_block=$(echo "$incident_details" | grep -o 'blocked_ips:[^,]*' | cut -d: -f2 | xargs)
    fi
    
    if [ -z "$ips_to_block" ]; then
        log_warning "No IP addresses found for blocking"
        return 1
    fi
    
    # Block each IP
    IFS=' ' read -ra ip_array <<< "$ips_to_block"
    for ip in "${ip_array[@]}"; do
        block_network "$incident_id" "$ip"
    done
}

# Block network function
block_network() {
    local incident_id="$1"
    local ip_address="$2"
    
    log_info "Blocking network access to/from: $ip_address"
    
    # Validate IP address
    if ! validate_ipv4 "$ip_address"; then
        log_error "Invalid IP address for blocking: $ip_address"
        return 1
    fi
    
    # Check if already blocked
    local existing_block=$(sqlite3 "$INCIDENT_DATABASE" << EOF
SELECT id FROM network_blocks 
WHERE blocked_ip = '$ip_address' AND unblocked_timestamp IS NULL;
EOF
)
    
    if [ -n "$existing_block" ]; then
        log_warning "IP $ip_address is already blocked"
        return 0
    fi
    
    # Block using iptables (if available)
    local block_success=false
    local rule_id=""
    
    if command -v iptables &>/dev/null; then
        # Generate rule ID
        rule_id="SEC_BLOCK_$(date +%s)_$(shuf -i 1000-9999 -n 1)"
        
        # Block inbound traffic
        if command -v sudo_execute &>/dev/null; then
            if sudo_execute "iptables -A INPUT -s $ip_address -j DROP -m comment --comment '$rule_id'" "block_ip_input_$ip_address"; then
                # Block outbound traffic
                sudo_execute "iptables -A OUTPUT -d $ip_address -j DROP -m comment --comment '$rule_id'" "block_ip_output_$ip_address"
                block_success=true
                log_info "IP blocked using iptables: $ip_address"
            fi
        else
            log_warning "sudo_execute not available, cannot block with iptables"
        fi
    else
        log_warning "iptables not available for network blocking"
    fi
    
    # Record in database (even if iptables failed, for tracking)
    sqlite3 "$INCIDENT_DATABASE" << EOF
INSERT INTO network_blocks (incident_id, blocked_ip, block_type, rule_id)
VALUES ('$incident_id', '$ip_address', 'iptables', '$rule_id');
EOF
    
    # Add to timeline
    add_timeline_entry "$incident_id" "network_blocked" "IP: $ip_address, Method: iptables, Success: $block_success" true
    
    return 0
}

# Execute evidence collection action
execute_evidence_collection() {
    local incident_id="$1"
    local incident_details="$2"
    
    log_info "Collecting evidence for incident: $incident_id"
    
    # Collect various types of evidence
    collect_evidence "$incident_id" "system_state" "Current system state"
    collect_evidence "$incident_id" "network_connections" "Active network connections"
    collect_evidence "$incident_id" "running_processes" "Running processes"
    collect_evidence "$incident_id" "incident_details" "Incident details and context"
    
    # If file-related incident, collect file evidence
    if [[ "$incident_details" =~ file:[^,]+ ]]; then
        local file_path=$(echo "$incident_details" | grep -o 'file:[^,]*' | cut -d: -f2 | xargs)
        if [ -n "$file_path" ]; then
            collect_file_evidence "$incident_id" "$file_path"
        fi
    fi
}

# Collect evidence function
collect_evidence() {
    local incident_id="$1"
    local evidence_type="$2"
    local description="$3"
    
    local evidence_file="$EVIDENCE_DIR/${incident_id}_${evidence_type}_$(date +%Y%m%d_%H%M%S).txt"
    local evidence_hash=""
    
    log_info "Collecting evidence: $evidence_type"
    
    case "$evidence_type" in
        "system_state")
            {
                echo "=== SYSTEM STATE EVIDENCE ==="
                echo "Incident ID: $incident_id"
                echo "Collection Time: $(date)"
                echo "Hostname: $(hostname)"
                echo "User: $(whoami)"
                echo "Uptime: $(uptime)"
                echo ""
                echo "=== MEMORY USAGE ==="
                free -h
                echo ""
                echo "=== DISK USAGE ==="
                df -h
                echo ""
                echo "=== SYSTEM LOAD ==="
                uptime
                echo ""
                echo "=== LOGGED IN USERS ==="
                who
            } > "$evidence_file"
            ;;
        "network_connections")
            {
                echo "=== NETWORK CONNECTIONS EVIDENCE ==="
                echo "Incident ID: $incident_id"
                echo "Collection Time: $(date)"
                echo ""
                echo "=== ACTIVE CONNECTIONS (ss) ==="
                ss -tuln 2>/dev/null || echo "ss command not available"
                echo ""
                echo "=== ESTABLISHED CONNECTIONS ==="
                ss -tn 2>/dev/null || echo "ss command not available"
                echo ""
                echo "=== LISTENING PORTS ==="
                ss -tlnp 2>/dev/null || echo "ss command not available"
                echo ""
                echo "=== ROUTING TABLE ==="
                ip route show 2>/dev/null || route -n 2>/dev/null || echo "Routing info not available"
            } > "$evidence_file"
            ;;
        "running_processes")
            {
                echo "=== RUNNING PROCESSES EVIDENCE ==="
                echo "Incident ID: $incident_id"
                echo "Collection Time: $(date)"
                echo ""
                echo "=== PROCESS TREE ==="
                ps auxf 2>/dev/null || ps aux 2>/dev/null
                echo ""
                echo "=== TOP PROCESSES ==="
                top -b -n 1 2>/dev/null || echo "top command not available"
            } > "$evidence_file"
            ;;
        "incident_details")
            {
                echo "=== INCIDENT DETAILS EVIDENCE ==="
                echo "Incident ID: $incident_id"
                echo "Collection Time: $(date)"
                echo "Description: $description"
                echo ""
                echo "=== ENVIRONMENT VARIABLES ==="
                env | sort
                echo ""
                echo "=== RECENT COMMAND HISTORY ==="
                history | tail -50 2>/dev/null || echo "History not available"
            } > "$evidence_file"
            ;;
        *)
            echo "Unknown evidence type: $evidence_type" > "$evidence_file"
            ;;
    esac
    
    # Calculate hash of evidence file
    if [ -f "$evidence_file" ]; then
        evidence_hash=$(sha256sum "$evidence_file" | awk '{print $1}')
        
        # Record in database
        sqlite3 "$INCIDENT_DATABASE" << EOF
INSERT INTO evidence_collection (incident_id, evidence_type, evidence_path, description, hash_value)
VALUES ('$incident_id', '$evidence_type', '$evidence_file', '$description', '$evidence_hash');
EOF
        
        # Add to timeline
        add_timeline_entry "$incident_id" "evidence_collected" "Type: $evidence_type, File: $evidence_file, Hash: $evidence_hash" true
        
        log_info "Evidence collected: $evidence_file (hash: $evidence_hash)"
        return 0
    else
        log_error "Failed to create evidence file: $evidence_file"
        return 1
    fi
}

# Collect file-specific evidence
collect_file_evidence() {
    local incident_id="$1"
    local file_path="$2"
    
    if [ ! -f "$file_path" ]; then
        log_warning "File not found for evidence collection: $file_path"
        return 1
    fi
    
    local evidence_file="$EVIDENCE_DIR/${incident_id}_file_evidence_$(date +%Y%m%d_%H%M%S).txt"
    local evidence_hash=""
    
    {
        echo "=== FILE EVIDENCE ==="
        echo "Incident ID: $incident_id"
        echo "Collection Time: $(date)"
        echo "File Path: $file_path"
        echo ""
        echo "=== FILE STATISTICS ==="
        stat "$file_path"
        echo ""
        echo "=== FILE HASHES ==="
        echo "MD5: $(md5sum "$file_path" | awk '{print $1}')"
        echo "SHA1: $(sha1sum "$file_path" | awk '{print $1}')"
        echo "SHA256: $(sha256sum "$file_path" | awk '{print $1}')"
        echo ""
        echo "=== FILE PERMISSIONS ==="
        ls -la "$file_path"
        echo ""
        echo "=== FILE CONTENT (first 100 lines) ==="
        head -100 "$file_path" 2>/dev/null || echo "Cannot read file content"
    } > "$evidence_file"
    
    # Calculate hash and record
    if [ -f "$evidence_file" ]; then
        evidence_hash=$(sha256sum "$evidence_file" | awk '{print $1}')
        
        sqlite3 "$INCIDENT_DATABASE" << EOF
INSERT INTO evidence_collection (incident_id, evidence_type, evidence_path, description, hash_value)
VALUES ('$incident_id', 'file_evidence', '$evidence_file', 'File evidence for: $file_path', '$evidence_hash');
EOF
        
        log_info "File evidence collected: $evidence_file"
        return 0
    else
        log_error "Failed to create file evidence: $evidence_file"
        return 1
    fi
}

# Execute admin notification
execute_admin_notification() {
    local incident_id="$1"
    local incident_type="$2"
    local severity="$3"
    
    log_info "Sending admin notification for incident: $incident_id"
    
    # Get incident details
    local incident_details=$(sqlite3 "$INCIDENT_DATABASE" << EOF
SELECT incident_details, timestamp FROM incidents WHERE incident_id = '$incident_id';
EOF
)
    
    # Send notification using common function
    send_notification "🚨 Security Incident: $incident_id" "Type: $incident_type, Severity: $severity, Details: $incident_details" "security-critical" "critical"
    
    # Add to timeline
    add_timeline_entry "$incident_id" "admin_notified" "Administrator notified of incident" true
    
    return 0
}

# Execute monitoring action
execute_monitoring() {
    local incident_id="$1"
    local incident_details="$2"
    
    log_info "Setting up monitoring for incident: $incident_id"
    
    # Create monitoring script
    local monitor_script="$EVIDENCE_DIR/${incident_id}_monitor.sh"
    
    cat > "$monitor_script" << EOF
#!/bin/bash
# Incident monitoring script for $incident_id
# Generated on $(date)

MONITOR_DURATION=3600  # 1 hour
MONITOR_INTERVAL=30    # 30 seconds
END_TIME=\$(date -d "+\$MONITOR_DURATION seconds" +%s)

echo "Starting monitoring for incident $incident_id"
echo "Monitoring duration: \$MONITOR_DURATION seconds"
echo "Monitoring interval: \$MONITOR_INTERVAL seconds"

while [ \$(date +%s) -lt \$END_TIME ]; do
    echo "--- Monitor check at \$(date) ---"
    
    # Check system load
    echo "System load: \$(uptime)"
    
    # Check memory usage
    echo "Memory usage: \$(free -h | grep Mem)"
    
    # Check network connections
    echo "Active connections: \$(ss -tn 2>/dev/null | wc -l)"
    
    # Check for suspicious processes
    echo "Suspicious processes (if any):"
    ps aux | grep -E "(wget|curl|nc|netcat|ssh)" | grep -v grep || echo "None found"
    
    echo ""
    sleep \$MONITOR_INTERVAL
done

echo "Monitoring completed for incident $incident_id"
EOF
    
    chmod +x "$monitor_script"
    
    # Start monitoring in background
    nohup "$monitor_script" > "$EVIDENCE_DIR/${incident_id}_monitor.log" 2>&1 &
    local monitor_pid=$!
    
    # Record monitoring setup
    sqlite3 "$INCIDENT_DATABASE" << EOF
INSERT INTO evidence_collection (incident_id, evidence_type, evidence_path, description, hash_value)
VALUES ('$incident_id', 'monitoring_script', '$monitor_script', 'Monitoring script (PID: $monitor_pid)', '');
EOF
    
    # Add to timeline
    add_timeline_entry "$incident_id" "monitoring_started" "Monitoring started (PID: $monitor_pid)" true
    
    log_info "Monitoring started for incident $incident_id (PID: $monitor_pid)"
    return 0
}

# Rollback incident actions
rollback_incident() {
    local incident_id="$1"
    local reason="${2:-false_positive}"
    
    log_info "Rolling back incident: $incident_id (reason: $reason)"
    
    # Get incident details
    local incident_data=$(sqlite3 "$INCIDENT_DATABASE" << EOF
SELECT rollback_data, false_positive FROM incidents WHERE incident_id = '$incident_id';
EOF
)
    
    if [ -z "$incident_data" ]; then
        log_error "Incident not found: $incident_id"
        return 1
    fi
    
    # Mark as false positive if specified
    if [ "$reason" = "false_positive" ]; then
        sqlite3 "$INCIDENT_DATABASE" << EOF
UPDATE incidents SET false_positive = 1 WHERE incident_id = '$incident_id';
EOF
    fi
    
    # Rollback quarantine actions
    rollback_quarantine "$incident_id"
    
    # Rollback network blocks
    rollback_network_blocks "$incident_id"
    
    # Update incident status
    sqlite3 "$INCIDENT_DATABASE" << EOF
UPDATE incidents 
SET status = 'rolled_back', 
    resolved_timestamp = CURRENT_TIMESTAMP 
WHERE incident_id = '$incident_id';
EOF
    
    # Add to timeline
    add_timeline_entry "$incident_id" "incident_rolled_back" "Incident rolled back (reason: $reason)" true
    
    log_info "Incident rollback completed: $incident_id"
    return 0
}

# Rollback quarantine actions
rollback_quarantine() {
    local incident_id="$1"
    
    # Get quarantined files for this incident
    local quarantined_files=$(sqlite3 "$INCIDENT_DATABASE" << EOF
SELECT original_path, quarantine_path FROM quarantine_log 
WHERE incident_id = '$incident_id' AND restored_timestamp IS NULL;
EOF
)
    
    while IFS='|' read -r original_path quarantine_path; do
        if [ -n "$original_path" ] && [ -n "$quarantine_path" ]; then
            log_info "Restoring quarantined file: $quarantine_path -> $original_path"
            
            if mv "$quarantine_path" "$original_path"; then
                # Update database
                sqlite3 "$INCIDENT_DATABASE" << EOF
UPDATE quarantine_log 
SET restored_timestamp = CURRENT_TIMESTAMP, restored_by = 'rollback'
WHERE incident_id = '$incident_id' AND original_path = '$original_path';
EOF
                
                log_info "File restored successfully: $original_path"
            else
                log_error "Failed to restore file: $quarantine_path"
            fi
        fi
    done <<< "$quarantined_files"
}

# Rollback network blocks
rollback_network_blocks() {
    local incident_id="$1"
    
    # Get blocked IPs for this incident
    local blocked_ips=$(sqlite3 "$INCIDENT_DATABASE" << EOF
SELECT blocked_ip, rule_id FROM network_blocks 
WHERE incident_id = '$incident_id' AND unblocked_timestamp IS NULL;
EOF
)
    
    while IFS='|' read -r blocked_ip rule_id; do
        if [ -n "$blocked_ip" ] && [ -n "$rule_id" ]; then
            log_info "Unblocking IP: $blocked_ip (rule: $rule_id)"
            
            # Remove iptables rules
            if command -v iptables &>/dev/null && command -v sudo_execute &>/dev/null; then
                sudo_execute "iptables -D INPUT -s $blocked_ip -j DROP -m comment --comment '$rule_id'" "unblock_ip_input_$blocked_ip"
                sudo_execute "iptables -D OUTPUT -d $blocked_ip -j DROP -m comment --comment '$rule_id'" "unblock_ip_output_$blocked_ip"
            fi
            
            # Update database
            sqlite3 "$INCIDENT_DATABASE" << EOF
UPDATE network_blocks 
SET unblocked_timestamp = CURRENT_TIMESTAMP, unblocked_by = 'rollback'
WHERE incident_id = '$incident_id' AND blocked_ip = '$blocked_ip';
EOF
            
            log_info "IP unblocked successfully: $blocked_ip"
        fi
    done <<< "$blocked_ips"
}

# Generate incident report
generate_incident_report() {
    local incident_id="$1"
    local output_format="${2:-text}"
    
    log_info "Generating incident report: $incident_id"
    
    # Get incident details
    local incident_details=$(sqlite3 "$INCIDENT_DATABASE" << EOF
SELECT incident_type, incident_details, severity, status, timestamp, actions_taken, false_positive
FROM incidents WHERE incident_id = '$incident_id';
EOF
)
    
    if [ -z "$incident_details" ]; then
        log_error "Incident not found: $incident_id"
        return 1
    fi
    
    # Parse incident details
    IFS='|' read -r incident_type incident_details severity status timestamp actions_taken false_positive <<< "$incident_details"
    
    local report_file="$EVIDENCE_DIR/${incident_id}_report_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=========================================="
        echo "SECURITY INCIDENT REPORT"
        echo "=========================================="
        echo "Incident ID: $incident_id"
        echo "Type: $incident_type"
        echo "Severity: $severity"
        echo "Status: $status"
        echo "Timestamp: $timestamp"
        echo "False Positive: $false_positive"
        echo "Actions Taken: $actions_taken"
        echo ""
        echo "Incident Details:"
        echo "$incident_details"
        echo ""
        echo "=========================================="
        echo "INCIDENT TIMELINE"
        echo "=========================================="
        
        sqlite3 "$INCIDENT_DATABASE" << EOF
SELECT timestamp, action, details, automated 
FROM incident_timeline 
WHERE incident_id = '$incident_id' 
ORDER BY timestamp;
EOF
        
        echo ""
        echo "=========================================="
        echo "QUARANTINE ACTIONS"
        echo "=========================================="
        
        sqlite3 "$INCIDENT_DATABASE" << EOF
SELECT original_path, quarantine_path, file_hash, quarantine_timestamp, restored_timestamp
FROM quarantine_log 
WHERE incident_id = '$incident_id';
EOF
        
        echo ""
        echo "=========================================="
        echo "NETWORK BLOCKS"
        echo "=========================================="
        
        sqlite3 "$INCIDENT_DATABASE" << EOF
SELECT blocked_ip, block_type, block_timestamp, unblocked_timestamp
FROM network_blocks 
WHERE incident_id = '$incident_id';
EOF
        
        echo ""
        echo "=========================================="
        echo "PROCESS ISOLATION"
        echo "=========================================="
        
        sqlite3 "$INCIDENT_DATABASE" << EOF
SELECT process_id, process_name, isolation_method, isolation_timestamp, killed_timestamp
FROM process_isolation 
WHERE incident_id = '$incident_id';
EOF
        
        echo ""
        echo "=========================================="
        echo "EVIDENCE COLLECTION"
        echo "=========================================="
        
        sqlite3 "$INCIDENT_DATABASE" << EOF
SELECT evidence_type, evidence_path, description, hash_value, collection_timestamp
FROM evidence_collection 
WHERE incident_id = '$incident_id';
EOF
        
        echo ""
        echo "=========================================="
        echo "REPORT GENERATED"
        echo "=========================================="
        echo "Generated on: $(date)"
        echo "Generated by: $(whoami)"
        
    } > "$report_file"
    
    log_info "Incident report generated: $report_file"
    echo "$report_file"
}

# List incidents
list_incidents() {
    local filter="${1:-all}"
    
    sqlite3 "$INCIDENT_DATABASE" << EOF
SELECT incident_id, incident_type, severity, status, timestamp, false_positive
FROM incidents 
WHERE '$filter' = 'all' OR severity = '$filter' OR status = '$filter'
ORDER BY timestamp DESC;
EOF
}

# Validate IPv4 address (reuse from threat-intelligence-optimized.sh)
source "$SCRIPT_DIR/threat-intelligence-optimized.sh"

# Export functions for use by other scripts
export -f init_incident_response create_incident_database
export -f automated_response create_incident_record update_incident_actions add_timeline_entry
export -f execute_quarantine_action quarantine_file
export -f execute_process_isolation isolate_process
export -f execute_network_blocking block_network
export -f execute_evidence_collection collect_evidence collect_file_evidence
export -f execute_admin_notification execute_monitoring
export -f rollback_incident rollback_quarantine rollback_network_blocks
export -f generate_incident_report list_incidents
export -f validate_ipv4

# Main execution
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    case "${1:-help}" in
        "init")
            init_incident_response
            ;;
        "response")
            automated_response "$2" "$3" "$4"
            ;;
        "rollback")
            rollback_incident "$2" "$3"
            ;;
        "report")
            generate_incident_report "$2" "$3"
            ;;
        "list")
            list_incidents "$2"
            ;;
        "quarantine")
            quarantine_file "$2" "$3"
            ;;
        "isolate")
            isolate_process "$2" "$3" "$4"
            ;;
        "block")
            block_network "$2" "$3"
            ;;
        "collect")
            collect_evidence "$2" "$3" "$4"
            ;;
        *)
            echo "Usage: $0 {init|response <type> <details> <severity>|rollback <incident_id> [reason]|report <incident_id> [format]|list [filter]|quarantine <incident_id> <file_path>|isolate <incident_id> <process_id> <process_name>|block <incident_id> <ip_address>|collect <incident_id> <type> <description>}"
            exit 1
            ;;
    esac
fi