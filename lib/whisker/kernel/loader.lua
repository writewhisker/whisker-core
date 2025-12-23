--- Module Loader
-- Loads and initializes modules into the container
-- @module whisker.kernel.loader
-- @author Whisker Core Team
-- @license MIT

local Loader = {}
Loader.__index = Loader

--- Create a new loader instance
-- @param container Container The DI container
-- @param registry Registry The module registry
-- @return Loader A new loader
function Loader.new(container, registry)
  local self = setmetatable({}, Loader)
  self._container = container
  self._registry = registry
  self._loaded = {}
  return self
end

--- Load a module by name
-- @param name string The module name
-- @param options table|nil Load options
-- @return boolean True if loading succeeded
-- @return string|nil Error message if loading failed
function Loader:load(name, options)
  options = options or {}

  -- Check if already loaded
  if self._loaded[name] and not options.reload then
    return true
  end

  -- Get module from registry
  local module = self._registry:get(name)
  if not module then
    return false, "Module '" .. name .. "' not found in registry"
  end

  -- Get metadata
  local metadata = self._registry:get_metadata(name) or {}

  -- Load dependencies first
  if metadata.dependencies then
    for _, dep in ipairs(metadata.dependencies) do
      if not self._loaded[dep] then
        local ok, err = self:load(dep)
        if not ok then
          return false, "Failed to load dependency '" .. dep .. "': " .. (err or "unknown error")
        end
      end
    end
  end

  -- Register with container
  local service_name = metadata.service_name or name
  local registration_options = {
    singleton = metadata.singleton ~= false,
    implements = metadata.implements,
    override = options.reload,
  }

  self._container:register(service_name, module, registration_options)
  self._loaded[name] = true

  -- Emit loaded event
  if self._container:has("events") then
    local events = self._container:resolve("events")
    events:emit("module:loaded", {
      name = name,
      service_name = service_name,
      metadata = metadata,
    })
  end

  return true
end

--- Load multiple modules
-- @param names table Array of module names
-- @param options table|nil Load options
-- @return boolean True if all loaded successfully
-- @return table Array of error messages for failed loads
function Loader:load_all(names, options)
  local errors = {}

  for _, name in ipairs(names) do
    local ok, err = self:load(name, options)
    if not ok then
      table.insert(errors, {name = name, error = err})
    end
  end

  return #errors == 0, errors
end

--- Load all modules in a category
-- @param category string The category name
-- @param options table|nil Load options
-- @return boolean True if all loaded successfully
-- @return table Array of error messages for failed loads
function Loader:load_category(category, options)
  local names = self._registry:get_by_category(category)
  return self:load_all(names, options)
end

--- Check if a module is loaded
-- @param name string The module name
-- @return boolean True if loaded
function Loader:is_loaded(name)
  return self._loaded[name] == true
end

--- Unload a module
-- @param name string The module name
function Loader:unload(name)
  if not self._loaded[name] then
    return
  end

  local metadata = self._registry:get_metadata(name) or {}
  local service_name = metadata.service_name or name

  self._container:unregister(service_name)
  self._loaded[name] = nil

  -- Emit unloaded event
  if self._container:has("events") then
    local events = self._container:resolve("events")
    events:emit("module:unloaded", {
      name = name,
      service_name = service_name,
    })
  end
end

--- Get all loaded module names
-- @return table Array of loaded module names
function Loader:get_loaded()
  local names = {}
  for name in pairs(self._loaded) do
    table.insert(names, name)
  end
  return names
end

return Loader
