/**
 * KernelSU Anti-Bootloop & Backup Module
 * Service Worker for WebUIX-compliant PWA functionality with enhanced offline support
 * v1.1.0
 */

const APP_VERSION = '1.1.0';
const CACHE_PREFIX = 'ksu-antibootloop-backup-';
const CACHE_NAME = `${CACHE_PREFIX}${APP_VERSION}`;

// Cache categories
const STATIC_CACHE = `${CACHE_PREFIX}static-${APP_VERSION}`;
const DYNAMIC_CACHE = `${CACHE_PREFIX}dynamic-${APP_VERSION}`;
const API_CACHE = `${CACHE_PREFIX}api-${APP_VERSION}`;

// Assets to cache immediately for offline functionality
const CORE_ASSETS = [
    '/',
    '/index.html',
    '/css/style.css',
    '/js/main.js',
    '/js/ui.js',
    '/js/api.js',
    '/manifest.json',
    '/images/logo.svg',
    '/images/icon-192x192.png',
    '/images/icon-512x512.png',
    '/images/icon-maskable-192x192.png',
    '/images/icon-maskable-512x512.png',
    '/offline.html'
];

// Extended assets to cache when network is available
const EXTENDED_ASSETS = [
    '/images/backup-icon.svg',
    '/images/restore-icon.svg',
    '/images/protection-icon.svg',
    '/images/settings-icon.svg',
    '/images/dashboard-icon.svg'
];

/**
 * Helper function to clean up old caches
 */
async function cleanupOldCaches() {
    const cacheKeepList = [STATIC_CACHE, DYNAMIC_CACHE, API_CACHE];
    const cacheNames = await caches.keys();
    const cachesToDelete = cacheNames.filter(cacheName =>
        cacheName.startsWith(CACHE_PREFIX) && !cacheKeepList.includes(cacheName)
    );
    
    return Promise.all(cachesToDelete.map(cacheName => {
        console.log('[Service Worker] Deleting old cache:', cacheName);
        return caches.delete(cacheName);
    }));
}

/**
 * Network-first strategy with timeout fallback to cache
 * Used for API requests where fresh data is preferred but fallback is acceptable
 */
async function networkFirstWithTimeout(request, cacheName, timeout = 3000) {
    return new Promise(async (resolve) => {
        let timeoutId;
        
        // Set up a timeout for the network request
        const timeoutPromise = new Promise(resolveTimeout => {
            timeoutId = setTimeout(async () => {
                const cachedResponse = await caches.match(request);
                if (cachedResponse) {
                    console.log('[Service Worker] Network timeout, returning cached response for:', request.url);
                    resolveTimeout(cachedResponse);
                } else {
                    console.log('[Service Worker] Network timeout, no cached data available for:', request.url);
                    resolveTimeout(await caches.match('/offline.html'));
                }
            }, timeout);
        });
        
        // Try network first
        try {
            const networkPromise = fetch(request).then(response => {
                clearTimeout(timeoutId);
                
                // Cache valid responses
                if (response && response.status === 200) {
                    const clonedResponse = response.clone();
                    caches.open(cacheName).then(cache => {
                        cache.put(request, clonedResponse);
                    });
                }
                
                return response;
            }).catch(error => {
                clearTimeout(timeoutId);
                throw error;
            });
            
            // Race network vs timeout
            const response = await Promise.race([networkPromise, timeoutPromise]);
            resolve(response);
        } catch (error) {
            clearTimeout(timeoutId);
            
            // On network failure, try the cache
            const cachedResponse = await caches.match(request);
            if (cachedResponse) {
                console.log('[Service Worker] Network failed, returning cached response for:', request.url);
                resolve(cachedResponse);
            } else {
                console.log('[Service Worker] Network failed, no cached data available for:', request.url);
                resolve(await caches.match('/offline.html'));
            }
        }
    });
}

/**
 * Cache-first strategy
 * Used for static assets that rarely change
 */
