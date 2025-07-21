#!/system/bin/sh
# KernelSU Anti-Bootloop & Backup Module
# service.sh - Runs at boot stage

MODDIR=${0%/*}
MODDIR=${MODDIR%/*}
CONFIG_DIR="$MODDIR/config"
BOOTLOG_DIR="$CONFIG_DIR/boot_logs"
RECOVERY_DIR="$CONFIG_DIR/recovery_points"
SAFEMODE_DIR="$CONFIG_DIR/safe_mode"
CHECKPOINT_DIR="$CONFIG_DIR/checkpoints"

# Log function
log_message() {
    echo "service: $1" >> "$MODDIR/scripts/module.log"
}

log_message "Starting service execution"

# Create boot checkpoint - boot stage reached
if [ -d "$CHECKPOINT_DIR" ]; then
    log_message "Creating boot stage checkpoint"
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    echo "$TIMESTAMP" > "$CHECKPOINT_DIR/boot_stage_reached"
fi

# Check if we're in safe mode
is_safe_mode() {
    if [ -f "$SAFEMODE_DIR/active" ] || [ -f "$CONFIG_DIR/bootloop_detected" ] || [ -f "$SAFEMODE_DIR/manual_trigger" ]; then
        return 0
    else
        return 1
    fi
}

# Start safety monitoring service
# This handles ongoing monitoring and safety features
if [ -f "$MODDIR/scripts/safety-service.sh" ]; then
    # Check if we're in safe mode
    is_safe_mode
    SAFE_MODE=$?
    
    if [ $SAFE_MODE -eq 0 ]; then
        log_message "Safe mode active, starting safety service with recovery options"
        nohup sh "$MODDIR/scripts/safety-service.sh" safe_mode >/dev/null 2>&1 &
    else
        log_message "Starting safety service"
        nohup sh "$MODDIR/scripts/safety-service.sh" >/dev/null 2>&1 &
    fi
    
    log_message "Safety service started with PID: $!"
else
    log_message "Warning: safety-service.sh not found"
fi

# Wait for system to fully boot
# This ensures that our services start only after system is ready
(
    # Wait for boot completed
    while [ "$(getprop sys.boot_completed)" != "1" ]; do
        sleep 1
    done
    
    log_message "System boot completed"
    
    # Create boot checkpoint - system boot completed
    if [ -d "$CHECKPOINT_DIR" ]; then
        log_message "Creating boot completed checkpoint"
        TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
        echo "$TIMESTAMP" > "$CHECKPOINT_DIR/boot_completed"
    fi
    
    # Update boot status
    echo "1" > "$CONFIG_DIR/boot_completed"
    
    # Check if we're in safe mode
    is_safe_mode
    SAFE_MODE=$?
    
    if [ $SAFE_MODE -eq 0 ]; then
        log_message "Safe mode active, launching recovery interface"
        
        # Show safe mode notification
        if command -v am >/dev/null 2>&1; then
            am broadcast -a android.intent.action.BOOT_COMPLETED
            am start -a android.intent.action.VIEW -d "http://localhost:8080/safemode" >/dev/null 2>&1
        fi
    fi
    
    # Start WebUI server if enabled
    if [ -f "$MODDIR/scripts/webui-server.sh" ]; then
        # Check if WebUI is enabled in configuration
        WEBUI_ENABLED=$(grep "webui_enabled" "$MODDIR/config/main.conf" | cut -d= -f2 || echo "true")
        
        if [ "$WEBUI_ENABLED" == "true" ]; then
            log_message "Starting WebUIX server"
            nohup sh "$MODDIR/scripts/webui-server.sh" >/dev/null 2>&1 &
            log_message "WebUIX server started with PID: $!"
        else
            log_message "WebUIX server is disabled in configuration"
        fi
    else
        log_message "Warning: webui-server.sh not found"
    fi
    
    # Execute scheduled backup if auto-backup is enabled
    if [ -f "$MODDIR/scripts/backup-engine.sh" ]; then
        # Check if auto-backup is enabled in configuration
        AUTO_BACKUP=$(grep "auto_backup" "$MODDIR/config/main.conf" | cut -d= -f2 || echo "false")
        
        if [ "$AUTO_BACKUP" == "true" ]; then
            log_message "Starting scheduled auto-backup"
            
            # Create backup name with timestamp
            BACKUP_NAME="AutoBackup_$(date +"%Y%m%d_%H%M%S")"
            
            # Execute backup with default profile
            nohup sh "$MODDIR/scripts/backup-engine.sh" backup default "$BACKUP_NAME" >/dev/null 2>&1 &
            log_message "Auto-backup started with PID: $!"
        else
            log_message "Auto-backup is disabled in configuration"
        fi
    else
        log_message "Warning: backup-engine.sh not found"
    fi
    
    # Execute boot-completed script for final boot operations
    if [ -f "$MODDIR/scripts/boot-completed.sh" ]; then
        log_message "Executing boot-completed.sh"
        sh "$MODDIR/scripts/boot-completed.sh"
        
        # Check if the boot was successful
        if [ $? -eq 0 ]; then
            log_message "Boot completed successfully"
            
            # Reset boot counter since we booted successfully
            echo "0" > "$CONFIG_DIR/boot_counter"
            
            # Clear any bootloop detection flags
            if [ -f "$CONFIG_DIR/bootloop_detected" ]; then
                log_message "Clearing bootloop detection flag after successful boot"
                rm -f "$CONFIG_DIR/bootloop_detected"
            fi
            
            # Clear any manual safe mode triggers if boot was successful
            if [ -f "$SAFEMODE_DIR/manual_trigger" ]; then
                log_message "Clearing manual safe mode trigger after successful boot"
                rm -f "$SAFEMODE_DIR/manual_trigger"
            fi
        else
            log_message "Warning: boot-completed.sh returned error status"
        fi
    else
        log_message "Warning: boot-completed.sh not found"
    fi
    
    log_message "All post-boot services started successfully"
) &

log_message "Service execution completed, waiting for boot completion in background"