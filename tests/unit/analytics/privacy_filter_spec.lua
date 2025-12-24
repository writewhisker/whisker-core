--- Privacy Filter Tests
-- @module tests.unit.analytics.privacy_filter_spec
describe("PrivacyFilter", function()
  local PrivacyFilter
  local Privacy
  local mock_consent_manager

  before_each(function()
    package.loaded["whisker.analytics.privacy_filter"] = nil
    package.loaded["whisker.analytics.privacy"] = nil

    PrivacyFilter = require("whisker.analytics.privacy_filter")
    Privacy = require("whisker.analytics.privacy")

    PrivacyFilter.reset()

    -- Create mock consent manager
    mock_consent_manager = {
      _level = Privacy.CONSENT_LEVELS.ANALYTICS,
      _userId = "user-123",
      getConsentLevel = function()
        return mock_consent_manager._level
      end,
      getUserId = function()
        return mock_consent_manager._userId
      end
    }

    PrivacyFilter.setDependencies({
      consent_manager = mock_consent_manager
    })
  end)

  describe("Privacy module", function()
    it("should define all consent levels", function()
      assert.are.equal(0, Privacy.CONSENT_LEVELS.NONE)
      assert.are.equal(1, Privacy.CONSENT_LEVELS.ESSENTIAL)
      assert.are.equal(2, Privacy.CONSENT_LEVELS.ANALYTICS)
      assert.are.equal(3, Privacy.CONSENT_LEVELS.FULL)
    end)

    it("should have names for all levels", function()
      assert.are.equal("None", Privacy.getConsentLevelName(0))
      assert.are.equal("Essential", Privacy.getConsentLevelName(1))
      assert.are.equal("Analytics", Privacy.getConsentLevelName(2))
      assert.are.equal("Full", Privacy.getConsentLevelName(3))
    end)

    it("should have descriptions for all levels", function()
      for i = 0, 3 do
        local desc = Privacy.getConsentLevelDescription(i)
        assert.is_string(desc)
        assert.is_true(#desc > 0)
      end
    end)

    it("should validate consent levels", function()
      assert.is_true(Privacy.isValidConsentLevel(0))
      assert.is_true(Privacy.isValidConsentLevel(1))
      assert.is_true(Privacy.isValidConsentLevel(2))
      assert.is_true(Privacy.isValidConsentLevel(3))
      assert.is_false(Privacy.isValidConsentLevel(-1))
      assert.is_false(Privacy.isValidConsentLevel(4))
      assert.is_false(Privacy.isValidConsentLevel("invalid"))
    end)
  end)

  describe("NONE consent level", function()
    before_each(function()
      mock_consent_manager._level = Privacy.CONSENT_LEVELS.NONE
    end)

    it("should discard all events", function()
      local event = {
        category = "story",
        action = "start",
        timestamp = 12345,
        sessionId = "session-1",
        storyId = "story-1",
        metadata = {}
      }

      local filtered = PrivacyFilter.apply(event)
      assert.is_nil(filtered)
    end)

    it("should discard even essential events", function()
      local event = {
        category = "error",
        action = "script",
        timestamp = 12345,
        sessionId = "session-1",
        storyId = "story-1",
        metadata = { errorType = "runtime" }
      }

      local filtered = PrivacyFilter.apply(event)
      assert.is_nil(filtered)
    end)
  end)

  describe("ESSENTIAL consent level", function()
    before_each(function()
      mock_consent_manager._level = Privacy.CONSENT_LEVELS.ESSENTIAL
    end)

    it("should allow essential error events", function()
      local event = {
        category = "error",
        action = "script",
        timestamp = 12345,
        sessionId = "session-1",
        storyId = "story-1",
        metadata = {
          errorType = "RuntimeError",
          errorMessage = "Variable not found",
          severity = "error"
        }
      }

      local filtered = PrivacyFilter.apply(event)
      assert.is_not_nil(filtered)
      assert.are.equal("error", filtered.category)
      assert.are.equal("script", filtered.action)
    end)

    it("should allow essential save events", function()
      local event = {
        category = "save",
        action = "create",
        timestamp = 12345,
        sessionId = "session-1",
        storyId = "story-1",
        metadata = {
          saveId = "save-1",
          currentPassage = "intro"
        }
      }

      local filtered = PrivacyFilter.apply(event)
      assert.is_not_nil(filtered)
    end)

    it("should discard behavioral events", function()
      local event = {
        category = "passage",
        action = "view",
        timestamp = 12345,
        sessionId = "session-1",
        storyId = "story-1",
        metadata = { passageId = "intro" }
      }

      local filtered = PrivacyFilter.apply(event)
      assert.is_nil(filtered)
    end)

    it("should strip non-essential metadata", function()
      local event = {
        category = "error",
        action = "script",
        timestamp = 12345,
        sessionId = "session-1",
        storyId = "story-1",
        metadata = {
          errorType = "RuntimeError",
          errorMessage = "Error",
          severity = "error",
          extraField = "should be removed",
          userName = "Alice"
        }
      }

      local filtered = PrivacyFilter.apply(event)
      assert.is_not_nil(filtered)
      assert.is_nil(filtered.metadata.extraField)
      assert.is_nil(filtered.metadata.userName)
      assert.are.equal("RuntimeError", filtered.metadata.errorType)
    end)

    it("should remove userId", function()
      local event = {
        category = "save",
        action = "create",
        timestamp = 12345,
        sessionId = "session-1",
        storyId = "story-1",
        userId = "user-123",
        metadata = { saveId = "save-1", currentPassage = "intro" }
      }

      local filtered = PrivacyFilter.apply(event)
      assert.is_nil(filtered.userId)
    end)
  end)

  describe("ANALYTICS consent level", function()
    before_each(function()
      mock_consent_manager._level = Privacy.CONSENT_LEVELS.ANALYTICS
    end)

    it("should allow story events", function()
      local event = {
        category = "story",
        action = "start",
        timestamp = 12345,
        sessionId = "session-1",
        storyId = "story-1",
        metadata = { isFirstLaunch = true }
      }

      local filtered = PrivacyFilter.apply(event)
      assert.is_not_nil(filtered)
    end)

    it("should allow passage events", function()
      local event = {
        category = "passage",
        action = "view",
        timestamp = 12345,
        sessionId = "session-1",
        storyId = "story-1",
        metadata = { passageId = "intro" }
      }

      local filtered = PrivacyFilter.apply(event)
      assert.is_not_nil(filtered)
    end)

    it("should allow choice events", function()
      local event = {
        category = "choice",
        action = "selected",
        timestamp = 12345,
        sessionId = "session-1",
        storyId = "story-1",
        metadata = { choiceId = "option-1" }
      }

      local filtered = PrivacyFilter.apply(event)
      assert.is_not_nil(filtered)
    end)

    it("should discard user events", function()
      local event = {
        category = "user",
        action = "consent_change",
        timestamp = 12345,
        sessionId = "session-1",
        storyId = "story-1",
        metadata = {}
      }

      local filtered = PrivacyFilter.apply(event)
      assert.is_nil(filtered)
    end)

    it("should discard test events", function()
      local event = {
        category = "test",
        action = "exposure",
        timestamp = 12345,
        sessionId = "session-1",
        storyId = "story-1",
        metadata = {}
      }

      local filtered = PrivacyFilter.apply(event)
      assert.is_nil(filtered)
    end)

    it("should remove PII fields", function()
      local event = {
        category = "story",
        action = "start",
        timestamp = 12345,
        sessionId = "session-1",
        storyId = "story-1",
        metadata = {
          isFirstLaunch = true,
          userName = "Alice",
          userEmail = "alice@example.com",
          ipAddress = "192.168.1.1"
        }
      }

      local filtered = PrivacyFilter.apply(event)
      assert.is_not_nil(filtered)
      assert.is_nil(filtered.metadata.userName)
      assert.is_nil(filtered.metadata.userEmail)
      assert.is_nil(filtered.metadata.ipAddress)
      assert.are.equal(true, filtered.metadata.isFirstLaunch)
    end)

    it("should remove userId", function()
      local event = {
        category = "story",
        action = "start",
        timestamp = 12345,
        sessionId = "session-1",
        storyId = "story-1",
        userId = "user-123",
        metadata = {}
      }

      local filtered = PrivacyFilter.apply(event)
      assert.is_nil(filtered.userId)
    end)

    it("should use session-scoped ID", function()
      local event = {
        category = "story",
        action = "start",
        timestamp = 12345,
        sessionId = "original-session",
        storyId = "story-1",
        metadata = {}
      }

      local filtered = PrivacyFilter.apply(event)
      assert.is_string(filtered.sessionId)
      -- Session ID should be consistent within session
      local filtered2 = PrivacyFilter.apply(event)
      assert.are.equal(filtered.sessionId, filtered2.sessionId)
    end)

    it("should anonymize save names", function()
      local event = {
        category = "save",
        action = "create",
        timestamp = 12345,
        sessionId = "session-1",
        storyId = "story-1",
        metadata = {
          saveId = "save-1",
          currentPassage = "intro",
          saveName = "Alice's Save Game"
        }
      }

      local filtered = PrivacyFilter.apply(event)
      assert.is_not_nil(filtered.metadata.saveName)
      assert.are_not.equal("Alice's Save Game", filtered.metadata.saveName)
      assert.is_true(filtered.metadata.saveName:match("^Save_") ~= nil)
    end)

    it("should redact feedback text", function()
      local event = {
        category = "story",
        action = "complete",
        timestamp = 12345,
        sessionId = "session-1",
        storyId = "story-1",
        metadata = {
          completionPassage = "ending",
          feedbackText = "My name is Alice and I loved this story!"
        }
      }

      local filtered = PrivacyFilter.apply(event)
      assert.are.equal("[redacted]", filtered.metadata.feedbackText)
    end)
  end)

  describe("FULL consent level", function()
    before_each(function()
      mock_consent_manager._level = Privacy.CONSENT_LEVELS.FULL
    end)

    it("should allow all event categories", function()
      local categories = {"story", "passage", "choice", "save", "error", "user", "test"}

      for _, category in ipairs(categories) do
        local event = {
          category = category,
          action = "test_action",
          timestamp = 12345,
          sessionId = "session-1",
          storyId = "story-1",
          metadata = {}
        }

        local filtered = PrivacyFilter.apply(event)
        assert.is_not_nil(filtered, "Category " .. category .. " should be allowed at FULL")
      end
    end)

    it("should preserve all metadata", function()
      local event = {
        category = "user",
        action = "feedback",
        timestamp = 12345,
        sessionId = "session-1",
        storyId = "story-1",
        metadata = {
          userName = "Alice",
          userEmail = "alice@example.com",
          feedbackText = "Great story!",
          rating = 5
        }
      }

      local filtered = PrivacyFilter.apply(event)
      assert.are.equal("Alice", filtered.metadata.userName)
      assert.are.equal("alice@example.com", filtered.metadata.userEmail)
      assert.are.equal("Great story!", filtered.metadata.feedbackText)
    end)

    it("should include persistent userId", function()
      local event = {
        category = "story",
        action = "start",
        timestamp = 12345,
        sessionId = "session-1",
        storyId = "story-1",
        metadata = {}
      }

      local filtered = PrivacyFilter.apply(event)
      assert.are.equal("user-123", filtered.userId)
    end)
  end)

  describe("applyConsentChangeToQueue", function()
    it("should filter queue based on new consent level", function()
      local queue = {
        {
          category = "story",
          action = "start",
          timestamp = 12345,
          sessionId = "session-1",
          storyId = "story-1",
          metadata = {}
        },
        {
          category = "user",
          action = "consent_change",
          timestamp = 12346,
          sessionId = "session-1",
          storyId = "story-1",
          metadata = {}
        }
      }

      local filtered = PrivacyFilter.applyConsentChangeToQueue(queue, Privacy.CONSENT_LEVELS.ANALYTICS)

      assert.are.equal(1, #filtered)
      assert.are.equal("story", filtered[1].category)
    end)

    it("should discard all events for NONE consent", function()
      local queue = {
        {
          category = "error",
          action = "script",
          timestamp = 12345,
          sessionId = "session-1",
          storyId = "story-1",
          metadata = { errorType = "test" }
        }
      }

      local filtered = PrivacyFilter.applyConsentChangeToQueue(queue, Privacy.CONSENT_LEVELS.NONE)
      assert.are.equal(0, #filtered)
    end)
  end)

  describe("validateCompliance", function()
    it("should pass for compliant events", function()
      local event = {
        category = "passage",
        action = "view",
        timestamp = 12345,
        sessionId = "session-1",
        storyId = "story-1",
        metadata = { passageId = "intro" }
      }

      local isValid, violations = PrivacyFilter.validateCompliance(event, Privacy.CONSENT_LEVELS.ANALYTICS)
      assert.is_true(isValid)
      assert.are.equal(0, #violations)
    end)

    it("should detect userId at ANALYTICS level", function()
      local event = {
        category = "passage",
        action = "view",
        timestamp = 12345,
        sessionId = "session-1",
        storyId = "story-1",
        userId = "user-123",
        metadata = {}
      }

      local isValid, violations = PrivacyFilter.validateCompliance(event, Privacy.CONSENT_LEVELS.ANALYTICS)
      assert.is_false(isValid)
      assert.is_true(#violations > 0)
    end)

    it("should detect PII fields", function()
      local event = {
        category = "passage",
        action = "view",
        timestamp = 12345,
        sessionId = "session-1",
        storyId = "story-1",
        metadata = { userName = "Alice" }
      }

      local isValid, violations = PrivacyFilter.validateCompliance(event, Privacy.CONSENT_LEVELS.ANALYTICS)
      assert.is_false(isValid)
    end)

    it("should detect non-essential events at ESSENTIAL level", function()
      local event = {
        category = "passage",
        action = "view",
        timestamp = 12345,
        sessionId = "session-1",
        storyId = "story-1",
        metadata = {}
      }

      local isValid, violations = PrivacyFilter.validateCompliance(event, Privacy.CONSENT_LEVELS.ESSENTIAL)
      assert.is_false(isValid)
    end)
  end)

  describe("isEventAllowed", function()
    it("should return false for all events at NONE", function()
      assert.is_false(PrivacyFilter.isEventAllowed("story", "start", Privacy.CONSENT_LEVELS.NONE))
      assert.is_false(PrivacyFilter.isEventAllowed("error", "script", Privacy.CONSENT_LEVELS.NONE))
    end)

    it("should return true only for essential events at ESSENTIAL", function()
      assert.is_true(PrivacyFilter.isEventAllowed("error", "script", Privacy.CONSENT_LEVELS.ESSENTIAL))
      assert.is_true(PrivacyFilter.isEventAllowed("save", "create", Privacy.CONSENT_LEVELS.ESSENTIAL))
      assert.is_false(PrivacyFilter.isEventAllowed("passage", "view", Privacy.CONSENT_LEVELS.ESSENTIAL))
    end)

    it("should return true for behavioral events at ANALYTICS", function()
      assert.is_true(PrivacyFilter.isEventAllowed("story", "start", Privacy.CONSENT_LEVELS.ANALYTICS))
      assert.is_true(PrivacyFilter.isEventAllowed("passage", "view", Privacy.CONSENT_LEVELS.ANALYTICS))
      assert.is_false(PrivacyFilter.isEventAllowed("user", "consent_change", Privacy.CONSENT_LEVELS.ANALYTICS))
    end)

    it("should return true for all events at FULL", function()
      assert.is_true(PrivacyFilter.isEventAllowed("user", "consent_change", Privacy.CONSENT_LEVELS.FULL))
      assert.is_true(PrivacyFilter.isEventAllowed("test", "exposure", Privacy.CONSENT_LEVELS.FULL))
    end)
  end)

  describe("startNewSession", function()
    it("should generate new session ID", function()
      local session1 = PrivacyFilter._getSessionScopedId()
      PrivacyFilter.startNewSession()
      local session2 = PrivacyFilter._getSessionScopedId()

      assert.are_not.equal(session1, session2)
    end)
  end)
end)
