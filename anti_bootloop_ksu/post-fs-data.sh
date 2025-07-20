#!/system/bin/sh

# Advanced Anti-Bootloop KSU Module Post-FS-Data Script
# Author: @overspend1/Wiktor
# Early initialization, emergency checks, and system preparation

MODDIR=${0%/*}
. "$MODDIR/utils.sh"

# Early initialization
early_initialization() {
    # Load configuration
    load_config
    
    # Ensure base directory exists
    mkdir -p "$BASE_DIR"
    
    # Set proper permissions for all scripts
    chmod 755 "$MODDIR"/*.sh 2>/dev/null
    chmod 644 "$MODDIR/config.conf" 2>/dev/null
    chmod 644 "$LOG_FILE" 2>/dev/null
    
    log_message "INFO" "Advanced Anti-Bootloop module initialized (post-fs-data)"
    log_message "INFO" "Author: @overspend1/Wiktor | Version: 2.0"
    
    # System information logging
    log_message "INFO" "Device: $(getprop ro.product.device) | Android: $(getprop ro.build.version.release)"
    log_message "INFO" "Kernel: $(uname -r)"
    log_message "INFO" "KSU Version: $(cat /data/adb/ksu/version 2>/dev/null || echo 'Unknown')"
}

# Check for previous recovery events
check_recovery_history() {
    # Check for emergency recovery marker
    if [ -f "$BASE_DIR/emergency_recovery_marker" ]; then
        log_message "WARN" "Previous emergency recovery detected"
        
        # Send notification about previous emergency
        if [ "$BOOT_NOTIFICATIONS" = "true" ]; then
            send_notification "Recovery History" "Previous emergency recovery detected" "high"
        fi
    fi
    
    # Check recovery state
    local recovery_state=$(cat "$BASE_DIR/recovery_state" 2>/dev/null || echo "normal")
    if [ "$recovery_state" != "normal" ]; then
        log_message "INFO" "Previous recovery state: $recovery_state"
    fi
    
    # Log total boot count
    local total_boots=$(cat "$BASE_DIR/total_boots" 2>/dev/null || echo "0")
    log_message "INFO" "Total successful boots: $total_boots"
}

# Early conflict detection
early_conflict_check() {
    # Check for other bootloop protection modules
    if [ -d "/data/adb/modules" ]; then
        local conflicting_modules=""
        for module_dir in /data/adb/modules/*; do
            if [ -d "$module_dir" ]; then
                local module_name=$(basename "$module_dir")
                local module_prop="$module_dir/module.prop"
                
                if [ -f "$module_prop" ] && [ "$module_name" != "anti_bootloop_advanced_ksu" ]; then
                    # Check for conflicting descriptions
                    if grep -qi "bootloop\|recovery\|anti.*boot" "$module_prop" 2>/dev/null; then
                        conflicting_modules="$conflicting_modules $module_name"
                    fi
                fi
            fi
        done
        
        if [ -n "$conflicting_modules" ]; then
            log_message "WARN" "Potentially conflicting modules detected:$conflicting_modules"
        fi
    fi
}

# Initialize emergency systems
init_emergency_systems() {
    # Create emergency disable mechanism documentation
    cat > "$BASE_DIR/README_EMERGENCY.txt" << EOF
EMERGENCY DISABLE INSTRUCTIONS
==============================

To disable this module in case of emergency:

1. Create file: $EMERGENCY_DISABLE_FILE
   Command: touch $EMERGENCY_DISABLE_FILE

2. Or delete the module directory:
   Command: rm -rf /data/adb/modules/anti_bootloop_advanced_ksu

3. Or disable via KernelSU Manager

The module will detect the disable file and stop functioning.

For support, check logs at: $LOG_FILE
EOF
    
    # Set up crash handler
    trap 'log_message "ERROR" "Post-FS-Data script crashed at line $LINENO"' ERR
}

# Validate module integrity
validate_module_integrity() {
    local required_files="
        service.sh
        utils.sh
        backup_manager.sh
        recovery_engine.sh
        config.conf
        module.prop
    "
    
    local missing_files=""
    for file in $required_files; do
        if [ ! -f "$MODDIR/$file" ]; then
            missing_files="$missing_files $file"
        fi
    done
    
    if [ -n "$missing_files" ]; then
        log_message "ERROR" "Missing module files:$missing_files"
        return 1
    fi
    
    log_message "INFO" "Module integrity check passed"
    return 0
}

# Main execution
main() {
    early_initialization
    
    if ! validate_module_integrity; then
        log_message "CRITICAL" "Module integrity validation failed - module may not function properly"
        return 1
    fi
    
    check_recovery_history
    early_conflict_check
    init_emergency_systems
    
    # Early telemetry collection
    if [ "$TELEMETRY_ENABLED" = "true" ]; then
        collect_telemetry
    fi
    
    log_message "INFO" "Post-FS-Data initialization completed successfully"
}

# Run main function
main