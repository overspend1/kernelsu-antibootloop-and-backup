/**
 * KernelSU Anti-Bootloop & Backup WebUI
 * Main JavaScript Application
 */

// KernelSU API Integration
const KSU_API = {
    exec: window.ksu?.exec || function(cmd) {
        console.log('Mock exec:', cmd);
        return Promise.resolve({ code: 0, out: 'Mock output for: ' + cmd, err: '' });
    },
    toast: window.ksu?.toast || function(msg, type = 'info') {
        console.log('Toast:', msg, type);
        showToast(msg, type);
    },
    moduleInfo: window.ksu?.moduleInfo || function() {
        return { 
            id: 'kernelsu_antibootloop_backup', 
            version: '1.0.0',
            name: 'KernelSU Anti-Bootloop & Backup',
            author: 'KernelSU Community'
        };
    },
    getModuleProp: window.ksu?.getModuleProp || function(key) {
        const props = {
            'id': 'kernelsu_antibootloop_backup',
            'name': 'KernelSU Anti-Bootloop & Backup',
            'version': 'v1.0.0',
            'versionCode': '1',
            'author': 'KernelSU Community',
            'description': 'Advanced system protection and backup management'
        };
        return props[key] || '';
    }
};

// Module Configuration
const MODULE_CONFIG = {
    MODULE_PATH: '/data/adb/modules/kernelsu_antibootloop_backup',
    SCRIPTS_PATH: '/data/adb/modules/kernelsu_antibootloop_backup/scripts',
    BACKUP_PATH: '/data/adb/modules/kernelsu_antibootloop_backup/backups',
    LOG_PATH: '/data/adb/modules/kernelsu_antibootloop_backup/logs',
    CONFIG_PATH: '/data/adb/modules/kernelsu_antibootloop_backup/config'
};

// Application State - using MainAppState from main.js
// MainAppState is defined in main.js and available globally

// Utility Functions
class Utils {
    static showLoading() {
        MainAppState.isLoading = true;
        const loadingEl = document.getElementById('loading');
        if (loadingEl) {
            loadingEl.classList.add('show');
        }
    }

    static hideLoading() {
        MainAppState.isLoading = false;
        const loadingEl = document.getElementById('loading');
        if (loadingEl) {
            loadingEl.classList.remove('show');
        }
    }

    static addLogEntry(message, type = 'info') {
        const timestamp = new Date().toLocaleTimeString();
        const logEntry = {
            timestamp,
            message,
            type
        };
        
        MainAppState.logs.push(logEntry);
        
        const logsViewer = document.getElementById('logs-viewer');
        if (logsViewer) {
            const logElement = document.createElement('div');
            logElement.className = `log-entry ${type}`;
            logElement.textContent = `[${timestamp}] [${type.toUpperCase()}] ${message}`;
            logsViewer.appendChild(logElement);
            logsViewer.scrollTop = logsViewer.scrollHeight;
        }
    }

    static formatBytes(bytes) {
        if (bytes === 0) return '0 Bytes';
        const k = 1024;
        const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
    }

    static formatDate(date) {
        return new Date(date).toLocaleString();
    }

    static debounce(func, wait) {
        let timeout;
        return function executedFunction(...args) {
            const later = () => {
                clearTimeout(timeout);
                func(...args);
            };
            clearTimeout(timeout);
            timeout = setTimeout(later, wait);
        };
    }
}

// Toast Notification System
function showToast(message, type = 'info', duration = 3000) {
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.innerHTML = `
        <div style="display: flex; align-items: center; gap: 8px;">
            <span>${message}</span>
            <button onclick="this.parentElement.parentElement.remove()" style="background: none; border: none; color: inherit; cursor: pointer; font-size: 1.2rem;">&times;</button>
        </div>
    `;
    
    document.body.appendChild(toast);
    
    // Show toast
    setTimeout(() => toast.classList.add('show'), 100);
    
    // Auto remove
    setTimeout(() => {
        toast.classList.remove('show');
        setTimeout(() => toast.remove(), 300);
    }, duration);
}

// Tab Management
function switchTab(tabName) {
    // Remove active class from all tabs and content
    document.querySelectorAll('.nav-tab').forEach(tab => tab.classList.remove('active'));
    document.querySelectorAll('.tab-content').forEach(content => content.classList.remove('active'));
    
    // Add active class to selected tab and content
    document.querySelector(`[onclick="switchTab('${tabName}')"]`).classList.add('active');
    document.getElementById(`${tabName}-tab`).classList.add('active');
    
    MainAppState.currentTab = tabName;
    
    // Load tab-specific data
    switch(tabName) {
        case 'backup':
            loadBackupList();
            break;
        case 'monitor':
            loadSystemMetrics();
            break;
        case 'settings':
            loadSettings();
            break;
    }
}

// Settings Management
function updateSetting(key, value) {
    MainAppState.settings[key] = value;
    saveSettings();
    applySetting(key, value);
    Utils.addLogEntry(`Setting updated: ${key} = ${value}`, 'info');
}

