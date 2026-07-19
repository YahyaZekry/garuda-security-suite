#!/bin/bash
# Performance Testing Script for Optimized Aegis Security Suite
# Tests memory usage, performance, and resource limits

source "$(dirname "$0")/common-functions.sh"

# Get security suite home directory
SCRIPT_DIR="$(dirname "$0")"
AEGIS_HOME="$(dirname "$SCRIPT_DIR")"

# Performance test configuration
TEST_DURATION=300  # 5 minutes
MEMORY_SAMPLE_INTERVAL=10  # seconds
CPU_SAMPLE_INTERVAL=5   # seconds
MAX_ACCEPTABLE_MEMORY_MB=1000  # 1GB
MAX_ACCEPTABLE_CPU_PERCENT=80
TEST_LOG="$AEGIS_HOME/logs/performance-test-$(date +%Y%m%d_%H%M%S).log"

# Test results
declare -A MEMORY_SAMPLES
declare -A CPU_SAMPLES
declare -A PROCESS_SAMPLES

# Initialize performance test
init_performance_test() {
    log_info "Initializing performance test..."
    
    # Create logs directory
    mkdir -p "$AEGIS_HOME/logs"
    
    # Initialize test log
    {
        echo "Aegis Security Suite Performance Test"
        echo "=================================="
        echo "Test Started: $(date)"
        echo "Test Duration: ${TEST_DURATION}s"
        echo "Max Acceptable Memory: ${MAX_ACCEPTABLE_MEMORY_MB}MB"
        echo "Max Acceptable CPU: ${MAX_ACCEPTABLE_CPU_PERCENT}%"
        echo ""
    } > "$TEST_LOG"
    
    log_info "Performance test initialized - Log: $TEST_LOG"
}

# Get system memory usage
get_memory_usage() {
    local memory_mb=$(free -m | grep "Mem:" | awk '{print $3}')
    local memory_total=$(free -m | grep "Mem:" | awk '{print $2}')
    local memory_percent=$((memory_mb * 100 / memory_total))
    
    # Ensure we have valid numbers
    memory_mb=${memory_mb:-0}
    memory_percent=${memory_percent:-0}
    
    echo "${memory_mb}:${memory_percent}"
}

# Get system CPU usage
get_cpu_usage() {
    local cpu_percent=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    echo "${cpu_percent}"
}

# Get process information
get_process_info() {
    local process_name="$1"
    local process_info=$(ps aux | grep "$process_name" | grep -v grep | head -1)
    
    if [ -n "$process_info" ]; then
        local pid=$(echo "$process_info" | awk '{print $2}')
        local cpu=$(echo "$process_info" | awk '{print $3}')
        local mem_kb=$(echo "$process_info" | awk '{print $6}')
        local mem_mb=$(echo "scale=2; $mem_kb / 1024" | bc -l 2>/dev/null || echo "0")
        local rss=$mem_kb
        
        echo "${pid}:${cpu}:${mem_mb}:${rss}"
    else
        echo "0:0:0:0"
    fi
}

