-- whisker/services/conditions/init.lua
-- Condition Evaluator service implementing IConditionEvaluator
-- Evaluates conditions for choice visibility and game logic

local ConditionEvaluator = {}
ConditionEvaluator.__index = ConditionEvaluator

-- Module metadata for container auto-registration
ConditionEvaluator._whisker = {
  name = "ConditionEvaluator",
  version = "2.0.0",
  description = "Condition evaluator implementing IConditionEvaluator",
  depends = {},
  implements = "IConditionEvaluator",
  capability = "services.conditions"
}

-- Standard operators (order matters for matching - longer operators first)
local STANDARD_OPERATORS = {
  ["=="] = function(a, b) return a == b end,
  ["!="] = function(a, b) return a ~= b end,
  ["~="] = function(a, b) return a ~= b end,  -- Lua-style
  ["<="] = function(a, b)
    if a == nil or b == nil then return false end
    return a <= b
  end,
  [">="] = function(a, b)
    if a == nil or b == nil then return false end
    return a >= b
  end,
  ["<"] = function(a, b)
    if a == nil or b == nil then return false end
    return a < b
  end,
  [">"] = function(a, b)
    if a == nil or b == nil then return false end
    return a > b
  end,
}

-- Operator matching order (longer first to prevent partial matches)
local OPERATOR_ORDER = {"<=", ">=", "==", "!=", "~=", "<", ">"}

-- Create a new ConditionEvaluator instance
-- @param options table|nil - Optional configuration
-- @return ConditionEvaluator
function ConditionEvaluator.new(options)
  options = options or {}
  local instance = {
    _state_service = options.state or nil,
    _operators = {},
    _functions = {}
  }

  -- Copy standard operators
  for name, fn in pairs(STANDARD_OPERATORS) do
    instance._operators[name] = fn
  end

  setmetatable(instance, ConditionEvaluator)
  return instance
end

-- Set the state service for variable resolution
function ConditionEvaluator:set_state_service(state)
  self._state_service = state
end

-- Get the state service
function ConditionEvaluator:get_state_service()
  return self._state_service
end

-- Register a custom operator
-- @param name string - Operator name
-- @param fn function - Operator implementation (a, b) -> result
function ConditionEvaluator:register_operator(name, fn)
  self._operators[name] = fn
end

-- Register a custom function
-- @param name string - Function name
-- @param fn function - Function implementation (args...) -> result
function ConditionEvaluator:register_function(name, fn)
  self._functions[name] = fn
end

-- Resolve a variable name to its value
-- @param name string - Variable name
-- @param context table|nil - Context with optional state
-- @return any - Variable value or nil
function ConditionEvaluator:resolve_variable(name, context)
  -- First check context
  if context and context[name] ~= nil then
    return context[name]
  end

  -- Then check context.state
  if context and context.state then
    if context.state.get then
      return context.state:get(name)
    elseif context.state[name] ~= nil then
      return context.state[name]
    end
  end

  -- Then check state service
  if self._state_service and self._state_service.get then
    return self._state_service:get(name)
  end

  return nil
end

-- Evaluate a simple condition string
-- Supports formats:
--   "variable" - true if variable is truthy
--   "variable == value"
--   "variable > 10"
-- @param condition string - Condition expression
-- @param context table|nil - Context with state/variables
-- @return boolean
function ConditionEvaluator:evaluate_string(condition, context)
  condition = condition:gsub("^%s+", ""):gsub("%s+$", "")  -- trim

  if condition == "" then
    return true
  end

  -- Handle "not variable" or "!variable"
  local negated = false
  if condition:match("^not%s+") then
    negated = true
    condition = condition:gsub("^not%s+", "")
  elseif condition:match("^!%s*") then
    negated = true
    condition = condition:gsub("^!%s*", "")
  end

  -- Try to parse as comparison (use ordered operators to match longer ones first)
  for _, op_name in ipairs(OPERATOR_ORDER) do
    local op_fn = self._operators[op_name]
    if op_fn then
      local pattern = "^(.-)%s*" .. op_name:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1") .. "%s*(.-)$"
      local left, right = condition:match(pattern)

      if left and right then
        left = left:gsub("^%s+", ""):gsub("%s+$", "")
        right = right:gsub("^%s+", ""):gsub("%s+$", "")

        -- Resolve left side (variable)
        local left_val = self:resolve_variable(left, context)

        -- Parse right side (could be number, string, boolean, or variable)
        local right_val
        if right:match("^%d+%.?%d*$") then
          right_val = tonumber(right)
        elseif right == "true" then
          right_val = true
        elseif right == "false" then
          right_val = false
        elseif right == "nil" then
          right_val = nil
        elseif right:match("^['\"].*['\"]$") then
          right_val = right:sub(2, -2)  -- Remove quotes
        else
          right_val = self:resolve_variable(right, context)
        end

        local result = op_fn(left_val, right_val)
        if negated then
          return not result
        end
        return result
      end
    end
  end

  -- Handle "and" / "or" expressions
  local and_left, and_right = condition:match("(.-)%s+and%s+(.*)")
  if and_left and and_right then
    local result = self:evaluate_string(and_left, context) and self:evaluate_string(and_right, context)
    if negated then
      return not result
    end
    return result
  end

  local or_left, or_right = condition:match("(.-)%s+or%s+(.*)")
  if or_left and or_right then
    local result = self:evaluate_string(or_left, context) or self:evaluate_string(or_right, context)
    if negated then
      return not result
    end
    return result
  end

  -- Just a variable name - check if truthy
  local value = self:resolve_variable(condition, context)
  local result = value and value ~= false and value ~= 0 and value ~= ""
  if negated then
    return not result
  end
  return result
end

-- Evaluate a table-based condition
-- Supports formats:
--   { var = "health", op = ">", value = 0 }
--   { left = "health", op = ">", right = 0 }
--   { all = { cond1, cond2 } }  -- AND
--   { any = { cond1, cond2 } }  -- OR
--   { not = condition }
-- @param condition table - Condition table
-- @param context table|nil - Context with state/variables
-- @return boolean
function ConditionEvaluator:evaluate_table(condition, context)
  -- Handle "not" wrapper
  if condition["not"] then
    return not self:evaluate(condition["not"], context)
  end

  -- Handle "all" (AND)
  if condition.all then
    for _, sub in ipairs(condition.all) do
      if not self:evaluate(sub, context) then
        return false
      end
    end
    return true
  end

  -- Handle "any" (OR)
  if condition.any then
    for _, sub in ipairs(condition.any) do
      if self:evaluate(sub, context) then
        return true
      end
    end
    return false
  end

  -- Handle single comparison
  local var_name = condition.var or condition.left or condition.variable
  local op = condition.op or condition.operator or "=="
  local value = condition.value
  if value == nil then
    value = condition.right
  end

  if var_name then
    local var_value = self:resolve_variable(var_name, context)
    local op_fn = self._operators[op]

    if op_fn then
      return op_fn(var_value, value)
    end
  end

  return false
end

-- Evaluate a condition (string or table)
-- @param condition string|table - Condition to evaluate
-- @param context table|nil - Context with state/variables
-- @return boolean
function ConditionEvaluator:evaluate(condition, context)
  if condition == nil or condition == "" then
    return true
  end

  if type(condition) == "boolean" then
    return condition
  end

  if type(condition) == "string" then
    return self:evaluate_string(condition, context)
  end

  if type(condition) == "table" then
    return self:evaluate_table(condition, context)
  end

  return false
end

return ConditionEvaluator
