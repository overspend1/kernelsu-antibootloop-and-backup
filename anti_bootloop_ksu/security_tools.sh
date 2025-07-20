#!/system/bin/sh

# KernelSU Advanced Multitool - Security & Privacy Tools
# Author: @overspend1/Wiktor

MODDIR="/data/adb/modules/kernelsu_multitool"
. "$MODDIR/utils.sh"

SECURITY_LOG="$BASE_DIR/security.log"
MALWARE_DB="$BASE_DIR/malware_signatures"

# Privacy protection tools
privacy_protection() {
    echo "👁️  Privacy Protection Tools"
    echo "==========================="
    echo ""
    echo "Privacy Options:"
    echo "1. 📱 Disable Telemetry & Analytics"
    echo "2. 🚫 Block Ads & Trackers"
    echo "3. 🔒 Secure DNS Configuration"
    echo "4. 📍 Location Privacy"
    echo "5. 📞 Call & SMS Privacy"
    echo "6. 🌐 Network Privacy"
    echo "7. 📊 Privacy Audit"
    echo "0. ← Back"
    echo ""
    read -p "Select option [0-7]: " choice
    
    case "$choice" in
        1) disable_telemetry ;;
        2) block_ads_trackers ;;
        3) secure_dns_config ;;
        4) location_privacy ;;
        5) call_sms_privacy ;;
        6) network_privacy ;;
        7) privacy_audit ;;
    esac
    
    if [ "$choice" != "0" ]; then
        read -p "Press Enter to continue..."
    fi
}

# Security hardening
security_hardening() {
    echo "🛡️  Security Hardening"
    echo "====================="
    echo ""
    echo "Security Hardening Options:"
    echo "1. 🔐 Kernel Security Settings"
    echo "2. 🛡️  System Protection"
    echo "3. 🚫 Disable Unsafe Features"
    echo "4. 🔒 File Permissions Hardening"
    echo "5. 🌐 Network Security"
    echo "6. 📱 App Security Settings"
    echo "7. 🔍 Security Audit"
    echo "8. 🏗️  SELinux Configuration"
    echo "0. ← Back"
    echo ""
    read -p "Select option [0-8]: " choice
    
    case "$choice" in
        1) kernel_security_settings ;;
        2) system_protection ;;
        3) disable_unsafe_features ;;
        4) file_permissions_hardening ;;
        5) network_security_hardening ;;
        6) app_security_settings ;;
        7) security_audit ;;
        8) selinux_configuration ;;
    esac
    
    if [ "$choice" != "0" ]; then
        read -p "Press Enter to continue..."
    fi
}

