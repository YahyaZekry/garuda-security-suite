/**
 * Aegis Security Suite - Advanced Dashboard JavaScript
 * Modern futuristic dashboard with real-time updates and enhanced interactions
 */

// Global variables
let socket;
let monitoringActive = false;
let charts = {};
let currentTheme = 'dark';
let notificationQueue = [];
let systemMetrics = {};
let performanceData = {
    cpu: [],
    memory: [],
    network: [],
    timestamps: []
};

// Configuration
const CONFIG = {
    maxDataPoints: 50,
    updateInterval: 5000,
    notificationTimeout: 8000,
    animationDuration: 300,
    debounceDelay: 250,
    maxNotifications: 5
};

// Initialize dashboard when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
    initializeDashboard();
    setupEventListeners();
    loadTheme();
    initializeCharts();
    connectWebSocket();
    startRealTimeUpdates();
    initializeKeyboardShortcuts();
    initializeTooltips();
    initializeNotifications();
    initializeMobileMenu();
});

/**
 * Initialize dashboard components
 */
function initializeDashboard() {
    console.log('🚀 Initializing Aegis Security Dashboard...');
    
    // Update last updated timestamp
    updateLastUpdated();
    
    // Load initial data
    loadSystemStatus();
    loadNotifications();
    loadUserPreferences();
    
    // Initialize performance monitoring
    initializePerformanceMonitoring();
    
    // Setup auto-refresh
    setupAutoRefresh();
    
    // Initialize service worker for offline support
    initializeServiceWorker();
    
    // Initialize session expiry timer
    initializeSessionTimer();
    
    console.log('✅ Dashboard initialized successfully');
}

/**
 * Track session expiry and warn before timeout
 */
function initializeSessionTimer() {
    if (!window.sessionStorage) return;
    
    const SESSION_DURATION = 23 * 60 * 60 * 1000; // 23 hours in ms
    const WARNING_TIME = 2 * 60 * 1000; // 2 minutes before warning
    
    let sessionStart = sessionStorage.getItem('sessionStart');
    if (!sessionStart) {
        sessionStart = Date.now().toString();
        sessionStorage.setItem('sessionStart', sessionStart);
    }
    sessionStart = parseInt(sessionStart, 10);
    
    setInterval(() => {
        const elapsed = Date.now() - sessionStart;
        const remaining = SESSION_DURATION - elapsed;
        
        if (remaining <= 0) {
            showStatusMessage('Session expired. Please log in again.', 'danger');
            setTimeout(() => window.location.href = '/logout', 5000);
        } else if (remaining <= WARNING_TIME) {
            showStatusMessage('Your session will expire in 2 minutes. Save your work.', 'warning');
        }
    }, 60000); // Check every minute
}

/**
 * Setup comprehensive event listeners
 */
function setupEventListeners() {
    // Theme toggle
    const themeToggle = document.getElementById('themeToggle');
    if (themeToggle) {
        themeToggle.addEventListener('click', toggleTheme);
    }
    
    // Mobile menu toggle
    const mobileMenuToggle = document.getElementById('mobileMenuToggle');
    if (mobileMenuToggle) {
        mobileMenuToggle.addEventListener('click', toggleMobileMenu);
    }
    
    // Window resize handler with debouncing
    window.addEventListener('resize', debounce(handleResize, CONFIG.debounceDelay));
    
    // Online/offline detection
    window.addEventListener('online', handleOnlineChange);
    window.addEventListener('offline', handleOfflineChange);
    
    // Before unload handler
    window.addEventListener('beforeunload', handleBeforeUnload);
    
    // Visibility change handler
    document.addEventListener('visibilitychange', handleVisibilityChange);
    
    // Context menu prevention (disabled - interferes with dev tools)
    // document.addEventListener('contextmenu', preventContextMenu);
    
    // Keyboard navigation
    document.addEventListener('keydown', handleKeyboardNavigation);
    
    // Click outside to close dropdowns
    document.addEventListener('click', handleClickOutside);
    
    // Scroll events for parallax effects
    window.addEventListener('scroll', handleScroll);
}

/**
 * Connect to WebSocket for real-time updates
 */
function connectWebSocket() {
    try {
        socket = io({
            transports: ['websocket', 'polling'],
            upgrade: true,
            rememberUpgrade: true,
            timeout: 20000,
            forceNew: true
        });
        
        socket.on('connect', function() {
            console.log('🔌 Connected to Aegis Security Server');
            showConnectionStatus('Connected', 'success');
            initializeConnectionHeartbeat();
            
            // Auto-subscribe to relevant rooms based on current page
            autoSubscribeToRooms();
        });
        
        socket.on('disconnect', function(reason) {
            console.log('🔌 Disconnected from Aegis Security Server:', reason);
            showConnectionStatus('Disconnected', 'danger');
            monitoringActive = false;
            handleReconnection();
        });
        
        socket.on('reconnect', function(attemptNumber) {
            console.log(`🔄 Reconnected after ${attemptNumber} attempts`);
            showConnectionStatus('Reconnected', 'success');
            
            // Re-subscribe to rooms after reconnection
            autoSubscribeToRooms();
        });
        
        socket.on('connect_error', function(error) {
            console.error('❌ WebSocket connection error:', error);
            showConnectionStatus('Connection Error', 'danger');
            
            // Try to fallback to polling if WebSocket fails
            if (socket.io.engine.transport.name === 'polling') {
                console.log('📡 Using HTTP polling fallback');
                showConnectionStatus('Polling Mode', 'warning');
            }
        });
        
        // System events
        socket.on('system_update', handleSystemUpdate);
        socket.on('security_status_update', handleSecurityStatusUpdate);
        
        // Behavioral analysis events
        socket.on('behavioral_alert', handleBehavioralAlert);
        
        // Threat intelligence events
        socket.on('threat_intelligence_update', handleThreatIntelligenceUpdate);
        
        // Incident management events
        socket.on('incident_update', handleIncidentUpdate);
        
        // General events
        socket.on('status', handleStatusMessage);
        socket.on('heartbeat_response', handleHeartbeatResponse);
        
    } catch (error) {
        console.error('❌ WebSocket connection failed:', error);
        showConnectionStatus('Connection Failed', 'danger');
        fallbackToPolling();
    }
}

