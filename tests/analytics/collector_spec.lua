--- Unit tests for Analytics Collector
-- @module tests.analytics.collector_spec

describe("Collector", function()
  local Collector
  local mockEventBuilder
  local mockPrivacyFilter
  local mockBackendRegistry

  before_each(function()
    package.loaded["whisker.analytics.collector"] = nil
    Collector = require("whisker.analytics.collector")
    Collector.reset()

    -- Create mock event builder
    mockEventBuilder = {
      buildEvent = function(category, action, metadata)
        return {
          category = category,
          action = action,
          timestamp = os.time() * 1000,
          sessionId = "test-session",
          storyId = "test-story",
          metadata = metadata or {}
        }
      end
    }

    -- Create mock privacy filter
    mockPrivacyFilter = {
      apply = function(event)
        return event -- Pass through by default
      end
    }

    -- Create mock backend registry
    local exportedBatches = {}
    mockBackendRegistry = {
      _exportedBatches = exportedBatches,
      getActiveBackends = function()
        return {
          {
            name = "mock",
            exportBatch = function(batch, callback)
              table.insert(exportedBatches, batch)
              callback(true)
            end
          }
        }
      end,
      clearExported = function()
        exportedBatches = {}
        mockBackendRegistry._exportedBatches = exportedBatches
      end
    }
  end)

  describe("initialize()", function()
    it("should initialize with default config", function()
      Collector.initialize()
      local config = Collector.getConfig()
      assert.are.equal(50, config.batchSize)
      assert.are.equal(30000, config.flushInterval)
      assert.are.equal(1000, config.maxQueueSize)
    end)

    it("should initialize with custom config", function()
      Collector.initialize({
        batchSize = 25,
        flushInterval = 15000,
        maxQueueSize = 500
      })

      local config = Collector.getConfig()
      assert.are.equal(25, config.batchSize)
      assert.are.equal(15000, config.flushInterval)
      assert.are.equal(500, config.maxQueueSize)
    end)

    it("should be enabled by default", function()
      Collector.initialize()
      assert.is_true(Collector.isEnabled())
    end)
  end)

  describe("setDependencies()", function()
    it("should set event builder dependency", function()
      Collector.setDependencies({ event_builder = mockEventBuilder })
      Collector.initialize()

      local success = Collector.trackEvent("story", "start", {})
      assert.is_true(success)
    end)

    it("should set privacy filter dependency", function()
      local filtered = false
      mockPrivacyFilter.apply = function(event)
        filtered = true
        return event
      end

      Collector.setDependencies({
        event_builder = mockEventBuilder,
        privacy_filter = mockPrivacyFilter
      })
      Collector.initialize()

      Collector.trackEvent("story", "start", {})
      assert.is_true(filtered)
    end)

    it("should set backend registry dependency", function()
      Collector.setDependencies({
        event_builder = mockEventBuilder,
        backend_registry = mockBackendRegistry
      })
      Collector.initialize({ batchSize = 1 })

      Collector.trackEvent("story", "start", {})
      -- Trigger manual flush since we don't have timers
      Collector.flushSync()

      assert.is_true(#mockBackendRegistry._exportedBatches > 0)
    end)
  end)

  describe("trackEvent()", function()
    before_each(function()
      Collector.setDependencies({
        event_builder = mockEventBuilder,
        privacy_filter = mockPrivacyFilter,
        backend_registry = mockBackendRegistry
      })
      Collector.initialize({ batchSize = 100 }) -- Large batch size to prevent auto-flush
    end)

    it("should track event and add to queue", function()
      local success = Collector.trackEvent("story", "start", {})
      assert.is_true(success)
      assert.are.equal(1, Collector.getQueueSize())
    end)

    it("should increment eventsTracked stat", function()
      Collector.trackEvent("story", "start", {})
      Collector.trackEvent("passage", "view", { passageId = "test" })

      local stats = Collector.getStats()
      assert.are.equal(2, stats.eventsTracked)
    end)

    it("should reject events when disabled", function()
      Collector.setEnabled(false)
      local success, err = Collector.trackEvent("story", "start", {})
      assert.is_false(success)
      assert.is_not_nil(err)
    end)

    it("should filter events through privacy filter", function()
      local filterCalled = false
      mockPrivacyFilter.apply = function(event)
        filterCalled = true
        return nil -- Filter out event
      end

      Collector.setDependencies({
        event_builder = mockEventBuilder,
        privacy_filter = mockPrivacyFilter
      })

      local success = Collector.trackEvent("story", "start", {})
      assert.is_true(success) -- Success even when filtered
      assert.is_true(filterCalled)
      assert.are.equal(0, Collector.getQueueSize()) -- Event was filtered
    end)

    it("should increment eventsFiltered stat when filtered", function()
      mockPrivacyFilter.apply = function(event)
        return nil
      end

      Collector.setDependencies({
        event_builder = mockEventBuilder,
        privacy_filter = mockPrivacyFilter
      })

      Collector.trackEvent("story", "start", {})
      local stats = Collector.getStats()
      assert.are.equal(1, stats.eventsFiltered)
    end)

    it("should drop oldest event when queue is full", function()
      Collector.initialize({ maxQueueSize = 3, batchSize = 100 })
      Collector.setDependencies({ event_builder = mockEventBuilder })

      Collector.trackEvent("story", "start", { id = 1 })
      Collector.trackEvent("passage", "view", { id = 2 })
      Collector.trackEvent("passage", "view", { id = 3 })
      Collector.trackEvent("passage", "view", { id = 4 }) -- Should drop first

      assert.are.equal(3, Collector.getQueueSize())
    end)
  end)

  describe("flush()", function()
    before_each(function()
      mockBackendRegistry.clearExported()
      Collector.setDependencies({
        event_builder = mockEventBuilder,
        backend_registry = mockBackendRegistry
      })
      Collector.initialize({ batchSize = 2 })
    end)

    it("should not flush empty queue", function()
      Collector.flush("test")
      assert.are.equal(0, #mockBackendRegistry._exportedBatches)
    end)

    it("should export batch when batch size reached", function()
      Collector.trackEvent("story", "start", {})
      Collector.trackEvent("passage", "view", { passageId = "test" })
      Collector.flushSync()

      assert.is_true(#mockBackendRegistry._exportedBatches > 0)
    end)
  end)

  describe("flushSync()", function()
    before_each(function()
      mockBackendRegistry.clearExported()
      Collector.setDependencies({
        event_builder = mockEventBuilder,
        backend_registry = mockBackendRegistry
      })
      Collector.initialize({ batchSize = 100 })
    end)

    it("should flush all queued events", function()
      Collector.trackEvent("story", "start", {})
      Collector.trackEvent("passage", "view", { passageId = "test" })
      Collector.trackEvent("choice", "selected", { choiceId = "a" })

      Collector.flushSync()

      assert.are.equal(0, Collector.getQueueSize())
    end)

    it("should export to all backends", function()
      Collector.trackEvent("story", "start", {})
      Collector.flushSync()

      assert.are.equal(1, #mockBackendRegistry._exportedBatches)
      assert.are.equal(1, #mockBackendRegistry._exportedBatches[1])
    end)

    it("should update eventsExported stat", function()
      Collector.trackEvent("story", "start", {})
      Collector.trackEvent("passage", "view", { passageId = "test" })
      Collector.flushSync()

      local stats = Collector.getStats()
      assert.are.equal(2, stats.eventsExported)
    end)

    it("should increment batchesExported stat", function()
      Collector.trackEvent("story", "start", {})
      Collector.flushSync()

      local stats = Collector.getStats()
      assert.are.equal(1, stats.batchesExported)
    end)
  end)

  describe("getStats()", function()
    before_each(function()
      Collector.setDependencies({ event_builder = mockEventBuilder })
      Collector.initialize({ batchSize = 100 })
    end)

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

    it("should reflect current queue size", function()
      Collector.trackEvent("story", "start", {})
      Collector.trackEvent("passage", "view", { passageId = "test" })

      local stats = Collector.getStats()
      assert.are.equal(2, stats.queueSize)
    end)
  end)

  describe("getQueueSize()", function()
    before_each(function()
      Collector.setDependencies({ event_builder = mockEventBuilder })
      Collector.initialize({ batchSize = 100 })
    end)

    it("should return zero for empty queue", function()
      assert.are.equal(0, Collector.getQueueSize())
    end)

    it("should return correct queue size", function()
      Collector.trackEvent("story", "start", {})
      Collector.trackEvent("passage", "view", { passageId = "test" })
      assert.are.equal(2, Collector.getQueueSize())
    end)
  end)

  describe("isEnabled()", function()
    it("should return true when enabled", function()
      Collector.initialize()
      assert.is_true(Collector.isEnabled())
    end)

    it("should return false when disabled", function()
      Collector.initialize({ enabled = false })
      assert.is_false(Collector.isEnabled())
    end)
  end)

  describe("setEnabled()", function()
    it("should enable collector", function()
      Collector.initialize({ enabled = false })
      Collector.setEnabled(true)
      assert.is_true(Collector.isEnabled())
    end)

    it("should disable collector", function()
      Collector.initialize()
      Collector.setEnabled(false)
      assert.is_false(Collector.isEnabled())
    end)
  end)

  describe("shutdown()", function()
    before_each(function()
      mockBackendRegistry.clearExported()
      Collector.setDependencies({
        event_builder = mockEventBuilder,
        backend_registry = mockBackendRegistry
      })
      Collector.initialize({ batchSize = 100 })
    end)

    it("should flush remaining events", function()
      Collector.trackEvent("story", "start", {})
      Collector.trackEvent("passage", "view", { passageId = "test" })

      Collector.shutdown()

      assert.are.equal(0, Collector.getQueueSize())
    end)
  end)

  describe("reset()", function()
    it("should clear queue", function()
      Collector.setDependencies({ event_builder = mockEventBuilder })
      Collector.initialize({ batchSize = 100 })

      Collector.trackEvent("story", "start", {})
      Collector.reset()

      assert.are.equal(0, Collector.getQueueSize())
    end)

    it("should reset statistics", function()
      Collector.setDependencies({ event_builder = mockEventBuilder })
      Collector.initialize()

      Collector.trackEvent("story", "start", {})
      Collector.reset()

      local stats = Collector.getStats()
      assert.are.equal(0, stats.eventsTracked)
    end)

    it("should reset config to defaults", function()
      Collector.initialize({ batchSize = 10 })
      Collector.reset()

      local config = Collector.getConfig()
      assert.are.equal(50, config.batchSize)
    end)
  end)
end)
