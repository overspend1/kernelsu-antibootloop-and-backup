/**
 * KernelSU Anti-Bootloop Backup - Main Application Script
 * 
 * This file contains the main entry point for the WebUI application,
 * handling WebUIX API integration, navigation, offline detection, and
 * core application functionality.
 */

// Application configuration
const APP_CONFIG = {
    version: '1.0.0',
    apiTimeoutMs: 5000,
    offlineCheckIntervalMs: 10000,
    themeStorageKey: 'ksu_app_theme',
    defaultSettings: {
        webUIPort: 8080,
        authRequired: true,
        debugLogging: false,
        backupEncryption: false,
        backupCompression: true,
        autoBackup: false,
        backupSchedule: 'weekly',
        overlayFS: true,
        selinuxMode: 'enforcing',
        storagePath: '/data/adb/modules/kernelsu_antibootloop_backup/config/backups',
        notificationsEnabled: true,
        backupNotifications: true,
        safetyNotifications: true,
        systemNotifications: true
    }
};

// Global state
const AppState = {
    isOnline: true,
    isWebUIXConnected: false,
    currentPage: 'dashboard',
    settings: { ...APP_CONFIG.defaultSettings },
    systemInfo: {
        deviceModel: 'Unknown',
        androidVersion: 'Unknown',
        kernelSUVersion: 'Unknown',
        moduleVersion: APP_CONFIG.version,
        kernelVersion: 'Unknown'
    },
    backups: [],
    recoveryPoints: [],
    notifications: [],
    bootHistory: [],
    activityLog: []
};

/**
 * Initialize the application when the document is fully loaded
 */
document.addEventListener('DOMContentLoaded', () => {
    // Initialize UI components
    UI.initTheme();
    UI.initRipple();
    UI.initNavigation();
    UI.initBottomNav();
    UI.initModals();
    UI.initFab();
    UI.initSwitches();
    UI.initSliders();
    
    // Initialize Dashboard
    Dashboard.init();
    
    // Initialize WebUIX API connection
    initWebUIX();
    
    // Setup offline detection
    setupOfflineDetection();
    
    // Setup event listeners for application features
    setupEventListeners();
    
    // Load settings
    loadSettings();
    
    // Load initial data
    refreshData();
    
    // Show toast to indicate app is ready
    UI.showToast('Application initialized');
    
    console.log('KernelSU Anti-Bootloop Backup WebUI initialized');
});

/**
 * Initialize WebUIX API integration
 */
function initWebUIX() {
    if (typeof ksu !== 'undefined') {
        console.log('WebUIX API detected, initializing integration');
        AppState.isWebUIXConnected = true;
        
        // Update connection status indicator
        document.getElementById('connection-status').title = 'WebUIX connected';
        document.getElementById('connection-status').querySelector('i').textContent = 'cloud_done';
        
        // Get module information
        try {
            const moduleInfo = ksu.moduleInfo();
            AppState.systemInfo.moduleVersion = moduleInfo.version || APP_CONFIG.version;
            console.log('Module info:', moduleInfo);
        } catch (error) {
            console.error('Failed to get module info:', error);
        }
        
        // Fetch system info
        fetchSystemInfo();
    } else {
        console.warn('WebUIX API not detected, running in standalone mode');
        AppState.isWebUIXConnected = false;
        
        // Update connection status indicator
        document.getElementById('connection-status').title = 'WebUIX not connected';
        document.getElementById('connection-status').querySelector('i').textContent = 'cloud_off';
        
        // Show offline mode notice
        toggleOfflineMode(true);
        
        // Load mock data in development mode
        if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
            loadMockData();
        }
    }
}

/**
 * Setup periodic offline detection
 */
function setupOfflineDetection() {
    // Check connectivity immediately
    checkConnectivity();
    
    // Setup periodic checks
    setInterval(checkConnectivity, APP_CONFIG.offlineCheckIntervalMs);
    
    // Setup network change listener
    window.addEventListener('online', () => {
        checkConnectivity();
        UI.showToast('Connection restored');
    });
    
    window.addEventListener('offline', () => {
        toggleOfflineMode(true);
        UI.showToast('Connection lost, running in offline mode');
    });
}

/**
 * Check connectivity to WebUIX
 */
async function checkConnectivity() {
    if (!navigator.onLine) {
        toggleOfflineMode(true);
        return;
    }
    
    if (typeof ksu === 'undefined') {
        toggleOfflineMode(true);
        return;
    }
    
    try {
        // Try to ping the WebUIX API
        const result = await executeCommand('echo "ping"', APP_CONFIG.apiTimeoutMs);
        if (result && result.includes('ping')) {
            toggleOfflineMode(false);
        } else {
            toggleOfflineMode(true);
        }
    } catch (error) {
        console.error('Connectivity check failed:', error);
        toggleOfflineMode(true);
    }
}

/**
 * Toggle offline mode UI
 * @param {boolean} isOffline - Whether offline mode should be enabled
 */
function toggleOfflineMode(isOffline) {
    const wasOffline = AppState.isOnline === false;
    AppState.isOnline = !isOffline;
    
    const offlineBanner = document.getElementById('offline-banner');
    
    if (isOffline) {
        offlineBanner.classList.remove('hidden');
        document.body.classList.add('offline-mode');
        document.getElementById('connection-status').querySelector('i').textContent = 'cloud_off';
        
        // Only show toast if transitioning to offline
        if (!wasOffline) {
            UI.showToast('Running in offline mode');
        }
    } else {
        offlineBanner.classList.add('hidden');
        document.body.classList.remove('offline-mode');
        document.getElementById('connection-status').querySelector('i').textContent = 'cloud_done';
        
        // Only show toast if transitioning to online
        if (wasOffline) {
            UI.showToast('Connection restored');
            
            // Refresh data
            refreshData();
        }
    }
}

/**
 * Setup event listeners for application features
 */