function saveSettings() {
    if (MainAppState.isKernelSUAvailable) {
        const settingsJson = JSON.stringify(MainAppState.settings);
        KSU_API.exec(`echo '${settingsJson}' > ${MODULE_CONFIG.CONFIG_PATH}/settings.json`);
    } else {
        localStorage.setItem('kernelsu_settings', JSON.stringify(MainAppState.settings));
    }
}

function loadSettings() {
    if (MainAppState.isKernelSUAvailable) {
        KSU_API.exec(`cat ${MODULE_CONFIG.CONFIG_PATH}/settings.json`).then(result => {
            if (result.code === 0 && result.out.trim()) {
                try {
                    MainAppState.settings = { ...MainAppState.settings, ...JSON.parse(result.out) };
                    updateSettingsUI();
                } catch (e) {
                    console.warn('Failed to parse settings:', e);
                }
            }
        });
    } else {
        const saved = localStorage.getItem('kernelsu_settings');
        if (saved) {
            try {
                MainAppState.settings = { ...MainAppState.settings, ...JSON.parse(saved) };
                updateSettingsUI();
            } catch (e) {
                console.warn('Failed to parse saved settings:', e);
            }
        }
    }
}

function updateSettingsUI() {
    document.getElementById('auto-backup').checked = MainAppState.settings.autoBackup;
    document.getElementById('backup-interval').value = MainAppState.settings.backupInterval;
    document.getElementById('max-backups').value = MainAppState.settings.maxBackups;
    document.getElementById('monitoring-enabled').checked = MainAppState.settings.monitoringEnabled;
    document.getElementById('alert-threshold').value = MainAppState.settings.alertThreshold;
    document.getElementById('theme-select').value = MainAppState.settings.theme;
    document.getElementById('animations-enabled').checked = MainAppState.settings.animationsEnabled;
}

function applySetting(key, value) {
    switch(key) {
        case 'theme':
            applyTheme(value);
            break;
        case 'animationsEnabled':
            document.body.style.setProperty('--animation-duration', value ? '0.3s' : '0s');
            break;
        case 'monitoringEnabled':
            if (value && MainAppState.realTimeMonitoring) {
                startRealTimeMonitoring();
            } else {
                stopRealTimeMonitoring();
            }
            break;
    }
}

function applyTheme(theme) {
    const body = document.body;
    body.classList.remove('theme-light', 'theme-dark');
    
    if (theme === 'light') {
        body.classList.add('theme-light');
    } else if (theme === 'dark') {
        body.classList.add('theme-dark');
    }
    // 'auto' uses system preference (default CSS)
}

// Real-time Monitoring
let monitoringInterval;

function toggleRealTimeMonitoring() {
    if (MainAppState.realTimeMonitoring) {
        stopRealTimeMonitoring();
    } else {
        startRealTimeMonitoring();
    }
}

function startRealTimeMonitoring() {
    if (!MainAppState.settings.monitoringEnabled) {
        KSU_API.toast('Monitoring is disabled in settings', 'warning');
        return;
    }
    
    MainAppState.realTimeMonitoring = true;
    const btn = document.getElementById('realtime-btn');
    btn.innerHTML = '<span class="btn-icon">⏸️</span><span>Stop Real-time</span>';
    
    Utils.addLogEntry('Real-time monitoring started', 'info');
    
    monitoringInterval = setInterval(() => {
        loadSystemMetrics();
    }, 2000);
}

function stopRealTimeMonitoring() {
    MainAppState.realTimeMonitoring = false;
    const btn = document.getElementById('realtime-btn');
    btn.innerHTML = '<span class="btn-icon">▶️</span><span>Start Real-time</span>';
    
    if (monitoringInterval) {
        clearInterval(monitoringInterval);
        monitoringInterval = null;
    }
    
    Utils.addLogEntry('Real-time monitoring stopped', 'info');
}

// System Metrics
async function loadSystemMetrics() {
    try {
        // CPU Usage
        const cpuResult = await KSU_API.exec("grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$3+$4)} END {print usage}'");
        if (cpuResult.code === 0) {
            MainAppState.metrics.cpu = Math.round(parseFloat(cpuResult.out) || 0);
        }
        
        // Memory Usage
        const memResult = await KSU_API.exec("free | grep Mem | awk '{print ($3/$2) * 100.0}'");
        if (memResult.code === 0) {
            MainAppState.metrics.memory = Math.round(parseFloat(memResult.out) || 0);
        }
        
        // Storage Usage
        const storageResult = await KSU_API.exec("df /data | tail -1 | awk '{print $5}' | sed 's/%//'");
        if (storageResult.code === 0) {
            MainAppState.metrics.storage = parseInt(storageResult.out) || 0;
        }
        
        // Temperature (if available)
        const tempResult = await KSU_API.exec("cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo '0'");
        if (tempResult.code === 0) {
            MainAppState.metrics.temperature = Math.round(parseInt(tempResult.out) / 1000) || 0;
        }
        
        updateMetricsUI();
        
        // Check thresholds
        checkAlertThresholds();
        
    } catch (error) {
        console.warn('Error loading system metrics:', error);
        // Use mock data for development
        MainAppState.metrics = {
            cpu: Math.round(Math.random() * 100),
            memory: Math.round(Math.random() * 100),
            storage: Math.round(Math.random() * 100),
            temperature: Math.round(30 + Math.random() * 40)
        };
        updateMetricsUI();
    }
}

