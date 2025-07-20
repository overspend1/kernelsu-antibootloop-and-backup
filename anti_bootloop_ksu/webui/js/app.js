/**
 * Advanced Anti-Bootloop KSU WebUI Application
 * Author: @overspend1/Wiktor
 */

class AntiBootloopWebUI {
    constructor() {
        this.baseUrl = window.location.origin;
        this.refreshInterval = null;
        this.currentTab = 'dashboard';
        this.init();
    }

    init() {
        this.setupEventListeners();
        this.loadInitialData();
        this.startAutoRefresh();
    }

    setupEventListeners() {
        // Tab navigation
        document.querySelectorAll('.nav-item').forEach(item => {
            item.addEventListener('click', (e) => {
                this.switchTab(e.target.getAttribute('data-tab'));
            });
        });

        // Window focus/blur for auto-refresh
        window.addEventListener('focus', () => this.startAutoRefresh());
        window.addEventListener('blur', () => this.stopAutoRefresh());
    }

    switchTab(tabName) {
        // Update navigation
        document.querySelectorAll('.nav-item').forEach(item => {
            item.classList.remove('active');
        });
        document.querySelector(`[data-tab="${tabName}"]`).classList.add('active');

        // Update content
        document.querySelectorAll('.tab-content').forEach(content => {
            content.classList.remove('active');
        });
        document.getElementById(tabName).classList.add('active');

        this.currentTab = tabName;

        // Load tab-specific data
        switch(tabName) {
            case 'dashboard':
                this.loadDashboardData();
                break;
            case 'backups':
                this.loadBackups();
                break;
            case 'config':
                this.loadConfig();
                break;
            case 'logs':
                this.loadLogs();
                break;
            case 'recovery':
                // Recovery tab doesn't need initial data loading
                break;
        }
    }

    async loadInitialData() {
        await this.loadDashboardData();
    }

    async loadDashboardData() {
        try {
            const [statusResponse, hardwareResponse] = await Promise.all([
                fetch(`${this.baseUrl}/api/status`),
                fetch(`${this.baseUrl}/api/hardware`)
            ]);

            if (statusResponse.ok && hardwareResponse.ok) {
                const statusData = await statusResponse.json();
                const hardwareData = await hardwareResponse.json();

                this.updateSystemStatus(statusData);
                this.updateHardwareStatus(hardwareData);
                this.updateConnectionStatus(true);
            } else {
                throw new Error('Failed to fetch data');
            }
        } catch (error) {
            console.error('Error loading dashboard data:', error);
            this.updateConnectionStatus(false);
        }
    }

    updateSystemStatus(data) {
        // Update system status values
        document.getElementById('bootCount').textContent = data.boot_count;
        document.getElementById('maxAttempts').textContent = data.max_attempts;
        document.getElementById('totalBoots').textContent = data.total_boots;
        document.getElementById('uptime').textContent = this.formatUptime(data.uptime);
        document.getElementById('deviceName').textContent = data.device;
        document.getElementById('androidVersion').textContent = data.android_version;
        document.getElementById('kernelVersion').textContent = data.kernel_version;
        document.getElementById('moduleVersion').textContent = data.module_version;

        // Update recovery state badge
        const recoveryStateElement = document.getElementById('recoveryState');
        recoveryStateElement.textContent = data.recovery_state;
        recoveryStateElement.className = `badge ${this.getRecoveryStateBadgeClass(data.recovery_state)}`;

        // Update safe mode badge
        const safeModeElement = document.getElementById('safeMode');
        safeModeElement.textContent = data.safe_mode ? 'Active' : 'Inactive';
        safeModeElement.className = `badge ${data.safe_mode ? 'warning' : 'success'}`;
    }

