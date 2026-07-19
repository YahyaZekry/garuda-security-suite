#!/bin/bash
# Service Template Processor
# Replaces template variables in service files with actual user-specific values

# Source common functions
SCRIPT_DIR="$(dirname "$0")"
if [ -f "$SCRIPT_DIR/common-functions.sh" ]; then
    source "$SCRIPT_DIR/common-functions.sh"
fi

# Setup user environment
setup_user_environment

# Function to process a service template
process_service_template() {
    local template_file="$1"
    local output_file="$2"
    local service_user="${3:-$CURRENT_USER}"
    
    if [ ! -f "$template_file" ]; then
        echo "ERROR: Template file not found: $template_file" >&2
        return 1
    fi
    
    # Create output directory if it doesn't exist
    mkdir -p "$(dirname "$output_file")"
    
    # Process template with variable substitution
    sed -e "s|\${CURRENT_USER}|$service_user|g" \
        -e "s|\${CURRENT_HOME}|$CURRENT_HOME|g" \
        -e "s|\${AEGIS_HOME}|$AEGIS_HOME|g" \
        -e "s|\${SCRIPTS_DIR}|$SCRIPTS_DIR|g" \
        -e "s|\${LOGS_DIR}|$LOGS_DIR|g" \
        -e "s|\${CONFIGS_DIR}|$CONFIGS_DIR|g" \
        -e "s|\${BACKUPS_DIR}|$BACKUPS_DIR|g" \
        "$template_file" > "$output_file"
    
    echo "Processed service template: $template_file -> $output_file"
    return 0
}

# Function to install service with user detection
install_user_service() {
    local service_name="$1"
    local template_file="$2"
    local install_dir="$3"
    local service_user="${4:-$CURRENT_USER}"
    
    local output_file="$install_dir/$service_name"
    
    # Process the template
    process_service_template "$template_file" "$output_file" "$service_user"
    
    # Set proper permissions
    chmod 644 "$output_file"
    
    # Reload systemd if it's a system service
    if [[ "$install_dir" == "/etc/systemd/system" ]]; then
        systemctl daemon-reload
    elif [[ "$install_dir" == "$HOME/.config/systemd/user" ]]; then
        systemctl --user daemon-reload
    fi
    
    echo "Service installed: $output_file"
}

# Main script logic
case "${1:-help}" in
    "process")
        if [ $# -lt 3 ]; then
            echo "Usage: $0 process <template_file> <output_file> [service_user]"
            exit 1
        fi
        process_service_template "$2" "$3" "$4"
        ;;
    "install")
        if [ $# -lt 3 ]; then
            echo "Usage: $0 install <service_name> <template_file> <install_dir> [service_user]"
            exit 1
        fi
        install_user_service "$2" "$3" "$4" "$5"
        ;;
    "env")
        echo "Current User Environment:"
        echo "  CURRENT_USER: $CURRENT_USER"
        echo "  CURRENT_HOME: $CURRENT_HOME"
        echo "  AEGIS_HOME: $AEGIS_HOME"
        echo "  SCRIPTS_DIR: $SCRIPTS_DIR"
        echo "  LOGS_DIR: $LOGS_DIR"
        echo "  CONFIGS_DIR: $CONFIGS_DIR"
        echo "  BACKUPS_DIR: $BACKUPS_DIR"
        ;;
    "help"|"-h"|"--help")
        echo "Service Template Processor for Aegis Security Suite"
        echo ""
        echo "Usage: $0 <command> [arguments]"
        echo ""
        echo "Commands:"
        echo "  process <template> <output> [user]  Process a service template"
        echo "  install <name> <template> <dir> [user]  Install a service"
        echo "  env                              Show current environment variables"
        echo "  help                              Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0 process aegis-dashboard.service.template aegis-dashboard.service"
        echo "  $0 install aegis-dashboard aegis-dashboard.service.template /etc/systemd/system"
        echo "  $0 env"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac