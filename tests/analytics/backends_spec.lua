--- Unit tests for Backend Registry
-- @module tests.analytics.backends_spec

describe("BackendRegistry", function()
  local BackendRegistry

  before_each(function()
    package.loaded["whisker.analytics.backends.init"] = nil
    BackendRegistry = require("whisker.analytics.backends.init")
    BackendRegistry.reset()
    -- Re-register built-in backends after reset
    package.loaded["whisker.analytics.backends.init"] = nil
    BackendRegistry = require("whisker.analytics.backends.init")
  end)

  local function createTestEvent(category, action, metadata)
    return {
      category = category or "story",
      action = action or "start",
      timestamp = os.time() * 1000,
      sessionId = "test-session-123",
      storyId = "test-story",
      metadata = metadata or {}
    }
  end

  describe("registerBackendType()", function()
    it("should register a backend type", function()
      BackendRegistry.registerBackendType("custom", {
        create = function()
          return {
            name = "custom",
            initialize = function(self) return true end,
            exportBatch = function(self, events, cb) cb(true) end
          }
        end
      })

      local types = BackendRegistry.getBackendTypes()
      local found = false
      for _, t in ipairs(types) do
        if t == "custom" then found = true end
      end
      assert.is_true(found)
    end)
  end)

  describe("createBackend()", function()
    it("should create null backend", function()
      local backend, err = BackendRegistry.createBackend("null", {})
      assert.is_not_nil(backend)
      assert.is_nil(err)
      assert.are.equal("null", backend.name)
    end)

    it("should create console backend", function()
      local backend, err = BackendRegistry.createBackend("console", { verbose = false })
      assert.is_not_nil(backend)
      assert.is_nil(err)
      assert.are.equal("console", backend.name)
    end)

    it("should create memory backend", function()
      local backend, err = BackendRegistry.createBackend("memory", {})
      assert.is_not_nil(backend)
      assert.is_nil(err)
      assert.are.equal("memory", backend.name)
    end)

    it("should create local-storage backend", function()
      local backend, err = BackendRegistry.createBackend("local-storage", {})
      assert.is_not_nil(backend)
      assert.is_nil(err)
      assert.are.equal("local-storage", backend.name)
    end)

    it("should return error for unknown backend type", function()
      local backend, err = BackendRegistry.createBackend("unknown", {})
      assert.is_nil(backend)
      assert.is_not_nil(err)
    end)
  end)

  describe("addBackend()", function()
    it("should add backend to active backends", function()
      local backend, _ = BackendRegistry.createBackend("null", {})
      BackendRegistry.addBackend(backend)

      local active = BackendRegistry.getActiveBackends()
      assert.are.equal(1, #active)
    end)
  end)

  describe("configure()", function()
    it("should configure multiple backends", function()
      BackendRegistry.configure({
        { type = "null", config = {} },
        { type = "console", config = { verbose = false } }
      })

      local active = BackendRegistry.getActiveBackends()
      assert.are.equal(2, #active)
    end)

    it("should shutdown existing backends when reconfiguring", function()
      BackendRegistry.configure({ { type = "null", config = {} } })
      BackendRegistry.configure({ { type = "console", config = {} } })

      local active = BackendRegistry.getActiveBackends()
      assert.are.equal(1, #active)
      assert.are.equal("console", active[1].name)
    end)

    it("should skip invalid backend configurations", function()
      BackendRegistry.configure({
        { type = "null", config = {} },
        { type = "invalid", config = {} }
      })

      local active = BackendRegistry.getActiveBackends()
      assert.are.equal(1, #active)
    end)
  end)

  describe("getActiveBackends()", function()
    it("should return empty array initially", function()
      BackendRegistry.reset()
      local active = BackendRegistry.getActiveBackends()
      assert.are.equal(0, #active)
    end)

    it("should return all active backends", function()
      BackendRegistry.configure({
        { type = "null", config = {} },
        { type = "memory", config = {} }
      })

      local active = BackendRegistry.getActiveBackends()
      assert.are.equal(2, #active)
    end)
  end)

  describe("getBackend()", function()
    it("should return backend by name", function()
      BackendRegistry.configure({
        { type = "null", config = {} },
        { type = "memory", config = {} }
      })

      local backend = BackendRegistry.getBackend("memory")
      assert.is_not_nil(backend)
      assert.are.equal("memory", backend.name)
    end)

    it("should return nil for unknown name", function()
      BackendRegistry.configure({ { type = "null", config = {} } })
      local backend = BackendRegistry.getBackend("unknown")
      assert.is_nil(backend)
    end)
  end)

  describe("shutdownAll()", function()
    it("should clear all active backends", function()
      BackendRegistry.configure({
        { type = "null", config = {} },
        { type = "memory", config = {} }
      })

      BackendRegistry.shutdownAll()

      local active = BackendRegistry.getActiveBackends()
      assert.are.equal(0, #active)
    end)
  end)

  describe("testAll()", function()
    it("should test all backends", function()
      BackendRegistry.configure({
        { type = "null", config = {} },
        { type = "memory", config = {} }
      })

      local results = BackendRegistry.testAll()
      assert.are.equal(2, #results)
      assert.is_true(results[1].success)
      assert.is_true(results[2].success)
    end)
  end)

  describe("getBackendTypes()", function()
    it("should return all registered backend types", function()
      local types = BackendRegistry.getBackendTypes()
      assert.is_true(#types >= 4) -- null, console, memory, local-storage
    end)
  end)

  describe("null backend", function()
    local backend

    before_each(function()
      backend, _ = BackendRegistry.createBackend("null", {})
    end)

    it("should export batch successfully", function()
      local events = { createTestEvent() }
      local success = nil

      backend:exportBatch(events, function(result)
        success = result
      end)

      assert.is_true(success)
    end)

    it("should track export statistics", function()
      local events = { createTestEvent(), createTestEvent() }

      backend:exportBatch(events, function() end)

      local status = backend:getStatus()
      assert.are.equal(2, status.stats.eventsExported)
      assert.are.equal(1, status.stats.batchesExported)
    end)
  end)

  describe("console backend", function()
    local backend

    before_each(function()
      backend, _ = BackendRegistry.createBackend("console", { verbose = false })
    end)

    it("should export batch successfully", function()
      local events = { createTestEvent() }
      local success = nil

      backend:exportBatch(events, function(result)
        success = result
      end)

      assert.is_true(success)
    end)
  end)

  describe("memory backend", function()
    local backend

    before_each(function()
      backend, _ = BackendRegistry.createBackend("memory", {})
    end)

    it("should store events in memory", function()
      local events = { createTestEvent("story", "start"), createTestEvent("passage", "view") }

      backend:exportBatch(events, function() end)

      local stored = backend:getEvents()
      assert.are.equal(2, #stored)
    end)

    it("should accumulate events across batches", function()
      backend:exportBatch({ createTestEvent() }, function() end)
      backend:exportBatch({ createTestEvent(), createTestEvent() }, function() end)

      local stored = backend:getEvents()
      assert.are.equal(3, #stored)
    end)

    it("should clear events", function()
      backend:exportBatch({ createTestEvent() }, function() end)
      backend:clear()

      local stored = backend:getEvents()
      assert.are.equal(0, #stored)
    end)

    it("should report status with event count", function()
      backend:exportBatch({ createTestEvent(), createTestEvent() }, function() end)

      local status = backend:getStatus()
      assert.are.equal(2, status.eventCount)
    end)
  end)

  describe("local-storage backend", function()
    local backend
    local mockStorage

    before_each(function()
      local stored = {}
      mockStorage = {
        get = function(key) return stored[key] end,
        set = function(key, value) stored[key] = value end
      }

      backend, _ = BackendRegistry.createBackend("local-storage", {
        storage = mockStorage,
        storageKey = "test_events",
        maxEvents = 100
      })
    end)

    it("should store events to storage", function()
      local events = { createTestEvent() }

      backend:exportBatch(events, function() end)

      local stored = mockStorage.get("test_events")
      assert.is_not_nil(stored)
      assert.are.equal(1, #stored)
    end)

    it("should limit stored events", function()
      backend, _ = BackendRegistry.createBackend("local-storage", {
        storage = mockStorage,
        maxEvents = 3
      })

      backend:exportBatch({ createTestEvent(), createTestEvent(), createTestEvent() }, function() end)
      backend:exportBatch({ createTestEvent(), createTestEvent() }, function() end)

      local stored = backend:getStoredEvents()
      assert.are.equal(3, #stored)
    end)

    it("should clear stored events", function()
      backend:exportBatch({ createTestEvent() }, function() end)
      backend:clearStoredEvents()

      local stored = backend:getStoredEvents()
      assert.are.equal(0, #stored)
    end)
  end)

  describe("http backend", function()
    it("should require endpoint config", function()
      local backend, err = BackendRegistry.createBackend("http", {})
      assert.is_nil(backend)
      assert.is_not_nil(err)
    end)

    it("should create with valid config", function()
      local mockHttp = {
        request = function(opts, callback)
          callback({ status = 200 })
        end
      }

      local backend, err = BackendRegistry.createBackend("http", {
        endpoint = "https://example.com/analytics",
        httpClient = mockHttp
      })

      assert.is_not_nil(backend)
      assert.is_nil(err)
    end)

    it("should export batch via HTTP", function()
      local requestMade = false
      local mockHttp = {
        request = function(opts, callback)
          requestMade = true
          assert.are.equal("https://example.com/analytics", opts.url)
          assert.are.equal("POST", opts.method)
          callback({ status = 200 })
        end
      }

      local backend, _ = BackendRegistry.createBackend("http", {
        endpoint = "https://example.com/analytics",
        httpClient = mockHttp
      })

      local success = nil
      backend:exportBatch({ createTestEvent() }, function(result)
        success = result
      end)

      assert.is_true(requestMade)
      assert.is_true(success)
    end)

    it("should handle HTTP errors", function()
      local mockHttp = {
        request = function(opts, callback)
          callback({ status = 500 })
        end
      }

      local backend, _ = BackendRegistry.createBackend("http", {
        endpoint = "https://example.com/analytics",
        httpClient = mockHttp
      })

      local success = nil
      backend:exportBatch({ createTestEvent() }, function(result)
        success = result
      end)

      assert.is_false(success)
    end)

    it("should fail without HTTP client", function()
      local backend, _ = BackendRegistry.createBackend("http", {
        endpoint = "https://example.com/analytics"
      })

      local success = nil
      local errorMsg = nil
      backend:exportBatch({ createTestEvent() }, function(result, err)
        success = result
        errorMsg = err
      end)

      assert.is_false(success)
      assert.is_not_nil(errorMsg)
    end)
  end)

  describe("google-analytics backend", function()
    it("should require measurementId config", function()
      local backend, err = BackendRegistry.createBackend("google-analytics", {
        apiSecret = "secret"
      })
      assert.is_nil(backend)
      assert.is_not_nil(err)
    end)

    it("should require apiSecret config", function()
      local backend, err = BackendRegistry.createBackend("google-analytics", {
        measurementId = "G-XXXXX"
      })
      assert.is_nil(backend)
      assert.is_not_nil(err)
    end)

    it("should create with valid config", function()
      local mockHttp = {
        request = function(opts, callback)
          callback({ status = 204 })
        end
      }

      local backend, err = BackendRegistry.createBackend("google-analytics", {
        measurementId = "G-XXXXX",
        apiSecret = "secret",
        httpClient = mockHttp
      })

      assert.is_not_nil(backend)
      assert.is_nil(err)
    end)

    it("should export batch to GA4", function()
      local requestUrl = nil
      local mockHttp = {
        request = function(opts, callback)
          requestUrl = opts.url
          callback({ status = 204 })
        end
      }

      local backend, _ = BackendRegistry.createBackend("google-analytics", {
        measurementId = "G-XXXXX",
        apiSecret = "secret",
        httpClient = mockHttp
      })

      local success = nil
      backend:exportBatch({ createTestEvent() }, function(result)
        success = result
      end)

      assert.is_true(success)
      assert.is_not_nil(requestUrl)
      assert.is_true(requestUrl:find("google%-analytics%.com") ~= nil)
    end)

    it("should convert events to GA4 format", function()
      local requestBody = nil
      local mockHttp = {
        request = function(opts, callback)
          requestBody = opts.body
          callback({ status = 204 })
        end
      }

      local backend, _ = BackendRegistry.createBackend("google-analytics", {
        measurementId = "G-XXXXX",
        apiSecret = "secret",
        httpClient = mockHttp
      })

      backend:exportBatch({ createTestEvent("story", "start", { passageId = "opening" }) }, function() end)

      assert.is_not_nil(requestBody)
      -- Body should contain GA4 formatted events
      assert.is_true(requestBody:find("story_start") ~= nil)
    end)

    it("should report status with measurementId", function()
      local mockHttp = {
        request = function(opts, callback)
          callback({ status = 204 })
        end
      }

      local backend, _ = BackendRegistry.createBackend("google-analytics", {
        measurementId = "G-XXXXX",
        apiSecret = "secret",
        httpClient = mockHttp
      })

      local status = backend:getStatus()
      assert.are.equal("G-XXXXX", status.measurementId)
    end)
  end)
end)