    updateHardwareStatus(data) {
        // CPU Temperature
        document.getElementById('cpuTemp').textContent = `${data.cpu_temperature}°C`;
        const cpuTempBar = document.getElementById('cpuTempBar');
        const cpuTempPercent = Math.min((data.cpu_temperature / data.monitoring.cpu_temp_threshold) * 100, 100);
        cpuTempBar.style.width = `${cpuTempPercent}%`;
        cpuTempBar.style.background = this.getTemperatureColor(data.cpu_temperature, data.monitoring.cpu_temp_threshold);

        // Available RAM
        document.getElementById('availableRam').textContent = `${data.available_ram_mb} MB`;
        const ramBar = document.getElementById('ramBar');
        const ramPercent = Math.min((data.available_ram_mb / 2000) * 100, 100); // Assume 2GB max for visualization
        ramBar.style.width = `${ramPercent}%`;
        ramBar.style.background = data.available_ram_mb < data.monitoring.min_free_ram ? '#e74c3c' : '#27ae60';

        // Storage Health
        document.getElementById('storageHealth').textContent = this.formatStorageHealth(data.storage_health);

        // Hardware Issues
        const hardwareIssuesElement = document.getElementById('hardwareIssues');
        if (data.hardware_issues && data.hardware_issues.trim() !== '') {
            hardwareIssuesElement.style.display = 'block';
            document.getElementById('hardwareIssuesText').textContent = data.hardware_issues;
        } else {
            hardwareIssuesElement.style.display = 'none';
        }
    }

    async loadBackups() {
        try {
            const response = await fetch(`${this.baseUrl}/api/backups`);
            if (response.ok) {
                const backups = await response.json();
                this.updateBackupsTable(backups);
            } else {
                throw new Error('Failed to load backups');
            }
        } catch (error) {
            console.error('Error loading backups:', error);
            this.showError('Failed to load backups');
        }
    }

    updateBackupsTable(backups) {
        const tbody = document.getElementById('backupsTable');
        
        if (backups.length === 0) {
            tbody.innerHTML = '<tr><td colspan="5" class="text-center">No backups found</td></tr>';
            return;
        }

        tbody.innerHTML = backups.map(backup => `
            <tr>
                <td>${backup.name}</td>
                <td>${this.formatFileSize(backup.size)}</td>
                <td>${this.formatDate(backup.created)}</td>
                <td>
                    <span class="badge ${backup.has_hash ? 'success' : 'warning'}">
                        ${backup.has_hash ? 'Verified' : 'No Hash'}
                    </span>
                </td>
                <td>
                    <button class="btn btn-info btn-sm" onclick="app.restoreBackup('${backup.name}')">
                        <i class="fas fa-undo"></i> Restore
                    </button>
                    <button class="btn btn-danger btn-sm" onclick="app.deleteBackup('${backup.name}')">
                        <i class="fas fa-trash"></i> Delete
                    </button>
                </td>
            </tr>
        `).join('');
    }

    async loadConfig() {
        try {
            const response = await fetch(`${this.baseUrl}/api/config`);
            if (response.ok) {
                const config = await response.json();
                this.updateConfigForm(config);
            } else {
                throw new Error('Failed to load configuration');
            }
        } catch (error) {
            console.error('Error loading config:', error);
            this.showError('Failed to load configuration');
        }
    }

    updateConfigForm(config) {
        // Recovery settings
        document.getElementById('maxBootAttempts').value = config.MAX_BOOT_ATTEMPTS || '3';
        document.getElementById('recoveryStrategy').value = config.RECOVERY_STRATEGY || 'progressive';
        document.getElementById('safeModeEnabled').checked = config.SAFE_MODE_ENABLED === 'true';

        // Hardware monitoring
        document.getElementById('monitorCpuTemp').checked = config.MONITOR_CPU_TEMP === 'true';
        document.getElementById('cpuTempThreshold').value = config.CPU_TEMP_THRESHOLD || '75';
        document.getElementById('monitorRam').checked = config.MONITOR_RAM === 'true';
        document.getElementById('minFreeRam').value = config.MIN_FREE_RAM || '200';

        // Backup settings
        document.getElementById('backupSlots').value = config.BACKUP_SLOTS || '3';
        document.getElementById('kernelIntegrityCheck').checked = config.KERNEL_INTEGRITY_CHECK === 'true';
    }

