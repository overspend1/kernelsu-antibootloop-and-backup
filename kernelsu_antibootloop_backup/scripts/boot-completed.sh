#!/system/bin/sh
# KernelSU Anti-Bootloop & Backup Module
# boot-completed.sh - Runs after boot has completed

MODDIR=${0%/*}
MODDIR=${MODDIR%/*}
CONFIG_DIR="$MODDIR/config"
BOOTLOG_DIR="$CONFIG_DIR/boot_logs"
RECOVERY_DIR="$CONFIG_DIR/recovery_points"
SAFEMODE_DIR="$CONFIG_DIR/safe_mode"
CHECKPOINT_DIR="$CONFIG_DIR/checkpoints"

# Log function
log_message() {
    echo "boot-completed: $1" >> "$MODDIR/scripts/module.log"
}

log_message "Starting boot-completed execution"

# Create boot checkpoint - final stage reached
if [ -d "$CHECKPOINT_DIR" ]; then
    log_message "Creating final boot stage checkpoint"
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    echo "$TIMESTAMP" > "$CHECKPOINT_DIR/boot_completed_final"
fi

# Check if we're in safe mode
is_safe_mode() {
    if [ -f "$SAFEMODE_DIR/active" ] || [ -f "$CONFIG_DIR/bootloop_detected" ] || [ -f "$SAFEMODE_DIR/manual_trigger" ]; then
        return 0
    else
        return 1
    fi
}

# Reset boot counter since we successfully booted
# This is critical for the anti-bootloop protection
log_message "Boot completed successfully, resetting boot counter"
echo "0" > "$CONFIG_DIR/boot_counter"
log_message "Boot counter reset to 0 (successful boot)"

# Handle safe mode status
is_safe_mode
SAFE_MODE=$?
if [ $SAFE_MODE -eq 0 ]; then
    log_message "System is in safe mode, maintaining recovery environment"
else
    # Clean up any leftover safe mode indicators
    if [ -f "$SAFEMODE_DIR/active" ]; then
        log_message "Clearing safe mode status after successful boot"
        rm -f "$SAFEMODE_DIR/active"
    fi
    
    if [ -f "$CONFIG_DIR/bootloop_detected" ]; then
        log_message "Clearing bootloop detection flag after successful boot"
        rm -f "$CONFIG_DIR/bootloop_detected"
    fi
    
    if [ -f "$SAFEMODE_DIR/manual_trigger" ]; then
        log_message "Clearing manual safe mode trigger after successful boot"
        rm -f "$SAFEMODE_DIR/manual_trigger"
    fi
fi

# Create a boot success marker
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
echo "Boot completed successfully at $TIMESTAMP" > "$MODDIR/config/boot_logs/boot_success_${TIMESTAMP}.log"

# System verification
verify_system() {
    log_message "Verifying system integrity"
    
    # Check critical system services
    ZYGOTE_RUNNING=$(ps -A | grep zygote | wc -l)
    SYSTEM_SERVER_RUNNING=$(ps -A | grep system_server | wc -l)
    
    if [ "$ZYGOTE_RUNNING" -gt 0 ] && [ "$SYSTEM_SERVER_RUNNING" -gt 0 ]; then
        log_message "Core system services are running"
        return 0
    else
        log_message "Warning: Some core system services may not be running properly"
        return 1
    fi
}

# Create recovery point after successful boot
create_recovery_point() {
    log_message "Creating successful boot recovery point"
    
    # Get total recovery points
    RECOVERY_COUNT=$(ls -1 "$RECOVERY_DIR" 2>/dev/null | wc -l)
    
    # Only create new recovery point if we have less than 3
    # This prevents filling up storage with too many recovery points
    if [ "$RECOVERY_COUNT" -lt 3 ]; then
        RECOVERY_POINT_DIR="$RECOVERY_DIR/recovery_${TIMESTAMP}"
        mkdir -p "$RECOVERY_POINT_DIR"
        
        # Log recovery point information
        echo "Recovery point created at: $(date)" > "$RECOVERY_POINT_DIR/info.txt"
        echo "Android version: $(getprop ro.build.version.release)" >> "$RECOVERY_POINT_DIR/info.txt"
        echo "Device: $(getprop ro.product.model)" >> "$RECOVERY_POINT_DIR/info.txt"
        echo "KernelSU version: $(cat /data/adb/ksu/version 2>/dev/null || echo "Unknown")" >> "$RECOVERY_POINT_DIR/info.txt"
        
        # Create list of active modules
        mkdir -p "$RECOVERY_POINT_DIR/modules"
        if [ -d "/data/adb/modules" ]; then
            ls -la /data/adb/modules/ > "$RECOVERY_POINT_DIR/modules/list.txt"
            
            # Save modules state
            for MODULE_DIR in /data/adb/modules/*; do
                if [ -d "$MODULE_DIR" ]; then
                    MODULE_NAME=$(basename "$MODULE_DIR")
                    mkdir -p "$RECOVERY_POINT_DIR/modules/$MODULE_NAME"
                    
                    # Save module properties
                    if [ -f "$MODULE_DIR/module.prop" ]; then
                        cp "$MODULE_DIR/module.prop" "$RECOVERY_POINT_DIR/modules/$MODULE_NAME/"
                    fi
                    
                    # Check if module is disabled
                    if [ -f "$MODULE_DIR/disable" ]; then
                        touch "$RECOVERY_POINT_DIR/modules/$MODULE_NAME/disable"
                    fi
                    
                    # Check module state
                    if [ -f "$MODULE_DIR/remove" ]; then
                        touch "$RECOVERY_POINT_DIR/modules/$MODULE_NAME/remove"
                    fi
                fi
            done
        fi
        
        # Save system properties
        mkdir -p "$RECOVERY_POINT_DIR/system"
        getprop > "$RECOVERY_POINT_DIR/system/properties.txt"
        
        # Save loaded kernel modules
        lsmod > "$RECOVERY_POINT_DIR/system/kernel_modules.txt" 2>/dev/null
        
        # Save mount points
        mount > "$RECOVERY_POINT_DIR/system/mounts.txt"
        
        # Create restore script for this recovery point
        cat > "$RECOVERY_POINT_DIR/restore.sh" << EOF
#!/system/bin/sh
# Auto-generated restore script for recovery point $TIMESTAMP
MODDIR=\${0%/*}
MODDIR=\${MODDIR%/*}
MODDIR=\${MODDIR%/*}

# Log function
log_message() {
    echo "[\$(date)] restore: \$1" >> "\$MODDIR/scripts/module.log"
}

log_message "Restoring from recovery point $TIMESTAMP"

# Disable all modules first
if [ -d "/data/adb/modules" ]; then
    for MODULE in /data/adb/modules/*; do
        if [ -d "\$MODULE" ] && [ ! -f "\$MODULE/disable" ]; then
            MODULE_NAME=\$(basename "\$MODULE")
            log_message "Disabling module \$MODULE_NAME"
            touch "\$MODULE/disable"
        fi
    done
fi

# Re-enable modules that were active in recovery point
for MODULE_DIR in "\$MODDIR/config/recovery_points/recovery_${TIMESTAMP}/modules/"*; do
    if [ -d "\$MODULE_DIR" ] && [ ! -f "\$MODULE_DIR/disable" ]; then
        MODULE_NAME=\$(basename "\$MODULE_DIR")
        if [ -d "/data/adb/modules/\$MODULE_NAME" ]; then
            log_message "Re-enabling module \$MODULE_NAME"
            rm -f "/data/adb/modules/\$MODULE_NAME/disable"
        fi
    fi
done

log_message "Recovery completed"
EOF

        # Make restore script executable
        chmod +x "$RECOVERY_POINT_DIR/restore.sh"
        
        log_message "Recovery point created: $RECOVERY_POINT_DIR"
    else
        log_message "Maximum recovery points reached, removing oldest and creating new one"
        
        # Remove oldest recovery point
        OLDEST_POINT=$(ls -1t "$RECOVERY_DIR" | tail -1)
        if [ ! -z "$OLDEST_POINT" ]; then
            log_message "Removing oldest recovery point: $OLDEST_POINT"
            rm -rf "$RECOVERY_DIR/$OLDEST_POINT"
            
            # Now create the new recovery point (recursive call)
            create_recovery_point
        fi
    fi
}

# Clean up old logs
cleanup_old_logs() {
    log_message "Cleaning up old logs"
    
    # Keep only the 10 most recent boot logs
    if [ -d "$MODDIR/config/boot_logs" ]; then
        LOGS_TO_DELETE=$(ls -1t "$MODDIR/config/boot_logs" | tail -n +11)
        if [ ! -z "$LOGS_TO_DELETE" ]; then
            for LOG in $LOGS_TO_DELETE; do
                rm -f "$MODDIR/config/boot_logs/$LOG"
            done
            log_message "Deleted $(echo "$LOGS_TO_DELETE" | wc -l) old boot logs"
        fi
    fi
    
    # Limit main log file size
    if [ -f "$MODDIR/scripts/module.log" ] && [ $(stat -c%s "$MODDIR/scripts/module.log") -gt 1048576 ]; then
        # If log is larger than 1MB, keep only the last 1000 lines
        tail -n 1000 "$MODDIR/scripts/module.log" > "$MODDIR/scripts/module.log.new"
        mv "$MODDIR/scripts/module.log.new" "$MODDIR/scripts/module.log"
        log_message "Trimmed module.log to last 1000 lines"
    fi
}

# Display boot notification (if device is unlocked)
show_boot_notification() {
    log_message "Attempting to show boot notification"
    
    # Check if device is unlocked
    SCREEN_STATE=$(dumpsys power | grep "mHoldingDisplaySuspendBlocker" | grep "true" | wc -l)
    
    if [ "$SCREEN_STATE" -gt 0 ]; then
        # Device screen is on, try to show notification
        am start -a android.intent.action.VIEW -d "http://localhost:8080" >/dev/null 2>&1
        log_message "Boot notification displayed"
    else
        log_message "Screen is off, skipping boot notification"
    fi
}

# Clear pending transaction if any
clear_pending_transactions() {
    if [ -d "$CONFIG_DIR/transactions" ] && [ -f "$CONFIG_DIR/transactions/current" ]; then
        TRANSACTION_ID=$(cat "$CONFIG_DIR/transactions/current" 2>/dev/null)
        if [ ! -z "$TRANSACTION_ID" ]; then
            log_message "Committing pending transaction: $TRANSACTION_ID"
            
            # Source overlayfs script to get access to commit function
            if [ -f "$MODDIR/scripts/overlayfs.sh" ]; then
                . "$MODDIR/scripts/overlayfs.sh"
                commit_transaction "$TRANSACTION_ID"
            else
                # Simple fallback if script not available
                echo "2" > "$CONFIG_DIR/transactions/$TRANSACTION_ID/state"
                rm -f "$CONFIG_DIR/transactions/current"
            fi
        fi
    fi
}

# Main function
main() {
    # Verify system integrity
    verify_system
    
    # Create recovery point only if not in safe mode
    is_safe_mode
    SAFE_MODE=$?
    if [ $SAFE_MODE -eq 0 ]; then
        log_message "System in safe mode, skipping recovery point creation"
    else
        # Create recovery point after successful boot
        create_recovery_point
        
        # Clear any pending transactions
        clear_pending_transactions
    fi
    
    # Clean up old logs
    cleanup_old_logs
    
    # Wait a moment to ensure system is fully initialized
    sleep 5
    
    # Show boot notification if appropriate
    is_safe_mode
    SAFE_MODE=$?
    if [ $SAFE_MODE -eq 0 ]; then
        # In safe mode, show recovery notification
        show_boot_notification
    else
        # Normal boot, show regular notification if configured
        SHOW_NOTIFICATIONS=$(grep "show_notifications" "$CONFIG_DIR/main.conf" | cut -d= -f2 || echo "false")
        if [ "$SHOW_NOTIFICATIONS" = "true" ]; then
            show_boot_notification
        fi
    fi
    
    # Record system stats
    log_message "System memory: $(free | grep Mem | awk '{print $3"/"$2" used"}')"
    log_message "System uptime: $(uptime)"
    
    log_message "Boot completed successfully!"
    return 0
}

# Execute main function
main