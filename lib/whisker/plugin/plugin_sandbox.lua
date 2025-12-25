--- Plugin Sandbox
-- Sandboxed execution environment for untrusted plugin code
-- @module whisker.plugin.plugin_sandbox
-- @author Whisker Core Team
-- @license MIT

local PluginSandbox = {}
PluginSandbox._dependencies = {}
PluginSandbox.__index = PluginSandbox

--- Default execution timeout in milliseconds
PluginSandbox.DEFAULT_TIMEOUT_MS = 100

--- Default instruction count between timeout checks
PluginSandbox.INSTRUCTION_CHECK_COUNT = 10000

--- Safe globals that are always available in sandbox
-- @table SAFE_GLOBALS
PluginSandbox.SAFE_GLOBALS = {
  -- Type checking
  "type",
  "tonumber",
  "tostring",
  "getmetatable",
  "setmetatable",
  "rawequal",
  "rawget",
  "rawset",
  "rawlen",

  -- Error handling
  "assert",
  "error",
  "pcall",
  "xpcall",

  -- Iteration
  "pairs",
  "ipairs",
  "next",
  "select",

  -- Misc
  "unpack",
  "_VERSION",
}

--- Safe libraries (all functions from these are safe)
-- @table SAFE_LIBRARIES
PluginSandbox.SAFE_LIBRARIES = {
  "math",
  "string",
}

--- Partial libraries (only specific functions are safe)
-- @table PARTIAL_LIBRARIES
PluginSandbox.PARTIAL_LIBRARIES = {
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
}

--- Blocked globals (for reference/documentation)
-- @table BLOCKED_GLOBALS
PluginSandbox.BLOCKED_GLOBALS = {
  "dofile",     -- Execute arbitrary files
  "loadfile",   -- Load arbitrary files
  "load",       -- Load arbitrary code (bytecode risk)
  "loadstring", -- Load arbitrary code (Lua 5.1)
  "require",    -- Module loading (controlled separately)
  "io",         -- File I/O
  "os",         -- System commands, environment
  "debug",      -- Runtime inspection/modification
  "package",    -- Module system internals
  "coroutine",  -- Potential escape vector
  "collectgarbage", -- GC control
  "newproxy",   -- Lua 5.1 internal
  "module",     -- Lua 5.1 module system
  "setfenv",    -- Lua 5.1 environment manipulation
  "getfenv",    -- Lua 5.1 environment manipulation
}

--- Create a new sandbox configuration
-- @param config table|nil Configuration options
-- @return PluginSandbox
function PluginSandbox.new(config, deps)
  deps = deps or {}
  local self = setmetatable({}, PluginSandbox)

  config = config or {}

  self._timeout_ms = config.timeout_ms or PluginSandbox.DEFAULT_TIMEOUT_MS
  self._instruction_count = config.instruction_count or PluginSandbox.INSTRUCTION_CHECK_COUNT
  self._allowed_modules = config.allowed_modules or {}
  self._enable_timeout = config.enable_timeout ~= false  -- Default true

  return self
end

--- Build the base safe environment table
-- @return table Base environment with safe globals
function PluginSandbox:_build_base_environment()
  local env = {}

  -- Copy safe globals from _G
  for _, name in ipairs(PluginSandbox.SAFE_GLOBALS) do
    if _G[name] ~= nil then
      env[name] = _G[name]
    end
  end

  -- Copy safe libraries entirely
  for _, lib_name in ipairs(PluginSandbox.SAFE_LIBRARIES) do
    if _G[lib_name] then
      env[lib_name] = _G[lib_name]
    end
  end

  -- Copy partial libraries (only safe functions)
  for lib_name, safe_funcs in pairs(PluginSandbox.PARTIAL_LIBRARIES) do
    if _G[lib_name] then
      env[lib_name] = {}
      for _, func_name in ipairs(safe_funcs) do
        if _G[lib_name][func_name] then
          env[lib_name][func_name] = _G[lib_name][func_name]
        end
      end
    end
  end

  return env
end

--- Create sandboxed environment for a plugin
-- @param plugin_context PluginContext Plugin context instance
-- @return table Sandboxed environment
function PluginSandbox:create_environment(plugin_context)
  local env = self:_build_base_environment()

  -- Create plugin-specific print/warn that route through logger
  env.print = function(...)
    local args = {...}
    local parts = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring(args[i])
    end
    local message = table.concat(parts, "\t")
    if plugin_context and plugin_context.log then
      plugin_context.log.info(message)
    else
      print("[" .. (plugin_context and plugin_context.name or "plugin") .. "]", message)
    end
  end

  env.warn = function(...)
    local args = {...}
    local parts = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring(args[i])
    end
    local message = table.concat(parts, "\t")
    if plugin_context and plugin_context.log then
      plugin_context.log.warn(message)
    else
      print("[WARN][" .. (plugin_context and plugin_context.name or "plugin") .. "]", message)
    end
  end

  -- Add controlled require if modules are allowed
  if #self._allowed_modules > 0 then
    env.require = self:_create_safe_require()
  end

  -- Add whisker global for plugin context access
  if plugin_context then
    env.whisker = {
      state = plugin_context.state,
      storage = plugin_context.storage,
      log = plugin_context.log,
      plugins = plugin_context.plugins,
      hooks = plugin_context.hooks,
      name = plugin_context.name,
      version = plugin_context.version,
    }
  end

  -- Set up metatable to catch undefined global access
  local plugin_name = plugin_context and plugin_context.name or "unknown"
  setmetatable(env, {
    __index = function(t, key)
      error(string.format(
        "Attempt to access undefined global '%s' in plugin '%s'",
        tostring(key),
        plugin_name
      ), 2)
    end,

    __newindex = function(t, key, value)
      error(string.format(
        "Attempt to create global '%s' in plugin '%s'. Use local variables.",
        tostring(key),
        plugin_name
      ), 2)
    end,
  })

  return env