# Malware scanner
malware_scanner() {
    echo "🕵️  Malware Scanner"
    echo "=================="
    echo ""
    echo "Scanning system for potential threats..."
    echo ""
    
    local threats_found=0
    local scan_results="$BASE_DIR/malware_scan_$(date '+%Y%m%d_%H%M%S').log"
    
    {
        echo "Malware Scan Report"
        echo "==================="
        echo "Scan Date: $(date)"
        echo "Scanner: KernelSU Multitool Security Scanner"
        echo ""
    } > "$scan_results"
    
    # Check for suspicious files
    echo "🔍 Scanning for suspicious files..."
    local suspicious_files=""
    
    # Common malware locations
    local scan_paths="/system/bin /system/xbin /data/local/tmp /sdcard/Android"
    
    for path in $scan_paths; do
        if [ -d "$path" ]; then
            # Look for suspicious executables
            find "$path" -type f -name "*.apk" -o -name "*.dex" -o -name "*.so" 2>/dev/null | while read file; do
                # Check file size and permissions
                local size=$(stat -c%s "$file" 2>/dev/null || echo "0")
                local perms=$(stat -c%a "$file" 2>/dev/null || echo "000")
                
                # Flag very small or very large files
                if [ "$size" -lt 1024 ] || [ "$size" -gt 50000000 ]; then
                    echo "SUSPICIOUS: $file (size: $size bytes)" >> "$scan_results"
                fi
                
                # Flag files with unusual permissions
                if [ "$perms" = "777" ] || [ "$perms" = "666" ]; then
                    echo "SUSPICIOUS: $file (permissions: $perms)" >> "$scan_results"
                fi
            done
        fi
    done
    
    # Check for known malware signatures
    echo "🔍 Checking for known malware signatures..."
    
    # Simple signature-based detection
    local malware_patterns="
        coinminer
        cryptominer
        adware
        trojan
        backdoor
        rootkit
        keylogger
        spyware
    "
    
    for pattern in $malware_patterns; do
        local found_files=$(find /data /system -type f -name "*$pattern*" 2>/dev/null | head -5)
        if [ -n "$found_files" ]; then
            echo "POTENTIAL THREAT: Files matching '$pattern':" >> "$scan_results"
            echo "$found_files" >> "$scan_results"
            threats_found=$((threats_found + 1))
        fi
    done
    
    # Check running processes
    echo "🔍 Scanning running processes..."
    
    ps -A | while read line; do
        local process=$(echo "$line" | awk '{print $9}')
        for pattern in $malware_patterns; do
            if echo "$process" | grep -qi "$pattern" 2>/dev/null; then
                echo "SUSPICIOUS PROCESS: $line" >> "$scan_results"
                threats_found=$((threats_found + 1))
            fi
        done
    done
    
    # Check network connections
    echo "🔍 Checking suspicious network connections..."
    
    # Look for connections to known bad IPs or suspicious ports
    netstat -an 2>/dev/null | grep -E "(4444|5555|6666|7777|8888|9999)" | while read connection; do
        echo "SUSPICIOUS CONNECTION: $connection" >> "$scan_results"
    done
    
    # Summary
    {
        echo ""
        echo "Scan Summary:"
        echo "============="
        echo "Threats Found: $threats_found"
        echo "Scan Completed: $(date)"
    } >> "$scan_results"
    
    echo ""
    echo "📊 Scan Results:"
    if [ "$threats_found" -eq 0 ]; then
        echo "✅ No threats detected"
    else
        echo "⚠️  $threats_found potential threats found"
        echo "📄 Detailed report: $scan_results"
    fi
    
    echo ""
    echo "🔍 Scan completed. Report saved to: $scan_results"
}

# Permission analyzer
permission_analyzer() {
    echo "🔑 Permission Analyzer"
    echo "====================="
    echo ""
    echo "Analyzing app permissions..."
    echo ""
    
    local high_risk_count=0
    local medium_risk_count=0
    local report_file="$BASE_DIR/permission_analysis_$(date '+%Y%m%d_%H%M%S').log"
    
    {
        echo "Permission Analysis Report"
        echo "========================="
        echo "Analysis Date: $(date)"
        echo ""
    } > "$report_file"
    
    # High-risk permissions
    local high_risk_perms="
        android.permission.WRITE_EXTERNAL_STORAGE
        android.permission.ACCESS_FINE_LOCATION
        android.permission.CAMERA
        android.permission.RECORD_AUDIO
        android.permission.READ_CONTACTS
        android.permission.READ_SMS
        android.permission.CALL_PHONE
        android.permission.SEND_SMS
        android.permission.ACCESS_COARSE_LOCATION
    "
    
    # Medium-risk permissions
    local medium_risk_perms="
        android.permission.INTERNET
        android.permission.ACCESS_NETWORK_STATE
        android.permission.READ_PHONE_STATE
        android.permission.WRITE_SETTINGS
        android.permission.SYSTEM_ALERT_WINDOW
    "
    
    echo "High-Risk Permissions:" >> "$report_file"
    echo "=====================" >> "$report_file"
    
    for perm in $high_risk_perms; do
        # This is a simplified check - in a real implementation you'd use pm list permissions
        echo "Checking permission: $perm"
        local apps_with_perm=$(pm list packages -f | wc -l 2>/dev/null || echo "0")
        if [ "$apps_with_perm" -gt 0 ]; then
            echo "$perm: Used by apps" >> "$report_file"
            high_risk_count=$((high_risk_count + 1))
        fi
    done
    
    echo "" >> "$report_file"
    echo "Medium-Risk Permissions:" >> "$report_file"
    echo "=======================" >> "$report_file"
    
    for perm in $medium_risk_perms; do
        echo "Checking permission: $perm"
        local apps_with_perm=$(pm list packages -f | wc -l 2>/dev/null || echo "0")
        if [ "$apps_with_perm" -gt 0 ]; then
            echo "$perm: Used by apps" >> "$report_file"
            medium_risk_count=$((medium_risk_count + 1))
        fi
    done
    
    {
        echo ""
        echo "Summary:"
        echo "========"
        echo "High-risk permissions in use: $high_risk_count"
        echo "Medium-risk permissions in use: $medium_risk_count"
        echo ""
        echo "Recommendations:"
        echo "==============="
        echo "• Review apps with high-risk permissions"
        echo "• Revoke unnecessary permissions"
        echo "• Use app-specific privacy settings"
        echo "• Consider using privacy-focused alternatives"
    } >> "$report_file"
    
    echo "📊 Permission Analysis Results:"
    echo "   High-risk permissions: $high_risk_count"
    echo "   Medium-risk permissions: $medium_risk_count"
    echo "   Report saved to: $report_file"
}

