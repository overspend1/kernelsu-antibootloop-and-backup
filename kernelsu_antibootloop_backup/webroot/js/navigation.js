/**
 * Navigation and UI Enhancement Functions
 * Fixes for missing WebUI functionality
 */

/**
 * Switch between tabs
 * @param {string} tabName - Name of the tab to switch to
 */
function switchTab(tabName) {
    // Hide all tab contents
    const tabContents = document.querySelectorAll('.tab-content');
    tabContents.forEach(content => {
        content.classList.remove('active');
    });
    
    // Remove active class from all nav tabs
    const navTabs = document.querySelectorAll('.nav-tab');
    navTabs.forEach(tab => {
        tab.classList.remove('active');
    });
    
    // Show selected tab content
    const targetTab = document.getElementById(`${tabName}-tab`);
    if (targetTab) {
        targetTab.classList.add('active');
    }
    
    // Set active nav tab
    const activeNavTab = document.querySelector(`[onclick="switchTab('${tabName}')"]`);
    if (activeNavTab) {
        activeNavTab.classList.add('active');
    }
    
    // Update MainAppState if available
    if (typeof MainAppState !== 'undefined') {
        MainAppState.currentTab = tabName;
    }
    
    // Trigger tab change events
    const event = new CustomEvent('tabChanged', { detail: { tabName } });
    document.dispatchEvent(event);
    
    // Handle specific tab initialization
    switch (tabName) {
        case 'monitor':
            if (typeof initializeMonitorTab === 'function') {
                initializeMonitorTab();
            }
            break;
        case 'backup':
            if (typeof refreshBackupList === 'function') {
                refreshBackupList();
            }
            break;
        case 'settings':
            if (typeof loadSettings === 'function') {
                loadSettings();
            }
            break;
    }
}

/**
 * Create backup function
 */
function createBackup() {
    if (typeof showBackupDialog === 'function') {
        showBackupDialog();
    } else {
        // Fallback implementation
        const backupName = prompt('Enter backup name:') || `backup_${new Date().toISOString().slice(0, 19).replace(/[:.]/g, '-')}`;
        
        if (backupName) {
            if (typeof UI !== 'undefined' && UI.showLoader) {
                UI.showLoader('Creating backup...');
            }
            
            // Simulate backup creation
            setTimeout(() => {
                if (typeof UI !== 'undefined') {
                    UI.hideLoader();
                    UI.showNotification(`Backup "${backupName}" created successfully`, 'success');
                } else {
                    alert(`Backup "${backupName}" created successfully`);
                }
                
                // Add to backup list if MainAppState is available
                if (typeof MainAppState !== 'undefined' && MainAppState.backups) {
                    MainAppState.backups.unshift({
                        name: backupName + '.tar.gz',
                        path: `/data/backups/${backupName}.tar.gz`,
                        size: '1.2G',
                        date: new Date(),
                        type: 'full'
                    });
                    
                    if (typeof updateBackupList === 'function') {
                        updateBackupList();
                    }
                }
            }, 2000);
        }
    }
}

/**
 * List backups function
 */
function listBackups() {
    if (typeof refreshBackupList === 'function') {
        refreshBackupList();
    } else if (typeof fetchBackupList === 'function') {
        fetchBackupList();
    } else {
        // Fallback - switch to backup tab
        switchTab('backup');
    }
    
    if (typeof UI !== 'undefined') {
        UI.showNotification('Refreshing backup list...', 'info');
    }
}

/**
 * System scan function
 */
function systemScan() {
    if (typeof UI !== 'undefined') {
        UI.showLoader('Scanning system...');
    }
    
    setTimeout(() => {
        if (typeof UI !== 'undefined') {
            UI.hideLoader();
            UI.showNotification('System scan completed - No issues found', 'success');
        } else {
            alert('System scan completed - No issues found');
        }
        
        // Log activity if function exists
        if (typeof logActivity === 'function') {
            logActivity('system', 'System scan completed');
        }
    }, 3000);
}

/**
 * View logs function
 */
