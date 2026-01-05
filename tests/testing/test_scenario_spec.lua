--- Test Scenario Tests
-- Unit tests for the TestScenario class
-- @module tests.testing.test_scenario_spec

local helper = require("tests.test_helper")
local TestScenario = require("whisker.testing.test_scenario")

describe("TestScenario", function()
  describe("new", function()
    it("should create a scenario with default values", function()
      local scenario = TestScenario.new()

      assert.is_string(scenario.id)
      assert.equals("Unnamed Scenario", scenario.name)
      assert.equals("", scenario.description)
      assert.is_true(scenario.enabled)
      assert.is_table(scenario.tags)
      assert.is_table(scenario.steps)
      assert.equals(30000, scenario.timeout)
    end)

    it("should create a scenario with provided config", function()
      local scenario = TestScenario.new({
        id = "test-1",
        name = "My Test",
        description = "A test scenario",
        enabled = false,
        tags = { "smoke", "happy-path" },
        timeout = 60000,
      })

      assert.equals("test-1", scenario.id)
      assert.equals("My Test", scenario.name)
      assert.equals("A test scenario", scenario.description)
      assert.is_false(scenario.enabled)
      assert.same({ "smoke", "happy-path" }, scenario.tags)
      assert.equals(60000, scenario.timeout)
    end)

    it("should initialize steps from config", function()
      local scenario = TestScenario.new({
        steps = {
          { type = "start" },
          { type = "choice", choice_index = 0 },
        },
      })

      assert.equals(2, #scenario.steps)
    end)
  end)

  describe("add_step", function()
    it("should add a step and return self for chaining", function()
      local scenario = TestScenario.new()
      local result = scenario:add_step({ type = "start" })

      assert.equals(1, #scenario.steps)
      assert.equals(scenario, result)
    end)

    it("should normalize step fields", function()
      local scenario = TestScenario.new()
      scenario:add_step({
        type = "choice",
        choiceIndex = 2, -- camelCase
      })

      assert.equals(2, scenario.steps[1].choice_index)
    end)
  end)

  describe("start", function()
    it("should add a start step", function()
      local scenario = TestScenario.new()
      scenario:start("Begin the test")

      assert.equals(1, #scenario.steps)
      assert.equals("start", scenario.steps[1].type)
      assert.equals("Begin the test", scenario.steps[1].description)
    end)

    it("should use default description", function()
      local scenario = TestScenario.new()
      scenario:start()

      assert.equals("Start the story", scenario.steps[1].description)
    end)
  end)

  describe("choose_by_index", function()
    it("should add a choice step with index", function()
      local scenario = TestScenario.new()
      scenario:choose_by_index(0, "Select first option")

      assert.equals(1, #scenario.steps)
      assert.equals("choice", scenario.steps[1].type)
      assert.equals(0, scenario.steps[1].choice_index)
      assert.equals("Select first option", scenario.steps[1].description)
    end)
  end)

  describe("choose_by_text", function()
    it("should add a choice step with text", function()
      local scenario = TestScenario.new()
      scenario:choose_by_text("Go north")

      assert.equals(1, #scenario.steps)
      assert.equals("choice", scenario.steps[1].type)
      assert.equals("Go north", scenario.steps[1].choice_text)
    end)
  end)

  describe("check_passage", function()
    it("should add a check passage step with id", function()
      local scenario = TestScenario.new()
      scenario:check_passage({ id = "room-1" })

      assert.equals(1, #scenario.steps)
      assert.equals("check_passage", scenario.steps[1].type)
      assert.equals("room-1", scenario.steps[1].expected_passage_id)
    end)

    it("should add a check passage step with title", function()
      local scenario = TestScenario.new()
      scenario:check_passage({ title = "The Dark Room" })

      assert.equals("The Dark Room", scenario.steps[1].expected_passage_title)
    end)
  end)

  describe("check_variable", function()
    it("should add a check variable step with default operator", function()
      local scenario = TestScenario.new()
      scenario:check_variable("score", 100)

      assert.equals(1, #scenario.steps)
      assert.equals("check_variable", scenario.steps[1].type)
      assert.equals("score", scenario.steps[1].variable_name)
      assert.equals(100, scenario.steps[1].expected_value)
      assert.equals("equals", scenario.steps[1].operator)
    end)

    it("should add a check variable step with custom operator", function()
      local scenario = TestScenario.new()
      scenario:check_variable("health", 50, "greater_than")

      assert.equals("greater_than", scenario.steps[1].operator)
    end)
  end)

  describe("check_text", function()
    it("should add a check text step with default match mode", function()
      local scenario = TestScenario.new()
      scenario:check_text("Welcome to the game")

      assert.equals(1, #scenario.steps)
      assert.equals("check_text", scenario.steps[1].type)
      assert.equals("Welcome to the game", scenario.steps[1].expected_text)
      assert.equals("contains", scenario.steps[1].text_match)
    end)

    it("should add a check text step with custom match mode", function()
      local scenario = TestScenario.new()
      scenario:check_text("^Welcome", "pattern")

      assert.equals("pattern", scenario.steps[1].text_match)
    end)
  end)

  describe("set_variable", function()
    it("should add a set variable step", function()
      local scenario = TestScenario.new()
      scenario:set_variable("gold", 500)

      assert.equals(1, #scenario.steps)
      assert.equals("set_variable", scenario.steps[1].type)
      assert.equals("gold", scenario.steps[1].variable_name)
      assert.equals(500, scenario.steps[1].value)
    end)
  end)

  describe("fluent chaining", function()
    it("should support method chaining", function()
      local scenario = TestScenario.new({ name = "Chained Test" })
        :start()
        :check_passage({ title = "Start" })
        :choose_by_index(0)
        :check_variable("score", 10)
        :check_text("You win")

      assert.equals(5, #scenario.steps)
      assert.equals("start", scenario.steps[1].type)
      assert.equals("check_passage", scenario.steps[2].type)
      assert.equals("choice", scenario.steps[3].type)
      assert.equals("check_variable", scenario.steps[4].type)
      assert.equals("check_text", scenario.steps[5].type)
    end)
  end)

  describe("serialize", function()
    it("should serialize scenario to table", function()
      local scenario = TestScenario.new({
        id = "test-1",
        name = "Serialize Test",
        description = "Test serialization",
        tags = { "unit" },
      })
      scenario:start()

      local data = scenario:serialize()

      assert.equals("test-1", data.id)
      assert.equals("Serialize Test", data.name)
      assert.equals("Test serialization", data.description)
      assert.same({ "unit" }, data.tags)
      assert.equals(1, #data.steps)
    end)
  end)

  describe("deserialize", function()
    it("should deserialize table to scenario", function()
      local data = {
        id = "test-2",
        name = "Deserialize Test",
        steps = {
          { type = "start" },
        },
      }

      local scenario = TestScenario.deserialize(data)

      assert.equals("test-2", scenario.id)
      assert.equals("Deserialize Test", scenario.name)
      assert.equals(1, #scenario.steps)
    end)
  end)

  describe("load_many", function()
    it("should load multiple scenarios from scenarios array", function()
      local data = {
        scenarios = {
          { id = "s1", name = "Scenario 1" },
          { id = "s2", name = "Scenario 2" },
        },
      }

      local scenarios = TestScenario.load_many(data)

      assert.equals(2, #scenarios)
      assert.equals("s1", scenarios[1].id)
      assert.equals("s2", scenarios[2].id)
    end)

    it("should load from tests array", function()
      local data = {
        tests = {
          { id = "t1", name = "Test 1" },
        },
      }

      local scenarios = TestScenario.load_many(data)

      assert.equals(1, #scenarios)
      assert.equals("t1", scenarios[1].id)
    end)

    it("should load from direct array", function()
      local data = {
        { id = "d1", name = "Direct 1" },
        { id = "d2", name = "Direct 2" },
      }

      local scenarios = TestScenario.load_many(data)

      assert.equals(2, #scenarios)
    end)
  end)
end)