# Test behavioral monitoring performance
test_behavioral_monitoring() {
    log_info "Testing behavioral monitoring performance..."
    
    echo "=== Behavioral Monitoring Performance Test ===" >> "$TEST_LOG"
    echo "Test Started: $(date)" >> "$TEST_LOG"
    
    # Start optimized behavioral monitoring
    local monitor_log="$AEGIS_HOME/logs/behavioral-test-$(date +%Y%m%d_%H%M%S).log"
    "$SCRIPT_DIR/behavioral-monitor-optimized.sh" 300 30 > "$monitor_log" 2>&1 &
    local monitor_pid=$!
    
    # Monitor for test duration
    local test_start=$(date +%s)
    local max_memory=0
    local max_cpu=0
    
    while [ $(($(date +%s) - test_start)) -lt $TEST_DURATION ]; do
        # Get memory usage
        local memory_info=$(get_memory_usage)
        local memory_mb=$(echo "$memory_info" | cut -d: -f1)
        local memory_percent=$(echo "$memory_info" | cut -d: -f2)
        
        # Get CPU usage
        local cpu_percent=$(get_cpu_usage)
        
        # Get process info
        local process_info=$(get_process_info "behavioral-monitor-optimized")
        local process_cpu=$(echo "$process_info" | cut -d: -f2)
        local process_mem_mb=$(echo "$process_info" | cut -d: -f3)
        
        # Track maximums
        if [ "$memory_mb" -gt "$max_memory" ]; then
            max_memory=$memory_mb
        fi
        
        # Use bc for decimal comparison
        if [ "$(echo "$cpu_percent > $max_cpu" | bc -l 2>/dev/null || echo 0)" -eq 1 ]; then
            max_cpu=$cpu_percent
        fi
        
        # Log sample with proper formatting
        echo "$(date): Memory=${memory_mb}MB (${memory_percent}%), CPU=${cpu_percent}%, Process=${process_mem_mb}MB (${process_cpu}%)" >> "$TEST_LOG"
        
        # Check thresholds
        if [ "$memory_mb" -gt "$MAX_ACCEPTABLE_MEMORY_MB" ]; then
            echo "$(date): WARNING - Memory usage exceeded threshold: ${memory_mb}MB > ${MAX_ACCEPTABLE_MEMORY_MB}MB" >> "$TEST_LOG"
        fi
        
        # Use bc for decimal comparison
        if [ "$(echo "$cpu_percent > $MAX_ACCEPTABLE_CPU_PERCENT" | bc -l 2>/dev/null || echo 0)" -eq 1 ]; then
            echo "$(date): WARNING - CPU usage exceeded threshold: ${cpu_percent}% > ${MAX_ACCEPTABLE_CPU_PERCENT}%" >> "$TEST_LOG"
        fi
        
        sleep $MEMORY_SAMPLE_INTERVAL
    done
    
    # Stop behavioral monitoring
    kill $monitor_pid 2>/dev/null || true
    wait $monitor_pid 2>/dev/null || true
    
    # Log results
    echo "Behavioral Monitoring Test Results:" >> "$TEST_LOG"
    echo "Maximum Memory Usage: ${max_memory}MB" >> "$TEST_LOG"
    echo "Maximum CPU Usage: ${max_cpu}%" >> "$TEST_LOG"
    echo "Test Completed: $(date)" >> "$TEST_LOG"
    echo "" >> "$TEST_LOG"
    
    log_info "Behavioral monitoring test completed - Max Memory: ${max_memory}MB, Max CPU: ${max_cpu}%"
}

