--- Built-in Plugin Loader
-- Specialized loader for trusted built-in plugins
-- @module whisker.plugin.builtin_loader
-- @author Whisker Core Team
-- @license MIT

local BuiltinLoader = {}
BuiltinLoader._dependencies = {}
BuiltinLoader.__index = BuiltinLoader

--- Default builtin plugins directory name
BuiltinLoader.BUILTIN_DIR = "builtin"

--- Create a new builtin loader
-- @param config table|nil Configuration options
-- @return BuiltinLoader
function BuiltinLoader.new(config, deps)
  deps = deps or {}
  local self = setmetatable({}, BuiltinLoader)

  config = config or {}
  self._builtin_path = config.builtin_path  -- Can be nil, will be found in paths
  self._enabled_plugins = config.enabled_plugins or {}  -- Map of name -> boolean
  self._logger = config.logger

  return self
end

--- Set logger
-- @param logger table Logger instance
function BuiltinLoader:set_logger(logger)
  self._logger = logger
end

--- Set enabled plugins configuration
-- @param enabled_plugins table Map of plugin_name -> boolean
function BuiltinLoader:set_enabled_plugins(enabled_plugins)
  self._enabled_plugins = enabled_plugins or {}
end

--- Check if a plugin is enabled in config
-- @param plugin_name string Plugin name
-- @return boolean
function BuiltinLoader:is_plugin_enabled(plugin_name)
  local enabled = self._enabled_plugins[plugin_name]
  if enabled == nil then
    return true  -- Default to enabled if not specified
  end
  return enabled == true
end

--- Find builtin path in given paths array
-- @param paths string[] Array of plugin paths
-- @return string|nil Builtin path or nil
function BuiltinLoader:find_builtin_path(paths)
  for _, path in ipairs(paths) do
    if path:match(BuiltinLoader.BUILTIN_DIR) then
      return path
    end
  end
  return nil
end

--- Check if a path is a builtin path
-- @param path string Path to check
-- @return boolean
function BuiltinLoader.is_builtin_path(path)
  return path:match(BuiltinLoader.BUILTIN_DIR) ~= nil
end

--- Discover built-in plugins in a directory
-- @param base_path string Base path to scan
-- @return table[] Array of plugin metadata {name, path, init_file}
function BuiltinLoader:discover_plugins(base_path)
  local plugins = {}

  -- Try to list directory contents
  local handle = io.popen('ls -1 "' .. base_path .. '" 2>/dev/null')
  if not handle then
    if self._logger then
      self._logger:warn("Cannot scan builtin directory: " .. base_path)
    end
    return plugins
  end

  for dir_name in handle:lines() do
    local plugin_path = base_path .. "/" .. dir_name
    local init_path = plugin_path .. "/init.lua"

    -- Check if init.lua exists
    local init_file = io.open(init_path, "r")
    if init_file then
      init_file:close()

      table.insert(plugins, {
        name = dir_name,
        path = plugin_path,
        init_file = init_path,
      })
    end
  end

  handle:close()

  -- Sort for deterministic order
  table.sort(plugins, function(a, b)
    return a.name < b.name
  end)

  return plugins
end

--- Load a single built-in plugin
-- @param metadata table Plugin metadata from discover
-- @return table|nil Plugin definition or nil
-- @return string|nil Error message if failed
function BuiltinLoader:load_plugin(metadata)
  -- Check if enabled
  if not self:is_plugin_enabled(metadata.name) then
    if self._logger then
      self._logger:debug("Skipping disabled builtin: " .. metadata.name)
    end
    return nil, "disabled"
  end

  -- Load the init file
  local chunk, load_err = loadfile(metadata.init_file)
  if not chunk then
    return nil, "Load error: " .. tostring(load_err)
  end

  -- Execute to get plugin definition
  local success, result = pcall(chunk)
  if not success then
    return nil, "Execution error: " .. tostring(result)
  end

  -- Validate result
  if type(result) ~= "table" then
    return nil, "Plugin must return table, got " .. type(result)
  end

  -- Validate required fields
  if not result.name then
    return nil, "Plugin missing required field: name"
  end

  if not result.version then
    return nil, "Plugin missing required field: version"
  end

  -- Ensure trusted flag for builtins
  result._trusted = true

  -- Add metadata
  result._metadata = {
    path = metadata.path,
    init_file = metadata.init_file,
    load_time = os.time(),
  }

  if self._logger then
    self._logger:debug(string.format(
      "Loaded builtin plugin: %s v%s",
      result.name,
      result.version
    ))
  end

  return result
end

--- Load all built-in plugins from a directory
-- @param base_path string Base path to scan
-- @return table results {loaded: table[], skipped: string[], failed: table[]}
function BuiltinLoader:load_all(base_path)
  local results = {
    loaded = {},
    skipped = {},
    failed = {},
  }

  -- Discover plugins
  local discovered = self:discover_plugins(base_path)

  if self._logger then
    self._logger:debug(string.format(
      "Discovered %d builtin plugins in %s",
      #discovered,
      base_path
    ))
  end

  -- Load each plugin
  for _, metadata in ipairs(discovered) do
    local plugin, err = self:load_plugin(metadata)

    if plugin then
      table.insert(results.loaded, plugin)
    elseif err == "disabled" then
      table.insert(results.skipped, metadata.name)
    else
      table.insert(results.failed, {
        name = metadata.name,
        error = err,
      })

      if self._logger then
        self._logger:error(string.format(
          "Failed to load builtin plugin '%s': %s",
          metadata.name,
          err
        ))
      end
    end
  end

  return results
end

--- Validate a built-in plugin definition
-- @param plugin table Plugin definition
-- @return boolean valid
-- @return string|nil error Error message if invalid
function BuiltinLoader.validate(plugin)
  if not plugin then
    return false, "Plugin is nil"
  end

  if type(plugin) ~= "table" then
    return false, "Plugin must be table"
  end

  if not plugin.name then
    return false, "Missing required field: name"
  end

  if type(plugin.name) ~= "string" then
    return false, "Field 'name' must be string"
  end

  if not plugin.version then
    return false, "Missing required field: version"
  end

  if type(plugin.version) ~= "string" then
    return false, "Field 'version' must be string"
  end

  -- Trusted flag is required for builtins
  if not plugin._trusted then
    return false, "Built-in plugins must have _trusted = true"
  end

  -- API should be a table if present
  if plugin.api and type(plugin.api) ~= "table" then
    return false, "Field 'api' must be table"
  end

  -- Lifecycle hooks should be functions if present
  local hooks = {"on_load", "on_init", "on_enable", "on_disable", "on_destroy"}
  for _, hook_name in ipairs(hooks) do
    if plugin[hook_name] and type(plugin[hook_name]) ~= "function" then
      return false, "Hook '" .. hook_name .. "' must be function"
    end
  end

  return true
end

--- Get builtin plugin metadata for documentation
-- @param plugin table Plugin definition
-- @return table Metadata summary
function BuiltinLoader.get_metadata(plugin)
  return {
    name = plugin.name,
    version = plugin.version,
    author = plugin.author or "whisker-core",
    description = plugin.description or "",
    license = plugin.license or "MIT",
    dependencies = plugin.dependencies or {},
    capabilities = plugin.capabilities or {},
    has_api = plugin.api ~= nil and next(plugin.api) ~= nil,
    has_hooks = plugin.hooks ~= nil and next(plugin.hooks) ~= nil,
  }
end

return BuiltinLoader
