-- whisker/formats/ink/transformers/logic.lua
-- Logic transformer for Ink to Whisker conversion
-- Converts Ink operators and expressions to whisker format

local LogicTransformer = {}
LogicTransformer.__index = LogicTransformer

-- Module metadata
LogicTransformer._whisker = {
  name = "LogicTransformer",
  version = "1.0.0",
  description = "Transforms Ink logic operators to whisker format",
  depends = {},
  capability = "formats.ink.transformers.logic"
}

-- Operator mappings from Ink to Lua/whisker
LogicTransformer.OPERATOR_MAP = {
  -- Arithmetic
  ["+"] = "+",
  ["-"] = "-",
  ["*"] = "*",
  ["/"] = "/",
  ["%"] = "%",
  ["_"] = "-",  -- Unary minus in Ink

  -- Comparison
  ["=="] = "==",
  ["!="] = "~=",  -- Lua uses ~= for not equal
  ["<"] = "<",
  [">"] = ">",
  ["<="] = "<=",
  [">="] = ">=",

  -- Logical
  ["&&"] = "and",
  ["||"] = "or",
  ["!"] = "not",

  -- Special Ink operators
  ["?"] = "has",      -- List contains
  ["!?"] = "not_has", -- List doesn't contain
  ["^"] = "intersect" -- List intersection
}

-- Create a new LogicTransformer instance
function LogicTransformer.new()
  local instance = {}
  setmetatable(instance, LogicTransformer)
  return instance
end

-- Transform an Ink operator to whisker/Lua equivalent
-- @param operator string - The Ink operator
-- @return string - The whisker/Lua equivalent
function LogicTransformer:transform_operator(operator)
  return self.OPERATOR_MAP[operator] or operator
end

-- Transform an Ink expression to whisker format
-- @param expression table - The Ink expression (parsed from JSON)
-- @param options table|nil - Conversion options
-- @return string - The whisker expression string
function LogicTransformer:transform_expression(expression, options)
  options = options or {}

  if type(expression) ~= "table" then
    return tostring(expression)
  end

  -- Handle different expression types
  if expression["^"] then
    -- String literal
    return self:_quote_string(expression["^"])
  elseif expression["VAR?"] then
    -- Variable reference
    return expression["VAR?"]
  elseif expression["CNT?"] then
    -- Visit count
    return "visit_count(\"" .. expression["CNT?"] .. "\")"
  end

  return self:_transform_complex(expression, options)
end

-- Transform a complex expression
function LogicTransformer:_transform_complex(expression, options)
  local parts = {}

  for i, item in ipairs(expression) do
    if type(item) == "string" then
      -- Check if it's an operator
      local mapped = self:transform_operator(item)
      if mapped ~= item or self:_is_operator(item) then
        table.insert(parts, mapped)
      else
        -- Might be a string value
        table.insert(parts, self:_quote_string(item))
      end
    elseif type(item) == "table" then
      -- Recurse into nested expression
      table.insert(parts, self:transform_expression(item, options))
    elseif type(item) == "number" then
      table.insert(parts, tostring(item))
    elseif type(item) == "boolean" then
      table.insert(parts, item and "true" or "false")
    end
  end

  return table.concat(parts, " ")
end

-- Check if a string is an operator
function LogicTransformer:_is_operator(str)
  return self.OPERATOR_MAP[str] ~= nil
end

-- Quote a string for output
function LogicTransformer:_quote_string(str)
  if type(str) ~= "string" then
    return tostring(str)
  end
  -- Escape quotes and return quoted string
  local escaped = str:gsub("\\", "\\\\"):gsub("\"", "\\\"")
  return "\"" .. escaped .. "\""
end

-- Transform an Ink condition to whisker format
-- @param condition table - The Ink condition
-- @param options table|nil - Conversion options
-- @return string - The whisker condition string
function LogicTransformer:transform_condition(condition, options)
  return self:transform_expression(condition, options)
end

-- Transform an Ink assignment operation
-- @param target string - Variable name
-- @param value any - Value or expression
-- @param operator string|nil - Assignment operator (=, +=, -=, etc)
-- @return string - The whisker assignment string
function LogicTransformer:transform_assignment(target, value, operator)
  operator = operator or "="

  local value_str
  if type(value) == "table" then
    value_str = self:transform_expression(value, {})
  else
    value_str = tostring(value)
  end

  -- Handle compound assignments
  if operator == "+=" then
    return target .. " = " .. target .. " + " .. value_str
  elseif operator == "-=" then
    return target .. " = " .. target .. " - " .. value_str
  elseif operator == "*=" then
    return target .. " = " .. target .. " * " .. value_str
  elseif operator == "/=" then
    return target .. " = " .. target .. " / " .. value_str
  end

  return target .. " = " .. value_str
end

-- Get the operator map for reference
function LogicTransformer:get_operator_map()
  return self.OPERATOR_MAP
end

return LogicTransformer
