--- Backend Registry for whisker-core Analytics
-- Manages export backends for analytics data
-- @module whisker.analytics.backends
-- @author Whisker Core Team
-- @license MIT

local BackendRegistry = {}
BackendRegistry.__index = BackendRegistry
BackendRegistry.VERSION = "1.0.0"

--- Registered backend types
BackendRegistry._backendTypes = {}

--- Active backend instances
BackendRegistry._activeBackends = {}

--- Register a backend type
-- @param name string Backend type name
-- @param backendClass table Backend class/factory
function BackendRegistry.registerBackendType(name, backendClass)
  BackendRegistry._backendTypes[name] = backendClass
end

--- Create and initialize a backend instance
-- @param backendType string The backend type
-- @param config table Backend configuration
-- @return table|nil Backend instance
-- @return string|nil Error message
function BackendRegistry.createBackend(backendType, config)
  local backendClass = BackendRegistry._backendTypes[backendType]
  if not backendClass then
    return nil, "Unknown backend type: " .. tostring(backendType)
  end

  -- Create instance
  local backend, err = backendClass.create(config)
  if not backend then
    return nil, err or "Failed to create backend"
  end

  -- Initialize
  local success, initErr = backend:initialize(config)
  if not success then
    return nil, initErr or "Failed to initialize backend"
  end

  return backend
end

--- Add backend to active backends
-- @param backend table Backend instance
function BackendRegistry.addBackend(backend)
  table.insert(BackendRegistry._activeBackends, backend)
end

--- Configure backends from config array
-- @param backends table Array of backend configurations
function BackendRegistry.configure(backends)
  -- Shutdown existing backends
  BackendRegistry.shutdownAll()

  -- Create and add new backends
  for _, backendConfig in ipairs(backends) do
    local backend, err = BackendRegistry.createBackend(
      backendConfig.type,
      backendConfig.config
    )

    if backend then
      BackendRegistry.addBackend(backend)
    end
  end
end

--- Get all active backends
-- @return table Array of backend instances
function BackendRegistry.getActiveBackends()
  return BackendRegistry._activeBackends
end

--- Get backend by name
-- @param name string Backend name
-- @return table|nil Backend instance
function BackendRegistry.getBackend(name)
  for _, backend in ipairs(BackendRegistry._activeBackends) do
    if backend.name == name then
      return backend
    end
  end
  return nil
end

--- Shutdown all backends
function BackendRegistry.shutdownAll()
  for _, backend in ipairs(BackendRegistry._activeBackends) do
    if backend.shutdown then
      backend:shutdown()
    end
  end
  BackendRegistry._activeBackends = {}
end

--- Test all backends
-- @return table Test results
function BackendRegistry.testAll()
  local results = {}

  for _, backend in ipairs(BackendRegistry._activeBackends) do
    local success, err = true, nil
    if backend.test then
      success, err = backend:test()
    end

    table.insert(results, {
      name = backend.name,
      success = success,
      error = err
    })
  end

  return results
end

--- Get backend types
-- @return table Registered backend type names
function BackendRegistry.getBackendTypes()
  local types = {}
  for name in pairs(BackendRegistry._backendTypes) do
    table.insert(types, name)
  end
  return types
end

--- Reset registry (for testing)
function BackendRegistry.reset()
  BackendRegistry.shutdownAll()
  BackendRegistry._backendTypes = {}
end