function setupEventListeners() {
    // Theme toggle
    document.getElementById('theme-toggle').addEventListener('click', UI.cycleTheme);
    
    // Offline banner details
    document.getElementById('offline-details').addEventListener('click', showOfflineDetails);
    
    // Dashboard refresh
    document.getElementById('refresh-dashboard').addEventListener('click', refreshData);
    
    // Quick backup button
    document.getElementById('quick-backup').addEventListener('click', performQuickBackup);
    
    // View all activity
    document.getElementById('view-all-activity').addEventListener('click', showActivityLog);
    
    // Create backup button
    document.getElementById('create-backup').addEventListener('click', showBackupDialog);
    
    // Import backup button
    document.getElementById('import-backup').addEventListener('click', showImportDialog);
    
    // Backup filter chips
    document.querySelectorAll('.backup-filter-chip').forEach(chip => {
        chip.addEventListener('click', () => {
            chip.classList.toggle('active');
            filterBackups();
        });
    });
    
    // Backup sort options
    document.querySelectorAll('.backup-sort-option').forEach(option => {
        option.addEventListener('click', (e) => {
            document.querySelectorAll('.backup-sort-option').forEach(opt => {
                opt.classList.remove('active');
            });
            e.target.classList.add('active');
            sortBackups(e.target.dataset.sort);
        });
    });
    
    // Backup search
    document.getElementById('search-backups').addEventListener('input', filterBackups);
    
    // Create profile button
    document.getElementById('create-profile').addEventListener('click', showCreateProfileDialog);
    
    // Test protection button
    document.getElementById('test-protection').addEventListener('click', testProtection);
    
    // Create recovery point button
    document.getElementById('create-recovery-point').addEventListener('click', createRecoveryPoint);
    
    // Settings buttons
    document.getElementById('save-settings').addEventListener('click', saveSettings);
    document.getElementById('reset-settings').addEventListener('click', resetSettings);
    
    // Footer links
    document.getElementById('view-logs').addEventListener('click', showLogs);
    document.getElementById('about').addEventListener('click', showAboutDialog);
    
    // Notification button
    document.getElementById('notification-button').addEventListener('click', Dashboard.toggleNotificationPanel);
}

/**
 * Load application settings
 */
function loadSettings() {
    try {
        if (AppState.isWebUIXConnected) {
            // Fetch settings from WebUIX
            executeCommand('cat /data/adb/modules/kernelsu_antibootloop_backup/config/settings.json')
                .then(settingsJson => {
                    if (settingsJson) {
                        try {
                            const settings = JSON.parse(settingsJson);
                            AppState.settings = { ...APP_CONFIG.defaultSettings, ...settings };
                            updateSettingsUI();
                        } catch (error) {
                            console.error('Failed to parse settings JSON:', error);
                            AppState.settings = { ...APP_CONFIG.defaultSettings };
                            updateSettingsUI();
                        }
                    } else {
                        // No settings file found, use defaults
                        AppState.settings = { ...APP_CONFIG.defaultSettings };
                        updateSettingsUI();
                    }
                })
                .catch(error => {
                    console.error('Failed to load settings:', error);
                    AppState.settings = { ...APP_CONFIG.defaultSettings };
                    updateSettingsUI();
                });
        } else {
            // Load from localStorage in standalone mode
            const savedSettings = localStorage.getItem('ksu_app_settings');
            if (savedSettings) {
                try {
                    AppState.settings = { ...APP_CONFIG.defaultSettings, ...JSON.parse(savedSettings) };
                } catch (error) {
                    console.error('Failed to parse saved settings:', error);
                    AppState.settings = { ...APP_CONFIG.defaultSettings };
                }
            } else {
                AppState.settings = { ...APP_CONFIG.defaultSettings };
            }
            updateSettingsUI();
        }
    } catch (error) {
        console.error('Error loading settings:', error);
        AppState.settings = { ...APP_CONFIG.defaultSettings };
        updateSettingsUI();
    }
}

/**
 * Update the settings UI to reflect current settings
 */
function updateSettingsUI() {
    const { settings } = AppState;
    
    // General settings
    document.getElementById('webui-enabled').checked = true; // Always true if WebUI is running
    document.getElementById('webui-port').value = settings.webUIPort;
    document.getElementById('auth-required').checked = settings.authRequired;
    document.getElementById('debug-logging').checked = settings.debugLogging;
    
    // Backup settings
    document.getElementById('backup-encryption').checked = settings.backupEncryption;
    document.getElementById('backup-compression').checked = settings.backupCompression;
    document.getElementById('auto-backup').checked = settings.autoBackup;
    document.getElementById('backup-schedule').value = settings.backupSchedule;
    
    // Advanced settings
    document.getElementById('use-overlayfs').checked = settings.overlayFS;
    document.getElementById('selinux-mode').value = settings.selinuxMode;
    document.getElementById('storage-path').value = settings.storagePath;
    
    // Notification settings
    document.getElementById('notifications-enabled').checked = settings.notificationsEnabled;
    document.getElementById('backup-notifications').checked = settings.backupNotifications;
    document.getElementById('safety-notifications').checked = settings.safetyNotifications;
    document.getElementById('system-notifications').checked = settings.systemNotifications;
}

/**
 * Save application settings
 */
function saveSettings() {
    // Collect settings from UI
    const settings = {
        webUIPort: parseInt(document.getElementById('webui-port').value, 10),
        authRequired: document.getElementById('auth-required').checked,
        debugLogging: document.getElementById('debug-logging').checked,
        backupEncryption: document.getElementById('backup-encryption').checked,
        backupCompression: document.getElementById('backup-compression').checked,
        autoBackup: document.getElementById('auto-backup').checked,
        backupSchedule: document.getElementById('backup-schedule').value,
        overlayFS: document.getElementById('use-overlayfs').checked,
        selinuxMode: document.getElementById('selinux-mode').value,
        storagePath: document.getElementById('storage-path').value,
        notificationsEnabled: document.getElementById('notifications-enabled').checked,
        backupNotifications: document.getElementById('backup-notifications').checked,
        safetyNotifications: document.getElementById('safety-notifications').checked,
        systemNotifications: document.getElementById('system-notifications').checked
    };
    
    // Update application state
    AppState.settings = settings;
    
    // Save settings
    if (AppState.isWebUIXConnected) {
        // Save to WebUIX
        const settingsJson = JSON.stringify(settings, null, 2);
        executeCommand(`echo '${settingsJson}' > /data/adb/modules/kernelsu_antibootloop_backup/config/settings.json`)
            .then(() => {
                UI.showToast('Settings saved successfully');
            })
            .catch(error => {
                console.error('Failed to save settings:', error);
                UI.showToast('Failed to save settings', 'error');
            });
    } else {
        // Save to localStorage in standalone mode
        localStorage.setItem('ksu_app_settings', JSON.stringify(settings));
        UI.showToast('Settings saved successfully');
    }
}

