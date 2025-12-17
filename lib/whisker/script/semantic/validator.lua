-- lib/whisker/script/semantic/validator.lua
-- Additional validation rules for Whisker Script semantic analysis

local visitor_module = require("whisker.script.visitor")
local Visitor = visitor_module.Visitor
local get_children = visitor_module.get_children

local symbols_module = require("whisker.script.semantic.symbols")
local SymbolKind = symbols_module.SymbolKind

local codes = require("whisker.script.errors.codes")

local M = {}

-- ============================================
-- Validator Class
-- ============================================

local Validator = setmetatable({}, { __index = Visitor })
Validator.__index = Validator

--- Create a new validator
-- @param symbol_table SymbolTable Symbol table with declarations
-- @return Validator
function Validator.new(symbol_table)
  local self = setmetatable(Visitor.new(), { __index = Validator })
  self.symbols = symbol_table
  self.diagnostics = {}
  self.in_passage = false
  self.referenced_passages = {}
  return self
end

--- Validate an AST
-- @param ast table The AST to validate
function Validator:validate(ast)
  self.diagnostics = {}
  self.referenced_passages = {}

  -- Collect all referenced passages
  self:_collect_references(ast)

  -- Check for unreachable passages
  self:_check_unreachable_passages(ast)

  -- Validate individual nodes
  self:visit(ast)
end

--- Get accumulated diagnostics
-- @return table Array of diagnostics
function Validator:get_diagnostics()
  return self.diagnostics
end

-- ============================================
-- Reference Collection
-- ============================================

--- Collect all passage references for unreachable detection
-- @param ast table The AST
function Validator:_collect_references(ast)
  -- Mark first passage as reachable (entry point)
  if ast.passages and #ast.passages > 0 then
    self.referenced_passages[ast.passages[1].name] = true
  end

  -- Walk AST and collect all divert targets
  self:_walk_for_references(ast)
end

--- Walk AST to collect passage references
-- @param node table Current node
function Validator:_walk_for_references(node)
  if not node or type(node) ~= "table" then return end

  if node.type == "Divert" then
    self.referenced_passages[node.target] = true
  elseif node.type == "TunnelCall" then
    self.referenced_passages[node.target] = true
  elseif node.type == "ThreadStart" then
    self.referenced_passages[node.target] = true
  elseif node.type == "Choice" and node.target then
    -- Choice with inline divert
    if node.target.type == "Divert" then
      self.referenced_passages[node.target.target] = true
    end
  end

  -- Recurse into children using visitor infrastructure
  local children = get_children(node)
  for _, child in ipairs(children) do
    self:_walk_for_references(child)
  end
end

--- Check for unreachable passages
-- @param ast table The AST
function Validator:_check_unreachable_passages(ast)
  if not ast.passages then return end

  for i, passage in ipairs(ast.passages) do
    -- Skip the first passage (entry point)
    if i > 1 and not self.referenced_passages[passage.name] then
      -- Check if passage has a "start" tag (alternative entry point)
      local has_start_tag = false
      for _, tag in ipairs(passage.tags or {}) do
        if type(tag) == "table" and tag.name == "start" then
          has_start_tag = true
          break
        elseif type(tag) == "string" and tag == "start" then
          has_start_tag = true
          break
        end
      end

      if not has_start_tag then
        self:_add_diagnostic({
          code = codes.Semantic.UNREACHABLE_PASSAGE,
          message = codes.format_message(codes.Semantic.UNREACHABLE_PASSAGE, passage.name),
          severity = codes.Severity.WARNING,
          position = passage.pos,
        })
      end
    end
  end
end

-- ============================================
-- Visitor Methods
-- ============================================

--- Visit Script node
function Validator:visit_Script(node)
  for _, passage in ipairs(node.passages or {}) do
    self:visit(passage)
  end
end

--- Visit Passage node
function Validator:visit_Passage(node)
  self.in_passage = true

  for _, stmt in ipairs(node.body or {}) do
    self:visit(stmt)
  end

  self.in_passage = false
end

--- Visit TunnelReturn node
function Validator:visit_TunnelReturn(node)
  if not self.in_passage then
    self:_add_diagnostic({
      code = codes.Semantic.TUNNEL_RETURN_OUTSIDE_PASSAGE,
      message = codes.format_message(codes.Semantic.TUNNEL_RETURN_OUTSIDE_PASSAGE),
      severity = codes.Severity.ERROR,
      position = node.pos,
    })
  end
end

--- Visit Choice node
function Validator:visit_Choice(node)
  -- Visit nested content
  if node.condition then
    self:visit(node.condition)
  end
  if node.text then
    self:visit(node.text)
  end
  if node.target then
    self:visit(node.target)
  end
  for _, stmt in ipairs(node.body or {}) do
    self:visit(stmt)
  end
end

--- Visit Conditional node
function Validator:visit_Conditional(node)
  self:visit(node.condition)

  for _, stmt in ipairs(node.then_body or {}) do
    self:visit(stmt)
  end

  for _, elif in ipairs(node.elif_clauses or {}) do
    self:visit(elif)
  end

  if node.else_body then
    for _, stmt in ipairs(node.else_body) do
      self:visit(stmt)
    end
  end
end

--- Visit ElifClause node
function Validator:visit_ElifClause(node)
  self:visit(node.condition)
  for _, stmt in ipairs(node.body or {}) do
    self:visit(stmt)
  end
end

-- ============================================
-- Helper Methods
-- ============================================

--- Add a diagnostic
-- @param diagnostic table Diagnostic to add
function Validator:_add_diagnostic(diagnostic)
  table.insert(self.diagnostics, diagnostic)
end

M.Validator = Validator

--- Module metadata
M._whisker = {
  name = "script.semantic.validator",
  version = "0.1.0",
  description = "Validation rules for Whisker Script",
  depends = {
    "script.visitor",
    "script.semantic.symbols",
    "script.errors.codes"
  },
  capability = "script.semantic.validator"
}

return M
