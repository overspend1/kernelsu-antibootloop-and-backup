# KernelSU Anti-Bootloop Backup System: Testing Guide

This guide outlines test scenarios to verify the functionality of the backup and restoration system. Each test should be performed in a controlled environment before deploying to production devices.

## Test Environment Setup

Before running any tests, ensure you have:

1. A test device with KernelSU installed
2. The backup module properly installed
3. Root access verified
4. At least 2GB of free storage space
5. A secondary storage location (SD card or USB) for storage adapter tests
6. A way to intentionally cause a controlled boot issue (for recovery testing)

## Basic Functionality Tests

### Module Installation Test

1. Install the module via KernelSU Manager
2. Reboot the device
3. Verify module appears as active in KernelSU Manager
4. Run initialization:
   ```bash
   su -c "sh /data/adb/modules/kernelsu_antibootloop_backup/scripts/backup-integration.sh init"
   ```
5. Check for any errors in logs:
   ```bash
   cat /data/adb/modules/kernelsu_antibootloop_backup/config/logs/integration.log
   ```

### Component Availability Test

```bash
su -c "sh /data/adb/modules/kernelsu_antibootloop_backup/scripts/backup-integration.sh check"
```

Expected result: All components should be reported as available.

### WebUI Test

1. Start the web server:
   ```bash
   su -c "sh /data/adb/modules/kernelsu_antibootloop_backup/scripts/webui-server.sh start"
   ```
2. Navigate to `http://localhost:8080` on device or via ADB forwarding
3. Verify all UI elements load correctly
4. Verify navigation between sections works

## Backup Creation Tests

### Full System Backup Test

1. Create a full system backup:
   ```bash
   su -c "sh /data/adb/modules/kernelsu_antibootloop_backup/scripts/backup-integration.sh backup-full 'Test full backup' local false"
   ```
2. Verify backup ID is returned
3. Check backup appears in backup list:
   ```bash
   su -c "sh /data/adb/modules/kernelsu_antibootloop_backup/scripts/backup-integration.sh list-backups"
   ```
4. Verify backup details:
   ```bash
   su -c "sh /data/adb/modules/kernelsu_antibootloop_backup/scripts/backup-integration.sh backup-details BACKUP_ID"
   ```

### App Backup Test

1. Create an app backup with multiple packages:
   ```bash
   su -c "sh /data/adb/modules/kernelsu_antibootloop_backup/scripts/backup-integration.sh backup-app 'com.android.settings,com.android.calculator2' 'Test app backup' local"
   ```
2. Verify backup ID is returned
3. Check backup appears in backup list
4. Verify app data is included in the backup

### Settings Backup Test

1. Create a settings backup:
   ```bash
   su -c "sh /data/adb/modules/kernelsu_antibootloop_backup/scripts/backup-integration.sh backup-settings 'Test settings backup' local"
   ```
2. Verify backup ID is returned
3. Check backup appears in backup list

### Encrypted Backup Test

1. Create an encrypted full backup:
   ```bash
   su -c "sh /data/adb/modules/kernelsu_antibootloop_backup/scripts/backup-integration.sh backup-full 'Test encrypted backup' local true"
   ```
2. Verify backup ID is returned
3. Check backup appears in backup list
4. Verify encryption status in backup details

## Storage Adapter Tests

### External Storage Test

1. Insert SD card
2. Create a backup to external storage:
   ```bash
   su -c "sh /data/adb/modules/kernelsu_antibootloop_backup/scripts/backup-integration.sh backup-full 'Test external backup' external false"
   ```
3. Verify backup is created on SD card
4. List backups from external storage to confirm

### USB Storage Test

1. Connect USB storage via OTG
2. Create a backup to USB storage:
   ```bash
   su -c "sh /data/adb/modules/kernelsu_antibootloop_backup/scripts/backup-integration.sh backup-full 'Test USB backup' usb false"
   ```
3. Verify backup is created on USB storage
4. List backups from USB storage to confirm

### Network Storage Test (if configured)

1. Configure network storage in settings
2. Create a backup to network storage:
   ```bash
   su -c "sh /data/adb/modules/kernelsu_antibootloop_backup/scripts/backup-integration.sh backup-full 'Test network backup' network false"
   ```
3. Verify backup is uploaded to network location
4. List backups from network storage to confirm

## Restoration Tests

### Full Restoration Test

