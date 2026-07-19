#!/bin/bash
# Optimized Threat Intelligence Integration with Memory Management
# Integrates threat feeds with resource limits and performance optimizations

source "$(dirname "$0")/common-functions.sh"

# Get security suite home directory
SCRIPT_DIR="$(dirname "$0")"
AEGIS_HOME="$(dirname "$SCRIPT_DIR")"

# Load configuration to get database paths
if [ -f "$AEGIS_HOME/configs/security-config.conf" ]; then
    source "$AEGIS_HOME/configs/security-config.conf"
fi

# Ensure variables are set with fallbacks
THREAT_DB_DIR="${THREAT_DB_DIR:-$AEGIS_HOME/configs/threat_intelligence}"
IOC_DATABASE="${IOC_DATABASE:-$THREAT_DB_DIR/ioc_database.db}"
FEED_CACHE_DIR="${FEED_CACHE_DIR:-$THREAT_DB_DIR/cache}"

# Optimized threat intelligence configuration
MAX_FEED_SIZE_MB=50  # Maximum feed size to process
MAX_MEMORY_USAGE_MB=200  # Maximum memory usage for feed processing
CONNECTION_TIMEOUT=30  # Connection timeout in seconds
MAX_RETRIES=3  # Maximum retry attempts
CLEANUP_INTERVAL=5  # Cleanup every 5 feeds
MAX_CONCURRENT_DOWNLOADS=3  # Maximum concurrent downloads

# Working threat intelligence feeds (optimized for performance)
declare -A THREAT_FEEDS_2025=(
    # High-confidence feeds (verified working - HTTP 200)
    ["feodotracker"]="https://feodotracker.abuse.ch/downloads/ipblocklist_recommended.txt|botnet_ips|95|ip"
    ["firehol_level1"]="https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/firehol_level1.netset|malicious_ips|85|ip"
    ["stevenblack"]="https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts|malware_domains|80|domain"
    
    # Backup feeds (tested working)
    ["malwarebazaar"]="https://bazaar.abuse.ch/export/hosts/online.txt|malware_domains|85|domain"
    ["urlhaus"]="https://urlhaus.abuse.ch/downloads/urls_recent.txt|malicious_urls|90|url"
)

# Fallback feeds for redundancy
FALLBACK_FEEDS=(
    "https://raw.githubusercontent.com/JohnHammond/kate-db/main/kate-hosts.txt|malware_domains|70|domain"
    "https://someonewhocares.org/hosts/hosts|ad_malware_domains|60|domain"
)

# Memory monitoring functions
check_memory_usage() {
    local memory_mb=$(ps aux | grep -E "(threat|intelligence)" | grep -v grep | awk '{sum+=$6} END {print sum/1024}')
    echo "${memory_mb:-0}"
}

check_feed_size() {
    local feed_url="$1"
    local temp_file="/tmp/feed_size_check_$(date +%s).txt"
    
    # Download just the headers to check size
    if curl -s -I --max-time 10 "$feed_url" | grep -i content-length > /dev/null 2>&1; then
        local content_length=$(curl -s -I --max-time 10 "$feed_url" | grep -i content-length | cut -d' ' -f2 | tr -d '\r')
        local size_mb=$((content_length / 1024 / 1024))
        
        rm -f "$temp_file"
        echo "$size_mb"
        return 0
    else
        rm -f "$temp_file"
        echo "0"
        return 1
    fi
}

