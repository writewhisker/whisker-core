--- Audio Effects for WLS 2.0
--- Extends audio functionality with fade effects and channel management
--- @module whisker.wls2.audio_effects

local AudioEffects = {
    _VERSION = "2.0.0"
}
AudioEffects.__index = AudioEffects
AudioEffects._dependencies = {"audio_backend"}

--- Audio channels with their behavior
AudioEffects.CHANNELS = {
    bgm = { exclusive = true, default_volume = 0.7 },
    sfx = { exclusive = false, default_volume = 1.0 },
    voice = { exclusive = true, default_volume = 1.0 },
    ambient = { exclusive = false, default_volume = 0.5 }
}

--- Parse an audio declaration string
--- @param declaration string Declaration (e.g., "bgm = \"music/theme.mp3\" loop volume:0.7")
--- @return table Parsed declaration with id, url, and options
function AudioEffects.parseAudioDeclaration(declaration)
    if type(declaration) ~= "string" or declaration == "" then
        error("Declaration must be a non-empty string")
    end

    -- Match: id = "url" [options...]
    local id, url, options_str = declaration:match('^([%w_]+)%s*=%s*"([^"]+)"(.*)$')

    if not id then
        error("Invalid audio declaration format: " .. declaration)
    end

    local options = {
        loop = false,
        preload = false,
        volume = 1.0,
        channel = "sfx"
    }

    if options_str then
        -- Parse options
        if options_str:match("loop") then
            options.loop = true
        end

        if options_str:match("preload") then
            options.preload = true
        end

        local volume = options_str:match("volume:([%d.]+)")
        if volume then
            options.volume = tonumber(volume)
        end

        local channel = options_str:match("channel:(%w+)")
        if channel then
            options.channel = channel
        end
    end

    return {
        id = id,
        url = url,
        loop = options.loop,
        preload = options.preload,
        volume = options.volume,
        channel = options.channel
    }
end

--- Create a new AudioEffects manager
--- @param config table Configuration options
--- @param deps table Dependencies (audio_backend required)
--- @return AudioEffects The new manager instance
function AudioEffects.new(config, deps)
    config = config or {}
    deps = deps or {}

    local self = setmetatable({}, AudioEffects)
    self._backend = deps.audio_backend or deps.backend
    self._tracks = {}           -- id -> track info
    self._instances = {}        -- id -> backend instance
    self._volumes = {}          -- id -> current volume
    self._masterVolume = 1.0
    self._channelVolumes = {}   -- channel -> volume
    self._channelMuted = {}     -- channel -> boolean
    self._activeByChannel = {}  -- channel -> set of active track ids
    self._deps = deps

    -- Initialize channel volumes
    for channel, info in pairs(AudioEffects.CHANNELS) do
        self._channelVolumes[channel] = info.default_volume
        self._activeByChannel[channel] = {}
    end

    return self
end

--- Create a factory function for DI
--- @param deps table Dependencies
--- @return function Factory function
function AudioEffects.create(deps)
    return function(config)
        return AudioEffects.new(config, deps)
    end
end

--- Register an audio track
--- @param track table Track definition with id, url, and options
function AudioEffects:registerTrack(track)
    if type(track) ~= "table" or not track.id or not track.url then
        error("Track must have id and url")
    end

    self._tracks[track.id] = {
        id = track.id,
        url = track.url,
        loop = track.loop or false,
        volume = track.volume or 1.0,
        channel = track.channel or "sfx",
        preload = track.preload or false
    }
    self._volumes[track.id] = track.volume or 1.0

    -- Preload if requested and backend supports it
    if track.preload and self._backend and self._backend.create then
        self._instances[track.id] = self._backend.create(track.url)
    end
end

--- Get a registered track
--- @param id string Track ID
--- @return table|nil Track info or nil
function AudioEffects:getTrack(id)
    return self._tracks[id]
end

--- Check if a track exists
--- @param id string Track ID
--- @return boolean True if track exists
function AudioEffects:hasTrack(id)
    return self._tracks[id] ~= nil
end

--- Calculate effective volume for a track
--- @param id string Track ID
--- @return number Effective volume (0-1)
function AudioEffects:_getEffectiveVolume(id)
    local track = self._tracks[id]
    if not track then return 0 end

    local trackVolume = self._volumes[id] or track.volume or 1.0
    local channelVolume = self._channelVolumes[track.channel] or 1.0
    local channelMuted = self._channelMuted[track.channel]

    if channelMuted then return 0 end

    return trackVolume * channelVolume * self._masterVolume
