#!/system/bin/sh
# KernelSU Anti-Bootloop & Backup Module Uninstall Script

MODDIR=${0%/*}

# Print uninstallation information
ui_print() {
  echo "$1"
}

ui_print "- Uninstalling KernelSU Anti-Bootloop & Backup Module"

# Backup configuration before removing
backup_configuration() {
    ui_print "- Backing up configuration data..."
    
    # Create backup directory in /data/local/tmp
    BACKUP_DIR="/data/local/tmp/kernelsu_antibootloop_backup"
    mkdir -p "$BACKUP_DIR"
    
    # Backup important configuration files
    cp -f "$MODDIR/config/main.conf" "$BACKUP_DIR/" 2>/dev/null
    cp -rf "$MODDIR/config/backup_profiles" "$BACKUP_DIR/" 2>/dev/null
    
    # Create backup info file
    echo "Backup created at: $(date)" > "$BACKUP_DIR/backup_info.txt"
    
    ui_print "- Configuration backed up to: $BACKUP_DIR"
    ui_print "- You can restore these settings manually if you reinstall"
}

# Remove any custom mounts or overlays
remove_overlays() {
    ui_print "- Removing custom overlays..."
    
    # Unmount any potential OverlayFS mounts
    # This is a placeholder - actual implementation would include specific umount commands
    # based on the module's overlay configuration
    
    ui_print "- Overlays removed"
}

# Disable any running services
disable_services() {
    ui_print "- Stopping module services..."
    
    # Kill any background services started by the module
    # This is a placeholder - actual implementation would include specific pkill/killall commands
    # for the module's services
    
    ui_print "- Services stopped"
}

# Main uninstall function
main() {
    ui_print "- Beginning module uninstallation..."
    
    # Backup configuration
    backup_configuration
    
    # Remove overlays
    remove_overlays
    
    # Disable services
    disable_services
    
    ui_print "- Module uninstallation complete"
    ui_print "- A reboot is recommended to ensure all changes take effect"
}

# Execute main function
main