/**
 * Reset settings to defaults
 */
function resetSettings() {
    UI.showConfirmDialog(
        'Reset Settings',
        'Are you sure you want to reset all settings to default values?',
        'Reset',
        'Cancel',
        () => {
            AppState.settings = { ...APP_CONFIG.defaultSettings };
            updateSettingsUI();
            
            if (AppState.isWebUIXConnected) {
                // Save to WebUIX
                const settingsJson = JSON.stringify(AppState.settings, null, 2);
                executeCommand(`echo '${settingsJson}' > /data/adb/modules/kernelsu_antibootloop_backup/config/settings.json`)
                    .then(() => {
                        UI.showToast('Settings reset to defaults');
                    })
                    .catch(error => {
                        console.error('Failed to save reset settings:', error);
                        UI.showToast('Failed to reset settings', 'error');
                    });
            } else {
                // Save to localStorage in standalone mode
                localStorage.setItem('ksu_app_settings', JSON.stringify(AppState.settings));
                UI.showToast('Settings reset to defaults');
            }
        }
    );
}

/**
 * Refresh application data
 */
function refreshData() {
    UI.showLoader('Refreshing data...');
    
    // Use Promise.all to run all data fetches in parallel
    Promise.all([
        fetchSystemInfo(),
        fetchBackupList(),
        fetchRecoveryPoints(),
        fetchBootHistory(),
        fetchDiskSpace(),
        fetchActivityLog()
    ])
    .then(() => {
        // Update dashboard
        Dashboard.updateSystemStatus();
        Dashboard.updateBackupStatus();
        Dashboard.updateDiskSpace();
        Dashboard.updateSystemMetrics();
        Dashboard.updateBootHistory();
        Dashboard.updateBackupSizes();
        Dashboard.updateSystemOverview();
        Dashboard.updateActivityLog();
        Dashboard.refreshNotifications();
        
        // Update other UI components
        updateBackupList();
        updateRecoveryPointList();
        
        UI.hideLoader();
        UI.showToast('Data refreshed successfully');
    })
    .catch(error => {
        console.error('Error refreshing data:', error);
        UI.hideLoader();
        UI.showToast('Failed to refresh some data', 'error');
    });
}

/**
 * Fetch system information
 */
async function fetchSystemInfo() {
    if (!AppState.isWebUIXConnected) {
        // In standalone mode, use mock data
        if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
            loadMockSystemInfo();
        }
        return;
    }
    
    try {
        // Get device model
        const deviceModel = await executeCommand('getprop ro.product.model');
        AppState.systemInfo.deviceModel = deviceModel.trim() || 'Unknown';
        
        // Get Android version
        const androidVersion = await executeCommand('getprop ro.build.version.release');
        AppState.systemInfo.androidVersion = androidVersion.trim() || 'Unknown';
        
        // Get KernelSU version
        const kernelSUVersion = await executeCommand('su -v');
        AppState.systemInfo.kernelSUVersion = kernelSUVersion.trim() || 'Unknown';
        
        // Get kernel version
        const kernelVersion = await executeCommand('uname -r');
        AppState.systemInfo.kernelVersion = kernelVersion.trim() || 'Unknown';
        
        // Update last boot time
        const uptime = await executeCommand('cat /proc/uptime');
        const uptimeSeconds = parseFloat(uptime.split(' ')[0]);
        const bootTime = Date.now() - (uptimeSeconds * 1000);
        document.getElementById('last-boot').textContent = new Date(bootTime).toLocaleString();
        document.getElementById('system-uptime').textContent = formatUptime(uptimeSeconds);
        
        // Update boot count
        const bootCount = await executeCommand('cat /data/adb/modules/kernelsu_antibootloop_backup/config/boot_count.txt');
        document.getElementById('boot-count').textContent = bootCount.trim() || '0';
        
        // Update protection status
        const protectionStatus = await executeCommand('cat /data/adb/modules/kernelsu_antibootloop_backup/config/protection_status.txt');
        document.getElementById('protection-status').textContent = protectionStatus.trim() || 'Unknown';
        
        return true;
    } catch (error) {
        console.error('Error fetching system info:', error);
        return false;
    }
}

/**
 * Fetch list of backups
 */
async function fetchBackupList() {
    if (!AppState.isWebUIXConnected) {
        // In standalone mode, use mock data
        if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
            loadMockBackups();
        }
        return;
    }
    
    try {
        const backupPath = AppState.settings.storagePath;
        const result = await executeCommand(`ls -la ${backupPath}`);
        
        if (!result) {
            AppState.backups = [];
            return;
        }
        
        const lines = result.split('\n').filter(line => line.endsWith('.tar.gz') || line.endsWith('.tar.xz'));
        const backups = [];
        
        for (const line of lines) {
            const parts = line.trim().split(/\s+/);
            if (parts.length >= 7) {
                const name = parts[parts.length - 1];
                const size = parts[4];
                const date = new Date(`${parts[5]} ${parts[6]} ${new Date().getFullYear()}`);
                
                // Get backup type from name (full, system, apps, data, custom)
                let type = 'custom';
                if (name.includes('_full_')) {
                    type = 'full';
                } else if (name.includes('_system_')) {
                    type = 'system';
                } else if (name.includes('_apps_')) {
                    type = 'apps';
                } else if (name.includes('_data_')) {
                    type = 'data';
                }
                
                backups.push({
                    name,
                    path: `${backupPath}/${name}`,
                    size,
                    date,
                    type
                });
            }
        }
        
        AppState.backups = backups;
        
        // Update backup count
        document.getElementById('backup-count').textContent = backups.length.toString();
        
        // Update last backup time
        if (backups.length > 0) {
            // Sort by date, newest first
            backups.sort((a, b) => b.date - a.date);
            document.getElementById('last-backup').textContent = backups[0].date.toLocaleString();
        }
        
        // Update storage usage
        let totalSize = 0;
        for (const backup of backups) {
            totalSize += parseInt(backup.size, 10);
        }
        document.getElementById('storage-usage').textContent = formatSize(totalSize);
        
        return true;
    } catch (error) {
        console.error('Error fetching backup list:', error);
        return false;
    }
}

