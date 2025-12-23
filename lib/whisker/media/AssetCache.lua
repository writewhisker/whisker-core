-- Asset Cache
-- LRU cache with memory budget management

local Types = require("whisker.media.types")

local AssetCache = {
  _VERSION = "1.0.0"
}
AssetCache.__index = AssetCache

function AssetCache.new(config)
  local self = setmetatable({}, AssetCache)

  config = config or {}

  self._cache = {}
  self._accessOrder = {}
  self._pinnedAssets = {}
  self._refCounts = {}

  self._bytesLimit = config.bytesLimit or (100 * 1024 * 1024) -- 100MB default
  self._bytesUsed = 0
  self._assetCount = 0
  self._hits = 0
  self._misses = 0

  self._evictionStrategy = config.evictionStrategy or Types.EvictionStrategy.LRU

  return self
end

function AssetCache:get(assetId)
  local entry = self._cache[assetId]

  if entry then
    self._hits = self._hits + 1
    self:_touchAccess(assetId)
    return entry.data
  end

  self._misses = self._misses + 1
  return nil
end

function AssetCache:set(assetId, data, sizeBytes)
  sizeBytes = sizeBytes or 0

  -- Remove existing entry if present
  if self._cache[assetId] then
    self:remove(assetId)
  end

  -- Evict entries if needed to make room
  while self._bytesUsed + sizeBytes > self._bytesLimit and self._assetCount > 0 do
    local evicted = self:_evictOne()
    if not evicted then
      break
    end
  end

  -- Store the entry
  self._cache[assetId] = {
    data = data,
    sizeBytes = sizeBytes,
    loadedAt = os.time(),
    accessCount = 1
  }

  self._bytesUsed = self._bytesUsed + sizeBytes
  self._assetCount = self._assetCount + 1

  self:_touchAccess(assetId)

  return true
end

function AssetCache:remove(assetId)
  local entry = self._cache[assetId]

  if not entry then
    return false
  end

  -- Don't remove pinned assets
  if self._pinnedAssets[assetId] then
    return false
  end

  -- Don't remove assets with references
  if self._refCounts[assetId] and self._refCounts[assetId] > 0 then
    return false
  end

  self._bytesUsed = self._bytesUsed - (entry.sizeBytes or 0)
  self._assetCount = self._assetCount - 1

  self._cache[assetId] = nil
  self._refCounts[assetId] = nil
  self:_removeFromAccessOrder(assetId)

  return true
end

function AssetCache:has(assetId)
  return self._cache[assetId] ~= nil
end

function AssetCache:pin(assetId)
  if self._cache[assetId] then
    self._pinnedAssets[assetId] = true
    return true
  end
  return false
end

function AssetCache:unpin(assetId)
  self._pinnedAssets[assetId] = nil
  return true
end

function AssetCache:isPinned(assetId)
  return self._pinnedAssets[assetId] == true
end

function AssetCache:retain(assetId)
  if not self._cache[assetId] then
    return false
  end

  self._refCounts[assetId] = (self._refCounts[assetId] or 0) + 1
  return true
end

function AssetCache:release(assetId)
  if not self._refCounts[assetId] then
    return false
  end

  self._refCounts[assetId] = self._refCounts[assetId] - 1

  if self._refCounts[assetId] <= 0 then
    self._refCounts[assetId] = nil
  end

  return true
end

function AssetCache:getRefCount(assetId)
  return self._refCounts[assetId] or 0
end

function AssetCache:clear()
  -- Only clear non-pinned, non-referenced assets
  local toRemove = {}

  for assetId, _ in pairs(self._cache) do
    if not self._pinnedAssets[assetId] and self:getRefCount(assetId) == 0 then
      table.insert(toRemove, assetId)
    end
  end

  for _, assetId in ipairs(toRemove) do
    self:remove(assetId)
  end
end

function AssetCache:clearAll()
  self._cache = {}
  self._accessOrder = {}
  self._pinnedAssets = {}
  self._refCounts = {}
  self._bytesUsed = 0
  self._assetCount = 0
end

function AssetCache:getStats()
  local hitRate = 0
  local total = self._hits + self._misses
  if total > 0 then
    hitRate = self._hits / total
  end

  return {
    bytesUsed = self._bytesUsed,
    bytesLimit = self._bytesLimit,
    assetCount = self._assetCount,
    hits = self._hits,
    misses = self._misses,
    hitRate = hitRate,
    pinnedCount = self:_countPinned()
  }
end

function AssetCache:setMemoryBudget(bytes)
  self._bytesLimit = bytes

  -- Evict if over new budget
  while self._bytesUsed > self._bytesLimit and self._assetCount > 0 do
    local evicted = self:_evictOne()
    if not evicted then
      break
    end
  end
end

function AssetCache:_touchAccess(assetId)
  self:_removeFromAccessOrder(assetId)
  table.insert(self._accessOrder, assetId)

  local entry = self._cache[assetId]
  if entry then
    entry.accessCount = (entry.accessCount or 0) + 1
  end
end

function AssetCache:_removeFromAccessOrder(assetId)
  for i, id in ipairs(self._accessOrder) do
    if id == assetId then
      table.remove(self._accessOrder, i)
      return
    end
  end
end

function AssetCache:_evictOne()
  -- Find oldest non-pinned, non-referenced asset
  for _, assetId in ipairs(self._accessOrder) do
    if not self._pinnedAssets[assetId] and self:getRefCount(assetId) == 0 then
      return self:remove(assetId)
    end
  end

  return false
end

function AssetCache:_countPinned()
  local count = 0
  for _, _ in pairs(self._pinnedAssets) do
    count = count + 1
  end
  return count
end

return AssetCache
