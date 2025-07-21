#!/system/bin/sh
# KernelSU Anti-Bootloop OverlayFS Integration Script

MODDIR=${0%/*}
MODDIR=${MODDIR%/*}
CONFIG_DIR="$MODDIR/config"
OVERLAY_DIR="$MODDIR/system"
BOOTLOG_DIR="$CONFIG_DIR/boot_logs"
TRANSACTION_DIR="$CONFIG_DIR/transactions"
OVERLAYFS_WORK_DIR="$OVERLAY_DIR/workdir"
OVERLAYFS_UPPER_DIR="$OVERLAY_DIR/upperdir"
OVERLAYFS_BACKUP_DIR="$OVERLAY_DIR/backup"

# Partition mount points to protect
SYSTEM_PARTITIONS="/system /vendor /product /system_ext /odm"

# Transaction states
TRANSACTION_NONE=0
TRANSACTION_STARTED=1
TRANSACTION_COMMITTED=2
TRANSACTION_ABORTED=3

# Ensure required directories exist
mkdir -p "$BOOTLOG_DIR"
mkdir -p "$TRANSACTION_DIR"
mkdir -p "$OVERLAYFS_WORK_DIR"
mkdir -p "$OVERLAYFS_UPPER_DIR"
mkdir -p "$OVERLAYFS_BACKUP_DIR"

# Log function for debugging
log_message() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$BOOTLOG_DIR/overlayfs.log"
}

log_message "OverlayFS script started"

# Check if system supports overlayfs
check_overlayfs_support() {
    # Check if kernel supports overlayfs
    if [ -d "/sys/module/overlay" ] || [ -d "/sys/module/overlayfs" ]; then
        log_message "Kernel supports OverlayFS"
        
        # Verify mount command supports overlay type
        if mount | grep -q "overlay"; then
            log_message "System has existing overlay mounts"
            return 0
        fi
        
        # Test if we can create an overlay mount
        TEST_LOWER="$OVERLAY_DIR/test_lower"
        TEST_UPPER="$OVERLAY_DIR/test_upper"
        TEST_WORK="$OVERLAY_DIR/test_work"
        TEST_MOUNT="$OVERLAY_DIR/test_mount"
        
        mkdir -p "$TEST_LOWER" "$TEST_UPPER" "$TEST_WORK" "$TEST_MOUNT"
        
        echo "test" > "$TEST_LOWER/test.txt"
        
        if mount -t overlay overlay -o "lowerdir=$TEST_LOWER,upperdir=$TEST_UPPER,workdir=$TEST_WORK" "$TEST_MOUNT" 2>/dev/null; then
            log_message "OverlayFS mount test successful"
            umount "$TEST_MOUNT" 2>/dev/null
            rm -rf "$TEST_LOWER" "$TEST_UPPER" "$TEST_WORK" "$TEST_MOUNT"
            return 0
        else
            log_message "OverlayFS mount test failed"
            rm -rf "$TEST_LOWER" "$TEST_UPPER" "$TEST_WORK" "$TEST_MOUNT"
            return 2
        fi
    else
        log_message "Kernel does not support OverlayFS"
        return 1
    fi
}

# Get mount point for a path
get_mount_point() {
    mount | grep -w "$1" | head -n1 | awk '{print $3}'
}

# Check if a mount point is read-only
is_mount_readonly() {
    mount | grep -w "$1" | grep -q "ro,"
    return $?
}

# Setup overlay for a specific partition
setup_partition_overlay() {
    PARTITION=$1
    
    # Skip if partition doesn't exist
    if [ ! -d "$PARTITION" ]; then
        log_message "Partition $PARTITION does not exist, skipping"
        return 1
    fi
    
    # Check if partition is already an overlay
    if mount | grep -q "overlay on $PARTITION "; then
        log_message "Partition $PARTITION is already an overlay mount"
        return 0
    fi
    
    # Get actual mount point
    MOUNT_POINT=$(get_mount_point "$PARTITION")
    if [ -z "$MOUNT_POINT" ]; then
        log_message "Could not determine mount point for $PARTITION"
        return 1
    fi
    
    # Create partition-specific directories
    PART_NAME=$(echo "$PARTITION" | sed 's|/|_|g' | sed 's|^_||')
    PART_UPPER="$OVERLAYFS_UPPER_DIR/$PART_NAME"
    PART_WORK="$OVERLAYFS_WORK_DIR/$PART_NAME"
    PART_BACKUP="$OVERLAYFS_BACKUP_DIR/$PART_NAME"
    
    mkdir -p "$PART_UPPER"
    mkdir -p "$PART_WORK"
    mkdir -p "$PART_BACKUP"
    
    log_message "Setting up overlay for $PARTITION (mount: $MOUNT_POINT)"
    
    # Check if we need to remount the partition as read-write first
    is_mount_readonly "$MOUNT_POINT"
    IS_READONLY=$?
    
    if [ $IS_READONLY -eq 0 ]; then
        log_message "$PARTITION is mounted read-only, attempting remount"
        mount -o remount,rw "$MOUNT_POINT"
        if [ $? -ne 0 ]; then
            log_message "Failed to remount $PARTITION as read-write, using alternative method"
            # Try a bind mount approach for read-only partitions
            
            # Create a temporary mount point
            TEMP_MOUNT="$OVERLAY_DIR/temp_$PART_NAME"
            mkdir -p "$TEMP_MOUNT"
            
            # Bind mount the partition to temp location
            mount -o bind "$MOUNT_POINT" "$TEMP_MOUNT"
            
            # Now set up overlay using the temp mount as lower
            mount -t overlay overlay -o "lowerdir=$TEMP_MOUNT,upperdir=$PART_UPPER,workdir=$PART_WORK" "$MOUNT_POINT"
            OVERLAY_STATUS=$?
            
            if [ $OVERLAY_STATUS -eq 0 ]; then
                log_message "Successfully set up overlay for $PARTITION using bind mount method"
                echo "$MOUNT_POINT:$TEMP_MOUNT:$PART_UPPER:$PART_WORK" >> "$CONFIG_DIR/active_overlays.txt"
                return 0
            else
                log_message "Failed to set up overlay for $PARTITION with bind mount method"
                umount "$TEMP_MOUNT" 2>/dev/null
                rmdir "$TEMP_MOUNT" 2>/dev/null
                return 1
            fi
        fi
    fi
    
    # Standard overlay setup
    mount -t overlay overlay -o "lowerdir=$MOUNT_POINT,upperdir=$PART_UPPER,workdir=$PART_WORK" "$MOUNT_POINT"
    OVERLAY_STATUS=$?
    
    if [ $OVERLAY_STATUS -eq 0 ]; then
        log_message "Successfully set up overlay for $PARTITION"
        echo "$MOUNT_POINT::$PART_UPPER:$PART_WORK" >> "$CONFIG_DIR/active_overlays.txt"
        return 0
    else
        log_message "Failed to set up overlay for $PARTITION with status $OVERLAY_STATUS"
        return 1
    fi
}

# Backup the current state of a partition
backup_partition_state() {
    PARTITION=$1
    
    # Skip if partition doesn't exist
    if [ ! -d "$PARTITION" ]; then
        return 1
    fi
    
    # Get partition name for backup location
    PART_NAME=$(echo "$PARTITION" | sed 's|/|_|g' | sed 's|^_||')
    PART_BACKUP="$OVERLAYFS_BACKUP_DIR/$PART_NAME"
    
    log_message "Creating backup of $PARTITION state"
    
    # Clean previous backup
    rm -rf "$PART_BACKUP"
    mkdir -p "$PART_BACKUP"
    
    # Copy current upper directory if it exists
    PART_UPPER="$OVERLAYFS_UPPER_DIR/$PART_NAME"
    if [ -d "$PART_UPPER" ] && [ "$(ls -A "$PART_UPPER" 2>/dev/null)" ]; then
        cp -a "$PART_UPPER/"* "$PART_BACKUP/" 2>/dev/null
        log_message "Backed up upperdir content for $PARTITION"
    else
        log_message "No existing upperdir content for $PARTITION"
    fi
    
    return 0
}

# Safe remount of system partition (fallback method)
safe_remount_system() {
    log_message "Attempting safe remount of system partitions"
    
    for PARTITION in $SYSTEM_PARTITIONS; do
        if [ -d "$PARTITION" ]; then
            # Create backup of original partition
            PART_NAME=$(echo "$PARTITION" | sed 's|/|_|g' | sed 's|^_||')
            BACKUP_DIR="$OVERLAYFS_BACKUP_DIR/$PART_NAME"
            mkdir -p "$BACKUP_DIR"
            
            # Try to remount as read-write
            log_message "Remounting $PARTITION as read-write"
            mount -o remount,rw "$PARTITION"
            
            if [ $? -eq 0 ]; then
                log_message "Successfully remounted $PARTITION as read-write"
                echo "$PARTITION" >> "$CONFIG_DIR/remounted_partitions.txt"
            else
                log_message "Failed to remount $PARTITION"
            fi
        fi
    done
    
    # Set up mount monitoring to catch system changes
    (
        # Check every 30 seconds for critical system changes
        while true; do
            sleep 30
            
            # Check for active transaction
            if [ -f "$TRANSACTION_DIR/current" ]; then
                CURRENT_TRANSACTION=$(cat "$TRANSACTION_DIR/current")
                TRANSACTION_STATE=$(cat "$TRANSACTION_DIR/$CURRENT_TRANSACTION/state" 2>/dev/null || echo "$TRANSACTION_NONE")
                
                if [ "$TRANSACTION_STATE" = "$TRANSACTION_STARTED" ]; then
                    # Transaction is still active, continue monitoring
                    continue
                fi
            fi
            
            # No active transaction, perform integrity check
            for PARTITION in $SYSTEM_PARTITIONS; do
                if [ -d "$PARTITION" ] && [ -f "$CONFIG_DIR/remounted_partitions.txt" ] && grep -q "$PARTITION" "$CONFIG_DIR/remounted_partitions.txt"; then
                    # Check if any critical system files were modified
                    if [ -f "$PARTITION/build.prop.bak" ] && [ ! -f "$PARTITION/build.prop" ]; then
                        log_message "CRITICAL: $PARTITION/build.prop missing, restoring backup"
                        cp "$PARTITION/build.prop.bak" "$PARTITION/build.prop"
                    fi
                fi
            done
        done
    ) &
    
    # Save monitor PID
    echo $! > "$CONFIG_DIR/mount_monitor.pid"
    
    return 0
}

# Create a safe overlay environment for all partitions
create_safe_environment() {
    log_message "Creating safe overlay environment for all partitions"
    
    # Reset active overlays list
    rm -f "$CONFIG_DIR/active_overlays.txt"
    
    # Backup current state before setting up overlays
    for PARTITION in $SYSTEM_PARTITIONS; do
        backup_partition_state "$PARTITION"
    done
    
    # Setup overlays for all system partitions
    OVERLAY_SUCCESS=true
    for PARTITION in $SYSTEM_PARTITIONS; do
        setup_partition_overlay "$PARTITION"
        if [ $? -ne 0 ]; then
            OVERLAY_SUCCESS=false
            log_message "Failed to set up overlay for $PARTITION"
        fi
    done
    
    # Check if we were able to set up overlays successfully
    if [ "$OVERLAY_SUCCESS" = "true" ]; then
        log_message "Successfully set up overlays for all partitions"
        echo "1" > "$CONFIG_DIR/overlayfs_active"
        return 0
    else
        log_message "Some overlays failed to set up, falling back to safe remount"
        echo "0" > "$CONFIG_DIR/overlayfs_active"
        return 1
    fi
}

# Begin a transaction for atomic operations
begin_transaction() {
    log_message "Beginning a new transaction"
    
    # Generate transaction ID
    TRANSACTION_ID="tx_$(date +"%Y%m%d_%H%M%S")_$(od -An -N4 -t x4 /dev/urandom 2>/dev/null | tr -d ' ')"
    
    # Create transaction directory
    if ! mkdir -p "$TRANSACTION_DIR/$TRANSACTION_ID" 2>/dev/null; then
        log_message "ERROR: Failed to create transaction directory"
        return 1
    fi
    
    # Mark transaction as started
    if ! echo "$TRANSACTION_STARTED" > "$TRANSACTION_DIR/$TRANSACTION_ID/state" 2>/dev/null; then
        log_message "ERROR: Failed to initialize transaction state"
        rm -rf "$TRANSACTION_DIR/$TRANSACTION_ID" 2>/dev/null
        return 1
    fi
    
    # Store current time
    date +"%Y-%m-%d %H:%M:%S" > "$TRANSACTION_DIR/$TRANSACTION_ID/start_time"
    
    # Set as current transaction
    echo "$TRANSACTION_ID" > "$TRANSACTION_DIR/current"
    
    # Create backup of current state
    for PARTITION in $SYSTEM_PARTITIONS; do
        if grep -q "$PARTITION" "$CONFIG_DIR/active_overlays.txt" 2>/dev/null; then
            PART_NAME=$(echo "$PARTITION" | sed 's|/|_|g' | sed 's|^_||')
            PART_UPPER="$OVERLAYFS_UPPER_DIR/$PART_NAME"
            
            # Create transaction-specific backup
            mkdir -p "$TRANSACTION_DIR/$TRANSACTION_ID/backup/$PART_NAME"
            
            # Copy current state to transaction backup
            if [ -d "$PART_UPPER" ] && [ "$(ls -A "$PART_UPPER" 2>/dev/null)" ]; then
                cp -a "$PART_UPPER/"* "$TRANSACTION_DIR/$TRANSACTION_ID/backup/$PART_NAME/" 2>/dev/null
            fi
        fi
    done
    
    log_message "Transaction $TRANSACTION_ID started"
    echo "$TRANSACTION_ID"
}

# Commit a transaction
commit_transaction() {
    local TRANSACTION_ID="$1"
    
    if [ -z "$TRANSACTION_ID" ]; then
        # Use current transaction if not specified
        if [ -f "$TRANSACTION_DIR/current" ]; then
            TRANSACTION_ID=$(cat "$TRANSACTION_DIR/current" 2>/dev/null)
        fi
    fi
    
    if [ -z "$TRANSACTION_ID" ]; then
        log_message "ERROR: No transaction ID specified or found"
        return 1
    fi
    
    if [ ! -d "$TRANSACTION_DIR/$TRANSACTION_ID" ]; then
        log_message "ERROR: Transaction directory not found: $TRANSACTION_ID"
        return 1
    fi
    
    log_message "Committing transaction $TRANSACTION_ID"
    
    # Mark transaction as committed
    echo "$TRANSACTION_COMMITTED" > "$TRANSACTION_DIR/$TRANSACTION_ID/state"
    
    # Store commit time
    date +"%Y-%m-%d %H:%M:%S" > "$TRANSACTION_DIR/$TRANSACTION_ID/commit_time"
    
    # Clear current transaction
    rm -f "$TRANSACTION_DIR/current"
    
    # Ensure all changes are synced to disk
    sync
    
    log_message "Transaction $TRANSACTION_ID committed successfully"
    return 0
}

# Abort a transaction
abort_transaction() {
    local TRANSACTION_ID="$1"
    
    if [ -z "$TRANSACTION_ID" ]; then
        # Use current transaction if not specified
        if [ -f "$TRANSACTION_DIR/current" ]; then
            TRANSACTION_ID=$(cat "$TRANSACTION_DIR/current" 2>/dev/null)
        fi
    fi
    
    if [ -z "$TRANSACTION_ID" ]; then
        log_message "ERROR: No transaction ID specified or found"
        return 1
    fi
    
    if [ ! -d "$TRANSACTION_DIR/$TRANSACTION_ID" ]; then
        log_message "ERROR: Transaction directory not found: $TRANSACTION_ID"
        return 1
    fi
    
    log_message "Aborting transaction $TRANSACTION_ID"
    
    # Mark transaction as aborted
    echo "$TRANSACTION_ABORTED" > "$TRANSACTION_DIR/$TRANSACTION_ID/state"
    
    # Store abort time
    date +"%Y-%m-%d %H:%M:%S" > "$TRANSACTION_DIR/$TRANSACTION_ID/abort_time"
    
    # Restore from transaction backup
    for PARTITION in $SYSTEM_PARTITIONS; do
        if grep -q "$PARTITION" "$CONFIG_DIR/active_overlays.txt" 2>/dev/null; then
            PART_NAME=$(echo "$PARTITION" | sed 's|/|_|g' | sed 's|^_||')
            PART_UPPER="$OVERLAYFS_UPPER_DIR/$PART_NAME"
            BACKUP_DIR="$TRANSACTION_DIR/$TRANSACTION_ID/backup/$PART_NAME"
            
            if [ -d "$BACKUP_DIR" ]; then
                # Remove current upper dir content
                rm -rf "$PART_UPPER"/*
                
                # Restore from backup
                if [ "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
                    mkdir -p "$PART_UPPER"
                    cp -a "$BACKUP_DIR/"* "$PART_UPPER/" 2>/dev/null
                    log_message "Restored $PARTITION from transaction backup"
                fi
            fi
        fi
    done
    
    # Clear current transaction
    rm -f "$TRANSACTION_DIR/current"
    
    # Ensure all changes are synced to disk
    sync
    
    log_message "Transaction $TRANSACTION_ID aborted, changes rolled back"
    return 0
}

# Rollback system to a previous state
rollback_system() {
    local RECOVERY_POINT="$1"
    
    if [ -z "$RECOVERY_POINT" ]; then
        # Find most recent recovery point
        if [ -d "$RECOVERY_DIR" ] && [ "$(ls -A "$RECOVERY_DIR" 2>/dev/null)" ]; then
            RECOVERY_POINT=$(ls -t "$RECOVERY_DIR" 2>/dev/null | head -1)
            log_message "Using most recent recovery point: $RECOVERY_POINT"
        else
            log_message "ERROR: No recovery points available"
            return 1
        fi
    fi
    
    if [ -z "$RECOVERY_POINT" ]; then
        log_message "ERROR: No valid recovery point specified or found"
        return 1
    fi
    
    if [ ! -d "$RECOVERY_DIR/$RECOVERY_POINT" ]; then
        log_message "ERROR: Recovery point directory not found: $RECOVERY_POINT"
        return 1
    fi
    
    log_message "Rolling back system to recovery point: $RECOVERY_POINT"
    
    # Check if we have an active overlay
    if [ "$(cat "$CONFIG_DIR/overlayfs_active" 2>/dev/null)" = "1" ]; then
        # Start a transaction to track this operation
        TRANSACTION_ID=$(begin_transaction)
        
        # Rollback through overlay by restoring module states
        if [ -d "$RECOVERY_DIR/$RECOVERY_POINT/modules" ]; then
            log_message "Restoring module states from recovery point"
            
            # Disable all modules first, then selectively re-enable
            if [ -d "/data/adb/modules" ]; then
                for MODULE in /data/adb/modules/*; do
                    if [ -d "$MODULE" ] && [ ! -f "$MODULE/disable" ]; then
                        MODULE_NAME=$(basename "$MODULE")
                        log_message "Disabling module $MODULE_NAME"
                        touch "$MODULE/disable"
                    fi
                done
            fi
            
            # Re-enable modules that were active in recovery point
            for MODULE_DIR in "$RECOVERY_DIR/$RECOVERY_POINT/modules/"*; do
                if [ -d "$MODULE_DIR" ] && [ ! -f "$MODULE_DIR/disable" ]; then
                    MODULE_NAME=$(basename "$MODULE_DIR")
                    if [ -d "/data/adb/modules/$MODULE_NAME" ]; then
                        log_message "Re-enabling module $MODULE_NAME"
                        rm -f "/data/adb/modules/$MODULE_NAME/disable"
                    fi
                done
            done
        fi
        
        # Execute recovery point's restore script if it exists
        if [ -f "$RECOVERY_DIR/$RECOVERY_POINT/restore.sh" ]; then
            log_message "Executing recovery point restore script"
            sh "$RECOVERY_DIR/$RECOVERY_POINT/restore.sh"
        fi
        
        # Commit the transaction
        commit_transaction "$TRANSACTION_ID"
        
        log_message "Recovery completed successfully via overlay"
        return 0
    else
        # No overlay active, perform direct restoration
        log_message "No active overlay, performing direct restoration"
        
        # Execute recovery point's restore script if it exists
        if [ -f "$RECOVERY_DIR/$RECOVERY_POINT/restore.sh" ]; then
            log_message "Executing recovery point restore script"
            sh "$RECOVERY_DIR/$RECOVERY_POINT/restore.sh"
            return $?
        else
            log_message "No restore script found in recovery point"
            return 1
        fi
    fi
}

# Handle overlay cleanup on shutdown
setup_overlay_cleanup() {
    log_message "Setting up overlay cleanup hooks"
    
    # Create cleanup script
    CLEANUP_SCRIPT="$CONFIG_DIR/overlay_cleanup.sh"
    
    cat > "$CLEANUP_SCRIPT" << EOF
#!/system/bin/sh
# Auto-generated overlay cleanup script

# Unmount all overlays in reverse order
if [ -f "$CONFIG_DIR/active_overlays.txt" ]; then
    tac "$CONFIG_DIR/active_overlays.txt" | while read OVERLAY_INFO; do
        MOUNT_POINT=\$(echo "\$OVERLAY_INFO" | cut -d: -f1)
        TEMP_MOUNT=\$(echo "\$OVERLAY_INFO" | cut -d: -f2)
        
        # Unmount overlay
        umount "\$MOUNT_POINT" 2>/dev/null
        
        # If we used a temp mount, unmount it too
        if [ ! -z "\$TEMP_MOUNT" ] && [ "\$TEMP_MOUNT" != "" ]; then
            umount "\$TEMP_MOUNT" 2>/dev/null
            rmdir "\$TEMP_MOUNT" 2>/dev/null
        fi
    done
fi

# Clean up any orphaned processes
if [ -f "$CONFIG_DIR/mount_monitor.pid" ]; then
    PID=\$(cat "$CONFIG_DIR/mount_monitor.pid" 2>/dev/null)
    if [ ! -z "\$PID" ]; then
        kill \$PID 2>/dev/null
    fi
fi
EOF

    chmod +x "$CLEANUP_SCRIPT"
    
    # Register cleanup script to be executed on shutdown
    # This varies by Android version, but we'll try common methods
    
    # Method 1: Add to init.d if available
    if [ -d "/system/etc/init.d" ]; then
        ln -sf "$CLEANUP_SCRIPT" "/system/etc/init.d/99overlayfs_cleanup"
        log_message "Added cleanup script to init.d"
    fi
    
    # Method 2: Use KernelSU's module system
    if [ -d "$MODDIR/system/bin" ]; then
        mkdir -p "$MODDIR/system/bin"
        cp "$CLEANUP_SCRIPT" "$MODDIR/system/bin/overlayfs_cleanup"
        chmod 755 "$MODDIR/system/bin/overlayfs_cleanup"
        log_message "Added cleanup script to module's system/bin"
    fi
    
    log_message "Overlay cleanup hooks configured"
}

# Main function
main() {
    log_message "OverlayFS main function started"
    
    # Check if we're in recovery mode
    if [ -f "$CONFIG_DIR/bootloop_detected" ] || [ -f "$SAFEMODE_DIR/manual_trigger" ]; then
        log_message "System in recovery mode, using minimal overlay setup"
        
        # Check if we have a recovery point to restore
        RECOVERY_POINTS=$(ls -t "$RECOVERY_DIR" 2>/dev/null)
        if [ ! -z "$RECOVERY_POINTS" ]; then
            # Get most recent recovery point
            LATEST_POINT=$(echo "$RECOVERY_POINTS" | head -1)
            log_message "Attempting to restore from recovery point: $LATEST_POINT"
            rollback_system "$LATEST_POINT"
        else
            log_message "No recovery points available for restoration"
        fi
        
        # Disable overlayfs for this boot to ensure stability
        log_message "Disabling overlayfs for recovery mode boot"
        echo "0" > "$CONFIG_DIR/overlayfs_active"
        
        # Just do a safe remount
        safe_remount_system
        return $?
    fi
    
    # Normal boot, check if overlayfs is supported
    if check_overlayfs_support; then
        # Set up system overlay for all partitions
        create_safe_environment
        OVERLAY_STATUS=$?
        
        # Setup cleanup handlers
        setup_overlay_cleanup
        
        if [ $OVERLAY_STATUS -eq 0 ]; then
            log_message "OverlayFS setup completed successfully"
            return 0
        else
            log_message "OverlayFS setup encountered issues, falling back to safe remount"
            safe_remount_system
            return $?
        fi
    else
        log_message "OverlayFS not supported, falling back to safe remount"
        safe_remount_system
        return $?
    fi
}

# Export functions for external use
export -f begin_transaction
export -f commit_transaction
export -f abort_transaction
export -f rollback_system

# Execute main function
main
exit $?