-- Register built-in backends
local function registerBuiltinBackends()
  -- Null backend
  BackendRegistry.registerBackendType("null", {
    create = function(config)
      return {
        name = "null",
        version = "1.0.0",
        _stats = { eventsExported = 0, batchesExported = 0 },
        initialize = function(self, cfg) return true end,
        exportBatch = function(self, events, callback)
          self._stats.eventsExported = self._stats.eventsExported + #events
          self._stats.batchesExported = self._stats.batchesExported + 1
          callback(true)
        end,
        test = function(self) return true end,
        shutdown = function(self) end,
        getStatus = function(self)
          return { name = self.name, stats = self._stats }
        end
      }
    end
  })

  -- Console backend
  BackendRegistry.registerBackendType("console", {
    create = function(config)
      return {
        name = "console",
        version = "1.0.0",
        _config = config or {},
        _stats = { eventsExported = 0, batchesExported = 0 },
        initialize = function(self, cfg)
          self._config = cfg or {}
          self._config.verbose = self._config.verbose or false
          return true
        end,
        exportBatch = function(self, events, callback)
          if self._config.verbose then
            for i, event in ipairs(events) do
              print(string.format("[Analytics] Event %d: %s.%s", i, event.category, event.action))
            end
          else
            print(string.format("[Analytics] Exported %d events", #events))
          end
          self._stats.eventsExported = self._stats.eventsExported + #events
          self._stats.batchesExported = self._stats.batchesExported + 1
          callback(true)
        end,
        test = function(self) return true end,
        shutdown = function(self) end,
        getStatus = function(self)
          return { name = self.name, stats = self._stats }
        end
      }
    end
  })

  -- Memory backend (for testing)
  BackendRegistry.registerBackendType("memory", {
    create = function(config)
      return {
        name = "memory",
        version = "1.0.0",
        _events = {},
        _stats = { eventsExported = 0, batchesExported = 0 },
        initialize = function(self, cfg) return true end,
        exportBatch = function(self, events, callback)
          for _, event in ipairs(events) do
            table.insert(self._events, event)
          end
          self._stats.eventsExported = self._stats.eventsExported + #events
          self._stats.batchesExported = self._stats.batchesExported + 1
          callback(true)
        end,
        test = function(self) return true end,
        shutdown = function(self) end,
        getEvents = function(self) return self._events end,
        clear = function(self) self._events = {} end,
        getStatus = function(self)
          return {
            name = self.name,
            stats = self._stats,
            eventCount = #self._events
          }
        end
      }
    end
  })

  -- Local storage backend
  BackendRegistry.registerBackendType("local-storage", {
    create = function(config)
      return {
        name = "local-storage",
        version = "1.0.0",
        _config = config or {},
        _events = {},
        _stats = { eventsExported = 0, batchesExported = 0 },
        _storage = nil,
        initialize = function(self, cfg)
          self._config = cfg or {}
          self._config.storageKey = self._config.storageKey or "whisker_analytics_events"
          self._config.maxEvents = self._config.maxEvents or 10000

          -- Try to load existing events from storage
          if self._config.storage then
            self._storage = self._config.storage
            local stored = self._storage.get(self._config.storageKey)
            if stored and type(stored) == "table" then
              self._events = stored
            end
          end

          return true
        end,
        exportBatch = function(self, events, callback)
          -- Add events to storage
          for _, event in ipairs(events) do
            table.insert(self._events, event)
          end

          -- Limit storage size
          while #self._events > self._config.maxEvents do
            table.remove(self._events, 1)
          end

          -- Save to storage
          if self._storage then
            self._storage.set(self._config.storageKey, self._events)
          end

          self._stats.eventsExported = self._stats.eventsExported + #events
          self._stats.batchesExported = self._stats.batchesExported + 1
          callback(true)
        end,
        test = function(self) return true end,
        shutdown = function(self)
          if self._storage then
            self._storage.set(self._config.storageKey, self._events)
          end
        end,
        getStoredEvents = function(self) return self._events end,
        clearStoredEvents = function(self)
          self._events = {}
          if self._storage then
            self._storage.set(self._config.storageKey, self._events)
          end
        end,
        getStatus = function(self)
          return {
            name = self.name,
            stats = self._stats,
            storedEvents = #self._events,
            maxEvents = self._config.maxEvents
          }
        end
      }
    end
  })

  -- HTTP backend
  BackendRegistry.registerBackendType("http", {
    create = function(config)
      return {
        name = "http",
        version = "1.0.0",
        _config = config or {},
        _stats = { eventsExported = 0, batchesExported = 0, failedBatches = 0 },
        _httpClient = nil,
        initialize = function(self, cfg)
          self._config = cfg or {}

          -- Validate required config
          if not self._config.endpoint then
            return false, "HTTP backend requires 'endpoint' config"
          end

          self._config.method = self._config.method or "POST"
          self._config.headers = self._config.headers or {}
          self._config.headers["Content-Type"] = self._config.headers["Content-Type"] or "application/json"
          self._config.timeout = self._config.timeout or 30000
          self._config.batchSize = self._config.batchSize or 50

          -- HTTP client is injected or uses platform-specific implementation
          self._httpClient = self._config.httpClient

          return true
        end,
        exportBatch = function(self, events, callback)
          if not self._httpClient then
            -- No HTTP client available, fail silently
            self._stats.failedBatches = self._stats.failedBatches + 1
            callback(false, "No HTTP client available")
            return
          end

          -- Prepare payload
          local payload = {
            events = events,
            timestamp = os.time() * 1000,
            batchSize = #events
          }

          -- Encode to JSON (requires json module)
          local success, json = pcall(require, "whisker.utils.json")
          if not success then
            self._stats.failedBatches = self._stats.failedBatches + 1
            callback(false, "JSON module not available")
            return
          end

          local body = json.encode(payload)

          -- Make HTTP request
          self._httpClient.request({
            url = self._config.endpoint,
            method = self._config.method,
            headers = self._config.headers,
            body = body,
            timeout = self._config.timeout
          }, function(response)
            if response and response.status >= 200 and response.status < 300 then
              self._stats.eventsExported = self._stats.eventsExported + #events
              self._stats.batchesExported = self._stats.batchesExported + 1
              callback(true)
            else
              self._stats.failedBatches = self._stats.failedBatches + 1
              local errMsg = response and ("HTTP " .. tostring(response.status)) or "Request failed"
              callback(false, errMsg)
            end
          end)
        end,
        test = function(self)
          if not self._httpClient then
            return false, "No HTTP client available"
          end
          return true
        end,
        shutdown = function(self) end,
        getStatus = function(self)
          return {
            name = self.name,
            endpoint = self._config.endpoint,
            stats = self._stats
          }
        end
      }
    end
  })

  -- Google Analytics 4 (GA4) backend
  BackendRegistry.registerBackendType("google-analytics", {
    create = function(config)
      return {
        name = "google-analytics",
        version = "1.0.0",
        _config = config or {},
        _stats = { eventsExported = 0, batchesExported = 0, failedBatches = 0 },
        _httpClient = nil,
        initialize = function(self, cfg)
          self._config = cfg or {}

          -- Validate required config
          if not self._config.measurementId then
            return false, "GA4 backend requires 'measurementId' config"
          end
          if not self._config.apiSecret then
            return false, "GA4 backend requires 'apiSecret' config"
          end

          self._config.batchSize = self._config.batchSize or 25 -- GA4 recommends max 25 events

          -- Build endpoint URL
          self._config.endpoint = string.format(
            "https://www.google-analytics.com/mp/collect?measurement_id=%s&api_secret=%s",
            self._config.measurementId,
            self._config.apiSecret
          )

          -- HTTP client is injected or uses platform-specific implementation
          self._httpClient = self._config.httpClient

          return true
        end,
        exportBatch = function(self, events, callback)
          if not self._httpClient then
            self._stats.failedBatches = self._stats.failedBatches + 1
            callback(false, "No HTTP client available")
            return
          end

          -- Convert events to GA4 format
          local ga4Events = {}
          for _, event in ipairs(events) do
            local ga4Event = self:_convertToGA4Event(event)
            if ga4Event then
              table.insert(ga4Events, ga4Event)
            end
          end

          if #ga4Events == 0 then
            callback(true) -- Nothing to send
            return
          end

          -- Prepare GA4 payload
          local payload = {
            client_id = events[1].sessionId or "unknown",
            events = ga4Events
          }

          -- Add user_id if available
          if events[1].userId then
            payload.user_id = events[1].userId
          end

          -- Encode to JSON
          local success, json = pcall(require, "whisker.utils.json")
          if not success then
            self._stats.failedBatches = self._stats.failedBatches + 1
            callback(false, "JSON module not available")
            return
          end

          local body = json.encode(payload)

          -- Make HTTP request
          self._httpClient.request({
            url = self._config.endpoint,
            method = "POST",
            headers = {
              ["Content-Type"] = "application/json"
            },
            body = body,
            timeout = 30000
          }, function(response)
            if response and response.status >= 200 and response.status < 300 then
              self._stats.eventsExported = self._stats.eventsExported + #events
              self._stats.batchesExported = self._stats.batchesExported + 1
              callback(true)
            else
              self._stats.failedBatches = self._stats.failedBatches + 1
              local errMsg = response and ("HTTP " .. tostring(response.status)) or "Request failed"
              callback(false, errMsg)
            end
          end)
        end,
        _convertToGA4Event = function(self, event)
          -- Map whisker events to GA4 event format
          local ga4Event = {
            name = event.category .. "_" .. event.action,
            params = {
              engagement_time_msec = 100, -- Required by GA4
              session_id = event.sessionId,
              story_id = event.storyId
            }
          }

          -- Add metadata as params
          if event.metadata then
            for key, value in pairs(event.metadata) do
              -- GA4 param names must be alphanumeric
              local paramName = string.gsub(key, "[^%w_]", "_")
              ga4Event.params[paramName] = value
            end
          end

          return ga4Event
        end,
        test = function(self)
          if not self._httpClient then
            return false, "No HTTP client available"
          end
          if not self._config.measurementId then
            return false, "Missing measurementId"
          end
          if not self._config.apiSecret then
            return false, "Missing apiSecret"
          end
          return true
        end,
        shutdown = function(self) end,
        getStatus = function(self)
          return {
            name = self.name,
            measurementId = self._config.measurementId,
            stats = self._stats
          }
        end
      }
    end
  })
end

-- Initialize built-in backends
registerBuiltinBackends()

return BackendRegistry
