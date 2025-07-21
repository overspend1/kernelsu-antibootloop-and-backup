# KernelSU Anti-Bootloop Backup System

## Overview

This document provides a comprehensive guide to the KernelSU Anti-Bootloop Backup System, a robust and secure backup solution for Android devices using KernelSU. The system provides block-level differential backups with compression, encryption, and flexible storage options.

## Architecture

The backup system follows a modular architecture with the following key components:

```
┌──────────────────────────────────────────────────────┐
│                  Integration Layer                   │
│           (backup-integration.sh interface)          │
├──────────┬───────────┬────────────┬─────────────────┤
│ Partition│ Diff      │ Encryption │ Storage         │
│ Manager  │ Engine    │ Framework  │ Manager         │
├──────────┼───────────┼────────────┼─────────────────┤
│          │           │            │ Backup          │
│          │           │            │ Scheduler       │
└──────────┴───────────┴────────────┴─────────────────┘
```

### Components

1. **Partition Management System** (`partition-manager.sh`)
   - A/B partition scheme detection and handling
   - Block-level access to device partitions
   - Partition snapshot management for point-in-time recovery

2. **Differential Backup Core** (`diff-engine.sh`)
   - Binary diffing algorithms to identify changed blocks
   - Multi-algorithm compression (gzip, bzip2, xz, lz4)
   - Content-aware deduplication using SHA-256 hashing

3. **Encryption & Security Framework** (`backup-encryption.sh`)
   - Hybrid cryptography (RSA-4096 + AES-256-GCM)
   - Secure key storage with hardware-backed options
   - Integrity verification with HMAC

4. **Backup Storage & Retrieval** (`storage-manager.sh`)
   - Modular storage adapters (local, SD card, USB, network)
   - Versioned metadata repository
   - Phased restoration engine with integrity checks

5. **Backup Scheduling and Automation** (`backup-scheduler.sh`)
   - Time and event-based scheduling
   - Configurable backup policies and retention rules
   - Notification system for backup status

6. **Integration Layer** (`backup-integration.sh`)
   - Unified API for all backup operations
   - Centralized logging and error handling
   - Consistent command-line interface

## Installation

The KernelSU Anti-Bootloop Backup System is installed as a KernelSU module. Installation steps:

1. Flash the module ZIP file via KernelSU or TWRP
2. Reboot the device
3. Configure backup settings via the WebUI or command-line

## Usage

### Command-Line Interface

The backup system provides a comprehensive command-line interface via the `backup-integration.sh` script.

```bash
# Initialize all backup components
sh /data/adb/modules/kernelsu_antibootloop_backup/scripts/backup-integration.sh init

# Create a full system backup
sh /data/adb/modules/kernelsu_antibootloop_backup/scripts/backup-integration.sh backup-full "My backup" local true

# Create an app backup
sh /data/adb/modules/kernelsu_antibootloop_backup/scripts/backup-integration.sh backup-app "com.example.app1,com.example.app2" "My app backup" local

# Create a settings backup
sh /data/adb/modules/kernelsu_antibootloop_backup/scripts/backup-integration.sh backup-settings "My settings backup" local

# Restore from a backup
sh /data/adb/modules/kernelsu_antibootloop_backup/scripts/backup-integration.sh restore full_20250720_123456 "system,apps,settings"

# List all backups
sh /data/adb/modules/kernelsu_antibootloop_backup/scripts/backup-integration.sh list-backups

# Get details for a backup
sh /data/adb/modules/kernelsu_antibootloop_backup/scripts/backup-integration.sh backup-details full_20250720_123456

# Delete a backup
sh /data/adb/modules/kernelsu_antibootloop_backup/scripts/backup-integration.sh delete-backup full_20250720_123456

# List all backup schedules
sh /data/adb/modules/kernelsu_antibootloop_backup/scripts/backup-integration.sh list-schedules

# Create a backup schedule
sh /data/adb/modules/kernelsu_antibootloop_backup/scripts/backup-integration.sh create-schedule "Daily" "daily" "default"

# Check and run due schedules
sh /data/adb/modules/kernelsu_antibootloop_backup/scripts/backup-integration.sh check-schedules time
```

### Web User Interface

The backup system includes a web-based user interface accessible at `http://localhost:8080` when enabled.

1. Enable the WebUI:
   ```bash
   sh /data/adb/modules/kernelsu_antibootloop_backup/scripts/webui-server.sh start
   ```

