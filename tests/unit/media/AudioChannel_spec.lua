-- Tests for AudioChannel module
describe("AudioChannel", function()
  local AudioChannel

  before_each(function()
    package.loaded["whisker.media.AudioChannel"] = nil
    package.loaded["whisker.media.types"] = nil
    AudioChannel = require("whisker.media.AudioChannel")
  end)

  describe("new", function()
    it("creates channel with name", function()
      local channel = AudioChannel.new("MUSIC")
      assert.equals("MUSIC", channel.name)
    end)

    it("creates channel with config", function()
      local channel = AudioChannel.new("SFX", {
        volume = 0.8,
        maxConcurrent = 5,
        priority = 10
      })

      assert.equals(0.8, channel.volume)
      assert.equals(5, channel.maxConcurrent)
      assert.equals(10, channel.priority)
    end)
  end)

  describe("addSource", function()
    it("adds a source", function()
      local channel = AudioChannel.new("TEST")
      local source = {id = 1, volume = 1.0}

      channel:addSource(1, source)

      assert.equals(1, channel:getSourceCount())
      assert.is_true(channel:hasSource(1))
    end)

    it("enforces concurrent limit", function()
      local channel = AudioChannel.new("TEST", {maxConcurrent = 2})

      local stopped = false
      local source1 = {id = 1, stop = function() stopped = true end}
      local source2 = {id = 2, stop = function() end}
      local source3 = {id = 3, stop = function() end}

      channel:addSource(1, source1)
      channel:addSource(2, source2)
      channel:addSource(3, source3)

      assert.equals(2, channel:getSourceCount())
      assert.is_true(stopped)
    end)
  end)

  describe("removeSource", function()
    it("removes a source", function()
      local channel = AudioChannel.new("TEST")
      channel:addSource(1, {id = 1})

      local result = channel:removeSource(1)

      assert.is_true(result)
      assert.equals(0, channel:getSourceCount())
    end)

    it("returns false for missing source", function()
      local channel = AudioChannel.new("TEST")
      assert.is_false(channel:removeSource(999))
    end)
  end)

  describe("volume", function()
    it("sets and gets volume", function()
      local channel = AudioChannel.new("TEST")
      channel:setVolume(0.5)
      assert.equals(0.5, channel:getVolume())
    end)

    it("clamps volume to valid range", function()
      local channel = AudioChannel.new("TEST")

      channel:setVolume(1.5)
      assert.equals(1, channel:getVolume())

      channel:setVolume(-0.5)
      assert.equals(0, channel:getVolume())
    end)

    it("updates source volumes when channel volume changes", function()
      local channel = AudioChannel.new("TEST")
      local volumeSet = nil
      local source = {
        volume = 1.0,
        baseVolume = 1.0,
        setVolume = function(s, v) volumeSet = v end
      }

      channel:addSource(1, source)
      channel:setVolume(0.5)

      assert.is_not_nil(volumeSet)
    end)
  end)

  describe("mute and unmute", function()
    it("mutes channel", function()
      local channel = AudioChannel.new("TEST", {volume = 0.8})
      channel:mute()

      assert.is_true(channel:isMuted())
      assert.equals(0, channel:getEffectiveVolume())
    end)

    it("unmutes channel", function()
      local channel = AudioChannel.new("TEST", {volume = 0.8})
      channel:mute()
      channel:unmute()

      assert.is_false(channel:isMuted())
      assert.equals(0.8, channel:getEffectiveVolume())
    end)
  end)

  describe("ducking", function()
    it("applies duck multiplier", function()
      local channel = AudioChannel.new("MUSIC", {volume = 1.0})

      channel:duck("VOICE", 0.3)

      assert.equals(0.3, channel:getDuckMultiplier())
      assert.equals(0.3, channel:getEffectiveVolume())
    end)

    it("removes ducking", function()
      local channel = AudioChannel.new("MUSIC", {volume = 1.0})
      channel:duck("VOICE", 0.3)
      channel:unduck("VOICE")

      assert.equals(1.0, channel:getDuckMultiplier())
    end)

    it("uses lowest duck amount when multiple ducks active", function()
      local channel = AudioChannel.new("MUSIC", {volume = 1.0})

      channel:duck("VOICE", 0.3)
      channel:duck("NARRATION", 0.5)

      assert.equals(0.3, channel:getDuckMultiplier())
    end)
  end)

  describe("stopAll", function()
    it("stops all sources", function()
      local channel = AudioChannel.new("TEST")
      local stopped = {}

      for i = 1, 3 do
        channel:addSource(i, {
          id = i,
          stop = function() table.insert(stopped, i) end
        })
      end

      channel:stopAll()

      assert.equals(3, #stopped)
      assert.equals(0, channel:getSourceCount())
    end)
  end)

  describe("pauseAll and resumeAll", function()
    it("pauses all sources", function()
      local channel = AudioChannel.new("TEST")
      local paused = 0

      channel:addSource(1, {pause = function() paused = paused + 1 end})
      channel:addSource(2, {pause = function() paused = paused + 1 end})

      channel:pauseAll()

      assert.equals(2, paused)
    end)

    it("resumes all sources", function()
      local channel = AudioChannel.new("TEST")
      local resumed = 0

      channel:addSource(1, {resume = function() resumed = resumed + 1 end})
      channel:addSource(2, {resume = function() resumed = resumed + 1 end})

      channel:resumeAll()

      assert.equals(2, resumed)
    end)
  end)

  describe("getAllSources", function()
    it("returns all sources", function()
      local channel = AudioChannel.new("TEST")
      channel:addSource(1, {id = 1})
      channel:addSource(2, {id = 2})

      local sources = channel:getAllSources()

      assert.is_not_nil(sources[1])
      assert.is_not_nil(sources[2])
    end)
  end)

  describe("getEffectiveVolume", function()
    it("combines volume and duck multiplier", function()
      local channel = AudioChannel.new("TEST", {volume = 0.8})
      channel:duck("OTHER", 0.5)

      assert.equals(0.4, channel:getEffectiveVolume())
    end)

    it("returns 0 when muted", function()
      local channel = AudioChannel.new("TEST", {volume = 0.8})
      channel:mute()

      assert.equals(0, channel:getEffectiveVolume())
    end)
  end)
end)
