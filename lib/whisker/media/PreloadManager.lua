-- Preload Manager
-- Coordinates preloading operations with group management and memory budget

local Types = require("whisker.media.types")

local PreloadManager = {
  _VERSION = "1.0.0"
}
PreloadManager.__index = PreloadManager

-- Dependencies for DI pattern
PreloadManager._dependencies = {"asset_manager", "event_bus"}

-- Cached asset manager for backward compatibility (lazy loaded)
local _asset_manager_cache = nil

--- Get the asset manager (supports both DI and backward compatibility)
local function get_asset_manager(deps)
  if deps and deps.asset_manager then
    return deps.asset_manager
  end
  if not _asset_manager_cache then
    _asset_manager_cache = require("whisker.media.AssetManager")
  end
  return _asset_manager_cache
end

--- Create a new PreloadManager instance via DI container
-- @param deps table Dependencies from container (asset_manager, event_bus)
-- @return function Factory function that creates PreloadManager instances
function PreloadManager.create(deps)
  return function(config)
    return PreloadManager.new(config, deps)
  end
end

--- Create a new PreloadManager instance
-- @param config table|nil Configuration options
-- @param deps table|nil Dependencies from container
-- @return PreloadManager The new manager instance
function PreloadManager.new(config, deps)
  local self = setmetatable({}, PreloadManager)

  config = config or {}
  deps = deps or {}

  -- Store dependencies
  self._event_bus = deps.event_bus
  self._asset_manager = get_asset_manager(deps)

  self._preloadGroups = {}
  self._activePreloads = {}
  self._preloadQueue = {}
  self._nextPreloadId = 1
  self._maxConcurrentPreloads = config.maxConcurrent or 3
  self._preloadBudgetRatio = config.budgetRatio or 0.3
  self._initialized = true

  return self
end

-- Legacy singleton-style initialize (for backward compatibility)
function PreloadManager:initialize(config)
  config = config or {}

  -- Ensure asset manager is available for legacy usage
  if not self._asset_manager then
    self._asset_manager = get_asset_manager()
  end

  self._preloadGroups = {}
  self._activePreloads = {}
  self._preloadQueue = {}
  self._nextPreloadId = 1
  self._maxConcurrentPreloads = config.maxConcurrent or 3
  self._preloadBudgetRatio = config.budgetRatio or 0.3
  self._initialized = true

  return self
end

function PreloadManager:registerGroup(groupName, assetIds)
  self._preloadGroups[groupName] = {
    assetIds = assetIds,
    preloaded = false
  }
end

function PreloadManager:unregisterGroup(groupName)
  self._preloadGroups[groupName] = nil
end

function PreloadManager:getGroup(groupName)
  return self._preloadGroups[groupName]
end

