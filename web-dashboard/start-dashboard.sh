#!/bin/bash

# Aegis Security Suite Web Dashboard Startup Script
# This script starts the web dashboard with proper environment setup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DASHBOARD_NAME="Aegis Security Dashboard"
DASHBOARD_PORT="8080"
PID_FILE="/tmp/aegis-dashboard.pid"
LOG_FILE="/tmp/aegis-dashboard-startup.log"

# Security suite home - detect from script location if not set
if [ -z "${AEGIS_HOME:-}" ]; then
    # Derive from script location
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    AEGIS_HOME="$(dirname "$SCRIPT_DIR")"
fi

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_warning "Running as root. Consider running as a dedicated user for better security."
    fi
}

# Function to check dependencies
check_dependencies() {
    print_status "Checking dependencies..."
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is not installed"
        exit 1
    fi
    
    # Check pip (try multiple methods)
    local pip_cmd=""
    if command -v pip3 &> /dev/null; then
        pip_cmd="pip3"
    elif command -v pip &> /dev/null; then
        pip_cmd="pip"
    elif python3 -m pip --version &> /dev/null; then
        pip_cmd="python3 -m pip"
    else
        print_warning "pip not found, attempting to continue without installing dependencies"
        print_status "Note: Some features may not work without proper dependencies"
        return 0
    fi
    
    # Check if virtual environment exists
    if [[ ! -d "$SCRIPT_DIR/venv" ]]; then
        print_status "Creating virtual environment..."
        python3 -m venv "$SCRIPT_DIR/venv" 2>/dev/null || {
            print_warning "Could not create virtual environment, using system Python"
            return 0
        }
    fi
    
    # Activate virtual environment
    if [[ -f "$SCRIPT_DIR/venv/bin/activate" ]]; then
        source "$SCRIPT_DIR/venv/bin/activate"
        print_status "Using virtual environment"
    else
        print_warning "Virtual environment not found, using system Python"
    fi
    
    # Install requirements if pip is available
    if [[ -n "$pip_cmd" && -f "$SCRIPT_DIR/requirements.txt" ]]; then
        print_status "Installing Python dependencies..."
        $pip_cmd install -r "$SCRIPT_DIR/requirements.txt" > "$LOG_FILE" 2>&1
        if [[ $? -eq 0 ]]; then
            print_success "Dependencies installed successfully"
        else
            print_warning "Some dependencies failed to install. Check $LOG_FILE for details."
            print_status "Attempting to continue with available dependencies..."
        fi
    elif [[ -f "$SCRIPT_DIR/requirements.txt" ]]; then
        print_warning "pip not available, cannot install dependencies automatically"
        print_status "Please manually install: $(cat $SCRIPT_DIR/requirements.txt | tr '\n' ' ')"
    fi
}

# Function to check security suite installation
check_security_suite() {
    print_status "Checking Aegis Security Suite installation..."
    
    if [[ ! -d "$AEGIS_HOME" ]]; then
        print_error "Aegis Security Suite not found at $AEGIS_HOME"
        print_status "Please install the security suite first or set AEGIS_HOME environment variable"
        exit 1
    fi
    
    if [[ ! -f "$AEGIS_HOME/configs/security-config.conf" ]]; then
        print_warning "Security configuration not found. Some features may not work properly."
    fi
    
    # Check required directories
    local required_dirs=(
        "configs"
        "scripts"
        "logs"
        "evidence"
        "quarantine"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$AEGIS_HOME/$dir" ]]; then
            print_status "Creating missing directory: $dir"
            mkdir -p "$AEGIS_HOME/$dir"
        fi
    done
    
    # Check for web dashboard specific requirements
    if [[ ! -f "$AEGIS_HOME/web-dashboard/app.py" ]]; then
        print_error "Web dashboard application not found at $AEGIS_HOME/web-dashboard/app.py"
        exit 1
    fi
    
    print_success "Security suite check completed"
}

# Function to setup environment
setup_environment() {
    print_status "Setting up environment..."
    
    # Set environment variables
    export AEGIS_HOME="$AEGIS_HOME"
    export FLASK_APP="$SCRIPT_DIR/app.py"
    export FLASK_ENV="production"
    export DASHBOARD_CONFIG="$SCRIPT_DIR/config/dashboard.conf"
    
    # Create logs directory if it doesn't exist
    mkdir -p "$AEGIS_HOME/logs"
    
    # Create database directory if it doesn't exist
    mkdir -p "$AEGIS_HOME/configs/web-dashboard"
    
    print_success "Environment setup completed"
}

# Function to check if dashboard is already running
check_running() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            print_warning "Dashboard is already running with PID $pid"
            return 0
        else
            print_status "Removing stale PID file"
            rm -f "$PID_FILE"
        fi
    fi
    return 1
}