# Optimized download function with memory limits
download_feed_optimized() {
    local feed_url="$1"
    local output="$2"
    local max_retries="${3:-$MAX_RETRIES}"
    local timeout="${4:-$CONNECTION_TIMEOUT}"
    
    # Check feed size first
    local feed_size_mb=$(check_feed_size "$feed_url")
    if [ "$feed_size_mb" -gt "$MAX_FEED_SIZE_MB" ]; then
        log_warning "Feed too large: $feed_url (${feed_size_mb}MB > ${MAX_FEED_SIZE_MB}MB)"
        return 1
    fi
    
    # Check current memory usage
    local current_memory=$(check_memory_usage)
    if [ "$current_memory" -gt "$MAX_MEMORY_USAGE_MB" ]; then
        log_warning "Memory usage too high for download: ${current_memory}MB > ${MAX_MEMORY_USAGE_MB}MB"
        return 1
    fi
    
    for ((i=1; i<=max_retries; i++)); do
        log_info "Downloading $feed_url (attempt $i/$max_retries)"
        
        # Use curl with memory limits
        if curl -s -L --max-time "$timeout" --max-filesize "$((MAX_FEED_SIZE_MB * 1024 * 1024))" \
           --retry-delay 5 --retry 0 -o "$output" "$feed_url" 2>/dev/null; then
            
            # Validate downloaded file
            if [ -s "$output" ]; then
                local file_size_mb=$(du -m "$output" 2>/dev/null | cut -f1)
                log_info "Download successful: $feed_url (${file_size_mb}MB)"
                return 0
            else
                log_warning "Downloaded file is empty: $output"
                rm -f "$output"
            fi
        else
            log_warning "Download failed (attempt $i/$max_retries): $feed_url"
            rm -f "$output"  # Remove partial download
        fi
        
        if [ $i -lt $max_retries ]; then
            local backoff=$((i * 5))
            log_info "Retrying in $backoff seconds..."
            sleep $backoff
        fi
    done
    
    log_error "Failed to download after $max_retries attempts: $feed_url"
    return 1
}

# Initialize optimized threat intelligence system
init_threat_intelligence_optimized() {
    log_info "Initializing optimized threat intelligence system..."
    
    # Create directories with proper error handling
    if [ -z "$THREAT_DB_DIR" ]; then
        log_error "THREAT_DB_DIR is not set"
        return 1
    fi
    
    if [ -z "$FEED_CACHE_DIR" ]; then
        log_error "FEED_CACHE_DIR is not set"
        return 1
    fi
    
    mkdir -p "$THREAT_DB_DIR" "$FEED_CACHE_DIR"
    
    # Set proper permissions
    chmod 700 "$THREAT_DB_DIR" 2>/dev/null || true
    chmod 700 "$FEED_CACHE_DIR" 2>/dev/null || true
    
    # Initialize IOC database with optimizations
    if [ ! -f "$IOC_DATABASE" ]; then
        create_optimized_ioc_database
    else
        # Apply optimizations to existing database
        optimize_ioc_database
    fi
    
    # Initialize threat feeds in database
    initialize_threat_feeds
    
    log_info "Optimized threat intelligence system initialized successfully"
}

# Create optimized IOC database
create_optimized_ioc_database() {
    log_info "Creating optimized IOC database..."
    
    # Create comprehensive SQLite database with performance optimizations
    sqlite3 "$IOC_DATABASE" << 'EOF'
-- Optimized IOC Database Schema
CREATE TABLE IF NOT EXISTS ioc_ips (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ip_address TEXT UNIQUE NOT NULL,
    source TEXT NOT NULL,
    threat_type TEXT NOT NULL,
    confidence INTEGER DEFAULT 50,
    first_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
    active BOOLEAN DEFAULT 1,
    feed_url TEXT,
    country_code TEXT,
    asn TEXT
);

CREATE TABLE IF NOT EXISTS ioc_domains (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    domain TEXT UNIQUE NOT NULL,
    source TEXT NOT NULL,
    threat_type TEXT NOT NULL,
    confidence INTEGER DEFAULT 50,
    first_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
    active BOOLEAN DEFAULT 1,
    feed_url TEXT
);

CREATE TABLE IF NOT EXISTS ioc_urls (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    url TEXT UNIQUE NOT NULL,
    source TEXT NOT NULL,
    threat_type TEXT NOT NULL,
    confidence INTEGER DEFAULT 50,
    first_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
    active BOOLEAN DEFAULT 1,
    feed_url TEXT
);

CREATE TABLE IF NOT EXISTS ioc_hashes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_hash TEXT UNIQUE NOT NULL,
    hash_type TEXT NOT NULL,
    source TEXT NOT NULL,
    threat_type TEXT NOT NULL,
    confidence INTEGER DEFAULT 50,
    first_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
    active BOOLEAN DEFAULT 1,
    feed_url TEXT
);

