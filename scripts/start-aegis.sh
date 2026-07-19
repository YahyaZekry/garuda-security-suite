#!/bin/bash
# Aegis Security Suite Service Management Script
# Comprehensive service control for all security suite components

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions and setup user environment
if [ -f "$SCRIPT_DIR/common-functions.sh" ]; then
    source "$SCRIPT_DIR/common-functions.sh"
    setup_user_environment
else
    # Fallback if common functions not available
    AEGIS_HOME="$(dirname "$SCRIPT_DIR")"
fi

CONFIG_FILE="$AEGIS_HOME/configs/security-config.conf"
PID_DIR="$AEGIS_HOME/.pids"

# Colors for output
declare -A COLORS=(
    ["RED"]='\033[0;31m'
    ["GREEN"]='\033[0;32m'
    ["YELLOW"]='\033[1;33m'
    ["BLUE"]='\033[0;34m'
    ["PURPLE"]='\033[0;35m'
    ["CYAN"]='\033[0;36m'
    ["WHITE"]='\033[1;37m'
    ["NC"]='\033[0m'
)

# Service definitions
declare -A SERVICES=(
    ["daily-scan"]="security-daily-scan"
    ["weekly-scan"]="security-weekly-scan"
    ["monthly-scan"]="security-monthly-scan"
    ["behavioral-monitor"]="behavioral-monitor"
    ["web-dashboard"]="aegis-dashboard"
)

declare -A SERVICE_DESCRIPTIONS=(
    ["daily-scan"]="Daily Security Scan (quick scan of critical directories)"
    ["weekly-scan"]="Weekly Security Scan (comprehensive home directory scan)"
    ["monthly-scan"]="Monthly Security Scan (full system scan)"
    ["behavioral-monitor"]="Behavioral Analysis Monitor (real-time anomaly detection)"
    ["web-dashboard"]="Web Dashboard (web-based security management interface)"
)

# Logging functions
log_info() {
    echo -e "${COLORS[BLUE]}[INFO]${COLORS[NC]} $1"
}

log_success() {
    echo -e "${COLORS[GREEN]}[SUCCESS]${COLORS[NC]} $1"
}

log_warning() {
    echo -e "${COLORS[YELLOW]}[WARNING]${COLORS[NC]} $1"
}

log_error() {
    echo -e "${COLORS[RED]}[ERROR]${COLORS[NC]} $1"
}

log_header() {
    echo -e "${COLORS[PURPLE]}=== $1 ===${COLORS[NC]}"
}

# Load configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        log_info "Configuration loaded from: $CONFIG_FILE"
    else
        log_warning "Configuration file not found: $CONFIG_FILE"
        log_warning "Using default configuration values"
    fi
}

# Check prerequisites
check_prerequisites() {
    log_header "Checking Prerequisites"
    
    local missing_deps=()
    
    # Check required system tools
    for tool in systemctl sqlite3 python3; do
        if ! command -v "$tool" &> /dev/null; then
            missing_deps+=("$tool")
        fi
    done
    
    # Check Aegis Security Suite installation
    if [ ! -d "$AEGIS_HOME" ]; then
        log_error "Aegis Security Suite not found at: $AEGIS_HOME"
        log_info "Please run the installation script first"
        exit 1
    fi
    
    # Check configuration file
    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        log_info "Please run the installation script first"
        exit 1
    fi
    
    # Check for missing dependencies
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_info "Install with: sudo pacman -S ${missing_deps[*]}"
        exit 1
    fi
    
    # Create PID directory
    mkdir -p "$PID_DIR"
    
    log_success "All prerequisites satisfied"
}

# Check if service is enabled
is_service_enabled() {
    local service_name="$1"
    
    case "$service_name" in
        "web-dashboard")
            # Dashboard doesn't use systemd timer
            return 1
            ;;
        "behavioral-monitor")
            # Check if behavioral monitor timer exists
            if [ -f "$HOME/.config/systemd/user/behavioral-monitor.timer" ] || [ -f "/etc/systemd/user/behavioral-monitor.timer" ]; then
                systemctl --user is-enabled "behavioral-monitor.timer" &> /dev/null
            else
                return 1
            fi
            ;;
        *)
            # For scan services, check if timer exists
            if systemctl --user list-unit-files | grep -q "${SERVICES[$service_name]}.timer"; then
                systemctl --user is-enabled "${SERVICES[$service_name]}.timer" &> /dev/null
            else
                return 1
            fi
            ;;
    esac
}

