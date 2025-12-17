-- spec/formats/ink/variable_exporter_spec.lua
-- Tests for variable and logic export

describe("VariableGenerator", function()
  local VariableGenerator

  before_each(function()
    -- Clear cached modules
    for k in pairs(package.loaded) do
      if k:match("^whisker%.formats%.ink%.generators%.variable") then
        package.loaded[k] = nil
      end
    end

    VariableGenerator = require("whisker.formats.ink.generators.variable")
  end)

  describe("module metadata", function()
    it("should have _whisker metadata", function()
      assert.is_table(VariableGenerator._whisker)
      assert.are.equal("VariableGenerator", VariableGenerator._whisker.name)
    end)

    it("should have capability", function()
      assert.are.equal("formats.ink.generators.variable", VariableGenerator._whisker.capability)
    end)
  end)

  describe("new", function()
    it("should create a new instance", function()
      local gen = VariableGenerator.new()
      assert.is_table(gen)
    end)
  end)

  describe("generate_reference", function()
    local gen

    before_each(function()
      gen = VariableGenerator.new()
    end)

    it("should generate variable reference", function()
      local result = gen:generate_reference("health")
      assert.are.equal("health", result["VAR?"])
    end)
  end)

  describe("generate_assignment", function()
    local gen

    before_each(function()
      gen = VariableGenerator.new()
    end)

    it("should generate number assignment", function()
      local result = gen:generate_assignment("score", 100)

      assert.are.equal("ev", result[1])
      assert.are.equal(100, result[2])
      assert.are.equal("/ev", result[3])
      assert.are.equal("score", result[4]["VAR="])
    end)

    it("should generate string assignment", function()
      local result = gen:generate_assignment("name", "Player")

      assert.are.equal("ev", result[1])
      assert.are.equal("Player", result[2]["^"])
    end)

    it("should generate boolean assignment", function()
      local result = gen:generate_assignment("has_key", true)

      assert.are.equal("ev", result[1])
      assert.is_true(result[2])
    end)
  end)

  describe("generate_compound_assignment", function()
    local gen

    before_each(function()
      gen = VariableGenerator.new()
    end)

    it("should generate += assignment", function()
      local result = gen:generate_compound_assignment("score", 10, "+=")

      assert.are.equal("ev", result[1])
      assert.are.equal("score", result[2]["VAR?"])
      assert.are.equal(10, result[3])
      assert.are.equal("+", result[4])
      assert.are.equal("/ev", result[5])
      assert.is_true(result[6]["re"])
    end)

    it("should generate -= assignment", function()
      local result = gen:generate_compound_assignment("health", 5, "-=")

      assert.are.equal("-", result[4])
    end)

    it("should generate *= assignment", function()
      local result = gen:generate_compound_assignment("multiplier", 2, "*=")

      assert.are.equal("*", result[4])
    end)

    it("should generate /= assignment", function()
      local result = gen:generate_compound_assignment("value", 2, "/=")

      assert.are.equal("/", result[4])
    end)
  end)

  describe("generate_declaration", function()
    local gen

    before_each(function()
      gen = VariableGenerator.new()
    end)

    it("should generate declaration with default", function()
      local result = gen:generate_declaration({
        name = "health",
        type = "integer",
        default = 100
      })

      assert.are.equal("health", result.name)
      assert.are.equal(100, result.value)
    end)

    it("should use type default for missing default", function()
      local result = gen:generate_declaration({
        name = "text",
        type = "string"
      })

      assert.are.equal("text", result.name)
      assert.are.equal("", result.value["^"])
    end)

    it("should default to 0 for number type", function()
      local result = gen:generate_declaration({
        name = "count",
        type = "integer"
      })

      assert.are.equal(0, result.value)
    end)

    it("should default to false for boolean", function()
      local result = gen:generate_declaration({
        name = "flag",
        type = "boolean"
      })

      assert.is_false(result.value)
    end)
  end)

  describe("generate_all_declarations", function()
    local gen

    before_each(function()
      gen = VariableGenerator.new()
    end)

    it("should generate all declarations", function()
      local variables = {
        health = { name = "health", type = "integer", default = 100 },
        name = { name = "name", type = "string", default = "Player" }
      }

      local result = gen:generate_all_declarations(variables)

      assert.are.equal(100, result.health)
      assert.are.equal("Player", result.name["^"])
    end)
  end)
end)

