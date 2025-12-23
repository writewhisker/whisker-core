--- Unit tests for A/B Testing Framework
-- @module tests.analytics.ab_testing_spec

describe("ABTesting", function()
  local ABTesting
  local mockConsentManager
  local mockCollector

  before_each(function()
    package.loaded["whisker.analytics.testing.init"] = nil
    ABTesting = require("whisker.analytics.testing.init")
    ABTesting.reset()

    mockConsentManager = {
      _userId = "test-user-123",
      _sessionId = "test-session-456",
      getUserId = function() return "test-user-123" end,
      getSessionId = function() return "test-session-456" end
    }

    local trackedEvents = {}
    mockCollector = {
      _events = trackedEvents,
      trackEvent = function(category, action, metadata)
        table.insert(trackedEvents, {
          category = category,
          action = action,
          metadata = metadata
        })
      end,
      getTrackedEvents = function()
        return trackedEvents
      end,
      clear = function()
        trackedEvents = {}
        mockCollector._events = trackedEvents
      end
    }

    ABTesting.setDependencies({
      consent_manager = mockConsentManager,
      collector = mockCollector
    })
  end)

  describe("initialize()", function()
    it("should initialize with empty tests", function()
      ABTesting.initialize()
      local tests = ABTesting.getAllTests()
      local count = 0
      for _ in pairs(tests) do count = count + 1 end
      assert.are.equal(0, count)
    end)

    it("should clear assignments", function()
      ABTesting.defineTest({
        id = "test_1",
        variants = {
          { id = "a", weight = 50 },
          { id = "b", weight = 50 }
        }
      })
      ABTesting.startTest("test_1")
      ABTesting.getVariant("test_1")

      ABTesting.initialize()

      local assignment = ABTesting.getAssignment("test_1", "test-user-123")
      assert.is_nil(assignment)
    end)
  end)

  describe("defineTest()", function()
    it("should define a valid test", function()
      local test, err = ABTesting.defineTest({
        id = "opening_test",
        name = "Opening Scene Test",
        description = "Testing different openings",
        variants = {
          { id = "control", name = "Calm Opening", weight = 50 },
          { id = "treatment", name = "Action Opening", weight = 50 }
        },
        metrics = { "completion_rate" },
        minSampleSize = 100
      })

      assert.is_not_nil(test)
      assert.is_nil(err)
      assert.are.equal("opening_test", test.id)
      assert.are.equal("draft", test.status)
    end)

    it("should set default values", function()
      local test, _ = ABTesting.defineTest({
        id = "test_1",
        variants = {
          { id = "a", weight = 50 },
          { id = "b", weight = 50 }
        }
      })

      assert.are.equal("draft", test.status)
      assert.are.equal(100, test.minSampleSize)
      assert.are.equal(0.95, test.confidenceLevel)
    end)

    it("should normalize variant weights", function()
      local test, _ = ABTesting.defineTest({
        id = "test_1",
        variants = {
          { id = "a", weight = 1 },
          { id = "b", weight = 3 }
        }
      })

      assert.are.equal(25, test.variants[1].normalizedWeight)
      assert.are.equal(75, test.variants[2].normalizedWeight)
    end)

    it("should reject test without id", function()
      local test, err = ABTesting.defineTest({
        variants = {
          { id = "a", weight = 50 },
          { id = "b", weight = 50 }
        }
      })

      assert.is_nil(test)
      assert.is_not_nil(err)
    end)

    it("should reject test with less than 2 variants", function()
      local test, err = ABTesting.defineTest({
        id = "test_1",
        variants = {
          { id = "a", weight = 100 }
        }
      })

      assert.is_nil(test)
      assert.is_not_nil(err)
    end)

    it("should reject test with zero total weight", function()
      local test, err = ABTesting.defineTest({
        id = "test_1",
        variants = {
          { id = "a", weight = 0 },
          { id = "b", weight = 0 }
        }
      })

      assert.is_nil(test)
      assert.is_not_nil(err)
    end)

    it("should reject variant without id", function()
      local test, err = ABTesting.defineTest({
        id = "test_1",
        variants = {
          { id = "a", weight = 50 },
          { weight = 50 }  -- missing id
        }
      })

      assert.is_nil(test)
      assert.is_not_nil(err)
    end)
  end)

  describe("getTest()", function()
    it("should return test by id", function()
      ABTesting.defineTest({
        id = "test_1",
        variants = {
          { id = "a", weight = 50 },
          { id = "b", weight = 50 }
        }
      })

      local test = ABTesting.getTest("test_1")
      assert.is_not_nil(test)
      assert.are.equal("test_1", test.id)
    end)

    it("should return nil for unknown test", function()
      local test = ABTesting.getTest("unknown")
      assert.is_nil(test)
    end)
  end)

  describe("getAllTests()", function()
    it("should return all defined tests", function()
      ABTesting.defineTest({
        id = "test_1",
        variants = { { id = "a", weight = 50 }, { id = "b", weight = 50 } }
      })
      ABTesting.defineTest({
        id = "test_2",
        variants = { { id = "x", weight = 50 }, { id = "y", weight = 50 } }
      })

      local tests = ABTesting.getAllTests()
      assert.is_not_nil(tests["test_1"])
      assert.is_not_nil(tests["test_2"])
    end)
  end)

  describe("getActiveTests()", function()
    it("should return only active tests", function()
      ABTesting.defineTest({
        id = "test_1",
        variants = { { id = "a", weight = 50 }, { id = "b", weight = 50 } }
      })
      ABTesting.defineTest({
        id = "test_2",
        variants = { { id = "x", weight = 50 }, { id = "y", weight = 50 } }
      })

      ABTesting.startTest("test_1")

      local active = ABTesting.getActiveTests()
      assert.are.equal(1, #active)
      assert.are.equal("test_1", active[1].id)
    end)
  end)

  describe("startTest()", function()
    before_each(function()
      ABTesting.defineTest({
        id = "test_1",
        variants = { { id = "a", weight = 50 }, { id = "b", weight = 50 } }
      })
    end)

    it("should start a draft test", function()
      local success, err = ABTesting.startTest("test_1")
      assert.is_true(success)
      assert.is_nil(err)

      local test = ABTesting.getTest("test_1")
      assert.are.equal("active", test.status)
    end)

    it("should set start date", function()
      ABTesting.startTest("test_1")
      local test = ABTesting.getTest("test_1")
      assert.is_number(test.startDate)
    end)

    it("should fail for unknown test", function()
      local success, err = ABTesting.startTest("unknown")
      assert.is_false(success)
      assert.is_not_nil(err)
    end)

    it("should fail for already active test", function()
      ABTesting.startTest("test_1")
      local success, err = ABTesting.startTest("test_1")
      assert.is_false(success)
      assert.is_not_nil(err)
    end)
  end)

  describe("pauseTest()", function()
    before_each(function()
      ABTesting.defineTest({
        id = "test_1",
        variants = { { id = "a", weight = 50 }, { id = "b", weight = 50 } }
      })
      ABTesting.startTest("test_1")
    end)

    it("should pause an active test", function()
      local success, err = ABTesting.pauseTest("test_1")
      assert.is_true(success)
      assert.is_nil(err)

      local test = ABTesting.getTest("test_1")
      assert.are.equal("paused", test.status)
    end)

    it("should fail for draft test", function()
      ABTesting.defineTest({
        id = "test_2",
        variants = { { id = "a", weight = 50 }, { id = "b", weight = 50 } }
      })

      local success, err = ABTesting.pauseTest("test_2")
      assert.is_false(success)
      assert.is_not_nil(err)
    end)

    it("should allow restarting paused test", function()
      ABTesting.pauseTest("test_1")
      local success, _ = ABTesting.startTest("test_1")
      assert.is_true(success)

      local test = ABTesting.getTest("test_1")
      assert.are.equal("active", test.status)
    end)
  end)

  describe("completeTest()", function()
    before_each(function()
      ABTesting.defineTest({
        id = "test_1",
        variants = { { id = "a", weight = 50 }, { id = "b", weight = 50 } }
      })
    end)

    it("should complete a test", function()
      ABTesting.startTest("test_1")
      local success, err = ABTesting.completeTest("test_1")
      assert.is_true(success)
      assert.is_nil(err)

      local test = ABTesting.getTest("test_1")
      assert.are.equal("completed", test.status)
    end)

    it("should set end date", function()
      ABTesting.startTest("test_1")
      ABTesting.completeTest("test_1")

      local test = ABTesting.getTest("test_1")
      assert.is_number(test.endDate)
    end)
  end)

  describe("archiveTest()", function()
    it("should archive a test", function()
      ABTesting.defineTest({
        id = "test_1",
        variants = { { id = "a", weight = 50 }, { id = "b", weight = 50 } }
      })

      local success, err = ABTesting.archiveTest("test_1")
      assert.is_true(success)

      local test = ABTesting.getTest("test_1")
      assert.are.equal("archived", test.status)
    end)
  end)

  describe("deleteTest()", function()
    it("should delete a test", function()
      ABTesting.defineTest({
        id = "test_1",
        variants = { { id = "a", weight = 50 }, { id = "b", weight = 50 } }
      })

      ABTesting.deleteTest("test_1")

      local test = ABTesting.getTest("test_1")
      assert.is_nil(test)
    end)
  end)

  describe("getVariant()", function()
    before_each(function()
      ABTesting.defineTest({
        id = "test_1",
        variants = {
          { id = "a", name = "Variant A", weight = 50 },
          { id = "b", name = "Variant B", weight = 50 }
        }
      })
      ABTesting.startTest("test_1")
      mockCollector.clear()
    end)

    it("should return a variant", function()
      local variant = ABTesting.getVariant("test_1")
      assert.is_not_nil(variant)
      assert.is_true(variant.id == "a" or variant.id == "b")
    end)

    it("should return consistent variant for same user", function()
      local variant1 = ABTesting.getVariant("test_1")
      local variant2 = ABTesting.getVariant("test_1")
      assert.are.equal(variant1.id, variant2.id)
    end)

    it("should return nil for inactive test", function()
      ABTesting.defineTest({
        id = "test_2",
        variants = { { id = "a", weight = 50 }, { id = "b", weight = 50 } }
      })

      local variant = ABTesting.getVariant("test_2")
      assert.is_nil(variant)
    end)

    it("should return nil for unknown test", function()
      local variant = ABTesting.getVariant("unknown")
      assert.is_nil(variant)
    end)

    it("should track exposure event", function()
      ABTesting.getVariant("test_1")

      local events = mockCollector.getTrackedEvents()
      assert.are.equal(1, #events)
      assert.are.equal("test", events[1].category)
      assert.are.equal("exposure", events[1].action)
      assert.are.equal("test_1", events[1].metadata.testId)
    end)

    it("should only track exposure once per user", function()
      ABTesting.getVariant("test_1")
      ABTesting.getVariant("test_1")
      ABTesting.getVariant("test_1")

      local events = mockCollector.getTrackedEvents()
      assert.are.equal(1, #events)
    end)
  end)

  describe("trackConversion()", function()
    before_each(function()
      ABTesting.defineTest({
        id = "test_1",
        variants = {
          { id = "a", weight = 50 },
          { id = "b", weight = 50 }
        }
      })
      ABTesting.startTest("test_1")
      ABTesting.getVariant("test_1") -- Assign variant
      mockCollector.clear()
    end)

    it("should track conversion event", function()
      ABTesting.trackConversion("test_1", "story_complete", 1)

      local events = mockCollector.getTrackedEvents()
      assert.are.equal(1, #events)
      assert.are.equal("test", events[1].category)
      assert.are.equal("conversion", events[1].action)
      assert.are.equal("test_1", events[1].metadata.testId)
      assert.are.equal("story_complete", events[1].metadata.conversionType)
    end)

    it("should not track if user not assigned", function()
      ABTesting.clearAssignments()
      ABTesting.trackConversion("test_1", "story_complete", 1)

      local events = mockCollector.getTrackedEvents()
      assert.are.equal(0, #events)
    end)
  end)

  describe("getAssignment()", function()
    before_each(function()
      ABTesting.defineTest({
        id = "test_1",
        variants = { { id = "a", weight = 50 }, { id = "b", weight = 50 } }
      })
      ABTesting.startTest("test_1")
    end)

    it("should return nil before assignment", function()
      local assignment = ABTesting.getAssignment("test_1", "new-user")
      assert.is_nil(assignment)
    end)

    it("should return variant after assignment", function()
      ABTesting.getVariant("test_1")
      local assignment = ABTesting.getAssignment("test_1", "test-user-123")
      assert.is_not_nil(assignment)
    end)
  end)

  describe("clearAssignments()", function()
    it("should clear all assignments", function()
      ABTesting.defineTest({
        id = "test_1",
        variants = { { id = "a", weight = 50 }, { id = "b", weight = 50 } }
      })
      ABTesting.startTest("test_1")
      ABTesting.getVariant("test_1")

      ABTesting.clearAssignments()

      local assignment = ABTesting.getAssignment("test_1", "test-user-123")
      assert.is_nil(assignment)
    end)
  end)

  describe("Statistics", function()
    describe("mean()", function()
      it("should calculate mean of values", function()
        local result = ABTesting.Statistics.mean({1, 2, 3, 4, 5})
        assert.are.equal(3, result)
      end)

      it("should return 0 for empty array", function()
        local result = ABTesting.Statistics.mean({})
        assert.are.equal(0, result)
      end)

      it("should handle single value", function()
        local result = ABTesting.Statistics.mean({42})
        assert.are.equal(42, result)
      end)
    end)

    describe("stdDev()", function()
      it("should calculate standard deviation", function()
        local result = ABTesting.Statistics.stdDev({2, 4, 4, 4, 5, 5, 7, 9})
        -- Sample standard deviation of this data is approximately 2.138
        assert.is_true(math.abs(result - 2.138) < 0.2)
      end)

      it("should return 0 for single value", function()
        local result = ABTesting.Statistics.stdDev({42})
        assert.are.equal(0, result)
      end)

      it("should return 0 for empty array", function()
        local result = ABTesting.Statistics.stdDev({})
        assert.are.equal(0, result)
      end)
    end)

    describe("confidenceInterval()", function()
      it("should calculate 95% confidence interval", function()
        local lower, upper = ABTesting.Statistics.confidenceInterval({10, 12, 14, 16, 18}, 0.95)
        assert.is_not_nil(lower)
        assert.is_not_nil(upper)
        assert.is_true(lower < 14)
        assert.is_true(upper > 14)
      end)

      it("should return nil for insufficient samples", function()
        local lower, upper = ABTesting.Statistics.confidenceInterval({10}, 0.95)
        assert.is_nil(lower)
        assert.is_nil(upper)
      end)
    end)

    describe("tTest()", function()
      it("should detect significant difference", function()
        local valuesA = {10, 12, 11, 13, 12, 11, 10, 12}
        local valuesB = {20, 22, 21, 23, 22, 21, 20, 22}

        local result, err = ABTesting.Statistics.tTest(valuesA, valuesB)
        assert.is_not_nil(result)
        assert.is_nil(err)
        assert.is_true(result.significant)
        assert.is_true(result.pValue < 0.05)
      end)

      it("should detect non-significant difference", function()
        local valuesA = {10, 12, 11, 13, 12}
        local valuesB = {11, 13, 12, 14, 13}

        local result, err = ABTesting.Statistics.tTest(valuesA, valuesB)
        assert.is_not_nil(result)
        assert.is_false(result.significant)
      end)

      it("should return error for insufficient samples", function()
        local result, err = ABTesting.Statistics.tTest({10}, {20})
        assert.is_nil(result)
        assert.is_not_nil(err)
      end)

      it("should return mean values", function()
        local valuesA = {10, 20}
        local valuesB = {30, 40}

        local result, _ = ABTesting.Statistics.tTest(valuesA, valuesB)
        assert.are.equal(15, result.meanA)
        assert.are.equal(35, result.meanB)
      end)
    end)
  end)

  describe("reset()", function()
    it("should reset all state", function()
      ABTesting.defineTest({
        id = "test_1",
        variants = { { id = "a", weight = 50 }, { id = "b", weight = 50 } }
      })
      ABTesting.startTest("test_1")
      ABTesting.getVariant("test_1")

      ABTesting.reset()

      assert.is_nil(ABTesting.getTest("test_1"))
      local active = ABTesting.getActiveTests()
      assert.are.equal(0, #active)
    end)
  end)
end)
