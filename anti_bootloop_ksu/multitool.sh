#!/system/bin/sh

# KernelSU Advanced Multitool - Main Menu
# Author: @overspend1/Wiktor
# Comprehensive toolkit for KernelSU power users

MODDIR="/data/adb/modules/kernelsu_multitool"
. "$MODDIR/utils.sh"

# Main multitool menu
show_main_menu() {
    clear
    echo "=============================================="
    echo "🛠️  KernelSU Advanced Multitool v3.0"
    echo "=============================================="
    echo "Author: @overspend1/Wiktor"
    echo "The Ultimate KernelSU Toolkit"
    echo ""
    
    # Show quick system status
    local boot_count=$(cat "$BOOT_COUNT_FILE" 2>/dev/null || echo "0")
    local cpu_temp=$(get_cpu_temp)
    local available_ram=$(get_available_ram)
    local ksu_version=$(cat /data/adb/ksu/version 2>/dev/null || echo "Unknown")
    
    echo "📊 Quick Status:"
    echo "   KernelSU: $ksu_version | Boot Count: $boot_count"
    echo "   CPU: ${cpu_temp}°C | RAM: ${available_ram}MB"
    echo ""
    
    echo "🛠️  MAIN CATEGORIES:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "1. 🛡️  Recovery & Protection Tools"
    echo "2. ⚡ System Optimization & Performance"
    echo "3. 🔒 Security & Privacy Tools"
    echo "4. 📊 System Information & Diagnostics"
    echo "5. 📦 Module Management & Utilities"
    echo "6. 💾 Backup & Restore Tools"
    echo "7. 🔧 Developer & Debugging Tools"
    echo "8. ⚙️  Multitool Settings & Configuration"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "9. 📖 Help & Documentation"
    echo "0. ❌ Exit Multitool"
    echo ""
}

# Category 1: Recovery & Protection Tools
recovery_tools_menu() {
    while true; do
        clear
        echo "🛡️  RECOVERY & PROTECTION TOOLS"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "1. 📁 Kernel Backup Management"
        echo "2. 🔄 Bootloop Protection Status"
        echo "3. 🛡️  Safe Mode Controls"
        echo "4. 🚨 Emergency Recovery"
        echo "5. 🔮 Bootloop Risk Prediction"
        echo "6. 📋 Recovery Test Suite"
        echo "7. ⚙️  Recovery Strategy Settings"
        echo "8. 📊 Protection Health Report"
        echo "0. ← Back to Main Menu"
        echo ""
        read -p "Select option [0-8]: " choice
        
        case "$choice" in
            1) sh "$MODDIR/action.sh" backup_menu ;;
            2) show_bootloop_status ;;
            3) sh "$MODDIR/action.sh" safe_mode_menu ;;
            4) sh "$MODDIR/action.sh" emergency_menu ;;
            5) sh "$MODDIR/health_monitor.sh" predict ;;
            6) sh "$MODDIR/auto_recovery_test.sh" quick ;;
            7) sh "$MODDIR/action.sh" strategy_menu ;;
            8) sh "$MODDIR/health_monitor.sh" report ;;
            0) return ;;
            *) echo "Invalid option"; read -p "Press Enter to continue..." ;;
        esac
    done
}

# Category 2: System Optimization & Performance
optimization_menu() {
    while true; do
        clear
        echo "⚡ SYSTEM OPTIMIZATION & PERFORMANCE"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "1. 🧹 Memory Optimization"
        echo "2. 🚀 Performance Tuning"
        echo "3. 🔋 Battery Optimization"
        echo "4. 🌡️  Thermal Management"
        echo "5. 💽 Storage Optimization"
        echo "6. 🌐 Network Optimization"
        echo "7. 🎮 Gaming Mode Settings"
        echo "8. ⚡ Quick System Boost"
        echo "0. ← Back to Main Menu"
        echo ""
        read -p "Select option [0-8]: " choice
        
        case "$choice" in
            1) memory_optimization ;;
            2) performance_tuning ;;
            3) battery_optimization ;;
            4) thermal_management ;;
            5) storage_optimization ;;
            6) network_optimization ;;
            7) gaming_mode ;;
            8) quick_system_boost ;;
            0) return ;;
            *) echo "Invalid option"; read -p "Press Enter to continue..." ;;
        esac
    done
}