function updateMetricsUI() {
    document.getElementById('cpu-usage').textContent = `${MainAppState.metrics.cpu}%`;
    document.getElementById('memory-usage').textContent = `${MainAppState.metrics.memory}%`;
    document.getElementById('storage-usage').textContent = `${MainAppState.metrics.storage}%`;
    document.getElementById('temperature').textContent = `${MainAppState.metrics.temperature}°C`;
    
    // Update chart visualizations (simple progress bars)
    updateMetricChart('cpu-chart', MainAppState.metrics.cpu);
    updateMetricChart('memory-chart', MainAppState.metrics.memory);
    updateMetricChart('storage-chart', MainAppState.metrics.storage);
    updateMetricChart('temp-chart', Math.min(MainAppState.metrics.temperature, 100));
}

function updateMetricChart(chartId, value) {
    const chart = document.getElementById(chartId);
    if (chart) {
        const percentage = Math.min(value, 100);
        chart.style.background = `linear-gradient(90deg, #667eea ${percentage}%, #667eea20 ${percentage}%)`;
    }
}

function checkAlertThresholds() {
    const threshold = MainAppState.settings.alertThreshold;
    
    if (MainAppState.metrics.cpu > threshold) {
        KSU_API.toast(`High CPU usage: ${MainAppState.metrics.cpu}%`, 'warning');
    }
    if (MainAppState.metrics.memory > threshold) {
        KSU_API.toast(`High memory usage: ${MainAppState.metrics.memory}%`, 'warning');
    }
    if (MainAppState.metrics.storage > threshold) {
        KSU_API.toast(`High storage usage: ${MainAppState.metrics.storage}%`, 'warning');
    }
    if (MainAppState.metrics.temperature > 70) {
        KSU_API.toast(`High temperature: ${MainAppState.metrics.temperature}°C`, 'warning');
    }
}

function exportMetrics() {
    const data = {
        timestamp: new Date().toISOString(),
        metrics: MainAppState.metrics,
        systemHealth: MainAppState.systemHealth
    };
    
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `system-metrics-${new Date().toISOString().split('T')[0]}.json`;
    a.click();
    URL.revokeObjectURL(url);
    
    Utils.addLogEntry('System metrics exported', 'success');
}

// Enhanced Backup Management
async function loadBackupList() {
    try {
        const result = await KSU_API.exec(`sh ${MODULE_CONFIG.SCRIPTS_PATH}/backup-engine.sh list_backups_detailed`);
        
        if (result.code === 0) {
            const backups = result.out.split('\n').filter(line => line.trim()).map(line => {
                const parts = line.split('|');
                return {
                    name: parts[0] || 'Unknown',
                    date: parts[1] || 'Unknown',
                    size: parts[2] || '0',
                    type: parts[3] || 'full'
                };
            });
            
            MainAppState.backupList = backups;
            updateBackupListUI();
        } else {
            // Mock data for development
            MainAppState.backupList = [
                { name: 'backup_2024_01_15_10_30', date: '2024-01-15 10:30:00', size: '2.5GB', type: 'full' },
                { name: 'backup_2024_01_14_22_15', date: '2024-01-14 22:15:00', size: '1.2GB', type: 'incremental' },
                { name: 'backup_2024_01_13_18_45', date: '2024-01-13 18:45:00', size: '2.3GB', type: 'full' }
            ];
            updateBackupListUI();
        }
    } catch (error) {
        console.warn('Error loading backup list:', error);
    }
}

function updateBackupListUI() {
    const container = document.getElementById('backup-items');
    if (!container) return;
    
    container.innerHTML = '';
    
    if (MainAppState.backupList.length === 0) {
        container.innerHTML = '<p style="text-align: center; color: #666; padding: 20px;">No backups found</p>';
        return;
    }
    
    MainAppState.backupList.forEach(backup => {
        const item = document.createElement('div');
        item.className = 'backup-item';
        item.innerHTML = `
            <div class="backup-info">
                <div class="backup-name">${backup.name}</div>
                <div class="backup-date">${Utils.formatDate(backup.date)}</div>
                <div class="backup-size">${backup.size} • ${backup.type}</div>
            </div>
            <div class="backup-actions">
                <button class="backup-btn restore" onclick="restoreBackupAdvanced('${backup.name}')" title="Restore this backup">Restore</button>
                <button class="backup-btn delete" onclick="deleteBackupAdvanced('${backup.name}')" title="Delete this backup">Delete</button>
            </div>
        `;
        container.appendChild(item);
    });
}

