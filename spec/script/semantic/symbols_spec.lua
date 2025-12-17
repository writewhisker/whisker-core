-- spec/script/semantic/symbols_spec.lua
-- Tests for symbol table and scope management

describe("Symbol Table", function()
  local symbols_module
  local Symbol, Scope, SymbolTable
  local SymbolKind, ScopeKind

  before_each(function()
    for k in pairs(package.loaded) do
      if k:match("^whisker%.script") then
        package.loaded[k] = nil
      end
    end
    symbols_module = require("whisker.script.semantic.symbols")
    Symbol = symbols_module.Symbol
    Scope = symbols_module.Scope
    SymbolTable = symbols_module.SymbolTable
    SymbolKind = symbols_module.SymbolKind
    ScopeKind = symbols_module.ScopeKind
  end)

  describe("Symbol", function()
    it("should create symbol with name and kind", function()
      local pos = { line = 1, column = 1 }
      local sym = Symbol.new("test", SymbolKind.VARIABLE, pos)
      assert.are.equal("test", sym.name)
      assert.are.equal(SymbolKind.VARIABLE, sym.kind)
      assert.are.equal(1, sym.position.line)
    end)

    it("should track references", function()
      local sym = Symbol.new("x", SymbolKind.VARIABLE, { line = 1 })
      sym:add_reference({ line = 5 })
      sym:add_reference({ line = 10 })
      assert.are.equal(2, #sym.references)
    end)

    it("should track initialization for variables", function()
      local var = Symbol.new("x", SymbolKind.VARIABLE, { line = 1 })
      assert.is_false(var:is_initialized())
      var:mark_initialized()
      assert.is_true(var:is_initialized())
    end)

    it("should mark non-variables as initialized", function()
      local passage = Symbol.new("Start", SymbolKind.PASSAGE, { line = 1 })
      assert.is_true(passage:is_initialized())
    end)
  end)

  describe("Scope", function()
    it("should create scope with kind", function()
      local scope = Scope.new(ScopeKind.GLOBAL, nil)
      assert.are.equal(ScopeKind.GLOBAL, scope.kind)
      assert.is_nil(scope.parent)
    end)

    it("should define symbols", function()
      local scope = Scope.new(ScopeKind.GLOBAL, nil)
      local sym, err = scope:define("x", SymbolKind.VARIABLE, { line = 1 })
      assert.is_not_nil(sym)
      assert.is_nil(err)
      assert.are.equal("x", sym.name)
    end)

    it("should detect duplicates in same scope", function()
      local scope = Scope.new(ScopeKind.GLOBAL, nil)
      scope:define("x", SymbolKind.VARIABLE, { line = 1 })
      local sym, err = scope:define("x", SymbolKind.VARIABLE, { line = 5 })
      assert.is_nil(sym)
      assert.is_not_nil(err)
      assert.is_truthy(err:match("already defined"))
    end)

    it("should lookup local symbols", function()
      local scope = Scope.new(ScopeKind.GLOBAL, nil)
      scope:define("x", SymbolKind.VARIABLE, { line = 1 })
      local sym = scope:lookup_local("x")
      assert.is_not_nil(sym)
      assert.are.equal("x", sym.name)
    end)

    it("should return nil for undefined symbols", function()
      local scope = Scope.new(ScopeKind.GLOBAL, nil)
      local sym = scope:lookup_local("undefined")
      assert.is_nil(sym)
    end)

    it("should lookup in parent scopes", function()
      local parent = Scope.new(ScopeKind.GLOBAL, nil)
      parent:define("x", SymbolKind.VARIABLE, { line = 1 })

      local child = Scope.new(ScopeKind.PASSAGE, parent)
      local sym = child:lookup("x")
      assert.is_not_nil(sym)
      assert.are.equal("x", sym.name)
    end)

    it("should get all symbols", function()
      local scope = Scope.new(ScopeKind.GLOBAL, nil)
      scope:define("a", SymbolKind.VARIABLE, { line = 1 })
      scope:define("b", SymbolKind.PASSAGE, { line = 2 })
      local all = scope:all_symbols()
      assert.are.equal(2, #all)
    end)

    it("should filter symbols by kind", function()
      local scope = Scope.new(ScopeKind.GLOBAL, nil)
      scope:define("a", SymbolKind.VARIABLE, { line = 1 })
      scope:define("b", SymbolKind.PASSAGE, { line = 2 })
      scope:define("c", SymbolKind.VARIABLE, { line = 3 })
      local vars = scope:symbols_of_kind(SymbolKind.VARIABLE)
      assert.are.equal(2, #vars)
    end)
  end)

  describe("SymbolTable", function()
    it("should create with global scope", function()
      local st = SymbolTable.new()
      assert.is_true(st:is_global_scope())
      assert.are.equal(1, st:scope_depth())
    end)

    it("should define in current scope", function()
      local st = SymbolTable.new()
      local sym, err = st:define("x", SymbolKind.VARIABLE, { line = 1 })
      assert.is_not_nil(sym)
      assert.is_nil(err)
    end)

    it("should lookup defined symbols", function()
      local st = SymbolTable.new()
      st:define("x", SymbolKind.VARIABLE, { line = 1 })
      local sym = st:lookup("x")
      assert.is_not_nil(sym)
    end)

    it("should enter and exit scopes", function()
      local st = SymbolTable.new()
      assert.are.equal(1, st:scope_depth())

      st:enter_scope(ScopeKind.PASSAGE)
      assert.are.equal(2, st:scope_depth())
      assert.are.equal(ScopeKind.PASSAGE, st:current_scope_kind())

      st:exit_scope()
      assert.are.equal(1, st:scope_depth())
      assert.is_true(st:is_global_scope())
    end)

    it("should error when exiting global scope", function()
      local st = SymbolTable.new()
      assert.has_error(function()
        st:exit_scope()
      end)
    end)

    it("should lookup in nested scopes", function()
      local st = SymbolTable.new()
      st:define("global_var", SymbolKind.VARIABLE, { line = 1 })

      st:enter_scope(ScopeKind.PASSAGE)
      local sym = st:lookup("global_var")
      assert.is_not_nil(sym)
    end)

    it("should allow shadowing in nested scopes", function()
      local st = SymbolTable.new()
      st:define("x", SymbolKind.VARIABLE, { line = 1 })

      st:enter_scope(ScopeKind.PASSAGE)
      local sym, err = st:define("x", SymbolKind.VARIABLE, { line = 10 })
      assert.is_not_nil(sym)  -- Shadowing allowed
      assert.is_nil(err)

      -- Should find the local one
      local found = st:lookup("x")
      assert.are.equal(10, found.position.line)
    end)

    it("should define global symbols", function()
      local st = SymbolTable.new()
      st:enter_scope(ScopeKind.PASSAGE)
      st:define_global("Start", SymbolKind.PASSAGE, { line = 1 })

      local sym = st:lookup_global("Start")
      assert.is_not_nil(sym)
    end)

    it("should collect all passages", function()
      local st = SymbolTable.new()
      st:define_global("Start", SymbolKind.PASSAGE, { line = 1 })
      st:define_global("End", SymbolKind.PASSAGE, { line = 10 })
      st:define("x", SymbolKind.VARIABLE, { line = 5 })

      local passages = st:all_passages()
      assert.are.equal(2, #passages)
    end)

    it("should collect all variables", function()
      local st = SymbolTable.new()
      st:define("a", SymbolKind.VARIABLE, { line = 1 })
      st:enter_scope(ScopeKind.PASSAGE)
      st:define("b", SymbolKind.VARIABLE, { line = 5 })
      st:exit_scope()

      local vars = st:all_variables()
      assert.are.equal(2, #vars)
    end)

    it("should lookup local only", function()
      local st = SymbolTable.new()
      st:define("global_var", SymbolKind.VARIABLE, { line = 1 })

      st:enter_scope(ScopeKind.PASSAGE)
      assert.is_nil(st:lookup_local("global_var"))
      assert.is_not_nil(st:lookup("global_var"))
    end)
  end)

  describe("Integration scenarios", function()
    it("should handle passage with local variables", function()
      local st = SymbolTable.new()

      -- Define passages globally
      st:define_global("Start", SymbolKind.PASSAGE, { line = 1 })
      st:define_global("End", SymbolKind.PASSAGE, { line = 20 })

      -- Enter passage scope
      st:enter_scope(ScopeKind.PASSAGE)
      st:define("local_var", SymbolKind.VARIABLE, { line = 5 })

      -- Verify lookups
      assert.is_not_nil(st:lookup("Start"))  -- Can see global passage
      assert.is_not_nil(st:lookup("local_var"))  -- Can see local var

      st:exit_scope()

      -- Outside passage, local var not visible
      assert.is_nil(st:lookup("local_var"))
    end)

    it("should handle nested conditionals", function()
      local st = SymbolTable.new()
      st:define("x", SymbolKind.VARIABLE, { line = 1 })

      st:enter_scope(ScopeKind.PASSAGE)
      st:enter_scope(ScopeKind.CONDITIONAL)
      st:define("y", SymbolKind.VARIABLE, { line = 5 })

      st:enter_scope(ScopeKind.CONDITIONAL)
      st:define("z", SymbolKind.VARIABLE, { line = 10 })

      -- Can see all variables
      assert.is_not_nil(st:lookup("x"))
      assert.is_not_nil(st:lookup("y"))
      assert.is_not_nil(st:lookup("z"))

      assert.are.equal(4, st:scope_depth())
    end)
  end)
end)
