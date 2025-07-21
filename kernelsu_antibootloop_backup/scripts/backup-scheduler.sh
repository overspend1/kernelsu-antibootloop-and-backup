#!/system/bin/sh
# KernelSU Anti-Bootloop Backup Scheduling and Automation
# Handles automated backup scheduling, policies, retention, and notifications

MODDIR=${0%/*}
MODDIR=${MODDIR%/*}
CONFIG_DIR="$MODDIR/config"
SCHEDULE_DIR="$CONFIG_DIR/schedules"
POLICY_DIR="$CONFIG_DIR/policies"
NOTIFICATION_DIR="$CONFIG_DIR/notifications"

# Ensure directories exist
mkdir -p "$SCHEDULE_DIR"
mkdir -p "$POLICY_DIR"
mkdir -p "$NOTIFICATION_DIR"

# Log function
log_message() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$CONFIG_DIR/scheduler.log"
}

log_message "Backup scheduler started"

# -----------------------------------------------
# AUTOMATED BACKUP SCHEDULING
# -----------------------------------------------

# List all scheduled backups
list_schedules() {
    log_message "Listing scheduled backups"
    
    if [ ! -d "$SCHEDULE_DIR" ]; then
        log_message "No schedules directory found"
        return 1
    fi
    
    for SCHEDULE_FILE in "$SCHEDULE_DIR"/*.schedule; do
        if [ -f "$SCHEDULE_FILE" ]; then
            SCHEDULE_NAME=$(basename "$SCHEDULE_FILE" .schedule)
            
            # Extract schedule information
            FREQUENCY=$(grep "^FREQUENCY=" "$SCHEDULE_FILE" | cut -d= -f2)
            PROFILE=$(grep "^PROFILE=" "$SCHEDULE_FILE" | cut -d= -f2)
            NEXT_RUN=$(grep "^NEXT_RUN=" "$SCHEDULE_FILE" | cut -d= -f2)
            ENABLED=$(grep "^ENABLED=" "$SCHEDULE_FILE" | cut -d= -f2)
            
            echo "$SCHEDULE_NAME:$FREQUENCY:$PROFILE:$NEXT_RUN:$ENABLED"
        fi
    done
    
    return 0
}

# Create a new scheduled backup
create_schedule() {
    SCHEDULE_NAME="$1"
    FREQUENCY="$2"
    PROFILE="$3"
    
    log_message "Creating backup schedule: $SCHEDULE_NAME, frequency: $FREQUENCY, profile: $PROFILE"
    
    # Create schedule file
    SCHEDULE_FILE="$SCHEDULE_DIR/$SCHEDULE_NAME.schedule"
    
    # Calculate next run time based on frequency
    case "$FREQUENCY" in
        "hourly")
            NEXT_HOUR=$(( ($(date +%H) + 1) % 24 ))
            NEXT_RUN=$(date -d "$(date +%Y-%m-%d) $NEXT_HOUR:00:00" +%s 2>/dev/null || echo $(( $(date +%s) + 3600 )))
            ;;
        "daily")
            NEXT_RUN=$(date -d "tomorrow 00:00:00" +%s 2>/dev/null || echo $(( $(date +%s) + 86400 )))
            ;;
        "weekly")
            NEXT_RUN=$(date -d "next Sunday 00:00:00" +%s 2>/dev/null || echo $(( $(date +%s) + 604800 )))
            ;;
        "monthly")
            NEXT_RUN=$(date -d "next month" +%s 2>/dev/null || echo $(( $(date +%s) + 2592000 )))
            ;;
        "boot")
            NEXT_RUN="boot"
            ;;
        *)
            log_message "Error: Invalid frequency: $FREQUENCY"
            return 1
            ;;
    esac
    
    # Create schedule file
    cat > "$SCHEDULE_FILE" << EOF
# Backup schedule for $SCHEDULE_NAME
SCHEDULE_NAME=$SCHEDULE_NAME
FREQUENCY=$FREQUENCY
PROFILE=$PROFILE
NEXT_RUN=$NEXT_RUN
LAST_RUN=0
LAST_STATUS=none
ENABLED=true
CREATED=$(date +%s)
EOF
    
    log_message "Backup schedule created: $SCHEDULE_NAME"
    return 0
}

# Delete a scheduled backup
delete_schedule() {
    SCHEDULE_NAME="$1"
    
    log_message "Deleting backup schedule: $SCHEDULE_NAME"
    
    SCHEDULE_FILE="$SCHEDULE_DIR/$SCHEDULE_NAME.schedule"
    
    if [ -f "$SCHEDULE_FILE" ]; then
        rm -f "$SCHEDULE_FILE"
        log_message "Backup schedule deleted: $SCHEDULE_NAME"
        return 0
    else
        log_message "Error: Schedule not found: $SCHEDULE_NAME"
        return 1
    fi
}

# Enable or disable a scheduled backup
toggle_schedule() {
    SCHEDULE_NAME="$1"
    ENABLED="$2"
    
    log_message "Toggling backup schedule: $SCHEDULE_NAME, enabled: $ENABLED"
    
    SCHEDULE_FILE="$SCHEDULE_DIR/$SCHEDULE_NAME.schedule"
    
    if [ -f "$SCHEDULE_FILE" ]; then
        # Create a temporary file
        TEMP_FILE="$SCHEDULE_DIR/temp_$SCHEDULE_NAME.schedule"
        
        # Update the enabled state
        sed "s/^ENABLED=.*/ENABLED=$ENABLED/" "$SCHEDULE_FILE" > "$TEMP_FILE"
        
        # Replace the original file
        mv "$TEMP_FILE" "$SCHEDULE_FILE"
        
        log_message "Backup schedule toggled: $SCHEDULE_NAME, enabled: $ENABLED"
        return 0
    else
        log_message "Error: Schedule not found: $SCHEDULE_NAME"
        return 1
    fi
}

