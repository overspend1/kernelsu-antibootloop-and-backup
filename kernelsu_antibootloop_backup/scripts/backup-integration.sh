#!/system/bin/sh
# KernelSU Anti-Bootloop Backup Integration Script
# Provides a unified interface to all backup components

MODDIR=${0%/*}
MODDIR=${MODDIR%/*}
CONFIG_DIR="$MODDIR/config"
LOGS_DIR="$CONFIG_DIR/logs"
API_VERSION="1.0"

# Ensure directories exist
mkdir -p "$CONFIG_DIR"
mkdir -p "$LOGS_DIR"

# Log function
log_message() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$LOGS_DIR/integration.log"
}

log_message "Backup integration started (API v$API_VERSION)"

# -----------------------------------------------
# COMPONENT PATH DEFINITIONS
# -----------------------------------------------

PARTITION_MANAGER="$MODDIR/scripts/partition-manager.sh"
DIFF_ENGINE="$MODDIR/scripts/diff-engine.sh"
ENCRYPTION="$MODDIR/scripts/backup-encryption.sh"
STORAGE_MANAGER="$MODDIR/scripts/storage-manager.sh"
SCHEDULER="$MODDIR/scripts/backup-scheduler.sh"
BACKUP_ENGINE="$MODDIR/scripts/backup-engine.sh"

# -----------------------------------------------
# INITIALIZATION
# -----------------------------------------------

# Initialize all components
initialize_all() {
    log_message "Initializing all backup components"
    
    # Initialize components in the correct order
    if [ -f "$PARTITION_MANAGER" ]; then
        log_message "Initializing partition manager"
        "$PARTITION_MANAGER" init
    else
        log_message "Error: Partition manager not found"
    fi
    
    if [ -f "$ENCRYPTION" ]; then
        log_message "Initializing encryption framework"
        "$ENCRYPTION" init
    else
        log_message "Error: Encryption framework not found"
    fi
    
    if [ -f "$STORAGE_MANAGER" ]; then
        log_message "Initializing storage manager"
        "$STORAGE_MANAGER" init
    else
        log_message "Error: Storage manager not found"
    fi
    
    if [ -f "$SCHEDULER" ]; then
        log_message "Initializing backup scheduler"
        "$SCHEDULER" init
    else
        log_message "Error: Backup scheduler not found"
    fi
    
    log_message "All components initialized"
    return 0
}

# Check if all components are available
check_components() {
    log_message "Checking component availability"
    
    MISSING=0
    
    for COMPONENT in "$PARTITION_MANAGER" "$DIFF_ENGINE" "$ENCRYPTION" "$STORAGE_MANAGER" "$SCHEDULER" "$BACKUP_ENGINE"; do
        if [ ! -f "$COMPONENT" ]; then
            log_message "Missing component: $COMPONENT"
            MISSING=$((MISSING + 1))
        fi
    done
    
    if [ "$MISSING" -eq 0 ]; then
        log_message "All components available"
        return 0
    else
        log_message "Missing $MISSING components"
        return 1
    fi
}

# -----------------------------------------------
# BACKUP OPERATIONS
# -----------------------------------------------

# Create a full system backup
create_full_backup() {
    DESCRIPTION="$1"
    ADAPTER="$2"
    ENCRYPT="$3"
    
    log_message "Creating full system backup"
    
    # Generate backup ID
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_ID="full_$TIMESTAMP"
    
    # Create backup directory
    BACKUP_DIR="$CONFIG_DIR/temp/$BACKUP_ID"
    mkdir -p "$BACKUP_DIR"
    
    # 1. Backup critical partitions
    log_message "Backing up critical partitions"
    if [ -f "$PARTITION_MANAGER" ]; then
        "$PARTITION_MANAGER" backup_critical
        PARTITION_BACKUP_ID=$?
        
        if [ "$PARTITION_BACKUP_ID" != "0" ]; then
            log_message "Partition backup created: $PARTITION_BACKUP_ID"
        else
            log_message "Error: Failed to create partition backup"
        fi
    fi
    
    # 2. Create backup metadata
    if [ -f "$STORAGE_MANAGER" ]; then
        "$STORAGE_MANAGER" create_metadata "$BACKUP_ID" "full" "${ADAPTER:-local}" "${DESCRIPTION:-Full system backup}"
    fi
    
    # 3. Create a backup of key system directories
    log_message "Backing up system directories"
    
    # Create temporary directory for system files
    mkdir -p "$BACKUP_DIR/system"
    
    # Backup important system directories (non-exhaustive example)
    for DIR in "/system/etc" "/system/priv-app" "/system/framework"; do
        if [ -d "$DIR" ]; then
            TARGET_DIR="$BACKUP_DIR/system$(echo $DIR | sed 's/\/system//')"
            mkdir -p "$(dirname "$TARGET_DIR")"
            cp -a "$DIR" "$TARGET_DIR" 2>/dev/null
        fi
    done
    
    # 4. Package the backup
    log_message "Packaging backup"
    BACKUP_PACKAGE="$CONFIG_DIR/temp/${BACKUP_ID}.tar"
    tar -cf "$BACKUP_PACKAGE" -C "$BACKUP_DIR" . 2>/dev/null
    
    # 5. Compress the backup using the diff engine
    if [ -f "$DIFF_ENGINE" ]; then
        log_message "Compressing backup"
        COMPRESSED_BACKUP="$CONFIG_DIR/temp/${BACKUP_ID}.backup"
        
        COMPRESSION_RESULT=$("$DIFF_ENGINE" best_compression "$BACKUP_PACKAGE" "$CONFIG_DIR/temp/${BACKUP_ID}")
        
        # Extract compression method and output file
        COMPRESSION_METHOD=$(echo "$COMPRESSION_RESULT" | cut -d: -f1)
        COMPRESSED_FILE=$(echo "$COMPRESSION_RESULT" | cut -d: -f2)
        
        log_message "Compression method: $COMPRESSION_METHOD"
        
        # Update metadata with compression info
        if [ -f "$STORAGE_MANAGER" ]; then
            "$STORAGE_MANAGER" update_metadata "$BACKUP_ID" "compression" "$COMPRESSION_METHOD" "${ADAPTER:-local}"
        fi
        
        # Use compressed file for further steps
        BACKUP_PACKAGE="$COMPRESSED_FILE"
    fi
    
    # 6. Encrypt the backup if requested
    if [ "$ENCRYPT" = "true" ] && [ -f "$ENCRYPTION" ]; then
        log_message "Encrypting backup"
        ENCRYPTED_BACKUP="$CONFIG_DIR/temp/${BACKUP_ID}.enc"
        
        "$ENCRYPTION" encrypt "$BACKUP_PACKAGE" "$ENCRYPTED_BACKUP"
        
        if [ $? -eq 0 ]; then
            log_message "Backup encrypted successfully"
            
            # Update metadata with encryption info
            if [ -f "$STORAGE_MANAGER" ]; then
                "$STORAGE_MANAGER" update_metadata "$BACKUP_ID" "encrypted" "true" "${ADAPTER:-local}"
            fi
            
            # Use encrypted file for storage
            BACKUP_PACKAGE="$ENCRYPTED_BACKUP"
        else
            log_message "Error: Backup encryption failed"
        fi
    fi
    
    # 7. Store the backup using storage manager
    if [ -f "$STORAGE_MANAGER" ]; then
        log_message "Storing backup"
        "$STORAGE_MANAGER" store "$BACKUP_PACKAGE" "$BACKUP_ID" "${ADAPTER:-local}"
        
        if [ $? -eq 0 ]; then
            log_message "Backup stored successfully"
            
            # Update metadata with completion info
            "$STORAGE_MANAGER" update_metadata "$BACKUP_ID" "status" "completed" "${ADAPTER:-local}"
        else
            log_message "Error: Failed to store backup"
            "$STORAGE_MANAGER" update_metadata "$BACKUP_ID" "status" "failed" "${ADAPTER:-local}"
        fi
    fi
    
    # 8. Clean up temporary files
    log_message "Cleaning up temporary files"
    rm -rf "$BACKUP_DIR"
    rm -f "$CONFIG_DIR/temp/${BACKUP_ID}.*"
    
    # 9. Create success notification
    if [ -f "$SCHEDULER" ]; then
        "$SCHEDULER" create_notification "Backup Completed" "Full system backup has been created successfully." "success"
    fi
    
    log_message "Full backup completed: $BACKUP_ID"
    echo "$BACKUP_ID"
    return 0
}

# Create an app backup
create_app_backup() {
    PACKAGE_LIST="$1"
    DESCRIPTION="$2"
    ADAPTER="$3"
    
    log_message "Creating app backup for packages: $PACKAGE_LIST"
    
    # Generate backup ID
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_ID="app_$TIMESTAMP"
    
    # Create backup directory
    BACKUP_DIR="$CONFIG_DIR/temp/$BACKUP_ID"
    mkdir -p "$BACKUP_DIR/apps"
    
    # 1. Create backup metadata
    if [ -f "$STORAGE_MANAGER" ]; then
        "$STORAGE_MANAGER" create_metadata "$BACKUP_ID" "app" "${ADAPTER:-local}" "${DESCRIPTION:-App backup}"
    fi
    
    # 2. Backup each package
    IFS=',' read -ra PACKAGES <<< "$PACKAGE_LIST"
    BACKUP_COUNT=0
    
    for PKG in "${PACKAGES[@]}"; do
        log_message "Backing up package: $PKG"
        
        # Get app path
        APP_PATH=""
        if command -v pm >/dev/null 2>&1; then
            APP_PATH=$(pm path "$PKG" 2>/dev/null | sed 's/package://')
        fi
        
        if [ -n "$APP_PATH" ] && [ -f "$APP_PATH" ]; then
            # Copy APK file
            cp "$APP_PATH" "$BACKUP_DIR/apps/$PKG.apk" 2>/dev/null
            
            # Backup app data if possible
            if [ -d "/data/data/$PKG" ]; then
                mkdir -p "$BACKUP_DIR/data/$PKG"
                cp -a "/data/data/$PKG" "$BACKUP_DIR/data/$PKG" 2>/dev/null
            fi
            
            BACKUP_COUNT=$((BACKUP_COUNT + 1))
        else
            log_message "Error: Could not find package $PKG"
        fi
    done
    
    # 3. Package the backup
    log_message "Packaging app backup"
    BACKUP_PACKAGE="$CONFIG_DIR/temp/${BACKUP_ID}.tar"
    tar -cf "$BACKUP_PACKAGE" -C "$BACKUP_DIR" . 2>/dev/null
    
    # 4. Compress and store using the same flow as full backup
    if [ -f "$DIFF_ENGINE" ]; then
        log_message "Compressing app backup"
        COMPRESSED_BACKUP="$CONFIG_DIR/temp/${BACKUP_ID}.backup"
        
        COMPRESSION_RESULT=$("$DIFF_ENGINE" best_compression "$BACKUP_PACKAGE" "$CONFIG_DIR/temp/${BACKUP_ID}")
        
        # Extract compression method and output file
        COMPRESSION_METHOD=$(echo "$COMPRESSION_RESULT" | cut -d: -f1)
        COMPRESSED_FILE=$(echo "$COMPRESSION_RESULT" | cut -d: -f2)
        
        log_message "Compression method: $COMPRESSION_METHOD"
        
        # Update metadata with compression info
        if [ -f "$STORAGE_MANAGER" ]; then
            "$STORAGE_MANAGER" update_metadata "$BACKUP_ID" "compression" "$COMPRESSION_METHOD" "${ADAPTER:-local}"
            "$STORAGE_MANAGER" update_metadata "$BACKUP_ID" "app_count" "$BACKUP_COUNT" "${ADAPTER:-local}"
        fi
        
        # Use compressed file for storage
        BACKUP_PACKAGE="$COMPRESSED_FILE"
    fi
    
    # 5. Store the backup
    if [ -f "$STORAGE_MANAGER" ]; then
        log_message "Storing app backup"
        "$STORAGE_MANAGER" store "$BACKUP_PACKAGE" "$BACKUP_ID" "${ADAPTER:-local}"
        
        if [ $? -eq 0 ]; then
            log_message "App backup stored successfully"
            
            # Update metadata with completion info
            "$STORAGE_MANAGER" update_metadata "$BACKUP_ID" "status" "completed" "${ADAPTER:-local}"
        else
            log_message "Error: Failed to store app backup"
            "$STORAGE_MANAGER" update_metadata "$BACKUP_ID" "status" "failed" "${ADAPTER:-local}"
        fi
    fi
    
    # 6. Clean up temporary files
    log_message "Cleaning up temporary files"
    rm -rf "$BACKUP_DIR"
    rm -f "$CONFIG_DIR/temp/${BACKUP_ID}.*"
    
    # 7. Create success notification
    if [ -f "$SCHEDULER" ]; then
        "$SCHEDULER" create_notification "App Backup Completed" "Backed up $BACKUP_COUNT applications." "success"
    fi
    
    log_message "App backup completed: $BACKUP_ID"
    echo "$BACKUP_ID"
    return 0
}

# Create a settings backup
create_settings_backup() {
    DESCRIPTION="$1"
    ADAPTER="$2"
    
    log_message "Creating settings backup"
    
    # Generate backup ID
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_ID="settings_$TIMESTAMP"
    
    # Create backup directory
    BACKUP_DIR="$CONFIG_DIR/temp/$BACKUP_ID"
    mkdir -p "$BACKUP_DIR/settings"
    
    # 1. Create backup metadata
    if [ -f "$STORAGE_MANAGER" ]; then
        "$STORAGE_MANAGER" create_metadata "$BACKUP_ID" "settings" "${ADAPTER:-local}" "${DESCRIPTION:-Settings backup}"
    fi
    
    # 2. Backup Android settings
    log_message "Backing up Android settings"
    
    # Get list of settings
    if command -v settings >/dev/null 2>&1; then
        # System settings
        settings list system > "$BACKUP_DIR/settings/system.txt" 2>/dev/null
        
        # Secure settings
        settings list secure > "$BACKUP_DIR/settings/secure.txt" 2>/dev/null
        
        # Global settings
        settings list global > "$BACKUP_DIR/settings/global.txt" 2>/dev/null
    fi
    
    # 3. Backup other configuration files
    log_message "Backing up configuration files"
    
    # APN settings
    if [ -f "/data/data/com.android.providers.telephony/databases/telephony.db" ]; then
        mkdir -p "$BACKUP_DIR/settings/apn"
        cp "/data/data/com.android.providers.telephony/databases/telephony.db" "$BACKUP_DIR/settings/apn/" 2>/dev/null
    fi
    
    # Wi-Fi configurations
    if [ -f "/data/misc/wifi/wpa_supplicant.conf" ]; then
        mkdir -p "$BACKUP_DIR/settings/wifi"
        cp "/data/misc/wifi/wpa_supplicant.conf" "$BACKUP_DIR/settings/wifi/" 2>/dev/null
    fi
    
    # 4. Package and store the backup (similar to other backup types)
    log_message "Packaging settings backup"
    BACKUP_PACKAGE="$CONFIG_DIR/temp/${BACKUP_ID}.tar"
    tar -cf "$BACKUP_PACKAGE" -C "$BACKUP_DIR" . 2>/dev/null
    
    # Follow the same compression and storage pattern as other backup types
    if [ -f "$DIFF_ENGINE" ]; then
        log_message "Compressing settings backup"
        COMPRESSION_RESULT=$("$DIFF_ENGINE" best_compression "$BACKUP_PACKAGE" "$CONFIG_DIR/temp/${BACKUP_ID}")
        
        # Extract compression method and output file
        COMPRESSION_METHOD=$(echo "$COMPRESSION_RESULT" | cut -d: -f1)
        COMPRESSED_FILE=$(echo "$COMPRESSION_RESULT" | cut -d: -f2)
        
        # Update metadata with compression info
        if [ -f "$STORAGE_MANAGER" ]; then
            "$STORAGE_MANAGER" update_metadata "$BACKUP_ID" "compression" "$COMPRESSION_METHOD" "${ADAPTER:-local}"
        fi
        
        # Use compressed file for storage
        BACKUP_PACKAGE="$COMPRESSED_FILE"
    fi
    
    # Store the backup
    if [ -f "$STORAGE_MANAGER" ]; then
        log_message "Storing settings backup"
        "$STORAGE_MANAGER" store "$BACKUP_PACKAGE" "$BACKUP_ID" "${ADAPTER:-local}"
        
        if [ $? -eq 0 ]; then
            log_message "Settings backup stored successfully"
            "$STORAGE_MANAGER" update_metadata "$BACKUP_ID" "status" "completed" "${ADAPTER:-local}"
        else
            log_message "Error: Failed to store settings backup"
            "$STORAGE_MANAGER" update_metadata "$BACKUP_ID" "status" "failed" "${ADAPTER:-local}"
        fi
    fi
    
    # Clean up temporary files
    rm -rf "$BACKUP_DIR"
    rm -f "$CONFIG_DIR/temp/${BACKUP_ID}.*"
    
    log_message "Settings backup completed: $BACKUP_ID"
    echo "$BACKUP_ID"
    return 0
}

# -----------------------------------------------
# RESTORE OPERATIONS
# -----------------------------------------------

# Restore from backup
restore_backup() {
    BACKUP_ID="$1"
    COMPONENTS="$2"  # comma-separated list of components to restore
    
    log_message "Restoring from backup: $BACKUP_ID"
    
    # 1. Prepare for restoration using storage manager
    if [ -f "$STORAGE_MANAGER" ]; then
        log_message "Preparing for restoration"
        RESTORE_DIR=$("$STORAGE_MANAGER" prepare_restore "$BACKUP_ID")
        
        if [ -z "$RESTORE_DIR" ] || [ ! -d "$RESTORE_DIR" ]; then
            log_message "Error: Failed to prepare for restoration"
            return 1
        fi
    else
        log_message "Error: Storage manager not found"
        return 1
    fi
    
    # 2. Run verification phase
    log_message "Verifying backup integrity"
    if [ -f "$STORAGE_MANAGER" ]; then
        "$STORAGE_MANAGER" restore "$RESTORE_DIR" "verify"
        
        if [ $? -ne 0 ]; then
            log_message "Error: Backup verification failed"
            return 1
        fi
    fi
    
    # 3. Run pre-restore phase
    log_message "Running pre-restore tasks"
    if [ -f "$STORAGE_MANAGER" ]; then
        "$STORAGE_MANAGER" restore "$RESTORE_DIR" "pre_restore"
        
        if [ $? -ne 0 ]; then
            log_message "Error: Pre-restore tasks failed"
            return 1
        fi
    fi
    
    # 4. Get backup type from metadata
    BACKUP_TYPE=$(cat "$RESTORE_DIR/backup_type" 2>/dev/null)
    
    # 5. Run component-specific restore
    if [ -z "$COMPONENTS" ]; then
        # If no specific components, restore everything
        log_message "Restoring all components for $BACKUP_TYPE backup"
        if [ -f "$STORAGE_MANAGER" ]; then
            "$STORAGE_MANAGER" restore "$RESTORE_DIR" "restore"
            RESTORE_STATUS=$?
        fi
    else
        # Restore specific components
        log_message "Restoring selected components: $COMPONENTS"
        
        IFS=',' read -ra COMPONENT_ARRAY <<< "$COMPONENTS"
        RESTORE_STATUS=0
        
        for COMPONENT in "${COMPONENT_ARRAY[@]}"; do
            log_message "Restoring component: $COMPONENT"
            
            # Add component-specific restore logic here
            case "$COMPONENT" in
                "system")
                    # Restore system files
                    log_message "Restoring system component"
                    if [ -f "$STORAGE_MANAGER" ]; then
                        "$STORAGE_MANAGER" restore "$RESTORE_DIR" "restore" "system"
                        if [ $? -ne 0 ]; then
                            RESTORE_STATUS=1
                        fi
                    fi
                    ;;
                "apps")
                    # Restore applications
                    log_message "Restoring apps component"
                    if [ -f "$STORAGE_MANAGER" ]; then
                        "$STORAGE_MANAGER" restore "$RESTORE_DIR" "restore" "app"
                        if [ $? -ne 0 ]; then
                            RESTORE_STATUS=1
                        fi
                    fi
                    ;;
                "settings")
                    # Restore settings
                    log_message "Restoring settings component"
                    if [ -f "$STORAGE_MANAGER" ]; then
                        "$STORAGE_MANAGER" restore "$RESTORE_DIR" "restore" "settings"
                        if [ $? -ne 0 ]; then
                            RESTORE_STATUS=1
                        fi
                    fi
                    ;;
                "boot")
                    # Restore boot partition
                    log_message "Restoring boot component"
                    if [ -f "$STORAGE_MANAGER" ]; then
                        "$STORAGE_MANAGER" restore "$RESTORE_DIR" "restore" "boot"
                        if [ $? -ne 0 ]; then
                            RESTORE_STATUS=1
                        fi
                    fi
                    ;;
                *)
                    log_message "Unknown component: $COMPONENT"
                    ;;
            esac
        done
    fi
    
    # 6. Run post-restore phase
    log_message "Running post-restore tasks"
    if [ -f "$STORAGE_MANAGER" ]; then
        "$STORAGE_MANAGER" restore "$RESTORE_DIR" "post_restore"
    fi
    
    # 7. Clean up
    log_message "Cleaning up restoration files"
    if [ -f "$STORAGE_MANAGER" ]; then
        "$STORAGE_MANAGER" restore "$RESTORE_DIR" "cleanup"
    fi
    
    # 8. Create notification about restoration
    if [ -f "$SCHEDULER" ]; then
        if [ "$RESTORE_STATUS" -eq 0 ]; then
            "$SCHEDULER" create_notification "Restore Completed" "Backup $BACKUP_ID has been restored successfully." "success"
        else
            "$SCHEDULER" create_notification "Restore Partially Failed" "Some components failed during restoration of $BACKUP_ID." "warning"
        fi
    fi
    
    log_message "Restoration completed with status: $RESTORE_STATUS"
    return $RESTORE_STATUS
}

# -----------------------------------------------
# MANAGEMENT OPERATIONS
# -----------------------------------------------

# List all backups
list_backups() {
    log_message "Listing all backups"
    
    if [ -f "$STORAGE_MANAGER" ]; then
        "$STORAGE_MANAGER" list_backups
        return $?
    else
        log_message "Error: Storage manager not found"
        return 1
    fi
}

# Get backup details
get_backup_details() {
    BACKUP_ID="$1"
    
    log_message "Getting details for backup: $BACKUP_ID"
    
    if [ -f "$STORAGE_MANAGER" ]; then
        # Get basic metadata
        TYPE=$("$STORAGE_MANAGER" get_metadata "$BACKUP_ID" "type")
        CREATED=$("$STORAGE_MANAGER" get_metadata "$BACKUP_ID" "created")
        ADAPTER=$("$STORAGE_MANAGER" get_metadata "$BACKUP_ID" "adapter")
        DESCRIPTION=$("$STORAGE_MANAGER" get_metadata "$BACKUP_ID" "description")
        STATUS=$("$STORAGE_MANAGER" get_metadata "$BACKUP_ID" "status")
        
        # Output in JSON format
        cat << EOF
{
  "backup_id": "$BACKUP_ID",
  "type": "$TYPE",
  "created": "$CREATED",
  "adapter": "$ADAPTER",
  "description": "$DESCRIPTION",
  "status": "$STATUS"
}
EOF
        return 0
    else
        log_message "Error: Storage manager not found"
        return 1
    fi
}

# Delete a backup
delete_backup() {
    BACKUP_ID="$1"
    
    log_message "Deleting backup: $BACKUP_ID"
    
    if [ -f "$STORAGE_MANAGER" ]; then
        "$STORAGE_MANAGER" delete "$BACKUP_ID"
        
        if [ $? -eq 0 ]; then
            log_message "Backup deleted successfully: $BACKUP_ID"
            return 0
        else
            log_message "Error: Failed to delete backup: $BACKUP_ID"
            return 1
        fi
    else
        log_message "Error: Storage manager not found"
        return 1
    fi
}

# -----------------------------------------------
# SCHEDULE MANAGEMENT
# -----------------------------------------------

# List all schedules
list_schedules() {
    log_message "Listing all backup schedules"
    
    if [ -f "$SCHEDULER" ]; then
        "$SCHEDULER" list_schedules
        return $?
    else
        log_message "Error: Scheduler not found"
        return 1
    fi
}

# Create a new schedule
create_schedule() {
    NAME="$1"
    FREQUENCY="$2"
    PROFILE="$3"
    
    log_message "Creating backup schedule: $NAME, frequency: $FREQUENCY, profile: $PROFILE"
    
    if [ -f "$SCHEDULER" ]; then
        "$SCHEDULER" create_schedule "$NAME" "$FREQUENCY" "$PROFILE"
        
        if [ $? -eq 0 ]; then
            log_message "Schedule created successfully: $NAME"
            return 0
        else
            log_message "Error: Failed to create schedule: $NAME"
            return 1
        fi
    else
        log_message "Error: Scheduler not found"
        return 1
    fi
}

# Check and run due schedules
check_schedules() {
    TYPE="$1"  # 'time' or 'boot'
    
    log_message "Checking schedules of type: $TYPE"
    
    if [ -f "$SCHEDULER" ]; then
        "$SCHEDULER" check_schedules "$TYPE"
        return $?
    else
        log_message "Error: Scheduler not found"
        return 1
    fi
}

# -----------------------------------------------
# MAIN FUNCTION
# -----------------------------------------------

# Display help information
show_help() {
    cat << EOF
KernelSU Anti-Bootloop Backup System (API v$API_VERSION)
Usage: $0 [command] [options]

Commands:
  init                     Initialize all backup components
  backup-full [desc] [adapter] [encrypt]  Create a full system backup
  backup-app [pkgs] [desc] [adapter]      Create an app backup
  backup-settings [desc] [adapter]        Create a settings backup
  restore [backup_id] [components]        Restore from a backup
  list-backups                           List all backups
  backup-details [backup_id]             Get details for a backup
  delete-backup [backup_id]              Delete a backup
  list-schedules                         List all backup schedules
  create-schedule [name] [freq] [profile] Create a backup schedule
  check-schedules [type]                 Check and run due schedules

For more information, refer to the documentation.
EOF
}

# Main function - Command processor
main() {
    COMMAND="$1"
    shift
    
    case "$COMMAND" in
        "init")
            initialize_all
            ;;
        "check")
            check_components
            ;;
        "backup-full")
            create_full_backup "$1" "$2" "$3"
            ;;
        "backup-app")
            create_app_backup "$1" "$2" "$3"
            ;;
        "backup-settings")
            create_settings_backup "$1" "$2"
            ;;
        "restore")
            restore_backup "$1" "$2"
            ;;
        "list-backups")
            list_backups
            ;;
        "backup-details")
            get_backup_details "$1"
            ;;
        "delete-backup")
            delete_backup "$1"
            ;;
        "list-schedules")
            list_schedules
            ;;
        "create-schedule")
            create_schedule "$1" "$2" "$3"
            ;;
        "check-schedules")
            check_schedules "$1"
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            log_message "Unknown command: $COMMAND"
            show_help
            return 1
            ;;
    esac
}

# Execute main with all arguments
main "$@"