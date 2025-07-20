#!/system/bin/sh

# Advanced Anti-Bootloop KSU Module - Action Script
# Author: @overspend1/Wiktor
# Provides KernelSU Manager action button functionality

MODDIR="/data/adb/modules/anti_bootloop_advanced_ksu"
. "$MODDIR/utils.sh"
. "$MODDIR/backup_manager.sh"
. "$MODDIR/recovery_engine.sh"

# Action menu for KernelSU Manager
show_menu() {
    echo "======================================"
    echo "🛡️  Advanced Anti-Bootloop KSU v2.0"
    echo "======================================"
    echo "Author: @overspend1/Wiktor"
    echo ""
    echo "Current Status:"
    
    # Load config and show current state
    load_config
    
    local boot_count=$(cat "$BOOT_COUNT_FILE" 2>/dev/null || echo "0")
    local recovery_state=$(get_recovery_state)
    local total_boots=$(cat "$BASE_DIR/total_boots" 2>/dev/null || echo "0")
    
    echo "📊 Boot Count: $boot_count / $MAX_BOOT_ATTEMPTS"
    echo "🔄 Recovery State: $recovery_state"
    echo "📈 Total Successful Boots: $total_boots"
    echo "⚙️  Safe Mode: $(is_safe_mode_active && echo "Active" || echo "Inactive")"
    echo ""
    
    # Hardware status
    local cpu_temp=$(get_cpu_temp)
    local available_ram=$(get_available_ram)
    
    echo "Hardware Status:"
    echo "🌡️  CPU Temperature: ${cpu_temp}°C"
    echo "💾 Available RAM: ${available_ram}MB"
    
    # Check for hardware issues
    local hardware_issues=$(check_hardware_health)
    if [ -n "$hardware_issues" ]; then
        echo "⚠️  Hardware Issues: $hardware_issues"
    else
        echo "✅ Hardware: OK"
    fi
    echo ""
    
    # Backup status
    local backup_count=$(find "$BACKUP_DIR" -name "*.img" 2>/dev/null | wc -l)
    echo "💾 Available Backups: $backup_count"
    echo ""
    
    echo "Available Actions:"
    echo "1. 📁 Create Kernel Backup"
    echo "2. 🔄 List & Restore Backups"
    echo "3. 🛡️  Enable/Disable Safe Mode"
    echo "4. 🔢 Reset Boot Counter"
    echo "5. 📋 View Recent Logs"
    echo "6. 🔧 Quick Diagnostics"
    echo "7. ⚙️  Change Recovery Strategy"
    echo "8. 🚨 Emergency Controls"
    echo "9. 📊 System Health Report"
    echo "0. ❌ Exit"
    echo ""
}

# Create kernel backup with user input
create_backup_interactive() {
    echo "Creating kernel backup..."
    echo ""
    echo "Backup options:"
    echo "1. Quick backup (auto-generated name)"
    echo "2. Custom backup (enter name and description)"
    echo ""
    read -p "Choose option [1-2]: " backup_option
    
    case "$backup_option" in
        1)
            local backup_name="manual_$(date '+%Y%m%d_%H%M%S')"
            local description="Manual backup created via action menu"
            ;;
        2)
            read -p "Enter backup name: " backup_name
            read -p "Enter description: " description
            ;;
        *)
            echo "Invalid option"
            return 1
            ;;
    esac
    
    echo "Creating backup: $backup_name"
    if create_backup "$backup_name" "$description" "true"; then
        echo "✅ Backup created successfully!"
    else
        echo "❌ Backup creation failed!"
    fi
    
    read -p "Press Enter to continue..."
}