async function createScheduledBackup() {
    const interval = prompt('Enter backup interval in hours (1-168):', '24');
    if (!interval || isNaN(interval) || interval < 1 || interval > 168) {
        KSU_API.toast('Invalid interval. Please enter a number between 1 and 168.', 'error');
        return;
    }
    
    Utils.showLoading();
    Utils.addLogEntry(`Setting up scheduled backup every ${interval} hours...`, 'info');
    
    try {
        const result = await KSU_API.exec(`sh ${MODULE_CONFIG.SCRIPTS_PATH}/backup-scheduler.sh setup_schedule ${interval}`);
        
        if (result.code === 0) {
            Utils.addLogEntry('Scheduled backup configured successfully', 'success');
            KSU_API.toast(`Backup scheduled every ${interval} hours`, 'success');
            MainAppState.settings.autoBackup = true;
            MainAppState.settings.backupInterval = parseInt(interval);
            updateSettingsUI();
            saveSettings();
        } else {
            Utils.addLogEntry(`Failed to schedule backup: ${result.err}`, 'error');
            KSU_API.toast('Failed to schedule backup', 'error');
        }
    } catch (error) {
        Utils.addLogEntry(`Error scheduling backup: ${error.message}`, 'error');
        KSU_API.toast('Error scheduling backup', 'error');
    }
    
    Utils.hideLoading();
}

async function createIncrementalBackup() {
    Utils.showLoading();
    Utils.addLogEntry('Creating incremental backup...', 'info');
    
    try {
        const result = await KSU_API.exec(`sh ${MODULE_CONFIG.SCRIPTS_PATH}/backup-engine.sh create_incremental_backup`);
        
        if (result.code === 0) {
            Utils.addLogEntry('Incremental backup created successfully', 'success');
            KSU_API.toast('Incremental backup created!', 'success');
            loadBackupList();
        } else {
            Utils.addLogEntry(`Incremental backup failed: ${result.err}`, 'error');
            KSU_API.toast('Incremental backup failed', 'error');
        }
    } catch (error) {
        Utils.addLogEntry(`Error creating incremental backup: ${error.message}`, 'error');
        KSU_API.toast('Error creating incremental backup', 'error');
    }
    
    Utils.hideLoading();
}

async function exportBackupAdvanced() {
    if (MainAppState.backupList.length === 0) {
        KSU_API.toast('No backups available to export', 'warning');
        return;
    }
    
    const backupName = prompt('Enter backup name to export:', MainAppState.backupList[0].name);
    if (!backupName) return;
    
    Utils.showLoading();
    Utils.addLogEntry(`Exporting backup: ${backupName}...`, 'info');
    
    try {
        const result = await KSU_API.exec(`sh ${MODULE_CONFIG.SCRIPTS_PATH}/backup-engine.sh export_backup "${backupName}"`);
        
        if (result.code === 0) {
            Utils.addLogEntry('Backup exported successfully', 'success');
            KSU_API.toast('Backup exported to /sdcard/KernelSU_Backups/', 'success');
        } else {
            Utils.addLogEntry(`Export failed: ${result.err}`, 'error');
            KSU_API.toast('Export failed', 'error');
        }
    } catch (error) {
        Utils.addLogEntry(`Error exporting backup: ${error.message}`, 'error');
        KSU_API.toast('Error exporting backup', 'error');
    }
    
    Utils.hideLoading();
}

async function importBackupAdvanced() {
    const backupPath = prompt('Enter backup file path:', '/sdcard/backup.tar.gz');
    if (!backupPath) return;
    
    Utils.showLoading();
    Utils.addLogEntry(`Importing backup from: ${backupPath}...`, 'info');
    
    try {
        const result = await KSU_API.exec(`sh ${MODULE_CONFIG.SCRIPTS_PATH}/backup-engine.sh import_backup "${backupPath}"`);
        
        if (result.code === 0) {
            Utils.addLogEntry('Backup imported successfully', 'success');
            KSU_API.toast('Backup imported successfully!', 'success');
            loadBackupList();
        } else {
            Utils.addLogEntry(`Import failed: ${result.err}`, 'error');
            KSU_API.toast('Import failed', 'error');
        }
    } catch (error) {
        Utils.addLogEntry(`Error importing backup: ${error.message}`, 'error');
        KSU_API.toast('Error importing backup', 'error');
    }
    
    Utils.hideLoading();
}

async function deleteBackupAdvanced(backupName) {
    if (!confirm(`Are you sure you want to delete backup: ${backupName}?`)) {
        return;
    }
    
    Utils.showLoading();
    Utils.addLogEntry(`Deleting backup: ${backupName}...`, 'info');
    
    try {
        const result = await KSU_API.exec(`sh ${MODULE_CONFIG.SCRIPTS_PATH}/backup-engine.sh delete_backup "${backupName}"`);
        
        if (result.code === 0) {
            Utils.addLogEntry('Backup deleted successfully', 'success');
            KSU_API.toast('Backup deleted', 'success');
            loadBackupList();
        } else {
            Utils.addLogEntry(`Delete failed: ${result.err}`, 'error');
            KSU_API.toast('Delete failed', 'error');
        }
    } catch (error) {
        Utils.addLogEntry(`Error deleting backup: ${error.message}`, 'error');
        KSU_API.toast('Error deleting backup', 'error');
    }
    
    Utils.hideLoading();
}

