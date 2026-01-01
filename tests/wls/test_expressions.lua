-- tests/wls/test_expressions.lua
-- WLS 1.0 Expression Syntax Tests
-- Tests for $var and ${expr} interpolation

local helper = require("tests.test_helper")
local Story = require("whisker.core.story")
local Passage = require("whisker.core.passage")
local Choice = require("whisker.core.choice")
local Engine = require("whisker.core.engine")
local GameState = require("whisker.core.game_state")
local Renderer = require("whisker.core.renderer")
local LuaInterpreter = require("whisker.core.lua_interpreter")

describe("WLS 1.0 Expression Syntax", function()

    -- Helper to create a test story with custom content
    local function create_story_with_content(content)
        local story = Story.new()
        story:set_metadata("name", "Expression Test")

        local start = Passage.new("start", "start")
        start:set_content(content)

        story:add_passage(start)
        story:set_start_passage("start")

        return story
    end

    -- ============================================
    -- $var Simple Variable Interpolation Tests
    -- ============================================

    describe("$var Simple Interpolation", function()
        local engine, game_state, story

        -- Helper to render content after setting variables
        local function render_with_vars(content_text, vars)
            story = create_story_with_content(content_text)
            game_state = GameState.new()
            engine = Engine.new(story, game_state)
            engine:start_story()
            -- Set variables AFTER start (which resets game state)
            for k, v in pairs(vars or {}) do
                game_state:set(k, v)
            end
            -- Re-render by navigating to the passage
            return engine:render_passage_content(story:get_passage("start"))
        end

        it("should interpolate simple variable", function()
            local result = render_with_vars("Hello, $name!", {name = "Alice"})
            assert.equals("Hello, Alice!", result)
        end)

        it("should interpolate number variable", function()
            local result = render_with_vars("You have $gold gold.", {gold = 100})
            assert.equals("You have 100 gold.", result)
        end)

        it("should interpolate boolean variable", function()
            local result = render_with_vars("Has key: $hasKey", {hasKey = true})
            assert.equals("Has key: true", result)
        end)

        it("should keep undefined variable as-is", function()
            local result = render_with_vars("Value: $undefined", {})
            assert.equals("Value: $undefined", result)
        end)

        it("should interpolate multiple variables", function()
            local result = render_with_vars("$name has $gold gold and $health HP.", {
                name = "Bob",
                gold = 50,
                health = 100
            })
            assert.equals("Bob has 50 gold and 100 HP.", result)
        end)

        it("should handle underscore in variable names", function()
            local result = render_with_vars("Player: $player_name", {player_name = "Charlie"})
            assert.equals("Player: Charlie", result)
        end)

        it("should handle variable at start of line", function()
            local result = render_with_vars("$greeting friend!", {greeting = "Hello"})
            assert.equals("Hello friend!", result)
        end)

        it("should handle variable at end of line", function()
            local result = render_with_vars("Total: $total", {total = 42})
            assert.equals("Total: 42", result)
        end)
    end)

    -- ============================================
    -- ${expr} Expression Interpolation Tests
    -- ============================================

    describe("${expr} Expression Interpolation", function()
        local engine, game_state, story

        -- Helper to render content after setting variables
        local function render_with_vars(content_text, vars)
            story = create_story_with_content(content_text)
            game_state = GameState.new()
            engine = Engine.new(story, game_state)
            engine:start_story()
            for k, v in pairs(vars or {}) do
                game_state:set(k, v)
            end
            return engine:render_passage_content(story:get_passage("start"))
        end

        it("should evaluate arithmetic expression", function()
            local result = render_with_vars("Sum: ${10 + 5}", {})
            assert.equals("Sum: 15", result)
        end)

        it("should evaluate expression with variables", function()
            local result = render_with_vars(
                "Total: ${whisker.state.get('a') + whisker.state.get('b')}",
                {a = 10, b = 20}
            )
            assert.equals("Total: 30", result)
        end)

        it("should evaluate string concatenation", function()
            local result = render_with_vars([[Result: ${"Hello" .. " " .. "World"}]], {})
            assert.equals("Result: Hello World", result)
        end)

        it("should evaluate math functions", function()
            local result = render_with_vars("Max: ${math.max(5, 10)}", {})
            assert.equals("Max: 10", result)
        end)

        it("should evaluate conditional expression", function()
            local result = render_with_vars(
                [[Status: ${whisker.state.get('gold') >= 100 and "Rich" or "Poor"}]],
                {gold = 150}
            )
            assert.equals("Status: Rich", result)
        end)

        it("should handle whitespace in expression", function()
            local result = render_with_vars("Value: ${  10 + 5  }", {})
            assert.equals("Value: 15", result)
        end)

        it("should use random function", function()
            local result = render_with_vars("Roll: ${random(1, 6)}", {})
            local roll = tonumber(result:match("Roll: (%d+)"))
            assert.is_true(roll >= 1 and roll <= 6)
        end)

        it("should use pick function", function()
            local result = render_with_vars([[Choice: ${pick("a", "b", "c")}]], {})
            local choice = result:match("Choice: (.)")
            assert.is_true(choice == "a" or choice == "b" or choice == "c")
        end)
    end)

    -- ============================================
    -- Escape Sequence Tests
    -- ============================================

    describe("Escape Sequences", function()
        local engine, game_state, story

        local function render_with_vars(content_text, vars)
            story = create_story_with_content(content_text)
            game_state = GameState.new()
            engine = Engine.new(story, game_state)
            engine:start_story()
            for k, v in pairs(vars or {}) do
                game_state:set(k, v)
            end
            return engine:render_passage_content(story:get_passage("start"))
        end

        it("should escape dollar sign", function()
            local result = render_with_vars("Price: \\$100", {})
            assert.equals("Price: $100", result)
        end)

        it("should escape opening brace", function()
            local result = render_with_vars("Code: \\{test\\}", {})
            assert.equals("Code: {test}", result)
        end)

        it("should mix escaped and interpolated", function()
            local result = render_with_vars("Cost: \\$${whisker.state.get('price')}", {price = 50})
            assert.equals("Cost: $50", result)
        end)
    end)

    -- ============================================
    -- Legacy {{expr}} Syntax Tests (Backward Compat)
    -- ============================================

    describe("Legacy {{expr}} Syntax", function()
        local engine, game_state, story

        local function render_with_vars(content_text, vars)
            story = create_story_with_content(content_text)
            game_state = GameState.new()
            engine = Engine.new(story, game_state)
            engine:start_story()
            for k, v in pairs(vars or {}) do
                game_state:set(k, v)
            end
            return engine:render_passage_content(story:get_passage("start"))
        end

        it("should still support legacy {{expr}} syntax", function()
            local result = render_with_vars("Value: {{10 + 5}}", {})
            assert.equals("Value: 15", result)
        end)

        it("should support legacy variable access", function()
            local result = render_with_vars("Gold: {{whisker.state.get('gold')}}", {gold = 75})
            assert.equals("Gold: 75", result)
        end)
    end)

    -- ============================================
    -- Mixed Syntax Tests
    -- ============================================

    describe("Mixed Syntax", function()
        local engine, game_state, story

        local function render_with_vars(content_text, vars)
            story = create_story_with_content(content_text)
            game_state = GameState.new()
            engine = Engine.new(story, game_state)
            engine:start_story()
            for k, v in pairs(vars or {}) do
                game_state:set(k, v)
            end
            return engine:render_passage_content(story:get_passage("start"))
        end

        it("should handle $var and ${expr} together", function()
            local result = render_with_vars(
                "$name has ${whisker.state.get('gold') * 2} effective gold.",
                {name = "Alice", gold = 50}
            )
            assert.equals("Alice has 100 effective gold.", result)
        end)

        it("should handle all syntaxes in one string", function()
            local result = render_with_vars(
                "$name: \\$${whisker.state.get('gold')} ({{whisker.state.get('gold')}})",
                {name = "Bob", gold = 25}
            )
            assert.equals("Bob: $25 (25)", result)
        end)
    end)

    -- ============================================
    -- Renderer Tests
    -- ============================================

    describe("Renderer Expression Evaluation", function()
        local renderer, interpreter, game_state

        before_each(function()
            renderer = Renderer.new("plain")
            interpreter = LuaInterpreter.new()
            game_state = GameState.new()
            renderer:set_interpreter(interpreter)
        end)

        it("should evaluate $var in renderer", function()
            game_state:set("name", "TestUser")
            local result = renderer:evaluate_expressions("Hello $name!", game_state)
            assert.equals("Hello TestUser!", result)
        end)

        it("should evaluate ${expr} in renderer", function()
            local result = renderer:evaluate_expressions("Sum: ${5 + 3}", game_state)
            assert.equals("Sum: 8", result)
        end)

        it("should handle escape sequences in renderer", function()
            local result = renderer:evaluate_expressions("Price: \\$100", game_state)
            assert.equals("Price: $100", result)
        end)
    end)

end)
