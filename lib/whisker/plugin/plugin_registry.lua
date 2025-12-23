--- Plugin Registry
-- Central authority for plugin management with lifecycle control
-- @module whisker.plugin.plugin_registry
-- @author Whisker Core Team
-- @license MIT

local PluginLifecycle = require("whisker.plugin.plugin_lifecycle")
local PluginContext = require("whisker.plugin.plugin_context")
local DependencyResolver = require("whisker.plugin.dependency_resolver")

local PluginRegistry = {}
PluginRegistry.__index = PluginRegistry

-- Singleton instance
local _instance = nil

--- Get the singleton registry instance
-- @return PluginRegistry The shared registry instance
function PluginRegistry.get_instance()
  if not _instance then
    _instance = PluginRegistry.new()
  end
  return _instance
end

--- Reset the singleton instance (for testing)
function PluginRegistry.reset_instance()
  if _instance then
    _instance:destroy_all_plugins()
  end
  _instance = nil
end

--- Create a new plugin registry
-- @return PluginRegistry A new registry instance
function PluginRegistry.new()
  local self = setmetatable({}, PluginRegistry)

  self._plugins = {}          -- name -> Plugin
  self._paths = {}            -- array of search paths
  self._loaded = false

  -- External dependencies (injected)
  self._state_manager = nil
  self._hook_manager = nil
  self._logger = nil

  return self
end

--- Configure plugin search paths
-- @param paths string[] Array of directory paths
function PluginRegistry:set_paths(paths)
  assert(type(paths) == "table", "Paths must be table")
  self._paths = paths
end

--- Get configured search paths
-- @return string[]
function PluginRegistry:get_paths()
  return self._paths
end

--- Set state manager for plugin contexts
-- @param state_manager table Phase 1 state manager
function PluginRegistry:set_state_manager(state_manager)
  self._state_manager = state_manager
end

--- Set hook manager for plugin contexts
-- @param hook_manager table Stage 4 hook manager
function PluginRegistry:set_hook_manager(hook_manager)
  self._hook_manager = hook_manager
end

--- Set logger for lifecycle logging
-- @param logger table Logger instance
function PluginRegistry:set_logger(logger)
  self._logger = logger
end

--- Log a message if logger is available
-- @param level string Log level
-- @param message string Log message
-- @param ... any Format arguments
function PluginRegistry:_log(level, message, ...)
  if self._logger and self._logger[level] then
    self._logger[level](self._logger, message, ...)
  end
end

--- Discover plugins in configured paths
-- @return table<string, table> Map of plugin_name -> metadata
function PluginRegistry:discover_plugins()
  local discovered = {}

  for _, path in ipairs(self._paths) do
    local plugins_in_path = self:_scan_directory(path)
    for name, metadata in pairs(plugins_in_path) do
      if discovered[name] then
        self:_log("warn", "Plugin '%s' found in multiple paths, using first occurrence", name)
      else
        discovered[name] = metadata
      end
    end
  end

  return discovered
end

--- Scan directory for plugin modules
-- @param path string Directory path
-- @return table<string, table> Map of plugin_name -> {path, type, name}
function PluginRegistry:_scan_directory(path)
  local plugins = {}

  -- Check if path exists using pcall
  local dir_handle = io.popen('ls "' .. path .. '" 2>/dev/null')
  if not dir_handle then
    return plugins
  end

  -- Enumerate directory contents
  for entry in dir_handle:lines() do
    -- Skip hidden files
    if not entry:match("^%.") then
      local full_path = path .. "/" .. entry

      -- Check if entry is directory with init.lua
      local test_file = io.open(full_path .. "/init.lua", "r")
      if test_file then
        test_file:close()
        -- Directory plugin with init.lua
        plugins[entry] = {
          path = full_path .. "/init.lua",
          type = "directory",
          name = entry,
        }
      else
        -- Check if single-file plugin
        if entry:match("%.lua$") then
          local plugin_name = entry:gsub("%.lua$", "")
          plugins[plugin_name] = {
            path = full_path,
            type = "file",
            name = plugin_name,
          }
        end
      end
    end
  end

  dir_handle:close()

  return plugins
