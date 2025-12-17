-- spec/formats/ink/variable_converter_spec.lua
-- Tests for variable and logic conversion

describe("VariableTransformer", function()
  local VariableTransformer

  before_each(function()
    -- Clear cached modules
    for k in pairs(package.loaded) do
      if k:match("^whisker%.formats%.ink%.transformers%.variable") then
        package.loaded[k] = nil
      end
    end

    VariableTransformer = require("whisker.formats.ink.transformers.variable")
  end)

  describe("module metadata", function()
    it("should have _whisker metadata", function()
      assert.is_table(VariableTransformer._whisker)
      assert.are.equal("VariableTransformer", VariableTransformer._whisker.name)
    end)

    it("should have capability", function()
      assert.are.equal("formats.ink.transformers.variable", VariableTransformer._whisker.capability)
    end)
  end)

  describe("new", function()
    it("should create a new instance", function()
      local transformer = VariableTransformer.new()
      assert.is_table(transformer)
    end)
  end)

  describe("_detect_type", function()
    local transformer

    before_each(function()
      transformer = VariableTransformer.new()
    end)

    it("should detect integer", function()
      assert.are.equal("integer", transformer:_detect_type(42))
      assert.are.equal("integer", transformer:_detect_type(0))
      assert.are.equal("integer", transformer:_detect_type(-10))
    end)

    it("should detect float", function()
      assert.are.equal("float", transformer:_detect_type(3.14))
      assert.are.equal("float", transformer:_detect_type(-0.5))
    end)

    it("should detect string", function()
      assert.are.equal("string", transformer:_detect_type("hello"))
      assert.are.equal("string", transformer:_detect_type(""))
    end)

    it("should detect boolean", function()
      assert.are.equal("boolean", transformer:_detect_type(true))
      assert.are.equal("boolean", transformer:_detect_type(false))
    end)

    it("should detect nil", function()
      assert.are.equal("nil", transformer:_detect_type(nil))
    end)

    it("should detect list", function()
      local list_value = { listName = "colors" }
      assert.are.equal("list", transformer:_detect_type(list_value))
    end)

    it("should handle wrapped values", function()
      local wrapped = { value = 42 }
      assert.are.equal("integer", transformer:_detect_type(wrapped))
    end)
  end)

  describe("transform", function()
    local transformer

    before_each(function()
      transformer = VariableTransformer.new()
    end)

    it("should transform integer variable", function()
      local result = transformer:transform("health", 100, {})

      assert.are.equal("health", result.name)
      assert.are.equal("integer", result.type)
      assert.are.equal(100, result.default)
    end)

    it("should transform string variable", function()
      local result = transformer:transform("name", "Player", {})

      assert.are.equal("name", result.name)
      assert.are.equal("string", result.type)
      assert.are.equal("Player", result.default)
    end)

    it("should transform boolean variable", function()
      local result = transformer:transform("has_key", true, {})

      assert.are.equal("has_key", result.name)
      assert.are.equal("boolean", result.type)
      assert.are.equal(true, result.default)
    end)

    it("should add source metadata when preserve_ink_paths", function()
      local result = transformer:transform("var", 10, { preserve_ink_paths = true })

      assert.is_table(result.metadata)
      assert.are.equal("ink", result.metadata.source)
    end)
  end)
end)

