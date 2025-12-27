-- Whisker Audio & Media Macros
-- Implements audio and media macros compatible with Twine formats
-- Supports SugarCube-style audio control and media playback
--
-- lib/whisker/script/macros/audio/init.lua

local Macros = require("whisker.script.macros")
local Signature = Macros.Signature

local Audio = {}

--- Module version
Audio.VERSION = "1.0.0"

-- ============================================================================
-- Audio Playback Macros
-- ============================================================================

--- audio macro - Play audio
-- SugarCube: <<audio "track" play>>
-- Supports: play, pause, stop, fadeIn, fadeOut, volume, mute, loop
Audio.audio_macro = Macros.define(
    function(ctx, args)
        local track = args[1]
        local action = args[2] or "play"
        local options = args[3] or {}

        if type(track) == "table" and track._is_expression then
            track = ctx:eval(track)
        end

        local audio_data = {
            _type = "audio",
            track = tostring(track or ""),
            action = action,
            options = {
                volume = options.volume or 1.0,
                loop = options.loop or false,
                fadeDuration = options.fadeDuration or 0,
                time = options.time or 0,
            },
        }

        -- Emit appropriate event based on action
        local event_type = "AUDIO_PLAY"
        if action == "stop" then
            event_type = "AUDIO_STOP"
        elseif action == "pause" then
            event_type = "AUDIO_PAUSE"
        elseif action == "resume" then
            event_type = "AUDIO_RESUME"
        end

        ctx:_emit_event(event_type, audio_data)

        return audio_data
    end,
    {
        signature = Signature.builder()
            :required("track", "any", "Audio track name or ID")
            :optional("action", "string", "play", "Action: play, pause, stop, resume")
            :optional("options", "table", nil, "Playback options")
            :build(),
        description = "Control audio playback",
        format = Macros.FORMAT.SUGARCUBE,
        category = Macros.CATEGORY.AUDIO,
        examples = {
            '<<audio "bgm" play>>',
            '<<audio "sfx" stop>>',
            '<<audio "music" volume 0.5>>',
        },
    }
)

--- play macro - Play audio track
-- Shorthand for <<audio "track" play>>
Audio.play_macro = Macros.define(
    function(ctx, args)
        local track = args[1]
        local options = args[2] or {}

        if type(track) == "table" and track._is_expression then
            track = ctx:eval(track)
        end

        local audio_data = {
            _type = "audio_play",
            track = tostring(track or ""),
            volume = options.volume or 1.0,
            loop = options.loop or false,
            fadeDuration = options.fadeDuration or 0,
        }

        ctx:_emit_event("AUDIO_PLAY", audio_data)

        return audio_data
    end,
    {
        signature = Signature.builder()
            :required("track", "any", "Audio track to play")
            :optional("options", "table", nil, "Playback options")
            :build(),
        description = "Play an audio track",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.AUDIO,
        aliases = { "playsound" },
        examples = {
            "(play: 'background_music')",
        },
    }
)

--- stop macro - Stop audio track
Audio.stop_macro = Macros.define(
    function(ctx, args)
        local track = args[1]
        local options = args[2] or {}

        if type(track) == "table" and track._is_expression then
            track = ctx:eval(track)
        end

        local audio_data = {
            _type = "audio_stop",
            track = track and tostring(track) or nil,  -- nil means stop all
            fadeDuration = options.fadeDuration or 0,
        }

        ctx:_emit_event("AUDIO_STOP", audio_data)

        return audio_data
    end,
    {
        signature = Signature.builder()
            :optional("track", "any", nil, "Audio track to stop (nil = all)")
            :optional("options", "table", nil, "Stop options")
            :build(),
        description = "Stop audio playback",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.AUDIO,
        aliases = { "stopsound" },
        examples = {
            "(stop: 'background_music')",
            "(stop:)",  -- Stop all
        },
    }
)

--- pause macro - Pause audio track
Audio.pause_macro = Macros.define(
    function(ctx, args)
        local track = args[1]

        if type(track) == "table" and track._is_expression then
            track = ctx:eval(track)
        end

        local audio_data = {
            _type = "audio_pause",
            track = track and tostring(track) or nil,
        }

        ctx:_emit_event("AUDIO_PAUSE", audio_data)

        return audio_data
    end,
    {
        signature = Signature.builder()
            :optional("track", "any", nil, "Audio track to pause (nil = all)")
            :build(),
        description = "Pause audio playback",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.AUDIO,
        examples = {
            "(pause: 'background_music')",
        },
    }
)

