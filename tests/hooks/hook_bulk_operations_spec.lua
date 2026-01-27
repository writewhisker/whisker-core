-- Test suite for Hook Bulk Operations
-- WLS 1.0 GAP-072: hook.all implementation
-- WLS 1.0 GAP-073: Dedicated hook.clear() and hook.reset()

local HookManager = require("lib.whisker.wls2.hook_manager")

describe("Hook Bulk Operations (GAP-072, GAP-073)", function()
  local manager

  before_each(function()
    manager = HookManager.new()
    -- Set up test hooks in a passage
    manager:register_hook("test_passage", "status", "Active")
    manager:register_hook("test_passage", "health", "100")
    manager:register_hook("test_passage", "mana", "50")
    manager:register_hook("test_passage", "stamina", "75")
    manager:register_hook("test_passage", "other_data", "data")
  end)

  describe("GAP-073: hook.reset()", function()
    it("should reset hook to original content", function()
      local hook_id = "test_passage_health"

      -- Modify the hook
      manager:replace_hook(hook_id, "50")
      local hook = manager:get_hook(hook_id)
      assert.equals("50", hook.current_content)

      -- Reset it
      local success = manager:reset_hook(hook_id)

      assert.is_true(success)
      hook = manager:get_hook(hook_id)
      assert.equals("100", hook.current_content)  -- Original content
      assert.equals(0, hook.modified_count)
    end)

    it("should return false for non-existent hook", function()
      local success, err = manager:reset_hook("nonexistent_hook")
      assert.is_false(success)
      assert.has.match("not found", err)
    end)

    it("should clear the cleared flag", function()
      local hook_id = "test_passage_health"

      manager:clear_hook(hook_id)
      assert.is_true(manager:is_cleared(hook_id))

      manager:reset_hook(hook_id)
      assert.is_false(manager:is_cleared(hook_id))
    end)
  end)

  describe("GAP-072: hide_all()", function()
    it("should hide all hooks in passage", function()
      local count = manager:hide_all("test_passage")

      assert.equals(5, count)

      local hooks = manager:get_passage_hooks("test_passage")
      for _, hook in ipairs(hooks) do
        assert.is_false(hook.visible)
      end
    end)

    it("should hide only matching pattern", function()
      local count = manager:hide_all("test_passage", "^s")  -- status, stamina

      assert.equals(2, count)

      -- Verify specific hooks
      assert.is_false(manager:get_hook("test_passage_status").visible)
      assert.is_false(manager:get_hook("test_passage_stamina").visible)
      assert.is_true(manager:get_hook("test_passage_health").visible)
    end)

    it("should return 0 for empty passage", function()
      local count = manager:hide_all("empty_passage")
      assert.equals(0, count)
    end)
  end)

  describe("GAP-072: show_all()", function()
    it("should show all hidden hooks", function()
      -- First hide all
      manager:hide_all("test_passage")

      -- Then show all
      local count = manager:show_all("test_passage")

      assert.equals(5, count)

      local hooks = manager:get_passage_hooks("test_passage")
      for _, hook in ipairs(hooks) do
        assert.is_true(hook.visible)
      end
    end)

    it("should show only matching pattern", function()
      manager:hide_all("test_passage")

      local count = manager:show_all("test_passage", "health")

      assert.equals(1, count)
      assert.is_true(manager:get_hook("test_passage_health").visible)
      assert.is_false(manager:get_hook("test_passage_status").visible)
    end)
  end)

  describe("GAP-072: replace_all()", function()
    it("should replace content in all hooks", function()
      local count = manager:replace_all("test_passage", "[REDACTED]")

      assert.equals(5, count)

      local hooks = manager:get_passage_hooks("test_passage")
      for _, hook in ipairs(hooks) do
        assert.equals("[REDACTED]", hook.current_content)
      end
    end)

    it("should replace only matching pattern", function()
      local count = manager:replace_all("test_passage", "0", "^m")  -- mana only

      assert.equals(1, count)
      assert.equals("0", manager:get_hook("test_passage_mana").current_content)
      assert.equals("100", manager:get_hook("test_passage_health").current_content)
    end)
  end)

  describe("GAP-072: clear_all()", function()
    it("should clear all hooks to empty string", function()
      local count = manager:clear_all("test_passage")

      assert.equals(5, count)

      local hooks = manager:get_passage_hooks("test_passage")
      for _, hook in ipairs(hooks) do
        assert.equals("", hook.current_content)
        assert.is_true(hook.cleared)
      end
    end)

    it("should clear only matching pattern", function()
      local count = manager:clear_all("test_passage", "^sta")  -- status, stamina

      assert.equals(2, count)
      assert.equals("", manager:get_hook("test_passage_status").current_content)
      assert.equals("", manager:get_hook("test_passage_stamina").current_content)
      assert.equals("100", manager:get_hook("test_passage_health").current_content)
    end)
  end)

  describe("GAP-072: reset_all()", function()
    it("should reset all hooks to original content", function()
      -- Modify all hooks
      manager:replace_all("test_passage", "modified")

      -- Reset all
      local count = manager:reset_all("test_passage")

      assert.equals(5, count)
      assert.equals("Active", manager:get_hook("test_passage_status").current_content)
      assert.equals("100", manager:get_hook("test_passage_health").current_content)
      assert.equals("50", manager:get_hook("test_passage_mana").current_content)
    end)

    it("should reset only matching pattern", function()
      manager:replace_all("test_passage", "X")

      local count = manager:reset_all("test_passage", "health")

      assert.equals(1, count)
      assert.equals("100", manager:get_hook("test_passage_health").current_content)
      assert.equals("X", manager:get_hook("test_passage_mana").current_content)
    end)
  end)

  describe("GAP-072: each()", function()
    it("should iterate over all hooks", function()
      local names = {}
      manager:each("test_passage", function(hook)
        table.insert(names, hook.name)
      end)

      assert.equals(5, #names)
      -- Check that expected hooks are in the list
      local found_status, found_health = false, false
      for _, n in ipairs(names) do
        if n == "status" then found_status = true end
        if n == "health" then found_health = true end
      end
      assert.is_true(found_status)
      assert.is_true(found_health)
    end)

    it("should filter by pattern", function()
      local names = {}
      manager:each("test_passage", function(hook)
        table.insert(names, hook.name)
      end, "^s")

      assert.equals(2, #names)  -- status, stamina
    end)
  end)

  describe("GAP-072: find_hooks()", function()
    it("should find hooks by name pattern", function()
      local results = manager:find_hooks("test_passage", { pattern = "^s" })

      assert.equals(2, #results)
    end)

    it("should find hooks by visibility", function()
      manager:hide_hook("test_passage_health")
      manager:hide_hook("test_passage_mana")

      local hidden = manager:find_hooks("test_passage", { visible = false })
      local visible = manager:find_hooks("test_passage", { visible = true })

      assert.equals(2, #hidden)
      assert.equals(3, #visible)
    end)

    it("should find hooks by content pattern", function()
      local results = manager:find_hooks("test_passage", { content_pattern = "^%d+$" })

      assert.equals(3, #results)  -- 100, 50, 75
    end)

    it("should combine criteria", function()
      manager:hide_hook("test_passage_health")

      local results = manager:find_hooks("test_passage", {
        content_pattern = "^%d+$",
        visible = true
      })

      assert.equals(2, #results)  -- 50, 75 (not health which is hidden)
    end)
  end)
end)