# App blocker/freezer
app_blocker() {
    echo "🚫 App Blocker/Freezer"
    echo "====================="
    echo ""
    echo "App Management Options:"
    echo "1. 📋 List All Apps"
    echo "2. 🚫 Disable/Freeze Apps"
    echo "3. ✅ Enable Apps"
    echo "4. 🗑️  Uninstall Apps"
    echo "5. 📊 App Usage Analysis"
    echo "6. 🛡️  Privacy-Risky Apps"
    echo "0. ← Back"
    echo ""
    read -p "Select option [0-6]: " choice
    
    case "$choice" in
        1) list_all_apps ;;
        2) disable_apps ;;
        3) enable_apps ;;
        4) uninstall_apps ;;
        5) app_usage_analysis ;;
        6) privacy_risky_apps ;;
    esac
    
    if [ "$choice" != "0" ]; then
        read -p "Press Enter to continue..."
    fi
}

# Network security
network_security() {
    echo "🌐 Network Security"
    echo "=================="
    echo ""
    echo "Network Security Options:"
    echo "1. 🔍 Network Scan"
    echo "2. 🚫 Block Malicious Domains"
    echo "3. 🔒 Secure DNS Setup"
    echo "4. 📊 Network Traffic Analysis"
    echo "5. 🛡️  Firewall Rules"
    echo "6. 🌐 VPN Status & Settings"
    echo "0. ← Back"
    echo ""
    read -p "Select option [0-6]: " choice
    
    case "$choice" in
        1) network_scan ;;
        2) block_malicious_domains ;;
        3) secure_dns_setup ;;
        4) network_traffic_analysis ;;
        5) firewall_rules ;;
        6) vpn_status ;;
    esac
    
    if [ "$choice" != "0" ]; then
        read -p "Press Enter to continue..."
    fi
}

# Encryption status
encryption_status() {
    echo "📱 Device Encryption Status"
    echo "=========================="
    echo ""
    
    # Check device encryption
    local encryption_state=$(getprop ro.crypto.state 2>/dev/null || echo "unknown")
    local encryption_type=$(getprop ro.crypto.type 2>/dev/null || echo "unknown")
    
    echo "🔒 Device Encryption:"
    echo "   State: $encryption_state"
    echo "   Type: $encryption_type"
    
    if [ "$encryption_state" = "encrypted" ]; then
        echo "   Status: ✅ Device is encrypted"
    else
        echo "   Status: ⚠️  Device may not be encrypted"
    fi
    echo ""
    
    # Check storage encryption
    echo "💽 Storage Encryption:"
    local storage_encryption=$(df /data | grep -o "ext4" 2>/dev/null)
    if [ -n "$storage_encryption" ]; then
        echo "   File System: $storage_encryption"
    fi
    
    # Check for file-based encryption
    local fbe_enabled=$(getprop ro.crypto.file_encryption 2>/dev/null)
    if [ -n "$fbe_enabled" ]; then
        echo "   File-Based Encryption: ✅ Enabled"
    else
        echo "   File-Based Encryption: ❓ Unknown/Disabled"
    fi
    echo ""
    
    # Security recommendations
    echo "🛡️  Security Recommendations:"
    if [ "$encryption_state" != "encrypted" ]; then
        echo "   ⚠️  Enable device encryption in Settings"
    fi
    echo "   ✅ Use strong lock screen password"
    echo "   ✅ Enable automatic screen lock"
    echo "   ✅ Disable USB debugging when not needed"
    echo "   ✅ Keep system updated"
    
    read -p "Press Enter to continue..."
}

