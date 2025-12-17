-- lib/whisker/script/semantic/symbols.lua
-- Symbol table and scope management for Whisker Script

local M = {}

-- ============================================
-- Symbol Class
-- ============================================

local Symbol = {}
Symbol.__index = Symbol

--- Symbol kinds
M.SymbolKind = {
  PASSAGE = "passage",
  VARIABLE = "variable",
  FUNCTION = "function",
  PARAMETER = "parameter",
}

--- Create a new symbol
-- @param name string Symbol name
-- @param kind string Symbol kind from SymbolKind
-- @param position table Source position of declaration
-- @return Symbol
function Symbol.new(name, kind, position)
  return setmetatable({
    name = name,
    kind = kind,
    position = position,
    type_info = nil,
    references = {},
    initialized = kind ~= M.SymbolKind.VARIABLE,  -- Variables start uninitialized
  }, Symbol)
end

--- Add a reference to this symbol
-- @param position table Source position of reference
function Symbol:add_reference(position)
  table.insert(self.references, position)
end

--- Mark variable as initialized
function Symbol:mark_initialized()
  self.initialized = true
end

--- Check if symbol is initialized
-- @return boolean
function Symbol:is_initialized()
  return self.initialized
end

--- String representation
function Symbol:__tostring()
  return string.format("Symbol(%s, %s)", self.name, self.kind)
end

M.Symbol = Symbol

-- ============================================
-- Scope Class
-- ============================================

local Scope = {}
Scope.__index = Scope

--- Scope kinds
M.ScopeKind = {
  GLOBAL = "global",
  PASSAGE = "passage",
  CHOICE = "choice",
  CONDITIONAL = "conditional",
  BLOCK = "block",
}

--- Create a new scope
-- @param kind string Scope kind from ScopeKind
-- @param parent Scope|nil Parent scope
-- @return Scope
function Scope.new(kind, parent)
  return setmetatable({
    kind = kind,
    parent = parent,
    symbols = {},
    children = {},
  }, Scope)
end

--- Define a symbol in this scope
-- @param name string Symbol name
-- @param kind string Symbol kind
-- @param position table Source position
-- @return Symbol|nil, string|nil Symbol if successful, or nil and error message
function Scope:define(name, kind, position)
  -- Check for duplicate in same scope
  if self.symbols[name] then
    local existing = self.symbols[name]
    return nil, string.format("'%s' already defined at line %d",
      name, existing.position and existing.position.line or 0)
  end

  local symbol = Symbol.new(name, kind, position)
  self.symbols[name] = symbol
  return symbol, nil
end

--- Lookup a symbol in this scope only
-- @param name string Symbol name
-- @return Symbol|nil
function Scope:lookup_local(name)
  return self.symbols[name]
end

--- Lookup a symbol in this scope or parent scopes
-- @param name string Symbol name
-- @return Symbol|nil
function Scope:lookup(name)
  local symbol = self.symbols[name]
  if symbol then
    return symbol
  end
  if self.parent then
    return self.parent:lookup(name)
  end
  return nil
end

--- Get all symbols in this scope
-- @return table Array of Symbol
function Scope:all_symbols()
  local result = {}
  for _, symbol in pairs(self.symbols) do
    table.insert(result, symbol)
  end
  return result
end

--- Get all symbols of a specific kind in this scope
-- @param kind string Symbol kind
-- @return table Array of Symbol
function Scope:symbols_of_kind(kind)
  local result = {}
  for _, symbol in pairs(self.symbols) do
    if symbol.kind == kind then
      table.insert(result, symbol)
    end
  end
  return result
end

M.Scope = Scope

-- ============================================
-- SymbolTable Class
-- ============================================

local SymbolTable = {}
SymbolTable.__index = SymbolTable

--- Create a new symbol table
-- @return SymbolTable
function SymbolTable.new()
  local global = Scope.new(M.ScopeKind.GLOBAL, nil)
  return setmetatable({
    global_scope = global,
    current_scope = global,
    scope_stack = { global },
  }, SymbolTable)
end

--- Enter a new scope
-- @param kind string Scope kind
-- @return Scope The new scope
function SymbolTable:enter_scope(kind)
  local new_scope = Scope.new(kind, self.current_scope)
  table.insert(self.current_scope.children, new_scope)
  table.insert(self.scope_stack, new_scope)
  self.current_scope = new_scope
  return new_scope
end

--- Exit the current scope
-- @return Scope The exited scope
function SymbolTable:exit_scope()
  if #self.scope_stack <= 1 then
    error("Cannot exit global scope")
  end

  local exited = table.remove(self.scope_stack)
  self.current_scope = self.scope_stack[#self.scope_stack]
  return exited
end

--- Define a symbol in the current scope
-- @param name string Symbol name
-- @param kind string Symbol kind
-- @param position table Source position
-- @return Symbol|nil, string|nil Symbol if successful, or nil and error message
function SymbolTable:define(name, kind, position)
  return self.current_scope:define(name, kind, position)
end

--- Define a symbol in the global scope (for passages)
-- @param name string Symbol name
-- @param kind string Symbol kind
-- @param position table Source position
-- @return Symbol|nil, string|nil
function SymbolTable:define_global(name, kind, position)
  return self.global_scope:define(name, kind, position)
end

--- Lookup a symbol starting from current scope
-- @param name string Symbol name
-- @return Symbol|nil
function SymbolTable:lookup(name)
  return self.current_scope:lookup(name)
end

--- Lookup a symbol only in current scope
-- @param name string Symbol name
-- @return Symbol|nil
function SymbolTable:lookup_local(name)
  return self.current_scope:lookup_local(name)
end

--- Lookup a symbol in global scope only
-- @param name string Symbol name
-- @return Symbol|nil
function SymbolTable:lookup_global(name)
  return self.global_scope:lookup_local(name)
end

--- Get all passage symbols
-- @return table Array of Symbol
function SymbolTable:all_passages()
  return self.global_scope:symbols_of_kind(M.SymbolKind.PASSAGE)
end

--- Get all variable symbols from all scopes
-- @return table Array of Symbol
function SymbolTable:all_variables()
  local result = {}
  local function collect(scope)
    for _, sym in ipairs(scope:symbols_of_kind(M.SymbolKind.VARIABLE)) do
      table.insert(result, sym)
    end
    for _, child in ipairs(scope.children) do
      collect(child)
    end
  end
  collect(self.global_scope)
  return result
end

--- Get current scope kind
-- @return string
function SymbolTable:current_scope_kind()
  return self.current_scope.kind
end

--- Check if currently in global scope
-- @return boolean
function SymbolTable:is_global_scope()
  return self.current_scope == self.global_scope
end

--- Get scope depth
-- @return number
function SymbolTable:scope_depth()
  return #self.scope_stack
end

M.SymbolTable = SymbolTable

--- Module metadata
M._whisker = {
  name = "script.semantic.symbols",
  version = "0.1.0",
  description = "Symbol table and scope management for Whisker Script",
  depends = {},
  capability = "script.semantic.symbols"
}

return M
