-- Tests for breakpoint_manager.lua
package.path = "./tools/whisker-debug/?.lua;./tools/whisker-debug/?/init.lua;" .. package.path

describe("BreakpointManager", function()
  local BreakpointManager

  before_each(function()
    package.loaded["lib.breakpoint_manager"] = nil
    BreakpointManager = require("lib.breakpoint_manager")
  end)

  describe("new", function()
    it("creates a new instance", function()
      local mgr = BreakpointManager.new()
      assert.is_not_nil(mgr)
    end)
  end)

  describe("set_breakpoints", function()
    it("stores breakpoints for a file", function()
      local mgr = BreakpointManager.new()
      local verified = mgr:set_breakpoints("test.ink", {10, 25, 30}, {})

      assert.equals(3, #verified)
      assert.is_true(verified[1].verified)
      assert.equals(10, verified[1].line)
    end)

    it("stores breakpoints with conditions", function()
      local mgr = BreakpointManager.new()
      mgr:set_breakpoints("test.ink", {10}, {{condition = "x > 5"}})

      local condition = mgr:get_condition("test.ink", 10)
      assert.equals("x > 5", condition)
    end)

    it("replaces existing breakpoints for file", function()
      local mgr = BreakpointManager.new()
      mgr:set_breakpoints("test.ink", {10, 20}, {})
      mgr:set_breakpoints("test.ink", {30}, {})

      assert.is_false(mgr:has_breakpoint("test.ink", 10))
      assert.is_true(mgr:has_breakpoint("test.ink", 30))
    end)
  end)

  describe("has_breakpoint", function()
    it("returns true for existing breakpoint", function()
      local mgr = BreakpointManager.new()
      mgr:set_breakpoints("test.ink", {10}, {})

      assert.is_true(mgr:has_breakpoint("test.ink", 10))
    end)

    it("returns false for non-existing breakpoint", function()
      local mgr = BreakpointManager.new()
      mgr:set_breakpoints("test.ink", {10}, {})

      assert.is_false(mgr:has_breakpoint("test.ink", 15))
    end)

    it("returns false for non-existing file", function()
      local mgr = BreakpointManager.new()

      assert.is_false(mgr:has_breakpoint("other.ink", 10))
    end)
  end)

  describe("check_condition", function()
    it("returns true when no condition", function()
      local mgr = BreakpointManager.new()
      mgr:set_breakpoints("test.ink", {10}, {{}})

      assert.is_true(mgr:check_condition("test.ink", 10, {}))
    end)

    it("evaluates condition against state", function()
      local mgr = BreakpointManager.new()
      mgr:set_breakpoints("test.ink", {10}, {{condition = "x > 5"}})

      assert.is_true(mgr:check_condition("test.ink", 10, {x = 10}))
      assert.is_false(mgr:check_condition("test.ink", 10, {x = 3}))
    end)

    it("returns false for invalid condition", function()
      local mgr = BreakpointManager.new()
      mgr:set_breakpoints("test.ink", {10}, {{condition = "invalid syntax +++"}})

      assert.is_false(mgr:check_condition("test.ink", 10, {}))
    end)
  end)

  describe("check_hit_count", function()
    it("increments hit count each call", function()
      local mgr = BreakpointManager.new()
      mgr:set_breakpoints("test.ink", {10}, {{hitCondition = "== 3"}})

      assert.is_false(mgr:check_hit_count("test.ink", 10))  -- hit 1
      assert.is_false(mgr:check_hit_count("test.ink", 10))  -- hit 2
      assert.is_true(mgr:check_hit_count("test.ink", 10))   -- hit 3
    end)

    it("handles >= condition", function()
      local mgr = BreakpointManager.new()
      mgr:set_breakpoints("test.ink", {10}, {{hitCondition = ">= 2"}})

      assert.is_false(mgr:check_hit_count("test.ink", 10))  -- hit 1
      assert.is_true(mgr:check_hit_count("test.ink", 10))   -- hit 2
      assert.is_true(mgr:check_hit_count("test.ink", 10))   -- hit 3
    end)

    it("returns true when no hit condition", function()
      local mgr = BreakpointManager.new()
      mgr:set_breakpoints("test.ink", {10}, {{}})

      assert.is_true(mgr:check_hit_count("test.ink", 10))
    end)
  end)

  describe("should_break", function()
    it("returns true for simple breakpoint", function()
      local mgr = BreakpointManager.new()
      mgr:set_breakpoints("test.ink", {10}, {{}})

      local should, msg = mgr:should_break("test.ink", 10, {})
      assert.is_true(should)
      assert.is_nil(msg)
    end)

    it("returns false when condition not met", function()
      local mgr = BreakpointManager.new()
      mgr:set_breakpoints("test.ink", {10}, {{condition = "x > 5"}})

      local should, msg = mgr:should_break("test.ink", 10, {x = 2})
      assert.is_false(should)
    end)

    it("returns log message for logpoint", function()
      local mgr = BreakpointManager.new()
      mgr:set_breakpoints("test.ink", {10}, {{logMessage = "Value is {x}"}})

      local should, msg = mgr:should_break("test.ink", 10, {x = 42})
      assert.is_false(should)  -- Logpoints don't break
      assert.equals("Value is 42", msg)
    end)
  end)

  describe("clear_breakpoints", function()
    it("removes breakpoints for a file", function()
      local mgr = BreakpointManager.new()
      mgr:set_breakpoints("test.ink", {10}, {})
      mgr:clear_breakpoints("test.ink")

      assert.is_false(mgr:has_breakpoint("test.ink", 10))
    end)
  end)

  describe("set_enabled", function()
    it("can disable a breakpoint", function()
      local mgr = BreakpointManager.new()
      mgr:set_breakpoints("test.ink", {10}, {})
      mgr:set_enabled("test.ink", 10, false)

      assert.is_false(mgr:has_breakpoint("test.ink", 10))
    end)

    it("can re-enable a breakpoint", function()
      local mgr = BreakpointManager.new()
      mgr:set_breakpoints("test.ink", {10}, {})
      mgr:set_enabled("test.ink", 10, false)
      mgr:set_enabled("test.ink", 10, true)

      assert.is_true(mgr:has_breakpoint("test.ink", 10))
    end)
  end)
end)
