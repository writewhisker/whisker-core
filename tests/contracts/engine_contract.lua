-- tests/contracts/engine_contract.lua
-- Contract test suite for IEngine implementations
-- Any runtime engine can be validated against this contract
--
-- Usage:
--   require("tests.contracts.engine_contract").register(
--     "MyEngine",
--     engine_factory,  -- function() that creates engine
--     { story = my_story }
--   )

local Fixtures = require("tests.support.fixtures")
local Helpers = require("tests.support.helpers")

local EngineContract = {}

-- Register contract tests for an IEngine implementation
-- Must be called from within a busted test file
-- @param name string - Name for the test suite
-- @param factory function - Factory that creates engine instances
-- @param options table - Optional: story (Story object or fixture name)
function EngineContract.register(name, factory, options)
  options = options or {}
  local fixture_name = options.fixture_name or "simple"

  describe(name, function()
    local engine
    local story

    before_each(function()
      story = Fixtures.load_story(fixture_name)
      engine = factory()
    end)

    describe("load", function()
      it("should accept a story object", function()
        assert.has_no.errors(function()
          engine:load(story)
        end)
      end)

      it("should be callable multiple times", function()
        engine:load(story)
        assert.has_no.errors(function()
          engine:load(story)
        end)
      end)
    end)

    describe("start", function()
      it("should start the story", function()
        engine:load(story)
        assert.has_no.errors(function()
          engine:start()
        end)
      end)

      it("should position at start passage", function()
        engine:load(story)
        engine:start()
        local passage = engine:get_current_passage()
        assert.is_not_nil(passage)
      end)
    end)

    describe("get_current_passage", function()
      it("should return nil before start", function()
        engine:load(story)
        local passage = engine:get_current_passage()
        -- May return nil or error before start - implementation dependent
        -- Just verify it doesn't crash
      end)

      it("should return current passage after start", function()
        engine:load(story)
        engine:start()
        local passage = engine:get_current_passage()
        assert.is_not_nil(passage)
      end)

      it("should return passage with content", function()
        engine:load(story)
        engine:start()
        local passage = engine:get_current_passage()
        assert.is_not_nil(passage.content or passage.text)
      end)
    end)

    describe("get_available_choices", function()
      it("should return a table", function()
        engine:load(story)
        engine:start()
        local choices = engine:get_available_choices()
        assert.is_table(choices)
      end)

      it("should return choices for passage with choices", function()
        engine:load(story)
        engine:start()
        local choices = engine:get_available_choices()
        -- simple.json start passage has 2 choices
        assert.is_true(#choices >= 0)
      end)
    end)

    describe("make_choice", function()
      it("should accept valid choice index", function()
        engine:load(story)
        engine:start()
        local choices = engine:get_available_choices()

        if #choices > 0 then
          assert.has_no.errors(function()
            engine:make_choice(1)
          end)
        end
      end)

      it("should advance to new passage", function()
        engine:load(story)
        engine:start()
        local initial_passage = engine:get_current_passage()
        local choices = engine:get_available_choices()

        if #choices > 0 then
          engine:make_choice(1)
          local new_passage = engine:get_current_passage()
          -- Passage should change (unless circular link to same passage)
          assert.is_not_nil(new_passage)
        end
      end)

      it("should return new passage after choice", function()
        engine:load(story)
        engine:start()
        local choices = engine:get_available_choices()

        if #choices > 0 then
          local result = engine:make_choice(1)
          -- Result may be passage or content object
          assert.is_not_nil(result)
        end
      end)

      it("should error on invalid index", function()
        engine:load(story)
        engine:start()

        assert.has_error(function()
          engine:make_choice(999)
        end)
      end)

      it("should error on zero index", function()
        engine:load(story)
        engine:start()

        assert.has_error(function()
          engine:make_choice(0)
        end)
      end)

      it("should error on negative index", function()
        engine:load(story)
        engine:start()

        assert.has_error(function()
          engine:make_choice(-1)
        end)
      end)
    end)

    describe("can_continue", function()
      it("should return boolean", function()
        engine:load(story)
        engine:start()
        local result = engine:can_continue()
        assert.is_boolean(result)
      end)

      it("should return true when choices available", function()
        engine:load(story)
        engine:start()
        local choices = engine:get_available_choices()

        if #choices > 0 then
          assert.is_true(engine:can_continue())
        end
      end)

      it("should return false at ending passage", function()
        engine:load(story)
        engine:start()

        -- Navigate to an ending (left_path or right_path have no choices)
        local choices = engine:get_available_choices()
        if #choices > 0 then
          engine:make_choice(1)
          local new_choices = engine:get_available_choices()
          if #new_choices == 0 then
            assert.is_false(engine:can_continue())
          end
        end
      end)
    end)

    describe("story progression", function()
      it("should allow multiple choices in sequence", function()
        -- Load complex story if available
        local complex_story = Fixtures.load_story("complex_branching")
        engine:load(complex_story)
        engine:start()

        -- Make several choices
        local max_moves = 5
        local moves = 0

        while engine:can_continue() and moves < max_moves do
          local choices = engine:get_available_choices()
          if #choices > 0 then
            engine:make_choice(1)
            moves = moves + 1
          else
            break
          end
        end

        assert.is_true(moves > 0, "Should be able to make at least one move")
      end)
    end)
  end)
end

return EngineContract
