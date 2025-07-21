/**
 * KernelSU Anti-Bootloop & Backup Module
 * Dashboard visualizations and data management
 * 
 * Provides system health monitoring, data visualization, and filtering capabilities
 */

// Dashboard Controller
const DashboardController = {
    // Chart objects
    charts: {},
    
    // Data cache
    dataCache: {
        bootHistory: [],
        backupSizes: [],
        diskUsage: [],
        systemMetrics: [],
        activityLog: []
    },
    
    // Initialization
    init: function() {
        console.log('Initializing Dashboard Controller...');
        
        // Initialize dashboard components when page is loaded
        document.addEventListener('page-activated', (event) => {
            if (event.detail.pageId === 'dashboard') {
                this.refreshDashboard();
            }
        });
        
        // Initialize data browsers
        this.initDataBrowsers();
        
        // Initialize notification system
        this.initNotificationSystem();
        
        // Set up refresh button
        const refreshButton = document.getElementById('refresh-dashboard');
        if (refreshButton) {
            refreshButton.addEventListener('click', () => {
                this.refreshDashboard();
            });
        }
        
        // Refresh dashboard immediately for initial load
        setTimeout(() => {
            this.refreshDashboard();
        }, 500);
    },
    
    /**
     * Refresh dashboard data and visualizations
     */
    refreshDashboard: function() {
        // Show loading state
        window.UI.createLoader('Loading dashboard data...');
        
        // Load all dashboard data
        Promise.all([
            this.loadBootHistory(),
            this.loadSystemMetrics(),
            this.loadDiskUsage(),
            this.loadBackupData(),
            this.loadActivityLog()
        ]).then(() => {
            // Update visualizations
            this.updateVisualizations();
            
            // Remove loader
            const loaderElements = document.querySelectorAll('.loader-container');
            loaderElements.forEach(loader => loader.remove());
        }).catch(error => {
            console.error('Failed to load dashboard data:', error);
            window.UI.showNotification('Failed to load dashboard data. Check connection and try again.', 'error');
            
            // Remove loader
            const loaderElements = document.querySelectorAll('.loader-container');
            loaderElements.forEach(loader => loader.remove());
        });
    },
    
    /**
     * Load boot history data
     * @returns {Promise} Promise that resolves when data is loaded
     */
    loadBootHistory: async function() {
        try {
            if (window.AppState.isOffline) {
                // Use cached data in offline mode
                return;
            }
            
            // Get boot history using WebUIX API
            const cmd = `cat ${window.MODULE_PATH}/logs/boot_history.log`;
            const result = await window.ksu.exec(cmd);
            
            if (result.code === 0) {
                // Parse boot history
                const bootHistory = [];
                const lines = result.stdout.split('\n');
                
                lines.forEach(line => {
                    if (!line.trim()) return;
                    
                    try {
                        const [timestamp, status, duration] = line.split('|').map(item => item.trim());
                        bootHistory.push({
                            timestamp,
                            date: new Date(timestamp),
                            status,
                            duration: parseInt(duration || '0')
                        });
                    } catch (e) {
                        console.error('Failed to parse boot history line:', line, e);
                    }
                });
                
                // Sort by date
                bootHistory.sort((a, b) => b.date - a.date);
                
                // Store in cache
                this.dataCache.bootHistory = bootHistory;
                
                // Save to localStorage for offline mode
                localStorage.setItem('bootHistory', JSON.stringify(bootHistory));
            }
        } catch (error) {
            console.error('Failed to load boot history:', error);
            
            // Try to load from localStorage
            const cachedData = localStorage.getItem('bootHistory');
            if (cachedData) {
                this.dataCache.bootHistory = JSON.parse(cachedData);
            }
        }
    },
    
    /**
     * Load system metrics data
     * @returns {Promise} Promise that resolves when data is loaded
     */
    loadSystemMetrics: async function() {
        try {
            if (window.AppState.isOffline) {
                // Use cached data in offline mode
                return;
            }
            
            // Get system metrics using WebUIX API
            const cmd = `${window.SCRIPTS_PATH}/system-metrics.sh`;
            const result = await window.ksu.exec(cmd);
            
            if (result.code === 0) {
                try {
                    // Parse system metrics JSON
                    const metrics = JSON.parse(result.stdout);
                    
                    // Store in cache
                    this.dataCache.systemMetrics = metrics;
                    
                    // Save to localStorage for offline mode
                    localStorage.setItem('systemMetrics', JSON.stringify(metrics));
                } catch (e) {
                    console.error('Failed to parse system metrics:', e);
                }
            }
        } catch (error) {
            console.error('Failed to load system metrics:', error);
            
            // Try to load from localStorage
            const cachedData = localStorage.getItem('systemMetrics');
            if (cachedData) {
                this.dataCache.systemMetrics = JSON.parse(cachedData);
            }
        }
    },
    
    /**
     * Load disk usage data
     * @returns {Promise} Promise that resolves when data is loaded
     */
    loadDiskUsage: async function() {
        try {
            if (window.AppState.isOffline) {
                // Use cached data in offline mode
                return;
            }
            
            // Get disk usage using WebUIX API
            const cmd = `df -h /data | tail -n 1 | awk '{print $2,$3,$4,$5}'`;
            const result = await window.ksu.exec(cmd);
            
            if (result.code === 0) {
                const [total, used, free, percentage] = result.stdout.trim().split(' ');
                
                const diskUsage = {
                    total,
                    used,
                    free,
                    percentage: percentage ? percentage.replace('%', '') : '0'
                };
                
                // Store in cache
                this.dataCache.diskUsage = diskUsage;
                
                // Update UI
                document.getElementById('disk-total').textContent = diskUsage.total || 'Unknown';
                document.getElementById('disk-used').textContent = diskUsage.used || 'Unknown';
                document.getElementById('disk-free').textContent = diskUsage.free || 'Unknown';
                
                // Update progress bar
                const progressBar = document.querySelector('.disk-usage .progress-bar');
                if (progressBar) {
                    progressBar.style.width = `${diskUsage.percentage}%`;
                    progressBar.setAttribute('data-value', diskUsage.percentage);
                }
                
                // Save to localStorage for offline mode
                localStorage.setItem('diskUsage', JSON.stringify(diskUsage));
            }
        } catch (error) {
            console.error('Failed to load disk usage:', error);
            
            // Try to load from localStorage
            const cachedData = localStorage.getItem('diskUsage');
            if (cachedData) {
                const diskUsage = JSON.parse(cachedData);
                
                // Update UI
                document.getElementById('disk-total').textContent = diskUsage.total || 'Unknown';
                document.getElementById('disk-used').textContent = diskUsage.used || 'Unknown';
                document.getElementById('disk-free').textContent = diskUsage.free || 'Unknown';
                
                // Update progress bar
                const progressBar = document.querySelector('.disk-usage .progress-bar');
                if (progressBar) {
                    progressBar.style.width = `${diskUsage.percentage}%`;
                    progressBar.setAttribute('data-value', diskUsage.percentage);
                }
                
                this.dataCache.diskUsage = diskUsage;
            }
        }
    },
    
    /**
     * Load backup data including sizes and statistics
     * @returns {Promise} Promise that resolves when data is loaded
     */
    loadBackupData: async function() {
        try {
            if (window.AppState.isOffline) {
                // Use cached data in offline mode
                return;
            }
            
            // Get backup sizes using WebUIX API
            const cmd = `ls -la ${window.BACKUP_PATH} | grep -E '\\.tar|\\.zip' | awk '{print $5,$9}'`;
            const result = await window.ksu.exec(cmd);
            
            if (result.code === 0) {
                const backupSizes = [];
                const lines = result.stdout.split('\n');
                
                lines.forEach(line => {
                    if (!line.trim()) return;
                    
                    try {
                        const [size, name] = line.trim().split(' ');
                        backupSizes.push({
                            name,
                            size: parseInt(size),
                            formattedSize: window.UI.formatFileSize(size)
                        });
                    } catch (e) {
                        console.error('Failed to parse backup size line:', line, e);
                    }
                });
                
                // Sort by size (largest first)
                backupSizes.sort((a, b) => b.size - a.size);
                
                // Store in cache
                this.dataCache.backupSizes = backupSizes;
                
                // Save to localStorage for offline mode
                localStorage.setItem('backupSizes', JSON.stringify(backupSizes));
            }
        } catch (error) {
            console.error('Failed to load backup sizes:', error);
            
            // Try to load from localStorage
            const cachedData = localStorage.getItem('backupSizes');
            if (cachedData) {
                this.dataCache.backupSizes = JSON.parse(cachedData);
            }
        }
    },
    
    /**
     * Load activity log data
     * @returns {Promise} Promise that resolves when data is loaded
     */
    loadActivityLog: async function() {
        try {
            if (window.AppState.isOffline) {
                // Use cached data in offline mode
                return;
            }
            
            // Get activity log using WebUIX API
            const cmd = `cat ${window.CONFIG_PATH}/activity_log.json`;
            const result = await window.ksu.exec(cmd);
            
            if (result.code === 0 && result.stdout.trim()) {
                try {
                    // Parse activity log JSON
                    const activityLog = JSON.parse(result.stdout);
                    
                    // Store in cache
                    this.dataCache.activityLog = activityLog;
                    
                    // Update activity log UI
                    this.updateActivityLog(activityLog);
                    
                    // Save to localStorage for offline mode
                    localStorage.setItem('activityLog', JSON.stringify(activityLog));
                } catch (e) {
                    console.error('Failed to parse activity log:', e);
                }
            }
        } catch (error) {
            console.error('Failed to load activity log:', error);
            
            // Try to load from localStorage
            const cachedData = localStorage.getItem('activityLog');
            if (cachedData) {
                const activityLog = JSON.parse(cachedData);
                this.dataCache.activityLog = activityLog;
                this.updateActivityLog(activityLog);
            }
        }
    },
    
    /**
     * Update activity log UI
     * @param {Array} activityLog - Activity log data
     */
    updateActivityLog: function(activityLog) {
        const activityLogContainer = document.querySelector('.activity-log');
        if (!activityLogContainer) return;
        
        if (!activityLog || activityLog.length === 0) {
            activityLogContainer.innerHTML = '<p class="placeholder-text">No recent activity to display</p>';
            return;
        }
        
        // Clear container
        activityLogContainer.innerHTML = '';
        
        // Show most recent activities (up to 10)
        const recentActivities = activityLog.slice(0, 10);
        
        recentActivities.forEach(activity => {
            const activityItem = document.createElement('div');
            activityItem.className = `activity-item ${activity.type}`;
            
            // Get icon based on activity type
            let icon;
            switch (activity.type) {
                case 'backup':
                    icon = 'backup';
                    break;
                case 'restore':
                    icon = 'restore';
                    break;
                case 'safety':
                    icon = 'security';
                    break;
                case 'error':
                    icon = 'error';
                    break;
                case 'warning':
                    icon = 'warning';
                    break;
                default:
                    icon = 'info';
            }
            
            activityItem.innerHTML = `
                <div class="activity-icon">
                    <i class="material-icons">${icon}</i>
                </div>
                <div class="activity-content">
                    <div class="activity-header">
                        <span class="activity-title">${activity.title}</span>
                        <span class="activity-time">${window.UI.formatTimestamp(activity.timestamp)}</span>
                    </div>
                    <p class="activity-description">${activity.description}</p>
                </div>
            `;
            
            activityLogContainer.appendChild(activityItem);
        });
    },
    
    /**
     * Update all dashboard visualizations
     */
    updateVisualizations: function() {
        // Update boot history chart
        this.updateBootHistoryChart();
        
        // Update backup size chart
        this.updateBackupSizeChart();
        
        // Update system metrics gauges
        this.updateSystemMetricsGauges();
        
        // Update protection status
        this.updateProtectionStatus();
        
        // Update system statistics
        this.updateSystemStatistics();
    },
    
    /**
     * Update boot history chart
     */
    updateBootHistoryChart: function() {
        const bootHistoryCanvas = document.getElementById('boot-history-chart');
        if (!bootHistoryCanvas) return;
        
        const bootHistory = this.dataCache.bootHistory;
        if (!bootHistory || bootHistory.length === 0) return;
        
        // Create data for chart
        const labels = [];
        const bootTimes = [];
        const colors = [];
        
        // Get most recent 10 boots
        const recentBoots = bootHistory.slice(0, 10).reverse();
        
        recentBoots.forEach(boot => {
            labels.push(new Date(boot.date).toLocaleDateString());
            bootTimes.push(boot.duration);
            
            // Set color based on boot status
            if (boot.status === 'success') {
                colors.push('#4CAF50'); // Green
            } else if (boot.status === 'recovery') {
                colors.push('#FFC107'); // Yellow
            } else {
                colors.push('#F44336'); // Red
            }
        });
        
        // Check if Chart.js is loaded
        if (typeof Chart === 'undefined') {
            console.error('Chart.js is not loaded, showing placeholder instead');
            bootHistoryCanvas.style.display = 'none';
            const placeholder = document.createElement('div');
            placeholder.className = 'chart-placeholder';
            placeholder.innerHTML = '<p>Charts require internet connection</p><button class="btn small" onclick="location.reload()">Reload</button>';
            bootHistoryCanvas.parentNode.appendChild(placeholder);
            return;
        }
        
        // Create or update chart
        if (this.charts.bootHistory) {
            this.charts.bootHistory.data.labels = labels;
            this.charts.bootHistory.data.datasets[0].data = bootTimes;
            this.charts.bootHistory.data.datasets[0].backgroundColor = colors;
            this.charts.bootHistory.update();
        } else {
            this.charts.bootHistory = new Chart(bootHistoryCanvas, {
                type: 'bar',
                data: {
                    labels: labels,
                    datasets: [{
                        label: 'Boot Time (seconds)',
                        data: bootTimes,
                        backgroundColor: colors,
                        borderColor: colors,
                        borderWidth: 1
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    scales: {
                        y: {
                            beginAtZero: true,
                            title: {
                                display: true,
                                text: 'Boot Time (seconds)'
                            }
                        },
                        x: {
                            title: {
                                display: true,
                                text: 'Boot Date'
                            }
                        }
                    },
                    plugins: {
                        legend: {
                            display: false
                        },
                        tooltip: {
                            callbacks: {
                                title: function(tooltipItems) {
                                    const index = tooltipItems[0].dataIndex;
                                    return `Boot: ${recentBoots[index].timestamp}`;
                                },
                                label: function(context) {
                                    const boot = recentBoots[context.dataIndex];
                                    return [
                                        `Status: ${boot.status}`,
                                        `Duration: ${boot.duration} seconds`
                                    ];
                                }
                            }
                        }
                    }
                }
            });
        }
    },
    
    /**
     * Update backup size chart
     */
    updateBackupSizeChart: function() {
        const backupSizeCanvas = document.getElementById('backup-size-chart');
        if (!backupSizeCanvas) return;
        
        const backupSizes = this.dataCache.backupSizes;
        if (!backupSizes || backupSizes.length === 0) return;
        
        // Create data for chart
        const labels = [];
        const sizes = [];
        const colors = [
            '#3F51B5', '#2196F3', '#03A9F4', '#00BCD4', '#009688', 
            '#4CAF50', '#8BC34A', '#CDDC39', '#FFEB3B', '#FFC107'
        ];
        
        // Get largest 10 backups
        const largestBackups = backupSizes.slice(0, 10);
        
        largestBackups.forEach((backup, index) => {
            labels.push(backup.name);
            sizes.push(backup.size);
        });
        
        // Check if Chart.js is loaded
        if (typeof Chart === 'undefined') {
            console.error('Chart.js is not loaded, showing placeholder instead');
            backupSizeCanvas.style.display = 'none';
            const placeholder = document.createElement('div');
            placeholder.className = 'chart-placeholder';
            placeholder.innerHTML = '<p>Charts require internet connection</p><button class="btn small" onclick="location.reload()">Reload</button>';
            backupSizeCanvas.parentNode.appendChild(placeholder);
            return;
        }
        
        // Create or update chart
        if (this.charts.backupSize) {
            this.charts.backupSize.data.labels = labels;
            this.charts.backupSize.data.datasets[0].data = sizes;
            this.charts.backupSize.update();
        } else {
            this.charts.backupSize = new Chart(backupSizeCanvas, {
                type: 'pie',
                data: {
                    labels: labels,
                    datasets: [{
                        data: sizes,
                        backgroundColor: colors,
                        borderColor: 'rgba(255, 255, 255, 0.5)',
                        borderWidth: 1
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        legend: {
                            position: 'right',
                            labels: {
                                boxWidth: 12
                            }
                        },
                        tooltip: {
                            callbacks: {
                                label: function(context) {
                                    const backup = largestBackups[context.dataIndex];
                                    return `${backup.name}: ${backup.formattedSize}`;
                                }
                            }
                        }
                    }
                }
            });
        }
    },
    
    /**
     * Update system metrics gauges
     */
    updateSystemMetricsGauges: function() {
        const metrics = this.dataCache.systemMetrics;
        if (!metrics) return;
        
        // CPU Usage Gauge
        const cpuGauge = document.getElementById('cpu-gauge');
        if (cpuGauge && metrics.cpu) {
            this.updateGauge(cpuGauge, metrics.cpu.usage, 'CPU');
        }
        
        // Memory Usage Gauge
        const memoryGauge = document.getElementById('memory-gauge');
        if (memoryGauge && metrics.memory) {
            this.updateGauge(memoryGauge, metrics.memory.percentage, 'Memory');
        }
        
        // IO Usage Gauge
        const ioGauge = document.getElementById('io-gauge');
        if (ioGauge && metrics.io) {
            this.updateGauge(ioGauge, metrics.io.usage, 'I/O');
        }
        
        // Battery Level Gauge
        const batteryGauge = document.getElementById('battery-gauge');
        if (batteryGauge && metrics.battery) {
            this.updateGauge(batteryGauge, metrics.battery.level, 'Battery');
        }
    },
    
    /**
     * Update a gauge with new value
     * @param {Element} element - Gauge element
     * @param {number} value - Gauge value (0-100)
     * @param {string} label - Gauge label
     */
    updateGauge: function(element, value, label) {
        // Check if value is a number
        if (isNaN(value)) {
            console.error(`Invalid gauge value for ${label}: ${value}`);
            return;
        }
        
        // Create gauge if it doesn't exist
        if (!element.querySelector('.gauge-inner')) {
            element.innerHTML = `
                <div class="gauge-inner">
                    <div class="gauge-value"></div>
                </div>
                <div class="gauge-label">${label}: <span class="gauge-percentage">0%</span></div>
            `;
        }
        
        // Update gauge value
        const gaugeValue = element.querySelector('.gauge-value');
        const gaugePercentage = element.querySelector('.gauge-percentage');
        
        if (gaugeValue && gaugePercentage) {
            const percentage = Math.min(Math.max(0, value), 100);
            const rotation = percentage / 100 * 180;
            
            gaugeValue.style.transform = `rotate(${rotation}deg)`;
            gaugePercentage.textContent = `${Math.round(percentage)}%`;
            
            // Update color based on value
            if (percentage < 60) {
                gaugeValue.style.backgroundColor = '#4CAF50'; // Green
            } else if (percentage < 80) {
                gaugeValue.style.backgroundColor = '#FFC107'; // Yellow
            } else {
                gaugeValue.style.backgroundColor = '#F44336'; // Red
            }
        }
    },
    
    /**
     * Update protection status
     */
    updateProtectionStatus: function() {
        const protectionStatus = document.getElementById('protection-status');
        if (!protectionStatus) return;
        
        // Get protection status from data
        const systemMetrics = this.dataCache.systemMetrics;
        if (!systemMetrics || !systemMetrics.protection) return;
        
        const status = systemMetrics.protection.status;
        const statusText = systemMetrics.protection.statusText || status;
        
        protectionStatus.textContent = statusText;
        
        // Update status class
        protectionStatus.className = '';
        if (status === 'active') {
            protectionStatus.classList.add('status-active');
        } else if (status === 'inactive') {
            protectionStatus.classList.add('status-inactive');
        } else if (status === 'triggered') {
            protectionStatus.classList.add('status-warning');
        }
    },
    
    /**
     * Update system statistics
     */
    updateSystemStatistics: function() {
        const metrics = this.dataCache.systemMetrics;
        if (!metrics) return;
        
        // Update uptime
        const uptime = document.getElementById('system-uptime');
        if (uptime && metrics.system && metrics.system.uptime) {
            uptime.textContent = metrics.system.uptime;
        }
        
        // Update kernel version
        const kernel = document.getElementById('kernel-version');
        if (kernel && metrics.system && metrics.system.kernel) {
            kernel.textContent = metrics.system.kernel;
        }
        
        // Update boot time
        const bootTime = document.getElementById('last-boot');
        if (bootTime && metrics.system && metrics.system.bootTime) {
            bootTime.textContent = metrics.system.bootTime;
        }
        
        // Update boot count
        const bootCount = document.getElementById('boot-count');
        if (bootCount && metrics.system && metrics.system.bootCount) {
            bootCount.textContent = metrics.system.bootCount;
        }
    },
    
    /**
     * Initialize data browsers with filtering capabilities
     */
    initDataBrowsers: function() {
        // Initialize backup browser
        this.initBackupBrowser();
        
        // Initialize recovery point browser
        this.initRecoveryPointBrowser();
        
        // Initialize log browser
        this.initLogBrowser();
    },
    
    /**
     * Initialize backup browser with filtering
     */
    initBackupBrowser: function() {
        // Set up backup search
        const searchInput = document.getElementById('search-backups');
        if (searchInput) {
            searchInput.addEventListener('input', () => {
                this.filterBackups(searchInput.value);
            });
        }
        
        // Set up backup sorting
        const sortOptions = document.querySelectorAll('.backup-sort-option');
        sortOptions.forEach(option => {
            option.addEventListener('click', () => {
                const sortBy = option.getAttribute('data-sort');
                if (sortBy) {
                    this.sortBackups(sortBy);
                    
                    // Update active sort option
                    sortOptions.forEach(opt => opt.classList.remove('active'));
                    option.classList.add('active');
                }
            });
        });
        
        // Set up backup filtering by type
        const filterChips = document.querySelectorAll('.backup-filter-chip');
        filterChips.forEach(chip => {
            chip.addEventListener('click', () => {
                chip.classList.toggle('active');
                
                // Get active filters
                const activeFilters = [];
                document.querySelectorAll('.backup-filter-chip.active').forEach(activeChip => {
                    const filter = activeChip.getAttribute('data-filter');
                    if (filter) {
                        activeFilters.push(filter);
                    }
                });
                
                this.filterBackupsByType(activeFilters);
            });
        });
    },
    
    /**
     * Filter backups by search term
     * @param {string} searchTerm - Search term
     */
    filterBackups: function(searchTerm) {
        const backupItems = document.querySelectorAll('.backup-item');
        
        searchTerm = searchTerm.toLowerCase();
        
        backupItems.forEach(item => {
            const name = item.querySelector('h4').textContent.toLowerCase();
            const description = item.querySelector('.description')?.textContent.toLowerCase() || '';
            
            if (name.includes(searchTerm) || description.includes(searchTerm)) {
                item.classList.remove('hidden');
            } else {
                item.classList.add('hidden');
            }
        });
        
        // Show "no results" message if all items are hidden
        const backupList = document.querySelector('.backup-list');
        const noResults = backupList.querySelector('.no-results');
        
        if (Array.from(backupItems).every(item => item.classList.contains('hidden'))) {
            if (!noResults) {
                const noResultsMsg = document.createElement('p');
                noResultsMsg.className = 'no-results placeholder-text';
                noResultsMsg.textContent = `No backups found matching "${searchTerm}"`;
                backupList.appendChild(noResultsMsg);
            } else {
                noResults.textContent = `No backups found matching "${searchTerm}"`;
                noResults.classList.remove('hidden');
            }
        } else if (noResults) {
            noResults.classList.add('hidden');
        }
    },
    
    /**
     * Sort backups by property
     * @param {string} sortBy - Property to sort by (name, date, size)
     */
    sortBackups: function(sortBy) {
        const backupList = document.querySelector('.backup-list');
        const backupItems = Array.from(document.querySelectorAll('.backup-item'));
        
        if (backupItems.length === 0) return;
        
        // Sort items
        backupItems.sort((a, b) => {
            if (sortBy === 'name') {
                const nameA = a.querySelector('h4').textContent;
                const nameB = b.querySelector('h4').textContent;
                return nameA.localeCompare(nameB);
            } else if (sortBy === 'date') {
                const dateA = new Date(a.querySelector('p:nth-of-type(1)').textContent.replace('Created: ', ''));
                const dateB = new Date(b.querySelector('p:nth-of-type(1)').textContent.replace('Created: ', ''));
                return dateB - dateA; // Most recent first
            } else if (sortBy === 'size') {
                const sizeA = a.querySelector('p:nth-of-type(2)').textContent.replace('Size: ', '');
                const sizeB = b.querySelector('p:nth-of-type(2)').textContent.replace('Size: ', '');
                return this.compareSizes(sizeB, sizeA); // Largest first
            }
            return 0;
        });
        
        // Reorder items
        backupItems.forEach(item => backupList.appendChild(item));
    },
    
    /**
     * Compare sizes for sorting (handles KB, MB, GB)
     * @param {string} a - First size
     * @param {string} b - Second size
     * @returns {number} Comparison result
     */
    compareSizes: function(a, b) {
        const units = {
            'B': 1,
            'KB': 1024,
            'MB': 1024 * 1024,
            'GB': 1024 * 1024 * 1024,
            'TB': 1024 * 1024 * 1024 * 1024
        };
        
        const regex = /^([\d.]+)\s*([A-Z]+)$/;
        
        const matchA = a.match(regex);
        const matchB = b.match(regex);
        
        if (!matchA || !matchB) return 0;
        
        const valueA = parseFloat(matchA[1]) * (units[matchA[2]] || 1);
        const valueB = parseFloat(matchB[1]) * (units[matchB[2]] || 1);
        
        return valueA - valueB;
    },
    
    /**
     * Filter backups by type
     * @param {Array} types - Backup types to show
     */
    filterBackupsByType: function(types) {
        const backupItems = document.querySelectorAll('.backup-item');
        
        // If no filters selected, show all
        if (types.length === 0) {
            backupItems.forEach(item => {
                item.classList.remove('hidden');
            });
            return;
        }
        
        backupItems.forEach(item => {
            const backupType = item.getAttribute('data-type');
            
            if (types.includes(backupType)) {
                item.classList.remove('hidden');
            } else {
                item.classList.add('hidden');
            }
        });
    },
    
    /**
     * Initialize recovery point browser
     */
    initRecoveryPointBrowser: function() {
        // Similar to backup browser, but for recovery points
        // Implementation would go here
    },
    
    /**
     * Initialize log browser
     */
    initLogBrowser: function() {
        // Log browser implementation
        // Implementation would go here
    },
    
    /**
     * Initialize notification system
     */
    initNotificationSystem: function() {
        // Check for notifications periodically
        this.checkForNotifications();
        
        // Set up notification center
        this.setupNotificationCenter();
        
        // Set up notification badge
        this.setupNotificationBadge();
    },
    
    /**
     * Check for new notifications
     */
    checkForNotifications: async function() {
        try {
            if (window.AppState.isOffline) {
                // Skip in offline mode
                return;
            }
            
            // Get notifications using WebUIX API
            const cmd = `cat ${window.CONFIG_PATH}/notifications.json`;
            const result = await window.ksu.exec(cmd);
            
            if (result.code === 0 && result.stdout.trim()) {
                try {
                    // Parse notifications JSON
                    const notifications = JSON.parse(result.stdout);
                    
                    // Get unseen notifications
                    const unseenNotifications = notifications.filter(n => !n.seen);
                    
                    // Update notification badge
                    this.updateNotificationBadge(unseenNotifications.length);
                    
                    // Show new notifications as toasts
                    this.showNewNotifications(unseenNotifications);
                    
                    // Store notifications in localStorage
                    localStorage.setItem('notifications', JSON.stringify(notifications));
                } catch (e) {
                    console.error('Failed to parse notifications:', e);
                }
            }
        } catch (error) {
            console.error('Failed to check for notifications:', error);
        }
        
        // Check again after 5 minutes
        setTimeout(() => {
            this.checkForNotifications();
        }, 5 * 60 * 1000);
    },
    
    /**
     * Update notification badge
     * @param {number} count - Number of unseen notifications
     */
    updateNotificationBadge: function(count) {
        const badge = document.getElementById('notification-badge');
        if (!badge) return;
        
        if (count > 0) {
            badge.textContent = count > 9 ? '9+' : count;
            badge.classList.remove('hidden');
        } else {
            badge.classList.add('hidden');
        }
    },
    
    /**
     * Show new notifications as toasts
     * @param {Array} notifications - Unseen notifications
     */
    showNewNotifications: function(notifications) {
        if (!notifications || notifications.length === 0) return;
        
        // Get only new notifications (not seen before)
        const seenIds = JSON.parse(localStorage.getItem('seenNotificationIds') || '[]');
        const newNotifications = notifications.filter(n => !seenIds.includes(n.id));
        
        // Show only important notifications as toasts (limit to 3)
        const importantNotifications = newNotifications
            .filter(n => n.priority === 'high')
            .slice(0, 3);
        
        // Show toasts
        importantNotifications.forEach(notification => {
            window.UI.showNotification(notification.message, notification.type, 5000);
            
            // Add to seen list
            seenIds.push(notification.id);
        });
        
        // Update seen list
        localStorage.setItem('seenNotificationIds', JSON.stringify(seenIds));
    },
    
    /**
     * Setup notification center
     */
    setupNotificationCenter: function() {
        // Setup notification center button
        const notificationButton = document.getElementById('notification-button');
        if (notificationButton) {
            notificationButton.addEventListener('click', () => {
                this.toggleNotificationCenter();
            });
        }
    },
    
    /**
     * Toggle notification center
     */
    toggleNotificationCenter: function() {
        let notificationCenter = document.getElementById('notification-center');
        
        if (!notificationCenter) {
            // Create notification center
            notificationCenter = document.createElement('div');
            notificationCenter.id = 'notification-center';
            notificationCenter.className = 'notification-center';
            
            notificationCenter.innerHTML = `
                <div class="notification-center-header">
                    <h3>Notifications</h3>
                    <button class="btn text" id="mark-all-read">Mark all as read</button>
                    <button class="notification-center-close" aria-label="Close">
                        <i class="material-icons">close</i>
                    </button>
                </div>
                <div class="notification-list">
                    <p class="placeholder-text">No notifications</p>
                </div>
            `;
            
            document.body.appendChild(notificationCenter);
            
            // Setup close button
            const closeButton = notificationCenter.querySelector('.notification-center-close');
            closeButton.addEventListener('click', () => {
                notificationCenter.classList.remove('active');
            });
            
            // Setup mark all read button
            const markAllReadButton = notificationCenter.querySelector('#mark-all-read');
            markAllReadButton.addEventListener('click', () => {
                this.markAllNotificationsAsRead();
            });
            
            // Load notifications
            this.loadNotifications();
        }
        
        // Toggle active class
        notificationCenter.classList.toggle('active');
        
        // Mark as seen if opened
        if (notificationCenter.classList.contains('active')) {
            this.markNotificationsAsSeen();
        }
    },
    
    /**
     * Load notifications into notification center
     */
    loadNotifications: function() {
        const notificationList = document.querySelector('.notification-list');
        if (!notificationList) return;
        
        // Get notifications from localStorage
        const notificationsJson = localStorage.getItem('notifications');
        if (!notificationsJson) {
            notificationList.innerHTML = '<p class="placeholder-text">No notifications</p>';
            return;
        }
        
        const notifications = JSON.parse(notificationsJson);
        
        if (notifications.length === 0) {
            notificationList.innerHTML = '<p class="placeholder-text">No notifications</p>';
            return;
        }
        
        // Clear list
        notificationList.innerHTML = '';
        
        // Add notifications to list
        notifications.forEach(notification => {
            const notificationItem = document.createElement('div');
            notificationItem.className = `notification-item ${notification.seen ? 'seen' : ''} ${notification.type}`;
            notificationItem.setAttribute('data-id', notification.id);
            
            // Get icon based on type
            let icon;
            switch (notification.type) {
                case 'success':
                    icon = 'check_circle';
                    break;
                case 'warning':
                    icon = 'warning';
                    break;
                case 'error':
                    icon = 'error';
                    break;
                default:
                    icon = 'info';
            }
            
            notificationItem.innerHTML = `
                <div class="notification-item-icon">
                    <i class="material-icons">${icon}</i>
                </div>
                <div class="notification-item-content">
                    <div class="notification-item-header">
                        <span class="notification-item-title">${notification.title}</span>
                        <span class="notification-item-time">${window.UI.formatTimestamp(notification.timestamp)}</span>
                    </div>
                    <p class="notification-item-message">${notification.message}</p>
                    ${notification.action ? `
                        <button class="btn small" data-action="${notification.action}">
                            ${notification.actionText || 'View'}
                        </button>
                    ` : ''}
                </div>
            `;
            
            // Add click handler for action button
            const actionButton = notificationItem.querySelector('[data-action]');
            if (actionButton) {
                actionButton.addEventListener('click', (e) => {
                    e.stopPropagation();
                    this.handleNotificationAction(notification.action, notification);
                });
            }
            
            notificationList.appendChild(notificationItem);
        });
    },
    
    /**
     * Mark all notifications as seen
     */
    markNotificationsAsSeen: function() {
        // Get notifications from localStorage
        const notificationsJson = localStorage.getItem('notifications');
        if (!notificationsJson) return;
        
        const notifications = JSON.parse(notificationsJson);
        
        // Mark all as seen
        let updated = false;
        notifications.forEach(notification => {
            if (!notification.seen) {
                notification.seen = true;
                updated = true;
            }
        });
        
        if (updated) {
            // Update localStorage
            localStorage.setItem('notifications', JSON.stringify(notifications));
            
            // Update badge
            this.updateNotificationBadge(0);
            
            // Update notification list items
            document.querySelectorAll('.notification-item').forEach(item => {
                item.classList.add('seen');
            });
        }
    },
    
    /**
     * Mark all notifications as read
     */
    markAllNotificationsAsRead: async function() {
        // Get notifications from localStorage
        const notificationsJson = localStorage.getItem('notifications');
        if (!notificationsJson) return;
        
        let notifications = JSON.parse(notificationsJson);
        
        // Mark all as read (remove from list)
        notifications = [];
        
        // Update localStorage
        localStorage.setItem('notifications', JSON.stringify(notifications));
        
        // Update badge
        this.updateNotificationBadge(0);
        
        // Update notification list
        const notificationList = document.querySelector('.notification-list');
        if (notificationList) {
            notificationList.innerHTML = '<p class="placeholder-text">No notifications</p>';
        }
        
        try {
            if (!window.AppState.isOffline) {
                // Clear notifications on server
                await window.ksu.exec(`echo '[]' > ${window.CONFIG_PATH}/notifications.json`);
            }
        } catch (error) {
            console.error('Failed to clear notifications on server:', error);
        }
    },
    
    /**
     * Handle notification action
     * @param {string} action - Action to perform
     * @param {Object} notification - Notification object
     */
    handleNotificationAction: function(action, notification) {
        console.log(`Handling notification action: ${action}`, notification);
        
        // Handle different actions
        switch (action) {
            case 'view_backup':
                // Navigate to backups page
                window.UI.navigateTo('backups');
                break;
            case 'view_safety':
                // Navigate to safety page
                window.UI.navigateTo('safety');
                break;
            case 'view_settings':
                // Navigate to settings page
                window.UI.navigateTo('settings');
                break;
            case 'test_protection':
                // Test bootloop protection
                window.testBootloopProtection();
                break;
            case 'create_backup':
                // Create backup
                window.showCreateBackupModal();
                break;
            case 'view_logs':
                // Show logs
                this.showLogViewer();
                break;
            default:
                console.log(`Unknown notification action: ${action}`);
        }
        
        // Close notification center
        const notificationCenter = document.getElementById('notification-center');
        if (notificationCenter) {
            notificationCenter.classList.remove('active');
        }
    },
    
    /**
     * Setup notification badge
     */
    setupNotificationBadge: function() {
        // Create notification badge if it doesn't exist
        const notificationButton = document.getElementById('notification-button');
        if (notificationButton && !document.getElementById('notification-badge')) {
            const badge = document.createElement('span');
            badge.id = 'notification-badge';
            badge.className = 'notification-badge hidden';
            notificationButton.appendChild(badge);
        }
    },
    
    /**
     * Show log viewer
     */
    showLogViewer: function() {
        // Implementation would go here
    }
};

// Initialize dashboard when document is loaded
document.addEventListener('DOMContentLoaded', () => {
    // Check if Chart.js is already loaded
    if (typeof Chart !== 'undefined') {
        console.log('Chart.js already loaded');
        DashboardController.init();
    } else {
        // Add Chart.js script dynamically
        const chartScript = document.createElement('script');
        chartScript.src = 'https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.js';
        chartScript.onload = () => {
            console.log('Chart.js loaded successfully');
            // Wait a bit for Chart.js to initialize
            setTimeout(() => {
                DashboardController.init();
            }, 100);
        };
        chartScript.onerror = (error) => {
            console.error('Failed to load Chart.js:', error);
            // Initialize without charts
            DashboardController.init();
        };
        document.head.appendChild(chartScript);
    }
    
    // Expose dashboard controller globally
    window.Dashboard = DashboardController;
});