--- resume macro - Resume paused audio
Audio.resume_macro = Macros.define(
    function(ctx, args)
        local track = args[1]

        if type(track) == "table" and track._is_expression then
            track = ctx:eval(track)
        end

        local audio_data = {
            _type = "audio_resume",
            track = track and tostring(track) or nil,
        }

        ctx:_emit_event("AUDIO_RESUME", audio_data)

        return audio_data
    end,
    {
        signature = Signature.builder()
            :optional("track", "any", nil, "Audio track to resume (nil = all)")
            :build(),
        description = "Resume paused audio",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.AUDIO,
        examples = {
            "(resume: 'background_music')",
        },
    }
)

--- volume macro - Set audio volume
Audio.volume_macro = Macros.define(
    function(ctx, args)
        local track = args[1]
        local level = args[2]
        local options = args[3] or {}

        -- Handle case where only volume is provided (master volume)
        if type(track) == "number" then
            level = track
            track = nil
        end

        if type(track) == "table" and track._is_expression then
            track = ctx:eval(track)
        end

        -- Clamp volume to 0-1 range
        level = math.max(0, math.min(1, tonumber(level) or 1))

        local volume_data = {
            _type = "audio_volume",
            track = track and tostring(track) or nil,
            volume = level,
            fadeDuration = options.fadeDuration or 0,
        }

        ctx:_emit_event("AUDIO_VOLUME_CHANGE", volume_data)

        return volume_data
    end,
    {
        signature = Signature.builder()
            :required("track_or_volume", "any", "Track name or volume level (0-1)")
            :optional("level", "number", nil, "Volume level if first arg is track")
            :optional("options", "table", nil, "Volume options")
            :build(),
        description = "Set audio volume",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.AUDIO,
        examples = {
            "(volume: 'music', 0.5)",
            "(volume: 0.8)",  -- Master volume
        },
    }
)

--- mute macro - Mute audio
Audio.mute_macro = Macros.define(
    function(ctx, args)
        local track = args[1]
        local muted = args[2]

        -- Default to mute (true)
        if muted == nil then muted = true end

        if type(track) == "table" and track._is_expression then
            track = ctx:eval(track)
        end

        -- Handle case where first arg is boolean (master mute)
        if type(track) == "boolean" then
            muted = track
            track = nil
        end

        local mute_data = {
            _type = "audio_mute",
            track = track and tostring(track) or nil,
            muted = muted and true or false,
        }

        ctx:_emit_event("AUDIO_MUTE", mute_data)

        return mute_data
    end,
    {
        signature = Signature.builder()
            :optional("track", "any", nil, "Track to mute (nil = master)")
            :optional("muted", "boolean", true, "Mute state")
            :build(),
        description = "Mute or unmute audio",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.AUDIO,
        aliases = { "unmute" },
        examples = {
            "(mute: 'sfx')",
            "(mute: 'sfx', false)",  -- Unmute
        },
    }
)

--- loop macro - Set audio looping
Audio.loop_macro = Macros.define(
    function(ctx, args)
        local track = args[1]
        local looping = args[2]

        if looping == nil then looping = true end

        if type(track) == "table" and track._is_expression then
            track = ctx:eval(track)
        end

        local loop_data = {
            _type = "audio_loop",
            track = tostring(track or ""),
            loop = looping and true or false,
        }

        ctx:_emit_event("AUDIO_LOOP", loop_data)

        return loop_data
    end,
    {
        signature = Signature.builder()
            :required("track", "any", "Audio track")
            :optional("loop", "boolean", true, "Loop state")
            :build(),
        description = "Set audio looping",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.AUDIO,
        examples = {
            "(loop: 'background_music')",
            "(loop: 'music', false)",
        },
    }
)

-- ============================================================================
-- Audio Management Macros
-- ============================================================================

