--- Lua Sandbox
-- Secure sandboxed execution environment for untrusted code
-- @module whisker.security.sandbox
-- @author Whisker Core Team
-- @license MIT

local SecurityContext = require("whisker.security.security_context")
local CapabilityChecker = require("whisker.security.capability_checker")

local Sandbox = {}

--- Configuration
Sandbox.DEFAULT_TIMEOUT_MS = 100
Sandbox.DEFAULT_MEMORY_LIMIT_KB = 10240  -- 10 MB
Sandbox.INSTRUCTION_CHECK_COUNT = 10000

--- Safe globals that are always available in sandbox
Sandbox.SAFE_GLOBALS = {
  -- Type checking and conversion
  "type",
  "tonumber",
  "tostring",
  "rawequal",
  "rawget",
  "rawset",
  "rawlen",

  -- Error handling
  "assert",
  "error",
  "pcall",
  "xpcall",

  -- Iteration and selection
  "pairs",
  "ipairs",
  "next",
  "select",

  -- Misc
  "unpack",
  "_VERSION",
}

--- Safe libraries (full access)
Sandbox.SAFE_LIBRARIES = {
  "math",
  "string",
}

--- Partial libraries (only specific functions)
Sandbox.PARTIAL_LIBRARIES = {
  table = {
    "concat",
    "insert",
    "move",
    "pack",
    "remove",
    "sort",
    "unpack",
  },
  utf8 = {
    "char",
    "charpattern",
    "codepoint",
    "codes",
    "len",
    "offset",
  },
  os = {
    "clock",  -- Only timing, no system access
    "date",   -- Date/time formatting
    "difftime",
    "time",
  },
}

--- Blocked globals (for documentation)
Sandbox.BLOCKED_GLOBALS = {
  "dofile",       -- Execute arbitrary files
  "loadfile",     -- Load arbitrary files
  "load",         -- Load arbitrary code (bytecode risk)
  "loadstring",   -- Load arbitrary code (Lua 5.1)
  "require",      -- Module loading (controlled separately)
  "io",           -- File I/O
  "debug",        -- Runtime inspection/modification
  "package",      -- Module system internals
  "coroutine",    -- Potential escape vector
  "collectgarbage", -- GC control
  "newproxy",     -- Lua 5.1 internal
  "module",       -- Lua 5.1 module system
  "setfenv",      -- Lua 5.1 environment manipulation
  "getfenv",      -- Lua 5.1 environment manipulation
  "getmetatable", -- Blocked to prevent metatable attacks
  "setmetatable", -- Blocked to prevent metatable attacks
}

--- Internal state
local _initialized = false
local _string_metatable_protected = false
local _logger = nil

--- Set security logger
-- @param logger table Logger instance
function Sandbox.set_logger(logger)
  _logger = logger
end

--- Log security event
local function log_event(event_type, details)
  if _logger and _logger.log_security_event then
    _logger.log_security_event(event_type, details)
  end
end

--- Initialize sandbox system
function Sandbox.init()
  if _initialized then
    return
  end

  -- Protect string metatable
  Sandbox.protect_string_metatable()

  _initialized = true
end

--- Protect string metatable from manipulation
function Sandbox.protect_string_metatable()
  if _string_metatable_protected then
    return
  end

  -- Get the string metatable
  local string_mt = getmetatable("")

  -- Only protect if it's a table (not already protected/locked)
  if string_mt and type(string_mt) == "table" then
    -- Make it read-only by setting __metatable
    -- This prevents: getmetatable("").__index = os
    local success = pcall(function()
      rawset(string_mt, "__metatable", "protected")
    end)
    -- If it fails, the metatable is already protected
  end

  _string_metatable_protected = true
end

