#!/system/bin/sh
# KernelSU Anti-Bootloop & Backup Module
# Settings Application Script
# Applies configuration changes and restarts services as needed

MODULE_DIR="/data/adb/modules/kernelsu_antibootloop_backup"
CONFIG_DIR="$MODULE_DIR/config"
SETTINGS_FILE="$CONFIG_DIR/settings.json"
LOG_FILE="$MODULE_DIR/logs/settings.log"
WEBUI_PID_FILE="/data/local/tmp/ksu_webui.pid"

# Ensure directories exist
mkdir -p "$MODULE_DIR/logs"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo "$1"
}

# Parse JSON value (simple implementation)
get_json_value() {
    local json_file="$1"
    local key="$2"
    local default_value="$3"
    
    if [ ! -f "$json_file" ]; then
        echo "$default_value"
        return
    fi
    
    # Extract value using grep and sed
    local value=$(grep "\"$key\"" "$json_file" | sed -n 's/.*"'$key'"[[:space:]]*:[[:space:]]*\([^,}]*\).*/\1/p' | tr -d '"' | tr -d ' ')
    
    if [ -z "$value" ]; then
        echo "$default_value"
    else
        echo "$value"
    fi
}

# Check if boolean value is true
is_true() {
    local value="$1"
    case "$value" in
        "true"|"1"|"yes"|"on")
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Apply WebUI settings
apply_webui_settings() {
    log "Applying WebUI settings"
    
    local webui_enabled=$(get_json_value "$SETTINGS_FILE" "webuiEnabled" "true")
    local webui_port=$(get_json_value "$SETTINGS_FILE" "webuiPort" "8080")
    local auth_required=$(get_json_value "$SETTINGS_FILE" "authRequired" "true")
    
    # Update WebUI configuration
    local webui_config="$CONFIG_DIR/webui.conf"
    cat > "$webui_config" << EOF
# WebUI Configuration
PORT=$webui_port
AUTH_REQUIRED=$auth_required
WEBUI_ENABLED=$webui_enabled
EOF
    
    # Restart WebUI if enabled and settings changed
    if is_true "$webui_enabled"; then
        log "WebUI enabled, checking if restart needed"
        
        # Check if WebUI is running and if port changed
        if [ -f "$WEBUI_PID_FILE" ] && [ -f "$MODULE_DIR/scripts/webui-server.sh" ]; then
            local current_pid=$(cat "$WEBUI_PID_FILE" 2>/dev/null)
            if [ -n "$current_pid" ] && kill -0 "$current_pid" 2>/dev/null; then
                log "Stopping existing WebUI (PID: $current_pid)"
                kill "$current_pid" 2>/dev/null || true
                sleep 2
            fi
        fi
        
        # Start WebUI with new settings
        log "Starting WebUI on port $webui_port"
        if [ -f "$MODULE_DIR/scripts/webui-server.sh" ]; then
            sh "$MODULE_DIR/scripts/webui-server.sh" "$webui_port" &
            local new_pid=$!
            echo "$new_pid" > "$WEBUI_PID_FILE"
            log "WebUI started with PID: $new_pid"
        else
            log "WARNING: WebUI server script not found"
        fi
    else
        log "WebUI disabled, stopping if running"
        if [ -f "$WEBUI_PID_FILE" ]; then
            local pid=$(cat "$WEBUI_PID_FILE" 2>/dev/null)
            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                kill "$pid" 2>/dev/null || true
                log "WebUI stopped"
            fi
            rm -f "$WEBUI_PID_FILE"
        fi
    fi
}

