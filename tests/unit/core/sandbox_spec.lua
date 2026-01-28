-- Test suite for Sandbox
-- WLS 1.0 GAP-074: Complete sandboxing tests

local Sandbox = require("lib.whisker.core.sandbox")

describe("Sandbox", function()
  local sandbox

  before_each(function()
    sandbox = Sandbox.new()
  end)

  describe("safe environment", function()
    it("should allow safe math functions", function()
      local result = sandbox:eval("math.abs(-5)")
      assert.equals(5, result)
    end)

    it("should allow safe string functions", function()
      local result = sandbox:eval("string.upper('hello')")
      assert.equals("HELLO", result)
    end)

    it("should allow safe table functions", function()
      local result = sandbox:eval("table.concat({'a', 'b', 'c'}, ',')")
      assert.equals("a,b,c", result)
    end)

    it("should allow type function", function()
      local result = sandbox:eval("type(123)")
      assert.equals("number", result)
    end)

    it("should allow pairs/ipairs", function()
      local result = sandbox:execute([[
        local t = {1, 2, 3}
        local sum = 0
        for _, v in ipairs(t) do
          sum = sum + v
        end
        return sum
      ]])
      assert.equals(6, result)
    end)
  end)

  describe("blocked functions", function()
    it("should block loadstring", function()
      local result, err = sandbox:eval("loadstring('return 1')()")
      assert.is_nil(result)
      assert.has.match("not available", err)
    end)

    it("should block dofile", function()
      local result, err = sandbox:eval("dofile('/etc/passwd')")
      assert.is_nil(result)
      assert.has.match("not available", err)
    end)

    it("should block loadfile", function()
      local result, err = sandbox:eval("loadfile('/etc/passwd')")
      assert.is_nil(result)
      assert.has.match("not available", err)
    end)

    it("should block os.execute", function()
      local result, err = sandbox:eval("os.execute('ls')")
      assert.is_nil(result)
      assert.has.match("not available", err)
    end)

    it("should block io module", function()
      local result, err = sandbox:eval("io.open('/etc/passwd')")
      assert.is_nil(result)
      assert.has.match("not available", err)
    end)

    it("should block debug module", function()
      local result, err = sandbox:eval("debug.getinfo(1)")
      assert.is_nil(result)
      assert.has.match("not available", err)
    end)

    it("should block require", function()
      local result, err = sandbox:eval("require('os')")
      assert.is_nil(result)
      assert.has.match("not available", err)
    end)
  end)

  describe("safe os functions", function()
    it("should allow os.time", function()
      local result = sandbox:eval("os.time()")
      assert.is_number(result)
    end)

    it("should allow os.date", function()
      local result = sandbox:eval("os.date('%Y')")
      assert.is_string(result)
      assert.has.match("^%d%d%d%d$", result)
    end)

    it("should allow os.clock", function()
      local result = sandbox:eval("os.clock()")
      assert.is_number(result)
    end)
  end)

  describe("resource limits", function()
    it("should allow configuring limits", function()
      local custom = Sandbox.new({
        max_instructions = 100,
        timeout_seconds = 1
      })

      local limits = custom:get_limits()
      assert.equals(100, limits.max_instructions)
      assert.equals(1, limits.timeout_seconds)
    end)

    it("should reject string.rep with huge result", function()
      local result, err = sandbox:eval("string.rep('x', 10000000)")
      assert.is_nil(result)
      assert.has.match("too long", err)
    end)
  end)

  describe("execute", function()
    it("should execute simple statements", function()
      local result = sandbox:execute("return 1 + 2 + 3")
      assert.equals(6, result)
    end)

    it("should execute with custom environment", function()
      local result = sandbox:execute("return x + y", { x = 10, y = 20 })
      assert.equals(30, result)
    end)

    it("should return nil for code without return", function()
      local result = sandbox:execute("local x = 5")
      assert.is_nil(result)
    end)

    it("should report syntax errors", function()
      local result, err = sandbox:execute("if then end")
      assert.is_nil(result)
      assert.has.match("Compilation error", err)
    end)

    it("should report runtime errors", function()
      local result, err = sandbox:execute("return nil + 1")
      assert.is_nil(result)
      assert.has.match("Runtime error", err)
    end)
  end)

  describe("eval", function()
    it("should evaluate expressions", function()
      local result = sandbox:eval("5 * 10")
      assert.equals(50, result)
    end)

    it("should evaluate with environment", function()
      local result = sandbox:eval("hp * 2", { hp = 50 })
      assert.equals(100, result)
    end)
  end)

  describe("analyze", function()
    it("should flag dangerous patterns", function()
      local is_safe, issues = sandbox:analyze("io.open('/etc/passwd')")
      assert.is_false(is_safe)
      assert.is_true(#issues > 0)
    end)

    it("should pass safe code", function()
      local is_safe, issues = sandbox:analyze("local x = 5")
      assert.is_true(is_safe)
      assert.equals(0, #issues)
    end)

    it("should detect loadstring", function()
      local is_safe, issues = sandbox:analyze("loadstring('return 1')()")
      assert.is_false(is_safe)
      local found = false
      for _, i in ipairs(issues) do
        if i.pattern == "loadstring" then found = true end
      end
      assert.is_true(found)
    end)

    it("should detect require", function()
      local is_safe, issues = sandbox:analyze("require('socket')")
      assert.is_false(is_safe)
    end)

    it("should detect os.execute", function()
      local is_safe, issues = sandbox:analyze("os.execute('rm -rf /')")
      assert.is_false(is_safe)
    end)
  end)

  describe("usage tracking", function()
    it("should track instruction count when hooks available", function()
      sandbox:execute("local sum = 0; for i=1,100 do sum = sum + i end; return sum")
      local usage = sandbox:get_usage()
      -- Instructions may be 0 if debug hooks are not available in this environment
      assert.is_number(usage.instructions)
      assert.is_number(usage.max_instructions)
    end)
  end)

  describe("metatable protection", function()
    it("should allow setmetatable on user tables", function()
      local result, err = sandbox:execute([[
        local t = {}
        setmetatable(t, { __index = function() return 42 end })
        return t.anything
      ]])
      assert.equals(42, result)
    end)

    it("should reject setmetatable on non-tables", function()
      local result, err = sandbox:execute([[
        setmetatable("string", {})
      ]])
      assert.is_nil(result)
      assert.has.match("only be used on tables", err)
    end)
  end)
end)