/**
 * Handle real-time system updates
 */
function handleSystemUpdate(data) {
    updateSystemMetrics(data);
    updateCharts(data);
    updateLastUpdated();
    animateValueChanges(data);
    
    // Store metrics for historical data
    storeSystemMetrics(data);
}

/**
 * Handle threat alerts with enhanced notifications
 */
function handleThreatAlert(data) {
    showThreatAlert(data);
    playNotificationSound('threat');
    addNotificationToQueue({
        type: 'threat',
        title: 'Threat Alert',
        message: data.message,
        severity: data.severity || 'high',
        timestamp: new Date(),
        data: data
    });
    
    // Update threat level indicator
    updateThreatLevel(data.threat_level);
    
    // Trigger visual alert
    triggerVisualAlert('danger');
}

/**
 * Handle incident creation with enhanced tracking
 */
function handleIncidentCreated(data) {
    showIncidentNotification(data);
    playNotificationSound('incident');
    addNotificationToQueue({
        type: 'incident',
        title: 'New Incident',
        message: `${data.incident_id}: ${data.incident_type}`,
        severity: data.severity || 'medium',
        timestamp: new Date(),
        data: data
    });
    
    updateIncidentCount();
    
    // Add to timeline if on dashboard
    if (window.location.pathname === '/dashboard') {
        addIncidentToTimeline(data);
    }
}

/**
 * Handle scan progress with visual feedback
 */
function handleScanProgress(data) {
    updateScanProgress(data);
    
    if (data.status === 'completed') {
        showStatusMessage('Scan completed successfully', 'success');
        playNotificationSound('success');
    } else if (data.status === 'failed') {
        showErrorMessage('Scan failed: ' + data.error);
        playNotificationSound('error');
    }
}

/**
 * Handle performance data for advanced monitoring
 */
function handlePerformanceData(data) {
    updatePerformanceCharts(data);
    checkPerformanceThresholds(data);
    storePerformanceData(data);
}

/**
 * Handle security events
 */
function handleSecurityEvent(data) {
    addSecurityEventToTimeline(data);
    
    if (data.severity === 'critical') {
        triggerVisualAlert('danger');
        playNotificationSound('critical');
    }
}

function handleSecurityStatusUpdate(data) {
    updateSecuritySuiteStatus(data.security_status);
    console.log('🛡️ Security suite status updated:', data);
}

function handleBehavioralAlert(data) {
    showBehavioralAlert(data);
    addNotificationToQueue({
        type: 'behavioral',
        title: 'Behavioral Alert',
        message: `${data.anomaly_type}: ${data.description}`,
        severity: data.severity || 'medium',
        timestamp: new Date(),
        data: data
    });
    
    if (data.severity === 'high' || data.severity === 'critical') {
        triggerVisualAlert('warning');
        playNotificationSound('threat');
    }
}

function handleThreatIntelligenceUpdate(data) {
    updateThreatIntelligenceStatus(data.feeds_status);
    console.log('🔍 Threat intelligence updated:', data);
}

function handleIncidentUpdate(data) {
    updateIncidentList(data.incidents);
    
    // Show notification for new incidents
    data.incidents.forEach(incident => {
        if (incident.status === 'new' || incident.status === 'open') {
            addNotificationToQueue({
                type: 'incident',
                title: 'Incident Update',
                message: `${incident.incident_id}: ${incident.incident_type}`,
                severity: incident.severity || 'medium',
                timestamp: new Date(),
                data: incident
            });
        }
    });
}

function handleHeartbeatResponse(data) {
    console.log('💓 Heartbeat response received:', data.timestamp);
    // Update connection status indicator
    updateConnectionLatency(data.timestamp);
}

/**
 * Load system status with error handling
 */
function loadSystemStatus() {
    showLoadingState('system-status');
    
    fetch('/api/system/status')
        .then(response => {
            if (!response.ok) throw new Error('Network response was not ok');
            return response.json();
        })
        .then(data => {
            updateSystemMetrics(data);
            hideLoadingState('system-status');
        })
        .catch(error => {
            console.error('❌ Error loading system status:', error);
            showErrorMessage('Failed to load system status');
            hideLoadingState('system-status');
        });
}

/**
 * Update system metrics with animations
 */
function updateSystemMetrics(data) {
    // Update sidebar metrics with animations
    animateValue('cpu-usage', data.cpu_usage, '%', 1);
    animateValue('memory-usage', data.memory_usage, '%', 1);
    updateElement('threat-level', data.threat_level || 'Low');

    // Update progress bars with smooth transitions
    updateProgressBar('cpu-progress', data.cpu_usage);
    updateProgressBar('memory-progress', data.memory_usage);

    // Update status indicators
    updateStatusIndicator('system-status', data.status);

    // Update incident count
    if (data.open_incidents !== undefined) {
        animateValue('incidents-count', data.open_incidents, '', 0);
    }

    updateResourceMetrics(data);

    // Store current metrics
    systemMetrics = { ...systemMetrics, ...data };
}

/**
 * Populate the System Metrics panel's detailed fields (cores, load average,
 * memory/disk used-of-total, network in/out). Shared by the initial page
 * load (/api/system/status) and the live 'system_update' socket event -
 * both send the same flat field names.
 */
