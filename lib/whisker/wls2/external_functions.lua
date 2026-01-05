--- WLS 2.0 External Functions Manager
-- Manages registration and execution of external functions from host applications.
--
-- @module whisker.wls2.external_functions
-- @author Whisker Team
-- @license MIT

-- Lua 5.1/5.2 compatibility
local unpack = unpack or table.unpack

local M = {}

-- Dependencies for DI pattern
M._dependencies = {}

--- External function event types
M.EVENTS = {
  REGISTERED = "functionRegistered",
  UNREGISTERED = "functionUnregistered",
  CALLED = "functionCalled",
  ERROR = "functionError",
}

--- External Functions Manager class
-- @type ExternalFunctionsManager
local ExternalFunctionsManager = {}
ExternalFunctionsManager.__index = ExternalFunctionsManager

--- Create a new ExternalFunctionsManager
-- @tparam[opt] table deps Injected dependencies (unused, for DI compatibility)
-- @treturn ExternalFunctionsManager New manager instance
function M.new(deps)
  -- deps parameter for DI compatibility (currently unused)
  local self = setmetatable({}, ExternalFunctionsManager)

  self.functions = {}
  self.namespaces = {}
  self.listeners = {}
  self.call_history = {}
  self.max_history = 100

  return self
end

--- Add an event listener
-- @tparam function callback Listener function(event, data)
function ExternalFunctionsManager:on(callback)
  table.insert(self.listeners, callback)
end

--- Remove an event listener
-- @tparam function callback Listener to remove
function ExternalFunctionsManager:off(callback)
  for i, listener in ipairs(self.listeners) do
    if listener == callback then
      table.remove(self.listeners, i)
      return
    end
  end
end

--- Emit an event to all listeners
-- @tparam string event Event name
-- @tparam table data Event data
function ExternalFunctionsManager:emit(event, data)
  for _, listener in ipairs(self.listeners) do
    listener(event, data)
  end
end

--- Register an external function
-- @tparam string name Function name (can be namespaced like "audio.play")
-- @tparam function fn The function to register
-- @tparam[opt] table metadata Function metadata (description, params, etc.)
function ExternalFunctionsManager:register(name, fn, metadata)
  if type(fn) ~= "function" then
    error("External function must be a function: " .. name)
  end

  self.functions[name] = {
    fn = fn,
    metadata = metadata or {},
    call_count = 0,
  }

  -- Track namespace
  local namespace = name:match("^([^%.]+)%.")
  if namespace then
    self.namespaces[namespace] = self.namespaces[namespace] or {}
    self.namespaces[namespace][name] = true
  end

  self:emit(M.EVENTS.REGISTERED, { name = name, metadata = metadata })
end

--- Register multiple functions at once
-- @tparam table functions Map of name -> function or {fn, metadata}
function ExternalFunctionsManager:register_all(functions)
  for name, value in pairs(functions) do
    if type(value) == "function" then
      self:register(name, value)
    elseif type(value) == "table" then
      self:register(name, value.fn or value[1], value.metadata or value[2])
    end
  end
end

--- Register a namespace of functions
-- @tparam string namespace Namespace prefix
-- @tparam table functions Map of name -> function
function ExternalFunctionsManager:register_namespace(namespace, functions)
  for name, fn in pairs(functions) do
    local full_name = namespace .. "." .. name
    self:register(full_name, fn)
  end
end

--- Unregister an external function
-- @tparam string name Function name
function ExternalFunctionsManager:unregister(name)
  local entry = self.functions[name]
  if entry then
    self.functions[name] = nil

    -- Remove from namespace tracking
    local namespace = name:match("^([^%.]+)%.")
    if namespace and self.namespaces[namespace] then
      self.namespaces[namespace][name] = nil
    end

    self:emit(M.EVENTS.UNREGISTERED, { name = name })
  end
end

--- Unregister all functions in a namespace
-- @tparam string namespace Namespace to clear
function ExternalFunctionsManager:unregister_namespace(namespace)
  local ns_functions = self.namespaces[namespace]
  if ns_functions then
    for name in pairs(ns_functions) do
      self:unregister(name)
    end
    self.namespaces[namespace] = nil
  end
end

--- Check if a function is registered
-- @tparam string name Function name
-- @treturn boolean True if registered
function ExternalFunctionsManager:has(name)
  return self.functions[name] ~= nil
end

--- Get function metadata
-- @tparam string name Function name
-- @treturn table|nil Metadata or nil
function ExternalFunctionsManager:get_metadata(name)
  local entry = self.functions[name]
  if entry then
    return entry.metadata
  end
  return nil
end