end

--- Load a plugin from file path
-- @param metadata table Plugin discovery metadata {path, type, name}
-- @return table|nil plugin Loaded plugin or nil on error
-- @return string|nil error Error message if loading failed
function PluginRegistry:load_plugin(metadata)
  local plugin_path = metadata.path
  local plugin_name = metadata.name

  -- Load plugin module
  local module, load_err = self:_load_module(plugin_path, plugin_name)
  if not module then
    return nil, string.format(
      "Failed to load plugin '%s': %s",
      plugin_name,
      load_err
    )
  end

  -- Validate against IPlugin interface (basic validation)
  local valid, validation_err = self:_validate_plugin(module)
  if not valid then
    return nil, string.format(
      "Plugin '%s' validation failed: %s",
      plugin_name,
      validation_err
    )
  end

  -- Ensure plugin name matches directory/filename
  if module.name ~= plugin_name then
    return nil, string.format(
      "Plugin name mismatch: file name '%s' vs declared name '%s'",
      plugin_name,
      module.name
    )
  end

  -- Create Plugin instance
  local plugin = {
    name = module.name,
    version = module.version,
    definition = module,
    state = "loaded",
    module = module,
    context = nil,
    error = nil,
  }

  return plugin
end

--- Load Lua module from file path
-- @param path string File path
-- @param name string Plugin name (for error messages)
-- @return table|nil module Loaded module or nil
-- @return string|nil error Error message if loading failed
function PluginRegistry:_load_module(path, name)
  -- Load file contents
  local file, file_err = io.open(path, "r")
  if not file then
    return nil, "Cannot open file: " .. tostring(file_err)
  end

  local source = file:read("*all")
  file:close()

  -- Compile Lua code
  local chunk, compile_err = load(source, "@" .. path, "t")
  if not chunk then
    return nil, "Syntax error: " .. tostring(compile_err)
  end

  -- Execute module (returns IPlugin table)
  local success, result = pcall(chunk)
  if not success then
    return nil, "Runtime error: " .. tostring(result)
  end

  if type(result) ~= "table" then
    return nil, string.format(
      "Plugin must return table, got %s",
      type(result)
    )
  end

  return result
end

--- Validate plugin definition
-- @param plugin_def table Plugin definition table
-- @return boolean success
-- @return string|nil error Error message if validation failed
function PluginRegistry:_validate_plugin(plugin_def)
  -- Check required fields
  if not plugin_def.name then
    return false, "Missing required field: name"
  end

  if type(plugin_def.name) ~= "string" then
    return false, "Plugin name must be string, got " .. type(plugin_def.name)
  end

  if not plugin_def.name:match("^[a-z][a-z0-9%-]*$") then
    return false, "Plugin name must match pattern ^[a-z][a-z0-9-]*$, got: " .. plugin_def.name
  end

  if not plugin_def.version then
    return false, "Missing required field: version"
  end

  if type(plugin_def.version) ~= "string" then
    return false, "Plugin version must be string, got " .. type(plugin_def.version)
  end

  local major, minor, patch = plugin_def.version:match("^(%d+)%.(%d+)%.(%d+)")
  if not major then
    return false, "Plugin version must be semantic version (MAJOR.MINOR.PATCH), got: " .. plugin_def.version
  end

  -- Validate capabilities if present
  if plugin_def.capabilities then
    local valid, err = PluginContext.validate_capabilities(plugin_def.capabilities)
    if not valid then
      return false, err
    end
  end

  -- Validate lifecycle hooks are functions
  local lifecycle_hooks = {"on_load", "on_init", "on_enable", "on_disable", "on_destroy"}
  for _, hook_name in ipairs(lifecycle_hooks) do
    local hook = plugin_def[hook_name]
    if hook and type(hook) ~= "function" then
      return false, "Lifecycle hook " .. hook_name .. " must be function, got " .. type(hook)
    end
  end

  -- Validate hooks table
  if plugin_def.hooks then
    if type(plugin_def.hooks) ~= "table" then
      return false, "Plugin hooks must be table, got " .. type(plugin_def.hooks)
    end

    for hook_name, hook_fn in pairs(plugin_def.hooks) do
      if type(hook_fn) ~= "function" then
        return false, "Story hook " .. hook_name .. " must be function, got " .. type(hook_fn)
      end
    end
  end

  -- Validate API table
  if plugin_def.api then
    if type(plugin_def.api) ~= "table" then
      return false, "Plugin API must be table, got " .. type(plugin_def.api)
    end

    for fn_name, fn in pairs(plugin_def.api) do
      if type(fn) ~= "function" then
        return false, "API member " .. fn_name .. " must be function, got " .. type(fn)
      end
    end
  end

  return true
