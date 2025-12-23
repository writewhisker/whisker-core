--- StateManager Service
-- Implements IState interface for state management
-- @module whisker.services.state
-- @author Whisker Core Team
-- @license MIT

local IState = require("whisker.interfaces.state")

local StateManager = {}
setmetatable(StateManager, { __index = IState })

StateManager.name = "state_manager"
StateManager.version = "2.1.0"

--- Create a new state manager instance
-- @param container Container The DI container
-- @return StateManager
function StateManager.new(container)
  local self = {
    _data = {},
    _events = container and container:has("events") and container:resolve("events") or nil,
    _serializer = container and container:has("serializer") and container:resolve("serializer") or nil,
  }

  return setmetatable(self, { __index = StateManager })
end

--- Get a value from state
-- @param key string The key to retrieve
-- @return any value The stored value, or nil if not set
function StateManager:get(key)
  return self._data[key]
end

--- Set a value in state
-- @param key string The key to set
-- @param value any The value to store
function StateManager:set(key, value)
  local old_value = self._data[key]
  self._data[key] = value

  -- Emit state change event
  if self._events then
    self._events:emit("state:changed", {
      key = key,
      old_value = old_value,
      new_value = value,
      timestamp = os.time()
    })
  end
end

--- Check if a key exists in state
-- @param key string The key to check
-- @return boolean exists True if the key exists
function StateManager:has(key)
  return self._data[key] ~= nil
end

--- Remove a key from state
-- @param key string The key to remove
-- @return boolean True if the key was deleted
function StateManager:delete(key)
  local old_value = self._data[key]
  if old_value == nil then
    return false
  end

  self._data[key] = nil

  if self._events then
    self._events:emit("state:deleted", {
      key = key,
      old_value = old_value
    })
  end

  return true
end

--- Clear all state
function StateManager:clear()
  self._data = {}

  if self._events then
    self._events:emit("state:cleared", {
      timestamp = os.time()
    })
  end
end

--- Create a snapshot of current state
-- @return table snapshot Serializable snapshot
function StateManager:snapshot()
  local snap = {}
  for k, v in pairs(self._data) do
    snap[k] = v
  end
  return snap
end

--- Restore state from a snapshot
-- @param snapshot table The snapshot to restore
function StateManager:restore(snapshot)
  self._data = {}
  for k, v in pairs(snapshot or {}) do
    self._data[k] = v
  end

  if self._events then
    self._events:emit("state:restored", {
      keys = self:keys(),
      timestamp = os.time()
    })
  end
end

--- Get all keys in state
-- @return string[] keys List of all keys
function StateManager:keys()
  local result = {}
  for k in pairs(self._data) do
    table.insert(result, k)
  end
  return result
end

--- Get the number of entries in state
-- @return number count Number of entries
function StateManager:count()
  local count = 0
  for _ in pairs(self._data) do
    count = count + 1
  end
  return count
end

--- Destroy the state manager and cleanup
function StateManager:destroy()
  self._data = {}
  self._events = nil
  self._serializer = nil
end

return StateManager
