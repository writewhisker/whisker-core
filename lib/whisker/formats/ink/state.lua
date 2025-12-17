-- whisker/formats/ink/state.lua
-- InkState IState implementation
-- Bridges tinta's state management to whisker-core interface

local InkState = {}
InkState.__index = InkState

-- Module metadata for container auto-registration
InkState._whisker = {
  name = "InkState",
  version = "1.0.0",
  description = "Ink story state implementing IState",
  depends = {},
  implements = "IState",
  capability = "state.ink"
}

-- Create a new InkState instance
-- @param engine InkEngine - The engine this state is associated with
-- @return InkState
function InkState.new(engine)
  local instance = {
    _engine = engine,
    _event_emitter = nil
  }
  setmetatable(instance, InkState)
  return instance
end

-- Get the tinta story from the engine
-- @return Story|nil - tinta Story instance
function InkState:_get_tinta_story()
  if not self._engine then
    return nil
  end
  return self._engine:_get_tinta_story()
end

-- Get the tinta variablesState
-- @return VariablesState|nil
function InkState:_get_variables_state()
  local ts = self:_get_tinta_story()
  if ts and ts.state and ts.state.variablesState then
    return ts.state.variablesState
  end
  return nil
end

-- Get a variable value by key
-- @param key string - Variable name
-- @return any - Variable value or nil
function InkState:get(key)
  local vs = self:_get_variables_state()
  if not vs then
    return nil
  end

  local value = vs:GetVariableWithName(key)
  if value then
    -- tinta wraps values in value objects, extract the actual value
    if type(value) == "table" and value.value ~= nil then
      return value.value
    end
    return value
  end
  return nil
end

-- Set a variable value by key
-- @param key string - Variable name
-- @param value any - Value to set
function InkState:set(key, value)
  local vs = self:_get_variables_state()
  if not vs then
    error("No variables state available")
  end

  -- Store old value for event
  local old_value = self:get(key)

  -- tinta expects value objects for certain operations
  -- but SetGlobal should handle raw values
  vs:SetGlobal(key, value)

  -- Emit change event
  self:_emit("ink.variable.changed", {
    key = key,
    old_value = old_value,
    new_value = value
  })
end

-- Check if a variable exists
-- @param key string - Variable name
-- @return boolean
function InkState:has(key)
  local vs = self:_get_variables_state()
  if not vs then
    return false
  end
  return vs:GlobalVariableExistsWithName(key)
end

-- Clear all variables (reset to defaults)
function InkState:clear()
  -- tinta doesn't have a direct clear method
  -- Instead, we can reset the state by restarting the engine
  if self._engine and self._engine.reset then
    self._engine:reset()
  end
end

-- Get all variable keys
-- @return table - Array of variable names
function InkState:keys()
  local vs = self:_get_variables_state()
  if not vs or not vs.globalVariables then
    return {}
  end

  local keys = {}
  for name, _ in pairs(vs.globalVariables) do
    table.insert(keys, name)
  end
  table.sort(keys)
  return keys
end

-- Get all variable values as a table
-- @return table - Map of variable name to value
function InkState:values()
  local values = {}
  for _, key in ipairs(self:keys()) do
    values[key] = self:get(key)
  end
  return values
end

-- Delete a variable (set to nil/default)
-- @param key string - Variable name
-- @return boolean - True if variable existed
function InkState:delete(key)
  if not self:has(key) then
    return false
  end
  -- tinta doesn't support deleting variables, set to nil
  self:set(key, nil)
  return true
end

-- Create a snapshot of current state
-- @return table - Serializable state snapshot
function InkState:snapshot()
  local ts = self:_get_tinta_story()
  if not ts or not ts.state then
    return nil
  end

  -- Use tinta's built-in save method
  return ts.state:save()
end

-- Restore state from a snapshot
-- @param snapshot table - Previously created snapshot
function InkState:restore(snapshot)
  if not snapshot then
    error("Snapshot is required")
  end

  local ts = self:_get_tinta_story()
  if not ts or not ts.state then
    error("No story state available")
  end

  -- Use tinta's built-in load method
  ts.state:load(snapshot)

  -- Emit restore event
  self:_emit("ink.state.restored", {})
end

-- Get visit count for a path
-- @param path string - Content path (knot.stitch)
-- @return number - Visit count
function InkState:get_visit_count(path)
  local ts = self:_get_tinta_story()
  if not ts then
    return 0
  end

  -- tinta has VisitCountAtPathString method
  if ts.VisitCountAtPathString then
    return ts:VisitCountAtPathString(path) or 0
  end
  return 0
end

-- Get current turn index
-- @return number
function InkState:get_turn_index()
  local ts = self:_get_tinta_story()
  if not ts or not ts.state then
    return 0
  end
  return ts.state.currentTurnIndex or 0
end

-- Set event emitter for notifications
-- @param emitter table - Event emitter with emit method
function InkState:set_event_emitter(emitter)
  self._event_emitter = emitter
end

-- Internal: emit an event if emitter is set
function InkState:_emit(event_name, data)
  if self._event_emitter and self._event_emitter.emit then
    self._event_emitter:emit(event_name, data)
  end
end

-- Get the associated engine
-- @return InkEngine
function InkState:get_engine()
  return self._engine
end

return InkState
