# Backend Development Guide

Learn how to create custom analytics backends to send events to your own services.

## Overview

Backends are plugins that export analytics events to external destinations. Whisker-core includes several built-in backends and supports custom implementations for:

- Custom analytics services
- Data warehouses
- Third-party integrations
- Specialized storage solutions

## Built-in Backends

| Backend | Description | Use Case |
|---------|-------------|----------|
| `null` | Discards all events | Testing, disabled analytics |
| `console` | Logs to console | Development, debugging |
| `memory` | Stores in memory | Unit tests, local analysis |
| `local-storage` | Persists locally | Offline support, caching |

## Backend Interface

Every backend must implement this interface:

```lua
local Backend = {}

-- Backend metadata
Backend.name = "my-backend"
Backend.version = "1.0.0"

-- Initialize the backend
-- @param config table Configuration options
-- @return boolean Success
function Backend:initialize(config)
  self._config = config
  -- Setup code here
  return true
end

-- Export a batch of events
-- @param events table Array of events to export
-- @param callback function Callback with (success, error)
function Backend:exportBatch(events, callback)
  -- Export logic here
  callback(true)
end

-- Test backend connectivity
-- @return boolean Success
-- @return string|nil Error message
function Backend:test()
  -- Connectivity test
  return true
end

-- Shutdown the backend
function Backend:shutdown()
  -- Cleanup code here
end

-- Get backend status
-- @return table Status information
function Backend:getStatus()
  return {
    name = self.name,
    stats = self._stats
  }
end

return Backend
```

## Creating a Custom Backend

### Step 1: Define the Backend Factory

```lua
-- my_backend.lua
local function createMyBackend(config)
  return {
    name = "my-backend",
    version = "1.0.0",
    _config = config or {},
    _stats = {
      eventsExported = 0,
      batchesExported = 0,
      errors = 0
    },

    initialize = function(self, cfg)
      self._config = cfg or self._config
      -- Initialize your backend
      return true
    end,

    exportBatch = function(self, events, callback)
      -- Export events
      self._stats.eventsExported = self._stats.eventsExported + #events
      self._stats.batchesExported = self._stats.batchesExported + 1
      callback(true)
    end,

    test = function(self)
      return true
    end,

    shutdown = function(self)
      -- Cleanup
    end,

    getStatus = function(self)
      return {
        name = self.name,
        stats = self._stats
      }
    end
  }
end

return {
  create = createMyBackend
}
```

### Step 2: Register the Backend

```lua
local BackendRegistry = require("whisker.analytics.backends")
local MyBackend = require("my_backend")

BackendRegistry.registerBackendType("my-backend", MyBackend)
```

### Step 3: Use the Backend

```lua
BackendRegistry.configure({
  {
    type = "my-backend",
    config = {
      -- Your configuration options
    }
  }
})
```

## Complete Example: HTTP Backend

```lua
-- http_backend.lua
-- A backend that sends events to an HTTP endpoint

local http = require("socket.http")
local json = require("json")  -- Use your preferred JSON library

local function createHttpBackend(config)
  local backend = {
    name = "http",
    version = "1.0.0",
    _config = {},
    _stats = {
      eventsExported = 0,
      batchesExported = 0,
      errors = 0,
      lastExportTime = nil
    }
  }

  function backend:initialize(cfg)
    self._config = cfg or {}

    -- Validate required config
    if not self._config.endpoint then
      return false, "Missing required config: endpoint"
    end

    -- Set defaults
    self._config.method = self._config.method or "POST"
    self._config.timeout = self._config.timeout or 30
    self._config.headers = self._config.headers or {}
    self._config.headers["Content-Type"] = "application/json"

    return true
  end

  function backend:exportBatch(events, callback)
    -- Prepare payload
    local payload = json.encode({
      events = events,
      timestamp = os.time() * 1000,
      batchSize = #events
    })

    -- Build headers string for socket.http
    local headerStr = ""
    for k, v in pairs(self._config.headers) do
      headerStr = headerStr .. k .. ": " .. v .. "\r\n"
    end

    -- Make HTTP request
    local response, status = http.request{
      url = self._config.endpoint,
      method = self._config.method,
      headers = self._config.headers,
      source = ltn12.source.string(payload),
      sink = ltn12.sink.table({}),
      timeout = self._config.timeout
    }

    if status == 200 or status == 201 or status == 204 then
      self._stats.eventsExported = self._stats.eventsExported + #events
      self._stats.batchesExported = self._stats.batchesExported + 1
      self._stats.lastExportTime = os.time() * 1000
      callback(true)
    else
      self._stats.errors = self._stats.errors + 1
      callback(false, "HTTP error: " .. tostring(status))
    end
  end

  function backend:test()
    -- Test connectivity with a simple request
    local response, status = http.request{
      url = self._config.endpoint,
      method = "HEAD",
      timeout = 5
    }

    if status == 200 or status == 204 or status == 405 then
      return true
    else
      return false, "Connectivity test failed: " .. tostring(status)
    end
  end

  function backend:shutdown()
    -- Nothing to clean up for HTTP backend
  end

  function backend:getStatus()
    return {
      name = self.name,
      version = self.version,
      endpoint = self._config.endpoint,
      stats = self._stats
    }
  end

  return backend
end

return {
  create = createHttpBackend
}
```

