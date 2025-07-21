#!/system/bin/sh
# KernelSU Anti-Bootloop & Backup Module
# Recovery Point Management Script
# Creates and manages system recovery points for rollback capabilities

MODULE_DIR="/data/adb/modules/kernelsu_antibootloop_backup"
RECOVERY_POINTS_DIR="$MODULE_DIR/config/recovery_points"
CONFIG_DIR="$MODULE_DIR/config"
LOG_FILE="$MODULE_DIR/logs/recovery-point.log"

# Ensure directories exist
mkdir -p "$RECOVERY_POINTS_DIR"
mkdir -p "$MODULE_DIR/logs"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo "$1"
}

# Create recovery point
create_recovery_point() {
    local point_name="$1"
    local description="$2"
    local point_file="$RECOVERY_POINTS_DIR/${point_name}.point"
    
    log "Creating recovery point: $point_name"
    
    # Create recovery point metadata
    cat > "$point_file" << EOF
{
    "name": "$point_name",
    "description": "$description",
    "timestamp": $(date +%s),
    "created": "$(date -Iseconds)",
    "kernel_version": "$(uname -r)",
    "android_version": "$(getprop ro.build.version.release)",
    "kernelsu_version": "$(su -v)",
    "modules": []
}
EOF

    # Backup current module states
    local modules_backup="$RECOVERY_POINTS_DIR/${point_name}_modules.tar.gz"
    if [ -d "/data/adb/modules" ]; then
        tar -czf "$modules_backup" -C /data/adb modules/ 2>/dev/null
        log "Backed up KernelSU modules to $modules_backup"
    fi
    
    # Backup system properties
    local props_backup="$RECOVERY_POINTS_DIR/${point_name}_props.txt"
    getprop > "$props_backup" 2>/dev/null
    log "Backed up system properties to $props_backup"
    
    # Backup important config files
    local config_backup="$RECOVERY_POINTS_DIR/${point_name}_config.tar.gz"
    tar -czf "$config_backup" \
        -C /data/adb \
        --exclude="modules/*/logs/*" \
        --exclude="modules/*/cache/*" \
        --exclude="modules/*/temp/*" \
        . 2>/dev/null
    
    log "Recovery point created successfully: $point_name"
    echo "Recovery point created successfully"
}

# Restore recovery point
restore_recovery_point() {
    local point_name="$1"
    local point_file="$RECOVERY_POINTS_DIR/${point_name}"
    
    # Remove .point extension if present
    point_name=${point_name%.point}
    point_file="$RECOVERY_POINTS_DIR/${point_name}.point"
    
    if [ ! -f "$point_file" ]; then
        log "ERROR: Recovery point not found: $point_name"
        echo "Recovery point not found: $point_name"
        return 1
    fi
    
    log "Restoring recovery point: $point_name"
    
    # Create backup of current state before restore
    local current_backup="$RECOVERY_POINTS_DIR/pre_restore_$(date +%s)"
    create_recovery_point "pre_restore_$(date +%s)" "Automatic backup before restore"
    
    # Restore modules
    local modules_backup="$RECOVERY_POINTS_DIR/${point_name}_modules.tar.gz"
    if [ -f "$modules_backup" ]; then
        log "Restoring KernelSU modules from $modules_backup"
        rm -rf /data/adb/modules_backup
        mv /data/adb/modules /data/adb/modules_backup 2>/dev/null || true
        mkdir -p /data/adb/modules
        tar -xzf "$modules_backup" -C /data/adb 2>/dev/null
        
        # Set proper permissions
        find /data/adb/modules -type d -exec chmod 755 {} \;
        find /data/adb/modules -type f -exec chmod 644 {} \;
        find /data/adb/modules -name "*.sh" -exec chmod 755 {} \;
    fi
    
    # Restore config
    local config_backup="$RECOVERY_POINTS_DIR/${point_name}_config.tar.gz"
    if [ -f "$config_backup" ]; then
        log "Restoring configuration from $config_backup"
        # Backup current config
        mv /data/adb/adb.sh /data/adb/adb.sh.backup 2>/dev/null || true
        mv /data/adb/service.sh /data/adb/service.sh.backup 2>/dev/null || true
        
        # Extract config (be careful not to overwrite critical files)
        tar -xzf "$config_backup" -C /data/adb \
            --exclude="adb.sh" \
            --exclude="service.sh" \
            --exclude="ksu/bin/*" 2>/dev/null
    fi
    
    log "Recovery point restored successfully: $point_name"
    echo "Recovery point restored successfully"
    
    # Log the restoration
    echo "$(date +%s),restore,$point_name" >> "$CONFIG_DIR/activity.log"
}

