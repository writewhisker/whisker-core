-- lib/whisker/script/parser/ast.lua
-- AST node definitions for Whisker Script

local source_module = require("whisker.script.source")
local SourceSpan = source_module.SourceSpan

local M = {}

--- Node type enum
-- All valid AST node types
M.NodeType = {
  -- Top-level nodes
  Script = "Script",
  Metadata = "Metadata",
  Include = "Include",
  Passage = "Passage",

  -- Statement nodes
  Text = "Text",
  Choice = "Choice",
  Assignment = "Assignment",
  Conditional = "Conditional",
  Divert = "Divert",
  TunnelCall = "TunnelCall",
  TunnelReturn = "TunnelReturn",
  ThreadStart = "ThreadStart",

  -- Expression nodes
  BinaryExpr = "BinaryExpr",
  UnaryExpr = "UnaryExpr",
  VariableRef = "VariableRef",
  FunctionCall = "FunctionCall",
  Literal = "Literal",
  ListLiteral = "ListLiteral",
  InlineExpr = "InlineExpr",
  InlineConditional = "InlineConditional",

  -- Clause nodes (parts of other nodes)
  ElifClause = "ElifClause",
  ElseClause = "ElseClause",
  Tag = "Tag",
}

-- Freeze NodeType to catch typos
setmetatable(M.NodeType, {
  __index = function(_, key)
    error("Unknown node type: " .. tostring(key))
  end,
  __newindex = function()
    error("Cannot modify NodeType enum")
  end
})

--- Create an immutable node
-- @param node_type string Node type from NodeType enum
-- @param fields table Node fields
-- @return table Immutable AST node
local function create_node(node_type, fields)
  -- Validate node type exists
  local _ = M.NodeType[node_type]

  -- Store actual data in a hidden table
  local data = { type = node_type }
  for k, v in pairs(fields) do
    data[k] = v
  end

  -- Create proxy table with no actual data
  local node = {}

  -- Make node immutable using proxy pattern
  return setmetatable(node, {
    __index = data,
    __newindex = function()
      error("AST nodes are immutable")
    end,
    __tostring = function()
      return string.format("<%s>", node_type)
    end,
    __pairs = function()
      return pairs(data)
    end
  })
end

--- Node factory functions
local Node = {}

-- ============================================
-- Top-level Nodes
-- ============================================

--- Create a Script node (root of AST)
-- @param metadata table Array of MetadataNode
-- @param includes table Array of IncludeNode
-- @param passages table Array of PassageNode
-- @param pos SourcePosition Optional position
-- @return table ScriptNode
function Node.script(metadata, includes, passages, pos)
  return create_node(M.NodeType.Script, {
    metadata = metadata or {},
    includes = includes or {},
    passages = passages or {},
    pos = pos
  })
end

--- Create a Metadata node
-- @param key string Metadata key
-- @param value any Metadata value
-- @param pos SourcePosition Optional position
-- @return table MetadataNode
function Node.metadata(key, value, pos)
  assert(type(key) == "string", "Metadata requires string key")
  return create_node(M.NodeType.Metadata, {
    key = key,
    value = value,
    pos = pos
  })
end

--- Create an Include node
-- @param path string Path to include
-- @param alias string Optional alias for import
-- @param pos SourcePosition Optional position
-- @return table IncludeNode
function Node.include(path, alias, pos)
  assert(type(path) == "string", "Include requires string path")
  return create_node(M.NodeType.Include, {
    path = path,
    alias = alias,
    pos = pos
  })
end

--- Create a Passage node
-- @param name string Passage name
-- @param tags table Array of tags
-- @param body table Array of statement nodes
-- @param pos SourcePosition Optional position
-- @return table PassageNode
function Node.passage(name, tags, body, pos)
  assert(type(name) == "string", "Passage requires string name")
  assert(type(body) == "table", "Passage requires body array")
  return create_node(M.NodeType.Passage, {
    name = name,
    tags = tags or {},
    body = body,
    pos = pos
  })
end

-- ============================================
-- Statement Nodes
-- ============================================

--- Create a Text node
-- @param segments table Array of text strings and InlineExpr nodes
-- @param pos SourcePosition Optional position
-- @return table TextNode
function Node.text(segments, pos)
  assert(type(segments) == "table", "Text requires segments array")
  return create_node(M.NodeType.Text, {
    segments = segments,
    pos = pos
  })
end

--- Create a Choice node
-- @param text table TextNode or array of segments for choice text
-- @param condition table Optional condition expression
-- @param target table Optional DivertNode for choice target
-- @param body table Optional nested content
-- @param sticky boolean Whether choice persists after selection
-- @param pos SourcePosition Optional position
-- @return table ChoiceNode
function Node.choice(text, condition, target, body, sticky, pos)
  return create_node(M.NodeType.Choice, {
    text = text,
    condition = condition,
    target = target,
    body = body or {},
    sticky = sticky or false,
    pos = pos
  })
end

