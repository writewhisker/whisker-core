-- Audio Manager
-- High-level audio playback with channels, crossfading, and ducking

local Types = require("whisker.media.types")

local AudioManager = {
  _VERSION = "1.0.0"
}
AudioManager.__index = AudioManager

-- Dependencies for DI pattern
AudioManager._dependencies = {"audio_backend", "asset_manager", "event_bus"}

-- Cached dependencies for backward compatibility (lazy loaded)
local _audio_channel_cache = nil
local _asset_manager_cache = nil

--- Get AudioChannel class (supports both DI and backward compatibility)
local function get_audio_channel(deps)
  if deps and deps.audio_channel then
    return deps.audio_channel
  end
  if not _audio_channel_cache then
    _audio_channel_cache = require("whisker.media.AudioChannel")
  end
  return _audio_channel_cache
end

--- Get the asset manager (supports both DI and backward compatibility)
local function get_asset_manager(deps)
  if deps and deps.asset_manager then
    return deps.asset_manager
  end
  if not _asset_manager_cache then
    _asset_manager_cache = require("whisker.media.AssetManager")
  end
  return _asset_manager_cache
end

--- Create a new AudioManager instance via DI container
-- @param deps table Dependencies from container (audio_backend, asset_manager, event_bus)
-- @return function Factory function that creates AudioManager instances
function AudioManager.create(deps)
  return function(config)
    return AudioManager.new(config, deps)
  end
end

--- Create a new AudioManager instance
-- @param config table|nil Configuration options
-- @param deps table|nil Dependencies from container
-- @return AudioManager The new manager instance
function AudioManager.new(config, deps)
  local self = setmetatable({}, AudioManager)

  config = config or {}
  deps = deps or {}

  -- Store dependencies
  self._event_bus = deps.event_bus
  self._audio_backend = deps.audio_backend
  self._asset_manager = get_asset_manager(deps)
  self._audio_channel_class = get_audio_channel(deps)

  self._backend = nil
  self._channels = {}
  self._sources = {}
  self._nextSourceId = 1
  self._masterVolume = config.masterVolume or 1.0
  self._crossfades = {}
  self._fades = {}
  self._initialized = false

  return self
end

-- Legacy singleton-style initialize (for backward compatibility)
function AudioManager:initialize(backend, config)
  config = config or {}

  self._backend = backend or self._audio_backend
  self._channels = {}
  self._sources = {}
  self._nextSourceId = 1
  self._masterVolume = config.masterVolume or 1.0
  self._crossfades = {}
  self._fades = {}

  -- Initialize asset manager if needed
  if not self._asset_manager then
    self._asset_manager = get_asset_manager()
  end

  -- Get AudioChannel class if needed
  if not self._audio_channel_class then
    self._audio_channel_class = get_audio_channel()
  end

  -- Initialize backend
  if self._backend then
    self._backend:initialize()
  end

  -- Create default channels
  for name, channelConfig in pairs(Types.DefaultChannels) do
    self:createChannel(name, channelConfig)
  end

  self._initialized = true

  return self
end

function AudioManager:createChannel(name, config)
  local AudioChannelClass = self._audio_channel_class or get_audio_channel()
  local channel = AudioChannelClass.new(name, config)
  self._channels[name] = channel
  return channel
end

function AudioManager:getChannel(name)
  return self._channels[name]
end

