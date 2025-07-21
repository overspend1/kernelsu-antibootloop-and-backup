#!/system/bin/sh
# KernelSU Anti-Bootloop Safe Mode Bootstrap Script

MODDIR=${0%/*}
MODDIR=${MODDIR%/*}
CONFIG_DIR="$MODDIR/config"
BOOTLOG_DIR="$CONFIG_DIR/boot_logs"
RECOVERY_DIR="$CONFIG_DIR/recovery_points"
SAFEMODE_DIR="$CONFIG_DIR/safe_mode"

# Safety levels
SAFETY_LEVEL_MINIMAL=1     # Only disable problematic modules
SAFETY_LEVEL_MODERATE=2    # Disable all modules except essential ones
SAFETY_LEVEL_AGGRESSIVE=3  # Disable all modules including this one
SAFETY_LEVEL_EXTREME=4     # Factory reset (data wipe) as last resort

# Ensure directories exist
mkdir -p "$BOOTLOG_DIR"
mkdir -p "$RECOVERY_DIR"
mkdir -p "$SAFEMODE_DIR"

# Log function for debugging
log_message() {
    if [ ! -d "$BOOTLOG_DIR" ]; then
        mkdir -p "$BOOTLOG_DIR" 2>/dev/null
    fi
    
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$BOOTLOG_DIR/safe_mode.log" 2>/dev/null
}

log_message "Safe Mode Bootstrap started"

# Determine if we're in safe mode
is_safe_mode() {
    if [ -f "$SAFEMODE_DIR/active" ] || [ -f "$CONFIG_DIR/bootloop_detected" ] || [ -f "$SAFEMODE_DIR/manual_trigger" ]; then
        return 0
    else
        return 1
    fi
}

# Create safemode notification
create_safemode_notification() {
    log_message "Creating safe mode notification"
    
    # Create notification file
    echo "SAFE_MODE_ACTIVE" > "$SAFEMODE_DIR/active"
    echo "$(date +"%Y%m%d_%H%M%S")" > "$SAFEMODE_DIR/activated_time"
    
    # Create notification in system
    if [ -d "/data/system/notification" ]; then
        cat > "/data/system/notification/safemode.txt" << EOF
KernelSU Safe Mode Active
Your device has been booted in safe mode due to boot issues.
Most modules have been temporarily disabled to ensure stability.
Tap for more information.
EOF
    fi
    
    # Show toast message (if possible)
    if command -v am >/dev/null 2>&1; then
        am broadcast -a android.intent.action.BOOT_COMPLETED -p android
        am startservice -n com.android.systemui/.SystemUIService
        am broadcast -a android.intent.action.CLOSE_SYSTEM_DIALOGS
        am start -a android.intent.action.VIEW -d "http://localhost:8080/safemode" >/dev/null 2>&1
    fi
}

# Get appropriate safety level based on boot attempts
get_safety_level() {
    # Read boot counter
    BOOT_COUNT=$(cat "$CONFIG_DIR/boot_counter" 2>/dev/null || echo "0")
    
    # Read previous safety level if exists
    PREV_LEVEL=$(cat "$SAFEMODE_DIR/safety_level" 2>/dev/null || echo "0")
    
    # Determine safety level based on boot count and previous level
    if [ "$BOOT_COUNT" -ge 6 ]; then
        # Extreme measures after 6 failed boots
        echo "$SAFETY_LEVEL_EXTREME"
    elif [ "$BOOT_COUNT" -ge 5 ]; then
        # Aggressive measures after 5 failed boots
        echo "$SAFETY_LEVEL_AGGRESSIVE"
    elif [ "$BOOT_COUNT" -ge 3 ] || [ "$PREV_LEVEL" -eq "$SAFETY_LEVEL_MINIMAL" ]; then
        # Moderate measures after 3 failed boots or if minimal didn't help
        echo "$SAFETY_LEVEL_MODERATE"
    else
        # Start with minimal measures
        echo "$SAFETY_LEVEL_MINIMAL"
    fi
}

# Initialize safe mode with appropriate safety level
initialize_safe_mode() {
    log_message "Initializing safe mode"
    
    # Ensure directory exists
    mkdir -p "$SAFEMODE_DIR" 2>/dev/null
    
    # Determine safety level
    SAFETY_LEVEL=$(get_safety_level)
    log_message "Using safety level: $SAFETY_LEVEL"
    
    # Save current safety level
    if ! echo "$SAFETY_LEVEL" > "$SAFEMODE_DIR/safety_level" 2>/dev/null; then
        log_message "WARNING: Failed to write safety level to file"
    fi
    
    # Create safe mode report
    REPORT_FILE="$BOOTLOG_DIR/safemode_report_$(date +"%Y%m%d_%H%M%S").log"
    echo "===== SAFE MODE ACTIVATED =====" > "$REPORT_FILE"
    echo "Safety Level: $SAFETY_LEVEL" >> "$REPORT_FILE"
    
    if [ -f "$CONFIG_DIR/bootloop_detected" ]; then
        echo "Reason: Bootloop detected" >> "$REPORT_FILE"
        if [ -f "$CONFIG_DIR/failed_boot_stage" ]; then
            FAILED_STAGE=$(cat "$CONFIG_DIR/failed_boot_stage")
            echo "Failed at boot stage: $FAILED_STAGE" >> "$REPORT_FILE"
        fi
    elif [ -f "$SAFEMODE_DIR/manual_trigger" ]; then
        echo "Reason: Manually triggered by user" >> "$REPORT_FILE"
    else
        echo "Reason: Unknown" >> "$REPORT_FILE"
    fi
    
    echo "Boot Attempts: $BOOT_COUNT" >> "$REPORT_FILE"
    echo "Device: $(getprop ro.product.model)" >> "$REPORT_FILE"
    echo "Android version: $(getprop ro.build.version.release)" >> "$REPORT_FILE"
    echo "Timestamp: $(date)" >> "$REPORT_FILE"
    
    # Apply safety measures based on level
    apply_safety_measures "$SAFETY_LEVEL" "$REPORT_FILE"
    
    # Create safemode notification
    create_safemode_notification
    
    log_message "Safe mode initialized with safety level $SAFETY_LEVEL"
}

# Apply safety measures based on safety level
apply_safety_measures() {
    LEVEL=$1
    REPORT_FILE=$2
    
    log_message "Applying safety measures for level $LEVEL"
    
    echo >> "$REPORT_FILE"
    echo "=== Applied Safety Measures ===" >> "$REPORT_FILE"
    
    case $LEVEL in
        $SAFETY_LEVEL_MINIMAL)
            apply_minimal_safety "$REPORT_FILE"
            ;;
        $SAFETY_LEVEL_MODERATE)
            apply_moderate_safety "$REPORT_FILE"
            ;;
        $SAFETY_LEVEL_AGGRESSIVE)
            apply_aggressive_safety "$REPORT_FILE"
            ;;
        $SAFETY_LEVEL_EXTREME)
            apply_extreme_safety "$REPORT_FILE"
            ;;
    esac
    
    # Always ensure this module remains enabled for recovery
    if [ -f "/data/adb/modules/kernelsu_antibootloop_backup/disable" ]; then
        rm -f "/data/adb/modules/kernelsu_antibootloop_backup/disable"
        log_message "Re-enabled anti-bootloop module for recovery"
        echo "Re-enabled anti-bootloop module for recovery" >> "$REPORT_FILE"
    fi
}

# Minimal safety measures - only disable potentially problematic modules
apply_minimal_safety() {
    REPORT_FILE=$1
    
    log_message "Applying minimal safety measures"
    echo "- Disabling potentially problematic modules" >> "$REPORT_FILE"
    
    # Check for recently installed or updated modules
    if [ -d "/data/adb/modules" ]; then
        CURRENT_TIME=$(date +%s)
        THRESHOLD_TIME=$((CURRENT_TIME - 86400)) # 24 hours ago
        
        for MODULE_DIR in /data/adb/modules/*; do
            if [ -d "$MODULE_DIR" ] && [ ! -f "$MODULE_DIR/disable" ]; then
                MODULE_NAME=$(basename "$MODULE_DIR")
                
                # Skip our own module
                if [ "$MODULE_NAME" = "kernelsu_antibootloop_backup" ]; then
                    continue
                fi
                
                # Check for recently modified modules
                MODULE_MOD_TIME=$(stat -c %Y "$MODULE_DIR" 2>/dev/null || date +%s)
                if [ $MODULE_MOD_TIME -ge $THRESHOLD_TIME ]; then
                    log_message "Disabling recently modified module: $MODULE_NAME"
                    touch "$MODULE_DIR/disable"
                    echo "  - Disabled recent module: $MODULE_NAME" >> "$REPORT_FILE"
                    continue
                fi
                
                # Check for known problematic modules (add module names as needed)
                PROBLEM_MODULES="magiskhide systemless_hosts"
                for PROB_MODULE in $PROBLEM_MODULES; do
                    if [ "$MODULE_NAME" = "$PROB_MODULE" ]; then
                        log_message "Disabling known problematic module: $MODULE_NAME"
                        touch "$MODULE_DIR/disable"
                        echo "  - Disabled known problematic module: $MODULE_NAME" >> "$REPORT_FILE"
                        break
                    fi
                done
                
                # Check for modules modifying system partition
                if [ -d "$MODULE_DIR/system" ] && [ "$(ls -A "$MODULE_DIR/system" 2>/dev/null)" ]; then
                    for SYSTEM_FILE in "$MODULE_DIR/system/"*; do
                        if [ -f "$SYSTEM_FILE" ]; then
                            # Disable modules modifying critical system files
                            if echo "$SYSTEM_FILE" | grep -q "framework\|services.jar\|boot\|init"; then
                                log_message "Disabling module modifying critical system files: $MODULE_NAME"
                                touch "$MODULE_DIR/disable"
                                echo "  - Disabled module modifying critical system files: $MODULE_NAME" >> "$REPORT_FILE"
                                break
                            fi
                        fi
                    done
                fi
            fi
        done
    fi
}

# Moderate safety measures - disable all non-essential modules
apply_moderate_safety() {
    REPORT_FILE=$1
    
    log_message "Applying moderate safety measures"
    echo "- Disabling all non-essential modules" >> "$REPORT_FILE"
    
    # Define list of essential modules that should remain enabled
    ESSENTIAL_MODULES="kernelsu_antibootloop_backup"
    
    if [ -d "/data/adb/modules" ]; then
        for MODULE_DIR in /data/adb/modules/*; do
            if [ -d "$MODULE_DIR" ] && [ ! -f "$MODULE_DIR/disable" ]; then
                MODULE_NAME=$(basename "$MODULE_DIR")
                
                # Skip essential modules
                ESSENTIAL=0
                for ESSENTIAL_MODULE in $ESSENTIAL_MODULES; do
                    if [ "$MODULE_NAME" = "$ESSENTIAL_MODULE" ]; then
                        ESSENTIAL=1
                        break
                    fi
                done
                
                if [ $ESSENTIAL -eq 0 ]; then
                    log_message "Disabling non-essential module: $MODULE_NAME"
                    touch "$MODULE_DIR/disable"
                    echo "  - Disabled module: $MODULE_NAME" >> "$REPORT_FILE"
                else
                    log_message "Keeping essential module enabled: $MODULE_NAME"
                    echo "  - Kept essential module: $MODULE_NAME" >> "$REPORT_FILE"
                fi
            fi
        done
    fi
    
    # Try to restore from last known good recovery point
    RECOVERY_POINTS=$(ls -t "$RECOVERY_DIR" 2>/dev/null)
    if [ ! -z "$RECOVERY_POINTS" ]; then
        # Get most recent recovery point
        LATEST_POINT=$(echo "$RECOVERY_POINTS" | head -1)
        log_message "Attempting to restore from recovery point: $LATEST_POINT"
        echo "- Restoring from recovery point: $LATEST_POINT" >> "$REPORT_FILE"
        
        if [ -f "$MODDIR/scripts/overlayfs.sh" ]; then
            # Source overlayfs script to get access to rollback function
            . "$MODDIR/scripts/overlayfs.sh"
            rollback_system "$LATEST_POINT"
            echo "  - System rollback executed" >> "$REPORT_FILE"
        fi
    fi
}

# Aggressive safety measures - disable all modules including this one
apply_aggressive_safety() {
    REPORT_FILE=$1
    
    log_message "Applying aggressive safety measures"
    echo "- Disabling ALL modules (temporary)" >> "$REPORT_FILE"
    
    # Completely disable KernelSU modules (temporarily)
    if [ -d "/data/adb" ]; then
        if [ -f "/data/adb/modules/.disable" ]; then
            log_message "KernelSU modules already disabled globally"
            echo "  - KernelSU modules already disabled globally" >> "$REPORT_FILE"
        else
            touch "/data/adb/modules/.disable"
            log_message "Disabled all KernelSU modules globally"
            echo "  - Disabled all KernelSU modules globally" >> "$REPORT_FILE"
        fi
    fi
    
    # Try to undo any system modifications
    if [ -f "$MODDIR/scripts/overlayfs.sh" ]; then
        log_message "Attempting to undo all system modifications"
        echo "- Attempting to undo all system modifications" >> "$REPORT_FILE"
        
        # Source overlayfs script
        . "$MODDIR/scripts/overlayfs.sh"
        
        # Look for any recovery point
        RECOVERY_POINTS=$(ls -t "$RECOVERY_DIR" 2>/dev/null)
        if [ ! -z "$RECOVERY_POINTS" ]; then
            # Try earliest point first as it should be most stable
            EARLIEST_POINT=$(echo "$RECOVERY_POINTS" | tail -1)
            log_message "Restoring from earliest recovery point: $EARLIEST_POINT"
            echo "  - Restoring from earliest recovery point: $EARLIEST_POINT" >> "$REPORT_FILE"
            rollback_system "$EARLIEST_POINT"
        fi
    fi
    
    # Schedule a reboot to safe mode on next boot
    if [ -d "/cache" ]; then
        echo "safe_mode=1" > "/cache/recovery/command"
        log_message "Scheduled Android Safe Mode boot"
        echo "- Scheduled Android Safe Mode boot" >> "$REPORT_FILE"
    fi
}

# Extreme safety measures - factory reset as last resort
apply_extreme_safety() {
    REPORT_FILE=$1
    
    log_message "CRITICAL: Applying extreme safety measures"
    echo "- WARNING: Preparing for factory reset (last resort)" >> "$REPORT_FILE"
    
    # Create warning files everywhere possible
    echo "WARNING: Device will be factory reset on next boot due to persistent bootloop" > "$SAFEMODE_DIR/FACTORY_RESET_WARNING"
    
    if [ -d "/cache" ]; then
        echo "WARNING: Device will be factory reset on next boot due to persistent bootloop" > "/cache/FACTORY_RESET_WARNING"
    fi
    
    if [ -d "/data" ]; then
        echo "WARNING: Device will be factory reset on next boot due to persistent bootloop" > "/data/FACTORY_RESET_WARNING"
    fi
    
    # Create recovery command for factory reset
    if [ -d "/cache/recovery" ]; then
        echo "--wipe_data" > "/cache/recovery/command"
        log_message "Scheduled factory reset via recovery"
        echo "  - Scheduled factory reset via recovery" >> "$REPORT_FILE"
    fi
    
    # Try last ditch effort to boot normally by disabling all modifications
    apply_aggressive_safety "$REPORT_FILE"
    
    log_message "CRITICAL: Factory reset scheduled. This is the last resort measure."
    echo "NOTICE: The device will attempt one more boot with all modules disabled." >> "$REPORT_FILE"
    echo "If this fails, a factory reset will be performed to recover the device." >> "$REPORT_FILE"
}

# Create recovery environment entry point
create_recovery_environment() {
    log_message "Creating recovery environment entry point"
    
    # Create recovery script
    RECOVERY_SCRIPT="$SAFEMODE_DIR/recovery_console.sh"
    
    cat > "$RECOVERY_SCRIPT" << EOF
#!/system/bin/sh
# Recovery Environment Console
MODDIR=\${0%/*}
MODDIR=\${MODDIR%/*}
MODDIR=\${MODDIR%/*}

echo "==============================================="
echo "KernelSU Anti-Bootloop Recovery Environment"
echo "==============================================="
echo "Device: \$(getprop ro.product.model)"
echo "Android version: \$(getprop ro.build.version.release)"
echo "Safe mode active at safety level: \$(cat \$MODDIR/config/safe_mode/safety_level)"
echo "==============================================="
echo
echo "Available recovery options:"
echo "1. View boot logs"
echo "2. List disabled modules"
echo "3. Enable specific module"
echo "4. Disable specific module"
echo "5. Restore from recovery point"
echo "6. Exit safe mode and reboot"
echo "7. Increase safety level"
echo "8. Decrease safety level"
echo "9. Exit"
echo

read -p "Enter option: " OPTION

case \$OPTION in
    1)
        echo "Latest boot logs:"
        cat \$MODDIR/config/boot_logs/boot_*.log | tail -50
        ;;
    2)
        echo "Disabled modules:"
        for MODULE in /data/adb/modules/*/disable; do
            if [ -f "\$MODULE" ]; then
                echo "- \$(basename \$(dirname \$MODULE))"
            fi
        done
        ;;
    3)
        echo "Available modules:"
        ls -1 /data/adb/modules/
        read -p "Enter module name to enable: " MODULE_NAME
        if [ -d "/data/adb/modules/\$MODULE_NAME" ]; then
            rm -f "/data/adb/modules/\$MODULE_NAME/disable"
            echo "Module \$MODULE_NAME enabled"
        else
            echo "Module not found"
        fi
        ;;
    4)
        echo "Available modules:"
        ls -1 /data/adb/modules/
        read -p "Enter module name to disable: " MODULE_NAME
        if [ -d "/data/adb/modules/\$MODULE_NAME" ]; then
            touch "/data/adb/modules/\$MODULE_NAME/disable"
            echo "Module \$MODULE_NAME disabled"
        else
            echo "Module not found"
        fi
        ;;
    5)
        echo "Available recovery points:"
        ls -1 \$MODDIR/config/recovery_points/
        read -p "Enter recovery point name: " RECOVERY_POINT
        if [ -d "\$MODDIR/config/recovery_points/\$RECOVERY_POINT" ]; then
            . \$MODDIR/scripts/overlayfs.sh
            rollback_system "\$RECOVERY_POINT"
            echo "System restored from recovery point \$RECOVERY_POINT"
        else
            echo "Recovery point not found"
        fi
        ;;
    6)
        echo "Exiting safe mode and rebooting..."
        rm -f "\$MODDIR/config/safe_mode/active"
        rm -f "\$MODDIR/config/bootloop_detected"
        rm -f "\$MODDIR/config/safe_mode/manual_trigger"
        echo "0" > "\$MODDIR/config/boot_counter"
        reboot
        ;;
    7)
        CURRENT_LEVEL=\$(cat \$MODDIR/config/safe_mode/safety_level)
        NEW_LEVEL=\$((CURRENT_LEVEL + 1))
        if [ \$NEW_LEVEL -gt 4 ]; then
            NEW_LEVEL=4
        fi
        echo "\$NEW_LEVEL" > "\$MODDIR/config/safe_mode/safety_level"
        echo "Safety level increased to \$NEW_LEVEL"
        echo "Changes will take effect on next boot"
        ;;
    8)
        CURRENT_LEVEL=\$(cat \$MODDIR/config/safe_mode/safety_level)
        NEW_LEVEL=\$((CURRENT_LEVEL - 1))
        if [ \$NEW_LEVEL -lt 1 ]; then
            NEW_LEVEL=1
        fi
        echo "\$NEW_LEVEL" > "\$MODDIR/config/safe_mode/safety_level"
        echo "Safety level decreased to \$NEW_LEVEL"
        echo "Changes will take effect on next boot"
        ;;
    9)
        echo "Exiting"
        exit
        ;;
    *)
        echo "Invalid option"
        ;;
