#!/system/bin/sh
# KernelSU Anti-Bootloop & Backup Module Customization Script

MODDIR=${0%/*}
API=`getprop ro.build.version.sdk`

# Print module information
ui_print "- KernelSU Anti-Bootloop & Backup Module"
ui_print "- By OverModules"
ui_print "- API Level: $API"

# Check device compatibility
check_device_compatibility() {
    local device_model=$(getprop ro.product.model)
    local device_brand=$(getprop ro.product.brand)
    local android_version=$(getprop ro.build.version.release)
    local api_level=$(getprop ro.build.version.sdk)
    
    ui_print "- Device: $device_brand $device_model"
    ui_print "- Android: $android_version (API $api_level)"
    
    # Check minimum Android version (API 21+)
    if [ "$api_level" -lt 21 ]; then
        ui_print "! Error: Android 5.0+ (API 21) required"
        return 1
    fi
    
    # Check for KernelSU
    if [ ! -f "/data/adb/ksu/bin/ksud" ] && [ ! -f "/data/adb/ksud" ]; then
        ui_print "! Warning: KernelSU not detected"
        ui_print "! This module requires KernelSU to function properly"
        return 1
    fi
    
    # Check available storage space (minimum 100MB)
    local available_space=$(df /data | tail -1 | awk '{print $4}')
    if [ "$available_space" -lt 102400 ]; then
        ui_print "! Error: Insufficient storage space"
        ui_print "! At least 100MB required in /data partition"
        return 1
    fi
    
    # Check for busybox
    if ! command -v busybox >/dev/null 2>&1; then
        ui_print "! Warning: Busybox not found"
        ui_print "! Some features may not work properly"
    fi
    
    # Check for critical partitions
    if [ ! -b "/dev/block/bootdevice/by-name/boot" ]; then
        ui_print "! Warning: Boot partition not accessible"
        ui_print "! Boot backup functionality will be limited"
    fi
    
    # Device-specific compatibility checks
    case "$device_brand" in
        "Xiaomi"|"Redmi"|"POCO")
            ui_print "- Xiaomi device detected"
            # Check for MIUI-specific issues
            if getprop ro.miui.ui.version.name >/dev/null 2>&1; then
                ui_print "- MIUI detected, enabling compatibility mode"
                echo "miui=true" >> "$MODDIR/config/device.conf"
            fi
            ;;
        "samsung")
            ui_print "- Samsung device detected"
            # Check for Knox
            if getprop ro.boot.warranty_bit >/dev/null 2>&1; then
                ui_print "- Knox detected, some features may be limited"
                echo "knox=true" >> "$MODDIR/config/device.conf"
            fi
            ;;
        "OnePlus")
            ui_print "- OnePlus device detected"
            echo "oneplus=true" >> "$MODDIR/config/device.conf"
            ;;
        *)
            ui_print "- Generic device compatibility mode"
            ;;
    esac
    
    ui_print "- Device compatibility check passed"
    return 0
}

# Setup permissions for key directories and files
setup_permissions() {
    ui_print "- Setting up permissions..."
    
    # Set executable permissions for all scripts
    find "$MODDIR/scripts" -type f -name "*.sh" -exec chmod 755 {} \;
    
    # Set permissions for binary executables
    find "$MODDIR/binary" -type f -exec chmod 755 {} \;
    
    # Ensure config directory is accessible
    chmod 755 "$MODDIR/config"
    
    # Set permissions for WebUI
    chmod -R 755 "$MODDIR/webroot"
    
    # Ensure template directory is accessible
    chmod 755 "$MODDIR/templates"
    
    ui_print "- Permissions set successfully"
}

# Initialize directories and configuration files
initialize_configuration() {
    ui_print "- Initializing configuration..."
    
    # Create necessary subdirectories
    mkdir -p "$MODDIR/config/backup_profiles"
    mkdir -p "$MODDIR/config/boot_logs"
    mkdir -p "$MODDIR/config/recovery_points"
    
    # Create initial configuration files if they don't exist
    if [ ! -f "$MODDIR/config/main.conf" ]; then
        echo "# Anti-Bootloop & Backup Main Configuration
enabled=true
bootloop_detection=true
boot_timeout=120
backup_encryption=false
auto_backup=false
auto_restore=true
webui_enabled=true
webui_port=8080
" > "$MODDIR/config/main.conf"
    fi
    
    ui_print "- Configuration initialized"
}

# Setup kernel safety integration
setup_kernel_safety() {
    ui_print "- Setting up kernel safety layer..."
    
    # Create necessary script symlinks
    ln -sf "$MODDIR/scripts/boot-monitor.sh" "$MODDIR/scripts/post-fs-data.sh" 2>/dev/null
    ln -sf "$MODDIR/scripts/safety-service.sh" "$MODDIR/scripts/service.sh" 2>/dev/null
    
    # Initialize boot counter
    echo "0" > "$MODDIR/config/boot_counter"
    
    ui_print "- Kernel safety layer configured"
}

# Main installation function
main() {
    ui_print "- Beginning module customization..."
    
    # Check if device is compatible
    check_device_compatibility
    if [ $? -ne 0 ]; then
        ui_print "! Device incompatible, aborting installation"
        abort
    fi
    
    # Setup directory permissions
    setup_permissions
    
    # Initialize configuration
    initialize_configuration
    
    # Setup kernel safety integration
    setup_kernel_safety
    
    ui_print "- Module customization complete"
    ui_print "- Please reboot to activate all features"
}

# Execute main function
main