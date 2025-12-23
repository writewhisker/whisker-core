-- Format Detector
-- Detects supported audio and image formats for the current platform

local Types = require("whisker.media.types")

local FormatDetector = {
  _VERSION = "1.0.0",
  _detected = nil,
  _platform = nil
}

function FormatDetector:detectPlatform()
  if self._platform then
    return self._platform
  end

  if love and love.audio then
    self._platform = Types.Platform.LOVE2D
  elseif _G.js or _G.document then
    self._platform = Types.Platform.WEB
  else
    self._platform = Types.Platform.LUA
  end

  return self._platform
end

function FormatDetector:detectLOVEFormats()
  return {
    audio = {"ogg", "mp3", "wav", "flac"},
    image = {"png", "jpg", "jpeg", "bmp", "gif"}
  }
end

function FormatDetector:detectWebFormats()
  return {
    audio = {"mp3", "ogg", "wav", "m4a", "webm"},
    image = {"png", "jpg", "jpeg", "gif", "webp", "svg"}
  }
end

function FormatDetector:detectLuaFormats()
  return {
    audio = {"mp3", "ogg", "wav", "flac", "m4a", "aac"},
    image = {"png", "jpg", "jpeg", "gif", "webp", "bmp"}
  }
end

function FormatDetector:detectFormats()
  if self._detected then
    return self._detected
  end

  local platform = self:detectPlatform()

  if platform == Types.Platform.LOVE2D then
    self._detected = self:detectLOVEFormats()
  elseif platform == Types.Platform.WEB then
    self._detected = self:detectWebFormats()
  else
    self._detected = self:detectLuaFormats()
  end

  return self._detected
end

function FormatDetector:isFormatSupported(format, assetType)
  local supported = self:detectFormats()
  format = format:lower()

  local formatList = supported[assetType]
  if not formatList then
    return false
  end

  for _, f in ipairs(formatList) do
    if f == format then
      return true
    end
  end

  return false
end

function FormatDetector:selectBestFormat(sources, assetType)
  local supported = self:detectFormats()
  local formatList = supported[assetType]

  if not formatList or not sources then
    return nil
  end

  local audioPriority = {"ogg", "mp3", "wav", "m4a", "webm", "flac", "aac"}
  local imagePriority = {"webp", "png", "jpg", "jpeg", "gif", "svg", "bmp"}

  local priority = assetType == "audio" and audioPriority or imagePriority

  local available = {}
  for _, source in ipairs(sources) do
    local format = source.format:lower()
    available[format] = source
  end

  for _, format in ipairs(priority) do
    if available[format] and self:isFormatSupported(format, assetType) then
      return available[format]
    end
  end

  for _, source in ipairs(sources) do
    if self:isFormatSupported(source.format, assetType) then
      return source
    end
  end

  return nil
end

function FormatDetector:getFormatFromPath(path)
  local ext = path:match("%.([^%.]+)$")
  return ext and ext:lower() or nil
end

function FormatDetector:getAssetTypeFromFormat(format)
  return Types.getFormatCategory(format)
end

function FormatDetector:reset()
  self._detected = nil
  self._platform = nil
end

return FormatDetector