/**
 * Fetch recovery points
 */
async function fetchRecoveryPoints() {
    if (!AppState.isWebUIXConnected) {
        // In standalone mode, use mock data
        if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
            loadMockRecoveryPoints();
        }
        return;
    }
    
    try {
        const recoveryPath = '/data/adb/modules/kernelsu_antibootloop_backup/config/recovery_points';
        const result = await executeCommand(`ls -la ${recoveryPath}`);
        
        if (!result) {
            AppState.recoveryPoints = [];
            return;
        }
        
        const lines = result.split('\n').filter(line => line.endsWith('.point'));
        const recoveryPoints = [];
        
        for (const line of lines) {
            const parts = line.trim().split(/\s+/);
            if (parts.length >= 7) {
                const name = parts[parts.length - 1];
                const date = new Date(`${parts[5]} ${parts[6]} ${new Date().getFullYear()}`);
                
                // Get description
                const descriptionResult = await executeCommand(`cat ${recoveryPath}/${name}`);
                let description = 'Recovery point';
                if (descriptionResult) {
                    const lines = descriptionResult.split('\n');
                    if (lines.length > 0) {
                        description = lines[0].trim();
                    }
                }
                
                recoveryPoints.push({
                    name,
                    path: `${recoveryPath}/${name}`,
                    date,
                    description
                });
            }
        }
        
        AppState.recoveryPoints = recoveryPoints;
        return true;
    } catch (error) {
        console.error('Error fetching recovery points:', error);
        return false;
    }
}

/**
 * Fetch boot history
 */
async function fetchBootHistory() {
    if (!AppState.isWebUIXConnected) {
        // In standalone mode, use mock data
        if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
            loadMockBootHistory();
        }
        return;
    }
    
    try {
        const bootHistoryPath = '/data/adb/modules/kernelsu_antibootloop_backup/config/boot_history.log';
        const result = await executeCommand(`cat ${bootHistoryPath}`);
        
        if (!result) {
            AppState.bootHistory = [];
            return;
        }
        
        const lines = result.split('\n').filter(line => line.trim() !== '');
        const bootHistory = [];
        
        for (const line of lines) {
            const parts = line.split(',');
            if (parts.length >= 3) {
                const timestamp = parseInt(parts[0], 10);
                const status = parts[1].trim();
                const duration = parseInt(parts[2], 10);
                
                bootHistory.push({
                    timestamp,
                    date: new Date(timestamp),
                    status,
                    duration
                });
            }
        }
        
        AppState.bootHistory = bootHistory;
        return true;
    } catch (error) {
        console.error('Error fetching boot history:', error);
        return false;
    }
}

/**
 * Fetch disk space information
 */
async function fetchDiskSpace() {
    if (!AppState.isWebUIXConnected) {
        // In standalone mode, use mock data
        if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
            loadMockDiskSpace();
        }
        return;
    }
    
    try {
        const result = await executeCommand('df -h /data');
        
        if (!result) {
            return;
        }
        
        const lines = result.split('\n');
        if (lines.length >= 2) {
            const parts = lines[1].trim().split(/\s+/);
            if (parts.length >= 6) {
                const total = parts[1];
                const used = parts[2];
                const free = parts[3];
                const percentage = parseInt(parts[4].replace('%', ''), 10);
                
                document.getElementById('disk-total').textContent = total;
                document.getElementById('disk-used').textContent = used;
                document.getElementById('disk-free').textContent = free;
                
                // Update progress bar
                const progressBar = document.querySelector('.disk-usage .progress-bar');
                progressBar.style.width = `${percentage}%`;
                progressBar.setAttribute('data-value', percentage);
                
                // Set color based on usage
                if (percentage >= 90) {
                    progressBar.classList.add('danger');
                } else if (percentage >= 75) {
                    progressBar.classList.add('warning');
                } else {
                    progressBar.classList.add('success');
                }
            }
        }
        
        return true;
    } catch (error) {
        console.error('Error fetching disk space:', error);
        return false;
    }
}

/**
 * Fetch activity log
 */
async function fetchActivityLog() {
    if (!AppState.isWebUIXConnected) {
        // In standalone mode, use mock data
        if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
            loadMockActivityLog();
        }
        return;
    }
    
    try {
        const activityLogPath = '/data/adb/modules/kernelsu_antibootloop_backup/config/activity.log';
        const result = await executeCommand(`cat ${activityLogPath}`);
        
        if (!result) {
            AppState.activityLog = [];
            return;
        }
        
        const lines = result.split('\n').filter(line => line.trim() !== '');
        const activityLog = [];
        
        for (const line of lines) {
            const parts = line.split('|');
            if (parts.length >= 3) {
                const timestamp = parseInt(parts[0], 10);
                const type = parts[1].trim();
                const message = parts[2].trim();
                
                activityLog.push({
                    timestamp,
                    date: new Date(timestamp),
                    type,
                    message
                });
            }
        }
        
        // Sort by timestamp, newest first
        activityLog.sort((a, b) => b.timestamp - a.timestamp);
        
        AppState.activityLog = activityLog;
        return true;
    } catch (error) {
        console.error('Error fetching activity log:', error);
        return false;
    }
}

/**
 * Update the backup list UI
 */