# Check if service is active
is_service_active() {
    local service_name="$1"
    
    case "$service_name" in
        "web-dashboard")
            # Check dashboard PID file
            local pid_file="/tmp/aegis-dashboard.pid"
            if [ -f "$pid_file" ]; then
                local pid=$(cat "$pid_file")
                if ps -p "$pid" &> /dev/null; then
                    return 0
                fi
            fi
            return 1
            ;;
        "behavioral-monitor")
            # Check if behavioral monitor process is running
            if pgrep -f "behavioral-monitor.sh" > /dev/null; then
                return 0
            fi
            return 1
            ;;
        *)
            # For scan services, check if timer is active
            if systemctl --user list-unit-files | grep -q "${SERVICES[$service_name]}.timer"; then
                systemctl --user is-active "${SERVICES[$service_name]}.timer" &> /dev/null
            else
                return 1
            fi
            ;;
    esac
}

# Get service status
get_service_status() {
    local service_name="$1"
    local status="unknown"
    
    if is_service_enabled "$service_name"; then
        status="enabled"
    else
        status="disabled"
    fi
    
    if is_service_active "$service_name"; then
        status="$status|running"
    else
        status="$status|stopped"
    fi
    
    echo "$status"
}

# Start individual service
start_service() {
    local service_name="$1"
    local service_desc="${SERVICE_DESCRIPTIONS[$service_name]}"
    
    log_info "Starting $service_name: $service_desc"
    
    case "$service_name" in
        "web-dashboard")
            start_web_dashboard
            ;;
        "behavioral-monitor")
            start_behavioral_monitor
            ;;
        *)
            # For scan services, try to start via systemd or fallback to manual
            if systemctl --user list-unit-files | grep -q "${SERVICES[$service_name]}.timer"; then
                if ! is_service_enabled "$service_name"; then
                    log_info "Enabling $service_name timer"
                    systemctl --user enable "${SERVICES[$service_name]}.timer" 2>/dev/null || log_warning "Could not enable $service_name timer"
                fi
                
                log_info "Starting $service_name service"
                systemctl --user start "${SERVICES[$service_name]}.timer" 2>/dev/null || {
                    log_warning "Could not start $service_name timer, trying manual execution"
                    start_scan_service_manually "$service_name"
                }
            else
                log_warning "$service_name timer not found, starting manually"
                start_scan_service_manually "$service_name"
            fi
            ;;
    esac
    
    # Verify service started
    sleep 2
    if is_service_active "$service_name"; then
        log_success "$service_name started successfully"
        return 0
    else
        log_error "$service_name failed to start"
        return 1
    fi
}

# Stop individual service
stop_service() {
    local service_name="$1"
    local service_desc="${SERVICE_DESCRIPTIONS[$service_name]}"
    
    log_info "Stopping $service_name: $service_desc"
    
    case "$service_name" in
        "web-dashboard")
            stop_web_dashboard
            ;;
        "behavioral-monitor")
            stop_behavioral_monitor
            ;;
        *)
            # Try systemd first, then manual
            log_info "Stopping $service_name timer"
            systemctl --user stop "${SERVICES[$service_name]}.timer" 2>/dev/null || true
            
            log_info "Stopping $service_name service"
            systemctl --user stop "${SERVICES[$service_name]}.service" 2>/dev/null || true
            
            # Kill any remaining processes
            pkill -f "${SERVICES[$service_name]}" 2>/dev/null || true
            ;;
    esac
    
    # Verify service stopped
    sleep 2
    if ! is_service_active "$service_name"; then
        log_success "$service_name stopped successfully"
        return 0
    else
        log_error "$service_name failed to stop"
        return 1
    fi
}

# Restart individual service
restart_service() {
    local service_name="$1"
    
    log_info "Restarting $service_name"
    stop_service "$service_name"
    sleep 3
    start_service "$service_name"
}

