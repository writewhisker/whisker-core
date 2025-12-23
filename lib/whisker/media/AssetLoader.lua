-- Asset Loader
-- Handles async and sync loading of assets

local Types = require("whisker.media.types")
local FormatDetector = require("whisker.media.FormatDetector")

local AssetLoader = {
  _VERSION = "1.0.0"
}
AssetLoader.__index = AssetLoader

function AssetLoader.new(config)
  local self = setmetatable({}, AssetLoader)

  config = config or {}

  self._loading = {}
  self._callbacks = {}
  self._basePath = config.basePath or ""

  return self
end

function AssetLoader:load(assetConfig, callback)
  local assetId = assetConfig.id

  -- Already loading?
  if self._loading[assetId] then
    if callback then
      table.insert(self._callbacks[assetId], callback)
    end
    return true
  end

  -- Mark as loading
  self._loading[assetId] = true
  self._callbacks[assetId] = callback and {callback} or {}

  -- Select best source
  local source
  if assetConfig.type == "audio" then
    source = FormatDetector:selectBestFormat(assetConfig.sources, "audio")
  elseif assetConfig.type == "image" then
    source = self:_selectImageVariant(assetConfig.variants)
  else
    source = assetConfig.sources and assetConfig.sources[1]
  end

  if not source then
    self:_handleLoadComplete(assetId, nil, {
      type = "format",
      message = "No supported format found for asset: " .. assetId
    })
    return false
  end

  -- Load the asset
  local path = source.path
  if self._basePath ~= "" and not path:match("^/") and not path:match("^%a:") then
    path = self._basePath .. "/" .. path
  end

  local data, err = self:_loadFile(path, assetConfig.type)

  if data then
    local asset = {
      id = assetId,
      type = assetConfig.type,
      data = data,
      path = path,
      format = source.format,
      metadata = assetConfig.metadata or {},
      sizeBytes = self:_estimateSize(data, assetConfig.type)
    }
    self:_handleLoadComplete(assetId, asset, nil)
  else
    self:_handleLoadComplete(assetId, nil, {
      type = "load",
      message = err or "Failed to load asset"
    })
  end

  return true
end

function AssetLoader:loadSync(assetConfig, timeout)
  local result = nil
  local error = nil
  local done = false

  self:load(assetConfig, function(asset, err)
    result = asset
    error = err
    done = true
  end)

  -- In Lua, this is effectively synchronous anyway
  -- For LOVE2D async, would need coroutine handling

  return result, error
end

function AssetLoader:cancel(assetId)
  if not self._loading[assetId] then
    return false
  end

  self._loading[assetId] = nil
  self._callbacks[assetId] = nil

  return true
end

function AssetLoader:isLoading(assetId)
  return self._loading[assetId] == true
end

function AssetLoader:_loadFile(path, assetType)
  -- Platform detection
  local platform = FormatDetector:detectPlatform()

  if platform == Types.Platform.LOVE2D then
    return self:_loadLOVE(path, assetType)
  else
    return self:_loadGeneric(path, assetType)
  end
end

function AssetLoader:_loadLOVE(path, assetType)
  local success, result = pcall(function()
    if assetType == "audio" then
      return love.audio.newSource(path, "static")
    elseif assetType == "image" then
      return love.graphics.newImage(path)
    elseif assetType == "font" then
      return love.graphics.newFont(path)
    else
      return love.filesystem.read(path)
    end
  end)

  if success then
    return result, nil
  else
    return nil, tostring(result)
  end
end

function AssetLoader:_loadGeneric(path, assetType)
  local file, err = io.open(path, "rb")

  if not file then
    return nil, "Failed to open file: " .. (err or path)
  end

  local content = file:read("*all")
  file:close()

  if not content then
    return nil, "Failed to read file content"
  end

  return {
    raw = content,
    path = path,
    size = #content
  }, nil
end

function AssetLoader:_selectImageVariant(variants)
  if not variants or #variants == 0 then
    return nil
  end

  -- Prefer 1x density for now, could be enhanced with device detection
  for _, variant in ipairs(variants) do
    if variant.density == "1x" then
      return variant
    end
  end

  return variants[1]
end

function AssetLoader:_handleLoadComplete(assetId, asset, error)
  local callbacks = self._callbacks[assetId] or {}

  self._loading[assetId] = nil
  self._callbacks[assetId] = nil

  for _, callback in ipairs(callbacks) do
    callback(asset, error)
  end
end

function AssetLoader:_estimateSize(data, assetType)
  if type(data) == "table" then
    if data.size then return data.size end
    if data.raw then return #data.raw end
  end

  if type(data) == "string" then
    return #data
  end

  -- Rough estimates for platform-specific objects
  if assetType == "audio" then
    return 1024 * 1024 -- 1MB estimate
  elseif assetType == "image" then
    return 256 * 1024 -- 256KB estimate
  end

  return 0
end

return AssetLoader
