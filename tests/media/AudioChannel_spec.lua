-- AudioChannel Tests
-- Unit tests for the AudioChannel module

describe("AudioChannel", function()
  local AudioChannel
  local channel

  before_each(function()
    package.loaded["whisker.media.AudioChannel"] = nil
    package.loaded["whisker.media.types"] = nil

    AudioChannel = require("whisker.media.AudioChannel")
    channel = AudioChannel.new("TEST", {
      maxConcurrent = 3,
      volume = 1.0,
      priority = 5
    })
  end)

  describe("initialization", function()
    it("creates channel with config", function()
      assert.equals("TEST", channel.name)
      assert.equals(1.0, channel.volume)
      assert.equals(3, channel.maxConcurrent)
      assert.equals(5, channel.priority)
    end)

    it("creates channel with defaults", function()
      local c = AudioChannel.new("DEFAULT")

      assert.equals("DEFAULT", c.name)
      assert.equals(1.0, c.volume)
      assert.equals(10, c.maxConcurrent)
    end)
  end)

  describe("source management", function()
    local function mockSource(priority)
      local stopped = false
      return {
        priority = priority or 5,
        volume = 1.0,
        baseVolume = 1.0,
        stop = function() stopped = true end,
        updateVolume = function(vol) end,
        isStopped = function() return stopped end
      }
    end

    it("adds source to channel", function()
      local source = mockSource()
      channel:addSource(1, source)

      assert.equals(1, channel:getSourceCount())
    end)

    it("removes source from channel", function()
      local source = mockSource()
      channel:addSource(1, source)

      local removed = channel:removeSource(1)

      assert.is_true(removed)
      assert.equals(0, channel:getSourceCount())
    end)

    it("returns false when removing non-existent source", function()
      local removed = channel:removeSource(999)
      assert.is_false(removed)
    end)

    it("hasSource returns true for existing source", function()
      local source = mockSource()
      channel:addSource(1, source)

      assert.is_true(channel:hasSource(1))
    end)

    it("hasSource returns false for non-existent source", function()
      assert.is_false(channel:hasSource(999))
    end)

    it("getSource returns source by ID", function()
      local source = mockSource()
      channel:addSource(1, source)

      local retrieved = channel:getSource(1)
      assert.equals(source, retrieved)
    end)

    it("getAllSources returns all sources", function()
      channel:addSource(1, mockSource())
      channel:addSource(2, mockSource())

      local sources = channel:getAllSources()

      local count = 0
      for _ in pairs(sources) do count = count + 1 end
      assert.equals(2, count)
    end)
  end)

  describe("concurrent limit", function()
    local function mockSource(priority)
      local stopped = false
      return {
        priority = priority or 5,
        volume = 1.0,
        baseVolume = 1.0,
        stop = function(self) stopped = true end,
        updateVolume = function(vol) end,
        isStopped = function() return stopped end
      }
    end

    it("enforces maxConcurrent limit", function()
      channel:addSource(1, mockSource())
      channel:addSource(2, mockSource())
      channel:addSource(3, mockSource())
      channel:addSource(4, mockSource())

      assert.equals(3, channel:getSourceCount())
    end)

    it("evicts lowest priority source", function()
      channel:addSource(1, mockSource(10)) -- high priority
      channel:addSource(2, mockSource(1))  -- low priority
      channel:addSource(3, mockSource(5))  -- medium priority

      -- This should evict source 2 (lowest priority)
      channel:addSource(4, mockSource(7))

      assert.is_true(channel:hasSource(1))
      assert.is_false(channel:hasSource(2))
      assert.is_true(channel:hasSource(3))
      assert.is_true(channel:hasSource(4))
    end)
  end)

  describe("volume", function()
    it("setVolume updates channel volume", function()
      channel:setVolume(0.5)
      assert.equals(0.5, channel:getVolume())
    end)

    it("volume clamps to 0-1", function()
      channel:setVolume(1.5)
      assert.equals(1.0, channel:getVolume())

      channel:setVolume(-0.5)
      assert.equals(0.0, channel:getVolume())
    end)

    it("getEffectiveVolume includes ducking", function()
      channel:setVolume(1.0)
      channel:duck("OTHER", 0.5)

      assert.equals(0.5, channel:getEffectiveVolume())
    end)

    it("getEffectiveVolume returns 0 when muted", function()
      channel:setVolume(1.0)
      channel:mute()

      assert.equals(0, channel:getEffectiveVolume())
    end)
  end)

  describe("muting", function()
    it("mute sets muted state", function()
      channel:mute()
      assert.is_true(channel:isMuted())
    end)

    it("unmute clears muted state", function()
      channel:mute()
      channel:unmute()
      assert.is_false(channel:isMuted())
    end)
  end)

  describe("ducking", function()
    it("duck applies multiplier", function()
      channel:duck("VOICE", 0.3)

      assert.equals(0.3, channel:getDuckMultiplier())
    end)

    it("unduck removes ducking", function()
      channel:duck("VOICE", 0.3)
      channel:unduck("VOICE")

      assert.equals(1.0, channel:getDuckMultiplier())
    end)

    it("multiple ducks use lowest value", function()
      channel:duck("VOICE", 0.5)
      channel:duck("SFX", 0.3)

      assert.equals(0.3, channel:getDuckMultiplier())
    end)

    it("removing one duck uses next lowest", function()
      channel:duck("VOICE", 0.5)
      channel:duck("SFX", 0.3)
      channel:unduck("SFX")

      assert.equals(0.5, channel:getDuckMultiplier())
    end)
  end)

  describe("channel operations", function()
    local function mockSource()
      local stopped = false
      local paused = false
      return {
        priority = 5,
        volume = 1.0,
        baseVolume = 1.0,
        stop = function(self) stopped = true end,
        pause = function(self) paused = true end,
        resume = function(self) paused = false end,
        updateVolume = function(vol) end,
        isStopped = function() return stopped end,
        isPaused = function() return paused end
      }
    end

    it("stopAll stops all sources", function()
      channel:addSource(1, mockSource())
      channel:addSource(2, mockSource())

      channel:stopAll()

      assert.equals(0, channel:getSourceCount())
    end)

    it("pauseAll pauses all sources", function()
      local source = mockSource()
      channel:addSource(1, source)

      channel:pauseAll()

      assert.is_true(source:isPaused())
    end)

    it("resumeAll resumes all sources", function()
      local source = mockSource()
      channel:addSource(1, source)

      channel:pauseAll()
      channel:resumeAll()

      assert.is_false(source:isPaused())
    end)
  end)

  describe("volume updates to sources", function()
    it("updates source volumes on channel volume change", function()
      local volumeUpdates = {}
      local source = {
        priority = 5,
        volume = 1.0,
        baseVolume = 1.0,
        updateVolume = function(vol)
          table.insert(volumeUpdates, vol)
        end
      }

      channel:addSource(1, source)
      channel:setVolume(0.5)

      assert.is_true(#volumeUpdates > 0)
    end)

    it("updates source volumes on duck", function()
      local volumeUpdates = {}
      local source = {
        priority = 5,
        volume = 1.0,
        baseVolume = 1.0,
        updateVolume = function(vol)
          table.insert(volumeUpdates, vol)
        end
      }

      channel:addSource(1, source)
      channel:duck("VOICE", 0.5)

      assert.is_true(#volumeUpdates > 0)
    end)
  end)
end)
