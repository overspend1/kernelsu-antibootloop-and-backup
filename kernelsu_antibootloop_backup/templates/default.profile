# KernelSU Anti-Bootloop Backup Default Profile
# This is a template for creating backup profiles

# Profile metadata
name=default
description=Default backup profile for essential system files
author=OverModules
version=1.0

# Backup settings
compression=true
encryption=false
incremental=false

# Backup items - one per line
# Format: type:path:options
# Types: file, dir, app, data
# Options: comma-separated list of options specific to the type

# System configuration files
file:/system/build.prop:critical
file:/system/etc/hosts:optional
dir:/system/etc/permissions:critical

# App data to backup (package names)
app:com.android.settings:data
app:com.google.android.gms:data,cache

# Custom directories
dir:/data/local/tmp:optional
dir:/data/misc:critical

# Exclusions - paths to exclude from backup
# Format: exclude:path
exclude:/data/local/tmp/cache
exclude:/data/misc/tempfiles

# Post-backup commands to run
# Format: command:command_to_run
command:sync
command:echo "Backup completed at $(date)" >> /data/local/tmp/backup_log.txt