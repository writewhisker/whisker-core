--- LuaInterpreter Unit Tests
-- Comprehensive unit tests for the LuaInterpreter module
-- Tests for WLS 1.0.0 compliance including:
--   GAP-007: visited() global function
--   GAP-008: Comprehensive Lua sandboxing
-- @module tests.unit.core.test_lua_interpreter_spec
-- @author Whisker Core Team

describe("LuaInterpreter", function()
  local LuaInterpreter
  local mock_engine
  local mock_game_state

  before_each(function()
    -- Clear cached module to ensure fresh state
    package.loaded["whisker.core.lua_interpreter"] = nil
    LuaInterpreter = require("whisker.core.lua_interpreter")

    -- Create mock engine with minimal hook_manager
    mock_engine = {
      current_passage = { id = "test_passage" },
      hook_manager = {
        get_hook = function() return nil end,
        replace_hook = function() return true end,
        append_hook = function() return true end,
        prepend_hook = function() return true end,
        show_hook = function() return true end,
        hide_hook = function() return true end,
        clear_hook = function() return true end,
        is_cleared = function() return false end,
      }
    }

    -- Create mock game state for visited() testing
    mock_game_state = {
      visited_passages = {},
      get_visit_count = function(self, passage_name)
        return self.visited_passages[passage_name] or 0
      end,
      get_current_passage = function(self)
        return "current_test"
      end,
    }
  end)

  describe("initialization", function()
    it("creates interpreter with engine", function()
      local interp = LuaInterpreter.new(mock_engine)
      assert.is_not_nil(interp)
      assert.equals(mock_engine, interp.engine)
    end)

    it("creates interpreter with config", function()
      local config = { deprecation_warnings = false }
      local interp = LuaInterpreter.new(mock_engine, config)
      assert.equals(false, interp.config.deprecation_warnings)
    end)

    it("initializes empty environment", function()
      local interp = LuaInterpreter.new(mock_engine)
      assert.is_table(interp.env)
    end)

    it("initializes output buffer", function()
      local interp = LuaInterpreter.new(mock_engine)
      assert.is_table(interp.output_buffer)
      assert.equals(0, #interp.output_buffer)
    end)
  end)

  -- GAP-007: visited() function tests
  describe("GAP-007: visited() function", function()
    local interp

    before_each(function()
      interp = LuaInterpreter.new(mock_engine, { game_state = mock_game_state })
    end)

    it("should be available as global function", function()
      local result = interp:eval("return type(visited)")
      assert.equals("function", result)
    end)

    it("should return 0 for unvisited passages", function()
      local result = interp:eval("return visited('NeverVisited')")
      assert.equals(0, result)
    end)

    it("should return visit count for visited passages", function()
      mock_game_state.visited_passages["Start"] = 3
      local result = interp:eval("return visited('Start')")
      assert.equals(3, result)
    end)

    it("should error on non-string argument", function()
      local result, err = interp:eval("return visited(123)")
      assert.is_nil(result)
      assert.matches("requires a string passage name", err)
    end)

    it("should work in conditionals", function()
      mock_game_state.visited_passages["Intro"] = 2
      local result = interp:eval([[
        if visited("Intro") > 0 then
          return "been here"
        else
          return "first time"
        end
      ]])
      assert.equals("been here", result)
    end)

    it("should have visits() as alias", function()
      local result = interp:eval("return type(visits)")
      assert.equals("function", result)

      mock_game_state.visited_passages["Test"] = 5
      local result2 = interp:eval("return visits('Test')")
      assert.equals(5, result2)
    end)

    it("should work without game_state (returns 0)", function()
      local interp_no_state = LuaInterpreter.new(mock_engine, {})
      local result = interp_no_state:eval("return visited('SomePassage')")
      assert.equals(0, result)
    end)

    it("supports set_game_state for deferred initialization", function()
      local interp_deferred = LuaInterpreter.new(mock_engine, {})
      -- Initially no game_state
      local result1 = interp_deferred:eval("return visited('Test')")
      assert.equals(0, result1)

      -- Set game_state later
      mock_game_state.visited_passages["Test"] = 7
      interp_deferred:set_game_state(mock_game_state)

      local result2 = interp_deferred:eval("return visited('Test')")
      assert.equals(7, result2)
    end)
  end)

  -- GAP-008: Sandbox Security Tests
  describe("GAP-008: Sandbox Security", function()
    local interp

    before_each(function()
      interp = LuaInterpreter.new(mock_engine)
    end)

    describe("blocked functions", function()
      it("should block io module access", function()
        local result, err = interp:eval("return io.open('/etc/passwd', 'r')")
        assert.is_nil(result)
        assert.matches("not available", err)
      end)

      it("should block os.execute", function()
        local result, err = interp:eval("return os.execute('ls')")
        assert.is_nil(result)
        assert.matches("not available", err)
      end)

      it("should block os.exit", function()
        local result, err = interp:eval("return os.exit(1)")
        assert.is_nil(result)
        assert.matches("not available", err)
      end)

      it("should block os.remove", function()
        local result, err = interp:eval("return os.remove('/tmp/test')")
        assert.is_nil(result)
        assert.matches("not available", err)
      end)

      it("should block os.rename", function()
        local result, err = interp:eval("return os.rename('/tmp/a', '/tmp/b')")
        assert.is_nil(result)
        assert.matches("not available", err)
      end)

      it("should block os.getenv", function()
        local result, err = interp:eval("return os.getenv('PATH')")
        assert.is_nil(result)
        assert.matches("not available", err)
      end)

      it("should block os.tmpname", function()
        local result, err = interp:eval("return os.tmpname()")
        assert.is_nil(result)
        assert.matches("not available", err)
      end)

      it("should block require", function()
        local result, err = interp:eval("return require('os')")
        assert.is_nil(result)
        assert.matches("not available", err)
      end)

      it("should block loadfile", function()
        local result, err = interp:eval("return loadfile('evil.lua')")
        assert.is_nil(result)
        assert.matches("not available", err)
      end)

      it("should block dofile", function()
        local result, err = interp:eval("return dofile('evil.lua')")
        assert.is_nil(result)
        assert.matches("not available", err)
      end)

      it("should block load", function()
        local result, err = interp:eval("return load('return io')")
        assert.is_nil(result)
        assert.matches("not available", err)
      end)

      it("should block debug module", function()
        local result, err = interp:eval("return debug.getinfo(1)")
        assert.is_nil(result)
        assert.matches("not available", err)
      end)

      it("should block package module", function()
        local result, err = interp:eval("return package.loaded")
        assert.is_nil(result)
        assert.matches("not available", err)
      end)

      it("should block coroutine module", function()
        local result, err = interp:eval("return coroutine.create(function() end)")
        assert.is_nil(result)
        assert.matches("not available", err)
      end)

      it("should block collectgarbage", function()
        local result, err = interp:eval("return collectgarbage('count')")
        assert.is_nil(result)
        assert.matches("not available", err)
      end)
    end)

    describe("allowed functions", function()
      it("should allow math functions", function()
        local result = interp:eval("return math.abs(-5)")
        assert.equals(5, result)
      end)

      it("should allow math.floor", function()
        local result = interp:eval("return math.floor(3.7)")
        assert.equals(3, result)
      end)

      it("should allow math.ceil", function()
        local result = interp:eval("return math.ceil(3.2)")
        assert.equals(4, result)
      end)

      it("should allow math.random", function()
        local result = interp:eval("return type(math.random())")
        assert.equals("number", result)
      end)

      it("should allow math.min and math.max", function()
        local result = interp:eval("return math.max(1, 2, 3)")
        assert.equals(3, result)
      end)

      it("should allow string functions", function()
        local result = interp:eval("return string.upper('hello')")
        assert.equals("HELLO", result)
      end)

      it("should allow string.find", function()
        local result = interp:eval("return string.find('hello world', 'world')")
        assert.equals(7, result)
      end)

      it("should allow string.sub", function()
        local result = interp:eval("return string.sub('hello', 1, 3)")
        assert.equals("hel", result)
      end)

      it("should allow string.format", function()
        local result = interp:eval("return string.format('%d + %d = %d', 1, 2, 3)")
        assert.equals("1 + 2 = 3", result)
      end)

      it("should allow table functions", function()
        local result = interp:eval([[
          local t = {3, 1, 2}
          table.sort(t)
          return t[1]
        ]])
        assert.equals(1, result)
      end)

      it("should allow table.concat", function()
        local result = interp:eval([[
          local t = {"a", "b", "c"}
          return table.concat(t, "-")
        ]])
        assert.equals("a-b-c", result)
      end)

      it("should allow table.insert", function()
        local result = interp:eval([[
          local t = {1, 2}
          table.insert(t, 3)
          return #t
        ]])
        assert.equals(3, result)
      end)

      it("should allow safe os functions", function()
        local result = interp:eval("return type(os.time())")
        assert.equals("number", result)
      end)

      it("should allow os.date", function()
        local result = interp:eval("return type(os.date())")
        assert.equals("string", result)
      end)

      it("should allow os.clock", function()
        local result = interp:eval("return type(os.clock())")
        assert.equals("number", result)
      end)

      it("should allow os.difftime", function()
        local result = interp:eval("return os.difftime(100, 50)")
        assert.equals(50, result)
      end)

      it("should allow pairs and ipairs", function()
        local result = interp:eval([[
          local sum = 0
          for _, v in ipairs({1, 2, 3}) do sum = sum + v end
          return sum
        ]])
        assert.equals(6, result)
      end)

      it("should allow pcall for error handling", function()
        local result = interp:eval([[
          local success, err = pcall(function()
            error("test error")
          end)
          return success
        ]])
        assert.is_false(result)
      end)

      it("should allow xpcall", function()
        local result = interp:eval([[
          local handled = false
          local success = xpcall(function()
            error("test")
          end, function(err)
            handled = true
          end)
          return handled
        ]])
        assert.is_true(result)
      end)

      it("should allow tonumber and tostring", function()
        local result = interp:eval("return tonumber('42')")
        assert.equals(42, result)
      end)

      it("should allow type checking", function()
        local result = interp:eval("return type({})")
        assert.equals("table", result)
      end)

      it("should allow assert", function()
        local result = interp:eval("return assert(true)")
        assert.is_true(result)
      end)

      it("should allow select", function()
        local result = interp:eval([[
          local function test(...)
            return select("#", ...)
          end
          return test(1, 2, 3)
        ]])
        assert.equals(3, result)
      end)
    end)

    describe("metatable protection", function()
      it("should allow setmetatable on user tables", function()
        local result = interp:eval([[
          local t = {}
          setmetatable(t, { __index = function() return 42 end })
          return t.anything
        ]])
        assert.equals(42, result)
      end)

      it("should block setmetatable on non-tables", function()
        local result, err = interp:eval("setmetatable('string', {})")
        assert.is_nil(result)
        assert.matches("tables", err)
      end)

      it("should return nil for protected metatable", function()
        local result = interp:eval([[
          local mt = getmetatable("")
          return mt
        ]])
        -- String metatable should be protected or nil
        assert.is_true(result == nil or type(result) == "string")
      end)
    end)

    describe("print redirection", function()
      it("should redirect print to buffer", function()
        interp:eval("print('hello', 'world')")
        local output = interp:flush_output()
        assert.equals("hello\tworld", output)
      end)

      it("should accumulate multiple prints", function()
        interp:eval("print('line1')")
        interp:eval("print('line2')")
        local output = interp:flush_output()
        assert.equals("line1\nline2", output)
      end)

      it("should clear buffer after flush", function()
        interp:eval("print('test')")
        interp:flush_output()
        local output = interp:flush_output()
        assert.equals("", output)
      end)
    end)

    describe("sandbox configuration", function()
      it("should expose sandbox config for inspection", function()
        local config = interp:get_sandbox_config()
        assert.is_table(config.safe_globals)
        assert.is_table(config.safe_modules)
        assert.is_table(config.blocked_functions)
        assert.is_table(config.blocked_modules)
      end)

      it("should report blocked functions correctly", function()
        assert.is_true(interp:is_blocked("require"))
        assert.is_true(interp:is_blocked("loadfile"))
        assert.is_true(interp:is_blocked("io"))
        assert.is_true(interp:is_blocked("debug"))
        assert.is_false(interp:is_blocked("math"))
        assert.is_false(interp:is_blocked("string"))
      end)
    end)
  end)

  describe("evaluation", function()
    local interp

    before_each(function()
      interp = LuaInterpreter.new(mock_engine)
    end)

    it("evaluates simple expressions", function()
      local result = interp:eval("return 1 + 2")
      assert.equals(3, result)
    end)

    it("evaluates string expressions", function()
      local result = interp:eval("return 'hello' .. ' ' .. 'world'")
      assert.equals("hello world", result)
    end)

    it("returns nil for syntax errors", function()
      local result, err = interp:eval("return 1 +")
      assert.is_nil(result)
      assert.matches("syntax error", err)
    end)

    it("returns nil for runtime errors", function()
      local result, err = interp:eval("return nil + 1")
      assert.is_nil(result)
      assert.matches("runtime error", err)
    end)

    it("execute is alias for eval", function()
      local result = interp:execute("return 42")
      assert.equals(42, result)
    end)
  end)

  describe("variable management", function()
    local interp

    before_each(function()
      interp = LuaInterpreter.new(mock_engine)
    end)

    it("sets and gets variables", function()
      interp:set_variable("x", 42)
      assert.equals(42, interp:get_variable("x"))
    end)

    it("variables are accessible in eval", function()
      interp:set_variable("myVar", 100)
      local result = interp:eval("return myVar")
      assert.equals(100, result)
    end)

    it("returns nil for undefined variables", function()
      assert.is_nil(interp:get_variable("undefined"))
    end)
  end)

  describe("whisker namespace", function()
    local interp

    before_each(function()
      interp = LuaInterpreter.new(mock_engine)
    end)

    it("whisker namespace exists", function()
      local result = interp:eval("return type(whisker)")
      assert.equals("table", result)
    end)

    it("whisker.hook namespace exists", function()
      local result = interp:eval("return type(whisker.hook)")
      assert.equals("table", result)
    end)

    it("whisker.hook.isVisible exists", function()
      local result = interp:eval("return type(whisker.hook.isVisible)")
      assert.equals("function", result)
    end)

    it("whisker.hook.get exists", function()
      local result = interp:eval("return type(whisker.hook.get)")
      assert.equals("function", result)
    end)

    it("whisker.hook.replace exists", function()
      local result = interp:eval("return type(whisker.hook.replace)")
      assert.equals("function", result)
    end)
  end)

  describe("pick() function", function()
    local interp

    before_each(function()
      interp = LuaInterpreter.new(mock_engine)
      interp:set_random_seed(12345)  -- For reproducibility
    end)

    it("picks from list", function()
      local result = interp:eval("return pick({1, 2, 3})")
      assert.is_number(result)
      assert.is_true(result >= 1 and result <= 3)
    end)

    it("returns nil for empty list", function()
      local result = interp:eval("return pick({})")
      assert.is_nil(result)
    end)

    it("errors on nil argument", function()
      local result, err = interp:eval("return pick(nil)")
      assert.is_nil(result)
      assert.matches("requires a list", err)
    end)

    it("errors on non-table argument", function()
      local result, err = interp:eval("return pick('string')")
      assert.is_nil(result)
      assert.matches("table/list", err)
    end)

    it("whisker.pick is alias", function()
      local result = interp:eval("return type(whisker.pick)")
      assert.equals("function", result)
    end)
  end)

  describe("utility functions", function()
    local interp

    before_each(function()
      interp = LuaInterpreter.new(mock_engine, { game_state = mock_game_state })
    end)

    it("random() with no args returns 0-1", function()
      local result = interp:eval("return type(random())")
      assert.equals("number", result)
    end)

    it("random(n) returns 1 to n", function()
      local result = interp:eval("return random(1)")
      assert.equals(1, result)
    end)

    it("random(min, max) returns min to max", function()
      local result = interp:eval([[
        local r = random(5, 5)
        return r
      ]])
      assert.equals(5, result)
    end)

    it("current() returns current passage", function()
      local result = interp:eval("return current()")
      assert.equals("current_test", result)
    end)
  end)
end)
