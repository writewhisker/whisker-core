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

  describe("plugin service registration", function()
    before_each(function()
      ServiceLoader.clear_plugins()
    end)

    after_each(function()
      ServiceLoader.clear_plugins()
    end)

    it("registers a plugin service with module path", function()
      local result = ServiceLoader.register_plugin("my_plugin", {
        module_path = "mygame.services.custom"
      })

      assert.is_true(result)
      assert.is_true(ServiceLoader.is_plugin("my_plugin"))
    end)

    it("registers a plugin service with factory", function()
      local factory = function() return { name = "custom" } end
      local result = ServiceLoader.register_plugin("factory_plugin", {
        factory = factory
      })

      assert.is_true(result)
      assert.is_true(ServiceLoader.is_plugin("factory_plugin"))
    end)

    it("assigns default metadata to plugin", function()
      ServiceLoader.register_plugin("my_plugin", {
        module_path = "mygame.services.custom"
      })

      local config = ServiceLoader._plugin_services["my_plugin"]

      assert.equals("plugin", config.metadata.category)
      assert.equals(1000, config.metadata.priority) -- LAZY priority
    end)

    it("uses custom metadata when provided", function()
      local ServicePriority = require("whisker.interfaces.service").ServicePriority

      ServiceLoader.register_plugin("my_plugin", {
        module_path = "mygame.services.custom",
        metadata = {
          category = "custom",
          priority = ServicePriority.HIGH,
          description = "My custom service"
        }
      })

      local config = ServiceLoader._plugin_services["my_plugin"]

      assert.equals("custom", config.metadata.category)
      assert.equals(ServicePriority.HIGH, config.metadata.priority)
    end)

    it("errors when name is invalid", function()
      assert.has_error(function()
        ServiceLoader.register_plugin(nil, { module_path = "test" })
      end)

      assert.has_error(function()
        ServiceLoader.register_plugin(123, { module_path = "test" })
      end)
    end)

    it("errors when config is missing", function()
      assert.has_error(function()
        ServiceLoader.register_plugin("test", nil)
      end)
    end)

    it("errors when no module_path or factory", function()
      assert.has_error(function()
        ServiceLoader.register_plugin("test", {})
      end)
    end)

    it("errors when trying to override core service", function()
      assert.has_error(function()
        ServiceLoader.register_plugin("state", {
          module_path = "fake.state"
        })
      end)
    end)
  end)

  describe("plugin service unregistration", function()
    before_each(function()
      ServiceLoader.clear_plugins()
    end)

    after_each(function()
      ServiceLoader.clear_plugins()
    end)

    it("unregisters a plugin service", function()
      ServiceLoader.register_plugin("my_plugin", {
        module_path = "mygame.services.custom"
      })

      local result = ServiceLoader.unregister_plugin("my_plugin")

      assert.is_true(result)
      assert.is_false(ServiceLoader.is_plugin("my_plugin"))
    end)

    it("returns false for non-existent plugin", function()
      local result = ServiceLoader.unregister_plugin("nonexistent")

      assert.is_false(result)
    end)

    it("errors when trying to unregister core service", function()
      assert.has_error(function()
        ServiceLoader.unregister_plugin("state")
      end)
    end)
  end)

  describe("get_plugin_names", function()
    before_each(function()
      ServiceLoader.clear_plugins()
    end)

    after_each(function()
      ServiceLoader.clear_plugins()
    end)

    it("returns empty array when no plugins", function()
      local names = ServiceLoader.get_plugin_names()

      assert.same({}, names)
    end)

    it("returns all plugin names sorted", function()
      ServiceLoader.register_plugin("zebra", { module_path = "z" })
      ServiceLoader.register_plugin("alpha", { module_path = "a" })
      ServiceLoader.register_plugin("beta", { module_path = "b" })

      local names = ServiceLoader.get_plugin_names()

      assert.same({"alpha", "beta", "zebra"}, names)
    end)
  end)

  describe("is_plugin", function()
    before_each(function()
      ServiceLoader.clear_plugins()
    end)

    after_each(function()
      ServiceLoader.clear_plugins()
    end)

    it("returns true for registered plugin", function()
      ServiceLoader.register_plugin("my_plugin", {
        module_path = "test"
      })

      assert.is_true(ServiceLoader.is_plugin("my_plugin"))
    end)

    it("returns false for core service", function()
      assert.is_false(ServiceLoader.is_plugin("state"))
    end)

    it("returns false for non-existent service", function()
      assert.is_false(ServiceLoader.is_plugin("nonexistent"))
    end)
  end)

  describe("get_module_path with plugins", function()
    before_each(function()
      ServiceLoader.clear_plugins()
    end)

    after_each(function()
      ServiceLoader.clear_plugins()
    end)

    it("returns module path for plugin service", function()
      ServiceLoader.register_plugin("my_plugin", {
        module_path = "mygame.services.custom"
      })

      local path = ServiceLoader.get_module_path("my_plugin")

      assert.equals("mygame.services.custom", path)
    end)

    it("still returns module path for core service", function()
      local path = ServiceLoader.get_module_path("state")

      assert.equals("whisker.services.state", path)
    end)
  end)

  describe("register_plugin_service with container", function()
    before_each(function()
      ServiceLoader.clear_plugins()
    end)

    after_each(function()
      ServiceLoader.clear_plugins()
    end)

    it("registers plugin with container using lazy loading", function()
      ServiceLoader.register_plugin("my_plugin", {
        module_path = "mygame.services.custom"
      })

      local result = ServiceLoader.register_plugin_service(mock_container, "my_plugin")

      assert.is_true(result)
      assert.is_not_nil(mock_container._lazy_registrations["my_plugin"])
    end)

    it("returns false for non-existent plugin", function()
      local result = ServiceLoader.register_plugin_service(mock_container, "nonexistent")

      assert.is_false(result)
    end)

    it("uses factory when provided", function()
      local factory_called = false
      local my_factory = function()
        factory_called = true
        return {}
      end

      ServiceLoader.register_plugin("factory_plugin", {
        factory = my_factory
      })

      -- Create a container that tracks regular registrations
      local test_container = {
        _registrations = {},
        register = function(self, name, factory, options)
          self._registrations[name] = { factory = factory, options = options }
        end,
        register_lazy = function() end
      }

      ServiceLoader.register_plugin_service(test_container, "factory_plugin")

      assert.is_not_nil(test_container._registrations["factory_plugin"])
    end)
  end)

  describe("register_all_plugins", function()
    before_each(function()
      ServiceLoader.clear_plugins()
    end)

    after_each(function()
      ServiceLoader.clear_plugins()
    end)

    it("registers all plugins with container", function()
      ServiceLoader.register_plugin("plugin1", { module_path = "p1" })
      ServiceLoader.register_plugin("plugin2", { module_path = "p2" })
      ServiceLoader.register_plugin("plugin3", { module_path = "p3" })

      local count = ServiceLoader.register_all_plugins(mock_container)

      assert.equals(3, count)
    end)

    it("returns 0 when no plugins", function()
      local count = ServiceLoader.register_all_plugins(mock_container)

      assert.equals(0, count)
    end)
  end)

  describe("get_all_services", function()
    before_each(function()
      ServiceLoader.clear_plugins()
    end)

    after_each(function()
      ServiceLoader.clear_plugins()
    end)

    it("returns core services", function()
      local all = ServiceLoader.get_all_services()

      assert.is_not_nil(all.state)
      assert.is_true(all.state.is_core)
      assert.is_false(all.state.is_plugin)
    end)

    it("includes plugin services", function()
      ServiceLoader.register_plugin("my_plugin", {
        module_path = "test"
      })

      local all = ServiceLoader.get_all_services()

      assert.is_not_nil(all.my_plugin)
      assert.is_false(all.my_plugin.is_core)
      assert.is_true(all.my_plugin.is_plugin)
    end)

    it("returns combined core and plugin services", function()
      ServiceLoader.register_plugin("plugin1", { module_path = "p1" })

      local all = ServiceLoader.get_all_services()

      -- Should have 4 core + 1 plugin
      local count = 0
      for _ in pairs(all) do count = count + 1 end

      assert.equals(5, count)
    end)
  end)

  describe("query", function()
    before_each(function()
      ServiceLoader.clear_plugins()
    end)

    after_each(function()
      ServiceLoader.clear_plugins()
    end)

    it("finds services by category", function()
      local matches = ServiceLoader.query({ category = "foundation" })

      assert.equals(1, #matches)
      assert.equals("state", matches[1])
    end)

    it("finds services by priority", function()
      local ServicePriority = require("whisker.interfaces.service").ServicePriority
      local matches = ServiceLoader.query({ priority = ServicePriority.NORMAL })

      assert.equals(3, #matches) -- history, persistence, variables
    end)

    it("finds plugin services by metadata", function()
      ServiceLoader.register_plugin("custom_plugin", {
        module_path = "test",
        metadata = {
          category = "analytics",
          priority = 500
        }
      })

      local matches = ServiceLoader.query({ category = "analytics" })

      assert.equals(1, #matches)
      assert.equals("custom_plugin", matches[1])
    end)

    it("returns empty for no matches", function()
      local matches = ServiceLoader.query({ category = "nonexistent" })

      assert.equals(0, #matches)
    end)

    it("matches multiple criteria", function()
      local ServicePriority = require("whisker.interfaces.service").ServicePriority
      local matches = ServiceLoader.query({
        category = "foundation",
        priority = ServicePriority.HIGH
      })

      assert.equals(1, #matches)
      assert.equals("state", matches[1])
    end)
  end)

  describe("get_by_interface", function()
    before_each(function()
      ServiceLoader.clear_plugins()
    end)

    after_each(function()
      ServiceLoader.clear_plugins()
    end)

    it("finds services implementing IState", function()
      local matches = ServiceLoader.get_by_interface("IState")

      assert.equals(1, #matches)
      assert.equals("state", matches[1])
    end)

    it("finds plugin services by interface", function()
      ServiceLoader.register_plugin("custom_state", {
        module_path = "test",
        options = { implements = "IState" }
      })

      local matches = ServiceLoader.get_by_interface("IState")

      assert.equals(2, #matches)
    end)

    it("returns empty for unknown interface", function()
      local matches = ServiceLoader.get_by_interface("IUnknown")

      assert.equals(0, #matches)
    end)
  end)

  describe("service status tracking", function()
    local ServiceStatus = require("whisker.interfaces.service").ServiceStatus

    before_each(function()
      ServiceLoader.clear_plugins()
    end)

    after_each(function()
      ServiceLoader.clear_plugins()
    end)

    it("tracks status on plugin registration", function()
      ServiceLoader.register_plugin("my_plugin", {
        module_path = "test"
      })

      local status = ServiceLoader.get_status("my_plugin")

      assert.equals(ServiceStatus.REGISTERED, status)
    end)

    it("updates status on unregister", function()
      ServiceLoader.register_plugin("my_plugin", {
        module_path = "test"
      })

      ServiceLoader.unregister_plugin("my_plugin")

      local status = ServiceLoader.get_status("my_plugin")

      assert.equals(ServiceStatus.UNREGISTERED, status)
    end)

    it("allows manual status update", function()
      ServiceLoader.set_status("any_service", ServiceStatus.READY)

      local status = ServiceLoader.get_status("any_service")

      assert.equals(ServiceStatus.READY, status)
    end)

    it("returns nil for untracked service", function()
      local status = ServiceLoader.get_status("never_registered")

      assert.is_nil(status)
    end)
  end)

  describe("discover_modules", function()
    before_each(function()
      ServiceLoader.clear_plugins()
    end)

    after_each(function()
      ServiceLoader.clear_plugins()
    end)

    it("discovers services from module list", function()
      -- Use an actual whisker service module for testing
      local discovered = ServiceLoader.discover_modules({
        "whisker.services.state"
      })

      -- Should discover and register as plugin (with different name)
      assert.is_table(discovered)
    end)

    it("applies filter function", function()
      local filter_called = false
      local discovered = ServiceLoader.discover_modules(
        {"whisker.services.state"},
        {
          filter = function(name, mod)
            filter_called = true
            return name ~= "state_service" -- Reject
          end
        }
      )

      assert.is_true(filter_called)
    end)

    it("applies custom category", function()
      local discovered = ServiceLoader.discover_modules(
        {"whisker.services.state"},
        { category = "custom_category" }
      )

      if #discovered > 0 then
        local config = ServiceLoader._plugin_services[discovered[1]]
        assert.equals("custom_category", config.metadata.category)
      end
    end)

    it("handles invalid module paths gracefully", function()
      local discovered = ServiceLoader.discover_modules({
        "nonexistent.module.path"
      })

      assert.same({}, discovered)
    end)
  end)

  describe("clear_plugins", function()
    it("clears all plugin services", function()
      ServiceLoader.register_plugin("plugin1", { module_path = "p1" })
      ServiceLoader.register_plugin("plugin2", { module_path = "p2" })

      ServiceLoader.clear_plugins()

      assert.same({}, ServiceLoader.get_plugin_names())
    end)

    it("clears service status tracking", function()
      ServiceLoader.set_status("test", "ready")

      ServiceLoader.clear_plugins()

      assert.is_nil(ServiceLoader.get_status("test"))
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
