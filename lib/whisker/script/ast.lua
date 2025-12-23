-- Whisker Script AST (Abstract Syntax Tree)
-- Defines node types for the parsed representation
--
-- lib/whisker/script/ast.lua

local AST = {}

--------------------------------------------------------------------------------
-- Source Location
--------------------------------------------------------------------------------

--- Create a source location for error reporting
---@param line number Line number (1-indexed)
---@param column number Column number (1-indexed)
---@param filename string|nil Optional filename
---@return table location
function AST.Location(line, column, filename)
  return {
    line = line,
    column = column,
    filename = filename
  }
end

--------------------------------------------------------------------------------
-- Node Constructors
--------------------------------------------------------------------------------

--- Create a Program node (root of AST)
---@param passages table[] Array of Passage nodes
---@param metadata table|nil Optional metadata
---@return table
function AST.Program(passages, metadata)
  return {
    type = "program",
    passages = passages or {},
    metadata = metadata or {}
  }
end

--- Create a Passage node
---@param name string Passage identifier
---@param content table[] Array of content nodes
---@param metadata table|nil Optional metadata (includes location)
---@return table
function AST.Passage(name, content, metadata)
  return {
    type = "passage",
    name = name,
    content = content or {},
    metadata = metadata or {}
  }
end

--- Create a Choice node
---@param text string|table Choice display text (string or interpolation nodes)
---@param target string Target passage name
---@param condition table|nil Optional condition expression
---@param metadata table|nil Optional metadata
---@return table
function AST.Choice(text, target, condition, metadata)
  return {
    type = "choice",
    text = text,
    target = target,
    condition = condition,
    metadata = metadata or {}
  }
end

--- Create a Conditional node
---@param condition table Condition expression
---@param then_content table[] Content shown when condition is true
---@param metadata table|nil Optional metadata
---@return table
function AST.Conditional(condition, then_content, metadata)
  return {
    type = "conditional",
    condition = condition,
    then_content = then_content or {},
    metadata = metadata or {}
  }
end

--- Create an Assignment node
---@param variable string Variable name (without $)
---@param operator string Assignment operator ('=', '+=', '-=')
---@param value table Value expression
---@param metadata table|nil Optional metadata
---@return table
function AST.Assignment(variable, operator, value, metadata)
  return {
    type = "assignment",
    variable = variable,
    operator = operator,
    value = value,
    metadata = metadata or {}
  }
end

--- Create a BinaryOp node
---@param operator string Operator ('&&', '||', '==', '!=', '<', '>', '<=', '>=')
---@param left table Left operand expression
---@param right table Right operand expression
---@param metadata table|nil Optional metadata
---@return table
function AST.BinaryOp(operator, left, right, metadata)
  return {
    type = "binary_op",
    operator = operator,
    left = left,
    right = right,
    metadata = metadata or {}
  }
end

--- Create a UnaryOp node
---@param operator string Operator ('!')
---@param operand table Operand expression
---@param metadata table|nil Optional metadata
---@return table
function AST.UnaryOp(operator, operand, metadata)
  return {
    type = "unary_op",
    operator = operator,
    operand = operand,
    metadata = metadata or {}
  }
end

--- Create a Variable node
---@param name string Variable name (without $)
---@param metadata table|nil Optional metadata
---@return table
function AST.Variable(name, metadata)
  return {
    type = "variable",
    name = name,
    metadata = metadata or {}
  }
end

--- Create a Literal node
---@param value number|string|boolean Literal value
---@param metadata table|nil Optional metadata
---@return table
function AST.Literal(value, metadata)
  return {
    type = "literal",
    value = value,
    metadata = metadata or {}
  }
end

--- Create a Text node
---@param content string|table Text content or array of text/variable nodes
---@param metadata table|nil Optional metadata
---@return table
function AST.Text(content, metadata)
  return {
    type = "text",
    content = content,
    metadata = metadata or {}
  }
end

--- Create a LuaBlock node
---@param code string Lua source code
---@param metadata table|nil Optional metadata
---@return table
function AST.LuaBlock(code, metadata)
  return {
    type = "lua_block",
    code = code,
    metadata = metadata or {}
  }
end

--- Create an Interpolation node (for text with embedded variables)
---@param parts table[] Array of string and Variable nodes
---@param metadata table|nil Optional metadata
---@return table
function AST.Interpolation(parts, metadata)
  return {
    type = "interpolation",
    parts = parts or {},
    metadata = metadata or {}
  }
end

--------------------------------------------------------------------------------
-- Visitor Pattern
--------------------------------------------------------------------------------

