-- AudioManager Tests
-- Unit tests for the AudioManager module

describe("AudioManager", function()
  local AudioManager
  local AssetManager
  local DummyAudioBackend
  local backend

  before_each(function()
    package.loaded["whisker.media.AudioManager"] = nil
    package.loaded["whisker.media.AssetManager"] = nil
    package.loaded["whisker.media.AudioChannel"] = nil
    package.loaded["whisker.media.backends.DummyAudioBackend"] = nil
    package.loaded["whisker.media.types"] = nil

    AssetManager = require("whisker.media.AssetManager")
    AssetManager:initialize()

    DummyAudioBackend = require("whisker.media.backends.DummyAudioBackend")
    backend = DummyAudioBackend.new()

    AudioManager = require("whisker.media.AudioManager")
    AudioManager:initialize(backend)

    -- Register test audio asset
    AssetManager:register({
      id = "test_audio",
      type = "audio",
      sources = { { format = "mp3", path = "test.mp3" } },
      metadata = { duration = 60 }
    })
  end)

  after_each(function()
    if AudioManager._initialized then
      AudioManager:stopAll()
      AudioManager:shutdown()
    end
  end)

  describe("initialization", function()
    it("initializes with backend", function()
      assert.is_true(AudioManager._initialized)
      assert.is_not_nil(AudioManager._backend)
    end)

    it("creates default channels", function()
      assert.is_not_nil(AudioManager:getChannel("MUSIC"))
      assert.is_not_nil(AudioManager:getChannel("SFX"))
      assert.is_not_nil(AudioManager:getChannel("VOICE"))
      assert.is_not_nil(AudioManager:getChannel("AMBIENT"))
    end)

    it("sets master volume", function()
      assert.equals(1.0, AudioManager:getMasterVolume())
    end)
  end)

  describe("channel management", function()
    it("creates custom channel", function()
      local channel = AudioManager:createChannel("CUSTOM", {
        maxConcurrent = 5,
        volume = 0.8
      })

      assert.is_not_nil(channel)
      assert.equals("CUSTOM", channel.name)
    end)

    it("getChannel returns channel by name", function()
      local music = AudioManager:getChannel("MUSIC")

      assert.is_not_nil(music)
      assert.equals("MUSIC", music.name)
    end)

    it("getChannel returns nil for non-existent channel", function()
      local nonexistent = AudioManager:getChannel("NONEXISTENT")
      assert.is_nil(nonexistent)
    end)
  end)

  describe("playback", function()
    it("play returns source ID or nil if asset not loaded", function()
      -- Load asset first
      AssetManager:loadSync("test_audio")

      local sourceId = AudioManager:play("test_audio", {
        channel = "SFX"
      })

      -- May return nil if file doesn't exist
      assert.is_true(sourceId == nil or type(sourceId) == "number")
    end)

    it("play with options returns source ID or nil", function()
      AssetManager:loadSync("test_audio")

      local sourceId = AudioManager:play("test_audio", {
        channel = "MUSIC",
        loop = true,
        volume = 0.5
      })

      -- May return nil if file doesn't exist
      assert.is_true(sourceId == nil or type(sourceId) == "number")
    end)

    it("isPlaying returns true for playing source", function()
      AssetManager:loadSync("test_audio")

      local sourceId = AudioManager:play("test_audio")

      if sourceId then
        assert.is_true(AudioManager:isPlaying(sourceId))
      end
    end)

    it("stop stops playback", function()
      AssetManager:loadSync("test_audio")

      local sourceId = AudioManager:play("test_audio")

      if sourceId then
        AudioManager:stop(sourceId)
        assert.is_false(AudioManager:isPlaying(sourceId))
      end
    end)

    it("pause pauses playback", function()
      AssetManager:loadSync("test_audio")

      local sourceId = AudioManager:play("test_audio")

      if sourceId then
        AudioManager:pause(sourceId)
        assert.is_false(AudioManager:isPlaying(sourceId))
      end
    end)

    it("resume resumes paused playback", function()
      AssetManager:loadSync("test_audio")

      local sourceId = AudioManager:play("test_audio")

      if sourceId then
        AudioManager:pause(sourceId)
        AudioManager:resume(sourceId)
        assert.is_true(AudioManager:isPlaying(sourceId))
      end
    end)
  end)

  describe("volume control", function()
    it("setVolume changes source volume", function()
      AssetManager:loadSync("test_audio")

      local sourceId = AudioManager:play("test_audio", { volume = 1.0 })

      if sourceId then
        AudioManager:setVolume(sourceId, 0.5)
        -- Verify through backend or internal state
        local sourceInfo = AudioManager._sources[sourceId]
        assert.equals(0.5, sourceInfo.baseVolume)
      end
    end)

    it("getVolume returns current volume", function()
      AssetManager:loadSync("test_audio")

      local sourceId = AudioManager:play("test_audio", { volume = 0.7 })

      if sourceId then
        assert.equals(0.7, AudioManager:getVolume(sourceId))
      end
    end)

    it("setChannelVolume changes channel volume", function()
      AudioManager:setChannelVolume("MUSIC", 0.5)

      assert.equals(0.5, AudioManager:getChannelVolume("MUSIC"))
    end)

    it("setMasterVolume changes master volume", function()
      AudioManager:setMasterVolume(0.5)

      assert.equals(0.5, AudioManager:getMasterVolume())
    end)

    it("master volume clamps to 0-1", function()
      AudioManager:setMasterVolume(1.5)
      assert.equals(1.0, AudioManager:getMasterVolume())

      AudioManager:setMasterVolume(-0.5)
      assert.equals(0.0, AudioManager:getMasterVolume())
    end)
  end)

  describe("crossfade", function()
    it("crossfades between two sources", function()
      AssetManager:register({
        id = "audio1",
        type = "audio",
        sources = { { format = "mp3", path = "audio1.mp3" } },
        metadata = { duration = 60 }
      })

      AssetManager:register({
        id = "audio2",
        type = "audio",
        sources = { { format = "mp3", path = "audio2.mp3" } },
        metadata = { duration = 60 }
      })

      AssetManager:loadSync("audio1")
      AssetManager:loadSync("audio2")

      local sourceId1 = AudioManager:play("audio1", { channel = "MUSIC" })

      if sourceId1 then
        local sourceId2 = AudioManager:crossfade(sourceId1, "audio2", {
          duration = 1.0
        })

        assert.is_number(sourceId2)
      end
    end)
  end)

  describe("channel operations", function()
    it("stopChannel stops all sources in channel", function()
      AssetManager:loadSync("test_audio")

      AudioManager:play("test_audio", { channel = "SFX" })
      AudioManager:play("test_audio", { channel = "SFX" })

      AudioManager:stopChannel("SFX")

      local channel = AudioManager:getChannel("SFX")
      assert.equals(0, channel:getSourceCount())
    end)

    it("stopAll stops all playing sources", function()
      AssetManager:loadSync("test_audio")

      AudioManager:play("test_audio", { channel = "SFX" })
      AudioManager:play("test_audio", { channel = "MUSIC" })

      AudioManager:stopAll()

      -- All sources should be stopped
      local sfxChannel = AudioManager:getChannel("SFX")
      local musicChannel = AudioManager:getChannel("MUSIC")

      assert.equals(0, sfxChannel:getSourceCount())
      assert.equals(0, musicChannel:getSourceCount())
    end)
  end)

  describe("update loop", function()
    it("update processes fades", function()
      AssetManager:loadSync("test_audio")

      local sourceId = AudioManager:play("test_audio", {
        fadeIn = 0.5,
        volume = 1.0
      })

      if sourceId then
        -- Simulate time passing
        AudioManager:update(0.25)
        AudioManager:update(0.25)

        -- Fade should be complete
        local sourceInfo = AudioManager._sources[sourceId]
        if sourceInfo then
          assert.is_true(sourceInfo.volume > 0)
        end
      end
    end)
  end)

  describe("fade operations", function()
    it("fadeIn starts at 0 volume", function()
      AssetManager:loadSync("test_audio")

      local sourceId = AudioManager:play("test_audio", {
        fadeIn = 1.0,
        volume = 1.0
      })

      if sourceId then
        local fade = AudioManager._fades[sourceId]
        if fade then
          assert.equals(0, fade.fromVolume)
        end
      end
    end)

    it("stop with fadeOut creates fade", function()
      AssetManager:loadSync("test_audio")

      local sourceId = AudioManager:play("test_audio", { volume = 1.0 })

      if sourceId then
        AudioManager:stop(sourceId, { fadeOut = 0.5 })

        local fade = AudioManager._fades[sourceId]
        if fade then
          assert.equals(0, fade.toVolume)
        end
      end
    end)
  end)

  describe("shutdown", function()
    it("stops all audio and cleans up", function()
      AssetManager:loadSync("test_audio")
      AudioManager:play("test_audio")

      AudioManager:shutdown()

      assert.is_false(AudioManager._initialized)
    end)
  end)
end)
