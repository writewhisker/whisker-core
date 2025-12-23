--- VariableService
-- Variable management service with state dependency
-- @module whisker.services.variables
-- @author Whisker Core Team
-- @license MIT

local VariableService = {}
VariableService.__index = VariableService

VariableService.name = "variable_service"
VariableService.version = "2.1.0"

-- Prefix for variable keys in state
local VAR_PREFIX = "var:"

--- Create a new variable service instance
-- @param container Container The DI container
-- @return VariableService
function VariableService.new(container)
  local self = {
    _state = container and container:has("state") and container:resolve("state") or nil,
    _events = container and container:has("events") and container:resolve("events") or nil,
    _evaluator = container and container:has("condition_evaluator") and container:resolve("condition_evaluator") or nil,
    _local_vars = {},  -- Fallback when state service not available
  }

  return setmetatable(self, { __index = VariableService })
end

--- Set a variable value
-- @param name string Variable name
-- @param value any Variable value
function VariableService:set(name, value)
  local old_value = self:get(name)

  if self._state then
    local key = VAR_PREFIX .. name
    self._state:set(key, value)
  else
    self._local_vars[name] = value
  end

  if self._events then
    self._events:emit("variable:changed", {
      name = name,
      old_value = old_value,
      new_value = value,
      timestamp = os.time()
    })
  end
end

--- Get a variable value
-- @param name string Variable name
-- @return any value The variable value, or nil if not set
function VariableService:get(name)
  if self._state then
    local key = VAR_PREFIX .. name
    return self._state:get(key)
  else
    return self._local_vars[name]
  end
end

--- Check if a variable exists
-- @param name string Variable name
-- @return boolean exists True if variable is set
function VariableService:has(name)
  if self._state then
    local key = VAR_PREFIX .. name
    return self._state:has(key)
  else
    return self._local_vars[name] ~= nil
  end
end

--- Delete a variable
-- @param name string Variable name
-- @return boolean deleted True if variable was deleted
function VariableService:delete(name)
  local existed = self:has(name)

  if self._state then
    local key = VAR_PREFIX .. name
    self._state:delete(key)
  else
    self._local_vars[name] = nil
  end

  if existed and self._events then
    self._events:emit("variable:deleted", {
      name = name,
      timestamp = os.time()
    })
  end

  return existed
end

--- Get all variable names
-- @return string[] names List of variable names
function VariableService:list()
  local result = {}

  if self._state then
    local prefix_len = #VAR_PREFIX
    for _, key in ipairs(self._state:keys()) do
      if key:sub(1, prefix_len) == VAR_PREFIX then
        table.insert(result, key:sub(prefix_len + 1))
      end
    end
  else
    for name in pairs(self._local_vars) do
      table.insert(result, name)
    end
  end

  table.sort(result)
  return result
end

--- Get all variables as a table
-- @return table variables Map of name -> value
function VariableService:get_all()
  local result = {}
  for _, name in ipairs(self:list()) do
    result[name] = self:get(name)
  end
  return result
end

--- Clear all variables
function VariableService:clear()
  if self._state then
    -- Only clear variables (with prefix)
    for _, name in ipairs(self:list()) do
      local key = VAR_PREFIX .. name
      self._state:delete(key)
    end
  else
    self._local_vars = {}
  end

  if self._events then
    self._events:emit("variables:cleared", {
      timestamp = os.time()
    })
  end
end

--- Evaluate a condition with current variables as context
-- @param condition string The condition expression
-- @return boolean result The evaluation result
function VariableService:evaluate(condition)
  if not self._evaluator then
    error("No condition evaluator available")
  end

  -- Build context from all variables
  local context = self:get_all()
  return self._evaluator:evaluate(condition, context)
end

--- Increment a numeric variable
-- @param name string Variable name
-- @param amount number Amount to add (default 1)
-- @return number new_value The new value
function VariableService:increment(name, amount)
  amount = amount or 1
  local current = self:get(name) or 0
  local new_value = current + amount
  self:set(name, new_value)
  return new_value
end

--- Decrement a numeric variable
-- @param name string Variable name
-- @param amount number Amount to subtract (default 1)
-- @return number new_value The new value
function VariableService:decrement(name, amount)
  amount = amount or 1
  return self:increment(name, -amount)
end

--- Toggle a boolean variable
-- @param name string Variable name
-- @return boolean new_value The new value
function VariableService:toggle(name)
  local current = self:get(name)
  local new_value = not current
  self:set(name, new_value)
  return new_value
end

--- Destroy the service and cleanup
function VariableService:destroy()
  self._local_vars = {}
  self._state = nil
  self._events = nil
  self._evaluator = nil
end

return VariableService