--- Visit an AST node with a visitor object
---@param node table AST node
---@param visitor table Visitor with visit_* methods
---@return any Result from visitor
function AST.visit(node, visitor)
  if not node or not node.type then
    error("Invalid AST node: missing type")
  end

  local method_name = "visit_" .. node.type
  local method = visitor[method_name]

  if method then
    return method(visitor, node)
  elseif visitor.visit_default then
    return visitor:visit_default(node)
  else
    error("No visitor method for node type: " .. node.type)
  end
end

--- Walk all children of a node
---@param node table AST node
---@param visitor table Visitor with visit_* methods
function AST.walk(node, visitor)
  if not node or not node.type then
    return
  end

  -- Visit current node first
  AST.visit(node, visitor)

  -- Then visit children based on node type
  if node.type == "program" then
    for _, passage in ipairs(node.passages or {}) do
      AST.walk(passage, visitor)
    end
  elseif node.type == "passage" then
    for _, elem in ipairs(node.content or {}) do
      AST.walk(elem, visitor)
    end
  elseif node.type == "choice" then
    if node.condition then
      AST.walk(node.condition, visitor)
    end
  elseif node.type == "conditional" then
    AST.walk(node.condition, visitor)
    for _, elem in ipairs(node.then_content or {}) do
      AST.walk(elem, visitor)
    end
  elseif node.type == "assignment" then
    AST.walk(node.value, visitor)
  elseif node.type == "binary_op" then
    AST.walk(node.left, visitor)
    AST.walk(node.right, visitor)
  elseif node.type == "unary_op" then
    AST.walk(node.operand, visitor)
  elseif node.type == "interpolation" then
    for _, part in ipairs(node.parts or {}) do
      if type(part) == "table" then
        AST.walk(part, visitor)
      end
    end
  end
end

--------------------------------------------------------------------------------
-- Validation
--------------------------------------------------------------------------------

--- Validate that a node has required fields
---@param node table AST node
---@return boolean valid
---@return string|nil error_message
function AST.validate(node)
  if not node then
    return false, "Node is nil"
  end
  if not node.type then
    return false, "Node missing type field"
  end

  if node.type == "program" then
    if type(node.passages) ~= "table" then
      return false, "Program missing passages array"
    end
    for i, passage in ipairs(node.passages) do
      local ok, err = AST.validate(passage)
      if not ok then
        return false, "Invalid passage " .. i .. ": " .. err
      end
    end
  elseif node.type == "passage" then
    if type(node.name) ~= "string" then
      return false, "Passage missing name"
    end
    if type(node.content) ~= "table" then
      return false, "Passage missing content array"
    end
  elseif node.type == "choice" then
    if not node.target then
      return false, "Choice missing target"
    end
  elseif node.type == "conditional" then
    if not node.condition then
      return false, "Conditional missing condition"
    end
  elseif node.type == "assignment" then
    if not node.variable then
      return false, "Assignment missing variable"
    end
    if not node.operator then
      return false, "Assignment missing operator"
    end
    if not node.value then
      return false, "Assignment missing value"
    end
  elseif node.type == "binary_op" then
    if not node.operator then
      return false, "BinaryOp missing operator"
    end
    if not node.left then
      return false, "BinaryOp missing left operand"
    end
    if not node.right then
      return false, "BinaryOp missing right operand"
    end
  elseif node.type == "unary_op" then
    if not node.operator then
      return false, "UnaryOp missing operator"
    end
    if not node.operand then
      return false, "UnaryOp missing operand"
    end
  elseif node.type == "variable" then
    if not node.name then
      return false, "Variable missing name"
    end
  end

  return true
end

--------------------------------------------------------------------------------
-- Pretty Printing
--------------------------------------------------------------------------------

