#!/system/bin/sh

# Advanced Anti-Bootloop KSU Module - Recovery Engine
# Author: @overspend1/Wiktor

MODDIR=${0%/*}
. "$MODDIR/utils.sh"
. "$MODDIR/backup_manager.sh"

RECOVERY_STATE_FILE="$BASE_DIR/recovery_state"
SAFE_MODE_FLAG="$BASE_DIR/safe_mode_active"
MODULE_DISABLE_FLAG="$BASE_DIR/modules_disabled"

# Initialize recovery engine
init_recovery_engine() {
    load_config
    init_backup_system
    
    # Create recovery state if doesn't exist
    if [ ! -f "$RECOVERY_STATE_FILE" ]; then
        echo "normal" > "$RECOVERY_STATE_FILE"
    fi
    
    log_message "INFO" "Recovery engine initialized"
}

# Get current recovery state
get_recovery_state() {
    if [ -f "$RECOVERY_STATE_FILE" ]; then
        cat "$RECOVERY_STATE_FILE"
    else
        echo "normal"
    fi
}

# Set recovery state
set_recovery_state() {
    local state="$1"
    echo "$state" > "$RECOVERY_STATE_FILE"
    log_message "INFO" "Recovery state changed to: $state"
}

# Progressive recovery strategy implementation
execute_recovery_strategy() {
    local boot_count="$1"
    local current_state=$(get_recovery_state)
    
    log_message "INFO" "Executing $RECOVERY_STRATEGY recovery strategy (boot count: $boot_count, state: $current_state)"
    
    case "$RECOVERY_STRATEGY" in
        "progressive")
            execute_progressive_recovery "$boot_count" "$current_state"
            ;;
        "aggressive")
            execute_aggressive_recovery "$boot_count" "$current_state"
            ;;
        "conservative")
            execute_conservative_recovery "$boot_count" "$current_state"
            ;;
        *)
            log_message "ERROR" "Unknown recovery strategy: $RECOVERY_STRATEGY"
            execute_progressive_recovery "$boot_count" "$current_state"
            ;;
    esac
}

# Progressive recovery: escalating interventions
execute_progressive_recovery() {
    local boot_count="$1"
    local current_state="$2"
    
    case "$boot_count" in
        1)
            # First failure - just log and monitor
            log_message "WARN" "First boot failure detected"
            set_recovery_state "monitoring"
            collect_telemetry
            
            if [ "$WARNING_NOTIFICATIONS" = "true" ]; then
                send_notification "Boot Warning" "First boot failure detected" "normal"
            fi
            ;;
            
        2)
            # Second failure - try safe mode
            log_message "WARN" "Second boot failure - attempting safe mode"
            set_recovery_state "safe_mode"
            
            if [ "$SAFE_MODE_ENABLED" = "true" ]; then
                enable_safe_mode
            fi
            
            # Disable problematic modules
            disable_problematic_modules
            
            if [ "$WARNING_NOTIFICATIONS" = "true" ]; then
                send_notification "Boot Warning" "Safe mode activated" "high"
            fi
            ;;
            
        3)
            # Third failure - kernel recovery
            log_message "ERROR" "Third boot failure - attempting kernel recovery"
            set_recovery_state "kernel_recovery"
            
            # Try to restore from most stable backup
            local backup_name=$(get_recovery_backup "stable")
            if [ -n "$backup_name" ]; then
                log_message "INFO" "Attempting kernel restore from: $backup_name"
                if restore_backup "$backup_name" "true"; then
                    log_message "INFO" "Kernel recovery successful"
                    set_recovery_state "recovered"
                    
                    if [ "$RECOVERY_NOTIFICATIONS" = "true" ]; then
                        send_notification "Recovery Success" "Kernel restored from backup" "high"
                    fi
                    
                    if [ "$AUTO_REBOOT" = "true" ]; then
                        schedule_reboot "$REBOOT_DELAY"
                    fi
                    return 0
                fi
            fi
            
            # Fallback to stock kernel
            backup_name=$(get_recovery_backup "stock")
            if [ -n "$backup_name" ]; then
                log_message "INFO" "Attempting stock kernel restore from: $backup_name"
                if restore_backup "$backup_name" "true"; then
                    log_message "INFO" "Stock kernel recovery successful"
                    set_recovery_state "stock_recovered"
                    
                    if [ "$RECOVERY_NOTIFICATIONS" = "true" ]; then
                        send_notification "Emergency Recovery" "Stock kernel restored" "critical"
                    fi
                    
                    if [ "$AUTO_REBOOT" = "true" ]; then
                        schedule_reboot "$REBOOT_DELAY"
                    fi
                    return 0
                fi
            fi
            
            # Last resort - complete module disable
            log_message "ERROR" "Kernel recovery failed - disabling all modules"
            disable_all_modules
            set_recovery_state "emergency"
            ;;
            
        *)
            # Beyond 3 failures - emergency mode
            log_message "CRITICAL" "Multiple recovery attempts failed - emergency mode"
            set_recovery_state "emergency"
            emergency_recovery_mode
            ;;
    esac
}

# Aggressive recovery: immediate kernel restore
execute_aggressive_recovery() {
    local boot_count="$1"
    local current_state="$2"
    
    if [ "$boot_count" -ge 2 ]; then
        log_message "WARN" "Aggressive recovery triggered at boot count: $boot_count"
        
        # Immediate kernel recovery
        local backup_name=$(get_recovery_backup "stock")
        if [ -n "$backup_name" ]; then
            log_message "INFO" "Aggressive kernel restore from: $backup_name"
            if restore_backup "$backup_name" "true"; then
                set_recovery_state "aggressive_recovered"
                
                if [ "$RECOVERY_NOTIFICATIONS" = "true" ]; then
                    send_notification "Aggressive Recovery" "Kernel restored immediately" "high"
                fi
                
                if [ "$AUTO_REBOOT" = "true" ]; then
                    schedule_reboot "$REBOOT_DELAY"
                fi
                return 0
            fi
        fi
        
        # Fallback to emergency mode
        emergency_recovery_mode
    fi
}

# Conservative recovery: more cautious approach
execute_conservative_recovery() {
    local boot_count="$1"
    local current_state="$2"
    
    case "$boot_count" in
        1|2)
            # Just monitor and log
            log_message "INFO" "Conservative approach - monitoring boot failure $boot_count"
            set_recovery_state "conservative_monitoring"
            collect_telemetry
            ;;
            
        3|4)
            # Try safe mode
            if [ "$current_state" != "safe_mode" ]; then
                log_message "INFO" "Conservative recovery - enabling safe mode"
                set_recovery_state "safe_mode"
                enable_safe_mode
            fi
            ;;
            
        *)
            # Finally attempt kernel recovery
            log_message "WARN" "Conservative recovery - kernel restore after $boot_count failures"
            execute_progressive_recovery "$boot_count" "$current_state"
            ;;
    esac
}

# Enable safe mode
enable_safe_mode() {
    if [ "$SAFE_MODE_ENABLED" != "true" ]; then
        return 1
    fi
    
    log_message "INFO" "Enabling safe mode"
    touch "$SAFE_MODE_FLAG"
    
    # Disable non-essential modules
    disable_non_essential_modules
    
    # Set system properties for safe mode
    setprop persist.vendor.debug.enable_safe_mode 1 2>/dev/null
    setprop ro.debuggable 1 2>/dev/null
    
    log_message "INFO" "Safe mode enabled"
    return 0
}

# Disable safe mode
disable_safe_mode() {
    log_message "INFO" "Disabling safe mode"
    rm -f "$SAFE_MODE_FLAG"
    
    # Reset system properties
    setprop persist.vendor.debug.enable_safe_mode 0 2>/dev/null
    
    log_message "INFO" "Safe mode disabled"
}

# Check if safe mode is active
is_safe_mode_active() {
    [ -f "$SAFE_MODE_FLAG" ]
}

# Disable problematic modules
disable_problematic_modules() {
    log_message "INFO" "Disabling problematic modules"
    
    # List of commonly problematic module patterns
    local problematic_patterns="
        *overclock*
        *governor*
        *thermal*
        *undervolt*
        *performance*
        *tweak*
    "
    
    if [ -d "/data/adb/modules" ]; then
        for pattern in $problematic_patterns; do
            for module_dir in /data/adb/modules/$pattern; do
                if [ -d "$module_dir" ] && [ ! -f "$module_dir/disable" ]; then
                    touch "$module_dir/disable"
                    log_message "INFO" "Disabled problematic module: $(basename $module_dir)"
                fi
            done
        done
    fi
    
    touch "$MODULE_DISABLE_FLAG"
}

# Disable non-essential modules
disable_non_essential_modules() {
    log_message "INFO" "Disabling non-essential modules for safe mode"
    
    # Keep only essential modules (whitelist approach)
    local essential_modules="
        anti_bootloop_advanced_ksu
        kernelsu
        zygisk
        shamiko
    "
    
    if [ -d "/data/adb/modules" ]; then
        for module_dir in /data/adb/modules/*; do
            if [ -d "$module_dir" ]; then
                local module_name=$(basename "$module_dir")
                local is_essential=false
                
                for essential in $essential_modules; do
                    if [ "$module_name" = "$essential" ]; then
                        is_essential=true
                        break
                    fi
                done
                
                if [ "$is_essential" = false ] && [ ! -f "$module_dir/disable" ]; then
                    touch "$module_dir/disable"
                    log_message "INFO" "Disabled non-essential module: $module_name"
                fi
            fi
        done
    fi
}

# Disable all modules except this one
disable_all_modules() {
    log_message "WARN" "Disabling all modules for emergency recovery"
    
    if [ -d "/data/adb/modules" ]; then
        for module_dir in /data/adb/modules/*; do
            if [ -d "$module_dir" ]; then
                local module_name=$(basename "$module_dir")
                
                # Don't disable this module
                if [ "$module_name" != "anti_bootloop_advanced_ksu" ] && [ ! -f "$module_dir/disable" ]; then
                    touch "$module_dir/disable"
                    log_message "INFO" "Emergency disabled module: $module_name"
                fi
            fi
        done
    fi
    
    touch "$MODULE_DISABLE_FLAG"
}

# Re-enable modules after successful recovery
re_enable_modules() {
    log_message "INFO" "Re-enabling modules after successful recovery"
    
    if [ -f "$MODULE_DISABLE_FLAG" ]; then
        if [ -d "/data/adb/modules" ]; then
            for disable_file in /data/adb/modules/*/disable; do
                if [ -f "$disable_file" ]; then
                    rm -f "$disable_file"
                    local module_name=$(basename "$(dirname "$disable_file")")
                    log_message "INFO" "Re-enabled module: $module_name"
                fi
            done
        fi
        
        rm -f "$MODULE_DISABLE_FLAG"
        log_message "INFO" "All modules re-enabled"
    fi
}