end

--- Register loaded plugin in registry
-- @param plugin table Plugin instance
-- @return boolean success
-- @return string|nil error Error message if registration failed
function PluginRegistry:register_plugin(plugin)
  assert(plugin.name, "Plugin must have name")
  assert(plugin.version, "Plugin must have version")

  -- Check for duplicate registration
  if self._plugins[plugin.name] then
    return false, string.format(
      "Plugin '%s' already registered",
      plugin.name
    )
  end

  -- Store in registry
  self._plugins[plugin.name] = plugin

  self:_log("info", "Registered plugin '%s' v%s", plugin.name, plugin.version)

  return true
end

--- Unregister plugin from registry
-- @param plugin_name string
-- @return boolean success
function PluginRegistry:unregister_plugin(plugin_name)
  if not self._plugins[plugin_name] then
    return false
  end

  self._plugins[plugin_name] = nil
  return true
end

--- Get plugin by name
-- @param name string Plugin name
-- @return table|nil Plugin instance
function PluginRegistry:get_plugin(name)
  return self._plugins[name]
end

--- Check if plugin is registered
-- @param name string Plugin name
-- @return boolean
function PluginRegistry:has_plugin(name)
  return self._plugins[name] ~= nil
end

--- Get all registered plugins
-- @return table[] Array of plugins
function PluginRegistry:get_all_plugins()
  local plugins = {}
  for _, plugin in pairs(self._plugins) do
    table.insert(plugins, plugin)
  end
  return plugins
end

--- Get all plugin names
-- @return string[] Sorted array of plugin names
function PluginRegistry:get_plugin_names()
  local names = {}
  for name in pairs(self._plugins) do
    table.insert(names, name)
  end
  table.sort(names)
  return names
end

--- Get plugin count
-- @return number
function PluginRegistry:get_plugin_count()
  local count = 0
  for _ in pairs(self._plugins) do
    count = count + 1
  end
  return count
end

--- Get plugins by state
-- @param state string State to filter by
-- @return table[] Array of plugins in that state
function PluginRegistry:get_plugins_by_state(state)
  local plugins = {}
  for _, plugin in pairs(self._plugins) do
    if plugin.state == state then
      table.insert(plugins, plugin)
    end
  end
  return plugins
end

--- Discover and load all plugins from configured paths
-- @return table results {loaded: Plugin[], failed: {name: string, error: string}[]}
function PluginRegistry:load_all_plugins()
  local results = {
    loaded = {},
    failed = {},
  }

  -- Discover plugins
  local discovered = self:discover_plugins()

  -- Load each discovered plugin
  for name, metadata in pairs(discovered) do
    local plugin, err = self:load_plugin(metadata)

    if plugin then
      local success, reg_err = self:register_plugin(plugin)
      if success then
        table.insert(results.loaded, plugin)
      else
        table.insert(results.failed, {
          name = name,
          error = reg_err,
        })
      end
    else
      table.insert(results.failed, {
        name = name,
        error = err,
      })
    end
  end

  self._loaded = true

  return results