# Update schedule after a backup run
update_schedule_after_run() {
    SCHEDULE_NAME="$1"
    STATUS="$2"
    
    log_message "Updating schedule after run: $SCHEDULE_NAME, status: $STATUS"
    
    SCHEDULE_FILE="$SCHEDULE_DIR/$SCHEDULE_NAME.schedule"
    
    if [ -f "$SCHEDULE_FILE" ]; then
        # Get current time
        CURRENT_TIME=$(date +%s)
        
        # Get frequency
        FREQUENCY=$(grep "^FREQUENCY=" "$SCHEDULE_FILE" | cut -d= -f2)
        
        # Calculate next run time based on frequency
        case "$FREQUENCY" in
            "hourly")
                NEXT_RUN=$(( CURRENT_TIME + 3600 ))
                ;;
            "daily")
                NEXT_RUN=$(( CURRENT_TIME + 86400 ))
                ;;
            "weekly")
                NEXT_RUN=$(( CURRENT_TIME + 604800 ))
                ;;
            "monthly")
                NEXT_RUN=$(( CURRENT_TIME + 2592000 ))
                ;;
            "boot")
                NEXT_RUN="boot"
                ;;
            *)
                NEXT_RUN=$(( CURRENT_TIME + 86400 ))
                ;;
        esac
        
        # Create a temporary file
        TEMP_FILE="$SCHEDULE_DIR/temp_$SCHEDULE_NAME.schedule"
        
        # Update last run and next run times
        sed -e "s/^NEXT_RUN=.*/NEXT_RUN=$NEXT_RUN/" \
            -e "s/^LAST_RUN=.*/LAST_RUN=$CURRENT_TIME/" \
            -e "s/^LAST_STATUS=.*/LAST_STATUS=$STATUS/" \
            "$SCHEDULE_FILE" > "$TEMP_FILE"
        
        # Replace the original file
        mv "$TEMP_FILE" "$SCHEDULE_FILE"
        
        log_message "Schedule updated after run: $SCHEDULE_NAME, next run: $NEXT_RUN"
        return 0
    else
        log_message "Error: Schedule not found: $SCHEDULE_NAME"
        return 1
    fi
}

