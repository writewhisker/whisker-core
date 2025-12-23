--- Story Hooks Integration Tests
-- @module tests.unit.plugin.story_hooks_spec

describe("StoryHooks", function()
  local StoryHooks
  local HookManager
  local story_hooks
  local hook_manager

  before_each(function()
    package.loaded["whisker.plugin.story_hooks"] = nil
    package.loaded["whisker.plugin.hook_manager"] = nil
    package.loaded["whisker.plugin.hook_types"] = nil

    StoryHooks = require("whisker.plugin.story_hooks")
    HookManager = require("whisker.plugin.hook_manager")

    hook_manager = HookManager.new()
    story_hooks = StoryHooks.new(hook_manager)
  end)

  describe("new()", function()
    it("creates instance with hook manager", function()
      assert.is_not_nil(story_hooks)
      assert.equal(hook_manager, story_hooks:get_hook_manager())
    end)

    it("errors without hook manager", function()
      assert.has_error(function()
        StoryHooks.new(nil)
      end)
    end)

    it("accepts optional state manager", function()
      local state_manager = { get = function() end }
      local hooks = StoryHooks.new(hook_manager, state_manager)
      assert.is_not_nil(hooks)
    end)
  end)

  describe("story lifecycle hooks", function()
    it("fires on_story_start", function()
      local called = false
      hook_manager:register_hook("on_story_start", function(ctx)
        called = true
        assert.is_not_nil(ctx)
      end)

      story_hooks:story_start()
      assert.is_true(called)
    end)

    it("fires on_story_end", function()
      local called = false
      hook_manager:register_hook("on_story_end", function(ctx)
        called = true
      end)

      story_hooks:story_end()
      assert.is_true(called)
    end)

    it("fires on_story_reset", function()
      local called = false
      hook_manager:register_hook("on_story_reset", function(ctx)
        called = true
      end)

      story_hooks:story_reset()
      assert.is_true(called)
    end)
  end)

  describe("passage hooks", function()
    local test_passage

    before_each(function()
      test_passage = {
        name = "test_passage",
        content = "Test content",
        tags = {"test"},
      }
    end)

    it("fires on_passage_enter with passage", function()
      local received_passage

      hook_manager:register_hook("on_passage_enter", function(ctx, passage)
        received_passage = passage
      end)

      story_hooks:passage_enter(test_passage)
      assert.equal(test_passage, received_passage)
    end)

    it("sets current passage on enter", function()
      story_hooks:passage_enter(test_passage)
      assert.equal(test_passage, story_hooks:get_current_passage())
    end)

    it("fires on_passage_exit with passage", function()
      local received_passage

      hook_manager:register_hook("on_passage_exit", function(ctx, passage)
        received_passage = passage
      end)

      story_hooks:passage_exit(test_passage)
      assert.equal(test_passage, received_passage)
    end)

    it("transforms passage render output", function()
      hook_manager:register_hook("on_passage_render", function(html, ctx, passage)
        return html .. "_modified"
      end)

      local result = story_hooks:passage_render("original", test_passage)
      assert.equal("original_modified", result)
    end)

    it("chains multiple passage render hooks", function()
      hook_manager:register_hook("on_passage_render", function(html) return html .. "_a" end, 10)
      hook_manager:register_hook("on_passage_render", function(html) return html .. "_b" end, 20)

      local result = story_hooks:passage_render("start", test_passage)
      assert.equal("start_a_b", result)
    end)

    it("includes current passage in context", function()
      story_hooks:passage_enter(test_passage)

      local received_ctx
      hook_manager:register_hook("on_passage_exit", function(ctx)
        received_ctx = ctx
      end)

      story_hooks:passage_exit(test_passage)
      assert.equal(test_passage, received_ctx.current_passage)
    end)
  end)

  describe("choice hooks", function()
    local test_choices

    before_each(function()
      test_choices = {
        {text = "Choice 1", target = "passage1"},
        {text = "Choice 2", target = "passage2"},
        {text = "Choice 3", target = "passage3"},
      }
    end)

    it("transforms choice presentation", function()
      hook_manager:register_hook("on_choice_present", function(choices, ctx)
        -- Filter to first 2 choices
        return {choices[1], choices[2]}
      end)

      local result = story_hooks:choice_present(test_choices)
      assert.equal(2, #result)
    end)

    it("chains multiple choice present hooks", function()
      hook_manager:register_hook("on_choice_present", function(choices)
        -- Add metadata
        for _, c in ipairs(choices) do
          c.modified_by = "hook1"
        end
        return choices
      end, 10)

      hook_manager:register_hook("on_choice_present", function(choices)
        -- Filter disabled
        local filtered = {}
        for _, c in ipairs(choices) do
          if not c.disabled then
            table.insert(filtered, c)
          end
        end
        return filtered
      end, 20)

      test_choices[2].disabled = true
      local result = story_hooks:choice_present(test_choices)
      assert.equal(2, #result)
      assert.equal("hook1", result[1].modified_by)
    end)

    it("fires on_choice_select", function()
      local received_choice

      hook_manager:register_hook("on_choice_select", function(ctx, choice)
        received_choice = choice
      end)

      story_hooks:choice_select(test_choices[1])
      assert.equal(test_choices[1], received_choice)
    end)

    it("transforms choice evaluation", function()
      hook_manager:register_hook("on_choice_evaluate", function(result, ctx, choice)
        -- Override evaluation result
        return false
      end)

      local result = story_hooks:choice_evaluate(true, test_choices[1])
      assert.is_false(result)
    end)
  end)

  describe("variable hooks", function()
    it("transforms variable set value", function()
      hook_manager:register_hook("on_variable_set", function(value, ctx, name)
        if type(value) == "number" then
          return value * 2
        end
        return value
      end)

      local result = story_hooks:variable_set(10, "score")
      assert.equal(20, result)
    end)

    it("transforms variable get value", function()
      hook_manager:register_hook("on_variable_get", function(value, ctx, name)
        if name == "secret" then
          return "***hidden***"
        end
        return value
      end)

      local result = story_hooks:variable_get("actual_value", "secret")
      assert.equal("***hidden***", result)
    end)

    it("fires on_state_change with changes", function()
      local received_changes

      hook_manager:register_hook("on_state_change", function(ctx, changes)
        received_changes = changes
      end)

      local changes = {score = 100, name = "Player"}
      story_hooks:state_change(changes)
      assert.same(changes, received_changes)
    end)

    it("passes variable name to hooks", function()
      local received_name

      hook_manager:register_hook("on_variable_set", function(value, ctx, name)
        received_name = name
        return value
      end)

      story_hooks:variable_set(42, "health")
      assert.equal("health", received_name)
    end)
  end)

  describe("persistence hooks", function()
    it("transforms save data", function()
      hook_manager:register_hook("on_save", function(data, ctx)
        data.plugin_data = {version = "1.0"}
        return data
      end)

      local save_data = {state = {}}
      local result = story_hooks:on_save(save_data)
      assert.is_not_nil(result.plugin_data)
      assert.equal("1.0", result.plugin_data.version)
    end)

    it("transforms load data", function()
      hook_manager:register_hook("on_load", function(data, ctx)
        -- Extract and process plugin data
        if data.plugin_data then
          data.processed = true
        end
        return data
      end)

      local save_data = {state = {}, plugin_data = {}}
      local result = story_hooks:on_load(save_data)
      assert.is_true(result.processed)
    end)

    it("transforms save list", function()
      hook_manager:register_hook("on_save_list", function(saves, ctx)
        -- Add metadata to each save
        for _, save in ipairs(saves) do
          save.has_plugin_data = true
        end
        return saves
      end)

      local saves = {{name = "save1"}, {name = "save2"}}
      local result = story_hooks:on_save_list(saves)
      assert.is_true(result[1].has_plugin_data)
      assert.is_true(result[2].has_plugin_data)
    end)
  end)

  describe("error hooks", function()
    it("fires on_error with error info", function()
      local received_error

      hook_manager:register_hook("on_error", function(ctx, error_info)
        received_error = error_info
      end)

      local error_info = {
        message = "Test error",
        stack = "stack trace",
      }

      story_hooks:on_error(error_info)
      assert.equal("Test error", received_error.message)
    end)
  end)

  describe("state manager integration", function()
    it("includes state manager in context", function()
      local mock_state = {
        get = function(self, key) return "value" end,
        set = function(self, key, value) end,
      }

      story_hooks:set_state_manager(mock_state)

      local received_ctx
      hook_manager:register_hook("on_story_start", function(ctx)
        received_ctx = ctx
      end)

      story_hooks:story_start()
      assert.equal(mock_state, received_ctx.state)
    end)
  end)

  describe("has_hooks()", function()
    it("returns false when no hooks registered", function()
      assert.is_false(story_hooks:has_hooks("on_story_start"))
    end)

    it("returns true when hooks registered", function()
      hook_manager:register_hook("on_story_start", function() end)
      assert.is_true(story_hooks:has_hooks("on_story_start"))
    end)
  end)

  describe("get_statistics()", function()
    it("returns statistics", function()
      hook_manager:register_hook("on_story_start", function() end)
      hook_manager:register_hook("on_passage_enter", function() end)
      hook_manager:register_hook("on_passage_enter", function() end)

      local stats = story_hooks:get_statistics()
      assert.equal(3, stats.total_hooks)
      assert.equal(2, stats.events_with_hooks)
      assert.equal(1, stats.hooks_by_event["on_story_start"])
      assert.equal(2, stats.hooks_by_event["on_passage_enter"])
    end)
  end)

  describe("performance tracking", function()
    it("can enable performance tracking", function()
      story_hooks:set_performance_tracking(true, 5)
      -- Just verify it doesn't error
      hook_manager:register_hook("on_story_start", function() end)
      story_hooks:story_start()
    end)
  end)

  describe("error handling", function()
    it("continues after hook error", function()
      local second_called = false

      hook_manager:register_hook("on_story_start", function()
        error("test error")
      end, 10)

      hook_manager:register_hook("on_story_start", function()
        second_called = true
      end, 20)

      story_hooks:story_start()
      assert.is_true(second_called)
    end)

    it("returns results including errors", function()
      hook_manager:register_hook("on_story_start", function()
        error("test error")
      end)

      local results = story_hooks:story_start()
      assert.equal(1, #results)
      assert.is_false(results[1].success)
    end)
  end)
end)