end

--- Check if plugins have been loaded
-- @return boolean
function PluginRegistry:is_loaded()
  return self._loaded
end

--- Clear all registered plugins (for testing/reset)
function PluginRegistry:clear()
  self._plugins = {}
  self._loaded = false
end

--- Transition plugin to new state
-- @param plugin_name string
-- @param target_state string
-- @return boolean success
-- @return string|nil error
function PluginRegistry:transition_plugin(plugin_name, target_state)
  local plugin = self._plugins[plugin_name]
  if not plugin then
    return false, "Plugin not found: " .. plugin_name
  end

  local current_state = plugin.state

  -- Validate transition
  if not PluginLifecycle.is_valid_transition(current_state, target_state) then
    return false, string.format(
      "Invalid transition: %s -> %s",
      current_state,
      target_state
    )
  end

  -- Execute transition
  local success, err = self:_execute_transition(plugin, target_state)
  if not success then
    -- Transition failed, mark as error
    plugin.state = "error"
    plugin.error = err
    self:_log("error", "Plugin '%s' transition failed: %s", plugin_name, err)
    return false, err
  end

  -- Update state
  plugin.state = target_state

  -- Log transition
  self:_log("info", "Plugin '%s' transitioned: %s -> %s", plugin_name, current_state, target_state)

  return true
end

--- Execute transition hooks
-- @param plugin table Plugin instance
-- @param target_state string Target state
-- @return boolean success
-- @return string|nil error
function PluginRegistry:_execute_transition(plugin, target_state)
  local current_state = plugin.state

  -- Get hooks to execute for this transition
  local hooks = PluginLifecycle.get_transition_hooks(current_state, target_state)

  if hooks then
    for _, hook_name in ipairs(hooks) do
      local success, err = self:_invoke_lifecycle_hook(plugin, hook_name)
      if not success then
        return false, err
      end
    end
  end

  return true
end

--- Invoke lifecycle hook with error handling
-- @param plugin table Plugin instance
-- @param hook_name string Hook name
-- @return boolean success
-- @return string|nil error
function PluginRegistry:_invoke_lifecycle_hook(plugin, hook_name)
  local hook = plugin.definition[hook_name]
  if not hook then
    return true  -- Hook not defined, success
  end

  -- Create plugin context if not exists
  if not plugin.context then
    plugin.context = self:_create_plugin_context(plugin)
  end

  -- Invoke hook with error handling
  local success, err = pcall(hook, plugin.context)
  if not success then
    return false, string.format(
      "Hook '%s' failed: %s",
      hook_name,
      tostring(err)
    )
  end

  return true
end

--- Create plugin context
-- @param plugin table Plugin instance
-- @return PluginContext
function PluginRegistry:_create_plugin_context(plugin)
  return PluginContext.new(
    plugin.name,
    plugin.version,
    plugin.definition.capabilities,
    self._state_manager,
    self._hook_manager,
    self
  )
end

--- Initialize all loaded plugins in dependency order
-- @return table results {initialized: string[], failed: {name: string, error: string}[]}
function PluginRegistry:initialize_all_plugins()
  local results = {
    initialized = {},
    failed = {},
  }

  -- Get all loaded plugins
  local loaded = self:get_plugins_by_state("loaded")

  -- Resolve load order
  local ordered, err = DependencyResolver.resolve(loaded)
  if not ordered then
    return {
      initialized = {},
      failed = {{name = "dependency_resolution", error = err}},
    }
  end

  -- Initialize in order
  for _, plugin in ipairs(ordered) do
    local success, init_err = self:transition_plugin(plugin.name, "initialized")
    if success then
      table.insert(results.initialized, plugin.name)
    else
      table.insert(results.failed, {
        name = plugin.name,
        error = init_err,
      })
    end
  end

  return results
end

