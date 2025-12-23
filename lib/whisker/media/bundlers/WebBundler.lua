-- Web Bundler
-- Bundles assets for web deployment with manifest and separate files

local BundlingStrategy = require("whisker.media.bundlers.BundlingStrategy")

local WebBundler = setmetatable({}, {__index = BundlingStrategy})
WebBundler.__index = WebBundler

function WebBundler.new()
  local self = setmetatable({}, WebBundler)
  return self
end

function WebBundler:bundle(assets, config)
  config = config or {}

  local outputPath = config.outputPath or "export/web"
  local compress = config.compress ~= false
  local embedLimit = config.embedLimit or 10240
  local formats = config.formats or {
    audio = {"mp3", "ogg"},
    image = {"webp", "png", "jpg"}
  }

  local bundledAssets = {}
  local errors = {}

  -- Create output directories
  self:_createDirectories(outputPath)

  -- Process each asset
  for _, assetConfig in ipairs(assets) do
    local assetType = assetConfig.type
    local supportedFormats = formats[assetType] or {}
    local selectedSources = self:selectSources(assetConfig, supportedFormats)

    for _, source in ipairs(selectedSources) do
      local sourcePath = source.path
      local fileSize = self:getFileSize(sourcePath)

      local bundledSource = {
        id = assetConfig.id,
        type = assetType,
        format = source.format,
        metadata = assetConfig.metadata
      }

      -- Embed small files as base64
      if fileSize > 0 and fileSize <= embedLimit then
        bundledSource.embedded = true
        bundledSource.data = self:_encodeBase64(sourcePath)
      else
        -- Copy to assets directory
        local destPath = self:_getAssetPath(outputPath, assetConfig.id, source.format, source.density)
        local success, err = self:copyAsset(sourcePath, destPath, {compress = compress})

        if success then
          bundledSource.url = self:_getAssetURL(assetConfig.id, source.format, source.density)
        else
          table.insert(errors, {
            assetId = assetConfig.id,
            source = source.path,
            error = err
          })
        end
      end

      table.insert(bundledAssets, bundledSource)
    end
  end

  -- Generate manifest
  local manifest = self:generateManifest(bundledAssets)

  -- Write manifest.json
  local manifestPath = outputPath .. "/assets/manifest.json"
  self:_writeJSON(manifestPath, manifest)

  local success = #errors == 0
  return success, manifest, errors
end

function WebBundler:generateManifest(bundledAssets)
  local manifest = {
    version = "1.0",
    generator = "whisker-core",
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    assets = {}
  }

  for _, asset in ipairs(bundledAssets) do
    table.insert(manifest.assets, {
      id = asset.id,
      type = asset.type,
      format = asset.format,
      url = asset.url,
      embedded = asset.embedded,
      data = asset.data,
      metadata = asset.metadata
    })
  end

  return manifest
end

function WebBundler:_createDirectories(basePath)
  local paths = {
    basePath .. "/assets",
    basePath .. "/assets/audio",
    basePath .. "/assets/images"
  }

  for _, path in ipairs(paths) do
    os.execute("mkdir -p " .. path)
  end
end

function WebBundler:_getAssetPath(basePath, assetId, format, density)
  local subdir = (format == "mp3" or format == "ogg" or format == "wav") and "audio" or "images"
  local filename = assetId
  if density then
    filename = filename .. "_" .. density
  end
  filename = filename .. "." .. format

  return basePath .. "/assets/" .. subdir .. "/" .. filename
end

function WebBundler:_getAssetURL(assetId, format, density)
  local subdir = (format == "mp3" or format == "ogg" or format == "wav") and "audio" or "images"
  local filename = assetId
  if density then
    filename = filename .. "_" .. density
  end
  filename = filename .. "." .. format

  return "assets/" .. subdir .. "/" .. filename
end

function WebBundler:_encodeBase64(path)
  local file = io.open(path, "rb")
  if not file then return nil end

  local content = file:read("*all")
  file:close()

  -- Simple base64 encoding
  local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  local result = {}

  local i = 1
  while i <= #content do
    local b1 = content:byte(i) or 0
    local b2 = content:byte(i + 1) or 0
    local b3 = content:byte(i + 2) or 0

    local n = b1 * 65536 + b2 * 256 + b3

    table.insert(result, b64chars:sub(math.floor(n / 262144) % 64 + 1, math.floor(n / 262144) % 64 + 1))
    table.insert(result, b64chars:sub(math.floor(n / 4096) % 64 + 1, math.floor(n / 4096) % 64 + 1))

    if i + 1 <= #content then
      table.insert(result, b64chars:sub(math.floor(n / 64) % 64 + 1, math.floor(n / 64) % 64 + 1))
    else
      table.insert(result, "=")
    end

    if i + 2 <= #content then
      table.insert(result, b64chars:sub(n % 64 + 1, n % 64 + 1))
    else
      table.insert(result, "=")
    end

    i = i + 3
  end

  return table.concat(result)
end

function WebBundler:_writeJSON(path, data)
  local file = io.open(path, "w")
  if not file then
    return false
  end

  file:write(self:_serializeJSON(data))
  file:close()

  return true
end

function WebBundler:_serializeJSON(value, indent)
  indent = indent or 0
  local spaces = string.rep("  ", indent)

  if type(value) == "nil" then
    return "null"
  elseif type(value) == "boolean" then
    return value and "true" or "false"
  elseif type(value) == "number" then
    return tostring(value)
  elseif type(value) == "string" then
    return '"' .. value:gsub('"', '\\"'):gsub("\n", "\\n") .. '"'
  elseif type(value) == "table" then
    -- Check if array
    local isArray = #value > 0 or next(value) == nil
    local items = {}

    if isArray then
      for _, v in ipairs(value) do
        table.insert(items, spaces .. "  " .. self:_serializeJSON(v, indent + 1))
      end
      return "[\n" .. table.concat(items, ",\n") .. "\n" .. spaces .. "]"
    else
      for k, v in pairs(value) do
        table.insert(items, spaces .. '  "' .. tostring(k) .. '": ' .. self:_serializeJSON(v, indent + 1))
      end
      return "{\n" .. table.concat(items, ",\n") .. "\n" .. spaces .. "}"
    end
  end

  return "null"
end

return WebBundler
