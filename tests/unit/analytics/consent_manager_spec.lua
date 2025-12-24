--- Consent Manager Tests
-- @module tests.unit.analytics.consent_manager_spec
describe("ConsentManager", function()
  local ConsentManager
  local Privacy
  local mock_storage

  before_each(function()
    package.loaded["whisker.analytics.consent_manager"] = nil
    package.loaded["whisker.analytics.privacy"] = nil

    ConsentManager = require("whisker.analytics.consent_manager")
    Privacy = require("whisker.analytics.privacy")

    ConsentManager.reset()

    -- Create mock storage
    mock_storage = {
      _data = {},
      get = function(key)
        return mock_storage._data[key]
      end,
      set = function(key, value)
        mock_storage._data[key] = value
      end,
      remove = function(key)
        mock_storage._data[key] = nil
      end
    }

    ConsentManager.setDependencies({
      storage = mock_storage
    })
    ConsentManager.initialize({})
  end)

  describe("getConsentLevel", function()
    it("should default to NONE", function()
      ConsentManager.reset()
      ConsentManager.initialize({})
      assert.are.equal(Privacy.CONSENT_LEVELS.NONE, ConsentManager.getConsentLevel())
    end)
  end)

  describe("setConsentLevel", function()
    it("should set valid consent levels", function()
      local success = ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.ANALYTICS)
      assert.is_true(success)
      assert.are.equal(Privacy.CONSENT_LEVELS.ANALYTICS, ConsentManager.getConsentLevel())
    end)

    it("should reject invalid consent levels", function()
      local success, err = ConsentManager.setConsentLevel(99)
      assert.is_false(success)
      assert.is_not_nil(err)
    end)

    it("should persist consent to storage", function()
      ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.FULL)
      local stored = mock_storage._data["whisker_consent"]
      assert.is_not_nil(stored)
      assert.are.equal(Privacy.CONSENT_LEVELS.FULL, stored.level)
    end)

    it("should record consent timestamp", function()
      ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.ANALYTICS)
      local timestamp = ConsentManager.getConsentTimestamp()
      assert.is_number(timestamp)
      assert.is_true(timestamp > 0)
    end)
  end)

  describe("getUserId", function()
    it("should return nil at NONE consent", function()
      ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.NONE)
      assert.is_nil(ConsentManager.getUserId())
    end)

    it("should return nil at ESSENTIAL consent", function()
      ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.ESSENTIAL)
      assert.is_nil(ConsentManager.getUserId())
    end)

    it("should return nil at ANALYTICS consent", function()
      ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.ANALYTICS)
      assert.is_nil(ConsentManager.getUserId())
    end)

    it("should return user ID at FULL consent", function()
      ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.FULL)
      local userId = ConsentManager.getUserId()
      assert.is_string(userId)
      assert.is_true(#userId > 0)
    end)

    it("should return consistent user ID", function()
      ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.FULL)
      local userId1 = ConsentManager.getUserId()
      local userId2 = ConsentManager.getUserId()
      assert.are.equal(userId1, userId2)
    end)
  end)

  describe("getSessionId", function()
    it("should return a session ID", function()
      local sessionId = ConsentManager.getSessionId()
      assert.is_string(sessionId)
      assert.is_true(#sessionId > 0)
    end)

    it("should return consistent session ID", function()
      local sessionId1 = ConsentManager.getSessionId()
      local sessionId2 = ConsentManager.getSessionId()
      assert.are.equal(sessionId1, sessionId2)
    end)
  end)

  describe("startNewSession", function()
    it("should generate new session ID", function()
      local oldSessionId = ConsentManager.getSessionId()
      local newSessionId = ConsentManager.startNewSession()
      assert.are_not.equal(oldSessionId, newSessionId)
    end)
  end)

  describe("hasConsent", function()
    it("should return false at NONE", function()
      ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.NONE)
      assert.is_false(ConsentManager.hasConsent())
    end)

    it("should return true at ESSENTIAL", function()
      ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.ESSENTIAL)
      assert.is_true(ConsentManager.hasConsent())
    end)

    it("should return true at ANALYTICS", function()
      ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.ANALYTICS)
      assert.is_true(ConsentManager.hasConsent())
    end)

    it("should return true at FULL", function()
      ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.FULL)
      assert.is_true(ConsentManager.hasConsent())
    end)
  end)

  describe("requiresConsentDialog", function()
    it("should return true if no consent given", function()
      ConsentManager.reset()
      ConsentManager.initialize({ requireConsentOnStart = true })
      assert.is_true(ConsentManager.requiresConsentDialog())
    end)

    it("should return false after consent given", function()
      ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.ANALYTICS)
      assert.is_false(ConsentManager.requiresConsentDialog())
    end)
  end)

  describe("getConsentState", function()
    it("should return complete state object", function()
      ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.ANALYTICS)
      local state = ConsentManager.getConsentState()

      assert.are.equal(Privacy.CONSENT_LEVELS.ANALYTICS, state.level)
      assert.are.equal("Analytics", state.levelName)
      assert.is_number(state.timestamp)
      assert.is_string(state.version)
      assert.is_true(state.hasConsent)
      assert.is_nil(state.userId) -- nil at ANALYTICS
      assert.is_string(state.sessionId)
    end)
  end)

  describe("getConsentOptions", function()
    it("should return all consent level options", function()
      local options = ConsentManager.getConsentOptions()
      assert.are.equal(4, #options)
      assert.are.equal(0, options[1].level)
      assert.are.equal(3, options[4].level)
    end)
  end)

  describe("exportUserData", function()
    it("should return user data", function()
      ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.FULL)
      local data = ConsentManager.exportUserData()

      assert.is_string(data.userId)
      assert.is_string(data.sessionId)
      assert.are.equal(Privacy.CONSENT_LEVELS.FULL, data.consentLevel)
    end)
  end)

  describe("deleteUserData", function()
    it("should clear all user data", function()
      ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.FULL)
      local userId = ConsentManager.getUserId()
      assert.is_not_nil(userId)

      ConsentManager.deleteUserData()

      assert.are.equal(Privacy.CONSENT_LEVELS.NONE, ConsentManager.getConsentLevel())
      assert.is_nil(ConsentManager.getUserId())
    end)

    it("should clear storage", function()
      ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.FULL)
      ConsentManager.deleteUserData()

      assert.is_nil(mock_storage._data["whisker_consent"])
      assert.is_nil(mock_storage._data["whisker_user_id"])
    end)
  end)

  describe("consent persistence", function()
    it("should load consent from storage on initialize", function()
      -- Pre-populate storage
      mock_storage._data["whisker_consent"] = {
        level = Privacy.CONSENT_LEVELS.ANALYTICS,
        timestamp = 12345,
        version = "1.0.0"
      }

      ConsentManager.reset()
      ConsentManager.setDependencies({ storage = mock_storage })
      ConsentManager.initialize({})

      assert.are.equal(Privacy.CONSENT_LEVELS.ANALYTICS, ConsentManager.getConsentLevel())
    end)

    it("should load user ID from storage", function()
      mock_storage._data["whisker_user_id"] = "stored-user-id"
      mock_storage._data["whisker_consent"] = {
        level = Privacy.CONSENT_LEVELS.FULL,
        timestamp = 12345
      }

      ConsentManager.reset()
      ConsentManager.setDependencies({ storage = mock_storage })
      ConsentManager.initialize({})

      assert.are.equal("stored-user-id", ConsentManager.getUserId())
    end)
  end)

  describe("consent level changes", function()
    it("should clear user ID when downgrading from FULL", function()
      ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.FULL)
      assert.is_not_nil(ConsentManager.getUserId())

      ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.ANALYTICS)
      assert.is_nil(ConsentManager.getUserId())
    end)

    it("should restore user ID when upgrading to FULL", function()
      ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.FULL)
      ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.ANALYTICS)
      ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.FULL)

      assert.is_not_nil(ConsentManager.getUserId())
    end)
  end)
end)