--- cacheaudio macro - Preload audio
-- SugarCube: <<cacheaudio "id" "url">>
Audio.cacheaudio_macro = Macros.define(
    function(ctx, args)
        local id = args[1]
        local sources = {}

        -- Collect all source URLs
        for i = 2, #args do
            if type(args[i]) == "string" then
                table.insert(sources, args[i])
            elseif type(args[i]) == "table" then
                for _, src in ipairs(args[i]) do
                    table.insert(sources, src)
                end
            end
        end

        local cache_data = {
            _type = "audio_cache",
            id = tostring(id or ""),
            sources = sources,
        }

        ctx:_emit_event("AUDIO_CACHE", cache_data)

        return cache_data
    end,
    {
        signature = Signature.builder()
            :required("id", "string", "Audio track ID")
            :rest("sources", "any", "Audio source URLs")
            :build(),
        description = "Preload audio tracks",
        format = Macros.FORMAT.SUGARCUBE,
        category = Macros.CATEGORY.AUDIO,
        aliases = { "preload" },
        examples = {
            '<<cacheaudio "bgm" "audio/music.mp3" "audio/music.ogg">>',
        },
    }
)

--- playlist macro - Create audio playlist
-- SugarCube: <<playlist "id">><<track "track1">><<track "track2">><</playlist>>
Audio.playlist_macro = Macros.define(
    function(ctx, args)
        local id = args[1]
        local tracks = args[2] or {}
        local options = args[3] or {}

        local playlist_data = {
            _type = "audio_playlist",
            id = tostring(id or ""),
            tracks = tracks,
            shuffle = options.shuffle or false,
            loop = options.loop or false,
            volume = options.volume or 1.0,
        }

        ctx:_emit_event("AUDIO_PLAYLIST_CREATED", playlist_data)

        return playlist_data
    end,
    {
        signature = Signature.builder()
            :required("id", "string", "Playlist ID")
            :optional("tracks", "table", nil, "Array of track IDs")
            :optional("options", "table", nil, "Playlist options")
            :build(),
        description = "Create an audio playlist",
        format = Macros.FORMAT.SUGARCUBE,
        category = Macros.CATEGORY.AUDIO,
        examples = {
            '<<playlist "battle">><<track "battle1">><<track "battle2">><</playlist>>',
        },
    }
)

--- masteraudio macro - Control master audio settings
-- SugarCube: <<masteraudio volume 0.5>>
Audio.masteraudio_macro = Macros.define(
    function(ctx, args)
        local action = args[1] or "volume"
        local value = args[2]

        local master_data = {
            _type = "audio_master",
            action = action,
        }

        if action == "volume" then
            master_data.volume = math.max(0, math.min(1, tonumber(value) or 1))
        elseif action == "mute" then
            master_data.muted = value == nil and true or (value and true or false)
        elseif action == "unmute" then
            master_data.muted = false
        elseif action == "stop" then
            master_data.stopped = true
        end

        ctx:_emit_event("AUDIO_MASTER", master_data)

        return master_data
    end,
    {
        signature = Signature.builder()
            :optional("action", "string", "volume", "Action: volume, mute, unmute, stop")
            :optional("value", "any", nil, "Action value")
            :build(),
        description = "Control master audio settings",
        format = Macros.FORMAT.SUGARCUBE,
        category = Macros.CATEGORY.AUDIO,
        examples = {
            "<<masteraudio volume 0.5>>",
            "<<masteraudio mute>>",
        },
    }
)

--- waitforaudio macro - Wait for audio to finish
-- SugarCube: <<waitforaudio>>
Audio.waitforaudio_macro = Macros.define(
    function(ctx, args)
        local track = args[1]

        local wait_data = {
            _type = "audio_wait",
            track = track and tostring(track) or nil,
        }

        ctx:_emit_event("AUDIO_WAIT", wait_data)

        return wait_data
    end,
    {
        signature = Signature.builder()
            :optional("track", "any", nil, "Track to wait for (nil = any)")
            :build(),
        description = "Wait for audio playback to complete",
        format = Macros.FORMAT.SUGARCUBE,
        category = Macros.CATEGORY.AUDIO,
        async = true,
        examples = {
            "<<waitforaudio>>",
        },
    }
)

-- ============================================================================
-- Sound Effect Macros
-- ============================================================================

