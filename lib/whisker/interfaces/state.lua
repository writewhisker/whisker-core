--- IState Interface
-- Interface for state management services
-- @module whisker.interfaces.state
-- @author Whisker Core Team
-- @license MIT

local IState = {}

--- Get a value from state
-- @param key string The key to retrieve
-- @return any The value, or nil if not found
function IState:get(key)
  error("IState:get must be implemented")
end

--- Set a value in state
-- @param key string The key to set
-- @param value any The value to store
function IState:set(key, value)
  error("IState:set must be implemented")
end

--- Check if a key exists in state
-- @param key string The key to check
-- @return boolean True if the key exists
function IState:has(key)
  error("IState:has must be implemented")
end

--- Delete a key from state
-- @param key string The key to delete
-- @return boolean True if the key was deleted
function IState:delete(key)
  error("IState:delete must be implemented")
end

--- Clear all state
function IState:clear()
  error("IState:clear must be implemented")
end

--- Create a snapshot of current state
-- @return table A snapshot that can be restored later
function IState:snapshot()
  error("IState:snapshot must be implemented")
end

--- Restore state from a snapshot
-- @param snapshot table The snapshot to restore
function IState:restore(snapshot)
  error("IState:restore must be implemented")
end

--- Get all keys in state
-- @return table Array of all keys
function IState:keys()
  error("IState:keys must be implemented")
end

return IState
