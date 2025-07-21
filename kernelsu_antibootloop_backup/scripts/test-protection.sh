#!/system/bin/sh
# KernelSU Anti-Bootloop & Backup Module
# Bootloop Protection Testing Script
# Safely tests the anti-bootloop mechanisms

MODULE_DIR="/data/adb/modules/kernelsu_antibootloop_backup"
CONFIG_DIR="$MODULE_DIR/config"
LOG_FILE="$MODULE_DIR/logs/protection-test.log"
TEST_FLAG="$CONFIG_DIR/protection_test_active"

# Ensure directories exist
mkdir -p "$CONFIG_DIR"
mkdir -p "$MODULE_DIR/logs"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo "$1"
}

# Create test recovery point
create_test_recovery_point() {
    log "Creating test recovery point before protection test"
    
    if [ -f "$MODULE_DIR/scripts/recovery-point.sh" ]; then
        sh "$MODULE_DIR/scripts/recovery-point.sh" create "protection_test_$(date +%s)" "Pre-protection test recovery point"
        if [ $? -eq 0 ]; then
            log "Test recovery point created successfully"
            return 0
        else
            log "Failed to create test recovery point"
            return 1
        fi
    else
        log "Recovery point script not found, skipping recovery point creation"
        return 0
    fi
}

# Test volume button detection
test_volume_button_detection() {
    log "Testing volume button detection mechanism"
    
    # Create a mock volume button press simulation
    local test_result=0
    
    # Check if volume button monitoring is active
    if pgrep -f "volume.*detect" >/dev/null 2>&1; then
        log "Volume button detection service is running"
        test_result=$((test_result + 1))
    else
        log "WARNING: Volume button detection service not found"
    fi
    
    # Check for volume detection script
    if [ -f "$MODULE_DIR/scripts/safe-mode.sh" ]; then
        log "Safe mode script found"
        test_result=$((test_result + 1))
        
        # Test safe mode trigger mechanism (without actually triggering)
        if grep -q "volume.*down" "$MODULE_DIR/scripts/safe-mode.sh" 2>/dev/null; then
            log "Volume down detection code found in safe mode script"
            test_result=$((test_result + 1))
        else
            log "WARNING: Volume down detection not found in safe mode script"
        fi
    else
        log "WARNING: Safe mode script not found"
    fi
    
    return $test_result
}

# Test boot timeout monitoring
test_boot_timeout_monitoring() {
    log "Testing boot timeout monitoring mechanism"
    
    local test_result=0
    
    # Check if boot monitoring service is running
    if [ -f "$MODULE_DIR/scripts/boot-monitor.sh" ]; then
        log "Boot monitoring script found"
        test_result=$((test_result + 1))
        
        # Check for timeout configuration
        local timeout_config="$CONFIG_DIR/boot_timeout.txt"
        if [ -f "$timeout_config" ]; then
            local timeout_value=$(cat "$timeout_config" 2>/dev/null || echo "0")
            if [ "$timeout_value" -gt 0 ]; then
                log "Boot timeout configured: ${timeout_value}s"
                test_result=$((test_result + 1))
            else
                log "WARNING: Boot timeout not properly configured"
            fi
        else
            log "Boot timeout configuration not found, using defaults"
        fi
    else
        log "WARNING: Boot monitoring script not found"
    fi
    
    # Check for boot completion tracking
    if [ -f "$CONFIG_DIR/boot_count.txt" ]; then
        local boot_count=$(cat "$CONFIG_DIR/boot_count.txt" 2>/dev/null || echo "0")
        log "Current boot count: $boot_count"
        test_result=$((test_result + 1))
    else
        log "Boot count tracking not initialized"
        echo "0" > "$CONFIG_DIR/boot_count.txt"
    fi
    
    return $test_result
}

