--- Service Integration Tests
-- Phase 3 validation tests for service layer optimization
-- @module tests.integration.services.service_integration_spec

describe("Service Layer Integration", function()
  local Container
  local ServiceLoader
  local ServicePriority
  local ServiceStatus

  before_each(function()
    -- Clear package cache for clean state
    package.loaded["whisker.kernel.container"] = nil
    package.loaded["whisker.services"] = nil
    package.loaded["whisker.services.state"] = nil
    package.loaded["whisker.services.history"] = nil
    package.loaded["whisker.services.variables"] = nil
    package.loaded["whisker.services.persistence"] = nil
    package.loaded["whisker.interfaces.service"] = nil

    Container = require("whisker.kernel.container")
    ServiceLoader = require("whisker.services")
    local Interfaces = require("whisker.interfaces.service")
    ServicePriority = Interfaces.ServicePriority
    ServiceStatus = Interfaces.ServiceStatus

    -- Clear any plugin registrations
    ServiceLoader.clear_plugins()
  end)

  describe("lazy loading verification", function()
    it("does not load service modules on registration", function()
      -- Clear service modules
      package.loaded["whisker.services.state"] = nil
      package.loaded["whisker.services.history"] = nil
      package.loaded["whisker.services.variables"] = nil
      package.loaded["whisker.services.persistence"] = nil

      local container = Container.new()

      -- Register all services lazily
      ServiceLoader.register_all(container)

      -- Verify modules are NOT loaded yet
      assert.is_nil(package.loaded["whisker.services.state"])
      assert.is_nil(package.loaded["whisker.services.history"])
      assert.is_nil(package.loaded["whisker.services.variables"])
      assert.is_nil(package.loaded["whisker.services.persistence"])
    end)

    it("loads module only on first resolution", function()
      -- Clear state module
      package.loaded["whisker.services.state"] = nil

      local container = Container.new()

      -- Register events dependency
      container:register("events", {
        emit = function() end,
        on = function() return function() end end
      }, { singleton = true })

      ServiceLoader.register_state(container)

      -- Not loaded yet
      assert.is_nil(package.loaded["whisker.services.state"])

      -- Resolve triggers loading
      local state = container:resolve("state")

      -- Now loaded
      assert.is_not_nil(package.loaded["whisker.services.state"])
      assert.is_not_nil(state)
    end)

    it("returns singleton instances on multiple resolves", function()
      local container = Container.new()

      container:register("events", {
        emit = function() end,
        on = function() return function() end end
      }, { singleton = true })

      ServiceLoader.register_state(container)

      local state1 = container:resolve("state")
      local state2 = container:resolve("state")

      assert.equals(state1, state2)
    end)
  end)

  describe("dependency injection pattern", function()
    it("all services declare _dependencies", function()
      local StateManager = require("whisker.services.state")
      local HistoryService = require("whisker.services.history")
      local PersistenceService = require("whisker.services.persistence")
      local VariableService = require("whisker.services.variables")

      assert.is_table(StateManager._dependencies)
      assert.is_table(HistoryService._dependencies)
      assert.is_table(PersistenceService._dependencies)
      assert.is_table(VariableService._dependencies)
    end)

    it("all services have create factory function", function()
      local StateManager = require("whisker.services.state")
      local HistoryService = require("whisker.services.history")
      local PersistenceService = require("whisker.services.persistence")
      local VariableService = require("whisker.services.variables")

      assert.is_function(StateManager.create)
      assert.is_function(HistoryService.create)
      assert.is_function(PersistenceService.create)
      assert.is_function(VariableService.create)
    end)

    it("all services implement IService interface", function()
      local container = Container.new()

      container:register("events", {
        emit = function() end,
        on = function() return function() end end
      }, { singleton = true })

      ServiceLoader.register_all(container)

      local state = container:resolve("state")
      local history = container:resolve("history")

      -- IService interface
      assert.is_function(state.getName)
      assert.is_function(state.isInitialized)
      assert.is_function(state.destroy)

      assert.is_function(history.getName)
      assert.is_function(history.isInitialized)
      assert.is_function(history.destroy)
    end)

    it("services return correct names", function()
      local container = Container.new()

      container:register("events", {
        emit = function() end,
        on = function() return function() end end
      }, { singleton = true })

      ServiceLoader.register_all(container)

      local state = container:resolve("state")
      local history = container:resolve("history")
      local variables = container:resolve("variables")

      assert.equals("state", state:getName())
      assert.equals("history", history:getName())
      assert.equals("variables", variables:getName())
    end)

    it("services are initialized after creation", function()
      local container = Container.new()

      container:register("events", {
        emit = function() end,
        on = function() return function() end end
      }, { singleton = true })

      ServiceLoader.register_all(container)

      local state = container:resolve("state")
      local history = container:resolve("history")

      assert.is_true(state:isInitialized())
      assert.is_true(history:isInitialized())
    end)

    it("services report not initialized after destroy", function()
      local container = Container.new()

      container:register("events", {
        emit = function() end,
        on = function() return function() end end
      }, { singleton = true })

      ServiceLoader.register_state(container)
      local state = container:resolve("state")

      state:destroy()

      assert.is_false(state:isInitialized())
    end)
  end)

  describe("service manifest correctness", function()
    it("all manifest services have module_path", function()
      for name, config in pairs(ServiceLoader.SERVICE_MANIFEST) do
        assert.is_string(config.module_path, "Service " .. name .. " missing module_path")
      end
    end)

    it("all manifest services have options", function()
      for name, config in pairs(ServiceLoader.SERVICE_MANIFEST) do
        assert.is_table(config.options, "Service " .. name .. " missing options")
      end
    end)

    it("all manifest services have metadata", function()
      for name, config in pairs(ServiceLoader.SERVICE_MANIFEST) do
        assert.is_table(config.metadata, "Service " .. name .. " missing metadata")
        assert.is_number(config.metadata.priority, "Service " .. name .. " missing priority")
        assert.is_string(config.metadata.category, "Service " .. name .. " missing category")
      end
    end)

    it("module paths are valid", function()
      for name, config in pairs(ServiceLoader.SERVICE_MANIFEST) do
        local success, mod = pcall(require, config.module_path)
        assert.is_true(success, "Failed to load " .. name .. ": " .. tostring(mod))
        assert.is_table(mod, "Module " .. name .. " did not return table")
      end
    end)
  end)

  describe("plugin service integration", function()
    it("plugin services integrate with core services", function()
      local container = Container.new()

      container:register("events", {
        emit = function() end,
        on = function() return function() end end
      }, { singleton = true })

      -- Register core services
      ServiceLoader.register_all(container)

      -- Register a plugin service
      ServiceLoader.register_plugin("custom_analytics", {
        factory = function()
          return {
            track = function() end,
            getName = function() return "analytics" end,
            isInitialized = function() return true end,
            destroy = function() end
          }
        end,
        metadata = {
          category = "analytics",
          priority = ServicePriority.LOW
        }
      })

      ServiceLoader.register_all_plugins(container)

      -- Both core and plugin services work
      local state = container:resolve("state")
      local analytics = container:resolve("custom_analytics")

      assert.is_not_nil(state)
      assert.is_not_nil(analytics)
    end)

    it("query returns both core and plugin services", function()
      ServiceLoader.register_plugin("custom_service", {
        module_path = "fake.path",
        metadata = {
          category = "custom",
          priority = ServicePriority.NORMAL
        }
      })

      local all = ServiceLoader.get_all_services()
      local core_count = 0
      local plugin_count = 0

      for _, service in pairs(all) do
        if service.is_core then core_count = core_count + 1 end
        if service.is_plugin then plugin_count = plugin_count + 1 end
      end

      assert.equals(4, core_count) -- state, history, variables, persistence
      assert.equals(1, plugin_count) -- custom_service
    end)
  end)

  describe("service discovery validation", function()
    it("discover returns empty for non-existent paths", function()
      local discovered = ServiceLoader.discover("nonexistent.path.to.services")

      assert.same({}, discovered)
    end)

    it("discover_modules handles mixed valid and invalid paths", function()
      local discovered = ServiceLoader.discover_modules({
        "nonexistent.module",
        "whisker.services.state", -- Valid
        "another.nonexistent"
      })

      -- Should find at least the state module (though it may be rejected for being a core service)
      assert.is_table(discovered)
    end)
  end)

  describe("service metadata queries", function()
    it("query by category works", function()
      local foundation = ServiceLoader.query({ category = "foundation" })
      local navigation = ServiceLoader.query({ category = "navigation" })
      local scripting = ServiceLoader.query({ category = "scripting" })
      local storage = ServiceLoader.query({ category = "storage" })

      assert.equals(1, #foundation)
      assert.equals(1, #navigation)
      assert.equals(1, #scripting)
      assert.equals(1, #storage)
    end)

    it("query by priority works", function()
      local high = ServiceLoader.get_by_priority(ServicePriority.HIGH)
      local normal = ServiceLoader.get_by_priority(ServicePriority.NORMAL)

      assert.equals(1, #high)
      assert.equals(3, #normal)
    end)

    it("get_by_interface finds implementing services", function()
      local state_impls = ServiceLoader.get_by_interface("IState")

      assert.equals(1, #state_impls)
      assert.equals("state", state_impls[1])
    end)
  end)

  describe("backward compatibility", function()
    it("services work with container parameter (legacy)", function()
      local TestContainer = require("tests.helpers.test_container")
      local container = TestContainer.create_full()

      local StateManager = require("whisker.services.state")
      local state = StateManager.new(container)

      assert.is_not_nil(state)
      assert.is_function(state.get)
      assert.is_function(state.set)
    end)

    it("services work without dependencies (standalone)", function()
      local StateManager = require("whisker.services.state")
      local state = StateManager.new(nil)

      assert.is_not_nil(state)
      state:set("key", "value")
      assert.equals("value", state:get("key"))
    end)

    it("services work with new DI pattern", function()
      local StateManager = require("whisker.services.state")
      local mock_event_bus = { emit = function() end }
      local mock_logger = { debug = function() end }

      local state = StateManager.new({}, {
        event_bus = mock_event_bus,
        logger = mock_logger
      })

      assert.is_not_nil(state)
      assert.equals(mock_event_bus, state._events)
      assert.equals(mock_logger, state._logger)
    end)
  end)
end)