# Test threat intelligence performance
test_threat_intelligence() {
    log_info "Testing threat intelligence performance..."
    
    echo "=== Threat Intelligence Performance Test ===" >> "$TEST_LOG"
    echo "Test Started: $(date)" >> "$TEST_LOG"
    
    # Start optimized threat intelligence update
    local threat_log="$AEGIS_HOME/logs/threat-test-$(date +%Y%m%d_%H%M%S).log"
    "$SCRIPT_DIR/threat-intelligence-optimized.sh" update > "$threat_log" 2>&1 &
    local threat_pid=$!
    
    # Monitor for test duration
    local test_start=$(date +%s)
    local max_memory=0
    local max_cpu=0
    
    while [ $(($(date +%s) - test_start)) -lt $TEST_DURATION ]; do
        # Get memory usage
        local memory_info=$(get_memory_usage)
        local memory_mb=$(echo "$memory_info" | cut -d: -f1)
        local memory_percent=$(echo "$memory_info" | cut -d: -f2)
        
        # Get CPU usage
        local cpu_percent=$(get_cpu_usage)
        
        # Get process info
        local process_info=$(get_process_info "threat-intelligence-optimized")
        local process_cpu=$(echo "$process_info" | cut -d: -f2)
        local process_mem_mb=$(echo "$process_info" | cut -d: -f3)
        
        # Track maximums
        if [ "$memory_mb" -gt "$max_memory" ]; then
            max_memory=$memory_mb
        fi
        
        # Use bc for decimal comparison
        if [ "$(echo "$cpu_percent > $max_cpu" | bc -l 2>/dev/null || echo 0)" -eq 1 ]; then
            max_cpu=$cpu_percent
        fi
        
        # Log sample with proper formatting
        echo "$(date): Memory=${memory_mb}MB (${memory_percent}%), CPU=${cpu_percent}%, Process=${process_mem_mb}MB (${process_cpu}%)" >> "$TEST_LOG"
        
        # Check thresholds
        if [ "$memory_mb" -gt "$MAX_ACCEPTABLE_MEMORY_MB" ]; then
            echo "$(date): WARNING - Memory usage exceeded threshold: ${memory_mb}MB > ${MAX_ACCEPTABLE_MEMORY_MB}MB" >> "$TEST_LOG"
        fi
        
        # Use bc for decimal comparison
        if [ "$(echo "$cpu_percent > $MAX_ACCEPTABLE_CPU_PERCENT" | bc -l 2>/dev/null || echo 0)" -eq 1 ]; then
            echo "$(date): WARNING - CPU usage exceeded threshold: ${cpu_percent}% > ${MAX_ACCEPTABLE_CPU_PERCENT}%" >> "$TEST_LOG"
        fi
        
        sleep $MEMORY_SAMPLE_INTERVAL
    done
    
    # Stop threat intelligence
    kill $threat_pid 2>/dev/null || true
    wait $threat_pid 2>/dev/null || true
    
    # Log results
    echo "Threat Intelligence Test Results:" >> "$TEST_LOG"
    echo "Maximum Memory Usage: ${max_memory}MB" >> "$TEST_LOG"
    echo "Maximum CPU Usage: ${max_cpu}%" >> "$TEST_LOG"
    echo "Test Completed: $(date)" >> "$TEST_LOG"
    echo "" >> "$TEST_LOG"
    
    log_info "Threat intelligence test completed - Max Memory: ${max_memory}MB, Max CPU: ${max_cpu}%"
}

# Test web dashboard performance
test_web_dashboard() {
    log_info "Testing web dashboard performance..."
    
    echo "=== Web Dashboard Performance Test ===" >> "$TEST_LOG"
    echo "Test Started: $(date)" >> "$TEST_LOG"
    
    # Start optimized web dashboard
    local dashboard_log="$AEGIS_HOME/logs/dashboard-test-$(date +%Y%m%d_%H%M%S).log"
    cd "$AEGIS_HOME/web-dashboard"
    python3 app.py > "$dashboard_log" 2>&1 &
    local dashboard_pid=$!
    
    # Wait for dashboard to start
    sleep 10
    
    # Monitor for test duration
    local test_start=$(date +%s)
    local max_memory=0
    local max_cpu=0
    
    while [ $(($(date +%s) - test_start)) -lt $TEST_DURATION ]; do
        # Get memory usage
        local memory_info=$(get_memory_usage)
        local memory_mb=$(echo "$memory_info" | cut -d: -f1)
        local memory_percent=$(echo "$memory_info" | cut -d: -f2)
        
        # Get CPU usage
        local cpu_percent=$(get_cpu_usage)
        
        # Get process info
        local process_info=$(get_process_info "app.py")
        local process_cpu=$(echo "$process_info" | cut -d: -f2)
        local process_mem_mb=$(echo "$process_info" | cut -d: -f3)
        
        # Track maximums
        if [ "$memory_mb" -gt "$max_memory" ]; then
            max_memory=$memory_mb
        fi
        
        # Use bc for decimal comparison
        if [ "$(echo "$cpu_percent > $max_cpu" | bc -l 2>/dev/null || echo 0)" -eq 1 ]; then
            max_cpu=$cpu_percent
        fi
        
        # Log sample with proper formatting
        echo "$(date): Memory=${memory_mb}MB (${memory_percent}%), CPU=${cpu_percent}%, Process=${process_mem_mb}MB (${process_cpu}%)" >> "$TEST_LOG"
        
        # Check thresholds
        if [ "$memory_mb" -gt "$MAX_ACCEPTABLE_MEMORY_MB" ]; then
            echo "$(date): WARNING - Memory usage exceeded threshold: ${memory_mb}MB > ${MAX_ACCEPTABLE_MEMORY_MB}MB" >> "$TEST_LOG"
        fi
        
        # Use bc for decimal comparison
        if [ "$(echo "$cpu_percent > $MAX_ACCEPTABLE_CPU_PERCENT" | bc -l 2>/dev/null || echo 0)" -eq 1 ]; then
            echo "$(date): WARNING - CPU usage exceeded threshold: ${cpu_percent}% > ${MAX_ACCEPTABLE_CPU_PERCENT}%" >> "$TEST_LOG"
        fi
        
        sleep $MEMORY_SAMPLE_INTERVAL
    done
    
    # Stop web dashboard
    kill $dashboard_pid 2>/dev/null || true
    wait $dashboard_pid 2>/dev/null || true
    
    # Log results
    echo "Web Dashboard Test Results:" >> "$TEST_LOG"
    echo "Maximum Memory Usage: ${max_memory}MB" >> "$TEST_LOG"
    echo "Maximum CPU Usage: ${max_cpu}%" >> "$TEST_LOG"
    echo "Test Completed: $(date)" >> "$TEST_LOG"
    echo "" >> "$TEST_LOG"
    
    log_info "Web dashboard test completed - Max Memory: ${max_memory}MB, Max CPU: ${max_cpu}%"
}