    async loadLogs() {
        const lines = document.getElementById('logLines').value;
        try {
            const response = await fetch(`${this.baseUrl}/api/logs?lines=${lines}`);
            if (response.ok) {
                const data = await response.json();
                document.getElementById('logContent').textContent = data.logs || 'No logs available';
            } else {
                throw new Error('Failed to load logs');
            }
        } catch (error) {
            console.error('Error loading logs:', error);
            document.getElementById('logContent').textContent = 'Error loading logs';
        }
    }

    async createBackup() {
        const name = prompt('Enter backup name (leave empty for auto-generated):');
        const description = prompt('Enter backup description (optional):');
        
        try {
            const params = new URLSearchParams();
            if (name) params.append('name', name);
            if (description) params.append('description', description);

            const response = await fetch(`${this.baseUrl}/api/backups`, {
                method: 'POST',
                body: params
            });

            if (response.ok) {
                this.showSuccess('Backup created successfully');
                this.loadBackups();
            } else {
                throw new Error('Failed to create backup');
            }
        } catch (error) {
            console.error('Error creating backup:', error);
            this.showError('Failed to create backup');
        }
    }

    async restoreBackup(backupName) {
        if (!confirm(`Are you sure you want to restore backup "${backupName}"? This will replace your current kernel.`)) {
            return;
        }

        try {
            const params = new URLSearchParams();
            params.append('backup', backupName);
            params.append('verify', 'true');

            const response = await fetch(`${this.baseUrl}/api/restore`, {
                method: 'POST',
                body: params
            });

            if (response.ok) {
                this.showSuccess('Backup restored successfully. System will reboot.');
            } else {
                throw new Error('Failed to restore backup');
            }
        } catch (error) {
            console.error('Error restoring backup:', error);
            this.showError('Failed to restore backup');
        }
    }

    async deleteBackup(backupName) {
        if (!confirm(`Are you sure you want to delete backup "${backupName}"? This action cannot be undone.`)) {
            return;
        }

        try {
            const response = await fetch(`${this.baseUrl}/api/backups`, {
                method: 'DELETE',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ name: backupName })
            });

