-- spec/wls2/audio_effects_spec.lua
-- Tests for WLS 2.0 Audio Effects

package.path = package.path .. ";./lib/?.lua;./lib/?/init.lua"

describe("AudioEffects", function()
    local AudioEffects

    before_each(function()
        AudioEffects = require("whisker.wls2.audio_effects")
    end)

    describe("parseAudioDeclaration", function()
        it("parses basic declaration", function()
            local decl = AudioEffects.parseAudioDeclaration('bgm = "music/theme.mp3"')
            assert.equals("bgm", decl.id)
            assert.equals("music/theme.mp3", decl.url)
        end)

        it("parses declaration with loop", function()
            local decl = AudioEffects.parseAudioDeclaration('bgm = "music/theme.mp3" loop')
            assert.is_true(decl.loop)
        end)

        it("parses declaration with preload", function()
            local decl = AudioEffects.parseAudioDeclaration('voice = "dialogue/intro.mp3" preload')
            assert.is_true(decl.preload)
        end)

        it("parses declaration with volume", function()
            local decl = AudioEffects.parseAudioDeclaration('bgm = "music/theme.mp3" volume:0.7')
            assert.equals(0.7, decl.volume)
        end)

        it("parses declaration with channel", function()
            local decl = AudioEffects.parseAudioDeclaration('sfx = "sounds/click.wav" channel:sfx')
            assert.equals("sfx", decl.channel)
        end)

        it("parses full declaration", function()
            local decl = AudioEffects.parseAudioDeclaration('theme = "music/main.mp3" loop volume:0.8 preload channel:bgm')
            assert.equals("theme", decl.id)
            assert.equals("music/main.mp3", decl.url)
            assert.is_true(decl.loop)
            assert.is_true(decl.preload)
            assert.equals(0.8, decl.volume)
            assert.equals("bgm", decl.channel)
        end)

        it("throws for empty declaration", function()
            assert.has_error(function()
                AudioEffects.parseAudioDeclaration("")
            end)
        end)

        it("throws for invalid format", function()
            assert.has_error(function()
                AudioEffects.parseAudioDeclaration("invalid")
            end)
        end)
    end)

    describe("channels", function()
        it("defines standard channels", function()
            assert.is_not_nil(AudioEffects.CHANNELS.bgm)
            assert.is_not_nil(AudioEffects.CHANNELS.sfx)
            assert.is_not_nil(AudioEffects.CHANNELS.voice)
            assert.is_not_nil(AudioEffects.CHANNELS.ambient)
        end)

        it("bgm channel is exclusive", function()
            assert.is_true(AudioEffects.CHANNELS.bgm.exclusive)
        end)

        it("sfx channel is not exclusive", function()
            assert.is_false(AudioEffects.CHANNELS.sfx.exclusive)
        end)
    end)

    describe("manager", function()
        local manager, mockBackend

        before_each(function()
            -- Create a mock audio backend using closures (not colon-syntax)
            local instances = {}
            local volumes = {}
            local playing = {}
            local loops = {}

            mockBackend = {
                instances = instances,
                volumes = volumes,
                playing = playing,
                loops = loops,

                create = function(url)
                    local instance = { url = url, id = #instances + 1 }
                    table.insert(instances, instance)
                    return instance
                end,

                play = function(instance)
                    playing[instance.id] = true
                end,

                stop = function(instance)
                    playing[instance.id] = false
                end,

                pause = function(instance)
                    playing[instance.id] = false
                end,

                resume = function(instance)
                    playing[instance.id] = true
                end,

                setVolume = function(instance, volume)
                    volumes[instance.id] = volume
                end,

                setLoop = function(instance, loop)
                    loops[instance.id] = loop
                end
            }

            manager = AudioEffects.new({}, { audio_backend = mockBackend })
        end)

        it("creates a new manager", function()
            assert.is_not_nil(manager)
        end)

        it("registers a track", function()
            manager:registerTrack({
                id = "bgm",
                url = "music/theme.mp3"
            })
            assert.is_true(manager:hasTrack("bgm"))
        end)

        it("gets registered track", function()
            manager:registerTrack({
                id = "bgm",
                url = "music/theme.mp3",
                loop = true,
                volume = 0.7
            })

            local track = manager:getTrack("bgm")
            assert.equals("music/theme.mp3", track.url)
            assert.is_true(track.loop)
            assert.equals(0.7, track.volume)
        end)

        it("throws for missing track on play", function()
            assert.has_error(function()
                manager:play("nonexistent")
            end)
        end)

        it("plays a track", function()
            manager:registerTrack({ id = "bgm", url = "music/theme.mp3" })
            manager:play("bgm")

            -- Backend should have received play
            assert.is_true(mockBackend.playing[1])
        end)

        it("stops a track", function()
            manager:registerTrack({ id = "bgm", url = "music/theme.mp3" })
            manager:play("bgm")
            manager:stop("bgm")

            assert.is_false(mockBackend.playing[1])
        end)

        it("sets track volume", function()
            manager:registerTrack({ id = "bgm", url = "music/theme.mp3" })
            manager:play("bgm")
            manager:setVolume("bgm", 0.5)

            assert.equals(0.5, manager:getVolume("bgm"))
        end)

        it("exclusive channel stops other tracks", function()
            manager:registerTrack({ id = "track1", url = "a.mp3", channel = "bgm" })
            manager:registerTrack({ id = "track2", url = "b.mp3", channel = "bgm" })

            manager:play("track1")
            assert.is_true(mockBackend.playing[1])

            manager:play("track2")
            -- track1 should be stopped
            assert.is_false(mockBackend.playing[1])
            assert.is_true(mockBackend.playing[2])
        end)

        it("non-exclusive channel allows multiple", function()
            manager:registerTrack({ id = "sfx1", url = "a.wav", channel = "sfx" })
            manager:registerTrack({ id = "sfx2", url = "b.wav", channel = "sfx" })

            manager:play("sfx1")
            manager:play("sfx2")

            -- Both should be playing
            assert.is_true(mockBackend.playing[1])
            assert.is_true(mockBackend.playing[2])
        end)

        it("sets master volume", function()
            manager:setMasterVolume(0.5)
            assert.equals(0.5, manager:getMasterVolume())
        end)

        it("sets channel volume", function()
            manager:setChannelVolume("bgm", 0.3)
            assert.equals(0.3, manager:getChannelVolume("bgm"))
        end)

        it("mutes and unmutes channel", function()
            manager:registerTrack({ id = "bgm", url = "theme.mp3", channel = "bgm" })
            manager:play("bgm")

            manager:muteChannel("bgm")
            assert.is_true(manager:isChannelMuted("bgm"))
            assert.equals(0, mockBackend.volumes[1])

            manager:unmuteChannel("bgm")
            assert.is_false(manager:isChannelMuted("bgm"))
        end)

        describe("fade effects", function()
            it("creates fade in controller", function()
                manager:registerTrack({ id = "bgm", url = "theme.mp3", volume = 1.0 })

                local controller = manager:fadeIn("bgm", 1000)
                assert.is_not_nil(controller)
                assert.is_not_nil(controller.tick)
            end)

            it("fade in increases volume over time", function()
                manager:registerTrack({ id = "bgm", url = "theme.mp3", volume = 1.0 })

                local controller = manager:fadeIn("bgm", 1000)

                -- Initial volume should be 0
                assert.equals(0, manager:getVolume("bgm"))

                -- Tick halfway
                controller:tick(500)
                local midVolume = manager:getVolume("bgm")
                assert.is_true(midVolume > 0)
                assert.is_true(midVolume < 1)

                -- Tick to completion
                controller:tick(500)
                assert.equals(1.0, manager:getVolume("bgm"))
            end)

            it("creates fade out controller", function()
                manager:registerTrack({ id = "bgm", url = "theme.mp3", volume = 1.0 })
                manager:play("bgm")

                local controller = manager:fadeOut("bgm", 1000)
                assert.is_not_nil(controller)
            end)

            it("fade out decreases volume and stops", function()
                manager:registerTrack({ id = "bgm", url = "theme.mp3", volume = 1.0 })
                manager:play("bgm")

                local controller = manager:fadeOut("bgm", 1000)

                -- Tick to completion
                controller:tick(1000)
                assert.equals(0, manager:getVolume("bgm"))
            end)

            it("creates crossfade controller", function()
                manager:registerTrack({ id = "forest", url = "forest.mp3", volume = 1.0 })
                manager:registerTrack({ id = "battle", url = "battle.mp3", volume = 1.0 })
                manager:play("forest")

                local controller = manager:crossfade("forest", "battle", 1000)
                assert.is_not_nil(controller)
            end)

            it("crossfade transitions between tracks", function()
                manager:registerTrack({ id = "forest", url = "forest.mp3", volume = 1.0 })
                manager:registerTrack({ id = "battle", url = "battle.mp3", volume = 1.0 })
                manager:play("forest")

                local controller = manager:crossfade("forest", "battle", 1000)

                -- Tick halfway
                controller:tick(500)
                local forestVol = manager:getVolume("forest")
                local battleVol = manager:getVolume("battle")

                assert.is_true(forestVol < 1.0)
                assert.is_true(battleVol > 0)

                -- Tick to completion
                controller:tick(500)
                assert.equals(1.0, manager:getVolume("battle"))
            end)
        end)

        it("stops all audio", function()
            manager:registerTrack({ id = "bgm", url = "theme.mp3" })
            manager:registerTrack({ id = "sfx", url = "click.wav" })
            manager:play("bgm")
            manager:play("sfx")

            manager:stopAll()

            assert.is_false(mockBackend.playing[1])
            assert.is_false(mockBackend.playing[2])
        end)

        it("clears all tracks", function()
            manager:registerTrack({ id = "bgm", url = "theme.mp3" })
            manager:clear()
            assert.is_false(manager:hasTrack("bgm"))
        end)
    end)
end)
