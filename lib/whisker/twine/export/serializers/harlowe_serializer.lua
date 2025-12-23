--- Harlowe AST to text serializer
-- Converts WhiskerScript AST back to Harlowe macro syntax
--
-- lib/whisker/twine/export/serializers/harlowe_serializer.lua

local HarloweSerializer = {}

--------------------------------------------------------------------------------
-- Main Serialization
--------------------------------------------------------------------------------

--- Serialize AST nodes to Harlowe text
---@param ast table Array of AST nodes
---@return string Harlowe passage text
function HarloweSerializer.serialize(ast)
  if not ast or #ast == 0 then
    return ""
  end

  local parts = {}

  for _, node in ipairs(ast) do
    local serialized = HarloweSerializer._serialize_node(node)
    if serialized then
      table.insert(parts, serialized)
    end
  end

  return table.concat(parts, "")
end

--------------------------------------------------------------------------------
-- Node Serialization
--------------------------------------------------------------------------------

--- Serialize single AST node
---@param node table AST node
---@return string|nil Serialized text
function HarloweSerializer._serialize_node(node)
  local node_type = node.type

  if node_type == "text" then
    return node.value or node.content or ""

  elseif node_type == "assignment" then
    return HarloweSerializer._serialize_set(node)

  elseif node_type == "conditional" then
    return HarloweSerializer._serialize_if(node)

  elseif node_type == "choice" then
    return HarloweSerializer._serialize_link(node)

  elseif node_type == "goto" then
    return HarloweSerializer._serialize_goto(node)

  elseif node_type == "for_loop" then
    return HarloweSerializer._serialize_for(node)

  elseif node_type == "array_literal" then
    return HarloweSerializer._serialize_array(node)

  elseif node_type == "table_literal" then
    return HarloweSerializer._serialize_datamap(node)

  elseif node_type == "print" then
    return HarloweSerializer._serialize_print(node)

  else
    return "<!-- Unsupported node type: " .. node_type .. " -->"
  end
end

--------------------------------------------------------------------------------
-- Macro Serialization
--------------------------------------------------------------------------------

--- Serialize assignment: (set: $var to value)
---@param node table Assignment node
---@return string Harlowe set macro
function HarloweSerializer._serialize_set(node)
  local var_name = node.variable
  local value = HarloweSerializer._serialize_expression(node.value)

  return string.format("(set: $%s to %s)", var_name, value)
end

--- Serialize conditional: (if: condition)[body]
---@param node table Conditional node
---@return string Harlowe if macro
function HarloweSerializer._serialize_if(node)
  local condition = HarloweSerializer._serialize_condition(node.condition)
  local body = HarloweSerializer.serialize(node.body or {})

  local result = string.format("(if: %s)[%s]", condition, body)

  -- Add elsif/else if present
  if node.elsif_clauses then
    for _, elsif in ipairs(node.elsif_clauses) do
      local elsif_cond = HarloweSerializer._serialize_condition(elsif.condition)
      local elsif_body = HarloweSerializer.serialize(elsif.body or {})
      result = result .. string.format("(else-if: %s)[%s]", elsif_cond, elsif_body)
    end
  end

  if node.else_body then
    local else_body = HarloweSerializer.serialize(node.else_body)
    result = result .. string.format("(else:)[%s]", else_body)
  end

  return result
end

--- Serialize link/choice
---@param node table Choice node
---@return string Harlowe link
function HarloweSerializer._serialize_link(node)
  local text = node.text

  if node.destination and node.destination ~= "" then
    if text == node.destination then
      -- Simple link [[text]]
      return string.format("[[%s]]", text)
    else
      -- (link-goto: "text", "dest")
      return string.format('(link-goto: "%s", "%s")', text, node.destination)
    end
  elseif node.body and #node.body > 0 then
    -- (link: "text")[body]
    local body = HarloweSerializer.serialize(node.body)
    return string.format('(link: "%s")[%s]', text, body)
  else
    -- Simple link
    return string.format("[[%s]]", text)
  end
end

--- Serialize goto: (goto: "destination")
---@param node table Goto node
---@return string Harlowe goto macro
function HarloweSerializer._serialize_goto(node)
  return string.format('(goto: "%s")', node.destination)
end

--- Serialize for loop: (for: each _var, ...$collection)[body]
---@param node table For loop node
---@return string Harlowe for macro
function HarloweSerializer._serialize_for(node)
  local var_name = node.variable
  local collection = HarloweSerializer._serialize_expression(node.collection)
  local body = HarloweSerializer.serialize(node.body or {})

  return string.format("(for: each _%s, ...%s)[%s]", var_name, collection, body)
end

--- Serialize array: (a: item1, item2, ...)
---@param node table Array literal node
---@return string Harlowe array
function HarloweSerializer._serialize_array(node)
  local items = {}

  for _, item in ipairs(node.items or {}) do
    table.insert(items, HarloweSerializer._serialize_expression(item))
  end

  return "(a: " .. table.concat(items, ", ") .. ")"
end

--- Serialize datamap: (dm: "key", value, ...)
---@param node table Table literal node
---@return string Harlowe datamap
function HarloweSerializer._serialize_datamap(node)
  local pairs_list = {}

  for _, pair in ipairs(node.pairs or {}) do
    local key = string.format('"%s"', pair.key)
    local value = HarloweSerializer._serialize_expression(pair.value)
    table.insert(pairs_list, key .. ", " .. value)
  end

  return "(dm: " .. table.concat(pairs_list, ", ") .. ")"
end

--- Serialize print: (print: expression)
---@param node table Print node
---@return string Harlowe print macro
function HarloweSerializer._serialize_print(node)
  local expr = HarloweSerializer._serialize_expression(node.expression)
  return string.format("(print: %s)", expr)
end

--------------------------------------------------------------------------------
-- Expression Serialization
--------------------------------------------------------------------------------

--- Serialize expression
---@param expr table Expression node
---@return string Harlowe expression
function HarloweSerializer._serialize_expression(expr)
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
    local left = HarloweSerializer._serialize_expression(expr.left)
    local right = HarloweSerializer._serialize_expression(expr.right)
    return left .. " " .. expr.operator .. " " .. right

  elseif expr.type == "array_literal" then
    return HarloweSerializer._serialize_array(expr)

  elseif type(expr) == "table" and expr.value ~= nil then
    -- Simple value wrapper
    if type(expr.value) == "string" then
      return string.format('"%s"', expr.value)
    else
      return tostring(expr.value)
    end

  else
    return tostring(expr.value or expr or "")
  end
end

--- Serialize condition (converts operators to Harlowe style)
---@param cond table Condition node
---@return string Harlowe condition
function HarloweSerializer._serialize_condition(cond)
  if not cond then return "true" end

  if cond.type == "binary_op" then
    local left = HarloweSerializer._serialize_expression(cond.left)
    local right = HarloweSerializer._serialize_expression(cond.right)

    -- Convert operators to Harlowe keywords
    local op = cond.operator
    if op == "==" then op = "is" end
    if op == "!=" or op == "~=" then op = "is not" end

    return left .. " " .. op .. " " .. right

  elseif cond.type == "logical_op" then
    local left = HarloweSerializer._serialize_condition(cond.left)
    local right = HarloweSerializer._serialize_condition(cond.right)
    return left .. " " .. cond.operator .. " " .. right

  elseif cond.type == "not" then
    local operand = HarloweSerializer._serialize_condition(cond.operand)
    return "not " .. operand

  else
    return HarloweSerializer._serialize_expression(cond)
  end
end

return HarloweSerializer
