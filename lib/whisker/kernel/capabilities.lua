-- whisker/kernel/capabilities.lua
-- Capability detection and feature flag system
-- Zero external dependencies

local Capabilities = {}
Capabilities.__index = Capabilities

-- Create a new capabilities instance
function Capabilities.new()
  local self = setmetatable({}, Capabilities)
  self._capabilities = {}
  return self
end

-- Register a capability (enabled by default)
function Capabilities:register(name, enabled)
  self._capabilities[name] = enabled ~= false
  return true
end

-- Unregister a capability
function Capabilities:unregister(name)
  if self._capabilities[name] == nil then
    return false
  end
  self._capabilities[name] = nil
  return true
end

-- Check if a capability is available and enabled
function Capabilities:has(name)
  return self._capabilities[name] == true
end

-- Enable/disable a capability (returns false if not registered)
function Capabilities:enable(name)
  if self._capabilities[name] == nil then return false end
  self._capabilities[name] = true
  return true
end

function Capabilities:disable(name)
  if self._capabilities[name] == nil then return false end
  self._capabilities[name] = false
  return true
end

-- Get all registered capabilities
function Capabilities:list()
  local caps = {}
  for name, enabled in pairs(self._capabilities) do
    table.insert(caps, { name = name, enabled = enabled })
  end
  table.sort(caps, function(a, b) return a.name < b.name end)
  return caps
end

-- Get all enabled capabilities
function Capabilities:list_enabled()
  local caps = {}
  for name, enabled in pairs(self._capabilities) do
    if enabled then
      table.insert(caps, name)
    end
  end
  table.sort(caps)
  return caps
end

-- Clear all capabilities
function Capabilities:clear()
  self._capabilities = {}
end

return Capabilities