# Start web dashboard
start_web_dashboard() {
    log_info "Starting web dashboard"
    
    # Check if dashboard is already running
    if is_service_active "web-dashboard"; then
        log_warning "Web dashboard is already running"
        return 0
    fi
    
    # Check if dashboard directory exists
    if [ ! -d "$AEGIS_HOME/web-dashboard" ]; then
        log_error "Web dashboard directory not found: $AEGIS_HOME/web-dashboard"
        return 1
    fi
    
    # Check if start script exists
    if [ ! -f "$AEGIS_HOME/web-dashboard/start-dashboard.sh" ]; then
        log_error "Dashboard start script not found: $AEGIS_HOME/web-dashboard/start-dashboard.sh"
        return 1
    fi
    
    # Make script executable
    chmod +x "$AEGIS_HOME/web-dashboard/start-dashboard.sh"
    
    # Start dashboard using the start script
    cd "$AEGIS_HOME/web-dashboard" || {
        log_error "Failed to change to dashboard directory"
        return 1
    }
    
    # Set environment variable for security suite home
    export AEGIS_HOME="$AEGIS_HOME"
    
    ./start-dashboard.sh start
}

# Stop web dashboard
stop_web_dashboard() {
    log_info "Stopping web dashboard"
    
    # Check if dashboard directory exists
    if [ ! -d "$AEGIS_HOME/web-dashboard" ]; then
        log_warning "Web dashboard directory not found: $AEGIS_HOME/web-dashboard"
        return 0
    fi
    
    # Check if start script exists
    if [ ! -f "$AEGIS_HOME/web-dashboard/start-dashboard.sh" ]; then
        log_warning "Dashboard start script not found, trying manual stop"
        # Try to stop using PID file directly
        local pid_file="/tmp/aegis-dashboard.pid"
        if [ -f "$pid_file" ]; then
            local pid=$(cat "$pid_file")
            if ps -p "$pid" &> /dev/null; then
                kill "$pid" 2>/dev/null || true
                sleep 2
                kill -9 "$pid" 2>/dev/null || true
                rm -f "$pid_file"
                log_success "Web dashboard stopped manually"
                return 0
            fi
        fi
        return 1
    fi
    
    # Navigate to dashboard directory
    cd "$AEGIS_HOME/web-dashboard" || {
        log_error "Failed to change to dashboard directory"
        return 1
    }
    
    # Stop dashboard using the start script
    ./start-dashboard.sh stop
}

# Start behavioral monitor
start_behavioral_monitor() {
    log_info "Starting behavioral monitor"
    
    # Check if behavioral analysis is enabled
    if [ "${BEHAVIORAL_ANALYSIS_ENABLED:-false}" != "true" ]; then
        log_warning "Behavioral analysis is not enabled in configuration"
        return 1
    fi
    
    # Check if behavioral monitor script exists
    if [ ! -f "$AEGIS_HOME/scripts/behavioral-monitor-optimized.sh" ]; then
        log_error "Behavioral monitor script not found: $AEGIS_HOME/scripts/behavioral-monitor-optimized.sh"
        return 1
    fi
    
    # Make script executable
    chmod +x "$AEGIS_HOME/scripts/behavioral-monitor-optimized.sh"
    
    # Check if already running
    if pgrep -f "behavioral-monitor-optimized.sh" > /dev/null; then
        log_warning "Behavioral monitor is already running"
        return 0
    fi
    
    # Start behavioral monitor in background
    cd "$AEGIS_HOME/scripts" || {
        log_error "Failed to change to scripts directory"
        return 1
    }
    
    # Set environment variables
    export AEGIS_HOME="$AEGIS_HOME"
    
    # Start the monitor with default duration (run continuously)
    nohup ./behavioral-monitor-optimized.sh > "$AEGIS_HOME/logs/behavioral-monitor.log" 2>&1 &
    
    # Save PID
    local pid=$!
    echo "$pid" > "$PID_DIR/behavioral-monitor.pid"
    
    log_success "Behavioral monitor started with PID $pid"
}

# Stop behavioral monitor
stop_behavioral_monitor() {
    log_info "Stopping behavioral monitor"
    
    # Try to stop using PID file
    local pid_file="$PID_DIR/behavioral-monitor.pid"
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if ps -p "$pid" &> /dev/null; then
            kill "$pid" 2>/dev/null || true
            sleep 2
            kill -9 "$pid" 2>/dev/null || true
            rm -f "$pid_file"
            log_success "Behavioral monitor stopped"
            return 0
        else
            rm -f "$pid_file"
        fi
    fi
    
    # Fallback to process kill
    pkill -f "behavioral-monitor-optimized.sh" 2>/dev/null || true
    log_success "Behavioral monitor stopped"
}