--- Create an Assignment node
-- @param variable table VariableRefNode for target
-- @param operator string Assignment operator (=, +=, -=, *=, /=)
-- @param value table Expression node for value
-- @param pos SourcePosition Optional position
-- @return table AssignmentNode
function Node.assignment(variable, operator, value, pos)
  assert(variable and variable.type == M.NodeType.VariableRef,
    "Assignment requires VariableRef target")
  assert(type(operator) == "string", "Assignment requires operator")
  assert(value and value.type, "Assignment requires value expression")
  return create_node(M.NodeType.Assignment, {
    variable = variable,
    operator = operator,
    value = value,
    pos = pos
  })
end

--- Create a Conditional node
-- @param condition table Condition expression
-- @param then_body table Array of statements for true branch
-- @param elif_clauses table Array of ElifClause nodes
-- @param else_body table Optional array of statements for else branch
-- @param pos SourcePosition Optional position
-- @return table ConditionalNode
function Node.conditional(condition, then_body, elif_clauses, else_body, pos)
  assert(condition and condition.type, "Conditional requires condition expression")
  assert(type(then_body) == "table", "Conditional requires then_body array")
  return create_node(M.NodeType.Conditional, {
    condition = condition,
    then_body = then_body,
    elif_clauses = elif_clauses or {},
    else_body = else_body,
    pos = pos
  })
end

--- Create an ElifClause node
-- @param condition table Condition expression
-- @param body table Array of statements
-- @param pos SourcePosition Optional position
-- @return table ElifClauseNode
function Node.elif_clause(condition, body, pos)
  assert(condition and condition.type, "ElifClause requires condition")
  assert(type(body) == "table", "ElifClause requires body array")
  return create_node(M.NodeType.ElifClause, {
    condition = condition,
    body = body,
    pos = pos
  })
end

--- Create an ElseClause node
-- @param body table Array of statements
-- @param pos SourcePosition Optional position
-- @return table ElseClauseNode
function Node.else_clause(body, pos)
  assert(type(body) == "table", "ElseClause requires body array")
  return create_node(M.NodeType.ElseClause, {
    body = body,
    pos = pos
  })
end

--- Create a Divert node
-- @param target string Target passage name
-- @param arguments table Optional array of argument expressions
-- @param pos SourcePosition Optional position
-- @return table DivertNode
function Node.divert(target, arguments, pos)
  assert(type(target) == "string", "Divert requires string target")
  return create_node(M.NodeType.Divert, {
    target = target,
    arguments = arguments or {},
    pos = pos
  })
end

--- Create a TunnelCall node
-- @param target string Target passage name
-- @param arguments table Optional array of argument expressions
-- @param pos SourcePosition Optional position
-- @return table TunnelCallNode
function Node.tunnel_call(target, arguments, pos)
  assert(type(target) == "string", "TunnelCall requires string target")
  return create_node(M.NodeType.TunnelCall, {
    target = target,
    arguments = arguments or {},
    pos = pos
  })
end

--- Create a TunnelReturn node
-- @param pos SourcePosition Optional position
-- @return table TunnelReturnNode
function Node.tunnel_return(pos)
  return create_node(M.NodeType.TunnelReturn, {
    pos = pos
  })
end

--- Create a ThreadStart node
-- @param target string Target passage name
-- @param pos SourcePosition Optional position
-- @return table ThreadStartNode
function Node.thread_start(target, pos)
  assert(type(target) == "string", "ThreadStart requires string target")
  return create_node(M.NodeType.ThreadStart, {
    target = target,
    pos = pos
  })
end

-- ============================================
-- Expression Nodes
-- ============================================

--- Create a BinaryExpr node
-- @param operator string Binary operator
-- @param left table Left operand expression
-- @param right table Right operand expression
-- @param pos SourcePosition Optional position
-- @return table BinaryExprNode
function Node.binary_expr(operator, left, right, pos)
  assert(type(operator) == "string", "BinaryExpr requires operator")
  assert(left and left.type, "BinaryExpr requires left operand")
  assert(right and right.type, "BinaryExpr requires right operand")
  return create_node(M.NodeType.BinaryExpr, {
    operator = operator,
    left = left,
    right = right,
    pos = pos
  })
end

--- Create a UnaryExpr node
-- @param operator string Unary operator
-- @param operand table Operand expression
-- @param pos SourcePosition Optional position
-- @return table UnaryExprNode
function Node.unary_expr(operator, operand, pos)
  assert(type(operator) == "string", "UnaryExpr requires operator")
  assert(operand and operand.type, "UnaryExpr requires operand")
  return create_node(M.NodeType.UnaryExpr, {
    operator = operator,
    operand = operand,
    pos = pos
  })
end

--- Create a VariableRef node
-- @param name string Variable name (without $)
-- @param index table Optional index expression for list access
-- @param pos SourcePosition Optional position
-- @return table VariableRefNode
function Node.variable_ref(name, index, pos)
  assert(type(name) == "string", "VariableRef requires string name")
  return create_node(M.NodeType.VariableRef, {
    name = name,
    index = index,
    pos = pos
  })
end

