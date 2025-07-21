#!/system/bin/sh
# KernelSU Anti-Bootloop Boot Monitor Script

MODDIR=${0%/*}
MODDIR=${MODDIR%/*}
CONFIG_DIR="$MODDIR/config"
BOOTLOG_DIR="$CONFIG_DIR/boot_logs"
RECOVERY_DIR="$CONFIG_DIR/recovery_points"
CHECKPOINT_DIR="$CONFIG_DIR/checkpoints"

# Boot stages with timeout values (in seconds)
BOOT_STAGES="init:30 early_boot:30 boot:30 post_boot:30 system_server:30"

# Maximum allowed boot attempts before recovery
MAX_BOOT_ATTEMPTS=3

# Ensure directories exist
mkdir -p "$BOOTLOG_DIR"
mkdir -p "$RECOVERY_DIR"
mkdir -p "$CHECKPOINT_DIR"

# Log function for debugging
log_message() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$BOOTLOG_DIR/boot_monitor.log"
}

# Log boot attempt and check failure threshold
log_boot_attempt() {
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BOOT_COUNT=$(cat "$CONFIG_DIR/boot_counter" 2>/dev/null || echo "0")
    BOOT_COUNT=$((BOOT_COUNT + 1))
    
    log_message "Recording boot attempt #$BOOT_COUNT"
    
    # Update boot counter
    echo "$BOOT_COUNT" > "$CONFIG_DIR/boot_counter"
    
    # Create boot log entry
    BOOT_LOG="$BOOTLOG_DIR/boot_${TIMESTAMP}.log"
    echo "Boot attempt: $BOOT_COUNT at $(date)" > "$BOOT_LOG"
    echo "Device: $(getprop ro.product.model)" >> "$BOOT_LOG"
    echo "Android version: $(getprop ro.build.version.release)" >> "$BOOT_LOG"
    echo "Kernel: $(uname -r)" >> "$BOOT_LOG"
    
    # Append system logs if available
    if [ -f "/dev/log/main" ]; then
        echo "--- System Logs ---" >> "$BOOT_LOG"
        logcat -d -v time >> "$BOOT_LOG" 2>/dev/null
    fi
    
    # Log all installed modules
    echo "--- Installed KernelSU Modules ---" >> "$BOOT_LOG"
    ls -la /data/adb/modules/ >> "$BOOT_LOG" 2>/dev/null
    
    # Check if we've exceeded the maximum boot attempts
    if [ "$BOOT_COUNT" -ge "$MAX_BOOT_ATTEMPTS" ]; then
        log_message "WARNING: Maximum boot attempts ($MAX_BOOT_ATTEMPTS) reached"
        # Trigger safe mode if maximum boot attempts exceeded
        trigger_safe_mode
    fi
    
    # Reset all checkpoint files on new boot attempt
    rm -f "$CHECKPOINT_DIR"/* 2>/dev/null
    
    # Initialize first checkpoint
    update_boot_checkpoint "init_started"
}

# Update boot checkpoint status
update_boot_checkpoint() {
    CHECKPOINT_NAME="$1"
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    
    # Create checkpoint file
    echo "$TIMESTAMP" > "$CHECKPOINT_DIR/$CHECKPOINT_NAME"
    log_message "Checkpoint reached: $CHECKPOINT_NAME"
    
    # Log to current boot log
    CURRENT_BOOT_LOG=$(ls -t "$BOOTLOG_DIR"/boot_*.log | head -1)
    if [ -f "$CURRENT_BOOT_LOG" ]; then
        echo "[$TIMESTAMP] Checkpoint: $CHECKPOINT_NAME" >> "$CURRENT_BOOT_LOG"
    fi
}

# Check if a checkpoint was reached
check_checkpoint() {
    if [ -z "$1" ]; then
        log_message "ERROR: check_checkpoint called without checkpoint name"
        return 2
    fi
    
    CHECKPOINT_NAME="$1"
    if [ -f "$CHECKPOINT_DIR/$CHECKPOINT_NAME" ]; then
        return 0
    else
        return 1
    fi
}

# Trigger safe mode when bootloop detected
trigger_safe_mode() {
    log_message "CRITICAL: Bootloop detected - Triggering safe mode"
    
    # Create bootloop marker
    echo "1" > "$CONFIG_DIR/bootloop_detected"
    
    # Record last checkpoint reached
    LAST_CHECKPOINT=$(ls -t "$CHECKPOINT_DIR"/* 2>/dev/null | head -1)
    LAST_STAGE=$(basename "$LAST_CHECKPOINT" 2>/dev/null || echo "unknown")
    echo "$LAST_STAGE" > "$CONFIG_DIR/failed_boot_stage"
    
    # Create bootloop report
    REPORT_FILE="$BOOTLOG_DIR/bootloop_report_$(date +"%Y%m%d_%H%M%S").log"
    echo "===== BOOTLOOP DETECTED =====" > "$REPORT_FILE"
    echo "Maximum boot attempts ($MAX_BOOT_ATTEMPTS) reached" >> "$REPORT_FILE"
    echo "Last checkpoint reached: $LAST_STAGE" >> "$REPORT_FILE"
    echo "Device: $(getprop ro.product.model)" >> "$REPORT_FILE"
    echo "Android version: $(getprop ro.build.version.release)" >> "$REPORT_FILE"
    echo "Timestamp: $(date)" >> "$REPORT_FILE"
    echo >> "$REPORT_FILE"
    echo "=== Installed Modules ===" >> "$REPORT_FILE"
    ls -la /data/adb/modules/ >> "$REPORT_FILE" 2>/dev/null
    
    # Try to restore from recovery point if available
    if [ -d "$RECOVERY_DIR" ] && [ "$(ls -A "$RECOVERY_DIR" 2>/dev/null)" ]; then
        log_message "Attempting recovery from last known good state"
        # In a real implementation, this would restore from the recovery point
        # using the recovery mechanism we'll implement later
    fi
    
    # Disable problematic modules (placeholder)
    log_message "Disabling modules for safe boot"
    # In a real implementation, this would disable KernelSU modules to allow safe boot
}

# Setup failsafe timer for each boot stage
setup_failsafe_timer() {
    log_message "Setting up boot stage timeouts"
    
    # Create default main.conf if it doesn't exist
    if [ ! -f "$CONFIG_DIR/main.conf" ]; then
        mkdir -p "$CONFIG_DIR" 2>/dev/null
        if ! echo "boot_timeout=30" > "$CONFIG_DIR/main.conf"; then
            log_message "ERROR: Failed to write to main.conf"
        fi
        echo "bootloop_detection=true" >> "$CONFIG_DIR/main.conf"
        echo "safe_mode_enabled=true" >> "$CONFIG_DIR/main.conf"
    fi
    
    # Read global timeout from config
    BOOT_TIMEOUT=$(grep "boot_timeout" "$CONFIG_DIR/main.conf" | cut -d= -f2 || echo "30")
    log_message "Global boot stage timeout: $BOOT_TIMEOUT seconds"
    
    # Launch timer monitor in background
    (
        # Wait a moment to allow boot process to start
        sleep 2
        
        # Create first checkpoint if not exist
        if ! check_checkpoint "init_started"; then
            update_boot_checkpoint "init_started"
        fi
        
        # Monitor each boot stage with timeout
        for STAGE_CONFIG in $BOOT_STAGES; do
            STAGE_NAME=${STAGE_CONFIG%%:*}
            STAGE_TIMEOUT=${STAGE_CONFIG##*:}
            
            log_message "Monitoring boot stage: $STAGE_NAME (timeout: ${STAGE_TIMEOUT}s)"
            
            # Create checkpoint file for this stage
            update_boot_checkpoint "${STAGE_NAME}_started"
            
            # Wait for timeout
            SECONDS_WAITED=0
            while [ $SECONDS_WAITED -lt $STAGE_TIMEOUT ]; do
                sleep 5
                SECONDS_WAITED=$((SECONDS_WAITED + 5))
                
                # Check if boot completed
                if [ "$(getprop sys.boot_completed)" = "1" ]; then
                    log_message "Boot completed, exiting timer"
                    update_boot_checkpoint "boot_completed"
                    exit 0
                fi
                
                # Check if next stage started
                NEXT_STAGE=$(echo "$BOOT_STAGES" | sed -e "s/.*$STAGE_NAME:[0-9]* \(.*\):.*/\1/")
                if [ "$NEXT_STAGE" != "$BOOT_STAGES" ] && check_checkpoint "${NEXT_STAGE}_started"; then
                    log_message "Stage $STAGE_NAME completed, moving to next stage"
                    break
                fi
            done
            
            # Check if stage timed out
            if [ $SECONDS_WAITED -ge $STAGE_TIMEOUT ] && [ "$(getprop sys.boot_completed)" != "1" ]; then
                log_message "WARNING: Boot stage $STAGE_NAME timed out after ${STAGE_TIMEOUT}s"
                update_boot_checkpoint "${STAGE_NAME}_timeout"
                
                # Record failure in boot log
                CURRENT_BOOT_LOG=$(ls -t "$BOOTLOG_DIR"/boot_*.log | head -1)
                if [ -f "$CURRENT_BOOT_LOG" ]; then
                    echo "ERROR: Boot stage $STAGE_NAME timed out after ${STAGE_TIMEOUT}s" >> "$CURRENT_BOOT_LOG"
                fi
                
                # If this was the last expected stage, trigger safe mode
                if [ "$STAGE_NAME" = "system_server" ]; then
                    log_message "CRITICAL: Final boot stage timed out, triggering safe mode"
                    trigger_safe_mode
                    exit 1
                fi
            fi
        done
        
        # Final timeout check for complete boot
        log_message "Waiting for final boot completion signal"
        SECONDS_WAITED=0
        while [ $SECONDS_WAITED -lt $BOOT_TIMEOUT ]; do
            sleep 5
            SECONDS_WAITED=$((SECONDS_WAITED + 5))
            
            # Check if boot completed
            if [ "$(getprop sys.boot_completed)" = "1" ]; then
                log_message "Boot completed successfully"
                update_boot_checkpoint "boot_completed"
                exit 0
            fi
        done
        
        # Boot didn't complete within timeout
        log_message "CRITICAL: Boot did not complete within final timeout period"
        update_boot_checkpoint "boot_complete_timeout"
        trigger_safe_mode
    ) &
    
    # Save background PID for later reference
    echo $! > "$CONFIG_DIR/timer_monitor.pid"
    log_message "Boot timer monitor started with PID: $!"
}