function updateBackupList() {
    const backupList = document.querySelector('.backup-list');
    const placeholderText = backupList.querySelector('.placeholder-text');
    
    // Clear existing items
    const existingItems = backupList.querySelectorAll('.backup-item');
    existingItems.forEach(item => item.remove());
    
    if (AppState.backups.length === 0) {
        placeholderText.style.display = 'block';
        return;
    }
    
    placeholderText.style.display = 'none';
    
    // Create backup items
    for (const backup of AppState.backups) {
        const backupItem = document.createElement('div');
        backupItem.className = 'backup-item card md-card';
        backupItem.dataset.type = backup.type;
        backupItem.dataset.name = backup.name;
        
        const typeClass = `backup-type-${backup.type}`;
        
        backupItem.innerHTML = `
            <div class="backup-item-header">
                <div class="backup-type ${typeClass}">${backup.type}</div>
                <div class="backup-date">${backup.date.toLocaleString()}</div>
            </div>
            <div class="backup-item-content">
                <h3 class="backup-name">${backup.name.replace(/\.tar\.(gz|xz)$/, '')}</h3>
                <div class="backup-size">${backup.size}</div>
            </div>
            <div class="backup-item-actions">
                <button class="btn small primary restore-backup" data-backup="${backup.name}">
                    Restore
                    <span class="ripple-container"></span>
                </button>
                <button class="btn small secondary export-backup" data-backup="${backup.name}">
                    Export
                    <span class="ripple-container"></span>
                </button>
                <button class="btn small danger delete-backup" data-backup="${backup.name}">
                    Delete
                    <span class="ripple-container"></span>
                </button>
            </div>
        `;
        
        backupList.appendChild(backupItem);
        
        // Add event listeners for buttons
        backupItem.querySelector('.restore-backup').addEventListener('click', () => {
            showRestoreDialog(backup);
        });
        
        backupItem.querySelector('.export-backup').addEventListener('click', () => {
            exportBackup(backup);
        });
        
        backupItem.querySelector('.delete-backup').addEventListener('click', () => {
            showDeleteBackupDialog(backup);
        });
    }
    
    /**
     * Update the recovery point list UI
     */
    function updateRecoveryPointList() {
        const recoveryPointList = document.querySelector('.recovery-point-list');
        const placeholderText = recoveryPointList.querySelector('.placeholder-text');
        
        // Clear existing items
        const existingItems = recoveryPointList.querySelectorAll('.recovery-point-item');
        existingItems.forEach(item => item.remove());
        
        if (AppState.recoveryPoints.length === 0) {
            placeholderText.style.display = 'block';
            return;
        }
        
        placeholderText.style.display = 'none';
        
        // Create recovery point items
        for (const point of AppState.recoveryPoints) {
            const pointItem = document.createElement('div');
            pointItem.className = 'recovery-point-item';
            
            pointItem.innerHTML = `
                <div class="recovery-point-info">
                    <div class="recovery-point-date">${point.date.toLocaleString()}</div>
                    <div class="recovery-point-description">${point.description}</div>
                </div>
                <div class="recovery-point-actions">
                    <button class="btn small primary restore-point" data-point="${point.name}">
                        Restore
                        <span class="ripple-container"></span>
                    </button>
                    <button class="btn small danger delete-point" data-point="${point.name}">
                        Delete
                        <span class="ripple-container"></span>
                    </button>
                </div>
            `;
            
            recoveryPointList.appendChild(pointItem);
            
            // Add event listeners for buttons
            pointItem.querySelector('.restore-point').addEventListener('click', () => {
                showRestorePointDialog(point);
            });
            
            pointItem.querySelector('.delete-point').addEventListener('click', () => {
                showDeleteRecoveryPointDialog(point);
            });
        }
        
        /**
         * Filter backups based on search input and filter chips
         */
        function filterBackups() {
            const searchTerm = document.getElementById('search-backups').value.toLowerCase();
            const filterChips = document.querySelectorAll('.backup-filter-chip.active');
            const activeFilters = Array.from(filterChips).map(chip => chip.dataset.filter);
            
            const backupItems = document.querySelectorAll('.backup-item');
            
            backupItems.forEach(item => {
                const name = item.dataset.name.toLowerCase();
                const type = item.dataset.type;
                
                let matchesSearch = true;
                let matchesFilter = true;
                
                // Check search term
                if (searchTerm && !name.includes(searchTerm)) {
                    matchesSearch = false;
                }
                
                // Check filters
                if (activeFilters.length > 0 && !activeFilters.includes(type)) {
                    matchesFilter = false;
                }
                
                // Show/hide item
                if (matchesSearch && matchesFilter) {
                    item.style.display = 'block';
                } else {
                    item.style.display = 'none';
                }
            });
            
            // Show placeholder if no items visible
            const visibleItems = document.querySelectorAll('.backup-item[style="display: block;"]');
            const placeholderText = document.querySelector('.backup-list .placeholder-text');
            
            if (visibleItems.length === 0) {
                placeholderText.style.display = 'block';
                placeholderText.textContent = 'No backups match your filters';
            } else {
                placeholderText.style.display = 'none';
            }
        }
        
        /**
         * Sort backups based on selected option
         * @param {string} sortBy - The field to sort by (date, name, size)
         */
        function sortBackups(sortBy) {
            const backupList = document.querySelector('.backup-list');
            const backupItems = Array.from(document.querySelectorAll('.backup-item'));
            
            backupItems.sort((a, b) => {
                if (sortBy === 'date') {
                    const dateA = new Date(a.querySelector('.backup-date').textContent);
                    const dateB = new Date(b.querySelector('.backup-date').textContent);
                    return dateB - dateA; // Newest first
                } else if (sortBy === 'name') {
                    const nameA = a.querySelector('.backup-name').textContent;
                    const nameB = b.querySelector('.backup-name').textContent;
                    return nameA.localeCompare(nameB);
                } else if (sortBy === 'size') {
                    const sizeA = a.querySelector('.backup-size').textContent;
                    const sizeB = b.querySelector('.backup-size').textContent;
                    return parseSize(sizeB) - parseSize(sizeA); // Largest first
                }
                return 0;
            });
            
            // Re-append items in sorted order
            backupItems.forEach(item => {
                backupList.appendChild(item);
            });
        }
        
        // Initialize ripple effect for new buttons
        UI.initRipple();
    }
    
    // Initialize ripple effect for new buttons
    UI.initRipple();
}

/**
 * Show dialog for creating a new backup
 */
