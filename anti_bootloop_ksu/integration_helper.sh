#!/system/bin/sh

# Advanced Anti-Bootloop KSU Module - Integration Helper
# Author: @overspend1/Wiktor
# Integration with other recovery tools and system components

MODDIR=${0%/*}
. "$MODDIR/utils.sh"

INTEGRATION_LOG="$BASE_DIR/integration.log"
DETECTED_TOOLS="$BASE_DIR/detected_tools"

# Detect other recovery tools
detect_recovery_tools() {
    log_message "INFO" "Scanning for other recovery tools..."
    
    local detected=""
    
    # Check for TWRP
    if [ -f "/system/recovery-resource.dat" ] || [ -d "/twres" ]; then
        detected="$detected TWRP"
        log_message "INFO" "TWRP recovery detected"
    fi
    
    # Check for OrangeFox
    if [ -f "/fox" ] || [ -d "/system/recovery-script" ]; then
        detected="$detected OrangeFox"
        log_message "INFO" "OrangeFox recovery detected"
    fi
    
    # Check for Magisk
    if [ -d "/data/adb/magisk" ] || [ -f "/data/adb/magisk/magisk" ]; then
        detected="$detected Magisk"
        log_message "INFO" "Magisk detected"
        
        # Get Magisk version
        local magisk_version=$(cat /data/adb/magisk/util_functions.sh 2>/dev/null | grep "MAGISK_VER=" | head -1 | cut -d'=' -f2 | tr -d '"')
        if [ -n "$magisk_version" ]; then
            log_message "INFO" "Magisk version: $magisk_version"
        fi
    fi
    
    # Check for Xposed
    if [ -d "/data/data/de.robv.android.xposed.installer" ] || [ -f "/system/xposed.prop" ]; then
        detected="$detected Xposed"
        log_message "INFO" "Xposed framework detected"
    fi
    
    # Check for LSPosed
    if [ -d "/data/adb/lspd" ] || [ -f "/data/adb/modules/zygisk_lsposed" ]; then
        detected="$detected LSPosed"
        log_message "INFO" "LSPosed detected"
    fi
    
    # Check for EdXposed
    if [ -d "/data/adb/modules/riru_edxposed" ]; then
        detected="$detected EdXposed"
        log_message "INFO" "EdXposed detected"
    fi
    
    # Check for Riru
    if [ -d "/data/adb/riru" ] || [ -f "/data/adb/modules/riru-core" ]; then
        detected="$detected Riru"
        log_message "INFO" "Riru detected"
    fi
    
    # Check for Zygisk
    if [ -f "/data/adb/ksu/bin/ksud" ]; then
        # KernelSU has built-in Zygisk
        detected="$detected Zygisk-KSU"
        log_message "INFO" "KernelSU Zygisk detected"
    elif [ -d "/data/adb/modules/zygisksu" ]; then
        detected="$detected Zygisk"
        log_message "INFO" "Zygisk detected"
    fi
    
    # Check for Shamiko
    if [ -d "/data/adb/modules/zygisk_shamiko" ]; then
        detected="$detected Shamiko"
        log_message "INFO" "Shamiko (hide detection) detected"
    fi
    
    # Check for other bootloop protection modules
    if [ -d "/data/adb/modules" ]; then
        local other_bootloop=$(find /data/adb/modules -maxdepth 2 -name "module.prop" -exec grep -l "bootloop\|recovery" {} \; 2>/dev/null | grep -v "anti_bootloop_advanced_ksu")
        if [ -n "$other_bootloop" ]; then
            detected="$detected OTHER_BOOTLOOP_MODULES"
            log_message "WARN" "Other bootloop protection modules detected"
        fi
    fi
    
    # Store detected tools
    echo "$detected" > "$DETECTED_TOOLS"
    
    log_message "INFO" "Recovery tools detected:$detected"
    echo "$detected"
}

# Check compatibility with detected tools
check_compatibility() {
    local tools_list="$1"
    log_message "INFO" "Checking compatibility with detected tools"
    
    local compatible=true
    local warnings=""
    local conflicts=""
    
    # Check each detected tool
    for tool in $tools_list; do
        case "$tool" in
            "Magisk")
                # Generally compatible, but may have module conflicts
                if [ -d "/data/adb/magisk/modules" ]; then
                    local magisk_bootloop_modules=$(find /data/adb/magisk/modules -name "module.prop" -exec grep -l "bootloop\|recovery" {} \; 2>/dev/null)
                    if [ -n "$magisk_bootloop_modules" ]; then
                        conflicts="$conflicts MAGISK_BOOTLOOP_MODULES"
                        log_message "WARN" "Conflicting Magisk bootloop modules detected"
                    fi
                fi
                ;;
            "LSPosed"|"EdXposed"|"Xposed")
                # Framework modules can cause stability issues
                warnings="$warnings XPOSED_FRAMEWORK"
                log_message "WARN" "Xposed framework detected - may affect system stability"
                ;;
            "OTHER_BOOTLOOP_MODULES")
                conflicts="$conflicts MULTIPLE_BOOTLOOP_PROTECTION"
                log_message "WARN" "Multiple bootloop protection modules detected - potential conflicts"
                ;;
            "Shamiko")
                # Shamiko can interfere with our detection mechanisms
                warnings="$warnings HIDE_DETECTION_ACTIVE"
                log_message "WARN" "Hide detection module active - may affect functionality"
                ;;
        esac
    done
    
    # Generate compatibility report
    if [ -n "$conflicts" ]; then
        compatible=false
        log_message "ERROR" "Compatibility conflicts detected:$conflicts"
    fi
    
    if [ -n "$warnings" ]; then
        log_message "WARN" "Compatibility warnings:$warnings"
    fi
    
    if [ "$compatible" = "true" ] && [ -z "$warnings" ]; then
        log_message "INFO" "All detected tools are compatible"
        echo "COMPATIBLE"
    elif [ "$compatible" = "true" ]; then
        echo "COMPATIBLE_WITH_WARNINGS:$warnings"
    else
        echo "CONFLICTS:$conflicts"
    fi
}

# Create integration hooks for other tools
create_integration_hooks() {
    log_message "INFO" "Creating integration hooks"
    
    local hooks_dir="$BASE_DIR/hooks"
    mkdir -p "$hooks_dir"
    
    # TWRP integration hook
    cat > "$hooks_dir/twrp_hook.sh" << 'EOF'
#!/sbin/sh
# TWRP Integration Hook for Anti-Bootloop Module
# Place this in /twres/scripts/ for TWRP integration

echo "Anti-Bootloop KSU Module - TWRP Integration"
echo "============================================"

ANTIBOOTLOOP_DIR="/data/local/tmp/antibootloop"

if [ -d "$ANTIBOOTLOOP_DIR" ]; then
    echo "Module detected. Available actions:"
    echo "1. Create emergency backup"
    echo "2. View module status"
    echo "3. Reset boot counter"
    echo "4. View recent logs"
    echo ""
    
    read -p "Select action [1-4] or Enter to skip: " choice
    
    case "$choice" in
        1)
            echo "Creating emergency backup..."
            sh /data/adb/modules/anti_bootloop_advanced_ksu/backup_manager.sh create_backup "twrp_emergency_$(date '+%Y%m%d_%H%M%S')" "TWRP emergency backup"
            ;;
        2)
            echo "Module Status:"
            echo "Boot Count: $(cat $ANTIBOOTLOOP_DIR/boot_count 2>/dev/null || echo '0')"
            echo "Recovery State: $(cat $ANTIBOOTLOOP_DIR/recovery_state 2>/dev/null || echo 'normal')"
            ;;
        3)
            echo "0" > "$ANTIBOOTLOOP_DIR/boot_count"
            echo "Boot counter reset"
            ;;
        4)
            echo "Recent logs:"
            tail -20 "$ANTIBOOTLOOP_DIR/detailed.log" 2>/dev/null || echo "No logs found"
            ;;
    esac
else
    echo "Anti-Bootloop module not found"
fi

read -p "Press Enter to continue..."
EOF
    
    # Magisk integration
    cat > "$hooks_dir/magisk_integration.md" << 'EOF'
# Magisk Integration Guide

## Module Conflict Resolution
If you have other Magisk modules that might conflict:

1. Disable conflicting modules:
   ```
   touch /data/adb/modules/[conflicting_module]/disable
   ```

2. Check module priority by renaming:
   ```
   mv /data/adb/modules/anti_bootloop_advanced_ksu /data/adb/modules/000_anti_bootloop_advanced_ksu
   ```

## Magisk Module Template Compatibility
This module is compatible with Magisk module template v1700+

## Integration Commands
- View status: `su -c 'sh /data/adb/modules/anti_bootloop_advanced_ksu/action.sh'`
- Quick test: `su -c 'sh /data/adb/modules/anti_bootloop_advanced_ksu/auto_recovery_test.sh quick'`
EOF
    
    # ADB integration script
    cat > "$hooks_dir/adb_integration.sh" << 'EOF'
#!/system/bin/sh
# ADB Integration for Anti-Bootloop Module
# Usage: adb shell sh /data/adb/modules/anti_bootloop_advanced_ksu/integration_helper.sh adb_menu

echo "Anti-Bootloop KSU Module - ADB Interface"
echo "========================================"

MODDIR="/data/adb/modules/anti_bootloop_advanced_ksu"

if [ ! -d "$MODDIR" ]; then
    echo "Error: Module not found"
    exit 1
fi

echo "1. Module Status"
echo "2. Create Backup"
echo "3. List Backups"
echo "4. Reset Boot Counter"
echo "5. Run Quick Test"
echo "6. View Logs"
echo "7. Emergency Disable"
echo ""

read -p "Select option [1-7]: " choice

case "$choice" in
    1)
        sh "$MODDIR/action.sh" 2>/dev/null | head -20
        ;;
    2)
        sh "$MODDIR/backup_manager.sh" create_backup "adb_backup_$(date '+%Y%m%d_%H%M%S')" "ADB created backup"
        ;;
    3)
        sh "$MODDIR/backup_manager.sh" list_backups true
        ;;
    4)
        echo "0" > /data/local/tmp/antibootloop/boot_count
        echo "Boot counter reset"
        ;;
    5)
        sh "$MODDIR/auto_recovery_test.sh" quick
        ;;
    6)
        tail -50 /data/local/tmp/antibootloop/detailed.log 2>/dev/null || echo "No logs found"
        ;;
    7)
        touch /data/local/tmp/disable_antibootloop
        echo "Module emergency disabled"
        ;;
    *)
        echo "Invalid option"
        ;;
esac
EOF
    
    chmod 755 "$hooks_dir"/*.sh
    
    log_message "INFO" "Integration hooks created in $hooks_dir"
}

# Generate integration report
generate_integration_report() {
    local report_file="$BASE_DIR/integration_report.txt"
    local detected_tools=$(cat "$DETECTED_TOOLS" 2>/dev/null || echo "")
    
    {
        echo "Anti-Bootloop KSU Module - Integration Report"
        echo "============================================="
        echo "Generated: $(date)"
        echo "Author: @overspend1/Wiktor"
        echo ""
        
        echo "Detected Recovery Tools:"
        echo "-----------------------"
        if [ -n "$detected_tools" ]; then
            for tool in $detected_tools; do
                echo "✓ $tool"
            done
        else
            echo "No additional recovery tools detected"
        fi
        echo ""
        
        echo "Compatibility Assessment:"
        echo "------------------------"
        local compat_result=$(check_compatibility "$detected_tools")
        echo "$compat_result"
        echo ""
        
        echo "Integration Status:"
        echo "------------------"
        if [ -d "$BASE_DIR/hooks" ]; then
            echo "✓ Integration hooks created"
            echo "✓ TWRP hook available"
            echo "✓ ADB interface available"
            echo "✓ Magisk integration guide available"
        else
            echo "✗ Integration hooks not created"
        fi
        echo ""
        
        echo "Recommendations:"
        echo "---------------"
        case "$compat_result" in
            "COMPATIBLE")
                echo "✓ All tools are compatible"
                echo "✓ No action required"
                ;;
            "COMPATIBLE_WITH_WARNINGS"*)
                echo "⚠ Compatible with warnings"
                echo "⚠ Monitor system stability"
                echo "⚠ Consider disabling conflicting features"
                ;;
            "CONFLICTS"*)
                echo "✗ Conflicts detected"
                echo "✗ Disable conflicting modules"
                echo "✗ Use selective recovery mode"
                ;;
        esac
        
        echo ""
        echo "Integration Commands:"
        echo "--------------------"
        echo "ADB Interface: adb shell sh $MODDIR/integration_helper.sh adb_menu"
        echo "Status Check: sh $MODDIR/action.sh"
        echo "Quick Test: sh $MODDIR/auto_recovery_test.sh quick"
        echo "Health Check: sh $MODDIR/health_monitor.sh monitor"
        
    } > "$report_file"
    
    log_message "INFO" "Integration report generated: $report_file"
    echo "$report_file"
}

# ADB menu interface
adb_menu() {
    echo "Anti-Bootloop KSU Module - ADB Interface"
    echo "========================================"
    echo "Author: @overspend1/Wiktor"
    echo ""
    
    # Quick status
    echo "Quick Status:"
    echo "-------------"
    local boot_count=$(cat "$BOOT_COUNT_FILE" 2>/dev/null || echo "0")
    local recovery_state=$(cat "$BASE_DIR/recovery_state" 2>/dev/null || echo "normal")
    local safe_mode=$([ -f "$BASE_DIR/safe_mode_active" ] && echo "Active" || echo "Inactive")
    
    echo "Boot Count: $boot_count"
    echo "Recovery State: $recovery_state"
    echo "Safe Mode: $safe_mode"
    echo "Module Status: $([ -f "$EMERGENCY_DISABLE_FILE" ] && echo "Disabled" || echo "Active")"
    echo ""
    
    echo "Available Commands:"
    echo "1. Full action menu"
    echo "2. Create backup"
    echo "3. Health check"
    echo "4. Run tests"
    echo "5. View logs"
    echo "6. Integration report"
    echo "0. Exit"
    echo ""
    
    read -p "Select option [0-6]: " choice
    
    case "$choice" in
        1)
            sh "$MODDIR/action.sh"
            ;;
        2)
            sh "$MODDIR/backup_manager.sh" create_backup "adb_$(date '+%Y%m%d_%H%M%S')" "ADB backup"
            ;;
        3)
            sh "$MODDIR/health_monitor.sh" monitor
            ;;
        4)
            sh "$MODDIR/auto_recovery_test.sh" quick
            ;;
        5)
            tail -50 "$LOG_FILE" 2>/dev/null || echo "No logs available"
            ;;
        6)
            generate_integration_report
            cat "$BASE_DIR/integration_report.txt"
            ;;
        0)
            echo "Goodbye!"
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
}

# Auto-configure integration
auto_configure() {
    log_message "INFO" "Starting auto-configuration for detected tools"
    
    local detected=$(detect_recovery_tools)
    local compatibility=$(check_compatibility "$detected")
    
    echo "Auto-Configuration Results:"
    echo "=========================="
    echo "Detected tools:$detected"
    echo "Compatibility: $compatibility"
    
    # Create integration hooks
    create_integration_hooks
    
    # Generate report
    local report=$(generate_integration_report)
    echo "Integration report: $report"
    
    # Apply automatic configurations based on detected tools
    for tool in $detected; do
        case "$tool" in
            "Magisk")
                # Ensure our module loads early
                if [ -d "/data/adb/modules/anti_bootloop_advanced_ksu" ]; then
                    log_message "INFO" "Configuring for Magisk compatibility"
                fi
                ;;
            "OTHER_BOOTLOOP_MODULES")
                # Adjust our behavior to be less aggressive
                log_message "WARN" "Other bootloop modules detected - adjusting strategy"
                sed -i 's/RECOVERY_STRATEGY=progressive/RECOVERY_STRATEGY=conservative/' "$CONFIG_FILE" 2>/dev/null
                ;;
        esac
    done
    
    log_message "INFO" "Auto-configuration completed"
}

# Command line interface
case "$1" in
    "detect")
        detect_recovery_tools
        ;;
    "compatibility")
        local tools=$(cat "$DETECTED_TOOLS" 2>/dev/null || detect_recovery_tools)
        check_compatibility "$tools"
        ;;
    "hooks")
        create_integration_hooks
        ;;
    "report")
        generate_integration_report
        cat "$BASE_DIR/integration_report.txt"
        ;;
    "adb_menu")
        adb_menu
        ;;
    "auto")
        auto_configure
        ;;
    *)
        echo "Advanced Anti-Bootloop KSU - Integration Helper"
        echo "Author: @overspend1/Wiktor"
        echo ""
        echo "Usage: $0 {detect|compatibility|hooks|report|adb_menu|auto}"
        echo ""
        echo "Commands:"
        echo "  detect        - Detect other recovery tools"
        echo "  compatibility - Check compatibility with detected tools"
        echo "  hooks         - Create integration hooks for other tools"
        echo "  report        - Generate full integration report"
        echo "  adb_menu      - Interactive ADB interface"
        echo "  auto          - Auto-configure integration"
        echo ""
        echo "Integration files will be created in: $BASE_DIR/hooks/"
        exit 1
        ;;
esac