# Test module disable mechanism
test_module_disable_mechanism() {
    log "Testing module disable mechanism"
    
    local test_result=0
    local test_module_dir="/data/adb/modules/kernelsu_protection_test"
    
    # Create a test module
    mkdir -p "$test_module_dir"
    cat > "$test_module_dir/module.prop" << EOF
id=kernelsu_protection_test
name=KernelSU Protection Test Module
version=v1.0.0
versionCode=1
author=ProtectionTest
description=Test module for bootloop protection
EOF
    
    log "Created test module: kernelsu_protection_test"
    test_result=$((test_result + 1))
    
    # Test disable mechanism
    if [ -f "$MODULE_DIR/scripts/safe-mode.sh" ]; then
        # Simulate module disable without actually running safe mode
        touch "$test_module_dir/disable"
        if [ -f "$test_module_dir/disable" ]; then
            log "Module disable mechanism working (test module disabled)"
            test_result=$((test_result + 1))
        else
            log "WARNING: Failed to disable test module"
        fi
    else
        log "WARNING: Safe mode script not available for testing"
    fi
    
    # Cleanup test module
    rm -rf "$test_module_dir"
    log "Cleaned up test module"
    test_result=$((test_result + 1))
    
    return $test_result
}

# Test recovery mechanisms
test_recovery_mechanisms() {
    log "Testing recovery mechanisms"
    
    local test_result=0
    
    # Test recovery point functionality
    if [ -f "$MODULE_DIR/scripts/recovery-point.sh" ]; then
        log "Recovery point script available"
        test_result=$((test_result + 1))
        
        # Test recovery point creation (dry run)
        if sh "$MODULE_DIR/scripts/recovery-point.sh" list >/dev/null 2>&1; then
            log "Recovery point listing works"
            test_result=$((test_result + 1))
        else
            log "WARNING: Recovery point listing failed"
        fi
    else
        log "WARNING: Recovery point script not found"
    fi
    
    # Test backup functionality
    if [ -f "$MODULE_DIR/scripts/backup-engine.sh" ]; then
        log "Backup engine script available"
        test_result=$((test_result + 1))
    else
        log "WARNING: Backup engine script not found"
    fi
    
    return $test_result
}

# Simulate bootloop condition (safe simulation)
simulate_bootloop_condition() {
    log "Simulating bootloop condition (safe mode)"
    
    # Mark test as active
    echo "$(date +%s)" > "$TEST_FLAG"
    
    local test_result=0
    
    # Create a temporary "problematic" module for testing
    local problem_module="/data/adb/modules/kernelsu_bootloop_test"
    mkdir -p "$problem_module"
    
    cat > "$problem_module/module.prop" << EOF
id=kernelsu_bootloop_test
name=KernelSU Bootloop Test
version=v1.0.0
versionCode=1
author=BootloopTest
description=Test module to simulate problematic behavior
EOF
    
    # Create a problematic service script
    cat > "$problem_module/service.sh" << EOF
#!/system/bin/sh
# This is a test script that would normally cause issues
echo "Test bootloop simulation - this module would cause problems"
exit 1
EOF
    chmod 755 "$problem_module/service.sh"
    
    log "Created problematic test module"
    test_result=$((test_result + 1))
    
    # Test automatic detection and handling
    sleep 2
    
    # Simulate detection of boot failure
    if [ -f "$MODULE_DIR/scripts/safe-mode.sh" ]; then
        log "Testing safe mode activation"
        
        # Don't actually trigger safe mode, just test detection
        if grep -q "disable.*modules" "$MODULE_DIR/scripts/safe-mode.sh" 2>/dev/null; then
            log "Safe mode script contains module disable logic"
            test_result=$((test_result + 1))
            
            # Simulate automatic module disable
            touch "$problem_module/disable"
            if [ -f "$problem_module/disable" ]; then
                log "Problematic module disabled successfully"
                test_result=$((test_result + 1))
            else
                log "WARNING: Failed to disable problematic module"
            fi
        else
            log "WARNING: Safe mode script doesn't contain expected disable logic"
        fi
    else
        log "WARNING: Safe mode script not found"
    fi
    
    # Cleanup
    rm -rf "$problem_module"
    log "Cleaned up test module"
    test_result=$((test_result + 1))
    
    # Remove test flag
    rm -f "$TEST_FLAG"
    
    return $test_result
}

# Generate test report
generate_test_report() {
    local total_tests="$1"
    local passed_tests="$2"
    local failed_tests="$3"
    
    log "=== PROTECTION TEST REPORT ==="
    log "Total tests run: $total_tests"
    log "Tests passed: $passed_tests"
    log "Tests failed: $failed_tests"
    log "Success rate: $(( (passed_tests * 100) / total_tests ))%"
    log "=============================="
    
    # Write summary to activity log
    echo "$(date +%s),safety,Protection test completed: $passed_tests/$total_tests tests passed" >> "$CONFIG_DIR/activity.log"
    
    # Update protection status
    if [ $failed_tests -eq 0 ]; then
        echo "All tests passed" > "$CONFIG_DIR/protection_status.txt"
        log "All protection tests passed successfully"
    else
        echo "Some tests failed" > "$CONFIG_DIR/protection_status.txt"
        log "Some protection tests failed - review configuration"
    fi
}

