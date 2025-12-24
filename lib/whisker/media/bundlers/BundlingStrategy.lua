-- Bundling Strategy Interface
-- Base class for platform-specific asset bundling

local BundlingStrategy = {
  _VERSION = "1.0.0"
}
BundlingStrategy.__index = BundlingStrategy

-- Dependencies for DI pattern
BundlingStrategy._dependencies = {"file_system", "event_bus"}

--- Create a new BundlingStrategy instance via DI container
-- @param deps table Dependencies from container (file_system, event_bus)
-- @return function Factory function that creates BundlingStrategy instances
function BundlingStrategy.create(deps)
  return function(config)
    return BundlingStrategy.new(config, deps)
  end
end

--- Create a new BundlingStrategy instance
-- @param config table|nil Configuration options
-- @param deps table|nil Dependencies from container
-- @return BundlingStrategy The new strategy instance
function BundlingStrategy.new(config, deps)
  local self = setmetatable({}, BundlingStrategy)

  config = config or {}
  deps = deps or {}

  -- Store dependencies
  self._file_system = deps.file_system
  self._event_bus = deps.event_bus

  return self
end

-- Bundle assets for the target platform
-- @param assets (table) Array of asset configurations
-- @param config (table) Bundling configuration
-- @return success (boolean)
-- @return manifest (table) Generated asset manifest
-- @return errors (table) Array of errors encountered
function BundlingStrategy:bundle(assets, config)
  error("BundlingStrategy:bundle() must be implemented by subclass")
end

-- Generate asset manifest
-- @param assets (table) Bundled assets with paths
-- @return manifest (table) Manifest data structure
function BundlingStrategy:generateManifest(assets)
  error("BundlingStrategy:generateManifest() must be implemented by subclass")
end

-- Copy asset file to output directory
-- @param sourcePath (string) Source asset path
-- @param destPath (string) Destination path
-- @param options (table) Copy options
-- @return success (boolean)
-- @return error (string or nil)
function BundlingStrategy:copyAsset(sourcePath, destPath, options)
  -- Use injected file system if available
  if self._file_system then
    return self._file_system:copy(sourcePath, destPath, options)
  end

  -- Fallback to native io
  local sourceFile = io.open(sourcePath, "rb")
  if not sourceFile then
    return false, "Cannot open source: " .. sourcePath
  end

  local content = sourceFile:read("*all")
  sourceFile:close()

  -- Create destination directory if needed
  local destDir = destPath:match("(.+)/[^/]+$")
  if destDir then
    os.execute("mkdir -p " .. destDir)
  end

  local destFile = io.open(destPath, "wb")
  if not destFile then
    return false, "Cannot open destination: " .. destPath
  end

  destFile:write(content)
  destFile:close()

  return true, nil
end

-- Get file size
-- @param path (string) File path
-- @return size (number) Size in bytes
function BundlingStrategy:getFileSize(path)
  -- Use injected file system if available
  if self._file_system and self._file_system.getSize then
    return self._file_system:getSize(path)
  end

  -- Fallback to native io
  local file = io.open(path, "rb")
  if not file then return 0 end

  local size = file:seek("end")
  file:close()

  return size or 0
end

-- Check if format is in supported list
-- @param format (string) Format to check
-- @param supportedFormats (table) Array of supported formats
-- @return supported (boolean)
function BundlingStrategy:isFormatSupported(format, supportedFormats)
  for _, supported in ipairs(supportedFormats) do
    if format == supported then
      return true
    end
  end
  return false
end

-- Select sources from asset config based on supported formats
-- @param assetConfig (table) Asset configuration
-- @param supportedFormats (table) Array of supported formats
-- @return selected (table) Array of selected sources
function BundlingStrategy:selectSources(assetConfig, supportedFormats)
  local selected = {}

  if assetConfig.sources then
    for _, source in ipairs(assetConfig.sources) do
      if self:isFormatSupported(source.format, supportedFormats) then
        table.insert(selected, source)
      end
    end
  end

  if assetConfig.variants then
    for _, variant in ipairs(assetConfig.variants) do
      local format = variant.path:match("%.([^%.]+)$")
      if format and self:isFormatSupported(format:lower(), supportedFormats) then
        table.insert(selected, {
          path = variant.path,
          format = format:lower(),
          density = variant.density
        })
      end
    end
  end

  return selected
end

return BundlingStrategy
