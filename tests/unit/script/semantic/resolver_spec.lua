-- tests/unit/script/semantic/resolver_spec.lua
-- Tests for reference resolution in semantic analysis

describe("Resolver", function()
  local Resolver
  local SymbolTable, SymbolKind, ScopeKind
  local Node, NodeType
  local codes
  local source_module

  before_each(function()
    -- Clear cached modules
    package.loaded["whisker.script.semantic.resolver"] = nil
    package.loaded["whisker.script.semantic.symbols"] = nil
    package.loaded["whisker.script.parser.ast"] = nil
    package.loaded["whisker.script.errors.codes"] = nil
    package.loaded["whisker.script.source"] = nil

    Resolver = require("whisker.script.semantic.resolver").Resolver
    local symbols = require("whisker.script.semantic.symbols")
    SymbolTable = symbols.SymbolTable
    SymbolKind = symbols.SymbolKind
    ScopeKind = symbols.ScopeKind

    local ast = require("whisker.script.parser.ast")
    Node = ast.Node
    NodeType = ast.NodeType

    codes = require("whisker.script.errors.codes")
    source_module = require("whisker.script.source")
  end)

  local function make_pos(line, col)
    return source_module.SourcePosition.new(line, col, (line - 1) * 80 + col)
  end

  describe("passage resolution", function()
    it("should resolve valid passage references", function()
      local symbols = SymbolTable.new()
      symbols:define_global("Start", SymbolKind.PASSAGE, make_pos(1, 1))
      symbols:define_global("Target", SymbolKind.PASSAGE, make_pos(10, 1))

      local ast = Node.script({}, {}, {
        Node.passage("Start", {}, {
          Node.divert("Target", {}, make_pos(5, 3))
        }, make_pos(1, 1))
      })

      local resolver = Resolver.new(symbols)
      resolver:resolve(ast)

      local diagnostics = resolver:get_diagnostics()
      assert.are.equal(0, #diagnostics)
    end)

    it("should report undefined passage", function()
      local symbols = SymbolTable.new()
      symbols:define_global("Start", SymbolKind.PASSAGE, make_pos(1, 1))

      local ast = Node.script({}, {}, {
        Node.passage("Start", {}, {
          Node.divert("NonExistent", {}, make_pos(5, 3))
        }, make_pos(1, 1))
      })

      local resolver = Resolver.new(symbols)
      resolver:resolve(ast)

      local diagnostics = resolver:get_diagnostics()
      assert.are.equal(1, #diagnostics)
      assert.are.equal(codes.Semantic.UNDEFINED_PASSAGE, diagnostics[1].code)
      assert.is_truthy(diagnostics[1].message:find("NonExistent"))
    end)

    it("should suggest similar passage names", function()
      local symbols = SymbolTable.new()
      symbols:define_global("Start", SymbolKind.PASSAGE, make_pos(1, 1))
      symbols:define_global("Kitchen", SymbolKind.PASSAGE, make_pos(10, 1))

      local ast = Node.script({}, {}, {
        Node.passage("Start", {}, {
          Node.divert("Kitchn", {}, make_pos(5, 3))  -- typo
        }, make_pos(1, 1))
      })

      local resolver = Resolver.new(symbols)
      resolver:resolve(ast)

      local diagnostics = resolver:get_diagnostics()
      assert.are.equal(1, #diagnostics)
      assert.is_truthy(diagnostics[1].suggestion)
      assert.is_truthy(diagnostics[1].suggestion:find("Kitchen"))
    end)

    it("should resolve tunnel call targets", function()
      local symbols = SymbolTable.new()
      symbols:define_global("Start", SymbolKind.PASSAGE, make_pos(1, 1))
      symbols:define_global("Helper", SymbolKind.PASSAGE, make_pos(10, 1))

      local ast = Node.script({}, {}, {
        Node.passage("Start", {}, {
          Node.tunnel_call("Helper", {}, make_pos(5, 3))
        }, make_pos(1, 1))
      })

      local resolver = Resolver.new(symbols)
      resolver:resolve(ast)

      local diagnostics = resolver:get_diagnostics()
      assert.are.equal(0, #diagnostics)
    end)

    it("should report undefined tunnel call target", function()
      local symbols = SymbolTable.new()
      symbols:define_global("Start", SymbolKind.PASSAGE, make_pos(1, 1))

      local ast = Node.script({}, {}, {
        Node.passage("Start", {}, {
          Node.tunnel_call("MissingHelper", {}, make_pos(5, 3))
        }, make_pos(1, 1))
      })

      local resolver = Resolver.new(symbols)
      resolver:resolve(ast)

      local diagnostics = resolver:get_diagnostics()
      assert.are.equal(1, #diagnostics)
      assert.are.equal(codes.Semantic.UNDEFINED_PASSAGE, diagnostics[1].code)
    end)

    it("should resolve thread start targets", function()
      local symbols = SymbolTable.new()
      symbols:define_global("Start", SymbolKind.PASSAGE, make_pos(1, 1))
      symbols:define_global("Background", SymbolKind.PASSAGE, make_pos(10, 1))

      local ast = Node.script({}, {}, {
        Node.passage("Start", {}, {
          Node.thread_start("Background", make_pos(5, 3))
        }, make_pos(1, 1))
      })

      local resolver = Resolver.new(symbols)
      resolver:resolve(ast)

      local diagnostics = resolver:get_diagnostics()
      assert.are.equal(0, #diagnostics)
    end)
  end)

  describe("variable resolution", function()
    it("should allow reading after assignment", function()
      local symbols = SymbolTable.new()
      symbols:define_global("Start", SymbolKind.PASSAGE, make_pos(1, 1))

      local var_ref = Node.variable_ref("counter", nil, make_pos(5, 3))
      local var_read = Node.variable_ref("counter", nil, make_pos(6, 3))

      local ast = Node.script({}, {}, {
        Node.passage("Start", {}, {
          Node.assignment(var_ref, "=", Node.literal(0, "number", make_pos(5, 14)), make_pos(5, 1)),
          Node.text({ var_read }, make_pos(6, 1))
        }, make_pos(1, 1))
      })

      local resolver = Resolver.new(symbols)
      resolver:resolve(ast)

      local diagnostics = resolver:get_diagnostics()
      -- Should have no errors (warnings are OK)
      local errors = {}
      for _, d in ipairs(diagnostics) do
        if d.severity == codes.Severity.ERROR then
          table.insert(errors, d)
        end
      end
      assert.are.equal(0, #errors)
    end)

    it("should warn on reading uninitialized variable", function()
      local symbols = SymbolTable.new()
      symbols:define_global("Start", SymbolKind.PASSAGE, make_pos(1, 1))

      local var_read = Node.variable_ref("undefined_var", nil, make_pos(5, 3))

      local ast = Node.script({}, {}, {
        Node.passage("Start", {}, {
          Node.text({ var_read }, make_pos(5, 1))
        }, make_pos(1, 1))
      })

      local resolver = Resolver.new(symbols)
      resolver:resolve(ast)

      local diagnostics = resolver:get_diagnostics()
      assert.is_true(#diagnostics >= 1)

      local found_warning = false
      for _, d in ipairs(diagnostics) do
        if d.code == codes.Semantic.UNINITIALIZED_VARIABLE then
          found_warning = true
          assert.are.equal(codes.Severity.WARNING, d.severity)
        end
      end
      assert.is_true(found_warning)
    end)
  end)

  describe("function resolution", function()
    it("should accept builtin functions with correct args", function()
      local symbols = SymbolTable.new()
      symbols:define_global("Start", SymbolKind.PASSAGE, make_pos(1, 1))

      local func_call = Node.function_call("abs", {
        Node.literal(-5, "number", make_pos(5, 8))
      }, make_pos(5, 3))

      local ast = Node.script({}, {}, {
        Node.passage("Start", {}, {
          Node.text({ Node.inline_expr(func_call, make_pos(5, 1)) }, make_pos(5, 1))
        }, make_pos(1, 1))
      })

      local resolver = Resolver.new(symbols)
      resolver:resolve(ast)

      local diagnostics = resolver:get_diagnostics()
      local errors = {}
      for _, d in ipairs(diagnostics) do
        if d.severity == codes.Severity.ERROR then
          table.insert(errors, d)
        end
      end
      assert.are.equal(0, #errors)
    end)

    it("should report unknown function", function()
      local symbols = SymbolTable.new()
      symbols:define_global("Start", SymbolKind.PASSAGE, make_pos(1, 1))

      local func_call = Node.function_call("unknown_func", {}, make_pos(5, 3))

      local ast = Node.script({}, {}, {
        Node.passage("Start", {}, {
          Node.text({ Node.inline_expr(func_call, make_pos(5, 1)) }, make_pos(5, 1))
        }, make_pos(1, 1))
      })

      local resolver = Resolver.new(symbols)
      resolver:resolve(ast)

      local diagnostics = resolver:get_diagnostics()
      assert.are.equal(1, #diagnostics)
      assert.are.equal(codes.Semantic.UNDEFINED_FUNCTION, diagnostics[1].code)
    end)

    it("should suggest similar function names", function()
      local symbols = SymbolTable.new()
      symbols:define_global("Start", SymbolKind.PASSAGE, make_pos(1, 1))

      local func_call = Node.function_call("abss", {  -- typo
        Node.literal(-5, "number", make_pos(5, 9))
      }, make_pos(5, 3))

      local ast = Node.script({}, {}, {
        Node.passage("Start", {}, {
          Node.text({ Node.inline_expr(func_call, make_pos(5, 1)) }, make_pos(5, 1))
        }, make_pos(1, 1))
      })

      local resolver = Resolver.new(symbols)
      resolver:resolve(ast)

      local diagnostics = resolver:get_diagnostics()
      assert.are.equal(1, #diagnostics)
      assert.is_truthy(diagnostics[1].suggestion)
      assert.is_truthy(diagnostics[1].suggestion:find("abs"))
    end)

    it("should report wrong argument count", function()
      local symbols = SymbolTable.new()
      symbols:define_global("Start", SymbolKind.PASSAGE, make_pos(1, 1))

      -- abs() expects exactly 1 argument
      local func_call = Node.function_call("abs", {}, make_pos(5, 3))

      local ast = Node.script({}, {}, {
        Node.passage("Start", {}, {
          Node.text({ Node.inline_expr(func_call, make_pos(5, 1)) }, make_pos(5, 1))
        }, make_pos(1, 1))
      })

      local resolver = Resolver.new(symbols)
      resolver:resolve(ast)

      local diagnostics = resolver:get_diagnostics()
      assert.are.equal(1, #diagnostics)
      assert.are.equal(codes.Semantic.WRONG_ARGUMENT_COUNT, diagnostics[1].code)
    end)

    it("should accept functions with variable argument counts", function()
      local symbols = SymbolTable.new()
      symbols:define_global("Start", SymbolKind.PASSAGE, make_pos(1, 1))

      -- random() accepts 0, 1, or 2 arguments
      local func_call = Node.function_call("random", {
        Node.literal(1, "number", make_pos(5, 10)),
        Node.literal(10, "number", make_pos(5, 13))
      }, make_pos(5, 3))

      local ast = Node.script({}, {}, {
        Node.passage("Start", {}, {
          Node.text({ Node.inline_expr(func_call, make_pos(5, 1)) }, make_pos(5, 1))
        }, make_pos(1, 1))
      })

      local resolver = Resolver.new(symbols)
      resolver:resolve(ast)

      local diagnostics = resolver:get_diagnostics()
      local errors = {}
      for _, d in ipairs(diagnostics) do
        if d.severity == codes.Severity.ERROR then
          table.insert(errors, d)
        end
      end
      assert.are.equal(0, #errors)
    end)
  end)

  describe("levenshtein_distance", function()
    local levenshtein = require("whisker.script.semantic.resolver").levenshtein_distance

    it("should return 0 for identical strings", function()
      assert.are.equal(0, levenshtein("hello", "hello"))
    end)

    it("should return length for empty vs non-empty", function()
      assert.are.equal(5, levenshtein("", "hello"))
      assert.are.equal(5, levenshtein("hello", ""))
    end)

    it("should calculate edit distance correctly", function()
      assert.are.equal(1, levenshtein("kitten", "sitten"))  -- substitution
      assert.are.equal(1, levenshtein("hello", "helo"))     -- deletion
      assert.are.equal(1, levenshtein("helo", "hello"))     -- insertion
      assert.are.equal(3, levenshtein("kitten", "sitting")) -- multiple edits
    end)
  end)
end)