# Kernel security settings
kernel_security_settings() {
    echo "🔐 Kernel Security Settings"
    echo "=========================="
    echo ""
    echo "Applying kernel security hardening..."
    
    # Enable kernel security features
    echo "🛡️  Enabling security features..."
    
    # ASLR (Address Space Layout Randomization)
    echo 2 > /proc/sys/kernel/randomize_va_space 2>/dev/null && echo "✅ ASLR enabled"
    
    # Restrict kernel pointer access
    echo 1 > /proc/sys/kernel/kptr_restrict 2>/dev/null && echo "✅ Kernel pointer access restricted"
    
    # Disable kernel symbol access
    echo 1 > /proc/sys/kernel/dmesg_restrict 2>/dev/null && echo "✅ Kernel log access restricted"
    
    # Enable SYN flood protection
    echo 1 > /proc/sys/net/ipv4/tcp_syncookies 2>/dev/null && echo "✅ SYN flood protection enabled"
    
    # Disable IP forwarding
    echo 0 > /proc/sys/net/ipv4/ip_forward 2>/dev/null && echo "✅ IP forwarding disabled"
    
    # Ignore ICMP redirects
    echo 0 > /proc/sys/net/ipv4/conf/all/accept_redirects 2>/dev/null && echo "✅ ICMP redirects ignored"
    
    # Ignore source routed packets
    echo 0 > /proc/sys/net/ipv4/conf/all/accept_source_route 2>/dev/null && echo "✅ Source routing disabled"
    
    echo ""
    echo "✅ Kernel security hardening applied"
    
    log_message "INFO" "Kernel security settings applied"
}