function showBackupDialog() {
    const modalContent = `
        <div class="backup-dialog">
            <p>Configure your backup settings:</p>
            
            <div class="form-group">
                <label for="backup-name">Backup Name:</label>
                <input type="text" id="backup-name" class="md-input" value="backup_${new Date().toISOString().replace(/[:.]/g, '-')}" placeholder="Enter backup name">
            </div>
            
            <div class="form-group">
                <label>Backup Type:</label>
                <div class="radio-group">
                    <div class="radio-option">
                        <input type="radio" id="backup-type-full" name="backup-type" value="full" checked>
                        <label for="backup-type-full">Full</label>
                    </div>
                    <div class="radio-option">
                        <input type="radio" id="backup-type-system" name="backup-type" value="system">
                        <label for="backup-type-system">System Only</label>
                    </div>
                    <div class="radio-option">
                        <input type="radio" id="backup-type-apps" name="backup-type" value="apps">
                        <label for="backup-type-apps">Apps & Data</label>
                    </div>
                    <div class="radio-option">
                        <input type="radio" id="backup-type-custom" name="backup-type" value="custom">
                        <label for="backup-type-custom">Custom</label>
                    </div>
                </div>
            </div>
            
            <div id="custom-backup-options" style="display: none;">
                <div class="form-group">
                    <label>Custom Backup Options:</label>
                    <div class="checkbox-group">
                        <div class="checkbox-option">
                            <input type="checkbox" id="backup-system" checked>
                            <label for="backup-system">System Partitions</label>
                        </div>
                        <div class="checkbox-option">
                            <input type="checkbox" id="backup-data" checked>
                            <label for="backup-data">User Data</label>
                        </div>
                        <div class="checkbox-option">
                            <input type="checkbox" id="backup-apps" checked>
                            <label for="backup-apps">Apps</label>
                        </div>
                        <div class="checkbox-option">
                            <input type="checkbox" id="backup-vendor">
                            <label for="backup-vendor">Vendor</label>
                        </div>
                        <div class="checkbox-option">
                            <input type="checkbox" id="backup-boot">
                            <label for="backup-boot">Boot & Recovery</label>
                        </div>
                    </div>
                </div>
            </div>
            
            <div class="form-group">
                <label for="backup-compression">Compression:</label>
                <div class="switch-container">
                    <input type="checkbox" id="backup-compression-toggle" ${AppState.settings.backupCompression ? 'checked' : ''}>
                    <label class="switch-label" for="backup-compression-toggle"></label>
                </div>
            </div>
            
            <div class="form-group">
                <label for="backup-encryption">Encryption:</label>
                <div class="switch-container">
                    <input type="checkbox" id="backup-encryption-toggle" ${AppState.settings.backupEncryption ? 'checked' : ''}>
                    <label class="switch-label" for="backup-encryption-toggle"></label>
                </div>
            </div>
            
            <div id="encryption-password" style="display: ${AppState.settings.backupEncryption ? 'block' : 'none'};">
                <div class="form-group">
                    <label for="backup-password">Password:</label>
                    <input type="password" id="backup-password" class="md-input" placeholder="Enter encryption password">
                </div>
            </div>
            
            <div class="form-group">
                <label for="create-recovery-point-toggle">Create Recovery Point:</label>
                <div class="switch-container">
                    <input type="checkbox" id="create-recovery-point-toggle" checked>
                    <label class="switch-label" for="create-recovery-point-toggle"></label>
                </div>
            </div>
        </div>
    `;
    
    UI.showCustomDialog(
        'Create Backup',
        modalContent,
        'Start Backup',
        'Cancel',
        () => {
            startBackup();
        }
    );
    
    // Initialize switches
    UI.initSwitches();
    
    // Add event listener for custom backup type
    document.getElementById('backup-type-custom').addEventListener('change', function() {
        document.getElementById('custom-backup-options').style.display = this.checked ? 'block' : 'none';
    });
    
    // Add event listener for encryption toggle
    document.getElementById('backup-encryption-toggle').addEventListener('change', function() {
        document.getElementById('encryption-password').style.display = this.checked ? 'block' : 'none';
    });
}

/**
 * Start the backup process
 */
function startBackup() {
    const name = document.getElementById('backup-name').value;
    
    // Get backup type
    let type = 'full';
    const typeRadios = document.getElementsByName('backup-type');
    for (const radio of typeRadios) {
        if (radio.checked) {
            type = radio.value;
            break;
        }
    }
    
    // Get options
    const useCompression = document.getElementById('backup-compression-toggle').checked;
    const useEncryption = document.getElementById('backup-encryption-toggle').checked;
    const createRecoveryPoint = document.getElementById('create-recovery-point-toggle').checked;
    
    // Get password if encryption is enabled
    let password = '';
    if (useEncryption) {
        password = document.getElementById('backup-password').value;
        if (!password) {
            UI.showToast('Please enter an encryption password', 'error');
            return;
        }
    }
    
    // Build custom options if custom type is selected
    let customOptions = '';
    if (type === 'custom') {
        const backupSystem = document.getElementById('backup-system').checked;
        const backupData = document.getElementById('backup-data').checked;
        const backupApps = document.getElementById('backup-apps').checked;
        const backupVendor = document.getElementById('backup-vendor').checked;
        const backupBoot = document.getElementById('backup-boot').checked;
        
        if (!backupSystem && !backupData && !backupApps && !backupVendor && !backupBoot) {
            UI.showToast('Please select at least one backup option', 'error');
            return;
        }
        
        customOptions = [
            backupSystem ? '--system' : '',
            backupData ? '--data' : '',
            backupApps ? '--apps' : '',
            backupVendor ? '--vendor' : '',
            backupBoot ? '--boot' : ''
        ].filter(Boolean).join(' ');
    }
    
    UI.showLoader('Creating backup...');
    
    // Build backup command
    let command = `sh /data/adb/modules/kernelsu_antibootloop_backup/scripts/backup-engine.sh create --name "${name}" --type ${type}`;
    
    if (type === 'custom' && customOptions) {
        command += ` ${customOptions}`;
    }
    
    if (useCompression) {
        command += ' --compress';
    }
    
    if (useEncryption) {
        command += ` --encrypt --password "${password}"`;
    }
    
    if (!AppState.isWebUIXConnected) {
        UI.hideLoader();
        UI.showToast('Backup created successfully (mock mode)');
        
        // Add mock backup
        const now = new Date();
        AppState.backups.push({
            name: `${name}_${type}_${now.toISOString().slice(0, 10)}.tar.gz`,
            path: `/data/adb/modules/kernelsu_antibootloop_backup/config/backups/${name}_${type}_${now.toISOString().slice(0, 10)}.tar.gz`,
            size: '1.2G',
            date: now,
            type
        });
        
        // Update UI
        updateBackupList();
        
        // Create recovery point if selected
        if (createRecoveryPoint) {
            const pointName = `backup_point_${now.getTime()}.point`;
            AppState.recoveryPoints.push({
                name: pointName,
                path: `/data/adb/modules/kernelsu_antibootloop_backup/config/recovery_points/${pointName}`,
                date: now,
                description: `Recovery point created with backup ${name}`
            });
            
            updateRecoveryPointList();
        }
        
        return;
    }
    
    // Execute command
    executeCommand(command)
        .then(result => {
            UI.hideLoader();
            
            if (result && result.includes('Backup completed successfully')) {
                UI.showToast('Backup created successfully');
                
                // Create recovery point if selected
                if (createRecoveryPoint) {
                    createRecoveryPoint(`Backup ${name}`);
                }
                
                // Refresh data
                refreshData();
                
                // Log activity
                logActivity('backup', `Created backup: ${name}`);
            } else {
                UI.showToast('Backup failed', 'error');
                console.error('Backup failed:', result);
            }
        })
        .catch(error => {
            UI.hideLoader();
            UI.showToast('Backup failed', 'error');
            console.error('Error creating backup:', error);
        });
}

