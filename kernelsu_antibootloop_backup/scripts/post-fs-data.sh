#!/system/bin/sh
# KernelSU Anti-Bootloop & Backup Module
# post-fs-data.sh - Runs at post-fs-data stage

MODDIR=${0%/*}
MODDIR=${MODDIR%/*}
CONFIG_DIR="$MODDIR/config"
BOOTLOG_DIR="$CONFIG_DIR/boot_logs"
RECOVERY_DIR="$CONFIG_DIR/recovery_points"
SAFEMODE_DIR="$CONFIG_DIR/safe_mode"

# Log function
log_message() {
    echo "post-fs-data: $1" >> "$MODDIR/scripts/module.log"
}

log_message "Starting post-fs-data execution"

# Early initialization - executed during the post-fs-data stage
# This is the earliest point at which the module can execute code

# Create required directories if they don't exist
mkdir -p "$CONFIG_DIR"
mkdir -p "$BOOTLOG_DIR"
mkdir -p "$CONFIG_DIR/backups"
mkdir -p "$RECOVERY_DIR"
mkdir -p "$SAFEMODE_DIR"
mkdir -p "$CONFIG_DIR/transactions"
mkdir -p "$CONFIG_DIR/checkpoints"

# Initialize boot counter for anti-bootloop protection
# This is critical for tracking boot attempts
if [ ! -f "$MODDIR/config/boot_counter" ]; then
    echo "0" > "$MODDIR/config/boot_counter"
    log_message "Initialized boot counter"
else
    # Increment boot counter
    BOOT_COUNT=$(cat "$MODDIR/config/boot_counter" 2>/dev/null || echo "0")
    BOOT_COUNT=$((BOOT_COUNT + 1))
    echo "$BOOT_COUNT" > "$MODDIR/config/boot_counter"
    log_message "Boot attempt: $BOOT_COUNT"
fi

# Log device information
log_message "Device: $(getprop ro.product.model) ($(getprop ro.product.device))"
log_message "Android version: $(getprop ro.build.version.release) (SDK $(getprop ro.build.version.sdk))"
log_message "Kernel: $(uname -r)"

# Check if we're in safe mode from previous boot
if [ -f "$CONFIG_DIR/bootloop_detected" ] || [ -f "$SAFEMODE_DIR/manual_trigger" ]; then
    log_message "Safe mode trigger detected, activating recovery environment"
    
    # Initialize safe mode environment
    if [ -f "$MODDIR/scripts/safe-mode.sh" ]; then
        log_message "Executing safe-mode.sh for recovery"
        sh "$MODDIR/scripts/safe-mode.sh"
    else
        log_message "Warning: safe-mode.sh not found"
    fi
fi

# Set up OverlayFS mounts if enabled
# Call the overlayfs setup script
if [ -f "$MODDIR/scripts/overlayfs.sh" ]; then
    log_message "Executing overlayfs.sh"
    sh "$MODDIR/scripts/overlayfs.sh"
    OVERLAY_STATUS=$?
    
    if [ $OVERLAY_STATUS -eq 0 ]; then
        log_message "OverlayFS setup completed successfully"
    else
        log_message "Warning: OverlayFS setup returned status $OVERLAY_STATUS"
    fi
else
    log_message "Warning: overlayfs.sh not found"
fi

# Create a boot stage checkpoint - post-fs-data stage reached
if [ -d "$CONFIG_DIR/checkpoints" ]; then
    log_message "Creating post-fs-data checkpoint"
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    echo "$TIMESTAMP" > "$CONFIG_DIR/checkpoints/post_fs_data_completed"
fi

# Start boot monitoring for anti-bootloop protection
# This is the core anti-bootloop functionality
if [ -f "$MODDIR/scripts/boot-monitor.sh" ]; then
    log_message "Executing boot-monitor.sh"
    sh "$MODDIR/scripts/boot-monitor.sh"
else
    log_message "Warning: boot-monitor.sh not found"
fi

# Ensure proper SELinux context for module files
# This helps prevent SELinux-related issues
chcon -R u:object_r:system_file:s0 "$MODDIR/scripts" 2>/dev/null
chcon -R u:object_r:system_file:s0 "$MODDIR/binary" 2>/dev/null

log_message "post-fs-data execution completed"