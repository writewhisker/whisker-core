-- tests/wls/test_variables.lua
-- WLS 1.0 Variable System Tests
-- Tests story-scoped ($var) and temporary-scoped (_var) variables

describe("WLS 1.0 Variables", function()
    local GameState = require("whisker.core.game_state")
    local LuaInterpreter = require("whisker.core.lua_interpreter")
    local Renderer = require("whisker.core.renderer")

    local game_state
    local interpreter
    local renderer

    before_each(function()
        game_state = GameState.new()
        interpreter = LuaInterpreter.new()
        renderer = Renderer.new("plain")
        renderer:set_interpreter(interpreter)
    end)

    describe("Story Variables ($var)", function()
        it("should set and get story variables", function()
            game_state:set("gold", 100)
            assert.equals(100, game_state:get("gold"))
        end)

        it("should return default for undefined variables", function()
            assert.equals(nil, game_state:get("undefined"))
            assert.equals(0, game_state:get("undefined", 0))
        end)

        it("should check variable existence", function()
            game_state:set("exists", true)
            assert.is_true(game_state:has("exists"))
            assert.is_false(game_state:has("notexists"))
        end)

        it("should delete variables", function()
            game_state:set("temp", "value")
            game_state:delete("temp")
            assert.is_false(game_state:has("temp"))
        end)

        it("should increment and decrement", function()
            game_state:set("count", 10)
            game_state:increment("count", 5)
            assert.equals(15, game_state:get("count"))
            game_state:decrement("count", 3)
            assert.equals(12, game_state:get("count"))
        end)

        it("should persist across passage changes", function()
            game_state:set("persistent", "value")
            game_state:set_current_passage("passage1")
            assert.equals("value", game_state:get("persistent"))
            game_state:set_current_passage("passage2")
            assert.equals("value", game_state:get("persistent"))
        end)
    end)

    describe("Temporary Variables (_var)", function()
        it("should set and get temp variables", function()
            game_state:set_temp("result", 42)
            assert.equals(42, game_state:get_temp("result"))
        end)

        it("should return default for undefined temp variables", function()
            assert.equals(nil, game_state:get_temp("undefined"))
            assert.equals(0, game_state:get_temp("undefined", 0))
        end)

        it("should check temp variable existence", function()
            game_state:set_temp("exists", true)
            assert.is_true(game_state:has_temp("exists"))
            assert.is_false(game_state:has_temp("notexists"))
        end)

        it("should delete temp variables", function()
            game_state:set_temp("temp", "value")
            game_state:delete_temp("temp")
            assert.is_false(game_state:has_temp("temp"))
        end)

        it("should clear on passage change", function()
            game_state:set_temp("localValue", "test")
            assert.equals("test", game_state:get_temp("localValue"))

            game_state:set_current_passage("passage1")
            assert.equals(nil, game_state:get_temp("localValue"))
        end)

        it("should not persist across passages", function()
            game_state:set_current_passage("passage1")
            game_state:set_temp("passageLocal", 100)

            game_state:set_current_passage("passage2")
            assert.equals(nil, game_state:get_temp("passageLocal"))
        end)
    end)

    describe("Shadowing Prevention", function()
        it("should prevent temp shadowing story variable", function()
            game_state:set("gold", 100)

            local old, err = game_state:set_temp("gold", 50)
            assert.equals(nil, old)
            assert.is_not_nil(err)
            assert.matches("shadow", err)
        end)

        it("should allow different names", function()
            game_state:set("gold", 100)

            local old, err = game_state:set_temp("tempGold", 50)
            assert.equals(nil, err)
            assert.equals(50, game_state:get_temp("tempGold"))
        end)

        it("should allow temp first then story later", function()
            game_state:set_temp("value", 10)
            game_state:set("value", 20)  -- Story can shadow temp (different scope)

            assert.equals(10, game_state:get_temp("value"))
            assert.equals(20, game_state:get("value"))
        end)
    end)

    describe("Variable Interpolation", function()
        it("should interpolate $var for story variables", function()
            game_state:set("name", "Alice")
            local result = renderer:evaluate_expressions("Hello, $name!", game_state)
            assert.equals("Hello, Alice!", result)
        end)

        it("should interpolate $_var for temp variables", function()
            game_state:set_temp("result", 42)
            local result = renderer:evaluate_expressions("Result: $_result", game_state)
            assert.equals("Result: 42", result)
        end)

        it("should handle multiple interpolations", function()
            game_state:set("a", 10)
            game_state:set_temp("b", 20)
            local result = renderer:evaluate_expressions("$a + $_b = ${10 + 20}", game_state)
            assert.equals("10 + 20 = 30", result)
        end)

        it("should leave undefined variables as-is", function()
            local result = renderer:evaluate_expressions("Value: $undefined", game_state)
            assert.equals("Value: $undefined", result)
        end)

        it("should escape with backslash", function()
            game_state:set("price", 50)
            local result = renderer:evaluate_expressions("Cost: \\$50 (not $price)", game_state)
            assert.equals("Cost: $50 (not 50)", result)
        end)
    end)

    describe("Expression Evaluation", function()
        it("should access story variables in expressions", function()
            game_state:set("x", 10)
            game_state:set("y", 5)
            local success, result = interpreter:evaluate_expression("x + y", game_state)
            assert.is_true(success)
            assert.equals(15, result)
        end)

        it("should access temp variables with underscore in expressions", function()
            game_state:set_temp("calc", 100)
            local success, result = interpreter:evaluate_expression("_calc * 2", game_state)
            assert.is_true(success)
            assert.equals(200, result)
        end)

        it("should mix story and temp in expressions", function()
            game_state:set("base", 50)
            game_state:set_temp("modifier", 1.5)
            local success, result = interpreter:evaluate_expression("base * _modifier", game_state)
            assert.is_true(success)
            assert.equals(75, result)
        end)
    end)

    describe("Condition Evaluation", function()
        it("should evaluate conditions with story variables", function()
            game_state:set("hasKey", true)
            local success, result = interpreter:evaluate_condition("hasKey", game_state)
            assert.is_true(success)
            assert.is_true(result)
        end)

        it("should evaluate conditions with temp variables", function()
            game_state:set_temp("count", 5)
            local success, result = interpreter:evaluate_condition("_count > 3", game_state)
            assert.is_true(success)
            assert.is_true(result)
        end)

        it("should evaluate complex conditions", function()
            game_state:set("gold", 100)
            game_state:set_temp("discount", 20)
            local success, result = interpreter:evaluate_condition("gold - _discount >= 80", game_state)
            assert.is_true(success)
            assert.is_true(result)
        end)
    end)

    describe("Serialization", function()
        it("should serialize story variables", function()
            game_state:set("saved", "value")
            local data = game_state:serialize()
            assert.equals("value", data.variables.saved)
        end)

        it("should NOT serialize temp variables", function()
            game_state:set_temp("notSaved", "value")
            local data = game_state:serialize()
            assert.equals(nil, data.temp_variables)  -- Not included in save
        end)

        it("should clear temp on deserialize", function()
            game_state:set_temp("before", "value")
            local data = game_state:serialize()
            game_state:deserialize(data)
            assert.equals(nil, game_state:get_temp("before"))
        end)
    end)

    describe("Reset Behavior", function()
        it("should clear story variables on reset", function()
            game_state:set("var", "value")
            game_state:reset()
            assert.equals(nil, game_state:get("var"))
        end)

        it("should clear temp variables on reset", function()
            game_state:set_temp("temp", "value")
            game_state:reset()
            assert.equals(nil, game_state:get_temp("temp"))
        end)
    end)

    describe("API Access", function()
        it("should expose story vars via whisker.state API", function()
            game_state:set("apiVar", 123)
            local context = { story = nil, engine = nil }
            local api = interpreter:create_story_api(game_state, context)

            assert.equals(123, api.whisker.state.get("apiVar"))
        end)

        it("should expose temp vars via whisker.state API", function()
            game_state:set_temp("apiTemp", 456)
            local context = { story = nil, engine = nil }
            local api = interpreter:create_story_api(game_state, context)

            assert.equals(456, api.whisker.state.get_temp("apiTemp"))
        end)

        it("should check existence via API", function()
            game_state:set("exists", true)
            game_state:set_temp("tempExists", true)
            local context = { story = nil, engine = nil }
            local api = interpreter:create_story_api(game_state, context)

            assert.is_true(api.whisker.state.has("exists"))
            assert.is_false(api.whisker.state.has("notexists"))
            assert.is_true(api.whisker.state.has_temp("tempExists"))
            assert.is_false(api.whisker.state.has_temp("notexists"))
        end)

        it("should enforce shadowing via API", function()
            game_state:set("shared", 100)
            local context = { story = nil, engine = nil }
            local api = interpreter:create_story_api(game_state, context)

            assert.has_error(function()
                api.whisker.state.set_temp("shared", 50)
            end)
        end)
    end)

    describe("Initialize Behavior", function()
        it("should clear temp variables on initialize", function()
            game_state:set_temp("beforeInit", "value")
            game_state:initialize({ metadata = {}, variables = {} })
            assert.equals(nil, game_state:get_temp("beforeInit"))
        end)

        it("should load story variables from story", function()
            local story = {
                metadata = { ifid = "test-123" },
                variables = {
                    gold = 100,
                    name = "Hero"
                }
            }
            game_state:initialize(story)
            assert.equals(100, game_state:get("gold"))
            assert.equals("Hero", game_state:get("name"))
        end)
    end)
end)