### Usage

```lua
local BackendRegistry = require("whisker.analytics.backends")
local HttpBackend = require("http_backend")

-- Register
BackendRegistry.registerBackendType("http", HttpBackend)

-- Configure
BackendRegistry.configure({
  {
    type = "http",
    config = {
      endpoint = "https://api.mysite.com/analytics",
      headers = {
        ["Authorization"] = "Bearer " .. API_TOKEN,
        ["X-Story-Id"] = "my-story"
      },
      timeout = 10
    }
  }
})
```

## Advanced Patterns

### Retry Logic

```lua
function backend:exportBatch(events, callback)
  local maxRetries = self._config.maxRetries or 3
  local retryDelay = self._config.retryDelay or 1000

  local function attempt(retryCount)
    local success, err = self:_doExport(events)

    if success then
      callback(true)
    elseif retryCount < maxRetries then
      -- Schedule retry
      -- Note: Actual implementation depends on your async framework
      setTimeout(function()
        attempt(retryCount + 1)
      end, retryDelay * retryCount)
    else
      callback(false, "Max retries exceeded: " .. tostring(err))
    end
  end

  attempt(0)
end
```

### Batching with Size Limit

```lua
function backend:exportBatch(events, callback)
  local maxBatchSize = self._config.maxBatchSize or 100
  local results = {}
  local errors = {}

  -- Split into smaller batches if needed
  for i = 1, #events, maxBatchSize do
    local batch = {}
    for j = i, math.min(i + maxBatchSize - 1, #events) do
      table.insert(batch, events[j])
    end

    local success, err = self:_doExport(batch)
    if not success then
      table.insert(errors, err)
    end
  end

  if #errors == 0 then
    callback(true)
  else
    callback(false, table.concat(errors, "; "))
  end
end
```

### Compression

```lua
local zlib = require("zlib")

function backend:exportBatch(events, callback)
  local payload = json.encode(events)

  -- Compress if large enough
  if #payload > 1000 and self._config.compression then
    payload = zlib.compress(payload)
    self._config.headers["Content-Encoding"] = "gzip"
  end

  -- Send compressed payload
  self:_send(payload, callback)
end
```

### Fallback Backend

```lua
-- fallback_backend.lua
-- Tries primary, falls back to secondary on failure

local function createFallbackBackend(config)
  local backend = {
    name = "fallback",
    _primary = nil,
    _secondary = nil
  }

  function backend:initialize(cfg)
    local BackendRegistry = require("whisker.analytics.backends")

    -- Create primary backend
    self._primary = BackendRegistry.createBackend(
      cfg.primary.type,
      cfg.primary.config
    )

    -- Create secondary backend
    self._secondary = BackendRegistry.createBackend(
      cfg.secondary.type,
      cfg.secondary.config
    )

    return true
  end

  function backend:exportBatch(events, callback)
    self._primary:exportBatch(events, function(success, err)
      if success then
        callback(true)
      else
        -- Fallback to secondary
        self._secondary:exportBatch(events, callback)
      end
    end)
  end

  return backend
end
```

## Testing Backends

### Unit Testing

```lua
describe("MyBackend", function()
  local MyBackend = require("my_backend")
  local backend

  before_each(function()
    backend = MyBackend.create({})
    backend:initialize({})
  end)

  it("should export events", function()
    local called = false
    backend:exportBatch({{category = "test"}}, function(success)
      called = true
      assert.is_true(success)
    end)
    assert.is_true(called)
  end)

  it("should track stats", function()
    backend:exportBatch({{}, {}, {}}, function() end)
    local status = backend:getStatus()
    assert.are.equal(3, status.stats.eventsExported)
    assert.are.equal(1, status.stats.batchesExported)
  end)

  it("should pass test", function()
    local success = backend:test()
    assert.is_true(success)
  end)
end)
```

### Integration Testing

```lua
describe("HTTP Backend Integration", function()
  local HttpBackend = require("http_backend")
  local backend

  before_each(function()
    backend = HttpBackend.create()
    backend:initialize({
      endpoint = "https://httpbin.org/post"
    })
  end)

  it("should send events to endpoint", function()
    local success = nil
    backend:exportBatch({
      { category = "test", action = "integration" }
    }, function(s)
      success = s
    end)

    -- Wait for async completion
    assert.is_true(success)
  end)
end)
```

## Best Practices

1. **Handle Errors Gracefully**: Always catch exceptions and report via callback
2. **Track Statistics**: Maintain export counts, errors, timing for monitoring
3. **Support Configuration**: Make endpoints, timeouts, etc. configurable
4. **Implement Test Method**: Allow verifying connectivity before use
5. **Clean Shutdown**: Release resources properly in shutdown()
6. **Document Configuration**: List all config options with defaults
7. **Use Async When Possible**: Don't block the main thread during export
8. **Validate Events**: Check event structure before sending
9. **Respect Rate Limits**: Implement backoff for rate-limited APIs
10. **Log Errors**: Help debugging by logging export failures