1. Create a full backup
2. Make some system changes (install app, change settings)
3. Restore the full backup:
   ```bash
   su -c "sh /data/adb/modules/kernelsu_antibootloop_backup/scripts/backup-integration.sh restore BACKUP_ID"
   ```
4. Verify system returns to the pre-change state

### Selective Restoration Test

1. Create a full backup
2. Make changes to apps and settings
3. Restore only settings component:
   ```bash
   su -c "sh /data/adb/modules/kernelsu_antibootloop_backup/scripts/backup-integration.sh restore BACKUP_ID settings"
   ```
4. Verify only settings are restored
5. Restore only apps component:
   ```bash
   su -c "sh /data/adb/modules/kernelsu_antibootloop_backup/scripts/backup-integration.sh restore BACKUP_ID apps"
   ```
6. Verify only apps are restored

### Encrypted Backup Restoration Test

1. Create an encrypted backup
2. Make system changes
3. Restore from encrypted backup:
   ```bash
   su -c "sh /data/adb/modules/kernelsu_antibootloop_backup/scripts/backup-integration.sh restore BACKUP_ID"
   ```
4. Verify restoration completes successfully

## Differential Backup Tests

### Incremental Backup Test

1. Create an initial full backup
2. Make some system changes
3. Create another backup with the same description
4. Verify the second backup is smaller than the first (differential)
5. Restore from the second backup
6. Verify all changes are properly restored

### Compression Test

Create backups with different content types (text-heavy apps vs. media-heavy apps) and verify compression effectiveness by checking backup sizes.

## Schedule Tests

### Time-Based Schedule Test

1. Create a schedule to run in a few minutes:
   ```bash
   su -c "sh /data/adb/modules/kernelsu_antibootloop_backup/scripts/backup-integration.sh create-schedule 'Test Schedule' 'custom:5m' 'default'"
   ```
2. Wait for the scheduled time
3. Verify backup is created automatically
4. Check for notification

### Boot-Based Schedule Test

1. Create a schedule to run at boot:
   ```bash
   su -c "sh /data/adb/modules/kernelsu_antibootloop_backup/scripts/backup-integration.sh create-schedule 'Boot Schedule' 'boot' 'default'"
   ```
2. Reboot the device
3. Verify backup is created automatically after boot

## Recovery Tests

### Anti-Bootloop Recovery Test

**CAUTION**: This test should only be performed on test devices with data backed up elsewhere.

1. Create a full system backup
2. Intentionally cause a boot issue:
   - Install a problematic app known to cause boot loops
   - Or modify a system file to cause boot failure
3. Attempt to boot the device
4. Verify the anti-bootloop protection activates
5. Verify automatic restoration from the backup
6. Verify device returns to normal operation

### Manual Recovery Test

1. Create a full system backup
2. Enter recovery mode
3. Use the recovery script to restore the backup
4. Verify system is restored correctly

## Performance Tests

### Large System Test

Create a full system backup on a device with many apps installed and verify backup and restore operations complete within reasonable time frames.

### Resource Usage Test

Monitor CPU, memory, and battery usage during backup and restore operations to ensure the system operates efficiently.

## Error Handling Tests

### Insufficient Space Test

1. Fill device storage to near capacity
2. Attempt to create a backup
3. Verify appropriate error message
4. Verify system remains stable

### Corrupt Backup Test

1. Create a backup
2. Manually corrupt the backup file
3. Attempt to restore from corrupt backup
4. Verify appropriate error handling
5. Verify system remains stable

## Security Tests

### Encryption Verification

1. Create an encrypted backup
2. Attempt to manually decrypt the backup file without proper keys
3. Verify this is not possible
4. Restore using the proper process
5. Verify restoration succeeds

### Permission Test

1. Attempt to run backup operations without root (remove `su -c`)
2. Verify appropriate permission errors
3. Verify system remains secure

## Reporting Test Results

For each test:
1. Document the test name and procedure followed
2. Record whether the test passed or failed
3. Note any unexpected behavior or errors
4. Include logs if errors occurred
5. Document the device model and Android version

Submit test results to the development team for analysis and improvement.

## Automated Testing

For developers, shell scripts for automated testing are available in:
```
/data/adb/modules/kernelsu_antibootloop_backup/tests/
```

Run the automated test suite:
```bash
su -c "sh /data/adb/modules/kernelsu_antibootloop_backup/tests/run-tests.sh"