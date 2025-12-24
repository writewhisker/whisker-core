--- VariableService
-- Variable management service with state dependency
-- @module whisker.services.variables
-- @author Whisker Core Team
-- @license MIT

local VariableService = {}
VariableService.__index = VariableService

VariableService.name = "variable_service"
VariableService.version = "2.2.0"

-- Prefix for variable keys in state
local VAR_PREFIX = "var:"

-- Dependencies for DI pattern
VariableService._dependencies = {"state", "event_bus", "condition_evaluator", "logger"}

--- Create a new VariableService instance via DI container
-- @param deps table Dependencies from container
-- @return function Factory function that creates VariableService instances
function VariableService.create(deps)
  return function(config)
    return VariableService.new(config, deps)
  end
end

--- Create a new variable service instance
-- @param config_or_container table|nil Configuration options or legacy container
-- @param deps table|nil Dependencies from container
-- @return VariableService
function VariableService.new(config_or_container, deps)
  local self = {
    _state = nil,
    _events = nil,
    _evaluator = nil,
    _logger = nil,
    _local_vars = {},  -- Fallback when state service not available
    _initialized = false
  }

  -- Handle backward compatibility with container parameter
  if config_or_container and type(config_or_container.has) == "function" then
    -- Legacy container-based initialization
    local container = config_or_container
    self._state = container:has("state") and container:resolve("state") or nil
    self._events = container:has("events") and container:resolve("events") or nil
    self._evaluator = container:has("condition_evaluator") and container:resolve("condition_evaluator") or nil
    self._logger = container:has("logger") and container:resolve("logger") or nil
  elseif deps then
    -- New DI pattern
    self._state = deps.state
    self._events = deps.event_bus
    self._evaluator = deps.condition_evaluator
    self._logger = deps.logger
  end

  self._initialized = true

  if self._logger then
    self._logger:debug("VariableService initialized")
  end

  return setmetatable(self, { __index = VariableService })
end

--- Get the service name
-- @return string The service name
function VariableService:getName()
  return "variables"
end

--- Check if the service is initialized
-- @return boolean True if initialized
function VariableService:isInitialized()
  return self._initialized == true
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

  if self._logger then
    self._logger:debug("Variable set: " .. tostring(name))
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

  if existed then
    if self._logger then
      self._logger:debug("Variable deleted: " .. tostring(name))
    end

    if self._events then
      self._events:emit("variable:deleted", {
        name = name,
        timestamp = os.time()
      })
    end
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

  if self._logger then
    self._logger:debug("Variables cleared")
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

  if self._logger then
    self._logger:debug("Evaluating condition: " .. tostring(condition))
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

  if self._logger then
    self._logger:debug("Variable incremented: " .. tostring(name) .. " by " .. tostring(amount))
  end

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

  if self._logger then
    self._logger:debug("Variable toggled: " .. tostring(name) .. " to " .. tostring(new_value))
  end

  return new_value
end

--- Destroy the service and cleanup
function VariableService:destroy()
  if self._logger then
    self._logger:debug("VariableService destroying")
  end

  self._local_vars = {}
  self._state = nil
  self._events = nil
  self._evaluator = nil
  self._logger = nil
  self._initialized = false
end

return VariableService
