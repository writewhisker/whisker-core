-- Audio Channel
-- Manages a group of audio sources with shared volume and ducking

local Types = require("whisker.media.types")

local AudioChannel = {
  _VERSION = "1.0.0"
}
AudioChannel.__index = AudioChannel
AudioChannel._dependencies = {}

function AudioChannel.new(name, config, deps)
  deps = deps or {}
  local self = setmetatable({}, AudioChannel)

  config = config or {}

  self.name = name
  self.volume = config.volume or 1.0
  self.maxConcurrent = config.maxConcurrent or 10
  self.priority = config.priority or 5
  self.ducking = config.ducking or {}

  self._sources = {}
  self._sourceCount = 0
  self._duckMultiplier = 1.0
  self._activeDucks = {}
  self._muted = false

  return self
end

function AudioChannel:addSource(sourceId, source)
  -- Enforce concurrent limit
  if self._sourceCount >= self.maxConcurrent then
    -- Evict lowest priority source
    self:_evictLowestPriority()
  end

  self._sources[sourceId] = {
    source = source,
    priority = source.priority or self.priority,
    addedAt = os.clock()
  }

  self._sourceCount = self._sourceCount + 1

  -- Apply current channel volume
  self:_updateSourceVolume(sourceId)
end

function AudioChannel:removeSource(sourceId)
  if self._sources[sourceId] then
    self._sources[sourceId] = nil
    self._sourceCount = self._sourceCount - 1
    return true
  end
  return false
end

function AudioChannel:getSource(sourceId)
  local entry = self._sources[sourceId]
  return entry and entry.source or nil
end

function AudioChannel:hasSource(sourceId)
  return self._sources[sourceId] ~= nil
end

function AudioChannel:getSourceCount()
  return self._sourceCount
end

function AudioChannel:setVolume(volume)
  self.volume = math.max(0, math.min(1, volume))
  self:_updateAllSourceVolumes()
end

function AudioChannel:getVolume()
  return self.volume
end

function AudioChannel:getEffectiveVolume()
  if self._muted then
    return 0
  end
  return self.volume * self._duckMultiplier
end

function AudioChannel:mute()
  self._muted = true
  self:_updateAllSourceVolumes()
end

function AudioChannel:unmute()
  self._muted = false
  self:_updateAllSourceVolumes()
end

function AudioChannel:isMuted()
  return self._muted
end

function AudioChannel:duck(duckingChannel, amount)
  self._activeDucks[duckingChannel] = amount
  self:_recalculateDuckMultiplier()
  self:_updateAllSourceVolumes()
end

function AudioChannel:unduck(duckingChannel)
  self._activeDucks[duckingChannel] = nil
  self:_recalculateDuckMultiplier()
  self:_updateAllSourceVolumes()
end

function AudioChannel:getDuckMultiplier()
  return self._duckMultiplier
end

function AudioChannel:stopAll(options)
  options = options or {}

  for sourceId, entry in pairs(self._sources) do
    if entry.source.stop then
      entry.source:stop()
    end
  end

  self._sources = {}
  self._sourceCount = 0
end

function AudioChannel:pauseAll()
  for sourceId, entry in pairs(self._sources) do
    if entry.source.pause then
      entry.source:pause()
    end
  end
end

function AudioChannel:resumeAll()
  for sourceId, entry in pairs(self._sources) do
    if entry.source.resume then
      entry.source:resume()
    end
  end
end

function AudioChannel:getAllSources()
  local sources = {}
  for sourceId, entry in pairs(self._sources) do
    sources[sourceId] = entry.source
  end
  return sources
end

function AudioChannel:_evictLowestPriority()
  local lowestPriority = math.huge
  local lowestSourceId = nil
  local oldestTime = math.huge

  for sourceId, entry in pairs(self._sources) do
    local shouldEvict = false

    if entry.priority < lowestPriority then
      lowestPriority = entry.priority
      lowestSourceId = sourceId
      oldestTime = entry.addedAt
      shouldEvict = true
    elseif entry.priority == lowestPriority and entry.addedAt < oldestTime then
      lowestSourceId = sourceId
      oldestTime = entry.addedAt
      shouldEvict = true
    end
  end

  if lowestSourceId then
    local entry = self._sources[lowestSourceId]
    if entry and entry.source and entry.source.stop then
      entry.source:stop()
    end
    self._sources[lowestSourceId] = nil
    self._sourceCount = self._sourceCount - 1
  end
end

function AudioChannel:_recalculateDuckMultiplier()
  -- Use the lowest duck amount from all active ducks
  self._duckMultiplier = 1.0

  for channel, amount in pairs(self._activeDucks) do
    if amount < self._duckMultiplier then
      self._duckMultiplier = amount
    end
  end
end

function AudioChannel:_updateAllSourceVolumes()
  for sourceId, _ in pairs(self._sources) do
    self:_updateSourceVolume(sourceId)
  end
end

function AudioChannel:_updateSourceVolume(sourceId)
  local entry = self._sources[sourceId]
  if not entry then return end

  local source = entry.source
  if source.updateVolume then
    source.updateVolume(self:getEffectiveVolume())
  elseif source.setVolume then
    local baseVolume = source.baseVolume or source.volume or 1.0
    source:setVolume(baseVolume * self:getEffectiveVolume())
  end
end

return AudioChannel
