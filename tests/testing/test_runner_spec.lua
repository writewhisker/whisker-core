--- Test Runner Tests
-- Unit tests for the TestRunner class
-- @module tests.testing.test_runner_spec

local helper = require("tests.test_helper")
local TestRunner = require("whisker.testing.test_runner")
local TestScenario = require("whisker.testing.test_scenario")

describe("TestRunner", function()
  local function create_test_story()
    return {
      startPassage = "start",
      passages = {
        start = {
          id = "start",
          name = "start",
          title = "Start",
          content = "Welcome to the adventure!",
          choices = {
            { id = "c1", text = "Go north", target = "north" },
            { id = "c2", text = "Go south", target = "south" },
          },
        },
        north = {
          id = "north",
          name = "north",
          title = "North Room",
          content = "You are in the north room.",
          choices = {
            { id = "c3", text = "Go back", target = "start" },
          },
        },
        south = {
          id = "south",
          name = "south",
          title = "South Room",
          content = "You found treasure! You win!",
          choices = {},
        },
      },
      variables = {
        score = { name = "score", type = "number", initial = 0 },
        name = { name = "name", type = "string", initial = "Player" },
      },
    }
  end

  describe("new", function()
    it("should create a runner with a story", function()
      local story = create_test_story()
      local runner = TestRunner.new(story)

      assert.is_not_nil(runner)
    end)
  end)

  describe("reset", function()
    it("should initialize variables from story", function()
      local story = create_test_story()
      local runner = TestRunner.new(story)
      runner:reset()

      assert.equals(0, runner._variables.score)
      assert.equals("Player", runner._variables.name)
    end)

    it("should clear visit history", function()
      local story = create_test_story()
      local runner = TestRunner.new(story)
      runner._visit_history = { { passage_id = "test" } }
      runner:reset()

      assert.equals(0, #runner._visit_history)
    end)
  end)

  describe("run_test", function()
    describe("start step", function()
      it("should start at the beginning passage", function()
        local story = create_test_story()
        local runner = TestRunner.new(story)

        local scenario = TestScenario.new({ name = "Start Test" })
          :start()

        local result = runner:run_test(scenario)

        assert.is_true(result.passed)
        assert.equals(1, result.passed_steps)
        assert.equals(0, result.failed_steps)
      end)

      it("should record visit history", function()
        local story = create_test_story()
        local runner = TestRunner.new(story)

        local scenario = TestScenario.new()
          :start()

        local result = runner:run_test(scenario)

        assert.equals(1, #result.visit_history)
        assert.equals("start", result.visit_history[1].passage_id)
      end)
    end)

    describe("choice step", function()
      it("should navigate by choice index", function()
        local story = create_test_story()
        local runner = TestRunner.new(story)

        local scenario = TestScenario.new()
          :start()
          :choose_by_index(0)
          :check_passage({ id = "north" })

        local result = runner:run_test(scenario)

        assert.is_true(result.passed)
      end)

      it("should navigate by choice text", function()
        local story = create_test_story()
        local runner = TestRunner.new(story)

        local scenario = TestScenario.new()
          :start()
          :choose_by_text("Go south")
          :check_passage({ id = "south" })

        local result = runner:run_test(scenario)

        assert.is_true(result.passed)
      end)

      it("should fail on invalid choice index", function()
        local story = create_test_story()
        local runner = TestRunner.new(story)

        local scenario = TestScenario.new()
          :start()
          :choose_by_index(99)

        local result = runner:run_test(scenario)

        assert.is_false(result.passed)
        assert.equals(1, result.failed_steps)
      end)

      it("should fail on invalid choice text", function()
        local story = create_test_story()
        local runner = TestRunner.new(story)

        local scenario = TestScenario.new()
          :start()
          :choose_by_text("Go nowhere")

        local result = runner:run_test(scenario)

        assert.is_false(result.passed)
      end)

      it("should record choice history", function()
        local story = create_test_story()
        local runner = TestRunner.new(story)

        local scenario = TestScenario.new()
          :start()
          :choose_by_index(0)

        local result = runner:run_test(scenario)

        assert.equals(1, #result.choice_history)
        assert.equals("start", result.choice_history[1].from_passage)
        assert.equals("north", result.choice_history[1].to_passage)
      end)
    end)

    describe("check_passage step", function()
      it("should pass when at expected passage by id", function()
        local story = create_test_story()
        local runner = TestRunner.new(story)

        local scenario = TestScenario.new()
          :start()
          :check_passage({ id = "start" })

        local result = runner:run_test(scenario)

        assert.is_true(result.passed)
      end)

      it("should pass when at expected passage by title", function()
        local story = create_test_story()
        local runner = TestRunner.new(story)

        local scenario = TestScenario.new()
          :start()
          :check_passage({ title = "Start" })

        local result = runner:run_test(scenario)

        assert.is_true(result.passed)
      end)

      it("should fail when at wrong passage", function()
        local story = create_test_story()
        local runner = TestRunner.new(story)

        local scenario = TestScenario.new()
          :start()
          :check_passage({ id = "north" })

        local result = runner:run_test(scenario)

        assert.is_false(result.passed)
      end)
    end)

    describe("check_variable step", function()
      it("should check equals operator", function()
        local story = create_test_story()
        local runner = TestRunner.new(story)

        local scenario = TestScenario.new()
          :start()
          :check_variable("score", 0, "equals")

        local result = runner:run_test(scenario)

        assert.is_true(result.passed)
      end)

      it("should check not_equals operator", function()
        local story = create_test_story()
        local runner = TestRunner.new(story)

        local scenario = TestScenario.new()
          :start()
          :check_variable("score", 100, "not_equals")

        local result = runner:run_test(scenario)

        assert.is_true(result.passed)
      end)

      it("should check greater_than operator", function()
        local story = create_test_story()
        local runner = TestRunner.new(story)

        local scenario = TestScenario.new()
          :start()
          :set_variable("score", 50)
          :check_variable("score", 25, "greater_than")

        local result = runner:run_test(scenario)

        assert.is_true(result.passed)
      end)

      it("should check less_than operator", function()
        local story = create_test_story()
        local runner = TestRunner.new(story)

        local scenario = TestScenario.new()
          :start()
          :check_variable("score", 100, "less_than")

        local result = runner:run_test(scenario)

        assert.is_true(result.passed)
      end)

      it("should check contains operator", function()
        local story = create_test_story()
        local runner = TestRunner.new(story)

        local scenario = TestScenario.new()
          :start()
          :check_variable("name", "Play", "contains")

        local result = runner:run_test(scenario)

        assert.is_true(result.passed)
      end)

      it("should fail on wrong value", function()
        local story = create_test_story()
        local runner = TestRunner.new(story)

        local scenario = TestScenario.new()
          :start()
          :check_variable("score", 999)

        local result = runner:run_test(scenario)

        assert.is_false(result.passed)
      end)
    end)

    describe("check_text step", function()
      it("should check contains mode", function()
        local story = create_test_story()
        local runner = TestRunner.new(story)

        local scenario = TestScenario.new()
          :start()
          :check_text("Welcome")

        local result = runner:run_test(scenario)

        assert.is_true(result.passed)
      end)

      it("should check exact mode", function()
        local story = create_test_story()
        local runner = TestRunner.new(story)

        local scenario = TestScenario.new()
          :start()
          :check_text("Welcome to the adventure!", "exact")

        local result = runner:run_test(scenario)

        assert.is_true(result.passed)
      end)

      it("should check pattern mode", function()
        local story = create_test_story()
        local runner = TestRunner.new(story)

        local scenario = TestScenario.new()
          :start()
          :check_text("^Welcome.*!$", "pattern")

        local result = runner:run_test(scenario)

        assert.is_true(result.passed)
      end)

      it("should fail on missing text", function()
        local story = create_test_story()
        local runner = TestRunner.new(story)

        local scenario = TestScenario.new()
          :start()
          :check_text("This text does not exist")

        local result = runner:run_test(scenario)

        assert.is_false(result.passed)
      end)
    end)

    describe("set_variable step", function()
      it("should set a variable value", function()
        local story = create_test_story()
        local runner = TestRunner.new(story)

        local scenario = TestScenario.new()
          :start()
          :set_variable("score", 100)
          :check_variable("score", 100)

        local result = runner:run_test(scenario)

        assert.is_true(result.passed)
      end)
    end)

    describe("result metadata", function()
      it("should include scenario info", function()
        local story = create_test_story()
        local runner = TestRunner.new(story)

        local scenario = TestScenario.new({
          id = "test-123",
          name = "My Test",
        }):start()

        local result = runner:run_test(scenario)

        assert.equals("test-123", result.scenario_id)
        assert.equals("My Test", result.scenario_name)
      end)

      it("should include timing info", function()
        local story = create_test_story()
        local runner = TestRunner.new(story)

        local scenario = TestScenario.new():start()
        local result = runner:run_test(scenario)

        assert.is_string(result.start_time)
        assert.is_string(result.end_time)
        assert.is_number(result.duration)
      end)

      it("should include step counts", function()
        local story = create_test_story()
        local runner = TestRunner.new(story)

        local scenario = TestScenario.new()
          :start()
          :choose_by_index(0)

        local result = runner:run_test(scenario)

        assert.equals(2, result.total_steps)
        assert.equals(2, result.passed_steps)
        assert.equals(0, result.failed_steps)
      end)
    end)
  end)

  describe("run_tests", function()
    it("should run multiple scenarios", function()
      local story = create_test_story()
      local runner = TestRunner.new(story)

      local scenarios = {
        TestScenario.new({ name = "Test 1" }):start(),
        TestScenario.new({ name = "Test 2" }):start():choose_by_index(0),
      }

      local results = runner:run_tests(scenarios)

      assert.equals(2, #results)
      assert.is_true(results[1].passed)
      assert.is_true(results[2].passed)
    end)

    it("should skip disabled scenarios", function()
      local story = create_test_story()
      local runner = TestRunner.new(story)

      local scenarios = {
        TestScenario.new({ name = "Enabled" }):start(),
        TestScenario.new({ name = "Disabled", enabled = false }):start(),
      }

      local results = runner:run_tests(scenarios)

      assert.equals(1, #results)
      assert.equals("Enabled", results[1].scenario_name)
    end)
  end)

  describe("run_all", function()
    it("should return summary with counts", function()
      local story = create_test_story()
      local runner = TestRunner.new(story)

      local scenarios = {
        TestScenario.new({ name = "Pass 1" }):start(),
        TestScenario.new({ name = "Pass 2" }):start(),
        TestScenario.new({ name = "Fail" }):start():choose_by_index(99),
      }

      local summary = runner:run_all(scenarios)

      assert.equals(3, summary.total)
      assert.equals(2, summary.passed)
      assert.equals(1, summary.failed)
      assert.is_false(summary.success)
    end)

    it("should report success when all pass", function()
      local story = create_test_story()
      local runner = TestRunner.new(story)

      local scenarios = {
        TestScenario.new({ name = "Pass 1" }):start(),
        TestScenario.new({ name = "Pass 2" }):start(),
      }

      local summary = runner:run_all(scenarios)

      assert.is_true(summary.success)
    end)

    it("should include total duration", function()
      local story = create_test_story()
      local runner = TestRunner.new(story)

      local scenarios = {
        TestScenario.new():start(),
        TestScenario.new():start(),
      }

      local summary = runner:run_all(scenarios)

      assert.is_number(summary.duration)
    end)
  end)
end)