async function cacheFirst(request, cacheName) {
    const cachedResponse = await caches.match(request);
    if (cachedResponse) {
        return cachedResponse;
    }
    
    try {
        const networkResponse = await fetch(request);
        if (networkResponse && networkResponse.status === 200) {
            const cache = await caches.open(cacheName);
            cache.put(request, networkResponse.clone());
        }
        return networkResponse;
    } catch (error) {
        console.error('[Service Worker] Cache-first fetch failed:', error);
        return new Response('Network error', { status: 408, headers: { 'Content-Type': 'text/plain' } });
    }
}

/**
 * Stale-while-revalidate strategy
 * Used for content that can be slightly stale but should be updated when possible
 */
async function staleWhileRevalidate(request, cacheName) {
    // Try to get the resource from the cache
    const cachedResponse = await caches.match(request);
    
    // Get the resource from the network regardless of cache status
    const networkResponsePromise = fetch(request).then(response => {
        // Update the cache with the new response
        if (response && response.status === 200) {
            const responseClone = response.clone();
            caches.open(cacheName).then(cache => {
                cache.put(request, responseClone);
            });
        }
        return response;
    }).catch(error => {
        console.error('[Service Worker] Network fetch failed in stale-while-revalidate:', error);
    });
    
    // Return the cached response immediately if available,
    // or wait for the network response
    return cachedResponse || networkResponsePromise;
}

// Install event - cache core assets
self.addEventListener('install', event => {
    console.log('[Service Worker] Installing version', APP_VERSION);
    
    event.waitUntil(
        (async () => {
            const staticCache = await caches.open(STATIC_CACHE);
            console.log('[Service Worker] Caching core app shell');
            await staticCache.addAll(CORE_ASSETS);
            
            // Try to cache extended assets but don't block installation
            try {
                console.log('[Service Worker] Caching extended assets');
                await staticCache.addAll(EXTENDED_ASSETS);
            } catch (error) {
                console.warn('[Service Worker] Some extended assets failed to cache:', error);
            }
            
            return self.skipWaiting();
        })()
    );
});

// Activate event - clean up old caches and take control
self.addEventListener('activate', event => {
    console.log('[Service Worker] Activating version', APP_VERSION);
    
    event.waitUntil(
        (async () => {
            // Clean up old caches
            await cleanupOldCaches();
            
            // Update dynamic caches if needed (e.g., new version)
            // This could involve migrating data from older caches
            
            // Take control of all clients
            await self.clients.claim();
            console.log('[Service Worker] Service worker activated and controlling all clients');
        })()
    );
});

// Fetch event - apply appropriate caching strategy based on request type
self.addEventListener('fetch', event => {
    const request = event.request;
    const url = new URL(request.url);
    
    // Skip cross-origin requests
    if (url.origin !== self.location.origin) {
        return;
    }
    
    // Skip WebUIX API calls that should go directly to the KernelSU module
    if (request.url.includes('/webui-api/') || request.url.includes('/api/v1/')) {
        console.log('[Service Worker] Bypassing WebUIX API call:', request.url);
        return;
    }
    
    // Apply different strategies based on the request type
    if (request.method === 'GET') {
        // For navigation requests, use cache first for fast loading
        if (request.mode === 'navigate') {
            event.respondWith(
                staleWhileRevalidate(request, STATIC_CACHE)
                    .catch(() => caches.match('/offline.html'))
            );
            return;
        }
        
        // For static assets, use cache-first strategy
        if (request.url.match(/\.(css|js|svg|png|jpg|jpeg|gif|woff2)$/)) {
            event.respondWith(cacheFirst(request, STATIC_CACHE));
            return;
        }
        
        // For API requests, use network-first with timeout fallback
        if (request.url.includes('/api/')) {
            event.respondWith(networkFirstWithTimeout(request, API_CACHE));
            return;
        }
        
        // Default: stale-while-revalidate for other requests
        event.respondWith(staleWhileRevalidate(request, DYNAMIC_CACHE));
    }
});