// Main Application Functions
class BackupManager {
    static async createBackup() {
        Utils.showLoading();
        Utils.addLogEntry('Starting backup process...', 'info');
        
        try {
            const result = await KSU_API.exec(`sh ${MODULE_CONFIG.SCRIPTS_PATH}/backup-engine.sh create_backup`);
            
            if (result.code === 0) {
                Utils.addLogEntry('Backup created successfully', 'success');
                KSU_API.toast('Backup created successfully!', 'success');
                await StatusManager.updateBackupStatus();
            } else {
                Utils.addLogEntry(`Backup failed: ${result.err}`, 'error');
                KSU_API.toast('Backup failed. Check logs for details.', 'error');
            }
        } catch (error) {
            Utils.addLogEntry(`Error creating backup: ${error.message}`, 'error');
            KSU_API.toast('Error creating backup', 'error');
        }
        
        Utils.hideLoading();
    }

    static async listBackups() {
        Utils.showLoading();
        Utils.addLogEntry('Listing available backups...', 'info');
        
        try {
            const result = await KSU_API.exec(`sh ${MODULE_CONFIG.SCRIPTS_PATH}/backup-engine.sh list_backups`);
            
            if (result.code === 0) {
                Utils.addLogEntry('Available backups:', 'info');
                const backups = result.out.split('\n').filter(line => line.trim());
                
                if (backups.length > 0) {
                    backups.forEach(backup => {
                        Utils.addLogEntry(`  - ${backup}`, 'info');
                    });
                } else {
                    Utils.addLogEntry('No backups found', 'warning');
                }
            } else {
                Utils.addLogEntry('Error listing backups', 'error');
            }
        } catch (error) {
            Utils.addLogEntry(`Error listing backups: ${error.message}`, 'error');
        }
        
        Utils.hideLoading();
    }

    static async restoreBackup(backupName) {
        // This function is now handled by the global restoreBackupAdvanced function
        return restoreBackupAdvanced(backupName);
    }
}

// Global restore function for UI compatibility
async function restoreBackupAdvanced(backupName) {
    if (!confirm(`Are you sure you want to restore backup: ${backupName}?\n\nThis will restart your device after restoration.`)) {
        return;
    }
    
    Utils.showLoading();
    Utils.addLogEntry(`Starting restore of backup: ${backupName}`, 'info');
    
    try {
        const result = await KSU_API.exec(`sh ${MODULE_CONFIG.SCRIPTS_PATH}/backup-engine.sh restore_backup "${backupName}"`);
        
        if (result.code === 0) {
            Utils.addLogEntry('Backup restored successfully', 'success');
            KSU_API.toast('Backup restored successfully!', 'success');
        } else {
            Utils.addLogEntry(`Restore failed: ${result.err}`, 'error');
            KSU_API.toast('Restore failed. Check logs for details.', 'error');
        }
    } catch (error) {
        Utils.addLogEntry(`Error restoring backup: ${error.message}`, 'error');
        KSU_API.toast('Error restoring backup', 'error');
    }
    
    Utils.hideLoading();
}

class SystemMonitor {
    static async systemScan() {
        Utils.showLoading();
        Utils.addLogEntry('Starting comprehensive system scan...', 'info');
        
        try {
            const result = await KSU_API.exec(`sh ${MODULE_CONFIG.SCRIPTS_PATH}/intelligent-monitor.sh system_scan`);
            
            if (result.code === 0) {
                Utils.addLogEntry('System scan completed', 'success');
                Utils.addLogEntry(result.out, 'info');
                KSU_API.toast('System scan completed', 'success');
                await StatusManager.updateSystemHealth();
            } else {
                Utils.addLogEntry(`System scan failed: ${result.err}`, 'error');
                KSU_API.toast('System scan failed', 'error');
            }
        } catch (error) {
            Utils.addLogEntry(`Error during system scan: ${error.message}`, 'error');
            KSU_API.toast('Error during system scan', 'error');
        }
        
        Utils.hideLoading();
    }

    static async optimizeSystem() {
        Utils.showLoading();
        Utils.addLogEntry('Starting system optimization...', 'info');
        
        try {
            const result = await KSU_API.exec(`sh ${MODULE_CONFIG.SCRIPTS_PATH}/intelligent-monitor.sh optimize_system`);
            
            if (result.code === 0) {
                Utils.addLogEntry('System optimization completed', 'success');
                KSU_API.toast('System optimized successfully!', 'success');
                await StatusManager.updateSystemHealth();
            } else {
                Utils.addLogEntry(`Optimization failed: ${result.err}`, 'error');
                KSU_API.toast('Optimization failed', 'error');
            }
        } catch (error) {
            Utils.addLogEntry(`Error during optimization: ${error.message}`, 'error');
            KSU_API.toast('Error during optimization', 'error');
        }
        
        Utils.hideLoading();
    }