--- Call an external function
-- @tparam string name Function name
-- @param ... Arguments to pass to the function
-- @return Function result(s)
function ExternalFunctionsManager:call(name, ...)
  local entry = self.functions[name]
  if not entry then
    local err_data = { name = name, error = "Function not found: " .. name }
    self:emit(M.EVENTS.ERROR, err_data)
    error("External function not found: " .. name)
  end

  local args = { ... }
  entry.call_count = entry.call_count + 1

  -- Record in history
  if #self.call_history >= self.max_history then
    table.remove(self.call_history, 1)
  end
  table.insert(self.call_history, {
    name = name,
    args = args,
    timestamp = os.time(),
  })

  -- Call the function
  local success, result = pcall(function()
    return entry.fn(unpack(args))
  end)

  if success then
    self:emit(M.EVENTS.CALLED, { name = name, args = args, result = result })
    return result
  else
    local err_data = { name = name, args = args, error = result }
    self:emit(M.EVENTS.ERROR, err_data)
    error("External function error in " .. name .. ": " .. tostring(result))
  end
end

--- Safe call that returns nil on error instead of throwing
-- @tparam string name Function name
-- @param ... Arguments to pass to the function
-- @treturn any|nil Function result or nil on error
-- @treturn string|nil Error message if failed
function ExternalFunctionsManager:try_call(name, ...)
  local entry = self.functions[name]
  if not entry then
    return nil, "Function not found: " .. name
  end

  local args = { ... }
  entry.call_count = entry.call_count + 1

  local success, result = pcall(function()
    return entry.fn(unpack(args))
  end)

  if success then
    self:emit(M.EVENTS.CALLED, { name = name, args = args, result = result })
    return result, nil
  else
    local err_msg = tostring(result)
    self:emit(M.EVENTS.ERROR, { name = name, args = args, error = err_msg })
    return nil, err_msg
  end
end

--- Get all registered function names
-- @treturn table Array of function names
function ExternalFunctionsManager:get_all_names()
  local names = {}
  for name in pairs(self.functions) do
    table.insert(names, name)
  end
  table.sort(names)
  return names
end

--- Get all functions in a namespace
-- @tparam string namespace Namespace to query
-- @treturn table Array of function names
function ExternalFunctionsManager:get_namespace_functions(namespace)
  local result = {}
  local ns_functions = self.namespaces[namespace]
  if ns_functions then
    for name in pairs(ns_functions) do
      table.insert(result, name)
    end
  end
  table.sort(result)
  return result
end

--- Get all namespaces
-- @treturn table Array of namespace names
function ExternalFunctionsManager:get_namespaces()
  local names = {}
  for namespace in pairs(self.namespaces) do
    table.insert(names, namespace)
  end
  table.sort(names)
  return names
end

--- Get call statistics
-- @treturn table Stats object
function ExternalFunctionsManager:get_stats()
  local total_calls = 0
  local function_count = 0

  for _, entry in pairs(self.functions) do
    function_count = function_count + 1
    total_calls = total_calls + entry.call_count
  end

  return {
    function_count = function_count,
    namespace_count = #self:get_namespaces(),
    total_calls = total_calls,
    history_size = #self.call_history,
  }
end

--- Get call history
-- @tparam[opt] number limit Max entries to return
-- @treturn table Array of call records
function ExternalFunctionsManager:get_history(limit)
  limit = limit or #self.call_history
  local result = {}

  local start = math.max(1, #self.call_history - limit + 1)
  for i = start, #self.call_history do
    table.insert(result, self.call_history[i])
  end

  return result
end

--- Clear call history
function ExternalFunctionsManager:clear_history()
  self.call_history = {}
end

--- Reset the manager (clears all functions and history)
function ExternalFunctionsManager:reset()
  self.functions = {}
  self.namespaces = {}
  self.call_history = {}
end

--- Create a proxy table for convenient function access
-- @treturn table Proxy that allows fn_manager.namespace.function() syntax
function ExternalFunctionsManager:create_proxy()
  local manager = self

  local namespace_mt = {
    __index = function(ns_table, fn_name)
      local namespace = rawget(ns_table, "_namespace")
      local full_name = namespace .. "." .. fn_name
      return function(...)
        return manager:call(full_name, ...)
      end
    end
  }

  local proxy_mt = {
    __index = function(_, key)
      -- Check if it's a direct function
      if manager:has(key) then
        return function(...)
          return manager:call(key, ...)
        end
      end

      -- Check if it's a namespace
      if manager.namespaces[key] then
        local ns_table = { _namespace = key }
        setmetatable(ns_table, namespace_mt)
        return ns_table
      end

      return nil
    end
  }

  local proxy = {}
  setmetatable(proxy, proxy_mt)
  return proxy
end

return M
