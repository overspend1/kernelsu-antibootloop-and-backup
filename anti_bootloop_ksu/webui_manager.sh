#!/system/bin/sh

# Advanced Anti-Bootloop KSU Module - WebUI Manager
# Author: @overspend1/Wiktor
# Simplified management script for WebUI

MODDIR=${0%/*}
. "$MODDIR/utils.sh"

WEBUI_PID_FILE="$BASE_DIR/webui.pid"
WEBUI_ACCESS_LOG="$BASE_DIR/webui_access.log"

# Check if WebUI is enabled in config
check_webui_enabled() {
    load_config
    [ "$WEBUI_ENABLED" = "true" ]
}

# Start WebUI using busybox httpd if available
start_webui_simple() {
    if ! check_webui_enabled; then
        log_message "INFO" "WebUI is disabled in configuration"
        return 1
    fi
    
    if is_webui_running; then
        log_message "WARN" "WebUI server already running"
        return 1
    fi
    
    # Use busybox httpd if available (more reliable than netcat)
    if command -v busybox >/dev/null 2>&1 && busybox httpd --help >/dev/null 2>&1; then
        log_message "INFO" "Starting WebUI with busybox httpd on port $WEBUI_PORT"
        
        # Create simple CGI handler
        mkdir -p "$BASE_DIR/www/cgi-bin"
        create_cgi_handlers
        
        # Start busybox httpd
        busybox httpd -f -p "$WEBUI_PORT" -h "$MODDIR/webui" -c /system/etc/httpd.conf 2>/dev/null &
        WEBUI_PID=$!
        
        echo "$WEBUI_PID" > "$WEBUI_PID_FILE"
        log_message "INFO" "WebUI started with PID: $WEBUI_PID"
        log_message "INFO" "Access WebUI at: http://localhost:$WEBUI_PORT"
        
        return 0
    else
        log_message "ERROR" "busybox httpd not available, falling back to netcat server"
        return 1
    fi
}

# Create CGI handlers for API endpoints
create_cgi_handlers() {
    # Status API
    cat > "$BASE_DIR/www/cgi-bin/status" << 'EOF'
#!/system/bin/sh
echo "Content-Type: application/json"
echo ""
sh /data/adb/modules/anti_bootloop_advanced_ksu/webui/api/status.sh
EOF
    chmod +x "$BASE_DIR/www/cgi-bin/status"
}

# Check if WebUI is running
is_webui_running() {
    if [ -f "$WEBUI_PID_FILE" ]; then
        local pid=$(cat "$WEBUI_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        else
            rm -f "$WEBUI_PID_FILE"
        fi
    fi
    return 1
}

# Stop WebUI
stop_webui() {
    if [ -f "$WEBUI_PID_FILE" ]; then
        local pid=$(cat "$WEBUI_PID_FILE")
        if kill "$pid" 2>/dev/null; then
            log_message "INFO" "WebUI server stopped (PID: $pid)"
        fi
        rm -f "$WEBUI_PID_FILE"
    else
        log_message "WARN" "WebUI server not running"
    fi
}

# Get WebUI status
webui_status() {
    if is_webui_running; then
        local pid=$(cat "$WEBUI_PID_FILE")
        echo "WebUI server is running on port $WEBUI_PORT (PID: $pid)"
        echo "Access URL: http://localhost:$WEBUI_PORT"
        echo "           http://$(getprop net.hostname):$WEBUI_PORT"
        echo "           http://$(getprop dhcp.wlan0.ipaddress):$WEBUI_PORT"
    else
        echo "WebUI server is not running"
        if ! check_webui_enabled; then
            echo "WebUI is disabled in configuration (WEBUI_ENABLED=false)"
        fi
    fi
}

# Auto-start WebUI if enabled
auto_start() {
    if check_webui_enabled && ! is_webui_running; then
        log_message "INFO" "Auto-starting WebUI server"
        start_webui_simple
    fi
}

# Main command handler
case "$1" in
    "start")
        start_webui_simple
        ;;
    "stop")
        stop_webui
        ;;
    "restart")
        stop_webui
        sleep 2
        start_webui_simple
        ;;
    "status")
        webui_status
        ;;
    "auto")
        auto_start
        ;;
    *)
        echo "Advanced Anti-Bootloop KSU WebUI Manager"
        echo "Author: @overspend1/Wiktor"
        echo ""
        echo "Usage: $0 {start|stop|restart|status|auto}"
        echo ""
        echo "Commands:"
        echo "  start   - Start WebUI server"
        echo "  stop    - Stop WebUI server"  
        echo "  restart - Restart WebUI server"
        echo "  status  - Show WebUI status"
        echo "  auto    - Auto-start if enabled"
        echo ""
        echo "Configuration: Edit WEBUI_ENABLED in config.conf"
        exit 1
        ;;
esac