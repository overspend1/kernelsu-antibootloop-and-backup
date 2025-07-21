#!/system/bin/sh
# KernelSU Anti-Bootloop Backup Engine Script

MODDIR=${0%/*}
MODDIR=${MODDIR%/*}
CONFIG_DIR="$MODDIR/config"
BACKUP_DIR="$CONFIG_DIR/backups"
TEMPLATE_DIR="$MODDIR/templates"
PROFILE_DIR="$CONFIG_DIR/backup_profiles"
TEMP_DIR="$CONFIG_DIR/temp"
STATE_DIR="$CONFIG_DIR/backup_state"

# Ensure backup directories exist
mkdir -p "$BACKUP_DIR"
mkdir -p "$PROFILE_DIR"
mkdir -p "$TEMP_DIR"
mkdir -p "$STATE_DIR"

# Advanced backup configuration
MAX_BACKUP_SIZE=2048  # MB
COMPRESSION_LEVEL=6
PARALLEL_JOBS=2
HASH_ALGORITHM="sha256"
BACKUP_VERSION="2.0"

# Enhanced logging with levels
log_message() {
    local level="${2:-INFO}"
    local timestamp="$(date +"%Y-%m-%d %H:%M:%S")"
    echo "[$timestamp] [$level] $1" >> "$CONFIG_DIR/backup_engine.log"
    
    # Also output to stderr for errors
    if [ "$level" = "ERROR" ]; then
        echo "[$timestamp] [$level] $1" >&2
    fi
}

# Progress tracking
update_progress() {
    local current="$1"
    local total="$2"
    local operation="$3"
    local percent=$((current * 100 / total))
    echo "$percent|$operation" > "$TEMP_DIR/backup_progress"
    log_message "Progress: $percent% - $operation" "INFO"
}

log_message "Advanced backup engine started v$BACKUP_VERSION" "INFO"

# Enhanced configuration loading
load_backup_config() {
    local config_file="$CONFIG_DIR/settings.json"
    
    if [ -f "$config_file" ]; then
        # Extract settings using grep/sed for shell compatibility
        ENCRYPTION_ENABLED=$(grep -o '"backupEncryption":\s*[^,}]*' "$config_file" | sed 's/.*://g' | tr -d ' "' || echo "false")
        COMPRESSION_ENABLED=$(grep -o '"backupCompression":\s*[^,}]*' "$config_file" | sed 's/.*://g' | tr -d ' "' || echo "true")
        AUTO_BACKUP=$(grep -o '"autoBackup":\s*[^,}]*' "$config_file" | sed 's/.*://g' | tr -d ' "' || echo "false")
        STORAGE_PATH=$(grep -o '"storagePath":\s*"[^"]*"' "$config_file" | sed 's/.*"\([^"]*\)".*/\1/' || echo "$BACKUP_DIR")
        
        # Override backup directory if specified
        if [ "$STORAGE_PATH" != "$BACKUP_DIR" ] && [ -n "$STORAGE_PATH" ]; then
            BACKUP_DIR="$STORAGE_PATH"
            mkdir -p "$BACKUP_DIR"
        fi
        
        log_message "Configuration loaded: encryption=$ENCRYPTION_ENABLED, compression=$COMPRESSION_ENABLED" "INFO"
    else
        # Default settings
        ENCRYPTION_ENABLED="false"
        COMPRESSION_ENABLED="true"
        AUTO_BACKUP="false"
        STORAGE_PATH="$BACKUP_DIR"
        log_message "Using default configuration" "WARN"
    fi
}

# Check available disk space
check_disk_space() {
    local required_mb="$1"
    local available=$(df "$BACKUP_DIR" | tail -1 | awk '{print int($4/1024)}')
    
    if [ "$available" -lt "$required_mb" ]; then
        log_message "Insufficient disk space: ${available}MB available, ${required_mb}MB required" "ERROR"
        return 1
    fi
    
    log_message "Disk space check passed: ${available}MB available" "INFO"
    return 0
}

# Generate file hash for integrity checking
generate_hash() {
    local file_path="$1"
    local hash_file="$2"
    
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file_path" | cut -d' ' -f1 > "$hash_file"
    elif command -v md5sum >/dev/null 2>&1; then
        md5sum "$file_path" | cut -d' ' -f1 > "$hash_file"
    else
        # Fallback: file size and timestamp
        stat "$file_path" | grep -E '(Size:|Modify:)' > "$hash_file"
    fi
}

