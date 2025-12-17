-- tests/unit/script/semantic/analyzer_spec.lua
-- Tests for the SemanticAnalyzer

describe("SemanticAnalyzer", function()
  local SemanticAnalyzer
  local Node, NodeType
  local codes
  local source_module

  before_each(function()
    -- Clear cached modules
    package.loaded["whisker.script.semantic"] = nil
    package.loaded["whisker.script.semantic.resolver"] = nil
    package.loaded["whisker.script.semantic.validator"] = nil
    package.loaded["whisker.script.semantic.symbols"] = nil
    package.loaded["whisker.script.parser.ast"] = nil
    package.loaded["whisker.script.errors.codes"] = nil
    package.loaded["whisker.script.source"] = nil

    local semantic = require("whisker.script.semantic")
    SemanticAnalyzer = semantic.SemanticAnalyzer

    local ast = require("whisker.script.parser.ast")
    Node = ast.Node
    NodeType = ast.NodeType

    codes = require("whisker.script.errors.codes")
    source_module = require("whisker.script.source")
  end)

  local function make_pos(line, col)
    return source_module.SourcePosition.new(line, col, (line - 1) * 80 + col)
  end

  describe("module structure", function()
    it("should load without error", function()
      local ok, mod = pcall(require, "whisker.script.semantic")
      assert.is_true(ok, "Failed to load whisker.script.semantic")
      assert.is_table(mod)
    end)

    it("should have _whisker metadata", function()
      local mod = require("whisker.script.semantic")
      assert.is_table(mod._whisker)
      assert.are.equal("script.semantic", mod._whisker.name)
    end)

    it("should have new() factory function", function()
      local mod = require("whisker.script.semantic")
      assert.is_function(mod.new)
    end)

    it("should have SemanticAnalyzer class", function()
      local mod = require("whisker.script.semantic")
      assert.is_table(mod.SemanticAnalyzer)
    end)
  end)

  describe("analyze()", function()
    it("should handle nil AST", function()
      local analyzer = SemanticAnalyzer.new()
      local result = analyzer:analyze(nil)
      assert.is_nil(result)
    end)

    it("should return annotated AST", function()
      local analyzer = SemanticAnalyzer.new()
      local ast = Node.script({}, {}, {
        Node.passage("Start", {}, {
          Node.text({ "Hello world" }, make_pos(2, 1))
        }, make_pos(1, 1))
      })

      local result = analyzer:analyze(ast)
      assert.is_not_nil(result)
      assert.are.equal("Script", result.type)
    end)

    it("should build symbol table", function()
      local analyzer = SemanticAnalyzer.new()
      local ast = Node.script({}, {}, {
        Node.passage("Start", {}, {}, make_pos(1, 1)),
        Node.passage("End", {}, {}, make_pos(5, 1))
      })

      analyzer:analyze(ast)

      local symbols = analyzer:get_symbols()
      assert.is_not_nil(symbols)

      local passages = symbols:all_passages()
      assert.are.equal(2, #passages)
    end)
  end)

  describe("duplicate passage detection", function()
    it("should detect duplicate passages", function()
      local analyzer = SemanticAnalyzer.new()
      local ast = Node.script({}, {}, {
        Node.passage("Start", {}, {}, make_pos(1, 1)),
        Node.passage("Start", {}, {}, make_pos(5, 1))  -- duplicate
      })

      analyzer:analyze(ast)

      local diagnostics = analyzer:get_diagnostics()
      assert.are.equal(1, #diagnostics)
      assert.are.equal(codes.Semantic.DUPLICATE_PASSAGE, diagnostics[1].code)
    end)

    it("should allow different passage names", function()
      local analyzer = SemanticAnalyzer.new()
      local ast = Node.script({}, {}, {
        Node.passage("Start", {}, {}, make_pos(1, 1)),
        Node.passage("Middle", {}, {}, make_pos(5, 1)),
        Node.passage("End", {}, {}, make_pos(9, 1))
      })

      analyzer:analyze(ast)

      local errors = analyzer:get_errors()
      assert.are.equal(0, #errors)
    end)
  end)

  describe("get_errors() and get_warnings()", function()
    it("should separate errors and warnings", function()
      local analyzer = SemanticAnalyzer.new()
      local ast = Node.script({}, {}, {
        Node.passage("Start", {}, {
          Node.divert("NonExistent", {}, make_pos(2, 1)),  -- error
          Node.text({ Node.variable_ref("unset", nil, make_pos(3, 3)) }, make_pos(3, 1))  -- warning
        }, make_pos(1, 1))
      })

      analyzer:analyze(ast)

      local errors = analyzer:get_errors()
      local warnings = analyzer:get_warnings()

      assert.is_true(#errors >= 1)
      assert.is_true(#warnings >= 1)
    end)
  end)

  describe("has_errors()", function()
    it("should return false for valid script", function()
      local analyzer = SemanticAnalyzer.new()
      local ast = Node.script({}, {}, {
        Node.passage("Start", {}, {
          Node.text({ "Hello" }, make_pos(2, 1))
        }, make_pos(1, 1))
      })

      analyzer:analyze(ast)
      assert.is_false(analyzer:has_errors())
    end)

    it("should return true when errors present", function()
      local analyzer = SemanticAnalyzer.new()
      local ast = Node.script({}, {}, {
        Node.passage("Start", {}, {}, make_pos(1, 1)),
        Node.passage("Start", {}, {}, make_pos(5, 1))  -- duplicate
      })

      analyzer:analyze(ast)
      assert.is_true(analyzer:has_errors())
    end)
  end)

  describe("valid script analysis", function()
    it("should produce no errors for well-formed script", function()
      local analyzer = SemanticAnalyzer.new()

      local var_ref = Node.variable_ref("gold", nil, make_pos(3, 3))

      local ast = Node.script({}, {}, {
        Node.passage("Start", {}, {
          Node.text({ "Welcome to the adventure!" }, make_pos(2, 1)),
          Node.assignment(
            var_ref,
            "=",
            Node.literal(100, "number", make_pos(3, 12)),
            make_pos(3, 1)
          ),
          Node.choice(
            Node.text({ "Go to town" }, make_pos(4, 5)),
            nil,
            Node.divert("Town", {}, make_pos(4, 20)),
            {},
            false,
            make_pos(4, 1)
          ),
          Node.choice(
            Node.text({ "Go to forest" }, make_pos(5, 5)),
            nil,
            Node.divert("Forest", {}, make_pos(5, 22)),
            {},
            false,
            make_pos(5, 1)
          )
        }, make_pos(1, 1)),
        Node.passage("Town", {}, {
          Node.text({ "You arrive in town." }, make_pos(8, 1))
        }, make_pos(7, 1)),
        Node.passage("Forest", {}, {
          Node.text({ "Dark trees surround you." }, make_pos(11, 1))
        }, make_pos(10, 1))
      })

      analyzer:analyze(ast)

      local errors = analyzer:get_errors()
      assert.are.equal(0, #errors)
    end)
  end)

  describe("integration with resolver and validator", function()
    it("should collect diagnostics from all phases", function()
      local analyzer = SemanticAnalyzer.new()

      -- Script with multiple issues:
      -- 1. Duplicate passage (caught by analyzer)
      -- 2. Undefined passage reference (caught by resolver)
      -- 3. Unknown function (caught by resolver)
      local ast = Node.script({}, {}, {
        Node.passage("Start", {}, {
          Node.divert("Missing", {}, make_pos(2, 1)),
          Node.text({
            Node.inline_expr(
              Node.function_call("badFunc", {}, make_pos(3, 3)),
              make_pos(3, 1)
            )
          }, make_pos(3, 1))
        }, make_pos(1, 1)),
        Node.passage("Start", {}, {}, make_pos(5, 1))  -- duplicate
      })

      analyzer:analyze(ast)

      local diagnostics = analyzer:get_diagnostics()
      -- Should have at least 3 diagnostics: duplicate, undefined passage, unknown function
      assert.is_true(#diagnostics >= 3)

      -- Check that we got the expected error types
      local has_duplicate = false
      local has_undefined_passage = false
      local has_undefined_function = false

      for _, d in ipairs(diagnostics) do
        if d.code == codes.Semantic.DUPLICATE_PASSAGE then
          has_duplicate = true
        elseif d.code == codes.Semantic.UNDEFINED_PASSAGE then
          has_undefined_passage = true
        elseif d.code == codes.Semantic.UNDEFINED_FUNCTION then
          has_undefined_function = true
        end
      end

      assert.is_true(has_duplicate)
      assert.is_true(has_undefined_passage)
      assert.is_true(has_undefined_function)
    end)
  end)
end)
