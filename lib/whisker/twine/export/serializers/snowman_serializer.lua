--- Snowman AST to template serializer
-- Converts WhiskerScript AST back to Snowman ERB-style templates
--
-- lib/whisker/twine/export/serializers/snowman_serializer.lua

local SnowmanSerializer = {}

--------------------------------------------------------------------------------
-- Main Serialization
--------------------------------------------------------------------------------

--- Serialize AST to Snowman templates
---@param ast table Array of AST nodes
---@return string Snowman passage text
function SnowmanSerializer.serialize(ast)
  if not ast or #ast == 0 then
    return ""
  end

  local parts = {}

  for _, node in ipairs(ast) do
    local serialized = SnowmanSerializer._serialize_node(node)
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
function SnowmanSerializer._serialize_node(node)
  if node.type == "text" then
    return node.value or node.content or ""

  elseif node.type == "assignment" then
    return string.format("<%%  s.%s = %s %%>",
      node.variable,
      SnowmanSerializer._serialize_expression(node.value))

  elseif node.type == "conditional" then
    local condition = SnowmanSerializer._serialize_condition(node.condition)
    local body = SnowmanSerializer.serialize(node.body or {})

    local result = string.format("<%% if (%s) { %%>%s", condition, body)

    if node.elsif_clauses then
      for _, elsif in ipairs(node.elsif_clauses) do
        local elsif_cond = SnowmanSerializer._serialize_condition(elsif.condition)
        local elsif_body = SnowmanSerializer.serialize(elsif.body or {})
        result = result .. string.format("<%% } else if (%s) { %%>%s", elsif_cond, elsif_body)
      end
    end

    if node.else_body then
      local else_body = SnowmanSerializer.serialize(node.else_body)
      result = result .. string.format("<%% } else { %%>%s", else_body)
    end

    result = result .. "<% } %>"

    return result

  elseif node.type == "choice" then
    if node.destination then
      return string.format('<a href="javascript:void(0)" data-passage="%s">%s</a>',
        node.destination, node.text)
    else
      return string.format('<a href="javascript:void(0)">%s</a>', node.text)
    end

  elseif node.type == "goto" then
    return string.format("<%%  window.story.show('%s'); %%>", node.destination)

  elseif node.type == "print" then
    return string.format("<%%= %s %%>",
      SnowmanSerializer._serialize_expression(node.expression))

  elseif node.type == "script_block" then
    return string.format("<%%  %s %%>", node.code or "")

  elseif node.type == "for_loop" then
    return SnowmanSerializer._serialize_for(node)

  else
    return ""
  end
end

--------------------------------------------------------------------------------
-- Loop Serialization
--------------------------------------------------------------------------------

--- Serialize for loop
---@param node table For loop node
---@return string Snowman for loop
function SnowmanSerializer._serialize_for(node)
  local body = SnowmanSerializer.serialize(node.body or {})

  if node.collection then
    -- Array iteration
    return string.format(
      "<%%  s.%s.forEach(function(%s) { %%>%s<%%  }); %%>",
      SnowmanSerializer._serialize_expression(node.collection),
      node.variable,
      body)
  else
    -- Range loop
    return string.format(
      "<%%  for (var %s = %s; %s < %s; %s++) { %%>%s<%%  } %%>",
      node.variable,
      SnowmanSerializer._serialize_expression(node.start_value or { value = 0 }),
      node.variable,
      SnowmanSerializer._serialize_expression(node.end_value),
      node.variable,
      body)
  end
end

--------------------------------------------------------------------------------
-- Expression Serialization
--------------------------------------------------------------------------------

--- Serialize expression
---@param expr table Expression node
---@return string Snowman expression
function SnowmanSerializer._serialize_expression(expr)
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
    return "s." .. expr.name

  elseif expr.type == "binary_op" then
    return string.format("%s %s %s",
      SnowmanSerializer._serialize_expression(expr.left),
      expr.operator,
      SnowmanSerializer._serialize_expression(expr.right))

  elseif expr.type == "array_literal" then
    local items = {}
    for _, item in ipairs(expr.items or {}) do
      table.insert(items, SnowmanSerializer._serialize_expression(item))
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
---@return string Snowman condition (JavaScript style)
function SnowmanSerializer._serialize_condition(cond)
  if not cond then return "true" end

  if cond.type == "binary_op" then
    -- Convert Lua operators to JavaScript
    local op = cond.operator
    if op == "~=" then op = "!=" end
    if op == "==" then op = "===" end  -- Use strict equality

    return string.format("%s %s %s",
      SnowmanSerializer._serialize_expression(cond.left),
      op,
      SnowmanSerializer._serialize_expression(cond.right))

  elseif cond.type == "logical_op" then
    -- Convert Lua logical operators to JavaScript
    local op = cond.operator
    if op == "and" then op = "&&" end
    if op == "or" then op = "||" end

    return string.format("%s %s %s",
      SnowmanSerializer._serialize_condition(cond.left),
      op,
      SnowmanSerializer._serialize_condition(cond.right))

  elseif cond.type == "not" then
    return "!" .. SnowmanSerializer._serialize_condition(cond.operand)

  else
    return SnowmanSerializer._serialize_expression(cond)
  end
end

return SnowmanSerializer
