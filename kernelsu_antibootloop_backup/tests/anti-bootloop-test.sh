#!/system/bin/sh
# KernelSU Anti-Bootloop Backup System
# Anti-Bootloop Specific Test Script
#
# CAUTION: This script intentionally causes a boot failure
# to test the anti-bootloop recovery mechanism.
# USE ONLY ON TEST DEVICES WITH DATA BACKED UP!

# Set paths
MODDIR="/data/adb/modules/kernelsu_antibootloop_backup"
INTEGRATION_SCRIPT="$MODDIR/scripts/backup-integration.sh"
TEST_LOG="$MODDIR/tests/anti-bootloop-test.log"

# Initialize log
echo "===== KernelSU Anti-Bootloop Recovery Test =====" > "$TEST_LOG"
echo "Started: $(date)" >> "$TEST_LOG"
echo "Device: $(getprop ro.product.model) ($(getprop ro.product.device))" >> "$TEST_LOG"
echo "Android: $(getprop ro.build.version.release) (SDK $(getprop ro.build.version.sdk))" >> "$TEST_LOG"
echo "KernelSU version: $(su -v 2>/dev/null || echo 'Not detected')" >> "$TEST_LOG"
echo "===================================================" >> "$TEST_LOG"

# Log function
log_message() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$TEST_LOG"
    echo "$1"
}

# =============================================
# PREPARATION PHASE
# =============================================

log_message "PHASE 1: PREPARATION"

# Initialize backup system
log_message "Initializing backup system..."
"$INTEGRATION_SCRIPT" init
if [ $? -ne 0 ]; then
    log_message "ERROR: Failed to initialize backup system"
    exit 1
fi

# Create a full system backup
log_message "Creating full system backup for recovery..."
BACKUP_ID=$("$INTEGRATION_SCRIPT" backup-full "Anti-bootloop test backup" local false)
if [ -z "$BACKUP_ID" ]; then
    log_message "ERROR: Failed to create backup"
    exit 1
fi
log_message "Created backup ID: $BACKUP_ID"

# Verify backup was created
"$INTEGRATION_SCRIPT" backup-details "$BACKUP_ID" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    log_message "ERROR: Backup verification failed"
    exit 1
fi
log_message "Backup verified successfully"

# =============================================
# BOOTLOOP SIMULATION PHASE
# =============================================

log_message "PHASE 2: BOOTLOOP SIMULATION"
log_message "WARNING: About to simulate a boot failure"
log_message "The device will reboot after this step"

# Choose a method to simulate boot failure
SIMULATION_METHOD="$1"

case "$SIMULATION_METHOD" in
    "build.prop")
        # Method 1: Corrupt build.prop
        log_message "Using build.prop corruption method"
        
        # Backup original file
        cp /system/build.prop /data/local/tmp/build.prop.bak
        
        # Create mount point
        mkdir -p /data/local/tmp/system_mount
        
        # Mount system as read-write
        mount -o rw,remount /system
        
        # Corrupt build.prop
        echo "ro.product.broken=true" >> /system/build.prop
        echo "# Intentionally corrupted line for testing>>><<<" >> /system/build.prop
        
        log_message "Corrupted build.prop for testing"
        ;;
        
    "boot_service")
        # Method 2: Create a problematic service that runs at boot
        log_message "Using boot service corruption method"
        
        # Create a service that causes problems at boot
        mkdir -p /data/local/tmp/boot_crash
        cat > /data/local/tmp/boot_crash/crash.sh << 'EOF'
#!/system/bin/sh
# Intentionally problematic boot script
while true; do
  # Create high CPU load
  dd if=/dev/zero of=/dev/null &
  dd if=/dev/zero of=/dev/null &
  dd if=/dev/zero of=/dev/null &
  
  # Wait for device to be fully booted
  until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 1
  done
  
  # Create memory pressure
  for i in $(seq 1 10); do
    dd if=/dev/zero bs=1M count=100 | gzip -9 > /data/local/tmp/test$i.gz &
  done
  
  # Wait and repeat
  sleep 30