# Start scan service manually
start_scan_service_manually() {
    local service_name="$1"
    local script_name=""
    
    case "$service_name" in
        "daily-scan")
            script_name="security-daily-scan.sh"
            ;;
        "weekly-scan")
            script_name="security-weekly-scan.sh"
            ;;
        "monthly-scan")
            script_name="security-monthly-scan.sh"
            ;;
        *)
            log_error "Unknown scan service: $service_name"
            return 1
            ;;
    esac
    
    # Check if script exists
    if [ ! -f "$AEGIS_HOME/scripts/$script_name" ]; then
        log_error "Scan script not found: $AEGIS_HOME/scripts/$script_name"
        return 1
    fi
    
    # Make script executable
    chmod +x "$AEGIS_HOME/scripts/$script_name"
    
    # Check if already running
    if pgrep -f "$script_name" > /dev/null; then
        log_warning "$service_name is already running"
        return 0
    fi
    
    # Start scan in background
    cd "$AEGIS_HOME/scripts" || {
        log_error "Failed to change to scripts directory"
        return 1
    }
    
    # Set environment variables
    export AEGIS_HOME="$AEGIS_HOME"
    
    # Start the scan
    nohup ./"$script_name" > "$AEGIS_HOME/logs/${service_name}.log" 2>&1 &
    
    # Save PID
    local pid=$!
    echo "$pid" > "$PID_DIR/${service_name}.pid"
    
    log_success "$service_name started manually with PID $pid"
}