# Test memory monitor performance
test_memory_monitor() {
    log_info "Testing memory monitor performance..."
    
    echo "=== Memory Monitor Performance Test ===" >> "$TEST_LOG"
    echo "Test Started: $(date)" >> "$TEST_LOG"
    
    # Start memory monitor
    local monitor_log="$AEGIS_HOME/logs/memory-monitor-test-$(date +%Y%m%d_%H%M%S).log"
    "$SCRIPT_DIR/memory-monitor.sh" check > "$monitor_log" 2>&1 &
    local monitor_pid=$!
    
    # Monitor for test duration
    local test_start=$(date +%s)
    local max_memory=0
    local max_cpu=0
    
    while [ $(($(date +%s) - test_start)) -lt $TEST_DURATION ]; do
        # Get memory usage
        local memory_info=$(get_memory_usage)
        local memory_mb=$(echo "$memory_info" | cut -d: -f1)
        local memory_percent=$(echo "$memory_info" | cut -d: -f2)
        
        # Get CPU usage
        local cpu_percent=$(get_cpu_usage)
        
        # Get process info
        local process_info=$(get_process_info "memory-monitor.sh")
        local process_cpu=$(echo "$process_info" | cut -d: -f2)
        local process_mem_mb=$(echo "$process_info" | cut -d: -f3)
        
        # Track maximums
        if [ "$memory_mb" -gt "$max_memory" ]; then
            max_memory=$memory_mb
        fi
        
        # Use bc for decimal comparison
        if [ "$(echo "$cpu_percent > $max_cpu" | bc -l 2>/dev/null || echo 0)" -eq 1 ]; then
            max_cpu=$cpu_percent
        fi
        
        # Log sample with proper formatting
        echo "$(date): Memory=${memory_mb}MB (${memory_percent}%), CPU=${cpu_percent}%, Process=${process_mem_mb}MB (${process_cpu}%)" >> "$TEST_LOG"
        
        # Check thresholds
        if [ "$memory_mb" -gt "$MAX_ACCEPTABLE_MEMORY_MB" ]; then
            echo "$(date): WARNING - Memory usage exceeded threshold: ${memory_mb}MB > ${MAX_ACCEPTABLE_MEMORY_MB}MB" >> "$TEST_LOG"
        fi
        
        # Use bc for decimal comparison
        if [ "$(echo "$cpu_percent > $MAX_ACCEPTABLE_CPU_PERCENT" | bc -l 2>/dev/null || echo 0)" -eq 1 ]; then
            echo "$(date): WARNING - CPU usage exceeded threshold: ${cpu_percent}% > ${MAX_ACCEPTABLE_CPU_PERCENT}%" >> "$TEST_LOG"
        fi
        
        sleep $MEMORY_SAMPLE_INTERVAL
    done
    
    # Stop memory monitor
    kill $monitor_pid 2>/dev/null || true
    wait $monitor_pid 2>/dev/null || true
    
    # Log results
    echo "Memory Monitor Test Results:" >> "$TEST_LOG"
    echo "Maximum Memory Usage: ${max_memory}MB" >> "$TEST_LOG"
    echo "Maximum CPU Usage: ${max_cpu}%" >> "$TEST_LOG"
    echo "Test Completed: $(date)" >> "$TEST_LOG"
    echo "" >> "$TEST_LOG"
    
    log_info "Memory monitor test completed - Max Memory: ${max_memory}MB, Max CPU: ${max_cpu}%"
}

