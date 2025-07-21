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
    // Performance monitoring
    performanceMetrics: {
        commandCount: 0,
        totalExecutionTime: 0,
        averageExecutionTime: 0,
        errorCount: 0,
        cacheHitCount: 0,
        startTime: Date.now()
    },
    
    // Command result cache
    commandCache: new Map(),
    cacheTimeout: 30000, // 30 seconds
    
    // Rate limiting
    rateLimiter: {
        commandQueue: [],
        isProcessing: false,
        maxConcurrent: 5,
        activeCommands: 0
    },
    
    /**
     * Check and use command cache
     * @private
     * @param {string} cacheKey - Cache key
     * @param {Function} commandFn - Function to execute if cache miss
     * @returns {Promise<any>} Cached or fresh result
     */
    _withCache: async function(cacheKey, commandFn) {
        // Check cache first
        const cachedItem = this.commandCache.get(cacheKey);
        if (cachedItem && (Date.now() - cachedItem.timestamp < this.cacheTimeout)) {
            this.performanceMetrics.cacheHitCount++;
            console.log(`Cache hit for: ${cacheKey}`);
            return cachedItem.result;
        }
        
        // Execute command and cache result
        const result = await commandFn();
        this.commandCache.set(cacheKey, {
            result,
            timestamp: Date.now()
        });
        
        // Clean up old cache entries periodically
        if (this.commandCache.size > 100) {
            this._cleanupCache();
        }
        
        return result;
    },
    
    /**
     * Clean up expired cache entries
     * @private
     */
    _cleanupCache: function() {
        const now = Date.now();
        for (const [key, value] of this.commandCache.entries()) {
            if (now - value.timestamp > this.cacheTimeout) {
                this.commandCache.delete(key);
            }
        }
    },
    
    /**
     * Rate limit command execution
     * @private
     * @param {Function} commandFn - Command function to execute
     * @returns {Promise<any>} Command result
     */
    _withRateLimit: async function(commandFn) {
        return new Promise((resolve, reject) => {
            this.rateLimiter.commandQueue.push({ commandFn, resolve, reject });
            this._processCommandQueue();
        });
    },
    
    /**
     * Process command queue with rate limiting
     * @private
     */
    _processCommandQueue: async function() {
        if (this.rateLimiter.isProcessing || 
            this.rateLimiter.activeCommands >= this.rateLimiter.maxConcurrent ||
            this.rateLimiter.commandQueue.length === 0) {
            return;
        }
        
        this.rateLimiter.isProcessing = true;
        
        while (this.rateLimiter.commandQueue.length > 0 && 
               this.rateLimiter.activeCommands < this.rateLimiter.maxConcurrent) {
            
            const { commandFn, resolve, reject } = this.rateLimiter.commandQueue.shift();
            this.rateLimiter.activeCommands++;
            
            commandFn()
                .then(resolve)
                .catch(reject)
                .finally(() => {
                    this.rateLimiter.activeCommands--;
                    // Process next command
                    setTimeout(() => this._processCommandQueue(), 10);
                });
        }
        
        this.rateLimiter.isProcessing = false;
    },
    
    /**
     * Update performance metrics
     * @private
     * @param {number} executionTime - Command execution time in ms
     * @param {boolean} isError - Whether the command resulted in error
     */
    _updateMetrics: function(executionTime, isError = false) {
        this.performanceMetrics.commandCount++;
        this.performanceMetrics.totalExecutionTime += executionTime;
        this.performanceMetrics.averageExecutionTime = 
            this.performanceMetrics.totalExecutionTime / this.performanceMetrics.commandCount;
        
        if (isError) {
            this.performanceMetrics.errorCount++;
        }
    },
    
    /**
     * Get performance metrics
     * @returns {Object} Performance metrics
     */
    getPerformanceMetrics: function() {
        const uptime = Date.now() - this.performanceMetrics.startTime;
        return {
            ...this.performanceMetrics,
            uptime,
            errorRate: this.performanceMetrics.errorCount / Math.max(1, this.performanceMetrics.commandCount),
            cacheHitRate: this.performanceMetrics.cacheHitCount / Math.max(1, this.performanceMetrics.commandCount),
            commandsPerSecond: (this.performanceMetrics.commandCount / uptime) * 1000
        };
    },
    
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
     * Execute shell command synchronously using KernelSU Next API
     * @param {string} cmd - Shell command to execute
     * @param {Object} options - Execution options (timeout, retries)
     * @returns {Promise<string>} Command output
     */
    execCommand: async function(cmd, options = {}) {
        const { 
            timeout = 30000, 
            retries = 3, 
            silent = false, 
            cache = false, 
            cacheKey = null,
            rateLimit = true 
        } = options;
        
        const startTime = Date.now();
        const finalCacheKey = cacheKey || `exec_${cmd}`;
        
        try {
            // Use cache if enabled
            if (cache) {
                return await this._withCache(finalCacheKey, async () => {
                    return await this._executeCommandWithRateLimit(cmd, { timeout, retries, silent, rateLimit });
                });
            }
            
            // Execute directly or with rate limiting
            return await this._executeCommandWithRateLimit(cmd, { timeout, retries, silent, rateLimit });
        } catch (error) {
            this._updateMetrics(Date.now() - startTime, true);
            throw error;
        } finally {
            this._updateMetrics(Date.now() - startTime, false);
        }
    },
    
    /**
     * Internal command execution with rate limiting
     * @private
     */
    _executeCommandWithRateLimit: async function(cmd, options) {
        const { timeout, retries, silent, rateLimit } = options;
        
        const executeCommand = async () => {
            return await this._executeCommandInternal(cmd, { timeout, retries, silent });
        };
        
        if (rateLimit) {
            return await this._withRateLimit(executeCommand);
        }
        
        return await executeCommand();
    },
    
    /**
     * Core command execution logic
     * @private
     */
    _executeCommandInternal: async function(cmd, options) {
        const { timeout, retries, silent } = options;
        let lastError;
        
        for (let attempt = 1; attempt <= retries; attempt++) {
            try {
                if (typeof ksu !== 'undefined' && ksu.exec) {
                    // Set timeout for command execution
                    const timeoutPromise = new Promise((_, reject) => {
                        setTimeout(() => reject(new Error('Command timeout')), timeout);
                    });
                    
                    const commandPromise = Promise.resolve(ksu.exec(cmd));
                    
                    const result = await Promise.race([commandPromise, timeoutPromise]);
                    
                    if (!silent) {
                        console.log(`Command executed (attempt ${attempt}): ${cmd.substring(0, 50)}...`);
                    }
                    
                    return result;
                } else {
                    throw new Error('KernelSU API not available');
                }
            } catch (error) {
                lastError = error;
                if (!silent) {
                    console.warn(`Command execution failed (attempt ${attempt}/${retries}):`, error.message);
                }
                
                // Don't retry on certain errors
                if (error.message.includes('permission denied') || 
                    error.message.includes('not found') ||
                    attempt === retries) {
                    break;
                }
                
                // Wait before retry with exponential backoff
                await new Promise(resolve => setTimeout(resolve, Math.min(10000, 1000 * Math.pow(2, attempt - 1))));
            }
        }
        
        console.error('All command execution attempts failed:', lastError);
        throw lastError;
    },
    
    /**
     * Execute shell command asynchronously with callback using KernelSU Next API
     * @param {string} cmd - Shell command to execute
     * @param {Function} callback - Callback function to handle result
     */
    execCommandAsync: function(cmd, callback) {
        if (typeof ksu !== 'undefined' && ksu.exec) {
            const callbackFuncName = `callback_${Date.now()}`;
            
            // Define callback function in global scope
            window[callbackFuncName] = function(exitCode, stdout, stderr) {
                callback({exitCode, stdout, stderr});
                // Clean up global function
                delete window[callbackFuncName];
            };
            
            // Execute command with callback
            ksu.exec(cmd, callbackFuncName);
        } else {
            // Fallback for development mode
            setTimeout(() => {
                callback({exitCode: 0, stdout: `Mock output for: ${cmd}`, stderr: ''});
            }, 100);
        }
    },
    
    /**
     * Spawn a shell command with streaming output using KernelSU Next API
     * @param {string} command - Shell command to execute
     * @param {Array} args - Command arguments
     * @param {Object} options - Execution options (cwd, env)
     * @returns {Promise<Object>} Process result
     */
    spawnCommand: async function(command, args = [], options = {}) {
        try {
            if (typeof ksu === 'undefined' || !ksu.spawn) {
                // Fallback for development mode
                return new Promise((resolve) => {
                    setTimeout(() => {
                        resolve({
                            stdout: `Mock spawn output for: ${command} ${args.join(' ')}`,
                            stderr: '',
                            exitCode: 0
                        });
                    }, 1000);
                });
            }

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
     * Show notification toast using KernelSU Next API
     * @param {string} message - Notification message
     * @param {string} type - Notification type (info, success, warning, error)
     */
    showNotification: function(message, type = 'info') {
        if (typeof ksu !== 'undefined' && ksu.toast) {
            ksu.toast(message);
        }
        if (typeof UIController !== 'undefined') {
            UIController.showNotification(message, type);
        } else {
            console.log(`Notification [${type}]: ${message}`);
        }
    },

    /**
     * Get system package information using KernelSU Next API
     * @param {string} type - Package type ('system', 'user', 'all')
     * @returns {Promise<Array>} List of packages
     */
    getPackages: async function(type = 'all') {
        try {
            if (typeof ksu === 'undefined') {
                return [];
            }

            let packages = [];
            
            switch(type) {
                case 'system':
                    packages = ksu.listSystemPackages();
                    break;
                case 'user':
                    packages = ksu.listUserPackages();
                    break;
                case 'all':
                default:
                    packages = ksu.listAllPackages();
                    break;
            }

            // Parse packages if they're returned as a string
            if (typeof packages === 'string') {
                try {
                    packages = JSON.parse(packages);
                } catch (e) {
                    packages = packages.split('\n').filter(p => p.trim());
                }
            }

            return Array.isArray(packages) ? packages : [];
        } catch (error) {
            console.error('Failed to get packages:', error);
            return [];
        }
    },

    /**
     * Get detailed package information
     * @param {Array<string>} packageNames - List of package names
     * @returns {Promise<Object>} Package details
     */
    getPackagesInfo: async function(packageNames) {
        try {
            if (typeof ksu === 'undefined' || !ksu.getPackagesInfo) {
                return {};
            }

            const packageNamesJson = JSON.stringify(packageNames);
            const result = ksu.getPackagesInfo(packageNamesJson);
            
            return typeof result === 'string' ? JSON.parse(result) : result;
        } catch (error) {
            console.error('Failed to get package info:', error);
            return {};
        }
    },
    
    /**
     * Get module information using KernelSU Next API
     * @returns {Promise<Object>} Module information
     */
    getModuleInfo: async function() {
        try {
            if (typeof ksu !== 'undefined' && ksu.moduleInfo) {
                const moduleInfoResult = ksu.moduleInfo();
                const moduleInfo = typeof moduleInfoResult === 'string' ? 
                    JSON.parse(moduleInfoResult) : moduleInfoResult;
                
                // Cache module info
                this.moduleInfo = moduleInfo;
                
                return moduleInfo;
            } else {
                // Return default module info for development mode
                const defaultInfo = {
                    id: 'kernelsu_antibootloop_backup',
                    name: 'KernelSU Anti-Bootloop & Backup',
                    version: 'v1.0.0',
                    versionCode: '100',
                    author: 'Wiktor/overspend1',
                    description: 'Advanced anti-bootloop protection and comprehensive backup solution'
                };
                
                this.moduleInfo = defaultInfo;
                return defaultInfo;
            }
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
        return await this._withCache('system_status', async () => {
            try {
                // Get device properties with cache
                const buildProp = await this.execCommand('getprop', { 
                    cache: true, 
                    cacheKey: 'device_properties' 
                });
                
                // Parse relevant properties
                const deviceModel = this._parseProperty(buildProp, 'ro.product.model');
                const androidVersion = this._parseProperty(buildProp, 'ro.build.version.release');
                const sdkVersion = this._parseProperty(buildProp, 'ro.build.version.sdk');
                const buildDate = this._parseProperty(buildProp, 'ro.build.date');
                const manufacturer = this._parseProperty(buildProp, 'ro.product.manufacturer');
                
                // Get KernelSU version
                const ksuVersion = await this.execCommand('su -v', { 
                    cache: true, 
                    cacheKey: 'ksu_version' 
                });
                
                // Get boot information
                const bootInfoCmd = 'cat /data/adb/modules/kernelsu_antibootloop_backup/config/boot_info.json || echo "{}"';
                const bootInfoJson = await this.execCommand(bootInfoCmd);
                const bootInfo = JSON.parse(bootInfoJson || '{"bootCount":0,"lastBoot":"None"}');
                
                // Get memory info
                const memInfo = await this.execCommand('cat /proc/meminfo | head -3', { 
                    cache: true, 
                    cacheKey: 'memory_info' 
                });
                const totalMem = this._parseMemInfo(memInfo, 'MemTotal');
                const freeMem = this._parseMemInfo(memInfo, 'MemFree');
                
                // Get storage info
                const storageInfo = await this.execCommand('df -h /data | tail -1', { 
                    cache: true, 
                    cacheKey: 'storage_info' 
                });
                const storage = this._parseStorageInfo(storageInfo);
                
                return {
                    deviceModel,
                    androidVersion,
                    sdkVersion: parseInt(sdkVersion) || 0,
                    manufacturer,
                    buildDate,
                    kernelsuVersion: ksuVersion.trim(),
                    moduleVersion: this.moduleInfo?.version || 'v1.0.0',
                    lastBoot: bootInfo.lastBoot,
                    bootCount: bootInfo.bootCount,
                    bootloopProtectionEnabled: true,
                    memory: {
                        total: totalMem,
                        free: freeMem,
                        used: totalMem - freeMem
                    },
                    storage,
                    timestamp: Date.now()
                };
            } catch (error) {
                console.error('Failed to get system status:', error);
                // Return default values on error
                return {
                    deviceModel: 'Unknown',
                    androidVersion: 'Unknown',
                    sdkVersion: 0,
                    manufacturer: 'Unknown',
                    buildDate: 'Unknown',
                    kernelsuVersion: 'Unknown',
                    moduleVersion: 'v1.0.0',
                    lastBoot: 'Unknown',
                    bootCount: 0,
                    bootloopProtectionEnabled: true,
                    memory: { total: 0, free: 0, used: 0 },
                    storage: { total: 0, used: 0, free: 0, percentage: 0 },
                    timestamp: Date.now()
                };
            }
        });
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
     * Toggle full-screen mode using KernelSU Next API
     * @param {boolean} enable - Whether to enable or disable full-screen
     */
    toggleFullScreen: function(enable) {
        if (typeof ksu !== 'undefined' && ksu.fullScreen) {
            ksu.fullScreen(enable);
        } else {
            console.log(`Full-screen mode ${enable ? 'enabled' : 'disabled'} (development mode)`);
        }
    },
    
    /**
     * Check if running in KernelSU Next environment
     * @returns {boolean} True if KernelSU Next API is available
     */
    isKernelSUAvailable: function() {
        return typeof ksu !== 'undefined';
    },

    /**
     * Get available KernelSU Next API methods
     * @returns {Array<string>} Available methods
     */
    getAvailableMethods: function() {
        if (!this.isKernelSUAvailable()) {
            return [];
        }
        
        const methods = [];
        const ksuMethods = ['exec', 'spawn', 'toast', 'fullScreen', 'moduleInfo', 
                           'listSystemPackages', 'listUserPackages', 'listAllPackages', 'getPackagesInfo'];
        
        ksuMethods.forEach(method => {
            if (typeof ksu[method] === 'function') {
                methods.push(method);
            }
        });
        
        return methods;
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
     * Parse memory information from /proc/meminfo
     * @private
     * @param {string} memOutput - meminfo output
     * @param {string} field - Field to extract (e.g., 'MemTotal', 'MemFree')
     * @returns {number} Memory in MB
     */
    _parseMemInfo: function(memOutput, field) {
        const regex = new RegExp(`${field}:\\s*(\\d+)\\s*kB`);
        const match = memOutput.match(regex);
        return match ? Math.round(parseInt(match[1]) / 1024) : 0; // Convert KB to MB
    },
    
    /**
     * Parse storage information from df output
     * @private
     * @param {string} dfOutput - df command output
     * @returns {Object} Storage information
     */
    _parseStorageInfo: function(dfOutput) {
        const parts = dfOutput.trim().split(/\s+/);
        if (parts.length >= 6) {
            const total = this._parseStorageSize(parts[1]);
            const used = this._parseStorageSize(parts[2]);
            const free = this._parseStorageSize(parts[3]);
            const percentage = parseInt(parts[4].replace('%', ''));
            
            return { total, used, free, percentage };
        }
        return { total: 0, used: 0, free: 0, percentage: 0 };
    },
    
    /**
     * Parse storage size to MB
     * @private
     * @param {string} sizeStr - Size string (e.g., '1.5G', '512M')
     * @returns {number} Size in MB
     */
    _parseStorageSize: function(sizeStr) {
        if (!sizeStr) return 0;
        
        const match = sizeStr.match(/^([\d.]+)([KMGT]?)$/i);
        if (!match) return 0;
        
        const value = parseFloat(match[1]);
        const unit = match[2].toUpperCase();
        
        switch (unit) {
            case 'T': return Math.round(value * 1024 * 1024);
            case 'G': return Math.round(value * 1024);
            case 'M': return Math.round(value);
            case 'K': return Math.round(value / 1024);
            default: return Math.round(value / (1024 * 1024)); // Assume bytes
        }
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
        
        // HTTP API Client for backend communication
        const HTTPClient = {
            baseURL: `${window.location.protocol}//${window.location.host}`,
            
            async request(endpoint, options = {}) {
                const url = `${this.baseURL}${endpoint}`;
                const config = {
                    method: 'GET',
                    headers: {
                        'Content-Type': 'application/json',
                        'X-Requested-With': 'XMLHttpRequest'
                    },
                    ...options
                };
                
                try {
                    const response = await fetch(url, config);
                    if (!response.ok) {
                        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
                    }
                    return await response.json();
                } catch (error) {
                    console.warn(`HTTP request failed for ${endpoint}:`, error.message);
                    throw error;
                }
            },
            
            async execCommand(cmd) {
                try {
                    const response = await this.request('/api/command/exec', {
                        method: 'POST',
                        body: JSON.stringify({ command: cmd })
                    });
                    return response.output || '';
                } catch (error) {
                    console.warn(`Command execution via HTTP failed: ${cmd}`, error.message);
                    return `Error: ${error.message}`;
                }
            },
            
            async getSystemInfo() {
                try {
                    return await this.request('/api/system/info');
                } catch (error) {
                    console.warn('Failed to get system info via HTTP:', error.message);
                    return null;
                }
            },
            
            async listBackups() {
                try {
                    return await this.request('/api/backups/list');
                } catch (error) {
                    console.warn('Failed to list backups via HTTP:', error.message);
                    return { backups: [] };
                }
            },
            
            async createBackup(options) {
                try {
                    return await this.request('/api/backups/create', {
                        method: 'POST',
                        body: JSON.stringify(options)
                    });
                } catch (error) {
                    console.warn('Failed to create backup via HTTP:', error.message);
                    throw error;
                }
            }
        };
        
        // Enhanced ksu object that tries HTTP first, then falls back to mock
        window.ksu = {
            exec: async (cmd) => {
                try {
                    // Try HTTP client first
                    const result = await HTTPClient.execCommand(cmd);
                    if (!result.startsWith('Error:')) {
                        return result;
                    }
                } catch (error) {
                    console.warn('HTTP execution failed, using mock:', error.message);
                }
                
                // Fallback to mock
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
                    author: 'Wiktor/overspend1',
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