# Find schedules that need to be run
find_schedules_to_run() {
    TYPE="$1" # 'time' or 'boot'
    
    log_message "Finding schedules to run for type: $TYPE"
    
    CURRENT_TIME=$(date +%s)
    
    for SCHEDULE_FILE in "$SCHEDULE_DIR"/*.schedule; do
        if [ -f "$SCHEDULE_FILE" ]; then
            SCHEDULE_NAME=$(basename "$SCHEDULE_FILE" .schedule)
            
            # Check if schedule is enabled
            ENABLED=$(grep "^ENABLED=" "$SCHEDULE_FILE" | cut -d= -f2)
            
            if [ "$ENABLED" = "true" ]; then
                # Get next run time
                NEXT_RUN=$(grep "^NEXT_RUN=" "$SCHEDULE_FILE" | cut -d= -f2)
                
                if [ "$TYPE" = "time" ] && [ "$NEXT_RUN" != "boot" ] && [ "$NEXT_RUN" -le "$CURRENT_TIME" ]; then
                    # Time-based schedule ready to run
                    PROFILE=$(grep "^PROFILE=" "$SCHEDULE_FILE" | cut -d= -f2)
                    echo "$SCHEDULE_NAME:$PROFILE"
                elif [ "$TYPE" = "boot" ] && [ "$NEXT_RUN" = "boot" ]; then
                    # Boot-based schedule
                    PROFILE=$(grep "^PROFILE=" "$SCHEDULE_FILE" | cut -d= -f2)
                    echo "$SCHEDULE_NAME:$PROFILE"
                fi
            fi
        fi
    done
    
    return 0
}

# Run scheduled backup
run_scheduled_backup() {
    SCHEDULE_NAME="$1"
    
    log_message "Running scheduled backup: $SCHEDULE_NAME"
    
    SCHEDULE_FILE="$SCHEDULE_DIR/$SCHEDULE_NAME.schedule"
    
    if [ -f "$SCHEDULE_FILE" ]; then
        # Get profile name
        PROFILE=$(grep "^PROFILE=" "$SCHEDULE_FILE" | cut -d= -f2)
        
        if [ -z "$PROFILE" ]; then
            log_message "Error: No profile specified in schedule"
            update_schedule_after_run "$SCHEDULE_NAME" "failed"
            return 1
        fi
        
        # Run backup using backup-engine.sh
        if [ -f "$MODDIR/scripts/backup-engine.sh" ]; then
            "$MODDIR/scripts/backup-engine.sh" backup "$PROFILE"
            BACKUP_STATUS=$?
            
            if [ $BACKUP_STATUS -eq 0 ]; then
                log_message "Scheduled backup completed successfully: $SCHEDULE_NAME"
                update_schedule_after_run "$SCHEDULE_NAME" "success"
                
                # Create success notification
                create_notification "Scheduled backup completed" "Backup $SCHEDULE_NAME completed successfully" "success"
                
                # Apply retention policy
                apply_retention_policy "$PROFILE"
                
                return 0
            else
                log_message "Error: Scheduled backup failed: $SCHEDULE_NAME"
                update_schedule_after_run "$SCHEDULE_NAME" "failed"
                
                # Create failure notification
                create_notification "Scheduled backup failed" "Backup $SCHEDULE_NAME failed to complete" "error"
                
                return 1
            fi
        else
            log_message "Error: Backup engine script not found"
            update_schedule_after_run "$SCHEDULE_NAME" "failed"
            return 1
        fi
    else
        log_message "Error: Schedule not found: $SCHEDULE_NAME"
        return 1
    fi
}

# Check and run all due schedules
check_and_run_schedules() {
    TYPE="$1" # 'time' or 'boot'
    
    log_message "Checking and running schedules for type: $TYPE"
    
    # Find schedules to run
    SCHEDULES=$(find_schedules_to_run "$TYPE")
    
    if [ -z "$SCHEDULES" ]; then
        log_message "No schedules to run for type: $TYPE"
        return 0
    fi
    
    # Run each schedule
    echo "$SCHEDULES" | while IFS=: read -r SCHEDULE_NAME PROFILE; do
        log_message "Running schedule: $SCHEDULE_NAME with profile: $PROFILE"
        run_scheduled_backup "$SCHEDULE_NAME"
    done
    
    return 0
}

# -----------------------------------------------
# BACKUP POLICIES AND RETENTION RULES
# -----------------------------------------------

# Create a new backup policy
create_policy() {
    POLICY_NAME="$1"
    MAX_BACKUPS="$2"
    MAX_AGE="$3"
    PROFILE="$4"
    
    log_message "Creating backup policy: $POLICY_NAME"
    
    # Create policy file
    POLICY_FILE="$POLICY_DIR/$POLICY_NAME.policy"
    
    cat > "$POLICY_FILE" << EOF
# Backup policy for $POLICY_NAME
POLICY_NAME=$POLICY_NAME
MAX_BACKUPS=$MAX_BACKUPS
MAX_AGE=$MAX_AGE
PROFILE=$PROFILE
CREATED=$(date +%s)
EOF
    
    log_message "Backup policy created: $POLICY_NAME"
    return 0
}

# Delete a backup policy
delete_policy() {
    POLICY_NAME="$1"
    
    log_message "Deleting backup policy: $POLICY_NAME"
    
    POLICY_FILE="$POLICY_DIR/$POLICY_NAME.policy"
    
    if [ -f "$POLICY_FILE" ]; then
        rm -f "$POLICY_FILE"
        log_message "Backup policy deleted: $POLICY_NAME"
        return 0
    else
        log_message "Error: Policy not found: $POLICY_NAME"
        return 1
    fi
}

# List all backup policies
list_policies() {
    log_message "Listing backup policies"
    
    if [ ! -d "$POLICY_DIR" ]; then
        log_message "No policies directory found"
        return 1
    fi
    
    for POLICY_FILE in "$POLICY_DIR"/*.policy; do
        if [ -f "$POLICY_FILE" ]; then
            POLICY_NAME=$(basename "$POLICY_FILE" .policy)
            
            # Extract policy information
            MAX_BACKUPS=$(grep "^MAX_BACKUPS=" "$POLICY_FILE" | cut -d= -f2)
            MAX_AGE=$(grep "^MAX_AGE=" "$POLICY_FILE" | cut -d= -f2)
            PROFILE=$(grep "^PROFILE=" "$POLICY_FILE" | cut -d= -f2)
            
            echo "$POLICY_NAME:$MAX_BACKUPS:$MAX_AGE:$PROFILE"
        fi
    done
    
    return 0
}

# Apply retention policy for a profile
apply_retention_policy() {
    PROFILE="$1"
    
    log_message "Applying retention policy for profile: $PROFILE"
    
    # Find policy for this profile
    POLICY_FILE=""
    
    for P_FILE in "$POLICY_DIR"/*.policy; do
        if [ -f "$P_FILE" ]; then
            P_PROFILE=$(grep "^PROFILE=" "$P_FILE" | cut -d= -f2)
            
            if [ "$P_PROFILE" = "$PROFILE" ]; then
                POLICY_FILE="$P_FILE"
                break
            fi
        fi
    done
    
    if [ -z "$POLICY_FILE" ]; then
        log_message "No policy found for profile: $PROFILE"
        return 0
    fi
    
    # Get policy parameters
    POLICY_NAME=$(basename "$POLICY_FILE" .policy)
    MAX_BACKUPS=$(grep "^MAX_BACKUPS=" "$POLICY_FILE" | cut -d= -f2)
    MAX_AGE=$(grep "^MAX_AGE=" "$POLICY_FILE" | cut -d= -f2)
    
    log_message "Found policy: $POLICY_NAME, max backups: $MAX_BACKUPS, max age: $MAX_AGE"
    
    # List backups for this profile
    if [ -f "$MODDIR/scripts/backup-engine.sh" ]; then
        BACKUPS=$("$MODDIR/scripts/backup-engine.sh" list | grep "^${PROFILE}_")
        
        if [ -z "$BACKUPS" ]; then
            log_message "No backups found for profile: $PROFILE"
            return 0
        fi
        
        # Get current time
        CURRENT_TIME=$(date +%s)
        
        # Apply age policy
        if [ -n "$MAX_AGE" ] && [ "$MAX_AGE" -gt 0 ]; then
            log_message "Applying age policy: $MAX_AGE days"
            
            echo "$BACKUPS" | while read -r BACKUP_ID; do
                # Extract timestamp from backup ID
                TIMESTAMP=$(echo "$BACKUP_ID" | sed -E "s/${PROFILE}_([0-9]{8})_([0-9]{6})/\1\2/")
                
                # Convert to timestamp format
                BACKUP_TIME=$(date -d "${TIMESTAMP:0:8} ${TIMESTAMP:8:2}:${TIMESTAMP:10:2}:${TIMESTAMP:12:2}" +%s 2>/dev/null)
                
                if [ -n "$BACKUP_TIME" ]; then
                    # Calculate age in days
                    BACKUP_AGE=$(( (CURRENT_TIME - BACKUP_TIME) / 86400 ))
                    
                    if [ "$BACKUP_AGE" -gt "$MAX_AGE" ]; then
                        log_message "Deleting old backup: $BACKUP_ID (age: $BACKUP_AGE days)"
                        "$MODDIR/scripts/backup-engine.sh" delete "$BACKUP_ID"
                    fi
                fi
            done
        fi
        
        # Apply count policy
        if [ -n "$MAX_BACKUPS" ] && [ "$MAX_BACKUPS" -gt 0 ]; then
            log_message "Applying count policy: $MAX_BACKUPS backups"
            
            # Count backups
            BACKUP_COUNT=$(echo "$BACKUPS" | wc -l)
            
            if [ "$BACKUP_COUNT" -gt "$MAX_BACKUPS" ]; then
                # Calculate how many to delete
                DELETE_COUNT=$((BACKUP_COUNT - MAX_BACKUPS))
                
                log_message "Need to delete $DELETE_COUNT backups to meet policy"
                
                # Sort backups by age (oldest first)
                SORTED_BACKUPS=$(echo "$BACKUPS" | sort)
                
                # Delete oldest backups
                echo "$SORTED_BACKUPS" | head -n "$DELETE_COUNT" | while read -r BACKUP_ID; do
                    log_message "Deleting excess backup: $BACKUP_ID"
                    "$MODDIR/scripts/backup-engine.sh" delete "$BACKUP_ID"
                done
            fi
        fi
    else
        log_message "Error: Backup engine script not found"
        return 1
    fi
    
    log_message "Retention policy applied for profile: $PROFILE"
    return 0
}

# -----------------------------------------------
# NOTIFICATION SYSTEM
# -----------------------------------------------

# Create a notification
create_notification() {
    TITLE="$1"
    MESSAGE="$2"
    TYPE="$3"  # success, warning, error, info
    
    log_message "Creating notification: $TITLE"
    
    # Generate notification ID
    NOTIFICATION_ID="notification_$(date +%s%N)"
    
    # Create notification file
    NOTIFICATION_FILE="$NOTIFICATION_DIR/$NOTIFICATION_ID.notification"
    
    cat > "$NOTIFICATION_FILE" << EOF
TITLE=$TITLE
MESSAGE=$MESSAGE
TYPE=$TYPE
TIMESTAMP=$(date +%s)
READ=false
EOF
    
    # Create system notification if possible
    if command -v am >/dev/null 2>&1; then
        # Use Android's notification system
        am broadcast -a android.intent.action.BOOT_COMPLETED -p android
        am startservice -n com.android.systemui/.SystemUIService
        
        # Use su command to show notification with proper permissions
        su -c "am broadcast -a android.intent.action.BOOT_COMPLETED -p android"
        su -c "am startservice -n com.android.systemui/.SystemUIService"
        
        # Try to create actual notification
        NOTIFICATION_COMMAND="am startservice -n $MODDIR/services/.NotificationService -e title \"$TITLE\" -e message \"$MESSAGE\" -e type \"$TYPE\""
        su -c "$NOTIFICATION_COMMAND" >/dev/null 2>&1
    fi
    
    log_message "Notification created: $NOTIFICATION_ID"
    return 0
}

# List all notifications
list_notifications() {
    SHOW_READ="$1" # "true" to show read notifications, "false" to hide them
    
    log_message "Listing notifications, show read: $SHOW_READ"
    
    if [ ! -d "$NOTIFICATION_DIR" ]; then
        log_message "No notifications directory found"
        return 1
    fi
    
    for NOTIFICATION_FILE in "$NOTIFICATION_DIR"/*.notification; do
        if [ -f "$NOTIFICATION_FILE" ]; then
            NOTIFICATION_ID=$(basename "$NOTIFICATION_FILE" .notification)
            
            # Extract notification information
            TITLE=$(grep "^TITLE=" "$NOTIFICATION_FILE" | cut -d= -f2-)
            MESSAGE=$(grep "^MESSAGE=" "$NOTIFICATION_FILE" | cut -d= -f2-)
            TYPE=$(grep "^TYPE=" "$NOTIFICATION_FILE" | cut -d= -f2)
            TIMESTAMP=$(grep "^TIMESTAMP=" "$NOTIFICATION_FILE" | cut -d= -f2)
            READ=$(grep "^READ=" "$NOTIFICATION_FILE" | cut -d= -f2)
            
            # Check if we should show this notification
            if [ "$SHOW_READ" = "true" ] || [ "$READ" = "false" ]; then
                echo "$NOTIFICATION_ID:$TITLE:$MESSAGE:$TYPE:$TIMESTAMP:$READ"
            fi
        fi
    done
    
    return 0
}

# Mark notification as read
mark_notification_read() {
    NOTIFICATION_ID="$1"
    
    log_message "Marking notification as read: $NOTIFICATION_ID"
    
    NOTIFICATION_FILE="$NOTIFICATION_DIR/$NOTIFICATION_ID.notification"
    
    if [ -f "$NOTIFICATION_FILE" ]; then
        # Create a temporary file
        TEMP_FILE="$NOTIFICATION_DIR/temp_$NOTIFICATION_ID.notification"
        
        # Update the read state
        sed "s/^READ=.*/READ=true/" "$NOTIFICATION_FILE" > "$TEMP_FILE"
        
        # Replace the original file
        mv "$TEMP_FILE" "$NOTIFICATION_FILE"
        
        log_message "Notification marked as read: $NOTIFICATION_ID"
        return 0
    else
        log_message "Error: Notification not found: $NOTIFICATION_ID"
        return 1
    fi
}