function updateResourceMetrics(data) {
    if (data.cpu_count !== undefined) updateElement('cpu-cores', data.cpu_count);
    if (data.load_avg !== undefined) updateElement('cpu-load', data.load_avg.toFixed(2));

    if (data.memory_used_gb !== undefined) updateElement('memory-used', data.memory_used_gb + ' GB');
    if (data.memory_total_gb !== undefined) updateElement('memory-total', data.memory_total_gb + ' GB');

    if (data.disk_usage !== undefined) {
        updateElement('disk-metric', data.disk_usage.toFixed(1) + '%');
        updateProgressBar('disk-progress', data.disk_usage);
    }
    if (data.disk_used_gb !== undefined) updateElement('disk-used', data.disk_used_gb + ' GB');
    if (data.disk_total_gb !== undefined) updateElement('disk-total', data.disk_total_gb + ' GB');

    if (data.network_in_kbps !== undefined && data.network_out_kbps !== undefined) {
        const total = data.network_in_kbps + data.network_out_kbps;
        updateElement('network-metric', total.toFixed(1) + ' KB/s');
        updateProgressBar('network-progress', Math.min(total, 100));
        updateElement('network-in', data.network_in_kbps.toFixed(1) + ' KB/s');
        updateElement('network-out', data.network_out_kbps.toFixed(1) + ' KB/s');
    }
}

/**
 * Update charts with new data
 */
function updateCharts(data) {
    const timestamp = new Date().toLocaleTimeString();
    
    // Update performance charts if they exist
    if (charts.performance) {
        addDataPoint(charts.performance, {
            timestamp: timestamp,
            cpu: data.cpu_usage,
            memory: data.memory_usage,
            network: data.network_io || 0
        });
    }
    
    // Update threat score chart if it exists
    if (charts.threatScore) {
        updateThreatScoreChart(data.threat_score);
    }
    
    // Update mini charts
    updateMiniCharts(data);
}

/**
 * Initialize charts with modern configuration
 */
function initializeCharts() {
    // Set global Chart.js defaults
    Chart.defaults.font.family = "'Inter', sans-serif";
    Chart.defaults.color = '#cbd5e1';
    Chart.defaults.borderColor = 'rgba(148, 163, 184, 0.1)';
    Chart.defaults.plugins.tooltip.backgroundColor = 'rgba(15, 23, 42, 0.9)';
    Chart.defaults.plugins.tooltip.titleColor = '#f1f5f9';
    Chart.defaults.plugins.tooltip.bodyColor = '#cbd5e1';
    Chart.defaults.plugins.tooltip.borderColor = '#334155';
    Chart.defaults.plugins.tooltip.borderWidth = 1;
    Chart.defaults.plugins.tooltip.padding = 12;
    Chart.defaults.plugins.tooltip.displayColors = true;
    Chart.defaults.plugins.tooltip.cornerRadius = 8;
    
    // Performance chart will be initialized by individual pages
    console.log('📊 Chart defaults initialized');
}

/**
 * Toggle real-time monitoring
 */
function toggleMonitoring() {
    if (monitoringActive) {
        stopMonitoring();
    } else {
        startMonitoring();
    }
}

/**
 * Start real-time monitoring
 */
function startMonitoring() {
    if (socket && socket.connected) {
        socket.emit('start_monitoring');
        monitoringActive = true;
        showStatusMessage('Real-time monitoring started', 'success');
        updateMonitoringButton(true);
        startDataCollection();
        
        // Subscribe to all relevant rooms for comprehensive monitoring
        subscribeToAllRooms();
    } else {
        showErrorMessage('Not connected to server');
    }
}

/**
 * Stop real-time monitoring
 */
function stopMonitoring() {
    if (socket) {
        socket.emit('stop_monitoring');
        monitoringActive = false;
        showStatusMessage('Real-time monitoring stopped', 'warning');
        updateMonitoringButton(false);
        stopDataCollection();
        
        // Unsubscribe from all rooms
        unsubscribeFromAllRooms();
    }
}

/**
 * Update monitoring button state
 */
function updateMonitoringButton(isActive) {
    const button = document.getElementById('monitoringToggle');
    const status = document.getElementById('monitoringStatus');
    
    if (button) {
        if (isActive) {
            button.innerHTML = '<i class="fas fa-stop"></i><span>Stop Monitoring</span>';
            button.classList.add('active');
        } else {
            button.innerHTML = '<i class="fas fa-play-circle"></i><span>Real-time Monitoring</span>';
            button.classList.remove('active');
        }
    }
    
    if (status) {
        status.className = `status-indicator ${isActive ? 'active' : ''}`;
    }
}

/**
 * Start quick security scan
 */
function startQuickScan() {
    showStatusMessage('Starting quick security scan...', 'info');
    showScanProgress(0);
    
    fetch('/api/scan/start', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': getCSRFToken()
        },
        body: JSON.stringify({ type: 'quick' })
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            showStatusMessage(data.message, 'success');
        } else {
            showErrorMessage(data.message || 'Failed to start scan');
        }
    })
    .catch(error => {
        console.error('❌ Error starting scan:', error);
        showErrorMessage('Failed to start security scan');
    });
}

/**
 * Refresh dashboard data
 */
function refreshData() {
    showStatusMessage('Refreshing dashboard data...', 'info');
    
    // Show loading states
    showLoadingStates();
    
    // Reload all data
    Promise.all([
        loadSystemStatus(),
        loadNotifications(),
        loadIncidents(),
        loadThreatData()
    ])
    .then(() => {
        hideLoadingStates();
        showStatusMessage('Dashboard data refreshed', 'success');
        
        // Emit refresh event to other components
        window.dispatchEvent(new CustomEvent('dashboardRefresh'));
    })
    .catch(error => {
        hideLoadingStates();
        console.error('❌ Error refreshing data:', error);
        showErrorMessage('Failed to refresh dashboard data');
    });
}

/**
 * Export data in different formats
 */
