--- Plugin Registry Tests
-- @module tests.unit.plugin.plugin_registry_spec

describe("PluginRegistry", function()
  local PluginRegistry
  local PluginLifecycle

  before_each(function()
    -- Clear cached modules
    package.loaded["whisker.plugin.plugin_registry"] = nil
    package.loaded["whisker.plugin.plugin_lifecycle"] = nil
    package.loaded["whisker.plugin.plugin_context"] = nil
    package.loaded["whisker.plugin.dependency_resolver"] = nil

    PluginRegistry = require("whisker.plugin.plugin_registry")
    PluginLifecycle = require("whisker.plugin.plugin_lifecycle")

    -- Reset singleton
    PluginRegistry.reset_instance()
  end)

  after_each(function()
    PluginRegistry.reset_instance()
  end)

  describe("Singleton pattern", function()
    it("should return same instance", function()
      local registry1 = PluginRegistry.get_instance()
      local registry2 = PluginRegistry.get_instance()
      assert.equals(registry1, registry2)
    end)

    it("should reset instance", function()
      local registry1 = PluginRegistry.get_instance()
      PluginRegistry.reset_instance()
      local registry2 = PluginRegistry.get_instance()
      assert.are_not.equals(registry1, registry2)
    end)
  end)

  describe("Path configuration", function()
    it("should set and get paths", function()
      local registry = PluginRegistry.new()
      registry:set_paths({"path1", "path2"})
      local paths = registry:get_paths()
      assert.equals(2, #paths)
      assert.equals("path1", paths[1])
      assert.equals("path2", paths[2])
    end)

    it("should require table for paths", function()
      local registry = PluginRegistry.new()
      assert.has_error(function()
        registry:set_paths("invalid")
      end)
    end)
  end)

  describe("Plugin registration", function()
    it("should register valid plugin", function()
      local registry = PluginRegistry.new()
      local plugin = {
        name = "test-plugin",
        version = "1.0.0",
        definition = {},
        state = "loaded",
        module = {},
      }

      local success, err = registry:register_plugin(plugin)
      assert.is_true(success)
      assert.is_nil(err)
      assert.is_true(registry:has_plugin("test-plugin"))
    end)

    it("should reject duplicate registration", function()
      local registry = PluginRegistry.new()
      local plugin = {
        name = "test-plugin",
        version = "1.0.0",
        definition = {},
        state = "loaded",
        module = {},
      }

      registry:register_plugin(plugin)
      local success, err = registry:register_plugin(plugin)
      assert.is_false(success)
      assert.truthy(err:match("already registered"))
    end)

    it("should unregister plugin", function()
      local registry = PluginRegistry.new()
      local plugin = {
        name = "test-plugin",
        version = "1.0.0",
        definition = {},
        state = "loaded",
        module = {},
      }

      registry:register_plugin(plugin)
      assert.is_true(registry:unregister_plugin("test-plugin"))
      assert.is_false(registry:has_plugin("test-plugin"))
    end)
  end)

  describe("Plugin queries", function()
    local registry

    before_each(function()
      registry = PluginRegistry.new()
      registry:register_plugin({
        name = "plugin-a",
        version = "1.0.0",
        definition = {},
        state = "loaded",
        module = {},
      })
      registry:register_plugin({
        name = "plugin-b",
        version = "2.0.0",
        definition = {},
        state = "enabled",
        module = {},
      })
    end)

    it("should get plugin by name", function()
      local plugin = registry:get_plugin("plugin-a")
      assert.is_table(plugin)
      assert.equals("plugin-a", plugin.name)
    end)

    it("should return nil for unknown plugin", function()
      local plugin = registry:get_plugin("unknown")
      assert.is_nil(plugin)
    end)

    it("should get all plugins", function()
      local plugins = registry:get_all_plugins()
      assert.equals(2, #plugins)
    end)

    it("should get plugin names sorted", function()
      local names = registry:get_plugin_names()
      assert.equals(2, #names)
      assert.equals("plugin-a", names[1])
      assert.equals("plugin-b", names[2])
    end)

    it("should get plugin count", function()
      assert.equals(2, registry:get_plugin_count())
    end)

    it("should get plugins by state", function()
      local loaded = registry:get_plugins_by_state("loaded")
      assert.equals(1, #loaded)
      assert.equals("plugin-a", loaded[1].name)

      local enabled = registry:get_plugins_by_state("enabled")
      assert.equals(1, #enabled)
      assert.equals("plugin-b", enabled[1].name)
    end)
  end)

  describe("Plugin validation", function()
    it("should reject plugin without name", function()
      local registry = PluginRegistry.new()
      local valid, err = registry:_validate_plugin({version = "1.0.0"})
      assert.is_false(valid)
      assert.truthy(err:match("name"))
    end)

    it("should reject plugin without version", function()
      local registry = PluginRegistry.new()
      local valid, err = registry:_validate_plugin({name = "test"})
      assert.is_false(valid)
      assert.truthy(err:match("version"))
    end)

    it("should reject invalid name format", function()
      local registry = PluginRegistry.new()
      local valid, err = registry:_validate_plugin({
        name = "INVALID",
        version = "1.0.0",
      })
      assert.is_false(valid)
      assert.truthy(err:match("pattern"))
    end)

    it("should reject invalid version format", function()
      local registry = PluginRegistry.new()
      local valid, err = registry:_validate_plugin({
        name = "test",
        version = "invalid",
      })
      assert.is_false(valid)
      assert.truthy(err:match("semantic version"))
    end)

    it("should accept valid minimal plugin", function()
      local registry = PluginRegistry.new()
      local valid, err = registry:_validate_plugin({
        name = "test-plugin",
        version = "1.0.0",
      })
      assert.is_true(valid)
    end)

    it("should reject non-function hooks", function()
      local registry = PluginRegistry.new()
      local valid, err = registry:_validate_plugin({
        name = "test",
        version = "1.0.0",
        on_load = "not a function",
      })
      assert.is_false(valid)
      assert.truthy(err:match("function"))
    end)

    it("should reject invalid capabilities", function()
      local registry = PluginRegistry.new()
      local valid, err = registry:_validate_plugin({
        name = "test",
        version = "1.0.0",
        capabilities = {"invalid:capability"},
      })
      assert.is_false(valid)
      assert.truthy(err:match("capability"))
    end)
  end)

  describe("Lifecycle transitions", function()
    local registry
    local mock_state_manager

    before_each(function()
      registry = PluginRegistry.new()
      mock_state_manager = {
        _data = {},
        get = function(self, key) return self._data[key] end,
        set = function(self, key, value) self._data[key] = value end,
        has = function(self, key) return self._data[key] ~= nil end,
      }
      registry:set_state_manager(mock_state_manager)

      registry:register_plugin({
        name = "test-plugin",
        version = "1.0.0",
        definition = {
          on_load = function(ctx) end,
          on_init = function(ctx) end,
          on_enable = function(ctx) end,
          on_disable = function(ctx) end,
          on_destroy = function(ctx) end,
        },
        state = "loaded",
        module = {},
      })
    end)

    it("should transition from loaded to initialized", function()
      local success, err = registry:transition_plugin("test-plugin", "initialized")
      assert.is_true(success)
      assert.equals("initialized", registry:get_plugin("test-plugin").state)
    end)

    it("should transition from initialized to enabled", function()
      registry:transition_plugin("test-plugin", "initialized")
      local success, err = registry:transition_plugin("test-plugin", "enabled")
      assert.is_true(success)
      assert.equals("enabled", registry:get_plugin("test-plugin").state)
    end)

    it("should reject invalid transitions", function()
      local success, err = registry:transition_plugin("test-plugin", "enabled")
      assert.is_false(success)
      assert.truthy(err:match("Invalid transition"))
      -- Validation failure doesn't change state - plugin remains in original state
      assert.equals("loaded", registry:get_plugin("test-plugin").state)
    end)

    it("should handle lifecycle hook errors", function()
      registry:register_plugin({
        name = "failing-plugin",
        version = "1.0.0",
        definition = {
          on_init = function(ctx)
            error("Initialization failed!")
          end,
        },
        state = "loaded",
        module = {},
      })

      local success, err = registry:transition_plugin("failing-plugin", "initialized")
      assert.is_false(success)
      assert.truthy(err:match("failed"))
      assert.equals("error", registry:get_plugin("failing-plugin").state)
    end)

    it("should create plugin context during transition", function()
      registry:transition_plugin("test-plugin", "initialized")
      local plugin = registry:get_plugin("test-plugin")
      assert.is_table(plugin.context)
    end)
  end)

  describe("Batch operations", function()
    local registry

    before_each(function()
      registry = PluginRegistry.new()
    end)

    it("should initialize all plugins", function()
      registry:register_plugin({
        name = "plugin-a",
        version = "1.0.0",
        definition = {},
        state = "loaded",
        module = {},
      })
      registry:register_plugin({
        name = "plugin-b",
        version = "1.0.0",
        definition = {},
        state = "loaded",
        module = {},
      })

      local results = registry:initialize_all_plugins()
      assert.equals(2, #results.initialized)
      assert.equals(0, #results.failed)
    end)

    it("should enable all initialized plugins", function()
      registry:register_plugin({
        name = "plugin-a",
        version = "1.0.0",
        definition = {},
        state = "initialized",
        module = {},
      })

      local results = registry:enable_all_plugins()
      assert.equals(1, #results.enabled)
    end)

    it("should disable all enabled plugins", function()
      registry:register_plugin({
        name = "plugin-a",
        version = "1.0.0",
        definition = {},
        state = "enabled",
        module = {},
      })

      local results = registry:disable_all_plugins()
      assert.equals(1, #results.disabled)
    end)

    it("should destroy all plugins", function()
      registry:register_plugin({
        name = "plugin-a",
        version = "1.0.0",
        definition = {},
        state = "disabled",
        module = {},
      })

      registry:destroy_all_plugins()
      assert.equals(0, registry:get_plugin_count())
    end)
  end)

  describe("Dependency ordering", function()
    local registry

    before_each(function()
      registry = PluginRegistry.new()
    end)

    it("should initialize in dependency order", function()
      local init_order = {}

      registry:register_plugin({
        name = "plugin-a",
        version = "1.0.0",
        definition = {
          dependencies = {["plugin-b"] = "^1.0.0"},
          on_init = function()
            table.insert(init_order, "plugin-a")
          end,
        },
        state = "loaded",
        module = {},
      })
      registry:register_plugin({
        name = "plugin-b",
        version = "1.0.0",
        definition = {
          on_init = function()
            table.insert(init_order, "plugin-b")
          end,
        },
        state = "loaded",
        module = {},
      })

      registry:initialize_all_plugins()

      assert.equals(2, #init_order)
      assert.equals("plugin-b", init_order[1])
      assert.equals("plugin-a", init_order[2])
    end)

    it("should report dependency resolution errors", function()
      registry:register_plugin({
        name = "plugin-a",
        version = "1.0.0",
        definition = {
          dependencies = {["missing"] = "^1.0.0"},
        },
        state = "loaded",
        module = {},
      })

      local results = registry:initialize_all_plugins()
      assert.equals(0, #results.initialized)
      assert.equals(1, #results.failed)
      assert.truthy(results.failed[1].error:match("missing"))
    end)
  end)

  describe("Error tracking", function()
    local registry

    before_each(function()
      registry = PluginRegistry.new()
      registry:register_plugin({
        name = "test-plugin",
        version = "1.0.0",
        definition = {},
        state = "loaded",
        module = {},
      })
    end)

    it("should set and get plugin error", function()
      registry:set_plugin_error("test-plugin", "Test error")
      assert.equals("Test error", registry:get_plugin_error("test-plugin"))
      assert.equals("error", registry:get_plugin("test-plugin").state)
    end)

    it("should get all failed plugins", function()
      registry:set_plugin_error("test-plugin", "Error 1")

      local failed = registry:get_failed_plugins()
      assert.equals(1, #failed)
      assert.equals("test-plugin", failed[1].name)
      assert.equals("Error 1", failed[1].error)
    end)
  end)

  describe("Clear and reset", function()
    it("should clear all plugins", function()
      local registry = PluginRegistry.new()
      registry:register_plugin({
        name = "test",
        version = "1.0.0",
        definition = {},
        state = "loaded",
        module = {},
      })

      registry:clear()
      assert.equals(0, registry:get_plugin_count())
      assert.is_false(registry:is_loaded())
    end)
  end)
end)
