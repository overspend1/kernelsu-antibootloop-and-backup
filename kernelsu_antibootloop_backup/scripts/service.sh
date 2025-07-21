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
ANALYTICS_DIR="$CONFIG_DIR/analytics"
PERF_DIR="$CONFIG_DIR/performance"

# Performance monitoring
SERVICE_START_TIME=$(date +%s%N)
MAX_CONCURRENT_JOBS=4
CURRENT_JOBS=0

# Enhanced logging with performance metrics
log_message() {
    local level="${2:-INFO}"
    local timestamp="$(date +"%Y-%m-%d %H:%M:%S")"
    local elapsed_ns=$(($(date +%s%N) - SERVICE_START_TIME))
    local elapsed_ms=$((elapsed_ns / 1000000))
    
    echo "[$timestamp] [service:$level] (+${elapsed_ms}ms) $1" >> "$MODDIR/scripts/module.log"
    
    # Performance logging
    if [ "$level" = "PERF" ]; then
        echo "{\"timestamp\":$(date +%s),\"component\":\"service\",\"metric\":\"$1\",\"elapsed_ms\":$elapsed_ms}" >> "$PERF_DIR/service_metrics.jsonl"
    fi
}

# Job management for concurrent execution
start_background_job() {
    local job_name="$1"
    local job_command="$2"
    
    if [ $CURRENT_JOBS -ge $MAX_CONCURRENT_JOBS ]; then
        log_message "Job queue full, waiting for slot" "WARN"
        wait_for_job_slot
    fi
    
    log_message "Starting background job: $job_name" "DEBUG"
    (
        eval "$job_command"
        echo $? > "$PERF_DIR/${job_name}_exit_code"
        log_message "Job completed: $job_name" "DEBUG"
    ) &
    
    local job_pid=$!
    echo "$job_pid" > "$PERF_DIR/${job_name}_pid"
    CURRENT_JOBS=$((CURRENT_JOBS + 1))
    
    return $job_pid
}

