#!/system/bin/sh

##########################################################################################
#
# Advanced Anti-Bootloop KSU Module Installer
# Author: @overspend1/Wiktor
#
##########################################################################################

##########################################################################################
# Config Flags
##########################################################################################

# Set to true if you do *NOT* want Magisk to mount
# any files for you. Most modules would NOT want
# to set this flag to true
SKIPMOUNT=false

# Set to true if you need to load system.prop
PROPFILE=false

# Set to true if you need post-fs-data script
POSTFSDATA=true

# Set to true if you need late_start service script
LATESTARTSERVICE=true

##########################################################################################
# Replace list
##########################################################################################

# List all directories you want to directly replace in the system
# Check the documentations for more info why you would need this

# Construct your list in the following format
# This is an example
REPLACE_EXAMPLE="
/system/app/Youtube
/system/priv-app/SystemUI
/system/priv-app/Settings
/system/framework
"

# Construct your own list here
REPLACE=""

##########################################################################################
#
# Function Callbacks
#
# The following functions will be called by the installation framework.
# You do not have the ability to modify update-binary, the only way you can customize
# installation is through implementing these functions.
#
# When running bootloop fix, the installation framework will use the environment and
# functions you provided to set up the module. This is the reason why this entire
# script is sourced, not executed.
#
##########################################################################################

##########################################################################################
# Installation Message
##########################################################################################

# Set what the installer should show when installing your module

print_modname() {
  ui_print "=========================================="
  ui_print "  Advanced Anti-Bootloop KSU Module v2.0  "
  ui_print "=========================================="
  ui_print "Author: @overspend1/Wiktor"
  ui_print "Device: Redmi Note 13 Pro 5G (garnet)"
  ui_print "Purpose: Advanced bootloop protection"
  ui_print ""
}

##########################################################################################
# Pre-Installation
##########################################################################################

on_install() {
  # Device compatibility check
  DEVICE_NAME=$(getprop ro.product.device)
  DEVICE_BRAND=$(getprop ro.product.brand)
  ANDROID_VERSION=$(getprop ro.build.version.release)

  ui_print "Device Information:"
  ui_print "  Device: $DEVICE_NAME"
  ui_print "  Brand: $DEVICE_BRAND"
  ui_print "  Android: $ANDROID_VERSION"
  ui_print ""

  if [ "$DEVICE_NAME" != "garnet" ]; then
    ui_print "WARNING: Optimized for Redmi Note 13 Pro 5G"
    ui_print "Current device: $DEVICE_NAME"
    ui_print "Module should work but paths may differ!"
    ui_print ""
  fi

  # Advanced KernelSU detection
  KSU_VERSION="Unknown"
  if [ -f "/data/adb/ksu/bin/ksud" ]; then
    KSU_VERSION=$(cat /data/adb/ksu/version 2>/dev/null || echo "Unknown")
    ui_print "KernelSU detected: Version $KSU_VERSION"
  elif [ -f "/data/adb/ksud" ]; then
    ui_print "KernelSU detected: Legacy installation"
  else
    ui_print "ERROR: KernelSU not detected!"
    ui_print "This module requires KernelSU to function."
    ui_print "Please install KernelSU first."
    abort "Installation aborted - KernelSU required"
  fi
  ui_print ""

  ui_print "Installing advanced module files..."

  # Set permissions for all files
  set_perm_recursive $MODPATH 0 0 0755 0644

  # Set executable permissions for scripts
  set_perm $MODPATH/service.sh 0 0 0755
  set_perm $MODPATH/post-fs-data.sh 0 0 0755
  set_perm $MODPATH/utils.sh 0 0 0755
  set_perm $MODPATH/backup_manager.sh 0 0 0755
  set_perm $MODPATH/recovery_engine.sh 0 0 0755
  set_perm $MODPATH/webui_server.sh 0 0 0755
  set_perm $MODPATH/webui_manager.sh 0 0 0755
  set_perm $MODPATH/action.sh 0 0 0755
  set_perm $MODPATH/health_monitor.sh 0 0 0755
  set_perm $MODPATH/auto_recovery_test.sh 0 0 0755
  set_perm $MODPATH/integration_helper.sh 0 0 0755
  set_perm $MODPATH/webui/api/status.sh 0 0 0755
  set_perm $MODPATH/webui/action.php 0 0 0644
  set_perm $MODPATH/webui/ksu_webui.html 0 0 0644

  # Set config file permissions
  set_perm $MODPATH/config.conf 0 0 0644

  ui_print ""
  ui_print "Installation completed successfully!"
  ui_print ""
  ui_print "ADVANCED FEATURES:"
  ui_print "- KernelSU Manager action button (tap module for menu)"
  ui_print "- WebUI management interface (http://localhost:8888)"
  ui_print "- AI-powered bootloop prediction system"
  ui_print "- Real-time hardware health monitoring"
  ui_print "- Progressive recovery strategies"
  ui_print "- Multiple kernel backup slots with integrity checks"
  ui_print "- Safe mode and automatic module management"
  ui_print "- Comprehensive system testing and validation"
  ui_print "- Integration with TWRP, Magisk, and other tools"
  ui_print "- Detailed logging and telemetry collection"
  ui_print ""
  ui_print "ACCESS METHODS:"
  ui_print "- Action Button: Tap module in KernelSU Manager"
  ui_print "- WebUI: http://localhost:8888 (auto-starts on boot)"
  ui_print "- ADB: adb shell sh /data/adb/modules/anti_bootloop_advanced_ksu/action.sh"
  ui_print "- Terminal: su -c 'sh /data/adb/modules/anti_bootloop_advanced_ksu/action.sh'"
  ui_print ""
  ui_print "QUICK COMMANDS:"
  ui_print "- Health Check: sh health_monitor.sh monitor"
  ui_print "- System Test: sh auto_recovery_test.sh quick"
  ui_print "- Create Backup: sh backup_manager.sh create_backup"
  ui_print "- Integration: sh integration_helper.sh auto"
  ui_print ""
  ui_print "RECOVERY STRATEGIES:"
  ui_print "- Progressive: Escalating interventions (default)"
  ui_print "- Aggressive: Immediate kernel restore"
  ui_print "- Conservative: More cautious approach"
  ui_print ""
  ui_print "AUTHOR: @overspend1/Wiktor"
  ui_print "Reboot to activate advanced protection."
  ui_print "=========================================="
}

##########################################################################################
# Permissions
##########################################################################################

set_permissions() {
  # The following is the default rule, DO NOT remove
  set_perm_recursive $MODPATH 0 0 0755 0644

  # Set additional permissions here
  set_perm $MODPATH/service.sh 0 0 0755
  set_perm $MODPATH/post-fs-data.sh 0 0 0755
  set_perm $MODPATH/utils.sh 0 0 0755
  set_perm $MODPATH/backup_manager.sh 0 0 0755
  set_perm $MODPATH/recovery_engine.sh 0 0 0755
  set_perm $MODPATH/webui_server.sh 0 0 0755
  set_perm $MODPATH/webui_manager.sh 0 0 0755
  set_perm $MODPATH/action.sh 0 0 0755
  set_perm $MODPATH/health_monitor.sh 0 0 0755
  set_perm $MODPATH/auto_recovery_test.sh 0 0 0755
  set_perm $MODPATH/integration_helper.sh 0 0 0755
  set_perm $MODPATH/webui/api/status.sh 0 0 0755
}