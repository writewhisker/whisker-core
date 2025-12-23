-- AudioBackend Interface
-- Abstract base class for audio playback backends

local AudioBackend = {
  _VERSION = "1.0.0"
}
AudioBackend.__index = AudioBackend

function AudioBackend.new()
  local self = setmetatable({}, AudioBackend)
  return self
end

-- Initialize the audio backend
-- @return success (boolean)
function AudioBackend:initialize()
  error("AudioBackend:initialize() must be implemented by subclass")
end

-- Create an audio source from asset data
-- @param assetData - The loaded asset data
-- @param options - Creation options {streaming, etc}
-- @return source - The audio source object
function AudioBackend:createSource(assetData, options)
  error("AudioBackend:createSource() must be implemented by subclass")
end

-- Play an audio source
-- @param source - The audio source
-- @param options - Playback options {loop, volume, etc}
-- @return success (boolean)
function AudioBackend:play(source, options)
  error("AudioBackend:play() must be implemented by subclass")
end

-- Stop an audio source
-- @param source - The audio source
-- @return success (boolean)
function AudioBackend:stop(source)
  error("AudioBackend:stop() must be implemented by subclass")
end

-- Pause an audio source
-- @param source - The audio source
-- @return success (boolean)
function AudioBackend:pause(source)
  error("AudioBackend:pause() must be implemented by subclass")
end

-- Resume a paused audio source
-- @param source - The audio source
-- @return success (boolean)
function AudioBackend:resume(source)
  error("AudioBackend:resume() must be implemented by subclass")
end

-- Set volume for an audio source
-- @param source - The audio source
-- @param volume - Volume level (0.0 to 1.0)
-- @return success (boolean)
function AudioBackend:setVolume(source, volume)
  error("AudioBackend:setVolume() must be implemented by subclass")
end

-- Get volume for an audio source
-- @param source - The audio source
-- @return volume (number)
function AudioBackend:getVolume(source)
  error("AudioBackend:getVolume() must be implemented by subclass")
end

-- Set looping for an audio source
-- @param source - The audio source
-- @param loop - Whether to loop (boolean)
-- @return success (boolean)
function AudioBackend:setLooping(source, loop)
  error("AudioBackend:setLooping() must be implemented by subclass")
end

-- Check if source is playing
-- @param source - The audio source
-- @return isPlaying (boolean)
function AudioBackend:isPlaying(source)
  error("AudioBackend:isPlaying() must be implemented by subclass")
end

-- Check if source is paused
-- @param source - The audio source
-- @return isPaused (boolean)
function AudioBackend:isPaused(source)
  error("AudioBackend:isPaused() must be implemented by subclass")
end

-- Get playback position
-- @param source - The audio source
-- @return position (number) - Position in seconds
function AudioBackend:getPosition(source)
  error("AudioBackend:getPosition() must be implemented by subclass")
end

-- Set playback position
-- @param source - The audio source
-- @param position - Position in seconds
-- @return success (boolean)
function AudioBackend:setPosition(source, position)
  error("AudioBackend:setPosition() must be implemented by subclass")
end

-- Get duration of audio source
-- @param source - The audio source
-- @return duration (number) - Duration in seconds
function AudioBackend:getDuration(source)
  error("AudioBackend:getDuration() must be implemented by subclass")
end

-- Update method called each frame
-- @param dt - Delta time in seconds
function AudioBackend:update(dt)
  -- Optional: subclasses may override
end

-- Cleanup and release resources
function AudioBackend:shutdown()
  -- Optional: subclasses may override
end

return AudioBackend