2. Navigate to `http://localhost:8080` in a browser on the device or via ADB port forwarding:
   ```bash
   adb forward tcp:8080 tcp:8080
   ```

3. Use the web interface to manage backups, schedules, and settings.

## Backup Types

The system supports three primary backup types:

1. **Full System Backup**
   - Backs up critical partitions (boot, system, etc.)
   - Stores key system directories and files
   - Full or differential backup options

2. **App Backup**
   - Backs up selected application APKs and data
   - Supports backing up multiple apps in one operation

3. **Settings Backup**
   - Backs up Android system settings
   - Stores configuration files like Wi-Fi and APN settings

## Storage Adapters

The backup system supports multiple storage destinations through its adapter system:

1. **Local Storage** (`local`)
   - Stores backups in the device's internal storage
   - Default path: `/data/adb/modules/kernelsu_antibootloop_backup/backups`

2. **External Storage** (`external`)
   - Stores backups on an external SD card
   - Path detection is automatic

3. **USB Storage** (`usb`)
   - Stores backups on attached USB storage
   - Requires USB OTG support

4. **Network Storage** (`network`)
   - Stores backups on a network location (FTP, SMB, WebDAV)
   - Requires network configuration

## Encryption

The backup system uses a hybrid encryption approach:

- **RSA-4096** for key protection
- **AES-256-GCM** for data encryption
- Hardware-backed keystore when available

The encryption keys are stored securely and can be backed up separately for disaster recovery.

## Scheduling

The backup system provides flexible scheduling options:

- **Time-based** schedules (daily, weekly, monthly)
- **Event-based** schedules (boot, app installation, system update)
- **Retention policies** to manage backup storage

## Backup Profiles

Backup profiles allow customization of backup parameters:

1. **Default Profile** (`default.profile`)
   - Backs up essential system partitions
   - Includes common settings
   - Recommended for most users

2. **Custom Profiles**
   - Create custom profiles in the `/data/adb/modules/kernelsu_antibootloop_backup/templates/` directory
   - Use as template for specific backup scenarios

## Restoration Process

The backup system follows a phased restoration approach:

1. **Verification Phase**
   - Verifies backup integrity
   - Checks space requirements
   - Validates compatibility

2. **Pre-Restoration Phase**
   - Prepares the system for restoration
   - Creates restoration snapshots when possible
   - Stops relevant services

3. **Restoration Phase**
   - Restores selected components
   - Handles permissions and ownership
   - Maintains system integrity

4. **Post-Restoration Phase**
   - Finalizes restoration
   - Updates system state
   - Restarts services

## Performance Optimization

The backup system includes several optimizations:

- **Binary Diffing**: Only stores changed blocks between backups
- **Compression**: Multiple algorithms with automatic selection
- **Deduplication**: Eliminates redundant data across backups
- **Parallel Processing**: Utilizes multiple cores when available

## Security Considerations

The backup system implements several security measures:

- **Encryption**: All backup data can be encrypted
- **Integrity Verification**: HMAC validation ensures backup integrity
- **Access Control**: Backup operations require appropriate permissions
- **Secure Key Management**: Protection of encryption keys

## Troubleshooting

Common issues and solutions:

1. **Backup Creation Fails**
   - Check storage space availability
   - Verify permissions
   - Check logs in `/data/adb/modules/kernelsu_antibootloop_backup/config/logs/`

2. **Restoration Fails**
   - Verify backup integrity
   - Check device compatibility
   - Examine restoration logs

3. **Schedule Not Running**
   - Check device power management settings
   - Verify schedule configuration
   - Ensure initialization at boot

## API Reference

The backup system provides a programmatic API for integration with other applications:

```bash
# API endpoint for WebUI
http://localhost:8080/api/v1/

# JSON response format
{
  "status": "success|error",
  "data": {...},
  "message": "..."
}
```

Refer to the API documentation for detailed endpoint information.

## Configuration

The backup system configuration is stored in the `/data/adb/modules/kernelsu_antibootloop_backup/config/` directory.

Key configuration files:

- `backup-config.json`: General configuration
- `storage-adapters.json`: Storage adapter configuration
- `schedules.json`: Backup schedules
- `encryption-config.json`: Encryption settings

## Contributing

To contribute to the KernelSU Anti-Bootloop Backup System:

1. Submit issues and feature requests
2. Follow coding standards for shell scripts
3. Test thoroughly on multiple device configurations
4. Submit pull requests with clear descriptions

## License

The KernelSU Anti-Bootloop Backup System is released under the GPL-3.0 license.