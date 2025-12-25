--- Ink State Bridge
-- Bidirectional synchronization between Ink and Whisker state
-- @module whisker.formats.ink.state_bridge
-- @author Whisker Core Team
-- @license MIT

local StateBridge = {}
StateBridge._dependencies = {}
StateBridge.__index = StateBridge

--- Create new state bridge
-- @param ink_engine InkEngine Ink engine instance
-- @param whisker_state IState Whisker state instance
-- @param events EventBus|nil Event bus for notifications
-- @return StateBridge
function StateBridge.new(ink_engine, whisker_state, events)
  local self = setmetatable({}, StateBridge)

  self.ink = ink_engine
  self.state = whisker_state
  self.events = events
  self._syncing = false -- Prevent sync loops
  self._observers = {}
  self._state_subscription = nil

  -- Setup bidirectional sync
  self:_setup_ink_to_whisker()
  self:_setup_whisker_to_ink()

  return self
end

--- Sync all Ink variables to Whisker state
function StateBridge:sync_all()
  if not self.ink:is_loaded() then
    return
  end

  self._syncing = true

  local var_names = self.ink:get_variable_names()

  for _, name in ipairs(var_names) do
    local value = self.ink:get_variable(name)
    local whisker_value = self:_convert_ink_to_whisker(value)
    self.state:set("ink." .. name, whisker_value)
  end

  self._syncing = false

  if self.events then
    self.events:emit("ink:state_synced", {
      count = #var_names,
    })
  end
end

--- Setup observer for Ink variable changes
-- @private
function StateBridge:_setup_ink_to_whisker()
  if not self.ink:is_loaded() then
    return
  end

  -- Observe all Ink variable changes
  local unsubscribe = self.ink:observe_variable("*", function(name, old_val, new_val)
    if self._syncing then
      return
    end

    self._syncing = true

    local whisker_value = self:_convert_ink_to_whisker(new_val)
    self.state:set("ink." .. name, whisker_value)

    self._syncing = false
  end)

  table.insert(self._observers, unsubscribe)
end

--- Setup listener for Whisker state changes
-- @private
function StateBridge:_setup_whisker_to_ink()
  if not self.events then
    return
  end

  -- Listen for state changes in the ink.* namespace
  self._state_subscription = self.events:on("state:changed", function(data)
    if self._syncing then
      return
    end

    -- Only handle ink.* keys
    local key = data.key or ""
    if not key:match("^ink%.") then
      return
    end

    local var_name = key:sub(5) -- Remove "ink." prefix

    self._syncing = true

    local ink_value = self:_convert_whisker_to_ink(data.value)
    self.ink:set_variable(var_name, ink_value)

    self._syncing = false
  end)
end

--- Convert Ink value to Whisker-compatible value
-- @param ink_value any Ink runtime value
-- @return any Lua value
-- @private
function StateBridge:_convert_ink_to_whisker(ink_value)
  if ink_value == nil then
    return nil
  end

  -- Check if it's an Ink value object
  if type(ink_value) == "table" and ink_value.value ~= nil then
    return ink_value.value
  end

  -- Already a primitive
  return ink_value
end

--- Convert Whisker value to Ink-compatible value
-- @param whisker_value any Lua value
-- @return any Value for Ink
-- @private
function StateBridge:_convert_whisker_to_ink(whisker_value)
  -- Ink accepts primitives directly
  return whisker_value
end

--- Get current variable value from Whisker state
-- @param name string Variable name (without ink. prefix)
-- @return any
function StateBridge:get(name)
  return self.state:get("ink." .. name)
end

--- Set variable value in Whisker state (will sync to Ink)
-- @param name string Variable name (without ink. prefix)
-- @param value any Value to set
function StateBridge:set(name, value)
  self.state:set("ink." .. name, value)
end

--- Check if variable exists
-- @param name string Variable name (without ink. prefix)
-- @return boolean
function StateBridge:has(name)
  return self.state:has("ink." .. name)
end

--- Get all synced variable names
-- @return table Array of variable names
function StateBridge:get_names()
  local names = {}
  local keys = self.state:keys()

  for _, key in ipairs(keys) do
    if key:match("^ink%.") then
      table.insert(names, key:sub(5))
    end
  end

  return names
end

--- Create snapshot of all Ink variables
-- @return table Snapshot
function StateBridge:snapshot()
  local snap = {}
  local names = self:get_names()

  for _, name in ipairs(names) do
    snap[name] = self:get(name)
  end

  return snap
end

--- Restore variables from snapshot
-- @param snap table Snapshot to restore
function StateBridge:restore(snap)
  self._syncing = true

  for name, value in pairs(snap) do
    self.state:set("ink." .. name, value)
    self.ink:set_variable(name, value)
  end

  self._syncing = false
end

--- Clear all Ink variables from Whisker state
function StateBridge:clear()
  local names = self:get_names()

  for _, name in ipairs(names) do
    self.state:delete("ink." .. name)
  end
end

--- Destroy the bridge and cleanup
function StateBridge:destroy()
  -- Unsubscribe from Ink observers
  for _, unsubscribe in ipairs(self._observers) do
    unsubscribe()
  end
  self._observers = {}

  -- Unsubscribe from state events
  if self._state_subscription then
    -- The on() method returns unsubscribe function
    self._state_subscription()
    self._state_subscription = nil
  end
end

return StateBridge