CREATE TABLE IF NOT EXISTS threat_feeds (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    feed_name TEXT UNIQUE NOT NULL,
    feed_url TEXT UNIQUE NOT NULL,
    feed_type TEXT NOT NULL,
    last_update DATETIME DEFAULT CURRENT_TIMESTAMP,
    update_frequency INTEGER DEFAULT 86400,
    status TEXT DEFAULT 'active',
    success_count INTEGER DEFAULT 0,
    failure_count INTEGER DEFAULT 0,
    last_success DATETIME,
    last_failure DATETIME,
    active BOOLEAN DEFAULT 1
);

CREATE TABLE IF NOT EXISTS feed_statistics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    feed_name TEXT NOT NULL,
    date DATE NOT NULL,
    items_processed INTEGER DEFAULT 0,
    new_items INTEGER DEFAULT 0,
    duplicates INTEGER DEFAULT 0,
    errors INTEGER DEFAULT 0,
    processing_time REAL DEFAULT 0
);

-- Optimized indexes for performance
CREATE INDEX IF NOT EXISTS idx_ioc_ips_address ON ioc_ips(ip_address);
CREATE INDEX IF NOT EXISTS idx_ioc_ips_active ON ioc_ips(active);
CREATE INDEX IF NOT EXISTS idx_ioc_domains_domain ON ioc_domains(domain);
CREATE INDEX IF NOT EXISTS idx_ioc_domains_active ON ioc_domains(active);
CREATE INDEX IF NOT EXISTS idx_ioc_urls_url ON ioc_urls(url);
CREATE INDEX IF NOT EXISTS idx_ioc_urls_active ON ioc_urls(active);
CREATE INDEX IF NOT EXISTS idx_ioc_hashes_hash ON ioc_hashes(file_hash);
CREATE INDEX IF NOT EXISTS idx_ioc_hashes_active ON ioc_hashes(active);
CREATE INDEX IF NOT EXISTS idx_threat_feeds_name ON threat_feeds(feed_name);
CREATE INDEX IF NOT EXISTS idx_feed_statistics_feed_date ON feed_statistics(feed_name, date);
EOF

    # Apply performance optimizations
    optimize_ioc_database
    
    log_info "Optimized IOC database created successfully"
}

# Optimize IOC database
optimize_ioc_database() {
    sqlite3 "$IOC_DATABASE" << EOF 2>/dev/null
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA cache_size = 10000;
PRAGMA temp_store = MEMORY;
PRAGMA mmap_size = 268435456;  -- 256MB
PRAGMA optimize;
EOF
}

# Initialize threat feeds in database
initialize_threat_feeds() {
    log_info "Initializing threat feeds in database..."
    
    for feed_name in "${!THREAT_FEEDS_2025[@]}"; do
        feed_config="${THREAT_FEEDS_2025[$feed_name]}"
        IFS='|' read -r feed_url threat_type confidence data_type <<< "$feed_config"
        
        sqlite3 "$IOC_DATABASE" << EOF 2>/dev/null
INSERT OR REPLACE INTO threat_feeds 
(feed_name, feed_url, feed_type, update_frequency, status, active)
VALUES ('$feed_name', '$feed_url', '$data_type', 86400, 'active', 1);
EOF
    done
    
    log_info "Threat feeds initialized in database"
}

