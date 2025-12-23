-- LOVE2D Audio Backend
-- Audio playback using LOVE2D's audio system

local AudioBackend = require("whisker.media.backends.AudioBackend")

local LOVEAudioBackend = setmetatable({}, {__index = AudioBackend})
LOVEAudioBackend.__index = LOVEAudioBackend

function LOVEAudioBackend.new()
  local self = setmetatable({}, LOVEAudioBackend)
  self._sources = {}
  self._nextId = 1
  self._initialized = false
  return self
end

function LOVEAudioBackend:initialize()
  if not love or not love.audio then
    return false
  end

  self._initialized = true
  return true
end

function LOVEAudioBackend:createSource(assetData, options)
  if not self._initialized then
    return nil
  end

  options = options or {}

  local loveSource

  -- Check if assetData is already a LOVE source
  if type(assetData) == "userdata" then
    loveSource = assetData
  elseif assetData and assetData.data and type(assetData.data) == "userdata" then
    loveSource = assetData.data
  elseif assetData and assetData.path then
    -- Load from path
    local success, result = pcall(function()
      local sourceType = options.streaming and "stream" or "static"
      return love.audio.newSource(assetData.path, sourceType)
    end)

    if success then
      loveSource = result
    else
      return nil
    end
  else
    return nil
  end

  local sourceId = self._nextId
  self._nextId = self._nextId + 1

  local source = {
    id = sourceId,
    loveSource = loveSource,
    volume = 1.0,
    baseVolume = 1.0
  }

  self._sources[sourceId] = source

  return source
end

function LOVEAudioBackend:play(source, options)
  if not source or not source.loveSource then
    return false
  end

  options = options or {}

  if options.volume then
    source.baseVolume = options.volume
    source.loveSource:setVolume(options.volume)
  end

  if options.loop ~= nil then
    source.loveSource:setLooping(options.loop)
  end

  local success = pcall(function()
    love.audio.play(source.loveSource)
  end)

  return success
end

function LOVEAudioBackend:stop(source)
  if not source or not source.loveSource then
    return false
  end

  local success = pcall(function()
    source.loveSource:stop()
  end)

  return success
end

function LOVEAudioBackend:pause(source)
  if not source or not source.loveSource then
    return false
  end

  local success = pcall(function()
    source.loveSource:pause()
  end)

  return success
end

function LOVEAudioBackend:resume(source)
  if not source or not source.loveSource then
    return false
  end

  local success = pcall(function()
    love.audio.play(source.loveSource)
  end)

  return success
end

function LOVEAudioBackend:setVolume(source, volume)
  if not source or not source.loveSource then
    return false
  end

  volume = math.max(0, math.min(1, volume))
  source.volume = volume

  local success = pcall(function()
    source.loveSource:setVolume(volume * source.baseVolume)
  end)

  return success
end

function LOVEAudioBackend:getVolume(source)
  if not source or not source.loveSource then
    return 0
  end

  local success, volume = pcall(function()
    return source.loveSource:getVolume()
  end)

  return success and volume or 0
end

function LOVEAudioBackend:setLooping(source, loop)
  if not source or not source.loveSource then
    return false
  end

  local success = pcall(function()
    source.loveSource:setLooping(loop)
  end)

  return success
end

function LOVEAudioBackend:isPlaying(source)
  if not source or not source.loveSource then
    return false
  end

  local success, playing = pcall(function()
    return source.loveSource:isPlaying()
  end)

  return success and playing or false
end

function LOVEAudioBackend:isPaused(source)
  if not source or not source.loveSource then
    return false
  end

  -- LOVE doesn't have isPaused, check if not playing but has position > 0
  local success, result = pcall(function()
    return not source.loveSource:isPlaying() and source.loveSource:tell() > 0
  end)

  return success and result or false
end

function LOVEAudioBackend:getPosition(source)
  if not source or not source.loveSource then
    return 0
  end

  local success, position = pcall(function()
    return source.loveSource:tell()
  end)

  return success and position or 0
end

function LOVEAudioBackend:setPosition(source, position)
  if not source or not source.loveSource then
    return false
  end

  local success = pcall(function()
    source.loveSource:seek(position)
  end)

  return success
end

function LOVEAudioBackend:getDuration(source)
  if not source or not source.loveSource then
    return 0
  end

  local success, duration = pcall(function()
    return source.loveSource:getDuration()
  end)

  return success and duration or 0
end

function LOVEAudioBackend:update(dt)
  -- LOVE handles its own audio updates
end

function LOVEAudioBackend:shutdown()
  -- Stop all sources
  for id, source in pairs(self._sources) do
    if source.loveSource then
      pcall(function()
        source.loveSource:stop()
      end)
    end
  end

  self._sources = {}
  self._initialized = false
end

return LOVEAudioBackend
