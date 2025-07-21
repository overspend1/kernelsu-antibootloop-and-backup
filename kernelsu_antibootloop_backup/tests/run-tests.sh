#!/system/bin/sh
# KernelSU Anti-Bootloop Backup System
# Automated Test Suite

# Set script paths
MODDIR="/data/adb/modules/kernelsu_antibootloop_backup"
INTEGRATION_SCRIPT="$MODDIR/scripts/backup-integration.sh"
TEST_DIR="$MODDIR/tests"
TEST_TEMP="$TEST_DIR/temp"
TEST_LOG="$TEST_DIR/test_results.log"

# Ensure test directories exist
mkdir -p "$TEST_DIR"
mkdir -p "$TEST_TEMP"

# Initialize log
echo "===== KernelSU Anti-Bootloop Backup System Test Suite =====" > "$TEST_LOG"
echo "Started: $(date)" >> "$TEST_LOG"
echo "Device: $(getprop ro.product.model) ($(getprop ro.product.device))" >> "$TEST_LOG"
echo "Android: $(getprop ro.build.version.release) (SDK $(getprop ro.build.version.sdk))" >> "$TEST_LOG"
echo "KernelSU version: $(su -v 2>/dev/null || echo 'Not detected')" >> "$TEST_LOG"
echo "===================================================" >> "$TEST_LOG"

# Utility functions
log_test() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$TEST_LOG"
    echo "$1"
}

run_test() {
    TEST_NAME="$1"
    TEST_CMD="$2"
    EXPECTED_RESULT="$3"
    
    log_test "TEST: $TEST_NAME"
    log_test "COMMAND: $TEST_CMD"
    
    # Run the test and capture output
    TEST_OUTPUT=$(eval "$TEST_CMD" 2>&1)
    TEST_RESULT=$?
    
    # Log the output
    log_test "OUTPUT: $TEST_OUTPUT"
    
    # Check result
    if [ "$TEST_RESULT" -eq "$EXPECTED_RESULT" ]; then
        log_test "RESULT: PASSED (Exit code: $TEST_RESULT)"
        return 0
    else
        log_test "RESULT: FAILED (Expected: $EXPECTED_RESULT, Got: $TEST_RESULT)"
        return 1
    fi
}

# Test counter variables
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# =============================================
# COMPONENT TESTS
# =============================================

log_test "SECTION: Component Tests"

# Test initialization
TESTS_TOTAL=$((TESTS_TOTAL + 1))
if run_test "Initialization" "\"$INTEGRATION_SCRIPT\" init" 0; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test component availability
TESTS_TOTAL=$((TESTS_TOTAL + 1))
if run_test "Component Availability" "\"$INTEGRATION_SCRIPT\" check" 0; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# =============================================
# BACKUP CREATION TESTS
# =============================================

log_test "SECTION: Backup Creation Tests"

# Test creating a small test file to backup
TEST_FILE="$TEST_TEMP/test_data.txt"
echo "This is test data for backup system testing" > "$TEST_FILE"
for i in $(seq 1 100); do
    echo "Line $i of test data" >> "$TEST_FILE"
done

# Test full backup (non-encrypted)
TESTS_TOTAL=$((TESTS_TOTAL + 1))
BACKUP_CMD="\"$INTEGRATION_SCRIPT\" backup-full \"Test backup $(date +%s)\" local false"
if run_test "Full Backup (Non-encrypted)" "$BACKUP_CMD" 0; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    
    # Capture the backup ID for restoration test
    BACKUP_ID=$(eval "$BACKUP_CMD" | tail -n 1)
    log_test "Created backup ID: $BACKUP_ID"
else
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test encrypted backup
TESTS_TOTAL=$((TESTS_TOTAL + 1))
ENC_BACKUP_CMD="\"$INTEGRATION_SCRIPT\" backup-full \"Encrypted test backup $(date +%s)\" local true"
if run_test "Full Backup (Encrypted)" "$ENC_BACKUP_CMD" 0; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    
    # Capture the encrypted backup ID for restoration test
    ENC_BACKUP_ID=$(eval "$ENC_BACKUP_CMD" | tail -n 1)
    log_test "Created encrypted backup ID: $ENC_BACKUP_ID"
else
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test app backup
TESTS_TOTAL=$((TESTS_TOTAL + 1))
APP_BACKUP_CMD="\"$INTEGRATION_SCRIPT\" backup-app \"com.android.settings\" \"App test backup $(date +%s)\" local"
if run_test "App Backup" "$APP_BACKUP_CMD" 0; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    
    # Capture the app backup ID for restoration test
    APP_BACKUP_ID=$(eval "$APP_BACKUP_CMD" | tail -n 1)
    log_test "Created app backup ID: $APP_BACKUP_ID"
