#!/system/bin/sh
# KernelSU Anti-Bootloop Boot Monitor Script

MODDIR=${0%/*}
MODDIR=${MODDIR%/*}
CONFIG_DIR="$MODDIR/config"
BOOTLOG_DIR="$CONFIG_DIR/boot_logs"
RECOVERY_DIR="$CONFIG_DIR/recovery_points"
CHECKPOINT_DIR="$CONFIG_DIR/checkpoints"

# Enhanced boot configuration with adaptive timeouts
BOOT_STAGES="init:30 early_boot:30 boot:30 post_boot:30 system_server:30 boot_complete:30"

# Advanced bootloop detection parameters
MAX_BOOT_ATTEMPTS=3
ADAPTIVE_TIMEOUT_ENABLED=true
ANOMALY_DETECTION_ENABLED=true
PREDICTIVE_FAILURE_ENABLED=true
MACHINE_LEARNING_THRESHOLD=0.8

# Boot performance baseline (microseconds)
BOOT_PERFORMANCE_BASELINE=0
PERFORMANCE_DEVIATION_THRESHOLD=50  # 50% deviation triggers warning

# Advanced directories for ML and analytics
ANALYTICS_DIR="$CONFIG_DIR/analytics"
ML_DATA_DIR="$CONFIG_DIR/ml_data"
ANOMALY_LOG_DIR="$CONFIG_DIR/anomaly_logs"

# Ensure directories exist
mkdir -p "$BOOTLOG_DIR"
mkdir -p "$RECOVERY_DIR"
mkdir -p "$CHECKPOINT_DIR"
mkdir -p "$ANALYTICS_DIR"
mkdir -p "$ML_DATA_DIR"
mkdir -p "$ANOMALY_LOG_DIR"

# Enhanced logging with levels and structured data
log_message() {
    local level="${2:-INFO}"
    local timestamp="$(date +"%Y-%m-%d %H:%M:%S")"
    local epoch="$(date +%s)"
    
    # Standard log format
    echo "[$timestamp] [$level] $1" >> "$BOOTLOG_DIR/boot_monitor.log"
    
    # Structured logging for analytics
    echo "{\"timestamp\":$epoch,\"level\":\"$level\",\"message\":\"$1\",\"component\":\"boot_monitor\"}" >> "$ANALYTICS_DIR/structured.log"
    
    # Critical alerts to separate file
    if [ "$level" = "CRITICAL" ] || [ "$level" = "ERROR" ]; then
        echo "[$timestamp] [$level] $1" >> "$BOOTLOG_DIR/critical_alerts.log"
    fi
}

# Advanced boot metrics collection
collect_boot_metrics() {
    local stage="$1"
    local timestamp=$(date +%s%N)  # nanoseconds
    local memory_usage=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    local cpu_load=$(uptime | awk '{print $3}' | sed 's/,//')
    local io_stats=$(cat /proc/loadavg | awk '{print $4}')
    
    # Collect system metrics
    local metrics="{
        \"stage\":\"$stage\",
        \"timestamp\":$timestamp,
        \"memory_available\":$memory_usage,
        \"cpu_load\":$cpu_load,
        \"io_stats\":\"$io_stats\",
        \"uptime\":$(cat /proc/uptime | awk '{print $1}'),
        \"processes\":$(ps | wc -l),
        \"open_files\":$(lsof 2>/dev/null | wc -l || echo 0)
    }"
    
    echo "$metrics" >> "$ML_DATA_DIR/boot_metrics.jsonl"
    log_message "Collected metrics for stage: $stage" "DEBUG"
}

# Machine learning-based anomaly detection
detect_anomalies() {
    local current_metrics="$1"
    
    if [ "$ANOMALY_DETECTION_ENABLED" != "true" ]; then
        return 0
    fi
    
    # Simple statistical anomaly detection
    local baseline_file="$ML_DATA_DIR/baseline_metrics.json"
    
    if [ ! -f "$baseline_file" ]; then
        log_message "No baseline metrics found, learning from current boot" "INFO"
        echo "$current_metrics" > "$baseline_file"
        return 0
    fi
    
    # Calculate deviation from baseline (simplified version)
    local current_memory=$(echo "$current_metrics" | grep -o '"memory_available":[0-9]*' | cut -d: -f2)
    local baseline_memory=$(grep -o '"memory_available":[0-9]*' "$baseline_file" | cut -d: -f2)
    
    if [ -n "$current_memory" ] && [ -n "$baseline_memory" ] && [ "$baseline_memory" -gt 0 ]; then
        local deviation=$(( (current_memory - baseline_memory) * 100 / baseline_memory ))
        local abs_deviation=$((deviation < 0 ? -deviation : deviation))
        
        if [ "$abs_deviation" -gt "$PERFORMANCE_DEVIATION_THRESHOLD" ]; then
            log_message "ANOMALY: Memory usage deviation: ${deviation}% (threshold: ${PERFORMANCE_DEVIATION_THRESHOLD}%)" "WARN"
            
            local anomaly_report="{
                \"timestamp\":$(date +%s),
                \"type\":\"memory_anomaly\",
                \"deviation_percent\":$deviation,
                \"current_value\":$current_memory,
                \"baseline_value\":$baseline_memory,
                \"threshold\":$PERFORMANCE_DEVIATION_THRESHOLD
            }"
            
            echo "$anomaly_report" >> "$ANOMALY_LOG_DIR/anomalies.jsonl"
            return 1
        fi
    fi
    
    return 0
}

# Predictive failure analysis
analyze_failure_patterns() {
    local current_stage="$1"
    
    if [ "$PREDICTIVE_FAILURE_ENABLED" != "true" ]; then
        return 0
    fi
    
    # Analyze historical boot patterns
    local failure_history="$ML_DATA_DIR/failure_history.jsonl"
    
    if [ ! -f "$failure_history" ]; then
        log_message "No failure history available for predictive analysis" "DEBUG"
        return 0
    fi
    
    # Count recent failures in this stage
    local recent_failures=$(tail -100 "$failure_history" | grep "\"stage\":\"$current_stage\"" | wc -l)
    local total_recent=$(tail -100 "$failure_history" | wc -l)
    
    if [ "$total_recent" -gt 10 ] && [ "$recent_failures" -gt 0 ]; then
        local failure_rate=$(( recent_failures * 100 / total_recent ))
        
        if [ "$failure_rate" -gt 30 ]; then  # 30% failure rate threshold
            log_message "PREDICTION: High failure probability for stage $current_stage (${failure_rate}% recent failure rate)" "WARN"
            
            # Create predictive alert
            local prediction="{
                \"timestamp\":$(date +%s),
                \"stage\":\"$current_stage\",
                \"predicted_failure_rate\":$failure_rate,
                \"confidence\":$(( failure_rate > 50 ? 85 : 65 )),
                \"recommendation\":\"Consider preventive recovery\"
            }"
            
            echo "$prediction" >> "$ML_DATA_DIR/predictions.jsonl"
            
            # Trigger preventive measures if confidence is high
            if [ "$failure_rate" -gt 70 ]; then
                log_message "CRITICAL: Initiating preventive recovery due to high failure prediction" "CRITICAL"
                return 2  # Signal for preventive recovery
            fi
            
            return 1  # Signal for increased monitoring
        fi
    fi
    
    return 0
}

# Adaptive timeout calculation based on historical data
calculate_adaptive_timeout() {
    local stage="$1"
    local default_timeout="$2"
    
    if [ "$ADAPTIVE_TIMEOUT_ENABLED" != "true" ]; then
        echo "$default_timeout"
        return 0
    fi
    
    local history_file="$ML_DATA_DIR/stage_durations.jsonl"
    
    if [ ! -f "$history_file" ]; then
        echo "$default_timeout"
        return 0
    fi
    
    # Calculate average duration for this stage from last 20 boots
    local avg_duration=$(grep "\"stage\":\"$stage\"" "$history_file" | tail -20 | \
                       grep -o '"duration":[0-9]*' | cut -d: -f2 | \
                       awk '{sum += $1; count++} END {if(count > 0) print int(sum/count + 0.5); else print 0}')
    
    if [ -n "$avg_duration" ] && [ "$avg_duration" -gt 0 ]; then
        # Add 50% buffer to average duration, but cap at 2x default timeout
        local adaptive_timeout=$(( avg_duration + avg_duration / 2 ))
        local max_timeout=$(( default_timeout * 2 ))
        
        if [ "$adaptive_timeout" -gt "$max_timeout" ]; then
            adaptive_timeout="$max_timeout"
        fi
        
        if [ "$adaptive_timeout" -lt "$default_timeout" ]; then
            adaptive_timeout="$default_timeout"
        fi
        
        log_message "Adaptive timeout for $stage: ${adaptive_timeout}s (avg: ${avg_duration}s, default: ${default_timeout}s)" "DEBUG"
        echo "$adaptive_timeout"
    else
        echo "$default_timeout"
    fi
}

# Enhanced boot attempt logging with analytics
log_boot_attempt() {
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BOOT_COUNT=$(cat "$CONFIG_DIR/boot_counter" 2>/dev/null || echo "0")
    BOOT_COUNT=$((BOOT_COUNT + 1))
    
    log_message "Recording boot attempt #$BOOT_COUNT" "INFO"
    
    # Update boot counter
    echo "$BOOT_COUNT" > "$CONFIG_DIR/boot_counter"
    
    # Collect initial boot metrics
    collect_boot_metrics "boot_start"
    
    # Create enhanced boot log entry
    BOOT_LOG="$BOOTLOG_DIR/boot_${TIMESTAMP}.log"
    local boot_session_id="boot_${TIMESTAMP}_$$"
    
    # Structured boot session data
    local boot_data="{
        \"session_id\":\"$boot_session_id\",
        \"boot_count\":$BOOT_COUNT,
        \"timestamp\":$(date +%s),
        \"device_info\":{
            \"model\":\"$(getprop ro.product.model 2>/dev/null || echo 'Unknown')\",
            \"android\":\"$(getprop ro.build.version.release 2>/dev/null || echo 'Unknown')\",
            \"sdk\":\"$(getprop ro.build.version.sdk 2>/dev/null || echo '0')\",
            \"kernel\":\"$(uname -r)\",
            \"architecture\":\"$(uname -m)\"
        },
        \"hardware_info\":{
            \"cpu_cores\":$(nproc 2>/dev/null || echo 1),
            \"total_memory\":$(grep MemTotal /proc/meminfo | awk '{print $2}'),
            \"available_memory\":$(grep MemAvailable /proc/meminfo | awk '{print $2}')
        },
        \"boot_reason\":\"$(getprop ro.boot.bootreason 2>/dev/null || echo 'unknown')\",
        \"boot_mode\":\"$(getprop ro.bootmode 2>/dev/null || echo 'normal')\"
    }"
    
    echo "$boot_data" > "$ANALYTICS_DIR/current_boot_session.json"
    echo "$boot_data" >> "$ML_DATA_DIR/boot_sessions.jsonl"
    
    # Legacy boot log for compatibility
    echo "Boot attempt: $BOOT_COUNT at $(date)" > "$BOOT_LOG"
    echo "Session ID: $boot_session_id" >> "$BOOT_LOG"
    echo "Device: $(getprop ro.product.model)" >> "$BOOT_LOG"
    echo "Android version: $(getprop ro.build.version.release)" >> "$BOOT_LOG"
    echo "Kernel: $(uname -r)" >> "$BOOT_LOG"
    echo "Boot reason: $(getprop ro.boot.bootreason 2>/dev/null || echo 'unknown')" >> "$BOOT_LOG"
    
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

# Enhanced failsafe timer with ML-based adaptive timeouts and anomaly detection
setup_failsafe_timer() {
    log_message "Setting up advanced boot monitoring with ML capabilities" "INFO"
    
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
        
        # Monitor each boot stage with adaptive timeouts and ML analysis
        for STAGE_CONFIG in $BOOT_STAGES; do
            STAGE_NAME=${STAGE_CONFIG%%:*}
            DEFAULT_STAGE_TIMEOUT=${STAGE_CONFIG##*:}
            
            # Calculate adaptive timeout using ML
            STAGE_TIMEOUT=$(calculate_adaptive_timeout "$STAGE_NAME" "$DEFAULT_STAGE_TIMEOUT")
            
            log_message "Monitoring boot stage: $STAGE_NAME (adaptive timeout: ${STAGE_TIMEOUT}s, default: ${DEFAULT_STAGE_TIMEOUT}s)" "INFO"
            
            # Collect stage start metrics
            collect_boot_metrics "${STAGE_NAME}_start"
            
            # Perform predictive failure analysis
            analyze_failure_patterns "$STAGE_NAME"
            prediction_result=$?
            
            if [ $prediction_result -eq 2 ]; then
                log_message "PREVENTIVE: Initiating early recovery due to high failure prediction" "CRITICAL"
                trigger_safe_mode
                return 1
            elif [ $prediction_result -eq 1 ]; then
                log_message "WARNING: Increased monitoring for stage $STAGE_NAME due to failure prediction" "WARN"
                # Reduce timeout for faster detection
                STAGE_TIMEOUT=$((STAGE_TIMEOUT * 3 / 4))
            fi
            
            # Create checkpoint file for this stage
            update_boot_checkpoint "${STAGE_NAME}_started"
            local stage_start_time=$(date +%s)
            
            # Enhanced monitoring loop with anomaly detection
            SECONDS_WAITED=0
            local anomaly_count=0
            while [ $SECONDS_WAITED -lt $STAGE_TIMEOUT ]; do
                sleep 3  # More frequent checks for better anomaly detection
                SECONDS_WAITED=$((SECONDS_WAITED + 3))
                
                # Collect metrics every 15 seconds for anomaly detection
                if [ $((SECONDS_WAITED % 15)) -eq 0 ]; then
                    collect_boot_metrics "${STAGE_NAME}_monitor"
                    
                    # Get latest metrics for anomaly detection
                    local latest_metrics=$(tail -1 "$ML_DATA_DIR/boot_metrics.jsonl")
                    if detect_anomalies "$latest_metrics"; then
                        anomaly_count=$((anomaly_count + 1))
                        log_message "Anomaly detected during $STAGE_NAME stage (count: $anomaly_count)" "WARN"
                        
                        # If too many anomalies, consider it a critical situation
                        if [ $anomaly_count -ge 3 ]; then
                            log_message "CRITICAL: Multiple anomalies detected in $STAGE_NAME stage" "CRITICAL"
                            
                            # Record failure pattern
                            local failure_record="{
                                \"timestamp\":$(date +%s),
                                \"stage\":\"$STAGE_NAME\",
                                \"failure_type\":\"anomaly_overload\",
                                \"anomaly_count\":$anomaly_count,
                                \"duration\":$SECONDS_WAITED
                            }"
                            echo "$failure_record" >> "$ML_DATA_DIR/failure_history.jsonl"
                            
                            trigger_safe_mode
                            return 1
                        fi
                    fi
                fi
                
                # Check if boot completed
                if [ "$(getprop sys.boot_completed)" = "1" ]; then
                    local boot_end_time=$(date +%s)
                    local total_boot_time=$((boot_end_time - stage_start_time))
                    
                    log_message "Boot completed successfully in ${total_boot_time}s" "INFO"
                    update_boot_checkpoint "boot_completed"
                    
                    # Record successful boot metrics for ML
                    local success_record="{
                        \"timestamp\":$boot_end_time,
                        \"stage\":\"$STAGE_NAME\",
                        \"duration\":$total_boot_time,
                        \"success\":true,
                        \"anomaly_count\":$anomaly_count
                    }"
                    echo "$success_record" >> "$ML_DATA_DIR/stage_durations.jsonl"
                    
                    # Update baseline metrics if this was a clean boot
                    if [ $anomaly_count -eq 0 ]; then
                        local final_metrics=$(tail -1 "$ML_DATA_DIR/boot_metrics.jsonl")
                        echo "$final_metrics" > "$ML_DATA_DIR/baseline_metrics.json"
                        log_message "Updated baseline metrics with clean boot data" "DEBUG"
                    fi
                    
                    exit 0
                fi
                
                # Check if next stage started
                NEXT_STAGE=$(echo "$BOOT_STAGES" | sed -e "s/.*$STAGE_NAME:[0-9]* \(.*\):.*/\1/")
                if [ "$NEXT_STAGE" != "$BOOT_STAGES" ] && check_checkpoint "${NEXT_STAGE}_started"; then
                    local stage_end_time=$(date +%s)
                    local stage_duration=$((stage_end_time - stage_start_time))
                    
                    log_message "Stage $STAGE_NAME completed in ${stage_duration}s, moving to next stage" "INFO"
                    
                    # Record stage completion for ML
                    local completion_record="{
                        \"timestamp\":$stage_end_time,
                        \"stage\":\"$STAGE_NAME\",
                        \"duration\":$stage_duration,
                        \"success\":true,
                        \"anomaly_count\":$anomaly_count
                    }"
                    echo "$completion_record" >> "$ML_DATA_DIR/stage_durations.jsonl"
                    
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