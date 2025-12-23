-- Whisker Media System
-- Phase F: Multimedia and Asset Management
-- Main entry point for the media module

local Media = {
  _VERSION = "1.0.0",
  _DESCRIPTION = "Whisker multimedia and asset management system"
}

-- Lazy-load submodules to avoid circular dependencies
local submodules = {
  "AssetManager",
  "AssetLoader",
  "AssetCache",
  "FormatDetector",
  "AudioManager",
  "AudioChannel",
  "ImageManager",
  "PreloadManager"
}

for _, name in ipairs(submodules) do
  Media[name] = setmetatable({}, {
    __index = function(t, k)
      local mod = require("whisker.media." .. name)
      for key, val in pairs(mod) do
        t[key] = val
      end
      return t[k]
    end
  })
end

return Media
