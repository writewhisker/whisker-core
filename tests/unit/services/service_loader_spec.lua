--- ServiceLoader Tests
-- Tests for service registration and lazy loading
-- @module tests.unit.services.service_loader_spec

describe("ServiceLoader", function()
  local ServiceLoader
  local Container
  local mock_container

  before_each(function()
    -- Clear package cache
    package.loaded["whisker.services"] = nil
    package.loaded["whisker.kernel.container"] = nil
    package.loaded["whisker.interfaces.service"] = nil

    ServiceLoader = require("whisker.services")
    Container = require("whisker.kernel.container")

    -- Create mock container for testing
    mock_container = {
      _registrations = {},
      _lazy_registrations = {},
      register_lazy = function(self, name, module_path, options)
        self._lazy_registrations[name] = {
          module_path = module_path,
          options = options
        }
      end,
      has = function(self, name)
        return self._lazy_registrations[name] ~= nil
      end
    }
  end)

  describe("SERVICE_MANIFEST", function()
    it("contains state service", function()
      assert.is_not_nil(ServiceLoader.SERVICE_MANIFEST.state)
    end)

    it("contains history service", function()
      assert.is_not_nil(ServiceLoader.SERVICE_MANIFEST.history)
    end)

    it("contains variables service", function()
      assert.is_not_nil(ServiceLoader.SERVICE_MANIFEST.variables)
    end)

    it("contains persistence service", function()
      assert.is_not_nil(ServiceLoader.SERVICE_MANIFEST.persistence)
    end)

    it("state service has correct module path", function()
      assert.equals("whisker.services.state", ServiceLoader.SERVICE_MANIFEST.state.module_path)
    end)

    it("history service has correct module path", function()
      assert.equals("whisker.services.history", ServiceLoader.SERVICE_MANIFEST.history.module_path)
    end)

    it("variables service has correct module path", function()
      assert.equals("whisker.services.variables", ServiceLoader.SERVICE_MANIFEST.variables.module_path)
    end)

    it("persistence service has correct module path", function()
      assert.equals("whisker.services.persistence", ServiceLoader.SERVICE_MANIFEST.persistence.module_path)
    end)

    it("state service implements IState", function()
      assert.equals("IState", ServiceLoader.SERVICE_MANIFEST.state.options.implements)
    end)

    it("all services have metadata", function()
      for name, config in pairs(ServiceLoader.SERVICE_MANIFEST) do
        assert.is_not_nil(config.metadata, "Service " .. name .. " should have metadata")
      end
    end)

    it("all services have priority in metadata", function()
      for name, config in pairs(ServiceLoader.SERVICE_MANIFEST) do
        assert.is_number(config.metadata.priority, "Service " .. name .. " should have priority")
      end
    end)

    it("all services have category in metadata", function()
      for name, config in pairs(ServiceLoader.SERVICE_MANIFEST) do
        assert.is_string(config.metadata.category, "Service " .. name .. " should have category")
      end
    end)
  end)

  describe("register_all", function()
    it("registers all services from manifest", function()
      ServiceLoader.register_all(mock_container)

      assert.is_true(mock_container:has("state"))
      assert.is_true(mock_container:has("history"))
      assert.is_true(mock_container:has("variables"))
      assert.is_true(mock_container:has("persistence"))
    end)

    it("uses register_lazy for all services", function()
      ServiceLoader.register_all(mock_container)

      -- All services should be in lazy_registrations
      assert.is_not_nil(mock_container._lazy_registrations.state)
      assert.is_not_nil(mock_container._lazy_registrations.history)
      assert.is_not_nil(mock_container._lazy_registrations.variables)
      assert.is_not_nil(mock_container._lazy_registrations.persistence)
    end)

    it("passes correct module paths", function()
      ServiceLoader.register_all(mock_container)

      assert.equals("whisker.services.state", mock_container._lazy_registrations.state.module_path)
      assert.equals("whisker.services.history", mock_container._lazy_registrations.history.module_path)
    end)

    it("passes singleton option", function()
      ServiceLoader.register_all(mock_container)

      assert.is_true(mock_container._lazy_registrations.state.options.singleton)
      assert.is_true(mock_container._lazy_registrations.history.options.singleton)
    end)

    it("passes dependency information", function()
      ServiceLoader.register_all(mock_container)

      assert.is_table(mock_container._lazy_registrations.variables.options.depends)
      assert.same({"state", "events"}, mock_container._lazy_registrations.variables.options.depends)
    end)

    it("passes metadata in options", function()
      ServiceLoader.register_all(mock_container)

      assert.is_not_nil(mock_container._lazy_registrations.state.options.metadata)
      assert.is_number(mock_container._lazy_registrations.state.options.metadata.priority)
    end)
  end)

  describe("register_state", function()
    it("registers only state service", function()
      ServiceLoader.register_state(mock_container)

      assert.is_true(mock_container:has("state"))
      assert.is_false(mock_container:has("history"))
      assert.is_false(mock_container:has("variables"))
    end)

    it("uses lazy registration", function()
      ServiceLoader.register_state(mock_container)

      assert.is_not_nil(mock_container._lazy_registrations.state)
    end)
  end)

  describe("register_history", function()
    it("registers only history service", function()
      ServiceLoader.register_history(mock_container)

      assert.is_true(mock_container:has("history"))
      assert.is_false(mock_container:has("state"))
    end)
  end)

  describe("register_variables", function()
    it("registers only variables service", function()
      ServiceLoader.register_variables(mock_container)

      assert.is_true(mock_container:has("variables"))
      assert.is_false(mock_container:has("state"))
    end)
  end)

  describe("register_persistence", function()
    it("registers only persistence service", function()
      ServiceLoader.register_persistence(mock_container)

      assert.is_true(mock_container:has("persistence"))
      assert.is_false(mock_container:has("state"))
    end)
  end)

  describe("get_metadata", function()
    it("returns metadata for known service", function()
      local metadata = ServiceLoader.get_metadata("state")

      assert.is_not_nil(metadata)
      assert.equals("foundation", metadata.category)
    end)

    it("returns nil for unknown service", function()
      local metadata = ServiceLoader.get_metadata("nonexistent")

      assert.is_nil(metadata)
    end)
  end)

  describe("get_names", function()
    it("returns all service names", function()
      local names = ServiceLoader.get_names()

      assert.is_table(names)
      assert.equals(4, #names)
    end)

    it("returns sorted names", function()
      local names = ServiceLoader.get_names()

      -- Check they're in sorted order
      for i = 1, #names - 1 do
        assert.is_true(names[i] < names[i + 1])
      end
    end)

    it("includes all expected services", function()
      local names = ServiceLoader.get_names()
      local name_set = {}
      for _, name in ipairs(names) do
        name_set[name] = true
      end

      assert.is_true(name_set.state)
      assert.is_true(name_set.history)
      assert.is_true(name_set.variables)
      assert.is_true(name_set.persistence)
    end)
  end)

  describe("get_by_category", function()
    it("returns services in foundation category", function()
      local names = ServiceLoader.get_by_category("foundation")

      assert.equals(1, #names)
      assert.equals("state", names[1])
    end)

    it("returns services in navigation category", function()
      local names = ServiceLoader.get_by_category("navigation")

      assert.equals(1, #names)
      assert.equals("history", names[1])
    end)

    it("returns empty for unknown category", function()
      local names = ServiceLoader.get_by_category("unknown")

      assert.equals(0, #names)
    end)
  end)

  describe("get_by_priority", function()
    local ServicePriority = require("whisker.interfaces.service").ServicePriority

    it("returns HIGH priority services", function()
      local names = ServiceLoader.get_by_priority(ServicePriority.HIGH)

      assert.equals(1, #names)
      assert.equals("state", names[1])
    end)

    it("returns NORMAL priority services", function()
      local names = ServiceLoader.get_by_priority(ServicePriority.NORMAL)

      assert.equals(3, #names) -- history, persistence, variables
    end)

    it("returns empty for unused priority", function()
      local names = ServiceLoader.get_by_priority(ServicePriority.CRITICAL)

      assert.equals(0, #names)
    end)
  end)

  describe("has_service", function()
    it("returns true for known service", function()
      assert.is_true(ServiceLoader.has_service("state"))
      assert.is_true(ServiceLoader.has_service("history"))
    end)

    it("returns false for unknown service", function()
      assert.is_false(ServiceLoader.has_service("nonexistent"))
    end)
  end)

  describe("get_module_path", function()
    it("returns module path for known service", function()
      local path = ServiceLoader.get_module_path("state")

      assert.equals("whisker.services.state", path)
    end)

    it("returns nil for unknown service", function()
      local path = ServiceLoader.get_module_path("nonexistent")

      assert.is_nil(path)
    end)
  end)

  describe("lazy loading verification", function()
    it("does not require service modules on register", function()
      -- Clear any cached modules
      package.loaded["whisker.services.state"] = nil
      package.loaded["whisker.services.history"] = nil
      package.loaded["whisker.services.variables"] = nil
      package.loaded["whisker.services.persistence"] = nil

      ServiceLoader.register_all(mock_container)

      -- Modules should not be loaded yet
      assert.is_nil(package.loaded["whisker.services.state"])
      assert.is_nil(package.loaded["whisker.services.history"])
      assert.is_nil(package.loaded["whisker.services.variables"])
      assert.is_nil(package.loaded["whisker.services.persistence"])
    end)

    it("loads module only on first resolve", function()
      local container = Container.new()

      -- Register events first (dependency)
      container:register("events", {
        emit = function() end,
        on = function() end
      }, {singleton = true})

      -- Clear cached state module
      package.loaded["whisker.services.state"] = nil

      ServiceLoader.register_state(container)

      -- Not loaded yet
      assert.is_nil(package.loaded["whisker.services.state"])

      -- Now resolve - this should load the module
      local state = container:resolve("state")

      -- Now it should be loaded
      assert.is_not_nil(package.loaded["whisker.services.state"])
      assert.is_not_nil(state)
    end)
  end)

  describe("integration with real container", function()
    it("registers and resolves state service", function()
      local container = Container.new()

      -- Register events (dependency)
      container:register("events", {
        emit = function() end,
        on = function() end
      }, {singleton = true})

      ServiceLoader.register_state(container)

      local state = container:resolve("state")

      assert.is_not_nil(state)
      assert.is_function(state.get)
      assert.is_function(state.set)
    end)

    it("registers and resolves history service", function()
      local container = Container.new()

      -- Register dependencies
      container:register("events", {
        emit = function() end,
        on = function() end
      }, {singleton = true})
      container:register("state", {}, {singleton = true})

      ServiceLoader.register_history(container)

      local history = container:resolve("history")

      assert.is_not_nil(history)
      assert.is_function(history.push)
      assert.is_function(history.pop)
    end)

    it("returns singleton instances", function()
      local container = Container.new()

      container:register("events", {
        emit = function() end,
        on = function() end
      }, {singleton = true})

      ServiceLoader.register_state(container)

      local state1 = container:resolve("state")
      local state2 = container:resolve("state")

      assert.equals(state1, state2)
    end)
  end)
end)