--- Create a clean sandbox environment
-- @param options table|nil {allowed_modules, api}
-- @return table Sandbox environment
function Sandbox.create_environment(options)
  options = options or {}

  local env = {}

  -- Copy safe globals
  for _, name in ipairs(Sandbox.SAFE_GLOBALS) do
    if _G[name] ~= nil then
      env[name] = _G[name]
    end
  end

  -- Copy safe libraries entirely
  for _, lib_name in ipairs(Sandbox.SAFE_LIBRARIES) do
    if _G[lib_name] then
      env[lib_name] = {}
      for k, v in pairs(_G[lib_name]) do
        env[lib_name][k] = v
      end
    end
  end

  -- Copy partial libraries (only safe functions)
  for lib_name, safe_funcs in pairs(Sandbox.PARTIAL_LIBRARIES) do
    if _G[lib_name] then
      env[lib_name] = {}
      for _, func_name in ipairs(safe_funcs) do
        if _G[lib_name][func_name] then
          env[lib_name][func_name] = _G[lib_name][func_name]
        end
      end
    end
  end

  -- Add safe print function
  env.print = function(...)
    local args = {...}
    local parts = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring(args[i])
    end
    -- Route through logger or stdout
    local message = table.concat(parts, "\t")
    if _logger then
      _logger.info("[sandbox] " .. message)
    else
      print("[sandbox]", message)
    end
  end

  -- Add controlled require if modules allowed
  if options.allowed_modules and #options.allowed_modules > 0 then
    env.require = Sandbox.create_safe_require(options.allowed_modules)
  end

  -- Add whisker API if provided
  if options.api then
    env.whisker = options.api
  end

  -- Add safe getmetatable that only works on user tables
  env.getmetatable = function(obj)
    local mt = getmetatable(obj)
    -- If metatable has __metatable field, return that instead (or nil if "protected")
    if mt and rawget(mt, "__metatable") then
      local custom = rawget(mt, "__metatable")
      if custom == "protected" then
        return nil
      end
      return custom
    end
    -- For user tables, allow metatable access
    if type(obj) == "table" then
      return mt
    end
    return nil
  end

  -- Add safe setmetatable that only works on user tables
  env.setmetatable = function(t, mt)
    if type(t) ~= "table" then
      error("setmetatable can only be used on tables", 2)
    end
    -- Check if table has protected metatable
    local existing = getmetatable(t)
    if existing and rawget(existing, "__metatable") then
      error("cannot change a protected metatable", 2)
    end
    return setmetatable(t, mt)
  end

  -- Set up metatable to catch undefined global access
  local env_mt = {
    __index = function(t, key)
      error(string.format(
        "Attempt to access undefined global '%s'",
        tostring(key)
      ), 2)
    end,

    __newindex = function(t, key, value)
      error(string.format(
        "Attempt to create global '%s'. Use 'local' variables.",
        tostring(key)
      ), 2)
    end,

    __metatable = "protected",
  }

  setmetatable(env, env_mt)

  return env
end

--- Create safe require function
-- @param allowed_modules table Array of allowed module names
-- @return function Safe require
function Sandbox.create_safe_require(allowed_modules)
  local allowed_set = {}
  for _, mod in ipairs(allowed_modules) do
    allowed_set[mod] = true
  end

  return function(module_name)
    if not allowed_set[module_name] then
      log_event("SANDBOX_ESCAPE_ATTEMPT", {
        type = "require",
        module = module_name,
      })
      error(string.format(
        "require() of '%s' not allowed in sandbox",
        module_name
      ))
    end

    return require(module_name)
  end
end

--- Load code into sandbox
-- @param code string Lua source code
-- @param chunk_name string Name for error messages
-- @param env table Sandbox environment
-- @return function|nil Compiled chunk or nil
-- @return string|nil Error message if failed
function Sandbox.load_code(code, chunk_name, env)
  -- Use "t" mode to only allow text (no bytecode) - security requirement
  local chunk, err = load(code, "@" .. chunk_name, "t", env)

  if not chunk then
    return nil, "Compilation error: " .. tostring(err)
  end

  return chunk
end

--- Execute function with timeout protection
-- @param fn function Function to execute
-- @param timeout_ms number Timeout in milliseconds
-- @param ... any Arguments
-- @return boolean success
-- @return any result or error message
function Sandbox.execute_with_timeout(fn, timeout_ms, ...)
  timeout_ms = timeout_ms or Sandbox.DEFAULT_TIMEOUT_MS

  local start_time = os.clock()
  local timed_out = false

  -- Timeout check function
  local function check_timeout()
    local elapsed_ms = (os.clock() - start_time) * 1000
    if elapsed_ms > timeout_ms then
      timed_out = true
      error("Execution timeout exceeded", 0)
    end
  end

  -- Install instruction hook
  debug.sethook(check_timeout, "", Sandbox.INSTRUCTION_CHECK_COUNT)

  -- Execute with pcall
  local results = {pcall(fn, ...)}
  local success = results[1]

  -- Remove hook
  debug.sethook()

  if timed_out then
    log_event("SANDBOX_TIMEOUT", {
      timeout_ms = timeout_ms,
    })
    return false, string.format("Execution timeout: exceeded %dms", timeout_ms)
  end

  if success then
    return true, select(2, table.unpack(results))
  else
    return false, results[2]
  end