done
EOF
        chmod +x /data/local/tmp/boot_crash/crash.sh
        
        # Add to init.rc (simplified for testing)
        mount -o rw,remount /system
        if [ -f "/system/etc/init/bootscripts.rc" ]; then
            cp /system/etc/init/bootscripts.rc /data/local/tmp/bootscripts.rc.bak
            echo "service bootcrash /data/local/tmp/boot_crash/crash.sh" >> /system/etc/init/bootscripts.rc
            echo "    class main" >> /system/etc/init/bootscripts.rc
            echo "    user root" >> /system/etc/init/bootscripts.rc
            echo "    oneshot" >> /system/etc/init/bootscripts.rc
        else
            log_message "Could not find init rc file to modify"
            log_message "Falling back to alternative method"
            
            # Add to init.d if available
            if [ -d "/system/etc/init.d" ]; then
                cp /data/local/tmp/boot_crash/crash.sh /system/etc/init.d/99crashtest
                chmod 755 /system/etc/init.d/99crashtest
            fi
        fi
        
        log_message "Created problematic boot service"
        ;;
        
    "system_app")
        # Method 3: Install a problematic app that runs at boot
        log_message "Using system app corruption method"
        
        # Create a dummy APK that will cause issues
        mkdir -p /data/local/tmp/bad_app
        
        # This is a placeholder - in a real test, you would install a specifically crafted APK
        # that causes boot issues when loaded
        
        # Instead, we'll modify an existing system app to cause it to crash
        SYSTEM_APP_DIR="/system/priv-app"
        TARGET_APP=$(find "$SYSTEM_APP_DIR" -name "*.apk" | head -1)
        
        if [ -n "$TARGET_APP" ]; then
            TARGET_APP_BACKUP="/data/local/tmp/$(basename "$TARGET_APP").bak"
            
            # Backup the app
            cp "$TARGET_APP" "$TARGET_APP_BACKUP"
            
            # Mount system as read-write
            mount -o rw,remount /system
            
            # Corrupt the APK (this should prevent it from loading properly)
            dd if=/dev/urandom of="$TARGET_APP" bs=1024 count=10 conv=notrunc
            
            log_message "Corrupted system app: $TARGET_APP"
        else
            log_message "No suitable system app found to corrupt"
            exit 1
        fi
        ;;
        
    *)
        # Default method
        log_message "No method specified, using default (build.prop)"
        
        # Backup original file
        cp /system/build.prop /data/local/tmp/build.prop.bak
        
        # Mount system as read-write
        mount -o rw,remount /system
        
        # Corrupt build.prop
        echo "ro.product.broken=true" >> /system/build.prop
        echo "# Intentionally corrupted line for testing>>><<<" >> /system/build.prop
        
        log_message "Corrupted build.prop for testing"
        ;;
esac

# Create marker file to detect if we recover successfully
echo "$(date)" > /data/local/tmp/bootloop_test_marker

log_message "Boot failure simulation complete"
log_message "Device will now reboot to test anti-bootloop recovery"

# Force a sync to ensure all changes are written
sync

# Set up a delayed reboot to ensure logging completes
(sleep 5; reboot) &

log_message "Test complete. If anti-bootloop protection works correctly:"
log_message "1. The device should fail to boot normally"
log_message "2. The anti-bootloop system should detect the failure"
log_message "3. The system should automatically restore from backup ID: $BACKUP_ID"
log_message "4. The device should successfully boot after restoration"

# =============================================
# VERIFICATION AFTER REBOOT
# =============================================

# This part should be run manually after the device recovers and boots

# The verification script would check:
# 1. If the marker file exists
# 2. If the boot count matches expectations
# 3. If the recovery log indicates successful restoration
# 4. If the corrupted file was properly restored

# The following commands should be run after recovery:
#
# if [ -f "/data/local/tmp/bootloop_test_marker" ]; then
#     echo "Found marker file, checking recovery logs"
#     grep "restoration successful" "$MODDIR/config/logs/recovery.log"
#     
#     # Check if the corrupted file was restored
#     # (specific checks depend on which method was used)
#     
#     echo "Anti-bootloop recovery test: PASSED"
# else
#     echo "Marker file not found. Test inconclusive."
# fi

exit 0