--- A/B Testing Framework Tests
-- @module tests.unit.analytics.ab_testing_spec
describe("ABTesting", function()
  local ABTesting
  local mock_consent_manager
  local mock_collector

  before_each(function()
    package.loaded["whisker.analytics.testing"] = nil
    package.loaded["whisker.analytics.testing.init"] = nil

    ABTesting = require("whisker.analytics.testing")
    ABTesting.reset()
    ABTesting.initialize()

    -- Mock consent manager
    mock_consent_manager = {
      _userId = "user-123",
      _sessionId = "session-456",
      getUserId = function()
        return mock_consent_manager._userId
      end,
      getSessionId = function()
        return mock_consent_manager._sessionId
      end
    }

    -- Mock collector
    mock_collector = {
      _events = {},
      trackEvent = function(category, action, metadata)
        table.insert(mock_collector._events, {
          category = category,
          action = action,
          metadata = metadata
        })
      end
    }

    ABTesting.setDependencies({
      consent_manager = mock_consent_manager,
      collector = mock_collector
    })
  end)

  describe("defineTest", function()
    it("should define a valid test", function()
      local test = ABTesting.defineTest({
        id = "test-1",
        name = "Test 1",
        variants = {
          { id = "control", weight = 50 },
          { id = "treatment", weight = 50 }
        }
      })

      assert.is_not_nil(test)
      assert.are.equal("test-1", test.id)
      assert.are.equal("draft", test.status)
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
        id = "test-1",
        variants = {
          { id = "only-one", weight = 100 }
        }
      })

      assert.is_nil(test)
      assert.is_not_nil(err)
    end)

    it("should normalize variant weights", function()
      local test = ABTesting.defineTest({
        id = "test-1",
        variants = {
          { id = "a", weight = 1 },
          { id = "b", weight = 3 }
        }
      })

      assert.are.equal(25, test.variants[1].normalizedWeight)
      assert.are.equal(75, test.variants[2].normalizedWeight)
    end)
  end)

  describe("getTest", function()
    it("should return defined test", function()
      ABTesting.defineTest({
        id = "test-1",
        variants = {
          { id = "a", weight = 50 },
          { id = "b", weight = 50 }
        }
      })

      local test = ABTesting.getTest("test-1")
      assert.is_not_nil(test)
      assert.are.equal("test-1", test.id)
    end)

    it("should return nil for undefined test", function()
      local test = ABTesting.getTest("nonexistent")
      assert.is_nil(test)
    end)
  end)

  describe("startTest", function()
    it("should start a draft test", function()
      ABTesting.defineTest({
        id = "test-1",
        variants = {
          { id = "a", weight = 50 },
          { id = "b", weight = 50 }
        }
      })

      local success = ABTesting.startTest("test-1")
      assert.is_true(success)

      local test = ABTesting.getTest("test-1")
      assert.are.equal("active", test.status)
    end)

    it("should fail for non-draft test", function()
      ABTesting.defineTest({
        id = "test-1",
        status = "completed",
        variants = {
          { id = "a", weight = 50 },
          { id = "b", weight = 50 }
        }
      })

      local success, err = ABTesting.startTest("test-1")
      assert.is_false(success)
    end)
  end)

  describe("pauseTest", function()
    it("should pause an active test", function()
      ABTesting.defineTest({
        id = "test-1",
        variants = {
          { id = "a", weight = 50 },
          { id = "b", weight = 50 }
        }
      })
      ABTesting.startTest("test-1")

      local success = ABTesting.pauseTest("test-1")
      assert.is_true(success)

      local test = ABTesting.getTest("test-1")
      assert.are.equal("paused", test.status)
    end)
  end)

  describe("completeTest", function()
    it("should complete a test", function()
      ABTesting.defineTest({
        id = "test-1",
        variants = {
          { id = "a", weight = 50 },
          { id = "b", weight = 50 }
        }
      })

      local success = ABTesting.completeTest("test-1")
      assert.is_true(success)

      local test = ABTesting.getTest("test-1")
      assert.are.equal("completed", test.status)
      assert.is_not_nil(test.endDate)
    end)
  end)

  describe("getVariant", function()
    it("should return nil for inactive test", function()
      ABTesting.defineTest({
        id = "test-1",
        variants = {
          { id = "a", weight = 50 },
          { id = "b", weight = 50 }
        }
      })

      local variant = ABTesting.getVariant("test-1")
      assert.is_nil(variant)
    end)

    it("should return variant for active test", function()
      ABTesting.defineTest({
        id = "test-1",
        variants = {
          { id = "a", weight = 50 },
          { id = "b", weight = 50 }
        }
      })
      ABTesting.startTest("test-1")

      local variant = ABTesting.getVariant("test-1")
      assert.is_not_nil(variant)
      assert.is_true(variant.id == "a" or variant.id == "b")
    end)

    it("should return consistent variant for same user", function()
      ABTesting.defineTest({
        id = "test-1",
        variants = {
          { id = "a", weight = 50 },
          { id = "b", weight = 50 }
        }
      })
      ABTesting.startTest("test-1")

      local variant1 = ABTesting.getVariant("test-1")
      local variant2 = ABTesting.getVariant("test-1")

      assert.are.equal(variant1.id, variant2.id)
    end)

    it("should track exposure event", function()
      ABTesting.defineTest({
        id = "test-1",
        name = "Test 1",
        variants = {
          { id = "a", weight = 50 },
          { id = "b", weight = 50 }
        }
      })
      ABTesting.startTest("test-1")

      ABTesting.getVariant("test-1")

      assert.are.equal(1, #mock_collector._events)
      assert.are.equal("test", mock_collector._events[1].category)
      assert.are.equal("exposure", mock_collector._events[1].action)
    end)
  end)

  describe("trackConversion", function()
    it("should track conversion for assigned variant", function()
      ABTesting.defineTest({
        id = "test-1",
        variants = {
          { id = "a", weight = 50 },
          { id = "b", weight = 50 }
        }
      })
      ABTesting.startTest("test-1")
      ABTesting.getVariant("test-1")

      ABTesting.trackConversion("test-1", "purchase", 100)

      -- Should have exposure + conversion events
      assert.are.equal(2, #mock_collector._events)
      assert.are.equal("conversion", mock_collector._events[2].action)
      assert.are.equal("purchase", mock_collector._events[2].metadata.conversionType)
    end)
  end)

  describe("getActiveTests", function()
    it("should return only active tests", function()
      ABTesting.defineTest({
        id = "test-1",
        variants = {{ id = "a", weight = 50 }, { id = "b", weight = 50 }}
      })
      ABTesting.defineTest({
        id = "test-2",
        variants = {{ id = "a", weight = 50 }, { id = "b", weight = 50 }}
      })

      ABTesting.startTest("test-1")

      local active = ABTesting.getActiveTests()
      assert.are.equal(1, #active)
      assert.are.equal("test-1", active[1].id)
    end)
  end)

  describe("Statistics", function()
    describe("mean", function()
      it("should calculate mean", function()
        local result = ABTesting.Statistics.mean({1, 2, 3, 4, 5})
        assert.are.equal(3, result)
      end)

      it("should return 0 for empty array", function()
        local result = ABTesting.Statistics.mean({})
        assert.are.equal(0, result)
      end)
    end)

    describe("stdDev", function()
      it("should calculate standard deviation", function()
        local result = ABTesting.Statistics.stdDev({2, 4, 4, 4, 5, 5, 7, 9})
        assert.is_true(result > 2 and result < 3)
      end)

      it("should return 0 for single value", function()
        local result = ABTesting.Statistics.stdDev({5})
        assert.are.equal(0, result)
      end)
    end)

    describe("confidenceInterval", function()
      it("should calculate confidence interval", function()
        local lower, upper = ABTesting.Statistics.confidenceInterval({10, 12, 11, 13, 12, 11, 10, 12})

        assert.is_not_nil(lower)
        assert.is_not_nil(upper)
        assert.is_true(lower < upper)
      end)

      it("should return nil for insufficient data", function()
        local lower, upper = ABTesting.Statistics.confidenceInterval({5})
        assert.is_nil(lower)
        assert.is_nil(upper)
      end)
    end)

    describe("tTest", function()
      it("should perform t-test", function()
        local valuesA = {10, 12, 11, 13, 12}
        local valuesB = {15, 17, 16, 18, 17}

        local result = ABTesting.Statistics.tTest(valuesA, valuesB)

        assert.is_not_nil(result)
        assert.is_number(result.meanA)
        assert.is_number(result.meanB)
        assert.is_number(result.tStatistic)
        assert.is_number(result.pValue)
        assert.is_boolean(result.significant)
      end)

      it("should return error for insufficient data", function()
        local result, err = ABTesting.Statistics.tTest({5}, {10})
        assert.is_nil(result)
        assert.is_not_nil(err)
      end)

      it("should detect significant difference", function()
        local valuesA = {10, 10, 10, 10, 10}
        local valuesB = {100, 100, 100, 100, 100}

        local result = ABTesting.Statistics.tTest(valuesA, valuesB)

        assert.is_true(result.significant)
      end)
    end)
  end)

  describe("clearAssignments", function()
    it("should clear all assignments", function()
      ABTesting.defineTest({
        id = "test-1",
        variants = {{ id = "a", weight = 50 }, { id = "b", weight = 50 }}
      })
      ABTesting.startTest("test-1")
      ABTesting.getVariant("test-1")

      ABTesting.clearAssignments()

      -- Next call should create new assignment
      mock_collector._events = {}
      ABTesting.getVariant("test-1")
      assert.are.equal(1, #mock_collector._events) -- New exposure tracked
    end)
  end)

  describe("deleteTest", function()
    it("should remove test", function()
      ABTesting.defineTest({
        id = "test-1",
        variants = {{ id = "a", weight = 50 }, { id = "b", weight = 50 }}
      })

      ABTesting.deleteTest("test-1")
      assert.is_nil(ABTesting.getTest("test-1"))
    end)
  end)
end)
