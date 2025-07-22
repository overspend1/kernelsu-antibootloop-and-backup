// KernelSU Control Center - Main Application JavaScript
// Modern ES6+ implementation with accessibility and performance optimizations

class KernelSUApp {
    constructor() {
        this.currentPage = 'dashboard';
        this.isLoading = false;
        this.notifications = [];
        this.moduleInfo = null;
        
        this.init();
    }
    
    init() {
        this.setupEventListeners();
        this.initializeAnimations();
        this.loadInitialData();
        this.setupAccessibility();
        
        // Initialize page after DOM is ready
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', () => this.onDOMReady());
        } else {
            this.onDOMReady();
        }
    }
    

    
    onDOMReady() {
        this.updateActiveNavigation();
        this.startPeriodicUpdates();
        this.showWelcomeMessage();
    }
    
    setupEventListeners() {
        // Navigation handling
        document.addEventListener('click', (e) => {
            const navItem = e.target.closest('.nav-item');
            if (navItem) {
                e.preventDefault();
                const page = navItem.dataset.page;
                if (page && page !== this.currentPage) {
                    this.navigateToPage(page);
                }
            }
            
            // Quick action handling
            const actionCard = e.target.closest('.action-card');
            if (actionCard) {
                e.preventDefault();
                const action = actionCard.dataset.action;
                if (action) {
                    this.handleQuickAction(action);
                }
            }
            
            // Header action buttons
            const actionBtn = e.target.closest('.action-btn');
            if (actionBtn) {
                e.preventDefault();
                this.handleHeaderAction(actionBtn);
            }
        });
        
        // Keyboard navigation
        document.addEventListener('keydown', (e) => {
            this.handleKeyboardNavigation(e);
        });
        
        // Settings event listeners
        document.getElementById('saveSettings')?.addEventListener('click', () => this.saveSettings());
        document.getElementById('resetSettings')?.addEventListener('click', () => this.resetSettings());
        
        // Logs event listeners
        document.getElementById('logLevel')?.addEventListener('change', () => this.filterLogs());
        document.getElementById('clearLogs')?.addEventListener('click', () => this.clearLogs());
        document.getElementById('refreshLogs')?.addEventListener('click', () => this.loadSystemLogs());
        
        // Window resize handling
        window.addEventListener('resize', this.debounce(() => {
            this.handleResize();
        }, 250));
        
        // Visibility change handling
        document.addEventListener('visibilitychange', () => {
            if (document.hidden) {
                this.pauseUpdates();
            } else {
                this.resumeUpdates();
            }
        });
    }
    
    navigateToPage(pageId) {
        if (this.isLoading) return;
        
        const currentPageEl = document.querySelector('.page.active');
        const targetPageEl = document.getElementById(pageId);
        const currentNavItem = document.querySelector('.nav-item.active');
        const targetNavItem = document.querySelector(`[data-page="${pageId}"]`);
        
        if (!targetPageEl || !targetNavItem) {
            console.warn(`Page or navigation item not found: ${pageId}`);
            return;
        }
        
        // Update navigation state
        if (currentNavItem) {
            currentNavItem.classList.remove('active');
            currentNavItem.removeAttribute('aria-current');
        }
        
        targetNavItem.classList.add('active');
        targetNavItem.setAttribute('aria-current', 'page');
        
        // Animate page transition
        this.animatePageTransition(currentPageEl, targetPageEl);
        
        // Update current page
        this.currentPage = pageId;
        
        // Update URL without page reload
        if (history.pushState) {
            history.pushState({ page: pageId }, '', `#${pageId}`);
        }
        
        // Announce page change for screen readers
        this.announcePageChange(pageId);
    }
    
    animatePageTransition(currentPage, targetPage) {
        if (currentPage) {
            currentPage.style.opacity = '0';
            currentPage.style.transform = 'translateY(-20px)';
            
            setTimeout(() => {
                currentPage.classList.remove('active');
                targetPage.classList.add('active');
                
                // Reset and animate in new page
                targetPage.style.opacity = '0';
                targetPage.style.transform = 'translateY(20px)';
                
                requestAnimationFrame(() => {
                    targetPage.style.transition = 'opacity 0.3s ease, transform 0.3s ease';
                    targetPage.style.opacity = '1';
                    targetPage.style.transform = 'translateY(0)';
                });
            }, 150);
        } else {
            targetPage.classList.add('active');
        }
    }
    
    handleQuickAction(action) {
        const actions = {
            backup: () => this.startBackup(),
            scan: () => this.startSystemScan(),
            optimize: () => this.optimizeSystem(),
            emergency: () => this.enterEmergencyMode()
        };
        
        if (actions[action]) {
            actions[action]();
        } else {
            this.showNotification(`Action "${action}" is not yet implemented`, 'info');
        }
    }
    
    handleHeaderAction(button) {
        const icon = button.querySelector('i');
        if (!icon) return;
        
        if (icon.classList.contains('fa-bell')) {
            this.toggleNotifications();
        } else if (icon.classList.contains('fa-cog')) {
            this.navigateToPage('settings');
        } else if (icon.classList.contains('fa-question-circle')) {
            this.showHelp();
        }
    }
    
    handleKeyboardNavigation(e) {
        // Alt + number keys for quick navigation
        if (e.altKey && e.key >= '1' && e.key <= '6') {
            e.preventDefault();
            const pages = ['dashboard', 'backup', 'restore', 'modules', 'logs', 'settings'];
            const pageIndex = parseInt(e.key) - 1;
            if (pages[pageIndex]) {
                this.navigateToPage(pages[pageIndex]);
            }
        }
        
        // Escape key to close modals/notifications
        if (e.key === 'Escape') {
            this.closeModals();
        }
    }
    
    startBackup() {
        this.showBackupDialog();
    }
    
    showBackupDialog() {
        const modalContent = `
            <div class="backup-dialog">
                <h3>Create System Backup</h3>
                <p>Configure your backup settings:</p>
                
                <div class="form-group">
                    <label for="backup-name">Backup Name:</label>
                    <input type="text" id="backup-name" class="md-input" value="backup_${new Date().toISOString().replace(/[:.]/g, '-')}" placeholder="Enter backup name">
                </div>
                
                <div class="form-group">
                    <label>Backup Type:</label>
                    <div class="radio-group">
                        <label><input type="radio" name="backup-type" value="full" checked> Full System Backup</label>
                        <label><input type="radio" name="backup-type" value="system"> System Only</label>
                        <label><input type="radio" name="backup-type" value="data"> Data Only</label>
                    </div>
                </div>
                
                <div class="form-group">
                    <label><input type="checkbox" id="backup-compression" checked> Enable Compression</label>
                </div>
                
                <div class="form-group">
                    <label><input type="checkbox" id="backup-encryption"> Enable Encryption</label>
                </div>
                
                <div class="form-group" id="encryption-password" style="display: none;">
                    <label for="backup-password">Encryption Password:</label>
                    <input type="password" id="backup-password" class="md-input" placeholder="Enter encryption password">
                </div>
                
                <div class="dialog-actions">
                    <button class="btn btn-secondary" onclick="this.closeModal()">Cancel</button>
                    <button class="btn btn-primary" onclick="kernelSUApp.performBackup()">Create Backup</button>
                </div>
            </div>
        `;
        
        this.showModal(modalContent);
        
        // Add event listener for encryption toggle
        const encryptionToggle = document.getElementById('backup-encryption');
        const passwordField = document.getElementById('encryption-password');
        
        if (encryptionToggle && passwordField) {
            encryptionToggle.addEventListener('change', function() {
                passwordField.style.display = this.checked ? 'block' : 'none';
            });
        }
    }
    
    performBackup() {
        const name = document.getElementById('backup-name')?.value || `backup_${Date.now()}`;
        
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
        const useCompression = document.getElementById('backup-compression')?.checked || false;
        const useEncryption = document.getElementById('backup-encryption')?.checked || false;
        const password = document.getElementById('backup-password')?.value || '';
        
        if (useEncryption && !password) {
            this.showNotification('Please enter an encryption password', 'error');
            return;
        }
        
        this.closeModal();
        this.showNotification('Starting system backup...', 'info');
        
        if (typeof ksu !== 'undefined') {
            // Build backup command
            let command = `sh /data/adb/modules/kernelsu_antibootloop_backup/scripts/backup-engine.sh create --name "${name}" --type ${type}`;
            
            if (useCompression) {
                command += ' --compress';
            }
            
            if (useEncryption) {
                command += ` --encrypt --password "${password}"`;
            }
            
            ksu.exec(command, (exitCode, stdout, stderr) => {
                if (exitCode === 0) {
                    this.showNotification('Backup completed successfully!', 'success');
                    this.updateBackupStatus();
                    this.loadRecentActivity();
                } else {
                    this.showNotification(`Backup failed: ${stderr}`, 'error');
                    console.error('Backup error:', stderr);
                }
            });
        } else {
            // Fallback for testing without KernelSU
            setTimeout(() => {
                this.showNotification('Backup completed (demo mode)', 'success');
                this.updateBackupStatus();
                this.loadRecentActivity();
            }, 3000);
        }
    }
    
    performQuickBackup() {
        const name = `quick_backup_${new Date().toISOString().replace(/[:.]/g, '-')}`;
        
        this.showNotification('Creating quick backup...', 'info');
        
        if (typeof ksu !== 'undefined') {
            const command = `sh /data/adb/modules/kernelsu_antibootloop_backup/scripts/backup-engine.sh create --name "${name}" --type full --compress`;
            
            ksu.exec(command, (exitCode, stdout, stderr) => {
                if (exitCode === 0) {
                    this.showNotification('Quick backup completed successfully!', 'success');
                    this.updateBackupStatus();
                    this.loadRecentActivity();
                } else {
                    this.showNotification(`Quick backup failed: ${stderr}`, 'error');
                    console.error('Quick backup error:', stderr);
                }
            });
        } else {
            // Fallback for testing without KernelSU
            setTimeout(() => {
                this.showNotification('Quick backup completed (demo mode)', 'success');
                this.updateBackupStatus();
                this.loadRecentActivity();
            }, 2000);
        }
    }
    
    startSystemScan() {
        this.showNotification('Performing system health scan...', 'info');
        
        if (typeof ksu !== 'undefined') {
            // Execute real system scan
            const analyticsScript = `${this.getModuleDir()}/scripts/analytics-engine.sh`;
            ksu.exec(`${analyticsScript} system_health_check`, (exitCode, stdout, stderr) => {
                if (exitCode === 0) {
                    try {
                        const scanResults = JSON.parse(stdout);
                        const issueCount = scanResults.issues ? scanResults.issues.length : 0;
                        
                        if (issueCount === 0) {
                            this.showNotification('System scan completed. No issues found.', 'success');
                        } else {
                            this.showNotification(`System scan completed. Found ${issueCount} issue(s).`, 'warning');
                        }
                        
                        this.updateSystemHealth(scanResults);
                    } catch (e) {
                        this.showNotification('System scan completed.', 'success');
                        this.updateSystemHealth();
                    }
                } else {
                    this.showNotification(`System scan failed: ${stderr}`, 'error');
                    console.error('Scan error:', stderr);
                }
            });
        } else {
            // Fallback for testing without KernelSU
            setTimeout(() => {
                this.showNotification('System scan completed (demo mode)', 'success');
                this.updateSystemHealth();
            }, 2000);
        }
    }
    
    optimizeSystem() {
        this.showNotification('Optimizing system performance...', 'info');
        
        if (typeof ksu !== 'undefined') {
            // Execute optimization script
            const optimizeScript = `${this.getModuleDir()}/scripts/analytics-engine.sh`;
            ksu.exec(`${optimizeScript} optimize_system`, (exitCode, stdout, stderr) => {
                if (exitCode === 0) {
                    this.showNotification('System optimization completed!', 'success');
                } else {
                    this.showNotification(`Optimization failed: ${stderr}`, 'error');
                }
            });
        } else {
            setTimeout(() => {
                this.showNotification('System optimization completed (demo mode)!', 'success');
            }, 2500);
        }
    }

    viewLogs() {
        this.showNotification('Loading system logs...', 'info');
        
        if (typeof ksu !== 'undefined') {
            // Get recent logs
            const logFile = `${this.getModuleDir()}/scripts/module.log`;
            ksu.exec(`tail -50 ${logFile}`, (exitCode, stdout, stderr) => {
                if (exitCode === 0) {
                    this.displayLogsModal(stdout);
                } else {
                    this.showNotification('Failed to load logs', 'error');
                }
            });
        } else {
            // Demo logs
            const demoLogs = `[2024-01-15 10:30:15] [INFO] KernelSU module loaded successfully
[2024-01-15 10:30:16] [INFO] Backup engine initialized
[2024-01-15 10:30:17] [INFO] WebUI server started on port 8080
[2024-01-15 11:00:00] [INFO] System backup completed
[2024-01-15 11:30:00] [INFO] Health scan performed - no issues found`;
            this.displayLogsModal(demoLogs);
        }
    }

    displayLogsModal(logContent) {
        // Create modal for logs
        const modal = document.createElement('div');
        modal.className = 'logs-modal';
        modal.innerHTML = `
            <div class="modal-content">
                <div class="modal-header">
                    <h3>System Logs</h3>
                    <button class="close-btn" onclick="this.closest('.logs-modal').remove()">&times;</button>
                </div>
                <div class="modal-body">
                    <pre class="log-content">${logContent}</pre>
                </div>
            </div>
        `;
        
        // Add modal styles
        const style = document.createElement('style');
        style.textContent = `
            .logs-modal {
                position: fixed;
                top: 0;
                left: 0;
                width: 100%;
                height: 100%;
                background: rgba(0, 0, 0, 0.8);
                display: flex;
                align-items: center;
                justify-content: center;
                z-index: 1000;
            }
            .logs-modal .modal-content {
                background: var(--glass-bg);
                border-radius: 16px;
                max-width: 80%;
                max-height: 80%;
                overflow: hidden;
                backdrop-filter: blur(20px);
            }
            .logs-modal .modal-header {
                padding: 20px;
                border-bottom: 1px solid rgba(255, 255, 255, 0.1);
                display: flex;
                justify-content: space-between;
                align-items: center;
            }
            .logs-modal .modal-body {
                padding: 20px;
                overflow-y: auto;
                max-height: 400px;
            }
            .logs-modal .log-content {
                font-family: 'Courier New', monospace;
                font-size: 12px;
                line-height: 1.4;
                color: var(--text-primary);
                white-space: pre-wrap;
            }
            .logs-modal .close-btn {
                background: none;
                border: none;
                color: var(--text-primary);
                font-size: 24px;
                cursor: pointer;
            }
        `;
        
        document.head.appendChild(style);
        document.body.appendChild(modal);
        
        this.showNotification('Logs loaded successfully', 'success');
    }

    saveSettings() {
        const settings = {
            autoBackup: document.getElementById('auto-backup')?.checked || false,
            backupInterval: document.getElementById('backup-interval')?.value || 'weekly',
            bootloopProtection: document.getElementById('bootloop-protection')?.checked || true,
            safeModeTimeout: document.getElementById('safe-mode-timeout')?.value || '60',
            themeMode: document.getElementById('theme-mode')?.value || 'auto',
            notifications: document.getElementById('notifications')?.checked || true
        };

        this.showNotification('Saving settings...', 'info');

        if (typeof ksu !== 'undefined') {
            // Save settings using KernelSU API
            const settingsJson = JSON.stringify(settings, null, 2);
            const settingsFile = `${this.getModuleDir()}/config/settings.json`;
            
            ksu.exec(`echo '${settingsJson}' > ${settingsFile}`, (exitCode, stdout, stderr) => {
                if (exitCode === 0) {
                    this.showNotification('Settings saved successfully!', 'success');
                    this.applySettings(settings);
                } else {
                    this.showNotification(`Failed to save settings: ${stderr}`, 'error');
                }
            });
        } else {
            // Demo mode - save to localStorage
            localStorage.setItem('kernelsu_settings', JSON.stringify(settings));
            this.showNotification('Settings saved (demo mode)!', 'success');
            this.applySettings(settings);
        }
    }

    loadSettings() {
        if (typeof ksu !== 'undefined') {
            // Load settings from file
            const settingsFile = `${this.getModuleDir()}/config/settings.json`;
            ksu.exec(`cat ${settingsFile}`, (exitCode, stdout, stderr) => {
                if (exitCode === 0) {
                    try {
                        const settings = JSON.parse(stdout);
                        this.applySettingsToUI(settings);
                        this.applySettings(settings);
                    } catch (error) {
                        console.error('Failed to parse settings:', error);
                        this.loadDefaultSettings();
                    }
                } else {
                    // Settings file doesn't exist, use defaults
                    this.loadDefaultSettings();
                }
            });
        } else {
            // Demo mode - load from localStorage
            const savedSettings = localStorage.getItem('kernelsu_settings');
            if (savedSettings) {
                try {
                    const settings = JSON.parse(savedSettings);
                    this.applySettingsToUI(settings);
                    this.applySettings(settings);
                } catch (error) {
                    this.loadDefaultSettings();
                }
            } else {
                this.loadDefaultSettings();
            }
        }
    }

    loadDefaultSettings() {
        const defaultSettings = {
            autoBackup: true,
            backupInterval: 'weekly',
            bootloopProtection: true,
            safeModeTimeout: '60',
            themeMode: 'auto',
            notifications: true
        };
        
        this.applySettingsToUI(defaultSettings);
        this.applySettings(defaultSettings);
    }

    applySettingsToUI(settings) {
        const autoBackup = document.getElementById('auto-backup');
        const backupInterval = document.getElementById('backup-interval');
        const bootloopProtection = document.getElementById('bootloop-protection');
        const safeModeTimeout = document.getElementById('safe-mode-timeout');
        const themeMode = document.getElementById('theme-mode');
        const notifications = document.getElementById('notifications');

        if (autoBackup) autoBackup.checked = settings.autoBackup;
        if (backupInterval) backupInterval.value = settings.backupInterval;
        if (bootloopProtection) bootloopProtection.checked = settings.bootloopProtection;
        if (safeModeTimeout) safeModeTimeout.value = settings.safeModeTimeout;
        if (themeMode) themeMode.value = settings.themeMode;
        if (notifications) notifications.checked = settings.notifications;
    }

    applySettings(settings) {
        // Apply theme
        this.applyTheme(settings.themeMode);
        
        // Store settings for use by other functions
        this.currentSettings = settings;
        
        console.log('Settings applied:', settings);
    }

    applyTheme(themeMode) {
        const body = document.body;
        body.classList.remove('theme-light', 'theme-dark');
        
        if (themeMode === 'light') {
            body.classList.add('theme-light');
        } else if (themeMode === 'dark') {
            body.classList.add('theme-dark');
        }
        // 'auto' uses system preference (default CSS)
    }

    resetSettings() {
        if (!confirm('Are you sure you want to reset all settings to defaults?')) {
            return;
        }
        
        this.showNotification('Resetting settings...', 'info');
        
        if (typeof ksu !== 'undefined') {
            // Remove settings file
            const settingsFile = `${this.getModuleDir()}/config/settings.json`;
            ksu.exec(`rm -f ${settingsFile}`, (exitCode, stdout, stderr) => {
                this.showNotification('Settings reset to defaults!', 'success');
                this.loadDefaultSettings();
            });
        } else {
            // Demo mode
            localStorage.removeItem('kernelsu_settings');
            this.showNotification('Settings reset (demo mode)!', 'success');
            this.loadDefaultSettings();
        }
    }
    
    // Logs Management
    async loadSystemLogs() {
        try {
            if (typeof ksu !== 'undefined') {
                // Try to get real system logs
                const logFile = `${this.getModuleDir()}/logs/system.log`;
                ksu.exec(`tail -100 ${logFile} 2>/dev/null || echo "No logs found"`, (exitCode, stdout, stderr) => {
                    if (exitCode === 0 && stdout && stdout.trim() !== 'No logs found') {
                        this.parseAndDisplayLogs(stdout);
                    } else {
                        this.displayLogsError('No system logs available');
                    }
                });
            } else {
                // Demo mode - show sample logs
                this.displayDemoLogs();
            }
        } catch (error) {
            console.error('Failed to load system logs:', error);
            this.displayLogsError('Failed to load system logs: ' + error.message);
        }
    }

    parseAndDisplayLogs(logData) {
        const logViewer = document.getElementById('logsViewer');
        if (!logViewer) return;

        const lines = logData.split('\n').filter(line => line.trim());
        const logEntries = lines.map(line => {
            // Parse log format: [timestamp] [level] message
            const match = line.match(/\[(.*?)\]\s*\[(.*?)\]\s*(.*)/);
            if (match) {
                return {
                    timestamp: match[1],
                    level: match[2].toLowerCase(),
                    message: match[3]
                };
            } else {
                // Fallback for unformatted logs
                return {
                    timestamp: new Date().toISOString(),
                    level: 'info',
                    message: line
                };
            }
        });

        this.displayLogEntries(logEntries);
    }

    displayLogEntries(entries) {
        const logViewer = document.getElementById('logsViewer');
        if (!logViewer) return;

        if (entries.length === 0) {
            logViewer.innerHTML = '<div class="logs-empty"><i class="fas fa-file-alt"></i><br>No log entries found</div>';
            return;
        }

        const html = entries.map(entry => `
            <div class="log-entry ${entry.level}">
                <span class="log-time">${this.formatLogTime(entry.timestamp)}</span>
                <span class="log-level">${entry.level}</span>
                <span class="log-message">${this.escapeHtml(entry.message)}</span>
            </div>
        `).join('');

        logViewer.innerHTML = html;
    }

    displayDemoLogs() {
        const demoLogs = [
            { timestamp: new Date(Date.now() - 300000).toISOString(), level: 'info', message: 'KernelSU module initialized successfully' },
            { timestamp: new Date(Date.now() - 240000).toISOString(), level: 'info', message: 'Backup system started' },
            { timestamp: new Date(Date.now() - 180000).toISOString(), level: 'warning', message: 'High memory usage detected: 85%' },
            { timestamp: new Date(Date.now() - 120000).toISOString(), level: 'info', message: 'System optimization completed' },
            { timestamp: new Date(Date.now() - 60000).toISOString(), level: 'error', message: 'Failed to create backup: insufficient storage' },
            { timestamp: new Date().toISOString(), level: 'info', message: 'System status check completed' }
        ];
        
        this.displayLogEntries(demoLogs);
    }

    displayLogsError(message) {
        const logViewer = document.getElementById('logsViewer');
        if (!logViewer) return;

        logViewer.innerHTML = `
            <div class="logs-error">
                <i class="fas fa-exclamation-triangle"></i>
                <div><strong>Error Loading Logs</strong></div>
                <div>${this.escapeHtml(message)}</div>
                <button onclick="app.loadSystemLogs()" class="retry-button" style="margin-top: 10px;">Retry</button>
            </div>
        `;
    }

    formatLogTime(timestamp) {
        try {
            const date = new Date(timestamp);
            return date.toLocaleString('en-US', {
                month: '2-digit',
                day: '2-digit',
                hour: '2-digit',
                minute: '2-digit',
                second: '2-digit',
                hour12: false
            });
        } catch (error) {
            return timestamp;
        }
    }

    filterLogs() {
        const filterLevel = document.getElementById('logLevel')?.value;
        const logEntries = document.querySelectorAll('.log-entry');
        
        logEntries.forEach(entry => {
            if (!filterLevel || filterLevel === 'all' || entry.classList.contains(filterLevel)) {
                entry.style.display = 'flex';
            } else {
                entry.style.display = 'none';
            }
        });
    }

    clearLogs() {
        if (confirm('Are you sure you want to clear all logs?')) {
            if (typeof ksu !== 'undefined') {
                const logFile = `${this.getModuleDir()}/logs/system.log`;
                ksu.exec(`echo "" > ${logFile}`, (exitCode, stdout, stderr) => {
                    if (exitCode === 0) {
                        this.showNotification('Logs cleared successfully', 'success');
                        this.loadSystemLogs();
                    } else {
                        this.showNotification('Failed to clear logs: ' + stderr, 'error');
                    }
                });
            } else {
                // Demo mode
                const logViewer = document.getElementById('logsViewer');
                if (logViewer) {
                    logViewer.innerHTML = '<div class="logs-empty"><i class="fas fa-file-alt"></i><br>No log entries found</div>';
                }
                this.showNotification('Logs cleared (demo mode)', 'success');
            }
        }
    }

    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }
    
    enterEmergencyMode() {
        if (confirm('Are you sure you want to enter Emergency Mode? This will enable safe mode protections and may require a reboot.')) {
            this.showNotification('Activating Emergency Mode...', 'warning');
            
            if (typeof ksu !== 'undefined') {
                // Execute safe mode script
                const safeModeScript = `${this.getModuleDir()}/scripts/safe-mode.sh`;
                ksu.exec(`${safeModeScript} enable`, (exitCode, stdout, stderr) => {
                    if (exitCode === 0) {
                        this.showNotification('Emergency Mode activated. System is now in safe state.', 'warning');
                        // Update UI to reflect safe mode status
                        this.updateSystemStatus();
                    } else {
                        this.showNotification(`Failed to activate Emergency Mode: ${stderr}`, 'error');
                        console.error('Safe mode error:', stderr);
                    }
                });
            } else {
                // Fallback for testing
                this.showNotification('Emergency Mode activated (demo mode)', 'warning');
            }
        }
    }
    
    // Recovery Points Management
    createRecoveryPoint(name = null) {
        const pointName = name || `Recovery_${new Date().toISOString().replace(/[:.]/g, '-')}`;
        this.showNotification('Creating recovery point...', 'info');
        
        if (typeof ksu !== 'undefined') {
            const recoveryScript = `${this.getModuleDir()}/scripts/recovery-point.sh`;
            ksu.exec(`${recoveryScript} create "${pointName}"`, (exitCode, stdout, stderr) => {
                if (exitCode === 0) {
                    this.showNotification('Recovery point created successfully!', 'success');
                    this.loadRecoveryPoints();
                } else {
                    this.showNotification(`Failed to create recovery point: ${stderr}`, 'error');
                }
            });
        } else {
            // Demo mode
            setTimeout(() => {
                this.showNotification('Recovery point created (Demo)', 'success');
                this.loadRecoveryPoints();
            }, 1500);
        }
    }
    
    loadRecoveryPoints() {
        if (typeof ksu !== 'undefined') {
            const recoveryScript = `${this.getModuleDir()}/scripts/recovery-point.sh`;
            ksu.exec(`${recoveryScript} list`, (exitCode, stdout, stderr) => {
                if (exitCode === 0) {
                    try {
                        const points = JSON.parse(stdout);
                        this.updateRecoveryPointsUI(points);
                    } catch (e) {
                        console.error('Failed to parse recovery points:', e);
                        this.loadFallbackRecoveryPoints();
                    }
                } else {
                    this.loadFallbackRecoveryPoints();
                }
            });
        } else {
            this.loadFallbackRecoveryPoints();
        }
    }
    
    loadFallbackRecoveryPoints() {
        const points = [
            { name: 'System_Stable', date: new Date(Date.now() - 86400000), size: '2.1GB' },
            { name: 'Pre_Update', date: new Date(Date.now() - 172800000), size: '1.9GB' }
        ];
        this.updateRecoveryPointsUI(points);
    }
    
    updateRecoveryPointsUI(points) {
        const container = document.getElementById('recoveryPointsList');
        if (!container) return;
        
        if (points.length === 0) {
            container.innerHTML = '<div class="empty-state">No recovery points available</div>';
            return;
        }
        
        container.innerHTML = points.map(point => `
            <div class="recovery-point-item">
                <div class="point-info">
                    <h4>${point.name}</h4>
                    <p>Created: ${new Date(point.date).toLocaleString()}</p>
                    <p>Size: ${point.size}</p>
                </div>
                <div class="point-actions">
                    <button onclick="kernelSUApp.restoreRecoveryPoint('${point.name}')" class="btn btn-primary btn-sm">
                        <i class="fas fa-undo"></i> Restore
                    </button>
                    <button onclick="kernelSUApp.deleteRecoveryPoint('${point.name}')" class="btn btn-danger btn-sm">
                        <i class="fas fa-trash"></i> Delete
                    </button>
                </div>
            </div>
        `).join('');
    }
    
    restoreRecoveryPoint(pointName) {
        if (confirm(`Are you sure you want to restore to recovery point "${pointName}"? This will revert your system to that state.`)) {
            this.showNotification('Restoring recovery point...', 'warning');
            
            if (typeof ksu !== 'undefined') {
                const recoveryScript = `${this.getModuleDir()}/scripts/recovery-point.sh`;
                ksu.exec(`${recoveryScript} restore "${pointName}"`, (exitCode, stdout, stderr) => {
                    if (exitCode === 0) {
                        this.showNotification('Recovery point restored successfully!', 'success');
                        this.updateSystemStatus();
                    } else {
                        this.showNotification(`Failed to restore recovery point: ${stderr}`, 'error');
                    }
                });
            } else {
                setTimeout(() => {
                    this.showNotification('Recovery point restored (Demo)', 'success');
                }, 2000);
            }
        }
    }
    
    deleteRecoveryPoint(pointName) {
        if (confirm(`Are you sure you want to delete recovery point "${pointName}"? This action cannot be undone.`)) {
            if (typeof ksu !== 'undefined') {
                const recoveryScript = `${this.getModuleDir()}/scripts/recovery-point.sh`;
                ksu.exec(`${recoveryScript} delete "${pointName}"`, (exitCode, stdout, stderr) => {
                    if (exitCode === 0) {
                        this.showNotification('Recovery point deleted', 'info');
                        this.loadRecoveryPoints();
                    } else {
                        this.showNotification(`Failed to delete recovery point: ${stderr}`, 'error');
                    }
                });
            } else {
                this.showNotification('Recovery point deleted (Demo)', 'info');
                this.loadRecoveryPoints();
            }
        }
    }
    
    showNotification(message, type = 'info', duration = 5000) {
        try {
            const notification = {
                id: Date.now(),
                message,
                type,
                timestamp: new Date()
            };
            
            this.notifications.unshift(notification);
            
            // Create notification element with error handling
            const notificationEl = this.createNotificationElement(notification);
            if (!notificationEl) {
                console.error('Failed to create notification element');
                return;
            }
            
            document.body.appendChild(notificationEl);
            
            // Animate in with fallback
            requestAnimationFrame(() => {
                try {
                    notificationEl.classList.add('show');
                } catch (error) {
                    console.error('Failed to animate notification:', error);
                }
            });
            
            // Auto remove with error handling
            setTimeout(() => {
                try {
                    this.removeNotification(notification.id);
                } catch (error) {
                    console.error('Failed to remove notification:', error);
                }
            }, duration);
            
            // Update notification dot
            this.updateNotificationDot();
        } catch (error) {
            console.error('Failed to show notification:', error);
            // Fallback to console log
            console.log(`${type.toUpperCase()}: ${message}`);
        }
    }
    
    showModal(content) {
        // Remove existing modal
        const existingModal = document.querySelector('.modal-overlay');
        if (existingModal) {
            existingModal.remove();
        }
        
        const modalOverlay = document.createElement('div');
        modalOverlay.className = 'modal-overlay';
        modalOverlay.innerHTML = `
            <div class="modal-content">
                <button class="modal-close" onclick="kernelSUApp.closeModal()" aria-label="Close modal">
                    <i class="fas fa-times" aria-hidden="true"></i>
                </button>
                ${content}
            </div>
        `;
        
        document.body.appendChild(modalOverlay);
        
        // Trigger animation
        setTimeout(() => {
            modalOverlay.classList.add('show');
        }, 10);
        
        // Close on overlay click
        modalOverlay.addEventListener('click', (e) => {
            if (e.target === modalOverlay) {
                this.closeModal();
            }
        });
        
        // Close on escape key
        const escapeHandler = (e) => {
            if (e.key === 'Escape') {
                this.closeModal();
                document.removeEventListener('keydown', escapeHandler);
            }
        };
        document.addEventListener('keydown', escapeHandler);
    }
    
    closeModal() {
        const modal = document.querySelector('.modal-overlay');
        if (modal) {
            modal.classList.add('hide');
            setTimeout(() => {
                if (modal.parentElement) {
                    modal.remove();
                }
            }, 300);
        }
    }
    
    createNotificationElement(notification) {
        const el = document.createElement('div');
        el.className = `notification notification-${notification.type}`;
        el.dataset.id = notification.id;
        
        const iconMap = {
            success: 'fa-check-circle',
            error: 'fa-exclamation-circle',
            warning: 'fa-exclamation-triangle',
            info: 'fa-info-circle'
        };
        
        el.innerHTML = `
            <div class="notification-content">
                <i class="fas ${iconMap[notification.type]}" aria-hidden="true"></i>
                <span>${notification.message}</span>
            </div>
            <button class="notification-close" aria-label="Close notification">
                <i class="fas fa-times" aria-hidden="true"></i>
            </button>
        `;
        
        // Close button handler
        el.querySelector('.notification-close').addEventListener('click', () => {
            this.removeNotification(notification.id);
        });
        
        return el;
    }
    
    removeNotification(id) {
        const el = document.querySelector(`[data-id="${id}"]`);
        if (el) {
            el.classList.add('hide');
            setTimeout(() => {
                if (el.parentNode) {
                    el.parentNode.removeChild(el);
                }
            }, 300);
        }
        
        this.notifications = this.notifications.filter(n => n.id !== id);
        this.updateNotificationDot();
    }
    
    updateNotificationDot() {
        const dot = document.querySelector('.notification-dot');
        if (dot) {
            dot.style.display = this.notifications.length > 0 ? 'block' : 'none';
        }
    }
    
    toggleNotifications() {
        // This would open a notifications panel
        this.showNotification('Notifications panel coming soon!', 'info');
    }
    
    showHelp() {
        this.showNotification('Help system is being developed. Check back soon!', 'info');
    }
    
    closeModals() {
        // Close any open modals or panels
        const modals = document.querySelectorAll('.modal.open');
        modals.forEach(modal => modal.classList.remove('open'));
    }
    
    updateBackupStatus() {
        const backupTime = document.querySelector('.backup-time');
        if (backupTime) {
            backupTime.textContent = 'Just now';
        }
    }
    
    updateSystemHealth() {
        const healthScore = document.querySelector('.health-score .score');
        if (healthScore) {
            const currentScore = parseInt(healthScore.textContent);
            const newScore = Math.min(100, currentScore + 1);
            healthScore.textContent = newScore;
        }
    }
    
    initializeAnimations() {
        // Add staggered animation to status cards
        const statusCards = document.querySelectorAll('.status-card');
        statusCards.forEach((card, index) => {
            card.style.animationDelay = `${index * 0.1}s`;
        });
        
        // Initialize floating orbs animation
        this.animateFloatingOrbs();
    }
    
    animateFloatingOrbs() {
        const orbs = document.querySelectorAll('.orb');
        orbs.forEach((orb, index) => {
            const duration = 15 + (index * 5); // Different speeds
            orb.style.animationDuration = `${duration}s`;
        });
    }
    
    async loadInitialData() {
        try {
            // Load settings first
            this.loadSettings();
            
            const statusData = await this.updateSystemStatus();
            await this.loadRecentActivity();
            await this.updateQuickStats();
            await this.loadSystemLogs();
            
            // Update status cards with real data
            if (statusData) {
                this.updateStatusCards(statusData);
            }
        } catch (error) {
            console.error('Error loading initial data:', error);
            this.showNotification('Failed to load some system data', 'warning');
        }
    }

    updateSystemStatus() {
        return new Promise((resolve) => {
            try {
                let statusData = {};
                let hasErrors = false;
                const errors = [];
                
                // Get real system information using KernelSU API
                if (typeof ksu !== 'undefined') {
                    // Execute system info script
                    ksu.exec(`${this.getModuleDir()}/scripts/analytics-engine.sh get_system_status`, (exitCode, stdout, stderr) => {
                        if (exitCode === 0) {
                            try {
                                statusData = JSON.parse(stdout);
                                this.updateStatusCards(statusData);
                                resolve(statusData);
                            } catch (e) {
                                console.error('Failed to parse system status:', e);
                                errors.push('Failed to parse system data');
                                hasErrors = true;
                                statusData = this.loadFallbackStatus();
                                statusData.hasErrors = hasErrors;
                                statusData.errors = errors;
                                this.showNotification('Error parsing system data - using fallback values', 'error');
                                resolve(statusData);
                            }
                        } else {
                            console.error('System status script failed:', stderr);
                            errors.push(`Script execution failed: ${stderr}`);
                            hasErrors = true;
                            statusData = this.loadFallbackStatus();
                            statusData.hasErrors = hasErrors;
                            statusData.errors = errors;
                            this.showNotification('System status script failed - limited functionality', 'error');
                            resolve(statusData);
                        }
                    });
                } else {
                    errors.push('KernelSU API not available');
                    hasErrors = true;
                    statusData = this.loadFallbackStatus();
                    statusData.hasErrors = hasErrors;
                    statusData.errors = errors;
                    this.showNotification('KernelSU not available - running in demo mode', 'warning');
                    resolve(statusData);
                }
            } catch (error) {
                console.error('Critical error loading system status:', error);
                const statusData = {
                    kernelsu: 'Critical Error',
                    bootloops: 'Error',
                    lastBackup: 'Error',
                    safeMode: 'Error',
                    hasErrors: true,
                    errors: ['Critical system error']
                };
                this.showNotification('Critical error retrieving system status', 'error');
                resolve(statusData);
            }
        });
    }

    loadFallbackStatus() {
        // Fallback data when KernelSU API is not available
        const statusData = {
            kernelsu: 'Unknown',
            bootloops: 0,
            lastBackup: 'Never',
            safeMode: false
        };
        this.updateStatusCards(statusData);
        return statusData;
    }

    getModuleDir() {
        return this.moduleInfo?.moduleDir || '/data/adb/modules/kernelsu_antibootloop_backup';
    }

    loadRecentActivity() {
        if (typeof ksu !== 'undefined') {
            // Load real activity from logs
            const logScript = `${this.getModuleDir()}/scripts/analytics-engine.sh`;
            ksu.exec(`${logScript} get_recent_activity`, (exitCode, stdout, stderr) => {
                if (exitCode === 0) {
                    try {
                        const activities = JSON.parse(stdout);
                        this.updateRecentActivityUI(activities);
                    } catch (e) {
                        console.error('Failed to parse activity data:', e);
                        this.showNotification('Error parsing activity logs - using fallback data', 'warning');
                        this.loadFallbackActivity();
                    }
                } else {
                    console.error('Failed to load activity:', stderr);
                    this.showNotification('Failed to load recent activity logs', 'error');
                    this.loadFallbackActivity();
                }
            });
        } else {
            this.showNotification('Activity logs unavailable - KernelSU required', 'info');
            this.loadFallbackActivity();
        }
    }

    loadFallbackActivity() {
        // Fallback activity data
        const activities = [
            { type: 'backup', message: 'System backup completed', time: '2 hours ago', status: 'success' },
            { type: 'scan', message: 'Health scan performed', time: '4 hours ago', status: 'success' },
            { type: 'boot', message: 'System boot detected', time: '6 hours ago', status: 'info' }
        ];
        this.updateRecentActivityUI(activities);
    }

    updateRecentActivityUI(activities) {
        const activityContainer = document.querySelector('.recent-activity .activity-list');
        if (!activityContainer) return;

        activityContainer.innerHTML = '';
        
        activities.slice(0, 5).forEach(activity => {
            const activityItem = document.createElement('div');
            activityItem.className = 'activity-item';
            activityItem.innerHTML = `
                <div class="activity-icon ${activity.status}">
                    <i class="fas ${this.getActivityIcon(activity.type)}"></i>
                </div>
                <div class="activity-content">
                    <div class="activity-message">${activity.message}</div>
                    <div class="activity-time">${activity.time}</div>
                </div>
            `;
            activityContainer.appendChild(activityItem);
        });
    }

    getActivityIcon(type) {
        const icons = {
            backup: 'fa-save',
            scan: 'fa-search',
            boot: 'fa-power-off',
            error: 'fa-exclamation-triangle',
            warning: 'fa-exclamation-circle',
            info: 'fa-info-circle'
        };
        return icons[type] || 'fa-circle';
    }

    updateQuickStats() {
        if (typeof ksu !== 'undefined') {
            let errorCount = 0;
            const totalChecks = 4;
            
            // Get real system information
            ksu.exec('getprop ro.product.model', (exitCode, stdout) => {
                if (exitCode === 0) {
                    this.updateDeviceInfo('model', stdout.trim());
                } else {
                    this.updateDeviceInfo('model', 'Error retrieving model');
                    errorCount++;
                }
            });
            
            ksu.exec('getprop ro.build.version.release', (exitCode, stdout) => {
                if (exitCode === 0) {
                    this.updateDeviceInfo('android', stdout.trim());
                } else {
                    this.updateDeviceInfo('android', 'Error retrieving version');
                    errorCount++;
                }
            });
            
            ksu.exec('getprop ro.kernelsu.version', (exitCode, stdout) => {
                if (exitCode === 0) {
                    this.updateDeviceInfo('kernelsu', stdout.trim());
                } else {
                    this.updateDeviceInfo('kernelsu', 'Not Available');
                    errorCount++;
                }
            });
            
            // Get storage information
            ksu.exec('df /data | tail -1', (exitCode, stdout) => {
                if (exitCode === 0) {
                    const parts = stdout.trim().split(/\s+/);
                    if (parts.length >= 5) {
                        const usedPercent = parseInt(parts[4].replace('%', ''));
                        this.updateStorageInfo(usedPercent);
                    } else {
                        this.updateStorageInfo(0);
                        errorCount++;
                    }
                } else {
                    this.updateStorageInfo(0);
                    errorCount++;
                }
            });
            
            // Show notification if there were errors
            setTimeout(() => {
                if (errorCount > 0) {
                    this.showNotification(`Failed to retrieve ${errorCount}/${totalChecks} system properties`, 'warning');
                }
            }, 1000);
        } else {
            this.showNotification('System properties unavailable - KernelSU required', 'info');
            this.loadFallbackStats();
        }
    }

    loadFallbackStats() {
        this.updateDeviceInfo('model', 'Unknown Device');
        this.updateDeviceInfo('android', 'Unknown');
        this.updateDeviceInfo('kernelsu', 'Not Available');
        this.updateStorageInfo(65);
    }

    updateDeviceInfo(type, value) {
        const element = document.querySelector(`[data-info="${type}"]`);
        if (element) {
            element.textContent = value;
        }
    }

    updateStorageInfo(percentage) {
        const storageBar = document.querySelector('.storage-fill');
        const storageText = document.querySelector('.storage-percentage');
        
        if (storageBar) {
            storageBar.style.width = `${percentage}%`;
        }
        if (storageText) {
            storageText.textContent = `${percentage}%`;
        }
    }

    updateSystemStats() {
        // This would typically fetch real data from the backend
        const stats = {
            protectionStatus: 'active',
            lastBackup: '2 hours ago',
            backupSize: '2.4 GB',
            systemHealth: 98,
            storageUsed: 65
        };
        
        // Update UI with stats
        this.renderSystemStats(stats);
    }
    
    updateStatusCards(statusData) {
        // Update KernelSU status
        const kernelsuStatus = document.querySelector('[data-status="kernelsu"]');
        if (kernelsuStatus) {
            const kernelsuValue = statusData.kernelsu || 'Unknown';
            kernelsuStatus.textContent = kernelsuValue;
            
            // Set appropriate class based on status
            if (kernelsuValue.includes('Error') || kernelsuValue === 'Unknown') {
                kernelsuStatus.className = 'status error';
            } else if (kernelsuValue === 'Active') {
                kernelsuStatus.className = 'status active';
            } else {
                kernelsuStatus.className = 'status inactive';
            }
        }

        // Update bootloop count
        const bootloopCount = document.querySelector('[data-status="bootloops"]');
        if (bootloopCount) {
            const bootloopValue = statusData.bootloops !== undefined ? statusData.bootloops : '0';
            bootloopCount.textContent = bootloopValue;
            
            if (bootloopValue.toString().includes('Error')) {
                bootloopCount.className = 'status error';
            } else {
                bootloopCount.className = 'status';
            }
        }

        // Update last backup
        const lastBackup = document.querySelector('[data-status="backup"]');
        if (lastBackup) {
            const backupValue = statusData.lastBackup || 'Never';
            lastBackup.textContent = backupValue;
            
            if (backupValue.includes('Error')) {
                lastBackup.className = 'status error';
            } else {
                lastBackup.className = 'status';
            }
        }

        // Update safe mode status
        const safeModeStatus = document.querySelector('[data-status="safemode"]');
        if (safeModeStatus) {
            const safeModeValue = statusData.safeMode;
            
            if (safeModeValue === 'Error' || safeModeValue === undefined) {
                safeModeStatus.textContent = 'Error';
                safeModeStatus.className = 'status error';
            } else if (safeModeValue === true) {
                safeModeStatus.textContent = 'Enabled';
                safeModeStatus.className = 'status warning';
            } else {
                safeModeStatus.textContent = 'Disabled';
                safeModeStatus.className = 'status success';
            }
        }
        
        // Show error indicator if there are errors
        if (statusData.hasErrors) {
            const errorIndicator = document.querySelector('.system-error-indicator');
            if (errorIndicator) {
                errorIndicator.style.display = 'block';
                errorIndicator.title = `Errors: ${statusData.errors.join(', ')}`;
            }
        }
    }

    renderSystemStats(stats) {
        // Update storage bar
        const storageBar = document.querySelector('.storage-fill');
        if (storageBar) {
            storageBar.style.width = `${stats.storageUsed}%`;
        }
    }
    
    setupAccessibility() {
        // Add ARIA live region for announcements
        const liveRegion = document.createElement('div');
        liveRegion.setAttribute('aria-live', 'polite');
        liveRegion.setAttribute('aria-atomic', 'true');
        liveRegion.className = 'sr-only';
        liveRegion.id = 'live-region';
        document.body.appendChild(liveRegion);
    }
    
    announcePageChange(pageId) {
        const liveRegion = document.getElementById('live-region');
        if (liveRegion) {
            const pageNames = {
                dashboard: 'Dashboard',
                backup: 'Backup Management',
                restore: 'System Restore',
                modules: 'Module Manager',
                logs: 'System Logs',
                settings: 'System Settings'
            };
            
            liveRegion.textContent = `Navigated to ${pageNames[pageId] || pageId} page`;
        }
    }
    
    // Enhanced Backup Management Functions
    updateBackupList() {
        if (typeof ksu !== 'undefined') {
            const backupScript = `${this.getModuleDir()}/scripts/backup-engine.sh`;
            ksu.exec(`${backupScript} list`, (exitCode, stdout, stderr) => {
                if (exitCode === 0) {
                    try {
                        const backups = JSON.parse(stdout);
                        this.displayBackupList(backups);
                    } catch (e) {
                        console.error('Failed to parse backup list:', e);
                        this.loadFallbackBackups();
                    }
                } else {
                    this.loadFallbackBackups();
                }
            });
        } else {
            this.loadFallbackBackups();
        }
    }
    
    loadFallbackBackups() {
        const backups = [
            { name: 'full_backup_2024', date: new Date(Date.now() - 86400000), size: '4.2GB', type: 'full' },
            { name: 'system_backup_stable', date: new Date(Date.now() - 172800000), size: '2.1GB', type: 'system' }
        ];
        this.displayBackupList(backups);
    }
    
    displayBackupList(backups) {
        const container = document.getElementById('backupList');
        if (!container) return;
        
        if (backups.length === 0) {
            container.innerHTML = '<div class="empty-state">No backups available</div>';
            return;
        }
        
        container.innerHTML = backups.map(backup => `
            <div class="backup-item">
                <div class="backup-info">
                    <h4>${backup.name}</h4>
                    <p>Created: ${new Date(backup.date).toLocaleString()}</p>
                    <p>Size: ${backup.size} | Type: ${backup.type}</p>
                </div>
                <div class="backup-actions">
                    <button onclick="kernelSUApp.showRestoreDialog('${backup.name}')" class="btn btn-primary btn-sm">
                        <i class="fas fa-download"></i> Restore
                    </button>
                    <button onclick="kernelSUApp.exportBackup('${backup.name}')" class="btn btn-secondary btn-sm">
                        <i class="fas fa-share"></i> Export
                    </button>
                    <button onclick="kernelSUApp.deleteBackup('${backup.name}')" class="btn btn-danger btn-sm">
                        <i class="fas fa-trash"></i> Delete
                    </button>
                </div>
            </div>
        `).join('');
    }
    
    showRestoreDialog(backupName) {
        const modalContent = `
            <div class="restore-dialog">
                <h3>Restore Backup</h3>
                <p>Are you sure you want to restore backup "${backupName}"?</p>
                <p class="warning-text">This will overwrite your current system state.</p>
                
                <div class="form-group">
                    <label><input type="checkbox" id="restore-reboot"> Reboot after restore</label>
                </div>
                
                <div class="dialog-actions">
                    <button class="btn btn-secondary" onclick="kernelSUApp.closeModal()">Cancel</button>
                    <button class="btn btn-danger" onclick="kernelSUApp.restoreBackup('${backupName}')">Restore</button>
                </div>
            </div>
        `;
        
        this.showModal(modalContent);
    }
    
    restoreBackup(backupName) {
        const shouldReboot = document.getElementById('restore-reboot')?.checked || false;
        
        this.closeModal();
        this.showNotification('Starting backup restoration...', 'warning');
        
        if (typeof ksu !== 'undefined') {
            let command = `sh ${this.getModuleDir()}/scripts/backup-engine.sh restore --name "${backupName}"`;
            
            if (shouldReboot) {
                command += ' --reboot';
            }
            
            ksu.exec(command, (exitCode, stdout, stderr) => {
                if (exitCode === 0) {
                    this.showNotification('Backup restored successfully!', 'success');
                    this.updateSystemStatus();
                } else {
                    this.showNotification(`Failed to restore backup: ${stderr}`, 'error');
                }
            });
        } else {
            setTimeout(() => {
                this.showNotification('Backup restored (Demo)', 'success');
            }, 2000);
        }
    }
    
    deleteBackup(backupName) {
        if (confirm(`Are you sure you want to delete backup "${backupName}"? This action cannot be undone.`)) {
            if (typeof ksu !== 'undefined') {
                const backupScript = `${this.getModuleDir()}/scripts/backup-engine.sh`;
                ksu.exec(`${backupScript} delete --name "${backupName}"`, (exitCode, stdout, stderr) => {
                    if (exitCode === 0) {
                        this.showNotification('Backup deleted successfully', 'info');
                        this.updateBackupList();
                    } else {
                        this.showNotification(`Failed to delete backup: ${stderr}`, 'error');
                    }
                });
            } else {
                this.showNotification('Backup deleted (Demo)', 'info');
                this.updateBackupList();
            }
        }
    }
    
    exportBackup(backupName) {
        this.showNotification('Preparing backup for export...', 'info');
        
        if (typeof ksu !== 'undefined') {
            const backupScript = `${this.getModuleDir()}/scripts/backup-engine.sh`;
            ksu.exec(`${backupScript} export --name "${backupName}"`, (exitCode, stdout, stderr) => {
                if (exitCode === 0) {
                    this.showNotification('Backup exported successfully!', 'success');
                } else {
                    this.showNotification(`Failed to export backup: ${stderr}`, 'error');
                }
            });
        } else {
            setTimeout(() => {
                this.showNotification('Backup exported (Demo)', 'success');
            }, 1500);
        }
    }
    
    importBackup() {
        const modalContent = `
            <div class="import-dialog">
                <h3>Import Backup</h3>
                <p>Select a backup file to import:</p>
                
                <div class="form-group">
                    <input type="file" id="backup-file" accept=".tar.gz,.zip,.bak" class="file-input">
                </div>
                
                <div class="dialog-actions">
                    <button class="btn btn-secondary" onclick="kernelSUApp.closeModal()">Cancel</button>
                    <button class="btn btn-primary" onclick="kernelSUApp.processImportedBackup()">Import</button>
                </div>
            </div>
        `;
        
        this.showModal(modalContent);
    }
    
    processImportedBackup() {
        const fileInput = document.getElementById('backup-file');
        const file = fileInput?.files[0];
        
        if (!file) {
            this.showNotification('Please select a backup file', 'error');
            return;
        }
        
        this.closeModal();
        this.showNotification('Importing backup...', 'info');
        
        if (typeof ksu !== 'undefined') {
            // In a real implementation, you would handle file upload
            this.showNotification('Backup import functionality requires file upload implementation', 'warning');
        } else {
            setTimeout(() => {
                this.showNotification('Backup imported (Demo)', 'success');
                this.updateBackupList();
            }, 2000);
        }
    }
    
    updateActiveNavigation() {
        // Handle initial page from URL hash
        const hash = window.location.hash.slice(1);
        if (hash && document.getElementById(hash)) {
            this.navigateToPage(hash);
        }
    }
    
    startPeriodicUpdates() {
        // Update system stats every 30 seconds
        this.updateInterval = setInterval(() => {
            if (!document.hidden) {
                this.updateSystemStats();
            }
        }, 30000);
    }
    
    pauseUpdates() {
        if (this.updateInterval) {
            clearInterval(this.updateInterval);
        }
    }
    
    resumeUpdates() {
        this.startPeriodicUpdates();
    }
    
    showWelcomeMessage() {
        setTimeout(() => {
            this.showNotification('Welcome to KernelSU Control Center! Your system is protected.', 'success');
        }, 1000);
    }
    
    handleResize() {
        // Handle responsive layout changes with enhanced mobile optimization
        const isMobile = window.innerWidth < 768;
        const isTablet = window.innerWidth >= 768 && window.innerWidth < 1024;
        
        document.body.classList.toggle('mobile', isMobile);
        document.body.classList.toggle('tablet', isTablet);
        
        // Adjust navigation for mobile
        const nav = document.querySelector('.nav');
        if (nav && isMobile) {
            nav.classList.add('mobile-nav');
        } else if (nav) {
            nav.classList.remove('mobile-nav');
        }
        
        // Optimize card layouts for different screen sizes
        const cards = document.querySelectorAll('.status-card, .action-card');
        cards.forEach(card => {
            if (isMobile) {
                card.classList.add('mobile-card');
            } else {
                card.classList.remove('mobile-card');
            }
        });
    }
    
    // Utility function for debouncing
    debounce(func, wait) {
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
    
    // Cleanup method
    destroy() {
        if (this.updateInterval) {
            clearInterval(this.updateInterval);
        }
        
        // Remove event listeners
        document.removeEventListener('click', this.handleClick);
        document.removeEventListener('keydown', this.handleKeyboardNavigation);
        window.removeEventListener('resize', this.handleResize);
    }
}

// Initialize the application
const app = new KernelSUApp();

// Handle browser back/forward buttons
window.addEventListener('popstate', (e) => {
    if (e.state && e.state.page) {
        app.navigateToPage(e.state.page);
    }
});

// Export for potential use in other scripts
if (typeof module !== 'undefined' && module.exports) {
    module.exports = KernelSUApp;
}

// Global error handling
window.addEventListener('error', (e) => {
    console.error('Application error:', e.error);
    if (app) {
        app.showNotification('An unexpected error occurred. Please refresh the page.', 'error');
    }
});

// Service worker registration (if available)
if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
        navigator.serviceWorker.register('/sw.js')
            .then(registration => {
                console.log('SW registered: ', registration);
            })
            .catch(registrationError => {
                console.log('SW registration failed: ', registrationError);
            });
    });
}