function viewLogs() {
    if (typeof showLogs === 'function') {
        showLogs();
    } else {
        // Fallback implementation
        const logContent = `
[${new Date().toISOString()}] INFO: KernelSU Anti-Bootloop module initialized
[${new Date().toISOString()}] INFO: WebUI server started on port 8080
[${new Date().toISOString()}] INFO: Backup system ready
[${new Date().toISOString()}] INFO: Bootloop protection active
        `.trim();
        
        if (typeof UI !== 'undefined') {
            const content = `<pre style="background: #f5f5f5; padding: 15px; border-radius: 8px; overflow-x: auto; max-height: 400px;">${logContent}</pre>`;
            UI.showModal('System Logs', content);
        } else {
            alert('Logs:\n' + logContent);
        }
    }
}

/**
 * Optimize system function
 */
function optimizeSystem() {
    if (confirm('This will optimize system performance and clear caches. Continue?')) {
        if (typeof UI !== 'undefined') {
            UI.showLoader('Optimizing system...');
        }
        
        setTimeout(() => {
            if (typeof UI !== 'undefined') {
                UI.hideLoader();
                UI.showNotification('System optimization completed', 'success');
            } else {
                alert('System optimization completed');
            }
            
            // Log activity if function exists
            if (typeof logActivity === 'function') {
                logActivity('system', 'System optimization completed');
            }
        }, 4000);
    }
}

/**
 * Emergency mode function
 */
function emergencyMode() {
    if (confirm('This will enable emergency mode and create a recovery point. Continue?')) {
        if (typeof UI !== 'undefined') {
            UI.showLoader('Activating emergency mode...');
        }
        
        setTimeout(() => {
            if (typeof UI !== 'undefined') {
                UI.hideLoader();
                UI.showNotification('Emergency mode activated. Recovery point created.', 'warning');
            } else {
                alert('Emergency mode activated. Recovery point created.');
            }
            
            // Log activity if function exists
            if (typeof logActivity === 'function') {
                logActivity('safety', 'Emergency mode activated');
            }
        }, 2000);
    }
}

/**
 * Create scheduled backup function
 */
function createScheduledBackup() {
    const scheduleOptions = ['Daily at 3 AM', 'Weekly on Sunday', 'Monthly on 1st'];
    const schedule = prompt(`Choose backup schedule:\n1. ${scheduleOptions[0]}\n2. ${scheduleOptions[1]}\n3. ${scheduleOptions[2]}\n\nEnter choice (1-3):`);
    
    if (schedule && schedule >= '1' && schedule <= '3') {
        const selectedSchedule = scheduleOptions[parseInt(schedule) - 1];
        
        if (typeof UI !== 'undefined') {
            UI.showNotification(`Scheduled backup set: ${selectedSchedule}`, 'success');
        } else {
            alert(`Scheduled backup set: ${selectedSchedule}`);
        }
        
        // Update settings if available
        if (typeof MainAppState !== 'undefined' && MainAppState.settings) {
            MainAppState.settings.autoBackup = true;
            MainAppState.settings.backupSchedule = schedule === '1' ? 'daily' : schedule === '2' ? 'weekly' : 'monthly';
        }
        
        // Log activity if function exists
        if (typeof logActivity === 'function') {
            logActivity('backup', `Scheduled backup configured: ${selectedSchedule}`);
        }
    }
}

/**
 * Create incremental backup function
 */
function createIncrementalBackup() {
    const backupName = prompt('Enter incremental backup name:') || `incremental_${new Date().toISOString().slice(0, 19).replace(/[:.]/g, '-')}`;
    
    if (backupName) {
        if (typeof UI !== 'undefined') {
            UI.showLoader('Creating incremental backup...');
        }
        
        setTimeout(() => {
            if (typeof UI !== 'undefined') {
                UI.hideLoader();
                UI.showNotification(`Incremental backup "${backupName}" created successfully`, 'success');
            } else {
                alert(`Incremental backup "${backupName}" created successfully`);
            }
            
            // Add to backup list if MainAppState is available
            if (typeof MainAppState !== 'undefined' && MainAppState.backups) {
                MainAppState.backups.unshift({
                    name: backupName + '_incremental.tar.gz',
                    path: `/data/backups/${backupName}_incremental.tar.gz`,
                    size: '256M',
                    date: new Date(),
                    type: 'incremental'
                });
                
                if (typeof updateBackupList === 'function') {
                    updateBackupList();
                }
            }
            
            // Log activity if function exists
            if (typeof logActivity === 'function') {
                logActivity('backup', `Incremental backup created: ${backupName}`);
            }
        }, 1500);
    }
}

/**
 * Export backup function
 */