end

--- Play a track
--- @param id string Track ID
function AudioEffects:play(id)
    local track = self._tracks[id]
    if not track then
        error("Track not registered: " .. id)
    end

    if not self._backend then
        return  -- No backend, silently skip
    end

    local channel = track.channel
    local channelInfo = AudioEffects.CHANNELS[channel] or { exclusive = false }

    -- Handle exclusive channels - stop other tracks on same channel
    if channelInfo.exclusive then
        for activeId in pairs(self._activeByChannel[channel] or {}) do
            if activeId ~= id then
                self:stop(activeId)
            end
        end
    end

    -- Get or create instance
    local instance = self._instances[id]
    if not instance then
        instance = self._backend.create(track.url)
        self._instances[id] = instance
    end

    -- Set volume and loop
    if self._backend.setVolume then
        self._backend.setVolume(instance, self:_getEffectiveVolume(id))
    end
    if self._backend.setLoop then
        self._backend.setLoop(instance, track.loop)
    end

    -- Play
    if self._backend.play then
        self._backend.play(instance)
    end

    -- Track as active
    if not self._activeByChannel[channel] then
        self._activeByChannel[channel] = {}
    end
    self._activeByChannel[channel][id] = true
end

--- Stop a track
--- @param id string Track ID
function AudioEffects:stop(id)
    local track = self._tracks[id]
    if not track then return end

    local instance = self._instances[id]
    if instance and self._backend and self._backend.stop then
        self._backend.stop(instance)
    end

    -- Remove from active
    local channel = track.channel
    if self._activeByChannel[channel] then
        self._activeByChannel[channel][id] = nil
    end
end

--- Pause a track
--- @param id string Track ID
function AudioEffects:pause(id)
    local instance = self._instances[id]
    if instance and self._backend and self._backend.pause then
        self._backend.pause(instance)
    end
end

--- Resume a track
--- @param id string Track ID
function AudioEffects:resume(id)
    local instance = self._instances[id]
    if instance and self._backend and self._backend.resume then
        self._backend.resume(instance)
    end
end

--- Set track volume
--- @param id string Track ID
--- @param volume number Volume (0-1)
function AudioEffects:setVolume(id, volume)
    self._volumes[id] = math.max(0, math.min(1, volume))

    local instance = self._instances[id]
    if instance and self._backend and self._backend.setVolume then
        self._backend.setVolume(instance, self:_getEffectiveVolume(id))
    end
end

--- Get track volume
--- @param id string Track ID
--- @return number Volume (0-1)
function AudioEffects:getVolume(id)
    return self._volumes[id] or 1.0
end

--- Fade in a track
--- @param id string Track ID
--- @param duration number Duration in ms
--- @param callback function|nil Callback when complete
function AudioEffects:fadeIn(id, duration, callback)
    local track = self._tracks[id]
    if not track then
        error("Track not registered: " .. id)
    end

    -- Start at volume 0
    self._volumes[id] = 0
    self:play(id)

    -- Create fade controller
    local targetVolume = track.volume or 1.0
    local startTime = 0
    local elapsed = 0

    local controller = {
        _completed = false,

        tick = function(self_ctrl, deltaMs)
            if self_ctrl._completed then return end

            elapsed = elapsed + deltaMs
            local progress = math.min(elapsed / duration, 1.0)
            local currentVolume = progress * targetVolume

            self._volumes[id] = currentVolume
            local instance = self._instances[id]
            if instance and self._backend and self._backend.setVolume then
                self._backend.setVolume(instance, self:_getEffectiveVolume(id))
            end

            if progress >= 1.0 then
                self_ctrl._completed = true
                if callback then callback() end
            end
        end
    }

    return controller
end

--- Fade out a track
--- @param id string Track ID
--- @param duration number Duration in ms
--- @param callback function|nil Callback when complete
function AudioEffects:fadeOut(id, duration, callback)
    local startVolume = self._volumes[id] or 1.0
    local elapsed = 0

    local controller = {
        _completed = false,

        tick = function(self_ctrl, deltaMs)
            if self_ctrl._completed then return end

            elapsed = elapsed + deltaMs
            local progress = math.min(elapsed / duration, 1.0)
            local currentVolume = startVolume * (1 - progress)

            self._volumes[id] = currentVolume
            local instance = self._instances[id]
            if instance and self._backend and self._backend.setVolume then
                self._backend.setVolume(instance, self:_getEffectiveVolume(id))
            end

            if progress >= 1.0 then
                self:stop(id)
                self_ctrl._completed = true
                if callback then callback() end
            end
        end
    }

    return controller
