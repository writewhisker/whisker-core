-- Mobile Bundler
-- Bundles assets for iOS and Android platforms

local BundlingStrategy = require("whisker.media.bundlers.BundlingStrategy")

local MobileBundler = setmetatable({}, {__index = BundlingStrategy})
MobileBundler.__index = MobileBundler

function MobileBundler.new()
  local self = setmetatable({}, MobileBundler)
  return self
end

function MobileBundler:bundle(assets, config)
  config = config or {}

  local platform = config.platform or "ios"
  local outputPath = config.outputPath or ("export/" .. platform)
  local formats = config.formats or self:_getPlatformFormats(platform)

  local bundledAssets = {}
  local errors = {}

  self:_createPlatformDirectories(outputPath, platform)

  for _, assetConfig in ipairs(assets) do
    local supportedFormats = formats[assetConfig.type] or {}
    local selectedSources = self:selectSources(assetConfig, supportedFormats)

    for _, source in ipairs(selectedSources) do
      local destPath = self:_getPlatformAssetPath(outputPath, platform, assetConfig.id, source.format, source.density)
      local success, err = self:copyAsset(source.path, destPath, {})

      if success then
        table.insert(bundledAssets, {
          id = assetConfig.id,
          type = assetConfig.type,
          path = self:_getRelativePlatformPath(platform, assetConfig.id, source.format, source.density),
          metadata = assetConfig.metadata
        })
      else
        table.insert(errors, {
          assetId = assetConfig.id,
          source = source.path,
          error = err
        })
      end
    end
  end

  local manifest = self:generateManifest(bundledAssets)

  local success = #errors == 0
  return success, manifest, errors
end

function MobileBundler:generateManifest(bundledAssets)
  return {
    version = "1.0",
    assets = bundledAssets
  }
end

function MobileBundler:_getPlatformFormats(platform)
  if platform == "ios" then
    return {
      audio = {"aac", "mp3"},
      image = {"png", "jpg"}
    }
  elseif platform == "android" then
    return {
      audio = {"mp3", "ogg"},
      image = {"png", "jpg", "webp"}
    }
  else
    return {
      audio = {"mp3"},
      image = {"png"}
    }
  end
end

function MobileBundler:_createPlatformDirectories(basePath, platform)
  if platform == "ios" then
    os.execute("mkdir -p " .. basePath .. "/Resources/assets")
  elseif platform == "android" then
    os.execute("mkdir -p " .. basePath .. "/app/src/main/assets")
  end
end

function MobileBundler:_getPlatformAssetPath(basePath, platform, assetId, format, density)
  local filename = assetId
  if density then
    filename = filename .. "_" .. density
  end
  filename = filename .. "." .. format

  if platform == "ios" then
    return basePath .. "/Resources/assets/" .. filename
  elseif platform == "android" then
    return basePath .. "/app/src/main/assets/" .. filename
  end

  return basePath .. "/assets/" .. filename
end

function MobileBundler:_getRelativePlatformPath(platform, assetId, format, density)
  local filename = assetId
  if density then
    filename = filename .. "_" .. density
  end
  filename = filename .. "." .. format

  return "assets/" .. filename
end

return MobileBundler