# Category 3: Security & Privacy Tools
security_menu() {
    while true; do
        clear
        echo "🔒 SECURITY & PRIVACY TOOLS"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "1. 🔐 Root Access Management"
        echo "2. 👁️  Privacy Protection"
        echo "3. 🛡️  Security Hardening"
        echo "4. 🕵️  Malware Scanner"
        echo "5. 🔑 Permission Analyzer"
        echo "6. 🚫 App Blocker/Freezer"
        echo "7. 🌐 Network Security"
        echo "8. 📱 Device Encryption Status"
        echo "0. ← Back to Main Menu"
        echo ""
        read -p "Select option [0-8]: " choice
        
        case "$choice" in
            1) root_access_management ;;
            2) privacy_protection ;;
            3) security_hardening ;;
            4) malware_scanner ;;
            5) permission_analyzer ;;
            6) app_blocker ;;
            7) network_security ;;
            8) encryption_status ;;
            0) return ;;
            *) echo "Invalid option"; read -p "Press Enter to continue..." ;;
        esac
    done
}

# Category 4: System Information & Diagnostics
diagnostics_menu() {
    while true; do
        clear
        echo "📊 SYSTEM INFORMATION & DIAGNOSTICS"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "1. 📱 Device Information"
        echo "2. 🔧 Hardware Diagnostics"
        echo "3. 💾 Memory & Storage Analysis"
        echo "4. ⚡ Performance Benchmarks"
        echo "5. 🌡️  Temperature Monitoring"
        echo "6. 🔋 Battery Health Analysis"
        echo "7. 📊 System Resource Monitor"
        echo "8. 📈 Performance History"
        echo "0. ← Back to Main Menu"
        echo ""
        read -p "Select option [0-8]: " choice
        
        case "$choice" in
            1) device_information ;;
            2) hardware_diagnostics ;;
            3) memory_storage_analysis ;;
            4) performance_benchmarks ;;
            5) temperature_monitoring ;;
            6) battery_health ;;
            7) resource_monitor ;;
            8) performance_history ;;
            0) return ;;
            *) echo "Invalid option"; read -p "Press Enter to continue..." ;;
        esac
    done
}

# Category 5: Module Management & Utilities
module_management_menu() {
    while true; do
        clear
        echo "📦 MODULE MANAGEMENT & UTILITIES"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "1. 📋 List All Modules"
        echo "2. ✅ Enable/Disable Modules"
        echo "3. ❌ Remove Modules"
        echo "4. 🔄 Update Module Status"
        echo "5. 🔍 Module Conflict Detection"
        echo "6. 📊 Module Performance Impact"
        echo "7. 📁 Module Backup/Restore"
        echo "8. 🧹 Clean Module Data"
        echo "0. ← Back to Main Menu"
        echo ""
        read -p "Select option [0-8]: " choice
        
        case "$choice" in
            1) list_all_modules ;;
            2) toggle_modules ;;
            3) remove_modules ;;
            4) update_module_status ;;
            5) sh "$MODDIR/integration_helper.sh" detect ;;
            6) module_performance_impact ;;
            7) module_backup_restore ;;
            8) clean_module_data ;;
            0) return ;;
            *) echo "Invalid option"; read -p "Press Enter to continue..." ;;
        esac
    done
}

