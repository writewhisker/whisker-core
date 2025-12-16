-- whisker/kernel/loader.lua
-- Dynamic module loading with lazy loading support
-- Integrates with container and capabilities

local Loader = {}
Loader.__index = Loader

-- Error codes for loader
Loader.errors = {
  MODULE_NOT_FOUND = "L001",
  INVALID_PATH = "L002",
  LOAD_FAILED = "L003",
}

-- Create a new loader instance
-- @param options table - Optional: container, capabilities, base_path
function Loader.new(options)
  options = options or {}
  return setmetatable({
    _loaded = {},
    _lazy = {},
    _container = options.container,
    _capabilities = options.capabilities,
    _base_path = options.base_path or "whisker",
  }, Loader)
end

-- Load a module by path
-- @param path string - Module path (e.g., "core.story" or "whisker.core.story")
-- @return any - The loaded module
function Loader:load(path)
  if not path or path == "" then
    error(string.format("[%s] Invalid module path", Loader.errors.INVALID_PATH), 2)
  end

  -- Normalize path (add base_path if not present)
  local full_path = path
  if not path:match("^" .. self._base_path .. "%.") then
    full_path = self._base_path .. "." .. path
  end

  -- Return cached module if already loaded
  if self._loaded[full_path] then
    return self._loaded[full_path]
  end

  -- Try to load the module
  local ok, module = pcall(require, full_path)
  if not ok then
    error(string.format("[%s] Failed to load module '%s': %s",
      Loader.errors.MODULE_NOT_FOUND, full_path, tostring(module)), 2)
  end

  -- Cache the loaded module
  self._loaded[full_path] = module

  -- Auto-register if module has _whisker metadata
  self:_auto_register(full_path, module)

  return module
end

-- Create a lazy-loading proxy for a module
-- Module is not loaded until first access
-- @param path string - Module path
-- @return table - Proxy that loads on first access
function Loader:lazy(path)
  if self._lazy[path] then
    return self._lazy[path]
  end

  local loader = self
  local loaded = nil

  local proxy = setmetatable({}, {
    __index = function(_, key)
      if not loaded then
        loaded = loader:load(path)
      end
      return loaded[key]
    end,
    __newindex = function(_, key, value)
      if not loaded then
        loaded = loader:load(path)
      end
      loaded[key] = value
    end,
    __call = function(_, ...)
      if not loaded then
        loaded = loader:load(path)
      end
      return loaded(...)
    end,
  })

  self._lazy[path] = proxy
  return proxy
end

-- Check if a module is available (without loading it)
-- @param path string - Module path
-- @return boolean
function Loader:exists(path)
  local full_path = path
  if not path:match("^" .. self._base_path .. "%.") then
    full_path = self._base_path .. "." .. path
  end

  -- Check if already loaded
  if self._loaded[full_path] then
    return true
  end

  -- Try to find the module in package.preload or package.path
  if package.preload[full_path] then
    return true
  end

  -- Check package.path
  local search_path = full_path:gsub("%.", "/")
  for template in package.path:gmatch("[^;]+") do
    local file_path = template:gsub("%?", search_path)
    local file = io.open(file_path, "r")
    if file then
      file:close()
      return true
    end
  end

  return false
end

-- Get list of loaded modules
-- @return table - Array of module paths
function Loader:list_loaded()
  local paths = {}
  for path in pairs(self._loaded) do
    table.insert(paths, path)
  end
  table.sort(paths)
  return paths
end

-- Unload a module (remove from cache)
-- @param path string - Module path
-- @return boolean - True if module was unloaded
function Loader:unload(path)
  local full_path = path
  if not path:match("^" .. self._base_path .. "%.") then
    full_path = self._base_path .. "." .. path
  end

  if self._loaded[full_path] then
    self._loaded[full_path] = nil
    package.loaded[full_path] = nil
    return true
  end
  return false
end

-- Internal: Auto-register module with container if it has metadata
function Loader:_auto_register(path, module)
  if type(module) ~= "table" then return end

  local meta = module._whisker
  if not meta then return end

  -- Register capability if specified
  if meta.capability and self._capabilities then
    self._capabilities:register(meta.capability, true)
  end

  -- Register with container if specified
  if meta.name and self._container then
    local options = {
      singleton = meta.singleton,
      implements = meta.implements,
      depends = meta.depends,
    }

    -- Don't re-register if already registered
    if not self._container:has(meta.name) then
      self._container:register(meta.name, module, options)
    end
  end
end

-- Clear all loaded modules and caches
function Loader:clear()
  -- Remove from package.loaded too
  for path in pairs(self._loaded) do
    package.loaded[path] = nil
  end
  self._loaded = {}
  self._lazy = {}
end

return Loader
