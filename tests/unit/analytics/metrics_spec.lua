--- Metrics Tests
-- @module tests.unit.analytics.metrics_spec
describe("Metrics", function()
  local Metrics

  before_each(function()
    package.loaded["whisker.analytics.metrics"] = nil
    package.loaded["whisker.analytics.metrics.init"] = nil

    Metrics = require("whisker.analytics.metrics")
    Metrics.reset()
    Metrics.initialize()
  end)

  describe("addEvent", function()
    it("should add events for calculation", function()
      Metrics.addEvent({
        category = "story",
        action = "start",
        timestamp = 1000,
        sessionId = "session-1"
      })

      local counts = Metrics.calculateEventCounts()
      assert.are.equal(1, counts.total)
    end)
  end)

  describe("calculateSessionDuration", function()
    it("should calculate session durations", function()
      Metrics.addEvent({
        category = "story",
        action = "start",
        timestamp = 1000,
        sessionId = "session-1"
      })
      Metrics.addEvent({
        category = "passage",
        action = "view",
        timestamp = 5000,
        sessionId = "session-1",
        metadata = { passageId = "intro" }
      })

      local metrics = Metrics.calculateSessionDuration()
      assert.are.equal(1, metrics.totalSessions)
      assert.are.equal(4000, metrics.totalDuration)
    end)

    it("should handle multiple sessions", function()
      Metrics.addEvent({
        category = "story",
        action = "start",
        timestamp = 1000,
        sessionId = "session-1"
      })
      Metrics.addEvent({
        category = "passage",
        action = "view",
        timestamp = 3000,
        sessionId = "session-1",
        metadata = {}
      })
      Metrics.addEvent({
        category = "story",
        action = "start",
        timestamp = 10000,
        sessionId = "session-2"
      })
      Metrics.addEvent({
        category = "passage",
        action = "view",
        timestamp = 15000,
        sessionId = "session-2",
        metadata = {}
      })

      local metrics = Metrics.calculateSessionDuration()
      assert.are.equal(2, metrics.totalSessions)
    end)

    it("should return zeros for no events", function()
      local metrics = Metrics.calculateSessionDuration()
      assert.are.equal(0, metrics.totalSessions)
      assert.are.equal(0, metrics.averageDuration)
    end)
  end)

  describe("calculateCompletionRate", function()
    it("should calculate completion rate", function()
      Metrics.addEvent({ category = "story", action = "start", timestamp = 1000, sessionId = "s1" })
      Metrics.addEvent({ category = "story", action = "complete", timestamp = 2000, sessionId = "s1" })
      Metrics.addEvent({ category = "story", action = "start", timestamp = 3000, sessionId = "s2" })
      Metrics.addEvent({ category = "story", action = "abandon", timestamp = 4000, sessionId = "s2" })

      local metrics = Metrics.calculateCompletionRate()
      assert.are.equal(2, metrics.starts)
      assert.are.equal(1, metrics.completes)
      assert.are.equal(1, metrics.abandons)
      assert.are.equal(0.5, metrics.completionRate)
    end)

    it("should handle no starts", function()
      local metrics = Metrics.calculateCompletionRate()
      assert.are.equal(0, metrics.starts)
      assert.are.equal(0, metrics.completionRate)
    end)
  end)

  describe("calculateChoiceDistribution", function()
    it("should calculate choice distribution", function()
      Metrics.addEvent({
        category = "choice",
        action = "selected",
        timestamp = 1000,
        sessionId = "s1",
        metadata = { passageId = "crossroads", choiceId = "left" }
      })
      Metrics.addEvent({
        category = "choice",
        action = "selected",
        timestamp = 2000,
        sessionId = "s2",
        metadata = { passageId = "crossroads", choiceId = "left" }
      })
      Metrics.addEvent({
        category = "choice",
        action = "selected",
        timestamp = 3000,
        sessionId = "s3",
        metadata = { passageId = "crossroads", choiceId = "right" }
      })

      local metrics = Metrics.calculateChoiceDistribution()
      assert.are.equal(3, metrics.totalChoices)
      assert.are.equal(2, metrics.uniqueChoices)
      assert.are.equal(2, metrics.distribution.left.count)
      assert.are.equal(1, metrics.distribution.right.count)
    end)

    it("should track choices by passage", function()
      Metrics.addEvent({
        category = "choice",
        action = "selected",
        timestamp = 1000,
        sessionId = "s1",
        metadata = { passageId = "p1", choiceId = "a" }
      })
      Metrics.addEvent({
        category = "choice",
        action = "selected",
        timestamp = 2000,
        sessionId = "s2",
        metadata = { passageId = "p2", choiceId = "b" }
      })

      local metrics = Metrics.calculateChoiceDistribution()
      assert.is_not_nil(metrics.byPassage.p1)
      assert.is_not_nil(metrics.byPassage.p2)
    end)
  end)

  describe("calculatePassageFlow", function()
    it("should count passage views", function()
      Metrics.addEvent({
        category = "passage",
        action = "view",
        timestamp = 1000,
        sessionId = "s1",
        metadata = { passageId = "intro" }
      })
      Metrics.addEvent({
        category = "passage",
        action = "view",
        timestamp = 2000,
        sessionId = "s1",
        metadata = { passageId = "chapter1" }
      })
      Metrics.addEvent({
        category = "passage",
        action = "view",
        timestamp = 3000,
        sessionId = "s2",
        metadata = { passageId = "intro" }
      })

      local metrics = Metrics.calculatePassageFlow()
      assert.are.equal(3, metrics.totalPassageViews)
      assert.are.equal(2, metrics.uniquePassages)
      assert.are.equal(2, metrics.passageViews.intro)
      assert.are.equal(1, metrics.passageViews.chapter1)
    end)

    it("should track transitions", function()
      Metrics.addEvent({
        category = "passage",
        action = "view",
        timestamp = 1000,
        sessionId = "s1",
        metadata = { passageId = "intro" }
      })
      Metrics.addEvent({
        category = "passage",
        action = "view",
        timestamp = 2000,
        sessionId = "s1",
        metadata = { passageId = "chapter1" }
      })

      local metrics = Metrics.calculatePassageFlow()
      assert.are.equal(1, metrics.transitions["intro -> chapter1"])
    end)

    it("should return top passages", function()
      Metrics.addEvent({
        category = "passage",
        action = "view",
        timestamp = 1000,
        sessionId = "s1",
        metadata = { passageId = "intro" }
      })
      Metrics.addEvent({
        category = "passage",
        action = "view",
        timestamp = 2000,
        sessionId = "s1",
        metadata = { passageId = "intro" }
      })
      Metrics.addEvent({
        category = "passage",
        action = "view",
        timestamp = 3000,
        sessionId = "s1",
        metadata = { passageId = "chapter1" }
      })

      local metrics = Metrics.calculatePassageFlow()
      assert.are.equal("intro", metrics.topPassages[1].passageId)
    end)
  end)

  describe("calculateEngagement", function()
    it("should calculate engagement metrics", function()
      Metrics.addEvent({
        category = "story",
        action = "start",
        timestamp = 1000,
        sessionId = "s1"
      })
      Metrics.addEvent({
        category = "passage",
        action = "view",
        timestamp = 2000,
        sessionId = "s1",
        metadata = { passageId = "intro" }
      })
      Metrics.addEvent({
        category = "passage",
        action = "exit",
        timestamp = 5000,
        sessionId = "s1",
        metadata = { passageId = "intro", timeOnPassage = 3000 }
      })

      local metrics = Metrics.calculateEngagement()
      assert.are.equal(3, metrics.totalEvents)
      assert.is_number(metrics.engagementScore)
    end)

    it("should calculate average time per passage", function()
      Metrics.addEvent({
        category = "passage",
        action = "exit",
        timestamp = 1000,
        sessionId = "s1",
        metadata = { passageId = "intro", timeOnPassage = 5000 }
      })
      Metrics.addEvent({
        category = "passage",
        action = "exit",
        timestamp = 2000,
        sessionId = "s2",
        metadata = { passageId = "intro", timeOnPassage = 3000 }
      })

      local metrics = Metrics.calculateEngagement()
      assert.are.equal(4000, metrics.avgTimePerPassage.intro)
    end)
  end)

  describe("calculateEventCounts", function()
    it("should count events by category", function()
      Metrics.addEvent({ category = "story", action = "start", timestamp = 1000, sessionId = "s1" })
      Metrics.addEvent({ category = "passage", action = "view", timestamp = 2000, sessionId = "s1", metadata = {} })
      Metrics.addEvent({ category = "passage", action = "view", timestamp = 3000, sessionId = "s1", metadata = {} })

      local counts = Metrics.calculateEventCounts()
      assert.are.equal(3, counts.total)
      assert.are.equal(1, counts.byCategory.story)
      assert.are.equal(2, counts.byCategory.passage)
    end)

    it("should count events by action", function()
      Metrics.addEvent({ category = "passage", action = "view", timestamp = 1000, sessionId = "s1", metadata = {} })
      Metrics.addEvent({ category = "passage", action = "exit", timestamp = 2000, sessionId = "s1", metadata = {} })
      Metrics.addEvent({ category = "passage", action = "view", timestamp = 3000, sessionId = "s1", metadata = {} })

      local counts = Metrics.calculateEventCounts()
      assert.are.equal(2, counts.byAction.view)
      assert.are.equal(1, counts.byAction.exit)
    end)
  end)

  describe("getAllMetrics", function()
    it("should return all metrics", function()
      Metrics.addEvent({ category = "story", action = "start", timestamp = 1000, sessionId = "s1" })

      local all = Metrics.getAllMetrics()
      assert.is_not_nil(all.sessionDuration)
      assert.is_not_nil(all.completionRate)
      assert.is_not_nil(all.choiceDistribution)
      assert.is_not_nil(all.passageFlow)
      assert.is_not_nil(all.engagement)
      assert.is_not_nil(all.eventCounts)
    end)
  end)

  describe("getMetric", function()
    it("should return specific metric", function()
      Metrics.addEvent({ category = "story", action = "start", timestamp = 1000, sessionId = "s1" })

      local metric = Metrics.getMetric("completionRate")
      assert.is_not_nil(metric)
      assert.are.equal(1, metric.starts)
    end)
  end)

  describe("export", function()
    it("should export metrics with timestamp", function()
      Metrics.addEvent({ category = "story", action = "start", timestamp = 1000, sessionId = "s1" })

      local exported = Metrics.export()
      assert.is_number(exported.timestamp)
      assert.is_table(exported.metrics)
      assert.are.equal(1, exported.eventCount)
    end)
  end)

  describe("clear", function()
    it("should clear all events and cache", function()
      Metrics.addEvent({ category = "story", action = "start", timestamp = 1000, sessionId = "s1" })
      assert.are.equal(1, Metrics.calculateEventCounts().total)

      Metrics.clear()
      assert.are.equal(0, Metrics.calculateEventCounts().total)
    end)
  end)
end)
