-- tests/contracts/format_contract.lua
-- Contract test suite for IFormat implementations
-- Any format implementation can be validated against this contract
--
-- Usage:
--   require("tests.contracts.format_contract").register(
--     "MyFormat",
--     MyFormat.new(),
--     { fixture_name = "simple" }
--   )
--
-- Note: This module must be required from within a busted test file
-- where describe/it/before_each are available as globals.

local Fixtures = require("tests.support.fixtures")
local Helpers = require("tests.support.helpers")

local FormatContract = {}

-- Register contract tests for an IFormat implementation
-- Must be called from within a busted test file
-- @param name string - Name for the test suite
-- @param implementation table - IFormat implementation to test
-- @param options table - Optional: fixture_name, skip_roundtrip
function FormatContract.register(name, implementation, options)
  options = options or {}
  local fixture_name = options.fixture_name or "simple"

  describe(name, function()
    local fixture_data
    local fixture_raw

    before_each(function()
      fixture_data = Fixtures.load_story(fixture_name)
      fixture_raw = Fixtures.load_raw("stories/" .. fixture_name .. ".json")
    end)

    describe("can_import", function()
      it("should return a boolean", function()
        local result = implementation:can_import(fixture_raw)
        assert.is_boolean(result)
      end)

      it("should return true for valid source", function()
        local result = implementation:can_import(fixture_raw)
        assert.is_true(result)
      end)

      it("should return false for invalid source", function()
        local result = implementation:can_import("not valid data at all {{{")
        assert.is_false(result)
      end)

      it("should not error on nil input", function()
        local ok, result = pcall(function()
          return implementation:can_import(nil)
        end)
        -- Either returns false or errors gracefully
        if ok then
          assert.is_boolean(result)
        end
      end)

      it("should not error on empty string", function()
        local ok, result = pcall(function()
          return implementation:can_import("")
        end)
        if ok then
          assert.is_boolean(result)
        end
      end)
    end)

    describe("import", function()
      it("should return a table", function()
        local result = implementation:import(fixture_raw)
        assert.is_table(result)
      end)

      it("should return story with required fields", function()
        local story = implementation:import(fixture_raw)
        assert.is_not_nil(story.name, "Story should have name")
        assert.is_not_nil(story.start, "Story should have start")
        assert.is_not_nil(story.passages, "Story should have passages")
      end)

      it("should import passages correctly", function()
        local story = implementation:import(fixture_raw)
        assert.is_table(story.passages)

        -- Start passage should exist
        local start_passage = story.passages[story.start]
        assert.is_not_nil(start_passage, "Start passage should exist")
      end)

      it("should preserve passage content", function()
        local story = implementation:import(fixture_raw)
        local start_passage = story.passages[story.start]
        assert.is_not_nil(start_passage.content)
      end)

      it("should import choices", function()
        local story = implementation:import(fixture_raw)
        local start_passage = story.passages[story.start]

        if start_passage.choices then
          assert.is_table(start_passage.choices)
          if #start_passage.choices > 0 then
            local choice = start_passage.choices[1]
            assert.is_not_nil(choice.target, "Choice should have target")
          end
        end
      end)
    end)

    describe("can_export", function()
      it("should return a boolean", function()
        local story = implementation:import(fixture_raw)
        local result = implementation:can_export(story)
        assert.is_boolean(result)
      end)

      it("should return true for valid story", function()
        local story = implementation:import(fixture_raw)
        local result = implementation:can_export(story)
        assert.is_true(result)
      end)

      it("should handle nil story gracefully", function()
        local ok, result = pcall(function()
          return implementation:can_export(nil)
        end)
        if ok then
          assert.is_false(result)
        end
      end)
    end)

    describe("export", function()
      it("should return a string", function()
        local story = implementation:import(fixture_raw)
        local result = implementation:export(story)
        assert.is_string(result)
      end)

      it("should return non-empty string for valid story", function()
        local story = implementation:import(fixture_raw)
        local result = implementation:export(story)
        assert.is_true(#result > 0, "Export should not be empty")
      end)
    end)

    if not options.skip_roundtrip then
      describe("round-trip", function()
        it("should preserve story name", function()
          local original = implementation:import(fixture_raw)
          local exported = implementation:export(original)
          local reimported = implementation:import(exported)

          assert.are.equal(original.name, reimported.name)
        end)

        it("should preserve start passage", function()
          local original = implementation:import(fixture_raw)
          local exported = implementation:export(original)
          local reimported = implementation:import(exported)

          assert.are.equal(original.start, reimported.start)
        end)

        it("should preserve passage count", function()
          local original = implementation:import(fixture_raw)
          local exported = implementation:export(original)
          local reimported = implementation:import(exported)

          local original_count = 0
          local reimported_count = 0

          for _ in pairs(original.passages) do original_count = original_count + 1 end
          for _ in pairs(reimported.passages) do reimported_count = reimported_count + 1 end

          assert.are.equal(original_count, reimported_count)
        end)

        it("should preserve passage content", function()
          local original = implementation:import(fixture_raw)
          local exported = implementation:export(original)
          local reimported = implementation:import(exported)

          for id, passage in pairs(original.passages) do
            local reimported_passage = reimported.passages[id]
            assert.is_not_nil(reimported_passage, "Passage " .. id .. " should exist after roundtrip")
            assert.are.equal(passage.content, reimported_passage.content)
          end
        end)

        it("should preserve choice count per passage", function()
          local original = implementation:import(fixture_raw)
          local exported = implementation:export(original)
          local reimported = implementation:import(exported)

          for id, passage in pairs(original.passages) do
            local reimported_passage = reimported.passages[id]
            local orig_choice_count = passage.choices and #passage.choices or 0
            local reimp_choice_count = reimported_passage.choices and #reimported_passage.choices or 0
            assert.are.equal(orig_choice_count, reimp_choice_count,
              "Choice count mismatch for passage " .. id)
          end
        end)
      end)
    end
  end)
end

return FormatContract