/**
 * Perform a quick backup with default settings
 */
function performQuickBackup() {
    const name = `quick_backup_${new Date().toISOString().replace(/[:.]/g, '-')}`;
    
    UI.showLoader('Creating quick backup...');
    
    // Build backup command with defaults
    let command = `sh /data/adb/modules/kernelsu_antibootloop_backup/scripts/backup-engine.sh create --name "${name}" --type full`;
    
    if (AppState.settings.backupCompression) {
        command += ' --compress';
    }
    
    if (!AppState.isWebUIXConnected) {
        UI.hideLoader();
        UI.showToast('Quick backup created successfully (mock mode)');
        
        // Add mock backup
        const now = new Date();
        AppState.backups.push({
            name: `${name}_full_${now.toISOString().slice(0, 10)}.tar.gz`,
            path: `/data/adb/modules/kernelsu_antibootloop_backup/config/backups/${name}_full_${now.toISOString().slice(0, 10)}.tar.gz`,
            size: '1.2G',
            date: now,
            type: 'full'
        });
        
        // Update UI
        updateBackupList();
        
        return;
    }
    
    // Execute command
    executeCommand(command)
        .then(result => {
            UI.hideLoader();
            
            if (result && result.includes('Backup completed successfully')) {
                UI.showToast('Quick backup created successfully');
                
                // Refresh data
                refreshData();
                
                // Log activity
                logActivity('backup', `Created quick backup: ${name}`);
            } else {
                UI.showToast('Quick backup failed', 'error');
                console.error('Quick backup failed:', result);
            }
        })
        .catch(error => {
            UI.hideLoader();
            UI.showToast('Quick backup failed', 'error');
            console.error('Error creating quick backup:', error);
        });
}

/**
 * Show dialog for restoring a backup
 * @param {Object} backup - The backup object to restore
 */
function showRestoreDialog(backup) {
    const modalContent = `
        <div class="restore-dialog">
            <p>You are about to restore the following backup:</p>
            <div class="backup-info">
                <p><strong>Name:</strong> ${backup.name.replace(/\.tar\.(gz|xz)$/, '')}</p>
                <p><strong>Type:</strong> ${backup.type}</p>
                <p><strong>Date:</strong> ${backup.date.toLocaleString()}</p>
                <p><strong>Size:</strong> ${backup.size}</p>
            </div>
            
            <div class="warning-box">
                <i class="material-icons">warning</i>
                <p>Warning: Restoring a backup will overwrite your current system state. Make sure you have a recent backup before proceeding.</p>
            </div>
            
            <div class="form-group">
                <label for="restore-verification">Verification:</label>
                <div class="switch-container">
                    <input type="checkbox" id="restore-verification" checked>
                    <label class="switch-label" for="restore-verification"></label>
                </div>
            </div>
            
            <div class="form-group">
                <label for="create-pre-restore-point">Create Pre-Restore Point:</label>
                <div class="switch-container">
                    <input type="checkbox" id="create-pre-restore-point" checked>
                    <label class="switch-label" for="create-pre-restore-point"></label>
                </div>
            </div>
            
            <div class="form-group" id="encryption-password-restore" style="display: none;">
                <label for="restore-password">Encryption Password:</label>
                <input type="password" id="restore-password" class="md-input" placeholder="Enter encryption password">
            </div>
            
            <div class="verification-checkbox">
                <input type="checkbox" id="restore-confirm">
                <label for="restore-confirm">I understand that this action will overwrite my current system data</label>
            </div>
        </div>
    `;
    
    UI.showCustomDialog(
        'Restore Backup',
        modalContent,
        'Restore',
        'Cancel',
        () => {
            // Check confirmation checkbox
            if (!document.getElementById('restore-confirm').checked) {
                UI.showToast('Please confirm that you understand the risks', 'error');
                return;
            }
            
            restoreBackup(backup);
        }
    );
    
    // Initialize switches
    UI.initSwitches();
    
    // Check if backup might be encrypted
    if (backup.name.includes('.enc') || AppState.settings.backupEncryption) {
        document.getElementById('encryption-password-restore').style.display = 'block';
    }
}

/**
 * Restore a backup
 * @param {Object} backup - The backup object to restore
 */
