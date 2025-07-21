#!/system/bin/sh
# KernelSU Anti-Bootloop & Backup Module - Analytics Engine
# Advanced monitoring, analytics, and reporting system

MODDIR=${0%/*}
MODDIR=${MODDIR%/*}
CONFIG_DIR="$MODDIR/config"
ANALYTICS_DIR="$CONFIG_DIR/analytics"
ML_DATA_DIR="$CONFIG_DIR/ml_data"
REPORTS_DIR="$CONFIG_DIR/reports"
METRICS_DIR="$CONFIG_DIR/metrics"

# Advanced analytics configuration
ANALYTICS_INTERVAL=30  # seconds
METRIC_RETENTION_DAYS=30
REPORT_GENERATION_INTERVAL=3600  # 1 hour
ANOMALY_THRESHOLD=2.5  # standard deviations
TREND_ANALYSIS_WINDOW=7  # days

# Ensure directories exist
mkdir -p "$ANALYTICS_DIR" "$ML_DATA_DIR" "$REPORTS_DIR" "$METRICS_DIR"

# Enhanced logging
log_message() {
    local level="${2:-INFO}"
    local timestamp="$(date +"%Y-%m-%d %H:%M:%S")"
    echo "[$timestamp] [analytics:$level] $1" >> "$CONFIG_DIR/analytics_engine.log"
    
    # Structured logging
    echo "{\"timestamp\":$(date +%s),\"level\":\"$level\",\"component\":\"analytics\",\"message\":\"$1\"}" >> "$ANALYTICS_DIR/structured.log"
}

# System metrics collection
collect_system_metrics() {
    local timestamp=$(date +%s)
    
    # CPU metrics
    local cpu_usage=$(top -n1 | grep "CPU:" | awk '{print $2}' | sed 's/%//')
    local load_avg=$(uptime | awk '{print $3 $4 $5}' | sed 's/,//g')
    
    # Memory metrics
    local mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local mem_free=$(grep MemFree /proc/meminfo | awk '{print $2}')
    local mem_available=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    local mem_usage=$((100 - (mem_available * 100 / mem_total)))
    
    # Storage metrics
    local storage_info=$(df /data | tail -1)
    local storage_used=$(echo $storage_info | awk '{print $5}' | sed 's/%//')
    local storage_total=$(echo $storage_info | awk '{print $2}')
    local storage_free=$(echo $storage_info | awk '{print $4}')
    
    # Process metrics
    local process_count=$(ps | wc -l)
    local zombie_processes=$(ps aux | grep -c " Z ")
    
    # Network metrics (if available)
    local network_rx=$(cat /proc/net/dev | grep -E "(wlan|eth|rmnet)" | head -1 | awk '{print $2}' || echo 0)
    local network_tx=$(cat /proc/net/dev | grep -E "(wlan|eth|rmnet)" | head -1 | awk '{print $10}' || echo 0)
    
    # I/O metrics
    local io_read=$(cat /proc/diskstats | head -1 | awk '{print $6}' || echo 0)
    local io_write=$(cat /proc/diskstats | head -1 | awk '{print $10}' || echo 0)
    
    # Create comprehensive metrics JSON
    local metrics="{
        \"timestamp\": $timestamp,
        \"system\": {
            \"uptime\": $(cat /proc/uptime | awk '{print $1}'),
            \"boot_time\": $((timestamp - $(cat /proc/uptime | awk '{print $1}'))),
            \"kernel_version\": \"$(uname -r)\",
            \"architecture\": \"$(uname -m)\"
        },
        \"cpu\": {
            \"usage_percent\": ${cpu_usage:-0},
            \"load_average\": \"$load_avg\",
            \"cores\": $(nproc),
            \"frequency\": $(cat /proc/cpuinfo | grep -m1 "cpu MHz" | awk '{print $4}' || echo 0)
        },
        \"memory\": {
            \"total_kb\": $mem_total,
            \"free_kb\": $mem_free,
            \"available_kb\": $mem_available,
            \"usage_percent\": $mem_usage,
            \"swap_total\": $(grep SwapTotal /proc/meminfo | awk '{print $2}'),
            \"swap_free\": $(grep SwapFree /proc/meminfo | awk '{print $2}')
        },
        \"storage\": {
            \"usage_percent\": $storage_used,
            \"total_kb\": $storage_total,
            \"free_kb\": $storage_free,
            \"inodes_used\": $(df -i /data | tail -1 | awk '{print $5}' | sed 's/%//')
        },
        \"processes\": {
            \"count\": $process_count,
            \"zombies\": $zombie_processes,
            \"running\": $(ps aux | grep -c " R ")
        },
        \"network\": {
            \"rx_bytes\": $network_rx,
            \"tx_bytes\": $network_tx
        },
        \"io\": {
            \"read_sectors\": $io_read,
            \"write_sectors\": $io_write
        }
    }"
    
    echo "$metrics" >> "$METRICS_DIR/system_metrics.jsonl"
    
    # Also update latest metrics file
    echo "$metrics" > "$ANALYTICS_DIR/latest_metrics.json"
    
    log_message "System metrics collected" "DEBUG"
}

# Module-specific metrics collection
collect_module_metrics() {
    local timestamp=$(date +%s)
    
    # Boot metrics
    local boot_count=$(cat "$CONFIG_DIR/boot_counter" 2>/dev/null || echo 0)
    local last_boot_time=$(stat -c %Y "$CONFIG_DIR/boot_counter" 2>/dev/null || echo 0)
    
    # Safety metrics
    local bootloop_detected=$([ -f "$CONFIG_DIR/bootloop_detected" ] && echo "true" || echo "false")
    local safe_mode_active=$([ -f "$CONFIG_DIR/safe_mode/active" ] && echo "true" || echo "false")
    
    # Backup metrics
    local backup_count=$(ls -1 "$CONFIG_DIR/backups" 2>/dev/null | wc -l)
    local last_backup_time=0
    if [ -d "$CONFIG_DIR/backups" ]; then
        last_backup_time=$(stat -c %Y "$CONFIG_DIR/backups" 2>/dev/null || echo 0)
    fi
    
    # Recovery metrics
    local recovery_points=$(ls -1 "$CONFIG_DIR/recovery_points" 2>/dev/null | wc -l)
    
    # WebUI metrics
    local webui_active=$(pgrep -f "webui-server" >/dev/null && echo "true" || echo "false")
    local webui_connections=$(netstat -an 2>/dev/null | grep ":8080" | grep ESTABLISHED | wc -l)
    
    # Performance metrics
    local service_start_time=0
    if [ -f "$CONFIG_DIR/performance/service_summary.json" ]; then
        service_start_time=$(grep -o '"total_duration_ms":[0-9]*' "$CONFIG_DIR/performance/service_summary.json" | cut -d: -f2)
    fi
    
    local module_metrics="{
        \"timestamp\": $timestamp,
        \"module_info\": {
            \"version\": \"$(grep version= $MODDIR/module.prop | cut -d= -f2)\",
            \"version_code\": \"$(grep versionCode= $MODDIR/module.prop | cut -d= -f2)\",
            \"author\": \"$(grep author= $MODDIR/module.prop | cut -d= -f2)\"
        },
        \"boot\": {
            \"count\": $boot_count,
            \"last_boot_timestamp\": $last_boot_time,
            \"bootloop_detected\": $bootloop_detected,
            \"safe_mode_active\": $safe_mode_active
        },
        \"backup\": {
            \"count\": $backup_count,
            \"last_backup_timestamp\": $last_backup_time,
            \"recovery_points\": $recovery_points
        },
        \"webui\": {
            \"active\": $webui_active,
            \"connections\": $webui_connections
        },
        \"performance\": {
            \"service_start_duration_ms\": ${service_start_time:-0}
        }
    }"
    
    echo "$module_metrics" >> "$METRICS_DIR/module_metrics.jsonl"
    echo "$module_metrics" > "$ANALYTICS_DIR/latest_module_metrics.json"
    
    log_message "Module metrics collected" "DEBUG"
}

# Advanced anomaly detection using statistical analysis
detect_anomalies() {
    local metric_file="$1"
    local field="$2"
    local threshold="${3:-$ANOMALY_THRESHOLD}"
    
    if [ ! -f "$metric_file" ]; then
        return 0
    fi
    
    # Get last 50 values for statistical analysis
    local values=$(tail -50 "$metric_file" | grep -o "\"$field\":[0-9.]*" | cut -d: -f2)
    local count=$(echo "$values" | wc -l)
    
    if [ "$count" -lt 10 ]; then
        return 0  # Not enough data
    fi
    
    # Calculate mean and standard deviation (simplified)
    local sum=0
    local sum_squared=0
    
    for value in $values; do
        sum=$((sum + value))
        sum_squared=$((sum_squared + value * value))
    done
    
    local mean=$((sum / count))
    local variance=$((sum_squared / count - mean * mean))
    local std_dev=$(echo "scale=2; sqrt($variance)" | bc -l 2>/dev/null || echo 1)
    
    # Get current value
    local current=$(tail -1 "$metric_file" | grep -o "\"$field\":[0-9.]*" | cut -d: -f2)
    
    if [ -n "$current" ]; then
        local deviation=$(echo "scale=2; ($current - $mean) / $std_dev" | bc -l 2>/dev/null || echo 0)
        local abs_deviation=$(echo "$deviation" | sed 's/-//')
        
        # Check if deviation exceeds threshold
        if [ "$(echo "$abs_deviation > $threshold" | bc -l 2>/dev/null)" = "1" ]; then
            # Anomaly detected
            local anomaly_report="{
                \"timestamp\": $(date +%s),
                \"metric\": \"$field\",
                \"current_value\": $current,
                \"mean\": $mean,
                \"std_dev\": $std_dev,
                \"deviation\": $deviation,
                \"threshold\": $threshold,
                \"severity\": $(echo "$abs_deviation > 3.0" | bc -l 2>/dev/null | grep -q 1 && echo "high" || echo "medium")
            }"
            
            echo "$anomaly_report" >> "$ANALYTICS_DIR/anomalies.jsonl"
            log_message "Anomaly detected in $field: deviation=$deviation, threshold=$threshold" "WARN"
            
            return 1
        fi
    fi
    
    return 0
}

# Generate comprehensive system report
generate_system_report() {
    local report_timestamp=$(date +%s)
    local report_file="$REPORTS_DIR/system_report_$(date +%Y%m%d_%H%M%S).json"
    
    log_message "Generating comprehensive system report" "INFO"
    
    # System overview
    local uptime_seconds=$(cat /proc/uptime | awk '{print $1}')
    local uptime_days=$(echo "scale=1; $uptime_seconds / 86400" | bc -l)
    
    # Recent metrics analysis
    local recent_cpu_avg=0
    local recent_mem_avg=0
    local recent_storage_avg=0
    
    if [ -f "$METRICS_DIR/system_metrics.jsonl" ]; then
        recent_cpu_avg=$(tail -20 "$METRICS_DIR/system_metrics.jsonl" | grep -o '"usage_percent":[0-9]*' | cut -d: -f2 | awk '{sum+=$1} END {print int(sum/NR)}')
        recent_mem_avg=$(tail -20 "$METRICS_DIR/system_metrics.jsonl" | grep -o '"usage_percent":[0-9]*' | cut -d: -f2 | awk '{sum+=$1} END {print int(sum/NR)}')
    fi
    
    # Anomaly summary
    local anomaly_count=0
    if [ -f "$ANALYTICS_DIR/anomalies.jsonl" ]; then
        anomaly_count=$(wc -l < "$ANALYTICS_DIR/anomalies.jsonl")
    fi
    
    # Performance summary
    local avg_boot_time=0
    if [ -f "$CONFIG_DIR/performance/service_summary.json" ]; then
        avg_boot_time=$(grep -o '"total_duration_ms":[0-9]*' "$CONFIG_DIR/performance/service_summary.json" | cut -d: -f2)
    fi
    
    # Create comprehensive report
    cat > "$report_file" << EOF
{
    "report_timestamp": $report_timestamp,
    "report_type": "system_health",
    "period": "last_24_hours",
    "system_overview": {
        "uptime_days": $uptime_days,
        "kernel_version": "$(uname -r)",
        "device_model": "$(getprop ro.product.model 2>/dev/null || echo 'Unknown')",
        "android_version": "$(getprop ro.build.version.release 2>/dev/null || echo 'Unknown')"
    },
    "performance_metrics": {
        "average_cpu_usage": $recent_cpu_avg,
        "average_memory_usage": $recent_mem_avg,
        "average_boot_time_ms": $avg_boot_time,
        "anomalies_detected": $anomaly_count
    },
    "module_status": {
        "version": "$(grep version= $MODDIR/module.prop | cut -d= -f2)",
        "boot_count": $(cat "$CONFIG_DIR/boot_counter" 2>/dev/null || echo 0),
        "backup_count": $(ls -1 "$CONFIG_DIR/backups" 2>/dev/null | wc -l),
        "recovery_points": $(ls -1 "$CONFIG_DIR/recovery_points" 2>/dev/null | wc -l),
        "safe_mode_active": $([ -f "$CONFIG_DIR/safe_mode/active" ] && echo true || echo false)
    },
    "health_score": {
        "overall": $(calculate_health_score),
        "cpu": $(calculate_component_health "cpu"),
        "memory": $(calculate_component_health "memory"),
        "storage": $(calculate_component_health "storage")
    },
    "recommendations": $(generate_recommendations)
}
EOF
    
    log_message "System report generated: $report_file" "INFO"
}

# Calculate overall system health score (0-100)
calculate_health_score() {
    local score=100
    
    # Check anomalies
    if [ -f "$ANALYTICS_DIR/anomalies.jsonl" ]; then
        local recent_anomalies=$(tail -100 "$ANALYTICS_DIR/anomalies.jsonl" | wc -l)
        score=$((score - recent_anomalies * 2))
    fi
    
    # Check bootloop status
    if [ -f "$CONFIG_DIR/bootloop_detected" ]; then
        score=$((score - 30))
    fi
    
    # Check safe mode
    if [ -f "$CONFIG_DIR/safe_mode/active" ]; then
        score=$((score - 20))
    fi
    
    # Ensure score is within bounds
    if [ $score -lt 0 ]; then
        score=0
    fi
    
    echo $score
}

# Calculate component-specific health score
calculate_component_health() {
    local component="$1"
    local score=100
    
    case "$component" in
        "cpu")
            if [ -f "$METRICS_DIR/system_metrics.jsonl" ]; then
                local avg_usage=$(tail -20 "$METRICS_DIR/system_metrics.jsonl" | grep -o '"usage_percent":[0-9]*' | cut -d: -f2 | awk '{sum+=$1} END {print int(sum/NR)}')
                if [ "$avg_usage" -gt 80 ]; then
                    score=$((score - 20))
                elif [ "$avg_usage" -gt 60 ]; then
                    score=$((score - 10))
                fi
            fi
            ;;
        "memory")
            if [ -f "$METRICS_DIR/system_metrics.jsonl" ]; then
                local avg_usage=$(tail -20 "$METRICS_DIR/system_metrics.jsonl" | grep -A5 '"memory"' | grep -o '"usage_percent":[0-9]*' | cut -d: -f2 | awk '{sum+=$1} END {print int(sum/NR)}')
                if [ "$avg_usage" -gt 85 ]; then
                    score=$((score - 25))
                elif [ "$avg_usage" -gt 70 ]; then
                    score=$((score - 10))
                fi
            fi
            ;;
        "storage")
            local storage_usage=$(df /data | tail -1 | awk '{print $5}' | sed 's/%//')
            if [ "$storage_usage" -gt 90 ]; then
                score=$((score - 30))
            elif [ "$storage_usage" -gt 80 ]; then
                score=$((score - 15))
            fi
            ;;
    esac
    
    echo $score
}

# Generate actionable recommendations
generate_recommendations() {
    local recommendations="[]"
    
    # Check for high resource usage
    if [ -f "$METRICS_DIR/system_metrics.jsonl" ]; then
        local cpu_usage=$(tail -1 "$METRICS_DIR/system_metrics.jsonl" | grep -o '"usage_percent":[0-9]*' | cut -d: -f2)
        if [ "$cpu_usage" -gt 80 ]; then
            recommendations='["Consider reducing background processes or checking for CPU-intensive modules"]'
        fi
    fi
    
    # Check storage space
    local storage_usage=$(df /data | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ "$storage_usage" -gt 85 ]; then
        if [ "$recommendations" = "[]" ]; then
            recommendations='["Free up storage space by cleaning old backups or logs"]'
        else
            recommendations=$(echo "$recommendations" | sed 's/\]/, "Free up storage space by cleaning old backups or logs"\]/')
        fi
    fi
    
    echo "$recommendations"
}

# Main monitoring loop
main_monitoring_loop() {
    log_message "Starting advanced analytics monitoring loop" "INFO"
    
    local last_report_time=0
    
    while true; do
        # Collect metrics
        collect_system_metrics
        collect_module_metrics
        
        # Perform anomaly detection
        detect_anomalies "$METRICS_DIR/system_metrics.jsonl" "usage_percent"
        detect_anomalies "$METRICS_DIR/system_metrics.jsonl" "usage_percent"  # Memory usage
        
        # Generate periodic reports
        local current_time=$(date +%s)
        if [ $((current_time - last_report_time)) -gt $REPORT_GENERATION_INTERVAL ]; then
            generate_system_report
            last_report_time=$current_time
        fi
        
        # Cleanup old data
        cleanup_old_data
        
        # Sleep until next collection
        sleep $ANALYTICS_INTERVAL
    done
}

# Cleanup old analytics data
cleanup_old_data() {
    local cutoff_time=$(($(date +%s) - METRIC_RETENTION_DAYS * 86400))
    
    # Clean old metrics
    for metric_file in "$METRICS_DIR"/*.jsonl; do
        if [ -f "$metric_file" ]; then
            awk -v cutoff=$cutoff_time '{if (match($0, /"timestamp": *([0-9]+)/, arr) && arr[1] > cutoff) print}' "$metric_file" > "$metric_file.tmp" && mv "$metric_file.tmp" "$metric_file"
        fi
    done
    
    # Clean old reports
    find "$REPORTS_DIR" -name "*.json" -mtime +$METRIC_RETENTION_DAYS -delete 2>/dev/null
    
    log_message "Cleaned old analytics data" "DEBUG"
}

# Command processing
case "$1" in
    "start")
        log_message "Starting analytics engine" "INFO"
        main_monitoring_loop
        ;;
    "collect")
        collect_system_metrics
        collect_module_metrics
        ;;
    "report")
        generate_system_report
        ;;
    "health")
        echo "Health Score: $(calculate_health_score)%"
        ;;
    *)
        echo "Usage: $0 {start|collect|report|health}"
        echo "  start  - Start continuous monitoring"
        echo "  collect - Collect metrics once"
        echo "  report - Generate system report"
        echo "  health - Show health score"
        exit 1
        ;;
esac