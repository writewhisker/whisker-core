-- tests/wls/test_conditionals.lua
-- WLS 1.0 Conditional Block Tests
-- Tests for { condition }...{else}...{elif}...{/} syntax

local helper = require("tests.test_helper")
local Story = require("whisker.core.story")
local Passage = require("whisker.core.passage")
local Engine = require("whisker.core.engine")
local GameState = require("whisker.core.game_state")

describe("WLS 1.0 Control Flow", function()

    -- Helper to create a test story with custom content
    local function create_story_with_content(content)
        local story = Story.new()
        story:set_metadata("name", "Conditional Test")

        local start = Passage.new("start", "start")
        start:set_content(content)

        story:add_passage(start)
        story:set_start_passage("start")

        return story
    end

    -- Helper to render content after setting variables
    local function render_with_vars(content_text, vars)
        local story = create_story_with_content(content_text)
        local game_state = GameState.new()
        local engine = Engine.new(story, game_state)
        engine:start_story()
        for k, v in pairs(vars or {}) do
            game_state:set(k, v)
        end
        return engine:render_passage_content(story:get_passage("start"))
    end

    -- ============================================
    -- Block Conditionals: { condition }...{/}
    -- ============================================

    describe("Block Conditionals", function()

        it("should show content when condition is true", function()
            local result = render_with_vars(
                "Start. { $hasKey }You have a key.{/} End.",
                {hasKey = true}
            )
            assert.equals("Start. You have a key. End.", result)
        end)

        it("should hide content when condition is false", function()
            local result = render_with_vars(
                "Start. { $hasKey }You have a key.{/} End.",
                {hasKey = false}
            )
            assert.equals("Start.  End.", result)
        end)

        it("should evaluate numeric comparisons", function()
            local result = render_with_vars(
                "{ $gold >= 100 }You are rich!{/}",
                {gold = 150}
            )
            assert.equals("You are rich!", result)
        end)

        it("should evaluate string comparisons", function()
            local result = render_with_vars(
                [[{ whisker.state.get('name') == "Hero" }Welcome, Hero!{/}]],
                {name = "Hero"}
            )
            assert.equals("Welcome, Hero!", result)
        end)

        it("should evaluate logical operators", function()
            local result = render_with_vars(
                "{ $hasKey and $hasTorch }You can enter the cave.{/}",
                {hasKey = true, hasTorch = true}
            )
            assert.equals("You can enter the cave.", result)
        end)

        it("should evaluate logical or", function()
            local result = render_with_vars(
                "{ $gold >= 50 or $hasDiscount }You can afford it.{/}",
                {gold = 30, hasDiscount = true}
            )
            assert.equals("You can afford it.", result)
        end)

        it("should evaluate not operator", function()
            local result = render_with_vars(
                "{ not $isLocked }The door is open.{/}",
                {isLocked = false}
            )
            assert.equals("The door is open.", result)
        end)
    end)

    -- ============================================
    -- Else Clauses
    -- ============================================

    describe("Else Clauses", function()

        it("should show else content when condition is false", function()
            local result = render_with_vars(
                "{ $hasKey }Unlocked.{else}Locked.{/}",
                {hasKey = false}
            )
            assert.equals("Locked.", result)
        end)

        it("should show if content when condition is true", function()
            local result = render_with_vars(
                "{ $hasKey }Unlocked.{else}Locked.{/}",
                {hasKey = true}
            )
            assert.equals("Unlocked.", result)
        end)

        it("should handle multiline content", function()
            local result = render_with_vars([[{ $verbose }
Line one.
Line two.
{else}
Brief.
{/}]], {verbose = true})
            assert.matches("Line one", result)
            assert.matches("Line two", result)
        end)
    end)

    -- ============================================
    -- Elif Clauses
    -- ============================================

    describe("Elif Clauses", function()

        it("should evaluate elif when first condition is false", function()
            local result = render_with_vars(
                "{ $health > 75 }Strong.{elif $health > 50}Decent.{elif $health > 25}Weak.{else}Critical.{/}",
                {health = 60}
            )
            assert.equals("Decent.", result)
        end)

        it("should stop at first true condition", function()
            local result = render_with_vars(
                "{ $health > 75 }Strong.{elif $health > 50}Decent.{elif $health > 25}Weak.{else}Critical.{/}",
                {health = 90}
            )
            assert.equals("Strong.", result)
        end)

        it("should fall through to else when all conditions false", function()
            local result = render_with_vars(
                "{ $health > 75 }Strong.{elif $health > 50}Decent.{elif $health > 25}Weak.{else}Critical.{/}",
                {health = 10}
            )
            assert.equals("Critical.", result)
        end)

        it("should work without else clause", function()
            local result = render_with_vars(
                "{ $level == 1 }Beginner.{elif $level == 2}Intermediate.{elif $level == 3}Expert.{/}",
                {level = 2}
            )
            assert.equals("Intermediate.", result)
        end)

        it("should return empty when no conditions match and no else", function()
            local result = render_with_vars(
                "{ $level == 1 }Beginner.{elif $level == 2}Intermediate.{/}",
                {level = 5}
            )
            assert.equals("", result)
        end)
    end)

    -- ============================================
    -- Nested Conditionals
    -- ============================================

    describe("Nested Conditionals", function()

        it("should handle simple nesting", function()
            local result = render_with_vars(
                "{ $outer }Outer.{ $inner }Inner.{/}{/}",
                {outer = true, inner = true}
            )
            assert.equals("Outer.Inner.", result)
        end)

        it("should handle nesting with else", function()
            local result = render_with_vars(
                "{ $a }A.{ $b }B.{else}Not B.{/}{else}Not A.{/}",
                {a = true, b = false}
            )
            assert.equals("A.Not B.", result)
        end)

        it("should handle deeply nested conditionals", function()
            local result = render_with_vars(
                "{ $a }{ $b }{ $c }ABC{/}{/}{/}",
                {a = true, b = true, c = true}
            )
            assert.equals("ABC", result)
        end)
    end)

    -- ============================================
    -- Inline Conditionals: {cond: true | false}
    -- ============================================

    describe("Inline Conditionals", function()

        it("should show true text when condition is true", function()
            local result = render_with_vars(
                "Door is {$hasKey: unlocked | locked}.",
                {hasKey = true}
            )
            assert.equals("Door is unlocked.", result)
        end)

        it("should show false text when condition is false", function()
            local result = render_with_vars(
                "Door is {$hasKey: unlocked | locked}.",
                {hasKey = false}
            )
            assert.equals("Door is locked.", result)
        end)

        it("should handle comparisons", function()
            local result = render_with_vars(
                "You have {$gold >= 100: enough | insufficient} gold.",
                {gold = 50}
            )
            assert.equals("You have insufficient gold.", result)
        end)

        it("should handle multiple inline conditionals", function()
            local result = render_with_vars(
                "The {$isDay: sun | moon} is {$isBright: bright | dim}.",
                {isDay = true, isBright = false}
            )
            assert.equals("The sun is dim.", result)
        end)
    end)

    -- ============================================
    -- Text Alternatives: {| a | b | c }
    -- ============================================

    describe("Text Alternatives", function()

        describe("Sequence {| a | b | c }", function()

            it("should show first option on first render", function()
                local story = create_story_with_content("{| First | Second | Third }")
                local game_state = GameState.new()
                local engine = Engine.new(story, game_state)
                -- start_story() already calls render, so get_current_content has the first render
                engine:start_story()

                local content = engine:get_current_content()
                assert.equals("First", content.content)
            end)

            it("should show subsequent options on later renders", function()
                local story = create_story_with_content("{| First | Second | Third }")
                local game_state = GameState.new()
                local engine = Engine.new(story, game_state)
                engine:start_story()  -- First render

                -- Second render
                local result = engine:render_passage_content(story:get_passage("start"))
                assert.equals("Second", result)
            end)

            it("should stick at last option", function()
                local story = create_story_with_content("{| A | B }")
                local game_state = GameState.new()
                local engine = Engine.new(story, game_state)
                engine:start_story()  -- First: A

                engine:render_passage_content(story:get_passage("start"))  -- Second: B
                local result = engine:render_passage_content(story:get_passage("start"))  -- Third: Still B
                assert.equals("B", result)
            end)
        end)

        describe("Cycle {&| a | b | c }", function()

            it("should cycle through options", function()
                local story = create_story_with_content("{&| A | B }")
                local game_state = GameState.new()
                local engine = Engine.new(story, game_state)
                local content = engine:start_story()  -- First: A

                local r2 = engine:render_passage_content(story:get_passage("start"))  -- Second: B
                local r3 = engine:render_passage_content(story:get_passage("start"))  -- Third: A (cycles)

                assert.equals("A", content.content)
                assert.equals("B", r2)
                assert.equals("A", r3)  -- Cycles back
            end)
        end)

        describe("Shuffle {~| a | b | c }", function()

            it("should return one of the options", function()
                local result = render_with_vars("{~| red | green | blue }", {})
                assert.is_true(result == "red" or result == "green" or result == "blue")
            end)
        end)

        describe("Once-only {!| a | b | c }", function()

            it("should show each option once then empty", function()
                local story = create_story_with_content("{!| One | Two }")
                local game_state = GameState.new()
                local engine = Engine.new(story, game_state)
                local content = engine:start_story()  -- First: One

                local r2 = engine:render_passage_content(story:get_passage("start"))  -- Second: Two
                local r3 = engine:render_passage_content(story:get_passage("start"))  -- Third: empty

                assert.equals("One", content.content)
                assert.equals("Two", r2)
                assert.equals("", r3)  -- Empty after exhausted
            end)
        end)
    end)

    -- ============================================
    -- Edge Cases
    -- ============================================

    describe("Edge Cases", function()

        it("should handle empty blocks", function()
            local result = render_with_vars("Before{ $x }{/}After", {x = true})
            assert.equals("BeforeAfter", result)
        end)

        it("should preserve content whitespace", function()
            local result = render_with_vars("{ $x }content{/}", {x = true})
            assert.equals("content", result)
        end)

        it("should not process ${} as block conditional", function()
            local result = render_with_vars("Value: ${5 + 3}", {})
            assert.equals("Value: 8", result)
        end)

        it("should handle escaped braces in content", function()
            local result = render_with_vars("{ $x }Content with \\{braces\\}{/}", {x = true})
            assert.equals("Content with {braces}", result)
        end)
    end)

end)