--- Pretty print an AST node (for debugging)
---@param node table AST node
---@param indent number|nil Indentation level
---@return string
function AST.pretty_print(node, indent)
  indent = indent or 0
  local prefix = string.rep("  ", indent)

  if not node or not node.type then
    return prefix .. "(nil)"
  end

  local lines = {}

  if node.type == "program" then
    table.insert(lines, prefix .. "Program")
    for _, passage in ipairs(node.passages or {}) do
      table.insert(lines, AST.pretty_print(passage, indent + 1))
    end
  elseif node.type == "passage" then
    table.insert(lines, prefix .. "Passage: " .. (node.name or "?"))
    for _, elem in ipairs(node.content or {}) do
      table.insert(lines, AST.pretty_print(elem, indent + 1))
    end
  elseif node.type == "choice" then
    local cond = node.condition and " (conditional)" or ""
    table.insert(lines, prefix .. "Choice -> " .. (node.target or "?") .. cond)
  elseif node.type == "conditional" then
    table.insert(lines, prefix .. "Conditional")
    table.insert(lines, prefix .. "  condition:")
    table.insert(lines, AST.pretty_print(node.condition, indent + 2))
    table.insert(lines, prefix .. "  then:")
    for _, elem in ipairs(node.then_content or {}) do
      table.insert(lines, AST.pretty_print(elem, indent + 2))
    end
  elseif node.type == "assignment" then
    table.insert(lines, prefix .. "Assignment: $" .. (node.variable or "?") ..
                        " " .. (node.operator or "="))
    table.insert(lines, AST.pretty_print(node.value, indent + 1))
  elseif node.type == "binary_op" then
    table.insert(lines, prefix .. "BinaryOp: " .. (node.operator or "?"))
    table.insert(lines, AST.pretty_print(node.left, indent + 1))
    table.insert(lines, AST.pretty_print(node.right, indent + 1))
  elseif node.type == "unary_op" then
    table.insert(lines, prefix .. "UnaryOp: " .. (node.operator or "?"))
    table.insert(lines, AST.pretty_print(node.operand, indent + 1))
  elseif node.type == "variable" then
    table.insert(lines, prefix .. "Variable: $" .. (node.name or "?"))
  elseif node.type == "literal" then
    local val = node.value
    if type(val) == "string" then
      val = '"' .. val .. '"'
    else
      val = tostring(val)
    end
    table.insert(lines, prefix .. "Literal: " .. val)
  elseif node.type == "text" then
    local content = node.content
    if type(content) == "string" then
      content = content:sub(1, 40)
      if #node.content > 40 then
        content = content .. "..."
      end
    else
      content = "(complex)"
    end
    table.insert(lines, prefix .. "Text: " .. content)
  elseif node.type == "lua_block" then
    local code = (node.code or ""):sub(1, 30)
    if #(node.code or "") > 30 then
      code = code .. "..."
    end
    table.insert(lines, prefix .. "LuaBlock: " .. code)
  elseif node.type == "interpolation" then
    table.insert(lines, prefix .. "Interpolation")
    for _, part in ipairs(node.parts or {}) do
      if type(part) == "string" then
        table.insert(lines, prefix .. "  text: " .. part:sub(1, 30))
      else
        table.insert(lines, AST.pretty_print(part, indent + 1))
      end
    end
  else
    table.insert(lines, prefix .. "Unknown: " .. node.type)
  end

  return table.concat(lines, "\n")
end

--- Convert AST to string (alias for pretty_print)
---@param node table AST node
---@return string
function AST.tostring(node)
  return AST.pretty_print(node, 0)
end

--------------------------------------------------------------------------------
-- Utilities
--------------------------------------------------------------------------------

--- Deep clone an AST node
---@param node table AST node
---@return table Cloned node
function AST.clone(node)
  if type(node) ~= "table" then
    return node
  end

  local copy = {}
  for k, v in pairs(node) do
    if type(v) == "table" then
      copy[k] = AST.clone(v)
    else
      copy[k] = v
    end
  end
  return copy
end

--- Get all variable names used in an AST
---@param node table AST node
---@return table Set of variable names
function AST.get_variables(node)
  local vars = {}

  local collector = {
    visit_variable = function(_, n)
      vars[n.name] = true
    end,
    visit_default = function() end
  }

  -- Add visit methods for all node types
  for _, t in ipairs({"program", "passage", "choice", "conditional",
                      "assignment", "binary_op", "unary_op", "literal",
                      "text", "lua_block", "interpolation"}) do
    collector["visit_" .. t] = collector.visit_default
  end
  collector.visit_variable = function(_, n)
    vars[n.name] = true
  end

  AST.walk(node, collector)
  return vars
end

--- Get all passage names in a program
---@param program table Program AST node
---@return table Array of passage names
function AST.get_passage_names(program)
  local names = {}
  if program.type == "program" then
    for _, passage in ipairs(program.passages or {}) do
      if passage.name then
        table.insert(names, passage.name)
      end
    end
  end
  return names
end

--- Get all choice targets in a program
---@param program table Program AST node
---@return table Set of target passage names
function AST.get_choice_targets(program)
  local targets = {}

  local collector = {
    visit_choice = function(_, n)
      if n.target then
        targets[n.target] = true
      end
    end,
    visit_default = function() end
  }

  -- Add default handlers for all types
  for _, t in ipairs({"program", "passage", "conditional", "assignment",
                      "binary_op", "unary_op", "variable", "literal",
                      "text", "lua_block", "interpolation"}) do
    collector["visit_" .. t] = collector.visit_default
  end

  AST.walk(program, collector)
  return targets
end

return AST
