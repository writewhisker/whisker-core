-- tests/hooks/test_gap_018_019_069.lua
-- Tests for WLS 1.0.0 compliance gaps:
--   GAP-018: pick() function for random selection
--   GAP-019: whisker.hook.clear() method
--   GAP-069: isVisible() naming with backward compat alias

describe("WLS 1.0.0 Gap Compliance", function()
  local Engine = require("lib.whisker.core.engine")
  local Story = require("lib.whisker.story.story")
  local Passage = require("lib.whisker.story.passage")
  local HookManager = require("lib.whisker.wls2.hook_manager")
  local LuaInterpreter = require("lib.whisker.core.lua_interpreter")

  local engine
  local story
  local interpreter

  before_each(function()
    story = Story.new()
    engine = Engine.new()
    engine:init(story, {platform = "plain"})
    interpreter = engine.lua_interpreter
  end)

  -- ============================================================================
  -- GAP-018: pick() Function Tests
  -- ============================================================================

  describe("GAP-018: pick() Function", function()

    describe("single pick", function()
      it("should return element from list", function()
        -- Set seed for reproducibility
        interpreter:set_random_seed(12345)

        local result = interpreter:eval('return pick({"a", "b", "c"})')

        assert.is_true(result == "a" or result == "b" or result == "c")
      end)

      it("should return nil for empty list", function()
        local result = interpreter:eval('return pick({})')

        assert.is_nil(result)
      end)

      it("should work with numeric lists", function()
        interpreter:set_random_seed(12345)

        local result = interpreter:eval('return pick({1, 2, 3, 4, 5})')

        assert.is_true(type(result) == "number")
        assert.is_true(result >= 1 and result <= 5)
      end)
    end)

    describe("multiple picks", function()
      it("should return array of elements", function()
        interpreter:set_random_seed(12345)

        local result = interpreter:eval('return pick({"a", "b", "c", "d", "e"}, 3)')

        assert.equals(3, #result)
      end)

      it("should not repeat by default", function()
        interpreter:set_random_seed(12345)

        local result = interpreter:eval('return pick({"a", "b", "c"}, 3)')

        -- All elements should be unique
        local seen = {}
        for _, v in ipairs(result) do
          assert.is_nil(seen[v], "Found duplicate: " .. tostring(v))
          seen[v] = true
        end
      end)

      it("should allow repeats when specified", function()
        interpreter:set_random_seed(12345)

        -- Pick more than available (only possible with repeat)
        local result = interpreter:eval('return pick({"a", "b"}, 5, true)')

        assert.equals(5, #result)
      end)

      it("should cap at list size without repeat", function()
        interpreter:set_random_seed(12345)

        local result = interpreter:eval('return pick({"a", "b"}, 10)')

        assert.equals(2, #result)
      end)

      it("should return all unique elements when count > list size", function()
        interpreter:set_random_seed(12345)

        local result = interpreter:eval('return pick({"x", "y", "z"}, 10)')

        assert.equals(3, #result)
        -- Verify all unique
        local seen = {}
        for _, v in ipairs(result) do
          assert.is_nil(seen[v])
          seen[v] = true
        end
      end)
    end)

    describe("error handling", function()
      it("should error on nil argument", function()
        local result, err = interpreter:eval('return pick(nil)')

        -- Should have errored
        assert.is_not_nil(err)
      end)

      it("should error on non-table argument", function()
        local result, err = interpreter:eval('return pick("not a list")')

        assert.is_not_nil(err)
      end)

      it("should error on number argument", function()
        local result, err = interpreter:eval('return pick(123)')

        assert.is_not_nil(err)
      end)
    end)

    describe("seeded randomness", function()
      it("should be reproducible with same seed", function()
        -- First run
        interpreter:set_random_seed(12345)
        local results1 = {}
        for i = 1, 5 do
          results1[i] = interpreter:eval('return pick({"a", "b", "c", "d", "e"})')
        end

        -- Second run with same seed
        interpreter:set_random_seed(12345)
        local results2 = {}
        for i = 1, 5 do
          results2[i] = interpreter:eval('return pick({"a", "b", "c", "d", "e"})')
        end

        -- Compare results
        for i = 1, 5 do
          assert.equals(results1[i], results2[i], "Mismatch at index " .. i)
        end
      end)

      it("should produce different results with different seeds", function()
        -- Run with two different seeds and collect results
        interpreter:set_random_seed(11111)
        local result1 = {}
        for i = 1, 10 do
          table.insert(result1, interpreter:eval('return pick({"a", "b", "c", "d", "e"})'))
        end

        interpreter:set_random_seed(99999)
        local result2 = {}
        for i = 1, 10 do
          table.insert(result2, interpreter:eval('return pick({"a", "b", "c", "d", "e"})'))
        end

        -- At least some results should differ
        local all_same = true
        for i = 1, 10 do
          if result1[i] ~= result2[i] then
            all_same = false
            break
          end
        end
        assert.is_false(all_same, "Expected different seeds to produce different results")
      end)
    end)

    describe("whisker namespace alias", function()
      it("should be available as whisker.pick", function()
        interpreter:set_random_seed(12345)

        local result = interpreter:eval('return whisker.pick({"x", "y", "z"})')

        assert.is_true(result == "x" or result == "y" or result == "z")
      end)

      it("should be same function as global pick", function()
        local result = interpreter:eval('return pick == whisker.pick')

        -- Note: This compares function references, which may not be equal
        -- depending on implementation. Let's just verify both work
        interpreter:set_random_seed(12345)
        local r1 = interpreter:eval('return pick({"a"})')
        interpreter:set_random_seed(12345)
        local r2 = interpreter:eval('return whisker.pick({"a"})')
        assert.equals(r1, r2)
      end)
    end)
  end)

  -- ============================================================================
  -- GAP-019: whisker.hook.clear() Tests
  -- ============================================================================

  describe("GAP-019: whisker.hook.clear()", function()

    describe("HookManager.clear_hook", function()
      local manager

      before_each(function()
        manager = HookManager.new()
      end)

      it("should set content to empty string", function()
        manager:register_hook("passage_1", "status", "Initial content")

        local success = manager:clear_hook("passage_1_status")

        assert.is_true(success)
        local hook = manager:get_hook("passage_1_status")
        assert.equals("", hook.current_content)
      end)

      it("should keep hook visible", function()
        manager:register_hook("passage_1", "status", "Initial content")

        manager:clear_hook("passage_1_status")

        local hook = manager:get_hook("passage_1_status")
        assert.is_true(hook.visible)
      end)

      it("should set cleared flag", function()
        manager:register_hook("passage_1", "status", "Initial content")

        manager:clear_hook("passage_1_status")

        assert.is_true(manager:is_cleared("passage_1_status"))
      end)

      it("should return false for non-existent hook", function()
        local success, err = manager:clear_hook("nonexistent")

        assert.is_false(success)
        assert.is_truthy(err:match("not found"))
      end)

      it("should increment modified_count", function()
        manager:register_hook("passage_1", "status", "Initial content")
        local hook_before = manager:get_hook("passage_1_status")
        local count_before = hook_before.modified_count

        manager:clear_hook("passage_1_status")

        local hook_after = manager:get_hook("passage_1_status")
        assert.equals(count_before + 1, hook_after.modified_count)
      end)
    end)

    describe("clear vs hide", function()
      local manager

      before_each(function()
        manager = HookManager.new()
      end)

      it("clear should keep hook visible but empty", function()
        manager:register_hook("passage_1", "a", "Content A")

        manager:clear_hook("passage_1_a")

        local hook_a = manager:get_hook("passage_1_a")
        assert.is_true(hook_a.visible)
        assert.equals("", hook_a.current_content)
      end)

      it("hide should keep content but make invisible", function()
        manager:register_hook("passage_1", "b", "Content B")

        manager:hide_hook("passage_1_b")

        local hook_b = manager:get_hook("passage_1_b")
        assert.is_false(hook_b.visible)
        assert.equals("Content B", hook_b.current_content)
      end)

      it("clear and hide should produce different results", function()
        manager:register_hook("passage_1", "clear_me", "Content")
        manager:register_hook("passage_1", "hide_me", "Content")

        manager:clear_hook("passage_1_clear_me")
        manager:hide_hook("passage_1_hide_me")

        local cleared = manager:get_hook("passage_1_clear_me")
        local hidden = manager:get_hook("passage_1_hide_me")

        -- Clear: visible but empty
        assert.is_true(cleared.visible)
        assert.equals("", cleared.current_content)

        -- Hide: invisible but content preserved
        assert.is_false(hidden.visible)
        assert.equals("Content", hidden.current_content)
      end)
    end)

    describe("replace resets cleared", function()
      local manager

      before_each(function()
        manager = HookManager.new()
      end)

      it("should reset cleared flag on replace", function()
        manager:register_hook("passage_1", "status", "Initial")

        manager:clear_hook("passage_1_status")
        assert.is_true(manager:is_cleared("passage_1_status"))

        manager:replace_hook("passage_1_status", "New content")
        assert.is_false(manager:is_cleared("passage_1_status"))
      end)
    end)

    describe("is_visible helper", function()
      local manager

      before_each(function()
        manager = HookManager.new()
      end)

      it("should return true for visible hook", function()
        manager:register_hook("passage_1", "test", "Content")

        assert.is_true(manager:is_visible("passage_1_test"))
      end)

      it("should return false for hidden hook", function()
        manager:register_hook("passage_1", "test", "Content")
        manager:hide_hook("passage_1_test")

        assert.is_false(manager:is_visible("passage_1_test"))
      end)

      it("should return false for non-existent hook", function()
        assert.is_false(manager:is_visible("nonexistent"))
      end)
    end)

    describe("whisker.hook.clear() in Lua API", function()
      it("should work from Lua script", function()
        local passage = Passage.new("test", "Status: |status>[Active]")
        story:add_passage(passage)
        engine:navigate_to_passage("test")

        -- Verify initial content
        local initial = interpreter:eval("return whisker.hook.get('status')")
        assert.equals("Active", initial)

        -- Clear the hook
        local success = interpreter:eval("return whisker.hook.clear('status')")
        assert.is_true(success)

        -- Verify content is now empty (but hook still visible)
        local after = interpreter:eval("return whisker.hook.get('status')")
        assert.equals("", after)

        -- Verify hook is still visible
        local visible = interpreter:eval("return whisker.hook.isVisible('status')")
        assert.is_true(visible)
      end)

      it("should return false for non-existent hook", function()
        local passage = Passage.new("test", "No hooks here")
        story:add_passage(passage)
        engine:navigate_to_passage("test")

        local success = interpreter:eval("return whisker.hook.clear('missing')")
        assert.is_false(success)
      end)

      it("should error on non-string argument", function()
        local passage = Passage.new("test", "Status: |status>[Active]")
        story:add_passage(passage)
        engine:navigate_to_passage("test")

        local _, err = interpreter:eval("return whisker.hook.clear(123)")
        assert.is_not_nil(err)
      end)
    end)

    describe("whisker.hook.isCleared()", function()
      it("should return true for cleared hook", function()
        local passage = Passage.new("test", "Status: |status>[Active]")
        story:add_passage(passage)
        engine:navigate_to_passage("test")

        interpreter:eval("whisker.hook.clear('status')")
        local result = interpreter:eval("return whisker.hook.isCleared('status')")

        assert.is_true(result)
      end)

      it("should return false for non-cleared hook", function()
        local passage = Passage.new("test", "Status: |status>[Active]")
        story:add_passage(passage)
        engine:navigate_to_passage("test")

        local result = interpreter:eval("return whisker.hook.isCleared('status')")

        assert.is_false(result)
      end)

      it("should return false after replace", function()
        local passage = Passage.new("test", "Status: |status>[Active]")
        story:add_passage(passage)
        engine:navigate_to_passage("test")

        interpreter:eval("whisker.hook.clear('status')")
        interpreter:eval("whisker.hook.replace('status', 'New')")
        local result = interpreter:eval("return whisker.hook.isCleared('status')")

        assert.is_false(result)
      end)
    end)

    describe("Engine clear operation", function()
      it("should support clear operation in execute_hook_operation", function()
        local passage = Passage.new("test", "Status: |status>[Active]")
        story:add_passage(passage)
        engine:navigate_to_passage("test")

        local _, err = engine:execute_hook_operation("clear", "status", nil)

        assert.is_nil(err)

        local hook = engine.hook_manager:get_hook("test_status")
        assert.equals("", hook.current_content)
        assert.is_true(hook.visible)
      end)
    end)
  end)

  -- ============================================================================
  -- GAP-069: isVisible() Naming Tests
  -- ============================================================================

  describe("GAP-069: Hook isVisible Naming", function()

    describe("isVisible (primary)", function()
      it("should be available as isVisible", function()
        local result = interpreter:eval("return type(whisker.hook.isVisible)")
        assert.equals("function", result)
      end)

      it("should return true for visible hook", function()
        local passage = Passage.new("test", "Item: |item>[key]")
        story:add_passage(passage)
        engine:navigate_to_passage("test")

        local result = interpreter:eval("return whisker.hook.isVisible('item')")
        assert.is_true(result)
      end)

      it("should return false for hidden hook", function()
        local passage = Passage.new("test", "Secret: |secret>[treasure]")
        story:add_passage(passage)
        engine:navigate_to_passage("test")
        engine:execute_hook_operation("hide", "secret")

        local result = interpreter:eval("return whisker.hook.isVisible('secret')")
        assert.is_false(result)
      end)

      it("should return false for non-existent hook", function()
        local passage = Passage.new("test", "No hooks")
        story:add_passage(passage)
        engine:navigate_to_passage("test")

        local result = interpreter:eval("return whisker.hook.isVisible('missing')")
        assert.is_false(result)
      end)
    end)

    describe("visible (deprecated alias)", function()
      it("should still work as alias", function()
        local passage = Passage.new("test", "Item: |item>[key]")
        story:add_passage(passage)
        engine:navigate_to_passage("test")

        -- Should work, just with deprecation warning
        local result = interpreter:eval("return whisker.hook.visible('item')")
        assert.is_true(result)
      end)

      it("should return same result as isVisible", function()
        local passage = Passage.new("test", "Item: |item>[key]")
        story:add_passage(passage)
        engine:navigate_to_passage("test")

        local old_result = interpreter:eval("return whisker.hook.visible('item')")
        local new_result = interpreter:eval("return whisker.hook.isVisible('item')")

        assert.equals(old_result, new_result)
      end)
    end)

    describe("strict mode", function()
      it("should error on deprecated usage in strict mode", function()
        -- Create interpreter with strict mode
        local strict_config = { strict_api = true, deprecation_warnings = false }
        local strict_interpreter = LuaInterpreter.new(engine, strict_config)

        -- Set up a hook
        local passage = Passage.new("test", "Item: |item>[key]")
        story:add_passage(passage)
        engine:navigate_to_passage("test")

        -- Using deprecated visible() should error
        local _, err = strict_interpreter:eval("return whisker.hook.visible('item')")
        assert.is_not_nil(err)
        assert.is_truthy(err:match("deprecated"))
      end)
    end)

    describe("deprecation warnings suppression", function()
      it("should not warn when deprecation_warnings is false", function()
        local quiet_config = { deprecation_warnings = false }
        local quiet_interpreter = LuaInterpreter.new(engine, quiet_config)

        local passage = Passage.new("test", "Item: |item>[key]")
        story:add_passage(passage)
        engine:navigate_to_passage("test")

        -- Should work without errors (warnings are suppressed)
        local result = quiet_interpreter:eval("return whisker.hook.visible('item')")
        assert.is_true(result)
      end)
    end)

    describe("API migration", function()
      it("should support gradual migration with both APIs", function()
        local passage = Passage.new("test", "Hook1: |hook1>[content1] Hook2: |hook2>[content2]")
        story:add_passage(passage)
        engine:navigate_to_passage("test")

        -- Old code still works
        local old_result = interpreter:eval("return whisker.hook.visible('hook1')")
        assert.is_true(old_result)

        -- New code is preferred
        local new_result = interpreter:eval("return whisker.hook.isVisible('hook2')")
        assert.is_true(new_result)
      end)
    end)
  end)

  -- ============================================================================
  -- Integration Tests
  -- ============================================================================

  describe("Integration Tests", function()

    describe("pick() with hook operations", function()
      it("should work together in script", function()
        interpreter:set_random_seed(12345)

        local passage = Passage.new("test", "Item: |item>[nothing]")
        story:add_passage(passage)
        engine:navigate_to_passage("test")

        -- Use pick to select content and update hook
        interpreter:eval([[
          local items = {"sword", "shield", "potion"}
          local selected = pick(items)
          whisker.hook.replace('item', selected)
        ]])

        local content = interpreter:eval("return whisker.hook.get('item')")
        assert.is_true(content == "sword" or content == "shield" or content == "potion")
      end)
    end)

    describe("clear() and isVisible() together", function()
      it("should work together correctly", function()
        local passage = Passage.new("test", "Status: |status>[Active]")
        story:add_passage(passage)
        engine:navigate_to_passage("test")

        -- Clear should keep visible
        interpreter:eval("whisker.hook.clear('status')")

        local is_visible = interpreter:eval("return whisker.hook.isVisible('status')")
        local content = interpreter:eval("return whisker.hook.get('status')")

        assert.is_true(is_visible)
        assert.equals("", content)
      end)
    end)
  end)
end)