# Start all services
start_all_services() {
    log_header "Starting All Security Services"
    
    local services_to_start=()
    
    # Determine which services to start based on configuration
    if [ "${ENABLE_SCHEDULING:-false}" = "true" ]; then
        services_to_start+=("daily-scan" "weekly-scan" "monthly-scan")
    fi
    
    if [ "${BEHAVIORAL_ANALYSIS_ENABLED:-false}" = "true" ]; then
        services_to_start+=("behavioral-monitor")
    fi
    
    # Always include web dashboard
    services_to_start+=("web-dashboard")
    
    # Start services
    local failed_services=()
    for service in "${services_to_start[@]}"; do
        if ! start_service "$service"; then
            failed_services+=("$service")
        fi
    done
    
    # Report results
    if [ ${#failed_services[@]} -eq 0 ]; then
        log_success "All services started successfully"
    else
        log_error "Failed to start services: ${failed_services[*]}"
        return 1
    fi
}

# Stop all services
stop_all_services() {
    log_header "Stopping All Security Services"
    
    local services_to_stop=("web-dashboard" "behavioral-monitor" "daily-scan" "weekly-scan" "monthly-scan")
    
    # Stop services in reverse order
    local failed_services=()
    for service in "${services_to_stop[@]}"; do
        if ! stop_service "$service"; then
            failed_services+=("$service")
        fi
    done
    
    # Report results
    if [ ${#failed_services[@]} -eq 0 ]; then
        log_success "All services stopped successfully"
    else
        log_error "Failed to stop services: ${failed_services[*]}"
        return 1
    fi
}

# Restart all services
restart_all_services() {
    log_header "Restarting All Security Services"
    
    stop_all_services
    sleep 5
    start_all_services
}

# Show service status
show_status() {
    log_header "Security Services Status"
    
    printf "%-20s %-10s %-10s %s\n" "Service" "Enabled" "Status" "Description"
    printf "%-20s %-10s %-10s %s\n" "------" "-------" "------" "-----------"
    
    # Check each service
    for service in "daily-scan" "weekly-scan" "monthly-scan" "behavioral-monitor" "web-dashboard"; do
        local status=$(get_service_status "$service")
        IFS='|' read -r enabled_status running_status <<< "$status"
        
        local enabled_color="${COLORS[YELLOW]}"
        if [ "$enabled_status" = "enabled" ]; then
            enabled_color="${COLORS[GREEN]}"
        fi
        
        local running_color="${COLORS[RED]}"
        if [ "$running_status" = "running" ]; then
            running_color="${COLORS[GREEN]}"
        fi
        
        printf "%-20s ${enabled_color}%-10s${COLORS[NC]} ${running_color}%-10s${COLORS[NC]} %s\n" \
            "$service" "$enabled_status" "$running_status" "${SERVICE_DESCRIPTIONS[$service]}"
    done
    
    echo ""
    
    # Show timer information
    if systemctl --user list-timers | grep -q "security"; then
        log_info "Active Security Timers:"
        systemctl --user list-timers | grep "security" | while read -r line; do
            echo "  $line"
        done
    else
        log_warning "No security timers are active"
    fi
    
    echo ""
    
    # Show dashboard information
    if is_service_active "web-dashboard"; then
        log_success "Web Dashboard: RUNNING"
        log_info "  URL: http://localhost:8080"
        log_info "  Logs: $AEGIS_HOME/logs/web-dashboard.log"
    else
        log_warning "Web Dashboard: STOPPED"
    fi
}

# Run comprehensive test
run_test() {
    log_header "Running Comprehensive Test"
    
    # Check if test script exists
    local test_script="$AEGIS_HOME/tests/test-suite-comprehensive.sh"
    if [ -f "$test_script" ]; then
        log_info "Running comprehensive test suite..."
        bash "$test_script"
    else
        log_warning "Comprehensive test script not found"
        log_info "Running basic validation test..."
        
        # Basic validation
        local validation_passed=true
        
        # Check configuration
        if [ ! -f "$CONFIG_FILE" ]; then
            log_error "Configuration file missing"
            validation_passed=false
        fi
        
        # Check scripts
        local required_scripts=("security-daily-scan.sh" "behavioral-analysis.sh" "incident-response.sh")
        for script in "${required_scripts[@]}"; do
            if [ ! -f "$AEGIS_HOME/scripts/$script" ]; then
                log_error "Required script missing: $script"
                validation_passed=false
            fi
        done
        
        # Check databases
        local db_dirs=("behavioral_analysis" "incident_response" "threat_intelligence")
        for db_dir in "${db_dirs[@]}"; do
            if [ ! -d "$AEGIS_HOME/configs/$db_dir" ]; then
                log_error "Database directory missing: $db_dir"
                validation_passed=false
            fi
        done
        
        if [ "$validation_passed" = true ]; then
            log_success "Basic validation passed"
        else
            log_error "Basic validation failed"
        fi
    fi
}

# Show help
show_help() {
    cat << EOF
Aegis Security Suite Service Management Script

Usage: $0 [COMMAND] [SERVICE]

Commands:
  start [service]     Start specific service or all services
  stop [service]      Stop specific service or all services
  restart [service]   Restart specific service or all services
  status              Show status of all services
  test                Run comprehensive test suite
  help                Show this help message

Services:
  daily-scan          Daily security scan service
  weekly-scan         Weekly security scan service
  monthly-scan        Monthly security scan service
  behavioral-monitor  Behavioral analysis monitoring service
  web-dashboard        Web dashboard service
  all                  All services (default for start/stop/restart)

Examples:
  $0 start all        Start all security services
  $0 start web-dashboard  Start only the web dashboard
  $0 stop daily-scan  Stop only the daily scan service
  $0 restart all       Restart all security services
  $0 status           Show status of all services
  $0 test             Run comprehensive test suite

Configuration:
  Configuration file: $CONFIG_FILE
  Aegis home: $AEGIS_HOME

For more information, see the documentation at:
  https://github.com/YahyaZekry/aegis-security-suite/docs/
EOF
}

# Main execution
main() {
    # Load configuration
    load_config
    
    # Check prerequisites
    check_prerequisites
    
    # Parse command line arguments
    local command="${1:-help}"
    local service="${2:-all}"
    
    case "$command" in
        "start")
            case "$service" in
                "all")
                    start_all_services
                    ;;
                *)
                    if [[ -n "${SERVICE_DESCRIPTIONS[$service]}" ]]; then
                        start_service "$service"
                    else
                        log_error "Unknown service: $service"
                        show_help
                        exit 1
                    fi
                    ;;
            esac
            ;;
        "stop")
            case "$service" in
                "all")
                    stop_all_services
                    ;;
                *)
                    if [[ -n "${SERVICE_DESCRIPTIONS[$service]}" ]]; then
                        stop_service "$service"
                    else
                        log_error "Unknown service: $service"
                        show_help
                        exit 1
                    fi
                    ;;
            esac
            ;;
        "restart")
            case "$service" in
                "all")
                    restart_all_services
                    ;;
                *)
                    if [[ -n "${SERVICE_DESCRIPTIONS[$service]}" ]]; then
                        restart_service "$service"
                    else
                        log_error "Unknown service: $service"
                        show_help
                        exit 1
                    fi
                    ;;
            esac
            ;;
        "status")
            show_status
            ;;
        "test")
            run_test
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"