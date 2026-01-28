-- tests/core/test_truthiness.lua
-- WLS 1.0.0 GAP-003: Truthiness Rules Tests
-- Tests that 0 and "" are falsy, unlike Lua native behavior

local Utils = require("lib.whisker.core.utils")

describe("WLS Truthiness (GAP-003)", function()

  describe("is_truthy function", function()

    describe("falsy values", function()

      it("nil should be falsy", function()
        assert.is_false(Utils.is_truthy(nil))
      end)

      it("false should be falsy", function()
        assert.is_false(Utils.is_truthy(false))
      end)

      it("0 should be falsy (differs from Lua native)", function()
        assert.is_false(Utils.is_truthy(0))
      end)

      it("0.0 should be falsy", function()
        assert.is_false(Utils.is_truthy(0.0))
      end)

      it("-0 should be falsy", function()
        assert.is_false(Utils.is_truthy(-0))
      end)

      it("empty string should be falsy (differs from Lua native)", function()
        assert.is_false(Utils.is_truthy(""))
      end)

    end)

    describe("truthy values", function()

      it("true should be truthy", function()
        assert.is_true(Utils.is_truthy(true))
      end)

      it("1 should be truthy", function()
        assert.is_true(Utils.is_truthy(1))
      end)

      it("-1 should be truthy", function()
        assert.is_true(Utils.is_truthy(-1))
      end)

      it("0.1 should be truthy", function()
        assert.is_true(Utils.is_truthy(0.1))
      end)

      it("0.001 should be truthy", function()
        assert.is_true(Utils.is_truthy(0.001))
      end)

      it("non-empty string should be truthy", function()
        assert.is_true(Utils.is_truthy("hello"))
      end)

      it("string '0' should be truthy (non-empty string)", function()
        assert.is_true(Utils.is_truthy("0"))
      end)

      it("string 'false' should be truthy (non-empty string)", function()
        assert.is_true(Utils.is_truthy("false"))
      end)

      it("whitespace string should be truthy (non-empty)", function()
        assert.is_true(Utils.is_truthy(" "))
        assert.is_true(Utils.is_truthy("\t"))
        assert.is_true(Utils.is_truthy("\n"))
      end)

      it("empty table should be truthy", function()
        assert.is_true(Utils.is_truthy({}))
      end)

      it("non-empty table should be truthy", function()
        assert.is_true(Utils.is_truthy({1, 2, 3}))
        assert.is_true(Utils.is_truthy({key = "value"}))
      end)

      it("function should be truthy", function()
        assert.is_true(Utils.is_truthy(function() end))
      end)

    end)

  end)

  describe("is_falsy function", function()

    it("should be inverse of is_truthy", function()
      assert.is_true(Utils.is_falsy(nil))
      assert.is_true(Utils.is_falsy(false))
      assert.is_true(Utils.is_falsy(0))
      assert.is_true(Utils.is_falsy(""))
      assert.is_false(Utils.is_falsy(true))
      assert.is_false(Utils.is_falsy(1))
      assert.is_false(Utils.is_falsy("hello"))
    end)

  end)

  describe("to_boolean function", function()

    it("should convert values using WLS truthiness", function()
      assert.is_false(Utils.to_boolean(nil))
      assert.is_false(Utils.to_boolean(false))
      assert.is_false(Utils.to_boolean(0))
      assert.is_false(Utils.to_boolean(""))
      assert.is_true(Utils.to_boolean(true))
      assert.is_true(Utils.to_boolean(1))
      assert.is_true(Utils.to_boolean("text"))
    end)

  end)

end)

describe("LuaInterpreter evaluate_condition (GAP-003)", function()
  local LuaInterpreter = require("lib.whisker.core.lua_interpreter")

  -- Create a minimal mock engine for testing
  local function create_mock_engine()
    return {
      current_passage = { id = "test" },
      hook_manager = {
        get_hook = function() return nil end
      }
    }
  end

  -- Create a minimal mock game_state for testing
  local function create_mock_game_state(vars)
    return {
      variables = vars or {},
      temp_variables = {},
      get_all_variables = function(self) return self.variables end,
      get_all_temp_variables = function(self) return self.temp_variables end,
    }
  end

  describe("condition evaluation with WLS truthiness", function()
    local interpreter

    before_each(function()
      interpreter = LuaInterpreter.new(create_mock_engine())
    end)

    it("should return true for empty/nil condition", function()
      local success, result = interpreter:evaluate_condition(nil)
      assert.is_true(success)
      assert.is_true(result)

      success, result = interpreter:evaluate_condition("")
      assert.is_true(success)
      assert.is_true(result)
    end)

    it("should treat 0 as falsy", function()
      local game_state = create_mock_game_state({count = 0})
      local success, result = interpreter:evaluate_condition("count", game_state)
      assert.is_true(success)
      assert.is_false(result)
    end)

    it("should treat empty string as falsy", function()
      local game_state = create_mock_game_state({name = ""})
      local success, result = interpreter:evaluate_condition("name", game_state)
      assert.is_true(success)
      assert.is_false(result)
    end)

    it("should treat non-zero numbers as truthy", function()
      local game_state = create_mock_game_state({count = 1})
      local success, result = interpreter:evaluate_condition("count", game_state)
      assert.is_true(success)
      assert.is_true(result)

      game_state = create_mock_game_state({count = -1})
      success, result = interpreter:evaluate_condition("count", game_state)
      assert.is_true(success)
      assert.is_true(result)
    end)

    it("should treat non-empty strings as truthy", function()
      local game_state = create_mock_game_state({name = "Alice"})
      local success, result = interpreter:evaluate_condition("name", game_state)
      assert.is_true(success)
      assert.is_true(result)
    end)

    it("should treat nil as falsy", function()
      local game_state = create_mock_game_state({})
      local success, result = interpreter:evaluate_condition("undefined_var", game_state)
      assert.is_true(success)
      assert.is_false(result)
    end)

    it("should handle comparison expressions", function()
      local game_state = create_mock_game_state({x = 5})
      local success, result = interpreter:evaluate_condition("x > 3", game_state)
      assert.is_true(success)
      assert.is_true(result)

      success, result = interpreter:evaluate_condition("x > 10", game_state)
      assert.is_true(success)
      assert.is_false(result)
    end)

    it("should handle equality with 0", function()
      local game_state = create_mock_game_state({count = 0})
      local success, result = interpreter:evaluate_condition("count == 0", game_state)
      assert.is_true(success)
      assert.is_true(result)  -- The comparison result is boolean true
    end)

  end)

end)