function exportData(format) {
    showStatusMessage(`Exporting data as ${format.toUpperCase()}...`, 'info');
    
    // Get current page data
    const pageData = getCurrentPageData();
    
    // Convert and download based on format
    switch (format) {
        case 'json':
            downloadJSON(pageData);
            break;
        case 'csv':
            downloadCSV(pageData);
            break;
        case 'pdf':
            downloadPDF(pageData);
            break;
        default:
            showErrorMessage('Unsupported export format');
    }
}

/**
 * Get current page data for export
 */
function getCurrentPageData() {
    return {
        timestamp: new Date().toISOString(),
        system_status: systemMetrics,
        performance_data: performanceData,
        incidents: getIncidentsData(),
        threats: getThreatsData(),
        user: getCurrentUserInfo(),
        export_format: 'aegis-dashboard-export'
    };
}

/**
 * Download data as JSON
 */
function downloadJSON(data) {
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
    downloadFile(blob, `aegis_dashboard_${new Date().toISOString().split('T')[0]}.json`);
}

/**
 * Download data as CSV
 */
function downloadCSV(data) {
    let csv = 'Timestamp,Metric,Value\n';
    
    // Add system metrics
    if (data.system_status) {
        csv += `${data.timestamp},CPU Usage,${data.system_status.cpu_usage}\n`;
        csv += `${data.timestamp},Memory Usage,${data.system_status.memory_usage}\n`;
        csv += `${data.timestamp},Threat Level,${data.system_status.threat_level}\n`;
    }
    
    // Add performance data
    if (data.performance_data && data.performance_data.timestamps) {
        data.performance_data.timestamps.forEach((timestamp, index) => {
            csv += `${timestamp},CPU,${data.performance_data.cpu[index] || 0}\n`;
            csv += `${timestamp},Memory,${data.performance_data.memory[index] || 0}\n`;
            csv += `${timestamp},Network,${data.performance_data.network[index] || 0}\n`;
        });
    }
    
    const blob = new Blob([csv], { type: 'text/csv' });
    downloadFile(blob, `aegis_dashboard_${new Date().toISOString().split('T')[0]}.csv`);
}

/**
 * Download data as PDF (placeholder implementation)
 */
function downloadPDF(data) {
    showStatusMessage('PDF export feature coming soon', 'info');
    // In a real implementation, you would use a library like jsPDF
}

/**
 * Download file helper
 */
function downloadFile(blob, filename) {
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    a.style.display = 'none';
    document.body.appendChild(a);
    a.click();
    window.URL.revokeObjectURL(url);
    document.body.removeChild(a);
}

/**
 * Theme management
 */
function loadTheme() {
    const savedTheme = localStorage.getItem('aegis-theme') || 'dark';
    currentTheme = savedTheme;
    applyTheme(savedTheme);
}

function toggleTheme() {
    currentTheme = currentTheme === 'light' ? 'dark' : 'light';
    applyTheme(currentTheme);
    localStorage.setItem('aegis-theme', currentTheme);
    
    // Animate theme transition
    document.body.style.transition = 'background-color 0.3s ease';
    
    // Update charts for new theme
    updateChartsTheme();
}

function applyTheme(theme) {
    document.documentElement.setAttribute('data-theme', theme);
    
    // Update theme toggle button
    const themeToggle = document.getElementById('themeToggle');
    const themeIcon = document.getElementById('themeIcon');
    
    if (themeToggle) {
        themeToggle.setAttribute('data-bs-original-title', 
            theme === 'light' ? 'Switch to Dark Mode' : 'Switch to Light Mode'
        );
    }
    
    if (themeIcon) {
        themeIcon.className = theme === 'light' ? 'fas fa-moon' : 'fas fa-sun';
    }
}

/**
 * Keyboard shortcuts
 */
function initializeKeyboardShortcuts() {
    const shortcuts = {
        'ctrl+k': openQuickSearch,
        'ctrl+r': refreshData,
        'ctrl+shift+t': toggleTheme,
        'ctrl+shift+m': toggleMonitoring,
        'ctrl+shift+s': startQuickScan,
        'f11': toggleFullscreen,
        'escape': closeModals,
        'ctrl+/': showKeyboardShortcuts
    };
    
    document.addEventListener('keydown', function(e) {
        const key = [];
        if (e.ctrlKey) key.push('ctrl');
        if (e.shiftKey) key.push('shift');
        if (e.altKey) key.push('alt');
        key.push(e.key.toLowerCase());
        
        const shortcut = key.join('+');
        if (shortcuts[shortcut]) {
            e.preventDefault();
            shortcuts[shortcut]();
        }
    });
}

function openQuickSearch() {
    // Implementation for quick search
    console.log('Opening quick search...');
}

function toggleFullscreen() {
    if (!document.fullscreenElement) {
        document.documentElement.requestFullscreen();
    } else {
        document.exitFullscreen();
    }
}

function closeModals() {
    // Close all open modals
    const modals = document.querySelectorAll('.modal.show');
    modals.forEach(modal => {
        const modalInstance = bootstrap.Modal.getInstance(modal);
        if (modalInstance) {
            modalInstance.hide();
        }
    });
}

function showKeyboardShortcuts() {
    const modal = new bootstrap.Modal(document.getElementById('shortcutsModal'));
    modal.show();
}

/**
 * Notification system
 */
function initializeNotifications() {
    // Request notification permission
    if ('Notification' in window && Notification.permission === 'default') {
        Notification.requestPermission();
    }
    
    // Initialize notification queue
    processNotificationQueue();
}

function addNotificationToQueue(notification) {
    notificationQueue.push(notification);
    
    // Limit queue size
    if (notificationQueue.length > CONFIG.maxNotifications) {
        notificationQueue.shift();
    }
    
    processNotificationQueue();
}

function processNotificationQueue() {
    if (notificationQueue.length === 0) return;
    
    const notification = notificationQueue.shift();
    showNotification(notification);
    
    // Process next notification after delay
    setTimeout(processNotificationQueue, 1000);
}