# Verify file integrity
verify_integrity() {
    local file_path="$1"
    local hash_file="$2"
    
    if [ ! -f "$hash_file" ]; then
        log_message "Hash file not found for integrity check: $hash_file" "WARN"
        return 1
    fi
    
    local temp_hash="$TEMP_DIR/verify.hash"
    generate_hash "$file_path" "$temp_hash"
    
    if cmp -s "$hash_file" "$temp_hash"; then
        rm "$temp_hash"
        return 0
    else
        rm "$temp_hash"
        log_message "Integrity check failed for: $file_path" "ERROR"
        return 1
    fi
}"

# Enhanced partition backup with compression and verification
backup_partition() {
    local partition="$1"
    local backup_path="$2"
    local incremental="$3"
    
    local partition_device="/dev/block/bootdevice/by-name/$partition"
    if [ ! -b "$partition_device" ]; then
        log_message "Partition device $partition_device not found" "WARN"
        return 1
    fi
    
    log_message "Backing up partition: $partition" "INFO"
    update_progress 0 1 "Backing up $partition partition"
    
    local output_file="$backup_path/${partition}.img"
    local temp_file="$TEMP_DIR/${partition}_temp.img"
    
    # Check for previous backup for incremental
    if [ "$incremental" = "true" ] && [ -f "$STATE_DIR/${partition}_state" ]; then
        local last_hash=$(cat "$STATE_DIR/${partition}_state" 2>/dev/null)
        local current_hash=$(dd if="$partition_device" bs=1M count=1 2>/dev/null | sha256sum | cut -d' ' -f1)
        
        if [ "$last_hash" = "$current_hash" ]; then
            log_message "Partition $partition unchanged, skipping" "INFO"
            return 0
        fi
    fi
    
    # Create partition backup
    if dd if="$partition_device" of="$temp_file" bs=1M status=progress 2>/dev/null; then
        # Compress if enabled
        if [ "$COMPRESSION_ENABLED" = "true" ] && command -v gzip >/dev/null 2>&1; then
            log_message "Compressing $partition partition backup" "INFO"
            gzip -"$COMPRESSION_LEVEL" "$temp_file"
            mv "${temp_file}.gz" "${output_file}.gz"
            output_file="${output_file}.gz"
        else
            mv "$temp_file" "$output_file"
        fi
        
        # Generate integrity hash
        generate_hash "$output_file" "${output_file}.hash"
        
        # Update state for incremental backups
        if [ "$incremental" = "true" ]; then
            echo "$current_hash" > "$STATE_DIR/${partition}_state"
        fi
        
        log_message "Successfully backed up $partition partition" "INFO"
        return 0
    else
        log_message "Failed to backup $partition partition" "ERROR"
        rm -f "$temp_file" 2>/dev/null
        return 1
    fi
}