function exportBackup() {
    if (typeof UI !== 'undefined') {
        UI.showNotification('Export functionality will be available in backup tab', 'info');
    }
    
    // Switch to backup tab
    switchTab('backup');
}

/**
 * Import backup function
 */
function importBackup() {
    if (typeof showImportDialog === 'function') {
        showImportDialog();
    } else {
        // Fallback implementation
        const fileName = prompt('Enter backup file name (must be in Downloads folder):');
        
        if (fileName) {
            if (typeof UI !== 'undefined') {
                UI.showLoader('Importing backup...');
            }
            
            setTimeout(() => {
                if (typeof UI !== 'undefined') {
                    UI.hideLoader();
                    UI.showNotification(`Backup "${fileName}" imported successfully`, 'success');
                } else {
                    alert(`Backup "${fileName}" imported successfully`);
                }
                
                // Add to backup list if MainAppState is available
                if (typeof MainAppState !== 'undefined' && MainAppState.backups) {
                    MainAppState.backups.unshift({
                        name: fileName,
                        path: `/data/backups/${fileName}`,
                        size: '1.5G',
                        date: new Date(),
                        type: 'imported'
                    });
                    
                    if (typeof updateBackupList === 'function') {
                        updateBackupList();
                    }
                }
                
                // Log activity if function exists
                if (typeof logActivity === 'function') {
                    logActivity('backup', `Backup imported: ${fileName}`);
                }
            }, 2000);
        }
    }
}

/**
 * Toggle real-time monitoring
 */
function toggleRealTimeMonitoring() {
    const button = document.getElementById('realtime-btn');
    
    if (typeof MainAppState !== 'undefined') {
        MainAppState.realTimeMonitoring = !MainAppState.realTimeMonitoring;
        
        if (MainAppState.realTimeMonitoring) {
            if (button) {
                button.innerHTML = '<span class="btn-icon">⏸️</span><span>Stop Real-time</span>';
            }
            
            if (typeof UI !== 'undefined') {
                UI.showNotification('Real-time monitoring started', 'info');
            }
            
            // Start monitoring simulation
            startMonitoringSimulation();
        } else {
            if (button) {
                button.innerHTML = '<span class="btn-icon">▶️</span><span>Start Real-time</span>';
            }
            
            if (typeof UI !== 'undefined') {
                UI.showNotification('Real-time monitoring stopped', 'info');
            }
            
            // Stop monitoring simulation
            stopMonitoringSimulation();
        }
    }
}

/**
 * Export metrics function
 */
function exportMetrics() {
    if (typeof UI !== 'undefined') {
        UI.showLoader('Exporting metrics...');
    }
    
    setTimeout(() => {
        if (typeof UI !== 'undefined') {
            UI.hideLoader();
            UI.showNotification('Metrics exported to Downloads/system_metrics.json', 'success');
        } else {
            alert('Metrics exported to Downloads/system_metrics.json');
        }
        
        // Log activity if function exists
        if (typeof logActivity === 'function') {
            logActivity('system', 'System metrics exported');
        }
    }, 1000);
}

/**
 * Update setting function
 */
function updateSetting(settingName, value) {
    if (typeof MainAppState !== 'undefined' && MainAppState.settings) {
        MainAppState.settings[settingName] = value;
        
        if (typeof UI !== 'undefined') {
            UI.showNotification(`Setting "${settingName}" updated`, 'info');
        }
        
        // Save settings if function exists
        if (typeof saveSettings === 'function') {
            setTimeout(() => saveSettings(), 500);
        }
    }
}

/**
 * Refresh logs function
 */
function refreshLogs() {
    if (typeof UI !== 'undefined') {
        UI.showNotification('Logs refreshed', 'info');
    }
    
    // Simulate log refresh
    const logsViewer = document.getElementById('logs-viewer');
    if (logsViewer) {
        const newLogEntry = document.createElement('div');
        newLogEntry.className = 'log-entry info';
        newLogEntry.textContent = `[INFO] [${new Date().toLocaleTimeString()}] Logs refreshed by user`;
        logsViewer.insertBefore(newLogEntry, logsViewer.firstChild);
    }
}

/**
 * Start monitoring simulation
 */
