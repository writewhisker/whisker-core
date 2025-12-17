-- lib/whisker/script/semantic/init.lua
-- Semantic analyzer for Whisker Script

local symbols_module = require("whisker.script.semantic.symbols")
local SymbolTable = symbols_module.SymbolTable
local SymbolKind = symbols_module.SymbolKind

local resolver_module = require("whisker.script.semantic.resolver")
local Resolver = resolver_module.Resolver

local validator_module = require("whisker.script.semantic.validator")
local Validator = validator_module.Validator

local codes = require("whisker.script.errors.codes")

local M = {}

-- ============================================
-- SemanticAnalyzer Class
-- ============================================

local SemanticAnalyzer = {}
SemanticAnalyzer.__index = SemanticAnalyzer

--- Create a new semantic analyzer
-- @return SemanticAnalyzer
function SemanticAnalyzer.new()
  return setmetatable({
    symbol_table = nil,
    diagnostics = {},
  }, SemanticAnalyzer)
end

--- Analyze an AST for semantic correctness
-- @param ast table The AST to analyze
-- @return table Annotated AST
function SemanticAnalyzer:analyze(ast)
  -- Reset state for new analysis
  self.symbol_table = SymbolTable.new()
  self.diagnostics = {}

  if not ast then
    return ast
  end

  -- Phase 1: Collect all declarations (passages, global variables)
  self:_collect_declarations(ast)

  -- Phase 2: Resolve references and validate
  local resolver = Resolver.new(self.symbol_table)
  resolver:resolve(ast)
  self:_merge_diagnostics(resolver:get_diagnostics())

  -- Phase 3: Additional validation
  local validator = Validator.new(self.symbol_table)
  validator:validate(ast)
  self:_merge_diagnostics(validator:get_diagnostics())

  return ast
end

--- Get the symbol table built during analysis
-- @return SymbolTable
function SemanticAnalyzer:get_symbols()
  return self.symbol_table
end

--- Get all diagnostics (errors and warnings)
-- @return table Array of diagnostics
function SemanticAnalyzer:get_diagnostics()
  return self.diagnostics
end

--- Get only error diagnostics
-- @return table Array of errors
function SemanticAnalyzer:get_errors()
  local errors = {}
  for _, d in ipairs(self.diagnostics) do
    if d.severity == codes.Severity.ERROR then
      table.insert(errors, d)
    end
  end
  return errors
end

--- Get only warning diagnostics
-- @return table Array of warnings
function SemanticAnalyzer:get_warnings()
  local warnings = {}
  for _, d in ipairs(self.diagnostics) do
    if d.severity == codes.Severity.WARNING then
      table.insert(warnings, d)
    end
  end
  return warnings
end

--- Check if there are any errors
-- @return boolean
function SemanticAnalyzer:has_errors()
  for _, d in ipairs(self.diagnostics) do
    if d.severity == codes.Severity.ERROR then
      return true
    end
  end
  return false
end

--- Collect all declarations from AST (Phase 1)
-- @param ast table The AST
function SemanticAnalyzer:_collect_declarations(ast)
  -- Collect passages
  if ast.passages then
    for _, passage in ipairs(ast.passages) do
      local symbol, err = self.symbol_table:define_global(
        passage.name,
        SymbolKind.PASSAGE,
        passage.pos
      )
      if not symbol then
        -- Duplicate passage
        local existing = self.symbol_table:lookup_global(passage.name)
        self:_add_diagnostic({
          code = codes.Semantic.DUPLICATE_PASSAGE,
          message = codes.format_message(
            codes.Semantic.DUPLICATE_PASSAGE,
            passage.name,
            existing and existing.position and existing.position.line or 0
          ),
          severity = codes.Severity.ERROR,
          position = passage.pos,
        })
      end
    end
  end
end

--- Add a diagnostic to the list
-- @param diagnostic table Diagnostic to add
function SemanticAnalyzer:_add_diagnostic(diagnostic)
  table.insert(self.diagnostics, diagnostic)
end

--- Merge diagnostics from another source
-- @param other_diagnostics table Array of diagnostics to merge
function SemanticAnalyzer:_merge_diagnostics(other_diagnostics)
  for _, d in ipairs(other_diagnostics or {}) do
    table.insert(self.diagnostics, d)
  end
end

M.SemanticAnalyzer = SemanticAnalyzer

--- Convenience function to create analyzer
-- @return SemanticAnalyzer
function M.new()
  return SemanticAnalyzer.new()
end

--- Module metadata
M._whisker = {
  name = "script.semantic",
  version = "0.1.0",
  description = "Semantic analyzer for Whisker Script",
  depends = {
    "script.semantic.symbols",
    "script.semantic.resolver",
    "script.semantic.validator",
    "script.errors.codes"
  },
  capability = "script.semantic"
}

return M
