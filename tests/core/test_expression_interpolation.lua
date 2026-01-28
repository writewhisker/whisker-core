-- tests/core/test_expression_interpolation.lua
-- WLS 1.0.0 GAP-002: Expression Interpolation Tests
-- Tests ${expression} syntax support

describe("Expression Interpolation (GAP-002)", function()
  local Renderer = require("lib.whisker.core.renderer")
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
      get = function(self, key) return self.variables[key] end,
    }
  end

  describe("LuaInterpreter.evaluate_expression", function()
    local interpreter

    before_each(function()
      interpreter = LuaInterpreter.new(create_mock_engine())
    end)

    describe("simple expressions", function()

      it("should evaluate arithmetic", function()
        local game_state = create_mock_game_state({})
        local success, result = interpreter:evaluate_expression("1 + 2", game_state)
        assert.is_true(success)
        assert.equals(3, result)
      end)

      it("should evaluate variable + literal", function()
        local game_state = create_mock_game_state({count = 5})
        local success, result = interpreter:evaluate_expression("count + 10", game_state)
        assert.is_true(success)
        assert.equals(15, result)
      end)

      it("should evaluate multiplication", function()
        local game_state = create_mock_game_state({x = 7})
        local success, result = interpreter:evaluate_expression("x * 2", game_state)
        assert.is_true(success)
        assert.equals(14, result)
      end)

      it("should evaluate division", function()
        local game_state = create_mock_game_state({total = 100, parts = 4})
        local success, result = interpreter:evaluate_expression("total / parts", game_state)
        assert.is_true(success)
        assert.equals(25, result)
      end)

      it("should evaluate modulo", function()
        local game_state = create_mock_game_state({x = 17})
        local success, result = interpreter:evaluate_expression("x % 5", game_state)
        assert.is_true(success)
        assert.equals(2, result)
      end)

    end)

    describe("property access", function()

      it("should access nested properties", function()
        local game_state = create_mock_game_state({
          player = { name = "Alice" }
        })
        local success, result = interpreter:evaluate_expression("player.name", game_state)
        assert.is_true(success)
        assert.equals("Alice", result)
      end)

      it("should access deeply nested properties", function()
        local game_state = create_mock_game_state({
          player = { inventory = { gold = 100 } }
        })
        local success, result = interpreter:evaluate_expression("player.inventory.gold", game_state)
        assert.is_true(success)
        assert.equals(100, result)
      end)

    end)

    describe("function calls", function()

      it("should evaluate math functions", function()
        local game_state = create_mock_game_state({a = -5})
        local success, result = interpreter:evaluate_expression("math.abs(a)", game_state)
        assert.is_true(success)
        assert.equals(5, result)
      end)

      it("should evaluate math.max", function()
        local game_state = create_mock_game_state({a = 5, b = 10})
        local success, result = interpreter:evaluate_expression("math.max(a, b)", game_state)
        assert.is_true(success)
        assert.equals(10, result)
      end)

      it("should evaluate math.floor", function()
        local game_state = create_mock_game_state({x = 3.7})
        local success, result = interpreter:evaluate_expression("math.floor(x)", game_state)
        assert.is_true(success)
        assert.equals(3, result)
      end)

    end)

    describe("string expressions", function()

      it("should concatenate strings", function()
        local game_state = create_mock_game_state({
          first = "John", last = "Doe"
        })
        local success, result = interpreter:evaluate_expression('first .. " " .. last', game_state)
        assert.is_true(success)
        assert.equals("John Doe", result)
      end)

      it("should call string functions", function()
        local game_state = create_mock_game_state({name = "alice"})
        local success, result = interpreter:evaluate_expression("string.upper(name)", game_state)
        assert.is_true(success)
        assert.equals("ALICE", result)
      end)

      it("should get string length", function()
        local game_state = create_mock_game_state({text = "hello"})
        local success, result = interpreter:evaluate_expression("string.len(text)", game_state)
        assert.is_true(success)
        assert.equals(5, result)
      end)

    end)

    describe("comparison expressions", function()

      it("should evaluate greater than", function()
        local game_state = create_mock_game_state({x = 10})
        local success, result = interpreter:evaluate_expression("x > 5", game_state)
        assert.is_true(success)
        assert.is_true(result)
      end)

      it("should evaluate equality", function()
        local game_state = create_mock_game_state({x = 10})
        local success, result = interpreter:evaluate_expression("x == 10", game_state)
        assert.is_true(success)
        assert.is_true(result)
      end)

      it("should evaluate not equal", function()
        local game_state = create_mock_game_state({x = 10})
        local success, result = interpreter:evaluate_expression("x ~= 5", game_state)
        assert.is_true(success)
        assert.is_true(result)
      end)

    end)

    describe("error handling", function()

      it("should handle undefined variables gracefully", function()
        local game_state = create_mock_game_state({})
        local success, result = interpreter:evaluate_expression("undefined_var", game_state)
        assert.is_true(success)
        assert.is_nil(result)
      end)

      it("should return error for syntax errors", function()
        local game_state = create_mock_game_state({})
        local success, result = interpreter:evaluate_expression("1 + + 2", game_state)
        assert.is_false(success)
        assert.is_nil(result)
      end)

      it("should return error for empty expression", function()
        local game_state = create_mock_game_state({})
        local success, result = interpreter:evaluate_expression("", game_state)
        assert.is_false(success)
      end)

    end)

  end)

  describe("Renderer expression interpolation", function()
    local renderer
    local interpreter

    before_each(function()
      local engine = create_mock_engine()
      interpreter = LuaInterpreter.new(engine)
      renderer = Renderer.new(interpreter, "plain")
    end)

    describe("${expression} syntax", function()

      it("should interpolate simple arithmetic", function()
        local result = renderer:evaluate_expressions("Value: ${1 + 2}", create_mock_game_state({}))
        assert.equals("Value: 3", result)
      end)

      it("should interpolate variable expressions", function()
        local result = renderer:evaluate_expressions(
          "Total: ${count + 10}",
          create_mock_game_state({count = 5})
        )
        assert.equals("Total: 15", result)
      end)

      it("should interpolate property access", function()
        local result = renderer:evaluate_expressions(
          "Name: ${player.name}",
          create_mock_game_state({player = {name = "Alice"}})
        )
        assert.equals("Name: Alice", result)
      end)

      it("should interpolate function calls", function()
        local result = renderer:evaluate_expressions(
          "Max: ${math.max(a, b)}",
          create_mock_game_state({a = 5, b = 10})
        )
        assert.equals("Max: 10", result)
      end)

      it("should handle undefined variables gracefully", function()
        local result = renderer:evaluate_expressions(
          "Value: ${undefined_var}",
          create_mock_game_state({})
        )
        assert.equals("Value: ", result)
      end)

      it("should handle syntax errors gracefully", function()
        local result = renderer:evaluate_expressions(
          "Value: ${1 + + 2}",
          create_mock_game_state({})
        )
        assert.equals("Value: ", result)
      end)

    end)

    describe("simple $variable syntax", function()

      it("should interpolate simple variables", function()
        local result = renderer:evaluate_expressions(
          "Hello, $name!",
          create_mock_game_state({name = "Alice"})
        )
        assert.equals("Hello, Alice!", result)
      end)

      it("should handle undefined simple variables", function()
        local result = renderer:evaluate_expressions(
          "Hello, $undefined!",
          create_mock_game_state({})
        )
        assert.equals("Hello, $undefined!", result)
      end)

    end)

    describe("mixed syntax", function()

      it("should handle both $var and ${expr} in same text", function()
        local result = renderer:evaluate_expressions(
          "Player $name has ${gold * 2} gold pieces",
          create_mock_game_state({name = "Bob", gold = 50})
        )
        assert.equals("Player Bob has 100 gold pieces", result)
      end)

    end)

  end)

end)
