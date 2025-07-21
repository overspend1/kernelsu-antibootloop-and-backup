#!/system/bin/sh
# KernelSU Anti-Bootloop & Backup Module - Security Framework
# Advanced security, encryption, and access control system

MODDIR=${0%/*}
MODDIR=${MODDIR%/*}
CONFIG_DIR="$MODDIR/config"
SECURITY_DIR="$CONFIG_DIR/security"
KEYS_DIR="$SECURITY_DIR/keys"
LOGS_DIR="$SECURITY_DIR/logs"
POLICIES_DIR="$SECURITY_DIR/policies"

# Security configuration
SECURITY_LEVEL="high"
ENCRYPTION_ALGORITHM="AES-256-CBC"
KEY_ROTATION_INTERVAL=86400  # 24 hours
SESSION_TIMEOUT=3600  # 1 hour
MAX_LOGIN_ATTEMPTS=3
AUDIT_LOG_RETENTION=30  # days

# Ensure security directories exist with proper permissions
mkdir -p "$SECURITY_DIR" "$KEYS_DIR" "$LOGS_DIR" "$POLICIES_DIR"
chmod 700 "$SECURITY_DIR" "$KEYS_DIR"
chmod 750 "$LOGS_DIR" "$POLICIES_DIR"

# Enhanced security logging
log_security_event() {
    local event_type="$1"
    local event_details="$2"
    local severity="${3:-INFO}"
    local timestamp=$(date +%s)
    local iso_time=$(date -Iseconds)
    
    # Structured security log
    local security_event="{
        \"timestamp\": $timestamp,
        \"iso_time\": \"$iso_time\",
        \"event_type\": \"$event_type\",
        \"details\": \"$event_details\",
        \"severity\": \"$severity\",
        \"source\": \"security_framework\",
        \"pid\": $$,
        \"user\": \"$(whoami)\",
        \"ip_address\": \"$(getprop dhcp.wlan0.ipaddress 2>/dev/null || echo 'unknown')\"
    }"
    
    echo "$security_event" >> "$LOGS_DIR/security_audit.jsonl"
    
    # Also log to main security log
    echo "[$iso_time] [$severity] $event_type: $event_details" >> "$LOGS_DIR/security.log"
    
    # Alert on critical events
    if [ "$severity" = "CRITICAL" ] || [ "$severity" = "ALERT" ]; then
        echo "$security_event" >> "$LOGS_DIR/critical_alerts.jsonl"
        
        # Send immediate notification if possible
        if command -v am >/dev/null 2>&1; then
            am broadcast -a com.android.security.ALERT --es event "$event_type" --es details "$event_details" 2>/dev/null
        fi
    fi
}

# Generate cryptographically secure random key
generate_secure_key() {
    local key_length="${1:-32}"  # Default 256-bit key
    
    # Try multiple sources for entropy
    if [ -c /dev/urandom ]; then
        dd if=/dev/urandom bs=1 count=$key_length 2>/dev/null | base64 -w0
    elif [ -c /dev/random ]; then
        dd if=/dev/random bs=1 count=$key_length 2>/dev/null | base64 -w0
    else
        # Fallback: use timestamp + process info
        echo "$(date +%s%N)$$$(ps | md5sum)" | sha256sum | cut -d' ' -f1 | head -c $((key_length * 2))
    fi
}

# Initialize security system
initialize_security() {
    log_security_event "SYSTEM_INIT" "Security framework initialization started" "INFO"
    
    # Generate master encryption key if not exists
    if [ ! -f "$KEYS_DIR/master.key" ]; then
        log_security_event "KEY_GENERATION" "Generating master encryption key" "INFO"
        
        local master_key=$(generate_secure_key 32)
        echo "$master_key" > "$KEYS_DIR/master.key"
        chmod 600 "$KEYS_DIR/master.key"
        
        # Generate key hash for verification
        echo "$master_key" | sha256sum | cut -d' ' -f1 > "$KEYS_DIR/master.key.hash"
        
        log_security_event "KEY_GENERATED" "Master key generated and secured" "INFO"
    fi
    
    # Generate session keys
    generate_session_key
    
    # Initialize security policies
    initialize_security_policies
    
    # Setup audit logging
    setup_audit_system
    
    # Initialize intrusion detection
    initialize_intrusion_detection
    
    log_security_event "SYSTEM_INIT_COMPLETE" "Security framework initialization completed" "INFO"
}

# Generate temporary session key
generate_session_key() {
    local session_key=$(generate_secure_key 16)
    local session_id="session_$(date +%s)_$$"
    local expiry=$(($(date +%s) + SESSION_TIMEOUT))
    
    # Store session information
    local session_data="{
        \"session_id\": \"$session_id\",
        \"key\": \"$session_key\",
        \"created\": $(date +%s),
        \"expires\": $expiry,
        \"active\": true
    }"
    
    echo "$session_data" > "$KEYS_DIR/current_session.json"
    chmod 600 "$KEYS_DIR/current_session.json"
    
    log_security_event "SESSION_CREATED" "New session key generated: $session_id" "INFO"
    echo "$session_id"
}

# Validate session
validate_session() {
    local provided_session_id="$1"
    
    if [ ! -f "$KEYS_DIR/current_session.json" ]; then
        log_security_event "SESSION_VALIDATION_FAILED" "No active session found" "WARN"
        return 1
    fi
    
    local stored_session_id=$(grep -o '"session_id": *"[^"]*"' "$KEYS_DIR/current_session.json" | cut -d'"' -f4)
    local session_expires=$(grep -o '"expires": *[0-9]*' "$KEYS_DIR/current_session.json" | cut -d: -f2)
    local current_time=$(date +%s)
    
    if [ "$provided_session_id" != "$stored_session_id" ]; then
        log_security_event "SESSION_VALIDATION_FAILED" "Invalid session ID: $provided_session_id" "WARN"
        return 1
    fi
    
    if [ "$current_time" -gt "$session_expires" ]; then
        log_security_event "SESSION_EXPIRED" "Session expired: $provided_session_id" "WARN"
        rm -f "$KEYS_DIR/current_session.json"
        return 1
    fi
    
    log_security_event "SESSION_VALIDATED" "Session validated: $provided_session_id" "DEBUG"
    return 0
}

# Advanced encryption function
encrypt_data() {
    local input_data="$1"
    local output_file="$2"
    local key_file="${3:-$KEYS_DIR/master.key}"
    
    if [ ! -f "$key_file" ]; then
        log_security_event "ENCRYPTION_FAILED" "Key file not found: $key_file" "ERROR"
        return 1
    fi
    
    local encryption_key=$(cat "$key_file")
    local salt=$(generate_secure_key 8)
    local iv=$(generate_secure_key 16)
    
    # Create metadata
    local metadata="{
        \"algorithm\": \"$ENCRYPTION_ALGORITHM\",
        \"salt\": \"$salt\",
        \"iv\": \"$iv\",
        \"timestamp\": $(date +%s),
        \"version\": \"1.0\"
    }"
    
    # Encrypt data
    if command -v openssl >/dev/null 2>&1; then
        # Use OpenSSL for strong encryption
        echo "$input_data" | openssl enc -aes-256-cbc -salt -k "$encryption_key" -iv "$iv" > "$output_file.encrypted" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            echo "$metadata" > "$output_file.meta"
            log_security_event "ENCRYPTION_SUCCESS" "Data encrypted to $output_file" "INFO"
            return 0
        else
            log_security_event "ENCRYPTION_FAILED" "OpenSSL encryption failed" "ERROR"
            return 1
        fi
    else
        # Fallback: simple XOR encryption (less secure)
        log_security_event "ENCRYPTION_FALLBACK" "Using fallback XOR encryption (security warning)" "WARN"
        
        local encrypted=""
        local i=0
        local key_len=${#encryption_key}
        
        while [ $i -lt ${#input_data} ]; do
            local char=$(echo "$input_data" | cut -c$((i+1)))
            local key_char=$(echo "$encryption_key" | cut -c$((i % key_len + 1)))
            local encrypted_char=$(printf "%02x" $(($(printf "%d" "'$char") ^ $(printf "%d" "'$key_char"))))
            encrypted="$encrypted$encrypted_char"
            i=$((i + 1))
        done
        
        echo "$encrypted" > "$output_file.encrypted"
        echo "$metadata" > "$output_file.meta"
        log_security_event "ENCRYPTION_COMPLETE" "Fallback encryption completed" "INFO"
        return 0
    fi
}

# Advanced decryption function
decrypt_data() {
    local encrypted_file="$1"
    local key_file="${2:-$KEYS_DIR/master.key}"
    
    if [ ! -f "$encrypted_file" ] || [ ! -f "$key_file" ]; then
        log_security_event "DECRYPTION_FAILED" "Missing files for decryption" "ERROR"
        return 1
    fi
    
    local encryption_key=$(cat "$key_file")
    local metadata_file="$encrypted_file.meta"
    
    if [ -f "$metadata_file" ]; then
        local algorithm=$(grep -o '"algorithm": *"[^"]*"' "$metadata_file" | cut -d'"' -f4)
        local iv=$(grep -o '"iv": *"[^"]*"' "$metadata_file" | cut -d'"' -f4)
        
        if [ "$algorithm" = "$ENCRYPTION_ALGORITHM" ] && command -v openssl >/dev/null 2>&1; then
            openssl enc -aes-256-cbc -d -k "$encryption_key" -iv "$iv" -in "$encrypted_file" 2>/dev/null
            
            if [ $? -eq 0 ]; then
                log_security_event "DECRYPTION_SUCCESS" "Data decrypted successfully" "INFO"
                return 0
            fi
        fi
    fi
    
    log_security_event "DECRYPTION_FAILED" "Failed to decrypt data" "ERROR"
    return 1
}

# Initialize security policies
initialize_security_policies() {
    local policy_file="$POLICIES_DIR/access_policy.json"
    
    if [ ! -f "$policy_file" ]; then
        cat > "$policy_file" << EOF
{
    "version": "1.0",
    "default_policy": "deny",
    "rules": [
        {
            "id": "webui_access",
            "resource": "webui",
            "action": "access",
            "conditions": {
                "ip_whitelist": ["127.0.0.1", "192.168.0.0/16", "10.0.0.0/8"],
                "max_sessions": 3,
                "require_auth": true
            },
            "effect": "allow"
        },
        {
            "id": "backup_operations",
            "resource": "backup",
            "action": "*",
            "conditions": {
                "require_session": true,
                "require_confirmation": true
            },
            "effect": "allow"
        },
        {
            "id": "system_modifications",
            "resource": "system",
            "action": "modify",
            "conditions": {
                "require_session": true,
                "require_multi_factor": true,
                "logging": "mandatory"
            },
            "effect": "allow"
        }
    ]
}
EOF
        
        log_security_event "POLICIES_INITIALIZED" "Security policies created" "INFO"
    fi
}

# Check access permissions
check_access_permission() {
    local resource="$1"
    local action="$2"
    local session_id="$3"
    local client_ip="$4"
    
    log_security_event "ACCESS_REQUEST" "Resource: $resource, Action: $action, Session: $session_id, IP: $client_ip" "DEBUG"
    
    # Validate session first
    if [ -n "$session_id" ]; then
        if ! validate_session "$session_id"; then
            log_security_event "ACCESS_DENIED" "Invalid session for resource: $resource" "WARN"
            return 1
        fi
    fi
    
    # Check IP whitelist for WebUI access
    if [ "$resource" = "webui" ] && [ -n "$client_ip" ]; then
        if ! is_ip_whitelisted "$client_ip"; then
            log_security_event "ACCESS_DENIED" "IP not whitelisted: $client_ip" "WARN"
            return 1
        fi
    fi
    
    # Check specific resource policies
    case "$resource" in
        "backup")
            if [ -z "$session_id" ]; then
                log_security_event "ACCESS_DENIED" "Session required for backup operations" "WARN"
                return 1
            fi
            ;;
        "system")
            if [ "$action" = "modify" ] && [ -z "$session_id" ]; then
                log_security_event "ACCESS_DENIED" "Session required for system modifications" "WARN"
                return 1
            fi
            ;;
    esac
    
    log_security_event "ACCESS_GRANTED" "Access granted for resource: $resource, action: $action" "INFO"
    return 0
}

# Check if IP is whitelisted
is_ip_whitelisted() {
    local client_ip="$1"
    
    # Always allow localhost
    if [ "$client_ip" = "127.0.0.1" ] || [ "$client_ip" = "::1" ]; then
        return 0
    fi
    
    # Check private IP ranges
    case "$client_ip" in
        192.168.*|10.*|172.1[6-9].*|172.2[0-9].*|172.3[0-1].*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Setup audit system
setup_audit_system() {
    log_security_event "AUDIT_SETUP" "Setting up audit logging system" "INFO"
    
    # Create audit configuration
    cat > "$SECURITY_DIR/audit_config.json" << EOF
{
    "version": "1.0",
    "retention_days": $AUDIT_LOG_RETENTION,
    "log_levels": ["INFO", "WARN", "ERROR", "CRITICAL", "ALERT"],
    "monitored_events": [
        "SESSION_CREATED",
        "SESSION_EXPIRED", 
        "ACCESS_DENIED",
        "ENCRYPTION_*",
        "INTRUSION_*",
        "SYSTEM_MODIFICATION"
    ],
    "alert_conditions": [
        {"pattern": "ACCESS_DENIED", "threshold": 5, "window": 300},
        {"pattern": "INTRUSION_*", "threshold": 1, "window": 60}
    ]
}
EOF
    
    # Setup log rotation
    setup_log_rotation
    
    log_security_event "AUDIT_SETUP_COMPLETE" "Audit system configured successfully" "INFO"
}

# Initialize intrusion detection
initialize_intrusion_detection() {
    log_security_event "IDS_INIT" "Initializing intrusion detection system" "INFO"
    
    # Create baseline file access patterns
    create_baseline_patterns
    
    # Setup file integrity monitoring
    setup_file_integrity_monitoring
    
    # Initialize network monitoring
    initialize_network_monitoring
    
    log_security_event "IDS_INIT_COMPLETE" "Intrusion detection system initialized" "INFO"
}

# Create baseline patterns for anomaly detection
create_baseline_patterns() {
    local baseline_file="$SECURITY_DIR/baseline_patterns.json"
    
    # Collect current system state
    local file_count=$(find "$MODDIR" -type f | wc -l)
    local dir_count=$(find "$MODDIR" -type d | wc -l)
    local total_size=$(du -s "$MODDIR" | awk '{print $1}')
    
    cat > "$baseline_file" << EOF
{
    "created": $(date +%s),
    "module_files": {
        "file_count": $file_count,
        "directory_count": $dir_count,
        "total_size_kb": $total_size
    },
    "critical_files": [
        "$MODDIR/module.prop",
        "$MODDIR/scripts/service.sh",
        "$MODDIR/scripts/boot-monitor.sh",
        "$KEYS_DIR/master.key"
    ],
    "checksums": {}
}
EOF
    
    # Generate checksums for critical files
    for file in "$MODDIR/module.prop" "$MODDIR/scripts/service.sh" "$MODDIR/scripts/boot-monitor.sh"; do
        if [ -f "$file" ]; then
            local checksum=$(sha256sum "$file" | cut -d' ' -f1)
            local rel_path=${file#$MODDIR/}
            
            # Update JSON with checksum (simplified approach)
            sed -i "s/\"checksums\": {}/\"checksums\": {\"$rel_path\": \"$checksum\"}/" "$baseline_file"
        fi
    done
    
    log_security_event "BASELINE_CREATED" "Security baseline patterns created" "INFO"
}

# Setup file integrity monitoring
setup_file_integrity_monitoring() {
    log_security_event "FIM_SETUP" "Setting up file integrity monitoring" "INFO"
    
    # Create file integrity monitor script
    cat > "$SECURITY_DIR/file_monitor.sh" << 'EOF'
#!/system/bin/sh
# File Integrity Monitor

SECURITY_DIR="$1"
MODDIR="$2"

check_file_integrity() {
    local baseline_file="$SECURITY_DIR/baseline_patterns.json"
    local alert_generated=false
    
    if [ ! -f "$baseline_file" ]; then
        return 1
    fi
    
    # Check critical files
    while IFS= read -r file_path; do
        if [ -f "$file_path" ]; then
            local current_checksum=$(sha256sum "$file_path" | cut -d' ' -f1)
            local rel_path=${file_path#$MODDIR/}
            local expected_checksum=$(grep -o "\"$rel_path\": *\"[^\"]*\"" "$baseline_file" | cut -d'"' -f4)
            
            if [ -n "$expected_checksum" ] && [ "$current_checksum" != "$expected_checksum" ]; then
                echo "ALERT: File integrity violation detected: $file_path"
                alert_generated=true
            fi
        else
            echo "ALERT: Critical file missing: $file_path"
            alert_generated=true
        fi
    done << EOL
$MODDIR/module.prop
$MODDIR/scripts/service.sh
$MODDIR/scripts/boot-monitor.sh
EOL
    
    return $alert_generated
}

check_file_integrity
EOF
    
    chmod +x "$SECURITY_DIR/file_monitor.sh"
    log_security_event "FIM_SETUP_COMPLETE" "File integrity monitoring configured" "INFO"
}

# Initialize network monitoring
initialize_network_monitoring() {
    log_security_event "NETMON_INIT" "Initializing network monitoring" "INFO"
    
    # Monitor WebUI connections
    if command -v netstat >/dev/null 2>&1; then
        # Create network monitoring script
        cat > "$SECURITY_DIR/network_monitor.sh" << 'EOF'
#!/system/bin/sh
# Network Security Monitor

monitor_connections() {
    local suspicious_count=0
    
    # Check for unusual connection patterns
    local connection_count=$(netstat -an 2>/dev/null | grep ":8080" | grep ESTABLISHED | wc -l)
    
    if [ "$connection_count" -gt 10 ]; then
        echo "ALERT: High number of WebUI connections detected: $connection_count"
        suspicious_count=$((suspicious_count + 1))
    fi
    
    # Check for connections from external IPs
    netstat -an 2>/dev/null | grep ":8080" | grep ESTABLISHED | while read line; do
        local remote_ip=$(echo "$line" | awk '{print $5}' | cut -d: -f1)
        
        case "$remote_ip" in
            127.*|192.168.*|10.*|172.1[6-9].*|172.2[0-9].*|172.3[0-1].*)
                # Private IP, OK
                ;;
            *)
                echo "ALERT: External connection detected from: $remote_ip"
                suspicious_count=$((suspicious_count + 1))
                ;;
        esac
    done
    
    return $suspicious_count
}

monitor_connections
EOF
        
        chmod +x "$SECURITY_DIR/network_monitor.sh"
        log_security_event "NETMON_INIT_COMPLETE" "Network monitoring initialized" "INFO"
    else
        log_security_event "NETMON_UNAVAILABLE" "Network monitoring unavailable (netstat not found)" "WARN"
    fi
}

# Setup log rotation
setup_log_rotation() {
    log_security_event "LOG_ROTATION_SETUP" "Setting up log rotation" "INFO"
    
    # Create log rotation script
    cat > "$SECURITY_DIR/rotate_logs.sh" << EOF
#!/system/bin/sh
# Security Log Rotation

LOGS_DIR="$LOGS_DIR"
RETENTION_DAYS=$AUDIT_LOG_RETENTION

rotate_logs() {
    local cutoff_time=\$((\$(date +%s) - RETENTION_DAYS * 86400))
    
    # Rotate security audit logs
    if [ -f "\$LOGS_DIR/security_audit.jsonl" ]; then
        awk -v cutoff=\$cutoff_time '{if (match(\$0, /"timestamp": *([0-9]+)/, arr) && arr[1] > cutoff) print}' "\$LOGS_DIR/security_audit.jsonl" > "\$LOGS_DIR/security_audit.jsonl.tmp"
        mv "\$LOGS_DIR/security_audit.jsonl.tmp" "\$LOGS_DIR/security_audit.jsonl"
    fi
    
    # Archive old critical alerts
    if [ -f "\$LOGS_DIR/critical_alerts.jsonl" ]; then
        local archive_file="\$LOGS_DIR/critical_alerts_\$(date +%Y%m%d).jsonl"
        mv "\$LOGS_DIR/critical_alerts.jsonl" "\$archive_file"
        touch "\$LOGS_DIR/critical_alerts.jsonl"
        
        # Compress old archives
        find "\$LOGS_DIR" -name "critical_alerts_*.jsonl" -mtime +7 -exec gzip {} \;
    fi
}

rotate_logs
EOF
    
    chmod +x "$SECURITY_DIR/rotate_logs.sh"
    log_security_event "LOG_ROTATION_SETUP_COMPLETE" "Log rotation configured" "INFO"
}

# Main security daemon
security_daemon() {
    log_security_event "SECURITY_DAEMON_START" "Security daemon starting" "INFO"
    
    local check_interval=60  # 1 minute
    
    while true; do
        # Run file integrity monitoring
        if [ -f "$SECURITY_DIR/file_monitor.sh" ]; then
            local fim_result=$(sh "$SECURITY_DIR/file_monitor.sh" "$SECURITY_DIR" "$MODDIR" 2>&1)
            if [ -n "$fim_result" ]; then
                log_security_event "INTRUSION_DETECTED" "FIM Alert: $fim_result" "ALERT"
            fi
        fi
        
        # Run network monitoring
        if [ -f "$SECURITY_DIR/network_monitor.sh" ]; then
            local netmon_result=$(sh "$SECURITY_DIR/network_monitor.sh" 2>&1)
            if [ -n "$netmon_result" ]; then
                log_security_event "INTRUSION_DETECTED" "Network Alert: $netmon_result" "ALERT"
            fi
        fi
        
        # Rotate logs if needed
        if [ $(($(date +%s) % 3600)) -eq 0 ]; then  # Every hour
            sh "$SECURITY_DIR/rotate_logs.sh"
        fi
        
        # Clean expired sessions
        clean_expired_sessions
        
        sleep $check_interval
    done
}

# Clean expired sessions
clean_expired_sessions() {
    if [ -f "$KEYS_DIR/current_session.json" ]; then
        local session_expires=$(grep -o '"expires": *[0-9]*' "$KEYS_DIR/current_session.json" | cut -d: -f2)
        local current_time=$(date +%s)
        
        if [ "$current_time" -gt "$session_expires" ]; then
            rm -f "$KEYS_DIR/current_session.json"
            log_security_event "SESSION_CLEANUP" "Expired session cleaned up" "DEBUG"
        fi
    fi
}

# Command processing
case "$1" in
    "init")
        initialize_security
        ;;
    "daemon")
        security_daemon
        ;;
    "generate-session")
        generate_session_key
        ;;
    "validate-session")
        validate_session "$2"
        ;;
    "encrypt")
        encrypt_data "$2" "$3" "$4"
        ;;
    "decrypt")
        decrypt_data "$2" "$3"
        ;;
    "check-access")
        check_access_permission "$2" "$3" "$4" "$5"
        ;;
    "status")
        echo "Security Framework Status:"
        echo "- Master key: $([ -f "$KEYS_DIR/master.key" ] && echo "Present" || echo "Missing")"
        echo "- Active session: $([ -f "$KEYS_DIR/current_session.json" ] && echo "Yes" || echo "No")"
        echo "- Security level: $SECURITY_LEVEL"
        echo "- Audit logs: $([ -f "$LOGS_DIR/security_audit.jsonl" ] && wc -l < "$LOGS_DIR/security_audit.jsonl" || echo 0) entries"
        ;;
    *)
        echo "Usage: $0 {init|daemon|generate-session|validate-session|encrypt|decrypt|check-access|status}"
        echo "Security Framework Commands:"
        echo "  init                     - Initialize security system"
        echo "  daemon                   - Start security monitoring daemon"
        echo "  generate-session         - Generate new session key"
        echo "  validate-session <id>    - Validate session ID"
        echo "  encrypt <data> <output>  - Encrypt data"
        echo "  decrypt <file>           - Decrypt file"
        echo "  check-access <resource> <action> <session> <ip> - Check access permissions"
        echo "  status                   - Show security status"
        exit 1
        ;;
esac