# Delete a notification
delete_notification() {
    NOTIFICATION_ID="$1"
    
    log_message "Deleting notification: $NOTIFICATION_ID"
    
    NOTIFICATION_FILE="$NOTIFICATION_DIR/$NOTIFICATION_ID.notification"
    
    if [ -f "$NOTIFICATION_FILE" ]; then
        rm -f "$NOTIFICATION_FILE"
        log_message "Notification deleted: $NOTIFICATION_ID"
        return 0
    else
        log_message "Error: Notification not found: $NOTIFICATION_ID"
        return 1
    fi
}

# Clean up old notifications
cleanup_old_notifications() {
    MAX_AGE="$1" # in days
    
    log_message "Cleaning up old notifications, max age: $MAX_AGE days"
    
    if [ ! -d "$NOTIFICATION_DIR" ]; then
        log_message "No notifications directory found"
        return 1
    fi
    
    # Get current time
    CURRENT_TIME=$(date +%s)
    MAX_AGE_SECONDS=$((MAX_AGE * 86400))
    
    for NOTIFICATION_FILE in "$NOTIFICATION_DIR"/*.notification; do
        if [ -f "$NOTIFICATION_FILE" ]; then
            # Get timestamp
            TIMESTAMP=$(grep "^TIMESTAMP=" "$NOTIFICATION_FILE" | cut -d= -f2)
            
            if [ -n "$TIMESTAMP" ]; then
                # Calculate age
                AGE=$((CURRENT_TIME - TIMESTAMP))
                
                if [ "$AGE" -gt "$MAX_AGE_SECONDS" ]; then
                    NOTIFICATION_ID=$(basename "$NOTIFICATION_FILE" .notification)
                    log_message "Deleting old notification: $NOTIFICATION_ID"
                    rm -f "$NOTIFICATION_FILE"
                fi
            fi
        fi
    done
    
    log_message "Old notifications cleaned up"
    return 0
}

# -----------------------------------------------
# MAIN FUNCTION
# -----------------------------------------------

# Initialize scheduler
init_scheduler() {
    log_message "Initializing backup scheduler"
    
    # Create directories if they don't exist
    mkdir -p "$SCHEDULE_DIR"
    mkdir -p "$POLICY_DIR"
    mkdir -p "$NOTIFICATION_DIR"
    
    # Create default policy if it doesn't exist
    if [ ! -f "$POLICY_DIR/default.policy" ]; then
        create_policy "default" "5" "30" "default"
    fi
    
    # Create default schedule if it doesn't exist
    if [ ! -f "$SCHEDULE_DIR/daily.schedule" ]; then
        create_schedule "daily" "daily" "default"
    fi
    
    log_message "Backup scheduler initialized"
    return 0
}

# Main function - Command processor
main() {
    COMMAND="$1"
    PARAM1="$2"
    PARAM2="$3"
    PARAM3="$4"
    PARAM4="$5"
    
    case "$COMMAND" in
        "init")
            init_scheduler
            ;;
        "list_schedules")
            list_schedules
            ;;
        "create_schedule")
            create_schedule "$PARAM1" "$PARAM2" "$PARAM3"
            ;;
        "delete_schedule")
            delete_schedule "$PARAM1"
            ;;
        "toggle_schedule")
            toggle_schedule "$PARAM1" "$PARAM2"
            ;;
        "run_schedule")
            run_scheduled_backup "$PARAM1"
            ;;
        "check_schedules")
            check_and_run_schedules "$PARAM1"
            ;;
        "create_policy")
            create_policy "$PARAM1" "$PARAM2" "$PARAM3" "$PARAM4"
            ;;
        "delete_policy")
            delete_policy "$PARAM1"
            ;;
        "list_policies")
            list_policies
            ;;
        "apply_policy")
            apply_retention_policy "$PARAM1"
            ;;
        "create_notification")
            create_notification "$PARAM1" "$PARAM2" "$PARAM3"
            ;;
        "list_notifications")
            list_notifications "$PARAM1"
            ;;
        "mark_read")
            mark_notification_read "$PARAM1"
            ;;
        "delete_notification")
            delete_notification "$PARAM1"
            ;;
        "cleanup_notifications")
            cleanup_old_notifications "$PARAM1"
            ;;
        *)
            log_message "Unknown command: $COMMAND"
            echo "Usage: $0 init|list_schedules|create_schedule|delete_schedule|toggle_schedule|run_schedule|check_schedules|create_policy|delete_policy|list_policies|apply_policy|create_notification|list_notifications|mark_read|delete_notification|cleanup_notifications [parameters]"
            return 1
            ;;
    esac
}

# Execute main with all arguments
main "$@"