function restoreBackup(backup) {
    const useVerification = document.getElementById('restore-verification').checked;
    const createPreRestorePoint = document.getElementById('create-pre-restore-point').checked;
    
    // Get password if encryption is enabled
    let password = '';
    if (document.getElementById('encryption-password-restore').style.display !== 'none') {
        password = document.getElementById('restore-password').value;
    }
    
    UI.showLoader('Restoring backup...');
    
    // Create pre-restore point if selected
    let preRestorePromise = Promise.resolve();
    if (createPreRestorePoint) {
        preRestorePromise = new Promise((resolve, reject) => {
            createRecoveryPoint('Pre-restore point')
                .then(() => resolve())
                .catch(error => {
                    console.error('Error creating pre-restore point:', error);
                    resolve(); // Continue with restore even if recovery point fails
                });
        });
    }
    
    preRestorePromise.then(() => {
        // Build restore command
        let command = `sh /data/adb/modules/kernelsu_antibootloop_backup/scripts/backup-engine.sh restore --path "${backup.path}"`;
        
        if (useVerification) {
            command += ' --verify';
        }
        
        if (password) {
            command += ` --password "${password}"`;
        }
        
        if (!AppState.isWebUIXConnected) {
            setTimeout(() => {
                UI.hideLoader();
                UI.showToast('Backup restored successfully (mock mode)');
            }, 2000);
            return;
        }
        
        // Execute command
        executeCommand(command)
            .then(result => {
                UI.hideLoader();
                
                if (result && result.includes('Restore completed successfully')) {
                    UI.showToast('Backup restored successfully');
                    
                    // Show reboot dialog
                    showRebootDialog('Restore completed successfully. Would you like to reboot now to apply the changes?');
                    
                    // Log activity
                    logActivity('restore', `Restored backup: ${backup.name}`);
                } else if (result && result.includes('Encryption password required')) {
                    UI.showToast('Encryption password required', 'error');
                    
                    // Show restore dialog again with password field visible
                    const encPasswordElem = document.getElementById('encryption-password-restore');
                    if (encPasswordElem) {
                        encPasswordElem.style.display = 'block';
                    }
                } else if (result && result.includes('Incorrect encryption password')) {
                    UI.showToast('Incorrect encryption password', 'error');
                } else {
                    UI.showToast('Restore failed', 'error');
                    console.error('Restore failed:', result);
                }
            })
            .catch(error => {
                UI.hideLoader();
                UI.showToast('Restore failed', 'error');
                console.error('Error restoring backup:', error);
            });
    });
}

/**
 * Show dialog for deleting a backup
 * @param {Object} backup - The backup object to delete
 */
function showDeleteBackupDialog(backup) {
    UI.showConfirmDialog(
        'Delete Backup',
        `Are you sure you want to delete the backup "${backup.name.replace(/\.tar\.(gz|xz)$/, '')}"? This action cannot be undone.`,
        'Delete',
        'Cancel',
        () => {
            deleteBackup(backup);
        }
    );
}

/**
 * Delete a backup
 * @param {Object} backup - The backup object to delete
 */
function deleteBackup(backup) {
    UI.showLoader('Deleting backup...');
    
    if (!AppState.isWebUIXConnected) {
        setTimeout(() => {
            UI.hideLoader();
            
            // Remove from array
            const index = AppState.backups.findIndex(b => b.name === backup.name);
            if (index !== -1) {
                AppState.backups.splice(index, 1);
            }
            
            // Update UI
            updateBackupList();
            
            UI.showToast('Backup deleted successfully (mock mode)');
        }, 1000);
        return;
    }
    
    // Execute command
    executeCommand(`rm -f "${backup.path}"`)
        .then(() => {
            UI.hideLoader();
            
            // Remove from array
            const index = AppState.backups.findIndex(b => b.name === backup.name);
            if (index !== -1) {
                AppState.backups.splice(index, 1);
            }
            
            // Update UI
            updateBackupList();
            
            UI.showToast('Backup deleted successfully');
            
            // Log activity
            logActivity('backup', `Deleted backup: ${backup.name}`);
            
            // Refresh backup stats
            fetchBackupList();
        })
        .catch(error => {
            UI.hideLoader();
            UI.showToast('Failed to delete backup', 'error');
            console.error('Error deleting backup:', error);
        });
}

/**
 * Export a backup
 * @param {Object} backup - The backup object to export
 */
function exportBackup(backup) {
    UI.showLoader('Preparing backup for export...');
    
    if (!AppState.isWebUIXConnected) {
        setTimeout(() => {
            UI.hideLoader();
            UI.showToast('Backup exported successfully (mock mode)');
        }, 1500);
        return;
    }
    
    // Execute command to copy to sdcard
    executeCommand(`cp "${backup.path}" /sdcard/Download/`)
        .then(() => {
            UI.hideLoader();
            UI.showToast(`Backup exported to Downloads folder as "${backup.name}"`);
            
            // Log activity
            logActivity('backup', `Exported backup: ${backup.name}`);
        })
        .catch(error => {
            UI.hideLoader();
            UI.showToast('Failed to export backup', 'error');
            console.error('Error exporting backup:', error);
        });
}

/**
 * Show dialog for importing a backup
 */
function showImportDialog() {
    const modalContent = `
        <div class="import-dialog">
            <p>Select a backup file to import:</p>
            <p class="note">Note: The backup file must be in the Downloads folder.</p>
            
            <div class="form-group">
                <label for="import-file">Backup File:</label>
                <input type="text" id="import-file" class="md-input" placeholder="Filename (e.g., backup.tar.gz)">
            </div>
            
            <div class="form-group">
                <label for="import-verification">Verify Backup:</label>
                <div class="switch-container">
                    <input type="checkbox" id="import-verification" checked>
                    <label class="switch-label" for="import-verification"></label>
                </div>
            </div>
        </div>
    `;
    
    UI.showCustomDialog(
        'Import Backup',
        modalContent,
        'Import',
        'Cancel',
        () => {
            const filename = document.getElementById('import-file').value;
            
            if (!filename) {
                UI.showToast('Please enter a filename', 'error');
                return;
            }
            
            importBackup(filename);
        }
    );
    
    // Initialize switches
    UI.initSwitches();
}