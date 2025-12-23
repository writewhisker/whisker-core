-- Tests for stack_frame_manager.lua
package.path = "./tools/whisker-debug/?.lua;./tools/whisker-debug/?/init.lua;" .. package.path

describe("StackFrameManager", function()
  local StackFrameManager

  before_each(function()
    package.loaded["lib.stack_frame_manager"] = nil
    StackFrameManager = require("lib.stack_frame_manager")
  end)

  describe("new", function()
    it("creates a new instance", function()
      local mgr = StackFrameManager.new()
      assert.is_not_nil(mgr)
      assert.equals(0, mgr:get_depth())
    end)
  end)

  describe("push_frame", function()
    it("adds frame to stack", function()
      local mgr = StackFrameManager.new()
      local id = mgr:push_frame("Start", {path = "story.ink", line = 1})

      assert.is_true(id >= 1)
      assert.equals(1, mgr:get_depth())
    end)

    it("returns incrementing IDs", function()
      local mgr = StackFrameManager.new()
      local id1 = mgr:push_frame("Start", {})
      local id2 = mgr:push_frame("Chapter1", {})

      assert.equals(id1 + 1, id2)
    end)
  end)

  describe("pop_frame", function()
    it("removes top frame", function()
      local mgr = StackFrameManager.new()
      mgr:push_frame("Start", {})
      mgr:push_frame("Chapter1", {})

      local popped = mgr:pop_frame()

      assert.equals("Chapter1", popped.passage)
      assert.equals(1, mgr:get_depth())
    end)

    it("returns nil for empty stack", function()
      local mgr = StackFrameManager.new()
      local popped = mgr:pop_frame()

      assert.is_nil(popped)
    end)
  end)

  describe("get_stack_trace", function()
    it("returns frames in reverse order (newest first)", function()
      local mgr = StackFrameManager.new()
      mgr:push_frame("Start", {path = "story.ink", line = 1})
      mgr:push_frame("Chapter1", {path = "story.ink", line = 10})
      mgr:push_frame("Combat", {path = "story.ink", line = 25})

      local frames = mgr:get_stack_trace()

      assert.equals(3, #frames)
      assert.equals("Combat", frames[1].name)
      assert.equals("Chapter1", frames[2].name)
      assert.equals("Start", frames[3].name)
    end)

    it("includes source information", function()
      local mgr = StackFrameManager.new()
      mgr:push_frame("Start", {path = "/path/to/story.ink", line = 5})

      local frames = mgr:get_stack_trace()

      assert.equals("story.ink", frames[1].source.name)
      assert.equals("/path/to/story.ink", frames[1].source.path)
      assert.equals(5, frames[1].line)
    end)

    it("returns empty array for empty stack", function()
      local mgr = StackFrameManager.new()
      local frames = mgr:get_stack_trace()

      assert.equals(0, #frames)
    end)
  end)

  describe("get_frame", function()
    it("returns frame by ID", function()
      local mgr = StackFrameManager.new()
      local id1 = mgr:push_frame("Start", {})
      local id2 = mgr:push_frame("Chapter1", {})

      local frame1 = mgr:get_frame(id1)
      local frame2 = mgr:get_frame(id2)

      assert.equals("Start", frame1.passage)
      assert.equals("Chapter1", frame2.passage)
    end)

    it("returns nil for invalid ID", function()
      local mgr = StackFrameManager.new()
      local frame = mgr:get_frame(9999)

      assert.is_nil(frame)
    end)
  end)

  describe("get_current_frame", function()
    it("returns top frame", function()
      local mgr = StackFrameManager.new()
      mgr:push_frame("Start", {})
      mgr:push_frame("Chapter1", {})

      local current = mgr:get_current_frame()

      assert.equals("Chapter1", current.passage)
    end)

    it("returns nil for empty stack", function()
      local mgr = StackFrameManager.new()
      local current = mgr:get_current_frame()

      assert.is_nil(current)
    end)
  end)

  describe("update_current_line", function()
    it("updates line of top frame", function()
      local mgr = StackFrameManager.new()
      mgr:push_frame("Start", {path = "story.ink", line = 1})
      mgr:update_current_line(15)

      local current = mgr:get_current_frame()
      assert.equals(15, current.line)
    end)
  end)

  describe("clear", function()
    it("removes all frames", function()
      local mgr = StackFrameManager.new()
      mgr:push_frame("Start", {})
      mgr:push_frame("Chapter1", {})

      mgr:clear()

      assert.equals(0, mgr:get_depth())
    end)
  end)

  describe("locals and temps", function()
    it("stores and retrieves locals", function()
      local mgr = StackFrameManager.new()
      local id = mgr:push_frame("Start", {})
      mgr:set_locals({x = 10, y = 20})

      local locals = mgr:get_frame_locals(id)

      assert.equals(10, locals.x)
      assert.equals(20, locals.y)
    end)

    it("stores and retrieves temps", function()
      local mgr = StackFrameManager.new()
      local id = mgr:push_frame("Start", {})
      mgr:set_temps({_temp = "value"})

      local temps = mgr:get_frame_temps(id)

      assert.equals("value", temps._temp)
    end)
  end)
end)