--- Create a FunctionCall node
-- @param name string Function name
-- @param arguments table Array of argument expressions
-- @param pos SourcePosition Optional position
-- @return table FunctionCallNode
function Node.function_call(name, arguments, pos)
  assert(type(name) == "string", "FunctionCall requires string name")
  return create_node(M.NodeType.FunctionCall, {
    name = name,
    arguments = arguments or {},
    pos = pos
  })
end

--- Create a Literal node
-- @param value any Literal value (number, string, boolean, nil)
-- @param literal_type string Type hint: "number", "string", "boolean", "null"
-- @param pos SourcePosition Optional position
-- @return table LiteralNode
function Node.literal(value, literal_type, pos)
  return create_node(M.NodeType.Literal, {
    value = value,
    literal_type = literal_type or type(value),
    pos = pos
  })
end

--- Create a ListLiteral node
-- @param elements table Array of expression nodes
-- @param pos SourcePosition Optional position
-- @return table ListLiteralNode
function Node.list_literal(elements, pos)
  assert(type(elements) == "table", "ListLiteral requires elements array")
  return create_node(M.NodeType.ListLiteral, {
    elements = elements,
    pos = pos
  })
end

--- Create an InlineExpr node (for {expression} in text)
-- @param expression table Expression node
-- @param pos SourcePosition Optional position
-- @return table InlineExprNode
function Node.inline_expr(expression, pos)
  assert(expression and expression.type, "InlineExpr requires expression")
  return create_node(M.NodeType.InlineExpr, {
    expression = expression,
    pos = pos
  })
end

--- Create an InlineConditional node (ternary in text)
-- @param condition table Condition expression
-- @param then_value table Value if true (expression or text)
-- @param else_value table Value if false (expression or text)
-- @param pos SourcePosition Optional position
-- @return table InlineConditionalNode
function Node.inline_conditional(condition, then_value, else_value, pos)
  assert(condition and condition.type, "InlineConditional requires condition")
  return create_node(M.NodeType.InlineConditional, {
    condition = condition,
    then_value = then_value,
    else_value = else_value,
    pos = pos
  })
end

--- Create a Tag node
-- @param name string Tag name
-- @param value any Optional tag value
-- @param pos SourcePosition Optional position
-- @return table TagNode
function Node.tag(name, value, pos)
  assert(type(name) == "string", "Tag requires string name")
  return create_node(M.NodeType.Tag, {
    name = name,
    value = value,
    pos = pos
  })
end

-- ============================================
-- Helper Functions
-- ============================================

--- Check if a value is an AST node
-- @param value any Value to check
-- @return boolean
function M.is_node(value)
  if type(value) ~= "table" or value.type == nil then
    return false
  end
  -- Check if it's a valid node type without triggering __index error
  return rawget(M.NodeType, value.type) ~= nil
end

--- Check if a node is of a specific type
-- @param node table AST node
-- @param node_type string Node type to check
-- @return boolean
function M.is_type(node, node_type)
  return M.is_node(node) and node.type == node_type
end

--- Check if a node is an expression
-- @param node table AST node
-- @return boolean
function M.is_expression(node)
  if not M.is_node(node) then return false end
  local expr_types = {
    [M.NodeType.BinaryExpr] = true,
    [M.NodeType.UnaryExpr] = true,
    [M.NodeType.VariableRef] = true,
    [M.NodeType.FunctionCall] = true,
    [M.NodeType.Literal] = true,
    [M.NodeType.ListLiteral] = true,
    [M.NodeType.InlineExpr] = true,
    [M.NodeType.InlineConditional] = true,
  }
  return expr_types[node.type] == true
end

--- Check if a node is a statement
-- @param node table AST node
-- @return boolean
function M.is_statement(node)
  if not M.is_node(node) then return false end
  local stmt_types = {
    [M.NodeType.Text] = true,
    [M.NodeType.Choice] = true,
    [M.NodeType.Assignment] = true,
    [M.NodeType.Conditional] = true,
    [M.NodeType.Divert] = true,
    [M.NodeType.TunnelCall] = true,
    [M.NodeType.TunnelReturn] = true,
    [M.NodeType.ThreadStart] = true,
  }
  return stmt_types[node.type] == true
end

--- Get the span of a node
-- @param node table AST node
-- @return SourceSpan|nil
function M.get_span(node)
  if not M.is_node(node) or not node.pos then
    return nil
  end
  -- If node has explicit end_pos, use it
  if node.end_pos then
    return SourceSpan.new(node.pos, node.end_pos)
  end
  -- Otherwise return single-position span
  return SourceSpan.new(node.pos, node.pos)
end

--- Create a copy of a node with a new position
-- @param node table AST node to copy
-- @param pos SourcePosition New position
-- @return table New node with updated position
function M.with_position(node, pos)
  if not M.is_node(node) then
    error("with_position requires an AST node")
  end
  local fields = {}
  for k, v in pairs(node) do
    if k ~= "type" then
      fields[k] = v
    end
  end
  fields.pos = pos
  return create_node(node.type, fields)
end

M.Node = Node

--- Module metadata
M._whisker = {
  name = "script.parser.ast",
  version = "0.1.0",
  description = "AST node definitions for Whisker Script",
  depends = { "script.source" },
  capability = "script.parser.ast"
}

return M