# Memory optimization tools
memory_optimization() {
    echo "🧹 Memory Optimization Tools"
    echo "============================"
    echo ""
    echo "Current Memory Status:"
    
    # Get memory info
    local total_ram=$(grep "MemTotal:" /proc/meminfo | awk '{print int($2/1024)}')
    local available_ram=$(get_available_ram)
    local used_ram=$((total_ram - available_ram))
    local usage_percent=$(( (used_ram * 100) / total_ram ))
    
    echo "Total RAM: ${total_ram}MB"
    echo "Used RAM: ${used_ram}MB (${usage_percent}%)"
    echo "Available RAM: ${available_ram}MB"
    echo ""
    
    echo "Memory Optimization Options:"
    echo "1. 🧹 Clear System Caches"
    echo "2. 💨 Free Memory (Drop Caches)"
    echo "3. 🔄 Memory Compaction"
    echo "4. 🚫 Kill Background Apps"
    echo "5. ⚙️  Optimize Memory Settings"
    echo "6. 📊 Memory Usage Analysis"
    echo "0. ← Back"
    echo ""
    read -p "Select option [0-6]: " choice
    
    case "$choice" in
        1)
            echo "Clearing system caches..."
            echo 3 > /proc/sys/vm/drop_caches 2>/dev/null
            rm -rf /data/system/usagestats/* 2>/dev/null
            rm -rf /data/system/appusagestats/* 2>/dev/null
            echo "✅ System caches cleared"
            ;;
        2)
            echo "Freeing memory..."
            echo 1 > /proc/sys/vm/drop_caches 2>/dev/null
            echo 2 > /proc/sys/vm/drop_caches 2>/dev/null
            echo 3 > /proc/sys/vm/drop_caches 2>/dev/null
            echo "✅ Memory freed"
            ;;
        3)
            echo "Running memory compaction..."
            echo 1 > /proc/sys/vm/compact_memory 2>/dev/null
            echo "✅ Memory compaction completed"
            ;;
        4)
            echo "Killing background apps..."
            am kill-all 2>/dev/null
            echo "✅ Background apps terminated"
            ;;
        5)
            optimize_memory_settings
            ;;
        6)
            memory_usage_analysis
            ;;
    esac
    
    if [ "$choice" != "0" ]; then
        read -p "Press Enter to continue..."
    fi
}

# Performance tuning
performance_tuning() {
    echo "🚀 Performance Tuning"
    echo "===================="
    echo ""
    echo "Performance Tuning Options:"
    echo "1. ⚡ CPU Governor Optimization"
    echo "2. 📊 I/O Scheduler Optimization"
    echo "3. 🔧 Kernel Parameter Tuning"
    echo "4. 🎯 Process Priority Optimization"
    echo "5. 🌐 Network Performance Tuning"
    echo "6. 📱 UI Performance Boost"
    echo "7. 🎮 Gaming Performance Mode"
    echo "8. 📊 Performance Benchmark"
    echo "0. ← Back"
    echo ""
    read -p "Select option [0-8]: " choice
    
    case "$choice" in
        1) cpu_governor_optimization ;;
        2) io_scheduler_optimization ;;
        3) kernel_parameter_tuning ;;
        4) process_priority_optimization ;;
        5) network_performance_tuning ;;
        6) ui_performance_boost ;;
        7) gaming_performance_mode ;;
        8) performance_benchmark ;;
    esac
    
    if [ "$choice" != "0" ]; then
        read -p "Press Enter to continue..."
    fi
}

# Quick system boost
quick_system_boost() {
    echo "⚡ Quick System Boost"
    echo "==================="
    echo ""
    echo "Performing quick optimizations..."
    
    # Memory optimization
    echo "🧹 Clearing caches..."
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null
    
    # Kill unnecessary processes
    echo "🚫 Terminating background apps..."
    am kill-all 2>/dev/null
    
    # Optimize CPU
    echo "⚡ Optimizing CPU performance..."
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        [ -f "$cpu" ] && echo "performance" > "$cpu" 2>/dev/null
    done
    
    # Memory compaction
    echo "🔄 Running memory compaction..."
    echo 1 > /proc/sys/vm/compact_memory 2>/dev/null
    
    # I/O optimization
    echo "💽 Optimizing I/O scheduler..."
    for queue in /sys/block/*/queue/scheduler; do
        [ -f "$queue" ] && echo "deadline" > "$queue" 2>/dev/null
    done
    
    # Network optimization
    echo "🌐 Optimizing network..."
    echo 1 > /proc/sys/net/ipv4/tcp_window_scaling 2>/dev/null
    echo 1 > /proc/sys/net/ipv4/tcp_timestamps 2>/dev/null
    
    echo ""
    echo "✅ Quick system boost completed!"
    echo "💡 System should feel more responsive now"
    
    read -p "Press Enter to continue..."
}

