-- tests/wls/test_gap_020_settings.lua
-- GAP-020: JSON Settings Section Tests
-- Tests settings parsing, validation, and export

describe("GAP-020: JSON Settings Section", function()
    local StorySchema = require("whisker.format.schemas.story_schema")
    local JsonParser = require("whisker.format.parsers.json")
    local WSParser = require("whisker.parser.ws_parser")
    local json = require("whisker.utils.json")

    describe("StorySchema.DEFAULT_SETTINGS", function()
        it("should have all expected default settings", function()
            local defaults = StorySchema.DEFAULT_SETTINGS

            assert.equals(100, defaults.tunnel_limit)
            assert.equals("implicit_end", defaults.choice_fallback)
            assert.is_nil(defaults.random_seed)
            assert.equals(false, defaults.strict_mode)
            assert.equals(false, defaults.strict_hooks)
            assert.equals(false, defaults.debug)
            assert.equals("The End", defaults.end_text)
            assert.equals("Continue", defaults.continue_text)
            assert.equals(50, defaults.max_include_depth)
        end)
    end)

    describe("StorySchema.validate_settings()", function()
        local schema

        before_each(function()
            schema = StorySchema.new()
        end)

        it("should accept nil settings", function()
            local valid, errors = schema:validate_settings(nil)
            assert.is_true(valid)
            assert.equals(0, #errors)
        end)

        it("should accept empty settings", function()
            local valid, errors = schema:validate_settings({})
            assert.is_true(valid)
            assert.equals(0, #errors)
        end)

        it("should accept valid settings", function()
            local valid, errors = schema:validate_settings({
                tunnel_limit = 50,
                choice_fallback = "continue",
                random_seed = 12345,
                strict_mode = true,
                debug = true
            })
            assert.is_true(valid)
            assert.equals(0, #errors)
        end)

        it("should reject non-table settings", function()
            local valid, errors = schema:validate_settings("invalid")
            assert.is_false(valid)
            assert.equals(1, #errors)
        end)

        it("should reject invalid tunnel_limit type", function()
            local valid, errors = schema:validate_settings({
                tunnel_limit = "not a number"
            })
            assert.is_false(valid)
            assert.is_true(#errors > 0)
        end)

        it("should reject tunnel_limit less than 1", function()
            local valid, errors = schema:validate_settings({
                tunnel_limit = 0
            })
            assert.is_false(valid)
            assert.is_true(#errors > 0)
        end)

        it("should reject invalid choice_fallback", function()
            local valid, errors = schema:validate_settings({
                choice_fallback = "invalid_value"
            })
            assert.is_false(valid)
            assert.is_true(#errors > 0)
        end)

        it("should accept all valid choice_fallback values", function()
            for behavior, _ in pairs(StorySchema.VALID_FALLBACK_BEHAVIORS) do
                local valid, errors = schema:validate_settings({
                    choice_fallback = behavior
                })
                assert.is_true(valid, "Should accept " .. behavior)
            end
        end)

        it("should accept numeric random_seed", function()
            local valid, errors = schema:validate_settings({
                random_seed = 42
            })
            assert.is_true(valid)
        end)

        it("should accept string random_seed", function()
            local valid, errors = schema:validate_settings({
                random_seed = "my-seed-string"
            })
            assert.is_true(valid)
        end)

        it("should reject non-number/string random_seed", function()
            local valid, errors = schema:validate_settings({
                random_seed = {}
            })
            assert.is_false(valid)
        end)

        it("should validate boolean settings", function()
            local valid, errors = schema:validate_settings({
                strict_mode = "not a boolean"
            })
            assert.is_false(valid)
        end)

        it("should validate string settings", function()
            local valid, errors = schema:validate_settings({
                end_text = 123  -- Should be string
            })
            assert.is_false(valid)
        end)
    end)

    describe("StorySchema.apply_default_settings()", function()
        local schema

        before_each(function()
            schema = StorySchema.new()
        end)

        it("should apply all defaults when settings is nil", function()
            local result = schema:apply_default_settings(nil)

            assert.equals(100, result.tunnel_limit)
            assert.equals("implicit_end", result.choice_fallback)
            assert.equals(false, result.strict_mode)
        end)

        it("should preserve provided settings", function()
            local result = schema:apply_default_settings({
                tunnel_limit = 50,
                debug = true
            })

            assert.equals(50, result.tunnel_limit)
            assert.equals(true, result.debug)
            -- Defaults still applied for non-provided
            assert.equals("implicit_end", result.choice_fallback)
        end)
    end)

    describe("StorySchema.serialize_settings()", function()
        local schema

        before_each(function()
            schema = StorySchema.new()
        end)

        it("should return nil when all settings are defaults", function()
            local defaults = schema:apply_default_settings(nil)
            local result = schema:serialize_settings(defaults)

            assert.is_nil(result)
        end)

        it("should only include non-default values", function()
            local settings = schema:apply_default_settings({
                tunnel_limit = 50,  -- Non-default
                choice_fallback = "implicit_end",  -- Default
                debug = true  -- Non-default
            })

            local result = schema:serialize_settings(settings)

            assert.is_not_nil(result)
            assert.equals(50, result.tunnel_limit)
            assert.equals(true, result.debug)
            assert.is_nil(result.choice_fallback)  -- Default, omitted
        end)
    end)

    describe("JSON Parser settings handling", function()
        it("should parse story with settings section", function()
            local story_json = json.encode({
                name = "Test Story",
                settings = {
                    tunnel_limit = 50,
                    choice_fallback = "continue",
                    debug = true
                },
                passages = {
                    { name = "Start", content = "Hello" }
                }
            })

            local parsed = JsonParser.parse(story_json)

            assert.is_not_nil(parsed)
            assert.is_not_nil(parsed.settings)
            assert.equals(50, parsed.settings.tunnel_limit)
            assert.equals("continue", parsed.settings.choice_fallback)
            assert.equals(true, parsed.settings.debug)
        end)

        it("should apply default settings when not provided", function()
            local story_json = json.encode({
                name = "Test Story",
                passages = {
                    { name = "Start", content = "Hello" }
                }
            })

            local parsed = JsonParser.parse(story_json)

            assert.is_not_nil(parsed)
            assert.is_not_nil(parsed.settings)
            assert.equals(100, parsed.settings.tunnel_limit)
            assert.equals("implicit_end", parsed.settings.choice_fallback)
        end)
    end)

    describe("JSON Export settings handling", function()
        it("should include non-default settings in export", function()
            local story = {
                name = "Test Story",
                settings = {
                    tunnel_limit = 50,
                    choice_fallback = "continue",
                    debug = true,
                    strict_mode = false  -- Default value
                },
                passages = {
                    { name = "Start", content = "Hello" }
                }
            }

            local exported = JsonParser.to_json(story, { pretty = true })
            local decoded = json.decode(exported)

            assert.is_not_nil(decoded.settings)
            assert.equals(50, decoded.settings.tunnel_limit)
            assert.equals("continue", decoded.settings.choice_fallback)
            assert.equals(true, decoded.settings.debug)
            -- Default values should be omitted
            assert.is_nil(decoded.settings.strict_mode)
        end)

        it("should omit settings section when all defaults", function()
            local story = {
                name = "Test Story",
                settings = StorySchema.DEFAULT_SETTINGS,
                passages = {
                    { name = "Start", content = "Hello" }
                }
            }

            local exported = JsonParser.to_json(story, { pretty = true })
            local decoded = json.decode(exported)

            -- Settings should be nil or empty when all defaults
            if decoded.settings then
                local count = 0
                for _ in pairs(decoded.settings) do count = count + 1 end
                assert.equals(0, count)
            end
        end)
    end)

    describe("WS Parser @set directive", function()
        local parser

        before_each(function()
            parser = WSParser.new()
        end)

        it("should parse @set directive with boolean value", function()
            local input = [[
@title: Test Story
@set strict_mode = true

:: Start
Hello world
]]
            local result = parser:parse(input)

            assert.is_true(result.success)
            assert.is_not_nil(result.story.settings)
            assert.equals(true, result.story.settings.strict_mode)
        end)

        it("should parse @set directive with numeric value", function()
            local input = [[
@title: Test Story
@set tunnel_limit = 50

:: Start
Hello world
]]
            local result = parser:parse(input)

            assert.is_true(result.success)
            assert.equals(50, result.story.settings.tunnel_limit)
        end)

        it("should parse @set directive with string value", function()
            local input = [[
@title: Test Story
@set end_text = "Game Over"

:: Start
Hello world
]]
            local result = parser:parse(input)

            assert.is_true(result.success)
            assert.equals("Game Over", result.story.settings.end_text)
        end)

        it("should parse multiple @set directives", function()
            local input = [[
@title: Test Story
@set strict_mode = true
@set tunnel_limit = 75
@set debug = false

:: Start
Hello world
]]
            local result = parser:parse(input)

            assert.is_true(result.success)
            assert.equals(true, result.story.settings.strict_mode)
            assert.equals(75, result.story.settings.tunnel_limit)
            assert.equals(false, result.story.settings.debug)
        end)
    end)
end)
