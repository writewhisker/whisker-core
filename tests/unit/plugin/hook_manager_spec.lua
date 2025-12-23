--- Hook Manager Tests
-- @module tests.unit.plugin.hook_manager_spec

describe("HookManager", function()
  local HookManager
  local manager

  before_each(function()
    package.loaded["whisker.plugin.hook_manager"] = nil
    package.loaded["whisker.plugin.hook_types"] = nil
    HookManager = require("whisker.plugin.hook_manager")
    manager = HookManager.new()
  end)

  describe("new()", function()
    it("creates a new instance", function()
      assert.is_not_nil(manager)
      assert.equal(0, manager:get_total_hook_count())
    end)
  end)

  describe("register_hook()", function()
    it("registers a hook and returns ID", function()
      local id = manager:register_hook("on_story_start", function() end)
      assert.is_string(id)
      assert.is_true(id:match("^hook_") ~= nil)
    end)

    it("increments hook count", function()
      assert.equal(0, manager:get_hook_count("on_story_start"))
      manager:register_hook("on_story_start", function() end)
      assert.equal(1, manager:get_hook_count("on_story_start"))
      manager:register_hook("on_story_start", function() end)
      assert.equal(2, manager:get_hook_count("on_story_start"))
    end)

    it("uses default priority when not specified", function()
      local id = manager:register_hook("on_story_start", function() end)
      local hooks = manager:get_hooks("on_story_start")
      assert.equal(HookManager.DEFAULT_PRIORITY, hooks[1].priority)
    end)

    it("accepts custom priority", function()
      local id = manager:register_hook("on_story_start", function() end, 10)
      local hooks = manager:get_hooks("on_story_start")
      assert.equal(10, hooks[1].priority)
    end)

    it("clamps priority to valid range", function()
      manager:register_hook("on_story_start", function() end, -50)
      manager:register_hook("on_story_start", function() end, 150)
      local hooks = manager:get_hooks("on_story_start")
      assert.equal(HookManager.MIN_PRIORITY, hooks[1].priority)
      assert.equal(HookManager.MAX_PRIORITY, hooks[2].priority)
    end)

    it("maintains priority order", function()
      manager:register_hook("test", function() end, 50)
      manager:register_hook("test", function() end, 10)
      manager:register_hook("test", function() end, 90)
      manager:register_hook("test", function() end, 30)

      local hooks = manager:get_hooks("test")
      assert.equal(4, #hooks)
      assert.equal(10, hooks[1].priority)
      assert.equal(30, hooks[2].priority)
      assert.equal(50, hooks[3].priority)
      assert.equal(90, hooks[4].priority)
    end)

    it("stores plugin name", function()
      local id = manager:register_hook("test", function() end, 50, "my-plugin")
      local hooks = manager:get_hooks("test")
      assert.equal("my-plugin", hooks[1].plugin_name)
    end)

    it("errors on invalid event type", function()
      assert.has_error(function()
        manager:register_hook(123, function() end)
      end)
    end)

    it("errors on invalid callback type", function()
      assert.has_error(function()
        manager:register_hook("test", "not a function")
      end)
    end)
  end)

  describe("unregister_hook()", function()
    it("removes registered hook", function()
      local id = manager:register_hook("test", function() end)
      assert.equal(1, manager:get_hook_count("test"))

      local success = manager:unregister_hook(id)
      assert.is_true(success)
      assert.equal(0, manager:get_hook_count("test"))
    end)

    it("returns false for unknown ID", function()
      local success = manager:unregister_hook("unknown_id")
      assert.is_false(success)
    end)

    it("returns false for already removed hook", function()
      local id = manager:register_hook("test", function() end)
      manager:unregister_hook(id)
      local success = manager:unregister_hook(id)
      assert.is_false(success)
    end)
  end)

  describe("trigger()", function()
    it("calls registered handlers", function()
      local called = false
      manager:register_hook("test", function()
        called = true
      end)
      manager:trigger("test")
      assert.is_true(called)
    end)

    it("passes arguments to handlers", function()
      local received_args = {}
      manager:register_hook("test", function(a, b, c)
        received_args = {a, b, c}
      end)
      manager:trigger("test", 1, 2, 3)
      assert.same({1, 2, 3}, received_args)
    end)

    it("calls handlers in priority order", function()
      local order = {}
      manager:register_hook("test", function() table.insert(order, "mid") end, 50)
      manager:register_hook("test", function() table.insert(order, "first") end, 10)
      manager:register_hook("test", function() table.insert(order, "last") end, 90)

      manager:trigger("test")
      assert.same({"first", "mid", "last"}, order)
    end)

    it("returns results for each handler", function()
      manager:register_hook("test", function() return "a" end)
      manager:register_hook("test", function() return "b" end)

      local results = manager:trigger("test")
      assert.equal(2, #results)
      assert.is_true(results[1].success)
      assert.is_true(results[2].success)
    end)

    it("catches handler errors", function()
      manager:register_hook("test", function()
        error("test error")
      end)

      local results = manager:trigger("test")
      assert.equal(1, #results)
      assert.is_false(results[1].success)
      assert.is_true(results[1].result:match("test error") ~= nil)
    end)

    it("continues after handler error", function()
      local order = {}
      manager:register_hook("test", function() table.insert(order, 1) end, 10)
      manager:register_hook("test", function() error("error") end, 20)
      manager:register_hook("test", function() table.insert(order, 3) end, 30)

      manager:trigger("test")
      assert.same({1, 3}, order)
    end)

    it("returns empty results for no hooks", function()
      local results = manager:trigger("unknown_event")
      assert.same({}, results)
    end)
  end)

  describe("transform()", function()
    it("returns initial value when no hooks", function()
      local value = manager:transform("test", "initial")
      assert.equal("initial", value)
    end)

    it("passes value through single handler", function()
      manager:register_hook("test", function(value)
        return value .. "_modified"
      end)

      local value = manager:transform("test", "initial")
      assert.equal("initial_modified", value)
    end)

    it("chains value through multiple handlers", function()
      manager:register_hook("test", function(v) return v .. "_a" end, 10)
      manager:register_hook("test", function(v) return v .. "_b" end, 20)
      manager:register_hook("test", function(v) return v .. "_c" end, 30)

      local value = manager:transform("test", "start")
      assert.equal("start_a_b_c", value)
    end)

    it("passes additional arguments to handlers", function()
      manager:register_hook("test", function(value, ctx, name)
        return value .. "_" .. name
      end)

      local value = manager:transform("test", "start", "ctx", "extra")
      assert.equal("start_extra", value)
    end)

    it("keeps value when handler returns nil", function()
      manager:register_hook("test", function(v) return v .. "_a" end, 10)
      manager:register_hook("test", function(v) return nil end, 20)  -- Return nil
      manager:register_hook("test", function(v) return v .. "_c" end, 30)

      local value = manager:transform("test", "start")
      assert.equal("start_a_c", value)
    end)

    it("catches handler errors and continues", function()
      manager:register_hook("test", function(v) return v .. "_a" end, 10)
      manager:register_hook("test", function(v) error("error") end, 20)
      manager:register_hook("test", function(v) return v .. "_c" end, 30)

      local value = manager:transform("test", "start")
      assert.equal("start_a_c", value)
    end)

    it("returns results along with value", function()
      manager:register_hook("test", function(v) return v * 2 end)

      local value, results = manager:transform("test", 5)
      assert.equal(10, value)
      assert.equal(1, #results)
      assert.is_true(results[1].success)
    end)
  end)

  describe("emit()", function()
    it("uses transform for transform hooks", function()
      local HookTypes = require("whisker.plugin.hook_types")
      manager:register_hook("on_passage_render", function(html)
        return html .. "_modified"
      end)

      local value = manager:emit("on_passage_render", "html")
      assert.equal("html_modified", value)
    end)

    it("uses trigger for observer hooks", function()
      local called = false
      manager:register_hook("on_story_start", function(ctx)
        called = true
      end)

      local value = manager:emit("on_story_start", "ctx")
      assert.is_nil(value)  -- Observer returns nil
      assert.is_true(called)
    end)

    it("treats unknown events as observer", function()
      local called = false
      manager:register_hook("custom_event", function()
        called = true
      end)

      local value = manager:emit("custom_event")
      assert.is_nil(value)
      assert.is_true(called)
    end)
  end)

  describe("get_hooks()", function()
    it("returns empty table for no hooks", function()
      local hooks = manager:get_hooks("unknown")
      assert.same({}, hooks)
    end)

    it("returns registered hooks", function()
      manager:register_hook("test", function() end, 50, "plugin1")
      manager:register_hook("test", function() end, 10, "plugin2")

      local hooks = manager:get_hooks("test")
      assert.equal(2, #hooks)
      assert.equal("plugin2", hooks[1].plugin_name)  -- Lower priority first
      assert.equal("plugin1", hooks[2].plugin_name)
    end)
  end)

  describe("get_registered_events()", function()
    it("returns empty for no hooks", function()
      local events = manager:get_registered_events()
      assert.same({}, events)
    end)

    it("returns events with hooks", function()
      manager:register_hook("event_a", function() end)
      manager:register_hook("event_b", function() end)
      manager:register_hook("event_a", function() end)

      local events = manager:get_registered_events()
      assert.equal(2, #events)
    end)

    it("returns sorted events", function()
      manager:register_hook("c", function() end)
      manager:register_hook("a", function() end)
      manager:register_hook("b", function() end)

      local events = manager:get_registered_events()
      assert.same({"a", "b", "c"}, events)
    end)
  end)

  describe("clear_event()", function()
    it("removes all hooks for event", function()
      manager:register_hook("test", function() end)
      manager:register_hook("test", function() end)
      manager:register_hook("other", function() end)

      local removed = manager:clear_event("test")
      assert.equal(2, removed)
      assert.equal(0, manager:get_hook_count("test"))
      assert.equal(1, manager:get_hook_count("other"))
    end)

    it("returns 0 for unknown event", function()
      local removed = manager:clear_event("unknown")
      assert.equal(0, removed)
    end)
  end)

  describe("clear_all()", function()
    it("removes all hooks", function()
      manager:register_hook("a", function() end)
      manager:register_hook("b", function() end)
      manager:register_hook("c", function() end)

      local removed = manager:clear_all()
      assert.equal(3, removed)
      assert.equal(0, manager:get_total_hook_count())
    end)
  end)

  describe("clear_plugin_hooks()", function()
    it("removes only hooks for specific plugin", function()
      manager:register_hook("test", function() end, 50, "plugin-a")
      manager:register_hook("test", function() end, 50, "plugin-b")
      manager:register_hook("other", function() end, 50, "plugin-a")

      local removed = manager:clear_plugin_hooks("plugin-a")
      assert.equal(2, removed)
      assert.equal(1, manager:get_total_hook_count())
    end)
  end)

  describe("pause/resume", function()
    it("pauses event execution", function()
      local called = false
      manager:register_hook("test", function() called = true end)

      manager:pause_event("test")
      manager:trigger("test")
      assert.is_false(called)
    end)

    it("resumes event execution", function()
      local called = false
      manager:register_hook("test", function() called = true end)

      manager:pause_event("test")
      manager:resume_event("test")
      manager:trigger("test")
      assert.is_true(called)
    end)

    it("checks if event is paused", function()
      assert.is_false(manager:is_event_paused("test"))
      manager:pause_event("test")
      assert.is_true(manager:is_event_paused("test"))
    end)

    it("pauses all events globally", function()
      local called_a = false
      local called_b = false
      manager:register_hook("a", function() called_a = true end)
      manager:register_hook("b", function() called_b = true end)

      manager:pause_all()
      manager:trigger("a")
      manager:trigger("b")
      assert.is_false(called_a)
      assert.is_false(called_b)
    end)

    it("resumes all events globally", function()
      local called = false
      manager:register_hook("test", function() called = true end)

      manager:pause_all()
      manager:resume_all()
      manager:trigger("test")
      assert.is_true(called)
    end)
  end)

  describe("get_plugin_hooks()", function()
    it("returns hooks for specific plugin", function()
      manager:register_hook("event1", function() end, 50, "my-plugin")
      manager:register_hook("event2", function() end, 50, "my-plugin")
      manager:register_hook("event1", function() end, 50, "other-plugin")

      local hooks = manager:get_plugin_hooks("my-plugin")
      assert.equal(2, #hooks)
      for _, h in ipairs(hooks) do
        assert.equal("my-plugin", h.hook.plugin_name)
      end
    end)
  end)

  describe("register_plugin_hooks()", function()
    it("registers all hooks from table", function()
      local hooks = {
        on_story_start = function() end,
        on_passage_enter = function() end,
      }

      local ids = manager:register_plugin_hooks("my-plugin", hooks, 30)
      assert.equal(2, #ids)
      assert.equal(2, manager:get_total_hook_count())
    end)

    it("uses provided priority", function()
      local hooks = {
        test = function() end,
      }

      manager:register_plugin_hooks("my-plugin", hooks, 25)
      local registered = manager:get_hooks("test")
      assert.equal(25, registered[1].priority)
    end)

    it("skips non-function values", function()
      local hooks = {
        on_story_start = function() end,
        some_value = "not a function",
      }

      local ids = manager:register_plugin_hooks("my-plugin", hooks)
      assert.equal(1, #ids)
    end)
  end)

  describe("create_scope()", function()
    it("creates a scope object", function()
      local scope = manager:create_scope()
      assert.is_not_nil(scope)
      assert.is_function(scope.register)
      assert.is_function(scope.close)
    end)

    it("registers hooks in scope", function()
      local scope = manager:create_scope()
      scope:register("test", function() end)
      scope:register("test", function() end)

      assert.equal(2, manager:get_hook_count("test"))
    end)

    it("unregisters all hooks on close", function()
      local scope = manager:create_scope()
      scope:register("test", function() end)
      scope:register("other", function() end)

      local removed = scope:close()
      assert.equal(2, removed)
      assert.equal(0, manager:get_total_hook_count())
    end)

    it("returns hook IDs", function()
      local scope = manager:create_scope()
      local id1 = scope:register("test", function() end)
      local id2 = scope:register("test", function() end)

      local hooks = scope:get_hooks()
      assert.equal(2, #hooks)
    end)
  end)
end)
