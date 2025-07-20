#!/system/bin/sh

# Advanced Anti-Bootloop KSU Module - Health Monitor
# Author: @overspend1/Wiktor
# Proactive system health monitoring and alerts

MODDIR=${0%/*}
. "$MODDIR/utils.sh"

HEALTH_LOG="$BASE_DIR/health_monitor.log"
ALERT_FILE="$BASE_DIR/health_alerts"
PREDICTION_FILE="$BASE_DIR/bootloop_prediction"

# Health monitoring thresholds
CRITICAL_CPU_TEMP=85
WARNING_CPU_TEMP=75
CRITICAL_RAM=100
WARNING_RAM=200
MAX_CONSECUTIVE_WARNINGS=3

# Initialize health monitoring
init_health_monitor() {
    log_message "INFO" "Health monitor initialized"
    
    # Create health tracking files
    [ ! -f "$HEALTH_LOG" ] && echo "timestamp,cpu_temp,ram_mb,storage_health,uptime,boot_count" > "$HEALTH_LOG"
    [ ! -f "$ALERT_FILE" ] && touch "$ALERT_FILE"
    [ ! -f "$PREDICTION_FILE" ] && echo "0" > "$PREDICTION_FILE"
}

# Collect health metrics
collect_health_metrics() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local cpu_temp=$(get_cpu_temp)
    local available_ram=$(get_available_ram)
    local storage_health=$(get_storage_health)
    local uptime=$(cat /proc/uptime | cut -d' ' -f1)
    local boot_count=$(cat "$BOOT_COUNT_FILE" 2>/dev/null || echo "0")
    
    # Log metrics
    echo "$timestamp,$cpu_temp,$available_ram,$storage_health,$uptime,$boot_count" >> "$HEALTH_LOG"
    
    # Rotate health log if too large (keep last 1000 entries)
    if [ $(wc -l < "$HEALTH_LOG") -gt 1000 ]; then
        tail -1000 "$HEALTH_LOG" > "$HEALTH_LOG.tmp"
        mv "$HEALTH_LOG.tmp" "$HEALTH_LOG"
    fi
    
    return 0
}

# Analyze health trends
analyze_health_trends() {
    if [ ! -f "$HEALTH_LOG" ] || [ $(wc -l < "$HEALTH_LOG") -lt 10 ]; then
        return 0
    fi
    
    # Get recent data (last 10 entries)
    local recent_data=$(tail -10 "$HEALTH_LOG" | grep -v "timestamp")
    
    # Analyze CPU temperature trend
    local temp_trend=$(echo "$recent_data" | awk -F',' '{print $2}' | awk '
        BEGIN { sum=0; count=0; trend=0 }
        { 
            if (NR > 1) {
                if ($1 > prev) trend++;
                else if ($1 < prev) trend--;
            }
            prev = $1; sum += $1; count++
        }
        END { 
            avg = sum/count;
            if (trend > 3) print "RISING," avg;
            else if (trend < -3) print "FALLING," avg;
            else print "STABLE," avg;
        }
    ')
    
    local temp_status=$(echo "$temp_trend" | cut -d',' -f1)
    local temp_avg=$(echo "$temp_trend" | cut -d',' -f2)
    
    # Analyze RAM trend
    local ram_trend=$(echo "$recent_data" | awk -F',' '{print $3}' | awk '
        BEGIN { sum=0; count=0; trend=0 }
        { 
            if (NR > 1) {
                if ($1 < prev) trend++;  # Less RAM = worse
                else if ($1 > prev) trend--;
            }
            prev = $1; sum += $1; count++
        }
        END { 
            avg = sum/count;
            if (trend > 3) print "WORSENING," avg;
            else if (trend < -3) print "IMPROVING," avg;
            else print "STABLE," avg;
        }
    ')
    
    local ram_status=$(echo "$ram_trend" | cut -d',' -f1)
    local ram_avg=$(echo "$ram_trend" | cut -d',' -f2)
    
    # Generate health assessment
    echo "TEMP_TREND:$temp_status:$temp_avg"
    echo "RAM_TREND:$ram_status:$ram_avg"
}

# Check for critical conditions
check_critical_conditions() {
    local cpu_temp=$(get_cpu_temp)
    local available_ram=$(get_available_ram)
    local boot_count=$(cat "$BOOT_COUNT_FILE" 2>/dev/null || echo "0")
    local alerts=""
    
    # Critical CPU temperature
    if [ "$cpu_temp" -gt "$CRITICAL_CPU_TEMP" ]; then
        alerts="$alerts CRITICAL_TEMP:$cpu_temp"
        log_message "CRITICAL" "CPU temperature critical: ${cpu_temp}°C (threshold: ${CRITICAL_CPU_TEMP}°C)"
        
        # Emergency thermal protection
        if [ "$cpu_temp" -gt 90 ]; then
            emergency_thermal_protection
        fi
    elif [ "$cpu_temp" -gt "$WARNING_CPU_TEMP" ]; then
        alerts="$alerts WARNING_TEMP:$cpu_temp"
        log_message "WARN" "CPU temperature high: ${cpu_temp}°C (threshold: ${WARNING_CPU_TEMP}°C)"
    fi
    
    # Critical RAM
    if [ "$available_ram" -lt "$CRITICAL_RAM" ]; then
        alerts="$alerts CRITICAL_RAM:$available_ram"
        log_message "CRITICAL" "Available RAM critical: ${available_ram}MB (threshold: ${CRITICAL_RAM}MB)"
        
        # Emergency RAM cleanup
        emergency_ram_cleanup
    elif [ "$available_ram" -lt "$WARNING_RAM" ]; then
        alerts="$alerts WARNING_RAM:$available_ram"
        log_message "WARN" "Available RAM low: ${available_ram}MB (threshold: ${WARNING_RAM}MB)"
    fi
    
    # Boot count approaching limit
    if [ "$boot_count" -ge $((MAX_BOOT_ATTEMPTS - 1)) ]; then
        alerts="$alerts CRITICAL_BOOT_COUNT:$boot_count"
        log_message "CRITICAL" "Boot count critical: $boot_count (limit: $MAX_BOOT_ATTEMPTS)"
    elif [ "$boot_count" -ge $((MAX_BOOT_ATTEMPTS / 2)) ]; then
        alerts="$alerts WARNING_BOOT_COUNT:$boot_count"
        log_message "WARN" "Boot count elevated: $boot_count (limit: $MAX_BOOT_ATTEMPTS)"
    fi
    
    # Store alerts
    if [ -n "$alerts" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S'):$alerts" >> "$ALERT_FILE"
        return 1
    fi
    
    return 0
}

# Bootloop prediction algorithm
predict_bootloop_risk() {
    local risk_score=0
    local factors=""
    
    # Factor 1: Current boot count
    local boot_count=$(cat "$BOOT_COUNT_FILE" 2>/dev/null || echo "0")
    if [ "$boot_count" -gt 0 ]; then
        risk_score=$((risk_score + boot_count * 20))
        factors="$factors BOOT_COUNT:$boot_count"
    fi
    
    # Factor 2: Hardware stress
    local cpu_temp=$(get_cpu_temp)
    if [ "$cpu_temp" -gt "$WARNING_CPU_TEMP" ]; then
        risk_score=$((risk_score + 15))
        factors="$factors HIGH_TEMP:$cpu_temp"
    fi
    
    local available_ram=$(get_available_ram)
    if [ "$available_ram" -lt "$WARNING_RAM" ]; then
        risk_score=$((risk_score + 10))
        factors="$factors LOW_RAM:$available_ram"
    fi
    
    # Factor 3: Recent recovery events
    local recovery_state=$(get_recovery_state)
    if [ "$recovery_state" != "normal" ]; then
        case "$recovery_state" in
            "monitoring") risk_score=$((risk_score + 5)) ;;
            "safe_mode") risk_score=$((risk_score + 15)) ;;
            "kernel_recovery") risk_score=$((risk_score + 25)) ;;
            "emergency") risk_score=$((risk_score + 35)) ;;
        esac
        factors="$factors RECOVERY_STATE:$recovery_state"
    fi
    
    # Factor 4: Module conflicts
    if ! detect_conflicts; then
        risk_score=$((risk_score + 10))
        factors="$factors MODULE_CONFLICTS"
    fi
    
    # Factor 5: Historical patterns
    if [ -f "$HEALTH_LOG" ]; then
        local recent_issues=$(tail -20 "$HEALTH_LOG" | grep -c "ERROR\|CRITICAL" 2>/dev/null || echo "0")
        if [ "$recent_issues" -gt 3 ]; then
            risk_score=$((risk_score + recent_issues * 2))
            factors="$factors RECENT_ISSUES:$recent_issues"
        fi
    fi
    
    # Factor 6: Uptime patterns (very short uptimes indicate instability)
    local uptime=$(cat /proc/uptime | cut -d' ' -f1)
    local uptime_minutes=$(echo "$uptime" | awk '{print int($1/60)}')
    if [ "$uptime_minutes" -lt 5 ] && [ "$boot_count" -gt 0 ]; then
        risk_score=$((risk_score + 20))
        factors="$factors SHORT_UPTIME:${uptime_minutes}min"
    fi
    
    # Store prediction
    echo "$risk_score" > "$PREDICTION_FILE"
    
    # Risk levels
    local risk_level="LOW"
    if [ "$risk_score" -ge 70 ]; then
        risk_level="CRITICAL"
    elif [ "$risk_score" -ge 50 ]; then
        risk_level="HIGH"
    elif [ "$risk_score" -ge 30 ]; then
        risk_level="MEDIUM"
    fi
    
    log_message "INFO" "Bootloop risk assessment: $risk_level (score: $risk_score, factors: $factors)"
    
    # Take preventive action for high risk
    if [ "$risk_score" -ge 50 ]; then
        take_preventive_action "$risk_level" "$risk_score"
    fi
    
    echo "$risk_level:$risk_score:$factors"
}

# Take preventive action based on risk level
take_preventive_action() {
    local risk_level="$1"
    local risk_score="$2"
    
    log_message "WARN" "Taking preventive action for $risk_level risk (score: $risk_score)"
    
    case "$risk_level" in
        "HIGH")
            # Create emergency backup
            create_backup "emergency_$(date '+%Y%m%d_%H%M%S')" "Emergency backup due to high bootloop risk" "true"
            
            # Enable safe mode if not already active
            if ! is_safe_mode_active; then
                log_message "WARN" "Enabling safe mode due to high bootloop risk"
                enable_safe_mode
            fi
            ;;
        "CRITICAL")
            # All HIGH actions plus more aggressive measures
            create_backup "emergency_$(date '+%Y%m%d_%H%M%S')" "Emergency backup due to critical bootloop risk" "true"
            
            if ! is_safe_mode_active; then
                log_message "CRITICAL" "Enabling safe mode due to critical bootloop risk"
                enable_safe_mode
            fi
            
            # Disable problematic modules
            disable_problematic_modules
            
            # Reduce recovery threshold temporarily
            if [ "$MAX_BOOT_ATTEMPTS" -gt 2 ]; then
                log_message "CRITICAL" "Reducing boot attempt threshold due to critical risk"
                # This would require updating the config, but we'll just log it for now
            fi
            ;;
    esac
}

# Emergency thermal protection
emergency_thermal_protection() {
    log_message "CRITICAL" "Activating emergency thermal protection"
    
    # Try to reduce CPU load by disabling non-essential services
    local services_to_stop="
        com.android.systemui.ImageWallpaper
        com.android.providers.media
        com.google.android.gms
    "
    
    for service in $services_to_stop; do
        if pgrep -f "$service" >/dev/null 2>&1; then
            log_message "INFO" "Attempting to stop $service for thermal protection"
            pkill -f "$service" 2>/dev/null
        fi
    done
    
    # Force garbage collection
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null
    
    # Create thermal protection marker
    echo "$(date '+%Y-%m-%d %H:%M:%S')" > "$BASE_DIR/thermal_protection_active"
}

# Emergency RAM cleanup
emergency_ram_cleanup() {
    log_message "CRITICAL" "Activating emergency RAM cleanup"
    
    # Force memory reclaim
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null
    echo 1 > /proc/sys/vm/compact_memory 2>/dev/null
    
    # Kill memory-heavy processes if critical
    local available_ram=$(get_available_ram)
    if [ "$available_ram" -lt 50 ]; then
        log_message "CRITICAL" "RAM critically low, attempting to free memory"
        
        # Kill some non-essential processes
        local memory_hogs=$(ps -eo pid,comm,%mem --sort=-%mem | head -10 | awk '$3 > 5 {print $1}' | tail -5)
        for pid in $memory_hogs; do
            local comm=$(ps -p "$pid" -o comm= 2>/dev/null)
            if [ -n "$comm" ] && [ "$comm" != "system_server" ] && [ "$comm" != "zygote" ]; then
                log_message "WARN" "Killing memory-heavy process: $comm (PID: $pid)"
                kill "$pid" 2>/dev/null
            fi
        done
    fi
    
    # Create RAM cleanup marker
    echo "$(date '+%Y-%m-%d %H:%M:%S')" > "$BASE_DIR/ram_cleanup_active"
}

# Generate health report
generate_health_report() {
    local report_file="$BASE_DIR/health_report_$(date '+%Y%m%d_%H%M%S').txt"
    
    {
        echo "Advanced Anti-Bootloop KSU - Health Report"
        echo "=========================================="
        echo "Generated: $(date)"
        echo "Author: @overspend1/Wiktor"
        echo ""
        
        echo "Current System Status:"
        echo "----------------------"
        echo "CPU Temperature: $(get_cpu_temp)°C"
        echo "Available RAM: $(get_available_ram)MB"
        echo "Storage Health: $(get_storage_health)"
        echo "Boot Count: $(cat "$BOOT_COUNT_FILE" 2>/dev/null || echo "0")"
        echo "Recovery State: $(get_recovery_state)"
        echo "Safe Mode: $(is_safe_mode_active && echo "Active" || echo "Inactive")"
        echo ""
        
        echo "Health Trends:"
        echo "--------------"
        analyze_health_trends
        echo ""
        
        echo "Bootloop Risk Assessment:"
        echo "-------------------------"
        predict_bootloop_risk
        echo ""
        
        echo "Recent Alerts:"
        echo "--------------"
        if [ -f "$ALERT_FILE" ] && [ -s "$ALERT_FILE" ]; then
            tail -10 "$ALERT_FILE"
        else
            echo "No recent alerts"
        fi
        echo ""
        
        echo "Module Configuration:"
        echo "--------------------"
        echo "Recovery Strategy: $RECOVERY_STRATEGY"
        echo "Max Boot Attempts: $MAX_BOOT_ATTEMPTS"
        echo "Hardware Monitoring: $HARDWARE_MONITORING"
        echo "Telemetry: $TELEMETRY_ENABLED"
        echo ""
        
        echo "Backup Status:"
        echo "--------------"
        local backup_count=$(find "$BACKUP_DIR" -name "*.img" 2>/dev/null | wc -l)
        echo "Available Backups: $backup_count"
        if [ $backup_count -gt 0 ]; then
            echo "Backup Details:"
            list_backups "false" | head -5
        fi
        
    } > "$report_file"
    
    log_message "INFO" "Health report generated: $report_file"
    echo "$report_file"
}

# Main health monitoring function
run_health_monitor() {
    init_health_monitor
    collect_health_metrics
    
    # Check for critical conditions
    if check_critical_conditions; then
        log_message "INFO" "Health check passed"
    else
        log_message "WARN" "Health issues detected"
    fi
    
    # Run prediction analysis
    predict_bootloop_risk
    
    # Run trend analysis
    analyze_health_trends
}

# Command line interface
case "$1" in
    "monitor")
        run_health_monitor
        ;;
    "report")
        generate_health_report
        ;;
    "predict")
        predict_bootloop_risk
        ;;
    "trends")
        analyze_health_trends
        ;;
    "alerts")
        if [ -f "$ALERT_FILE" ] && [ -s "$ALERT_FILE" ]; then
            cat "$ALERT_FILE"
        else
            echo "No alerts found"
        fi
        ;;
    *)
        echo "Usage: $0 {monitor|report|predict|trends|alerts}"
        echo ""
        echo "Commands:"
        echo "  monitor  - Run full health monitoring cycle"
        echo "  report   - Generate detailed health report"
        echo "  predict  - Run bootloop risk prediction"
        echo "  trends   - Analyze health trends"
        echo "  alerts   - Show recent health alerts"
        exit 1
        ;;
esac