# Emergency recovery mode
emergency_recovery_mode() {
    log_message "CRITICAL" "Entering emergency recovery mode"
    set_recovery_state "emergency"
    
    # Try custom recovery script if specified
    if [ -n "$CUSTOM_RECOVERY_SCRIPT" ] && [ -f "$CUSTOM_RECOVERY_SCRIPT" ]; then
        log_message "INFO" "Executing custom recovery script: $CUSTOM_RECOVERY_SCRIPT"
        sh "$CUSTOM_RECOVERY_SCRIPT" 2>&1 | while read line; do
            log_message "CUSTOM" "$line"
        done
    fi
    
    # Disable all modules
    disable_all_modules
    
    # Final attempt at stock kernel restore
    local backup_name=$(get_recovery_backup "stock")
    if [ -n "$backup_name" ]; then
        log_message "INFO" "Emergency stock kernel restore from: $backup_name"
        restore_backup "$backup_name" "false"  # Skip verification in emergency
    fi
    
    # Create emergency marker
    echo "Emergency recovery performed at $(date)" > "$BASE_DIR/emergency_recovery_marker"
    
    if [ "$RECOVERY_NOTIFICATIONS" = "true" ]; then
        send_notification "Emergency Recovery" "System in emergency mode" "critical"
    fi
    
    log_message "CRITICAL" "Emergency recovery completed - manual intervention may be required"
}

# Schedule reboot
schedule_reboot() {
    local delay="$1"
    
    log_message "INFO" "Scheduling reboot in $delay seconds"
    
    if [ "$delay" -gt 0 ]; then
        (sleep "$delay" && reboot) &
    else
        reboot
    fi
}

# Reset recovery state on successful boot
reset_recovery_state() {
    local current_state=$(get_recovery_state)
    
    if [ "$current_state" != "normal" ]; then
        log_message "INFO" "Successful boot detected - resetting recovery state from: $current_state"
        set_recovery_state "normal"
        
        # Re-enable modules if they were disabled
        if [ -f "$MODULE_DISABLE_FLAG" ]; then
            re_enable_modules
        fi
        
        # Disable safe mode if active
        if is_safe_mode_active; then
            disable_safe_mode
        fi
        
        # Send success notification
        if [ "$BOOT_NOTIFICATIONS" = "true" ]; then
            send_notification "Boot Success" "System recovered successfully" "normal"
        fi
    fi
}