describe("LogicGenerator", function()
  local LogicGenerator

  before_each(function()
    for k in pairs(package.loaded) do
      if k:match("^whisker%.formats%.ink%.generators%.logic") then
        package.loaded[k] = nil
      end
    end

    LogicGenerator = require("whisker.formats.ink.generators.logic")
  end)

  describe("module metadata", function()
    it("should have _whisker metadata", function()
      assert.is_table(LogicGenerator._whisker)
      assert.are.equal("LogicGenerator", LogicGenerator._whisker.name)
    end)

    it("should have capability", function()
      assert.are.equal("formats.ink.generators.logic", LogicGenerator._whisker.capability)
    end)
  end)

  describe("OPERATOR_MAP", function()
    it("should map arithmetic operators", function()
      assert.are.equal("+", LogicGenerator.OPERATOR_MAP["+"])
      assert.are.equal("-", LogicGenerator.OPERATOR_MAP["-"])
      assert.are.equal("*", LogicGenerator.OPERATOR_MAP["*"])
      assert.are.equal("/", LogicGenerator.OPERATOR_MAP["/"])
    end)

    it("should map comparison operators", function()
      assert.are.equal("==", LogicGenerator.OPERATOR_MAP["=="])
      assert.are.equal("!=", LogicGenerator.OPERATOR_MAP["~="])
      assert.are.equal("<", LogicGenerator.OPERATOR_MAP["<"])
      assert.are.equal(">", LogicGenerator.OPERATOR_MAP[">"])
    end)

    it("should map logical operators", function()
      assert.are.equal("&&", LogicGenerator.OPERATOR_MAP["and"])
      assert.are.equal("||", LogicGenerator.OPERATOR_MAP["or"])
      assert.are.equal("!", LogicGenerator.OPERATOR_MAP["not"])
    end)
  end)

  describe("new", function()
    it("should create a new instance", function()
      local gen = LogicGenerator.new()
      assert.is_table(gen)
    end)
  end)

  describe("map_operator", function()
    local gen

    before_each(function()
      gen = LogicGenerator.new()
    end)

    it("should map known operators", function()
      assert.are.equal("!=", gen:map_operator("~="))
      assert.are.equal("&&", gen:map_operator("and"))
      assert.are.equal("||", gen:map_operator("or"))
    end)

    it("should pass through unknown operators", function()
      assert.are.equal("unknown", gen:map_operator("unknown"))
    end)
  end)

  describe("generate_expression", function()
    local gen

    before_each(function()
      gen = LogicGenerator.new()
    end)

    it("should generate simple number", function()
      local result = gen:generate_expression(42)
      assert.are.equal(42, result[1])
    end)

    it("should generate simple string", function()
      local result = gen:generate_expression("hello")
      assert.are.equal("hello", result[1]["^"])
    end)

    it("should generate variable reference", function()
      local result = gen:generate_expression({ variable = "health" })
      assert.are.equal("health", result[1]["VAR?"])
    end)

    it("should generate visit count", function()
      local result = gen:generate_expression({ visit_count = "my_knot" })
      assert.are.equal("my_knot", result[1]["CNT?"])
    end)

    it("should generate binary expression", function()
      local result = gen:generate_expression({
        left = { variable = "health" },
        right = 50,
        operator = ">"
      })

      assert.are.equal("health", result[1]["VAR?"])
      assert.are.equal(50, result[2])
      assert.are.equal(">", result[3])
    end)

    it("should generate unary expression", function()
      local result = gen:generate_expression({
        operand = { variable = "has_key" },
        operator = "not"
      })

      assert.are.equal("has_key", result[1]["VAR?"])
      assert.are.equal("!", result[2])
    end)

    it("should handle wrapped value", function()
      local result = gen:generate_expression({ value = 100 })
      assert.are.equal(100, result[1])
    end)
  end)

  describe("generate_condition", function()
    local gen

    before_each(function()
      gen = LogicGenerator.new()
    end)

    it("should wrap expression in ev block", function()
      local result = gen:generate_condition({ variable = "flag" })

      assert.are.equal("ev", result[1])
      assert.are.equal("flag", result[2]["VAR?"])
      assert.are.equal("/ev", result[3])
    end)
  end)

  describe("is_comparison", function()
    local gen

    before_each(function()
      gen = LogicGenerator.new()
    end)

    it("should return true for comparison operators", function()
      assert.is_true(gen:is_comparison("=="))
      assert.is_true(gen:is_comparison("!="))
      assert.is_true(gen:is_comparison("<"))
      assert.is_true(gen:is_comparison(">"))
      assert.is_true(gen:is_comparison("<="))
      assert.is_true(gen:is_comparison(">="))
    end)

    it("should return false for non-comparison", function()
      assert.is_false(gen:is_comparison("+"))
      assert.is_false(gen:is_comparison("and"))
    end)
  end)

  describe("is_logical", function()
    local gen

    before_each(function()
      gen = LogicGenerator.new()
    end)

    it("should return true for logical operators", function()
      assert.is_true(gen:is_logical("and"))
      assert.is_true(gen:is_logical("or"))
      assert.is_true(gen:is_logical("not"))
      assert.is_true(gen:is_logical("&&"))
      assert.is_true(gen:is_logical("||"))
    end)

    it("should return false for non-logical", function()
      assert.is_false(gen:is_logical("+"))
      assert.is_false(gen:is_logical("=="))
    end)
  end)

  describe("get_operator_map", function()
    it("should return operator map", function()
      local gen = LogicGenerator.new()
      local map = gen:get_operator_map()

      assert.is_table(map)
      assert.are.equal("&&", map["and"])
    end)
  end)
end)

describe("Exporter with variables", function()
  local Exporter

  before_each(function()
    for k in pairs(package.loaded) do
      if k:match("^whisker%.formats%.ink") then
        package.loaded[k] = nil
      end
    end

    Exporter = require("whisker.formats.ink.exporter")
  end)

  it("should export story with variables", function()
    local story = {
      start = "start",
      passages = {
        start = { id = "start", content = "You have {health} HP" }
      },
      variables = {
        health = { name = "health", type = "integer", default = 100 },
        name = { name = "name", type = "string", default = "Hero" }
      }
    }

    local exporter = Exporter.new()
    local result = exporter:export(story)

    assert.is_table(result)
    assert.are.equal(20, result.inkVersion)
  end)
end)
