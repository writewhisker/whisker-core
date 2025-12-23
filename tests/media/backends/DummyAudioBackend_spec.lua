-- DummyAudioBackend Tests
-- Unit tests for the DummyAudioBackend module

describe("DummyAudioBackend", function()
  local DummyAudioBackend
  local backend

  before_each(function()
    package.loaded["whisker.media.backends.DummyAudioBackend"] = nil
    package.loaded["whisker.media.backends.AudioBackend"] = nil

    DummyAudioBackend = require("whisker.media.backends.DummyAudioBackend")
    backend = DummyAudioBackend.new()
  end)

  after_each(function()
    if backend then
      backend:shutdown()
    end
  end)

  describe("initialization", function()
    it("creates new backend instance", function()
      assert.is_not_nil(backend)
    end)

    it("initializes successfully", function()
      local success = backend:initialize()
      assert.is_true(success)
      assert.is_true(backend._initialized)
    end)
  end)

  describe("source creation", function()
    it("creates source from asset data", function()
      backend:initialize()

      local assetData = {
        id = "test",
        metadata = { duration = 30 }
      }

      local source = backend:createSource(assetData, {})

      assert.is_not_nil(source)
      assert.is_number(source.id)
    end)

    it("creates source with default duration", function()
      backend:initialize()

      local source = backend:createSource({}, {})

      assert.is_not_nil(source)
      assert.equals(60, source.duration)
    end)

    it("creates source with metadata duration", function()
      backend:initialize()

      local assetData = {
        metadata = { duration = 120 }
      }

      local source = backend:createSource(assetData, {})

      assert.equals(120, source.duration)
    end)
  end)

  describe("playback", function()
    local source

    before_each(function()
      backend:initialize()
      source = backend:createSource({ metadata = { duration = 30 } }, {})
    end)

    it("play starts playback", function()
      local success = backend:play(source, {})

      assert.is_true(success)
      assert.is_true(source.playing)
      assert.is_false(source.paused)
    end)

    it("play sets volume from options", function()
      backend:play(source, { volume = 0.5 })

      assert.equals(0.5, source.volume)
    end)

    it("play sets loop from options", function()
      backend:play(source, { loop = true })

      assert.is_true(source.looping)
    end)

    it("play returns false for nil source", function()
      local success = backend:play(nil, {})
      assert.is_false(success)
    end)

    it("stop stops playback", function()
      backend:play(source, {})
      local success = backend:stop(source)

      assert.is_true(success)
      assert.is_false(source.playing)
      assert.equals(0, source.position)
    end)

    it("stop returns false for nil source", function()
      local success = backend:stop(nil)
      assert.is_false(success)
    end)

    it("pause pauses playback", function()
      backend:play(source, {})
      local success = backend:pause(source)

      assert.is_true(success)
      assert.is_true(source.paused)
      assert.is_false(source.playing)
    end)

    it("pause returns false for nil source", function()
      local success = backend:pause(nil)
      assert.is_false(success)
    end)

    it("resume resumes paused playback", function()
      backend:play(source, {})
      backend:pause(source)
      local success = backend:resume(source)

      assert.is_true(success)
      assert.is_false(source.paused)
      assert.is_true(source.playing)
    end)

    it("resume returns false for nil source", function()
      local success = backend:resume(nil)
      assert.is_false(success)
    end)
  end)

  describe("volume control", function()
    local source

    before_each(function()
      backend:initialize()
      source = backend:createSource({}, {})
    end)

    it("setVolume changes volume", function()
      local success = backend:setVolume(source, 0.7)

      assert.is_true(success)
      assert.equals(0.7, source.volume)
    end)

    it("setVolume clamps to 0-1", function()
      backend:setVolume(source, 1.5)
      assert.equals(1.0, source.volume)

      backend:setVolume(source, -0.5)
      assert.equals(0.0, source.volume)
    end)

    it("setVolume returns false for nil source", function()
      local success = backend:setVolume(nil, 0.5)
      assert.is_false(success)
    end)

    it("getVolume returns current volume", function()
      source.volume = 0.8
      assert.equals(0.8, backend:getVolume(source))
    end)

    it("getVolume returns 0 for nil source", function()
      assert.equals(0, backend:getVolume(nil))
    end)
  end)

  describe("looping", function()
    local source

    before_each(function()
      backend:initialize()
      source = backend:createSource({}, {})
    end)

    it("setLooping enables looping", function()
      local success = backend:setLooping(source, true)

      assert.is_true(success)
      assert.is_true(source.looping)
    end)

    it("setLooping disables looping", function()
      source.looping = true
      backend:setLooping(source, false)

      assert.is_false(source.looping)
    end)

    it("setLooping returns false for nil source", function()
      local success = backend:setLooping(nil, true)
      assert.is_false(success)
    end)
  end)

  describe("state queries", function()
    local source

    before_each(function()
      backend:initialize()
      source = backend:createSource({}, {})
    end)

    it("isPlaying returns true when playing", function()
      backend:play(source, {})
      assert.is_true(backend:isPlaying(source))
    end)

    it("isPlaying returns false when stopped", function()
      assert.is_false(backend:isPlaying(source))
    end)

    it("isPlaying returns false when paused", function()
      backend:play(source, {})
      backend:pause(source)
      assert.is_false(backend:isPlaying(source))
    end)

    it("isPlaying returns false for nil source", function()
      assert.is_false(backend:isPlaying(nil))
    end)

    it("isPaused returns true when paused", function()
      backend:play(source, {})
      backend:pause(source)
      assert.is_true(backend:isPaused(source))
    end)

    it("isPaused returns false when playing", function()
      backend:play(source, {})
      assert.is_false(backend:isPaused(source))
    end)

    it("isPaused returns false for nil source", function()
      assert.is_false(backend:isPaused(nil))
    end)
  end)

  describe("position", function()
    local source

    before_each(function()
      backend:initialize()
      source = backend:createSource({ metadata = { duration = 60 } }, {})
    end)

    it("getPosition returns current position", function()
      local pos = backend:getPosition(source)
      assert.is_number(pos)
      assert.is_true(pos >= 0)
    end)

    it("getPosition returns 0 for nil source", function()
      assert.equals(0, backend:getPosition(nil))
    end)

    it("setPosition changes position", function()
      local success = backend:setPosition(source, 10)

      assert.is_true(success)
      assert.equals(10, source.position)
    end)

    it("setPosition clamps to 0", function()
      backend:setPosition(source, -5)
      assert.equals(0, source.position)
    end)

    it("setPosition returns false for nil source", function()
      local success = backend:setPosition(nil, 10)
      assert.is_false(success)
    end)
  end)

  describe("duration", function()
    it("getDuration returns source duration", function()
      backend:initialize()
      local source = backend:createSource({ metadata = { duration = 45 } }, {})

      assert.equals(45, backend:getDuration(source))
    end)

    it("getDuration returns 0 for nil source", function()
      assert.equals(0, backend:getDuration(nil))
    end)
  end)

  describe("update", function()
    it("update handles finished non-looping sources", function()
      backend:initialize()
      local source = backend:createSource({ metadata = { duration = 1 } }, {})

      backend:play(source, { loop = false })
      source.position = 1.5 -- Past duration
      source.startTime = os.clock() - 2

      backend:update(0.1)

      assert.is_false(source.playing)
    end)

    it("update loops looping sources", function()
      backend:initialize()
      local source = backend:createSource({ metadata = { duration = 1 } }, {})

      backend:play(source, { loop = true })
      source.position = 1.5 -- Past duration
      source.startTime = os.clock() - 2

      backend:update(0.1)

      assert.is_true(source.playing)
      assert.equals(0, source.position)
    end)
  end)

  describe("shutdown", function()
    it("clears all sources", function()
      backend:initialize()
      backend:createSource({}, {})
      backend:createSource({}, {})

      backend:shutdown()

      assert.is_false(backend._initialized)
    end)
  end)

  describe("testing helpers", function()
    it("getActiveSources returns playing sources", function()
      backend:initialize()
      local source1 = backend:createSource({}, {})
      local source2 = backend:createSource({}, {})

      backend:play(source1, {})

      local active = backend:getActiveSources()

      assert.equals(1, #active)
    end)

    it("getSource returns source by ID", function()
      backend:initialize()
      local source = backend:createSource({}, {})

      local retrieved = backend:getSource(source.id)

      assert.equals(source, retrieved)
    end)
  end)
end)
