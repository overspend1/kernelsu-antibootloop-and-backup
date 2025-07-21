# KernelSU Anti-Bootloop Backup System: Quick Start Guide

This guide provides simple instructions to get started with the KernelSU Anti-Bootloop Backup System.

## Installation

1. Download the latest module ZIP from the releases page
2. Install via KernelSU Manager:
   - Open KernelSU Manager
   - Go to Modules tab
   - Tap "Install" and select the downloaded ZIP
3. Reboot your device
4. Verify installation by checking for the module in KernelSU Manager

## First-Time Setup

### Via Command Line

Open a terminal app or ADB shell and run:

```bash
su -c "sh /data/adb/modules/kernelsu_antibootloop_backup/scripts/backup-integration.sh init"
```

### Via Web Interface

1. Start the web server:
   ```bash
   su -c "sh /data/adb/modules/kernelsu_antibootloop_backup/scripts/webui-server.sh start"
   ```

2. Access the web interface:
   - On device: Open browser and navigate to `http://localhost:8080`
   - From computer: Run `adb forward tcp:8080 tcp:8080` then navigate to `http://localhost:8080`

3. Follow the setup wizard

## Common Tasks

### Create Your First Backup

#### Full System Backup (Command Line)

```bash
su -c "sh /data/adb/modules/kernelsu_antibootloop_backup/scripts/backup-integration.sh backup-full 'My first backup' local true"
```

#### App Backup (Command Line)

```bash
su -c "sh /data/adb/modules/kernelsu_antibootloop_backup/scripts/backup-integration.sh backup-app 'com.example.app1,com.example.app2' 'My app backup' local"
```

#### Via Web Interface

1. Open the web interface
2. Click "Create Backup"
3. Select backup type
4. Configure options
5. Click "Start Backup"

### Restore a Backup

#### Command Line

```bash
# List available backups
su -c "sh /data/adb/modules/kernelsu_antibootloop_backup/scripts/backup-integration.sh list-backups"

# Restore a backup (replace BACKUP_ID with the actual ID)
su -c "sh /data/adb/modules/kernelsu_antibootloop_backup/scripts/backup-integration.sh restore BACKUP_ID"
```

#### Via Web Interface

1. Open the web interface
2. Click "Backups" tab
3. Find the backup to restore
4. Click "Restore"
5. Select components to restore
6. Click "Start Restore"

### Set Up Automated Backups

#### Command Line

```bash
# Create a daily backup schedule
su -c "sh /data/adb/modules/kernelsu_antibootloop_backup/scripts/backup-integration.sh create-schedule 'Daily Backup' 'daily' 'default'"

# Create a weekly backup schedule
su -c "sh /data/adb/modules/kernelsu_antibootloop_backup/scripts/backup-integration.sh create-schedule 'Weekly Backup' 'weekly' 'default'"
```

#### Via Web Interface

1. Open the web interface
2. Click "Schedules" tab
3. Click "Add Schedule"
4. Configure schedule options
5. Click "Save"

## Storage Options

The backup system supports multiple storage locations:

- **Local**: Internal device storage (default)
- **External**: SD card
- **USB**: USB OTG storage
- **Network**: FTP, SMB, or WebDAV

To use an alternative storage location, specify the adapter name when creating backups.

Example:
```bash
# Backup to SD card
su -c "sh /data/adb/modules/kernelsu_antibootloop_backup/scripts/backup-integration.sh backup-full 'SD card backup' external true"
```

## Encryption

All backups can be encrypted for security. To create an encrypted backup, specify `true` as the encryption parameter:

```bash
su -c "sh /data/adb/modules/kernelsu_antibootloop_backup/scripts/backup-integration.sh backup-full 'Encrypted backup' local true"
```

## Troubleshooting

### Check Logs

```bash
cat /data/adb/modules/kernelsu_antibootloop_backup/config/logs/integration.log
```

### Common Issues

1. **Permission Denied**: Ensure you're running commands with `su -c`
2. **Storage Full**: Check available space on your storage destination
3. **Backup Failed**: Check logs for detailed error messages
4. **Web Interface Not Loading**: Ensure the server is running and ports are correctly forwarded

## Additional Resources

- Full documentation: `/data/adb/modules/kernelsu_antibootloop_backup/docs/backup-system.md`
- Project website: [https://github.com/yourusername/kernelsu_antibootloop_backup](https://github.com/yourusername/kernelsu_antibootloop_backup)