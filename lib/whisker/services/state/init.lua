-- whisker/services/state/init.lua
-- State service implementing IState interface
-- Simple key-value store with snapshot/restore support

local State = {}
State.__index = State

-- Module metadata for container auto-registration
State._whisker = {
  name = "State",
  version = "2.0.0",
  description = "State service implementing IState interface",
  depends = {},
  implements = "IState",
  capability = "services.state"
}

-- Deep copy helper for immutable snapshots
local function deep_copy(original)
  if type(original) ~= "table" then
    return original
  end
  local copy = {}
  for k, v in pairs(original) do
    if type(v) == "table" then
      copy[k] = deep_copy(v)
    else
      copy[k] = v
    end
  end
  return copy
end

-- Create a new State instance
-- @param options table|nil - Optional configuration
-- @return State
function State.new(options)
  options = options or {}
  local instance = {
    _data = {},
    _event_emitter = options.event_emitter or nil
  }
  setmetatable(instance, State)
  return instance
end

-- Set an event emitter for state change notifications
-- @param emitter table|nil - Object with emit(event_name, data) method
function State:set_event_emitter(emitter)
  self._event_emitter = emitter
end

-- Get the current event emitter
function State:get_event_emitter()
  return self._event_emitter
end

-- Internal: emit an event if emitter is set
local function emit_event(self, event_name, data)
  if self._event_emitter and self._event_emitter.emit then
    self._event_emitter:emit(event_name, data)
  end
end

-- Get a value by key
-- @param key string - Key to retrieve
-- @return any - Value or nil if not found
function State:get(key)
  return self._data[key]
end

-- Set a value by key
-- @param key string - Key to set
-- @param value any - Value to store
function State:set(key, value)
  local old_value = self._data[key]
  self._data[key] = value

  emit_event(self, "state:changed", {
    key = key,
    old_value = old_value,
    new_value = value
  })
end

-- Check if a key exists
-- @param key string - Key to check
-- @return boolean - True if key exists
function State:has(key)
  return self._data[key] ~= nil
end

-- Delete a key (optional IState method)
-- @param key string - Key to delete
-- @return boolean - True if key was deleted
function State:delete(key)
  if self._data[key] ~= nil then
    local old_value = self._data[key]
    self._data[key] = nil
    emit_event(self, "state:changed", {
      key = key,
      old_value = old_value,
      new_value = nil,
      deleted = true
    })
    return true
  end
  return false
end

-- Get all keys (optional IState method)
-- @return table - Array of keys
function State:keys()
  local result = {}
  for k, _ in pairs(self._data) do
    table.insert(result, k)
  end
  return result
end

-- Get all values (optional IState method)
-- @return table - Array of values
function State:values()
  local result = {}
  for _, v in pairs(self._data) do
    table.insert(result, v)
  end
  return result
end

-- Get all data as key-value pairs
-- @return table - Copy of all data
function State:get_all()
  return deep_copy(self._data)
end

-- Clear all state
function State:clear()
  local had_data = next(self._data) ~= nil
  self._data = {}

  if had_data then
    emit_event(self, "state:cleared", {})
  end
end

-- Create a snapshot of current state
-- @return table - State snapshot for later restoration
function State:snapshot()
  return deep_copy(self._data)
end

-- Restore state from a snapshot
-- @param snapshot table - Previously created snapshot
function State:restore(snapshot)
  local old_data = self._data
  self._data = deep_copy(snapshot)

  emit_event(self, "state:restored", {
    old_data = old_data,
    new_data = self._data
  })
end

-- Serialization - returns plain table representation
function State:serialize()
  return {
    data = deep_copy(self._data)
  }
end

-- Deserialization - restores from plain table
function State:deserialize(data)
  if data and data.data then
    self._data = deep_copy(data.data)
  end
end

return State