--- sfx macro - Play sound effect
Audio.sfx_macro = Macros.define(
    function(ctx, args)
        local effect = args[1]
        local options = args[2] or {}

        if type(effect) == "table" and effect._is_expression then
            effect = ctx:eval(effect)
        end

        local sfx_data = {
            _type = "sfx",
            effect = tostring(effect or ""),
            volume = options.volume or 1.0,
            pitch = options.pitch or 1.0,
            pan = options.pan or 0,  -- -1 left, 0 center, 1 right
        }

        ctx:_emit_event("AUDIO_PLAY", {
            track = sfx_data.effect,
            type = "sfx",
            volume = sfx_data.volume,
            pitch = sfx_data.pitch,
            pan = sfx_data.pan,
        })

        return sfx_data
    end,
    {
        signature = Signature.builder()
            :required("effect", "any", "Sound effect name")
            :optional("options", "table", nil, "Playback options")
            :build(),
        description = "Play a sound effect",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.AUDIO,
        aliases = { "sound", "effect" },
        examples = {
            "(sfx: 'click')",
            "(sfx: 'explosion', { volume: 0.8 })",
        },
    }
)

--- music macro - Play background music
Audio.music_macro = Macros.define(
    function(ctx, args)
        local track = args[1]
        local options = args[2] or {}

        if type(track) == "table" and track._is_expression then
            track = ctx:eval(track)
        end

        local music_data = {
            _type = "music",
            track = tostring(track or ""),
            volume = options.volume or 1.0,
            loop = options.loop == nil and true or options.loop,
            fadeDuration = options.fadeDuration or 0,
            crossfade = options.crossfade or false,
        }

        ctx:_emit_event("AUDIO_PLAY", {
            track = music_data.track,
            type = "music",
            volume = music_data.volume,
            loop = music_data.loop,
            fadeDuration = music_data.fadeDuration,
            crossfade = music_data.crossfade,
        })

        return music_data
    end,
    {
        signature = Signature.builder()
            :required("track", "any", "Music track name")
            :optional("options", "table", nil, "Playback options")
            :build(),
        description = "Play background music (loops by default)",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.AUDIO,
        aliases = { "bgm", "playmusic" },
        examples = {
            "(music: 'theme')",
            "(music: 'battle', { volume: 0.7, crossfade: true })",
        },
    }
)

--- ambience macro - Play ambient sound
Audio.ambience_macro = Macros.define(
    function(ctx, args)
        local track = args[1]
        local options = args[2] or {}

        if type(track) == "table" and track._is_expression then
            track = ctx:eval(track)
        end

        local ambience_data = {
            _type = "ambience",
            track = tostring(track or ""),
            volume = options.volume or 0.5,
            loop = options.loop == nil and true or options.loop,
            fadeDuration = options.fadeDuration or 2000,
        }

        ctx:_emit_event("AUDIO_PLAY", {
            track = ambience_data.track,
            type = "ambience",
            volume = ambience_data.volume,
            loop = ambience_data.loop,
            fadeDuration = ambience_data.fadeDuration,
        })

        return ambience_data
    end,
    {
        signature = Signature.builder()
            :required("track", "any", "Ambient sound track")
            :optional("options", "table", nil, "Playback options")
            :build(),
        description = "Play ambient background sound",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.AUDIO,
        aliases = { "ambient" },
        examples = {
            "(ambience: 'forest')",
            "(ambience: 'rain', { volume: 0.3 })",
        },
    }
)

-- ============================================================================
-- Media Macros
-- ============================================================================

--- image macro - Display image
Audio.image_macro = Macros.define(
    function(ctx, args)
        local src = args[1]
        local options = args[2] or {}

        if type(src) == "table" and src._is_expression then
            src = ctx:eval(src)
        end

        local image_data = {
            _type = "image",
            src = tostring(src or ""),
            alt = options.alt or "",
            width = options.width,
            height = options.height,
            align = options.align or "center",
        }

        ctx:_emit_event("MEDIA_DISPLAY", {
            type = "image",
            data = image_data,
        })

        return image_data
    end,
    {
        signature = Signature.builder()
            :required("src", "any", "Image source URL or path")
            :optional("options", "table", nil, "Display options")
            :build(),
        description = "Display an image",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.UI,
        aliases = { "img", "picture" },
        examples = {
            "(image: 'hero.png')",
            "(image: 'map.jpg', { width: 400 })",
        },
    }
)

--- video macro - Display video
Audio.video_macro = Macros.define(
    function(ctx, args)
        local src = args[1]
        local options = args[2] or {}

        if type(src) == "table" and src._is_expression then
            src = ctx:eval(src)
        end

        local video_data = {
            _type = "video",
            src = tostring(src or ""),
            autoplay = options.autoplay or false,
            controls = options.controls == nil and true or options.controls,
            loop = options.loop or false,
            muted = options.muted or false,
            width = options.width,
            height = options.height,
        }

        ctx:_emit_event("MEDIA_DISPLAY", {
            type = "video",
            data = video_data,
        })

        return video_data
    end,
    {
        signature = Signature.builder()
            :required("src", "any", "Video source URL or path")
            :optional("options", "table", nil, "Video options")
            :build(),
        description = "Display a video",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.UI,
        examples = {
            "(video: 'intro.mp4')",
            "(video: 'cutscene.webm', { autoplay: true })",
        },
    }
)

