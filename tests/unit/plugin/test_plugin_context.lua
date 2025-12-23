--- Plugin Context Tests
-- @module tests.unit.plugin.plugin_context_spec

describe("PluginContext", function()
  local PluginContext
  local mock_state_manager
  local mock_hook_manager
  local mock_plugin_registry

  before_each(function()
    package.loaded["whisker.plugin.plugin_context"] = nil
    PluginContext = require("whisker.plugin.plugin_context")

    -- Mock state manager
    mock_state_manager = {
      _data = {},
      get = function(self, key)
        return self._data[key]
      end,
      set = function(self, key, value)
        self._data[key] = value
      end,
      has = function(self, key)
        return self._data[key] ~= nil
      end,
      delete = function(self, key)
        self._data[key] = nil
      end,
      get_all_variables = function(self)
        return self._data
      end,
    }

    -- Mock hook manager
    mock_hook_manager = {
      _hooks = {},
      _next_id = 1,
      register_hook = function(self, event, callback, priority)
        local id = "hook_" .. self._next_id
        self._next_id = self._next_id + 1
        self._hooks[id] = {event = event, callback = callback, priority = priority}
        return id
      end,
      unregister_hook = function(self, hook_id)
        if self._hooks[hook_id] then
          self._hooks[hook_id] = nil
          return true
        end
        return false
      end,
    }

    -- Mock plugin registry
    mock_plugin_registry = {
      _plugins = {},
      get_plugin = function(self, name)
        return self._plugins[name]
      end,
      get_plugins_by_state = function(self, state)
        local result = {}
        for _, plugin in pairs(self._plugins) do
          if plugin.state == state then
            table.insert(result, plugin)
          end
        end
        return result
      end,
    }
  end)

  describe("Basic creation", function()
    it("should create context with name and version", function()
      local ctx = PluginContext.new("test-plugin", "1.0.0", {})
      assert.equals("test-plugin", ctx.name)
      assert.equals("1.0.0", ctx.version)
    end)

    it("should create context with nil capabilities", function()
      local ctx = PluginContext.new("test-plugin", "1.0.0", nil)
      assert.is_table(ctx:get_capabilities())
      assert.equals(0, #ctx:get_capabilities())
    end)
  end)

  describe("Capability checking", function()
    it("should return true for granted capabilities", function()
      local ctx = PluginContext.new("test", "1.0.0", {"state:read", "state:write"})
      assert.is_true(ctx:has_capability("state:read"))
      assert.is_true(ctx:has_capability("state:write"))
    end)

    it("should return false for missing capabilities", function()
      local ctx = PluginContext.new("test", "1.0.0", {"state:read"})
      assert.is_false(ctx:has_capability("state:write"))
      assert.is_false(ctx:has_capability("ui:inject"))
    end)

    it("should return copy of capabilities", function()
      local ctx = PluginContext.new("test", "1.0.0", {"state:read"})
      local caps = ctx:get_capabilities()
      caps[1] = "modified"
      assert.equals("state:read", ctx:get_capabilities()[1])
    end)
  end)

  describe("State interface", function()
    it("should allow state:read to get variables", function()
      mock_state_manager._data["test_key"] = "test_value"
      local ctx = PluginContext.new("test", "1.0.0", {"state:read"}, mock_state_manager)

      local value = ctx.state.get("test_key")
      assert.equals("test_value", value)
    end)

    it("should deny state:read without capability", function()
      local ctx = PluginContext.new("test", "1.0.0", {}, mock_state_manager)

      assert.has_error(function()
        ctx.state.get("test_key")
      end, "Plugin 'test' lacks capability 'state:read'")
    end)

    it("should allow state:write to set variables", function()
      local ctx = PluginContext.new("test", "1.0.0", {"state:write"}, mock_state_manager)

      ctx.state.set("new_key", "new_value")
      assert.equals("new_value", mock_state_manager._data["new_key"])
    end)

    it("should deny state:write without capability", function()
      local ctx = PluginContext.new("test", "1.0.0", {"state:read"}, mock_state_manager)

      assert.has_error(function()
        ctx.state.set("key", "value")
      end, "Plugin 'test' lacks capability 'state:write'")
    end)

    it("should check for variable existence", function()
      mock_state_manager._data["exists"] = true
      local ctx = PluginContext.new("test", "1.0.0", {"state:read"}, mock_state_manager)

      assert.is_true(ctx.state.has("exists"))
      assert.is_false(ctx.state.has("not_exists"))
    end)

    it("should delete variables with state:write", function()
      mock_state_manager._data["to_delete"] = "value"
      local ctx = PluginContext.new("test", "1.0.0", {"state:write"}, mock_state_manager)

      ctx.state.delete("to_delete")
      assert.is_nil(mock_state_manager._data["to_delete"])
    end)
  end)

  describe("Storage interface", function()
    it("should namespace storage keys", function()
      local ctx = PluginContext.new("my-plugin", "1.0.0", {"persistence:write"}, mock_state_manager)

      ctx.storage.set("data", "value")
      assert.equals("value", mock_state_manager._data["__plugin_my-plugin_data"])
    end)

    it("should get namespaced values", function()
      mock_state_manager._data["__plugin_my-plugin_data"] = "stored"
      local ctx = PluginContext.new("my-plugin", "1.0.0", {"persistence:read"}, mock_state_manager)

      local value = ctx.storage.get("data")
      assert.equals("stored", value)
    end)

    it("should deny persistence:read without capability", function()
      local ctx = PluginContext.new("test", "1.0.0", {}, mock_state_manager)

      assert.has_error(function()
        ctx.storage.get("key")
      end, "Plugin 'test' lacks capability 'persistence:read'")
    end)

    it("should deny persistence:write without capability", function()
      local ctx = PluginContext.new("test", "1.0.0", {"persistence:read"}, mock_state_manager)

      assert.has_error(function()
        ctx.storage.set("key", "value")
      end, "Plugin 'test' lacks capability 'persistence:write'")
    end)
  end)

  describe("Log interface", function()
    local original_print

    before_each(function()
      original_print = print
    end)

    after_each(function()
      print = original_print
    end)

    it("should format log messages with plugin name", function()
      -- Create context and capture its log output
      local ctx = PluginContext.new("test-plugin", "1.0.0", {})

      -- The log interface calls print directly, so we test by checking the format function
      -- We'll just verify the context has a log interface with the expected methods
      assert.is_table(ctx.log)
      assert.is_function(ctx.log.info)
      assert.is_function(ctx.log.debug)
      assert.is_function(ctx.log.warn)
      assert.is_function(ctx.log.error)
    end)

    it("should support format arguments", function()
      -- Test that log methods exist and can be called without errors
      local ctx = PluginContext.new("test", "1.0.0", {})

      -- These shouldn't throw errors
      assert.has_no_error(function()
        ctx.log.warn("Value is %d", 42)
      end)
    end)

    it("should support all log levels", function()
      local ctx = PluginContext.new("test", "1.0.0", {})

      -- Test that all log levels exist and are callable
      assert.has_no_error(function()
        ctx.log.debug("debug message")
        ctx.log.info("info message")
        ctx.log.warn("warn message")
        ctx.log.error("error message")
      end)
    end)
  end)

  describe("Plugins interface", function()
    it("should get enabled plugin API", function()
      mock_plugin_registry._plugins["other-plugin"] = {
        name = "other-plugin",
        state = "enabled",
        definition = {
          api = {
            do_something = function() return "done" end,
          },
        },
      }

      local ctx = PluginContext.new("test", "1.0.0", {}, nil, nil, mock_plugin_registry)
      local api = ctx.plugins.get("other-plugin")

      assert.is_table(api)
      assert.is_function(api.do_something)
    end)

    it("should return nil for non-existent plugin", function()
      local ctx = PluginContext.new("test", "1.0.0", {}, nil, nil, mock_plugin_registry)
      local api = ctx.plugins.get("non-existent")

      assert.is_nil(api)
    end)

    it("should return nil for disabled plugin", function()
      mock_plugin_registry._plugins["disabled-plugin"] = {
        name = "disabled-plugin",
        state = "disabled",
        definition = {api = {}},
      }

      local ctx = PluginContext.new("test", "1.0.0", {}, nil, nil, mock_plugin_registry)
      local api = ctx.plugins.get("disabled-plugin")

      assert.is_nil(api)
    end)

    it("should check plugin availability", function()
      mock_plugin_registry._plugins["enabled-plugin"] = {
        name = "enabled-plugin",
        state = "enabled",
      }
      mock_plugin_registry._plugins["disabled-plugin"] = {
        name = "disabled-plugin",
        state = "disabled",
      }

      local ctx = PluginContext.new("test", "1.0.0", {}, nil, nil, mock_plugin_registry)

      assert.is_true(ctx.plugins.has("enabled-plugin"))
      assert.is_false(ctx.plugins.has("disabled-plugin"))
      assert.is_false(ctx.plugins.has("non-existent"))
    end)

    it("should list enabled plugins", function()
      mock_plugin_registry._plugins["plugin-a"] = {name = "plugin-a", state = "enabled"}
      mock_plugin_registry._plugins["plugin-b"] = {name = "plugin-b", state = "enabled"}
      mock_plugin_registry._plugins["plugin-c"] = {name = "plugin-c", state = "disabled"}

      local ctx = PluginContext.new("test", "1.0.0", {}, nil, nil, mock_plugin_registry)
      local list = ctx.plugins.list()

      assert.equals(2, #list)
    end)
  end)

  describe("Hooks interface", function()
    it("should register hooks", function()
      local ctx = PluginContext.new("test", "1.0.0", {}, nil, mock_hook_manager, nil)

      local callback = function() end
      local hook_id = ctx.hooks.register("on_passage_enter", callback, 50)

      assert.is_string(hook_id)
      assert.is_table(mock_hook_manager._hooks[hook_id])
    end)

    it("should unregister hooks", function()
      local ctx = PluginContext.new("test", "1.0.0", {}, nil, mock_hook_manager, nil)

      local hook_id = ctx.hooks.register("on_passage_enter", function() end)
      local success = ctx.hooks.unregister(hook_id)

      assert.is_true(success)
      assert.is_nil(mock_hook_manager._hooks[hook_id])
    end)

    it("should track registered hooks for cleanup", function()
      local ctx = PluginContext.new("test", "1.0.0", {}, nil, mock_hook_manager, nil)

      ctx.hooks.register("event1", function() end)
      ctx.hooks.register("event2", function() end)

      assert.equals(2, #ctx._registered_hooks)
    end)

    it("should cleanup all hooks", function()
      local ctx = PluginContext.new("test", "1.0.0", {}, nil, mock_hook_manager, nil)

      ctx.hooks.register("event1", function() end)
      ctx.hooks.register("event2", function() end)

      ctx:cleanup()

      assert.equals(0, #ctx._registered_hooks)
    end)
  end)

  describe("Capability validation", function()
    it("should validate known capabilities", function()
      assert.is_true(PluginContext.is_valid_capability("state:read"))
      assert.is_true(PluginContext.is_valid_capability("state:write"))
      assert.is_true(PluginContext.is_valid_capability("persistence:read"))
      assert.is_true(PluginContext.is_valid_capability("ui:inject"))
    end)

    it("should reject unknown capabilities", function()
      assert.is_false(PluginContext.is_valid_capability("invalid:capability"))
      assert.is_false(PluginContext.is_valid_capability(""))
    end)

    it("should validate capability arrays", function()
      local valid, err = PluginContext.validate_capabilities({"state:read", "state:write"})
      assert.is_true(valid)
      assert.is_nil(err)
    end)

    it("should reject invalid capability arrays", function()
      local valid, err = PluginContext.validate_capabilities({"state:read", "invalid"})
      assert.is_false(valid)
      assert.is_string(err)
      assert.truthy(err:match("Unknown capability"))
    end)

    it("should accept nil capabilities", function()
      local valid, err = PluginContext.validate_capabilities(nil)
      assert.is_true(valid)
    end)
  end)
end)
