#!/system/bin/sh
# KernelSU Anti-Bootloop Backup Partition Management System
# Handles partition detection, block-level access, and snapshot management

MODDIR=${0%/*}
MODDIR=${MODDIR%/*}
CONFIG_DIR="$MODDIR/config"
PART_INFO_DIR="$CONFIG_DIR/partition_info"
SNAPSHOT_DIR="$CONFIG_DIR/snapshots"

# Ensure directories exist
mkdir -p "$PART_INFO_DIR"
mkdir -p "$SNAPSHOT_DIR"

# Log function
log_message() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$CONFIG_DIR/partition_manager.log"
}

log_message "Partition manager started"

# -----------------------------------------------
# PARTITION DETECTION FOR A/B SCHEMES
# -----------------------------------------------

# Detect if the device uses A/B partition scheme
detect_ab_partitioning() {
    log_message "Detecting A/B partition scheme"
    
    # Check if device has slot_suffix or slot properties
    SLOT=$(getprop ro.boot.slot_suffix 2>/dev/null)
    if [ -z "$SLOT" ]; then
        SLOT=$(getprop ro.boot.slot 2>/dev/null)
    fi
    
    if [ -n "$SLOT" ]; then
        log_message "A/B partition scheme detected, current slot: $SLOT"
        echo "$SLOT" > "$PART_INFO_DIR/current_slot"
        echo "true" > "$PART_INFO_DIR/is_ab_device"
        return 0
    else
        log_message "Device does not use A/B partition scheme"
        echo "false" > "$PART_INFO_DIR/is_ab_device"
        return 1
    fi
}

# Get the inactive slot (for A/B devices)
get_inactive_slot() {
    if [ -f "$PART_INFO_DIR/is_ab_device" ] && [ "$(cat "$PART_INFO_DIR/is_ab_device")" = "true" ]; then
        CURRENT_SLOT=$(cat "$PART_INFO_DIR/current_slot")
        if [ "$CURRENT_SLOT" = "_a" ]; then
            echo "_b"
        else
            echo "_a"
        fi
    else
        echo ""
    fi
}

# List all available partitions
list_partitions() {
    log_message "Listing available partitions"
    
    # Clear previous partition info
    rm -f "$PART_INFO_DIR/partitions.list" 2>/dev/null
    
    # Find all block devices
    for BLOCK in /dev/block/by-name/*; do
        if [ -L "$BLOCK" ]; then
            PART_NAME=$(basename "$BLOCK")
            PART_PATH=$(readlink -f "$BLOCK")
            echo "$PART_NAME:$PART_PATH" >> "$PART_INFO_DIR/partitions.list"
        fi
    done
    
    # Also check /dev/block/bootdevice/by-name if available
    if [ -d "/dev/block/bootdevice/by-name" ]; then
        for BLOCK in /dev/block/bootdevice/by-name/*; do
            if [ -L "$BLOCK" ]; then
                PART_NAME=$(basename "$BLOCK")
                PART_PATH=$(readlink -f "$BLOCK")
                # Check if already in the list
                if ! grep -q "^$PART_NAME:" "$PART_INFO_DIR/partitions.list" 2>/dev/null; then
                    echo "$PART_NAME:$PART_PATH" >> "$PART_INFO_DIR/partitions.list"
                fi
            fi
        done
    fi
    
    # Log total partitions found
    PART_COUNT=$(wc -l < "$PART_INFO_DIR/partitions.list" 2>/dev/null || echo "0")
    log_message "Found $PART_COUNT partitions"
    
    return 0
}

# Get critical partitions that should be backed up
get_critical_partitions() {
    log_message "Identifying critical partitions"
    
    # Clear previous critical partitions list
    rm -f "$PART_INFO_DIR/critical_partitions.list" 2>/dev/null
    
    # Define list of critical partition patterns
    CRITICAL_PATTERNS="boot system vendor product dtbo vbmeta super"
    
    # Extract partition names from the list
    if [ -f "$PART_INFO_DIR/partitions.list" ]; then
        while IFS=: read -r PART_NAME PART_PATH; do
            for PATTERN in $CRITICAL_PATTERNS; do
                if echo "$PART_NAME" | grep -q "^$PATTERN"; then
                    echo "$PART_NAME:$PART_PATH" >> "$PART_INFO_DIR/critical_partitions.list"
                    break
                fi
            done
        done < "$PART_INFO_DIR/partitions.list"
    fi
    
    # Log critical partitions count
    CRITICAL_COUNT=$(wc -l < "$PART_INFO_DIR/critical_partitions.list" 2>/dev/null || echo "0")
    log_message "Identified $CRITICAL_COUNT critical partitions"
    
    return 0
}

# -----------------------------------------------
# BLOCK-LEVEL ACCESS ENGINE
# -----------------------------------------------

# Check if a partition is mounted
is_partition_mounted() {
    PART_PATH="$1"
    
    if mount | grep -q "$PART_PATH"; then
        return 0
    else
        return 1
    fi
}

# Read a block from a partition
read_partition_block() {
    PART_PATH="$1"
    OFFSET="$2"
    SIZE="$3"
    OUTPUT="$4"
    
    log_message "Reading block from $PART_PATH at offset $OFFSET, size $SIZE"
    
    if [ ! -e "$PART_PATH" ]; then
        log_message "Error: Partition $PART_PATH does not exist"
        return 1
    fi
    
    # Use dd to read a block from the partition
    if ! dd if="$PART_PATH" of="$OUTPUT" bs=1 skip="$OFFSET" count="$SIZE" 2>/dev/null; then
        log_message "Error: Failed to read block from $PART_PATH"
        return 1
    fi
    
    return 0
}

# Write a block to a partition (with safety checks)
write_partition_block() {
    PART_PATH="$1"
    OFFSET="$2"
    INPUT="$3"
    
    log_message "Writing block to $PART_PATH at offset $OFFSET"
    
    if [ ! -e "$PART_PATH" ]; then
        log_message "Error: Partition $PART_PATH does not exist"
        return 1
    fi
    
    # Check if partition is mounted
    if is_partition_mounted "$PART_PATH"; then
        log_message "Warning: Attempting to write to mounted partition $PART_PATH"
        return 1
    fi
    
    # Get size of input file
    SIZE=$(stat -c %s "$INPUT" 2>/dev/null)
    if [ -z "$SIZE" ]; then
        log_message "Error: Failed to get size of input file $INPUT"
        return 1
    fi
    
    # Use dd to write the block to the partition
    if ! dd if="$INPUT" of="$PART_PATH" bs=1 seek="$OFFSET" count="$SIZE" 2>/dev/null; then
        log_message "Error: Failed to write block to $PART_PATH"
        return 1
    fi
    
    return 0
}

# Calculate partition checksum
calculate_partition_checksum() {
    PART_PATH="$1"
    
    log_message "Calculating checksum for $PART_PATH"
    
    if [ ! -e "$PART_PATH" ]; then
        log_message "Error: Partition $PART_PATH does not exist"
        return 1
    fi
    
    # Use sha256sum if available, fall back to md5sum
    if command -v sha256sum >/dev/null 2>&1; then
        CHECKSUM=$(dd if="$PART_PATH" bs=1M count=100 2>/dev/null | sha256sum | awk '{print $1}')
    else
        CHECKSUM=$(dd if="$PART_PATH" bs=1M count=100 2>/dev/null | md5sum | awk '{print $1}')
    fi
    
    if [ -n "$CHECKSUM" ]; then
        echo "$CHECKSUM"
        return 0
    else
        log_message "Error: Failed to calculate checksum for $PART_PATH"
        return 1
    fi
}

# -----------------------------------------------
# SNAPSHOT MANAGEMENT
# -----------------------------------------------

# Create a snapshot of a partition
create_partition_snapshot() {
    PART_NAME="$1"
    SNAPSHOT_NAME="$2"
    
    if [ -z "$SNAPSHOT_NAME" ]; then
        SNAPSHOT_NAME="${PART_NAME}_$(date +"%Y%m%d_%H%M%S")"
    fi
    
    log_message "Creating snapshot $SNAPSHOT_NAME for partition $PART_NAME"
    
    # Get partition path
    PART_PATH=""
    if [ -f "$PART_INFO_DIR/partitions.list" ]; then
        PART_PATH=$(grep "^$PART_NAME:" "$PART_INFO_DIR/partitions.list" | cut -d: -f2)
    fi
    
    if [ -z "$PART_PATH" ]; then
        log_message "Error: Partition $PART_NAME not found"
        return 1
    fi
    
    # Create snapshot directory
    SNAPSHOT_PATH="$SNAPSHOT_DIR/$SNAPSHOT_NAME"
    mkdir -p "$SNAPSHOT_PATH"
    
    # Get partition size
    PART_SIZE=$(blockdev --getsize64 "$PART_PATH" 2>/dev/null)
    if [ -z "$PART_SIZE" ]; then
        # Fallback method to get size
        PART_SIZE=$(wc -c < "$PART_PATH" 2>/dev/null)
    fi
    
    if [ -z "$PART_SIZE" ]; then
        log_message "Error: Failed to get size of partition $PART_NAME"
        return 1
    fi
    
    # Create snapshot metadata
    cat > "$SNAPSHOT_PATH/metadata.txt" << EOF
Partition: $PART_NAME
Path: $PART_PATH
Size: $PART_SIZE
Created: $(date)
Checksum: $(calculate_partition_checksum "$PART_PATH")
EOF
    
    # For small partitions, create a full backup
    if [ "$PART_SIZE" -lt 104857600 ]; then # 100MB
        log_message "Creating full backup of small partition $PART_NAME ($PART_SIZE bytes)"
        if ! dd if="$PART_PATH" of="$SNAPSHOT_PATH/full_backup.img" bs=1M 2>/dev/null; then
            log_message "Error: Failed to create full backup of $PART_NAME"
            return 1
        fi
    else
        # For larger partitions, save only the first 10MB and important metadata
        log_message "Creating partial backup of large partition $PART_NAME ($PART_SIZE bytes)"
        if ! dd if="$PART_PATH" of="$SNAPSHOT_PATH/header.img" bs=1M count=10 2>/dev/null; then
            log_message "Error: Failed to create header backup of $PART_NAME"
            return 1
        fi
        
        # Save partition table if this is a super partition
        if echo "$PART_NAME" | grep -q "^super"; then
            log_message "Saving partition table for super partition"
            if command -v lpdump >/dev/null 2>&1; then
                lpdump "$PART_PATH" > "$SNAPSHOT_PATH/lpdump.txt" 2>/dev/null
            fi
        fi
    fi
    
    log_message "Successfully created snapshot $SNAPSHOT_NAME for partition $PART_NAME"
    return 0
}

# List all available snapshots
list_snapshots() {
    log_message "Listing available snapshots"
    
    if [ ! -d "$SNAPSHOT_DIR" ]; then
        log_message "No snapshots directory found"
        return 1
    fi
    
    for SNAPSHOT in "$SNAPSHOT_DIR"/*; do
        if [ -d "$SNAPSHOT" ]; then
            SNAPSHOT_NAME=$(basename "$SNAPSHOT")
            echo "$SNAPSHOT_NAME"
        fi
    done
    
    return 0
}

# Restore from a snapshot
restore_from_snapshot() {
    SNAPSHOT_NAME="$1"
    SNAPSHOT_PATH="$SNAPSHOT_DIR/$SNAPSHOT_NAME"
    
    log_message "Restoring from snapshot $SNAPSHOT_NAME"
    
    if [ ! -d "$SNAPSHOT_PATH" ]; then
        log_message "Error: Snapshot $SNAPSHOT_NAME not found"
        return 1
    fi
    
    # Check if metadata exists
    if [ ! -f "$SNAPSHOT_PATH/metadata.txt" ]; then
        log_message "Error: Snapshot metadata not found"
        return 1
    fi
    
    # Extract partition info from metadata
    PART_NAME=$(grep "^Partition:" "$SNAPSHOT_PATH/metadata.txt" | cut -d: -f2- | tr -d ' ')
    PART_PATH=$(grep "^Path:" "$SNAPSHOT_PATH/metadata.txt" | cut -d: -f2- | tr -d ' ')
    
    if [ -z "$PART_NAME" ] || [ -z "$PART_PATH" ]; then
        log_message "Error: Invalid snapshot metadata"
        return 1
    fi
    
    # Check if partition exists
    if [ ! -e "$PART_PATH" ]; then
        log_message "Error: Partition $PART_PATH does not exist"
        return 1
    fi
    
    # Check if full backup exists
    if [ -f "$SNAPSHOT_PATH/full_backup.img" ]; then
        log_message "Restoring full backup to $PART_NAME"
        
        # Check if partition is mounted
        if is_partition_mounted "$PART_PATH"; then
            log_message "Error: Cannot restore to mounted partition $PART_NAME"
            return 1
        fi
        
        # Restore the full backup
        if ! dd if="$SNAPSHOT_PATH/full_backup.img" of="$PART_PATH" bs=1M 2>/dev/null; then
            log_message "Error: Failed to restore full backup to $PART_NAME"
            return 1
        fi
    else
        log_message "Error: Full backup not available for restoration"
        return 1
    fi
    
    log_message "Successfully restored snapshot $SNAPSHOT_NAME to partition $PART_NAME"
    return 0
}

# Initialize partition manager
init_partition_manager() {
    log_message "Initializing partition manager"
    
    # Create directories if they don't exist
    mkdir -p "$PART_INFO_DIR"
    mkdir -p "$SNAPSHOT_DIR"
    
    # Detect A/B partitioning
    detect_ab_partitioning
    
    # List all partitions
    list_partitions
    
    # Identify critical partitions
    get_critical_partitions
    
    log_message "Partition manager initialized"
    return 0
}

# Create snapshots of all critical partitions
backup_critical_partitions() {
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_ID="critical_$TIMESTAMP"
    
    log_message "Backing up all critical partitions with ID: $BACKUP_ID"
    
    # Create backup directory
    BACKUP_PATH="$SNAPSHOT_DIR/$BACKUP_ID"
    mkdir -p "$BACKUP_PATH"
    
    # Check if critical partitions list exists
    if [ ! -f "$PART_INFO_DIR/critical_partitions.list" ]; then
        log_message "Critical partitions list not found, generating..."
        get_critical_partitions
    fi
    
    # Count of successful backups
    SUCCESS_COUNT=0
    
    # Backup each critical partition
    while IFS=: read -r PART_NAME PART_PATH; do
        log_message "Backing up critical partition: $PART_NAME"
        SNAPSHOT_NAME="${BACKUP_ID}_${PART_NAME}"
        
        if create_partition_snapshot "$PART_NAME" "$SNAPSHOT_NAME"; then
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        fi
    done < "$PART_INFO_DIR/critical_partitions.list"
    
    # Create backup summary
    cat > "$BACKUP_PATH/summary.txt" << EOF
Backup ID: $BACKUP_ID
Created: $(date)
Successful Backups: $SUCCESS_COUNT
A/B Device: $(cat "$PART_INFO_DIR/is_ab_device")
Current Slot: $(cat "$PART_INFO_DIR/current_slot" 2>/dev/null)
EOF
    
    log_message "Critical partitions backup completed with $SUCCESS_COUNT successful backups"
    
    if [ "$SUCCESS_COUNT" -gt 0 ]; then
        echo "$BACKUP_ID"
        return 0
    else
        return 1
    fi
}

# Main function - Command processor
main() {
    COMMAND="$1"
    PARAM1="$2"
    PARAM2="$3"
    
    case "$COMMAND" in
        "init")
            init_partition_manager
            ;;
        "detect_ab")
            detect_ab_partitioning
            ;;
        "list_partitions")
            list_partitions
            ;;
        "get_critical")
            get_critical_partitions
            ;;
        "snapshot")
            create_partition_snapshot "$PARAM1" "$PARAM2"
            ;;
        "list_snapshots")
            list_snapshots
            ;;
        "restore")
            restore_from_snapshot "$PARAM1"
            ;;
        "backup_critical")
            backup_critical_partitions
            ;;
        *)
            log_message "Unknown command: $COMMAND"
            echo "Usage: $0 init|detect_ab|list_partitions|get_critical|snapshot|list_snapshots|restore|backup_critical [parameters]"
            return 1
            ;;
    esac
}

# Execute main with all arguments
main "$@"