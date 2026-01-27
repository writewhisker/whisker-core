-- Test suite for Extended Lua Interpreter Features
-- WLS 1.0 GAP-066: isVisible naming
-- WLS 1.0 GAP-070: Global visited() exposure
-- WLS 1.0 GAP-071: Global pick() exposure

describe("LuaInterpreter Extended Features", function()
  local LuaInterpreter = require("lib.whisker.core.lua_interpreter")
  local HookManager = require("lib.whisker.wls2.hook_manager")

  -- Mock engine and game state for testing
  local function create_mock_engine()
    local hook_manager = HookManager.new()
    local engine = {
      hook_manager = hook_manager,
      current_passage = { id = "test_passage" }
    }
    return engine, hook_manager
  end

  local function create_mock_game_state()
    local state = {
      _visits = { Start = 3, Combat = 1 },
      _turn = 5
    }

    function state:get_visit_count(passage_name)
      return self._visits[passage_name] or 0
    end

    function state:get_turn_count()
      return self._turn
    end

    function state:get_current_passage()
      return "Combat"
    end

    function state:get_previous_passage()
      return "Start"
    end

    return state
  end

  describe("GAP-070: visited() and hasVisited()", function()
    local interpreter
    local game_state

    before_each(function()
      local engine = create_mock_engine()
      game_state = create_mock_game_state()
      interpreter = LuaInterpreter.new(engine, { game_state = game_state })
    end)

    it("should return visit count for visited passage", function()
      local result = interpreter:eval("return visited('Start')")
      assert.equals(3, result)
    end)

    it("should return 0 for unvisited passage", function()
      local result = interpreter:eval("return visited('Unknown')")
      assert.equals(0, result)
    end)

    it("should provide visits as alias", function()
      local result = interpreter:eval("return visits('Start')")
      assert.equals(3, result)
    end)

    it("should provide hasVisited convenience function", function()
      local result1 = interpreter:eval("return hasVisited('Start')")
      local result2 = interpreter:eval("return hasVisited('Unknown')")

      assert.is_true(result1)
      assert.is_false(result2)
    end)

    it("should error on non-string argument", function()
      local result, err = interpreter:eval("visited(123)")
      assert.is_nil(result)
      assert.has.match("string passage name", err)
    end)
  end)

  describe("GAP-071: pick() and variants", function()
    local interpreter

    before_each(function()
      local engine = create_mock_engine()
      interpreter = LuaInterpreter.new(engine)
      -- Set deterministic seed for testing
      interpreter:set_random_seed(12345)
    end)

    it("should pick single element from list", function()
      local result = interpreter:eval("return pick({1, 2, 3, 4, 5})")
      assert.is_number(result)
      assert.is_true(result >= 1 and result <= 5)
    end)

    it("should return nil for empty list", function()
      local result = interpreter:eval("return pick({})")
      assert.is_nil(result)
    end)

    it("should pick multiple elements without repetition", function()
      local result = interpreter:eval("return pick({1, 2, 3, 4, 5}, 3)")
      assert.is_table(result)
      assert.equals(3, #result)

      -- Check no duplicates
      local seen = {}
      for _, v in ipairs(result) do
        assert.is_nil(seen[v], "Duplicate found: " .. tostring(v))
        seen[v] = true
      end
    end)

    it("should pick with repetition when allowed", function()
      interpreter:set_random_seed(12345)
      -- Pick more than list size with repetition
      local result = interpreter:eval("return pick({1, 2, 3}, 5, true)")
      assert.is_table(result)
      assert.equals(5, #result)
    end)

    it("should error on nil argument", function()
      local result, err = interpreter:eval("pick(nil)")
      assert.is_nil(result)
      assert.has.match("requires a list", err)
    end)

    it("should error on non-table argument", function()
      local result, err = interpreter:eval("pick('string')")
      assert.is_nil(result)
      assert.has.match("must be a table", err)
    end)
  end)

  describe("GAP-071: pickWeighted()", function()
    local interpreter

    before_each(function()
      local engine = create_mock_engine()
      interpreter = LuaInterpreter.new(engine)
    end)

    it("should exist in environment", function()
      local result = interpreter:eval("return type(pickWeighted)")
      assert.equals("function", result)
    end)

    it("should return element from list", function()
      local result = interpreter:eval("return pickWeighted({'a', 'b', 'c'}, {1, 1, 1})")
      assert.is_true(result == "a" or result == "b" or result == "c")
    end)

    it("should return nil for empty list", function()
      local result = interpreter:eval("return pickWeighted({}, {})")
      assert.is_nil(result)
    end)

    it("should work without weights (equal)", function()
      local result = interpreter:eval("return pickWeighted({'x', 'y', 'z'})")
      assert.is_true(result == "x" or result == "y" or result == "z")
    end)
  end)

  describe("GAP-071: shuffle()", function()
    local interpreter

    before_each(function()
      local engine = create_mock_engine()
      interpreter = LuaInterpreter.new(engine)
    end)

    it("should exist in environment", function()
      local result = interpreter:eval("return type(shuffle)")
      assert.equals("function", result)
    end)

    it("should return same elements in different order", function()
      interpreter:set_random_seed(99999)
      local result = interpreter:eval("return shuffle({1, 2, 3, 4, 5})")

      assert.is_table(result)
      assert.equals(5, #result)

      -- Check all elements present
      local sum = 0
      for _, v in ipairs(result) do
        sum = sum + v
      end
      assert.equals(15, sum)
    end)

    it("should not modify original array", function()
      local result = interpreter:execute([[
        local original = {1, 2, 3}
        local shuffled = shuffle(original)
        return original[1] == 1 and original[2] == 2 and original[3] == 3
      ]])
      assert.is_true(result)
    end)

    it("should error on non-table argument", function()
      local result, err = interpreter:eval("shuffle('not a table')")
      assert.is_nil(result)
      assert.has.match("requires a table", err)
    end)
  end)

  describe("GAP-066: isVisible naming", function()
    local interpreter
    local hook_manager

    before_each(function()
      local engine
      engine, hook_manager = create_mock_engine()
      interpreter = LuaInterpreter.new(engine, { deprecation_warnings = false })

      -- Register a test hook
      hook_manager:register_hook("test_passage", "banner", "Welcome!")
    end)

    it("should expose isVisible function", function()
      local result = interpreter:eval("return type(whisker.hook.isVisible)")
      assert.equals("function", result)
    end)

    it("should check hook visibility correctly", function()
      local result = interpreter:eval("return whisker.hook.isVisible('banner')")
      assert.is_true(result)
    end)

    it("should return false for hidden hook", function()
      hook_manager:hide_hook("test_passage_banner")
      local result = interpreter:eval("return whisker.hook.isVisible('banner')")
      assert.is_false(result)
    end)

    it("should return false for non-existent hook", function()
      local result = interpreter:eval("return whisker.hook.isVisible('nonexistent')")
      assert.is_false(result)
    end)

    it("should still support deprecated visible() alias", function()
      local result = interpreter:eval("return whisker.hook.visible('banner')")
      assert.is_true(result)
    end)

    it("should error in strict mode for deprecated visible()", function()
      local engine = create_mock_engine()
      local strict_interpreter = LuaInterpreter.new(engine, { strict_api = true })
      hook_manager:register_hook("test_passage", "test", "content")

      local result, err = strict_interpreter:eval("return whisker.hook.visible('test')")
      assert.is_nil(result)
      assert.has.match("deprecated", err)
    end)
  end)

  describe("whisker.hook.all namespace", function()
    local interpreter
    local hook_manager

    before_each(function()
      local engine
      engine, hook_manager = create_mock_engine()
      interpreter = LuaInterpreter.new(engine)

      -- Register test hooks
      hook_manager:register_hook("test_passage", "h1", "content1")
      hook_manager:register_hook("test_passage", "h2", "content2")
      hook_manager:register_hook("test_passage", "h3", "content3")
    end)

    it("should expose hook.all.hide", function()
      local result = interpreter:eval("return type(whisker.hook.all.hide)")
      assert.equals("function", result)
    end)

    it("should expose hook.all.show", function()
      local result = interpreter:eval("return type(whisker.hook.all.show)")
      assert.equals("function", result)
    end)

    it("should expose hook.all.clear", function()
      local result = interpreter:eval("return type(whisker.hook.all.clear)")
      assert.equals("function", result)
    end)

    it("should expose hook.all.reset", function()
      local result = interpreter:eval("return type(whisker.hook.all.reset)")
      assert.equals("function", result)
    end)

    it("should expose hook.all.each", function()
      local result = interpreter:eval("return type(whisker.hook.all.each)")
      assert.equals("function", result)
    end)

    it("should expose hook.all.find", function()
      local result = interpreter:eval("return type(whisker.hook.all.find)")
      assert.equals("function", result)
    end)

    it("should hide all via script", function()
      local count = interpreter:eval("return whisker.hook.all.hide()")
      assert.equals(3, count)
    end)

    it("should find hooks via script", function()
      local result = interpreter:eval("return whisker.hook.all.find({})")
      assert.is_table(result)
      assert.equals(3, #result)
    end)
  end)

  describe("whisker.hook.reset()", function()
    local interpreter
    local hook_manager

    before_each(function()
      local engine
      engine, hook_manager = create_mock_engine()
      interpreter = LuaInterpreter.new(engine)
      hook_manager:register_hook("test_passage", "counter", "0")
    end)

    it("should reset hook to original content", function()
      -- Modify the hook
      interpreter:eval("whisker.hook.replace('counter', '100')")
      local modified = hook_manager:get_hook("test_passage_counter")
      assert.equals("100", modified.current_content)

      -- Reset it
      local success = interpreter:eval("return whisker.hook.reset('counter')")
      assert.is_true(success)

      local reset = hook_manager:get_hook("test_passage_counter")
      assert.equals("0", reset.current_content)
    end)
  end)
end)

