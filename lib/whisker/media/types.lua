-- Media Type Definitions
-- Core types and constants for the multimedia system

local Types = {
  _VERSION = "1.0.0"
}

-- Asset Types
Types.AssetType = {
  AUDIO = "audio",
  IMAGE = "image",
  VIDEO = "video",
  FONT = "font",
  DATA = "data"
}

-- Asset States
Types.AssetState = {
  UNLOADED = "unloaded",
  LOADING = "loading",
  LOADED = "loaded",
  FAILED = "failed"
}

-- Audio Formats with priority order
Types.AudioFormat = {
  OGG = "ogg",
  MP3 = "mp3",
  WAV = "wav",
  AAC = "aac",
  M4A = "m4a",
  WEBM = "webm",
  FLAC = "flac"
}

-- Image Formats
Types.ImageFormat = {
  PNG = "png",
  JPG = "jpg",
  JPEG = "jpeg",
  WEBP = "webp",
  GIF = "gif",
  SVG = "svg",
  BMP = "bmp"
}

-- Video Formats
Types.VideoFormat = {
  MP4 = "mp4",
  WEBM = "webm",
  OGG = "ogg",
  MOV = "mov"
}

-- Default Audio Channels
Types.DefaultChannels = {
  MUSIC = {
    name = "MUSIC",
    maxConcurrent = 1,
    priority = 10,
    volume = 1.0,
    ducking = {}
  },
  AMBIENT = {
    name = "AMBIENT",
    maxConcurrent = 5,
    priority = 5,
    volume = 1.0,
    ducking = {}
  },
  SFX = {
    name = "SFX",
    maxConcurrent = 10,
    priority = 8,
    volume = 1.0,
    ducking = {}
  },
  VOICE = {
    name = "VOICE",
    maxConcurrent = 2,
    priority = 20,
    volume = 1.0,
    ducking = {
      MUSIC = 0.3,
      AMBIENT = 0.4,
      SFX = 0.7
    }
  }
}

-- Image Fit Modes
Types.FitMode = {
  CONTAIN = "contain",
  COVER = "cover",
  FILL = "fill",
  NONE = "none"
}

-- Platform identifiers
Types.Platform = {
  LOVE2D = "love2d",
  WEB = "web",
  LUA = "lua",
  DUMMY = "dummy"
}

-- Cache eviction strategies
Types.EvictionStrategy = {
  LRU = "lru",
  LFU = "lfu",
  FIFO = "fifo"
}

-- Preload priority levels
Types.PreloadPriority = {
  LOW = "low",
  NORMAL = "normal",
  HIGH = "high"
}

-- Helper function to validate asset type
function Types.isValidAssetType(assetType)
  for _, v in pairs(Types.AssetType) do
    if v == assetType then
      return true
    end
  end
  return false
end

-- Helper to get format category
-- Note: Some formats (webm, ogg) can be audio or video - we check audio-only formats first
function Types.getFormatCategory(format)
  format = format:lower()

  -- Audio-only formats (not shared with video)
  local audioOnly = {mp3 = true, wav = true, aac = true, m4a = true, flac = true}
  if audioOnly[format] then
    return Types.AssetType.AUDIO
  end

  -- Video formats (including shared formats like webm, ogg)
  for _, f in pairs(Types.VideoFormat) do
    if f == format then return Types.AssetType.VIDEO end
  end

  -- Image formats
  for _, f in pairs(Types.ImageFormat) do
    if f == format then return Types.AssetType.IMAGE end
  end

  -- Remaining audio formats
  for _, f in pairs(Types.AudioFormat) do
    if f == format then return Types.AssetType.AUDIO end
  end

  return nil
end

return Types