# Apply backup settings
apply_backup_settings() {
    log "Applying backup settings"
    
    local auto_backup=$(get_json_value "$SETTINGS_FILE" "autoBackup" "false")
    local backup_schedule=$(get_json_value "$SETTINGS_FILE" "backupSchedule" "weekly")
    local backup_encryption=$(get_json_value "$SETTINGS_FILE" "backupEncryption" "false")
    local backup_compression=$(get_json_value "$SETTINGS_FILE" "backupCompression" "true")
    local storage_path=$(get_json_value "$SETTINGS_FILE" "storagePath" "$CONFIG_DIR/backups")
    
    # Create backup configuration
    local backup_config="$CONFIG_DIR/backup.conf"
    cat > "$backup_config" << EOF
# Backup Configuration
AUTO_BACKUP=$auto_backup
BACKUP_SCHEDULE=$backup_schedule
BACKUP_ENCRYPTION=$backup_encryption
BACKUP_COMPRESSION=$backup_compression
STORAGE_PATH=$storage_path
EOF
    
    # Ensure backup storage directory exists
    mkdir -p "$storage_path"
    
    # Configure automatic backup if enabled
    if is_true "$auto_backup"; then
        log "Automatic backup enabled with schedule: $backup_schedule"
        
        # Setup backup scheduler
        if [ -f "$MODULE_DIR/scripts/backup-scheduler.sh" ]; then
            sh "$MODULE_DIR/scripts/backup-scheduler.sh" setup "$backup_schedule"
        else
            log "WARNING: Backup scheduler script not found"
        fi
    else
        log "Automatic backup disabled"
        
        # Disable backup scheduler
        if [ -f "$MODULE_DIR/scripts/backup-scheduler.sh" ]; then
            sh "$MODULE_DIR/scripts/backup-scheduler.sh" disable
        fi
    fi
}

# Apply safety settings
apply_safety_settings() {
    log "Applying safety settings"
    
    local boot_timeout=$(get_json_value "$SETTINGS_FILE" "bootTimeout" "120")
    local max_boot_attempts=$(get_json_value "$SETTINGS_FILE" "maxBootAttempts" "3")
    local auto_restore=$(get_json_value "$SETTINGS_FILE" "autoRestore" "true")
    local disable_modules=$(get_json_value "$SETTINGS_FILE" "disableModules" "true")
    local safe_mode_timeout=$(get_json_value "$SETTINGS_FILE" "safeModeTimeout" "5")
    
    # Update safety configuration
    local safety_config="$CONFIG_DIR/safety.conf"
    cat > "$safety_config" << EOF
# Safety Configuration
BOOT_TIMEOUT=$boot_timeout
MAX_BOOT_ATTEMPTS=$max_boot_attempts
AUTO_RESTORE=$auto_restore
DISABLE_MODULES=$disable_modules
SAFE_MODE_TIMEOUT=$safe_mode_timeout
EOF
    
    # Update individual config files for compatibility
    echo "$boot_timeout" > "$CONFIG_DIR/boot_timeout.txt"
    echo "$max_boot_attempts" > "$CONFIG_DIR/max_boot_attempts.txt"
    
    # Configure boot monitoring
    if [ -f "$MODULE_DIR/scripts/boot-monitor.sh" ]; then
        # Signal boot monitor to reload configuration
        pkill -USR1 -f "boot-monitor.sh" 2>/dev/null || true
        log "Signaled boot monitor to reload configuration"
    fi
    
    # Configure safe mode
    if [ -f "$MODULE_DIR/scripts/safe-mode.sh" ]; then
        # Update safe mode configuration
        local safe_mode_config="$CONFIG_DIR/safe_mode.conf"
        cat > "$safe_mode_config" << EOF
TIMEOUT=$safe_mode_timeout
DISABLE_MODULES=$disable_modules
AUTO_RESTORE=$auto_restore
EOF
        log "Safe mode configuration updated"
    fi
}

# Apply system settings
apply_system_settings() {
    log "Applying system settings"
    
    local debug_logging=$(get_json_value "$SETTINGS_FILE" "debugLogging" "false")
    local use_overlayfs=$(get_json_value "$SETTINGS_FILE" "useOverlayfs" "true")
    local selinux_mode=$(get_json_value "$SETTINGS_FILE" "selinuxMode" "enforcing")
    
    # Update system configuration
    local system_config="$CONFIG_DIR/system.conf"
    cat > "$system_config" << EOF
# System Configuration
DEBUG_LOGGING=$debug_logging
USE_OVERLAYFS=$use_overlayfs
SELINUX_MODE=$selinux_mode
EOF
    
    # Apply debug logging
    if is_true "$debug_logging"; then
        log "Debug logging enabled"
        export KSU_DEBUG=1
        # Enable verbose logging for scripts
        touch "$CONFIG_DIR/debug_mode"
    else
        log "Debug logging disabled"
        rm -f "$CONFIG_DIR/debug_mode"
    fi
    
    # Configure OverlayFS
    if is_true "$use_overlayfs" && [ -f "$MODULE_DIR/scripts/overlayfs.sh" ]; then
        log "OverlayFS enabled, applying configuration"
        sh "$MODULE_DIR/scripts/overlayfs.sh" configure
    fi
    
    # Note: SELinux mode changes require reboot to take effect
    if [ "$selinux_mode" != "enforcing" ]; then
        log "WARNING: Non-enforcing SELinux mode configured (requires reboot)"
    fi
}

