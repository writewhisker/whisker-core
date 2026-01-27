-- tests/wls/test_presentation_features.lua
-- WLS 1.0 Presentation Features Tests
-- Tests for GAP-030 through GAP-036:
--   GAP-030: Named Alternatives
--   GAP-031: Gather Points
--   GAP-032: Choice Expression Interpolation
--   GAP-033: Escaped Brackets in Choices
--   GAP-034: Text Alternatives in Choices
--   GAP-035: Block CSS Classes
--   GAP-036: Inline CSS Classes

local Story = require("whisker.core.story")
local Passage = require("whisker.core.passage")
local Engine = require("whisker.core.engine")
local GameState = require("whisker.core.game_state")
local Renderer = require("whisker.core.renderer")
local ControlFlow = require("whisker.core.control_flow")
local WSParser = require("whisker.parser.ws_parser")

describe("WLS 1.0 Presentation Features", function()

    -- Helper to create a test story with custom content
    local function create_story_with_content(content)
        local story = Story.new()
        story:set_metadata("name", "Presentation Test")

        local start = Passage.new("start", "start")
        start:set_content(content)

        story:add_passage(start)
        story:set_start_passage("start")

        return story
    end

    -- Helper to create a renderer for testing
    local function create_test_renderer(platform)
        return Renderer.new(nil, platform or "web")
    end

    -- ============================================
    -- GAP-030: Named Alternatives
    -- ============================================

    describe("GAP-030: Named Alternatives", function()
        local game_state
        local control_flow

        before_each(function()
            game_state = GameState.new()
            control_flow = ControlFlow.new(nil, game_state, { passage_id = "test" })
        end)

        describe("Basic Named Alternatives", function()

            it("should parse @name: prefix correctly", function()
                local content = "{@counter:| first | second | third }"
                local result = control_flow:process_alternatives(content)
                assert.equals("first", result)
            end)

            it("should use name as state key for named alternatives", function()
                local content = "{@myname:| a | b | c }"
                -- First call
                local result1 = control_flow:process_alternatives(content)
                assert.equals("a", result1)

                -- Second call - should use saved state
                local result2 = control_flow:process_alternatives(content)
                assert.equals("b", result2)
            end)

            it("should share state between alternatives with same name", function()
                -- First alternative named "shared"
                local result1 = control_flow:process_alternatives("{@shared:| one | two | three }")
                assert.equals("one", result1)

                -- Second alternative with same name should share state
                local result2 = control_flow:process_alternatives("{@shared:| one | two | three }")
                assert.equals("two", result2)
            end)

            it("should not interfere with unnamed alternatives", function()
                local content = "{@named:| A | B } and {| X | Y }"

                -- First render
                local result1 = control_flow:process_alternatives(content)
                assert.matches("A", result1)
                assert.matches("X", result1)

                -- Second render - both should advance independently
                local result2 = control_flow:process_alternatives(content)
                assert.matches("B", result2)
                assert.matches("Y", result2)
            end)
        end)

        describe("Named Alternatives with Prefixes", function()

            it("should work with cycle prefix (&)", function()
                local content = "{@mycycle&:| one | two }"
                local result1 = control_flow:process_alternatives(content)
                local result2 = control_flow:process_alternatives(content)
                local result3 = control_flow:process_alternatives(content)

                assert.equals("one", result1)
                assert.equals("two", result2)
                assert.equals("one", result3)  -- Cycles back
            end)

            it("should work with shuffle prefix (~)", function()
                local content = "{@myshuffle~:| red | green | blue }"
                local result = control_flow:process_alternatives(content)
                assert.is_true(result == "red" or result == "green" or result == "blue")
            end)

            it("should work with once-only prefix (!)", function()
                local content = "{@myonce!:| first | second }"
                local result1 = control_flow:process_alternatives(content)
                local result2 = control_flow:process_alternatives(content)
                local result3 = control_flow:process_alternatives(content)

                assert.equals("first", result1)
                assert.equals("second", result2)
                assert.equals("", result3)  -- Exhausted
            end)
        end)

        describe("Named Alternatives State Persistence", function()

            it("should persist state in game_state", function()
                control_flow:process_alternatives("{@persist:| a | b | c }")

                -- Check that named alternatives state was saved
                local named_state = game_state:get("_named_alternatives")
                assert.is_not_nil(named_state)
                assert.is_not_nil(named_state["persist"])
            end)
        end)
    end)

    -- ============================================
    -- GAP-031: Gather Points
    -- ============================================

    describe("GAP-031: Gather Points", function()

        describe("Parser Recognition", function()

            it("should parse single-depth gather points", function()
                local parser = WSParser.new()
                local result = parser:parse([[
:: TestPassage
+ [Choice 1] -> Target1
+ [Choice 2] -> Target2
- This is a gather point
]])
                local passage = result.story.passages["TestPassage"]
                assert.is_not_nil(passage)
                assert.is_not_nil(passage.gathers)
                assert.equals(1, #passage.gathers)
                assert.equals(1, passage.gathers[1].depth)
                assert.equals("This is a gather point", passage.gathers[1].content)
            end)

            it("should parse multi-depth gather points", function()
                local parser = WSParser.new()
                local result = parser:parse([[
:: TestPassage
+ [Outer Choice]
++ [Inner Choice]
- - This gathers at depth 2
- This gathers at depth 1
]])
                local passage = result.story.passages["TestPassage"]
                assert.is_not_nil(passage.gathers)
                assert.equals(2, #passage.gathers)
                assert.equals(2, passage.gathers[1].depth)
                assert.equals(1, passage.gathers[2].depth)
            end)
        end)

        describe("Engine Execution", function()

            it("should have execute_gather_after_choice method", function()
                local story = create_story_with_content("Test content")
                local engine = Engine.new(story, { platform = "plain" })
                assert.is_function(engine.execute_gather_after_choice)
            end)

            it("should return empty string when no gathers exist", function()
                local story = create_story_with_content("Test content")
                local engine = Engine.new(story, { platform = "plain" })
                local passage = { gathers = {} }
                local result = engine:execute_gather_after_choice(passage, 1)
                assert.equals("", result)
            end)
        end)
    end)

    -- ============================================
    -- GAP-032: Choice Expression Interpolation
    -- ============================================

    describe("GAP-032: Choice Expression Interpolation", function()
        local renderer
        local game_state

        before_each(function()
            renderer = create_test_renderer("web")
            game_state = { gold = 100, player_name = "Hero" }
        end)

        describe("Simple Variable Interpolation", function()

            it("should interpolate $variable in text", function()
                local result = renderer:evaluate_expressions("You have $gold coins", game_state)
                assert.equals("You have 100 coins", result)
            end)

            it("should handle undefined variables", function()
                local result = renderer:evaluate_expressions("Value: $undefined", game_state)
                assert.equals("Value: $undefined", result)
            end)
        end)

        describe("Complex Expression Interpolation", function()

            it("should interpolate ${expression} syntax", function()
                local result = renderer:evaluate_expressions("Total: ${10 + 5}", game_state)
                assert.equals("Total: 15", result)
            end)

            it("should handle math functions in expressions", function()
                local result = renderer:evaluate_expressions("Floor: ${math.floor(3.7)}", {})
                assert.equals("Floor: 3", result)
            end)

            it("should handle variable expressions", function()
                local result = renderer:evaluate_expressions("Double: ${gold * 2}", game_state)
                assert.equals("Double: 200", result)
            end)

            it("should gracefully degrade on error", function()
                local result = renderer:evaluate_expressions("Error: ${invalid_syntax(}", {})
                -- GAP-015: Graceful degradation returns empty string on error
                assert.equals("Error: ", result)
            end)
        end)

        describe("Choice Text Processing", function()

            it("should process choice text with expressions", function()
                local choice_text = "Buy sword ($gold coins)"
                local result = renderer:process_choice_text(choice_text, game_state)
                assert.equals("Buy sword (100 coins)", result)
            end)

            it("should process complex expressions in choice text", function()
                local choice_text = "${player_name} attacks"
                local result = renderer:process_choice_text(choice_text, game_state)
                assert.equals("Hero attacks", result)
            end)
        end)
    end)

    -- ============================================
    -- GAP-033: Escaped Brackets in Choices
    -- ============================================

    describe("GAP-033: Escaped Brackets in Choices", function()

        describe("Parser Handling", function()

            it("should parse choice with escaped brackets", function()
                local parser = WSParser.new()
                local text = " [Open the \\[secret\\] door]"
                local choice_text, remaining = parser:parse_choice_text_with_escapes(text)

                assert.is_not_nil(choice_text)
                assert.equals("Open the \\[secret\\] door", choice_text)
            end)

            it("should parse choice with multiple escaped brackets", function()
                local parser = WSParser.new()
                local text = " [Press \\[ENTER\\] to \\[continue\\]]"
                local choice_text, remaining = parser:parse_choice_text_with_escapes(text)

                assert.equals("Press \\[ENTER\\] to \\[continue\\]", choice_text)
            end)

            it("should handle mixed escaped and unescaped brackets", function()
                local parser = WSParser.new()
                -- Regular brackets inside should increase depth
                local text = " [[[inner]] text]"
                local choice_text, remaining = parser:parse_choice_text_with_escapes(text)
                assert.is_not_nil(choice_text)
            end)
        end)

        describe("Renderer Unescaping", function()
            local renderer

            before_each(function()
                renderer = create_test_renderer("web")
            end)

            it("should unescape \\[ to [", function()
                local result = renderer:unescape_brackets("Open \\[secret\\] door")
                assert.equals("Open [secret] door", result)
            end)

            it("should unescape multiple brackets", function()
                local result = renderer:unescape_brackets("Press \\[ENTER\\] or \\[ESC\\]")
                assert.equals("Press [ENTER] or [ESC]", result)
            end)

            it("should handle nil input", function()
                local result = renderer:unescape_brackets(nil)
                assert.is_nil(result)
            end)
        end)

        describe("Full Pipeline", function()
            local renderer

            before_each(function()
                renderer = create_test_renderer("web")
            end)

            it("should process choice text with escaped brackets", function()
                local result = renderer:process_choice_text("Open \\[secret\\] door", {})
                assert.equals("Open [secret] door", result)
            end)
        end)
    end)

    -- ============================================
    -- GAP-034: Text Alternatives in Choices
    -- ============================================

    describe("GAP-034: Text Alternatives in Choices", function()
        local control_flow
        local game_state

        before_each(function()
            game_state = GameState.new()
            control_flow = ControlFlow.new(nil, game_state, { passage_id = "test" })
        end)

        describe("Reusable Processing Method", function()

            it("should have process_alternatives_in_text method", function()
                assert.is_function(control_flow.process_alternatives_in_text)
            end)

            it("should process alternatives with custom context", function()
                local context = "choice_1"
                local content = "{| Take | Grab | Pick up } the sword"

                local result1 = control_flow:process_alternatives_in_text(content, context)
                assert.matches("Take", result1)

                local result2 = control_flow:process_alternatives_in_text(content, context)
                assert.matches("Grab", result2)
            end)

            it("should use separate state for different contexts", function()
                local content = "{| A | B | C }"

                -- Process with context "choice_1"
                local r1 = control_flow:process_alternatives_in_text(content, "choice_1")
                assert.equals("A", r1)

                -- Process with different context "choice_2" - should start fresh
                local r2 = control_flow:process_alternatives_in_text(content, "choice_2")
                assert.equals("A", r2)

                -- Process "choice_1" again - should be at B
                local r3 = control_flow:process_alternatives_in_text(content, "choice_1")
                assert.equals("B", r3)
            end)

            it("should share named alternatives across contexts", function()
                -- Named alternative in context 1
                local r1 = control_flow:process_alternatives_in_text("{@shared:| one | two }", "ctx1")
                assert.equals("one", r1)

                -- Same named alternative in context 2 should share state
                local r2 = control_flow:process_alternatives_in_text("{@shared:| one | two }", "ctx2")
                assert.equals("two", r2)
            end)
        end)
    end)

    -- ============================================
    -- GAP-035: Block CSS Classes
    -- ============================================

    describe("GAP-035: Block CSS Classes", function()
        local renderer_web
        local renderer_plain

        before_each(function()
            renderer_web = create_test_renderer("web")
            renderer_plain = create_test_renderer("plain")
        end)

        describe("Web Platform", function()

            it("should render single class as div", function()
                local content = ".highlight::[Important text]"
                local result = renderer_web:apply_formatting(content)
                assert.equals('<div class="highlight">Important text</div>', result)
            end)

            it("should render multiple classes", function()
                local content = ".warning.important::[Alert message]"
                local result = renderer_web:apply_formatting(content)
                assert.equals('<div class="warning important">Alert message</div>', result)
            end)

            it("should process nested formatting inside block", function()
                local content = ".highlight::[**Bold** text]"
                local result = renderer_web:apply_formatting(content)
                assert.matches('<div class="highlight">', result)
                assert.matches("<strong>Bold</strong>", result)
            end)
        end)

        describe("Plain Platform", function()

            it("should strip block class syntax on plain platform", function()
                local content = ".highlight::[Important text]"
                local result = renderer_plain:apply_formatting(content)
                assert.equals("Important text", result)
            end)
        end)

        describe("Reserved Prefix Validation", function()

            it("should block whisker- prefix", function()
                local valid, err = renderer_web:validate_css_class("whisker-internal")
                assert.is_false(valid)
                assert.matches("Reserved", err)
            end)

            it("should block ws- prefix", function()
                local valid, err = renderer_web:validate_css_class("ws-reserved")
                assert.is_false(valid)
                assert.matches("Reserved", err)
            end)

            it("should allow normal class names", function()
                local valid, err = renderer_web:validate_css_class("my-class")
                assert.is_true(valid)
                assert.is_nil(err)
            end)
        end)
    end)

    -- ============================================
    -- GAP-036: Inline CSS Classes
    -- ============================================

    describe("GAP-036: Inline CSS Classes", function()
        local renderer_web
        local renderer_plain

        before_each(function()
            renderer_web = create_test_renderer("web")
            renderer_plain = create_test_renderer("plain")
        end)

        describe("Web Platform", function()

            it("should render single inline class as span", function()
                local content = "This is .highlight:[important text] in a sentence."
                local result = renderer_web:apply_formatting(content)
                assert.equals('This is <span class="highlight">important text</span> in a sentence.', result)
            end)

            it("should render multiple inline classes", function()
                local content = "You have .gold.bold:[100 coins] remaining."
                local result = renderer_web:apply_formatting(content)
                assert.equals('You have <span class="gold bold">100 coins</span> remaining.', result)
            end)

            it("should not conflict with block syntax", function()
                local block = ".block::[Block content]"
                local inline = "Text .inline:[inline] here"

                local block_result = renderer_web:apply_formatting(block)
                local inline_result = renderer_web:apply_formatting(inline)

                assert.matches("<div", block_result)
                assert.matches("<span", inline_result)
            end)
        end)

        describe("Plain Platform", function()

            it("should strip inline class syntax on plain platform", function()
                local content = "This is .highlight:[important text] in a sentence."
                local result = renderer_plain:apply_formatting(content)
                assert.equals("This is important text in a sentence.", result)
            end)
        end)

        describe("CSS Class Parsing", function()

            it("should parse single class", function()
                local classes, errors = renderer_web:parse_css_classes(".myclass")
                assert.equals(1, #classes)
                assert.equals("myclass", classes[1])
                assert.is_nil(errors)
            end)

            it("should parse multiple classes", function()
                local classes, errors = renderer_web:parse_css_classes(".class1.class2.class3")
                assert.equals(3, #classes)
                assert.equals("class1", classes[1])
                assert.equals("class2", classes[2])
                assert.equals("class3", classes[3])
            end)

            it("should skip reserved classes and report errors", function()
                local classes, errors = renderer_web:parse_css_classes(".valid.whisker-bad.another")
                assert.equals(2, #classes)  -- Only valid and another
                assert.is_not_nil(errors)
                assert.equals(1, #errors)
            end)
        end)
    end)

    -- ============================================
    -- Integration Tests
    -- ============================================

    describe("Integration", function()

        describe("Combined Features", function()

            it("should handle expression interpolation with CSS classes", function()
                local renderer = create_test_renderer("web")
                local game_state = { coins = 50 }

                local content = "You have .gold:[$coins] coins"
                local processed = renderer:evaluate_expressions(content, game_state)
                local formatted = renderer:apply_formatting(processed)

                assert.matches("50", formatted)
                assert.matches('<span class="gold">', formatted)
            end)

            it("should process choice text with all features", function()
                local renderer = create_test_renderer("web")
                local game_state = { gold = 100 }

                -- Choice with expression, CSS class, and escaped bracket
                local choice = "Buy .gold:[$gold] coins worth of \\[items\\]"
                local result = renderer:process_choice_text(choice, game_state)

                assert.matches("100", result)
                assert.matches('<span class="gold">', result)
                assert.matches("%[items%]", result)
            end)
        end)
    end)

end)
