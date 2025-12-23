--- Engine Contract Tests
-- Contract tests for IEngine implementations
-- @module tests.contracts.engine_contract
-- @author Whisker Core Team

--- Runs IEngine contract tests against an implementation
-- @param engine_factory function Creates IEngine instances
-- @param test_data table Provides test data {valid_story, invalid_story, ending_passage}
local function run_engine_contract_tests(engine_factory, test_data)
  describe("IEngine Contract", function()
    local engine

    before_each(function()
      engine = engine_factory()
    end)

    describe("Metadata and Interface", function()
      it("should be a table", function()
        assert.is_table(engine)
      end)

      it("should have all required methods", function()
        local required_methods = {
          "load", "start", "get_current_passage", "get_available_choices",
          "make_choice", "can_continue", "has_ended", "get_state", "restore_state"
        }

        for _, method in ipairs(required_methods) do
          assert.is_function(engine[method],
            "Missing required method: " .. method)
        end
      end)
    end)

    describe("load()", function()
      it("should accept valid story content", function()
        local success, err = engine:load(test_data.valid_story)
        assert.is_true(success)
        assert.is_nil(err)
      end)

      it("should reject invalid story content", function()
        local success, err = engine:load(test_data.invalid_story)
        assert.is_false(success)
        assert.is_not_nil(err)
        assert.is_string(err)
      end)

      it("should accept options table", function()
        local success = engine:load(test_data.valid_story, { debug = true })
        assert.is_true(success)
      end)

      it("should allow reloading a story", function()
        engine:load(test_data.valid_story)
        local success = engine:load(test_data.valid_story)
        assert.is_true(success)
      end)
    end)

    describe("start()", function()
      it("should fail if story not loaded", function()
        local success, err = engine:start()
        assert.is_false(success)
        assert.matches("not loaded", err:lower())
      end)

      it("should start from default passage when loaded", function()
        engine:load(test_data.valid_story)
        local success, err = engine:start()
        assert.is_true(success)
        assert.is_nil(err)
      end)

      it("should start from specified passage", function()
        engine:load(test_data.valid_story)
        local success = engine:start(test_data.custom_start_passage)
        assert.is_true(success)
      end)

      it("should reject nonexistent start passage", function()
        engine:load(test_data.valid_story)
        local success, err = engine:start("nonexistent_passage_xyz")
        assert.is_false(success)
        assert.is_not_nil(err)
      end)
    end)

    describe("get_current_passage()", function()
      it("should fail if engine not started", function()
        assert.has_error(function()
          engine:get_current_passage()
        end)
      end)

      it("should return passage object when running", function()
        engine:load(test_data.valid_story)
        engine:start()
        local passage = engine:get_current_passage()

        assert.is_not_nil(passage)
        assert.is_string(passage.name)
        assert.is_string(passage.text)
        assert.is_table(passage.tags)
      end)
    end)

    describe("get_available_choices()", function()
      it("should return array of choices", function()
        engine:load(test_data.valid_story)
        engine:start()
        local choices = engine:get_available_choices()

        assert.is_table(choices)
      end)

      it("should return empty table at story end", function()
        engine:load(test_data.valid_story)
        engine:start(test_data.ending_passage)
        local choices = engine:get_available_choices()

        assert.equals(0, #choices)
      end)

      it("should only include choices with satisfied conditions", function()
        engine:load(test_data.valid_story)
        engine:start()
        local choices = engine:get_available_choices()

        for _, choice in ipairs(choices) do
          assert.is_string(choice.text)
          assert.is_not_nil(choice.destination)
        end
      end)
    end)

    describe("make_choice()", function()
      it("should reject invalid choice index", function()
        engine:load(test_data.valid_story)
        engine:start()
        local success, err = engine:make_choice(999)

        assert.is_false(success)
        assert.matches("invalid", err:lower())
      end)

      it("should reject negative choice index", function()
        engine:load(test_data.valid_story)
        engine:start()
        local success, err = engine:make_choice(-1)

        assert.is_false(success)
      end)

      it("should advance to choice destination", function()
        engine:load(test_data.valid_story)
        engine:start()
        local choices = engine:get_available_choices()

        if #choices > 0 then
          local success = engine:make_choice(1)
          assert.is_true(success)

          local new_passage = engine:get_current_passage()
          assert.equals(choices[1].destination, new_passage.name)
        end
      end)
    end)

    describe("State Management", function()
      it("can_continue and has_ended should be opposites at endpoints", function()
        engine:load(test_data.valid_story)
        engine:start(test_data.ending_passage)

        local can_continue = engine:can_continue()
        local has_ended = engine:has_ended()

        assert.not_equals(can_continue, has_ended)
      end)

      it("should capture state snapshot", function()
        engine:load(test_data.valid_story)
        engine:start()

        local state = engine:get_state()
        assert.is_table(state)
      end)

      it("should restore from state snapshot", function()
        engine:load(test_data.valid_story)
        engine:start()

        local choices = engine:get_available_choices()
        if #choices > 0 then
          engine:make_choice(1)
        end

        local state = engine:get_state()

        local new_engine = engine_factory()
        local success = new_engine:restore_state(state)
        assert.is_true(success)

        local passage1 = engine:get_current_passage()
        local passage2 = new_engine:get_current_passage()
        assert.equals(passage1.name, passage2.name)
      end)
    end)

    describe("Lifecycle", function()
      it("should allow multiple playthroughs", function()
        engine:load(test_data.valid_story)

        -- First playthrough
        engine:start()
        local choices = engine:get_available_choices()
        if #choices > 0 then
          engine:make_choice(1)
        end

        -- Second playthrough
        local success = engine:start()
        assert.is_true(success)
        local passage = engine:get_current_passage()
        assert.is_not_nil(passage)
      end)
    end)
  end)
end

return {
  run_contract_tests = run_engine_contract_tests,
  required_test_data = {
    "valid_story",
    "invalid_story",
    "ending_passage",
    "custom_start_passage",
  }
}
