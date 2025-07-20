#!/system/bin/sh

# Advanced Anti-Bootloop KSU Module - WebUI Server
# Author: @overspend1/Wiktor
# Lightweight HTTP server for module management

MODDIR=${0%/*}
. "$MODDIR/utils.sh"
. "$MODDIR/backup_manager.sh"
. "$MODDIR/recovery_engine.sh"

WEBUI_PORT=8888
WEBUI_DIR="$MODDIR/webui"
PID_FILE="$BASE_DIR/webui.pid"
ACCESS_LOG="$BASE_DIR/webui_access.log"

# Start WebUI server
start_webui() {
    if is_webui_running; then
        log_message "WARN" "WebUI server already running on port $WEBUI_PORT"
        return 1
    fi
    
    log_message "INFO" "Starting WebUI server on port $WEBUI_PORT"
    
    # Create response functions
    create_api_handlers
    
    # Start HTTP server using netcat
    start_http_server &
    SERVER_PID=$!
    
    echo "$SERVER_PID" > "$PID_FILE"
    log_message "INFO" "WebUI server started with PID: $SERVER_PID"
    
    return 0
}

# Stop WebUI server
stop_webui() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill "$pid" 2>/dev/null; then
            log_message "INFO" "WebUI server stopped (PID: $pid)"
        fi
        rm -f "$PID_FILE"
    else
        log_message "WARN" "WebUI server not running"
    fi
}

# Check if WebUI is running
is_webui_running() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        else
            rm -f "$PID_FILE"
        fi
    fi
    return 1
}

# Simple HTTP server implementation
start_http_server() {
    while true; do
        # Listen for connections using netcat
        (
            read request
            read_headers
            handle_request "$request"
        ) | nc -l -p "$WEBUI_PORT" 2>/dev/null
        
        # Break if server should stop
        if [ ! -f "$PID_FILE" ]; then
            break
        fi
    done
}

# Read HTTP headers (simplified)
read_headers() {
    while read line && [ "$line" != "" ]; do
        : # Skip headers for now
    done
}

# Handle HTTP requests
handle_request() {
    local request="$1"
    local method=$(echo "$request" | cut -d' ' -f1)
    local path=$(echo "$request" | cut -d' ' -f2)
    local query_string=""
    
    # Extract query string
    if echo "$path" | grep -q "?"; then
        query_string=$(echo "$path" | cut -d'?' -f2)
        path=$(echo "$path" | cut -d'?' -f1)
    fi
    
    # Log access
    echo "$(date '+%Y-%m-%d %H:%M:%S') $method $path" >> "$ACCESS_LOG"
    
    # Route requests
    case "$path" in
        "/" | "/index.html")
            serve_file "$WEBUI_DIR/index.html" "text/html"
            ;;
        "/api/status")
            api_status
            ;;
        "/api/config")
            if [ "$method" = "GET" ]; then
                api_get_config
            elif [ "$method" = "POST" ]; then
                api_set_config "$query_string"
            fi
            ;;
        "/api/backups")
            if [ "$method" = "GET" ]; then
                api_list_backups
            elif [ "$method" = "POST" ]; then
                api_create_backup "$query_string"
            fi
            ;;
        "/api/restore")
            api_restore_backup "$query_string"
            ;;
        "/api/logs")
            api_get_logs "$query_string"
            ;;
        "/api/hardware")
            api_hardware_status
            ;;
        "/api/recovery")
            api_recovery_control "$query_string"
            ;;
        "/css/"*)
            serve_file "$WEBUI_DIR$path" "text/css"
            ;;
        "/js/"*)
            serve_file "$WEBUI_DIR$path" "application/javascript"
            ;;
        *)
            http_404
            ;;
    esac
}

# Serve static files
serve_file() {
    local file_path="$1"
    local content_type="$2"
    
    if [ -f "$file_path" ]; then
        local file_size=$(stat -c%s "$file_path")
        
        # HTTP response headers
        echo "HTTP/1.1 200 OK"
        echo "Content-Type: $content_type"
        echo "Content-Length: $file_size"
        echo "Connection: close"
        echo ""
        
        # File content
        cat "$file_path"
    else
        http_404
    fi
}

# HTTP 404 response
http_404() {
    echo "HTTP/1.1 404 Not Found"
    echo "Content-Type: text/html"
    echo "Connection: close"
    echo ""
    echo "<html><body><h1>404 Not Found</h1></body></html>"
}

# HTTP JSON response
json_response() {
    local json_data="$1"
    local status_code="${2:-200}"
    
    echo "HTTP/1.1 $status_code OK"
    echo "Content-Type: application/json"
    echo "Access-Control-Allow-Origin: *"
    echo "Connection: close"
    echo ""
    echo "$json_data"
}

# API: Get system status
api_status() {
    local boot_count=$(cat "$BOOT_COUNT_FILE" 2>/dev/null || echo "0")
    local recovery_state=$(get_recovery_state)
    local total_boots=$(cat "$BASE_DIR/total_boots" 2>/dev/null || echo "0")
    local uptime=$(cat /proc/uptime | cut -d' ' -f1)
    
    local json="{
        \"status\": \"running\",
        \"boot_count\": $boot_count,
        \"max_attempts\": $MAX_BOOT_ATTEMPTS,
        \"recovery_state\": \"$recovery_state\",
        \"total_boots\": $total_boots,
        \"uptime\": $uptime,
        \"device\": \"$(getprop ro.product.device)\",
        \"android_version\": \"$(getprop ro.build.version.release)\",
        \"kernel_version\": \"$(uname -r)\",
        \"module_version\": \"2.0\",
        \"safe_mode\": $(is_safe_mode_active && echo "true" || echo "false")
    }"
    
    json_response "$json"
}

# API: Get configuration
api_get_config() {
    # Read current config
    local config_json="{"
    local first=true
    
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        case "$key" in
            \#*|"") continue ;;
        esac
        
        if [ "$first" = true ]; then
            first=false
        else
            config_json="$config_json,"
        fi
        
        config_json="$config_json\"$key\": \"$value\""
    done < "$CONFIG_FILE"
    
    config_json="$config_json}"
    json_response "$config_json"
}

# API: Hardware status
api_hardware_status() {
    local cpu_temp=$(get_cpu_temp)
    local available_ram=$(get_available_ram)
    local storage_health=$(get_storage_health)
    local hardware_issues=$(check_hardware_health)
    
    local json="{
        \"cpu_temperature\": $cpu_temp,
        \"available_ram_mb\": $available_ram,
        \"storage_health\": \"$storage_health\",
        \"hardware_issues\": \"$hardware_issues\",
        \"monitoring\": {
            \"cpu_temp_enabled\": $([ "$MONITOR_CPU_TEMP" = "true" ] && echo "true" || echo "false"),
            \"cpu_temp_threshold\": $CPU_TEMP_THRESHOLD,
            \"ram_enabled\": $([ "$MONITOR_RAM" = "true" ] && echo "true" || echo "false"),
            \"min_free_ram\": $MIN_FREE_RAM
        }
    }"
    
    json_response "$json"
}

# API: List backups
api_list_backups() {
    local backups_json="["
    local first=true
    
    for backup_file in "$BACKUP_DIR"/*.img; do
        if [ -f "$backup_file" ]; then
            local backup_name=$(basename "$backup_file" .img)
            local backup_size=$(stat -c%s "$backup_file" 2>/dev/null || echo "0")
            local backup_date=$(stat -c%y "$backup_file" 2>/dev/null | cut -d'.' -f1)
            local hash_file="$BACKUP_DIR/${backup_name}.sha256"
            local has_hash=$([ -f "$hash_file" ] && echo "true" || echo "false")
            
            if [ "$first" = true ]; then
                first=false
            else
                backups_json="$backups_json,"
            fi
            
            backups_json="$backups_json{
                \"name\": \"$backup_name\",
                \"size\": $backup_size,
                \"created\": \"$backup_date\",
                \"has_hash\": $has_hash
            }"
        fi
    done
    
    backups_json="$backups_json]"
    json_response "$backups_json"
}

# API: Get logs
api_get_logs() {
    local lines="${1:-100}"
    local log_content=""
    
    if [ -f "$LOG_FILE" ]; then
        log_content=$(tail -n "$lines" "$LOG_FILE" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
    fi
    
    local json="{
        \"logs\": \"$log_content\",
        \"lines\": $lines
    }"
    
    json_response "$json"
}

# Create API handlers
create_api_handlers() {
    log_message "INFO" "API handlers initialized"
}

# Main WebUI command handler
case "$1" in
    "start")
        start_webui
        ;;
    "stop")
        stop_webui
        ;;
    "restart")
        stop_webui
        sleep 2
        start_webui
        ;;
    "status")
        if is_webui_running; then
            echo "WebUI server is running on port $WEBUI_PORT"
            echo "PID: $(cat "$PID_FILE")"
        else
            echo "WebUI server is not running"
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        echo ""
        echo "WebUI will be available at: http://localhost:$WEBUI_PORT"
        echo "Or from another device: http://[device-ip]:$WEBUI_PORT"
        exit 1
        ;;
esac