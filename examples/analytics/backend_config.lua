--- Backend Configuration Example
-- Demonstrates configuring multiple export backends
-- @module examples.analytics.backend_config

local BackendRegistry = require("whisker.analytics.backends")
local Collector = require("whisker.analytics.collector")
local ConsentManager = require("whisker.analytics.consent_manager")
local Privacy = require("whisker.analytics.privacy")

-----------------------------------------------------------
-- Configuration Profiles
-----------------------------------------------------------

-- Development configuration: Console logging for debugging
local devConfig = {
  backends = {
    {
      type = "console",
      config = { verbose = true }
    },
    {
      type = "memory",
      config = {}
    }
  }
}

-- Testing configuration: Memory backend for assertions
local testConfig = {
  backends = {
    {
      type = "memory",
      config = {}
    }
  }
}

-- Offline/Local configuration: Persist to local storage
local offlineConfig = {
  backends = {
    {
      type = "local-storage",
      config = {
        storageKey = "whisker_offline_analytics",
        maxEvents = 5000
      }
    }
  }
}

-- Production configuration: Multiple backends with fallback
-- Note: HTTP backend would require actual implementation
local productionConfig = {
  backends = {
    {
      type = "console",  -- Replace with "http" or "google-analytics" in production
      config = { verbose = false }
    },
    {
      type = "local-storage",
      config = {
        storageKey = "whisker_analytics_backup",
        maxEvents = 10000
      }
    }
  }
}

-----------------------------------------------------------
-- Configuration Functions
-----------------------------------------------------------

-- Apply a configuration profile
local function applyConfig(config, profileName)
  print(string.format("\n[Config] Applying '%s' profile...", profileName))

  -- Shutdown existing backends
  BackendRegistry.shutdownAll()

  -- Configure new backends
  BackendRegistry.configure(config.backends)

  -- Connect to collector
  Collector.setBackends(BackendRegistry.getActiveBackends())

  -- Report status
  local backends = BackendRegistry.getActiveBackends()
  print(string.format("[Config] Active backends: %d", #backends))
  for i, backend in ipairs(backends) do
    print(string.format("  %d. %s", i, backend.name))
  end
end

-- Test all configured backends
local function testBackends()
  print("\n[Config] Testing backends...")

  local results = BackendRegistry.testAll()

  for _, result in ipairs(results) do
    local status = result.success and "PASS" or "FAIL"
    print(string.format("  %s: %s", result.name, status))
    if result.error then
      print(string.format("    Error: %s", result.error))
    end
  end

  return results
end

-- Get backend status
local function getBackendStatus()
  print("\n[Config] Backend Status:")

  local backends = BackendRegistry.getActiveBackends()
  for _, backend in ipairs(backends) do
    local status = backend:getStatus()
    print(string.format("\n  %s:", status.name))
    print(string.format("    Events exported: %d", status.stats.eventsExported))
    print(string.format("    Batches exported: %d", status.stats.batchesExported))
  end
end

-----------------------------------------------------------
-- Custom Backend Registration
-----------------------------------------------------------

-- Example: Register a custom logging backend
local function registerCustomLogBackend()
  BackendRegistry.registerBackendType("custom-log", {
    create = function(config)
      return {
        name = "custom-log",
        version = "1.0.0",
        _config = config or {},
        _stats = { eventsExported = 0, batchesExported = 0 },
        _logFile = nil,

        initialize = function(self, cfg)
          self._config = cfg or self._config
          self._config.logPath = self._config.logPath or "analytics.log"
          self._config.format = self._config.format or "json"

          -- In real implementation, open file here
          print(string.format(
            "[CustomLog] Initialized (path: %s, format: %s)",
            self._config.logPath,
            self._config.format
          ))

          return true
        end,

        exportBatch = function(self, events, callback)
          -- In real implementation, write to file
          for _, event in ipairs(events) do
            print(string.format(
              "[CustomLog] %s.%s at %d",
              event.category,
              event.action,
              event.timestamp or 0
            ))
          end

          self._stats.eventsExported = self._stats.eventsExported + #events
          self._stats.batchesExported = self._stats.batchesExported + 1

          callback(true)
        end,

        test = function(self)
          -- Check if we can write to file
          return true
        end,

        shutdown = function(self)
          -- Close file handle
          print("[CustomLog] Shutdown")
        end,

        getStatus = function(self)
          return {
            name = self.name,
            stats = self._stats,
            logPath = self._config.logPath
          }
        end
      }
    end
  })

  print("[Config] Registered custom-log backend")
end

-----------------------------------------------------------
-- Demo: Show different configurations
-----------------------------------------------------------

local function runDemo()
  print("\n--- Backend Configuration Demo ---")

  -- Initialize minimal dependencies
  ConsentManager.initialize({ defaultConsentLevel = Privacy.CONSENT_LEVELS.ANALYTICS })
  ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.ANALYTICS)
  Collector.initialize({ batchSize = 5 })
  Collector.setDependencies({ consent_manager = ConsentManager })

  -- Demo 1: Development config
  print("\n=== Development Configuration ===")
  applyConfig(devConfig, "development")
  testBackends()

  -- Track some events
  print("\n[Demo] Tracking events with dev config...")
  Collector.trackEvent("test", "exposure", { testId = "demo" })
  Collector.trackEvent("story", "start", { storyId = "demo" })
  Collector.flush()

  getBackendStatus()

  -- Demo 2: Testing config
  print("\n=== Testing Configuration ===")
  applyConfig(testConfig, "testing")

  Collector.trackEvent("test", "exposure", { testId = "test-demo" })
  Collector.flush()

  -- Access memory backend for assertions
  local memBackend = BackendRegistry.getBackend("memory")
  if memBackend then
    local events = memBackend:getEvents()
    print(string.format("[Demo] Memory backend has %d events", #events))
  end

  -- Demo 3: Offline config
  print("\n=== Offline Configuration ===")
  applyConfig(offlineConfig, "offline")

  Collector.trackEvent("story", "start", { storyId = "offline-demo" })
  Collector.flush()

  local localStorage = BackendRegistry.getBackend("local-storage")
  if localStorage then
    local stored = localStorage:getStoredEvents()
    print(string.format("[Demo] Local storage has %d events", #stored))
  end

  -- Demo 4: Custom backend
  print("\n=== Custom Backend ===")
  registerCustomLogBackend()

  BackendRegistry.configure({
    {
      type = "custom-log",
      config = {
        logPath = "/tmp/analytics.log",
        format = "json"
      }
    }
  })

  Collector.setBackends(BackendRegistry.getActiveBackends())
  Collector.trackEvent("custom", "event", { demo = true })
  Collector.flush()

  getBackendStatus()

  -- Cleanup
  BackendRegistry.shutdownAll()

  print("\n--- Demo Complete ---\n")
end

-- Run demo
runDemo()

return {
  devConfig = devConfig,
  testConfig = testConfig,
  offlineConfig = offlineConfig,
  productionConfig = productionConfig,
  applyConfig = applyConfig,
  testBackends = testBackends,
  getBackendStatus = getBackendStatus,
  registerCustomLogBackend = registerCustomLogBackend
}
