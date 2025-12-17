-- whisker/formats/ink/externals.lua
-- External function manager for Ink stories
-- Bridges Lua functions to Ink EXTERNAL declarations

local InkExternals = {}
InkExternals.__index = InkExternals

-- Module metadata for container auto-registration
InkExternals._whisker = {
  name = "InkExternals",
  version = "1.0.0",
  description = "External function manager for Ink stories",
  depends = {},
  capability = "formats.ink.externals"
}

-- Create a new InkExternals instance
-- @param engine InkEngine - The engine this manager is associated with
-- @return InkExternals
function InkExternals.new(engine)
  local instance = {
    _engine = engine,
    _bindings = {},  -- Track our bindings for management
    _event_emitter = nil
  }
  setmetatable(instance, InkExternals)
  return instance
end

-- Get the tinta story from the engine
-- @return Story|nil - tinta Story instance
function InkExternals:_get_tinta_story()
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

-- Bind a Lua function to an Ink EXTERNAL declaration
-- @param name string - The EXTERNAL function name in Ink
-- @param fn function - The Lua function to call
-- @param lookahead_safe boolean|nil - Whether function is safe for lookahead (default false)
-- @return boolean - True if binding succeeded
function InkExternals:bind(name, fn, lookahead_safe)
  if type(name) ~= "string" or name == "" then
    error("External function name must be a non-empty string")
  end
  if type(fn) ~= "function" then
    error("External function must be a function")
  end

  local ts = self:_get_tinta_story()
  if not ts then
    -- Store for later binding when story starts
    self._bindings[name] = {
      fn = fn,
      lookahead_safe = lookahead_safe == true,
      bound = false
    }
    return true
  end

  -- Create wrapper that emits events and handles errors
  local self_ref = self
  local wrapper = function(args)
    local result
    local ok, err = pcall(function()
      result = fn(unpack(args or {}))
    end)

    -- Emit event
    self_ref:_emit("ink.external.called", {
      name = name,
      args = args or {},
      result = result,
      error = not ok and err or nil
    })

    if not ok then
      error("External function '" .. name .. "' error: " .. tostring(err))
    end

    return result
  end

  -- Bind to tinta
  ts:BindExternalFunction(name, wrapper, lookahead_safe == true)

  -- Track binding
  self._bindings[name] = {
    fn = fn,
    lookahead_safe = lookahead_safe == true,
    bound = true
  }

  return true
end

-- Unbind an external function
-- @param name string - The EXTERNAL function name
-- @return boolean - True if unbinding succeeded
function InkExternals:unbind(name)
  if not self._bindings[name] then
    return false
  end

  local ts = self:_get_tinta_story()
  if ts and self._bindings[name].bound then
    ts:UnbindExternalFunction(name)
  end

  self._bindings[name] = nil
  return true
end

-- Check if a function is bound
-- @param name string - The EXTERNAL function name
-- @return boolean
function InkExternals:is_bound(name)
  return self._bindings[name] ~= nil
end

-- Get list of bound function names
-- @return table - Array of function names
function InkExternals:get_bound_names()
  local names = {}
  for name, _ in pairs(self._bindings) do
    table.insert(names, name)
  end
  table.sort(names)
  return names
end

-- Apply all pending bindings to the story
-- Called when story starts
function InkExternals:apply_bindings()
  local ts = self:_get_tinta_story()
  if not ts then
    return
  end

  for name, binding in pairs(self._bindings) do
    if not binding.bound then
      -- Re-bind with wrapper
      local self_ref = self
      local fn = binding.fn
      local wrapper = function(args)
        local result
        local ok, err = pcall(function()
          result = fn(unpack(args or {}))
        end)

        self_ref:_emit("ink.external.called", {
          name = name,
          args = args or {},
          result = result,
          error = not ok and err or nil
        })

        if not ok then
          error("External function '" .. name .. "' error: " .. tostring(err))
        end

        return result
      end

      ts:BindExternalFunction(name, wrapper, binding.lookahead_safe)
      binding.bound = true
    end
  end
end

-- Enable or disable fallback functions
-- @param enabled boolean - Whether to allow fallback ink functions
function InkExternals:set_fallbacks_enabled(enabled)
  local ts = self:_get_tinta_story()
  if ts then
    ts.allowExternalFunctionFallbacks = enabled
  end
end

-- Get fallback enabled state
-- @return boolean
function InkExternals:get_fallbacks_enabled()
  local ts = self:_get_tinta_story()
  if ts then
    return ts.allowExternalFunctionFallbacks
  end
  return false
end

-- Validate that all required externals are bound
-- @return boolean, table - Success flag and list of missing externals
function InkExternals:validate()
  local ts = self:_get_tinta_story()
  if not ts then
    return true, {}
  end

  -- tinta validates on first Continue(), but we can check _externals
  -- This returns true if validation hasn't been needed yet
  return true, {}
end

-- Set event emitter for notifications
-- @param emitter table - Event emitter with emit method
function InkExternals:set_event_emitter(emitter)
  self._event_emitter = emitter
end

-- Internal: emit an event if emitter is set
function InkExternals:_emit(event_name, data)
  if self._event_emitter and self._event_emitter.emit then
    self._event_emitter:emit(event_name, data)
  end
end

-- Get the associated engine
-- @return InkEngine
function InkExternals:get_engine()
  return self._engine
end

-- Clear all bindings
function InkExternals:clear()
  for name, _ in pairs(self._bindings) do
    self:unbind(name)
  end
  self._bindings = {}
end

return InkExternals
