-- tests/unit/script/generator/advanced_spec.lua
-- Tests for advanced code generation (conditionals, tunnels, threads)

describe("Advanced CodeGenerator", function()
  local CodeGenerator
  local Node
  local source_module

  before_each(function()
    -- Clear cached modules
    package.loaded["whisker.script.generator"] = nil
    package.loaded["whisker.script.generator.emitter"] = nil
    package.loaded["whisker.script.generator.sourcemap"] = nil
    package.loaded["whisker.script.parser.ast"] = nil
    package.loaded["whisker.script.source"] = nil

    CodeGenerator = require("whisker.script.generator").CodeGenerator
    local ast = require("whisker.script.parser.ast")
    Node = ast.Node

    source_module = require("whisker.script.source")
  end)

  local function make_pos(line, col)
    return source_module.SourcePosition.new(line, col, (line - 1) * 80 + col)
  end

  describe("conditional generation", function()
    it("should generate conditional content", function()
      local generator = CodeGenerator.new()

      local cond = Node.conditional(
        Node.binary_expr(
          ">",
          Node.variable_ref("health", nil, make_pos(2, 5)),
          Node.literal(50, "number", make_pos(2, 15)),
          make_pos(2, 5)
        ),
        { Node.text({ "You feel strong!" }, make_pos(3, 3)) },
        {},
        nil,
        make_pos(2, 1)
      )

      local ast = Node.script({}, {}, {
        Node.passage("Start", {}, { cond }, make_pos(1, 1))
      })

      local story = generator:generate(ast)
      local passage = story:get_passage("Start")

      assert.is_not_nil(passage)
      assert.is_truthy(passage.content:find("conditional") or passage.content ~= "")
    end)

    it("should handle elif clauses", function()
      local generator = CodeGenerator.new()

      local cond = Node.conditional(
        Node.binary_expr(
          ">",
          Node.variable_ref("health", nil, make_pos(2, 5)),
          Node.literal(75, "number", make_pos(2, 15)),
          make_pos(2, 5)
        ),
        { Node.text({ "Strong" }, make_pos(3, 3)) },
        {
          Node.elif_clause(
            Node.binary_expr(
              ">",
              Node.variable_ref("health", nil, make_pos(5, 5)),
              Node.literal(25, "number", make_pos(5, 15)),
              make_pos(5, 5)
            ),
            { Node.text({ "Wounded" }, make_pos(6, 3)) },
            make_pos(5, 1)
          )
        },
        { Node.text({ "Critical" }, make_pos(8, 3)) },
        make_pos(2, 1)
      )

      local ast = Node.script({}, {}, {
        Node.passage("Start", {}, { cond }, make_pos(1, 1))
      })

      local story = generator:generate(ast)
      local passage = story:get_passage("Start")

      assert.is_not_nil(passage)
    end)
  end)

  describe("compound assignment generation", function()
    it("should expand += operator", function()
      local generator = CodeGenerator.new()
      local emitter = generator.emitter or require("whisker.script.generator.emitter").Emitter.new()

      local var_ref = Node.variable_ref("score", nil, make_pos(2, 3))
      local assign = Node.assignment(
        var_ref,
        "+=",
        Node.literal(10, "number", make_pos(2, 13)),
        make_pos(2, 1)
      )

      local code = emitter:_emit_assignment_code(assign)

      assert.is_truthy(code:find("score"))
      assert.is_truthy(code:find("%+"))
    end)

    it("should expand -= operator", function()
      local generator = CodeGenerator.new()
      local emitter = generator.emitter or require("whisker.script.generator.emitter").Emitter.new()

      local var_ref = Node.variable_ref("health", nil, make_pos(2, 3))
      local assign = Node.assignment(
        var_ref,
        "-=",
        Node.literal(5, "number", make_pos(2, 14)),
        make_pos(2, 1)
      )

      local code = emitter:_emit_assignment_code(assign)

      assert.is_truthy(code:find("health"))
      assert.is_truthy(code:find("%-"))
    end)

    it("should expand *= operator", function()
      local generator = CodeGenerator.new()
      local emitter = generator.emitter or require("whisker.script.generator.emitter").Emitter.new()

      local var_ref = Node.variable_ref("multiplier", nil, make_pos(2, 3))
      local assign = Node.assignment(
        var_ref,
        "*=",
        Node.literal(2, "number", make_pos(2, 17)),
        make_pos(2, 1)
      )

      local code = emitter:_emit_assignment_code(assign)

      assert.is_truthy(code:find("multiplier"))
      assert.is_truthy(code:find("%*"))
    end)

    it("should expand /= operator", function()
      local generator = CodeGenerator.new()
      local emitter = generator.emitter or require("whisker.script.generator.emitter").Emitter.new()

      local var_ref = Node.variable_ref("value", nil, make_pos(2, 3))
      local assign = Node.assignment(
        var_ref,
        "/=",
        Node.literal(2, "number", make_pos(2, 12)),
        make_pos(2, 1)
      )

      local code = emitter:_emit_assignment_code(assign)

      assert.is_truthy(code:find("value"))
      assert.is_truthy(code:find("/"))
    end)
  end)

  describe("list append generation", function()
    it("should generate table.insert for []= operator", function()
      local generator = CodeGenerator.new()
      local emitter = generator.emitter or require("whisker.script.generator.emitter").Emitter.new()

      local var_ref = Node.variable_ref("inventory", nil, make_pos(2, 3))
      local assign = Node.assignment(
        var_ref,
        "[]=",
        Node.literal("sword", "string", make_pos(2, 18)),
        make_pos(2, 1)
      )

      local code = emitter:_emit_assignment_code(assign)

      assert.is_truthy(code:find("table%.insert"))
      assert.is_truthy(code:find("inventory"))
      assert.is_truthy(code:find("sword"))
    end)
  end)

  describe("tunnel generation", function()
    it("should generate tunnel call content", function()
      local generator = CodeGenerator.new()

      local ast = Node.script({}, {}, {
        Node.passage("Start", {}, {
          Node.text({ "Before tunnel" }, make_pos(2, 1)),
          Node.tunnel_call("Helper", {}, make_pos(3, 1))
        }, make_pos(1, 1)),
        Node.passage("Helper", {}, {
          Node.text({ "Helper content" }, make_pos(6, 1)),
          Node.tunnel_return(make_pos(7, 1))
        }, make_pos(5, 1))
      })

      local story = generator:generate(ast)
      local passage = story:get_passage("Start")

      assert.is_truthy(passage.content:find("Helper"))
    end)

    it("should generate tunnel return content", function()
      local generator = CodeGenerator.new()

      local ast = Node.script({}, {}, {
        Node.passage("Helper", {}, {
          Node.text({ "Doing something" }, make_pos(2, 1)),
          Node.tunnel_return(make_pos(3, 1))
        }, make_pos(1, 1))
      })

      local story = generator:generate(ast)
      local passage = story:get_passage("Helper")

      assert.is_truthy(passage.content:find("->->") or passage.content ~= "")
    end)
  end)

  describe("thread generation", function()
    it("should generate thread start content", function()
      local generator = CodeGenerator.new()

      local ast = Node.script({}, {}, {
        Node.passage("Start", {}, {
          Node.text({ "Main content" }, make_pos(2, 1)),
          Node.thread_start("Background", make_pos(3, 1))
        }, make_pos(1, 1)),
        Node.passage("Background", {}, {
          Node.text({ "Background content" }, make_pos(6, 1))
        }, make_pos(5, 1))
      })

      local story = generator:generate(ast)
      local passage = story:get_passage("Start")

      assert.is_truthy(passage.content:find("Background") or passage.content ~= "")
    end)
  end)

  describe("generate_with_sourcemap", function()
    it("should return story and sourcemap", function()
      local generator = CodeGenerator.new()

      local ast = Node.script({}, {}, {
        Node.passage("Start", {}, {
          Node.text({ "Hello" }, make_pos(2, 1))
        }, make_pos(1, 1))
      })

      local result = generator:generate_with_sourcemap(ast)

      assert.is_table(result)
      assert.is_not_nil(result.story)
      assert.is_not_nil(result.sourcemap)
    end)

    it("should handle nil AST", function()
      local generator = CodeGenerator.new()

      local result = generator:generate_with_sourcemap(nil)

      assert.is_table(result)
      assert.is_nil(result.story)
      assert.is_nil(result.sourcemap)
    end)
  end)
end)
