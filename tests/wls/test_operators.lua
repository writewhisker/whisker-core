-- tests/wls/test_operators.lua
-- WLS 1.0 Operator Standardization Tests
-- Tests for Lua-style operators (and, or, not, ~=)

local helper = require("tests.test_helper")
local Lexer = require("whisker.script.lexer").Lexer
local Story = require("whisker.core.story")
local Passage = require("whisker.core.passage")
local Engine = require("whisker.core.engine")
local GameState = require("whisker.core.game_state")

describe("WLS 1.0 Operator Standardization", function()

    -- ============================================
    -- Lexer Tests - Lua-style Operators Accepted
    -- ============================================

    describe("Lua-style operators (accepted)", function()

        it("should tokenize 'and' as AND", function()
            local lexer = Lexer.new("x and y")
            local tokens = lexer:tokenize()
            -- Find the AND token
            local found = false
            for _, token in ipairs(tokens) do
                if token.type == "AND" then
                    found = true
                    break
                end
            end
            assert.is_true(found)
        end)

        it("should tokenize 'or' as OR", function()
            local lexer = Lexer.new("x or y")
            local tokens = lexer:tokenize()
            local found = false
            for _, token in ipairs(tokens) do
                if token.type == "OR" then
                    found = true
                    break
                end
            end
            assert.is_true(found)
        end)

        it("should tokenize 'not' as NOT", function()
            local lexer = Lexer.new("not x")
            local tokens = lexer:tokenize()
            local found = false
            for _, token in ipairs(tokens) do
                if token.type == "NOT" then
                    found = true
                    break
                end
            end
            assert.is_true(found)
        end)

        it("should tokenize '~=' as NEQ", function()
            local lexer = Lexer.new("x ~= y")
            local tokens = lexer:tokenize()
            local found = false
            for _, token in ipairs(tokens) do
                if token.type == "NEQ" then
                    found = true
                    break
                end
            end
            assert.is_true(found)
        end)

        it("should tokenize 'and' in complex expression", function()
            local lexer = Lexer.new("x > 5 and y < 10")
            local tokens = lexer:tokenize()
            local found = false
            for _, token in ipairs(tokens) do
                if token.type == "AND" then
                    found = true
                    break
                end
            end
            assert.is_true(found)
        end)

        it("should tokenize 'or' in complex expression", function()
            local lexer = Lexer.new("a == 1 or b == 2")
            local tokens = lexer:tokenize()
            local found = false
            for _, token in ipairs(tokens) do
                if token.type == "OR" then
                    found = true
                    break
                end
            end
            assert.is_true(found)
        end)

        it("should tokenize 'not' with parentheses", function()
            local lexer = Lexer.new("not (x and y)")
            local tokens = lexer:tokenize()
            local found = false
            for _, token in ipairs(tokens) do
                if token.type == "NOT" then
                    found = true
                    break
                end
            end
            assert.is_true(found)
        end)

        it("should tokenize multiple Lua operators", function()
            local lexer = Lexer.new("a and b or not c")
            local tokens = lexer:tokenize()
            local and_found, or_found, not_found = false, false, false
            for _, token in ipairs(tokens) do
                if token.type == "AND" then and_found = true end
                if token.type == "OR" then or_found = true end
                if token.type == "NOT" then not_found = true end
            end
            assert.is_true(and_found)
            assert.is_true(or_found)
            assert.is_true(not_found)
        end)
    end)

    -- ============================================
    -- Lexer Tests - C-style Operators Rejected
    -- ============================================

    describe("C-style operators (rejected with error)", function()

        it("should reject '&&' with helpful error", function()
            local lexer = Lexer.new("x && y")
            local tokens = lexer:tokenize()
            local error_found = false
            local error_message = nil
            for _, token in ipairs(tokens) do
                if token.type == "ERROR" then
                    error_found = true
                    error_message = token.value
                    break
                end
            end
            assert.is_true(error_found)
            assert.matches("Use 'and'", error_message)
        end)

        it("should reject '||' with helpful error", function()
            local lexer = Lexer.new("x || y")
            local tokens = lexer:tokenize()
            local error_found = false
            local error_message = nil
            for _, token in ipairs(tokens) do
                if token.type == "ERROR" then
                    error_found = true
                    error_message = token.value
                    break
                end
            end
            assert.is_true(error_found)
            assert.matches("Use 'or'", error_message)
        end)

        it("should reject '!' with helpful error", function()
            local lexer = Lexer.new("!x")
            local tokens = lexer:tokenize()
            local error_found = false
            local error_message = nil
            for _, token in ipairs(tokens) do
                if token.type == "ERROR" then
                    error_found = true
                    error_message = token.value
                    break
                end
            end
            assert.is_true(error_found)
            assert.matches("Use 'not'", error_message)
        end)

        it("should reject '!=' with helpful error", function()
            local lexer = Lexer.new("x != y")
            local tokens = lexer:tokenize()
            local error_found = false
            local error_message = nil
            for _, token in ipairs(tokens) do
                if token.type == "ERROR" then
                    error_found = true
                    error_message = token.value
                    break
                end
            end
            assert.is_true(error_found)
            assert.matches("Use '~='", error_message)
        end)

        it("error message should mention WLS 1.0", function()
            local lexer = Lexer.new("x && y")
            local tokens = lexer:tokenize()
            local error_message = nil
            for _, token in ipairs(tokens) do
                if token.type == "ERROR" then
                    error_message = token.value
                    break
                end
            end
            assert.matches("WLS 1.0", error_message)
        end)
    end)

    -- ============================================
    -- Comparison Operators (still valid)
    -- ============================================

    describe("Comparison operators (unchanged)", function()

        it("should tokenize '==' as EQ", function()
            local lexer = Lexer.new("x == y")
            local tokens = lexer:tokenize()
            local found = false
            for _, token in ipairs(tokens) do
                if token.type == "EQ" then
                    found = true
                    break
                end
            end
            assert.is_true(found)
        end)

        it("should tokenize '<' as LT", function()
            local lexer = Lexer.new("x < y")
            local tokens = lexer:tokenize()
            local found = false
            for _, token in ipairs(tokens) do
                if token.type == "LT" then
                    found = true
                    break
                end
            end
            assert.is_true(found)
        end)

        it("should tokenize '>' as GT", function()
            local lexer = Lexer.new("x > y")
            local tokens = lexer:tokenize()
            local found = false
            for _, token in ipairs(tokens) do
                if token.type == "GT" then
                    found = true
                    break
                end
            end
            assert.is_true(found)
        end)

        it("should tokenize '<=' as LTE", function()
            local lexer = Lexer.new("x <= y")
            local tokens = lexer:tokenize()
            local found = false
            for _, token in ipairs(tokens) do
                if token.type == "LTE" then
                    found = true
                    break
                end
            end
            assert.is_true(found)
        end)

        it("should tokenize '>=' as GTE", function()
            local lexer = Lexer.new("x >= y")
            local tokens = lexer:tokenize()
            local found = false
            for _, token in ipairs(tokens) do
                if token.type == "GTE" then
                    found = true
                    break
                end
            end
            assert.is_true(found)
        end)
    end)

    -- ============================================
    -- Expression Evaluation with Lua Operators
    -- ============================================

    describe("Expression evaluation with Lua operators", function()
        local engine, game_state, story

        local function create_story_with_content(content)
            local s = Story.new()
            s:set_metadata("name", "Operator Test")
            local start = Passage.new("start", "start")
            start:set_content(content)
            s:add_passage(start)
            s:set_start_passage("start")
            return s
        end

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

        it("should evaluate 'and' in expressions", function()
            local result = render_with_vars(
                [[Result: ${whisker.state.get('a') and whisker.state.get('b')}]],
                {a = true, b = "yes"}
            )
            assert.equals("Result: yes", result)
        end)

        it("should evaluate 'or' in expressions", function()
            local result = render_with_vars(
                [[Result: ${whisker.state.get('a') or whisker.state.get('b')}]],
                {a = false, b = "fallback"}
            )
            assert.equals("Result: fallback", result)
        end)

        it("should evaluate 'not' in expressions", function()
            local result = render_with_vars(
                [[Result: ${not whisker.state.get('flag')}]],
                {flag = false}
            )
            assert.equals("Result: true", result)
        end)

        it("should evaluate '~=' in expressions", function()
            local result = render_with_vars(
                [[Different: ${whisker.state.get('a') ~= whisker.state.get('b')}]],
                {a = 1, b = 2}
            )
            assert.equals("Different: true", result)
        end)

        it("should evaluate complex Lua expression", function()
            local result = render_with_vars(
                [[Status: ${(whisker.state.get('gold') >= 100 and "Rich") or "Poor"}]],
                {gold = 150}
            )
            assert.equals("Status: Rich", result)
        end)
    end)

end)
