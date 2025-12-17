-- whisker/formats/ink/flows.lua
-- Flow manager for Ink stories
-- Manages parallel execution contexts (flows)

local InkFlows = {}
InkFlows.__index = InkFlows

-- Module metadata for container auto-registration
InkFlows._whisker = {
  name = "InkFlows",
  version = "1.0.0",
  description = "Flow manager for Ink stories",
  depends = {},
  capability = "formats.ink.flows"
}

-- Default flow name constant
InkFlows.DEFAULT_FLOW = "DEFAULT_FLOW"

-- Create a new InkFlows instance
-- @param engine InkEngine - The engine this manager is associated with
-- @return InkFlows
function InkFlows.new(engine)
  local instance = {
    _engine = engine,
    _event_emitter = nil
  }
  setmetatable(instance, InkFlows)
  return instance
end

-- Get the tinta story from the engine
-- @return Story|nil - tinta Story instance
function InkFlows:_get_tinta_story()
  if not self._engine then
    return nil
  end
  -- Handle case where no story is loaded yet
  if not self._engine:is_loaded() or not self._engine:is_started() then
    return nil
  end
  local ok, ts = pcall(function()
    return self._engine:_get_tinta_story()
  end)
  if ok then
    return ts
  end
  return nil
end

-- Create a new flow and switch to it
-- @param name string - Name of the flow to create
-- @return boolean - True if successful
function InkFlows:create(name)
  if type(name) ~= "string" or name == "" then
    error("Flow name must be a non-empty string")
  end

  local ts = self:_get_tinta_story()
  if not ts then
    error("Cannot create flow: story not started")
  end

  -- SwitchFlow creates the flow if it doesn't exist
  ts:SwitchFlow(name)

  self:_emit("ink.flow.created", {
    name = name
  })

  return true
end

-- Switch to an existing flow
-- @param name string - Name of the flow to switch to
-- @return boolean - True if successful
function InkFlows:switch(name)
  if type(name) ~= "string" or name == "" then
    error("Flow name must be a non-empty string")
  end

  local ts = self:_get_tinta_story()
  if not ts then
    error("Cannot switch flow: story not started")
  end

  local old_flow = self:get_current()
  ts:SwitchFlow(name)

  self:_emit("ink.flow.switched", {
    from = old_flow,
    to = name
  })

  return true
end

-- Remove a flow
-- @param name string - Name of the flow to remove
-- @return boolean - True if successful
function InkFlows:remove(name)
  if type(name) ~= "string" or name == "" then
    error("Flow name must be a non-empty string")
  end

  if name == InkFlows.DEFAULT_FLOW then
    error("Cannot remove the default flow")
  end

  local ts = self:_get_tinta_story()
  if not ts then
    error("Cannot remove flow: story not started")
  end

  ts:RemoveFlow(name)

  self:_emit("ink.flow.removed", {
    name = name
  })

  return true
end

-- Get the current flow name
-- @return string|nil - Current flow name
function InkFlows:get_current()
  local ts = self:_get_tinta_story()
  if not ts then
    return nil
  end
  -- tinta's currentFlowName returns the state method, so call it
  return ts.state:currentFlowName()
end

-- Check if current flow is the default flow
-- @return boolean
function InkFlows:is_default()
  local ts = self:_get_tinta_story()
  if not ts then
    return true
  end
  return ts:currentFlowIsDefaultFlow()
end

-- List all active flows
-- @return table - Array of flow names
function InkFlows:list()
  local ts = self:_get_tinta_story()
  if not ts then
    return { InkFlows.DEFAULT_FLOW }
  end

  local names = ts:aliveFlowNames()
  if not names or #names == 0 then
    return { InkFlows.DEFAULT_FLOW }
  end

  -- Return a copy to prevent modification
  local result = {}
  for i, name in ipairs(names) do
    result[i] = name
  end
  return result
end

-- Check if a flow exists
-- @param name string - Flow name to check
-- @return boolean
function InkFlows:exists(name)
  local flows = self:list()
  for _, flow_name in ipairs(flows) do
    if flow_name == name then
      return true
    end
  end
  return false
end

-- Switch to the default flow
-- @return boolean - True if successful
function InkFlows:switch_to_default()
  return self:switch(InkFlows.DEFAULT_FLOW)
end

-- Set event emitter for notifications
-- @param emitter table - Event emitter with emit method
function InkFlows:set_event_emitter(emitter)
  self._event_emitter = emitter
end

-- Internal: emit an event if emitter is set
function InkFlows:_emit(event_name, data)
  if self._event_emitter and self._event_emitter.emit then
    self._event_emitter:emit(event_name, data)
  end
end

-- Get the associated engine
-- @return InkEngine
function InkFlows:get_engine()
  return self._engine
end

return InkFlows
