/**
 * KernelSU Anti-Bootloop & Backup Module
 * WebUIX API Interface for Module Communication
 * Compliant with WebUIX framework standards
 */

/**
 * API Client for KernelSU Anti-Bootloop & Backup Module
 * Implements WebUIX API standards for kernel-level operations
 */
const ModuleAPI = {
    /**
     * Initialize API and load system information
     * @returns {Promise<boolean>} Success status
     */
    init: async function() {
        console.log('Initializing WebUIX-compliant ModuleAPI...');
        
        try {
            // Get module information
            const moduleInfo = await this.getModuleInfo();
            console.log('Module Info:', moduleInfo);
            
            // Get system status
            const systemStatus = await this.getSystemStatus();
            console.log('System Status:', systemStatus);
            
            return true;
        } catch (error) {
            console.error('Failed to initialize API:', error);
            this.showNotification('API initialization failed', 'error');
            return false;
        }
    },
    
    /**
     * Execute shell command synchronously
     * @param {string} cmd - Shell command to execute
     * @returns {Promise<string>} Command output
     */
    execCommand: async function(cmd) {
        try {
            return await this._executeKsuCommand('exec', cmd);
        } catch (error) {
            console.error('Command execution failed:', error);
            throw error;
        }
    },
    
    /**
     * Execute shell command asynchronously with callback
     * @param {string} cmd - Shell command to execute
     * @param {Function} callback - Callback function to handle result
     */
    execCommandAsync: function(cmd, callback) {
        const callbackFuncName = `callback_${Date.now()}`;
        
        // Define callback function in global scope
        window[callbackFuncName] = function(exitCode, stdout, stderr) {
            callback({exitCode, stdout, stderr});
            // Clean up global function
            delete window[callbackFuncName];
        };
        
        // Execute command with callback
        ksu.exec(cmd, callbackFuncName);
    },
    
    /**
     * Spawn a shell command with streaming output
     * @param {string} command - Shell command to execute
     * @param {Array} args - Command arguments
     * @param {Object} options - Execution options (cwd, env)
     * @returns {Promise<Object>} Process result
     */
    spawnCommand: async function(command, args = [], options = {}) {
        try {
            const streamHandlerName = `streamHandler_${Date.now()}`;
            let output = {stdout: '', stderr: '', exitCode: null};
            
            return new Promise((resolve, reject) => {
                // Create stream handler object
                window[streamHandlerName] = {
                    stdout: {
                        emit: (event, data) => {
                            if (event === 'data') {
                                output.stdout += data;
                                console.log('stdout:', data);
                            }
                        }
                    },
                    stderr: {
                        emit: (event, data) => {
                            if (event === 'data') {
                                output.stderr += data;
                                console.error('stderr:', data);
                            }
                        }
                    },
                    exit: (code) => {
                        output.exitCode = code;
                        // Clean up
                        delete window[streamHandlerName];
                        resolve(output);
                    },
                    error: (err) => {
                        // Clean up
                        delete window[streamHandlerName];
                        reject(err);
                    }
                };
                
                // Prepare arguments and options
                const jsonArgs = JSON.stringify(args);
                const jsonOptions = JSON.stringify(options);
                
                // Execute spawn command
                ksu.spawn(command, jsonArgs, jsonOptions, streamHandlerName);
            });
        } catch (error) {
            console.error('Spawn command failed:', error);
            throw error;
        }
    },
    
    /**
     * Show notification toast
     * @param {string} message - Notification message
     * @param {string} type - Notification type (info, success, warning, error)
     */
    showNotification: function(message, type = 'info') {
        ksu.toast(message);
        UIController.showNotification(message, type);
    },
    
    /**
     * Get module information
     * @returns {Promise<Object>} Module information
     */
    getModuleInfo: async function() {
        try {
            const moduleInfoJson = await this._executeKsuCommand('moduleInfo');
            const moduleInfo = JSON.parse(moduleInfoJson);
            
            // Cache module info
            this.moduleInfo = moduleInfo;
            
            return moduleInfo;
        } catch (error) {
            console.error('Failed to get module information:', error);
            throw error;
        }
    },
    
    /**
     * Get system status including bootloop protection status
     * @returns {Promise<Object>} System status
     */
    getSystemStatus: async function() {
        try {
            // Get device properties
            const buildProp = await this.execCommand('getprop');
            
            // Parse relevant properties
            const deviceModel = this._parseProperty(buildProp, 'ro.product.model');
            const androidVersion = this._parseProperty(buildProp, 'ro.build.version.release');
            
            // Get KernelSU version
            const ksuVersion = await this.execCommand('su -v');
            
            // Get boot information
            const bootInfoCmd = 'cat /data/adb/modules/kernelsu_antibootloop_backup/config/boot_info.json';
            const bootInfoJson = await this.execCommand(bootInfoCmd);
            const bootInfo = JSON.parse(bootInfoJson || '{"bootCount":0,"lastBoot":"None"}');
            
            return {
                deviceModel,
                androidVersion,
                kernelsuVersion: ksuVersion.trim(),
                moduleVersion: this.moduleInfo?.version || 'v1.0.0',
                lastBoot: bootInfo.lastBoot,
                bootCount: bootInfo.bootCount,
                bootloopProtectionEnabled: true
            };
        } catch (error) {
            console.error('Failed to get system status:', error);
            // Return default values on error
            return {
                deviceModel: 'Unknown',
                androidVersion: 'Unknown',
                kernelsuVersion: 'Unknown',
                moduleVersion: 'v1.0.0',
                lastBoot: 'Unknown',
                bootCount: 0,
                bootloopProtectionEnabled: true
            };
        }
    },
    
    /**
     * Get module settings
     * @returns {Promise<Object>} Module settings
     */
    getSettings: async function() {
        try {
            const settingsCmd = 'cat /data/adb/modules/kernelsu_antibootloop_backup/config/settings.json';
            const settingsJson = await this.execCommand(settingsCmd);
            return JSON.parse(settingsJson || '{}');
        } catch (error) {
            console.error('Failed to get settings:', error);
            // Return default settings on error
            return {
                webuiEnabled: true,
                webuiPort: 8080,
                authRequired: true,
                debugLogging: false,
                backupEncryption: false,
                backupCompression: true,
                autoBackup: false,
                backupSchedule: 'weekly',
                useOverlayfs: true,
                selinuxMode: 'enforcing',
                storagePath: '/data/adb/modules/kernelsu_antibootloop_backup/config/backups',
                bootTimeout: 120,
                maxBootAttempts: 3,
                autoRestore: true,
                disableModules: true,
                safeModeTimeout: 5
            };
        }
    },
    
    /**
     * Update module settings
     * @param {Object} settings - New settings
     * @returns {Promise<Object>} Update result
     */
    updateSettings: async function(settings) {
        try {
            const settingsJson = JSON.stringify(settings, null, 2);
            const updateCmd = `echo '${settingsJson}' > /data/adb/modules/kernelsu_antibootloop_backup/config/settings.json`;
            await this.execCommand(updateCmd);
            
            // Apply settings (restart services if needed)
            const applyCmd = '/data/adb/modules/kernelsu_antibootloop_backup/scripts/apply-settings.sh';
            await this.execCommand(`sh ${applyCmd}`);
            
            return { success: true, message: 'Settings updated successfully' };
        } catch (error) {
            console.error('Failed to update settings:', error);
            throw error;
        }
    },
    
    /**
     * Get list of backups
     * @returns {Promise<Array>} List of backups
     */
    getBackups: async function() {
        try {
            const settings = await this.getSettings();
            const storagePath = settings.storagePath || '/data/adb/modules/kernelsu_antibootloop_backup/config/backups';
            
            const listCmd = `ls -la ${storagePath}`;
            const output = await this.execCommand(listCmd);
            
            // Parse ls output to get backup files
            const backups = this._parseBackupList(output, storagePath);
            return { backups };
        } catch (error) {
            console.error('Failed to get backups:', error);
            return { backups: [] };
        }
    },
    
    /**
     * Create a new backup
     * @param {Object} options - Backup options
     * @returns {Promise<Object>} Creation result
     */
    createBackup: async function(options) {
        try {
            const { name, profile, description } = options;
            
            // Prepare backup command
            const backupScript = '/data/adb/modules/kernelsu_antibootloop_backup/scripts/backup-engine.sh';
            const backupCmd = `sh ${backupScript} create "${name}" "${profile}" "${description}"`;
            
            // Show notification
            this.showNotification(`Creating backup: ${name}...`, 'info');
            
            // Execute backup command
            const result = await this.spawnCommand('sh', ['-c', backupCmd]);
            
            if (result.exitCode === 0) {
                this.showNotification(`Backup ${name} created successfully`, 'success');
                return {
                    success: true,
                    message: 'Backup created successfully',
                    backupId: name
                };
            } else {
                this.showNotification(`Backup creation failed: ${result.stderr}`, 'error');
                throw new Error(`Backup creation failed: ${result.stderr}`);
            }
        } catch (error) {
            console.error('Backup creation failed:', error);
            this.showNotification('Backup creation failed', 'error');
            throw error;
        }
    },
    
    /**
     * Restore from backup
     * @param {string} backupId - Backup ID
     * @returns {Promise<Object>} Restore result
     */
    restoreBackup: async function(backupId) {
        try {
            // Prepare restore command
            const restoreScript = '/data/adb/modules/kernelsu_antibootloop_backup/scripts/backup-engine.sh';
            const restoreCmd = `sh ${restoreScript} restore "${backupId}"`;
            
            // Show notification
            this.showNotification(`Restoring from backup: ${backupId}...`, 'info');
            
            // Execute restore command
            const result = await this.spawnCommand('sh', ['-c', restoreCmd]);
            
            if (result.exitCode === 0) {
                this.showNotification(`Restore from ${backupId} completed successfully`, 'success');
                return {
                    success: true,
                    message: 'Backup restored successfully'
                };
            } else {
                this.showNotification(`Restore failed: ${result.stderr}`, 'error');
                throw new Error(`Restore failed: ${result.stderr}`);
            }
        } catch (error) {
            console.error('Restore failed:', error);
            this.showNotification('Restore failed', 'error');
            throw error;
        }
    },
    
    /**
     * Delete a backup
     * @param {string} backupId - Backup ID
     * @returns {Promise<Object>} Delete result
     */
    deleteBackup: async function(backupId) {
        try {
            const settings = await this.getSettings();
            const storagePath = settings.storagePath || '/data/adb/modules/kernelsu_antibootloop_backup/config/backups';
            
            const deleteCmd = `rm -rf "${storagePath}/${backupId}"`;
            await this.execCommand(deleteCmd);
            
            this.showNotification(`Backup ${backupId} deleted successfully`, 'success');
            return {
                success: true,
                message: 'Backup deleted successfully'
            };
        } catch (error) {
            console.error('Failed to delete backup:', error);
            this.showNotification('Failed to delete backup', 'error');
            throw error;
        }
    },
    
    /**
     * Get safety status (bootloop protection)
     * @returns {Promise<Object>} Safety status
     */
    getSafetyStatus: async function() {
        try {
            const statusCmd = 'cat /data/adb/modules/kernelsu_antibootloop_backup/config/safety_status.json';
            const statusJson = await this.execCommand(statusCmd);
            return JSON.parse(statusJson || '{"bootloopProtectionEnabled":true,"bootCount":0,"lastBootTime":"None","recoveryPointsAvailable":0}');
        } catch (error) {
            console.error('Failed to get safety status:', error);
            return {
                bootloopProtectionEnabled: true,
                bootCount: 0,
                lastBootTime: 'None',
                recoveryPointsAvailable: 0
            };
        }
    },
    
    /**
     * Test bootloop protection
     * @returns {Promise<Object>} Test result
     */
    testBootloopProtection: async function() {
        try {
            const testScript = '/data/adb/modules/kernelsu_antibootloop_backup/scripts/test-bootloop.sh';
            const testCmd = `sh ${testScript}`;
            
            this.showNotification('Bootloop protection test initiated...', 'info');
            
            // Execute test command
            await this.execCommand(testCmd);
            
            return {
                success: true,
                message: 'Bootloop protection test initiated'
            };
        } catch (error) {
            console.error('Failed to test bootloop protection:', error);
            this.showNotification('Failed to test bootloop protection', 'error');
            throw error;
        }
    },
    
    /**
     * Create recovery point
     * @param {Object} options - Recovery point options
     * @returns {Promise<Object>} Creation result
     */
    createRecoveryPoint: async function(options) {
        try {
            const { name, description } = options;
            
            // Prepare recovery point command
            const recoveryScript = '/data/adb/modules/kernelsu_antibootloop_backup/scripts/recovery-point.sh';
            const recoveryCmd = `sh ${recoveryScript} create "${name}" "${description}"`;
            
            this.showNotification(`Creating recovery point: ${name}...`, 'info');
            
            // Execute recovery point command
            const result = await this.spawnCommand('sh', ['-c', recoveryCmd]);
            
            if (result.exitCode === 0) {
                this.showNotification(`Recovery point ${name} created successfully`, 'success');
                return {
                    success: true,
                    message: 'Recovery point created successfully',
                    pointId: name
                };
            } else {
                this.showNotification(`Recovery point creation failed: ${result.stderr}`, 'error');
                throw new Error(`Recovery point creation failed: ${result.stderr}`);
            }
        } catch (error) {
            console.error('Recovery point creation failed:', error);
            this.showNotification('Recovery point creation failed', 'error');
            throw error;
        }
    },
    
    /**
     * Toggle full-screen mode
     * @param {boolean} enable - Whether to enable or disable full-screen
     */
    toggleFullScreen: function(enable) {
        ksu.fullScreen(enable);
    },
    
    /**
     * Helper method to execute KSU command
     * @private
     * @param {string} method - KSU API method name
     * @param {string} params - Command parameters
     * @returns {Promise<string>} Command result
     */
    _executeKsuCommand: async function(method, params = '') {
        return new Promise((resolve, reject) => {
            try {
                if (method === 'exec') {
                    const result = ksu.exec(params);
                    resolve(result);
                } else if (method === 'moduleInfo') {
                    const result = ksu.moduleInfo();
                    resolve(result);
                } else {
                    reject(new Error(`Unsupported KSU method: ${method}`));
                }
            } catch (error) {
                reject(error);
            }
        });
    },
    
    /**
     * Parse property from getprop output
     * @private
     * @param {string} propOutput - getprop command output
     * @param {string} propertyName - Property name to extract
     * @returns {string} Property value
     */
    _parseProperty: function(propOutput, propertyName) {
        const regex = new RegExp(`\\[${propertyName}\\]:\\s*\\[(.+?)\\]`);
        const match = propOutput.match(regex);
        return match ? match[1] : 'Unknown';
    },
    
    /**
     * Parse backup list from ls output
     * @private
     * @param {string} lsOutput - ls command output
     * @param {string} storagePath - Backup storage path
     * @returns {Array} List of backup objects
     */
    _parseBackupList: function(lsOutput, storagePath) {
        const lines = lsOutput.split('\n');
        const backups = [];
        
        // Skip first line (total size) and parse directory entries
        for (let i = 1; i < lines.length; i++) {
            const line = lines[i].trim();
            if (!line || line.startsWith('total ') || line.startsWith('.')) continue;
            
            const parts = line.split(/\s+/);
            if (parts.length >= 9 && parts[0].startsWith('d')) {
                const name = parts.slice(8).join(' ');
                
                // Skip if it's . or ..
                if (name === '.' || name === '..') continue;
                
                const date = `${parts[5]} ${parts[6]} ${parts[7]}`;
                
                backups.push({
                    id: name,
                    name: name,
                    date: date,
                    size: 'Calculating...',
                    path: `${storagePath}/${name}`
                });
            }
        }
        
        return backups;
    }
};