# List and restore backups
list_restore_backups() {
    echo "Available Kernel Backups:"
    echo ""
    
    local backup_files=$(find "$BACKUP_DIR" -name "*.img" 2>/dev/null | sort -t_ -k2 -r)
    local count=1
    local backup_array=""
    
    if [ -z "$backup_files" ]; then
        echo "No backups found."
        read -p "Press Enter to continue..."
        return
    fi
    
    for backup_file in $backup_files; do
        local backup_name=$(basename "$backup_file" .img)
        local backup_size=$(stat -c%s "$backup_file" 2>/dev/null || echo "0")
        local backup_date=$(stat -c%y "$backup_file" 2>/dev/null | cut -d' ' -f1)
        local hash_file="$BACKUP_DIR/${backup_name}.sha256"
        local integrity="❌"
        
        if [ -f "$hash_file" ]; then
            integrity="✅"
        fi
        
        echo "$count. $backup_name"
        echo "   📅 Created: $backup_date"
        echo "   📏 Size: $(echo $backup_size | awk '{print int($1/1024/1024)"MB"}')"
        echo "   🔒 Integrity: $integrity"
        echo ""
        
        backup_array="$backup_array $backup_name"
        count=$((count + 1))
    done
    
    echo "0. Back to main menu"
    echo ""
    read -p "Select backup to restore [0-$((count-1))]: " restore_choice
    
    if [ "$restore_choice" = "0" ]; then
        return
    fi
    
    if [ "$restore_choice" -gt 0 ] && [ "$restore_choice" -lt "$count" ]; then
        local selected_backup=$(echo $backup_array | cut -d' ' -f$restore_choice)
        
        echo "⚠️  WARNING: This will replace your current kernel!"
        echo "Selected backup: $selected_backup"
        read -p "Are you sure? [y/N]: " confirm
        
        if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
            echo "Restoring backup: $selected_backup"
            if restore_backup "$selected_backup" "true"; then
                echo "✅ Backup restored successfully!"
                echo "🔄 System will reboot in 10 seconds..."
                sleep 10
                reboot
            else
                echo "❌ Backup restoration failed!"
            fi
        fi
    else
        echo "Invalid selection"
    fi
    
    read -p "Press Enter to continue..."
}

# Safe mode toggle
toggle_safe_mode() {
    if is_safe_mode_active; then
        echo "Safe mode is currently ACTIVE"
        read -p "Disable safe mode? [y/N]: " confirm
        
        if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
            disable_safe_mode
            echo "✅ Safe mode disabled"
        fi
    else
        echo "Safe mode is currently INACTIVE"
        read -p "Enable safe mode? [y/N]: " confirm
        
        if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
            enable_safe_mode
            echo "✅ Safe mode enabled"
            echo "Non-essential modules have been disabled"
        fi
    fi
    
    read -p "Press Enter to continue..."
}

# Reset boot counter
reset_boot_counter() {
    local current_count=$(cat "$BOOT_COUNT_FILE" 2>/dev/null || echo "0")
    
    echo "Current boot count: $current_count"
    read -p "Reset boot counter to 0? [y/N]: " confirm
    
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        echo "0" > "$BOOT_COUNT_FILE"
        echo "✅ Boot counter reset to 0"
        log_message "INFO" "Boot counter manually reset via action menu"
    fi
    
    read -p "Press Enter to continue..."
}

# View recent logs
view_logs() {
    echo "Recent Logs (last 50 lines):"
    echo "=============================="
    
    if [ -f "$LOG_FILE" ]; then
        tail -50 "$LOG_FILE"
    else
        echo "No logs found"
    fi
    
    echo ""
    echo "=============================="
    read -p "Press Enter to continue..."
}

