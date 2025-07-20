#!/system/bin/sh

# API endpoint for system status
# Author: @overspend1/Wiktor

MODDIR="$(dirname "$(dirname "$0")")"
. "$MODDIR/utils.sh"

# Get current status
BOOT_COUNT=$(cat "$BOOT_COUNT_FILE" 2>/dev/null || echo "0")
RECOVERY_STATE=$(cat "$BASE_DIR/recovery_state" 2>/dev/null || echo "normal")
TOTAL_BOOTS=$(cat "$BASE_DIR/total_boots" 2>/dev/null || echo "0")
UPTIME=$(cat /proc/uptime | cut -d' ' -f1)
SAFE_MODE_ACTIVE=$([ -f "$BASE_DIR/safe_mode_active" ] && echo "true" || echo "false")

# Device information
DEVICE=$(getprop ro.product.device)
ANDROID_VERSION=$(getprop ro.build.version.release)
KERNEL_VERSION=$(uname -r)

# Generate JSON response
cat << EOF
{
    "status": "running",
    "boot_count": $BOOT_COUNT,
    "max_attempts": $MAX_BOOT_ATTEMPTS,
    "recovery_state": "$RECOVERY_STATE",
    "total_boots": $TOTAL_BOOTS,
    "uptime": $UPTIME,
    "device": "$DEVICE",
    "android_version": "$ANDROID_VERSION",
    "kernel_version": "$KERNEL_VERSION",
    "module_version": "2.0",
    "safe_mode": $SAFE_MODE_ACTIVE,
    "webui_enabled": true,
    "timestamp": "$(date '+%Y-%m-%d %H:%M:%S')"
}
EOF