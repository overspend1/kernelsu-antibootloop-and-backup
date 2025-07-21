#!/system/bin/sh
# KernelSU Anti-Bootloop Safety Service Script

MODDIR=${0%/*}
MODDIR=${MODDIR%/*}
CONFIG_DIR="$MODDIR/config"
BOOTLOG_DIR="$CONFIG_DIR/boot_logs"
RECOVERY_DIR="$CONFIG_DIR/recovery_points"
SAFEMODE_DIR="$CONFIG_DIR/safe_mode"

# Ensure we have our directories
mkdir -p "$BOOTLOG_DIR"
mkdir -p "$RECOVERY_DIR"
mkdir -p "$SAFEMODE_DIR"

# Hardware key detection constants
VOL_UP_KEY=115  # KEY_VOLUMEUP
VOL_DOWN_KEY=114  # KEY_VOLUMEDOWN
POWER_KEY=116    # KEY_POWER
KEY_HOLD_TIME=3  # Seconds to hold key combination

# Log function for debugging
log_message() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$BOOTLOG_DIR/safety_service.log"
}

log_message "Safety service started"

# Detect key state using Android's input device
# Returns 1 if key is pressed, 0 otherwise
is_key_pressed() {
    if [ -z "$1" ]; then
        log_message "ERROR: is_key_pressed called without key code"
        return 2
    fi
    
    KEY_CODE="$1"
    
    # Check if KEY_CODE is numeric
    case "$KEY_CODE" in
        ''|*[!0-9]*)
            log_message "ERROR: Invalid key code: $KEY_CODE"
            return 2
            ;;
    esac
    
    # Try to use getevent if available (more reliable)
    if command -v getevent >/dev/null 2>&1; then
        # Check for key press events in all input devices
        # Use find to safely handle cases where no matching devices exist
        find /dev/input -name "event*" -type c 2>/dev/null | while read -r DEVICE; do
            if [ -c "$DEVICE" ]; then
                if getevent -l "$DEVICE" 2>/dev/null | grep -q "EV_KEY.*$KEY_CODE.*DOWN"; then
                    return 1
                fi
            fi
        done
    else
        # Fallback method using cat to read input device
        # Use find to safely handle cases where no matching devices exist
        find /dev/input -name "event*" -type c 2>/dev/null | while read -r DEVICE; do
            if [ -c "$DEVICE" ]; then
                # Use cat with timeout to avoid blocking
                if timeout 1 cat "$DEVICE" >/dev/null 2>&1; then
                    # Check if the key event was captured
                    if hexdump -e '1/1 "%02x"' "$DEVICE" 2>/dev/null | grep -q "$(printf '%02x' "$KEY_CODE")"; then
                        return 1
                    fi
                fi
            fi
        done
    fi
    
    return 0
}

# Check for emergency recovery key combination
# Volume Up + Volume Down for KEY_HOLD_TIME seconds
check_emergency_key_combo() {
    log_message "Checking for emergency recovery key combination"
    
    COUNT=0
    while [ $COUNT -lt $KEY_HOLD_TIME ]; do
        # Check if both volume keys are pressed
        is_key_pressed $VOL_UP_KEY
        VOL_UP_STATE=$?
        
        is_key_pressed $VOL_DOWN_KEY
        VOL_DOWN_STATE=$?
        
        if [ $VOL_UP_STATE -eq 1 ] && [ $VOL_DOWN_STATE -eq 1 ]; then
            log_message "Recovery key combination detected ($COUNT/$KEY_HOLD_TIME)"
            COUNT=$((COUNT + 1))
        else
            # Keys released, reset counter
            log_message "Keys released, resetting counter"
            return 0
        fi
        
        sleep 1
    done
    
    # Keys were held for the required time
    log_message "Emergency recovery key combination confirmed"
    return 1
}

# Check for forced restart combination
# Volume Down + Power for KEY_HOLD_TIME seconds
check_forced_restart_combo() {
    log_message "Checking for forced restart key combination"
    
    COUNT=0
    while [ $COUNT -lt $KEY_HOLD_TIME ]; do
        # Check if volume down and power are pressed
        is_key_pressed $VOL_DOWN_KEY
        VOL_DOWN_STATE=$?
        
        is_key_pressed $POWER_KEY
        POWER_STATE=$?
        
        if [ $VOL_DOWN_STATE -eq 1 ] && [ $POWER_STATE -eq 1 ]; then
            log_message "Forced restart key combination detected ($COUNT/$KEY_HOLD_TIME)"
            COUNT=$((COUNT + 1))
        else
            # Keys released, reset counter
            return 0
        fi
        
        sleep 1
    done
    
    # Keys were held for the required time
    log_message "Forced restart key combination confirmed"
    return 1
}

# Check if bootloop detection is enabled
check_bootloop_detection_enabled() {
    ENABLED=$(grep "bootloop_detection" "$CONFIG_DIR/main.conf" | cut -d= -f2 || echo "true")
    if [ "$ENABLED" == "true" ]; then
        log_message "Bootloop detection is enabled"
        return 0
    else
        log_message "Bootloop detection is disabled"
        return 1
    fi
}

# Reset boot counter when boot completes successfully
reset_boot_counter() {
    log_message "Boot completed successfully, resetting boot counter"
    echo "0" > "$CONFIG_DIR/boot_counter"
}

# Trigger safe mode from hardware key detection
trigger_safe_mode() {
    log_message "Triggering safe mode from hardware key detection"
    
    # Create safe mode trigger file
    echo "1" > "$SAFEMODE_DIR/manual_trigger"
    echo "$(date +"%Y%m%d_%H%M%S")" > "$SAFEMODE_DIR/trigger_time"
    
    # Create report file
    REPORT_FILE="$BOOTLOG_DIR/manual_recovery_$(date +"%Y%m%d_%H%M%S").log"
    echo "===== MANUAL RECOVERY TRIGGERED =====" > "$REPORT_FILE"
    echo "Triggered by: Hardware key combination" >> "$REPORT_FILE"
    echo "Device: $(getprop ro.product.model)" >> "$REPORT_FILE"
    echo "Android version: $(getprop ro.build.version.release)" >> "$REPORT_FILE"
    echo "Timestamp: $(date)" >> "$REPORT_FILE"
    
    # Disable all modules for safe boot
    log_message "Disabling all modules for safe boot"
    if [ -d "/data/adb/modules" ]; then
        for MODULE_DIR in /data/adb/modules/*; do
            if [ -d "$MODULE_DIR" ] && [ ! -f "$MODULE_DIR/disable" ]; then
                MODULE_NAME=$(basename "$MODULE_DIR")
                log_message "Disabling module: $MODULE_NAME"
                touch "$MODULE_DIR/disable"
                echo "Disabled module: $MODULE_NAME" >> "$REPORT_FILE"
            fi
        done
    fi
    
    # This module should remain enabled
    if [ -f "/data/adb/modules/kernelsu_antibootloop_backup/disable" ]; then
        log_message "Re-enabling anti-bootloop module"
        rm -f "/data/adb/modules/kernelsu_antibootloop_backup/disable"
    fi
    
    # Attempt to reboot if possible
    log_message "Attempting to reboot device into safe mode"
    
    # Request a reboot
    sync
    
    # Try different reboot methods (fallback options)
    if command -v reboot >/dev/null 2>&1; then
        reboot
    elif [ -f "/system/bin/reboot" ]; then
        /system/bin/reboot
    elif [ -f "/system/xbin/reboot" ]; then
        /system/xbin/reboot
    else
        # Fallback to more direct methods
        echo 1 > /proc/sys/kernel/sysrq
        echo b > /proc/sysrq-trigger
    fi
}

# Monitor system stability
monitor_system_stability() {
    log_message "Starting system stability monitoring"
    
    # Monitor for app crashes
    (
        # Wait for system to be fully booted
        while [ "$(getprop sys.boot_completed)" != "1" ]; do
            sleep 1
        done
        
        log_message "Beginning app crash monitoring"
        
        # Record initial crash count
        INITIAL_CRASH_COUNT=$(dumpsys dropbox | grep -c "data_app_crash")
        
        # Check for abnormal number of crashes
        while true; do
            sleep 60  # Check every minute
            
            # Get current crash count
            CURRENT_CRASH_COUNT=$(dumpsys dropbox | grep -c "data_app_crash")
            NEW_CRASHES=$((CURRENT_CRASH_COUNT - INITIAL_CRASH_COUNT))
            
            # If we have more than 5 new crashes in a minute, log a warning
            if [ $NEW_CRASHES -gt 5 ]; then
                log_message "WARNING: Detected abnormal crash rate: $NEW_CRASHES crashes in the last minute"
                
                # Log the most recent crash info
                CRASH_INFO=$(dumpsys dropbox --print | grep -A 10 "data_app_crash" | head -10)
                echo "$CRASH_INFO" >> "$BOOTLOG_DIR/crash_monitoring.log"
                
                # Update initial count to avoid repeated warnings
                INITIAL_CRASH_COUNT=$CURRENT_CRASH_COUNT
            fi
        done
    ) &
}

# Setup early detection for boot issues
setup_early_detection() {
    log_message "Setting up early boot issue detection"
    
    # Start key monitoring in background
    (
        log_message "Starting hardware key monitoring"
        
        # Monitor hardware keys for emergency recovery combination
        # Keep monitoring for a period after boot
        MONITOR_TIME=600  # 10 minutes
        END_TIME=$(($(date +%s) + MONITOR_TIME))
        
        while [ $(date +%s) -lt $END_TIME ]; do
            # Check for emergency key combo
            check_emergency_key_combo
            if [ $? -eq 1 ]; then
                log_message "Emergency recovery key combination detected"
                trigger_safe_mode
                break
            fi
            
            # Check for forced restart combo
            check_forced_restart_combo
            if [ $? -eq 1 ]; then
                log_message "Forced restart key combination detected"
                trigger_safe_mode
                break
            fi
            
            # Short pause between checks
            sleep 2
        done
        
        log_message "Hardware key monitoring completed"
    ) &
    
    # Save monitoring PID
    echo $! > "$SAFEMODE_DIR/key_monitor.pid"
}

# Check hardware keys (called from boot-monitor.sh)
check_keys() {
    log_message "Checking hardware keys (external request)"
    
    # Check for emergency key combo
    check_emergency_key_combo
    if [ $? -eq 1 ]; then
        log_message "Emergency recovery key combination detected"
        return 10  # Special return code for boot-monitor.sh
    fi
    
    return 0
}

# Register for boot completed broadcast
wait_for_boot_completed() {
    # Wait for boot completed signal
    while [ "$(getprop sys.boot_completed)" != "1" ]; do
        sleep 1
    done
    
    log_message "System boot completed"
    
    # Verify system is stable for a few seconds
    sleep 5
    
    # Reset the boot counter as the device booted successfully
    reset_boot_counter
    
    # Start stability monitoring
    monitor_system_stability
}

# Main function
main() {
    log_message "Safety service main function started"
    
    # Check if this is a command mode call
    if [ "$1" = "check_keys" ]; then
        check_keys
        exit $?
    fi
    
    # Check if bootloop detection is enabled
    if check_bootloop_detection_enabled; then
        # Setup early detection
        setup_early_detection
        
        # Wait for boot completed in background
        wait_for_boot_completed &
    else
        log_message "Bootloop detection disabled, running minimal service"
    fi
    
    log_message "Safety service initialization completed"
}

# Execute main function
main