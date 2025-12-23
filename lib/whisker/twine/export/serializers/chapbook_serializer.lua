--- Chapbook AST to text serializer
-- Converts WhiskerScript AST back to Chapbook syntax
--
-- lib/whisker/twine/export/serializers/chapbook_serializer.lua

local ChapbookSerializer = {}

--------------------------------------------------------------------------------
-- Main Serialization
--------------------------------------------------------------------------------

--- Serialize AST to Chapbook text
---@param ast table Array of AST nodes
---@return string Chapbook passage text
function ChapbookSerializer.serialize(ast)
  if not ast or #ast == 0 then
    return ""
  end

  local parts = {}

  for _, node in ipairs(ast) do
    local serialized = ChapbookSerializer._serialize_node(node)
    if serialized then
      table.insert(parts, serialized)
    end
  end

  return table.concat(parts, "\n")
end

--------------------------------------------------------------------------------
-- Node Serialization
--------------------------------------------------------------------------------

--- Serialize single node
---@param node table AST node
---@return string|nil Serialized text
function ChapbookSerializer._serialize_node(node)
  if node.type == "text" then
    return node.value or node.content or ""

  elseif node.type == "assignment" then
    return string.format("%s: %s",
      node.variable,
      ChapbookSerializer._serialize_expression(node.value))

  elseif node.type == "conditional" then
    local condition = ChapbookSerializer._serialize_condition(node.condition)
    local body = ChapbookSerializer.serialize(node.body or {})
    return string.format("[if %s]\n%s", condition, body)

  elseif node.type == "choice" then
    if node.destination then
      if node.text == node.destination then
        return string.format("[[%s]]", node.text)
      else
        return string.format("[[%s->%s]]", node.text, node.destination)
      end
    else
      return string.format("[[%s]]", node.text)
    end

  elseif node.type == "goto" then
    return string.format("[[%s]]", node.destination)

  elseif node.type == "insert" or node.type == "interpolation" then
    return string.format("{%s}",
      ChapbookSerializer._serialize_expression(node.expression))

  elseif node.type == "delayed_content" then
    return string.format("[after %ss]\n%s",
      node.delay,
      ChapbookSerializer.serialize(node.body or {}))

  elseif node.type == "continue_prompt" then
    return "[continue]"

  elseif node.type == "aligned_text" then
    return string.format("[align %s]\n%s",
      node.alignment,
      ChapbookSerializer.serialize(node.body or {}))

  elseif node.type == "note" then
    return string.format("[note]\n%s",
      ChapbookSerializer.serialize(node.body or {}))

  else
    return "<!-- " .. node.type .. " -->"
  end
end

--------------------------------------------------------------------------------
-- Expression Serialization
--------------------------------------------------------------------------------

--- Serialize expression
---@param expr table Expression node
---@return string Chapbook expression
function ChapbookSerializer._serialize_expression(expr)
  if not expr then return "" end

  if expr.type == "literal" then
    if expr.value_type == "string" then
      return string.format("'%s'", expr.value)
    elseif expr.value_type == "boolean" then
      return expr.value and "true" or "false"
    else
      return tostring(expr.value)
    end

  elseif expr.type == "variable_ref" then
    return expr.name  -- No sigil in Chapbook

  elseif expr.type == "binary_op" then
    return string.format("%s %s %s",
      ChapbookSerializer._serialize_expression(expr.left),
      expr.operator,
      ChapbookSerializer._serialize_expression(expr.right))

  elseif expr.type == "array_literal" then
    local items = {}
    for _, item in ipairs(expr.items or {}) do
      table.insert(items, ChapbookSerializer._serialize_expression(item))
    end
    return "[" .. table.concat(items, ", ") .. "]"

  elseif expr.type == "function_call" then
    local args = {}
    for _, arg in ipairs(expr.arguments or {}) do
      table.insert(args, ChapbookSerializer._serialize_expression(arg))
    end
    return expr.name .. "(" .. table.concat(args, ", ") .. ")"

  elseif type(expr) == "table" and expr.value ~= nil then
    if type(expr.value) == "string" then
      return string.format("'%s'", expr.value)
    else
      return tostring(expr.value)
    end

  else
    return tostring(expr.value or expr or "")
  end
end

--- Serialize condition
---@param cond table Condition node
---@return string Chapbook condition
function ChapbookSerializer._serialize_condition(cond)
  if not cond then return "true" end

  if cond.type == "binary_op" then
    return string.format("%s %s %s",
      ChapbookSerializer._serialize_expression(cond.left),
      cond.operator,
      ChapbookSerializer._serialize_expression(cond.right))

  elseif cond.type == "logical_op" then
    return string.format("%s %s %s",
      ChapbookSerializer._serialize_condition(cond.left),
      cond.operator,
      ChapbookSerializer._serialize_condition(cond.right))

  elseif cond.type == "not" then
    return "not " .. ChapbookSerializer._serialize_condition(cond.operand)

  else
    return ChapbookSerializer._serialize_expression(cond)
  end
end

return ChapbookSerializer