# Create a recovery point
create_recovery_point() {
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    RECOVERY_POINT="$RECOVERY_DIR/recovery_${TIMESTAMP}"
    
    log_message "Creating boot recovery point: $RECOVERY_POINT"
    
    mkdir -p "$RECOVERY_POINT"
    
    # Create recovery point info file
    echo "Recovery point created at: $(date)" > "$RECOVERY_POINT/info.txt"
    echo "Device: $(getprop ro.product.model)" >> "$RECOVERY_POINT/info.txt"
    echo "Android version: $(getprop ro.build.version.release)" >> "$RECOVERY_POINT/info.txt"
    echo "KernelSU version: $(cat /data/adb/ksu/version 2>/dev/null || echo "Unknown")" >> "$RECOVERY_POINT/info.txt"
    
    # Create list of active modules
    mkdir -p "$RECOVERY_POINT/modules"
    if [ -d "/data/adb/modules" ]; then
        ls -la /data/adb/modules/ > "$RECOVERY_POINT/modules/list.txt"
        
        # Save modules state
        for MODULE_DIR in /data/adb/modules/*; do
            if [ -d "$MODULE_DIR" ]; then
                MODULE_NAME=$(basename "$MODULE_DIR")
                mkdir -p "$RECOVERY_POINT/modules/$MODULE_NAME"
                
                # Save module properties
                if [ -f "$MODULE_DIR/module.prop" ]; then
                    cp "$MODULE_DIR/module.prop" "$RECOVERY_POINT/modules/$MODULE_NAME/"
                fi
                
                # Check if module is disabled
                if [ -f "$MODULE_DIR/disable" ]; then
                    touch "$RECOVERY_POINT/modules/$MODULE_NAME/disable"
                fi
                
                # Check module state
                if [ -f "$MODULE_DIR/remove" ]; then
                    touch "$RECOVERY_POINT/modules/$MODULE_NAME/remove"
                fi
            fi
        done
    fi
    
    # Save system properties
    mkdir -p "$RECOVERY_POINT/system"
    getprop > "$RECOVERY_POINT/system/properties.txt"
    
    # Save loaded kernel modules
    lsmod > "$RECOVERY_POINT/system/kernel_modules.txt" 2>/dev/null
    
    # Save mount points
    mount > "$RECOVERY_POINT/system/mounts.txt"
    
    # Create restore script for this recovery point
    cat > "$RECOVERY_POINT/restore.sh" << EOF
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
    chmod +x "$RECOVERY_POINT/restore.sh"
    
    log_message "Recovery point created successfully"
}

# Setup OverlayFS for safe system modifications
setup_overlayfs() {
    log_message "Setting up OverlayFS protection"
    
    # Call the dedicated overlayfs script
    if [ -f "$MODDIR/scripts/overlayfs.sh" ]; then
        sh "$MODDIR/scripts/overlayfs.sh"
        OVERLAY_STATUS=$?
        
        if [ $OVERLAY_STATUS -eq 0 ]; then
            log_message "OverlayFS setup completed successfully"
            update_boot_checkpoint "overlayfs_mounted"
        else
            log_message "WARNING: OverlayFS setup failed with status $OVERLAY_STATUS"
            update_boot_checkpoint "overlayfs_failed"
        fi
    else
        log_message "ERROR: overlayfs.sh script not found"
    fi
}

# Check if hardware key combination is pressed
check_hardware_keys() {
    log_message "Checking hardware key combination"
    
    # Call the dedicated safety service script to check hardware keys
    if [ -f "$MODDIR/scripts/safety-service.sh" ]; then
        sh "$MODDIR/scripts/safety-service.sh" check_keys
        KEY_STATUS=$?
        
        if [ $KEY_STATUS -eq 10 ]; then
            log_message "Hardware key recovery combination detected"
            update_boot_checkpoint "hardware_recovery_triggered"
            return 10
        fi
    else
        log_message "WARNING: safety-service.sh script not found for key detection"
    fi
    
    return 0
}

# Main function
main() {
    log_message "Boot monitor started"
    
    # Check if hardware recovery keys are pressed
    check_hardware_keys
    KEY_STATUS=$?
    if [ $KEY_STATUS -eq 10 ]; then
        log_message "Entering recovery mode due to hardware key detection"
        trigger_safe_mode
        return
    fi
    
    # Log the boot attempt
    log_boot_attempt
    
    # Create a recovery point if needed
    if [ ! -d "$RECOVERY_DIR" ] || [ $(ls -1 "$RECOVERY_DIR" | wc -l) -eq 0 ]; then
        # No recovery points exist, create one
        create_recovery_point
    fi
    
    # Setup failsafe boot timer
    setup_failsafe_timer
    
    # Setup OverlayFS protection
    setup_overlayfs
    
    log_message "Boot monitoring initialized successfully"
}

# Execute main function
main