            if (response.ok) {
                this.showSuccess('Backup deleted successfully');
                this.loadBackups();
            } else {
                throw new Error('Failed to delete backup');
            }
        } catch (error) {
            console.error('Error deleting backup:', error);
            this.showError('Failed to delete backup');
        }
    }

    async saveConfig() {
        const formData = new FormData();
        
        // Collect form data
        formData.append('MAX_BOOT_ATTEMPTS', document.getElementById('maxBootAttempts').value);
        formData.append('RECOVERY_STRATEGY', document.getElementById('recoveryStrategy').value);
        formData.append('SAFE_MODE_ENABLED', document.getElementById('safeModeEnabled').checked);
        formData.append('MONITOR_CPU_TEMP', document.getElementById('monitorCpuTemp').checked);
        formData.append('CPU_TEMP_THRESHOLD', document.getElementById('cpuTempThreshold').value);
        formData.append('MONITOR_RAM', document.getElementById('monitorRam').checked);
        formData.append('MIN_FREE_RAM', document.getElementById('minFreeRam').value);
        formData.append('BACKUP_SLOTS', document.getElementById('backupSlots').value);
        formData.append('KERNEL_INTEGRITY_CHECK', document.getElementById('kernelIntegrityCheck').checked);

        try {
            const response = await fetch(`${this.baseUrl}/api/config`, {
                method: 'POST',
                body: formData
            });

            if (response.ok) {
                this.showSuccess('Configuration saved successfully');
            } else {
                throw new Error('Failed to save configuration');
            }
        } catch (error) {
            console.error('Error saving config:', error);
            this.showError('Failed to save configuration');
        }
    }

    // Recovery functions
    async enableSafeMode() {
        if (!confirm('Enable safe mode? This will disable non-essential modules.')) return;
        await this.sendRecoveryCommand('enable_safe_mode');
    }

    async disableAllModules() {
        if (!confirm('Disable all modules? This will disable ALL KSU modules except this one.')) return;
        await this.sendRecoveryCommand('disable_all_modules');
    }

    async emergencyDisable() {
        if (!confirm('Emergency disable this module? The module will stop functioning until manually re-enabled.')) return;
        await this.sendRecoveryCommand('emergency_disable');
    }

    async resetBootCounter() {
        if (!confirm('Reset boot counter to 0?')) return;
        await this.sendRecoveryCommand('reset_boot_counter');
    }

    async resetRecoveryState() {
        if (!confirm('Reset recovery state to normal?')) return;
        await this.sendRecoveryCommand('reset_recovery_state');
    }

    async sendRecoveryCommand(command) {
        try {
            const response = await fetch(`${this.baseUrl}/api/recovery`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ command })
            });

            if (response.ok) {
                this.showSuccess('Command executed successfully');
                this.loadDashboardData();
            } else {
                throw new Error('Failed to execute command');
            }
        } catch (error) {
            console.error('Error executing recovery command:', error);
            this.showError('Failed to execute command');
        }
    }

    // Utility functions
    refreshData() {
        switch(this.currentTab) {
            case 'dashboard':
                this.loadDashboardData();
                break;
            case 'backups':
                this.loadBackups();
                break;
            case 'logs':
                this.loadLogs();
                break;
        }
    }

    startAutoRefresh() {
        this.stopAutoRefresh();
        this.refreshInterval = setInterval(() => {
            if (this.currentTab === 'dashboard') {
                this.loadDashboardData();
            }
        }, 5000); // Refresh every 5 seconds
    }

    stopAutoRefresh() {
        if (this.refreshInterval) {
            clearInterval(this.refreshInterval);
            this.refreshInterval = null;
        }
    }

    updateConnectionStatus(connected) {
        const statusElement = document.getElementById('connectionStatus');
        const icon = statusElement.querySelector('i');
        const text = statusElement.querySelector('span');

        if (connected) {
            icon.style.color = '#27ae60';
            text.textContent = 'Connected';
        } else {
            icon.style.color = '#e74c3c';
            text.textContent = 'Disconnected';
        }
    }

    // Helper functions
    formatUptime(seconds) {
        const days = Math.floor(seconds / 86400);
        const hours = Math.floor((seconds % 86400) / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        
        if (days > 0) return `${days}d ${hours}h ${minutes}m`;
        if (hours > 0) return `${hours}h ${minutes}m`;
        return `${minutes}m`;
    }

    formatFileSize(bytes) {
        const sizes = ['B', 'KB', 'MB', 'GB'];
        if (bytes === 0) return '0 B';
        const i = Math.floor(Math.log(bytes) / Math.log(1024));
        return `${(bytes / Math.pow(1024, i)).toFixed(1)} ${sizes[i]}`;
    }

    formatDate(dateString) {
        return new Date(dateString).toLocaleString();
    }

    formatStorageHealth(health) {
        switch(health) {
            case '0x01': return 'Good';
            case 'unknown': return 'Unknown';
            default: return health;
        }
    }

    getRecoveryStateBadgeClass(state) {
        switch(state) {
            case 'normal': return 'success';
            case 'monitoring': return 'info';
            case 'safe_mode': return 'warning';
            case 'emergency': return 'danger';
            default: return 'secondary';
        }
    }

    getTemperatureColor(temp, threshold) {
        if (temp < threshold * 0.7) return '#27ae60';
        if (temp < threshold * 0.9) return '#f39c12';
        return '#e74c3c';
    }

    // Modal functions
    showModal(title, body, footer = '') {
        document.getElementById('modalTitle').textContent = title;
        document.getElementById('modalBody').innerHTML = body;
        document.getElementById('modalFooter').innerHTML = footer;
        document.getElementById('modal').classList.add('show');
    }

    closeModal() {
        document.getElementById('modal').classList.remove('show');
    }

    showSuccess(message) {
        this.showNotification(message, 'success');
    }

    showError(message) {
        this.showNotification(message, 'error');
    }

    showNotification(message, type) {
        // Simple notification - could be enhanced with a proper notification system
        const alertClass = type === 'success' ? 'alert-success' : 'alert-danger';
        const icon = type === 'success' ? 'fa-check' : 'fa-exclamation-triangle';
        
        const notification = document.createElement('div');
        notification.className = `alert ${alertClass}`;
        notification.style.cssText = 'position: fixed; top: 20px; right: 20px; z-index: 1001; max-width: 300px;';
        notification.innerHTML = `<i class="fas ${icon}"></i> ${message}`;
        
        document.body.appendChild(notification);
        
        setTimeout(() => {
            notification.remove();
        }, 3000);
    }

    showAbout() {
        this.showModal(
            'About',
            `
            <div class="text-center">
                <i class="fas fa-shield-alt" style="font-size: 3rem; color: var(--primary-color); margin-bottom: 1rem;"></i>
                <h4>Advanced Anti-Bootloop KSU Module</h4>
                <p><strong>Version:</strong> 2.0</p>
                <p><strong>Author:</strong> @overspend1/Wiktor</p>
                <p><strong>Purpose:</strong> Advanced bootloop protection with intelligent recovery</p>
                <hr>
                <p class="text-muted">This module provides comprehensive protection against bootloops with progressive recovery strategies, hardware monitoring, and advanced backup management.</p>
            </div>
            `,
            '<button class="btn btn-primary" onclick="app.closeModal()">Close</button>'
        );
    }

    showHelp() {
        this.showModal(
            'Help & Documentation',
            `
            <div>
                <h5>Quick Help</h5>
                <ul>
                    <li><strong>Dashboard:</strong> View system status and hardware monitoring</li>
                    <li><strong>Backups:</strong> Manage kernel backups and restore points</li>
                    <li><strong>Configuration:</strong> Adjust module behavior and monitoring settings</li>
                    <li><strong>Logs:</strong> View detailed module activity logs</li>
                    <li><strong>Recovery:</strong> Emergency controls and recovery operations</li>
                </ul>
                
                <h5>Emergency Procedures</h5>
                <p>If the module malfunctions:</p>
                <ol>
                    <li>Use "Emergency Disable" in Recovery tab</li>
                    <li>Create disable file: <code>touch /data/local/tmp/disable_antibootloop</code></li>
                    <li>Disable via KernelSU Manager</li>
                </ol>
                
                <p class="text-muted mt-3">For detailed documentation, check the README.md file in the module directory.</p>
            </div>
            `,
            '<button class="btn btn-primary" onclick="app.closeModal()">Close</button>'
        );
    }
}

// Global functions for HTML onclick handlers
function refreshData() { app.refreshData(); }
function createBackup() { app.createBackup(); }
function saveConfig() { app.saveConfig(); }
function loadLogs() { app.loadLogs(); }
function enableSafeMode() { app.enableSafeMode(); }
function disableAllModules() { app.disableAllModules(); }
function emergencyDisable() { app.emergencyDisable(); }
function resetBootCounter() { app.resetBootCounter(); }
function resetRecoveryState() { app.resetRecoveryState(); }
function showAbout() { app.showAbout(); }
function showHelp() { app.showHelp(); }
function closeModal() { app.closeModal(); }

// Initialize the application
const app = new AntiBootloopWebUI();

// Handle page visibility changes
document.addEventListener('visibilitychange', () => {
    if (document.hidden) {
        app.stopAutoRefresh();
    } else {
        app.startAutoRefresh();
    }
});