# Device information
device_information() {
    echo "📱 Device Information"
    echo "==================="
    echo ""
    
    # Basic device info
    echo "🏷️  Device Details:"
    echo "   Model: $(getprop ro.product.model)"
    echo "   Brand: $(getprop ro.product.brand)"
    echo "   Device: $(getprop ro.product.device)"
    echo "   Board: $(getprop ro.product.board)"
    echo "   Manufacturer: $(getprop ro.product.manufacturer)"
    echo ""
    
    # System info
    echo "🤖 System Information:"
    echo "   Android Version: $(getprop ro.build.version.release)"
    echo "   API Level: $(getprop ro.build.version.sdk)"
    echo "   Build ID: $(getprop ro.build.id)"
    echo "   Security Patch: $(getprop ro.build.version.security_patch)"
    echo "   Kernel: $(uname -r)"
    echo ""
    
    # KernelSU info
    echo "🔧 KernelSU Information:"
    local ksu_version=$(cat /data/adb/ksu/version 2>/dev/null || echo "Unknown")
    echo "   Version: $ksu_version"
    echo "   Manager Installed: $([ -d "/data/data/me.weishu.kernelsu" ] && echo "Yes" || echo "No")"
    
    # Hardware info
    echo ""
    echo "💻 Hardware Information:"
    echo "   CPU: $(cat /proc/cpuinfo | grep "Hardware" | cut -d':' -f2 | head -1 | sed 's/^ *//')"
    echo "   CPU Cores: $(nproc)"
    echo "   CPU Architecture: $(uname -m)"
    
    # Memory info
    local total_ram=$(grep "MemTotal:" /proc/meminfo | awk '{print int($2/1024)}')
    echo "   Total RAM: ${total_ram}MB"
    
    # Storage info
    local storage_total=$(df /data | tail -1 | awk '{print int($2/1024)}')
    local storage_used=$(df /data | tail -1 | awk '{print int($3/1024)}')
    local storage_free=$(df /data | tail -1 | awk '{print int($4/1024)}')
    echo "   Storage Total: ${storage_total}MB"
    echo "   Storage Used: ${storage_used}MB"
    echo "   Storage Free: ${storage_free}MB"
    
    read -p "Press Enter to continue..."
}

# Root access management
root_access_management() {
    echo "🔐 Root Access Management"
    echo "========================"
    echo ""
    echo "Root Status Information:"
    echo "   KernelSU Status: $([ -f "/data/adb/ksu/bin/ksud" ] && echo "Active" || echo "Inactive")"
    echo "   Root Shell Access: $([ "$(id -u)" = "0" ] && echo "Granted" || echo "Denied")"
    echo ""
    
    echo "Root Management Options:"
    echo "1. 📋 List Apps with Root Access"
    echo "2. 🚫 Revoke App Root Access"
    echo "3. ✅ Grant App Root Access"
    echo "4. 📊 Root Access Logs"
    echo "5. ⚙️  Root Settings"
    echo "0. ← Back"
    echo ""
    read -p "Select option [0-5]: " choice
    
    case "$choice" in
        1) list_root_apps ;;
        2) revoke_root_access ;;
        3) grant_root_access ;;
        4) root_access_logs ;;
        5) root_settings ;;
    esac
    
    if [ "$choice" != "0" ]; then
        read -p "Press Enter to continue..."
    fi
}

