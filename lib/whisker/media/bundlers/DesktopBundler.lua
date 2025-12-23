-- Desktop Bundler
-- Bundles assets for desktop deployment

local BundlingStrategy = require("whisker.media.bundlers.BundlingStrategy")

local DesktopBundler = setmetatable({}, {__index = BundlingStrategy})
DesktopBundler.__index = DesktopBundler

function DesktopBundler.new()
  local self = setmetatable({}, DesktopBundler)
  return self
end

function DesktopBundler:bundle(assets, config)
  config = config or {}

  local outputPath = config.outputPath or "export/desktop"
  local strategy = config.strategy or "external"
  local formats = config.formats or {
    audio = {"ogg", "mp3"},
    image = {"png", "jpg"}
  }

  local bundledAssets = {}
  local errors = {}

  if strategy == "external" then
    self:_createDirectories(outputPath)

    for _, assetConfig in ipairs(assets) do
      local supportedFormats = formats[assetConfig.type] or {}
      local selectedSources = self:selectSources(assetConfig, supportedFormats)

      for _, source in ipairs(selectedSources) do
        local destPath = self:_getAssetPath(outputPath, assetConfig.id, source.format, source.density)
        local success, err = self:copyAsset(source.path, destPath, {})

        if success then
          table.insert(bundledAssets, {
            id = assetConfig.id,
            type = assetConfig.type,
            path = self:_getRelativePath(assetConfig.id, source.format, source.density),
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
  end

  local manifest = self:generateManifest(bundledAssets)

  -- Write manifest
  local manifestPath = outputPath .. "/game_data/assets/manifest.lua"
  self:_writeManifest(manifestPath, manifest)

  local success = #errors == 0
  return success, manifest, errors
end

function DesktopBundler:generateManifest(bundledAssets)
  return {
    version = "1.0",
    platform = "desktop",
    assets = bundledAssets
  }
end

function DesktopBundler:_createDirectories(basePath)
  os.execute("mkdir -p " .. basePath .. "/game_data/assets/audio")
  os.execute("mkdir -p " .. basePath .. "/game_data/assets/images")
end

function DesktopBundler:_getAssetPath(basePath, assetId, format, density)
  local subdir = (format == "mp3" or format == "ogg" or format == "wav") and "audio" or "images"
  local filename = assetId
  if density then
    filename = filename .. "_" .. density
  end
  filename = filename .. "." .. format

  return basePath .. "/game_data/assets/" .. subdir .. "/" .. filename
end

function DesktopBundler:_getRelativePath(assetId, format, density)
  local subdir = (format == "mp3" or format == "ogg" or format == "wav") and "audio" or "images"
  local filename = assetId
  if density then
    filename = filename .. "_" .. density
  end
  filename = filename .. "." .. format

  return "game_data/assets/" .. subdir .. "/" .. filename
end

function DesktopBundler:_writeManifest(path, manifest)
  local file = io.open(path, "w")
  if not file then return false end

  file:write("-- Asset Manifest (auto-generated)\n")
  file:write("return {\n")
  file:write("  version = \"" .. manifest.version .. "\",\n")
  file:write("  platform = \"" .. manifest.platform .. "\",\n")
  file:write("  assets = {\n")

  for _, asset in ipairs(manifest.assets) do
    file:write("    {\n")
    file:write("      id = \"" .. asset.id .. "\",\n")
    file:write("      type = \"" .. asset.type .. "\",\n")
    file:write("      path = \"" .. asset.path .. "\",\n")
    file:write("    },\n")
  end

  file:write("  }\n")
  file:write("}\n")

  file:close()
  return true
end

return DesktopBundler