# Test database performance
test_database_performance() {
    log_info "Testing database performance..."
    
    echo "=== Database Performance Test ===" >> "$TEST_LOG"
    echo "Test Started: $(date)" >> "$TEST_LOG"
    
    # Test behavioral database
    local behavioral_db="$AEGIS_HOME/configs/behavioral_analysis/behavioral_data.db"
    if [ -f "$behavioral_db" ]; then
        echo "Testing behavioral database performance..." >> "$TEST_LOG"
        
        # Test query performance
        local start_time=$(date +%s.%N)
        for i in {1..100}; do
            sqlite3 "$behavioral_db" "SELECT COUNT(*) FROM system_metrics;" > /dev/null
        done
        local end_time=$(date +%s.%N)
        local query_time=$(echo "$end_time - $start_time" | bc -l)
        local avg_query_time=$(echo "scale=3; $query_time / 100" | bc -l)
        
        echo "Behavioral Database - 100 queries in ${query_time}s (avg: ${avg_query_time}s)" >> "$TEST_LOG"
        
        # Test insert performance
        start_time=$(date +%s.%N)
        for i in {1..100}; do
            sqlite3 "$behavioral_db" "INSERT INTO system_metrics (cpu_usage, memory_usage) VALUES ($RANDOM % 100, $RANDOM % 100);" > /dev/null
        done
        end_time=$(date +%s.%N)
        local insert_time=$(echo "$end_time - $start_time" | bc -l)
        local avg_insert_time=$(echo "scale=3; $insert_time / 100" | bc -l)
        
        echo "Behavioral Database - 100 inserts in ${insert_time}s (avg: ${avg_insert_time}s)" >> "$TEST_LOG"
        
        # Cleanup test data
        sqlite3 "$behavioral_db" "DELETE FROM system_metrics WHERE cpu_usage < 1000;" > /dev/null
    fi
    
    # Test threat intelligence database
    local threat_db="$AEGIS_HOME/configs/threat_intelligence/ioc_database.db"
    if [ -f "$threat_db" ]; then
        echo "Testing threat intelligence database performance..." >> "$TEST_LOG"
        
        # Test query performance
        local start_time=$(date +%s.%N)
        for i in {1..100}; do
            sqlite3 "$threat_db" "SELECT COUNT(*) FROM ioc_ips;" > /dev/null
        done
        local end_time=$(date +%s.%N)
        local query_time=$(echo "$end_time - $start_time" | bc -l)
        local avg_query_time=$(echo "scale=3; $query_time / 100" | bc -l)
        
        echo "Threat Database - 100 queries in ${query_time}s (avg: ${avg_query_time}s)" >> "$TEST_LOG"
        
        # Test insert performance
        start_time=$(date +%s.%N)
        for i in {1..100}; do
            sqlite3 "$threat_db" "INSERT OR IGNORE INTO ioc_ips (ip_address, source, threat_type, confidence) VALUES ('192.168.1.$i', 'test', 'test', 50);" > /dev/null
        done
        end_time=$(date +%s.%N)
        local insert_time=$(echo "$end_time - $start_time" | bc -l)
        local avg_insert_time=$(echo "scale=3; $insert_time / 100" | bc -l)
        
        echo "Threat Database - 100 inserts in ${insert_time}s (avg: ${avg_insert_time}s)" >> "$TEST_LOG"
        
        # Cleanup test data
        sqlite3 "$threat_db" "DELETE FROM ioc_ips WHERE source = 'test';" > /dev/null
    fi
    
    echo "Database Performance Test Completed: $(date)" >> "$TEST_LOG"
    echo "" >> "$TEST_LOG"
    
    log_info "Database performance test completed"
}

