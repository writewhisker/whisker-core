-- Asset Manager
-- Central registry and manager for all media assets

local Types = require("whisker.media.types")
local Schemas = require("whisker.media.schemas")

local AssetManager = {
  _VERSION = "1.0.0"
}
AssetManager.__index = AssetManager

-- Dependencies for DI pattern
AssetManager._dependencies = {"asset_cache", "asset_loader", "event_bus"}

-- Cached factories for backward compatibility (lazy loaded)
local _asset_cache_cache = nil
local _asset_loader_cache = nil

--- Get the asset cache (supports both DI and backward compatibility)
-- @param deps table|nil Dependencies from container
-- @return table The asset cache
local function get_asset_cache(deps)
  if deps and deps.asset_cache then
    return deps.asset_cache
  end
  -- Fallback: lazy load the default cache for backward compatibility
  if not _asset_cache_cache then
    local AssetCache = require("whisker.media.AssetCache")
    _asset_cache_cache = AssetCache
  end
  return _asset_cache_cache
end

--- Get the asset loader (supports both DI and backward compatibility)
-- @param deps table|nil Dependencies from container
-- @return table The asset loader
local function get_asset_loader(deps)
  if deps and deps.asset_loader then
    return deps.asset_loader
  end
  -- Fallback: lazy load the default loader for backward compatibility
  if not _asset_loader_cache then
    local AssetLoader = require("whisker.media.AssetLoader")
    _asset_loader_cache = AssetLoader
  end
  return _asset_loader_cache
end

--- Create a new AssetManager instance via DI container
-- @param deps table Dependencies from container (asset_cache, asset_loader, event_bus)
-- @return function Factory function that creates AssetManager instances
function AssetManager.create(deps)
  -- Return a factory function that creates managers
  return function(config)
    return AssetManager.new(config, deps)
  end
end

--- Create a new AssetManager instance
-- @param config table|nil Configuration options
-- @param deps table|nil Dependencies from container
-- @return AssetManager The new manager instance
function AssetManager.new(config, deps)
  local self = setmetatable({}, AssetManager)

  config = config or {}
  deps = deps or {}

  -- Store dependencies
  self._event_bus = deps.event_bus

  -- Get cache and loader (use injected or create new)
  local CacheClass = get_asset_cache(deps)
  local LoaderClass = get_asset_loader(deps)

  -- If deps provided cache/loader instances directly, use them
  -- Otherwise, create new instances from the classes
  if deps.asset_cache and type(deps.asset_cache) ~= "table" then
    self._cache = deps.asset_cache
  elseif deps.asset_cache and deps.asset_cache.get then
    -- It's an instance
    self._cache = deps.asset_cache
  else
    -- Create new instance
    self._cache = CacheClass.new({
      bytesLimit = config.memoryBudget or (100 * 1024 * 1024)
    })
  end

  if deps.asset_loader and deps.asset_loader.load then
    -- It's an instance
    self._loader = deps.asset_loader
  else
    -- Create new instance
    self._loader = LoaderClass.new({
      basePath = config.basePath or ""
    })
  end

  self._registry = {}
  self._states = {}
  self._initialized = true

  return self
end

-- Legacy singleton-style initialize (for backward compatibility)
function AssetManager:initialize(config)
  config = config or {}

  self._registry = {}
  self._states = {}

  -- Use helper functions for lazy loading
  local CacheClass = get_asset_cache()
  local LoaderClass = get_asset_loader()

  self._cache = CacheClass.new({
    bytesLimit = config.memoryBudget or (100 * 1024 * 1024)
  })

  self._loader = LoaderClass.new({
    basePath = config.basePath or ""
  })

  self._initialized = true

  return self
end

function AssetManager:register(config)
  if not self._initialized then
    self:initialize()
  end

  -- Validate configuration
  local errors = Schemas.validateAsset(config)
  if #errors > 0 then
    return false, {
      type = "validation",
      message = "Asset validation failed",
      errors = errors
    }
  end

  local assetId = config.id

  -- Check for duplicate
  if self._registry[assetId] then
    return false, {
      type = "duplicate",
      message = "Asset already registered: " .. assetId
    }
  end

  -- Store configuration
  self._registry[assetId] = config
  self._states[assetId] = Types.AssetState.UNLOADED

  -- Emit event
  if self._event_bus then
    self._event_bus:emit("asset:registered", {
      assetId = assetId,
      assetType = config.type
    })
  end

  return true, nil
end

function AssetManager:unregister(assetId)
  if not self._registry[assetId] then
    return false
  end

  -- Unload if loaded
  self:unload(assetId)

  self._registry[assetId] = nil
  self._states[assetId] = nil

  -- Emit event
  if self._event_bus then
    self._event_bus:emit("asset:unregistered", {
      assetId = assetId
    })
  end

  return true
end