function AudioManager:play(assetId, options)
  if not self._initialized then
    return nil
  end

  options = options or {}

  -- Get asset from injected asset manager
  local asset_manager = self._asset_manager or get_asset_manager()
  local asset = asset_manager:get(assetId)

  if not asset then
    -- Try to load synchronously
    local loadedAsset, err = asset_manager:loadSync(assetId)
    if not loadedAsset then
      return nil
    end
    asset = loadedAsset
  end

  -- Create source from backend
  local source = self._backend:createSource(asset, options)
  if not source then
    return nil
  end

  -- Generate source ID
  local sourceId = self._nextSourceId
  self._nextSourceId = self._nextSourceId + 1

  -- Store source info
  self._sources[sourceId] = {
    source = source,
    assetId = assetId,
    channelName = options.channel or "SFX",
    volume = options.volume or 1.0,
    baseVolume = options.volume or 1.0,
    loop = options.loop or false,
    priority = options.priority or 5,
    startTime = os.clock(),
    stop = function(s)
      self._backend:stop(source)
    end,
    pause = function(s)
      self._backend:pause(source)
    end,
    resume = function(s)
      self._backend:resume(source)
    end,
    setVolume = function(s, v)
      self._backend:setVolume(source, v)
    end,
    updateVolume = function(channelVolume)
      local vol = self._sources[sourceId].baseVolume * channelVolume * self._masterVolume
      self._backend:setVolume(source, vol)
    end
  }

  -- Add to channel
  local channel = self._channels[options.channel or "SFX"]
  if channel then
    channel:addSource(sourceId, self._sources[sourceId])

    -- Apply ducking from this channel to others
    if channel.ducking then
      for targetChannel, duckAmount in pairs(channel.ducking) do
        local target = self._channels[targetChannel]
        if target then
          target:duck(channel.name, duckAmount)
        end
      end
    end
  end

  -- Retain asset in cache
  asset_manager:retain(assetId)

  -- Play the source
  local playOptions = {
    volume = self._sources[sourceId].baseVolume * (channel and channel:getEffectiveVolume() or 1.0) * self._masterVolume,
    loop = options.loop
  }

  -- Handle fade in
  if options.fadeIn and options.fadeIn > 0 then
    playOptions.volume = 0
    self:_startFade(sourceId, 0, self._sources[sourceId].baseVolume, options.fadeIn)
  end

  self._backend:play(source, playOptions)

  -- Emit event
  if self._event_bus then
    self._event_bus:emit("audio:play", {
      sourceId = sourceId,
      assetId = assetId,
      channel = options.channel or "SFX"
    })
  end

  return sourceId
end

function AudioManager:stop(sourceId, options)
  options = options or {}

  local sourceInfo = self._sources[sourceId]
  if not sourceInfo then
    return false
  end

  if options.fadeOut and options.fadeOut > 0 then
    self:_startFade(sourceId, sourceInfo.volume, 0, options.fadeOut, function()
      self:_stopSource(sourceId)
    end)
    return true
  end

  return self:_stopSource(sourceId)
end

function AudioManager:_stopSource(sourceId)
  local sourceInfo = self._sources[sourceId]
  if not sourceInfo then
    return false
  end

  -- Stop the audio
  self._backend:stop(sourceInfo.source)

  -- Remove from channel
  local channel = self._channels[sourceInfo.channelName]
  if channel then
    channel:removeSource(sourceId)

    -- Remove ducking if channel is now empty
    if channel:getSourceCount() == 0 and channel.ducking then
      for targetChannel, _ in pairs(channel.ducking) do
        local target = self._channels[targetChannel]
        if target then
          target:unduck(channel.name)
        end
      end
    end
  end

  -- Release asset using injected asset manager
  local asset_manager = self._asset_manager or get_asset_manager()
  asset_manager:release(sourceInfo.assetId)

  -- Emit event
  if self._event_bus then
    self._event_bus:emit("audio:stop", {
      sourceId = sourceId,
      assetId = sourceInfo.assetId,
      channel = sourceInfo.channelName
    })
  end

  -- Remove source
  self._sources[sourceId] = nil

  return true
end

function AudioManager:pause(sourceId)
  local sourceInfo = self._sources[sourceId]
  if not sourceInfo then
    return false
  end

  return self._backend:pause(sourceInfo.source)
end

function AudioManager:resume(sourceId)
  local sourceInfo = self._sources[sourceId]
  if not sourceInfo then
    return false
  end

  return self._backend:resume(sourceInfo.source)
end

function AudioManager:setVolume(sourceId, volume)
  local sourceInfo = self._sources[sourceId]
  if not sourceInfo then
    return false
  end

  sourceInfo.baseVolume = volume
  sourceInfo.volume = volume

  local channel = self._channels[sourceInfo.channelName]
  local channelVolume = channel and channel:getEffectiveVolume() or 1.0

  return self._backend:setVolume(sourceInfo.source, volume * channelVolume * self._masterVolume)
end

function AudioManager:getVolume(sourceId)
  local sourceInfo = self._sources[sourceId]
  if not sourceInfo then
    return 0
  end

  return sourceInfo.volume