# Function to start dashboard
start_dashboard() {
    print_status "Starting $DASHBOARD_NAME..."
    
    # Activate virtual environment
    if [[ -d "$SCRIPT_DIR/venv" ]]; then
        source "$SCRIPT_DIR/venv/bin/activate"
    else
        print_warning "Virtual environment not found, using system Python"
    fi
    
    # Change to script directory
    cd "$SCRIPT_DIR" || {
        print_error "Failed to change to dashboard directory: $SCRIPT_DIR"
        exit 1
    }
    
    # Check if app.py exists
    if [[ ! -f "app.py" ]]; then
        print_error "Dashboard application not found: app.py"
        exit 1
    fi
    
    # Start the dashboard in background
    nohup python3 app.py > "$AEGIS_HOME/logs/web-dashboard.log" 2>&1 &
    local pid=$!
    
    # Save PID
    echo "$pid" > "$PID_FILE"
    
    # Wait a moment and check if it started successfully
    sleep 3
    if ps -p "$pid" > /dev/null 2>&1; then
        print_success "$DASHBOARD_NAME started successfully with PID $pid"
        print_status "Dashboard is available at: http://localhost:$DASHBOARD_PORT"
        print_status "Log file: $AEGIS_HOME/logs/web-dashboard.log"
        print_status "PID file: $PID_FILE"
    else
        print_error "Failed to start $DASHBOARD_NAME"
        print_status "Check the log file for details: $AEGIS_HOME/logs/web-dashboard.log"
        rm -f "$PID_FILE"
        exit 1
    fi
}

# Function to stop dashboard
stop_dashboard() {
    print_status "Stopping $DASHBOARD_NAME..."
    
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            kill "$pid"
            sleep 2
            
            # Force kill if still running
            if ps -p "$pid" > /dev/null 2>&1; then
                print_warning "Force killing dashboard process..."
                kill -9 "$pid"
            fi
            
            rm -f "$PID_FILE"
            print_success "$DASHBOARD_NAME stopped successfully"
        else
            print_warning "Dashboard process not found. Removing PID file."
            rm -f "$PID_FILE"
        fi
    else
        print_warning "PID file not found. Dashboard may not be running."
    fi
}

# Function to show status
show_status() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            print_success "$DASHBOARD_NAME is running with PID $pid"
            print_status "Dashboard URL: http://localhost:$DASHBOARD_PORT"
            
            # Show resource usage
            local cpu_usage=$(ps -p "$pid" -o %cpu --no-headers | tr -d ' ')
            local mem_usage=$(ps -p "$pid" -o %mem --no-headers | tr -d ' ')
            print_status "CPU Usage: ${cpu_usage}%"
            print_status "Memory Usage: ${mem_usage}%"
        else
            print_error "$DASHBOARD_NAME is not running (stale PID file)"
            rm -f "$PID_FILE"
        fi
    else
        print_warning "$DASHBOARD_NAME is not running"
    fi
}

# Function to show help
show_help() {
    echo "Aegis Security Suite Web Dashboard Startup Script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start     Start the dashboard (default)"
    echo "  stop      Stop the dashboard"
    echo "  restart   Restart the dashboard"
    echo "  status    Show dashboard status"
    echo "  help      Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  AEGIS_HOME    Path to security suite installation (default: \$HOME/aegis-security-suite)"
    echo "  DASHBOARD_PORT        Dashboard port (default: 8080)"
    echo ""
    echo "Examples:"
    echo "  $0 start              # Start dashboard"
    echo "  $0 stop               # Stop dashboard"
    echo "  AEGIS_HOME=/opt/security $0 start  # Start with custom path"
}

# Main script logic
main() {
    local command="${1:-start}"
    
    case "$command" in
        "start")
            check_root
            if ! check_running; then
                check_dependencies
                check_security_suite
                setup_environment
                start_dashboard
            fi
            ;;
        "stop")
            stop_dashboard
            ;;
        "restart")
            stop_dashboard
            sleep 2
            check_root
            check_dependencies
            check_security_suite
            setup_environment
            start_dashboard
            ;;
        "status")
            show_status
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Trap signals for cleanup
trap 'print_status "Cleaning up..."; rm -f "$PID_FILE"; exit 0' INT TERM

# Run main function with all arguments
main "$@"