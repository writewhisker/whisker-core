--- Backend Registry Tests
-- @module tests.unit.analytics.backends_spec
describe("BackendRegistry", function()
  local BackendRegistry

  before_each(function()
    package.loaded["whisker.analytics.backends"] = nil
    package.loaded["whisker.analytics.backends.init"] = nil

    BackendRegistry = require("whisker.analytics.backends")
    BackendRegistry.reset()

    -- Re-register built-in backends after reset
    package.loaded["whisker.analytics.backends"] = nil
    BackendRegistry = require("whisker.analytics.backends")
  end)

  after_each(function()
    BackendRegistry.shutdownAll()
  end)

  describe("registerBackendType", function()
    it("should register a backend type", function()
      BackendRegistry.registerBackendType("test", {
        create = function(config)
          return {
            name = "test",
            initialize = function() return true end
          }
        end
      })

      local types = BackendRegistry.getBackendTypes()
      local found = false
      for _, t in ipairs(types) do
        if t == "test" then
          found = true
          break
        end
      end
      assert.is_true(found)
    end)
  end)

  describe("createBackend", function()
    it("should create null backend", function()
      local backend, err = BackendRegistry.createBackend("null", {})
      assert.is_not_nil(backend)
      assert.is_nil(err)
      assert.are.equal("null", backend.name)
    end)

    it("should create console backend", function()
      local backend = BackendRegistry.createBackend("console", { verbose = true })
      assert.is_not_nil(backend)
      assert.are.equal("console", backend.name)
    end)

    it("should create memory backend", function()
      local backend = BackendRegistry.createBackend("memory", {})
      assert.is_not_nil(backend)
      assert.are.equal("memory", backend.name)
    end)

    it("should create local-storage backend", function()
      local backend = BackendRegistry.createBackend("local-storage", {
        storageKey = "test_events"
      })
      assert.is_not_nil(backend)
      assert.are.equal("local-storage", backend.name)
    end)

    it("should return error for unknown backend", function()
      local backend, err = BackendRegistry.createBackend("unknown", {})
      assert.is_nil(backend)
      assert.is_not_nil(err)
    end)
  end)

  describe("addBackend", function()
    it("should add backend to active list", function()
      local backend = BackendRegistry.createBackend("null", {})
      BackendRegistry.addBackend(backend)

      local active = BackendRegistry.getActiveBackends()
      assert.are.equal(1, #active)
    end)
  end)

  describe("configure", function()
    it("should configure multiple backends", function()
      BackendRegistry.configure({
        { type = "null", config = {} },
        { type = "memory", config = {} }
      })

      local active = BackendRegistry.getActiveBackends()
      assert.are.equal(2, #active)
    end)

    it("should shutdown existing backends before configuring new ones", function()
      BackendRegistry.configure({
        { type = "null", config = {} }
      })
      assert.are.equal(1, #BackendRegistry.getActiveBackends())

      BackendRegistry.configure({
        { type = "memory", config = {} }
      })
      assert.are.equal(1, #BackendRegistry.getActiveBackends())
    end)
  end)

  describe("getActiveBackends", function()
    it("should return empty array when no backends", function()
      local active = BackendRegistry.getActiveBackends()
      assert.is_table(active)
      assert.are.equal(0, #active)
    end)
  end)

  describe("getBackend", function()
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
      local backend = BackendRegistry.getBackend("unknown")
      assert.is_nil(backend)
    end)
  end)

  describe("shutdownAll", function()
    it("should clear active backends", function()
      BackendRegistry.configure({
        { type = "null", config = {} }
      })
      assert.are.equal(1, #BackendRegistry.getActiveBackends())

      BackendRegistry.shutdownAll()
      assert.are.equal(0, #BackendRegistry.getActiveBackends())
    end)
  end)

  describe("testAll", function()
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

  describe("null backend", function()
    it("should discard events silently", function()
      local backend = BackendRegistry.createBackend("null", {})
      local called = false

      backend:exportBatch({{}, {}, {}}, function(success)
        called = true
        assert.is_true(success)
      end)

      assert.is_true(called)
      local status = backend:getStatus()
      assert.are.equal(3, status.stats.eventsExported)
    end)
  end)

  describe("memory backend", function()
    it("should store events in memory", function()
      local backend = BackendRegistry.createBackend("memory", {})

      backend:exportBatch({
        { category = "test", action = "event1" },
        { category = "test", action = "event2" }
      }, function(success)
        assert.is_true(success)
      end)

      local events = backend:getEvents()
      assert.are.equal(2, #events)
    end)

    it("should clear stored events", function()
      local backend = BackendRegistry.createBackend("memory", {})

      backend:exportBatch({ { category = "test" } }, function() end)
      assert.are.equal(1, #backend:getEvents())

      backend:clear()
      assert.are.equal(0, #backend:getEvents())
    end)
  end)

  describe("local-storage backend", function()
    it("should store events with limit", function()
      local backend = BackendRegistry.createBackend("local-storage", {
        maxEvents = 5
      })

      -- Add 10 events
      for i = 1, 10 do
        backend:exportBatch({{ category = "test", action = "event" .. i }}, function() end)
      end

      local events = backend:getStoredEvents()
      assert.are.equal(5, #events)  -- Should be limited to 5
    end)

    it("should clear stored events", function()
      local backend = BackendRegistry.createBackend("local-storage", {})

      backend:exportBatch({ { category = "test" } }, function() end)
      backend:clearStoredEvents()

      assert.are.equal(0, #backend:getStoredEvents())
    end)
  end)

  describe("console backend", function()
    it("should export without error", function()
      local backend = BackendRegistry.createBackend("console", { verbose = false })
      local called = false

      backend:exportBatch({
        { category = "test", action = "event" }
      }, function(success)
        called = true
        assert.is_true(success)
      end)

      assert.is_true(called)
    end)
  end)

  describe("getBackendTypes", function()
    it("should return built-in backend types", function()
      local types = BackendRegistry.getBackendTypes()
      assert.is_table(types)
      assert.is_true(#types >= 4)  -- null, console, memory, local-storage
    end)
  end)
end)
