-- whisker/interfaces/state.lua
-- IState interface definition
-- State managers must implement this interface

local IState = {
  _name = "IState",
  _description = "State management for game variables and progress",
  _required = {"get", "set", "has", "clear", "snapshot", "restore"},
  _optional = {"delete", "keys", "values"},

  -- Get a value by key
  -- @param key string - Key to retrieve
  -- @return any - Value or nil if not found
  get = "function(self, key) -> any",

  -- Set a value by key
  -- @param key string - Key to set
  -- @param value any - Value to store
  set = "function(self, key, value)",

  -- Check if a key exists
  -- @param key string - Key to check
  -- @return boolean - True if key exists
  has = "function(self, key) -> boolean",

  -- Clear all state
  clear = "function(self)",

  -- Create a snapshot of current state
  -- @return table - State snapshot for later restoration
  snapshot = "function(self) -> table",

  -- Restore state from a snapshot
  -- @param snapshot table - Previously created snapshot
  restore = "function(self, snapshot)",
}

return IState