# Quick diagnostics
quick_diagnostics() {
    echo "🔍 Running Quick Diagnostics..."
    echo "=============================="
    
    # Check module integrity
    echo "📁 Module Integrity:"
    local missing_files=""
    local required_files="service.sh post-fs-data.sh utils.sh backup_manager.sh recovery_engine.sh config.conf"
    
    for file in $required_files; do
        if [ ! -f "$MODDIR/$file" ]; then
            missing_files="$missing_files $file"
        fi
    done
    
    if [ -z "$missing_files" ]; then
        echo "   ✅ All required files present"
    else
        echo "   ❌ Missing files:$missing_files"
    fi
    
    # Check permissions
    echo "🔒 Permissions:"
    if [ -x "$MODDIR/service.sh" ]; then
        echo "   ✅ Scripts are executable"
    else
        echo "   ❌ Script permissions incorrect"
    fi
    
    # Check backup directory
    echo "💾 Backup System:"
    if [ -d "$BACKUP_DIR" ]; then
        local backup_count=$(find "$BACKUP_DIR" -name "*.img" 2>/dev/null | wc -l)
        echo "   ✅ Backup directory exists ($backup_count backups)"
    else
        echo "   ❌ Backup directory missing"
    fi
    
    # Check configuration
    echo "⚙️  Configuration:"
    if [ -f "$CONFIG_FILE" ]; then
        echo "   ✅ Configuration file exists"
        echo "   📊 Recovery strategy: $RECOVERY_STRATEGY"
        echo "   🔢 Max boot attempts: $MAX_BOOT_ATTEMPTS"
    else
        echo "   ❌ Configuration file missing"
    fi
    
    # Verify backups
    echo "🔍 Backup Integrity:"
    verify_all_backups >/dev/null 2>&1
    local verify_result=$?
    if [ $verify_result -eq 0 ]; then
        echo "   ✅ All backups verified"
    else
        echo "   ⚠️  Some backups may be corrupted"
    fi
    
    # Check conflicts
    echo "⚠️  Conflict Detection:"
    if detect_conflicts; then
        echo "   ✅ No conflicts detected"
    else
        echo "   ⚠️  Potential conflicts found (check logs)"
    fi
    
    echo ""
    echo "=============================="
    read -p "Press Enter to continue..."
}

# Change recovery strategy
change_strategy() {
    echo "Current Recovery Strategy: $RECOVERY_STRATEGY"
    echo ""
    echo "Available strategies:"
    echo "1. Progressive - Escalating interventions (recommended)"
    echo "2. Aggressive - Immediate kernel restore"
    echo "3. Conservative - More cautious approach"
    echo ""
    read -p "Select strategy [1-3]: " strategy_choice
    
    case "$strategy_choice" in
        1) new_strategy="progressive" ;;
        2) new_strategy="aggressive" ;;
        3) new_strategy="conservative" ;;
        *) echo "Invalid choice"; read -p "Press Enter to continue..."; return ;;
    esac
    
    # Update config file
    sed -i "s/RECOVERY_STRATEGY=.*/RECOVERY_STRATEGY=$new_strategy/" "$CONFIG_FILE"
    
    echo "✅ Recovery strategy changed to: $new_strategy"
    log_message "INFO" "Recovery strategy changed to $new_strategy via action menu"
    
    read -p "Press Enter to continue..."
}

# Emergency controls
emergency_controls() {
    echo "🚨 Emergency Controls"
    echo "===================="
    echo "⚠️  WARNING: These actions can affect system stability!"
    echo ""
    echo "1. 🛡️  Force enable safe mode"
    echo "2. ❌ Disable all modules"
    echo "3. 🔄 Reset recovery state"
    echo "4. 🚨 Emergency disable module"
    echo "0. ← Back"
    echo ""
    read -p "Select action [0-4]: " emergency_choice
    
    case "$emergency_choice" in
        1)
            read -p "Force enable safe mode? [y/N]: " confirm
            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                enable_safe_mode
                echo "✅ Safe mode force enabled"
            fi
            ;;
        2)
            read -p "Disable ALL modules? [y/N]: " confirm
            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                disable_all_modules
                echo "✅ All modules disabled"
            fi
            ;;
        3)
            read -p "Reset recovery state to normal? [y/N]: " confirm
            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                set_recovery_state "normal"
                echo "✅ Recovery state reset"
            fi
            ;;
        4)
            read -p "Emergency disable this module? [y/N]: " confirm
            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                touch "$EMERGENCY_DISABLE_FILE"
                echo "✅ Module emergency disabled"
                echo "Remove $EMERGENCY_DISABLE_FILE to re-enable"
            fi
            ;;
        0) return ;;
        *) echo "Invalid choice" ;;
    esac
    
    read -p "Press Enter to continue..."
}

