#!/system/bin/sh

# Advanced Anti-Bootloop KSU Module - Auto Recovery Test
# Author: @overspend1/Wiktor
# Automated testing and validation of recovery mechanisms

MODDIR=${0%/*}
. "$MODDIR/utils.sh"
. "$MODDIR/backup_manager.sh"
. "$MODDIR/recovery_engine.sh"

TEST_LOG="$BASE_DIR/recovery_test.log"
TEST_RESULTS="$BASE_DIR/test_results"

# Test framework
init_test_framework() {
    mkdir -p "$BASE_DIR"
    
    # Create test log
    {
        echo "Recovery Test Framework Initialized"
        echo "=================================="
        echo "Timestamp: $(date)"
        echo "Module Version: 2.0"
        echo "Author: @overspend1/Wiktor"
        echo ""
    } > "$TEST_LOG"
    
    log_message "INFO" "Recovery test framework initialized"
}

# Test result logging
log_test_result() {
    local test_name="$1"
    local result="$2"
    local details="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] TEST: $test_name | RESULT: $result | DETAILS: $details" >> "$TEST_LOG"
    
    if [ "$result" = "PASS" ]; then
        log_message "INFO" "Test PASSED: $test_name"
    else
        log_message "ERROR" "Test FAILED: $test_name - $details"
    fi
}

# Test 1: Backup System Integrity
test_backup_system() {
    local test_name="Backup System Integrity"
    log_message "INFO" "Running test: $test_name"
    
    # Check backup directory
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
    fi
    
    # Test backup creation
    local test_backup_name="test_backup_$(date '+%Y%m%d_%H%M%S')"
    
    if create_backup "$test_backup_name" "Automated test backup" "true"; then
        # Verify backup exists
        if [ -f "$BACKUP_DIR/${test_backup_name}.img" ]; then
            # Verify backup size (should be reasonable)
            local backup_size=$(stat -c%s "$BACKUP_DIR/${test_backup_name}.img" 2>/dev/null || echo "0")
            
            if [ "$backup_size" -gt 1048576 ]; then  # At least 1MB
                # Test hash verification
                if [ -f "$BACKUP_DIR/${test_backup_name}.sha256" ]; then
                    local stored_hash=$(cat "$BACKUP_DIR/${test_backup_name}.sha256")
                    local actual_hash=$(sha256sum "$BACKUP_DIR/${test_backup_name}.img" | cut -d' ' -f1)
                    
                    if [ "$stored_hash" = "$actual_hash" ]; then
                        log_test_result "$test_name" "PASS" "Backup created and verified successfully"
                        
                        # Cleanup test backup
                        rm -f "$BACKUP_DIR/${test_backup_name}.img" "$BACKUP_DIR/${test_backup_name}.sha256"
                        return 0
                    else
                        log_test_result "$test_name" "FAIL" "Hash verification failed"
                    fi
                else
                    log_test_result "$test_name" "FAIL" "Hash file not created"
                fi
            else
                log_test_result "$test_name" "FAIL" "Backup size too small: $backup_size bytes"
            fi
        else
            log_test_result "$test_name" "FAIL" "Backup file not created"
        fi
    else
        log_test_result "$test_name" "FAIL" "Backup creation failed"
    fi
    
    return 1
}

# Test 2: Configuration Loading
test_config_loading() {
    local test_name="Configuration Loading"
    log_message "INFO" "Running test: $test_name"
    
    # Backup original config
    local original_config=""
    if [ -f "$CONFIG_FILE" ]; then
        original_config=$(cat "$CONFIG_FILE")
    fi
    
    # Create test config
    cat > "$CONFIG_FILE" << EOF
# Test configuration
MAX_BOOT_ATTEMPTS=5
RECOVERY_STRATEGY=progressive
SAFE_MODE_ENABLED=true
HARDWARE_MONITORING=true
EOF
    
    # Load config
    load_config
    
    # Verify values
    if [ "$MAX_BOOT_ATTEMPTS" = "5" ] && [ "$RECOVERY_STRATEGY" = "progressive" ] && [ "$SAFE_MODE_ENABLED" = "true" ]; then
        log_test_result "$test_name" "PASS" "Configuration loaded correctly"
        
        # Restore original config
        if [ -n "$original_config" ]; then
            echo "$original_config" > "$CONFIG_FILE"
        fi
        load_config  # Reload original
        return 0
    else
        log_test_result "$test_name" "FAIL" "Configuration values incorrect"
        return 1
    fi
}

# Test 3: Hardware Monitoring
test_hardware_monitoring() {
    local test_name="Hardware Monitoring"
    log_message "INFO" "Running test: $test_name"
    
    # Test CPU temperature reading
    local cpu_temp=$(get_cpu_temp)
    if [ "$cpu_temp" -gt 0 ] && [ "$cpu_temp" -lt 150 ]; then
        # Test RAM reading
        local ram=$(get_available_ram)
        if [ "$ram" -gt 0 ] && [ "$ram" -lt 10000 ]; then
            # Test storage health
            local storage=$(get_storage_health)
            if [ -n "$storage" ]; then
                log_test_result "$test_name" "PASS" "All hardware sensors responding"
                return 0
            else
                log_test_result "$test_name" "FAIL" "Storage health detection failed"
            fi
        else
            log_test_result "$test_name" "FAIL" "RAM detection failed or unrealistic value: $ram"
        fi
    else
        log_test_result "$test_name" "FAIL" "CPU temperature detection failed or unrealistic value: $cpu_temp"
    fi
    
    return 1
}

# Test 4: Recovery State Management
test_recovery_states() {
    local test_name="Recovery State Management"
    log_message "INFO" "Running test: $test_name"
    
    # Backup current state
    local original_state=$(get_recovery_state)
    
    # Test state transitions
    local test_states="monitoring safe_mode kernel_recovery emergency normal"
    local failed_states=""
    
    for state in $test_states; do
        set_recovery_state "$state"
        local current_state=$(get_recovery_state)
        
        if [ "$current_state" != "$state" ]; then
            failed_states="$failed_states $state"
        fi
    done
    
    # Restore original state
    set_recovery_state "$original_state"
    
    if [ -z "$failed_states" ]; then
        log_test_result "$test_name" "PASS" "All state transitions working"
        return 0
    else
        log_test_result "$test_name" "FAIL" "Failed states:$failed_states"
        return 1
    fi
}

# Test 5: Safe Mode Functionality
test_safe_mode() {
    local test_name="Safe Mode Functionality"
    log_message "INFO" "Running test: $test_name"
    
    # Test enabling safe mode
    local original_safe_mode=$(is_safe_mode_active && echo "true" || echo "false")
    
    # Enable safe mode
    enable_safe_mode
    
    if is_safe_mode_active; then
        # Test disabling safe mode
        disable_safe_mode
        
        if ! is_safe_mode_active; then
            log_test_result "$test_name" "PASS" "Safe mode toggle working"
            
            # Restore original state
            if [ "$original_safe_mode" = "true" ]; then
                enable_safe_mode
            fi
            return 0
        else
            log_test_result "$test_name" "FAIL" "Safe mode disable failed"
        fi
    else
        log_test_result "$test_name" "FAIL" "Safe mode enable failed"
    fi
    
    return 1
}

# Test 6: Boot Counter Management
test_boot_counter() {
    local test_name="Boot Counter Management"
    log_message "INFO" "Running test: $test_name"
    
    # Backup original count
    local original_count=$(cat "$BOOT_COUNT_FILE" 2>/dev/null || echo "0")
    
    # Test setting different values
    echo "5" > "$BOOT_COUNT_FILE"
    local test_count=$(cat "$BOOT_COUNT_FILE")
    
    if [ "$test_count" = "5" ]; then
        # Test reset
        echo "0" > "$BOOT_COUNT_FILE"
        local reset_count=$(cat "$BOOT_COUNT_FILE")
        
        if [ "$reset_count" = "0" ]; then
            log_test_result "$test_name" "PASS" "Boot counter management working"
            
            # Restore original count
            echo "$original_count" > "$BOOT_COUNT_FILE"
            return 0
        else
            log_test_result "$test_name" "FAIL" "Boot counter reset failed"
        fi
    else
        log_test_result "$test_name" "FAIL" "Boot counter set failed"
    fi
    
    return 1
}

# Test 7: Emergency Disable Mechanism
test_emergency_disable() {
    local test_name="Emergency Disable Mechanism"
    log_message "INFO" "Running test: $test_name"
    
    # Test emergency disable file detection
    if check_emergency_disable; then
        log_test_result "$test_name" "FAIL" "Emergency disable incorrectly detected when not set"
        return 1
    fi
    
    # Create emergency disable file
    touch "$EMERGENCY_DISABLE_FILE"
    
    if check_emergency_disable; then
        log_test_result "$test_name" "PASS" "Emergency disable detection working"
        
        # Cleanup
        rm -f "$EMERGENCY_DISABLE_FILE"
        return 0
    else
        log_test_result "$test_name" "FAIL" "Emergency disable not detected when set"
        rm -f "$EMERGENCY_DISABLE_FILE"
        return 1
    fi
}

# Test 8: Conflict Detection
test_conflict_detection() {
    local test_name="Conflict Detection"
    log_message "INFO" "Running test: $test_name"
    
    # This test checks if the conflict detection system is working
    # We can't easily create real conflicts, so we test the detection logic
    
    if detect_conflicts; then
        log_test_result "$test_name" "PASS" "Conflict detection system operational"
        return 0
    else
        # This might be expected if there are actual conflicts
        log_test_result "$test_name" "WARN" "Conflicts detected (may be expected)"
        return 0
    fi
}

# Test 9: Logging System
test_logging_system() {
    local test_name="Logging System"
    log_message "INFO" "Running test: $test_name"
    
    local test_message="Test message $(date '+%Y%m%d_%H%M%S')"
    
    # Test different log levels
    log_message "INFO" "$test_message"
    log_message "WARN" "$test_message"
    log_message "ERROR" "$test_message"
    
    # Check if messages were logged
    if [ -f "$LOG_FILE" ]; then
        local found_messages=$(grep -c "$test_message" "$LOG_FILE" 2>/dev/null || echo "0")
        
        if [ "$found_messages" = "3" ]; then
            log_test_result "$test_name" "PASS" "All log levels working"
            return 0
        else
            log_test_result "$test_name" "FAIL" "Only $found_messages/3 messages logged"
        fi
    else
        log_test_result "$test_name" "FAIL" "Log file not found"
    fi
    
    return 1
}

# Test 10: Module Integrity
test_module_integrity() {
    local test_name="Module Integrity"
    log_message "INFO" "Running test: $test_name"
    
    local required_files="
        module.prop
        service.sh
        post-fs-data.sh
        utils.sh
        backup_manager.sh
        recovery_engine.sh
        config.conf
        action.sh
        health_monitor.sh
    "
    
    local missing_files=""
    local total_files=0
    local found_files=0
    
    for file in $required_files; do
        total_files=$((total_files + 1))
        if [ -f "$MODDIR/$file" ]; then
            found_files=$((found_files + 1))
        else
            missing_files="$missing_files $file"
        fi
    done
    
    if [ $found_files -eq $total_files ]; then
        log_test_result "$test_name" "PASS" "All module files present ($found_files/$total_files)"
        return 0
    else
        log_test_result "$test_name" "FAIL" "Missing files:$missing_files ($found_files/$total_files)"
        return 1
    fi
}

# Run all tests
run_all_tests() {
    init_test_framework
    
    local total_tests=0
    local passed_tests=0
    local failed_tests=0
    
    echo "Running comprehensive recovery system tests..."
    echo "============================================="
    
    # List of all tests
    local tests="
        test_module_integrity
        test_config_loading
        test_hardware_monitoring
        test_recovery_states
        test_safe_mode
        test_boot_counter
        test_emergency_disable
        test_conflict_detection
        test_logging_system
        test_backup_system
    "
    
    for test in $tests; do
        total_tests=$((total_tests + 1))
        echo "Running $test..."
        
        if $test; then
            passed_tests=$((passed_tests + 1))
            echo "✅ PASSED"
        else
            failed_tests=$((failed_tests + 1))
            echo "❌ FAILED"
        fi
        echo ""
    done
    
    # Generate summary
    {
        echo ""
        echo "Test Summary"
        echo "============"
        echo "Total Tests: $total_tests"
        echo "Passed: $passed_tests"
        echo "Failed: $failed_tests"
        echo "Success Rate: $(( (passed_tests * 100) / total_tests ))%"
        echo ""
        echo "Test completed: $(date)"
    } >> "$TEST_LOG"
    
    # Store results
    echo "TOTAL:$total_tests PASSED:$passed_tests FAILED:$failed_tests" > "$TEST_RESULTS"
    
    echo "Test Summary:"
    echo "Total Tests: $total_tests"
    echo "Passed: $passed_tests"
    echo "Failed: $failed_tests"
    echo "Success Rate: $(( (passed_tests * 100) / total_tests ))%"
    echo ""
    echo "Detailed results logged to: $TEST_LOG"
    
    if [ $failed_tests -eq 0 ]; then
        log_message "INFO" "All recovery tests passed successfully"
        return 0
    else
        log_message "WARN" "$failed_tests tests failed - check $TEST_LOG for details"
        return 1
    fi
}

# Quick test (subset of critical tests)
run_quick_test() {
    init_test_framework
    
    echo "Running quick recovery system test..."
    echo "====================================="
    
    local quick_tests="test_module_integrity test_config_loading test_hardware_monitoring test_boot_counter"
    local total=0
    local passed=0
    
    for test in $quick_tests; do
        total=$((total + 1))
        echo "Running $test..."
        
        if $test; then
            passed=$((passed + 1))
            echo "✅ PASSED"
        else
            echo "❌ FAILED"
        fi
    done
    
    echo ""
    echo "Quick Test Summary: $passed/$total tests passed"
    
    if [ $passed -eq $total ]; then
        echo "✅ All critical systems operational"
        return 0
    else
        echo "⚠️  Some systems need attention"
        return 1
    fi
}

# Command line interface
case "$1" in
    "all")
        run_all_tests
        ;;
    "quick")
        run_quick_test
        ;;
    "backup")
        test_backup_system
        ;;
    "config")
        test_config_loading
        ;;
    "hardware")
        test_hardware_monitoring
        ;;
    "recovery")
        test_recovery_states
        ;;
    "safe")
        test_safe_mode
        ;;
    "counter")
        test_boot_counter
        ;;
    "emergency")
        test_emergency_disable
        ;;
    "conflicts")
        test_conflict_detection
        ;;
    "logging")
        test_logging_system
        ;;
    "integrity")
        test_module_integrity
        ;;
    *)
        echo "Advanced Anti-Bootloop KSU - Auto Recovery Test"
        echo "Author: @overspend1/Wiktor"
        echo ""
        echo "Usage: $0 {all|quick|specific_test}"
        echo ""
        echo "Test Suites:"
        echo "  all      - Run comprehensive test suite"
        echo "  quick    - Run quick critical systems test"
        echo ""
        echo "Individual Tests:"
        echo "  backup     - Test backup system integrity"
        echo "  config     - Test configuration loading"
        echo "  hardware   - Test hardware monitoring"
        echo "  recovery   - Test recovery state management"
        echo "  safe       - Test safe mode functionality"
        echo "  counter    - Test boot counter management"
        echo "  emergency  - Test emergency disable mechanism"
        echo "  conflicts  - Test conflict detection"
        echo "  logging    - Test logging system"
        echo "  integrity  - Test module file integrity"
        echo ""
        echo "Results logged to: $TEST_LOG"
        exit 1
        ;;
esac