#!/system/bin/sh

# Advanced Anti-Bootloop KSU Module Service Script
# Author: @overspend1/Wiktor
# Advanced bootloop protection with progressive recovery and hardware monitoring

MODDIR=${0%/*}
. "$MODDIR/utils.sh"
. "$MODDIR/recovery_engine.sh"

BOOT_COUNT_FILE="$BASE_DIR/boot_count"
SUCCESS_MARKER="$BASE_DIR/boot_success"

# Main service entry point
main_service() {
    # Load configuration
    load_config
    
    # Check for emergency disable
    if check_emergency_disable; then
        log_message "INFO" "Module disabled via emergency file"
        return 0
    fi
    
    # Initialize recovery engine
    init_recovery_engine

    # Initialize boot counter if it doesn't exist
    if [ ! -f "$BOOT_COUNT_FILE" ]; then
        echo "0" > "$BOOT_COUNT_FILE"
    fi
    
    # Read current boot count
    BOOT_COUNT=$(cat "$BOOT_COUNT_FILE")
    NEW_BOOT_COUNT=$((BOOT_COUNT + 1))
    
    log_message "INFO" "Boot attempt #$NEW_BOOT_COUNT (max: $MAX_BOOT_ATTEMPTS)"
    
    # Collect telemetry
    collect_telemetry

    # Create initial kernel backup if needed
    if [ "$NEW_BOOT_COUNT" -eq 1 ] || [ ! -f "$BACKUP_DIR/stock.img" ]; then
        log_message "INFO" "Creating initial kernel backup..."
        if create_backup "stock" "Initial stock kernel backup" "true"; then
            log_message "INFO" "Stock kernel backup created successfully"
        else
            log_message "ERROR" "Failed to create stock kernel backup"
        fi
    fi

    # Perform hardware health check
    local hardware_issues=$(check_hardware_health)
    if [ -n "$hardware_issues" ]; then
        log_message "WARN" "Hardware issues detected: $hardware_issues"
        
        if [ "$WARNING_NOTIFICATIONS" = "true" ]; then
            send_notification "Hardware Warning" "Issues: $hardware_issues" "high"
        fi
    fi
    
    # Check for conflicts
    detect_conflicts
    
    # Verify kernel integrity
    check_kernel_integrity
    
    # Check if we've exceeded maximum boot attempts
    if [ "$NEW_BOOT_COUNT" -ge "$MAX_BOOT_ATTEMPTS" ]; then
        log_message "ERROR" "Boot attempt limit exceeded ($NEW_BOOT_COUNT >= $MAX_BOOT_ATTEMPTS)"
        
        # Execute recovery strategy
        execute_recovery_strategy "$NEW_BOOT_COUNT"
        
        # Reset boot counter after recovery attempt
        echo "0" > "$BOOT_COUNT_FILE"
        log_message "INFO" "Boot counter reset after recovery attempt"
        
        return 0
    else
        # Update boot counter
        echo "$NEW_BOOT_COUNT" > "$BOOT_COUNT_FILE"
        log_message "INFO" "Boot counter updated to $NEW_BOOT_COUNT"
    fi

    # Set up delayed boot success detection
    setup_boot_success_detection
    
    # Start WebUI server if enabled
    if [ "$WEBUI_ENABLED" = "true" ]; then
        log_message "INFO" "Auto-starting WebUI server"
        sh "$MODDIR/webui_manager.sh" auto &
    fi
}

# Set up boot success detection with configurable timeout
setup_boot_success_detection() {
    (
        sleep "$BOOT_SUCCESS_TIMEOUT"
        
        # Check if boot was successful
        if [ -f "$BOOT_COUNT_FILE" ]; then
            local current_count=$(cat "$BOOT_COUNT_FILE")
            
            if [ "$current_count" -gt 0 ]; then
                # Successful boot detected
                echo "0" > "$BOOT_COUNT_FILE"
                touch "$SUCCESS_MARKER"
                
                log_message "INFO" "Boot successful - counter reset after ${BOOT_SUCCESS_TIMEOUT}s"
                
                # Reset recovery state
                reset_recovery_state
                
                # Send success notification if enabled
                if [ "$BOOT_NOTIFICATIONS" = "true" ]; then
                    send_notification "Boot Success" "System started successfully" "normal"
                fi
                
                # Verify all backups periodically (every 10th successful boot)
                local boot_number=$(( $(cat "$BASE_DIR/total_boots" 2>/dev/null || echo "0") + 1 ))
                echo "$boot_number" > "$BASE_DIR/total_boots"
                
                if [ $((boot_number % 10)) -eq 0 ]; then
                    log_message "INFO" "Periodic backup verification (boot #$boot_number)"
                    verify_all_backups
                fi
            fi
        fi
    ) &
}

# Run main service
main_service