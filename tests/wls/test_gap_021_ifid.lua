-- tests/wls/test_gap_021_ifid.lua
-- GAP-021: IFID (Interactive Fiction ID) Generation Tests
-- Tests UUID generation, validation, and IFID handling

describe("GAP-021: IFID Generation", function()
    local UUID = require("whisker.utils.uuid")
    local WSParser = require("whisker.parser.ws_parser")
    local JsonParser = require("whisker.format.parsers.json")
    local json = require("whisker.utils.json")

    describe("UUID.v4()", function()
        it("should generate a valid UUID", function()
            local uuid = UUID.v4()

            assert.is_string(uuid)
            assert.equals(36, #uuid)  -- Standard UUID length
        end)

        it("should generate uppercase UUID", function()
            local uuid = UUID.v4()

            -- Should be all uppercase (or digits/hyphens)
            assert.equals(uuid, uuid:upper())
        end)

        it("should generate unique UUIDs", function()
            local uuids = {}
            for i = 1, 100 do
                uuids[i] = UUID.v4()
            end

            -- Check uniqueness
            local seen = {}
            for _, uuid in ipairs(uuids) do
                assert.is_nil(seen[uuid], "Duplicate UUID generated")
                seen[uuid] = true
            end
        end)

        it("should generate valid v4 UUIDs", function()
            for _ = 1, 10 do
                local uuid = UUID.v4()
                assert.is_true(UUID.is_valid_v4(uuid))
            end
        end)

        it("should have correct format", function()
            local uuid = UUID.v4()

            -- Format: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
            local parts = {}
            for part in uuid:gmatch("([^-]+)") do
                table.insert(parts, part)
            end

            assert.equals(5, #parts)
            assert.equals(8, #parts[1])
            assert.equals(4, #parts[2])
            assert.equals(4, #parts[3])
            assert.equals(4, #parts[4])
            assert.equals(12, #parts[5])
        end)
    end)

    describe("UUID.is_valid()", function()
        it("should accept valid UUIDs", function()
            assert.is_true(UUID.is_valid("550E8400-E29B-41D4-A716-446655440000"))
            assert.is_true(UUID.is_valid("550e8400-e29b-41d4-a716-446655440000"))
            assert.is_true(UUID.is_valid("00000000-0000-0000-0000-000000000000"))
        end)

        it("should reject invalid UUIDs", function()
            assert.is_false(UUID.is_valid(nil))
            assert.is_false(UUID.is_valid(""))
            assert.is_false(UUID.is_valid("not-a-uuid"))
            assert.is_false(UUID.is_valid("550E8400-E29B-41D4-A716"))  -- Too short
            assert.is_false(UUID.is_valid("550E8400E29B41D4A716446655440000"))  -- No hyphens
            assert.is_false(UUID.is_valid("GGGGGGGG-GGGG-GGGG-GGGG-GGGGGGGGGGGG"))  -- Invalid hex
        end)

        it("should handle case insensitively", function()
            assert.is_true(UUID.is_valid("550E8400-E29B-41D4-A716-446655440000"))
            assert.is_true(UUID.is_valid("550e8400-e29b-41d4-a716-446655440000"))
            assert.is_true(UUID.is_valid("550E8400-e29b-41D4-a716-446655440000"))
        end)
    end)

    describe("UUID.is_valid_v4()", function()
        it("should accept valid v4 UUIDs", function()
            -- v4 UUID has version 4 at position 15 and variant 8/9/A/B at position 20
            assert.is_true(UUID.is_valid_v4("550E8400-E29B-41D4-A716-446655440000"))
            assert.is_true(UUID.is_valid_v4("550E8400-E29B-41D4-8716-446655440000"))
            assert.is_true(UUID.is_valid_v4("550E8400-E29B-41D4-9716-446655440000"))
            assert.is_true(UUID.is_valid_v4("550E8400-E29B-41D4-B716-446655440000"))
        end)

        it("should reject non-v4 UUIDs", function()
            -- Version 1 UUID
            assert.is_false(UUID.is_valid_v4("550E8400-E29B-11D4-A716-446655440000"))
            -- Version 5 UUID
            assert.is_false(UUID.is_valid_v4("550E8400-E29B-51D4-A716-446655440000"))
            -- Invalid variant
            assert.is_false(UUID.is_valid_v4("550E8400-E29B-41D4-0716-446655440000"))
            assert.is_false(UUID.is_valid_v4("550E8400-E29B-41D4-7716-446655440000"))
        end)
    end)

    describe("UUID.normalize()", function()
        it("should convert to uppercase", function()
            local normalized = UUID.normalize("550e8400-e29b-41d4-a716-446655440000")
            assert.equals("550E8400-E29B-41D4-A716-446655440000", normalized)
        end)

        it("should handle already uppercase", function()
            local normalized = UUID.normalize("550E8400-E29B-41D4-A716-446655440000")
            assert.equals("550E8400-E29B-41D4-A716-446655440000", normalized)
        end)

        it("should return nil for nil input", function()
            assert.is_nil(UUID.normalize(nil))
        end)
    end)

    describe("UUID.parse()", function()
        it("should parse UUID into components", function()
            local parts = UUID.parse("550E8400-E29B-41D4-A716-446655440000")

            assert.is_not_nil(parts)
            assert.equals("550E8400", parts.time_low)
            assert.equals("E29B", parts.time_mid)
            assert.equals("41D4", parts.time_hi_version)
            assert.equals("A716", parts.clock_seq)
            assert.equals("446655440000", parts.node)
        end)

        it("should return nil for invalid UUID", function()
            assert.is_nil(UUID.parse("not-a-uuid"))
            assert.is_nil(UUID.parse(nil))
        end)
    end)

    describe("UUID.nil_uuid()", function()
        it("should return the nil UUID", function()
            local nil_uuid = UUID.nil_uuid()
            assert.equals("00000000-0000-0000-0000-000000000000", nil_uuid)
        end)
    end)

    describe("UUID.is_nil()", function()
        it("should detect nil UUID", function()
            assert.is_true(UUID.is_nil("00000000-0000-0000-0000-000000000000"))
            assert.is_true(UUID.is_nil(UUID.nil_uuid()))
        end)

        it("should return false for non-nil UUID", function()
            assert.is_false(UUID.is_nil("550E8400-E29B-41D4-A716-446655440000"))
            assert.is_false(UUID.is_nil(UUID.v4()))
        end)

        it("should handle nil input", function()
            assert.is_false(UUID.is_nil(nil))
        end)
    end)

    describe("WS Parser @ifid handling", function()
        local parser

        before_each(function()
            parser = WSParser.new()
        end)

        it("should parse valid IFID", function()
            local input = [[
@title: Test Story
@ifid: 550E8400-E29B-41D4-A716-446655440000

:: Start
Hello world
]]
            local result = parser:parse(input)

            assert.is_true(result.success)
            assert.equals("550E8400-E29B-41D4-A716-446655440000", result.story.metadata.ifid)
            assert.is_nil(result.story.metadata.ifid_invalid)
        end)

        it("should normalize lowercase IFID to uppercase", function()
            local input = [[
@title: Test Story
@ifid: 550e8400-e29b-41d4-a716-446655440000

:: Start
Hello world
]]
            local result = parser:parse(input)

            assert.is_true(result.success)
            assert.equals("550E8400-E29B-41D4-A716-446655440000", result.story.metadata.ifid)
        end)

        it("should warn for invalid IFID format", function()
            local input = [[
@title: Test Story
@ifid: not-a-valid-uuid

:: Start
Hello world
]]
            local result = parser:parse(input)

            assert.is_true(result.success)  -- Still parses successfully
            assert.is_true(#result.warnings > 0)

            local has_ifid_warning = false
            for _, warning in ipairs(result.warnings) do
                if warning.code == "WLS-META-001" then
                    has_ifid_warning = true
                    break
                end
            end
            assert.is_true(has_ifid_warning)

            -- Should mark as invalid
            assert.is_true(result.story.metadata.ifid_invalid)
        end)
    end)

    describe("JSON Parser IFID handling", function()
        it("should preserve existing IFID on export", function()
            local story = {
                name = "Test Story",
                ifid = "550E8400-E29B-41D4-A716-446655440000",
                passages = {
                    { name = "Start", content = "Hello" }
                }
            }

            local exported = JsonParser.to_json(story, { pretty = true })
            local decoded = json.decode(exported)

            assert.equals("550E8400-E29B-41D4-A716-446655440000", decoded.ifid)
        end)

        it("should generate IFID when missing", function()
            local story = {
                name = "Test Story",
                passages = {
                    { name = "Start", content = "Hello" }
                }
            }

            local exported = JsonParser.to_json(story, { pretty = true })
            local decoded = json.decode(exported)

            assert.is_not_nil(decoded.ifid)
            assert.is_true(UUID.is_valid(decoded.ifid))
        end)

        it("should not generate IFID when generate_ifid is false", function()
            local story = {
                name = "Test Story",
                passages = {
                    { name = "Start", content = "Hello" }
                }
            }

            local exported = JsonParser.to_json(story, { generate_ifid = false })
            local decoded = json.decode(exported)

            assert.is_nil(decoded.ifid)
        end)

        it("should store generated IFID back in story object", function()
            local story = {
                name = "Test Story",
                passages = {
                    { name = "Start", content = "Hello" }
                }
            }

            assert.is_nil(story.ifid)

            JsonParser.to_json(story)

            -- IFID should now be set on the original story object
            assert.is_not_nil(story.ifid)
            assert.is_true(UUID.is_valid(story.ifid))
        end)
    end)

    describe("Integration: Round-trip IFID preservation", function()
        it("should preserve IFID through parse/export cycle", function()
            local original_ifid = "550E8400-E29B-41D4-A716-446655440000"

            local story_json = json.encode({
                name = "Test Story",
                ifid = original_ifid,
                passages = {
                    { name = "Start", content = "Hello" }
                }
            })

            -- Parse
            local parsed = JsonParser.parse(story_json)
            assert.equals(original_ifid, parsed.ifid)

            -- Export
            local exported = JsonParser.to_json(parsed, { pretty = true })
            local decoded = json.decode(exported)

            assert.equals(original_ifid, decoded.ifid)
        end)
    end)
end)
