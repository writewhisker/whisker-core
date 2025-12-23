-- Integration tests for AssetManager + AudioManager
describe("AssetManager + AudioManager Integration", function()
  local AssetManager, AudioManager, DummyBackend, Types

  -- Helper to cache an asset
  local function cacheAsset(id, assetType)
    AssetManager._cache:set(id, {
      id = id,
      type = assetType,
      data = "mock_data",
      sizeBytes = 1024,
      metadata = {duration = 60}
    }, 1024)
    AssetManager._states[id] = Types.AssetState.LOADED
  end

  before_each(function()
    package.loaded["whisker.media.AssetManager"] = nil
    package.loaded["whisker.media.AudioManager"] = nil
    package.loaded["whisker.media.backends.DummyAudioBackend"] = nil
    package.loaded["whisker.media.types"] = nil

    Types = require("whisker.media.types")
    AssetManager = require("whisker.media.AssetManager")
    AudioManager = require("whisker.media.AudioManager")
    DummyBackend = require("whisker.media.backends.DummyAudioBackend")

    AssetManager:initialize()
    AudioManager:initialize(DummyBackend.new())

    -- Register test asset
    AssetManager:register({
      id = "test_music",
      type = "audio",
      sources = {{format = "mp3", path = "test.mp3"}},
      metadata = {duration = 60}
    })
    cacheAsset("test_music", "audio")
  end)

  describe("playback workflow", function()
    it("plays audio from AssetManager", function()
      local sourceId = AudioManager:play("test_music", {
        channel = "MUSIC",
        loop = true,
        volume = 0.8
      })

      assert.is_not_nil(sourceId)
      assert.is_true(AudioManager:isPlaying(sourceId))
    end)

    it("retains asset when playing", function()
      local initialRefCount = AssetManager._cache:getRefCount("test_music") or 0

      local sourceId = AudioManager:play("test_music", {channel = "MUSIC"})

      local newRefCount = AssetManager._cache:getRefCount("test_music") or 0
      assert.is_true(newRefCount > initialRefCount)
    end)

    it("releases asset when playback stops", function()
      local sourceId = AudioManager:play("test_music", {channel = "MUSIC"})
      local playingRefCount = AssetManager._cache:getRefCount("test_music") or 0

      AudioManager:stop(sourceId)

      local stoppedRefCount = AssetManager._cache:getRefCount("test_music") or 0
      assert.is_true(stoppedRefCount < playingRefCount)
    end)
  end)

  describe("multi-channel playback", function()
    it("plays same asset on multiple channels", function()
      local musicSource = AudioManager:play("test_music", {channel = "MUSIC"})
      local sfxSource = AudioManager:play("test_music", {channel = "SFX"})

      assert.is_not_nil(musicSource)
      assert.is_not_nil(sfxSource)
      assert.not_equals(musicSource, sfxSource)
    end)

    it("applies channel-specific volume", function()
      AudioManager:setChannelVolume("MUSIC", 0.5)
      AudioManager:setChannelVolume("SFX", 1.0)

      local musicSource = AudioManager:play("test_music", {channel = "MUSIC", volume = 1.0})
      local sfxSource = AudioManager:play("test_music", {channel = "SFX", volume = 1.0})

      assert.equals(0.5, AudioManager:getChannelVolume("MUSIC"))
      assert.equals(1.0, AudioManager:getChannelVolume("SFX"))
    end)
  end)

  describe("crossfade workflow", function()
    it("crossfades between two assets", function()
      AssetManager:register({
        id = "test_music_2",
        type = "audio",
        sources = {{format = "mp3", path = "test2.mp3"}}
      })
      cacheAsset("test_music_2", "audio")

      local sourceId1 = AudioManager:play("test_music", {channel = "MUSIC"})
      local sourceId2 = AudioManager:crossfade(sourceId1, "test_music_2", {duration = 1.0})

      assert.is_not_nil(sourceId2)
    end)
  end)

  describe("asset lifecycle", function()
    it("handles multiple play/stop cycles", function()
      for i = 1, 5 do
        local sourceId = AudioManager:play("test_music", {channel = "MUSIC"})
        assert.is_not_nil(sourceId)
        AudioManager:stop(sourceId)
      end

      -- Asset should still be registered
      assert.is_not_nil(AssetManager._registry["test_music"])
    end)

    it("cleans up sources on shutdown", function()
      AudioManager:play("test_music", {channel = "MUSIC"})
      AudioManager:play("test_music", {channel = "SFX"})

      AudioManager:shutdown()

      -- Sources should be cleared
      local count = 0
      for _ in pairs(AudioManager._sources or {}) do
        count = count + 1
      end
      assert.equals(0, count)
    end)
  end)
end)
