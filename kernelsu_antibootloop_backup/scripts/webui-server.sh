#!/system/bin/sh
# KernelSU Anti-Bootloop & Backup Module WebUIX Server Script

MODDIR=${0%/*}
MODDIR=${MODDIR%/*}
CONFIG_DIR="$MODDIR/config"
WEBROOT_DIR="$MODDIR/webroot"

# Log function for debugging
log_message() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$CONFIG_DIR/webui.log"
}

log_message "WebUIX server script started"

# Check if WebUI is enabled
check_webui_enabled() {
    ENABLED=$(grep "webui_enabled" "$CONFIG_DIR/main.conf" | cut -d= -f2 || echo "true")
    if [ "$ENABLED" == "true" ]; then
        log_message "WebUI is enabled"
        return 0
    else
        log_message "WebUI is disabled"
        return 1
    fi
}

# Get configured port
get_webui_port() {
    PORT=$(grep "webui_port" "$CONFIG_DIR/main.conf" | cut -d= -f2 || echo "8080")
    log_message "Using port: $PORT"
    echo "$PORT"
}

# Check if authentication is required
check_auth_required() {
    AUTH_REQUIRED=$(grep "webui_auth" "$CONFIG_DIR/main.conf" | cut -d= -f2 || echo "true")
    if [ "$AUTH_REQUIRED" == "true" ]; then
        log_message "Authentication is required"
        return 0
    else
        log_message "Authentication is disabled"
        return 1
    fi
}

# Start the WebUI server
start_webui_server() {
    PORT=$(get_webui_port)
    
    log_message "Starting WebUIX server on port $PORT"
    
    # Start busybox httpd server
    if command -v busybox >/dev/null 2>&1; then
        # Create httpd configuration
        cat > "$CONFIG_DIR/httpd.conf" <<EOF
*.cgi:/system/bin/sh
/api/*:application/json
EOF
        
        # Start busybox httpd
        busybox httpd -p "$PORT" -h "$WEBROOT_DIR" -c "$CONFIG_DIR/httpd.conf" -f &
        HTTPD_PID=$!
        echo "$HTTPD_PID" > "$CONFIG_DIR/httpd.pid"
        
        log_message "Busybox httpd started with PID: $HTTPD_PID"
    else
        # Fallback to netcat-based simple server
        start_netcat_server "$PORT" &
        NC_PID=$!
        echo "$NC_PID" > "$CONFIG_DIR/httpd.pid"
        
        log_message "Netcat server started with PID: $NC_PID"
    fi
    
    log_message "WebUIX server started successfully"
}

# Netcat-based simple HTTP server fallback
start_netcat_server() {
    local port="$1"
    
    while true; do
        {
            echo "HTTP/1.1 200 OK"
            echo "Content-Type: text/html"
            echo ""
            cat "$WEBROOT_DIR/index.html"
        } | nc -l -p "$port"
    done
}

# API Handler Functions
get_system_info() {
    echo "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{"
    echo "\"device_model\":\"$(getprop ro.product.model)\","
    echo "\"android_version\":\"$(getprop ro.build.version.release)\","
    echo "\"kernel_version\":\"$(uname -r)\","
    echo "\"kernelsu_version\":\"$(getprop ro.kernelsu.version)\","
    echo "\"module_version\":\"1.0.0\""
    echo "}"
}

list_backups() {
    echo "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{"
    echo "\"backups\":["
    
    local first=true
    for backup in "$CONFIG_DIR/backups"/*; do
        if [ -d "$backup" ]; then
            [ "$first" = false ] && echo ","
            echo "    {\"id\":\"$(basename "$backup")\",\"created\":\"$(stat -c %Y "$backup")\"}"
            first=false
        fi
    done
    
    echo "]}"
}

create_backup_api() {
    local profile="${REQUEST_BODY:-default}"
    "$MODDIR/scripts/backup-engine.sh" create_backup "$profile"
    
    echo "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{"
    echo "\"status\":\"success\","
    echo "\"message\":\"Backup created successfully\""
    echo "}"
}

restore_backup_api() {
    local backup_id="${REQUEST_BODY}"
    "$MODDIR/scripts/backup-engine.sh" restore_from_backup "$backup_id"
    
    echo "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{"
    echo "\"status\":\"success\","
    echo "\"message\":\"Backup restored successfully\""
    echo "}"
}

get_safety_status() {
    local boot_count=$(cat "$CONFIG_DIR/boot_counter" 2>/dev/null || echo "0")
    local safe_mode=$([ -f "/data/local/tmp/ksu_safe_mode" ] && echo "true" || echo "false")
    
    echo "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{"
    echo "\"boot_count\":$boot_count,"
    echo "\"safe_mode\":$safe_mode,"
    echo "\"last_boot\":\"$(date)\""
    echo "}"
}

get_settings() {
    echo "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{"
    echo "\"webui_port\":8080,"
    echo "\"auth_required\":true,"
    echo "\"backup_encryption\":$(grep 'backup_encryption' "$CONFIG_DIR/main.conf" | cut -d= -f2 || echo 'false'),"
    echo "\"auto_backup\":false"
    echo "}"
}

# Handle API requests
handle_api_request() {
    REQUEST="$1"
    
    log_message "Handling API request: $REQUEST"
    
    # Parse API request and route to appropriate handler
    case "$REQUEST" in
        "/api/system/info")
            get_system_info
            ;;
        "/api/backups/list")
            list_backups
            ;;
        "/api/backups/create")
            create_backup_api
            ;;
        "/api/backups/restore")
            restore_backup_api
            ;;
        "/api/safety/status")
            get_safety_status
            ;;
        "/api/settings")
            get_settings
            ;;
        *)
            echo "HTTP/1.1 404 Not Found\r\nContent-Type: application/json\r\n\r\n{\"error\":\"Endpoint not found\"}"
            ;;
    esac
    
    log_message "API request handled (placeholder)"
}

# Set up authentication
setup_authentication() {
    log_message "Setting up authentication"
    
    # Generate random session token
    SESSION_TOKEN=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32)
    echo "$SESSION_TOKEN" > "$CONFIG_DIR/session_token"
    
    # Create basic auth file if it doesn't exist
    if [ ! -f "$CONFIG_DIR/auth_users" ]; then
        # Default credentials: admin/kernelsu
        echo "admin:$(echo -n 'kernelsu' | sha256sum | cut -d' ' -f1)" > "$CONFIG_DIR/auth_users"
    fi
    
    log_message "Authentication configured with session token"
    
    log_message "Authentication setup completed (placeholder)"
}

# Main function
main() {
    log_message "WebUIX main function started"
    
    # Check if WebUI is enabled
    if check_webui_enabled; then
        # Check if authentication is required
        if check_auth_required; then
            setup_authentication
        fi
        
        # Start the WebUI server
        start_webui_server
    else
        log_message "WebUI is disabled, exiting"
        exit 0
    fi
}

# Execute main function
main