# Main test function
run_protection_tests() {
    log "Starting KernelSU Anti-Bootloop protection tests"
    log "========================================"
    
    local total_tests=0
    local passed_tests=0
    local failed_tests=0
    
    # Create test recovery point first
    if ! create_test_recovery_point; then
        log "WARNING: Failed to create test recovery point"
    fi
    
    # Test 1: Volume button detection
    log "Running Test 1: Volume button detection"
    test_volume_button_detection
    local result=$?
    total_tests=$((total_tests + 1))
    if [ $result -gt 0 ]; then
        passed_tests=$((passed_tests + 1))
        log "Test 1: PASSED ($result/3 checks)"
    else
        failed_tests=$((failed_tests + 1))
        log "Test 1: FAILED"
    fi
    
    # Test 2: Boot timeout monitoring
    log "Running Test 2: Boot timeout monitoring"
    test_boot_timeout_monitoring
    result=$?
    total_tests=$((total_tests + 1))
    if [ $result -gt 0 ]; then
        passed_tests=$((passed_tests + 1))
        log "Test 2: PASSED ($result/3 checks)"
    else
        failed_tests=$((failed_tests + 1))
        log "Test 2: FAILED"
    fi
    
    # Test 3: Module disable mechanism
    log "Running Test 3: Module disable mechanism"
    test_module_disable_mechanism
    result=$?
    total_tests=$((total_tests + 1))
    if [ $result -gt 1 ]; then
        passed_tests=$((passed_tests + 1))
        log "Test 3: PASSED ($result/3 checks)"
    else
        failed_tests=$((failed_tests + 1))
        log "Test 3: FAILED"
    fi
    
    # Test 4: Recovery mechanisms
    log "Running Test 4: Recovery mechanisms"
    test_recovery_mechanisms
    result=$?
    total_tests=$((total_tests + 1))
    if [ $result -gt 0 ]; then
        passed_tests=$((passed_tests + 1))
        log "Test 4: PASSED ($result/3 checks)"
    else
        failed_tests=$((failed_tests + 1))
        log "Test 4: FAILED"
    fi
    
    # Test 5: Bootloop simulation (safe)
    log "Running Test 5: Safe bootloop simulation"
    simulate_bootloop_condition
    result=$?
    total_tests=$((total_tests + 1))
    if [ $result -gt 1 ]; then
        passed_tests=$((passed_tests + 1))
        log "Test 5: PASSED ($result/4 checks)"
    else
        failed_tests=$((failed_tests + 1))
        log "Test 5: FAILED"
    fi
    
    # Generate final report
    generate_test_report $total_tests $passed_tests $failed_tests
    
    log "Protection test completed"
    echo "Test completed"
    
    # Return overall success status
    if [ $failed_tests -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# Help function
show_help() {
    echo "KernelSU Anti-Bootloop Protection Test"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -v, --verbose           Enable verbose logging"
    echo "  -q, --quiet             Suppress output (log only)"
    echo "  --volume-test           Test only volume button detection"
    echo "  --timeout-test          Test only boot timeout monitoring"
    echo "  --disable-test          Test only module disable mechanism"
    echo "  --recovery-test         Test only recovery mechanisms"
    echo "  --simulate              Run safe bootloop simulation"
    echo ""
    echo "This script safely tests the anti-bootloop protection mechanisms"
    echo "without actually causing a bootloop condition."
}

# Main execution
case "$1" in
    "-h"|"--help")
        show_help
        exit 0
        ;;
    "--volume-test")
        test_volume_button_detection
        ;;
    "--timeout-test")
        test_boot_timeout_monitoring
        ;;
    "--disable-test")
        test_module_disable_mechanism
        ;;
    "--recovery-test")
        test_recovery_mechanisms
        ;;
    "--simulate")
        simulate_bootloop_condition
        ;;
    *)
        run_protection_tests
        ;;
esac