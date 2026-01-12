--- Hot Module Reload for Lua
-- Implements hot reloading of Lua modules during development
-- @module whisker.dev.hot_reload
-- @author Whisker Development Team
-- @license MIT

local EventSystem = require("whisker.core.event_system")

local HotReload = {}
HotReload.__index = HotReload

--- Create a new hot reload manager
-- @param config Configuration table
-- @param config.watch_paths Paths to watch for module changes (optional)
-- @param config.on_reload Callback when module reloaded (optional)
-- @return HotReload instance
function HotReload.new(config)
  config = config or {}
  
  local self = setmetatable({}, HotReload)
  
  self.watch_paths = config.watch_paths or {}
  self.on_reload = config.on_reload
  
  -- Module tracking
  self.module_paths = {}  -- {module_name = file_path}
  self.module_dependencies = {}  -- {module_name = {dependent1, dependent2, ...}}
  self.module_backups = {}  -- {module_name = module_backup}
  
  -- Event system
  self.events = EventSystem.new()
  
  -- Track initial loaded modules
  self:_scan_loaded_modules()
  
  return self
end

--- Scan currently loaded modules
function HotReload:_scan_loaded_modules()
  for module_name, _ in pairs(package.loaded) do
    -- Skip internal Lua modules
    if not module_name:match("^_") and module_name ~= "package" then
      local path = self:_get_module_path(module_name)
      if path then
        self.module_paths[module_name] = path
      end
    end
  end
end

--- Get file path for a module
-- @param module_name Module name
-- @return string|nil File path or nil
function HotReload:_get_module_path(module_name)
  -- Convert module name to path pattern
  local path_pattern = module_name:gsub("%.", "/")
  
  -- Search package.path
  for path_template in package.path:gmatch("[^;]+") do
    local file_path = path_template:gsub("%?", path_pattern)
    
    local file = io.open(file_path, "r")
    if file then
      file:close()
      return file_path
    end
  end
  
  return nil
end

--- Get module name from file path
-- @param file_path File path
-- @return string|nil Module name or nil
function HotReload:_get_module_from_path(file_path)
  -- Reverse lookup in module_paths
  for module_name, path in pairs(self.module_paths) do
    if path == file_path then
      return module_name
    end
  end
  
  -- Try to infer from path
  for path_template in package.path:gmatch("[^;]+") do
    local pattern = path_template:gsub("%.", "%%.")
    pattern = pattern:gsub("%?", "(.+)")
    
    local match = file_path:match(pattern)
    if match then
      return match:gsub("/", ".")
    end
  end
  
  return nil
end

--- Reload a module
-- @param module_name Module name to reload
-- @return boolean success, string? error
function HotReload:reload_module(module_name)
  if not package.loaded[module_name] then
    return false, "Module not loaded: " .. module_name
  end
  
  -- Backup current module
  self.module_backups[module_name] = package.loaded[module_name]
  
  -- Try to reload
  local success, result = self:safe_reload(module_name)
  
  if success then
    -- Reload dependents
    self:_reload_dependents(module_name)
    
    -- Emit event
    self.events:emit("module_reloaded", {
      module = module_name,
      path = self.module_paths[module_name]
    })
    
    -- Call callback
    if self.on_reload then
      self.on_reload(module_name)
    end
    
    return true
  else
    -- Restore backup on failure
    package.loaded[module_name] = self.module_backups[module_name]
    return false, result
  end
end

--- Safely reload a module with error handling
-- @param module_name Module name
-- @return boolean success, any result_or_error
function HotReload:safe_reload(module_name)
  -- Unload module
  package.loaded[module_name] = nil
  
  -- Try to reload
  local success, result = pcall(require, module_name)
  
  if not success then
    return false, "Failed to reload module: " .. tostring(result)
  end
  
  -- Validate module
  if not self:_validate_module(result) then
    return false, "Module validation failed"
  end
  
  return true, result
end

--- Validate reloaded module
-- @param module Module to validate
-- @return boolean valid
function HotReload:_validate_module(module)
  -- Basic validation - module should be a table or function
  local module_type = type(module)
  return module_type == "table" or module_type == "function" or module_type == "boolean"
end

--- Build dependency graph
-- This is a simplified implementation
-- In production, you'd want to parse require() calls
function HotReload:_build_dependency_graph()
  -- Clear existing dependencies
  self.module_dependencies = {}
  
  -- For now, we don't track dependencies automatically
  -- This could be enhanced with AST parsing
end

--- Get modules that depend on a module
-- @param module_name Module name
-- @return table Array of dependent module names
function HotReload:_get_dependents(module_name)
  return self.module_dependencies[module_name] or {}
end

--- Reload dependent modules
-- @param module_name Module that was reloaded
function HotReload:_reload_dependents(module_name)
  local dependents = self:_get_dependents(module_name)
  
  for _, dependent in ipairs(dependents) do
    -- Reload dependent recursively
    self:reload_module(dependent)
  end
end

--- Register a dependency relationship
-- @param module_name Module name
-- @param depends_on Module it depends on
function HotReload:register_dependency(module_name, depends_on)
  if not self.module_dependencies[depends_on] then
    self.module_dependencies[depends_on] = {}
  end
  
  -- Add if not already present
  local found = false
  for _, dep in ipairs(self.module_dependencies[depends_on]) do
    if dep == module_name then
      found = true
      break
    end
  end
  
  if not found then
    table.insert(self.module_dependencies[depends_on], module_name)
  end
end

--- Handle file change event from watcher
-- @param file_path Changed file path
-- @return boolean handled
function HotReload:handle_file_change(file_path)
  -- Get module name from path
  local module_name = self:_get_module_from_path(file_path)
  
  if not module_name then
    return false
  end
  
  -- Reload the module
  local success, err = self:reload_module(module_name)
  
  if not success then
    self.events:emit("reload_failed", {
      module = module_name,
      path = file_path,
      error = err
    })
  end
  
  return success
end

--- Connect to a file watcher
-- @param watcher File watcher instance
function HotReload:connect_watcher(watcher)
  -- Listen for file modifications
  watcher:on("file_modified", function(data)
    if data.path:match("%.lua$") then
      self:handle_file_change(data.path)
    end
  end)
  
  -- Listen for file creation (new modules)
  watcher:on("file_created", function(data)
    if data.path:match("%.lua$") then
      -- Track the new module path
      local module_name = self:_get_module_from_path(data.path)
      if module_name then
        self.module_paths[module_name] = data.path
      end
    end
  end)
end

--- Register event handler
-- @param event Event name ("module_reloaded", "reload_failed")
-- @param callback Callback function(data)
function HotReload:on(event, callback)
  -- Wrap callback to extract data from event object
  local wrapper = function(event_obj)
    callback(event_obj.data)
  end
  self.events:on(event, wrapper)
end

--- Get list of tracked modules
-- @return table Array of module names
function HotReload:get_tracked_modules()
  local modules = {}
  for module_name, _ in pairs(self.module_paths) do
    table.insert(modules, module_name)
  end
  return modules
end

--- Get module count
-- @return number
function HotReload:get_module_count()
  local count = 0
  for _, _ in pairs(self.module_paths) do
    count = count + 1
  end
  return count
end

--- Clear all module backups
function HotReload:clear_backups()
  self.module_backups = {}
end

--- Get dependency count for a module
-- @param module_name Module name
-- @return number Number of modules that depend on this module
function HotReload:get_dependent_count(module_name)
  local dependents = self.module_dependencies[module_name]
  return dependents and #dependents or 0
end

return HotReload