function PreloadManager:preloadGroup(groupNameOrAssets, options)
  options = options or {}

  local assetIds

  if type(groupNameOrAssets) == "string" then
    local group = self._preloadGroups[groupNameOrAssets]
    if not group then
      return nil
    end
    assetIds = group.assetIds
  elseif type(groupNameOrAssets) == "table" then
    assetIds = groupNameOrAssets
  else
    return nil
  end

  -- Filter already-loaded assets
  local assetsToLoad = {}
  for _, assetId in ipairs(assetIds) do
    if not self._asset_manager:isLoaded(assetId) then
      table.insert(assetsToLoad, assetId)
    end
  end

  if #assetsToLoad == 0 then
    if options.onComplete then
      options.onComplete(#assetIds, {})
    end
    return nil
  end

  -- Create preload operation
  local preloadId = self._nextPreloadId
  self._nextPreloadId = self._nextPreloadId + 1

  local preloadOp = {
    id = preloadId,
    assetIds = assetsToLoad,
    total = #assetsToLoad,
    loaded = 0,
    errors = {},
    priority = options.priority or "normal",
    onProgress = options.onProgress,
    onComplete = options.onComplete,
    startTime = os.clock()
  }

  if self:_canStartPreload() then
    self:_startPreload(preloadOp)
  else
    table.insert(self._preloadQueue, preloadOp)
  end

  return preloadId
end

function PreloadManager:_canStartPreload()
  local activeCount = 0
  for _ in pairs(self._activePreloads) do
    activeCount = activeCount + 1
  end
  return activeCount < self._maxConcurrentPreloads
end

function PreloadManager:_startPreload(preloadOp)
  self._activePreloads[preloadOp.id] = preloadOp

  -- Emit preload started event
  if self._event_bus then
    self._event_bus:emit("preload:start", {
      preloadId = preloadOp.id,
      assetCount = #preloadOp.assetIds,
      priority = preloadOp.priority
    })
  end

  for _, assetId in ipairs(preloadOp.assetIds) do
    self._asset_manager:load(assetId, function(asset, error)
      self:_handleAssetLoaded(preloadOp.id, assetId, asset, error)
    end)
  end
end

function PreloadManager:_handleAssetLoaded(preloadId, assetId, asset, error)
  local preloadOp = self._activePreloads[preloadId]
  if not preloadOp then return end

  preloadOp.loaded = preloadOp.loaded + 1

  if error then
    table.insert(preloadOp.errors, {
      assetId = assetId,
      error = error
    })
  end

  -- Emit progress event
  if self._event_bus then
    self._event_bus:emit("preload:progress", {
      preloadId = preloadId,
      assetId = assetId,
      loaded = preloadOp.loaded,
      total = preloadOp.total,
      success = not error
    })
  end

  if preloadOp.onProgress then
    preloadOp.onProgress(preloadOp.loaded, preloadOp.total)
  end

  if preloadOp.loaded >= preloadOp.total then
    self:_completePreload(preloadId)
  end
end

function PreloadManager:_completePreload(preloadId)
  local preloadOp = self._activePreloads[preloadId]
  if not preloadOp then return end

  local successCount = preloadOp.loaded - #preloadOp.errors

  -- Emit completion event
  if self._event_bus then
    self._event_bus:emit("preload:complete", {
      preloadId = preloadId,
      successCount = successCount,
      errorCount = #preloadOp.errors,
      duration = os.clock() - preloadOp.startTime
    })
  end

  if preloadOp.onComplete then
    preloadOp.onComplete(successCount, preloadOp.errors)
  end

  self._activePreloads[preloadId] = nil
  self:_processQueue()
end

function PreloadManager:_processQueue()
  if not self:_canStartPreload() then return end
  if #self._preloadQueue == 0 then return end

  -- Sort by priority
  table.sort(self._preloadQueue, function(a, b)
    local priorityOrder = {high = 3, normal = 2, low = 1}
    return (priorityOrder[a.priority] or 2) > (priorityOrder[b.priority] or 2)
  end)

  local preloadOp = table.remove(self._preloadQueue, 1)
  self:_startPreload(preloadOp)
end

function PreloadManager:cancelPreload(preloadId)
  if self._activePreloads[preloadId] then
    self._activePreloads[preloadId] = nil
    return true
  end

  for i, op in ipairs(self._preloadQueue) do
    if op.id == preloadId then
      table.remove(self._preloadQueue, i)
      return true
    end
  end

  return false
end

function PreloadManager:unloadGroup(groupNameOrAssets)
  local assetIds

  if type(groupNameOrAssets) == "string" then
    local group = self._preloadGroups[groupNameOrAssets]
    if not group then return false end
    assetIds = group.assetIds
    group.preloaded = false
  elseif type(groupNameOrAssets) == "table" then
    assetIds = groupNameOrAssets
  else
    return false
  end

  for _, assetId in ipairs(assetIds) do
    self._asset_manager:unload(assetId)
  end

  return true
end

function PreloadManager:preloadForPassage(passageId, options)
  options = options or {}

  -- This would integrate with StoryEngine to get passage content
  -- For now, return nil as StoryEngine integration is external
  return nil
end

function PreloadManager:extractPassageAssets(passage)
  local assets = {}
  local content = passage.content or passage.text or ""

  -- Extract audio directives
  for assetId in content:gmatch("@@audio:%w+ ([%w_]+)") do
    table.insert(assets, assetId)
  end

  -- Extract image directives
  for assetId in content:gmatch("@@image:%w+ ([%w_]+)") do
    table.insert(assets, assetId)
  end

  -- Extract explicit preload directives
  for assetIds in content:gmatch("@@preload:%w+ ([%w_, ]+)") do
    for assetId in assetIds:gmatch("([%w_]+)") do
      table.insert(assets, assetId)
    end
  end

  return assets
end

function PreloadManager:getPreloadBudget()
  local cacheStats = self._asset_manager:getCacheStats()
  return cacheStats.bytesLimit * self._preloadBudgetRatio
end

function PreloadManager:getPreloadUsage()
  local usage = 0

  for _, preloadOp in pairs(self._activePreloads) do
    for _, assetId in ipairs(preloadOp.assetIds) do
      if self._asset_manager:isLoaded(assetId) then
        local asset = self._asset_manager:get(assetId)
        if asset and asset.sizeBytes then
          usage = usage + asset.sizeBytes
        end
      end
    end
  end

  return usage
end

function PreloadManager:isPreloadBudgetExceeded()
  return self:getPreloadUsage() > self:getPreloadBudget()
end

function PreloadManager:getPreloadStatus(preloadId)
  local preloadOp = self._activePreloads[preloadId]
  if preloadOp then
    return {
      id = preloadId,
      status = "loading",
      loaded = preloadOp.loaded,
      total = preloadOp.total,
      progress = preloadOp.loaded / preloadOp.total,
      errors = #preloadOp.errors
    }
  end

  for _, op in ipairs(self._preloadQueue) do
    if op.id == preloadId then
      return {
        id = preloadId,
        status = "queued",
        priority = op.priority
      }
    end
  end

  return nil
end

function PreloadManager:getActivePreloads()
  local active = {}
  for id, _ in pairs(self._activePreloads) do
    table.insert(active, self:getPreloadStatus(id))
  end
  return active
end

function PreloadManager:getQueuedPreloads()
  local queued = {}
  for _, op in ipairs(self._preloadQueue) do
    table.insert(queued, {
      id = op.id,
      status = "queued",
      priority = op.priority,
      assetCount = #op.assetIds
    })
  end
  return queued
end

return PreloadManager