# Enhanced directory backup with incremental support and compression
backup_directory() {
    local source_dir="$1"
    local backup_path="$2"
    local incremental="$3"
    
    if [ ! -d "$source_dir" ]; then
        log_message "Directory $source_dir not found" "WARN"
        return 1
    fi
    
    log_message "Backing up directory: $source_dir" "INFO"
    update_progress 0 1 "Backing up directory $source_dir"
    
    local dest_name=$(echo "$source_dir" | sed 's|/|_|g' | sed 's|^_||')
    local output_dir="$backup_path/$dest_name"
    local temp_dir="$TEMP_DIR/${dest_name}_temp"
    local archive_file="$backup_path/${dest_name}.tar"
    
    # Create temporary directory
    mkdir -p "$temp_dir"
    
    local files_copied=0
    local files_total=$(find "$source_dir" -type f | wc -l)
    
    if [ "$incremental" = "true" ] && [ -f "$STATE_DIR/${dest_name}_filelist" ]; then
        # Incremental backup: only backup changed/new files
        log_message "Performing incremental backup of $source_dir" "INFO"
        
        find "$source_dir" -type f -exec stat -c '%n %Y %s' {} \; | sort > "$TEMP_DIR/current_filelist"
        
        if ! cmp -s "$STATE_DIR/${dest_name}_filelist" "$TEMP_DIR/current_filelist"; then
            # Files have changed
            while IFS= read -r file_info; do
                local file_path=$(echo "$file_info" | cut -d' ' -f1)
                local rel_path=${file_path#$source_dir/}
                local dest_file="$temp_dir/$rel_path"
                
                mkdir -p "$(dirname "$dest_file")"
                if cp "$file_path" "$dest_file" 2>/dev/null; then
                    files_copied=$((files_copied + 1))
                    update_progress $files_copied $files_total "Copying files ($files_copied/$files_total)"
                fi
            done < <(comm -13 "$STATE_DIR/${dest_name}_filelist" "$TEMP_DIR/current_filelist" | cut -d' ' -f1)
            
            # Update state file
            mv "$TEMP_DIR/current_filelist" "$STATE_DIR/${dest_name}_filelist"
        else
            log_message "Directory $source_dir unchanged, skipping" "INFO"
            rm -rf "$temp_dir"
            return 0
        fi
    else
        # Full backup
        log_message "Performing full backup of $source_dir" "INFO"
        
        # Use tar with progress for better handling of large directories
        if tar -cf "$archive_file" -C "$source_dir" . 2>/dev/null; then
            files_copied=$files_total
        else
            log_message "Failed to create tar archive for $source_dir" "ERROR"
            return 1
        fi
        
        # Create state file for future incremental backups
        find "$source_dir" -type f -exec stat -c '%n %Y %s' {} \; | sort > "$STATE_DIR/${dest_name}_filelist"
    fi
    
    # Compress if enabled and we have files to compress
    if [ $files_copied -gt 0 ] && [ "$COMPRESSION_ENABLED" = "true" ] && command -v gzip >/dev/null 2>&1; then
        if [ -f "$archive_file" ]; then
            log_message "Compressing directory backup" "INFO"
            gzip -"$COMPRESSION_LEVEL" "$archive_file"
            archive_file="${archive_file}.gz"
        elif [ -d "$temp_dir" ] && [ "$(find "$temp_dir" -type f | wc -l)" -gt 0 ]; then
            tar -czf "${archive_file}.gz" -C "$temp_dir" . 2>/dev/null
            archive_file="${archive_file}.gz"
        fi
    fi
    
    # Generate integrity hash
    if [ -f "$archive_file" ]; then
        generate_hash "$archive_file" "${archive_file}.hash"
        log_message "Successfully backed up directory $source_dir ($files_copied files)" "INFO"
    elif [ -d "$temp_dir" ]; then
        # Move temp directory to final location if no archive was created
        rm -rf "$output_dir" 2>/dev/null
        mv "$temp_dir" "$output_dir"
        log_message "Successfully backed up directory $source_dir ($files_copied files)" "INFO"
    fi
    
    # Cleanup
    rm -rf "$temp_dir" 2>/dev/null
    
    return 0
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

# Enhanced backup creation with advanced features
create_backup() {
    local PROFILE_NAME="$1"
    local BACKUP_NAME="${2:-$PROFILE_NAME}"
    local BACKUP_DESCRIPTION="${3:-Automated backup}"
    local INCREMENTAL="${4:-false}"
    
    # Load configuration
    load_backup_config
    
    local TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    local BACKUP_ID="${BACKUP_NAME}_${TIMESTAMP}"
    local BACKUP_PATH="$BACKUP_DIR/$BACKUP_ID"
    
    log_message "Creating backup: $BACKUP_ID (profile: $PROFILE_NAME, incremental: $INCREMENTAL)" "INFO"
    
    # Check disk space (estimate 500MB minimum)
    if ! check_disk_space 500; then
        log_message "Backup aborted due to insufficient disk space" "ERROR"
        return 1
    fi
    
    # Create backup directory
    mkdir -p "$BACKUP_PATH"
    
    # Initialize progress
    update_progress 0 100 "Initializing backup"
    
    # Create enhanced backup metadata
    cat > "$BACKUP_PATH/metadata.json" << EOF
{
    "backupId": "$BACKUP_ID",
    "backupName": "$BACKUP_NAME",
    "profileName": "$PROFILE_NAME",
    "description": "$BACKUP_DESCRIPTION",
    "created": "$(date -Iseconds)",
    "timestamp": $TIMESTAMP,
    "incremental": $INCREMENTAL,
    "version": "$BACKUP_VERSION",
    "compression": $COMPRESSION_ENABLED,
    "encryption": $ENCRYPTION_ENABLED,
    "systemInfo": {
        "device": "$(getprop ro.product.model 2>/dev/null || echo 'Unknown')",
        "android": "$(getprop ro.build.version.release 2>/dev/null || echo 'Unknown')",
        "kernel": "$(uname -r)"
    },
    "items": []
}
EOF

    # Legacy metadata for compatibility
    echo "Backup ID: $BACKUP_ID" > "$BACKUP_PATH/metadata.txt"
    echo "Created: $(date)" >> "$BACKUP_PATH/metadata.txt"
    echo "Profile: $PROFILE_NAME" >> "$BACKUP_PATH/metadata.txt"
    echo "Description: $BACKUP_DESCRIPTION" >> "$BACKUP_PATH/metadata.txt"
    echo "Incremental: $INCREMENTAL" >> "$BACKUP_PATH/metadata.txt"
    
    local backup_items=0
    local backup_success=0
    local total_items=0
    
    # Check if profile exists and count items
    if [ -f "$PROFILE_DIR/$PROFILE_NAME.profile" ]; then
        log_message "Using profile: $PROFILE_NAME" "INFO"
        
        # Copy profile to backup for reference
        cp "$PROFILE_DIR/$PROFILE_NAME.profile" "$BACKUP_PATH/profile.txt"
        
        # Count total items for progress tracking
        total_items=$(grep -E "^(partition:|directory:|file:)" "$PROFILE_DIR/$PROFILE_NAME.profile" | wc -l)
        
        update_progress 10 100 "Processing backup profile ($total_items items)"
        
        # Parse profile and backup specified items
        while IFS= read -r line; do
            [ -z "$line" ] || [ "${line#\#}" != "$line" ] && continue
            
            backup_items=$((backup_items + 1))
            local progress=$((10 + (backup_items * 80 / total_items)))
            
            case "$line" in
                "partition:"*)
                    partition=$(echo "$line" | cut -d: -f2 | tr -d ' ')
                    update_progress $progress 100 "Backing up partition: $partition"
                    if backup_partition "$partition" "$BACKUP_PATH" "$INCREMENTAL"; then
                        backup_success=$((backup_success + 1))
                    fi
                    ;;
                "directory:"*)
                    dir=$(echo "$line" | cut -d: -f2 | tr -d ' ')
                    update_progress $progress 100 "Backing up directory: $dir"
                    if backup_directory "$dir" "$BACKUP_PATH" "$INCREMENTAL"; then
                        backup_success=$((backup_success + 1))
                    fi
                    ;;
                "file:"*)
                    file=$(echo "$line" | cut -d: -f2 | tr -d ' ')
                    update_progress $progress 100 "Backing up file: $file"
                    if backup_file "$file" "$BACKUP_PATH"; then
                        backup_success=$((backup_success + 1))
                    fi
                    ;;
            esac
        done < "$PROFILE_DIR/$PROFILE_NAME.profile"
    else
        log_message "Profile not found: $PROFILE_NAME, using default" "WARN"
        echo "Default backup profile used" > "$BACKUP_PATH/profile.txt"
        
        # Default backup: essential system files and KernelSU modules
        total_items=4
        update_progress 10 100 "Using default backup profile ($total_items items)"
        
        update_progress 30 100 "Backing up KernelSU modules"
        if backup_directory "/data/adb/modules" "$BACKUP_PATH" "$INCREMENTAL"; then
            backup_success=$((backup_success + 1))
        fi
        backup_items=$((backup_items + 1))
        
        update_progress 50 100 "Backing up system configuration"
        if backup_directory "/system/etc" "$BACKUP_PATH" "$INCREMENTAL"; then
            backup_success=$((backup_success + 1))
        fi
        backup_items=$((backup_items + 1))
        
        update_progress 70 100 "Backing up build properties"
        if backup_file "/system/build.prop" "$BACKUP_PATH"; then
            backup_success=$((backup_success + 1))
        fi
        backup_items=$((backup_items + 1))
        
        # Backup boot partition if accessible
        if [ -b "/dev/block/bootdevice/by-name/boot" ]; then
            update_progress 80 100 "Backing up boot partition"
            if backup_partition "boot" "$BACKUP_PATH" "$INCREMENTAL"; then
                backup_success=$((backup_success + 1))
            fi
            backup_items=$((backup_items + 1))
        fi
    fi
    
    update_progress 90 100 "Finalizing backup"
    
    # Update metadata with results
    echo "Items processed: $backup_items" >> "$BACKUP_PATH/metadata.txt"
    echo "Items successful: $backup_success" >> "$BACKUP_PATH/metadata.txt"
    echo "Success rate: $((backup_success * 100 / backup_items))%" >> "$BACKUP_PATH/metadata.txt"
    
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