    static async getSystemLogs() {
        Utils.showLoading();
        Utils.addLogEntry('Fetching system logs...', 'info');
        
        try {
            const result = await KSU_API.exec(`sh ${MODULE_CONFIG.SCRIPTS_PATH}/intelligent-monitor.sh get_logs`);
            
            if (result.code === 0) {
                const logs = result.out.split('\n').filter(line => line.trim());
                logs.forEach(log => {
                    if (log.includes('ERROR')) {
                        Utils.addLogEntry(log, 'error');
                    } else if (log.includes('WARNING')) {
                        Utils.addLogEntry(log, 'warning');
                    } else if (log.includes('SUCCESS')) {
                        Utils.addLogEntry(log, 'success');
                    } else {
                        Utils.addLogEntry(log, 'info');
                    }
                });
            } else {
                Utils.addLogEntry('Failed to fetch system logs', 'error');
            }
        } catch (error) {
            Utils.addLogEntry(`Error fetching logs: ${error.message}`, 'error');
        }
        
        Utils.hideLoading();
    }
}

class EmergencyManager {
    static async activateEmergencyMode() {
        if (!confirm('Are you sure you want to activate emergency mode? This will enable safe mode and create an emergency backup.')) {
            return;
        }
        
        Utils.showLoading();
        Utils.addLogEntry('Activating emergency mode...', 'warning');
        
        try {
            // Create emergency backup first
            const backupResult = await KSU_API.exec(`sh ${MODULE_CONFIG.SCRIPTS_PATH}/backup-engine.sh create_emergency_backup`);
            
            if (backupResult.code === 0) {
                Utils.addLogEntry('Emergency backup created', 'success');
            }
            
            // Activate safe mode
            const safeResult = await KSU_API.exec(`sh ${MODULE_CONFIG.SCRIPTS_PATH}/safe-mode.sh activate_emergency`);
            
            if (safeResult.code === 0) {
                Utils.addLogEntry('Emergency mode activated', 'warning');
                KSU_API.toast('Emergency mode activated. System is now in safe state.', 'warning');
                await StatusManager.updateProtectionStatus();
            } else {
                Utils.addLogEntry(`Failed to activate emergency mode: ${safeResult.err}`, 'error');
                KSU_API.toast('Failed to activate emergency mode', 'error');
            }
        } catch (error) {
            Utils.addLogEntry(`Error activating emergency mode: ${error.message}`, 'error');
            KSU_API.toast('Error activating emergency mode', 'error');
        }
        
        Utils.hideLoading();
    }

    static async deactivateEmergencyMode() {
        if (!confirm('Are you sure you want to deactivate emergency mode?')) {
            return;
        }
        
        Utils.showLoading();
        Utils.addLogEntry('Deactivating emergency mode...', 'info');
        
        try {
            const result = await KSU_API.exec(`sh ${MODULE_CONFIG.SCRIPTS_PATH}/safe-mode.sh deactivate_emergency`);
            
            if (result.code === 0) {
                Utils.addLogEntry('Emergency mode deactivated', 'success');
                KSU_API.toast('Emergency mode deactivated. Normal operation resumed.', 'success');
                await StatusManager.updateProtectionStatus();
            } else {
                Utils.addLogEntry(`Failed to deactivate emergency mode: ${result.err}`, 'error');
                KSU_API.toast('Failed to deactivate emergency mode', 'error');
            }
        } catch (error) {
            Utils.addLogEntry(`Error deactivating emergency mode: ${error.message}`, 'error');
            KSU_API.toast('Error deactivating emergency mode', 'error');
        }
        
        Utils.hideLoading();
    }
}

class StatusManager {
    static async updateBackupStatus() {
        try {
            const result = await KSU_API.exec(`sh ${MODULE_CONFIG.SCRIPTS_PATH}/backup-engine.sh get_last_backup`);
            
            if (result.code === 0 && result.out.trim()) {
                MainAppState.lastBackup = result.out.trim();
                const statusEl = document.getElementById('backup-status');
                const infoEl = document.getElementById('backup-info');
                
                if (statusEl) statusEl.textContent = 'Available';
                if (infoEl) infoEl.textContent = `Last backup: ${MainAppState.lastBackup}`;
            }
        } catch (error) {
            console.error('Error updating backup status:', error);
        }
    }