end

--- Create a safe require function that only allows whitelisted modules
-- @return function Safe require function
function PluginSandbox:_create_safe_require()
  local allowed_set = {}
  for _, mod_name in ipairs(self._allowed_modules) do
    allowed_set[mod_name] = true
  end

  return function(module_name)
    if not allowed_set[module_name] then
      error(string.format(
        "require() of '%s' not allowed in sandbox. Allowed: %s",
        module_name,
        table.concat(self._allowed_modules, ", ")
      ))
    end

    return require(module_name)
  end
end

--- Load code into a sandboxed environment
-- @param code string Lua source code
-- @param chunk_name string Name for error messages
-- @param env table Sandbox environment
-- @return function|nil Compiled chunk or nil on error
-- @return string|nil Error message if compilation failed
function PluginSandbox:load_code(code, chunk_name, env)
  -- Use "t" mode to only allow text (no bytecode) - more secure
  local chunk, err = load(code, "@" .. chunk_name, "t", env)
  if not chunk then
    return nil, "Compilation error: " .. tostring(err)
  end

  return chunk
end

--- Execute a function with timeout protection
-- Uses debug.sethook to count instructions and abort if timeout exceeded
-- @param fn function Function to execute
-- @param timeout_ms number|nil Timeout in milliseconds (uses default if nil)
-- @param ... any Arguments to pass to function
-- @return boolean success True if execution completed without timeout
-- @return any result Function result or error message
function PluginSandbox:execute_with_timeout(fn, timeout_ms, ...)
  timeout_ms = timeout_ms or self._timeout_ms

  if not self._enable_timeout then
    -- Timeout disabled, just execute normally with pcall
    return pcall(fn, ...)
  end

  local start_time = os.clock()
  local timed_out = false

  -- Create timeout checker function
  local function check_timeout()
    local elapsed_ms = (os.clock() - start_time) * 1000
    if elapsed_ms > timeout_ms then
      timed_out = true
      error("Execution timeout: exceeded " .. timeout_ms .. "ms", 0)
    end
  end

  -- Install instruction hook
  -- The "" mask means count instructions, fire every N instructions
  debug.sethook(check_timeout, "", self._instruction_count)

  -- Execute function with protected call
  local results = {pcall(fn, ...)}

  -- Remove hook immediately
  debug.sethook()

  local success = results[1]

  if timed_out then
    return false, string.format(
      "Execution timeout: exceeded %dms limit",
      timeout_ms
    )
  end

  if success then
    -- Return true plus all return values
    return true, select(2, table.unpack(results))
  else
    -- Return false plus error message
    return false, results[2]
  end
end

--- Load and execute plugin code in sandbox
-- @param code string Plugin source code
-- @param plugin_name string Plugin name
-- @param plugin_context PluginContext Plugin context
-- @param timeout_ms number|nil Execution timeout
-- @return table|nil Plugin definition table or nil
-- @return string|nil Error message if failed
function PluginSandbox:load_plugin(code, plugin_name, plugin_context, timeout_ms)
  -- Create sandboxed environment
  local env = self:create_environment(plugin_context)

  -- Compile code
  local chunk, compile_err = self:load_code(code, "plugin:" .. plugin_name, env)
  if not chunk then
    return nil, compile_err
  end

  -- Execute with timeout
  local success, result = self:execute_with_timeout(chunk, timeout_ms)
  if not success then
    return nil, "Execution error: " .. tostring(result)
  end

  -- Validate result is a table
  if type(result) ~= "table" then
    return nil, string.format(
      "Plugin must return table, got %s",
      type(result)
    )
  end

  return result
end

--- Check if a plugin definition is trusted
-- @param plugin_def table Plugin definition
-- @return boolean True if trusted
function PluginSandbox.is_trusted(plugin_def)
  return plugin_def._trusted == true
end

--- Wrap a function to execute in sandbox with timeout
-- @param fn function Function to wrap
-- @param timeout_ms number|nil Timeout in milliseconds
-- @return function Wrapped function
function PluginSandbox:wrap_function(fn, timeout_ms)
  local sandbox = self

  return function(...)
    local success, result = sandbox:execute_with_timeout(fn, timeout_ms, ...)
    if not success then
      error(result, 0)
    end
    return result
  end
end

--- Get sandbox configuration
-- @return table Configuration
function PluginSandbox:get_config()
  return {
    timeout_ms = self._timeout_ms,
    instruction_count = self._instruction_count,
    allowed_modules = self._allowed_modules,
    enable_timeout = self._enable_timeout,
  }
end

--- Set timeout enabled/disabled
-- @param enabled boolean
function PluginSandbox:set_timeout_enabled(enabled)
  self._enable_timeout = enabled
end

--- Set timeout value
-- @param timeout_ms number Timeout in milliseconds
function PluginSandbox:set_timeout(timeout_ms)
  assert(type(timeout_ms) == "number" and timeout_ms > 0, "Timeout must be positive number")
  self._timeout_ms = timeout_ms
end

--- Add allowed module for require
-- @param module_name string Module name to allow
function PluginSandbox:allow_module(module_name)
  table.insert(self._allowed_modules, module_name)
end

return PluginSandbox