// Push event - handle push notifications
self.addEventListener('push', event => {
    console.log('[Service Worker] Push received:', event);
    
    let notificationData = {};
    
    if (event.data) {
        try {
            notificationData = event.data.json();
        } catch (e) {
            notificationData = {
                title: 'KernelSU Anti-Bootloop & Backup',
                body: event.data.text(),
                icon: '/images/icon-192x192.png'
            };
        }
    } else {
        notificationData = {
            title: 'KernelSU Anti-Bootloop & Backup',
            body: 'New notification (no data provided)',
            icon: '/images/icon-192x192.png'
        };
    }
    
    const title = notificationData.title || 'KernelSU Notification';
    const options = {
        body: notificationData.body || 'You have a new notification',
        icon: notificationData.icon || '/images/icon-192x192.png',
        badge: '/images/notification-badge.png',
        data: notificationData.data || {},
        vibrate: [100, 50, 100],
        actions: notificationData.actions || []
    };
    
    event.waitUntil(self.registration.showNotification(title, options));
});

// Notification click event - handle notification interactions
self.addEventListener('notificationclick', event => {
    console.log('[Service Worker] Notification click:', event);
    
    event.notification.close();
    
    // Handle notification action clicks
    if (event.action) {
        console.log('[Service Worker] Notification action clicked:', event.action);
        // Handle specific actions here
    } else {
        // Default action: open or focus the app
        event.waitUntil(
            clients.matchAll({ type: 'window' })
                .then(windowClients => {
                    // If a window client is already open, focus it
                    for (const client of windowClients) {
                        if (client.url.includes(self.location.origin) && 'focus' in client) {
                            return client.focus();
                        }
                    }
                    // Otherwise open a new window
                    if (clients.openWindow) {
                        return clients.openWindow('/');
                    }
                })
        );
    }
});

// Message event - handle messages from clients
self.addEventListener('message', event => {
    console.log('[Service Worker] Message received:', event.data);
    
    if (event.data.action === 'skipWaiting') {
        self.skipWaiting();
    } else if (event.data.action === 'clearCache') {
        event.waitUntil(
            caches.keys()
                .then(cacheNames => {
                    return Promise.all(
                        cacheNames.map(cacheName => {
                            if (cacheName.startsWith(CACHE_PREFIX)) {
                                console.log('[Service Worker] Clearing cache:', cacheName);
                                return caches.delete(cacheName);
                            }
                        })
                    );
                })
                .then(() => {
                    // Notify the client that caches were cleared
                    if (event.source) {
                        event.source.postMessage({
                            action: 'cacheCleared',
                            success: true
                        });
                    }
                })
        );
    } else if (event.data.action === 'updateCache') {
        // Refresh specific cache items
        const urls = event.data.urls || [];
        
        if (urls.length > 0) {
            event.waitUntil(
                caches.open(DYNAMIC_CACHE)
                    .then(cache => {
                        return Promise.all(
                            urls.map(url => {
                                return fetch(url)
                                    .then(response => {
                                        if (response && response.status === 200) {
                                            return cache.put(url, response);
                                        }
                                    })
                                    .catch(error => {
                                        console.error('[Service Worker] Failed to update cache for:', url, error);
                                    });
                            })
                        );
                    })
                    .then(() => {
                        // Notify the client that cache was updated
                        if (event.source) {
                            event.source.postMessage({
                                action: 'cacheUpdated',
                                success: true,
                                urls: urls
                            });
                        }
                    })
            );
        }
    }
});

// Sync event - handle background sync
self.addEventListener('sync', event => {
    console.log('[Service Worker] Sync event:', event.tag);
    
    if (event.tag === 'sync-backups') {
        event.waitUntil(
            // Logic to sync backups with the server
            fetch('/api/v1/backup/sync')
                .then(response => {
                    if (response.ok) {
                        return response.json();
                    }
                    throw new Error('Backup sync failed');
                })
                .then(data => {
                    console.log('[Service Worker] Backup sync completed:', data);
                    // Optionally show a notification
                    return self.registration.showNotification('Backup Sync', {
                        body: 'Your backups have been synchronized successfully',
                        icon: '/images/icon-192x192.png'
                    });
                })
                .catch(error => {
                    console.error('[Service Worker] Backup sync failed:', error);
                    // Show error notification
                    return self.registration.showNotification('Backup Sync Failed', {
                        body: 'Failed to synchronize your backups. Will retry later.',
                        icon: '/images/icon-192x192.png'
                    });
                })
        );
    }
});