    static async updateSystemHealth() {
        try {
            const result = await KSU_API.exec(`sh ${MODULE_CONFIG.SCRIPTS_PATH}/intelligent-monitor.sh get_health_score`);
            
            if (result.code === 0 && result.out.trim()) {
                const score = parseInt(result.out.trim());
                MainAppState.systemHealth = score;
                
                const statusEl = document.getElementById('health-status');
                const infoEl = document.getElementById('health-info');
                const dotEl = statusEl?.parentElement?.querySelector('.status-dot');
                
                let status, statusClass;
                if (score > 80) {
                    status = 'Excellent';
                    statusClass = 'success';
                } else if (score > 60) {
                    status = 'Good';
                    statusClass = 'warning';
                } else {
                    status = 'Needs Attention';
                    statusClass = 'error';
                }
                
                if (statusEl) {
                    statusEl.textContent = status;
                    statusEl.className = `status-text ${statusClass}`;
                }
                if (infoEl) infoEl.textContent = `Health score: ${score}/100`;
                if (dotEl) {
                    dotEl.className = `status-dot ${statusClass}`;
                }
            }
        } catch (error) {
            console.error('Error updating health status:', error);
        }
    }

    static async updateStorageStatus() {
        try {
            const result = await KSU_API.exec(`df -h /data | tail -1 | awk '{print $4}'`);
            
            if (result.code === 0 && result.out.trim()) {
                MainAppState.storageInfo = result.out.trim();
                const statusEl = document.getElementById('storage-status');
                const infoEl = document.getElementById('storage-info');
                
                if (statusEl) statusEl.textContent = 'Available';
                if (infoEl) infoEl.textContent = `Free space: ${MainAppState.storageInfo}`;
            }
        } catch (error) {
            console.error('Error updating storage status:', error);
        }
    }

    static async updateProtectionStatus() {
        try {
            const result = await KSU_API.exec(`sh ${MODULE_CONFIG.SCRIPTS_PATH}/intelligent-monitor.sh get_protection_status`);
            
            if (result.code === 0 && result.out.trim()) {
                MainAppState.protectionStatus = result.out.trim().toLowerCase();
                const statusEl = document.getElementById('protection-status');
                const dotEl = statusEl?.parentElement?.querySelector('.status-dot');
                
                let status, statusClass;
                switch (MainAppState.protectionStatus) {
                    case 'active':
                        status = 'Active & Monitoring';
                        statusClass = 'success';
                        break;
                    case 'emergency':
                        status = 'Emergency Mode';
                        statusClass = 'warning';
                        break;
                    case 'disabled':
                        status = 'Disabled';
                        statusClass = 'error';
                        break;
                    default:
                        status = 'Unknown';
                        statusClass = 'warning';
                }
                
                if (statusEl) {
                    statusEl.textContent = status;
                    statusEl.className = `status-text ${statusClass}`;
                }
                if (dotEl) {
                    dotEl.className = `status-dot ${statusClass}`;
                }
            }
        } catch (error) {
            console.error('Error updating protection status:', error);
        }
    }

    static async updateAllStatus() {
        await Promise.all([
            this.updateBackupStatus(),
            this.updateSystemHealth(),
            this.updateStorageStatus(),
            this.updateProtectionStatus()
        ]);
    }
}

// Event Handlers
function createBackup() {
    BackupManager.createBackup();
}

function listBackups() {
    BackupManager.listBackups();
}

function systemScan() {
    SystemMonitor.systemScan();
}

function viewLogs() {
    SystemMonitor.getSystemLogs();
}

function optimizeSystem() {
    SystemMonitor.optimizeSystem();
}

function emergencyMode() {
    if (MainAppState.protectionStatus === 'emergency') {
        EmergencyManager.deactivateEmergencyMode();
    } else {
        EmergencyManager.activateEmergencyMode();
    }
}

function refreshLogs() {
    const logsViewer = document.getElementById('logs-viewer');
    if (logsViewer) {
        logsViewer.innerHTML = '';
    }
    MainAppState.logs = [];
    Utils.addLogEntry('Logs refreshed', 'info');
    SystemMonitor.getSystemLogs();
}

// Auto-refresh functionality
const AUTO_REFRESH_INTERVAL = 30000; // 30 seconds
let autoRefreshTimer;

function startAutoRefresh() {
    autoRefreshTimer = setInterval(() => {
        if (!MainAppState.isLoading) {
            StatusManager.updateAllStatus();
        }
    }, AUTO_REFRESH_INTERVAL);
}

function stopAutoRefresh() {
    if (autoRefreshTimer) {
        clearInterval(autoRefreshTimer);
        autoRefreshTimer = null;
    }
}

