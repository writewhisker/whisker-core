--- Security Context Unit Tests
-- @module tests.unit.security.security_context_spec

describe("SecurityContext", function()
  local SecurityContext

  before_each(function()
    package.loaded["whisker.security.security_context"] = nil
    SecurityContext = require("whisker.security.security_context")
    SecurityContext.clear()
  end)

  after_each(function()
    SecurityContext.clear()
  end)

  describe("enter and exit", function()
    it("enters and exits context", function()
      assert.is_true(SecurityContext.enter("test-plugin", {"READ_STATE"}))
      assert.equals("test-plugin", SecurityContext.get_plugin_id())

      local success = SecurityContext.exit()
      assert.is_true(success)
      assert.is_nil(SecurityContext.get_plugin_id())
    end)

    it("supports nested contexts", function()
      SecurityContext.enter("plugin-a", {"READ_STATE"})
      SecurityContext.enter("plugin-b", {"NETWORK"})

      assert.equals("plugin-b", SecurityContext.get_plugin_id())
      assert.equals(2, SecurityContext.depth())

      SecurityContext.exit()
      assert.equals("plugin-a", SecurityContext.get_plugin_id())
      assert.equals(1, SecurityContext.depth())

      SecurityContext.exit()
      assert.is_nil(SecurityContext.get_plugin_id())
    end)

    it("returns error when exiting empty stack", function()
      local success, err = SecurityContext.exit()
      assert.is_false(success)
      assert.is_string(err)
    end)
  end)

  describe("has_capability", function()
    it("returns true for declared capabilities", function()
      SecurityContext.enter("test", {"READ_STATE", "NETWORK"})

      assert.is_true(SecurityContext.has_capability("READ_STATE"))
      assert.is_true(SecurityContext.has_capability("NETWORK"))
      assert.is_false(SecurityContext.has_capability("WRITE_STATE"))

      SecurityContext.exit()
    end)

    it("returns true when no context (core code)", function()
      assert.is_true(SecurityContext.has_capability("READ_STATE"))
      assert.is_true(SecurityContext.has_capability("ANYTHING"))
    end)
  end)

  describe("in_plugin_context", function()
    it("returns false when no context", function()
      assert.is_false(SecurityContext.in_plugin_context())
    end)

    it("returns true when in context", function()
      SecurityContext.enter("test", {})
      assert.is_true(SecurityContext.in_plugin_context())
      SecurityContext.exit()
    end)
  end)

  describe("is_nested", function()
    it("returns false for single context", function()
      SecurityContext.enter("test", {})
      assert.is_false(SecurityContext.is_nested())
      SecurityContext.exit()
    end)

    it("returns true for nested contexts", function()
      SecurityContext.enter("outer", {})
      SecurityContext.enter("inner", {})
      assert.is_true(SecurityContext.is_nested())
      SecurityContext.exit()
      SecurityContext.exit()
    end)
  end)

  describe("get_parent_id", function()
    it("returns nil for top-level context", function()
      SecurityContext.enter("test", {})
      assert.is_nil(SecurityContext.get_parent_id())
      SecurityContext.exit()
    end)

    it("returns parent id for nested context", function()
      SecurityContext.enter("parent", {})
      SecurityContext.enter("child", {})
      assert.equals("parent", SecurityContext.get_parent_id())
      SecurityContext.exit()
      SecurityContext.exit()
    end)
  end)

  describe("with_context", function()
    it("executes function in context", function()
      local captured_id = nil

      local success, result = SecurityContext.with_context(
        "test-plugin",
        {"READ_STATE"},
        function()
          captured_id = SecurityContext.get_plugin_id()
          return "result"
        end
      )

      assert.is_true(success)
      assert.equals("result", result)
      assert.equals("test-plugin", captured_id)
      assert.is_nil(SecurityContext.get_plugin_id())
    end)

    it("cleans up on error", function()
      local success, err = SecurityContext.with_context(
        "test",
        {},
        function()
          error("test error")
        end
      )

      assert.is_false(success)
      assert.matches("test error", err)
      assert.is_nil(SecurityContext.get_plugin_id())
    end)
  end)

  describe("validate", function()
    it("passes when stack is empty", function()
      local valid, err = SecurityContext.validate()
      assert.is_true(valid)
      assert.is_nil(err)
    end)

    it("fails when contexts not exited", function()
      SecurityContext.enter("leaked", {})

      local valid, err = SecurityContext.validate()
      assert.is_false(valid)
      assert.matches("leak", err:lower())
      assert.matches("leaked", err)

      SecurityContext.clear()
    end)
  end)

  describe("get_stack", function()
    it("returns context stack for debugging", function()
      SecurityContext.enter("a", {"READ_STATE"})
      SecurityContext.enter("b", {"NETWORK"})

      local stack = SecurityContext.get_stack()
      assert.equals(2, #stack)
      assert.equals("a", stack[1].plugin_id)
      assert.equals("b", stack[2].plugin_id)

      SecurityContext.clear()
    end)
  end)
end)