end

function AudioManager:isPlaying(sourceId)
  local sourceInfo = self._sources[sourceId]
  if not sourceInfo then
    return false
  end

  return self._backend:isPlaying(sourceInfo.source)
end

function AudioManager:crossfade(fromSourceId, toAssetId, options)
  options = options or {}
  local duration = options.duration or 2.0

  local fromSource = self._sources[fromSourceId]
  if not fromSource then
    return nil
  end

  -- Start new source
  local newOptions = {
    channel = options.channel or fromSource.channelName,
    loop = options.loop,
    volume = 0,
    priority = options.priority or fromSource.priority
  }

  local toSourceId = self:play(toAssetId, newOptions)
  if not toSourceId then
    return nil
  end

  -- Fade out old source
  self:_startFade(fromSourceId, fromSource.volume, 0, duration, function()
    self:_stopSource(fromSourceId)
  end)

  -- Fade in new source
  local targetVolume = options.volume or fromSource.baseVolume
  self:_startFade(toSourceId, 0, targetVolume, duration)

  return toSourceId
end

function AudioManager:setChannelVolume(channelName, volume)
  local channel = self._channels[channelName]
  if not channel then
    return false
  end

  channel:setVolume(volume)
  return true
end

function AudioManager:getChannelVolume(channelName)
  local channel = self._channels[channelName]
  return channel and channel:getVolume() or 0
end

function AudioManager:setMasterVolume(volume)
  self._masterVolume = math.max(0, math.min(1, volume))

  -- Update all sources
  for sourceId, sourceInfo in pairs(self._sources) do
    local channel = self._channels[sourceInfo.channelName]
    local channelVolume = channel and channel:getEffectiveVolume() or 1.0
    self._backend:setVolume(sourceInfo.source, sourceInfo.baseVolume * channelVolume * self._masterVolume)
  end
end

function AudioManager:getMasterVolume()
  return self._masterVolume
end

function AudioManager:stopChannel(channelName, options)
  local channel = self._channels[channelName]
  if not channel then
    return false
  end

  local sources = channel:getAllSources()
  for sourceId, _ in pairs(sources) do
    self:stop(sourceId, options)
  end

  return true
end

function AudioManager:stopAll(options)
  for sourceId, _ in pairs(self._sources) do
    self:stop(sourceId, options)
  end
end

function AudioManager:update(dt)
  if not self._initialized then
    return
  end

  -- Update backend
  if self._backend then
    self._backend:update(dt)
  end

  -- Update fades
  self:_updateFades(dt)

  -- Check for finished sources
  for sourceId, sourceInfo in pairs(self._sources) do
    if not self._backend:isPlaying(sourceInfo.source) and not self._backend:isPaused(sourceInfo.source) then
      -- Source finished naturally
      self:_stopSource(sourceId)
    end
  end
end

function AudioManager:_startFade(sourceId, fromVolume, toVolume, duration, onComplete)
  self._fades[sourceId] = {
    fromVolume = fromVolume,
    toVolume = toVolume,
    duration = duration,
    elapsed = 0,
    onComplete = onComplete
  }
end

function AudioManager:_updateFades(dt)
  local completedFades = {}

  for sourceId, fade in pairs(self._fades) do
    fade.elapsed = fade.elapsed + dt

    local progress = math.min(1, fade.elapsed / fade.duration)
    local volume = fade.fromVolume + (fade.toVolume - fade.fromVolume) * progress

    local sourceInfo = self._sources[sourceId]
    if sourceInfo then
      sourceInfo.volume = volume
      local channel = self._channels[sourceInfo.channelName]
      local channelVolume = channel and channel:getEffectiveVolume() or 1.0
      self._backend:setVolume(sourceInfo.source, volume * channelVolume * self._masterVolume)
    end

    if progress >= 1 then
      table.insert(completedFades, sourceId)
      if fade.onComplete then
        fade.onComplete()
      end
    end
  end

  for _, sourceId in ipairs(completedFades) do
    self._fades[sourceId] = nil
  end
end

function AudioManager:shutdown()
  self:stopAll()

  if self._backend then
    self._backend:shutdown()
  end

  self._channels = {}
  self._sources = {}
  self._initialized = false
end

return AudioManager