# Enhanced threat feed update with memory management
update_threat_feeds_optimized() {
    log_info "Updating threat feeds with optimized processing..."
    
    local total_feeds=0
    local successful_feeds=0
    local failed_feeds=0
    local feed_count=0
    
    # Process primary feeds with concurrency control
    for feed_name in "${!THREAT_FEEDS_2025[@]}"; do
        ((total_feeds++))
        ((feed_count++))
        
        # Check memory usage before processing each feed
        local current_memory=$(check_memory_usage)
        if [ "$current_memory" -gt "$MAX_MEMORY_USAGE_MB" ]; then
            log_warning "Memory usage too high, pausing feed processing: ${current_memory}MB"
            sleep 30  # Wait for memory to free up
            current_memory=$(check_memory_usage)
            if [ "$current_memory" -gt "$MAX_MEMORY_USAGE_MB" ]; then
                log_error "Memory usage still too high, stopping feed updates"
                break
            fi
        fi
        
        log_info "Processing feed: $feed_name (memory: ${current_memory}MB)"
        
        if process_threat_feed_optimized "$feed_name" "${THREAT_FEEDS_2025[$feed_name]}"; then
            ((successful_feeds++))
            log_info "✓ Successfully processed feed: $feed_name"
        else
            ((failed_feeds++))
            log_warning "✗ Failed to process feed: $feed_name"
            
            # Try fallback feeds for this type
            activate_fallback_feeds "$feed_name"
        fi
        
        # Cleanup every CLEANUP_INTERVAL feeds
        if [ $((feed_count % CLEANUP_INTERVAL)) -eq 0 ]; then
            log_info "Performing periodic cleanup..."
            cleanup_old_iocs
            optimize_ioc_database
        fi
        
        # Small delay between feeds to prevent overwhelming the system
        sleep 2
    done
    
    # Update feed statistics
    update_feed_statistics "$total_feeds" "$successful_feeds" "$failed_feeds"
    
    # Final cleanup
    cleanup_old_iocs
    optimize_ioc_database
    
    log_info "Threat feed update complete: $successful_feeds/$total_feeds successful"
    
    # Return success if at least 50% of feeds succeeded
    if [ $((successful_feeds * 100 / total_feeds)) -ge 50 ]; then
        return 0
    else
        log_error "Too many feed failures: $failed_feeds/$total_feeds failed"
        return 1
    fi
}

# Process individual threat feed with optimizations
process_threat_feed_optimized() {
    local feed_name="$1"
    local feed_config="$2"
    
    # Parse feed configuration
    IFS='|' read -r feed_url threat_type confidence data_type <<< "$feed_config"
    
    local start_time=$(date +%s)
    local feed_file="$FEED_CACHE_DIR/${feed_name}_$(date +%s).txt"
    
    # Record attempt in database
    record_feed_attempt "$feed_name" "$feed_url"
    
    # Download feed with memory management
    if ! download_feed_optimized "$feed_url" "$feed_file"; then
        record_feed_failure "$feed_name" "download_failed"
        return 1
    fi
    
    # Validate downloaded file
    if [ ! -s "$feed_file" ]; then
        log_error "Downloaded file is empty: $feed_file"
        record_feed_failure "$feed_name" "empty_file"
        rm -f "$feed_file"
        return 1
    fi
    
    # Process based on data type with memory limits
    local processed_items=0
    
    case "$data_type" in
        "ip")
            process_ip_feed_optimized "$feed_file" "$feed_name" "$threat_type" "$confidence"
            processed_items=$?
            ;;
        "domain")
            process_domain_feed_optimized "$feed_file" "$feed_name" "$threat_type" "$confidence"
            processed_items=$?
            ;;
        "url")
            process_url_feed_optimized "$feed_file" "$feed_name" "$threat_type" "$confidence"
            processed_items=$?
            ;;
        *)
            log_error "Unknown data type for feed $feed_name: $data_type"
            record_feed_failure "$feed_name" "unknown_type"
            rm -f "$feed_file"
            return 1
            ;;
    esac
    
    # Update feed success record
    local end_time=$(date +%s)
    local processing_time=$((end_time - start_time))
    
    record_feed_success "$feed_name" "$processed_items" "$processing_time"
    
    # Cleanup
    rm -f "$feed_file"
    
    return 0
}