--- Enable all initialized plugins
-- @return table results {enabled: string[], failed: {name: string, error: string}[]}
function PluginRegistry:enable_all_plugins()
  local results = {
    enabled = {},
    failed = {},
  }

  local initialized = self:get_plugins_by_state("initialized")

  for _, plugin in ipairs(initialized) do
    local success, err = self:transition_plugin(plugin.name, "enabled")
    if success then
      table.insert(results.enabled, plugin.name)
    else
      table.insert(results.failed, {
        name = plugin.name,
        error = err,
      })
    end
  end

  return results
end

--- Disable all enabled plugins
-- @return table results {disabled: string[], failed: {name: string, error: string}[]}
function PluginRegistry:disable_all_plugins()
  local results = {
    disabled = {},
    failed = {},
  }

  local enabled = self:get_plugins_by_state("enabled")

  for _, plugin in ipairs(enabled) do
    local success, err = self:transition_plugin(plugin.name, "disabled")
    if success then
      table.insert(results.disabled, plugin.name)
    else
      table.insert(results.failed, {
        name = plugin.name,
        error = err,
      })
    end
  end

  return results
end

--- Destroy all plugins (cleanup)
function PluginRegistry:destroy_all_plugins()
  local all_plugins = self:get_all_plugins()

  for _, plugin in ipairs(all_plugins) do
    -- Disable if enabled
    if plugin.state == "enabled" then
      self:transition_plugin(plugin.name, "disabled")
    end

    -- Destroy if not already destroyed
    if plugin.state ~= "destroyed" then
      -- Can transition to destroyed from disabled or error
      if plugin.state == "disabled" or plugin.state == "error" then
        self:transition_plugin(plugin.name, "destroyed")
      end
    end

    -- Cleanup context
    if plugin.context then
      plugin.context:cleanup()
      plugin.context = nil
    end
  end

  -- Clear registry
  self:clear()
end

--- Set plugin error
-- @param name string Plugin name
-- @param error_msg string Error message
-- @return boolean success
function PluginRegistry:set_plugin_error(name, error_msg)
  local plugin = self._plugins[name]
  if not plugin then
    return false
  end

  plugin.error = error_msg
  plugin.state = "error"
  return true
end

--- Get plugin error
-- @param name string Plugin name
-- @return string|nil error Error message or nil
function PluginRegistry:get_plugin_error(name)
  local plugin = self._plugins[name]
  if not plugin then
    return nil
  end
  return plugin.error
end

--- Get all plugins with errors
-- @return table[] Array of {name, error, version}
function PluginRegistry:get_failed_plugins()
  local failed = {}
  for _, plugin in pairs(self._plugins) do
    if plugin.state == "error" and plugin.error then
      table.insert(failed, {
        name = plugin.name,
        version = plugin.version,
        error = plugin.error,
      })
    end
  end
  return failed
end

--- Initialize plugin system with default configuration
-- @param config table|nil Configuration {paths: string[], auto_load: boolean}
-- @return PluginRegistry
function PluginRegistry.initialize(config)
  config = config or {}

  local registry = PluginRegistry.get_instance()

  -- Set paths (default to builtin and community)
  local paths = config.paths or {
    "plugins/builtin",
    "plugins/community",
  }
  registry:set_paths(paths)

  -- Set injected dependencies
  if config.state_manager then
    registry:set_state_manager(config.state_manager)
  end
  if config.hook_manager then
    registry:set_hook_manager(config.hook_manager)
  end
  if config.logger then
    registry:set_logger(config.logger)
  end

  -- Auto-load if requested
  if config.auto_load then
    local results = registry:load_all_plugins()

    print(string.format(
      "Loaded %d plugins (%d failed)",
      #results.loaded,
      #results.failed
    ))

    for _, failure in ipairs(results.failed) do
      print(string.format(
        "  Failed to load '%s': %s",
        failure.name,
        failure.error
      ))
    end
  end

  return registry
end

return PluginRegistry
