-- Dummy Audio Backend
-- A no-op implementation for testing and headless environments

local AudioBackend = require("whisker.media.backends.AudioBackend")

local DummyAudioBackend = setmetatable({}, {__index = AudioBackend})
DummyAudioBackend._dependencies = {}
DummyAudioBackend.__index = DummyAudioBackend

function DummyAudioBackend.new(deps)
  deps = deps or {}
  local self = setmetatable({}, DummyAudioBackend)
  self._sources = {}
  self._nextId = 1
  self._initialized = false
  return self
end

function DummyAudioBackend:initialize()
  self._initialized = true
  return true
end

function DummyAudioBackend:createSource(assetData, options)
  options = options or {}

  local sourceId = self._nextId
  self._nextId = self._nextId + 1

  local source = {
    id = sourceId,
    assetData = assetData,
    volume = 1.0,
    looping = false,
    playing = false,
    paused = false,
    position = 0,
    duration = (assetData and assetData.metadata and assetData.metadata.duration) or 60,
    startTime = nil
  }

  self._sources[sourceId] = source

  return source
end

function DummyAudioBackend:play(source, options)
  if not source then return false end

  options = options or {}

  source.playing = true
  source.paused = false
  source.startTime = os.clock()

  if options.volume then
    source.volume = options.volume
  end

  if options.loop ~= nil then
    source.looping = options.loop
  end

  return true
end

function DummyAudioBackend:stop(source)
  if not source then return false end

  source.playing = false
  source.paused = false
  source.position = 0
  source.startTime = nil

  return true
end

function DummyAudioBackend:pause(source)
  if not source then return false end

  if source.playing and not source.paused then
    source.paused = true
    source.playing = false

    -- Update position
    if source.startTime then
      source.position = source.position + (os.clock() - source.startTime)
    end
  end

  return true
end

function DummyAudioBackend:resume(source)
  if not source then return false end

  if source.paused then
    source.paused = false
    source.playing = true
    source.startTime = os.clock()
  end

  return true
end

function DummyAudioBackend:setVolume(source, volume)
  if not source then return false end

  source.volume = math.max(0, math.min(1, volume))
  return true
end

function DummyAudioBackend:getVolume(source)
  if not source then return 0 end
  return source.volume
end

function DummyAudioBackend:setLooping(source, loop)
  if not source then return false end
  source.looping = loop
  return true
end

function DummyAudioBackend:isPlaying(source)
  if not source then return false end
  return source.playing and not source.paused
end

function DummyAudioBackend:isPaused(source)
  if not source then return false end
  return source.paused
end

function DummyAudioBackend:getPosition(source)
  if not source then return 0 end

  if source.playing and source.startTime then
    return source.position + (os.clock() - source.startTime)
  end

  return source.position
end

function DummyAudioBackend:setPosition(source, position)
  if not source then return false end

  source.position = math.max(0, position)
  if source.playing then
    source.startTime = os.clock()
  end

  return true
end

function DummyAudioBackend:getDuration(source)
  if not source then return 0 end
  return source.duration
end

function DummyAudioBackend:update(dt)
  -- Check for sources that have finished playing
  for id, source in pairs(self._sources) do
    if source.playing and not source.paused then
      local currentPos = self:getPosition(source)

      if currentPos >= source.duration then
        if source.looping then
          source.position = 0
          source.startTime = os.clock()
        else
          source.playing = false
          source.position = 0
        end
      end
    end
  end
end

function DummyAudioBackend:shutdown()
  self._sources = {}
  self._initialized = false
end

-- Get all active sources (for testing)
function DummyAudioBackend:getActiveSources()
  local active = {}
  for id, source in pairs(self._sources) do
    if source.playing then
      table.insert(active, source)
    end
  end
  return active
end

-- Get source by ID (for testing)
function DummyAudioBackend:getSource(sourceId)
  return self._sources[sourceId]
end

return DummyAudioBackend
