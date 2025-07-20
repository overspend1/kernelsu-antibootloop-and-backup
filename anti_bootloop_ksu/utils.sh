#!/system/bin/sh

# Advanced Anti-Bootloop KSU Module - Utility Functions
# Author: @overspend1/Wiktor

MODDIR=${0%/*}
CONFIG_FILE="$MODDIR/config.conf"
BASE_DIR="/data/local/tmp/antibootloop"
LOG_FILE="$BASE_DIR/detailed.log"
TELEMETRY_FILE="$BASE_DIR/telemetry.json"

# Ensure base directory exists
mkdir -p "$BASE_DIR"

# Load configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        # Source config with error handling
        . "$CONFIG_FILE" 2>/dev/null || {
            log_message "ERROR" "Failed to load config, using defaults"
            set_default_config
        }
    else
        log_message "WARN" "Config file not found, using defaults"
        set_default_config
    fi
}

# Set default configuration values
set_default_config() {
    MAX_BOOT_ATTEMPTS=3
    BOOT_SUCCESS_TIMEOUT=60
    VERBOSE_LOGGING=true
    HARDWARE_MONITORING=true
    TELEMETRY_ENABLED=true
    RECOVERY_STRATEGY="progressive"
    SAFE_MODE_ENABLED=true
    BACKUP_SLOTS=3
    AUTO_REBOOT=true
    REBOOT_DELAY=5
    MONITOR_CPU_TEMP=true
    CPU_TEMP_THRESHOLD=75
    MONITOR_RAM=true
    MIN_FREE_RAM=200
    MONITOR_STORAGE=true
    BOOT_NOTIFICATIONS=true
    RECOVERY_NOTIFICATIONS=true
    WARNING_NOTIFICATIONS=true
    KERNEL_INTEGRITY_CHECK=true
    CONFLICT_DETECTION=true
    EMERGENCY_DISABLE_FILE="/data/local/tmp/disable_antibootloop"
    CUSTOM_RECOVERY_SCRIPT=""
    DEBUG_MODE=false
}

# Enhanced logging function
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="[$timestamp] [$level] $message"
    
    echo "$log_entry" >> "$LOG_FILE"
    
    if [ "$VERBOSE_LOGGING" = "true" ] || [ "$level" = "ERROR" ]; then
        echo "$log_entry"
    fi
    
    # Rotate log if it gets too large (>1MB)
    if [ -f "$LOG_FILE" ]; then
        local log_size=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo "0")
        if [ "$log_size" -gt 1048576 ]; then
            tail -500 "$LOG_FILE" > "$LOG_FILE.tmp"
            mv "$LOG_FILE.tmp" "$LOG_FILE"
            log_message "INFO" "Log rotated due to size limit"
        fi
    fi
}

# Hardware monitoring functions
get_cpu_temp() {
    local temp_file
    local temp_value=0
    
    # Check common temperature sensor paths for Snapdragon devices
    for temp_file in \
        "/sys/class/thermal/thermal_zone0/temp" \
        "/sys/class/thermal/thermal_zone1/temp" \
        "/sys/devices/virtual/thermal/thermal_zone0/temp" \
        "/sys/devices/virtual/thermal/thermal_zone1/temp"
    do
        if [ -f "$temp_file" ]; then
            temp_value=$(cat "$temp_file" 2>/dev/null)
            if [ "$temp_value" -gt 0 ]; then
                # Convert millicelsius to celsius
                temp_value=$((temp_value / 1000))
                break
            fi
        fi
    done
    
    echo "$temp_value"
}

get_available_ram() {
    local ram_mb=0
    
    if [ -f "/proc/meminfo" ]; then
        local available_kb=$(grep "MemAvailable:" /proc/meminfo | awk '{print $2}' 2>/dev/null)
        if [ -n "$available_kb" ] && [ "$available_kb" -gt 0 ]; then
            ram_mb=$((available_kb / 1024))
        fi
    fi
    
    echo "$ram_mb"
}

get_storage_health() {
    local health="unknown"
    
    # Check eMMC health
    if [ -f "/sys/class/mmc_host/mmc0/mmc0:0001/life_time" ]; then
        health=$(cat "/sys/class/mmc_host/mmc0/mmc0:0001/life_time" 2>/dev/null || echo "unknown")
    fi
    
    echo "$health"
}

# Hardware monitoring check
check_hardware_health() {
    local issues=""
    
    if [ "$MONITOR_CPU_TEMP" = "true" ]; then
        local cpu_temp=$(get_cpu_temp)
        if [ "$cpu_temp" -gt "$CPU_TEMP_THRESHOLD" ]; then
            issues="$issues CPU_OVERHEAT($cpu_temp°C)"
            log_message "WARN" "CPU temperature high: ${cpu_temp}°C (threshold: ${CPU_TEMP_THRESHOLD}°C)"
        fi
    fi
    
    if [ "$MONITOR_RAM" = "true" ]; then
        local available_ram=$(get_available_ram)
        if [ "$available_ram" -lt "$MIN_FREE_RAM" ]; then
            issues="$issues LOW_RAM(${available_ram}MB)"
            log_message "WARN" "Low available RAM: ${available_ram}MB (minimum: ${MIN_FREE_RAM}MB)"
        fi
    fi
    
    if [ "$MONITOR_STORAGE" = "true" ]; then
        local storage_health=$(get_storage_health)
        if [ "$storage_health" != "unknown" ] && [ "$storage_health" != "0x01" ]; then
            issues="$issues STORAGE_WEAR($storage_health)"
            log_message "WARN" "Storage wear detected: $storage_health"
        fi
    fi
    
    echo "$issues"
}

# Telemetry collection
collect_telemetry() {
    if [ "$TELEMETRY_ENABLED" != "true" ]; then
        return
    fi
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local uptime=$(cat /proc/uptime | cut -d' ' -f1)
    local cpu_temp=$(get_cpu_temp)
    local available_ram=$(get_available_ram)
    local storage_health=$(get_storage_health)
    local kernel_version=$(uname -r)
    local android_version=$(getprop ro.build.version.release)
    
    # Create JSON telemetry entry
    cat >> "$TELEMETRY_FILE" << EOF
{
  "timestamp": "$timestamp",
  "uptime": $uptime,
  "cpu_temperature": $cpu_temp,
  "available_ram_mb": $available_ram,
  "storage_health": "$storage_health",
  "kernel_version": "$kernel_version",
  "android_version": "$android_version",
  "device_model": "$(getprop ro.product.model)",
  "device_brand": "$(getprop ro.product.brand)"
},
EOF
    
    log_message "DEBUG" "Telemetry collected"
}

# Send notification function
send_notification() {
    local title="$1"
    local message="$2"
    local priority="$3"
    
    # Try to send notification via various methods
    # KernelSU notification (if available)
    if command -v su >/dev/null 2>&1; then
        su -c "am broadcast -a android.intent.action.MAIN -e title '$title' -e message '$message'" 2>/dev/null
    fi
    
    # Log the notification
    log_message "NOTIFICATION" "$title: $message"
}

# Check for emergency disable
check_emergency_disable() {
    if [ -f "$EMERGENCY_DISABLE_FILE" ]; then
        log_message "WARN" "Emergency disable file found, module disabled"
        return 0
    fi
    return 1
}

# Validate kernel integrity
check_kernel_integrity() {
    if [ "$KERNEL_INTEGRITY_CHECK" != "true" ]; then
        return 0
    fi
    
    local boot_partition="/dev/block/bootdevice/by-name/boot"
    local current_hash=""
    local stored_hash_file="$BASE_DIR/kernel_hash"
    
    # Calculate current kernel hash
    if [ -f "$boot_partition" ]; then
        current_hash=$(sha256sum "$boot_partition" 2>/dev/null | cut -d' ' -f1)
    fi
    
    # Compare with stored hash
    if [ -f "$stored_hash_file" ]; then
        local stored_hash=$(cat "$stored_hash_file")
        if [ "$current_hash" != "$stored_hash" ]; then
            log_message "WARN" "Kernel integrity check failed - hash mismatch"
            return 1
        fi
    else
        # Store initial hash
        echo "$current_hash" > "$stored_hash_file"
        log_message "INFO" "Kernel hash stored for integrity checking"
    fi
    
    return 0
}

# Conflict detection
detect_conflicts() {
    if [ "$CONFLICT_DETECTION" != "true" ]; then
        return 0
    fi
    
    local conflicts=""
    
    # Check for Magisk
    if [ -d "/sbin/.magisk" ] || [ -f "/data/adb/magisk/magisk" ]; then
        conflicts="$conflicts MAGISK_DETECTED"
        log_message "INFO" "Magisk installation detected"
    fi
    
    # Check for other recovery modules
    if [ -d "/data/adb/modules" ]; then
        local other_recovery=$(find /data/adb/modules -name "*bootloop*" -o -name "*recovery*" | grep -v "$(basename $MODDIR)" | head -1)
        if [ -n "$other_recovery" ]; then
            conflicts="$conflicts OTHER_RECOVERY_MODULE"
            log_message "WARN" "Other recovery module detected: $other_recovery"
        fi
    fi
    
    if [ -n "$conflicts" ]; then
        log_message "WARN" "Conflicts detected: $conflicts"
        return 1
    fi
    
    return 0
}