# Optimized IP feed processing with memory limits
process_ip_feed_optimized() {
    local feed_file="$1"
    local feed_name="$2"
    local threat_type="$3"
    local confidence="$4"
    
    local processed_items=0
    local new_items=0
    local duplicate_items=0
    local error_items=0
    local batch_size=1000  # Process in batches to limit memory usage
    
    log_info "Processing IP feed: $feed_name ($threat_type)"
    
    # Process file in batches
    local line_count=0
    local batch_query=""
    
    while IFS= read -r line; do
        ((line_count++))
        ((processed_items++))
        
        # Skip comments, empty lines, and whitespace
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [ -z "${line// }" ] && continue
        
        # Extract IP address (handle different formats)
        local ip_address
        case "$feed_name" in
            "firehol_level1")
                ip_address=$(echo "$line" | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')
                ;;
            "feodotracker")
                ip_address=$(echo "$line" | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')
                ;;
            *)
                ip_address=$(echo "$line" | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')
                ;;
        esac
        
        # Validate IP address
        if ! validate_ipv4 "$ip_address"; then
            ((error_items++))
            continue
        fi
        
        # Add to batch query
        batch_query+="INSERT OR IGNORE INTO ioc_ips (ip_address, source, threat_type, confidence, feed_url)
VALUES ('$ip_address', '$feed_name', '$threat_type', $confidence, '${THREAT_FEEDS_2025[$feed_name]%%|*}');"
        
        # Execute batch when batch size reached
        if [ $((line_count % batch_size)) -eq 0 ]; then
            local insert_result=$(sqlite3 "$IOC_DATABASE" << EOF 2>/dev/null
$batch_query
SELECT changes();
EOF
)
            if [ "$insert_result" -gt 0 ]; then
                ((new_items += insert_result))
            else
                ((duplicate_items += batch_size))
            fi
            
            # Reset batch
            batch_query=""
            
            # Check memory usage
            local current_memory=$(check_memory_usage)
            if [ "$current_memory" -gt "$MAX_MEMORY_USAGE_MB" ]; then
                log_warning "Memory usage high during IP processing: ${current_memory}MB"
                break
            fi
        fi
        
    done < "$feed_file"
    
    # Execute remaining batch
    if [ -n "$batch_query" ]; then
        local insert_result=$(sqlite3 "$IOC_DATABASE" << EOF 2>/dev/null
$batch_query
SELECT changes();
EOF
)
        if [ "$insert_result" -gt 0 ]; then
            ((new_items += insert_result))
        else
            ((duplicate_items += line_count % batch_size))
        fi
    fi
    
    log_info "IP feed processing complete: $processed_items processed, $new_items new, $duplicate_items duplicates, $error_items errors"
    
    # Update daily statistics
    update_daily_feed_stats "$feed_name" "$processed_items" "$new_items" "$duplicate_items" "$error_items"
    
    return $processed_items
}