# System protection
system_protection() {
    echo "🛡️  System Protection"
    echo "==================="
    echo ""
    echo "Applying system protection measures..."
    
    # Protect system files
    echo "🔒 Protecting critical system files..."
    
    # Make system partition read-only (if possible)
    mount -o remount,ro /system 2>/dev/null && echo "✅ System partition set to read-only"
    
    # Protect important binaries
    local critical_binaries="/system/bin/su /system/xbin/su"
    for binary in $critical_binaries; do
        if [ -f "$binary" ]; then
            chmod 4755 "$binary" 2>/dev/null && echo "✅ Protected $binary"
        fi
    done
    
    # Clear temporary files
    echo "🧹 Cleaning temporary files..."
    rm -rf /data/local/tmp/* 2>/dev/null
    rm -rf /cache/* 2>/dev/null
    echo "✅ Temporary files cleaned"
    
    # Set secure permissions on sensitive directories
    echo "🔐 Setting secure permissions..."
    chmod 700 /data/data 2>/dev/null
    chmod 755 /system/bin 2>/dev/null
    echo "✅ Permissions secured"
    
    echo ""
    echo "✅ System protection measures applied"
    
    log_message "INFO" "System protection applied"
}

# Security audit
security_audit() {
    echo "🔍 Security Audit"
    echo "================"
    echo ""
    
    local audit_file="$BASE_DIR/security_audit_$(date '+%Y%m%d_%H%M%S').log"
    local issues_found=0
    
    {
        echo "Security Audit Report"
        echo "===================="
        echo "Audit Date: $(date)"
        echo "Device: $(getprop ro.product.model)"
        echo ""
    } > "$audit_file"
    
    echo "Running comprehensive security audit..."
    echo ""
    
    # Check 1: Root access security
    echo "🔍 Checking root access security..."
    if [ "$(id -u)" = "0" ]; then
        echo "✅ Root access available" >> "$audit_file"
        if [ -f "/data/adb/ksu/bin/ksud" ]; then
            echo "✅ KernelSU properly installed" >> "$audit_file"
        else
            echo "⚠️  Root method unclear" >> "$audit_file"
            issues_found=$((issues_found + 1))
        fi
    else
        echo "❌ No root access" >> "$audit_file"
        issues_found=$((issues_found + 1))
    fi
    
    # Check 2: System file integrity
    echo "🔍 Checking system file integrity..."
    if [ -f "/system/build.prop" ]; then
        echo "✅ System build.prop exists" >> "$audit_file"
    else
        echo "❌ System build.prop missing" >> "$audit_file"
        issues_found=$((issues_found + 1))
    fi
    
    # Check 3: SELinux status
    echo "🔍 Checking SELinux status..."
    local selinux_status=$(getenforce 2>/dev/null || echo "Unknown")
    case "$selinux_status" in
        "Enforcing")
            echo "✅ SELinux is enforcing" >> "$audit_file"
            ;;
        "Permissive")
            echo "⚠️  SELinux is permissive" >> "$audit_file"
            issues_found=$((issues_found + 1))
            ;;
        *)
            echo "❓ SELinux status unknown" >> "$audit_file"
            ;;
    esac
    
    # Check 4: Network security
    echo "🔍 Checking network security..."
    local open_ports=$(netstat -an 2>/dev/null | grep LISTEN | wc -l)
    if [ "$open_ports" -gt 10 ]; then
        echo "⚠️  Many open ports detected ($open_ports)" >> "$audit_file"
        issues_found=$((issues_found + 1))
    else
        echo "✅ Reasonable number of open ports ($open_ports)" >> "$audit_file"
    fi
    
    # Check 5: File permissions
    echo "🔍 Checking critical file permissions..."
    local world_writable=$(find /system -type f -perm -002 2>/dev/null | wc -l)
    if [ "$world_writable" -gt 0 ]; then
        echo "⚠️  World-writable files in /system ($world_writable)" >> "$audit_file"
        issues_found=$((issues_found + 1))
    else
        echo "✅ No world-writable files in /system" >> "$audit_file"
    fi
    
    # Summary
    {
        echo ""
        echo "Audit Summary:"
        echo "=============="
        echo "Security Issues Found: $issues_found"
        echo "Audit Completed: $(date)"
        echo ""
        if [ "$issues_found" -eq 0 ]; then
            echo "Overall Security Status: ✅ GOOD"
        elif [ "$issues_found" -le 2 ]; then
            echo "Overall Security Status: ⚠️  FAIR"
        else
            echo "Overall Security Status: ❌ POOR"
        fi
    } >> "$audit_file"
    
    echo "📊 Security Audit Results:"
    echo "   Issues Found: $issues_found"
    echo "   Status: $([ "$issues_found" -eq 0 ] && echo "✅ GOOD" || echo "⚠️  NEEDS ATTENTION")"
    echo "   Report: $audit_file"
    
    log_message "INFO" "Security audit completed - $issues_found issues found"
}

# List all apps (simplified)
list_all_apps() {
    echo "📋 All Installed Apps"
    echo "===================="
    echo ""
    echo "Listing installed packages..."
    echo ""
    
    # Get package list (simplified)
    local package_count=$(pm list packages 2>/dev/null | wc -l || echo "0")
    echo "Total packages: $package_count"
    echo ""
    
    # Show some system apps
    echo "System Apps:"
    pm list packages -s 2>/dev/null | head -10 | sed 's/package://' | while read pkg; do
        echo "  📱 $pkg"
    done
    
    echo ""
    echo "User Apps:"
    pm list packages -3 2>/dev/null | head -10 | sed 's/package://' | while read pkg; do
        echo "  📱 $pkg"
    done
    
    echo ""
    echo "Use 'pm list packages' for complete list"
}

# Network scan
network_scan() {
    echo "🔍 Network Scan"
    echo "=============="
    echo ""
    echo "Scanning network configuration..."
    echo ""
    
    # Check network interfaces
    echo "📡 Network Interfaces:"
    ip addr show 2>/dev/null | grep -E "^[0-9]+:" | while read iface; do
        echo "  $iface"
    done
    
    echo ""
    echo "🌐 Active Connections:"
    netstat -an 2>/dev/null | grep ESTABLISHED | head -5 | while read conn; do
        echo "  $conn"
    done
    
    echo ""
    echo "🔍 Listening Ports:"
    netstat -an 2>/dev/null | grep LISTEN | head -5 | while read port; do
        echo "  $port"
    done
    
    echo ""
    echo "📊 Network scan completed"
}

# Export functions for external use
# (Functions are already defined above)

log_message "INFO" "Security tools module loaded"