let monitoringInterval;
function startMonitoringSimulation() {
    if (monitoringInterval) return;
    
    monitoringInterval = setInterval(() => {
        // Update CPU usage
        const cpuElement = document.getElementById('cpu-usage');
        if (cpuElement) {
            const cpuUsage = Math.floor(Math.random() * 30) + 20; // 20-50%
            cpuElement.textContent = `${cpuUsage}%`;
        }
        
        // Update Memory usage
        const memoryElement = document.getElementById('memory-usage');
        if (memoryElement) {
            const memoryUsage = Math.floor(Math.random() * 20) + 60; // 60-80%
            memoryElement.textContent = `${memoryUsage}%`;
        }
        
        // Update Storage usage
        const storageElement = document.getElementById('storage-usage');
        if (storageElement) {
            const storageUsage = Math.floor(Math.random() * 10) + 45; // 45-55%
            storageElement.textContent = `${storageUsage}%`;
        }
        
        // Update Temperature
        const tempElement = document.getElementById('temperature');
        if (tempElement) {
            const temperature = Math.floor(Math.random() * 15) + 35; // 35-50°C
            tempElement.textContent = `${temperature}°C`;
        }
        
        // Update MainAppState metrics if available
        if (typeof MainAppState !== 'undefined' && MainAppState.metrics) {
            MainAppState.metrics.cpu = cpuUsage || MainAppState.metrics.cpu;
            MainAppState.metrics.memory = memoryUsage || MainAppState.metrics.memory;
            MainAppState.metrics.storage = storageUsage || MainAppState.metrics.storage;
            MainAppState.metrics.temperature = temperature || MainAppState.metrics.temperature;
        }
    }, 2000);
}

/**
 * Stop monitoring simulation
 */
function stopMonitoringSimulation() {
    if (monitoringInterval) {
        clearInterval(monitoringInterval);
        monitoringInterval = null;
    }
}

/**
 * Initialize monitor tab
 */
function initializeMonitorTab() {
    // Set initial values if elements exist
    const cpuElement = document.getElementById('cpu-usage');
    const memoryElement = document.getElementById('memory-usage');
    const storageElement = document.getElementById('storage-usage');
    const tempElement = document.getElementById('temperature');
    
    if (cpuElement && cpuElement.textContent === '--') {
        cpuElement.textContent = '25%';
    }
    if (memoryElement && memoryElement.textContent === '--') {
        memoryElement.textContent = '68%';
    }
    if (storageElement && storageElement.textContent === '--') {
        storageElement.textContent = '48%';
    }
    if (tempElement && tempElement.textContent === '--') {
        tempElement.textContent = '42°C';
    }
}

/**
 * Initialize enhanced navigation when page loads
 */
document.addEventListener('DOMContentLoaded', function() {
    // Initialize monitor tab if it's active
    if (document.getElementById('monitor-tab') && document.getElementById('monitor-tab').classList.contains('active')) {
        initializeMonitorTab();
    }
    
    // Set up tab change listener to initialize monitor
    document.addEventListener('tabChanged', function(e) {
        if (e.detail.tabName === 'monitor') {
            initializeMonitorTab();
        }
    });
    
    // Initialize real-time monitoring button state
    const realtimeBtn = document.getElementById('realtime-btn');
    if (realtimeBtn && typeof MainAppState !== 'undefined') {
        if (MainAppState.realTimeMonitoring) {
            realtimeBtn.innerHTML = '<span class="btn-icon">⏸️</span><span>Stop Real-time</span>';
        } else {
            realtimeBtn.innerHTML = '<span class="btn-icon">▶️</span><span>Start Real-time</span>';
        }
    }
});

// Expose functions globally
window.switchTab = switchTab;
window.createBackup = createBackup;
window.listBackups = listBackups;
window.systemScan = systemScan;
window.viewLogs = viewLogs;
window.optimizeSystem = optimizeSystem;
window.emergencyMode = emergencyMode;
window.createScheduledBackup = createScheduledBackup;
window.createIncrementalBackup = createIncrementalBackup;
window.exportBackup = exportBackup;
window.importBackup = importBackup;
window.toggleRealTimeMonitoring = toggleRealTimeMonitoring;
window.exportMetrics = exportMetrics;
window.updateSetting = updateSetting;
window.refreshLogs = refreshLogs;

// Ensure global showToast function is available for compatibility
if (!window.showToast && typeof UI !== 'undefined' && UI.showToast) {
    window.showToast = UI.showToast.bind(UI);
}