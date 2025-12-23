-- Audio Backend Selector
-- Automatically selects the appropriate audio backend

local Types = require("whisker.media.types")
local FormatDetector = require("whisker.media.FormatDetector")

local Backends = {
  _VERSION = "1.0.0"
}

function Backends.selectBackend()
  local platform = FormatDetector:detectPlatform()

  if platform == Types.Platform.LOVE2D then
    local LOVEAudioBackend = require("whisker.media.backends.LOVEAudioBackend")
    return LOVEAudioBackend.new()
  else
    local DummyAudioBackend = require("whisker.media.backends.DummyAudioBackend")
    return DummyAudioBackend.new()
  end
end

function Backends.getDummyBackend()
  local DummyAudioBackend = require("whisker.media.backends.DummyAudioBackend")
  return DummyAudioBackend.new()
end

function Backends.getLOVEBackend()
  local LOVEAudioBackend = require("whisker.media.backends.LOVEAudioBackend")
  return LOVEAudioBackend.new()
end

return Backends