end

--- Execute code in sandbox
-- @param code string Lua source code
-- @param plugin_id string Plugin identifier
-- @param options table|nil {timeout_ms, allowed_modules, api, capabilities}
-- @return boolean success
-- @return any result or error message
function Sandbox.execute(code, plugin_id, options)
  options = options or {}

  -- Ensure sandbox is initialized
  if not _initialized then
    Sandbox.init()
  end

  -- Create sandbox environment
  local env = Sandbox.create_environment({
    allowed_modules = options.allowed_modules,
    api = options.api,
  })

  -- Load code
  local chunk, load_err = Sandbox.load_code(code, "plugin:" .. plugin_id, env)
  if not chunk then
    return false, load_err
  end

  -- Enter security context
  local capabilities = options.capabilities or {}
  SecurityContext.enter(plugin_id, capabilities)

  -- Execute with timeout
  local success, result = Sandbox.execute_with_timeout(
    chunk,
    options.timeout_ms
  )

  -- Exit security context
  SecurityContext.exit()

  return success, result
end

--- Execute function in sandbox context
-- @param fn function Function to execute
-- @param plugin_id string Plugin identifier
-- @param capabilities table Array of capability IDs
-- @param timeout_ms number|nil Timeout
-- @param ... any Arguments
-- @return boolean success
-- @return any result or error
function Sandbox.execute_function(fn, plugin_id, capabilities, timeout_ms, ...)
  -- Enter security context
  SecurityContext.enter(plugin_id, capabilities)

  -- Execute with timeout
  local success, result = Sandbox.execute_with_timeout(fn, timeout_ms, ...)

  -- Exit security context
  SecurityContext.exit()

  return success, result
end

--- Create capability-gated whisker API
-- @param plugin_id string Plugin ID
-- @param state_manager table State manager instance
-- @param storage table Plugin storage
-- @return table Capability-gated API
function Sandbox.create_whisker_api(plugin_id, state_manager, storage)
  local api = {}

  -- State reading (requires READ_STATE)
  api.get_variable = function(name)
    CapabilityChecker.require_capability("READ_STATE")
    return state_manager:get_variable(name)
  end

  api.get_current_passage = function()
    CapabilityChecker.require_capability("READ_STATE")
    return state_manager:get_current_passage()
  end

  api.get_history = function()
    CapabilityChecker.require_capability("READ_STATE")
    return state_manager:get_history()
  end

  api.get_visit_count = function(passage_id)
    CapabilityChecker.require_capability("READ_STATE")
    return state_manager:get_visit_count(passage_id)
  end

  -- State writing (requires WRITE_STATE)
  api.set_variable = function(name, value)
    CapabilityChecker.require_capability("WRITE_STATE")
    return state_manager:set_variable(name, value)
  end

  api.navigate_to = function(passage_id)
    CapabilityChecker.require_capability("WRITE_STATE")
    return state_manager:navigate_to(passage_id)
  end

  -- Plugin storage (no capability required - isolated per plugin)
  api.storage = {
    get = function(key)
      return storage:get(plugin_id, key)
    end,
    set = function(key, value)
      return storage:set(plugin_id, key, value)
    end,
    delete = function(key)
      return storage:delete(plugin_id, key)
    end,
  }

  -- Logging (no capability required)
  api.log = {
    info = function(msg)
      if _logger then
        _logger.info("[" .. plugin_id .. "] " .. tostring(msg))
      end
    end,
    warn = function(msg)
      if _logger then
        _logger.warn("[" .. plugin_id .. "] " .. tostring(msg))
      end
    end,
    error = function(msg)
      if _logger then
        _logger.error("[" .. plugin_id .. "] " .. tostring(msg))
      end
    end,
  }

  return api
end

--- Wrap function to execute in sandbox
-- @param fn function Function to wrap
-- @param plugin_id string Plugin ID
-- @param capabilities table Capabilities
-- @param timeout_ms number|nil Timeout
-- @return function Wrapped function
function Sandbox.wrap_function(fn, plugin_id, capabilities, timeout_ms)
  return function(...)
    local success, result = Sandbox.execute_function(
      fn, plugin_id, capabilities, timeout_ms, ...
    )
    if not success then
      error(result, 0)
    end
    return result
  end
end

--- Check if sandbox is initialized
-- @return boolean
function Sandbox.is_initialized()
  return _initialized
end

--- Reset sandbox (for testing)
function Sandbox.reset()
  _initialized = false
  _string_metatable_protected = false
end

return Sandbox