-- ============================================================================
-- Audio State Queries
-- ============================================================================

--- isplaying macro - Check if audio is playing
Audio.isplaying_macro = Macros.define(
    function(ctx, args)
        local track = args[1]

        if type(track) == "table" and track._is_expression then
            track = ctx:eval(track)
        end

        -- This would need to query actual audio state from client
        -- Return a query object that client can resolve
        local query_data = {
            _type = "audio_query",
            query = "isplaying",
            track = track and tostring(track) or nil,
        }

        return query_data
    end,
    {
        signature = Signature.builder()
            :optional("track", "any", nil, "Track to check (nil = any)")
            :build(),
        description = "Check if audio is currently playing",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.AUDIO,
        pure = true,
        examples = {
            "(if: (isplaying: 'music'))[Music is playing]",
        },
    }
)

--- duration macro - Get audio duration
Audio.duration_macro = Macros.define(
    function(ctx, args)
        local track = args[1]

        if type(track) == "table" and track._is_expression then
            track = ctx:eval(track)
        end

        local query_data = {
            _type = "audio_query",
            query = "duration",
            track = tostring(track or ""),
        }

        return query_data
    end,
    {
        signature = Signature.builder()
            :required("track", "any", "Audio track")
            :build(),
        description = "Get audio track duration",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.AUDIO,
        pure = true,
        examples = {
            "(print: (duration: 'music'))",
        },
    }
)

--- time macro - Get/set audio playback time
Audio.time_macro = Macros.define(
    function(ctx, args)
        local track = args[1]
        local time_val = args[2]

        if type(track) == "table" and track._is_expression then
            track = ctx:eval(track)
        end

        if time_val ~= nil then
            -- Setting time
            local time_data = {
                _type = "audio_seek",
                track = tostring(track or ""),
                time = tonumber(time_val) or 0,
            }

            ctx:_emit_event("AUDIO_SEEK", time_data)
            return time_data
        else
            -- Getting time (query)
            return {
                _type = "audio_query",
                query = "time",
                track = tostring(track or ""),
            }
        end
    end,
    {
        signature = Signature.builder()
            :required("track", "any", "Audio track")
            :optional("time", "number", nil, "Time to seek to (seconds)")
            :build(),
        description = "Get or set audio playback position",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.AUDIO,
        aliases = { "seek" },
        examples = {
            "(time: 'music', 30)",  -- Seek to 30 seconds
            "(print: (time: 'music'))",  -- Get current time
        },
    }
)

-- ============================================================================
-- Registration Helper
-- ============================================================================

--- Register all audio macros with a registry
-- @param registry MacroRegistry The registry to register with
-- @return number Number of macros registered
function Audio.register_all(registry)
    local macros = {
        -- Playback control
        ["audio"] = Audio.audio_macro,
        ["play"] = Audio.play_macro,
        ["stop_audio"] = Audio.stop_macro,
        ["pause_audio"] = Audio.pause_macro,
        ["resume_audio"] = Audio.resume_macro,
        ["volume"] = Audio.volume_macro,
        ["mute"] = Audio.mute_macro,
        ["loop_audio"] = Audio.loop_macro,

        -- Audio management
        ["cacheaudio"] = Audio.cacheaudio_macro,
        ["playlist"] = Audio.playlist_macro,
        ["masteraudio"] = Audio.masteraudio_macro,
        ["waitforaudio"] = Audio.waitforaudio_macro,

        -- Sound types
        ["sfx"] = Audio.sfx_macro,
        ["music"] = Audio.music_macro,
        ["ambience"] = Audio.ambience_macro,

        -- Media
        ["image"] = Audio.image_macro,
        ["video"] = Audio.video_macro,

        -- Queries
        ["isplaying"] = Audio.isplaying_macro,
        ["duration"] = Audio.duration_macro,
        ["time_audio"] = Audio.time_macro,
    }

    local count, _ = registry:register_all(macros)
    return count
end

return Audio
