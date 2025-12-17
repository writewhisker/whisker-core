-- tests/unit/script/semantic/validator_spec.lua
-- Tests for validation rules in semantic analysis

describe("Validator", function()
  local Validator
  local SymbolTable, SymbolKind
  local Node, NodeType
  local codes
  local source_module

  before_each(function()
    -- Clear cached modules
    package.loaded["whisker.script.semantic.validator"] = nil
    package.loaded["whisker.script.semantic.symbols"] = nil
    package.loaded["whisker.script.parser.ast"] = nil
    package.loaded["whisker.script.errors.codes"] = nil
    package.loaded["whisker.script.source"] = nil

    Validator = require("whisker.script.semantic.validator").Validator
    local symbols = require("whisker.script.semantic.symbols")
    SymbolTable = symbols.SymbolTable
    SymbolKind = symbols.SymbolKind

    local ast = require("whisker.script.parser.ast")
    Node = ast.Node
    NodeType = ast.NodeType

    codes = require("whisker.script.errors.codes")
    source_module = require("whisker.script.source")
  end)

  local function make_pos(line, col)
    return source_module.SourcePosition.new(line, col, (line - 1) * 80 + col)
  end

  describe("tunnel return validation", function()
    it("should allow tunnel return inside passage", function()
      local symbols = SymbolTable.new()

      local ast = Node.script({}, {}, {
        Node.passage("Helper", {}, {
          Node.text({ "Helper content" }, make_pos(2, 1)),
          Node.tunnel_return(make_pos(3, 1))
        }, make_pos(1, 1))
      })

      local validator = Validator.new(symbols)
      validator:validate(ast)

      local diagnostics = validator:get_diagnostics()
      local errors = {}
      for _, d in ipairs(diagnostics) do
        if d.severity == codes.Severity.ERROR then
          table.insert(errors, d)
        end
      end
      assert.are.equal(0, #errors)
    end)
  end)

  describe("unreachable passage detection", function()
    it("should not warn about first passage (entry point)", function()
      local symbols = SymbolTable.new()

      local ast = Node.script({}, {}, {
        Node.passage("Start", {}, {
          Node.text({ "First passage" }, make_pos(2, 1))
        }, make_pos(1, 1))
      })

      local validator = Validator.new(symbols)
      validator:validate(ast)

      local diagnostics = validator:get_diagnostics()
      local unreachable_warnings = {}
      for _, d in ipairs(diagnostics) do
        if d.code == codes.Semantic.UNREACHABLE_PASSAGE then
          table.insert(unreachable_warnings, d)
        end
      end
      assert.are.equal(0, #unreachable_warnings)
    end)

    it("should warn about unreachable passages", function()
      local symbols = SymbolTable.new()

      local ast = Node.script({}, {}, {
        Node.passage("Start", {}, {
          Node.text({ "Go to middle" }, make_pos(2, 1)),
          Node.divert("Middle", {}, make_pos(3, 1))
        }, make_pos(1, 1)),
        Node.passage("Middle", {}, {
          Node.text({ "Middle passage" }, make_pos(6, 1))
        }, make_pos(5, 1)),
        Node.passage("Orphan", {}, {
          Node.text({ "Nobody comes here" }, make_pos(10, 1))
        }, make_pos(9, 1))
      })

      local validator = Validator.new(symbols)
      validator:validate(ast)

      local diagnostics = validator:get_diagnostics()
      local unreachable_warnings = {}
      for _, d in ipairs(diagnostics) do
        if d.code == codes.Semantic.UNREACHABLE_PASSAGE then
          table.insert(unreachable_warnings, d)
        end
      end
      assert.are.equal(1, #unreachable_warnings)
      assert.is_truthy(unreachable_warnings[1].message:find("Orphan"))
    end)

    it("should not warn about passages reached through choices", function()
      local symbols = SymbolTable.new()

      local ast = Node.script({}, {}, {
        Node.passage("Start", {}, {
          Node.choice(
            Node.text({ "Go left" }, make_pos(2, 5)),
            nil,
            Node.divert("Left", {}, make_pos(2, 20)),
            {},
            false,
            make_pos(2, 1)
          )
        }, make_pos(1, 1)),
        Node.passage("Left", {}, {
          Node.text({ "You went left" }, make_pos(6, 1))
        }, make_pos(5, 1))
      })

      local validator = Validator.new(symbols)
      validator:validate(ast)

      local diagnostics = validator:get_diagnostics()
      local unreachable_warnings = {}
      for _, d in ipairs(diagnostics) do
        if d.code == codes.Semantic.UNREACHABLE_PASSAGE then
          table.insert(unreachable_warnings, d)
        end
      end
      assert.are.equal(0, #unreachable_warnings)
    end)

    it("should not warn about passages with start tag", function()
      local symbols = SymbolTable.new()

      local ast = Node.script({}, {}, {
        Node.passage("Start", {}, {
          Node.text({ "Main story" }, make_pos(2, 1))
        }, make_pos(1, 1)),
        Node.passage("AltStart", { Node.tag("start", nil, make_pos(5, 15)) }, {
          Node.text({ "Alternative start" }, make_pos(6, 1))
        }, make_pos(5, 1))
      })

      local validator = Validator.new(symbols)
      validator:validate(ast)

      local diagnostics = validator:get_diagnostics()
      local unreachable_warnings = {}
      for _, d in ipairs(diagnostics) do
        if d.code == codes.Semantic.UNREACHABLE_PASSAGE then
          table.insert(unreachable_warnings, d)
        end
      end
      assert.are.equal(0, #unreachable_warnings)
    end)

    it("should track passages reached through tunnel calls", function()
      local symbols = SymbolTable.new()

      local ast = Node.script({}, {}, {
        Node.passage("Start", {}, {
          Node.tunnel_call("Helper", {}, make_pos(2, 1))
        }, make_pos(1, 1)),
        Node.passage("Helper", {}, {
          Node.text({ "Helper content" }, make_pos(6, 1)),
          Node.tunnel_return(make_pos(7, 1))
        }, make_pos(5, 1))
      })

      local validator = Validator.new(symbols)
      validator:validate(ast)

      local diagnostics = validator:get_diagnostics()
      local unreachable_warnings = {}
      for _, d in ipairs(diagnostics) do
        if d.code == codes.Semantic.UNREACHABLE_PASSAGE then
          table.insert(unreachable_warnings, d)
        end
      end
      assert.are.equal(0, #unreachable_warnings)
    end)

    it("should track passages reached through thread starts", function()
      local symbols = SymbolTable.new()

      local ast = Node.script({}, {}, {
        Node.passage("Start", {}, {
          Node.thread_start("Background", make_pos(2, 1))
        }, make_pos(1, 1)),
        Node.passage("Background", {}, {
          Node.text({ "Background content" }, make_pos(6, 1))
        }, make_pos(5, 1))
      })

      local validator = Validator.new(symbols)
      validator:validate(ast)

      local diagnostics = validator:get_diagnostics()
      local unreachable_warnings = {}
      for _, d in ipairs(diagnostics) do
        if d.code == codes.Semantic.UNREACHABLE_PASSAGE then
          table.insert(unreachable_warnings, d)
        end
      end
      assert.are.equal(0, #unreachable_warnings)
    end)
  end)
end)
