-- whisker/formats/ink/generators/logic.lua
-- Generates Ink logic and expressions from whisker conditions

local LogicGenerator = {}
LogicGenerator.__index = LogicGenerator

-- Module metadata
LogicGenerator._whisker = {
  name = "LogicGenerator",
  version = "1.0.0",
  description = "Generates Ink logic and expressions from whisker conditions",
  depends = {},
  capability = "formats.ink.generators.logic"
}

-- Operator mapping from whisker to Ink
LogicGenerator.OPERATOR_MAP = {
  -- Arithmetic
  ["+"] = "+",
  ["-"] = "-",
  ["*"] = "*",
  ["/"] = "/",
  ["%"] = "%",
  -- Comparison
  ["=="] = "==",
  ["~="] = "!=",
  ["!="] = "!=",
  ["<"] = "<",
  [">"] = ">",
  ["<="] = "<=",
  [">="] = ">=",
  -- Logical
  ["and"] = "&&",
  ["or"] = "||",
  ["not"] = "!"
}

-- Create a new LogicGenerator instance
function LogicGenerator.new()
  local instance = {}
  setmetatable(instance, LogicGenerator)
  return instance
end

-- Map a whisker operator to Ink operator
-- @param op string - Whisker operator
-- @return string - Ink operator
function LogicGenerator:map_operator(op)
  return self.OPERATOR_MAP[op] or op
end

-- Generate an expression
-- @param expr table|any - Expression to generate
-- @return table - Array of Ink commands
function LogicGenerator:generate_expression(expr)
  local result = {}

  if type(expr) ~= "table" then
    -- Simple value
    table.insert(result, self:_convert_value(expr))
    return result
  end

  -- Variable reference
  if expr.variable then
    table.insert(result, { ["VAR?"] = expr.variable })
    return result
  end

  -- Visit count
  if expr.visit_count then
    table.insert(result, { ["CNT?"] = expr.visit_count })
    return result
  end

  -- Binary operation
  if expr.left and expr.right and expr.operator then
    -- Generate left operand
    local left_expr = self:generate_expression(expr.left)
    for _, item in ipairs(left_expr) do
      table.insert(result, item)
    end

    -- Generate right operand
    local right_expr = self:generate_expression(expr.right)
    for _, item in ipairs(right_expr) do
      table.insert(result, item)
    end

    -- Add operator
    table.insert(result, self:map_operator(expr.operator))

    return result
  end

  -- Unary operation (not)
  if expr.operand and expr.operator then
    local operand_expr = self:generate_expression(expr.operand)
    for _, item in ipairs(operand_expr) do
      table.insert(result, item)
    end
    table.insert(result, self:map_operator(expr.operator))
    return result
  end

  -- Literal value wrapped in table
  if expr.value ~= nil then
    table.insert(result, self:_convert_value(expr.value))
    return result
  end

  return result
end

-- Generate a condition block
-- @param condition table - Condition expression
-- @return table - Condition block with evaluation
function LogicGenerator:generate_condition(condition)
  local result = {}

  table.insert(result, "ev")

  local expr = self:generate_expression(condition)
  for _, item in ipairs(expr) do
    table.insert(result, item)
  end

  table.insert(result, "/ev")

  return result
end

-- Generate a conditional branch
-- @param condition table - The condition
-- @param true_content table - Content if true
-- @param false_content table|nil - Content if false
-- @return table - Branch structure
function LogicGenerator:generate_branch(condition, true_content, false_content)
  local result = {}

  -- Generate condition
  local cond = self:generate_condition(condition)
  for _, item in ipairs(cond) do
    table.insert(result, item)
  end

  -- Add branch structure
  -- This is simplified - full implementation would need proper containers
  if true_content then
    table.insert(result, true_content)
  end

  if false_content then
    table.insert(result, false_content)
  end

  return result
end

-- Convert a value to Ink format
-- @param value any - Value to convert
-- @return any - Converted value
function LogicGenerator:_convert_value(value)
  local t = type(value)

  if t == "string" then
    return { ["^"] = value }
  elseif t == "number" then
    return value
  elseif t == "boolean" then
    return value
  elseif t == "nil" then
    return 0
  end

  return value
end

-- Get the operator map
-- @return table - Map of operators
function LogicGenerator:get_operator_map()
  return self.OPERATOR_MAP
end

-- Check if operator is comparison
-- @param op string - Operator to check
-- @return boolean
function LogicGenerator:is_comparison(op)
  local comparisons = { "==", "!=", "~=", "<", ">", "<=", ">=" }
  for _, c in ipairs(comparisons) do
    if op == c then return true end
  end
  return false
end

-- Check if operator is logical
-- @param op string - Operator to check
-- @return boolean
function LogicGenerator:is_logical(op)
  return op == "and" or op == "or" or op == "not" or
         op == "&&" or op == "||" or op == "!"
end

return LogicGenerator