# List all modules
list_all_modules() {
    echo "📋 All KernelSU Modules"
    echo "======================"
    echo ""
    
    if [ ! -d "/data/adb/modules" ]; then
        echo "No modules directory found"
        return
    fi
    
    local module_count=0
    local enabled_count=0
    local disabled_count=0
    
    for module_dir in /data/adb/modules/*; do
        if [ -d "$module_dir" ]; then
            local module_name=$(basename "$module_dir")
            local module_prop="$module_dir/module.prop"
            
            if [ -f "$module_prop" ]; then
                module_count=$((module_count + 1))
                
                local name=$(grep "^name=" "$module_prop" | cut -d'=' -f2- 2>/dev/null || echo "Unknown")
                local version=$(grep "^version=" "$module_prop" | cut -d'=' -f2- 2>/dev/null || echo "Unknown")
                local author=$(grep "^author=" "$module_prop" | cut -d'=' -f2- 2>/dev/null || echo "Unknown")
                
                if [ -f "$module_dir/disable" ] || [ -f "$module_dir/remove" ]; then
                    echo "❌ $name"
                    disabled_count=$((disabled_count + 1))
                else
                    echo "✅ $name"
                    enabled_count=$((enabled_count + 1))
                fi
                
                echo "   ID: $module_name"
                echo "   Version: $version"
                echo "   Author: $author"
                echo ""
            fi
        fi
    done
    
    echo "Summary:"
    echo "   Total Modules: $module_count"
    echo "   Enabled: $enabled_count"
    echo "   Disabled: $disabled_count"
    
    read -p "Press Enter to continue..."
}

# Main menu loop
main_menu() {
    while true; do
        show_main_menu
        read -p "Enter your choice [0-9]: " choice
        
        case "$choice" in
            1) recovery_tools_menu ;;
            2) optimization_menu ;;
            3) security_menu ;;
            4) diagnostics_menu ;;
            5) module_management_menu ;;
            6) backup_restore_menu ;;
            7) developer_tools_menu ;;
            8) multitool_settings ;;
            9) show_help ;;
            0) echo "Thank you for using KernelSU Advanced Multitool!"; exit 0 ;;
            *) echo "Invalid choice"; read -p "Press Enter to continue..." ;;
        esac
    done
}

# Show help
show_help() {
    echo "📖 KernelSU Advanced Multitool - Help"
    echo "====================================="
    echo ""
    echo "🛠️  ABOUT:"
    echo "KernelSU Advanced Multitool is a comprehensive toolkit designed"
    echo "for KernelSU power users. It combines bootloop protection,"
    echo "system optimization, security tools, and advanced diagnostics"
    echo "into one powerful module."
    echo ""
    echo "🎯 MAIN FEATURES:"
    echo "• Advanced bootloop protection with AI prediction"
    echo "• System optimization and performance tuning"
    echo "• Security and privacy protection tools"
    echo "• Comprehensive system diagnostics"
    echo "• Module management utilities"
    echo "• Backup and restore functionality"
    echo "• Developer debugging tools"
    echo ""
    echo "📞 SUPPORT:"
    echo "Author: @overspend1/Wiktor"
    echo "Version: 3.0"
    echo ""
    echo "🔧 QUICK ACCESS:"
    echo "Action Button: Tap module in KernelSU Manager"
    echo "Terminal: su -c 'sh /data/adb/modules/kernelsu_multitool/multitool.sh'"
    echo "ADB: adb shell sh /data/adb/modules/kernelsu_multitool/multitool.sh"
    echo ""
    
    read -p "Press Enter to continue..."
}

# Initialize and start
log_message "INFO" "KernelSU Advanced Multitool accessed"
main_menu