describe("LogicTransformer", function()
  local LogicTransformer

  before_each(function()
    -- Clear cached modules
    for k in pairs(package.loaded) do
      if k:match("^whisker%.formats%.ink%.transformers%.logic") then
        package.loaded[k] = nil
      end
    end

    LogicTransformer = require("whisker.formats.ink.transformers.logic")
  end)

  describe("module metadata", function()
    it("should have _whisker metadata", function()
      assert.is_table(LogicTransformer._whisker)
      assert.are.equal("LogicTransformer", LogicTransformer._whisker.name)
    end)

    it("should have capability", function()
      assert.are.equal("formats.ink.transformers.logic", LogicTransformer._whisker.capability)
    end)
  end)

  describe("new", function()
    it("should create a new instance", function()
      local transformer = LogicTransformer.new()
      assert.is_table(transformer)
    end)
  end)

  describe("transform_operator", function()
    local transformer

    before_each(function()
      transformer = LogicTransformer.new()
    end)

    it("should map arithmetic operators", function()
      assert.are.equal("+", transformer:transform_operator("+"))
      assert.are.equal("-", transformer:transform_operator("-"))
      assert.are.equal("*", transformer:transform_operator("*"))
      assert.are.equal("/", transformer:transform_operator("/"))
      assert.are.equal("%", transformer:transform_operator("%"))
    end)

    it("should map comparison operators", function()
      assert.are.equal("==", transformer:transform_operator("=="))
      assert.are.equal("~=", transformer:transform_operator("!="))
      assert.are.equal("<", transformer:transform_operator("<"))
      assert.are.equal(">", transformer:transform_operator(">"))
      assert.are.equal("<=", transformer:transform_operator("<="))
      assert.are.equal(">=", transformer:transform_operator(">="))
    end)

    it("should map logical operators", function()
      assert.are.equal("and", transformer:transform_operator("&&"))
      assert.are.equal("or", transformer:transform_operator("||"))
      assert.are.equal("not", transformer:transform_operator("!"))
    end)

    it("should return unmapped operators as-is", function()
      assert.are.equal("unknown", transformer:transform_operator("unknown"))
    end)
  end)

  describe("transform_expression", function()
    local transformer

    before_each(function()
      transformer = LogicTransformer.new()
    end)

    it("should transform simple value", function()
      local result = transformer:transform_expression(42, {})
      assert.are.equal("42", result)
    end)

    it("should transform string literal", function()
      local result = transformer:transform_expression({ ["^"] = "hello" }, {})
      assert.are.equal("\"hello\"", result)
    end)

    it("should transform variable reference", function()
      local result = transformer:transform_expression({ ["VAR?"] = "health" }, {})
      assert.are.equal("health", result)
    end)

    it("should transform visit count", function()
      local result = transformer:transform_expression({ ["CNT?"] = "my_knot" }, {})
      assert.are.equal("visit_count(\"my_knot\")", result)
    end)
  end)

  describe("transform_assignment", function()
    local transformer

    before_each(function()
      transformer = LogicTransformer.new()
    end)

    it("should transform simple assignment", function()
      local result = transformer:transform_assignment("x", 10, "=")
      assert.are.equal("x = 10", result)
    end)

    it("should transform add assignment", function()
      local result = transformer:transform_assignment("score", 5, "+=")
      assert.are.equal("score = score + 5", result)
    end)

    it("should transform subtract assignment", function()
      local result = transformer:transform_assignment("health", 10, "-=")
      assert.are.equal("health = health - 10", result)
    end)

    it("should transform multiply assignment", function()
      local result = transformer:transform_assignment("multiplier", 2, "*=")
      assert.are.equal("multiplier = multiplier * 2", result)
    end)

    it("should transform divide assignment", function()
      local result = transformer:transform_assignment("value", 2, "/=")
      assert.are.equal("value = value / 2", result)
    end)

    it("should default to simple assignment", function()
      local result = transformer:transform_assignment("x", 5)
      assert.are.equal("x = 5", result)
    end)
  end)

  describe("get_operator_map", function()
    it("should return the operator map", function()
      local transformer = LogicTransformer.new()
      local map = transformer:get_operator_map()

      assert.is_table(map)
      assert.are.equal("+", map["+"])
      assert.are.equal("~=", map["!="])
    end)
  end)
end)

describe("Converter variable integration", function()
  local transformers

  before_each(function()
    -- Clear cached modules
    for k in pairs(package.loaded) do
      if k:match("^whisker%.formats%.ink") then
        package.loaded[k] = nil
      end
    end

    transformers = require("whisker.formats.ink.transformers")
  end)

  describe("transformers registry", function()
    it("should include variable transformer", function()
      local list = transformers.list()
      local has_var = false
      for _, name in ipairs(list) do
        if name == "variable" then
          has_var = true
          break
        end
      end
      assert.is_true(has_var)
    end)

    it("should include logic transformer", function()
      local list = transformers.list()
      local has_logic = false
      for _, name in ipairs(list) do
        if name == "logic" then
          has_logic = true
          break
        end
      end
      assert.is_true(has_logic)
    end)

    it("should create variable transformer", function()
      local variable = transformers.create("variable")
      assert.is_table(variable)
      assert.is_function(variable.transform)
    end)

    it("should create logic transformer", function()
      local logic = transformers.create("logic")
      assert.is_table(logic)
      assert.is_function(logic.transform_operator)
    end)
  end)
end)