esac

# Pause before returning to menu
read -p "Press Enter to continue..."
exec \$0
EOF

    chmod +x "$RECOVERY_SCRIPT"
    log_message "Recovery environment entry point created"
}

# Main function
main() {
    log_message "Safe mode bootstrap main function started"
    
    # Ensure all required directories exist
    mkdir -p "$BOOTLOG_DIR" 2>/dev/null
    mkdir -p "$RECOVERY_DIR" 2>/dev/null
    mkdir -p "$SAFEMODE_DIR" 2>/dev/null
    mkdir -p "$CHECKPOINT_DIR" 2>/dev/null
    
    # Check if we should activate safe mode
    if [ -f "$CONFIG_DIR/bootloop_detected" ] || [ -f "$SAFEMODE_DIR/manual_trigger" ]; then
        log_message "Bootloop detected or manual trigger found, activating safe mode"
        
        # Initialize safe mode with appropriate safety level
        initialize_safe_mode
        
        # Create recovery environment
        create_recovery_environment
        
        log_message "Safe mode activated successfully"
        return 0
    else
        # Check if we're already in safe mode
        if is_safe_mode; then
            log_message "System already in safe mode"
            return 0
        else
            log_message "Normal boot, safe mode not needed"
            return 0
        fi
    fi
}

# Execute main function
main
exit $?