# Generate performance report
generate_performance_report() {
    log_info "Generating performance report..."
    
    local report_file="$AEGIS_HOME/logs/performance-report-$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "Aegis Security Suite Performance Report"
        echo "===================================="
        echo "Report Generated: $(date)"
        echo "Test Duration: ${TEST_DURATION}s"
        echo "Max Acceptable Memory: ${MAX_ACCEPTABLE_MEMORY_MB}MB"
        echo "Max Acceptable CPU: ${MAX_ACCEPTABLE_CPU_PERCENT}%"
        echo ""
        
        echo "Test Results Summary:"
        echo "===================="
        
        # Extract maximum values from test log with better parsing
        local max_memory=$(grep "Maximum Memory Usage:" "$TEST_LOG" | sed 's/[^0-9]*//g' | sort -n | tail -1)
        local max_cpu=$(grep "Maximum CPU Usage:" "$TEST_LOG" | sed 's/[^0-9]*//g' | sort -n | tail -1)
        
        # Clean up the values to ensure they're just numbers
        max_memory=$(echo "$max_memory" | sed 's/[^0-9]*//g' | head -1)
        max_cpu=$(echo "$max_cpu" | sed 's/[^0-9]*//g' | head -1)
        
        echo "Overall Maximum Memory Usage: ${max_memory:-0}MB"
        echo "Overall Maximum CPU Usage: ${max_cpu:-0}%"
        echo ""
        
        # Performance assessment
        if [ -n "$max_memory" ] && [ "$max_memory" -le "$MAX_ACCEPTABLE_MEMORY_MB" ]; then
            echo "✅ Memory Usage: WITHIN LIMITS"
        else
            echo "❌ Memory Usage: EXCEEDS LIMITS"
        fi
        
        if [ -n "$max_cpu" ] && [ "$max_cpu" -le "$MAX_ACCEPTABLE_CPU_PERCENT" ]; then
            echo "✅ CPU Usage: WITHIN LIMITS"
        else
            echo "❌ CPU Usage: EXCEEDS LIMITS"
        fi
        
        echo ""
        echo "Recommendations:"
        echo "==============="
        
        if [ -n "$max_memory" ] && [ "$max_memory" -gt "$MAX_ACCEPTABLE_MEMORY_MB" ]; then
            echo "- Memory usage exceeded limits. Consider:"
            echo "  * Reducing monitoring intervals"
            echo "  * Implementing more aggressive cleanup"
            echo "  * Increasing system memory"
        fi
        
        if [ -n "$max_cpu" ] && [ "$max_cpu" -gt "$MAX_ACCEPTABLE_CPU_PERCENT" ]; then
            echo "- CPU usage exceeded limits. Consider:"
            echo "  * Reducing monitoring frequency"
            echo "  * Optimizing database queries"
            echo "  * Using more efficient algorithms"
        fi
        
        echo ""
        echo "Full test log available at: $TEST_LOG"
        
    } > "$report_file"
    
    log_info "Performance report generated: $report_file"
    echo "$report_file"
}

# Main execution
case "${1:-all}" in
    "behavioral")
        init_performance_test
        test_behavioral_monitoring
        generate_performance_report
        ;;
    "threat")
        init_performance_test
        test_threat_intelligence
        generate_performance_report
        ;;
    "dashboard")
        init_performance_test
        test_web_dashboard
        generate_performance_report
        ;;
    "memory")
        init_performance_test
        test_memory_monitor
        generate_performance_report
        ;;
    "database")
        init_performance_test
        test_database_performance
        generate_performance_report
        ;;
    "all")
        init_performance_test
        test_behavioral_monitoring
        test_threat_intelligence
        test_web_dashboard
        test_memory_monitor
        test_database_performance
        generate_performance_report
        ;;
    *)
        echo "Usage: $0 {behavioral|threat|dashboard|memory|database|all}"
        echo "  behavioral - Test behavioral monitoring performance"
        echo "  threat - Test threat intelligence performance"
        echo "  dashboard - Test web dashboard performance"
        echo "  memory - Test memory monitor performance"
        echo "  database - Test database performance"
        echo "  all - Test all components"
        exit 1
        ;;
esac