// Initialize API when document is loaded
document.addEventListener('DOMContentLoaded', () => {
    // Check if running in WebUIX environment
    if (typeof ksu !== 'undefined') {
        console.log('WebUIX environment detected');
        ModuleAPI.init()
            .then(success => {
                if (success) {
                    console.log('ModuleAPI initialized successfully');
                    
                    // Update app state with system info
                    if (typeof AppState !== 'undefined') {
                        ModuleAPI.getSystemStatus().then(info => {
                            AppState.systemInfo = info;
                            updateSystemInfo();
                        });
                    }
                } else {
                    console.error('Failed to initialize ModuleAPI');
                }
            });
    } else {
        console.warn('WebUIX environment not detected. Running in development/fallback mode.');
        // Define mock ksu object for development
        window.ksu = {
            exec: (cmd) => {
                console.log('Mock exec:', cmd);
                return `Mock output for: ${cmd}`;
            },
            spawn: (cmd, args, options, callback) => {
                console.log('Mock spawn:', cmd, args, options);
                if (window[callback]) {
                    setTimeout(() => {
                        window[callback].stdout.emit('data', 'Mock stdout output');
                        window[callback].exit(0);
                    }, 500);
                }
            },
            toast: (msg) => {
                console.log('Mock toast:', msg);
            },
            fullScreen: (enable) => {
                console.log('Mock fullScreen:', enable);
            },
            moduleInfo: () => {
                return JSON.stringify({
                    id: 'kernelsu_antibootloop_backup',
                    name: 'KernelSU Anti-Bootloop & Backup',
                    version: 'v1.0.0',
                    versionCode: '1',
                    author: 'OverModules Team',
                    description: 'Advanced KernelSU module that combines anti-bootloop protection with comprehensive backup capabilities',
                    moduleDir: '/data/adb/modules/kernelsu_antibootloop_backup'
                });
            }
        };
        
        // Initialize with mock API
        ModuleAPI.init().then(() => {
            console.log('Mock API initialized');
        });
    }
});