end

--- Crossfade between two tracks
--- @param fromId string Track to fade out
--- @param toId string Track to fade in
--- @param duration number Duration in ms
--- @param callback function|nil Callback when complete
function AudioEffects:crossfade(fromId, toId, duration, callback)
    local fromVolume = self._volumes[fromId] or 1.0
    local toTrack = self._tracks[toId]
    local toTargetVolume = toTrack and toTrack.volume or 1.0
    local elapsed = 0

    -- Start the target track at volume 0
    self._volumes[toId] = 0
    self:play(toId)

    local controller = {
        _completed = false,

        tick = function(self_ctrl, deltaMs)
            if self_ctrl._completed then return end

            elapsed = elapsed + deltaMs
            local progress = math.min(elapsed / duration, 1.0)

            -- Fade out from track
            local fromCurrent = fromVolume * (1 - progress)
            self._volumes[fromId] = fromCurrent
            local fromInstance = self._instances[fromId]
            if fromInstance and self._backend and self._backend.setVolume then
                self._backend.setVolume(fromInstance, self:_getEffectiveVolume(fromId))
            end

            -- Fade in to track
            local toCurrent = toTargetVolume * progress
            self._volumes[toId] = toCurrent
            local toInstance = self._instances[toId]
            if toInstance and self._backend and self._backend.setVolume then
                self._backend.setVolume(toInstance, self:_getEffectiveVolume(toId))
            end

            if progress >= 1.0 then
                self:stop(fromId)
                self_ctrl._completed = true
                if callback then callback() end
            end
        end
    }

    return controller
end

--- Set master volume
--- @param volume number Volume (0-1)
function AudioEffects:setMasterVolume(volume)
    self._masterVolume = math.max(0, math.min(1, volume))

    -- Update all active instances
    for id, instance in pairs(self._instances) do
        if self._backend and self._backend.setVolume then
            self._backend.setVolume(instance, self:_getEffectiveVolume(id))
        end
    end
end

--- Get master volume
--- @return number Master volume (0-1)
function AudioEffects:getMasterVolume()
    return self._masterVolume
end

--- Set channel volume
--- @param channel string Channel name
--- @param volume number Volume (0-1)
function AudioEffects:setChannelVolume(channel, volume)
    self._channelVolumes[channel] = math.max(0, math.min(1, volume))

    -- Update active tracks on this channel
    for id in pairs(self._activeByChannel[channel] or {}) do
        local instance = self._instances[id]
        if instance and self._backend and self._backend.setVolume then
            self._backend.setVolume(instance, self:_getEffectiveVolume(id))
        end
    end
end

--- Get channel volume
--- @param channel string Channel name
--- @return number Channel volume (0-1)
function AudioEffects:getChannelVolume(channel)
    return self._channelVolumes[channel] or 1.0
end

--- Mute a channel
--- @param channel string Channel name
function AudioEffects:muteChannel(channel)
    self._channelMuted[channel] = true

    -- Update active tracks on this channel
    for id in pairs(self._activeByChannel[channel] or {}) do
        local instance = self._instances[id]
        if instance and self._backend and self._backend.setVolume then
            self._backend.setVolume(instance, 0)
        end
    end
end

--- Unmute a channel
--- @param channel string Channel name
function AudioEffects:unmuteChannel(channel)
    self._channelMuted[channel] = false

    -- Update active tracks on this channel
    for id in pairs(self._activeByChannel[channel] or {}) do
        local instance = self._instances[id]
        if instance and self._backend and self._backend.setVolume then
            self._backend.setVolume(instance, self:_getEffectiveVolume(id))
        end
    end
end

--- Check if a channel is muted
--- @param channel string Channel name
--- @return boolean True if muted
function AudioEffects:isChannelMuted(channel)
    return self._channelMuted[channel] == true
end

--- Stop all audio
function AudioEffects:stopAll()
    for id in pairs(self._instances) do
        self:stop(id)
    end
end

--- Clear all tracks and instances
function AudioEffects:clear()
    self:stopAll()
    self._tracks = {}
    self._instances = {}
    self._volumes = {}
    self._activeByChannel = {}

    for channel in pairs(AudioEffects.CHANNELS) do
        self._activeByChannel[channel] = {}
    end
end

return AudioEffects
