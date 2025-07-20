#!/system/bin/sh

# Advanced Anti-Bootloop KSU Module - Backup Manager
# Author: @overspend1/Wiktor

MODDIR=${0%/*}
. "$MODDIR/utils.sh"

BOOT_PARTITION="/dev/block/bootdevice/by-name/boot"
BACKUP_DIR="$BASE_DIR/kernels"
METADATA_FILE="$BACKUP_DIR/metadata.json"

# Initialize backup system
init_backup_system() {
    mkdir -p "$BACKUP_DIR"
    
    if [ ! -f "$METADATA_FILE" ]; then
        cat > "$METADATA_FILE" << EOF
{
  "version": "2.0",
  "created": "$(date '+%Y-%m-%d %H:%M:%S')",
  "device": "$(getprop ro.product.device)",
  "backups": []
}
EOF
        log_message "INFO" "Backup metadata initialized"
    fi
}

# Create kernel backup
create_backup() {
    local backup_name="$1"
    local description="$2"
    local force="$3"
    
    if [ -z "$backup_name" ]; then
        backup_name="backup_$(date '+%Y%m%d_%H%M%S')"
    fi
    
    local backup_file="$BACKUP_DIR/${backup_name}.img"
    local backup_hash_file="$BACKUP_DIR/${backup_name}.sha256"
    
    # Check if backup already exists
    if [ -f "$backup_file" ] && [ "$force" != "true" ]; then
        log_message "WARN" "Backup $backup_name already exists, use force=true to overwrite"
        return 1
    fi
    
    # Check available space (need at least 100MB)
    local available_space=$(df "$BACKUP_DIR" | tail -1 | awk '{print $4}')
    if [ "$available_space" -lt 102400 ]; then
        log_message "ERROR" "Insufficient space for backup (need 100MB, available: ${available_space}KB)"
        return 1
    fi
    
    log_message "INFO" "Creating kernel backup: $backup_name"
    
    # Create backup
    if dd if="$BOOT_PARTITION" of="$backup_file" bs=1024 2>/dev/null; then
        # Generate hash
        sha256sum "$backup_file" | cut -d' ' -f1 > "$backup_hash_file"
        
        # Get kernel info
        local kernel_version=$(strings "$backup_file" | grep "Linux version" | head -1 | cut -d' ' -f3)
        local backup_size=$(stat -c%s "$backup_file")
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        
        # Update metadata
        update_backup_metadata "$backup_name" "$description" "$kernel_version" "$backup_size" "$timestamp"
        
        log_message "INFO" "Backup created successfully: $backup_name (${backup_size} bytes)"
        
        # Cleanup old backups if we exceed the limit
        cleanup_old_backups
        
        return 0
    else
        log_message "ERROR" "Failed to create backup: $backup_name"
        rm -f "$backup_file" "$backup_hash_file"
        return 1
    fi
}

# Update backup metadata
update_backup_metadata() {
    local name="$1"
    local description="$2"
    local kernel_version="$3"
    local size="$4"
    local timestamp="$5"
    
    # Create temporary metadata file
    local temp_metadata="/tmp/metadata_$$.json"
    
    # Read existing metadata and add new backup entry
    if [ -f "$METADATA_FILE" ]; then
        # Remove existing entry if updating
        grep -v "\"name\": \"$name\"" "$METADATA_FILE" > "$temp_metadata" 2>/dev/null || echo '{"backups":[]}' > "$temp_metadata"
    else
        echo '{"backups":[]}' > "$temp_metadata"
    fi
    
    # Add new backup entry (simplified JSON manipulation)
    sed -i 's/"backups":\[/"backups":[{"name":"'$name'","description":"'$description'","kernel_version":"'$kernel_version'","size":'$size',"created":"'$timestamp'"},/' "$temp_metadata"
    
    mv "$temp_metadata" "$METADATA_FILE"
}

# Restore kernel from backup
restore_backup() {
    local backup_name="$1"
    local verify_hash="$2"
    
    local backup_file="$BACKUP_DIR/${backup_name}.img"
    local backup_hash_file="$BACKUP_DIR/${backup_name}.sha256"
    
    if [ ! -f "$backup_file" ]; then
        log_message "ERROR" "Backup not found: $backup_name"
        return 1
    fi
    
    # Verify backup integrity
    if [ "$verify_hash" = "true" ] && [ -f "$backup_hash_file" ]; then
        local stored_hash=$(cat "$backup_hash_file")
        local current_hash=$(sha256sum "$backup_file" | cut -d' ' -f1)
        
        if [ "$stored_hash" != "$current_hash" ]; then
            log_message "ERROR" "Backup integrity check failed for: $backup_name"
            return 1
        fi
        log_message "INFO" "Backup integrity verified: $backup_name"
    fi
    
    log_message "INFO" "Restoring kernel from backup: $backup_name"
    
    # Create current kernel backup before restoring
    create_backup "pre_restore_$(date '+%Y%m%d_%H%M%S')" "Auto backup before restore" "true"
    
    # Restore kernel
    if dd if="$backup_file" of="$BOOT_PARTITION" bs=1024 2>/dev/null; then
        log_message "INFO" "Kernel restored successfully from backup: $backup_name"
        
        # Update kernel hash for integrity checking
        local new_hash=$(sha256sum "$BOOT_PARTITION" 2>/dev/null | cut -d' ' -f1)
        echo "$new_hash" > "$BASE_DIR/kernel_hash"
        
        return 0
    else
        log_message "ERROR" "Failed to restore kernel from backup: $backup_name"
        return 1
    fi
}

# List available backups
list_backups() {
    local verbose="$1"
    
    if [ ! -f "$METADATA_FILE" ]; then
        log_message "INFO" "No backups found"
        return 1
    fi
    
    log_message "INFO" "Available kernel backups:"
    
    # Parse metadata and list backups
    local backup_count=0
    local total_size=0
    
    for backup_file in "$BACKUP_DIR"/*.img; do
        if [ -f "$backup_file" ]; then
            local backup_name=$(basename "$backup_file" .img)
            local backup_size=$(stat -c%s "$backup_file" 2>/dev/null || echo "0")
            local backup_date=$(stat -c%y "$backup_file" 2>/dev/null | cut -d' ' -f1)
            
            if [ "$verbose" = "true" ]; then
                log_message "INFO" "  $backup_name (${backup_size} bytes, created: $backup_date)"
            else
                log_message "INFO" "  $backup_name"
            fi
            
            backup_count=$((backup_count + 1))
            total_size=$((total_size + backup_size))
        fi
    done
    
    log_message "INFO" "Total: $backup_count backups, $total_size bytes"
    return 0
}

# Delete backup
delete_backup() {
    local backup_name="$1"
    
    local backup_file="$BACKUP_DIR/${backup_name}.img"
    local backup_hash_file="$BACKUP_DIR/${backup_name}.sha256"
    
    if [ ! -f "$backup_file" ]; then
        log_message "ERROR" "Backup not found: $backup_name"
        return 1
    fi
    
    log_message "INFO" "Deleting backup: $backup_name"
    
    rm -f "$backup_file" "$backup_hash_file"
    
    # Update metadata (remove entry)
    if [ -f "$METADATA_FILE" ]; then
        grep -v "\"name\": \"$backup_name\"" "$METADATA_FILE" > "$METADATA_FILE.tmp" 2>/dev/null
        mv "$METADATA_FILE.tmp" "$METADATA_FILE"
    fi
    
    log_message "INFO" "Backup deleted: $backup_name"
    return 0
}

# Cleanup old backups when exceeding limit
cleanup_old_backups() {
    local max_backups="$BACKUP_SLOTS"
    local backup_count=$(find "$BACKUP_DIR" -name "*.img" | wc -l)
    
    if [ "$backup_count" -gt "$max_backups" ]; then
        local excess=$((backup_count - max_backups))
        log_message "INFO" "Cleaning up $excess old backups (limit: $max_backups)"
        
        # Remove oldest backups
        find "$BACKUP_DIR" -name "*.img" -printf '%T@ %p\n' | sort -n | head -$excess | while read timestamp file; do
            local backup_name=$(basename "$file" .img)
            delete_backup "$backup_name"
        done
    fi
}

# Get recommended backup for recovery
get_recovery_backup() {
    local strategy="$1"
    
    case "$strategy" in
        "latest")
            find "$BACKUP_DIR" -name "*.img" -printf '%T@ %p\n' | sort -nr | head -1 | cut -d' ' -f2 | xargs basename -s .img
            ;;
        "stock")
            # Look for stock or original backup
            for name in "stock" "original" "factory" "initial"; do
                if [ -f "$BACKUP_DIR/${name}.img" ]; then
                    echo "$name"
                    return 0
                fi
            done
            # Fallback to oldest backup
            find "$BACKUP_DIR" -name "*.img" -printf '%T@ %p\n' | sort -n | head -1 | cut -d' ' -f2 | xargs basename -s .img
            ;;
        "stable")
            # Look for backups marked as stable (TODO: implement marking system)
            find "$BACKUP_DIR" -name "*stable*.img" -printf '%T@ %p\n' | sort -nr | head -1 | cut -d' ' -f2 | xargs basename -s .img
            ;;
        *)
            # Default to latest
            find "$BACKUP_DIR" -name "*.img" -printf '%T@ %p\n' | sort -nr | head -1 | cut -d' ' -f2 | xargs basename -s .img
            ;;
    esac
}

# Verify all backups
verify_all_backups() {
    local failed_count=0
    local total_count=0
    
    log_message "INFO" "Verifying all kernel backups..."
    
    for backup_file in "$BACKUP_DIR"/*.img; do
        if [ -f "$backup_file" ]; then
            local backup_name=$(basename "$backup_file" .img)
            local backup_hash_file="$BACKUP_DIR/${backup_name}.sha256"
            
            total_count=$((total_count + 1))
            
            if [ -f "$backup_hash_file" ]; then
                local stored_hash=$(cat "$backup_hash_file")
                local current_hash=$(sha256sum "$backup_file" | cut -d' ' -f1)
                
                if [ "$stored_hash" = "$current_hash" ]; then
                    log_message "INFO" "Backup OK: $backup_name"
                else
                    log_message "ERROR" "Backup CORRUPTED: $backup_name"
                    failed_count=$((failed_count + 1))
                fi
            else
                log_message "WARN" "No hash file for backup: $backup_name"
            fi
        fi
    done
    
    log_message "INFO" "Backup verification complete: $((total_count - failed_count))/$total_count OK"
    
    if [ "$failed_count" -gt 0 ]; then
        return 1
    fi
    return 0
}