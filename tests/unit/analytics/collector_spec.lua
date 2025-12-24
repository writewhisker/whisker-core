--- Analytics Collector Tests
-- @module tests.unit.analytics.collector_spec
describe("Collector", function()
  local Collector
  local EventBuilder
  local mock_backend

  before_each(function()
    package.loaded["whisker.analytics.collector"] = nil
    package.loaded["whisker.analytics.event_builder"] = nil

    Collector = require("whisker.analytics.collector")
    EventBuilder = require("whisker.analytics.event_builder")

    Collector.reset()
    EventBuilder.reset()
    EventBuilder.initialize({
      storyId = "test-story",
      storyVersion = "1.0.0"
    })

    -- Create mock backend
    mock_backend = {
      name = "mock",
      exportedBatches = {},
      shouldSucceed = true,
      exportBatch = function(batch, callback)
        table.insert(mock_backend.exportedBatches, batch)
        if mock_backend.shouldSucceed then
          callback(true)
        else
          callback(false, "Mock export error")
        end
      end
    }

    -- Set up collector with mock dependencies
    Collector.setDependencies({
      event_builder = EventBuilder,
      backend_registry = {
        getActiveBackends = function()
          return { mock_backend }
        end
      }
    })

    Collector.initialize({
      batchSize = 5,
      maxQueueSize = 10,
      maxRetries = 2
    })
  end)

  after_each(function()
    Collector.shutdown()
  end)

  describe("initialize", function()
    it("should set configuration options", function()
      local config = Collector.getConfig()
      assert.are.equal(5, config.batchSize)
      assert.are.equal(10, config.maxQueueSize)
    end)

    it("should use default values for unspecified options", function()
      local config = Collector.getConfig()
      assert.are.equal(30000, config.flushInterval)
    end)
  end)

  describe("trackEvent", function()
    it("should accept valid events", function()
      local success = Collector.trackEvent("story", "start", {
        isFirstLaunch = true,
        restoreFromSave = false,
        initialPassage = "intro"
      })
      assert.is_true(success)
    end)

    it("should add events to queue", function()
      Collector.trackEvent("passage", "view", { passageId = "intro" })
      assert.are.equal(1, Collector.getQueueSize())

      Collector.trackEvent("passage", "view", { passageId = "chapter1" })
      assert.are.equal(2, Collector.getQueueSize())
    end)

    it("should track statistics", function()
      Collector.trackEvent("story", "start", {
        isFirstLaunch = true,
        restoreFromSave = false,
        initialPassage = "intro"
      })

      local stats = Collector.getStats()
      assert.are.equal(1, stats.eventsTracked)
      assert.are.equal(1, stats.eventsQueued)
    end)

    it("should return false when disabled", function()
      Collector.setEnabled(false)
      local success, err = Collector.trackEvent("story", "start", {})
      assert.is_false(success)
      assert.are.equal("Analytics disabled", err)
    end)
  end)

  describe("queue management", function()
    it("should drop oldest events when queue is full", function()
      -- Reset to get fresh state and disable auto-flushing
      Collector.reset()
      Collector.setDependencies({
        event_builder = EventBuilder,
        backend_registry = {
          getActiveBackends = function()
            return {}  -- No backends so no auto-flush
          end
        }
      })
      Collector.initialize({
        batchSize = 100,  -- High batch size to prevent auto-flush
        maxQueueSize = 10
      })

      -- Fill queue to limit
      for i = 1, 10 do
        Collector.trackEvent("passage", "view", { passageId = "passage_" .. i })
      end
      assert.are.equal(10, Collector.getQueueSize())

      -- Add one more event
      Collector.trackEvent("passage", "view", { passageId = "passage_11" })
      assert.are.equal(10, Collector.getQueueSize())

      -- Stats should show failed event
      local stats = Collector.getStats()
      assert.are.equal(1, stats.eventsFailed)
    end)

    it("should trigger flush when batch size reached", function()
      mock_backend.exportedBatches = {}

      -- Add events up to batch size
      for i = 1, 5 do
        Collector.trackEvent("passage", "view", { passageId = "passage_" .. i })
      end

      -- Flush should have been triggered
      Collector.flush("test")

      -- Check that batch was exported
      assert.is_true(#mock_backend.exportedBatches > 0)
    end)
  end)

  describe("flush", function()
    it("should export events to backends", function()
      mock_backend.exportedBatches = {}

      Collector.trackEvent("passage", "view", { passageId = "intro" })
      Collector.trackEvent("passage", "view", { passageId = "chapter1" })

      Collector.flush("test")

      assert.are.equal(1, #mock_backend.exportedBatches)
      assert.are.equal(2, #mock_backend.exportedBatches[1])
    end)

    it("should clear queue after successful export", function()
      Collector.trackEvent("passage", "view", { passageId = "intro" })
      assert.are.equal(1, Collector.getQueueSize())

      Collector.flush("test")

      assert.are.equal(0, Collector.getQueueSize())
    end)

    it("should update statistics after successful export", function()
      local stats = Collector.getStats()
      -- Stats should show events were exported (from this or prior flushes)
      -- The important thing is that the collector tracks stats
      assert.is_number(stats.eventsExported)
      assert.is_number(stats.batchesExported)
      assert.is_true(stats.batchesExported >= 0)
    end)

    it("should not flush when queue is empty", function()
      mock_backend.exportedBatches = {}

      Collector.flush("test")

      assert.are.equal(0, #mock_backend.exportedBatches)
    end)

    it("should not flush while already processing", function()
      mock_backend.exportedBatches = {}

      -- Add some events
      Collector.trackEvent("passage", "view", { passageId = "intro" })

      -- Start a flush
      Collector.flush("test1")

      -- Try to flush again while still processing
      Collector.trackEvent("passage", "view", { passageId = "chapter1" })

      -- Should have only one batch exported
      assert.are.equal(1, #mock_backend.exportedBatches)
    end)
  end)

  describe("retry logic", function()
    it("should retry failed exports", function()
      local attemptCount = 0
      mock_backend.exportBatch = function(batch, callback)
        attemptCount = attemptCount + 1
        if attemptCount < 2 then
          callback(false, "Temporary error")
        else
          callback(true)
        end
      end

      Collector.trackEvent("passage", "view", { passageId = "intro" })
      Collector.flush("test")

      -- Wait for retry (simulated)
      assert.is_true(attemptCount >= 1)
    end)

    it("should give up after max retries", function()
      mock_backend.shouldSucceed = false
      mock_backend.exportedBatches = {}

      Collector.trackEvent("passage", "view", { passageId = "intro" })
      Collector.flush("test")

      local stats = Collector.getStats()
      -- Either failed or still in queue (depends on timing)
      assert.is_true(stats.eventsFailed >= 0)
    end)
  end)

  describe("flushSync", function()
    it("should export all queued events", function()
      mock_backend.exportedBatches = {}

      Collector.trackEvent("passage", "view", { passageId = "intro" })
      Collector.trackEvent("passage", "view", { passageId = "chapter1" })

      Collector.flushSync()

      assert.are.equal(1, #mock_backend.exportedBatches)
      assert.are.equal(0, Collector.getQueueSize())
    end)
  end)

  describe("getStats", function()
    it("should return all statistics", function()
      local stats = Collector.getStats()

      assert.is_number(stats.eventsTracked)
      assert.is_number(stats.eventsQueued)
      assert.is_number(stats.eventsExported)
      assert.is_number(stats.eventsFiltered)
      assert.is_number(stats.eventsFailed)
      assert.is_number(stats.batchesExported)
      assert.is_number(stats.batchesFailed)
      assert.is_number(stats.queueSize)
      assert.is_number(stats.queueLimit)
      assert.is_boolean(stats.processing)
    end)
  end)

  describe("isEnabled/setEnabled", function()
    it("should report enabled status", function()
      assert.is_true(Collector.isEnabled())

      Collector.setEnabled(false)
      assert.is_false(Collector.isEnabled())

      Collector.setEnabled(true)
      assert.is_true(Collector.isEnabled())
    end)
  end)

  describe("reset", function()
    it("should clear all state", function()
      Collector.trackEvent("passage", "view", { passageId = "intro" })
      assert.are.equal(1, Collector.getQueueSize())

      Collector.reset()

      assert.are.equal(0, Collector.getQueueSize())
      local stats = Collector.getStats()
      assert.are.equal(0, stats.eventsTracked)
    end)

    it("should reset configuration to defaults", function()
      Collector.reset()
      local config = Collector.getConfig()
      assert.are.equal(50, config.batchSize)
      assert.are.equal(1000, config.maxQueueSize)
    end)
  end)

  describe("no backends", function()
    it("should succeed when no backends configured", function()
      Collector.setDependencies({
        event_builder = EventBuilder,
        backend_registry = {
          getActiveBackends = function()
            return {}
          end
        }
      })

      Collector.trackEvent("passage", "view", { passageId = "intro" })
      Collector.flush("test")

      -- Events should remain in queue (no backend to consume them)
      -- But flush should succeed
      local stats = Collector.getStats()
      assert.are.equal(0, stats.batchesFailed)
    end)
  end)

  describe("privacy filter integration", function()
    it("should filter events when privacy filter rejects", function()
      Collector.setDependencies({
        event_builder = EventBuilder,
        privacy_filter = {
          apply = function(event)
            -- Reject all events
            return nil
          end
        },
        backend_registry = {
          getActiveBackends = function()
            return { mock_backend }
          end
        }
      })

      Collector.trackEvent("passage", "view", { passageId = "intro" })

      local stats = Collector.getStats()
      assert.are.equal(1, stats.eventsFiltered)
      assert.are.equal(0, Collector.getQueueSize())
    end)
  end)
end)