function showNotification(notification) {
    // Show in-app notification
    const notificationHtml = createNotificationHTML(notification);
    document.body.insertAdjacentHTML('beforeend', notificationHtml);
    
    // Show browser notification if permitted
    if ('Notification' in window && Notification.permission === 'granted') {
        new Notification(notification.title, {
            body: notification.message,
            icon: '/static/images/favicon.ico',
            tag: notification.type
        });
    }
    
    // Auto-remove after timeout
    setTimeout(() => {
        const element = document.querySelector(`[data-notification-id="${notification.id}"]`);
        if (element) {
            element.classList.add('fade-out');
            setTimeout(() => element.remove(), 300);
        }
    }, CONFIG.notificationTimeout);
}

function createNotificationHTML(notification) {
    const id = 'notification-' + Date.now();
    const severityClass = `alert-${notification.severity || 'info'}`;
    const icon = getNotificationIcon(notification.type);
    
    return `
        <div class="alert ${severityClass} alert-dismissible fade show position-fixed notification-slide-in" 
             data-notification-id="${id}" 
             style="top: 20px; right: 20px; z-index: 9999; max-width: 400px;">
            <div class="d-flex align-items-start">
                <div class="notification-icon me-3">
                    <i class="fas ${icon}"></i>
                </div>
                <div class="flex-grow-1">
                    <div class="notification-title fw-bold">${notification.title}</div>
                    <div class="notification-message">${notification.message}</div>
                    <div class="notification-time text-muted small">${formatTime(notification.timestamp)}</div>
                </div>
                <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
            </div>
        </div>
    `;
}

function getNotificationIcon(type) {
    const icons = {
        'threat': 'fa-exclamation-triangle',
        'incident': 'fa-ambulance',
        'success': 'fa-check-circle',
        'error': 'fa-exclamation-circle',
        'info': 'fa-info-circle',
        'warning': 'fa-exclamation-triangle'
    };
    return icons[type] || 'fa-info-circle';
}

/**
 * Mobile menu handling
 */
function initializeMobileMenu() {
    const sidebar = document.getElementById('sidebar');
    const overlay = document.createElement('div');
    overlay.className = 'mobile-menu-overlay';
    overlay.style.display = 'none';
    document.body.appendChild(overlay);
    
    overlay.addEventListener('click', closeMobileMenu);
}

function toggleMobileMenu() {
    const sidebar = document.getElementById('sidebar');
    const overlay = document.querySelector('.mobile-menu-overlay');
    
    if (sidebar.classList.contains('show')) {
        closeMobileMenu();
    } else {
        sidebar.classList.add('show');
        overlay.style.display = 'block';
        document.body.style.overflow = 'hidden';
    }
}

function closeMobileMenu() {
    const sidebar = document.getElementById('sidebar');
    const overlay = document.querySelector('.mobile-menu-overlay');
    
    sidebar.classList.remove('show');
    overlay.style.display = 'none';
    document.body.style.overflow = '';
}

/**
 * Performance monitoring
 */
function initializePerformanceMonitoring() {
    // Monitor page performance
    if ('performance' in window) {
        window.addEventListener('load', function() {
            const perfData = performance.getEntriesByType('navigation')[0];
            console.log('📊 Page load time:', perfData.loadEventEnd - perfData.loadEventStart, 'ms');
        });
    }
    
    // Monitor memory usage (if available)
    if ('memory' in performance) {
        setInterval(() => {
            const memoryInfo = performance.memory;
            console.log('💾 Memory usage:', {
                used: formatBytes(memoryInfo.usedJSHeapSize),
                total: formatBytes(memoryInfo.totalJSHeapSize),
                limit: formatBytes(memoryInfo.jsHeapSizeLimit)
            });
        }, 30000);
    }
}

/**
 * Service worker for offline support
 */
function initializeServiceWorker() {
    if ('serviceWorker' in navigator) {
        navigator.serviceWorker.register('/static/js/service-worker.js')
            .then(registration => {
                console.log('🔧 Service Worker registered:', registration);
            })
            .catch(error => {
                console.log('❌ Service Worker registration failed:', error);
            });
    }
}

/**
 * Utility functions
 */
