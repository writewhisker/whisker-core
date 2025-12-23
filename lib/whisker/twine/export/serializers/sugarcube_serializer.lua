--- SugarCube AST to text serializer
-- Converts WhiskerScript AST back to SugarCube macro syntax
--
-- lib/whisker/twine/export/serializers/sugarcube_serializer.lua

local SugarCubeSerializer = {}

--------------------------------------------------------------------------------
-- Main Serialization
--------------------------------------------------------------------------------

--- Serialize AST to SugarCube text
---@param ast table Array of AST nodes
---@return string SugarCube passage text
function SugarCubeSerializer.serialize(ast)
  if not ast or #ast == 0 then
    return ""
  end

  local parts = {}

  for _, node in ipairs(ast) do
    local serialized = SugarCubeSerializer._serialize_node(node)
    if serialized then
      table.insert(parts, serialized)
    end
  end

  return table.concat(parts, "")
end

--------------------------------------------------------------------------------
-- Node Serialization
--------------------------------------------------------------------------------

--- Serialize single node
---@param node table AST node
---@return string|nil Serialized text
function SugarCubeSerializer._serialize_node(node)
  local node_type = node.type

  if node_type == "text" then
    return node.value or node.content or ""

  elseif node_type == "assignment" then
    return string.format("<<set $%s to %s>>",
      node.variable,
      SugarCubeSerializer._serialize_expression(node.value))

  elseif node_type == "conditional" then
    return SugarCubeSerializer._serialize_if(node)

  elseif node_type == "choice" then
    return SugarCubeSerializer._serialize_link(node)

  elseif node_type == "goto" then
    return string.format('<<goto "%s">>', node.destination)

  elseif node_type == "for_loop" then
    return SugarCubeSerializer._serialize_for(node)

  elseif node_type == "print" then
    return string.format("<<print %s>>",
      SugarCubeSerializer._serialize_expression(node.expression))

  elseif node_type == "script_block" then
    return string.format("<<script>>\n%s\n<</script>>", node.code or "")

  elseif node_type == "widget" then
    return SugarCubeSerializer._serialize_widget(node)

  else
    return "<!-- Unsupported: " .. node_type .. " -->"
  end
end

--------------------------------------------------------------------------------
-- Macro Serialization
--------------------------------------------------------------------------------

--- Serialize if/elseif/else
---@param node table Conditional node
---@return string SugarCube if macro
function SugarCubeSerializer._serialize_if(node)
  local parts = {}

  local condition = SugarCubeSerializer._serialize_condition(node.condition)
  local body = SugarCubeSerializer.serialize(node.body or {})

  table.insert(parts, string.format("<<if %s>>%s", condition, body))

  if node.elsif_clauses then
    for _, elsif in ipairs(node.elsif_clauses) do
      local elsif_cond = SugarCubeSerializer._serialize_condition(elsif.condition)
      local elsif_body = SugarCubeSerializer.serialize(elsif.body or {})
      table.insert(parts, string.format("<<elseif %s>>%s", elsif_cond, elsif_body))
    end
  end

  if node.else_body then
    local else_body = SugarCubeSerializer.serialize(node.else_body)
    table.insert(parts, string.format("<<else>>%s", else_body))
  end

  table.insert(parts, "<</if>>")

  return table.concat(parts, "")
end

--- Serialize link
---@param node table Choice node
---@return string SugarCube link
function SugarCubeSerializer._serialize_link(node)
  if node.destination then
    if node.text == node.destination then
      -- Simple wiki link [[text]]
      return string.format("[[%s]]", node.text)
    elseif node.body and #node.body > 0 then
      local body = SugarCubeSerializer.serialize(node.body)
      return string.format('<<link "%s" "%s">>%s<</link>>',
        node.text, node.destination, body)
    else
      -- Arrow link [[text->dest]]
      return string.format("[[%s->%s]]", node.text, node.destination)
    end
  else
    return string.format("[[%s]]", node.text)
  end
end

--- Serialize for loop
---@param node table For loop node
---@return string SugarCube for macro
function SugarCubeSerializer._serialize_for(node)
  local body = SugarCubeSerializer.serialize(node.body or {})

  if node.loop_type == "range" then
    return string.format("<<for $%s = %s; $%s < %s; $%s++>>%s<</for>>",
      node.variable,
      SugarCubeSerializer._serialize_expression(node.start_value or { value = 0 }),
      node.variable,
      SugarCubeSerializer._serialize_expression(node.end_value),
      node.variable,
      body)
  else
    -- Range iteration
    return string.format("<<for $%s range %s>>%s<</for>>",
      node.variable,
      SugarCubeSerializer._serialize_expression(node.collection),
      body)
  end
end

--- Serialize widget
---@param node table Widget node
---@return string SugarCube widget macro
function SugarCubeSerializer._serialize_widget(node)
  local body = SugarCubeSerializer.serialize(node.body or {})
  return string.format("<<widget \"%s\">>%s<</widget>>", node.name, body)
end

--------------------------------------------------------------------------------
-- Expression Serialization
--------------------------------------------------------------------------------

--- Serialize expression
---@param expr table Expression node
---@return string SugarCube expression
function SugarCubeSerializer._serialize_expression(expr)
  if not expr then return "" end

  if expr.type == "literal" then
    if expr.value_type == "string" then
      return string.format('"%s"', expr.value)
    elseif expr.value_type == "boolean" then
      return expr.value and "true" or "false"
    else
      return tostring(expr.value)
    end

  elseif expr.type == "variable_ref" then
    return "$" .. expr.name

  elseif expr.type == "binary_op" then
    return string.format("%s %s %s",
      SugarCubeSerializer._serialize_expression(expr.left),
      expr.operator,
      SugarCubeSerializer._serialize_expression(expr.right))

  elseif expr.type == "array_literal" then
    local items = {}
    for _, item in ipairs(expr.items or {}) do
      table.insert(items, SugarCubeSerializer._serialize_expression(item))
    end
    return "[" .. table.concat(items, ", ") .. "]"

  elseif type(expr) == "table" and expr.value ~= nil then
    if type(expr.value) == "string" then
      return string.format('"%s"', expr.value)
    else
      return tostring(expr.value)
    end

  else
    return tostring(expr.value or expr or "")
  end
end

--- Serialize condition
---@param cond table Condition node
---@return string SugarCube condition
function SugarCubeSerializer._serialize_condition(cond)
  if not cond then return "true" end

  if cond.type == "binary_op" then
    return string.format("%s %s %s",
      SugarCubeSerializer._serialize_expression(cond.left),
      cond.operator,
      SugarCubeSerializer._serialize_expression(cond.right))

  elseif cond.type == "logical_op" then
    return string.format("%s %s %s",
      SugarCubeSerializer._serialize_condition(cond.left),
      cond.operator,
      SugarCubeSerializer._serialize_condition(cond.right))

  elseif cond.type == "not" then
    return "not " .. SugarCubeSerializer._serialize_condition(cond.operand)

  else
    return SugarCubeSerializer._serialize_expression(cond)
  end
end

return SugarCubeSerializer
