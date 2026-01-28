-- tests/wls/test_gap_016_fallback.lua
-- GAP-016: Choice Fallback Behavior Tests
-- Tests fallback behavior when all choices are consumed

describe("GAP-016: Choice Fallback Behavior", function()
    local Choice = require("whisker.core.choice")
    local GameState = require("whisker.core.game_state")
    local WSParser = require("whisker.parser.ws_parser")
    local StorySchema = require("whisker.format.schemas.story_schema")

    describe("Choice.is_available()", function()
        local game_state

        before_each(function()
            game_state = GameState.new()
        end)

        it("should return true for sticky choices even when previously selected", function()
            local choice = Choice.new({
                id = "ch_1",
                text = "Sticky Choice",
                target = "Target",
                choice_type = Choice.TYPE_STICKY
            })

            -- Mark as selected
            game_state:mark_choice_selected("TestPassage_ch_1")

            -- Sticky choices should always be available
            assert.is_true(choice:is_available(game_state, "TestPassage"))
        end)

        it("should return false for once-only choices when already selected", function()
            local choice = Choice.new({
                id = "ch_1",
                text = "Once Only Choice",
                target = "Target",
                choice_type = Choice.TYPE_ONCE
            })

            -- Mark as selected
            game_state:mark_choice_selected("TestPassage_ch_1")

            -- Once-only choices should not be available after selection
            assert.is_false(choice:is_available(game_state, "TestPassage"))
        end)

        it("should return true for once-only choices not yet selected", function()
            local choice = Choice.new({
                id = "ch_1",
                text = "Once Only Choice",
                target = "Target",
                choice_type = Choice.TYPE_ONCE
            })

            -- Not marked as selected
            assert.is_true(choice:is_available(game_state, "TestPassage"))
        end)
    end)

    describe("Choice.evaluate_condition()", function()
        local game_state

        before_each(function()
            game_state = GameState.new()
        end)

        it("should return true when no condition is set", function()
            local choice = Choice.new({
                text = "No Condition",
                target = "Target"
            })

            assert.is_true(choice:evaluate_condition(game_state))
        end)

        it("should return true when condition evaluates to true", function()
            local choice = Choice.new({
                text = "Conditional",
                target = "Target",
                condition = "gold >= 10"
            })

            game_state:set("gold", 20)
            assert.is_true(choice:evaluate_condition(game_state))
        end)

        it("should return false when condition evaluates to false", function()
            local choice = Choice.new({
                text = "Conditional",
                target = "Target",
                condition = "gold >= 10"
            })

            game_state:set("gold", 5)
            assert.is_false(choice:evaluate_condition(game_state))
        end)

        it("should support visited() helper in conditions", function()
            local choice = Choice.new({
                text = "Conditional",
                target = "Target",
                condition = "visited('PreviousPassage')"
            })

            -- Not visited yet
            assert.is_false(choice:evaluate_condition(game_state))

            -- Mark as visited
            game_state:set_current_passage("PreviousPassage")
            assert.is_true(choice:evaluate_condition(game_state))
        end)
    end)

    describe("Choice.mark_selected()", function()
        local game_state

        before_each(function()
            game_state = GameState.new()
        end)

        it("should mark once-only choices as selected", function()
            local choice = Choice.new({
                id = "ch_1",
                text = "Once Only",
                target = "Target",
                choice_type = Choice.TYPE_ONCE
            })

            choice:mark_selected(game_state, "TestPassage")

            assert.is_true(game_state:is_choice_selected("TestPassage_ch_1"))
        end)

        it("should not mark sticky choices as selected", function()
            local choice = Choice.new({
                id = "ch_1",
                text = "Sticky",
                target = "Target",
                choice_type = Choice.TYPE_STICKY
            })

            choice:mark_selected(game_state, "TestPassage")

            -- Sticky choices don't get marked
            assert.is_false(game_state:is_choice_selected("TestPassage_ch_1"))
        end)
    end)

    describe("Parser @fallback directive", function()
        local parser

        before_each(function()
            parser = WSParser.new()
        end)

        it("should parse story-level @fallback directive", function()
            local input = [[
@title: Test Story
@fallback: implicit_end

:: Start
Hello world
]]
            local result = parser:parse(input)

            assert.is_true(result.success)
            assert.equals("implicit_end", result.story.default_fallback)
        end)

        it("should parse passage-level @fallback directive", function()
            local input = [[
@title: Test Story

:: Start
@fallback: continue
Hello world
]]
            local result = parser:parse(input)

            assert.is_true(result.success)
            local passage = result.story.passages["Start"]
            assert.is_not_nil(passage)
            assert.equals("continue", passage.fallback)
        end)

        it("should support all fallback behaviors", function()
            local behaviors = {"implicit_end", "continue", "error", "none"}

            for _, behavior in ipairs(behaviors) do
                local input = string.format([[
@title: Test
@fallback: %s

:: Start
Hello
]], behavior)
                local result = parser:parse(input)
                assert.is_true(result.success)
                assert.equals(behavior, result.story.default_fallback)
            end
        end)
    end)

    describe("StorySchema Settings Validation", function()
        local schema

        before_each(function()
            schema = StorySchema.new()
        end)

        it("should validate valid choice_fallback setting", function()
            local settings = { choice_fallback = "implicit_end" }
            local valid, errors = schema:validate_settings(settings)

            assert.is_true(valid)
            assert.equals(0, #errors)
        end)

        it("should reject invalid choice_fallback setting", function()
            local settings = { choice_fallback = "invalid_behavior" }
            local valid, errors = schema:validate_settings(settings)

            assert.is_false(valid)
            assert.is_true(#errors > 0)
        end)

        it("should apply default choice_fallback", function()
            local settings = schema:apply_default_settings({})

            assert.equals("implicit_end", settings.choice_fallback)
        end)
    end)
end)
