#!/system/bin/sh
# KernelSU Anti-Bootloop Backup Engine Script

MODDIR=${0%/*}
MODDIR=${MODDIR%/*}
CONFIG_DIR="$MODDIR/config"
BACKUP_DIR="$CONFIG_DIR/backups"
TEMPLATE_DIR="$MODDIR/templates"
PROFILE_DIR="$CONFIG_DIR/backup_profiles"

# Ensure backup directories exist
mkdir -p "$BACKUP_DIR"
mkdir -p "$PROFILE_DIR"

# Log function for debugging
log_message() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$CONFIG_DIR/backup_engine.log"
}

log_message "Backup engine started"

# Check if backup encryption is enabled
check_encryption_enabled() {
    ENCRYPTION_ENABLED=$(grep "backup_encryption" "$CONFIG_DIR/main.conf" | cut -d= -f2 || echo "false")
    if [ "$ENCRYPTION_ENABLED" == "true" ]; then
        log_message "Backup encryption is enabled"
        return 0
    else
        log_message "Backup encryption is disabled"
        return 1
    fi
}

# Helper function to backup a partition
backup_partition() {
    local partition="$1"
    local backup_path="$2"
    
    local partition_device="/dev/block/bootdevice/by-name/$partition"
    if [ -b "$partition_device" ]; then
        log_message "Backing up partition: $partition"
        dd if="$partition_device" of="$backup_path/${partition}.img" bs=1M 2>/dev/null
        if [ $? -eq 0 ]; then
            log_message "Successfully backed up $partition partition"
        else
            log_message "Failed to backup $partition partition"
        fi
    else
        log_message "Partition $partition not found"
    fi
}

# Helper function to backup a directory
backup_directory() {
    local source_dir="$1"
    local backup_path="$2"
    
    if [ -d "$source_dir" ]; then
        log_message "Backing up directory: $source_dir"
        local dest_name=$(echo "$source_dir" | sed 's|/|_|g' | sed 's|^_||')
        mkdir -p "$backup_path/$dest_name"
        cp -r "$source_dir"/* "$backup_path/$dest_name/" 2>/dev/null
        if [ $? -eq 0 ]; then
            log_message "Successfully backed up directory $source_dir"
        else
            log_message "Failed to backup directory $source_dir"
        fi
    else
        log_message "Directory $source_dir not found"
    fi
}

# Helper function to backup a single file
backup_file() {
    local source_file="$1"
    local backup_path="$2"
    
    if [ -f "$source_file" ]; then
        log_message "Backing up file: $source_file"
        local dest_dir=$(dirname "$source_file" | sed 's|/|_|g' | sed 's|^_||')
        local dest_file=$(basename "$source_file")
        mkdir -p "$backup_path/$dest_dir"
        cp "$source_file" "$backup_path/$dest_dir/$dest_file"
        if [ $? -eq 0 ]; then
            log_message "Successfully backed up file $source_file"
        else
            log_message "Failed to backup file $source_file"
        fi
    else
        log_message "File $source_file not found"
    fi
}

# Create backup based on profile
create_backup() {
    PROFILE_NAME="$1"
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_ID="${PROFILE_NAME}_${TIMESTAMP}"
    BACKUP_PATH="$BACKUP_DIR/$BACKUP_ID"
    
    log_message "Creating backup with profile: $PROFILE_NAME, ID: $BACKUP_ID"
    
    # Create backup directory
    mkdir -p "$BACKUP_PATH"
    
    # Create backup metadata
    echo "Backup ID: $BACKUP_ID" > "$BACKUP_PATH/metadata.txt"
    echo "Created: $(date)" >> "$BACKUP_PATH/metadata.txt"
    echo "Profile: $PROFILE_NAME" >> "$BACKUP_PATH/metadata.txt"
    
    # Check if profile exists
    if [ -f "$PROFILE_DIR/$PROFILE_NAME.profile" ]; then
        log_message "Using profile: $PROFILE_NAME"
        
        # Copy profile to backup for reference
        cp "$PROFILE_DIR/$PROFILE_NAME.profile" "$BACKUP_PATH/profile.txt"
        
        # Parse profile and backup specified items
        while IFS= read -r line; do
            [ -z "$line" ] || [ "${line#\#}" != "$line" ] && continue
            
            case "$line" in
                "partition:"*)
                    partition=$(echo "$line" | cut -d: -f2)
                    backup_partition "$partition" "$BACKUP_PATH"
                    ;;
                "directory:"*)
                    dir=$(echo "$line" | cut -d: -f2)
                    backup_directory "$dir" "$BACKUP_PATH"
                    ;;
                "file:"*)
                    file=$(echo "$line" | cut -d: -f2)
                    backup_file "$file" "$BACKUP_PATH"
                    ;;
            esac
        done < "$PROFILE_DIR/$PROFILE_NAME.profile"
    else
        log_message "Profile not found: $PROFILE_NAME, using default"
        echo "Default backup profile used" > "$BACKUP_PATH/profile.txt"
        
        # Default backup: essential system files and KernelSU modules
        backup_directory "/data/adb/modules" "$BACKUP_PATH"
        backup_directory "/system/etc" "$BACKUP_PATH"
        backup_file "/system/build.prop" "$BACKUP_PATH"
        
        # Backup boot partition if accessible
        if [ -b "/dev/block/bootdevice/by-name/boot" ]; then
            backup_partition "boot" "$BACKUP_PATH"
        fi
    fi
    
    # Encrypt backup if enabled
    if check_encryption_enabled; then
        log_message "Encrypting backup"
        
        # Generate random encryption key
        ENCRYPTION_KEY=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32)
        
        # Create encrypted archive
        tar -czf "$BACKUP_PATH/backup_data.tar.gz" -C "$BACKUP_PATH" --exclude="*.tar.gz" --exclude="encrypted" .
        
        # Encrypt with openssl if available
        if command -v openssl >/dev/null 2>&1; then
            openssl enc -aes-256-cbc -salt -in "$BACKUP_PATH/backup_data.tar.gz" -out "$BACKUP_PATH/backup_encrypted.bin" -k "$ENCRYPTION_KEY"
            echo "$ENCRYPTION_KEY" | sha256sum | cut -d' ' -f1 > "$BACKUP_PATH/key_hash"
            rm "$BACKUP_PATH/backup_data.tar.gz"
        else
            # Fallback: simple XOR encryption
            "$MODDIR/scripts/backup-encryption.sh" encrypt "$BACKUP_PATH/backup_data.tar.gz" "$ENCRYPTION_KEY"
        fi
        
        touch "$BACKUP_PATH/encrypted"
        log_message "Backup encrypted successfully"
    fi
    
    log_message "Backup completed: $BACKUP_ID"
    return 0
}

# Restore from backup
restore_from_backup() {
    BACKUP_ID="$1"
    BACKUP_PATH="$BACKUP_DIR/$BACKUP_ID"
    
    log_message "Restoring from backup: $BACKUP_ID"
    
    # Check if backup exists
    if [ ! -d "$BACKUP_PATH" ]; then
        log_message "Backup not found: $BACKUP_ID"
        return 1
    fi
    
    # Check if backup is encrypted
    if [ -f "$BACKUP_PATH/encrypted" ]; then
        log_message "Decrypting backup"
        
        # Prompt for encryption key (in real implementation)
        read -p "Enter encryption key: " -s ENCRYPTION_KEY
        echo
        
        # Verify key hash
        if [ -f "$BACKUP_PATH/key_hash" ]; then
            PROVIDED_HASH=$(echo "$ENCRYPTION_KEY" | sha256sum | cut -d' ' -f1)
            STORED_HASH=$(cat "$BACKUP_PATH/key_hash")
            
            if [ "$PROVIDED_HASH" != "$STORED_HASH" ]; then
                log_message "Invalid encryption key"
                return 1
            fi
        fi
        
        # Decrypt backup
        if command -v openssl >/dev/null 2>&1 && [ -f "$BACKUP_PATH/backup_encrypted.bin" ]; then
            openssl enc -aes-256-cbc -d -in "$BACKUP_PATH/backup_encrypted.bin" -out "$BACKUP_PATH/backup_data.tar.gz" -k "$ENCRYPTION_KEY"
        else
            "$MODDIR/scripts/backup-encryption.sh" decrypt "$BACKUP_PATH/backup_data.tar.gz" "$ENCRYPTION_KEY"
        fi
        
        # Extract decrypted data
        tar -xzf "$BACKUP_PATH/backup_data.tar.gz" -C "$BACKUP_PATH"
        rm "$BACKUP_PATH/backup_data.tar.gz"
    fi
    
    # Restore backup data
    log_message "Restoring backup data"
    
    # Restore directories
    if [ -d "$BACKUP_PATH/data_adb_modules" ]; then
        cp -r "$BACKUP_PATH/data_adb_modules"/* "/data/adb/modules/" 2>/dev/null
        log_message "Restored KernelSU modules"
    fi
    
    # Restore system files (with caution)
    if [ -d "$BACKUP_PATH/system_etc" ]; then
        # Only restore non-critical files
        find "$BACKUP_PATH/system_etc" -name "*.conf" -exec cp {} "/system/etc/" \;
        log_message "Restored system configuration files"
    fi
    
    # Set proper permissions
    find "/data/adb/modules" -type f -exec chmod 644 {} \;
    find "/data/adb/modules" -type d -exec chmod 755 {} \;
    find "/data/adb/modules" -name "*.sh" -exec chmod 755 {} \;
    
    log_message "Restoration completed from: $BACKUP_ID"
    return 0
}

# List available backups
list_backups() {
    log_message "Listing available backups"
    
    # Check if backup directory exists
    if [ ! -d "$BACKUP_DIR" ]; then
        log_message "No backups found"
        return 1
    fi
    
    # List all backup directories
    for backup in "$BACKUP_DIR"/*; do
        if [ -d "$backup" ]; then
            BACKUP_ID=$(basename "$backup")
            echo "$BACKUP_ID"
        fi
    done
    
    return 0
}

# Main function - Command processor
main() {
    COMMAND="$1"
    PARAM="$2"
    
    case "$COMMAND" in
        "backup")
            create_backup "$PARAM"
            ;;
        "restore")
            restore_from_backup "$PARAM"
            ;;
        "list")
            list_backups
            ;;
        *)
            log_message "Unknown command: $COMMAND"
            echo "Usage: $0 backup|restore|list [profile_name|backup_id]"
            return 1
            ;;
    esac
}

# Execute main with all arguments
main "$@"