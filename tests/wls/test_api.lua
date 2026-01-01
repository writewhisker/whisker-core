-- tests/wls/test_api.lua
-- WLS 1.0 API Tests
-- Tests for the unified whisker.* namespace with dot notation

local helper = require("tests.test_helper")
local Story = require("whisker.core.story")
local Passage = require("whisker.core.passage")
local Choice = require("whisker.core.choice")
local Engine = require("whisker.core.engine")
local GameState = require("whisker.core.game_state")
local LuaInterpreter = require("whisker.core.lua_interpreter")

describe("WLS 1.0 API", function()

    -- Helper to create a test story
    local function create_test_story()
        local story = Story.new()
        story:set_metadata("name", "API Test Story")
        story:set_metadata("ifid", "TEST-API-001")

        local start = Passage.new("start", "start")
        start:set_content("Welcome! Gold: {{whisker.state.get('gold')}}")
        start.tags = {"intro", "main"}

        local shop = Passage.new("shop", "shop")
        shop:set_content("Welcome to the shop!")
        shop.tags = {"shop"}

        local forest = Passage.new("forest", "forest")
        forest:set_content("You enter the forest.")
        forest.tags = {"outdoor"}

        local choice1 = Choice.new("Go to shop", "shop")
        local choice2 = Choice.new("Enter forest", "forest")
        start:add_choice(choice1)
        start:add_choice(choice2)

        story:add_passage(start)
        story:add_passage(shop)
        story:add_passage(forest)
        story:set_start_passage("start")

        return story
    end

    -- ============================================
    -- whisker.state Tests
    -- ============================================

    describe("whisker.state", function()
        local interpreter, game_state, context

        before_each(function()
            interpreter = LuaInterpreter.new()
            game_state = GameState.new()
            context = {
                story = create_test_story(),
                engine = nil
            }
        end)

        it("should get and set variables with dot notation", function()
            local code = [[
                whisker.state.set("gold", 100)
                return whisker.state.get("gold")
            ]]
            local success, result = interpreter:execute_code(code, game_state, context)
            assert.is_true(success)
            assert.equals(100, result)
        end)

        it("should check if variable exists with has()", function()
            local code = [[
                whisker.state.set("name", "Alice")
                return whisker.state.has("name")
            ]]
            local success, result = interpreter:execute_code(code, game_state, context)
            assert.is_true(success)
            assert.is_true(result)
        end)

        it("should return false for non-existent variable with has()", function()
            local code = [[
                return whisker.state.has("nonexistent")
            ]]
            local success, result = interpreter:execute_code(code, game_state, context)
            assert.is_true(success)
            assert.is_false(result)
        end)

        it("should delete variables with delete()", function()
            local code = [[
                whisker.state.set("temp", 50)
                whisker.state.delete("temp")
                return whisker.state.has("temp")
            ]]
            local success, result = interpreter:execute_code(code, game_state, context)
            assert.is_true(success)
            assert.is_false(result)
        end)

        it("should get all variables with all()", function()
            local code = [[
                whisker.state.set("a", 1)
                whisker.state.set("b", 2)
                local vars = whisker.state.all()
                return vars.a + vars.b
            ]]
            local success, result = interpreter:execute_code(code, game_state, context)
            assert.is_true(success)
            assert.equals(3, result)
        end)

        it("should reset all variables with reset()", function()
            local code = [[
                whisker.state.set("gold", 100)
                whisker.state.reset()
                return whisker.state.has("gold")
            ]]
            local success, result = interpreter:execute_code(code, game_state, context)
            assert.is_true(success)
            assert.is_false(result)
        end)

        it("should handle string variables", function()
            local code = [[
                whisker.state.set("name", "Alice")
                return whisker.state.get("name")
            ]]
            local success, result = interpreter:execute_code(code, game_state, context)
            assert.is_true(success)
            assert.equals("Alice", result)
        end)

        it("should handle boolean variables", function()
            local code = [[
                whisker.state.set("hasKey", true)
                return whisker.state.get("hasKey")
            ]]
            local success, result = interpreter:execute_code(code, game_state, context)
            assert.is_true(success)
            assert.is_true(result)
        end)
    end)

    -- ============================================
    -- whisker.passage Tests
    -- ============================================

    describe("whisker.passage", function()
        local interpreter, game_state, engine, story

        before_each(function()
            interpreter = LuaInterpreter.new()
            game_state = GameState.new()
            story = create_test_story()
            engine = Engine.new(story, game_state)
            engine:start_story()
        end)

        it("should get current passage", function()
            local context = { story = story, engine = engine }
            local code = [[
                local p = whisker.passage.current()
                return p and p.id or "nil"
            ]]
            local success, result = interpreter:execute_code(code, game_state, context)
            assert.is_true(success)
            assert.equals("start", result)
        end)

        it("should get passage by id", function()
            local context = { story = story, engine = engine }
            local code = [[
                local p = whisker.passage.get("shop")
                return p and p.id or "nil"
            ]]
            local success, result = interpreter:execute_code(code, game_state, context)
            assert.is_true(success)
            assert.equals("shop", result)
        end)

        it("should check if passage exists", function()
            local context = { story = story, engine = engine }
            local code = [[
                return whisker.passage.exists("shop")
            ]]
            local success, result = interpreter:execute_code(code, game_state, context)
            assert.is_true(success)
            assert.is_true(result)
        end)

        it("should return false for non-existent passage", function()
            local context = { story = story, engine = engine }
            local code = [[
                return whisker.passage.exists("nonexistent")
            ]]
            local success, result = interpreter:execute_code(code, game_state, context)
            assert.is_true(success)
            assert.is_false(result)
        end)

        it("should get all passage ids", function()
            local context = { story = story, engine = engine }
            local code = [[
                local ids = whisker.passage.all()
                return #ids
            ]]
            local success, result = interpreter:execute_code(code, game_state, context)
            assert.is_true(success)
            assert.equals(3, result)
        end)

        it("should get passages by tag", function()
            local context = { story = story, engine = engine }
            local code = [[
                local tagged = whisker.passage.tags("intro")
                return #tagged
            ]]
            local success, result = interpreter:execute_code(code, game_state, context)
            assert.is_true(success)
            assert.equals(1, result)
        end)

        it("should navigate with go() via deferred execution", function()
            local context = { story = story, engine = engine, _pending_navigation = nil }
            local code = [[
                whisker.passage.go("shop")
                return true
            ]]
            local success, result = interpreter:execute_code(code, game_state, context)
            assert.is_true(success)
            assert.equals("shop", context._pending_navigation)
        end)
    end)

    -- ============================================
    -- whisker.history Tests
    -- ============================================

    describe("whisker.history", function()
        local interpreter, game_state, engine, story

        before_each(function()
            interpreter = LuaInterpreter.new()
            game_state = GameState.new()
            story = create_test_story()
            engine = Engine.new(story, game_state)
            engine:start_story()
        end)

        it("should check if back is possible with canBack()", function()
            local context = { story = story, engine = engine }
            local code = [[
                return whisker.history.canBack()
            ]]
            local success, result = interpreter:execute_code(code, game_state, context)
            assert.is_true(success)
            -- First passage, can't go back
            assert.is_false(result)
        end)

        it("should get history list", function()
            local context = { story = story, engine = engine }
            local code = [[
                return #whisker.history.list()
            ]]
            local success, result = interpreter:execute_code(code, game_state, context)
            assert.is_true(success)
            assert.equals(1, result) -- visited start
        end)

        it("should get history count", function()
            local context = { story = story, engine = engine }
            local code = [[
                return whisker.history.count()
            ]]
            local success, result = interpreter:execute_code(code, game_state, context)
            assert.is_true(success)
            assert.equals(1, result)
        end)

        it("should check if passage is in history with contains()", function()
            local context = { story = story, engine = engine }
            local code = [[
                return whisker.history.contains("start")
            ]]
            local success, result = interpreter:execute_code(code, game_state, context)
            assert.is_true(success)
            assert.is_true(result)
        end)

        it("should return false for unvisited passage with contains()", function()
            local context = { story = story, engine = engine }
            local code = [[
                return whisker.history.contains("shop")
            ]]
            local success, result = interpreter:execute_code(code, game_state, context)
            assert.is_true(success)
            assert.is_false(result)
        end)

        it("should clear history", function()
            -- First navigate to build history
            engine:make_choice(1) -- go to shop
            local context = { story = story, engine = engine }
            local code = [[
                whisker.history.clear()
                return true
            ]]
            local success, result = interpreter:execute_code(code, game_state, context)
            assert.is_true(success)
            assert.is_true(result)
        end)
    end)

    -- ============================================
    -- whisker.choice Tests
    -- ============================================

    describe("whisker.choice", function()
        local interpreter, game_state, engine, story

        before_each(function()
            interpreter = LuaInterpreter.new()
            game_state = GameState.new()
            story = create_test_story()
            engine = Engine.new(story, game_state)
            engine:start_story()
        end)

        it("should get available choices", function()
            local context = { story = story, engine = engine }
            local code = [[
                local choices = whisker.choice.available()
                return #choices
            ]]
            local success, result = interpreter:execute_code(code, game_state, context)
            assert.is_true(success)
            assert.equals(2, result)
        end)

        it("should get choice count", function()
            local context = { story = story, engine = engine }
            local code = [[
                return whisker.choice.count()
            ]]
            local success, result = interpreter:execute_code(code, game_state, context)
            assert.is_true(success)
            assert.equals(2, result)
        end)

        it("should select choice via deferred execution", function()
            local context = { story = story, engine = engine, _pending_choice = nil }
            local code = [[
                whisker.choice.select(1)
                return true
            ]]
            local success, result = interpreter:execute_code(code, game_state, context)
            assert.is_true(success)
            assert.equals(1, context._pending_choice)
        end)
    end)

    -- ============================================
    -- Top-Level Functions Tests
    -- ============================================

    describe("Top-Level Functions", function()
        local interpreter, game_state, context

        before_each(function()
            interpreter = LuaInterpreter.new()
            game_state = GameState.new()
            context = { story = create_test_story(), engine = nil }
        end)

        it("should check visited count for current passage", function()
            game_state:set_current_passage("start")
            local code = [[
                return visited()
            ]]
            local success, result = interpreter:execute_code(code, game_state, context)
            assert.is_true(success)
            assert.equals(1, result)
        end)

        it("should check visited count for specific passage", function()
            game_state:set_current_passage("start")
            local code = [[
                return visited("shop")
            ]]
            local success, result = interpreter:execute_code(code, game_state, context)
            assert.is_true(success)
            assert.equals(0, result)
        end)

        it("should generate random number in range", function()
            local code = [[
                local r = random(1, 6)
                return r >= 1 and r <= 6
            ]]
            local success, result = interpreter:execute_code(code, game_state, context)
            assert.is_true(success)
            assert.is_true(result)
        end)

        it("should generate random with single argument", function()
            local code = [[
                local r = random(10)
                return r >= 1 and r <= 10
            ]]
            local success, result = interpreter:execute_code(code, game_state, context)
            assert.is_true(success)
            assert.is_true(result)
        end)

        it("should pick random from arguments", function()
            local code = [[
                local p = pick("a", "b", "c")
                return p == "a" or p == "b" or p == "c"
            ]]
            local success, result = interpreter:execute_code(code, game_state, context)
            assert.is_true(success)
            assert.is_true(result)
        end)

        it("should return nil for empty pick", function()
            local code = [[
                return pick()
            ]]
            local success, result = interpreter:execute_code(code, game_state, context)
            assert.is_true(success)
            assert.is_nil(result)
        end)
    end)

    -- ============================================
    -- Backward Compatibility Tests
    -- ============================================

    describe("Backward Compatibility", function()
        local interpreter, game_state, context

        before_each(function()
            interpreter = LuaInterpreter.new()
            game_state = GameState.new()
            context = { story = create_test_story(), engine = nil }
        end)

        it("should support legacy get() function", function()
            game_state:set("gold", 50)
            local code = [[
                return get("gold")
            ]]
            local success, result = interpreter:execute_code(code, game_state, context)
            assert.is_true(success)
            assert.equals(50, result)
        end)

        it("should support legacy set() function", function()
            local code = [[
                set("gold", 100)
                return get("gold")
            ]]
            local success, result = interpreter:execute_code(code, game_state, context)
            assert.is_true(success)
            assert.equals(100, result)
        end)

        it("should support legacy inc() function", function()
            game_state:set("count", 5)
            local code = [[
                inc("count", 3)
                return get("count")
            ]]
            local success, result = interpreter:execute_code(code, game_state, context)
            assert.is_true(success)
            assert.equals(8, result)
        end)

        it("should support legacy dec() function", function()
            game_state:set("count", 10)
            local code = [[
                dec("count", 2)
                return get("count")
            ]]
            local success, result = interpreter:execute_code(code, game_state, context)
            assert.is_true(success)
            assert.equals(8, result)
        end)

        it("should support legacy has() function", function()
            game_state:set("key", true)
            local code = [[
                return has("key")
            ]]
            local success, result = interpreter:execute_code(code, game_state, context)
            assert.is_true(success)
            assert.is_true(result)
        end)

        it("should support legacy del() function", function()
            game_state:set("temp", 100)
            local code = [[
                del("temp")
                return has("temp")
            ]]
            local success, result = interpreter:execute_code(code, game_state, context)
            assert.is_true(success)
            assert.is_false(result)
        end)
    end)

end)
