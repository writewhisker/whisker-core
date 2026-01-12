/**
 * Hot Reload Client for Whisker Dev Server
 * Handles browser-side hot reload functionality
 * @author Whisker Development Team
 * @license MIT
 */

(function(window) {
  'use strict';

  /**
   * Hot Reload Client
   * @class
   */
  class HotReloadClient {
    /**
     * Create a new hot reload client
     * @param {Object} config - Configuration options
     * @param {string} config.url - Server URL (default: current host)
     * @param {number} config.reconnectDelay - Delay between reconnect attempts (ms)
     * @param {number} config.maxReconnectAttempts - Max reconnection tries
     */
    constructor(config = {}) {
      this.config = {
        url: config.url || `http://${window.location.host}`,
        reconnectDelay: config.reconnectDelay || 1000,
        maxReconnectAttempts: config.maxReconnectAttempts || 10,
        ...config
      };

      this.connected = false;
      this.reconnectAttempts = 0;
      this.eventSource = null;
      this.state = {};
    }

    /**
     * Connect to dev server
     */
    connect() {
      if (this.connected) {
        return;
      }

      try {
        this.eventSource = new EventSource(`${this.config.url}/hot-reload`);

        this.eventSource.onopen = () => {
          this.connected = true;
          this.reconnectAttempts = 0;
          this.showNotification('Connected to dev server', 'success');
          console.log('[Hot Reload] Connected to dev server');
        };

        this.eventSource.onmessage = (event) => {
          try {
            const data = JSON.parse(event.data);
            this.handleReload(data);
          } catch (err) {
            console.error('[Hot Reload] Failed to parse message:', err);
          }
        };

        this.eventSource.onerror = () => {
          this.connected = false;
          this.eventSource.close();
          this.reconnect();
        };
      } catch (err) {
        console.error('[Hot Reload] Connection error:', err);
        this.reconnect();
      }
    }

    /**
     * Disconnect from dev server
     */
    disconnect() {
      if (this.eventSource) {
        this.eventSource.close();
        this.eventSource = null;
      }
      this.connected = false;
    }

    /**
     * Attempt to reconnect
     */
    reconnect() {
      if (this.reconnectAttempts >= this.config.maxReconnectAttempts) {
        this.showNotification('Failed to connect to dev server', 'error');
        console.error('[Hot Reload] Max reconnect attempts reached');
        return;
      }

      this.reconnectAttempts++;
      const delay = this.config.reconnectDelay * Math.min(this.reconnectAttempts, 5);

      console.log(`[Hot Reload] Reconnecting in ${delay}ms (attempt ${this.reconnectAttempts})`);

      setTimeout(() => {
        this.connect();
      }, delay);
    }

    /**
     * Handle reload event
     * @param {Object} data - Reload data
     */
    handleReload(data) {
      console.log('[Hot Reload] Reload event:', data);

      switch (data.type) {
        case 'full':
          this.fullReload();
          break;
        case 'css':
          this.reloadCSS();
          break;
        case 'story':
          this.reloadStory(data.story);
          break;
        case 'asset':
          this.reloadAsset(data.path);
          break;
        case 'file_modified':
        case 'file_created':
          this.handleFileChange(data.data);
          break;
        default:
          console.warn('[Hot Reload] Unknown reload type:', data.type);
      }
    }

    /**
     * Handle file change event
     * @param {Object} fileData - File change data
     */
    handleFileChange(fileData) {
      const path = fileData.path;

      if (path.endsWith('.css')) {
        this.showNotification('Reloading styles...', 'info');
        this.reloadCSS();
      } else if (path.endsWith('.js')) {
        this.showNotification('JavaScript changed - reloading...', 'info');
        this.fullReload();
      } else if (path.endsWith('.lua') || path.endsWith('.json')) {
        this.showNotification('Story changed - reloading...', 'info');
        this.fullReload();
      } else {
        this.fullReload();
      }
    }

    /**
     * Perform full page reload
     */
    fullReload() {
      console.log('[Hot Reload] Full page reload');
      window.location.reload();
    }

    /**
     * Reload CSS without page refresh
     */
    reloadCSS() {
      console.log('[Hot Reload] Reloading CSS');
      const timestamp = Date.now();
      const links = document.querySelectorAll('link[rel="stylesheet"]');

      links.forEach(link => {
        const href = link.href.split('?')[0];
        link.href = `${href}?t=${timestamp}`;
      });

      this.showNotification('Styles reloaded', 'success');
    }

    /**
     * Reload story data
     * @param {Object} storyData - New story data
     */
    reloadStory(storyData) {
      console.log('[Hot Reload] Reloading story');

      // Save current state
      this.state = this.saveState();

      // Reload page with state
      sessionStorage.setItem('hotReloadState', JSON.stringify(this.state));
      window.location.reload();
    }

    /**
     * Reload specific asset
     * @param {string} assetPath - Asset path
     */
    reloadAsset(assetPath) {
      console.log('[Hot Reload] Reloading asset:', assetPath);

      const timestamp = Date.now();

      // Reload images
      const images = document.querySelectorAll(`img[src*="${assetPath}"]`);
      images.forEach(img => {
        const src = img.src.split('?')[0];
        img.src = `${src}?t=${timestamp}`;
      });

      // Reload background images
      const elements = document.querySelectorAll('*');
      elements.forEach(el => {
        const style = window.getComputedStyle(el);
        const bgImage = style.backgroundImage;
        if (bgImage && bgImage.includes(assetPath)) {
          const current = el.style.backgroundImage || bgImage;
          const cleaned = current.replace(/\?t=\d+/, '');
          el.style.backgroundImage = cleaned.replace(')', `?t=${timestamp})`);
        }
      });

      this.showNotification('Asset reloaded', 'success');
    }

    /**
     * Save current application state
     * @returns {Object} Current state
     */
    saveState() {
      // This is a placeholder - applications should override this
      return {
        timestamp: Date.now(),
        url: window.location.href,
        scroll: {
          x: window.scrollX,
          y: window.scrollY
        }
      };
    }

    /**
     * Restore application state
     * @param {Object} state - State to restore
     */
    restoreState(state) {
      if (!state) return;

      // Restore scroll position
      if (state.scroll) {
        window.scrollTo(state.scroll.x, state.scroll.y);
      }
    }

    /**
     * Show notification to user
     * @param {string} message - Notification message
     * @param {string} type - Notification type (info, success, error)
     */
    showNotification(message, type = 'info') {
      // Remove existing notifications
      const existing = document.querySelectorAll('.hot-reload-notification');
      existing.forEach(el => el.remove());

      // Create notification
      const notification = document.createElement('div');
      notification.className = `hot-reload-notification ${type}`;
      notification.textContent = message;
      document.body.appendChild(notification);

      // Auto-remove after 3 seconds
      setTimeout(() => {
        notification.remove();
      }, 3000);
    }
  }

  // Auto-initialize if in development mode
  if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
    const client = new HotReloadClient();
    client.connect();

    // Restore state on load
    const savedState = sessionStorage.getItem('hotReloadState');
    if (savedState) {
      try {
        const state = JSON.parse(savedState);
        client.restoreState(state);
        sessionStorage.removeItem('hotReloadState');
      } catch (err) {
        console.error('[Hot Reload] Failed to restore state:', err);
      }
    }

    // Expose client globally for debugging
    window.hotReloadClient = client;
  }

  // Export for use as module
  window.HotReloadClient = HotReloadClient;

})(window);