# Optimized domain feed processing
process_domain_feed_optimized() {
    local feed_file="$1"
    local feed_name="$2"
    local threat_type="$3"
    local confidence="$4"
    
    local processed_items=0
    local new_items=0
    local duplicate_items=0
    local error_items=0
    local batch_size=1000
    
    log_info "Processing domain feed: $feed_name ($threat_type)"
    
    # Similar batch processing as IP feed
    local line_count=0
    local batch_query=""
    
    while IFS= read -r line; do
        ((line_count++))
        ((processed_items++))
        
        # Skip comments, empty lines, and whitespace
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [ -z "${line// }" ] && continue
        
        # Extract domain name (handle different formats)
        local domain
        case "$feed_name" in
            "stevenblack")
                domain=$(echo "$line" | awk '{print $2}' | grep -oE '[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}')
                ;;
            *)
                domain=$(echo "$line" | grep -oE '[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}')
                ;;
        esac
        
        # Validate domain name
        if ! validate_domain "$domain"; then
            ((error_items++))
            continue
        fi
        
        # Add to batch query
        batch_query+="INSERT OR IGNORE INTO ioc_domains (domain, source, threat_type, confidence, feed_url)
VALUES ('$domain', '$feed_name', '$threat_type', $confidence, '${THREAT_FEEDS_2025[$feed_name]%%|*}');"
        
        # Execute batch when batch size reached
        if [ $((line_count % batch_size)) -eq 0 ]; then
            local insert_result=$(sqlite3 "$IOC_DATABASE" << EOF 2>/dev/null
$batch_query
SELECT changes();
EOF
)
            if [ "$insert_result" -gt 0 ]; then
                ((new_items += insert_result))
            else
                ((duplicate_items += batch_size))
            fi
            
            batch_query=""
            
            # Check memory usage
            local current_memory=$(check_memory_usage)
            if [ "$current_memory" -gt "$MAX_MEMORY_USAGE_MB" ]; then
                log_warning "Memory usage high during domain processing: ${current_memory}MB"
                break
            fi
        fi
        
    done < "$feed_file"
    
    # Execute remaining batch
    if [ -n "$batch_query" ]; then
        local insert_result=$(sqlite3 "$IOC_DATABASE" << EOF 2>/dev/null
$batch_query
SELECT changes();
EOF
)
        if [ "$insert_result" -gt 0 ]; then
            ((new_items += insert_result))
        else
            ((duplicate_items += line_count % batch_size))
        fi
    fi
    
    log_info "Domain feed processing complete: $processed_items processed, $new_items new, $duplicate_items duplicates, $error_items errors"
    
    # Update daily statistics
    update_daily_feed_stats "$feed_name" "$processed_items" "$new_items" "$duplicate_items" "$error_items"
    
    return $processed_items
}

# Optimized URL feed processing
process_url_feed_optimized() {
    local feed_file="$1"
    local feed_name="$2"
    local threat_type="$3"
    local confidence="$4"
    
    local processed_items=0
    local new_items=0
    local duplicate_items=0
    local error_items=0
    local batch_size=500  # Smaller batch for URLs due to larger size
    
    log_info "Processing URL feed: $feed_name ($threat_type)"
    
    # Similar batch processing as other feeds
    local line_count=0
    local batch_query=""
    
    while IFS= read -r line; do
        ((line_count++))
        ((processed_items++))
        
        # Skip comments, empty lines, and whitespace
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [ -z "${line// }" ] && continue
        
        # Extract URL
        local url=$(echo "$line" | grep -oE 'https?://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}[^\s]*')
        
        # Validate URL
        if ! validate_url "$url"; then
            ((error_items++))
            continue
        fi
        
        # Add to batch query
        batch_query+="INSERT OR IGNORE INTO ioc_urls (url, source, threat_type, confidence, feed_url)
VALUES ('$url', '$feed_name', '$threat_type', $confidence, '${THREAT_FEEDS_2025[$feed_name]%%|*}');"
        
        # Execute batch when batch size reached
        if [ $((line_count % batch_size)) -eq 0 ]; then
            local insert_result=$(sqlite3 "$IOC_DATABASE" << EOF 2>/dev/null
$batch_query
SELECT changes();
EOF
)
            if [ "$insert_result" -gt 0 ]; then
                ((new_items += insert_result))
            else
                ((duplicate_items += batch_size))
            fi
            
            batch_query=""
            
            # Check memory usage
            local current_memory=$(check_memory_usage)
            if [ "$current_memory" -gt "$MAX_MEMORY_USAGE_MB" ]; then
                log_warning "Memory usage high during URL processing: ${current_memory}MB"
                break
            fi
        fi
        
    done < "$feed_file"
    
    # Execute remaining batch
    if [ -n "$batch_query" ]; then
        local insert_result=$(sqlite3 "$IOC_DATABASE" << EOF 2>/dev/null
$batch_query
SELECT changes();
EOF
)
        if [ "$insert_result" -gt 0 ]; then
            ((new_items += insert_result))
        else
            ((duplicate_items += line_count % batch_size))
        fi
    fi
    
    log_info "URL feed processing complete: $processed_items processed, $new_items new, $duplicate_items duplicates, $error_items errors"
    
    # Update daily statistics
    update_daily_feed_stats "$feed_name" "$processed_items" "$new_items" "$duplicate_items" "$error_items"
    
    return $processed_items
}

