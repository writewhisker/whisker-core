-- Tests for DummyAudioBackend
describe("DummyAudioBackend", function()
  local DummyAudioBackend

  before_each(function()
    package.loaded["whisker.media.backends.DummyAudioBackend"] = nil
    package.loaded["whisker.media.backends.AudioBackend"] = nil
    DummyAudioBackend = require("whisker.media.backends.DummyAudioBackend")
  end)

  describe("initialize", function()
    it("initializes successfully", function()
      local backend = DummyAudioBackend.new()
      local result = backend:initialize()
      assert.is_true(result)
    end)
  end)

  describe("createSource", function()
    it("creates a source from asset data", function()
      local backend = DummyAudioBackend.new()
      backend:initialize()

      local source = backend:createSource({
        id = "test",
        path = "test.mp3",
        metadata = {duration = 120}
      })

      assert.is_not_nil(source)
      assert.is_number(source.id)
      assert.equals(120, source.duration)
    end)

    it("creates source with default duration", function()
      local backend = DummyAudioBackend.new()
      backend:initialize()

      local source = backend:createSource({id = "test"})

      assert.is_not_nil(source)
      assert.equals(60, source.duration)
    end)
  end)

  describe("play", function()
    it("plays a source", function()
      local backend = DummyAudioBackend.new()
      backend:initialize()

      local source = backend:createSource({id = "test"})
      local result = backend:play(source)

      assert.is_true(result)
      assert.is_true(backend:isPlaying(source))
    end)

    it("applies options when playing", function()
      local backend = DummyAudioBackend.new()
      backend:initialize()

      local source = backend:createSource({id = "test"})
      backend:play(source, {volume = 0.5, loop = true})

      assert.equals(0.5, backend:getVolume(source))
      assert.is_true(source.looping)
    end)

    it("returns false for nil source", function()
      local backend = DummyAudioBackend.new()
      assert.is_false(backend:play(nil))
    end)
  end)

  describe("stop", function()
    it("stops a playing source", function()
      local backend = DummyAudioBackend.new()
      backend:initialize()

      local source = backend:createSource({id = "test"})
      backend:play(source)
      backend:stop(source)

      assert.is_false(backend:isPlaying(source))
      assert.equals(0, backend:getPosition(source))
    end)
  end)

  describe("pause and resume", function()
    it("pauses a playing source", function()
      local backend = DummyAudioBackend.new()
      backend:initialize()

      local source = backend:createSource({id = "test"})
      backend:play(source)
      backend:pause(source)

      assert.is_false(backend:isPlaying(source))
      assert.is_true(backend:isPaused(source))
    end)

    it("resumes a paused source", function()
      local backend = DummyAudioBackend.new()
      backend:initialize()

      local source = backend:createSource({id = "test"})
      backend:play(source)
      backend:pause(source)
      backend:resume(source)

      assert.is_true(backend:isPlaying(source))
      assert.is_false(backend:isPaused(source))
    end)
  end)

  describe("volume", function()
    it("sets and gets volume", function()
      local backend = DummyAudioBackend.new()
      backend:initialize()

      local source = backend:createSource({id = "test"})
      backend:setVolume(source, 0.7)

      assert.equals(0.7, backend:getVolume(source))
    end)

    it("clamps volume to 0-1 range", function()
      local backend = DummyAudioBackend.new()
      backend:initialize()

      local source = backend:createSource({id = "test"})

      backend:setVolume(source, 1.5)
      assert.equals(1, backend:getVolume(source))

      backend:setVolume(source, -0.5)
      assert.equals(0, backend:getVolume(source))
    end)
  end)

  describe("looping", function()
    it("sets looping", function()
      local backend = DummyAudioBackend.new()
      backend:initialize()

      local source = backend:createSource({id = "test"})
      backend:setLooping(source, true)

      assert.is_true(source.looping)
    end)
  end)

  describe("position", function()
    it("sets and gets position", function()
      local backend = DummyAudioBackend.new()
      backend:initialize()

      local source = backend:createSource({id = "test"})
      backend:setPosition(source, 30)

      assert.equals(30, backend:getPosition(source))
    end)

    it("clamps position to 0 minimum", function()
      local backend = DummyAudioBackend.new()
      backend:initialize()

      local source = backend:createSource({id = "test"})
      backend:setPosition(source, -10)

      assert.equals(0, backend:getPosition(source))
    end)
  end)

  describe("duration", function()
    it("returns source duration", function()
      local backend = DummyAudioBackend.new()
      backend:initialize()

      local source = backend:createSource({
        id = "test",
        metadata = {duration = 180}
      })

      assert.equals(180, backend:getDuration(source))
    end)
  end)

  describe("update", function()
    it("handles source completion", function()
      local backend = DummyAudioBackend.new()
      backend:initialize()

      local source = backend:createSource({
        id = "test",
        metadata = {duration = 0.001}
      })

      backend:play(source)
      source.position = source.duration + 1

      backend:update(0.016)

      assert.is_false(backend:isPlaying(source))
    end)

    it("loops playing source when looping enabled", function()
      local backend = DummyAudioBackend.new()
      backend:initialize()

      local source = backend:createSource({
        id = "test",
        metadata = {duration = 0.001}
      })

      backend:play(source, {loop = true})
      source.position = source.duration + 1

      backend:update(0.016)

      assert.is_true(backend:isPlaying(source))
      assert.equals(0, source.position)
    end)
  end)

  describe("shutdown", function()
    it("clears all sources", function()
      local backend = DummyAudioBackend.new()
      backend:initialize()

      backend:createSource({id = "test1"})
      backend:createSource({id = "test2"})

      backend:shutdown()

      assert.equals(0, #backend:getActiveSources())
    end)
  end)

  describe("getActiveSources", function()
    it("returns only playing sources", function()
      local backend = DummyAudioBackend.new()
      backend:initialize()

      local source1 = backend:createSource({id = "test1"})
      local source2 = backend:createSource({id = "test2"})

      backend:play(source1)

      local active = backend:getActiveSources()
      assert.equals(1, #active)
      assert.equals(source1.id, active[1].id)
    end)
  end)
end)