else
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test settings backup
TESTS_TOTAL=$((TESTS_TOTAL + 1))
SETTINGS_BACKUP_CMD="\"$INTEGRATION_SCRIPT\" backup-settings \"Settings test backup $(date +%s)\" local"
if run_test "Settings Backup" "$SETTINGS_BACKUP_CMD" 0; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    
    # Capture the settings backup ID for restoration test
    SETTINGS_BACKUP_ID=$(eval "$SETTINGS_BACKUP_CMD" | tail -n 1)
    log_test "Created settings backup ID: $SETTINGS_BACKUP_ID"
else
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# =============================================
# BACKUP MANAGEMENT TESTS
# =============================================

log_test "SECTION: Backup Management Tests"

# Test listing backups
TESTS_TOTAL=$((TESTS_TOTAL + 1))
if run_test "List Backups" "\"$INTEGRATION_SCRIPT\" list-backups" 0; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test backup details (if we have a backup ID)
if [ -n "$BACKUP_ID" ]; then
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    if run_test "Backup Details" "\"$INTEGRATION_SCRIPT\" backup-details \"$BACKUP_ID\"" 0; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
fi

# =============================================
# SCHEDULE TESTS
# =============================================

log_test "SECTION: Schedule Tests"

# Test creating a schedule
TESTS_TOTAL=$((TESTS_TOTAL + 1))
if run_test "Create Schedule" "\"$INTEGRATION_SCRIPT\" create-schedule \"Test Schedule $(date +%s)\" \"daily\" \"default\"" 0; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test listing schedules
TESTS_TOTAL=$((TESTS_TOTAL + 1))
if run_test "List Schedules" "\"$INTEGRATION_SCRIPT\" list-schedules" 0; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test checking schedules
TESTS_TOTAL=$((TESTS_TOTAL + 1))
if run_test "Check Schedules" "\"$INTEGRATION_SCRIPT\" check-schedules \"time\"" 0; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# =============================================
# RESTORATION TESTS
# =============================================

log_test "SECTION: Restoration Tests"

# Test restoration if we have a backup ID
if [ -n "$BACKUP_ID" ]; then
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    if run_test "Restore Backup" "\"$INTEGRATION_SCRIPT\" restore \"$BACKUP_ID\"" 0; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
else
    log_test "SKIPPED: Restore test (no backup ID available)"
fi

# Test encrypted backup restoration if we have an encrypted backup ID
if [ -n "$ENC_BACKUP_ID" ]; then
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    if run_test "Restore Encrypted Backup" "\"$INTEGRATION_SCRIPT\" restore \"$ENC_BACKUP_ID\"" 0; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
else
    log_test "SKIPPED: Encrypted restore test (no encrypted backup ID available)"
fi

# =============================================
# STORAGE ADAPTER TESTS
# =============================================

log_test "SECTION: Storage Adapter Tests"

# Test if external storage is available
if [ -d "/sdcard" ] || [ -d "/storage/sdcard1" ]; then
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    if run_test "External Storage Backup" "\"$INTEGRATION_SCRIPT\" backup-full \"External storage test $(date +%s)\" external false" 0; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
else
    log_test "SKIPPED: External storage test (no external storage available)"
fi

# =============================================
# CLEANUP TESTS
# =============================================

log_test "SECTION: Cleanup Tests"

# Test backup deletion if we have a backup ID
if [ -n "$BACKUP_ID" ]; then
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    if run_test "Delete Backup" "\"$INTEGRATION_SCRIPT\" delete-backup \"$BACKUP_ID\"" 0; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
fi

# =============================================
# TEST RESULTS
# =============================================

log_test "===================================================="
log_test "TEST SUMMARY"
log_test "Total tests: $TESTS_TOTAL"
log_test "Passed: $TESTS_PASSED"
log_test "Failed: $TESTS_FAILED"
log_test "Success rate: $(( (TESTS_PASSED * 100) / TESTS_TOTAL ))%"
log_test "===================================================="

# Clean up test files
rm -rf "$TEST_TEMP"

# Final result
if [ "$TESTS_FAILED" -eq 0 ]; then
    log_test "ALL TESTS PASSED"
    exit 0
else
    log_test "SOME TESTS FAILED"
    exit 1
fi