# Apply notification settings
apply_notification_settings() {
    log "Applying notification settings"
    
    local notifications_enabled=$(get_json_value "$SETTINGS_FILE" "notificationsEnabled" "true")
    local backup_notifications=$(get_json_value "$SETTINGS_FILE" "backupNotifications" "true")
    local safety_notifications=$(get_json_value "$SETTINGS_FILE" "safetyNotifications" "true")
    local system_notifications=$(get_json_value "$SETTINGS_FILE" "systemNotifications" "true")
    
    # Update notification configuration
    local notification_config="$CONFIG_DIR/notifications.conf"
    cat > "$notification_config" << EOF
# Notification Configuration
NOTIFICATIONS_ENABLED=$notifications_enabled
BACKUP_NOTIFICATIONS=$backup_notifications
SAFETY_NOTIFICATIONS=$safety_notifications
SYSTEM_NOTIFICATIONS=$system_notifications
EOF
    
    log "Notification settings applied"
}

# Validate settings
validate_settings() {
    log "Validating settings"
    
    if [ ! -f "$SETTINGS_FILE" ]; then
        log "ERROR: Settings file not found: $SETTINGS_FILE"
        return 1
    fi
    
    # Check JSON syntax (basic validation)
    if ! grep -q '{' "$SETTINGS_FILE" || ! grep -q '}' "$SETTINGS_FILE"; then
        log "ERROR: Invalid JSON format in settings file"
        return 1
    fi
    
    # Validate port number
    local webui_port=$(get_json_value "$SETTINGS_FILE" "webuiPort" "8080")
    if [ "$webui_port" -lt 1024 ] || [ "$webui_port" -gt 65535 ]; then
        log "WARNING: WebUI port $webui_port is outside recommended range (1024-65535)"
    fi
    
    # Validate storage path
    local storage_path=$(get_json_value "$SETTINGS_FILE" "storagePath" "$CONFIG_DIR/backups")
    if [ ! -d "$(dirname "$storage_path")" ]; then
        log "WARNING: Storage path parent directory does not exist: $(dirname "$storage_path")"
    fi
    
    # Validate timeout values
    local boot_timeout=$(get_json_value "$SETTINGS_FILE" "bootTimeout" "120")
    if [ "$boot_timeout" -lt 30 ] || [ "$boot_timeout" -gt 600 ]; then
        log "WARNING: Boot timeout $boot_timeout is outside recommended range (30-600 seconds)"
    fi
    
    log "Settings validation completed"
    return 0
}

# Create default settings if not exists
create_default_settings() {
    if [ ! -f "$SETTINGS_FILE" ]; then
        log "Creating default settings file"
        
        cat > "$SETTINGS_FILE" << EOF
{
    "webuiEnabled": true,
    "webuiPort": 8080,
    "authRequired": true,
    "debugLogging": false,
    "backupEncryption": false,
    "backupCompression": true,
    "autoBackup": false,
    "backupSchedule": "weekly",
    "useOverlayfs": true,
    "selinuxMode": "enforcing",
    "storagePath": "$CONFIG_DIR/backups",
    "bootTimeout": 120,
    "maxBootAttempts": 3,
    "autoRestore": true,
    "disableModules": true,
    "safeModeTimeout": 5,
    "notificationsEnabled": true,
    "backupNotifications": true,
    "safetyNotifications": true,
    "systemNotifications": true
}
EOF
        
        log "Default settings created"
    fi
}

# Main function
main() {
    log "Starting settings application process"
    
    # Create default settings if needed
    create_default_settings
    
    # Validate settings
    if ! validate_settings; then
        log "ERROR: Settings validation failed"
        exit 1
    fi
    
    # Apply different categories of settings
    apply_webui_settings
    apply_backup_settings
    apply_safety_settings
    apply_system_settings
    apply_notification_settings
    
    # Log activity
    echo "$(date +%s),system,Settings applied" >> "$CONFIG_DIR/activity.log"
    
    log "Settings application completed successfully"
    echo "Settings applied successfully"
}

# Run main function
main "$@"