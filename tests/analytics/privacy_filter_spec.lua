--- Unit tests for Privacy Filter
-- @module tests.analytics.privacy_filter_spec

describe("PrivacyFilter", function()
  local PrivacyFilter
  local Privacy
  local mockConsentManager

  before_each(function()
    package.loaded["whisker.analytics.privacy_filter"] = nil
    package.loaded["whisker.analytics.privacy"] = nil
    PrivacyFilter = require("whisker.analytics.privacy_filter")
    Privacy = require("whisker.analytics.privacy")
    PrivacyFilter.reset()

    mockConsentManager = {
      _level = Privacy.CONSENT_LEVELS.ANALYTICS,
      _userId = "test-user-id",
      getConsentLevel = function()
        return mockConsentManager._level
      end,
      getUserId = function()
        return mockConsentManager._userId
      end
    }
  end)

  local function createTestEvent(category, action, metadata)
    return {
      category = category or "story",
      action = action or "start",
      timestamp = os.time() * 1000,
      sessionId = "test-session-123",
      sessionStart = os.time() * 1000,
      storyId = "test-story",
      storyVersion = "1.0.0",
      storyTitle = "Test Story",
      metadata = metadata or {}
    }
  end

  describe("apply()", function()
    describe("at NONE consent level", function()
      before_each(function()
        mockConsentManager._level = Privacy.CONSENT_LEVELS.NONE
        PrivacyFilter.setDependencies({ consent_manager = mockConsentManager })
      end)

      it("should return nil for all events", function()
        local event = createTestEvent("story", "start")
        local result = PrivacyFilter.apply(event)
        assert.is_nil(result)
      end)
    end)

    describe("at ESSENTIAL consent level", function()
      before_each(function()
        mockConsentManager._level = Privacy.CONSENT_LEVELS.ESSENTIAL
        PrivacyFilter.setDependencies({ consent_manager = mockConsentManager })
      end)

      it("should allow error.script events", function()
        local event = createTestEvent("error", "script", {
          errorType = "runtime",
          errorMessage = "Test error",
          severity = "error"
        })
        local result = PrivacyFilter.apply(event)
        assert.is_not_nil(result)
        assert.are.equal("error", result.category)
      end)

      it("should allow error.resource events", function()
        local event = createTestEvent("error", "resource", {
          resourceType = "image",
          errorCode = 404
        })
        local result = PrivacyFilter.apply(event)
        assert.is_not_nil(result)
      end)

      it("should allow error.state events", function()
        local event = createTestEvent("error", "state", {
          errorType = "invalid_state"
        })
        local result = PrivacyFilter.apply(event)
        assert.is_not_nil(result)
      end)

      it("should allow save.create events", function()
        local event = createTestEvent("save", "create", {
          saveId = "save_1",
          currentPassage = "forest"
        })
        local result = PrivacyFilter.apply(event)
        assert.is_not_nil(result)
      end)

      it("should allow save.load events", function()
        local event = createTestEvent("save", "load", {
          saveId = "save_1",
          loadedPassage = "forest"
        })
        local result = PrivacyFilter.apply(event)
        assert.is_not_nil(result)
      end)

      it("should filter out story events", function()
        local event = createTestEvent("story", "start")
        local result = PrivacyFilter.apply(event)
        assert.is_nil(result)
      end)

      it("should filter out passage events", function()
        local event = createTestEvent("passage", "view", { passageId = "forest" })
        local result = PrivacyFilter.apply(event)
        assert.is_nil(result)
      end)

      it("should filter out choice events", function()
        local event = createTestEvent("choice", "selected", { passageId = "forest", choiceId = "a" })
        local result = PrivacyFilter.apply(event)
        assert.is_nil(result)
      end)

      it("should strip non-essential metadata", function()
        local event = createTestEvent("error", "script", {
          errorType = "runtime",
          errorMessage = "Test error",
          severity = "error",
          extraField = "should be removed"
        })
        local result = PrivacyFilter.apply(event)
        assert.is_not_nil(result)
        assert.is_nil(result.metadata.extraField)
      end)

      it("should remove userId", function()
        local event = createTestEvent("error", "script", {
          errorType = "runtime",
          errorMessage = "Test",
          severity = "error"
        })
        event.userId = "test-user"
        local result = PrivacyFilter.apply(event)
        assert.is_nil(result.userId)
      end)
    end)

    describe("at ANALYTICS consent level", function()
      before_each(function()
        mockConsentManager._level = Privacy.CONSENT_LEVELS.ANALYTICS
        PrivacyFilter.setDependencies({ consent_manager = mockConsentManager })
      end)

      it("should allow story events", function()
        local event = createTestEvent("story", "start")
        local result = PrivacyFilter.apply(event)
        assert.is_not_nil(result)
        assert.are.equal("story", result.category)
      end)

      it("should allow passage events", function()
        local event = createTestEvent("passage", "view", { passageId = "forest" })
        local result = PrivacyFilter.apply(event)
        assert.is_not_nil(result)
        assert.are.equal("passage", result.category)
      end)

      it("should allow choice events", function()
        local event = createTestEvent("choice", "selected", { passageId = "forest", choiceId = "a" })
        local result = PrivacyFilter.apply(event)
        assert.is_not_nil(result)
        assert.are.equal("choice", result.category)
      end)

      it("should allow save events", function()
        local event = createTestEvent("save", "create", { saveId = "save_1", currentPassage = "forest" })
        local result = PrivacyFilter.apply(event)
        assert.is_not_nil(result)
      end)

      it("should allow error events", function()
        local event = createTestEvent("error", "script", { errorType = "runtime", errorMessage = "Test", severity = "error" })
        local result = PrivacyFilter.apply(event)
        assert.is_not_nil(result)
      end)

      it("should filter out user events", function()
        local event = createTestEvent("user", "consent_change", { previousLevel = 0, newLevel = 2 })
        local result = PrivacyFilter.apply(event)
        assert.is_nil(result)
      end)

      it("should filter out test events", function()
        local event = createTestEvent("test", "exposure", { testId = "test_1", variantId = "a" })
        local result = PrivacyFilter.apply(event)
        assert.is_nil(result)
      end)

      it("should remove PII fields", function()
        local event = createTestEvent("passage", "view", {
          passageId = "forest",
          userName = "John Doe",
          userEmail = "john@example.com"
        })
        local result = PrivacyFilter.apply(event)
        assert.is_nil(result.metadata.userName)
        assert.is_nil(result.metadata.userEmail)
      end)

      it("should anonymize save names", function()
        local event = createTestEvent("save", "create", {
          saveId = "save_1",
          currentPassage = "forest",
          saveName = "My Personal Save"
        })
        local result = PrivacyFilter.apply(event)
        assert.is_not_nil(result.metadata.saveName)
        assert.are_not.equal("My Personal Save", result.metadata.saveName)
        assert.is_true(result.metadata.saveName:match("^Save_") ~= nil)
      end)

      it("should redact feedback text", function()
        local event = createTestEvent("passage", "view", {
          passageId = "forest",
          feedbackText = "This story is great!"
        })
        local result = PrivacyFilter.apply(event)
        assert.are.equal("[redacted]", result.metadata.feedbackText)
      end)

      it("should remove persistent userId", function()
        local event = createTestEvent("story", "start")
        event.userId = "persistent-user-id"
        local result = PrivacyFilter.apply(event)
        assert.is_nil(result.userId)
      end)

      it("should use session-scoped ID", function()
        local event = createTestEvent("story", "start")
        local result = PrivacyFilter.apply(event)
        assert.is_not_nil(result.sessionId)
      end)
    end)

    describe("at FULL consent level", function()
      before_each(function()
        mockConsentManager._level = Privacy.CONSENT_LEVELS.FULL
        PrivacyFilter.setDependencies({ consent_manager = mockConsentManager })
      end)

      it("should allow all events", function()
        local storyEvent = createTestEvent("story", "start")
        local userEvent = createTestEvent("user", "consent_change", { previousLevel = 0, newLevel = 3 })
        local testEvent = createTestEvent("test", "exposure", { testId = "test_1", variantId = "a" })

        assert.is_not_nil(PrivacyFilter.apply(storyEvent))
        assert.is_not_nil(PrivacyFilter.apply(userEvent))
        assert.is_not_nil(PrivacyFilter.apply(testEvent))
      end)

      it("should preserve all metadata", function()
        local event = createTestEvent("passage", "view", {
          passageId = "forest",
          userName = "John Doe",
          customData = { key = "value" }
        })
        local result = PrivacyFilter.apply(event)
        assert.are.equal("forest", result.metadata.passageId)
        assert.are.equal("John Doe", result.metadata.userName)
        assert.is_not_nil(result.metadata.customData)
      end)

      it("should add userId from consent manager", function()
        local event = createTestEvent("story", "start")
        local result = PrivacyFilter.apply(event)
        assert.are.equal("test-user-id", result.userId)
      end)
    end)
  end)

  describe("isEventAllowed()", function()
    it("should return false for NONE consent", function()
      assert.is_false(PrivacyFilter.isEventAllowed("story", "start", Privacy.CONSENT_LEVELS.NONE))
      assert.is_false(PrivacyFilter.isEventAllowed("error", "script", Privacy.CONSENT_LEVELS.NONE))
    end)

    it("should return true for essential events at ESSENTIAL consent", function()
      assert.is_true(PrivacyFilter.isEventAllowed("error", "script", Privacy.CONSENT_LEVELS.ESSENTIAL))
      assert.is_true(PrivacyFilter.isEventAllowed("save", "create", Privacy.CONSENT_LEVELS.ESSENTIAL))
    end)

    it("should return false for non-essential events at ESSENTIAL consent", function()
      assert.is_false(PrivacyFilter.isEventAllowed("story", "start", Privacy.CONSENT_LEVELS.ESSENTIAL))
      assert.is_false(PrivacyFilter.isEventAllowed("passage", "view", Privacy.CONSENT_LEVELS.ESSENTIAL))
    end)

    it("should return true for analytics categories at ANALYTICS consent", function()
      assert.is_true(PrivacyFilter.isEventAllowed("story", "start", Privacy.CONSENT_LEVELS.ANALYTICS))
      assert.is_true(PrivacyFilter.isEventAllowed("passage", "view", Privacy.CONSENT_LEVELS.ANALYTICS))
      assert.is_true(PrivacyFilter.isEventAllowed("choice", "selected", Privacy.CONSENT_LEVELS.ANALYTICS))
    end)

    it("should return false for user/test categories at ANALYTICS consent", function()
      assert.is_false(PrivacyFilter.isEventAllowed("user", "consent_change", Privacy.CONSENT_LEVELS.ANALYTICS))
      assert.is_false(PrivacyFilter.isEventAllowed("test", "exposure", Privacy.CONSENT_LEVELS.ANALYTICS))
    end)

    it("should return true for all events at FULL consent", function()
      assert.is_true(PrivacyFilter.isEventAllowed("story", "start", Privacy.CONSENT_LEVELS.FULL))
      assert.is_true(PrivacyFilter.isEventAllowed("user", "consent_change", Privacy.CONSENT_LEVELS.FULL))
      assert.is_true(PrivacyFilter.isEventAllowed("test", "exposure", Privacy.CONSENT_LEVELS.FULL))
    end)
  end)

  describe("validateCompliance()", function()
    it("should pass for valid event at consent level", function()
      local event = createTestEvent("story", "start")
      local isValid, violations = PrivacyFilter.validateCompliance(event, Privacy.CONSENT_LEVELS.ANALYTICS)
      assert.is_true(isValid)
      assert.are.equal(0, #violations)
    end)

    it("should fail when userId present at lower consent levels", function()
      local event = createTestEvent("story", "start")
      event.userId = "test-user"
      local isValid, violations = PrivacyFilter.validateCompliance(event, Privacy.CONSENT_LEVELS.ANALYTICS)
      assert.is_false(isValid)
      assert.is_true(#violations > 0)
    end)

    it("should fail when PII present at lower consent levels", function()
      local event = createTestEvent("story", "start", { userName = "John" })
      local isValid, violations = PrivacyFilter.validateCompliance(event, Privacy.CONSENT_LEVELS.ANALYTICS)
      assert.is_false(isValid)
      assert.is_true(#violations > 0)
    end)

    it("should fail for non-essential event at ESSENTIAL consent", function()
      local event = createTestEvent("story", "start")
      local isValid, violations = PrivacyFilter.validateCompliance(event, Privacy.CONSENT_LEVELS.ESSENTIAL)
      assert.is_false(isValid)
      assert.is_true(#violations > 0)
    end)

    it("should fail for user category at ANALYTICS consent", function()
      local event = createTestEvent("user", "consent_change", { previousLevel = 0, newLevel = 2 })
      local isValid, violations = PrivacyFilter.validateCompliance(event, Privacy.CONSENT_LEVELS.ANALYTICS)
      assert.is_false(isValid)
      assert.is_true(#violations > 0)
    end)

    it("should pass for all valid events at FULL consent", function()
      local event = createTestEvent("user", "consent_change", { previousLevel = 0, newLevel = 3 })
      event.userId = "test-user"
      event.metadata.userName = "John"
      local isValid, violations = PrivacyFilter.validateCompliance(event, Privacy.CONSENT_LEVELS.FULL)
      assert.is_true(isValid)
    end)
  end)

  describe("applyConsentChangeToQueue()", function()
    it("should filter queue based on new consent level", function()
      local queue = {
        createTestEvent("story", "start"),
        createTestEvent("passage", "view", { passageId = "forest" }),
        createTestEvent("error", "script", { errorType = "runtime", errorMessage = "Test", severity = "error" })
      }

      local filtered = PrivacyFilter.applyConsentChangeToQueue(queue, Privacy.CONSENT_LEVELS.ESSENTIAL)
      assert.are.equal(1, #filtered) -- Only error event should remain
      assert.are.equal("error", filtered[1].category)
    end)

    it("should return empty queue for NONE consent", function()
      local queue = {
        createTestEvent("story", "start"),
        createTestEvent("error", "script", { errorType = "runtime", errorMessage = "Test", severity = "error" })
      }

      local filtered = PrivacyFilter.applyConsentChangeToQueue(queue, Privacy.CONSENT_LEVELS.NONE)
      assert.are.equal(0, #filtered)
    end)

    it("should preserve all events for FULL consent", function()
      local queue = {
        createTestEvent("story", "start"),
        createTestEvent("user", "consent_change", { previousLevel = 0, newLevel = 3 }),
        createTestEvent("test", "exposure", { testId = "test_1", variantId = "a" })
      }

      local filtered = PrivacyFilter.applyConsentChangeToQueue(queue, Privacy.CONSENT_LEVELS.FULL)
      assert.are.equal(3, #filtered)
    end)
  end)

  describe("startNewSession()", function()
    it("should generate new session ID", function()
      local id1 = PrivacyFilter.startNewSession()
      local id2 = PrivacyFilter.startNewSession()
      assert.are_not.equal(id1, id2)
    end)

    it("should return valid UUID format", function()
      local id = PrivacyFilter.startNewSession()
      assert.is_string(id)
      assert.is_true(#id > 0)
    end)
  end)

  describe("reset()", function()
    it("should clear session ID", function()
      mockConsentManager._level = Privacy.CONSENT_LEVELS.ANALYTICS
      PrivacyFilter.setDependencies({ consent_manager = mockConsentManager })

      local event1 = createTestEvent("story", "start")
      local result1 = PrivacyFilter.apply(event1)
      local sessionId1 = result1.sessionId

      PrivacyFilter.reset()
      mockConsentManager._level = Privacy.CONSENT_LEVELS.ANALYTICS
      PrivacyFilter.setDependencies({ consent_manager = mockConsentManager })

      local event2 = createTestEvent("story", "start")
      local result2 = PrivacyFilter.apply(event2)
      local sessionId2 = result2.sessionId

      assert.are_not.equal(sessionId1, sessionId2)
    end)
  end)
end)
