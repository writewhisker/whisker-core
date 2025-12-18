-- lib/whisker/script/semantic/resolver.lua
-- Reference resolution for Whisker Script semantic analysis

local visitor_module = require("whisker.script.visitor")
local Visitor = visitor_module.Visitor

local symbols_module = require("whisker.script.semantic.symbols")
local SymbolKind = symbols_module.SymbolKind
local ScopeKind = symbols_module.ScopeKind

local codes = require("whisker.script.errors.codes")

local M = {}

-- ============================================
-- Built-in Functions
-- ============================================

--- Built-in functions with argument counts
-- { name = { min = min_args, max = max_args } }
local BUILTIN_FUNCTIONS = {
  -- Math functions
  abs = { min = 1, max = 1 },
  floor = { min = 1, max = 1 },
  ceil = { min = 1, max = 1 },
  round = { min = 1, max = 1 },
  min = { min = 2, max = 2 },
  max = { min = 2, max = 2 },
  random = { min = 0, max = 2 },

  -- String functions
  len = { min = 1, max = 1 },
  upper = { min = 1, max = 1 },
  lower = { min = 1, max = 1 },
  trim = { min = 1, max = 1 },
  substr = { min = 2, max = 3 },
  contains = { min = 2, max = 2 },

  -- List functions
  count = { min = 1, max = 1 },
  first = { min = 1, max = 1 },
  last = { min = 1, max = 1 },
  has = { min = 2, max = 2 },
  push = { min = 2, max = 2 },
  pop = { min = 1, max = 1 },

  -- Type functions
  type = { min = 1, max = 1 },
  str = { min = 1, max = 1 },
  num = { min = 1, max = 1 },
  bool = { min = 1, max = 1 },

  -- Story functions
  visited = { min = 0, max = 1 },
  visit_count = { min = 0, max = 1 },
  turns = { min = 0, max = 0 },
  choice_count = { min = 0, max = 0 },
}

M.BUILTIN_FUNCTIONS = BUILTIN_FUNCTIONS

-- ============================================
-- Levenshtein Distance for suggestions
-- ============================================