# Wait for available job slot
wait_for_job_slot() {
    while [ $CURRENT_JOBS -ge $MAX_CONCURRENT_JOBS ]; do
        sleep 0.1
        # Count running jobs
        local running_jobs=0
        for pid_file in "$PERF_DIR"/*_pid; do
            if [ -f "$pid_file" ]; then
                local pid=$(cat "$pid_file")
                if kill -0 "$pid" 2>/dev/null; then
                    running_jobs=$((running_jobs + 1))
                else
                    rm -f "$pid_file"
                fi
            fi
        done
        CURRENT_JOBS=$running_jobs
    done
}

# Ensure performance directory exists
mkdir -p "$PERF_DIR"

log_message "Starting enhanced service execution with performance monitoring" "INFO"

# Record service start performance
log_message "service_start" "PERF"

# Create boot checkpoint - boot stage reached
if [ -d "$CHECKPOINT_DIR" ]; then
    log_message "Creating boot stage checkpoint" "DEBUG"
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    echo "$TIMESTAMP" > "$CHECKPOINT_DIR/boot_stage_reached"
    log_message "checkpoint_created" "PERF"
fi

# Pre-create all necessary directories for better performance
mkdir -p "$ANALYTICS_DIR" "$PERF_DIR" 2>/dev/null
log_message "directories_initialized" "PERF"

# Check if we're in safe mode
is_safe_mode() {
    if [ -f "$SAFEMODE_DIR/active" ] || [ -f "$CONFIG_DIR/bootloop_detected" ] || [ -f "$SAFEMODE_DIR/manual_trigger" ]; then
        return 0
    else
        return 1
    fi
}

# Start safety monitoring service with performance optimization
if [ -f "$MODDIR/scripts/safety-service.sh" ]; then
    is_safe_mode
    SAFE_MODE=$?
    
    if [ $SAFE_MODE -eq 0 ]; then
        log_message "Safe mode detected, starting enhanced safety service" "WARN"
        start_background_job "safety_service_safe" "sh '$MODDIR/scripts/safety-service.sh' safe_mode"
    else
        log_message "Starting safety monitoring service" "INFO"
        start_background_job "safety_service" "sh '$MODDIR/scripts/safety-service.sh'"
    fi
    
    log_message "safety_service_started" "PERF"
else
    log_message "Critical: safety-service.sh not found" "ERROR"
fi

# Enhanced boot completion monitoring with intelligent waiting
start_background_job "boot_monitor" "
    # Intelligent boot completion detection with timeout
    local boot_timeout=120  # 2 minutes maximum wait
    local elapsed=0
    
    log_message 'Waiting for system boot completion' 'INFO'
    
    while [ \$(getprop sys.boot_completed) != '1' ] && [ \$elapsed -lt \$boot_timeout ]; do
        # Check multiple boot indicators for faster detection
        if [ \$(getprop sys.boot_completed) = '1' ] || [ \$(getprop ro.boot.complete) = '1' ]; then
            break
        fi
        
        # Progressive sleep - start with shorter intervals
        if [ \$elapsed -lt 30 ]; then
            sleep 0.5
        else
            sleep 1
        fi
        
        elapsed=\$((elapsed + 1))
    done
    
    if [ \$(getprop sys.boot_completed) != '1' ]; then
        log_message 'Boot completion timeout reached, proceeding anyway' 'WARN'
    else
        log_message 'System boot completed successfully' 'INFO'
        log_message 'boot_completed' 'PERF'
    fi"

# Continue with post-boot services while boot monitor runs
(
    # Wait for our boot monitor job to complete
    while [ ! -f "$PERF_DIR/boot_monitor_exit_code" ]; do
        sleep 0.1
    done
    
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
    
    # Start WebUI server with performance optimization
    if [ -f "$MODDIR/scripts/webui-server.sh" ]; then
        # Load configuration efficiently
        local config_file="$MODDIR/config/settings.json"
        local webui_enabled="true"
        
        if [ -f "$config_file" ]; then
            webui_enabled=$(grep -o '"webuiEnabled":\s*[^,}]*' "$config_file" | sed 's/.*://g' | tr -d ' "' || echo "true")
        fi
        
        if [ "$webui_enabled" = "true" ]; then
            log_message "Starting optimized WebUIX server" "INFO"
            start_background_job "webui_server" "sh '$MODDIR/scripts/webui-server.sh'"
            log_message "webui_server_started" "PERF"
        else
            log_message "WebUIX server disabled in configuration" "DEBUG"
        fi
    else
        log_message "Warning: webui-server.sh not found" "WARN"
    fi
    
    # Execute optimized auto-backup if enabled
    if [ -f "$MODDIR/scripts/backup-engine.sh" ]; then
        local config_file="$MODDIR/config/settings.json"
        local auto_backup="false"
        
        if [ -f "$config_file" ]; then
            auto_backup=$(grep -o '"autoBackup":\s*[^,}]*' "$config_file" | sed 's/.*://g' | tr -d ' "' || echo "false")
        fi
        
        if [ "$auto_backup" = "true" ]; then
            log_message "Starting intelligent auto-backup" "INFO"
            
            # Create unique backup name with session ID
            local backup_name="AutoBackup_$(date +'%Y%m%d_%H%M%S')_$$"
            
            # Start backup with incremental support for better performance
            start_background_job "auto_backup" "sh '$MODDIR/scripts/backup-engine.sh' create_backup default '$backup_name' 'Automated boot backup' true"
            log_message "auto_backup_started" "PERF"
        else
            log_message "Auto-backup disabled in configuration" "DEBUG"
        fi
    else
        log_message "Warning: backup-engine.sh not found" "WARN"
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
    
    # Wait for all critical jobs to complete
    log_message "Waiting for critical jobs to complete" "DEBUG"
    
    # Monitor job completion with timeout
    local job_timeout=60
    local job_elapsed=0
    
    while [ $job_elapsed -lt $job_timeout ]; do
        local pending_jobs=0
        
        # Check critical jobs
        for job in safety_service webui_server; do
            if [ ! -f "$PERF_DIR/${job}_exit_code" ] && [ -f "$PERF_DIR/${job}_pid" ]; then
                local pid=$(cat "$PERF_DIR/${job}_pid")
                if kill -0 "$pid" 2>/dev/null; then
                    pending_jobs=$((pending_jobs + 1))
                fi
            fi
        done
        
        if [ $pending_jobs -eq 0 ]; then
            break
        fi
        
        sleep 1
        job_elapsed=$((job_elapsed + 1))
    done
    
    # Generate performance summary
    local service_end_time=$(date +%s%N)
    local total_elapsed_ms=$(((service_end_time - SERVICE_START_TIME) / 1000000))
    
    log_message "Service initialization completed in ${total_elapsed_ms}ms" "INFO"
    log_message "service_complete:${total_elapsed_ms}" "PERF"
    
    # Write performance summary
    cat > "$PERF_DIR/service_summary.json" << EOF
{
    "service_start": $SERVICE_START_TIME,
    "service_end": $service_end_time,
    "total_duration_ms": $total_elapsed_ms,
    "concurrent_jobs": $MAX_CONCURRENT_JOBS,
    "timestamp": $(date +%s)
}
EOF
    
    log_message "All post-boot services initialized successfully" "INFO"
) &

log_message "Enhanced service execution completed, monitoring jobs in background" "INFO"