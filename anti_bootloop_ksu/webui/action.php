<?php
/**
 * KernelSU-Next WebUI Action Handler
 * Advanced Anti-Bootloop KSU Module
 * Author: @overspend1/Wiktor
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

$action = $_GET['action'] ?? $_POST['action'] ?? '';
$moddir = '/data/adb/modules/anti_bootloop_advanced_ksu';

function execCommand($cmd) {
    $output = shell_exec($cmd . ' 2>&1');
    return $output ?: '';
}

function getModuleStatus() {
    global $moddir;
    
    $bootCount = file_exists('/data/local/tmp/antibootloop/boot_count') ? 
        (int)file_get_contents('/data/local/tmp/antibootloop/boot_count') : 0;
    
    $recoveryState = file_exists('/data/local/tmp/antibootloop/recovery_state') ? 
        trim(file_get_contents('/data/local/tmp/antibootloop/recovery_state')) : 'normal';
    
    $totalBoots = file_exists('/data/local/tmp/antibootloop/total_boots') ? 
        (int)file_get_contents('/data/local/tmp/antibootloop/total_boots') : 0;
    
    $uptime = (float)explode(' ', file_get_contents('/proc/uptime'))[0];
    $safeModeActive = file_exists('/data/local/tmp/antibootloop/safe_mode_active');
    
    // Get device info
    $device = trim(execCommand('getprop ro.product.device'));
    $androidVersion = trim(execCommand('getprop ro.build.version.release'));
    $kernelVersion = trim(execCommand('uname -r'));
    
    return [
        'status' => 'running',
        'boot_count' => $bootCount,
        'max_attempts' => 3, // Default value
        'recovery_state' => $recoveryState,
        'total_boots' => $totalBoots,
        'uptime' => $uptime,
        'device' => $device,
        'android_version' => $androidVersion,
        'kernel_version' => $kernelVersion,
        'module_version' => '2.0',
        'safe_mode' => $safeModeActive,
        'timestamp' => date('Y-m-d H:i:s')
    ];
}

function getHardwareStatus() {
    // CPU Temperature
    $cpuTemp = 0;
    $tempFiles = [
        '/sys/class/thermal/thermal_zone0/temp',
        '/sys/class/thermal/thermal_zone1/temp',
        '/sys/devices/virtual/thermal/thermal_zone0/temp'
    ];
    
    foreach ($tempFiles as $file) {
        if (file_exists($file)) {
            $temp = (int)file_get_contents($file);
            if ($temp > 0) {
                $cpuTemp = intval($temp / 1000); // Convert to Celsius
                break;
            }
        }
    }
    
    // Available RAM
    $availableRam = 0;
    if (file_exists('/proc/meminfo')) {
        $meminfo = file_get_contents('/proc/meminfo');
        if (preg_match('/MemAvailable:\s+(\d+) kB/', $meminfo, $matches)) {
            $availableRam = intval($matches[1] / 1024); // Convert to MB
        }
    }
    
    // Storage health (simplified)
    $storageHealth = 'unknown';
    if (file_exists('/sys/class/mmc_host/mmc0/mmc0:0001/life_time')) {
        $storageHealth = trim(file_get_contents('/sys/class/mmc_host/mmc0/mmc0:0001/life_time'));
    }
    
    return [
        'cpu_temperature' => $cpuTemp,
        'available_ram_mb' => $availableRam,
        'storage_health' => $storageHealth,
        'hardware_issues' => '',
        'monitoring' => [
            'cpu_temp_enabled' => true,
            'cpu_temp_threshold' => 75,
            'ram_enabled' => true,
            'min_free_ram' => 200
        ]
    ];
}

function getBackups() {
    $backupDir = '/data/local/tmp/antibootloop/kernels';
    $backups = [];
    
    if (is_dir($backupDir)) {
        $files = glob($backupDir . '/*.img');
        foreach ($files as $file) {
            $name = basename($file, '.img');
            $size = filesize($file);
            $created = date('Y-m-d H:i:s', filemtime($file));
            $hashFile = $backupDir . '/' . $name . '.sha256';
            $hasHash = file_exists($hashFile);
            
            $backups[] = [
                'name' => $name,
                'size' => $size,
                'created' => $created,
                'has_hash' => $hasHash
            ];
        }
    }
    
    return $backups;
}

function getLogs($lines = 100) {
    $logFile = '/data/local/tmp/antibootloop/detailed.log';
    if (file_exists($logFile)) {
        return execCommand("tail -n {$lines} '{$logFile}'");
    }
    return 'No logs available';
}

// Main action handler
$response = ['success' => false, 'message' => 'Unknown action'];

try {
    switch ($action) {
        case 'status':
            $response = ['success' => true, 'data' => getModuleStatus()];
            break;
            
        case 'hardware':
            $response = ['success' => true, 'data' => getHardwareStatus()];
            break;
            
        case 'backups':
            $response = ['success' => true, 'data' => getBackups()];
            break;
            
        case 'logs':
            $lines = (int)($_GET['lines'] ?? $_POST['lines'] ?? 100);
            $logs = getLogs($lines);
            $response = ['success' => true, 'data' => ['logs' => $logs, 'lines' => $lines]];
            break;
            
        case 'create_backup':
            $name = $_POST['name'] ?? 'backup_' . date('Ymd_His');
            $description = $_POST['description'] ?? 'WebUI created backup';
            $cmd = "sh {$moddir}/backup_manager.sh create_backup '{$name}' '{$description}' true";
            $output = execCommand($cmd);
            $response = ['success' => true, 'message' => 'Backup creation initiated', 'output' => $output];
            break;
            
        case 'restore_backup':
            $backupName = $_POST['backup'] ?? '';
            if ($backupName) {
                $cmd = "sh {$moddir}/backup_manager.sh restore_backup '{$backupName}' true";
                $output = execCommand($cmd);
                $response = ['success' => true, 'message' => 'Backup restoration initiated', 'output' => $output];
            } else {
                $response = ['success' => false, 'message' => 'Backup name required'];
            }
            break;
            
        case 'emergency_disable':
            execCommand('touch /data/local/tmp/disable_antibootloop');
            $response = ['success' => true, 'message' => 'Emergency disable activated'];
            break;
            
        case 'reset_boot_counter':
            execCommand('echo "0" > /data/local/tmp/antibootloop/boot_count');
            $response = ['success' => true, 'message' => 'Boot counter reset'];
            break;
            
        case 'enable_safe_mode':
            execCommand('touch /data/local/tmp/antibootloop/safe_mode_active');
            $response = ['success' => true, 'message' => 'Safe mode enabled'];
            break;
            
        case 'webui_status':
            $isRunning = execCommand('sh ' . $moddir . '/webui_manager.sh status');
            $response = ['success' => true, 'data' => ['status' => $isRunning, 'port' => 8888]];
            break;
            
        default:
            $response = ['success' => false, 'message' => 'Invalid action: ' . $action];
            break;
    }
} catch (Exception $e) {
    $response = ['success' => false, 'message' => 'Error: ' . $e->getMessage()];
}

echo json_encode($response);
?>