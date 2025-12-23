--- Unit tests for Built-in Metrics
-- @module tests.analytics.metrics_spec

describe("Metrics", function()
  local Metrics

  before_each(function()
    package.loaded["whisker.analytics.metrics.init"] = nil
    Metrics = require("whisker.analytics.metrics.init")
    Metrics.reset()
    Metrics.initialize()
  end)

  local function createEvent(category, action, metadata, timestamp, sessionId)
    return {
      category = category,
      action = action,
      timestamp = timestamp or os.time() * 1000,
      sessionId = sessionId or "session-1",
      storyId = "test-story",
      metadata = metadata or {}
    }
  end

  describe("initialize()", function()
    it("should initialize with empty events", function()
      Metrics.reset()
      Metrics.initialize()
      local counts = Metrics.calculateEventCounts()
      assert.are.equal(0, counts.total)
    end)
  end)

  describe("addEvent()", function()
    it("should add event to collection", function()
      Metrics.addEvent(createEvent("story", "start"))
      local counts = Metrics.calculateEventCounts()
      assert.are.equal(1, counts.total)
    end)

    it("should invalidate cache when event added", function()
      Metrics.addEvent(createEvent("story", "start"))
      local metrics1 = Metrics.getAllMetrics()

      Metrics.addEvent(createEvent("story", "complete"))
      local metrics2 = Metrics.getAllMetrics()

      -- Should have recalculated
      assert.are.equal(1, metrics1.completionRate.starts)
      assert.are.equal(1, metrics2.completionRate.starts)
      assert.are.equal(0, metrics1.completionRate.completes)
      assert.are.equal(1, metrics2.completionRate.completes)
    end)
  end)

  describe("calculateSessionDuration()", function()
    it("should return zero values for no sessions", function()
      local result = Metrics.calculateSessionDuration()
      assert.are.equal(0, result.totalSessions)
      assert.are.equal(0, result.averageDuration)
    end)

    it("should calculate single session duration", function()
      local startTime = os.time() * 1000
      local endTime = startTime + 60000 -- 1 minute later

      Metrics.addEvent(createEvent("story", "start", {}, startTime, "session-1"))
      Metrics.addEvent(createEvent("passage", "view", { passageId = "opening" }, startTime + 10000, "session-1"))
      Metrics.addEvent(createEvent("passage", "view", { passageId = "chapter_1" }, endTime, "session-1"))

      local result = Metrics.calculateSessionDuration()
      assert.are.equal(1, result.totalSessions)
      assert.are.equal(60000, result.averageDuration)
      assert.are.equal(60000, result.minDuration)
      assert.are.equal(60000, result.maxDuration)
    end)

    it("should calculate multiple session durations", function()
      local startTime = os.time() * 1000

      -- Session 1: 30 seconds
      Metrics.addEvent(createEvent("story", "start", {}, startTime, "session-1"))
      Metrics.addEvent(createEvent("passage", "view", { passageId = "end" }, startTime + 30000, "session-1"))

      -- Session 2: 60 seconds
      Metrics.addEvent(createEvent("story", "start", {}, startTime, "session-2"))
      Metrics.addEvent(createEvent("passage", "view", { passageId = "end" }, startTime + 60000, "session-2"))

      local result = Metrics.calculateSessionDuration()
      assert.are.equal(2, result.totalSessions)
      assert.are.equal(45000, result.averageDuration) -- (30000 + 60000) / 2
      assert.are.equal(30000, result.minDuration)
      assert.are.equal(60000, result.maxDuration)
      assert.are.equal(90000, result.totalDuration)
    end)
  end)

  describe("calculateCompletionRate()", function()
    it("should return zero for no events", function()
      local result = Metrics.calculateCompletionRate()
      assert.are.equal(0, result.starts)
      assert.are.equal(0, result.completes)
      assert.are.equal(0, result.completionRate)
    end)

    it("should calculate completion rate", function()
      Metrics.addEvent(createEvent("story", "start", {}, nil, "session-1"))
      Metrics.addEvent(createEvent("story", "start", {}, nil, "session-2"))
      Metrics.addEvent(createEvent("story", "complete", {}, nil, "session-1"))

      local result = Metrics.calculateCompletionRate()
      assert.are.equal(2, result.starts)
      assert.are.equal(1, result.completes)
      assert.are.equal(0.5, result.completionRate)
    end)

    it("should calculate abandon rate", function()
      Metrics.addEvent(createEvent("story", "start", {}, nil, "session-1"))
      Metrics.addEvent(createEvent("story", "start", {}, nil, "session-2"))
      Metrics.addEvent(createEvent("story", "abandon", {}, nil, "session-2"))

      local result = Metrics.calculateCompletionRate()
      assert.are.equal(2, result.starts)
      assert.are.equal(1, result.abandons)
      assert.are.equal(0.5, result.abandonRate)
    end)

    it("should handle 100% completion rate", function()
      Metrics.addEvent(createEvent("story", "start"))
      Metrics.addEvent(createEvent("story", "complete"))

      local result = Metrics.calculateCompletionRate()
      assert.are.equal(1, result.completionRate)
    end)

    it("should handle 0% completion rate", function()
      Metrics.addEvent(createEvent("story", "start"))
      Metrics.addEvent(createEvent("story", "abandon"))

      local result = Metrics.calculateCompletionRate()
      assert.are.equal(0, result.completionRate)
      assert.are.equal(1, result.abandonRate)
    end)
  end)

  describe("calculateChoiceDistribution()", function()
    it("should return empty distribution for no choices", function()
      local result = Metrics.calculateChoiceDistribution()
      assert.are.equal(0, result.totalChoices)
      assert.are.equal(0, result.uniqueChoices)
    end)

    it("should calculate choice distribution", function()
      Metrics.addEvent(createEvent("choice", "selected", { passageId = "forest", choiceId = "left" }))
      Metrics.addEvent(createEvent("choice", "selected", { passageId = "forest", choiceId = "left" }))
      Metrics.addEvent(createEvent("choice", "selected", { passageId = "forest", choiceId = "right" }))

      local result = Metrics.calculateChoiceDistribution()
      assert.are.equal(3, result.totalChoices)
      assert.are.equal(2, result.uniqueChoices)
      assert.are.equal(2, result.distribution["left"].count)
      assert.are.equal(1, result.distribution["right"].count)
    end)

    it("should calculate percentages", function()
      Metrics.addEvent(createEvent("choice", "selected", { passageId = "forest", choiceId = "a" }))
      Metrics.addEvent(createEvent("choice", "selected", { passageId = "forest", choiceId = "a" }))
      Metrics.addEvent(createEvent("choice", "selected", { passageId = "forest", choiceId = "a" }))
      Metrics.addEvent(createEvent("choice", "selected", { passageId = "forest", choiceId = "b" }))

      local result = Metrics.calculateChoiceDistribution()
      assert.are.equal(75, result.distribution["a"].percentage)
      assert.are.equal(25, result.distribution["b"].percentage)
    end)

    it("should track choices by passage", function()
      Metrics.addEvent(createEvent("choice", "selected", { passageId = "forest", choiceId = "left" }))
      Metrics.addEvent(createEvent("choice", "selected", { passageId = "cave", choiceId = "enter" }))

      local result = Metrics.calculateChoiceDistribution()
      assert.is_not_nil(result.byPassage["forest"])
      assert.is_not_nil(result.byPassage["cave"])
      assert.are.equal(1, result.byPassage["forest"]["left"])
      assert.are.equal(1, result.byPassage["cave"]["enter"])
    end)
  end)

  describe("calculatePassageFlow()", function()
    it("should return empty flow for no passage views", function()
      local result = Metrics.calculatePassageFlow()
      assert.are.equal(0, result.totalPassageViews)
      assert.are.equal(0, result.uniquePassages)
    end)

    it("should count passage views", function()
      Metrics.addEvent(createEvent("passage", "view", { passageId = "opening" }))
      Metrics.addEvent(createEvent("passage", "view", { passageId = "forest" }))
      Metrics.addEvent(createEvent("passage", "view", { passageId = "forest" }))

      local result = Metrics.calculatePassageFlow()
      assert.are.equal(3, result.totalPassageViews)
      assert.are.equal(2, result.uniquePassages)
      assert.are.equal(1, result.passageViews["opening"])
      assert.are.equal(2, result.passageViews["forest"])
    end)

    it("should track transitions between passages", function()
      Metrics.addEvent(createEvent("passage", "view", { passageId = "opening" }))
      Metrics.addEvent(createEvent("passage", "view", { passageId = "forest" }))
      Metrics.addEvent(createEvent("passage", "view", { passageId = "cave" }))

      local result = Metrics.calculatePassageFlow()
      assert.are.equal(1, result.transitions["opening -> forest"])
      assert.are.equal(1, result.transitions["forest -> cave"])
    end)

    it("should return top passages sorted by views", function()
      Metrics.addEvent(createEvent("passage", "view", { passageId = "opening" }))
      Metrics.addEvent(createEvent("passage", "view", { passageId = "forest" }))
      Metrics.addEvent(createEvent("passage", "view", { passageId = "forest" }))
      Metrics.addEvent(createEvent("passage", "view", { passageId = "forest" }))
      Metrics.addEvent(createEvent("passage", "view", { passageId = "cave" }))
      Metrics.addEvent(createEvent("passage", "view", { passageId = "cave" }))

      local result = Metrics.calculatePassageFlow()
      assert.are.equal("forest", result.topPassages[1].passageId)
      assert.are.equal(3, result.topPassages[1].views)
      assert.are.equal("cave", result.topPassages[2].passageId)
      assert.are.equal(2, result.topPassages[2].views)
    end)
  end)

  describe("calculateEngagement()", function()
    it("should return base engagement for no events", function()
      local result = Metrics.calculateEngagement()
      assert.are.equal(0, result.totalEvents)
      assert.are.equal(0, result.engagementScore)
    end)

    it("should track time per passage", function()
      Metrics.addEvent(createEvent("passage", "view", { passageId = "forest" }))
      Metrics.addEvent(createEvent("passage", "exit", { passageId = "forest", timeOnPassage = 5000 }))
      Metrics.addEvent(createEvent("passage", "exit", { passageId = "forest", timeOnPassage = 10000 }))

      local result = Metrics.calculateEngagement()
      assert.are.equal(7500, result.avgTimePerPassage["forest"])
    end)

    it("should count total events", function()
      Metrics.addEvent(createEvent("story", "start"))
      Metrics.addEvent(createEvent("passage", "view", { passageId = "forest" }))
      Metrics.addEvent(createEvent("choice", "selected", { passageId = "forest", choiceId = "a" }))

      local result = Metrics.calculateEngagement()
      assert.are.equal(3, result.totalEvents)
    end)
  end)

  describe("calculateEventCounts()", function()
    it("should return zero for no events", function()
      local result = Metrics.calculateEventCounts()
      assert.are.equal(0, result.total)
    end)

    it("should count events by category", function()
      Metrics.addEvent(createEvent("story", "start"))
      Metrics.addEvent(createEvent("passage", "view", { passageId = "forest" }))
      Metrics.addEvent(createEvent("passage", "view", { passageId = "cave" }))
      Metrics.addEvent(createEvent("choice", "selected", { passageId = "forest", choiceId = "a" }))

      local result = Metrics.calculateEventCounts()
      assert.are.equal(4, result.total)
      assert.are.equal(1, result.byCategory["story"])
      assert.are.equal(2, result.byCategory["passage"])
      assert.are.equal(1, result.byCategory["choice"])
    end)

    it("should count events by action", function()
      Metrics.addEvent(createEvent("story", "start"))
      Metrics.addEvent(createEvent("passage", "view", { passageId = "forest" }))
      Metrics.addEvent(createEvent("passage", "view", { passageId = "cave" }))

      local result = Metrics.calculateEventCounts()
      assert.are.equal(1, result.byAction["start"])
      assert.are.equal(2, result.byAction["view"])
    end)

    it("should count events by category.action", function()
      Metrics.addEvent(createEvent("story", "start"))
      Metrics.addEvent(createEvent("passage", "view", { passageId = "forest" }))
      Metrics.addEvent(createEvent("choice", "selected", { passageId = "forest", choiceId = "a" }))

      local result = Metrics.calculateEventCounts()
      assert.are.equal(1, result.byCategoryAction["story.start"])
      assert.are.equal(1, result.byCategoryAction["passage.view"])
      assert.are.equal(1, result.byCategoryAction["choice.selected"])
    end)
  end)

  describe("getAllMetrics()", function()
    it("should return all metrics", function()
      Metrics.addEvent(createEvent("story", "start"))
      Metrics.addEvent(createEvent("passage", "view", { passageId = "forest" }))

      local all = Metrics.getAllMetrics()
      assert.is_not_nil(all.sessionDuration)
      assert.is_not_nil(all.completionRate)
      assert.is_not_nil(all.choiceDistribution)
      assert.is_not_nil(all.passageFlow)
      assert.is_not_nil(all.engagement)
      assert.is_not_nil(all.eventCounts)
    end)

    it("should use cache on subsequent calls", function()
      Metrics.addEvent(createEvent("story", "start"))

      local all1 = Metrics.getAllMetrics()
      local all2 = Metrics.getAllMetrics()

      -- Should be same reference (cached)
      assert.are.equal(all1, all2)
    end)
  end)

  describe("getMetric()", function()
    it("should return specific metric", function()
      Metrics.addEvent(createEvent("story", "start"))
      Metrics.addEvent(createEvent("story", "complete"))

      local completion = Metrics.getMetric("completionRate")
      assert.is_not_nil(completion)
      assert.are.equal(1, completion.completionRate)
    end)

    it("should return nil for unknown metric", function()
      local unknown = Metrics.getMetric("unknownMetric")
      assert.is_nil(unknown)
    end)
  end)

  describe("export()", function()
    it("should export metrics with timestamp", function()
      Metrics.addEvent(createEvent("story", "start"))
      local exported = Metrics.export()

      assert.is_number(exported.timestamp)
      assert.is_not_nil(exported.metrics)
      assert.are.equal(1, exported.eventCount)
    end)
  end)

  describe("clear()", function()
    it("should clear all events", function()
      Metrics.addEvent(createEvent("story", "start"))
      Metrics.addEvent(createEvent("passage", "view", { passageId = "forest" }))
      Metrics.clear()

      local counts = Metrics.calculateEventCounts()
      assert.are.equal(0, counts.total)
    end)

    it("should clear cache", function()
      Metrics.addEvent(createEvent("story", "start"))
      Metrics.getAllMetrics() -- Populate cache
      Metrics.clear()

      local counts = Metrics.calculateEventCounts()
      assert.are.equal(0, counts.total)
    end)
  end)

  describe("reset()", function()
    it("should reset all state", function()
      Metrics.addEvent(createEvent("story", "start"))
      Metrics.reset()

      local counts = Metrics.calculateEventCounts()
      assert.are.equal(0, counts.total)
    end)
  end)
end)
