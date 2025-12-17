-- tests/unit/script/generator/basic_spec.lua
-- Tests for basic code generation

describe("CodeGenerator", function()
  local CodeGenerator
  local Node
  local source_module

  before_each(function()
    -- Clear cached modules
    package.loaded["whisker.script.generator"] = nil
    package.loaded["whisker.script.generator.emitter"] = nil
    package.loaded["whisker.script.parser.ast"] = nil
    package.loaded["whisker.script.source"] = nil
    package.loaded["whisker.core.story"] = nil
    package.loaded["whisker.core.passage"] = nil
    package.loaded["whisker.core.choice"] = nil

    CodeGenerator = require("whisker.script.generator").CodeGenerator
    local ast = require("whisker.script.parser.ast")
    Node = ast.Node

    source_module = require("whisker.script.source")
  end)

  local function make_pos(line, col)
    return source_module.SourcePosition.new(line, col, (line - 1) * 80 + col)
  end

  describe("module structure", function()
    it("should load without error", function()
      local ok, mod = pcall(require, "whisker.script.generator")
      assert.is_true(ok, "Failed to load whisker.script.generator")
      assert.is_table(mod)
    end)

    it("should have _whisker metadata", function()
      local mod = require("whisker.script.generator")
      assert.is_table(mod._whisker)
      assert.are.equal("script.generator", mod._whisker.name)
    end)

    it("should have new() factory function", function()
      local mod = require("whisker.script.generator")
      assert.is_function(mod.new)
    end)

    it("should have CodeGenerator class", function()
      local mod = require("whisker.script.generator")
      assert.is_table(mod.CodeGenerator)
    end)
  end)

  describe("generate()", function()
    it("should handle nil AST", function()
      local generator = CodeGenerator.new()
      local result = generator:generate(nil)
      assert.is_nil(result)
    end)

    it("should create Story from simple AST", function()
      local generator = CodeGenerator.new()

      local ast = Node.script({}, {}, {
        Node.passage("Start", {}, {
          Node.text({ "Hello world" }, make_pos(2, 1))
        }, make_pos(1, 1))
      })

      local story = generator:generate(ast)

      assert.is_not_nil(story)
      assert.is_not_nil(story.passages)
      assert.is_not_nil(story.passages["Start"])
    end)

    it("should extract metadata from AST", function()
      local generator = CodeGenerator.new()

      local ast = Node.script(
        {
          Node.metadata("title", "My Story", make_pos(1, 1)),
          Node.metadata("author", "Test Author", make_pos(2, 1))
        },
        {},
        {
          Node.passage("Start", {}, {}, make_pos(4, 1))
        }
      )

      local story = generator:generate(ast)

      assert.are.equal("My Story", story.metadata.name)
      assert.are.equal("Test Author", story.metadata.author)
    end)

    it("should set start passage to first passage", function()
      local generator = CodeGenerator.new()

      local ast = Node.script({}, {}, {
        Node.passage("FirstPassage", {}, {}, make_pos(1, 1)),
        Node.passage("SecondPassage", {}, {}, make_pos(5, 1))
      })

      local story = generator:generate(ast)

      assert.are.equal("FirstPassage", story:get_start_passage())
    end)
  end)

  describe("passage generation", function()
    it("should create passage with correct id and name", function()
      local generator = CodeGenerator.new()

      local ast = Node.script({}, {}, {
        Node.passage("MyPassage", {}, {
          Node.text({ "Content here" }, make_pos(2, 1))
        }, make_pos(1, 1))
      })

      local story = generator:generate(ast)
      local passage = story:get_passage("MyPassage")

      assert.is_not_nil(passage)
      assert.are.equal("MyPassage", passage.id)
      assert.are.equal("MyPassage", passage.name)
    end)

    it("should include tags in passage", function()
      local generator = CodeGenerator.new()

      local ast = Node.script({}, {}, {
        Node.passage("Tagged", {
          Node.tag("important", nil, make_pos(1, 12)),
          Node.tag("visited", nil, make_pos(1, 23))
        }, {}, make_pos(1, 1))
      })

      local story = generator:generate(ast)
      local passage = story:get_passage("Tagged")

      assert.is_true(passage:has_tag("important"))
      assert.is_true(passage:has_tag("visited"))
    end)

    it("should flatten text content", function()
      local generator = CodeGenerator.new()

      local ast = Node.script({}, {}, {
        Node.passage("TextTest", {}, {
          Node.text({ "Line one" }, make_pos(2, 1)),
          Node.text({ "Line two" }, make_pos(3, 1))
        }, make_pos(1, 1))
      })

      local story = generator:generate(ast)
      local passage = story:get_passage("TextTest")

      assert.is_truthy(passage.content:find("Line one"))
      assert.is_truthy(passage.content:find("Line two"))
    end)
  end)

  describe("choice generation", function()
    it("should create choices from choice nodes", function()
      local generator = CodeGenerator.new()

      local ast = Node.script({}, {}, {
        Node.passage("Start", {}, {
          Node.choice(
            Node.text({ "Go north" }, make_pos(2, 5)),
            nil,
            Node.divert("North", {}, make_pos(2, 20)),
            {},
            false,
            make_pos(2, 1)
          )
        }, make_pos(1, 1)),
        Node.passage("North", {}, {}, make_pos(5, 1))
      })

      local story = generator:generate(ast)
      local passage = story:get_passage("Start")

      assert.are.equal(1, #passage.choices)
      assert.are.equal("Go north", passage.choices[1].text)
      assert.are.equal("North", passage.choices[1].target)
    end)

    it("should handle choice conditions", function()
      local generator = CodeGenerator.new()

      local condition = Node.binary_expr(
        ">",
        Node.variable_ref("gold", nil, make_pos(2, 7)),
        Node.literal(10, "number", make_pos(2, 15)),
        make_pos(2, 7)
      )

      local ast = Node.script({}, {}, {
        Node.passage("Shop", {}, {
          Node.choice(
            Node.text({ "Buy item" }, make_pos(2, 22)),
            condition,
            Node.divert("Bought", {}, make_pos(2, 35)),
            {},
            false,
            make_pos(2, 1)
          )
        }, make_pos(1, 1)),
        Node.passage("Bought", {}, {}, make_pos(5, 1))
      })

      local story = generator:generate(ast)
      local passage = story:get_passage("Shop")

      assert.are.equal(1, #passage.choices)
      assert.is_truthy(passage.choices[1].condition)
      assert.is_truthy(passage.choices[1].condition:find("gold"))
    end)

    it("should generate choice action from body", function()
      local generator = CodeGenerator.new()

      local var_ref = Node.variable_ref("gold", nil, make_pos(3, 5))
      local assignment = Node.assignment(
        var_ref,
        "-=",
        Node.literal(10, "number", make_pos(3, 15)),
        make_pos(3, 3)
      )

      local ast = Node.script({}, {}, {
        Node.passage("Shop", {}, {
          Node.choice(
            Node.text({ "Buy item" }, make_pos(2, 5)),
            nil,
            Node.divert("Bought", {}, make_pos(2, 20)),
            { assignment },
            false,
            make_pos(2, 1)
          )
        }, make_pos(1, 1)),
        Node.passage("Bought", {}, {}, make_pos(6, 1))
      })

      local story = generator:generate(ast)
      local passage = story:get_passage("Shop")

      assert.are.equal(1, #passage.choices)
      assert.is_truthy(passage.choices[1].action)
      assert.is_truthy(passage.choices[1].action:find("gold"))
    end)
  end)

  describe("variable generation", function()
    it("should generate variable reference code", function()
      local generator = CodeGenerator.new()

      local var_ref = Node.variable_ref("player_name", nil, make_pos(2, 3))

      local ast = Node.script({}, {}, {
        Node.passage("Start", {}, {
          Node.text({
            "Hello ",
            Node.inline_expr(var_ref, make_pos(2, 7))
          }, make_pos(2, 1))
        }, make_pos(1, 1))
      })

      local story = generator:generate(ast)
      local passage = story:get_passage("Start")

      assert.is_truthy(passage.content:find("player_name"))
    end)

    it("should handle indexed variable access", function()
      local generator = CodeGenerator.new()

      local var_ref = Node.variable_ref(
        "inventory",
        Node.literal(0, "number", make_pos(2, 16)),
        make_pos(2, 3)
      )

      local ast = Node.script({}, {}, {
        Node.passage("Start", {}, {
          Node.text({
            Node.inline_expr(var_ref, make_pos(2, 1))
          }, make_pos(2, 1))
        }, make_pos(1, 1))
      })

      local story = generator:generate(ast)
      local passage = story:get_passage("Start")

      assert.is_truthy(passage.content:find("inventory"))
    end)
  end)

  describe("expression generation", function()
    it("should generate number literals", function()
      local generator = CodeGenerator.new()
      local emitter = generator.emitter

      local node = Node.literal(42, "number", make_pos(1, 1))
      local code = emitter:_emit_expression_code(node)

      assert.are.equal("42", code)
    end)

    it("should generate string literals", function()
      local generator = CodeGenerator.new()
      local emitter = generator.emitter

      local node = Node.literal("hello", "string", make_pos(1, 1))
      local code = emitter:_emit_expression_code(node)

      assert.are.equal('"hello"', code)
    end)

    it("should generate boolean literals", function()
      local generator = CodeGenerator.new()
      local emitter = generator.emitter

      local true_node = Node.literal(true, "boolean", make_pos(1, 1))
      local false_node = Node.literal(false, "boolean", make_pos(1, 1))

      assert.are.equal("true", emitter:_emit_expression_code(true_node))
      assert.are.equal("false", emitter:_emit_expression_code(false_node))
    end)

    it("should generate binary expressions", function()
      local generator = CodeGenerator.new()
      local emitter = generator.emitter

      local node = Node.binary_expr(
        "+",
        Node.literal(1, "number", make_pos(1, 1)),
        Node.literal(2, "number", make_pos(1, 5)),
        make_pos(1, 1)
      )

      local code = emitter:_emit_expression_code(node)
      assert.are.equal("(1 + 2)", code)
    end)

    it("should generate unary expressions", function()
      local generator = CodeGenerator.new()
      local emitter = generator.emitter

      local not_node = Node.unary_expr(
        "not",
        Node.literal(true, "boolean", make_pos(1, 5)),
        make_pos(1, 1)
      )

      local neg_node = Node.unary_expr(
        "-",
        Node.literal(5, "number", make_pos(1, 2)),
        make_pos(1, 1)
      )

      assert.are.equal("(not true)", emitter:_emit_expression_code(not_node))
      assert.are.equal("(-5)", emitter:_emit_expression_code(neg_node))
    end)

    it("should map != to ~=", function()
      local generator = CodeGenerator.new()
      local emitter = generator.emitter

      local node = Node.binary_expr(
        "!=",
        Node.literal(1, "number", make_pos(1, 1)),
        Node.literal(2, "number", make_pos(1, 6)),
        make_pos(1, 1)
      )

      local code = emitter:_emit_expression_code(node)
      assert.are.equal("(1 ~= 2)", code)
    end)

    it("should generate function calls", function()
      local generator = CodeGenerator.new()
      local emitter = generator.emitter

      local node = Node.function_call("abs", {
        Node.literal(-5, "number", make_pos(1, 5))
      }, make_pos(1, 1))

      local code = emitter:_emit_expression_code(node)
      assert.is_truthy(code:find("abs"))
      assert.is_truthy(code:find("-5"))
    end)

    it("should generate list literals", function()
      local generator = CodeGenerator.new()
      local emitter = generator.emitter

      local node = Node.list_literal({
        Node.literal(1, "number", make_pos(1, 2)),
        Node.literal(2, "number", make_pos(1, 5)),
        Node.literal(3, "number", make_pos(1, 8))
      }, make_pos(1, 1))

      local code = emitter:_emit_expression_code(node)
      assert.are.equal("{1, 2, 3}", code)
    end)
  end)

  describe("divert generation", function()
    it("should include divert in content", function()
      local generator = CodeGenerator.new()

      local ast = Node.script({}, {}, {
        Node.passage("Start", {}, {
          Node.text({ "Going somewhere" }, make_pos(2, 1)),
          Node.divert("Target", {}, make_pos(3, 1))
        }, make_pos(1, 1)),
        Node.passage("Target", {}, {}, make_pos(5, 1))
      })

      local story = generator:generate(ast)
      local passage = story:get_passage("Start")

      assert.is_truthy(passage.content:find("Target"))
    end)
  end)

  describe("inline conditional generation", function()
    it("should generate inline conditional text", function()
      local generator = CodeGenerator.new()

      local inline_cond = Node.inline_conditional(
        Node.binary_expr(
          ">",
          Node.variable_ref("gold", nil, make_pos(2, 3)),
          Node.literal(0, "number", make_pos(2, 11)),
          make_pos(2, 3)
        ),
        Node.text({ "rich" }, make_pos(2, 14)),
        Node.text({ "poor" }, make_pos(2, 21)),
        make_pos(2, 1)
      )

      local ast = Node.script({}, {}, {
        Node.passage("Start", {}, {
          Node.text({
            "You are ",
            inline_cond
          }, make_pos(2, 1))
        }, make_pos(1, 1))
      })

      local story = generator:generate(ast)
      local passage = story:get_passage("Start")

      assert.is_truthy(passage.content:find("gold"))
      assert.is_truthy(passage.content:find("rich"))
      assert.is_truthy(passage.content:find("poor"))
    end)
  end)
end)