function AssetManager:load(assetId, callback)
  if not self._initialized then
    self:initialize()
  end

  local config = self._registry[assetId]

  if not config then
    if callback then
      callback(nil, {
        type = "not_found",
        message = "Asset not registered: " .. assetId
      })
    end
    return false
  end

  -- Check cache first
  local cached = self._cache:get(assetId)
  if cached then
    self._states[assetId] = Types.AssetState.LOADED
    if callback then
      callback(cached, nil)
    end
    return true
  end

  -- Mark as loading
  self._states[assetId] = Types.AssetState.LOADING

  -- Emit loading event
  if self._event_bus then
    self._event_bus:emit("asset:loading", {
      assetId = assetId,
      assetType = config.type
    })
  end

  -- Load the asset
  local event_bus = self._event_bus
  self._loader:load(config, function(asset, error)
    if asset then
      self._cache:set(assetId, asset, asset.sizeBytes or 0)
      self._states[assetId] = Types.AssetState.LOADED

      -- Emit loaded event
      if event_bus then
        event_bus:emit("asset:loaded", {
          assetId = assetId,
          assetType = config.type,
          sizeBytes = asset.sizeBytes
        })
      end
    else
      self._states[assetId] = Types.AssetState.FAILED

      -- Emit failed event
      if event_bus then
        event_bus:emit("asset:failed", {
          assetId = assetId,
          error = error
        })
      end
    end

    if callback then
      callback(asset, error)
    end
  end)

  return true
end

function AssetManager:loadSync(assetId, timeout)
  local result = nil
  local error = nil

  self:load(assetId, function(asset, err)
    result = asset
    error = err
  end)

  return result, error
end

function AssetManager:loadBatch(assetIds, options)
  options = options or {}

  local total = #assetIds
  local loaded = 0
  local errors = {}
  local assets = {}

  for _, assetId in ipairs(assetIds) do
    self:load(assetId, function(asset, error)
      loaded = loaded + 1

      if asset then
        table.insert(assets, asset)
      else
        table.insert(errors, {
          assetId = assetId,
          error = error
        })
      end

      if options.onProgress then
        options.onProgress(loaded, total)
      end

      if loaded >= total and options.onComplete then
        options.onComplete(assets, errors)
      end
    end)
  end

  return true
end

function AssetManager:unload(assetId)
  if not self._cache:has(assetId) then
    return false
  end

  local removed = self._cache:remove(assetId)

  if removed then
    self._states[assetId] = Types.AssetState.UNLOADED
  end

  return removed
end

function AssetManager:get(assetId)
  return self._cache:get(assetId)
end

function AssetManager:getState(assetId)
  return self._states[assetId]
end

function AssetManager:isLoaded(assetId)
  return self._states[assetId] == Types.AssetState.LOADED
end

function AssetManager:isLoading(assetId)
  return self._states[assetId] == Types.AssetState.LOADING
end

function AssetManager:getConfig(assetId)
  return self._registry[assetId]
end

function AssetManager:getAllAssets()
  local assets = {}
  for assetId, _ in pairs(self._registry) do
    table.insert(assets, assetId)
  end
  return assets
end

-- Alias for interface compatibility
AssetManager.getAllIds = AssetManager.getAllAssets

--- Check if an asset is registered
-- @param id string Asset identifier
-- @return boolean True if registered
function AssetManager:isRegistered(id)
  return self._registry[id] ~= nil
end

function AssetManager:pin(assetId)
  return self._cache:pin(assetId)
end

function AssetManager:unpin(assetId)
  return self._cache:unpin(assetId)
end

function AssetManager:retain(assetId)
  return self._cache:retain(assetId)
end

function AssetManager:release(assetId)
  return self._cache:release(assetId)
end

function AssetManager:getRefCount(assetId)
  return self._cache:getRefCount(assetId)
end

function AssetManager:getCacheStats()
  return self._cache:getStats()
end

function AssetManager:setMemoryBudget(bytes)
  self._cache:setMemoryBudget(bytes)
end

function AssetManager:clearCache()
  self._cache:clear()

  -- Update states
  for assetId, state in pairs(self._states) do
    if state == Types.AssetState.LOADED and not self._cache:has(assetId) then
      self._states[assetId] = Types.AssetState.UNLOADED
    end
  end
end

function AssetManager:retry(assetId, callback)
  -- Reset state and reload
  if self._states[assetId] == Types.AssetState.FAILED then
    self._states[assetId] = Types.AssetState.UNLOADED
  end

  return self:load(assetId, callback)
end

function AssetManager:cancel(assetId)
  local cancelled = self._loader:cancel(assetId)

  if cancelled then
    self._states[assetId] = Types.AssetState.UNLOADED
  end

  return cancelled
end

function AssetManager:registerFromManifest(manifestPath)
  local file, err = io.open(manifestPath, "r")

  if not file then
    return 0, {{
      type = "file",
      message = "Failed to open manifest: " .. (err or manifestPath)
    }}
  end

  local content = file:read("*all")
  file:close()

  -- Parse JSON (simple implementation)
  local success, manifest = pcall(function()
    -- Try to use cjson if available, otherwise basic parsing
    local json = package.loaded["cjson"] or package.loaded["dkjson"]
    if json then
      return json.decode(content)
    end

    -- Fallback: try loadstring (unsafe, for development only)
    local fn = load or loadstring
    return fn("return " .. content)()
  end)

  if not success or not manifest then
    return 0, {{
      type = "parse",
      message = "Failed to parse manifest"
    }}
  end

  local count = 0
  local errors = {}

  local assets = manifest.assets or manifest

  for _, config in ipairs(assets) do
    local ok, regErr = self:register(config)
    if ok then
      count = count + 1
    else
      table.insert(errors, {
        assetId = config.id,
        error = regErr
      })
    end
  end

  return count, errors
end

return AssetManager