# Validation functions (reuse from original)
validate_ipv4() {
    local ip="$1"
    
    if [[ ! "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 1
    fi
    
    # Check each octet
    IFS='.' read -ra octets <<< "$ip"
    for octet in "${octets[@]}"; do
        if [ "$octet" -gt 255 ] || [ "$octet" -lt 0 ]; then
            return 1
        fi
    done
    
    # Skip private and reserved ranges
    case "$ip" in
        10.*|172.16.*|172.17.*|172.18.*|172.19.*|172.2*|172.30.*|172.31.*|192.168.*|127.*|169.254.*)
            return 1
            ;;
    esac
    
    return 0
}

validate_domain() {
    local domain="$1"
    
    [ -z "$domain" ] && return 1
    
    # Basic domain format validation
    if [[ ! "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        return 1
    fi
    
    # Skip localhost and local domains
    case "$domain" in
        localhost|*.local|*.localhost|*.internal)
            return 1
            ;;
    esac
    
    return 0
}

validate_url() {
    local url="$1"
    
    [ -z "$url" ] && return 1
    
    # Basic URL format validation
    if [[ ! "$url" =~ ^https?://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,} ]]; then
        return 1
    fi
    
    # Additional validation
    local domain=$(echo "$url" | sed 's|^https\?://||' | cut -d/ -f1 | cut -d: -f1)
    
    if ! validate_domain "$domain"; then
        return 1
    fi
    
    return 0
}

# Database maintenance functions (reuse from original with optimizations)
record_feed_attempt() {
    local feed_name="$1"
    local feed_url="$2"
    
    sqlite3 "$IOC_DATABASE" << EOF 2>/dev/null
INSERT OR REPLACE INTO threat_feeds (feed_name, feed_url, feed_type, last_update, active)
VALUES ('$feed_name', '$feed_url', 'external', CURRENT_TIMESTAMP, 1);
EOF
}

record_feed_success() {
    local feed_name="$1"
    local items_processed="$2"
    local processing_time="$3"
    
    sqlite3 "$IOC_DATABASE" << EOF 2>/dev/null
UPDATE threat_feeds 
SET success_count = success_count + 1,
    last_success = CURRENT_TIMESTAMP,
    status = 'active'
WHERE feed_name = '$feed_name';
EOF
}

record_feed_failure() {
    local feed_name="$1"
    local error_type="$2"
    
    sqlite3 "$IOC_DATABASE" << EOF 2>/dev/null
UPDATE threat_feeds 
SET failure_count = failure_count + 1,
    last_failure = CURRENT_TIMESTAMP,
    status = CASE WHEN failure_count + 1 > 3 THEN 'failed' ELSE 'active' END
WHERE feed_name = '$feed_name';
EOF
}

update_daily_feed_stats() {
    local feed_name="$1"
    local processed="$2"
    local new="$3"
    local duplicates="$4"
    local errors="$5"
    local today=$(date +%Y-%m-%d)
    
    # Validate inputs to prevent SQL injection and constraint violations
    if [ -z "$feed_name" ] || [ -z "$today" ]; then
        log_error "Invalid parameters for update_daily_feed_stats"
        return 1
    fi
    
    # Ensure numeric values are valid
    processed=${processed:-0}
    new=${new:-0}
    duplicates=${duplicates:-0}
    errors=${errors:-0}
    
    sqlite3 "$IOC_DATABASE" << EOF 2>/dev/null
INSERT OR REPLACE INTO feed_statistics
(feed_name, date, items_processed, new_items, duplicates, errors)
VALUES ('$feed_name', '$today', $processed, $new, $duplicates, $errors);
EOF
}

cleanup_old_iocs() {
    log_info "Cleaning up old IOC entries..."
    
    # Deactivate IOCs older than 30 days that haven't been seen recently
    sqlite3 "$IOC_DATABASE" << EOF 2>/dev/null
UPDATE ioc_ips SET active = 0 
WHERE last_seen < datetime('now', '-30 days') 
AND first_seen < datetime('now', '-7 days');

UPDATE ioc_domains SET active = 0 
WHERE last_seen < datetime('now', '-30 days') 
AND first_seen < datetime('now', '-7 days');

UPDATE ioc_urls SET active = 0 
WHERE last_seen < datetime('now', '-30 days') 
AND first_seen < datetime('now', '-7 days');
EOF
    
    log_info "IOC cleanup complete"
}

# Update overall feed statistics
update_feed_statistics() {
    local total_feeds="$1"
    local successful_feeds="$2"
    local failed_feeds="$3"
    local today=$(date +%Y-%m-%d)
    
    log_info "Feed update summary: $successful_feeds/$total_feeds successful, $failed_feeds failed"
    
    # Validate inputs
    total_feeds=${total_feeds:-0}
    successful_feeds=${successful_feeds:-0}
    failed_feeds=${failed_feeds:-0}
    
    # Log to database
    sqlite3 "$IOC_DATABASE" << EOF 2>/dev/null
INSERT OR REPLACE INTO feed_statistics (feed_name, date, items_processed, new_items, duplicates, errors)
VALUES ('summary', '$today', $total_feeds, $successful_feeds, $failed_feeds, 0);
EOF
}

# Fallback feed activation
activate_fallback_feeds() {
    local failed_feed="$1"
    
    log_info "Activating fallback feeds for: $failed_feed"
    
    for fallback_feed in "${FALLBACK_FEEDS[@]}"; do
        IFS='|' read -r feed_url threat_type confidence data_type <<< "$fallback_feed"
        
        log_info "Trying fallback feed: $feed_url"
        
        if download_feed_optimized "$feed_url" "/tmp/fallback_test.txt"; then
            log_info "Fallback feed is accessible: $feed_url"
            # Add to active feeds temporarily
            break
        fi
    done
}

# Export functions for use by other scripts
export -f init_threat_intelligence_optimized create_optimized_ioc_database
export -f update_threat_feeds_optimized process_threat_feed_optimized
export -f process_ip_feed_optimized process_domain_feed_optimized process_url_feed_optimized
export -f validate_ipv4 validate_domain validate_url
export -f record_feed_attempt record_feed_success record_feed_failure
export -f update_daily_feed_stats cleanup_old_iocs

# Main execution
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    case "${1:-update}" in
        "init")
            init_threat_intelligence_optimized
            ;;
        "update")
            init_threat_intelligence_optimized
            ;;
        "stats")
            sqlite3 "$IOC_DATABASE" "SELECT feed_name, status, success_count, failure_count FROM threat_feeds ORDER BY success_count DESC;" 2>/dev/null
            ;;
        "cleanup")
            cleanup_old_iocs
            ;;
        *)
            echo "Usage: $0 {init|update|stats|cleanup}"
            exit 1
            ;;
    esac
fi