# System health report
system_health_report() {
    echo "📊 System Health Report"
    echo "======================="
    echo "Generated: $(date)"
    echo ""
    
    # Boot statistics
    echo "🔄 Boot Statistics:"
    echo "   Current boot count: $(cat "$BOOT_COUNT_FILE" 2>/dev/null || echo "0")"
    echo "   Max attempts: $MAX_BOOT_ATTEMPTS"
    echo "   Total successful boots: $(cat "$BASE_DIR/total_boots" 2>/dev/null || echo "0")"
    echo "   Recovery state: $(get_recovery_state)"
    echo ""
    
    # Hardware status
    echo "🖥️  Hardware Status:"
    echo "   CPU temperature: $(get_cpu_temp)°C"
    echo "   Available RAM: $(get_available_ram)MB"
    echo "   Storage health: $(get_storage_health)"
    echo ""
    
    # Module status
    echo "🔧 Module Status:"
    echo "   Safe mode: $(is_safe_mode_active && echo "Active" || echo "Inactive")"
    echo "   Recovery strategy: $RECOVERY_STRATEGY"
    echo "   Hardware monitoring: $([ "$HARDWARE_MONITORING" = "true" ] && echo "Enabled" || echo "Disabled")"
    echo "   Telemetry: $([ "$TELEMETRY_ENABLED" = "true" ] && echo "Enabled" || echo "Disabled")"
    echo ""
    
    # Backup status
    echo "💾 Backup Status:"
    local backup_count=$(find "$BACKUP_DIR" -name "*.img" 2>/dev/null | wc -l)
    echo "   Available backups: $backup_count"
    echo "   Backup slots configured: $BACKUP_SLOTS"
    
    if [ $backup_count -gt 0 ]; then
        local latest_backup=$(find "$BACKUP_DIR" -name "*.img" -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2)
        if [ -n "$latest_backup" ]; then
            local backup_name=$(basename "$latest_backup" .img)
            local backup_date=$(stat -c%y "$latest_backup" 2>/dev/null | cut -d' ' -f1)
            echo "   Latest backup: $backup_name ($backup_date)"
        fi
    fi
    echo ""
    
    # Recent issues
    echo "⚠️  Recent Issues:"
    if [ -f "$LOG_FILE" ]; then
        local error_count=$(grep -c "ERROR\|CRITICAL" "$LOG_FILE" 2>/dev/null || echo "0")
        local warning_count=$(grep -c "WARN" "$LOG_FILE" 2>/dev/null || echo "0")
        echo "   Errors in log: $error_count"
        echo "   Warnings in log: $warning_count"
        
        if [ $error_count -gt 0 ]; then
            echo "   Recent errors:"
            grep "ERROR\|CRITICAL" "$LOG_FILE" | tail -3 | while read line; do
                echo "     - $(echo "$line" | cut -d']' -f3-)"
            done
        fi
    else
        echo "   No log file found"
    fi
    
    echo ""
    echo "======================="
    read -p "Press Enter to continue..."
}

# Main menu loop
main_menu() {
    while true; do
        clear
        show_menu
        read -p "Enter your choice [0-9]: " choice
        
        case "$choice" in
            1) create_backup_interactive ;;
            2) list_restore_backups ;;
            3) toggle_safe_mode ;;
            4) reset_boot_counter ;;
            5) view_logs ;;
            6) quick_diagnostics ;;
            7) change_strategy ;;
            8) emergency_controls ;;
            9) system_health_report ;;
            0) echo "Goodbye!"; exit 0 ;;
            *) echo "Invalid choice"; read -p "Press Enter to continue..." ;;
        esac
    done
}

# Initialize and start
log_message "INFO" "Action menu accessed"
main_menu