// Initialize the application
async function initializeApp() {
    Utils.addLogEntry('Initializing KernelSU Anti-Bootloop WebUI...', 'info');
    
    // Initialize settings
    loadSettings();
    
    // Apply initial theme
    applyTheme(MainAppState.settings.theme);
    
    // Check KernelSU availability
    if (MainAppState.isKernelSUAvailable) {
        Utils.addLogEntry('KernelSU APIs detected', 'success');
        
        // Get module information
        const moduleInfo = KSU_API.moduleInfo();
        Utils.addLogEntry(`Module: ${moduleInfo.name} v${moduleInfo.version}`, 'info');
    } else {
        Utils.addLogEntry('Running in demo mode (KernelSU APIs not available)', 'warning');
        KSU_API.toast('Demo Mode: KernelSU APIs not available', 'warning');
    }
    
    // Update all status information
    await StatusManager.updateAllStatus();
    
    // Load initial data for dashboard
    loadSystemMetrics();
    
    // Start auto-refresh
    startAutoRefresh();
    
    // Set up event listeners for settings
    setupSettingsEventListeners();
    
    // Initialize default tab
    switchTab('dashboard');
    
    Utils.addLogEntry('WebUI initialization complete', 'success');
    
    // Add fade-in animation to main container
    const container = document.querySelector('.container');
    if (container) {
        container.classList.add('fade-in');
    }
}

// Settings Event Listeners
function setupSettingsEventListeners() {
    // Auto backup toggle
    const autoBackupToggle = document.getElementById('auto-backup');
    if (autoBackupToggle) {
        autoBackupToggle.addEventListener('change', (e) => {
            updateSetting('autoBackup', e.target.checked);
        });
    }
    
    // Backup interval
    const backupInterval = document.getElementById('backup-interval');
    if (backupInterval) {
        backupInterval.addEventListener('change', (e) => {
            updateSetting('backupInterval', parseInt(e.target.value));
        });
    }
    
    // Max backups
    const maxBackups = document.getElementById('max-backups');
    if (maxBackups) {
        maxBackups.addEventListener('change', (e) => {
            updateSetting('maxBackups', parseInt(e.target.value));
        });
    }
    
    // Monitoring enabled
    const monitoringEnabled = document.getElementById('monitoring-enabled');
    if (monitoringEnabled) {
        monitoringEnabled.addEventListener('change', (e) => {
            updateSetting('monitoringEnabled', e.target.checked);
        });
    }
    
    // Alert threshold
    const alertThreshold = document.getElementById('alert-threshold');
    if (alertThreshold) {
        alertThreshold.addEventListener('change', (e) => {
            updateSetting('alertThreshold', parseInt(e.target.value));
        });
    }
    
    // Theme select
    const themeSelect = document.getElementById('theme-select');
    if (themeSelect) {
        themeSelect.addEventListener('change', (e) => {
            updateSetting('theme', e.target.value);
        });
    }
    
    // Animations enabled
    const animationsEnabled = document.getElementById('animations-enabled');
    if (animationsEnabled) {
        animationsEnabled.addEventListener('change', (e) => {
            updateSetting('animationsEnabled', e.target.checked);
        });
    }
}

// Event Listeners
document.addEventListener('DOMContentLoaded', initializeApp);

// Enhanced utility functions for mobile optimization
function handleTouchStart(e) {
    // Add touch feedback
    e.target.classList.add('touch-active');
}

function handleTouchEnd(e) {
    // Remove touch feedback after delay
    setTimeout(() => {
        e.target.classList.remove('touch-active');
    }, 150);
}

// Swipe gesture support for tab navigation
let touchStartX = 0;
let touchEndX = 0;

function handleSwipeGesture() {
    const swipeThreshold = 50;
    const swipeDistance = touchEndX - touchStartX;
    
    if (Math.abs(swipeDistance) > swipeThreshold) {
        const tabs = ['dashboard', 'backup', 'monitor', 'settings'];
        const currentIndex = tabs.indexOf(MainAppState.currentTab);
        
        if (swipeDistance > 0 && currentIndex > 0) {
            // Swipe right - go to previous tab
            switchTab(tabs[currentIndex - 1]);
        } else if (swipeDistance < 0 && currentIndex < tabs.length - 1) {
            // Swipe left - go to next tab
            switchTab(tabs[currentIndex + 1]);
        }
    }
}

// Vibration feedback for mobile devices
function vibrateFeedback(pattern = [50]) {
    if ('vibrate' in navigator) {
        navigator.vibrate(pattern);
    }
}

// Handle page visibility changes
document.addEventListener('visibilitychange', () => {
    if (document.hidden) {
        stopAutoRefresh();
    } else {
        startAutoRefresh();
    }
});

// Handle beforeunload
window.addEventListener('beforeunload', () => {
    stopAutoRefresh();
});

// Add touch event listeners
document.addEventListener('DOMContentLoaded', function() {
    const buttons = document.querySelectorAll('button, .nav-tab');
    buttons.forEach(button => {
        button.addEventListener('touchstart', handleTouchStart, { passive: true });
        button.addEventListener('touchend', handleTouchEnd, { passive: true });
    });
});

// Touch gesture listeners
document.addEventListener('touchstart', (e) => {
    touchStartX = e.changedTouches[0].screenX;
}, { passive: true });

document.addEventListener('touchend', (e) => {
    touchEndX = e.changedTouches[0].screenX;
    handleSwipeGesture();
}, { passive: true });

// Export for global access
window.KernelSUApp = {
    BackupManager,
    SystemMonitor,
    EmergencyManager,
    StatusManager,
    Utils,
    MainAppState,
    KSU_API
};