function debounce(func, wait) {
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

function throttle(func, limit) {
    let inThrottle;
    return function() {
        const args = arguments;
        const context = this;
        if (!inThrottle) {
            func.apply(context, args);
            inThrottle = true;
            setTimeout(() => inThrottle = false, limit);
        }
    };
}

function animateValue(id, value, suffix = '', decimals = 0) {
    const element = document.getElementById(id);
    if (!element) return;
    
    const current = parseFloat(element.textContent) || 0;
    const increment = (value - current) / 20;
    let step = 0;
    
    const timer = setInterval(() => {
        step++;
        const newValue = current + (increment * step);
        element.textContent = newValue.toFixed(decimals) + suffix;
        
        if (step >= 20) {
            element.textContent = value.toFixed(decimals) + suffix;
            clearInterval(timer);
        }
    }, 20);
}

function updateElement(id, value) {
    const element = document.getElementById(id);
    if (element) {
        element.textContent = value;
    }
}

function updateProgressBar(id, value) {
    const progressBar = document.getElementById(id);
    if (progressBar) {
        progressBar.style.width = `${Math.min(100, Math.max(0, value))}%`;
        progressBar.setAttribute('aria-valuenow', value);
    }
}

function updateStatusIndicator(id, status) {
    const indicator = document.getElementById(id);
    if (indicator) {
        const statusClass = status === 'online' ? 'text-success' : 'text-danger';
        indicator.className = statusClass;
        indicator.innerHTML = `<i class="fas fa-circle ${statusClass}"></i> ${status.charAt(0).toUpperCase() + status.slice(1)}`;
    }
}

function updateLastUpdated() {
    const element = document.getElementById('last-updated');
    if (element) {
        element.textContent = new Date().toLocaleString();
    }
}

function formatTime(timestamp) {
    const date = new Date(timestamp);
    const now = new Date();
    const diff = now - date;
    
    if (diff < 60000) return 'Just now';
    if (diff < 3600000) return Math.floor(diff / 60000) + ' min ago';
    if (diff < 86400000) return Math.floor(diff / 3600000) + ' hours ago';
    return date.toLocaleDateString();
}

function formatBytes(bytes, decimals = 2) {
    if (bytes === 0) return '0 Bytes';
    
    const k = 1024;
    const dm = decimals < 0 ? 0 : decimals;
    const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'];
    
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    
    return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
}

function getCSRFToken() {
    const token = document.querySelector('meta[name="csrf-token"]');
    return token ? token.getAttribute('content') : '';
}

function isSingleUserMode() {
    const meta = document.querySelector('meta[name="deployment-mode"]');
    return !meta || meta.getAttribute('content') !== 'team';
}

function showLoadingState(elementId) {
    const element = document.getElementById(elementId);
    if (element) {
        element.classList.add('loading');
    }
}

function hideLoadingState(elementId) {
    const element = document.getElementById(elementId);
    if (element) {
        element.classList.remove('loading');
    }
}

function showLoadingStates() {
    // Add loading states to key elements
    const elements = ['system-status', 'incidents-count', 'threat-level'];
    elements.forEach(id => showLoadingState(id));
}

function hideLoadingStates() {
    // Remove loading states from all elements
    document.querySelectorAll('.loading').forEach(element => {
        element.classList.remove('loading');
    });
}

function triggerVisualAlert(severity) {
    const alertClass = `alert-${severity}`;
    const body = document.body;
    
    body.classList.add(alertClass);
    setTimeout(() => {
        body.classList.remove(alertClass);
    }, 1000);
}

function playNotificationSound(type = 'default') {
    try {
        const audioContext = new (window.AudioContext || window.webkitAudioContext)();
        const oscillator = audioContext.createOscillator();
        const gainNode = audioContext.createGain();
        
        oscillator.connect(gainNode);
        gainNode.connect(audioContext.destination);
        
        // Different frequencies for different types
        const frequencies = {
            'threat': 800,
            'incident': 600,
            'success': 400,
            'error': 300,
            'critical': 1000,
            'default': 500
        };
        
        oscillator.frequency.value = frequencies[type] || frequencies.default;
        oscillator.type = 'sine';
        gainNode.gain.value = 0.1;
        
        oscillator.start();
        oscillator.stop(audioContext.currentTime + 0.2);
    } catch (error) {
        console.log('🔇 Could not play notification sound:', error);
    }
}

// Event handlers
function handleResize() {
    // Resize charts if they exist
    Object.values(charts).forEach(chart => {
        if (chart && chart.resize) {
            chart.resize();
        }
    });
}

function handleOnlineChange() {
    showConnectionStatus('Online', 'success');
    if (socket && !socket.connected) {
        connectWebSocket();
    }
}

function handleOfflineChange() {
    showConnectionStatus('Offline', 'danger');
    monitoringActive = false;
}

function handleBeforeUnload() {
    if (socket) {
        socket.disconnect();
    }
}

function handleVisibilityChange() {
    if (document.hidden) {
        // Page is hidden, reduce update frequency
        reduceUpdateFrequency();
    } else {
        // Page is visible, resume normal updates
        resumeNormalUpdates();
    }
}



function handleKeyboardNavigation(e) {
    // Handle keyboard navigation for accessibility
    if (e.key === 'Tab') {
        // Ensure focus is visible
        document.body.classList.add('keyboard-navigation');
    }
}

function handleClickOutside(e) {
    // Close dropdowns when clicking outside
    const dropdowns = document.querySelectorAll('.dropdown-menu.show');
    dropdowns.forEach(dropdown => {
        if (!dropdown.contains(e.target)) {
            const dropdownInstance = bootstrap.Dropdown.getInstance(dropdown.previousElementSibling);
            if (dropdownInstance) {
                dropdownInstance.hide();
            }
        }
    });
}

function handleScroll(e) {
    // Add parallax effects or other scroll-based animations
    const scrolled = window.pageYOffset;
    const parallax = document.querySelector('.parallax');
    
    if (parallax) {
        parallax.style.transform = `translateY(${scrolled * 0.5}px)`;
    }
}

// Additional helper functions
function initializeConnectionHeartbeat() {
    setInterval(() => {
        if (socket && socket.connected) {
            socket.emit('heartbeat');
        }
    }, 30000);
}

function handleReconnection() {
    let attempts = 0;
    const maxAttempts = 5;
    
    const reconnectInterval = setInterval(() => {
        attempts++;
        
        if (socket && socket.connected) {
            clearInterval(reconnectInterval);
            return;
        }
        
        if (attempts >= maxAttempts) {
            clearInterval(reconnectInterval);
            showErrorMessage('Failed to reconnect to server');
            fallbackToPolling();
            return;
        }
        
        console.log(`🔄 Reconnection attempt ${attempts}/${maxAttempts}`);
        socket.connect();
    }, 5000);
}

function fallbackToPolling() {
    console.log('📡 Falling back to HTTP polling');
    setInterval(() => {
        if (!monitoringActive) return;
        loadSystemStatus();
    }, CONFIG.updateInterval);
}

function startDataCollection() {
    // Start collecting performance data
    setInterval(() => {
        if (monitoringActive && socket && socket.connected) {
            socket.emit('request_performance_data');
        }
    }, CONFIG.updateInterval);
}

function stopDataCollection() {
    // Stop collecting performance data
    console.log('⏹️ Data collection stopped');
}

function autoSubscribeToRooms() {
    // Automatically subscribe to rooms based on current page
    const currentPath = window.location.pathname;
    
    // Always subscribe to system updates
    if (socket && socket.connected) {
        socket.emit('subscribe_system');
    }
    
    // Page-specific subscriptions
    if (currentPath.includes('/behavioral')) {
        socket.emit('subscribe_behavioral');
    }
    
    if (currentPath.includes('/threats')) {
        socket.emit('subscribe_threats');
    }
    
    if (currentPath.includes('/incidents')) {
        socket.emit('subscribe_incidents');
    }
}

function subscribeToAllRooms() {
    // Subscribe to all rooms for comprehensive monitoring
    if (socket && socket.connected) {
        socket.emit('subscribe_system');
        socket.emit('subscribe_behavioral');
        socket.emit('subscribe_threats');
        socket.emit('subscribe_incidents');
    }
}

function unsubscribeFromAllRooms() {
    // Unsubscribe from all rooms
    if (socket && socket.connected) {
        socket.emit('unsubscribe_system');
        socket.emit('unsubscribe_behavioral');
        socket.emit('unsubscribe_threats');
        socket.emit('unsubscribe_incidents');
    }
}

function updateSecuritySuiteStatus(securityStatus) {
    // Update security suite status indicators
    const statusElement = document.getElementById('security-status');
    if (statusElement && securityStatus) {
        const overallStatus = securityStatus.overall_status || 'unknown';
        statusElement.textContent = overallStatus.charAt(0).toUpperCase() + overallStatus.slice(1);
        statusElement.className = `status-indicator ${overallStatus}`;
    }
    
    // Update component status
    if (securityStatus.components) {
        Object.keys(securityStatus.components).forEach(component => {
            const element = document.getElementById(`${component}-status`);
            if (element) {
                const status = securityStatus.components[component];
                element.textContent = status.status;
                element.className = `status-indicator ${status.status}`;
            }
        });
    }
}

function showBehavioralAlert(data) {
    // Show behavioral alert in the UI
    const alertContainer = document.getElementById('behavioral-alerts');
    if (alertContainer) {
        const alertHtml = createBehavioralAlertHTML(data);
        alertContainer.insertAdjacentHTML('afterbegin', alertHtml);
        
        // Auto-remove after timeout
        setTimeout(() => {
            const alertElement = alertContainer.querySelector(`[data-alert-id="${data.timestamp}"]`);
            if (alertElement) {
                alertElement.classList.add('fade-out');
                setTimeout(() => alertElement.remove(), 300);
            }
        }, CONFIG.notificationTimeout);
    }
}

function createBehavioralAlertHTML(data) {
    const severityClass = `alert-${data.severity || 'info'}`;
    return `
        <div class="alert ${severityClass} alert-dismissible fade show behavioral-alert"
             data-alert-id="${data.timestamp}">
            <div class="d-flex align-items-start">
                <div class="alert-icon me-3">
                    <i class="fas fa-brain"></i>
                </div>
                <div class="flex-grow-1">
                    <div class="alert-title fw-bold">${data.anomaly_type}</div>
                    <div class="alert-message">${data.description}</div>
                    <div class="alert-time text-muted small">${formatTime(data.timestamp)}</div>
                </div>
                <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
            </div>
        </div>
    `;
}

function updateThreatIntelligenceStatus(feedsStatus) {
    // Update threat intelligence status indicators
    const feedsElement = document.getElementById('threat-feeds-status');
    if (feedsElement && feedsStatus) {
        const activeFeeds = feedsStatus.feeds ? feedsStatus.feeds.filter(f => f.status === 'active').length : 0;
        const totalFeeds = feedsStatus.feeds ? feedsStatus.feeds.length : 0;
        
        feedsElement.textContent = `${activeFeeds}/${totalFeeds} Active`;
    }
}

function updateIncidentList(incidents) {
    // Update incident list in the UI
    const incidentContainer = document.getElementById('incident-list');
    if (incidentContainer && incidents) {
        // Clear existing incidents
        incidentContainer.innerHTML = '';
        
        // Add new incidents
        incidents.forEach(incident => {
            const incidentHtml = createIncidentHTML(incident);
            incidentContainer.insertAdjacentHTML('beforeend', incidentHtml);
        });
    }
}

function createIncidentHTML(incident) {
    const severityClass = `severity-${incident.severity || 'medium'}`;
    const statusClass = `status-${incident.status || 'open'}`;
    
    return `
        <div class="incident-item ${severityClass} ${statusClass}" data-incident-id="${incident.incident_id}">
            <div class="incident-header">
                <div class="incident-id">${incident.incident_id}</div>
                <div class="incident-severity">${incident.severity || 'medium'}</div>
                <div class="incident-status">${incident.status || 'open'}</div>
            </div>
            <div class="incident-body">
                <div class="incident-type">${incident.incident_type}</div>
                <div class="incident-description">${incident.description || 'No description available'}</div>
                <div class="incident-time">${formatTime(incident.timestamp)}</div>
            </div>
        </div>
    `;
}

function updateConnectionLatency(timestamp) {
    // Calculate and display connection latency
    const latencyElement = document.getElementById('connection-latency');
    if (latencyElement) {
        const serverTime = new Date(timestamp);
        const clientTime = new Date();
        const latency = Math.abs(clientTime - serverTime);
        
        latencyElement.textContent = `${latency}ms`;
        
        // Update latency indicator color
        if (latency < 100) {
            latencyElement.className = 'text-success';
        } else if (latency < 500) {
            latencyElement.className = 'text-warning';
        } else {
            latencyElement.className = 'text-danger';
        }
    }
}

function storeSystemMetrics(data) {
    // Store metrics for historical analysis
    const timestamp = new Date().toISOString();
    
    if (!window.localStorage) return;
    
    const stored = JSON.parse(localStorage.getItem('systemMetrics') || '[]');
    stored.push({ timestamp, ...data });
    
    // Keep only last 1000 entries
    if (stored.length > 1000) {
        stored.splice(0, stored.length - 1000);
    }
    
    localStorage.setItem('systemMetrics', JSON.stringify(stored));
}

function storePerformanceData(data) {
    // Store performance data for charts
    performanceData.timestamps.push(new Date().toLocaleTimeString());
    performanceData.cpu.push(data.cpu || 0);
    performanceData.memory.push(data.memory || 0);
    performanceData.network.push(data.network || 0);
    
    // Keep only recent data points
    if (performanceData.timestamps.length > CONFIG.maxDataPoints) {
        performanceData.timestamps.shift();
        performanceData.cpu.shift();
        performanceData.memory.shift();
        performanceData.network.shift();
    }
}

function checkPerformanceThresholds(data) {
    const thresholds = {
        cpu: 80,
        memory: 85,
        network: 90
    };
    
    if (data.cpu > thresholds.cpu) {
        showStatusMessage('High CPU usage detected', 'warning');
    }
    
    if (data.memory > thresholds.memory) {
        showStatusMessage('High memory usage detected', 'warning');
    }
    
    if (data.network > thresholds.network) {
        showStatusMessage('High network activity detected', 'warning');
    }
}

function updateChartsTheme() {
    // Update chart colors based on current theme
    const isDark = currentTheme === 'dark';
    const textColor = isDark ? '#cbd5e1' : '#374151';
    const gridColor = isDark ? 'rgba(148, 163, 184, 0.1)' : 'rgba(0, 0, 0, 0.1)';
    
    Object.values(charts).forEach(chart => {
        if (chart) {
            chart.options.scales.x.ticks.color = textColor;
            chart.options.scales.y.ticks.color = textColor;
            chart.options.scales.x.grid.color = gridColor;
            chart.options.scales.y.grid.color = gridColor;
            chart.update();
        }
    });
}

function loadUserPreferences() {
    // Load user preferences from localStorage
    const preferences = JSON.parse(localStorage.getItem('userPreferences') || '{}');
    
    // Apply preferences
    if (preferences.language) {
        // Set language
    }
    
    if (preferences.timezone) {
        // Set timezone
    }
    
    if (preferences.notifications !== undefined) {
        // Set notification preferences
    }
}

function getCurrentUserInfo() {
    // Get current user information
    return {
        username: document.querySelector('.user-name')?.textContent || 'Unknown',
        role: document.querySelector('.user-role')?.textContent || 'Unknown',
        session: sessionStorage.getItem('sessionId') || 'Unknown'
    };
}

/**
 * Show a status message toast notification
 */
function showStatusMessage(message, type) {
    const container = document.getElementById('notificationList');
    if (container) {
        const icons = {
            'success': 'fa-check-circle',
            'error': 'fa-exclamation-circle',
            'warning': 'fa-exclamation-triangle',
            'info': 'fa-info-circle'
        };
        const item = document.createElement('div');
        item.className = 'notification-item';
        item.innerHTML = `<i class="fas ${icons[type] || icons.info} me-2"></i>${message}`;
        container.prepend(item);
        
        // Update badge count
        const badge = document.getElementById('notificationCount');
        if (badge) {
            const count = parseInt(badge.textContent) + 1;
            badge.textContent = count;
            badge.style.display = count > 0 ? 'inline' : 'none';
        }
        
        setTimeout(() => item.remove(), CONFIG.notificationTimeout || 8000);
    } else {
        console.log(`[${type}] ${message}`);
    }
}

/**
 * Show error status message
 */
function showErrorMessage(message) {
    showStatusMessage(message, 'error');
}

/**
 * Auto-refresh dashboard data periodically
 */
function setupAutoRefresh() {
    setInterval(() => {
        if (!document.hidden) {
            loadSystemStatus();
        }
    }, CONFIG.updateInterval || 30000);
}

/**
 * Show connection status indicator
 */
function showConnectionStatus(status, type) {
    const indicator = document.getElementById('connection-status');
    if (indicator) {
        indicator.textContent = status;
        indicator.className = `text-${type}`;
    }
}

/**
 * Initialize Bootstrap tooltips
 */
function initializeTooltips() {
    const tooltips = document.querySelectorAll('[data-bs-toggle="tooltip"]');
    tooltips.forEach(el => {
        try { new bootstrap.Tooltip(el); } catch (e) {}
    });
}

/**
 * Real-time updates handler (stub for page-specific implementations)
 */
function startRealTimeUpdates() {
    console.log('Real-time updates initialized');
}

/**
 * Animate value changes in the UI
 */
function animateValueChanges(data) {
    // Handled by animateValue() calls in updateSystemMetrics
}

/**
 * Update threat level indicator
 */
function updateThreatLevel(level) {
    const element = document.getElementById('threat-level');
    if (element) {
        element.textContent = level || 'Low';
    }
}

/**
 * Show scan progress indicator
 */
function showScanProgress(percent) {
    const progress = document.getElementById('scan-progress');
    if (progress) {
        progress.style.width = `${percent}%`;
        progress.setAttribute('aria-valuenow', percent);
    }
}

/**
 * Page-specific data loader stubs (implemented in template scripts)
 */
function loadNotifications() {}
function loadIncidents() {}
function loadThreatData() {}

// Export global functions for use in HTML
window.toggleMonitoring = toggleMonitoring;
window.startMonitoring = startMonitoring;
window.stopMonitoring = stopMonitoring;
window.startQuickScan = startQuickScan;
window.refreshData = refreshData;
window.exportData = exportData;
window.toggleTheme = toggleTheme;
window.toggleFullscreen = toggleFullscreen;
window.showKeyboardShortcuts = showKeyboardShortcuts;
window.toggleMobileMenu = toggleMobileMenu;
window.closeMobileMenu = closeMobileMenu;

console.log('🎯 Aegis Security Dashboard JavaScript loaded successfully');