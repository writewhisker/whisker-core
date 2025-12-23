--- Sandbox Escape Prevention Tests
-- Security tests for sandbox escape attempts
-- @module tests.unit.security.sandbox_escapes_spec

describe("Sandbox Escape Prevention", function()
  local Sandbox

  before_each(function()
    package.loaded["whisker.security.sandbox"] = nil
    package.loaded["whisker.security.security_context"] = nil
    Sandbox = require("whisker.security.sandbox")
    Sandbox.reset()
    Sandbox.init()
  end)

  after_each(function()
    local SecurityContext = require("whisker.security.security_context")
    SecurityContext.clear()
  end)

  describe("Dangerous Global Access", function()
    it("blocks os.execute access", function()
      local code = [[
        return os.execute("echo pwned")
      ]]

      local success, result = Sandbox.execute(code, "escape-test")
      assert.is_false(success)
      -- os exists but execute is nil (only safe functions allowed)
      assert.matches("nil value", result)
    end)

    it("blocks io library access", function()
      local code = [[
        return io.open("/etc/passwd", "r")
      ]]

      local success, result = Sandbox.execute(code, "escape-test")
      assert.is_false(success)
      assert.matches("undefined global 'io'", result)
    end)

    it("blocks debug library access", function()
      local code = [[
        return debug.getinfo(1)
      ]]

      local success, result = Sandbox.execute(code, "escape-test")
      assert.is_false(success)
      assert.matches("undefined global 'debug'", result)
    end)

    it("blocks package library access", function()
      local code = [[
        return package.loadlib("libc.so", "system")
      ]]

      local success, result = Sandbox.execute(code, "escape-test")
      assert.is_false(success)
      assert.matches("undefined global 'package'", result)
    end)

    it("blocks loadfile", function()
      local code = [[
        return loadfile("/tmp/evil.lua")
      ]]

      local success, result = Sandbox.execute(code, "escape-test")
      assert.is_false(success)
      assert.matches("undefined global 'loadfile'", result)
    end)

    it("blocks dofile", function()
      local code = [[
        return dofile("/tmp/evil.lua")
      ]]

      local success, result = Sandbox.execute(code, "escape-test")
      assert.is_false(success)
      assert.matches("undefined global 'dofile'", result)
    end)

    it("blocks load without whitelisting", function()
      local code = [[
        return load("return os")
      ]]

      local success, result = Sandbox.execute(code, "escape-test")
      assert.is_false(success)
      assert.matches("undefined global 'load'", result)
    end)

    it("blocks coroutine library", function()
      local code = [[
        return coroutine.create(function() end)
      ]]

      local success, result = Sandbox.execute(code, "escape-test")
      assert.is_false(success)
      assert.matches("undefined global 'coroutine'", result)
    end)
  end)

  describe("Metatable Manipulation", function()
    it("blocks getmetatable on strings", function()
      -- Protected string metatable should return nil or "protected"
      local code = [[
        local mt = getmetatable("")
        if mt then
          -- Try to access internal functions
          return mt.__index
        end
        return nil
      ]]

      local success, result = Sandbox.execute(code, "escape-test")
      -- Should either fail or return nil (metatable protected)
      if success then
        assert.is_nil(result)
      end
    end)

    it("blocks setmetatable on protected objects", function()
      local code = [[
        local str = "test"
        -- Try to set custom metatable
        local success = pcall(setmetatable, str, {__index = {}})
        return success
      ]]

      local success, result = Sandbox.execute(code, "escape-test")
      -- String metatable modification should fail
      if success then
        assert.is_false(result)
      end
    end)
  end)

  describe("Require Restrictions", function()
    it("blocks require when not allowed", function()
      local code = [[
        return require("os")
      ]]

      local success, result = Sandbox.execute(code, "escape-test", {
        allowed_modules = {}
      })
      assert.is_false(success)
      assert.matches("undefined global 'require'", result)
    end)

    it("blocks require of non-whitelisted modules", function()
      local code = [[
        return require("os")
      ]]

      local success, result = Sandbox.execute(code, "escape-test", {
        allowed_modules = {"json"}
      })
      assert.is_false(success)
      assert.matches("not allowed", result)
    end)
  end)

  describe("Global Creation", function()
    it("blocks global variable creation", function()
      local code = [[
        evil_global = "pwned"
        return evil_global
      ]]

      local success, result = Sandbox.execute(code, "escape-test")
      assert.is_false(success)
      assert.matches("global", result:lower())
    end)

    it("allows local variable creation", function()
      local code = [[
        local x = "safe"
        return x
      ]]

      local success, result = Sandbox.execute(code, "escape-test")
      assert.is_true(success)
      assert.equals("safe", result)
    end)
  end)

  describe("Safe Operations", function()
    it("allows math operations", function()
      local code = [[
        return math.sqrt(16) + math.floor(3.7)
      ]]

      local success, result = Sandbox.execute(code, "escape-test")
      assert.is_true(success)
      assert.equals(7, result)
    end)

    it("allows string operations", function()
      local code = [[
        return string.upper("hello") .. string.rep("!", 3)
      ]]

      local success, result = Sandbox.execute(code, "escape-test")
      assert.is_true(success)
      assert.equals("HELLO!!!", result)
    end)

    it("allows table operations", function()
      local code = [[
        local t = {1, 2, 3}
        table.insert(t, 4)
        return table.concat(t, "-")
      ]]

      local success, result = Sandbox.execute(code, "escape-test")
      assert.is_true(success)
      assert.equals("1-2-3-4", result)
    end)

    it("allows safe os functions", function()
      local code = [[
        local t = os.time()
        local c = os.clock()
        return type(t), type(c)
      ]]

      local success, t_type, c_type = Sandbox.execute(code, "escape-test")
      assert.is_true(success)
      assert.equals("number", t_type)
    end)

    it("allows pcall for error handling", function()
      local code = [[
        local success, err = pcall(function()
          error("test")
        end)
        return success, type(err)
      ]]

      local success, result = Sandbox.execute(code, "escape-test")
      assert.is_true(success)
    end)
  end)

  describe("Timeout Protection", function()
    it("terminates infinite loops", function()
      local code = [[
        while true do end
      ]]

      local success, result = Sandbox.execute(code, "escape-test", {
        timeout_ms = 50
      })
      assert.is_false(success)
      assert.matches("timeout", result:lower())
    end)

    it("terminates long-running operations", function()
      local code = [[
        local x = 0
        for i = 1, 1000000000 do
          x = x + 1
        end
        return x
      ]]

      local success, result = Sandbox.execute(code, "escape-test", {
        timeout_ms = 50
      })
      assert.is_false(success)
      assert.matches("timeout", result:lower())
    end)
  end)
end)