--- Calculate Levenshtein distance between two strings
-- @param a string First string
-- @param b string Second string
-- @return number Edit distance
local function levenshtein_distance(a, b)
  if a == b then return 0 end
  if #a == 0 then return #b end
  if #b == 0 then return #a end

  local matrix = {}

  -- Initialize first column
  for i = 0, #a do
    matrix[i] = { [0] = i }
  end

  -- Initialize first row
  for j = 0, #b do
    matrix[0][j] = j
  end

  -- Fill matrix
  for i = 1, #a do
    for j = 1, #b do
      local cost = (a:sub(i, i) == b:sub(j, j)) and 0 or 1
      matrix[i][j] = math.min(
        matrix[i - 1][j] + 1,       -- deletion
        matrix[i][j - 1] + 1,       -- insertion
        matrix[i - 1][j - 1] + cost -- substitution
      )
    end
  end

  return matrix[#a][#b]
end

M.levenshtein_distance = levenshtein_distance

-- ============================================
-- Resolver Class
-- ============================================

local Resolver = setmetatable({}, { __index = Visitor })
Resolver.__index = Resolver

--- Create a new resolver
-- @param symbol_table SymbolTable Symbol table with declarations
-- @return Resolver
function Resolver.new(symbol_table)
  local self = setmetatable(Visitor.new(), { __index = Resolver })
  self.symbols = symbol_table
  self.diagnostics = {}
  self.in_passage = false
  self.current_passage = nil
  -- Track variable initialization state
  self.initialized_vars = {}
  return self
end

--- Resolve references in an AST
-- @param ast table The AST to resolve
function Resolver:resolve(ast)
  self.diagnostics = {}
  self.initialized_vars = {}
  self:visit(ast)
end

--- Get accumulated diagnostics
-- @return table Array of diagnostics
function Resolver:get_diagnostics()
  return self.diagnostics
end

-- ============================================
-- Visitor Methods
-- ============================================

--- Visit Script node
function Resolver:visit_Script(node)
  -- Visit all passages
  for _, passage in ipairs(node.passages or {}) do
    self:visit(passage)
  end
end

--- Visit Passage node
function Resolver:visit_Passage(node)
  self.in_passage = true
  self.current_passage = node.name

  -- Enter passage scope
  self.symbols:enter_scope(ScopeKind.PASSAGE)

  -- Visit body
  for _, stmt in ipairs(node.body or {}) do
    self:visit(stmt)
  end

  -- Exit passage scope
  self.symbols:exit_scope()

  self.in_passage = false
  self.current_passage = nil
end

--- Visit Divert node
function Resolver:visit_Divert(node)
  local passage = self.symbols:lookup_global(node.target)

  if not passage then
    -- Undefined passage reference - treat as warning (story is still playable)
    local suggestion = self:_suggest_passage(node.target)
    self:_add_diagnostic({
      code = codes.Semantic.UNDEFINED_PASSAGE,
      message = codes.format_message(codes.Semantic.UNDEFINED_PASSAGE, node.target),
      severity = codes.Severity.WARNING,
      position = node.pos,
      suggestion = suggestion,
    })
  else
    -- Add reference to symbol
    passage:add_reference(node.pos)
    -- Annotate the AST node with resolved symbol
    rawset(node, "resolved_target", passage)
  end

  -- Visit arguments
  for _, arg in ipairs(node.arguments or {}) do
    self:visit(arg)
  end
end

--- Visit TunnelCall node
function Resolver:visit_TunnelCall(node)
  local passage = self.symbols:lookup_global(node.target)

  if not passage then
    local suggestion = self:_suggest_passage(node.target)
    self:_add_diagnostic({
      code = codes.Semantic.UNDEFINED_PASSAGE,
      message = codes.format_message(codes.Semantic.UNDEFINED_PASSAGE, node.target),
      severity = codes.Severity.WARNING,
      position = node.pos,
      suggestion = suggestion,
    })
  else
    passage:add_reference(node.pos)
    rawset(node, "resolved_target", passage)
  end

  -- Visit arguments
  for _, arg in ipairs(node.arguments or {}) do
    self:visit(arg)
  end
end

--- Visit ThreadStart node
function Resolver:visit_ThreadStart(node)
  local passage = self.symbols:lookup_global(node.target)

  if not passage then
    local suggestion = self:_suggest_passage(node.target)
    self:_add_diagnostic({
      code = codes.Semantic.UNDEFINED_PASSAGE,
      message = codes.format_message(codes.Semantic.UNDEFINED_PASSAGE, node.target),
      severity = codes.Severity.WARNING,
      position = node.pos,
      suggestion = suggestion,
    })
  else
    passage:add_reference(node.pos)
    rawset(node, "resolved_target", passage)
  end
end

--- Visit Assignment node
function Resolver:visit_Assignment(node)
  -- Visit the value first (may reference the variable)
  self:visit(node.value)

  -- Define or update the variable
  local var_name = node.variable.name
  local symbol = self.symbols:lookup(var_name)

  if not symbol then
    -- New variable definition
    symbol = self.symbols:define(var_name, SymbolKind.VARIABLE, node.variable.pos)
    if symbol then
      symbol:mark_initialized()
      self.initialized_vars[var_name] = true
    end
  else
    -- Existing variable - mark as initialized
    symbol:mark_initialized()
    self.initialized_vars[var_name] = true
    symbol:add_reference(node.variable.pos)
  end

  -- Annotate the variable reference
  if symbol then
    rawset(node.variable, "resolved_symbol", symbol)
  end
end

--- Visit VariableRef node (when reading a variable)
function Resolver:visit_VariableRef(node)
  local symbol = self.symbols:lookup(node.name)

  if not symbol then
    -- Variable not defined - define it but warn about uninitialized use
    symbol = self.symbols:define(node.name, SymbolKind.VARIABLE, node.pos)
    if symbol then
      self:_add_diagnostic({
        code = codes.Semantic.UNINITIALIZED_VARIABLE,
        message = codes.format_message(codes.Semantic.UNINITIALIZED_VARIABLE, node.name),
        severity = codes.Severity.WARNING,
        position = node.pos,
      })
    end
  else
    -- Check if initialized
    if not self.initialized_vars[node.name] and not symbol:is_initialized() then
      self:_add_diagnostic({
        code = codes.Semantic.UNINITIALIZED_VARIABLE,
        message = codes.format_message(codes.Semantic.UNINITIALIZED_VARIABLE, node.name),
        severity = codes.Severity.WARNING,
        position = node.pos,
      })
    end
    symbol:add_reference(node.pos)
  end

  -- Annotate with resolved symbol
  if symbol then
    rawset(node, "resolved_symbol", symbol)
  end

  -- Visit index if present
  if node.index then
    self:visit(node.index)
  end
end

--- Visit FunctionCall node
function Resolver:visit_FunctionCall(node)
  local func_info = BUILTIN_FUNCTIONS[node.name]

  if not func_info then
    -- Unknown function
    self:_add_diagnostic({
      code = codes.Semantic.UNDEFINED_FUNCTION,
      message = codes.format_message(codes.Semantic.UNDEFINED_FUNCTION, node.name),
      severity = codes.Severity.ERROR,
      position = node.pos,
      suggestion = self:_suggest_function(node.name),
    })
  else
    -- Check argument count
    local arg_count = #(node.arguments or {})
    if arg_count < func_info.min or arg_count > func_info.max then
      local expected
      if func_info.min == func_info.max then
        expected = tostring(func_info.min)
      else
        expected = func_info.min .. "-" .. func_info.max
      end
      self:_add_diagnostic({
        code = codes.Semantic.WRONG_ARGUMENT_COUNT,
        message = codes.format_message(
          codes.Semantic.WRONG_ARGUMENT_COUNT,
          node.name,
          expected,
          arg_count
        ),
        severity = codes.Severity.ERROR,
        position = node.pos,
      })
    end
  end

  -- Visit arguments
  for _, arg in ipairs(node.arguments or {}) do
    self:visit(arg)
  end
end

--- Visit Choice node
function Resolver:visit_Choice(node)
  -- Enter choice scope
  self.symbols:enter_scope(ScopeKind.CHOICE)

  -- Visit condition if present
  if node.condition then
    self:visit(node.condition)
  end

  -- Visit text
  if node.text then
    self:visit(node.text)
  end

  -- Visit target if present
  if node.target then
    self:visit(node.target)
  end

  -- Visit body
  for _, stmt in ipairs(node.body or {}) do
    self:visit(stmt)
  end

  self.symbols:exit_scope()
end

--- Visit Conditional node
function Resolver:visit_Conditional(node)
  -- Visit condition
  self:visit(node.condition)

  -- Enter conditional scope for then branch
  self.symbols:enter_scope(ScopeKind.CONDITIONAL)
  for _, stmt in ipairs(node.then_body or {}) do
    self:visit(stmt)
  end
  self.symbols:exit_scope()

  -- Visit elif clauses
  for _, elif in ipairs(node.elif_clauses or {}) do
    self:visit(elif)
  end

  -- Visit else body if present
  if node.else_body then
    self.symbols:enter_scope(ScopeKind.CONDITIONAL)
    for _, stmt in ipairs(node.else_body) do
      self:visit(stmt)
    end
    self.symbols:exit_scope()
  end
end

--- Visit ElifClause node
function Resolver:visit_ElifClause(node)
  self:visit(node.condition)

  self.symbols:enter_scope(ScopeKind.CONDITIONAL)
  for _, stmt in ipairs(node.body or {}) do
    self:visit(stmt)
  end
  self.symbols:exit_scope()
end

--- Visit Text node
function Resolver:visit_Text(node)
  for _, seg in ipairs(node.segments or {}) do
    if type(seg) == "table" and seg.type then
      self:visit(seg)
    end
  end
end

--- Visit InlineExpr node
function Resolver:visit_InlineExpr(node)
  if node.expression then
    self:visit(node.expression)
  end
end

--- Visit InlineConditional node
function Resolver:visit_InlineConditional(node)
  if node.condition then
    self:visit(node.condition)
  end
  if node.then_value then
    self:visit(node.then_value)
  end
  if node.else_value then
    self:visit(node.else_value)
  end
end

--- Visit BinaryExpr node
function Resolver:visit_BinaryExpr(node)
  if node.left then
    self:visit(node.left)
  end
  if node.right then
    self:visit(node.right)
  end
end

--- Visit UnaryExpr node
function Resolver:visit_UnaryExpr(node)
  if node.operand then
    self:visit(node.operand)
  end
end

--- Visit ListLiteral node
function Resolver:visit_ListLiteral(node)
  for _, elem in ipairs(node.elements or {}) do
    self:visit(elem)
  end
end

-- ============================================
-- Helper Methods
-- ============================================

--- Add a diagnostic
-- @param diagnostic table Diagnostic to add
function Resolver:_add_diagnostic(diagnostic)
  table.insert(self.diagnostics, diagnostic)
end

--- Suggest a similar passage name
-- @param name string The undefined passage name
-- @return string|nil Suggestion message or nil
function Resolver:_suggest_passage(name)
  local passages = self.symbols:all_passages()
  local best = nil
  local best_dist = math.huge

  for _, p in ipairs(passages) do
    local dist = levenshtein_distance(name:lower(), p.name:lower())
    if dist < best_dist and dist <= 3 then
      best = p
      best_dist = dist
    end
  end

  if best then
    local line_info = best.position and best.position.line or "?"
    return "Did you mean '" .. best.name .. "'? (defined at line " .. line_info .. ")"
  end
  return nil
end

--- Suggest a similar function name
-- @param name string The undefined function name
-- @return string|nil Suggestion message or nil
function Resolver:_suggest_function(name)
  local best = nil
  local best_dist = math.huge

  for func_name, _ in pairs(BUILTIN_FUNCTIONS) do
    local dist = levenshtein_distance(name:lower(), func_name:lower())
    if dist < best_dist and dist <= 2 then
      best = func_name
      best_dist = dist
    end
  end

  if best then
    return "Did you mean '" .. best .. "'?"
  end
  return nil
end

M.Resolver = Resolver

--- Module metadata
M._whisker = {
  name = "script.semantic.resolver",
  version = "0.1.0",
  description = "Reference resolution for Whisker Script",
  depends = {
    "script.visitor",
    "script.semantic.symbols",
    "script.errors.codes"
  },
  capability = "script.semantic.resolver"
}

return M