# List recovery points
list_recovery_points() {
    log "Listing recovery points"
    
    if [ ! -d "$RECOVERY_POINTS_DIR" ]; then
        echo "No recovery points found"
        return 0
    fi
    
    echo "Available recovery points:"
    for point_file in "$RECOVERY_POINTS_DIR"/*.point; do
        if [ -f "$point_file" ]; then
            local point_name=$(basename "$point_file" .point)
            local created_time=$(date -d "@$(grep -o '"timestamp": [0-9]*' "$point_file" | cut -d' ' -f2)" 2>/dev/null || echo "Unknown")
            local description=$(grep -o '"description": "[^"]*"' "$point_file" | cut -d'"' -f4 2>/dev/null || echo "No description")
            
            echo "  $point_name ($created_time) - $description"
        fi
    done
}

# Delete recovery point
delete_recovery_point() {
    local point_name="$1"
    
    # Remove .point extension if present
    point_name=${point_name%.point}
    
    local point_file="$RECOVERY_POINTS_DIR/${point_name}.point"
    local modules_backup="$RECOVERY_POINTS_DIR/${point_name}_modules.tar.gz"
    local props_backup="$RECOVERY_POINTS_DIR/${point_name}_props.txt"
    local config_backup="$RECOVERY_POINTS_DIR/${point_name}_config.tar.gz"
    
    if [ ! -f "$point_file" ]; then
        log "ERROR: Recovery point not found: $point_name"
        echo "Recovery point not found: $point_name"
        return 1
    fi
    
    log "Deleting recovery point: $point_name"
    
    # Remove all related files
    rm -f "$point_file"
    rm -f "$modules_backup"
    rm -f "$props_backup"
    rm -f "$config_backup"
    
    log "Recovery point deleted successfully: $point_name"
    echo "Recovery point deleted successfully"
}

# Cleanup old recovery points (keep only last 10)
cleanup_old_points() {
    log "Cleaning up old recovery points"
    
    # Count recovery points
    local point_count=$(find "$RECOVERY_POINTS_DIR" -name "*.point" | wc -l)
    
    if [ "$point_count" -le 10 ]; then
        log "No cleanup needed, only $point_count recovery points"
        return 0
    fi
    
    # Get oldest points to delete
    local to_delete=$((point_count - 10))
    find "$RECOVERY_POINTS_DIR" -name "*.point" -type f -printf '%T@ %p\n' | \
        sort -n | \
        head -n "$to_delete" | \
        cut -d' ' -f2- | \
        while read -r point_file; do
            local point_name=$(basename "$point_file" .point)
            log "Cleaning up old recovery point: $point_name"
            delete_recovery_point "$point_name"
        done
    
    log "Cleanup completed, kept 10 most recent recovery points"
}

# Main function
main() {
    local action="$1"
    local point_name="$2"
    local description="$3"
    
    case "$action" in
        "create")
            if [ -z "$point_name" ]; then
                echo "Usage: $0 create <point_name> [description]"
                exit 1
            fi
            create_recovery_point "$point_name" "$description"
            cleanup_old_points
            ;;
        "restore")
            if [ -z "$point_name" ]; then
                echo "Usage: $0 restore <point_name>"
                exit 1
            fi
            restore_recovery_point "$point_name"
            ;;
        "list")
            list_recovery_points
            ;;
        "delete")
            if [ -z "$point_name" ]; then
                echo "Usage: $0 delete <point_name>"
                exit 1
            fi
            delete_recovery_point "$point_name"
            ;;
        "cleanup")
            cleanup_old_points
            ;;
        *)
            echo "Usage: $0 {create|restore|list|delete|cleanup} [arguments]"
            echo ""
            echo "Commands:"
            echo "  create <name> [description]  - Create a new recovery point"
            echo "  restore <name>              - Restore from recovery point"
            echo "  list                        - List all recovery points"
            echo "  delete <name>               - Delete a recovery point"
            echo "  cleanup                     - Remove old recovery points"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"