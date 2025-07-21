/**
 * KernelSU Anti-Bootloop & Backup Module
 * UI-specific functionality for WebUIX interface
 * 
 * Material Design 3 implementation with WebUIX integration
 */

// UI Controller
const UIController = {
    // Theme constants
    themes: {
        LIGHT: 'light',
        DARK: 'dark',
        AUTO: 'auto'
    },

    // Material Design color tokens
    colorTokens: {
        primary: '--md-sys-color-primary',
        onPrimary: '--md-sys-color-on-primary',
        primaryContainer: '--md-sys-color-primary-container',
        onPrimaryContainer: '--md-sys-color-on-primary-container',
        secondary: '--md-sys-color-secondary',
        onSecondary: '--md-sys-color-on-secondary',
        secondaryContainer: '--md-sys-color-secondary-container',
        onSecondaryContainer: '--md-sys-color-on-secondary-container',
        tertiary: '--md-sys-color-tertiary',
        onTertiary: '--md-sys-color-on-tertiary',
        tertiaryContainer: '--md-sys-color-tertiary-container',
        onTertiaryContainer: '--md-sys-color-on-tertiary-container',
        error: '--md-sys-color-error',
        onError: '--md-sys-color-on-error',
        errorContainer: '--md-sys-color-error-container',
        onErrorContainer: '--md-sys-color-on-error-container',
        background: '--md-sys-color-background',
        onBackground: '--md-sys-color-on-background',
        surface: '--md-sys-color-surface',
        onSurface: '--md-sys-color-on-surface',
        surfaceVariant: '--md-sys-color-surface-variant',
        onSurfaceVariant: '--md-sys-color-on-surface-variant',
        outline: '--md-sys-color-outline',
        outlineVariant: '--md-sys-color-outline-variant',
        shadow: '--md-sys-color-shadow',
        scrim: '--md-sys-color-scrim',
        inverseSurface: '--md-sys-color-inverse-surface',
        inverseOnSurface: '--md-sys-color-inverse-on-surface',
        inversePrimary: '--md-sys-color-inverse-primary'
    },

    // Navigation menu items
    navigationItems: [
        { id: 'dashboard', icon: 'dashboard', label: 'Dashboard' },
        { id: 'backups', icon: 'backup', label: 'Backups' },
        { id: 'safety', icon: 'security', label: 'Safety' },
        { id: 'settings', icon: 'settings', label: 'Settings' }
    ],

    /**
     * Initialize UI
     */
    init: function() {
        console.log('Initializing UI with Material Design 3...');
        
        // Initialize ripple effect for all interactive elements
        this.initRippleEffect();
        
        // Initialize theme
        this.initTheme();
        
        // Initialize bottom navigation
        this.initBottomNavigation();
        
        // Initialize modals
        this.setupModalHandlers();
        
        // Initialize custom UI components
        this.initCustomComponents();
        
        // Initialize WebUIX integration
        this.initWebUIXIntegration();
    },
    
    /**
     * Initialize WebUIX integration
     */
    initWebUIXIntegration: function() {
        // Check if WebUIX APIs are available
        const isWebUIXAvailable = typeof ksu !== 'undefined' && ksu;
        
        // Update UI based on WebUIX availability
        document.body.classList.toggle('webuix-available', isWebUIXAvailable);
        
        if (isWebUIXAvailable) {
            console.log('WebUIX APIs available - enabling advanced features');
            
            // Enable WebUIX-specific UI elements
            document.querySelectorAll('.webuix-feature').forEach(el => {
                el.classList.remove('hidden');
            });
            
            // Setup WebUIX toast integration
            window.showToast = function(message, duration) {
                ksu.toast(message);
            };
        } else {
            console.log('WebUIX APIs not available - using fallback features');
            
            // Hide WebUIX-specific UI elements
            document.querySelectorAll('.webuix-feature').forEach(el => {
                el.classList.add('hidden');
            });
            
            // Setup fallback toast
            window.showToast = this.showNotification;
        }
    },
    
    /**
     * Initialize Material Design ripple effect
     */
    initRippleEffect: function() {
        // Add ripple effect to buttons
        document.querySelectorAll('.btn, .icon-button, .nav-item, .bottom-nav-item').forEach(button => {
            // Skip if already initialized
            if (button.classList.contains('ripple-initialized')) return;
            
            // Add ripple container if not present
            if (!button.querySelector('.ripple-container')) {
                const rippleContainer = document.createElement('span');
                rippleContainer.className = 'ripple-container';
                button.appendChild(rippleContainer);
            }
            
            // Add click event listener
            button.addEventListener('click', this.createRippleEffect);
            
            // Mark as initialized
            button.classList.add('ripple-initialized');
        });
    },
    
    /**
     * Create ripple effect on element click
     * @param {Event} event - Click event
     */
    createRippleEffect: function(event) {
        const button = this;
        const rippleContainer = button.querySelector('.ripple-container');
        
        if (!rippleContainer) return;
        
        // Remove existing ripples
        const existingRipples = rippleContainer.querySelectorAll('.ripple');
        existingRipples.forEach(ripple => {
            if (ripple.animationEnd) {
                ripple.remove();
            }
        });
        
        // Create ripple element
        const circle = document.createElement('span');
        circle.className = 'ripple';
        
        // Get ripple size (should be at least as large as the button)
        const diameter = Math.max(button.clientWidth, button.clientHeight);
        const radius = diameter / 2;
        
        // Position the ripple
        const rect = button.getBoundingClientRect();
        const left = event.clientX - rect.left - radius;
        const top = event.clientY - rect.top - radius;
        
        // Set ripple style
        circle.style.width = circle.style.height = `${diameter}px`;
        circle.style.left = `${left}px`;
        circle.style.top = `${top}px`;
        
        // Add ripple to container
        rippleContainer.appendChild(circle);
        
        // Remove ripple after animation
        setTimeout(() => {
            circle.animationEnd = true;
            circle.remove();
        }, 600);
    },
    
    /**
     * Initialize theme
     */
    initTheme: function() {
        // Theme toggle button
        const themeToggle = document.getElementById('theme-toggle');
        if (themeToggle) {
            themeToggle.addEventListener('click', () => {
                this.cycleTheme();
            });
        }
        
        // Apply initial theme
        this.applyTheme();
        
        // Update theme toggle UI
        this.updateThemeToggleUI();
    },
    
    /**
     * Apply theme based on preference
     */
    applyTheme: function() {
        // Get theme preference
        const savedTheme = localStorage.getItem('themePreference') || this.themes.AUTO;
        
        // Apply theme
        if (savedTheme === this.themes.AUTO) {
            // Use system preference
            const prefersDarkMode = window.matchMedia('(prefers-color-scheme: dark)').matches;
            document.documentElement.setAttribute('data-theme', prefersDarkMode ? this.themes.DARK : this.themes.LIGHT);
            
            // Set up listener for system theme changes
            window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', e => {
                if (localStorage.getItem('themePreference') === this.themes.AUTO) {
                    document.documentElement.setAttribute('data-theme', e.matches ? this.themes.DARK : this.themes.LIGHT);
                }
            });
        } else {
            // Use saved preference
            document.documentElement.setAttribute('data-theme', savedTheme);
        }
    },
    
    /**
     * Cycle through theme options
     */
    cycleTheme: function() {
        const currentTheme = localStorage.getItem('themePreference') || this.themes.AUTO;
        let newTheme;
        
        // Cycle: auto -> light -> dark -> auto
        switch (currentTheme) {
            case this.themes.AUTO:
                newTheme = this.themes.LIGHT;
                break;
            case this.themes.LIGHT:
                newTheme = this.themes.DARK;
                break;
            case this.themes.DARK:
                newTheme = this.themes.AUTO;
                break;
            default:
                newTheme = this.themes.AUTO;
        }
        
        // Save preference
        localStorage.setItem('themePreference', newTheme);
        
        // Apply new theme
        this.applyTheme();
        
        // Update theme toggle UI
        this.updateThemeToggleUI();
        
        // Show notification
        this.showNotification(`Theme set to ${newTheme} mode`, 'info');
    },
    
    /**
     * Update theme toggle button UI
     */
    updateThemeToggleUI: function() {
        const themeToggle = document.getElementById('theme-toggle');
        if (!themeToggle) return;
        
        const currentTheme = localStorage.getItem('themePreference') || this.themes.AUTO;
        
        // Update button icon and title
        switch (currentTheme) {
            case this.themes.AUTO:
                themeToggle.innerHTML = '<i class="material-icons">brightness_auto</i>';
                themeToggle.setAttribute('title', 'Auto theme (system preference)');
                break;
            case this.themes.LIGHT:
                themeToggle.innerHTML = '<i class="material-icons">brightness_5</i>';
                themeToggle.setAttribute('title', 'Light theme');
                break;
            case this.themes.DARK:
                themeToggle.innerHTML = '<i class="material-icons">brightness_4</i>';
                themeToggle.setAttribute('title', 'Dark theme');
                break;
        }
    },
    
    /**
     * Initialize bottom navigation
     */
    initBottomNavigation: function() {
        const bottomNav = document.getElementById('bottom-nav');
        if (!bottomNav) {
            // Create bottom navigation if it doesn't exist
            this.createBottomNavigation();
        } else {
            // Setup existing bottom navigation
            this.setupBottomNavigation();
        }
    },
    
    /**
     * Create bottom navigation
     */
    createBottomNavigation: function() {
        // Create bottom navigation container
        const bottomNav = document.createElement('nav');
        bottomNav.id = 'bottom-nav';
        bottomNav.className = 'bottom-navigation';
        
        // Create navigation items
        let navItemsHTML = '';
        this.navigationItems.forEach(item => {
            navItemsHTML += `
                <div class="bottom-nav-item" data-page="${item.id}">
                    <i class="material-icons">${item.icon}</i>
                    <span>${item.label}</span>
                    <span class="ripple-container"></span>
                </div>
            `;
        });
        
        // Set navigation items
        bottomNav.innerHTML = navItemsHTML;
        
        // Add to body
        document.body.appendChild(bottomNav);
        
        // Setup navigation
        this.setupBottomNavigation();
    },
    
    /**
     * Setup bottom navigation
     */
    setupBottomNavigation: function() {
        const bottomNav = document.getElementById('bottom-nav');
        if (!bottomNav) return;
        
        // Get navigation items
        const navItems = bottomNav.querySelectorAll('.bottom-nav-item');
        
        // Add click event listeners
        navItems.forEach(item => {
            item.addEventListener('click', () => {
                const page = item.getAttribute('data-page');
                if (page) {
                    // Navigate to page
                    this.navigateTo(page);
                    
                    // Update active item
                    this.updateActiveNavItem(page);
                }
            });
        });
        
        // Initialize with current page
        const currentPage = document.querySelector('.page.active')?.id || 'dashboard';
        this.updateActiveNavItem(currentPage);
    },
    
    /**
     * Update active navigation item
     * @param {string} pageId - Page ID
     */
    updateActiveNavItem: function(pageId) {
        // Update bottom navigation
        const bottomNav = document.getElementById('bottom-nav');
        if (bottomNav) {
            const navItems = bottomNav.querySelectorAll('.bottom-nav-item');
            navItems.forEach(item => {
                item.classList.toggle('active', item.getAttribute('data-page') === pageId);
            });
        }
        
        // Update main navigation
        const mainNav = document.querySelector('.main-nav');
        if (mainNav) {
            const navLinks = mainNav.querySelectorAll('a');
            navLinks.forEach(link => {
                link.classList.toggle('active', link.getAttribute('data-page') === pageId);
            });
        }
    },
    
    /**
     * Navigate to specific page
     * @param {string} pageId - Page ID
     * @param {boolean} skipPushState - Skip push state if true
     */
    navigateTo: function(pageId, skipPushState) {
        // Hide all pages
        const pages = document.querySelectorAll('.page');
        pages.forEach(page => page.classList.remove('active'));
        
        // Show selected page
        const activePage = document.getElementById(pageId);
        if (activePage) {
            // Add active class
            activePage.classList.add('active');
            
            // Update URL without reload
            if (!skipPushState) {
                history.pushState({ page: pageId }, '', `#${pageId}`);
            }
            
            // Update navigation
            this.updateActiveNavItem(pageId);
            
            // Animate page transition
            this.animatePageTransition(activePage);
            
            // Trigger page-specific loading
            const event = new CustomEvent('page-activated', { detail: { pageId } });
            document.dispatchEvent(event);
        }
    },
    
    /**
     * Animate page transition
     * @param {Element} page - Page element
     */
    animatePageTransition: function(page) {
        // Add transition class
        page.classList.add('page-transition');
        
        // Remove transition class after animation
        setTimeout(() => {
            page.classList.remove('page-transition');
        }, 300);
    },
    
    /**
     * Initialize custom UI components
     */
    initCustomComponents: function() {
        // Initialize custom UI components
        this.initCards();
        this.initFabs();
        this.initChips();
        this.initSwitches();
        this.initSliders();
        this.initProgressBars();
        this.initBackupActionCards();
    },
    
    /**
     * Initialize cards
     */
    initCards: function() {
        // Add click event listeners to card actions
        document.querySelectorAll('.card-action').forEach(action => {
            action.addEventListener('click', (e) => {
                e.stopPropagation();
            });
        });
        
        // Add click event listeners to expandable cards
        document.querySelectorAll('.card.expandable').forEach(card => {
            const header = card.querySelector('.card-header');
            if (header) {
                header.addEventListener('click', () => {
                    card.classList.toggle('expanded');
                });
            }
        });
    },
    
    /**
     * Initialize floating action buttons
     */
    initFabs: function() {
        // Add click event listeners to FAB
        document.querySelectorAll('.fab').forEach(fab => {
            fab.addEventListener('click', () => {
                // Handle FAB click
                const action = fab.getAttribute('data-action');
                if (action) {
                    this.handleFabAction(action);
                }
            });
        });
        
        // Initialize speed dial FABs
        document.querySelectorAll('.fab-speed-dial').forEach(speedDial => {
            const mainButton = speedDial.querySelector('.fab-main');
            if (mainButton) {
                mainButton.addEventListener('click', () => {
                    speedDial.classList.toggle('active');
                });
            }
            
            // Add click event listeners to mini FABs
            speedDial.querySelectorAll('.fab-mini').forEach(miniFab => {
                miniFab.addEventListener('click', () => {
                    // Handle mini FAB click
                    const action = miniFab.getAttribute('data-action');
                    if (action) {
                        this.handleFabAction(action);
                        speedDial.classList.remove('active');
                    }
                });
            });
        });
    },
    
    /**
     * Handle FAB action
     * @param {string} action - Action name
     */
    handleFabAction: function(action) {
        switch (action) {
            case 'create-backup':
                window.showCreateBackupModal();
                break;
            case 'quick-backup':
                window.createQuickBackup();
                break;
            case 'create-recovery-point':
                window.createRecoveryPoint();
                break;
            default:
                console.log(`Unknown FAB action: ${action}`);
        }
    },
    
    /**
     * Initialize chips
     */
    initChips: function() {
        // Add click event listeners to chips
        document.querySelectorAll('.chip').forEach(chip => {
            // Skip if already initialized
            if (chip.classList.contains('chip-initialized')) return;
            
            // Set up close button if it's closable
            if (chip.classList.contains('closable')) {
                const closeButton = document.createElement('span');
                closeButton.className = 'chip-close';
                closeButton.innerHTML = '&times;';
                closeButton.addEventListener('click', (e) => {
                    e.stopPropagation();
                    chip.remove();
                });
                chip.appendChild(closeButton);
            }
            
            // Set up click handler
            chip.addEventListener('click', () => {
                // Toggle active state for selectable chips
                if (chip.classList.contains('selectable')) {
                    chip.classList.toggle('active');
                }
                
                // Handle chip click
                const action = chip.getAttribute('data-action');
                if (action) {
                    // Fire event with chip data
                    const event = new CustomEvent('chip-action', { 
                        detail: { 
                            action, 
                            id: chip.getAttribute('data-id'),
                            value: chip.getAttribute('data-value')
                        }
                    });
                    document.dispatchEvent(event);
                }
            });
            
            // Mark as initialized
            chip.classList.add('chip-initialized');
        });
    },
    
    /**
     * Initialize switches
     */
    initSwitches: function() {
        // Add click event listeners to switches
        document.querySelectorAll('.switch-container').forEach(container => {
            const switchInput = container.querySelector('input[type="checkbox"]');
            const switchLabel = container.querySelector('.switch-label');
            
            if (switchInput && switchLabel) {
                switchLabel.addEventListener('click', () => {
                    switchInput.checked = !switchInput.checked;
                    
                    // Trigger change event
                    const event = new Event('change');
                    switchInput.dispatchEvent(event);
                });
            }
        });
    },
    
    /**
     * Initialize sliders
     */
    initSliders: function() {
        // Initialize range sliders
        document.querySelectorAll('.slider-container').forEach(container => {
            const slider = container.querySelector('input[type="range"]');
            const valueDisplay = container.querySelector('.slider-value');
            
            if (slider && valueDisplay) {
                // Update value display on input
                slider.addEventListener('input', () => {
                    valueDisplay.textContent = slider.value;
                });
                
                // Initialize value display
                valueDisplay.textContent = slider.value;
            }
        });
    },
    
    /**
     * Initialize progress bars
     */
    initProgressBars: function() {
        // Initialize determinate progress bars
        document.querySelectorAll('.progress-bar.determinate').forEach(progressBar => {
            const value = progressBar.getAttribute('data-value') || 0;
            progressBar.style.width = `${value}%`;
        });
    },
    
    /**
     * Initialize backup action cards
     */
    initBackupActionCards: function() {
        // Create backup action cards if not present
        if (!document.querySelector('.backup-action-card')) {
            this.createBackupActionCards();
        }
        
        // Add click event listeners to backup action cards
        document.querySelectorAll('.backup-action-card').forEach(card => {
            card.addEventListener('click', () => {
                const action = card.getAttribute('data-action');
                if (action) {
                    this.handleBackupActionCard(action);
                }
            });
        });
    },
    
    /**
     * Create backup action cards
     */
    createBackupActionCards: function() {
        // Get backup actions container
        const actionsContainer = document.querySelector('.backup-actions-container');
        if (!actionsContainer) return;
        
        // Define action cards
        const actionCards = [
            {
                action: 'create-backup',
                icon: 'backup',
                title: 'Create Backup',
                description: 'Create a full system backup'
            },
            {
                action: 'create-recovery-point',
                icon: 'restore',
                title: 'Recovery Point',
                description: 'Create a bootloop recovery point'
            },
            {
                action: 'schedule-backup',
                icon: 'schedule',
                title: 'Schedule Backup',
                description: 'Set up automatic backups'
            },
            {
                action: 'test-protection',
                icon: 'security',
                title: 'Test Protection',
                description: 'Test bootloop protection'
            }
        ];
        
        // Create cards
        actionCards.forEach(card => {
            const cardElement = document.createElement('div');
            cardElement.className = 'backup-action-card';
            cardElement.setAttribute('data-action', card.action);
            cardElement.innerHTML = `
                <div class="action-card-icon">
                    <i class="material-icons">${card.icon}</i>
                </div>
                <div class="action-card-content">
                    <h3>${card.title}</h3>
                    <p>${card.description}</p>
                </div>
                <span class="ripple-container"></span>
            `;
            actionsContainer.appendChild(cardElement);
        });
        
        // Initialize ripple effect
        this.initRippleEffect();
    },
    
    /**
     * Handle backup action card
     * @param {string} action - Action name
     */
    handleBackupActionCard: function(action) {
        switch (action) {
            case 'create-backup':
                window.showCreateBackupModal();
                break;
            case 'create-recovery-point':
                window.createRecoveryPoint();
                break;
            case 'schedule-backup':
                this.showScheduleBackupModal();
                break;
            case 'test-protection':
                window.testBootloopProtection();
                break;
            default:
                console.log(`Unknown action card: ${action}`);
        }
    },
    
    /**
     * Show schedule backup modal
     */
    showScheduleBackupModal: function() {
        const content = `
            <div class="form-group">
                <label for="schedule-enabled">Enable Scheduled Backups:</label>
                <div class="switch-container">
                    <input type="checkbox" id="schedule-enabled" ${window.AppState?.settings?.autoBackup ? 'checked' : ''}>
                    <label class="switch-label" for="schedule-enabled"></label>
                </div>
            </div>
            <div class="form-group">
                <label for="schedule-frequency">Backup Frequency:</label>
                <select id="schedule-frequency" class="md-select">
                    <option value="daily" ${window.AppState?.settings?.backupSchedule === 'daily' ? 'selected' : ''}>Daily</option>
                    <option value="weekly" ${window.AppState?.settings?.backupSchedule === 'weekly' ? 'selected' : ''}>Weekly</option>
                    <option value="monthly" ${window.AppState?.settings?.backupSchedule === 'monthly' ? 'selected' : ''}>Monthly</option>
                </select>
            </div>
            <div class="form-group">
                <label for="schedule-time">Backup Time:</label>
                <input type="time" id="schedule-time" value="03:00" class="md-input">
            </div>
            <div class="form-group checkbox-group">
                <label>
                    <input type="checkbox" id="schedule-notification" checked>
                    Show notification when backup starts
                </label>
            </div>
        `;
        
        this.showModal('Schedule Backups', content, () => {
            const enabled = document.getElementById('schedule-enabled').checked;
            const frequency = document.getElementById('schedule-frequency').value;
            const time = document.getElementById('schedule-time').value;
            const notification = document.getElementById('schedule-notification').checked;
            
            // Save schedule settings
            if (window.AppState && window.AppState.settings) {
                window.AppState.settings.autoBackup = enabled;
                window.AppState.settings.backupSchedule = frequency;
                window.AppState.settings.backupTime = time;
                window.AppState.settings.backupNotification = notification;
                
                // Save settings
                if (typeof window.saveSettings === 'function') {
                    window.saveSettings();
                }
            }
            
            this.closeModal();
        });
    },
    
    /**
     * Show notification
     * @param {string} message - Notification message
     * @param {string} type - Notification type (info, success, warning, error)
     * @param {number} duration - Duration in milliseconds
     */
    showNotification: function(message, type, duration) {
        if (!type) type = 'info';
        if (!duration) duration = 3000;
        
        // Check if notification container exists, create if not
        let notificationContainer = document.querySelector('.notification-container');
        
        if (!notificationContainer) {
            notificationContainer = document.createElement('div');
            notificationContainer.className = 'notification-container';
            document.body.appendChild(notificationContainer);
        }
        
        // Create notification element
        const notification = document.createElement('div');
        notification.className = `notification ${type}`;
        
        // Get icon based on type
        let icon;
        switch (type) {
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
        
        // Set notification content
        notification.innerHTML = `
            <div class="notification-content">
                <i class="material-icons notification-icon">${icon}</i>
                <span class="notification-message">${message}</span>
            </div>
            <button class="notification-close" aria-label="Close">
                <i class="material-icons">close</i>
            </button>
        `;
        
        // Add to container
        notificationContainer.appendChild(notification);
        
        // Setup close button
        const closeButton = notification.querySelector('.notification-close');
        closeButton.addEventListener('click', () => {
            notification.classList.add('notification-hiding');
            setTimeout(() => {
                notification.remove();
            }, 300);
        });
        
        // Auto-remove after duration
        setTimeout(() => {
            // Only remove if notification still exists
            if (notification.parentNode) {
                notification.classList.add('notification-hiding');
                setTimeout(() => {
                    if (notification.parentNode) {
                        notification.remove();
                    }
                }, 300);
            }
        }, duration);
    },
    
    /**
     * Setup modal handlers
     */
    setupModalHandlers: function() {
        // Get modal elements
        const modal = document.getElementById('modal-container');
        const closeButton = document.querySelector('.modal-close');
        const cancelButton = document.getElementById('modal-cancel');
        
        // Close modal on close button click
        if (closeButton) {
            closeButton.addEventListener('click', () => {
                this.closeModal();
            });
        }
        
        // Close modal on cancel button click
        if (cancelButton) {
            cancelButton.addEventListener('click', () => {
                this.closeModal();
            });
        }
        
        // Close modal on click outside modal content
        if (modal) {
            modal.addEventListener('click', (e) => {
                if (e.target === modal) {
                    this.closeModal();
                }
            });
        }
        
        // Create modal if it doesn't exist
        if (!modal) {
            this.createModal();
        }
    },
    
    /**
     * Create modal
     */
    createModal: function() {
        // Create modal container
        const modal = document.createElement('div');
        modal.id = 'modal-container';
        modal.className = 'modal';
        
        // Create modal content
        modal.innerHTML = `
            <div class="modal-content">
                <div class="modal-header">
                    <h2 class="modal-title">Modal Title</h2>
                    <button class="modal-close" aria-label="Close">
                        <i class="material-icons">close</i>
                    </button>
                </div>
                <div class="modal-body">
                    Modal content goes here
                </div>
                <div class="modal-footer">
                    <button id="modal-cancel" class="btn">Cancel</button>
                    <button id="modal-confirm" class="btn primary">Confirm</button>
                </div>
            </div>
        `;
        
        // Add to body
        document.body.appendChild(modal);
        
        // Setup modal handlers
        this.setupModalHandlers();
    },
    
    /**
     * Show modal
     * @param {string} title - Modal title
     * @param {string} content - Modal content HTML
     * @param {Function} confirmCallback - Callback for confirm button
     */
    showModal: function(title, content, confirmCallback) {
        const modal = document.getElementById('modal-container');
        const modalTitle = document.querySelector('.modal-title');
        const modalBody = document.querySelector('.modal-body');
        const modalConfirm = document.getElementById('modal-confirm');
        
        if (!modal || !modalTitle || !modalBody) {
            console.error('Modal elements not found');
            this.createModal();
            return this.showModal(title, content, confirmCallback);
        }
        
        // Set modal content
        modalTitle.textContent = title;
        modalBody.innerHTML = content;
        
        // Set confirm callback
        if (modalConfirm && confirmCallback) {
            modalConfirm.onclick = confirmCallback;
        }
        
        // Show modal
        modal.style.display = 'block';
        
        // Add active class for animation
        setTimeout(() => {
            modal.classList.add('active');
        }, 10);
        
        // Initialize form elements in modal
        setTimeout(() => {
            this.initSwitches();
            this.initSliders();
            this.initRippleEffect();
        }, 100);
    },
    
    /**
     * Close modal
     */
    closeModal: function() {
        const modal = document.getElementById('modal-container');
        
        if (!modal) {
            return;
        }
        
        // Remove active class for animation
        modal.classList.remove('active');
        
        // Hide modal after animation
        setTimeout(() => {
            modal.style.display = 'none';
        }, 300);
    },
    
    /**
     * Create loading indicator
     * @param {string} message - Loading message
     * @returns {Object} Loading indicator object
     */
    createLoader: function(message) {
        if (!message) message = 'Loading...';
        
        // Create loader container
        const loaderContainer = document.createElement('div');
        loaderContainer.className = 'loader-container';
        
        // Create loader
        loaderContainer.innerHTML = `
            <div class="loader-content">
                <div class="loader-spinner"></div>
                <div class="loader-message">${message}</div>
            </div>
        `;
        
        // Add to body
        document.body.appendChild(loaderContainer);
        
        // Add active class for animation
        setTimeout(() => {
            loaderContainer.classList.add('active');
        }, 10);
        
        // Return loader object
        return {
            element: loaderContainer,
            
            // Update message
            updateMessage: function(newMessage) {
                const messageElement = loaderContainer.querySelector('.loader-message');
                if (messageElement) {
                    messageElement.textContent = newMessage;
                }
            },
            
            // Update progress (0-100)
            updateProgress: function(progress) {
                let progressBar = loaderContainer.querySelector('.loader-progress');
                
                // Create progress bar if it doesn't exist
                if (!progressBar) {
                    progressBar = document.createElement('div');
                    progressBar.className = 'loader-progress';
                    
                    const progressInner = document.createElement('div');
                    progressInner.className = 'loader-progress-inner';
                    progressBar.appendChild(progressInner);
                    
                    const loaderContent = loaderContainer.querySelector('.loader-content');
                    loaderContent.appendChild(progressBar);
                }
                
                // Update progress
                const progressInner = progressBar.querySelector('.loader-progress-inner');
                if (progressInner) {
                    progressInner.style.width = `${progress}%`;
                }
            },
            
            // Remove loader
            remove: function() {
                loaderContainer.classList.remove('active');
                setTimeout(() => {
                    if (loaderContainer.parentNode) {
                        loaderContainer.remove();
                    }
                }, 300);
            }
        };
    },
    
    /**
     * Format timestamp to human-readable date/time
     * @param {string} timestamp - Timestamp string
     * @returns {string} Formatted date/time
     */
    formatTimestamp: function(timestamp) {
        if (!timestamp) return 'Unknown';
        
        try {
            const date = new Date(timestamp);
            return date.toLocaleString();
        } catch (error) {
            return timestamp;
        }
    },
    
    /**
     * Format file size to human-readable size
     * @param {number} bytes - Size in bytes
     * @returns {string} Formatted size
     */
    formatFileSize: function(bytes) {
        if (isNaN(bytes) || bytes === 0) return '0 Bytes';
        
        const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
        const i = Math.floor(Math.log(bytes) / Math.log(1024));
        
        return parseFloat((bytes / Math.pow(1024, i)).toFixed(2)) + ' ' + sizes[i];
    },
    
    /**
     * Create confirmation dialog
     * @param {string} message - Confirmation message
     * @param {Function} confirmCallback - Callback for confirm button
     * @param {string} confirmText - Text for confirm button
     * @param {string} cancelText - Text for cancel button
     */
    confirm: function(message, confirmCallback, confirmText, cancelText) {
        if (!confirmText) confirmText = 'Confirm';
        if (!cancelText) cancelText = 'Cancel';
        
        const content = `
            <p>${message}</p>
        `;
        
        // Show confirmation modal
        this.showModal('Confirm Action', content, confirmCallback);
        
        // Update button text
        const confirmButton = document.getElementById('modal-confirm');
        const cancelButton = document.getElementById('modal-cancel');
        
        if (confirmButton) {
            confirmButton.textContent = confirmText;
        }
        
        if (cancelButton) {
            cancelButton.textContent = cancelText;
        }
    }
};

// Initialize UI when document is loaded
document.addEventListener('DOMContentLoaded', () => {
    UIController.init();
    
    // Expose UI controller globally
    window.UI = UIController;
});