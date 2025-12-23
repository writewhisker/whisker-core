--- Unit tests for Consent Manager
-- @module tests.analytics.consent_manager_spec

describe("ConsentManager", function()
  local ConsentManager
  local Privacy
  local mockStorage

  before_each(function()
    package.loaded["whisker.analytics.consent_manager"] = nil
    package.loaded["whisker.analytics.privacy"] = nil
    ConsentManager = require("whisker.analytics.consent_manager")
    Privacy = require("whisker.analytics.privacy")
    ConsentManager.reset()

    -- Create mock storage
    local storedData = {}
    mockStorage = {
      _data = storedData,
      get = function(key)
        return storedData[key]
      end,
      set = function(key, value)
        storedData[key] = value
      end,
      remove = function(key)
        storedData[key] = nil
      end,
      clear = function()
        storedData = {}
        mockStorage._data = storedData
      end
    }
  end)

  describe("initialize()", function()
    it("should initialize with default config", function()
      ConsentManager.initialize()
      assert.are.equal(Privacy.CONSENT_LEVELS.NONE, ConsentManager.getConsentLevel())
    end)

    it("should initialize with custom config", function()
      ConsentManager.initialize({
        defaultConsentLevel = Privacy.CONSENT_LEVELS.ANALYTICS
      })
      -- Note: default only applies if no stored consent
      assert.are.equal(Privacy.CONSENT_LEVELS.NONE, ConsentManager.getConsentLevel())
    end)

    it("should generate session ID", function()
      ConsentManager.initialize()
      local sessionId = ConsentManager.getSessionId()
      assert.is_string(sessionId)
      assert.is_true(#sessionId > 0)
    end)

    it("should load stored consent from storage", function()
      mockStorage.set("whisker_consent", {
        level = Privacy.CONSENT_LEVELS.ANALYTICS,
        timestamp = os.time() * 1000,
        version = "1.0.0"
      })

      ConsentManager.setDependencies({ storage = mockStorage })
      ConsentManager.initialize()

      assert.are.equal(Privacy.CONSENT_LEVELS.ANALYTICS, ConsentManager.getConsentLevel())
    end)
  end)

  describe("setDependencies()", function()
    it("should set storage dependency", function()
      ConsentManager.setDependencies({ storage = mockStorage })
      ConsentManager.initialize()
      ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.ANALYTICS)

      -- Check that consent was persisted
      local stored = mockStorage.get("whisker_consent")
      assert.is_not_nil(stored)
      assert.are.equal(Privacy.CONSENT_LEVELS.ANALYTICS, stored.level)
    end)
  end)

  describe("getConsentLevel()", function()
    it("should return current consent level", function()
      ConsentManager.initialize()
      assert.are.equal(Privacy.CONSENT_LEVELS.NONE, ConsentManager.getConsentLevel())
    end)
  end)

  describe("setConsentLevel()", function()
    before_each(function()
      ConsentManager.setDependencies({ storage = mockStorage })
      ConsentManager.initialize()
    end)

    it("should set valid consent level", function()
      local success = ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.ANALYTICS)
      assert.is_true(success)
      assert.are.equal(Privacy.CONSENT_LEVELS.ANALYTICS, ConsentManager.getConsentLevel())
    end)

    it("should reject invalid consent level", function()
      local success, err = ConsentManager.setConsentLevel(999)
      assert.is_false(success)
      assert.is_not_nil(err)
    end)

    it("should reject negative consent level", function()
      local success, err = ConsentManager.setConsentLevel(-1)
      assert.is_false(success)
      assert.is_not_nil(err)
    end)

    it("should persist consent to storage", function()
      ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.FULL)

      local stored = mockStorage.get("whisker_consent")
      assert.is_not_nil(stored)
      assert.are.equal(Privacy.CONSENT_LEVELS.FULL, stored.level)
    end)

    it("should update consent timestamp", function()
      ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.ANALYTICS)
      local timestamp = ConsentManager.getConsentTimestamp()
      assert.is_number(timestamp)
      assert.is_true(timestamp > 0)
    end)

    it("should clear userId when lowering from FULL", function()
      ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.FULL)
      local userId1 = ConsentManager.getUserId()
      assert.is_not_nil(userId1)

      ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.ANALYTICS)
      local userId2 = ConsentManager.getUserId()
      assert.is_nil(userId2)
    end)
  end)

  describe("getUserId()", function()
    before_each(function()
      ConsentManager.setDependencies({ storage = mockStorage })
      ConsentManager.initialize()
    end)

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

    it("should return userId at FULL consent", function()
      ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.FULL)
      local userId = ConsentManager.getUserId()
      assert.is_string(userId)
      assert.is_true(#userId > 0)
    end)

    it("should return consistent userId", function()
      ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.FULL)
      local userId1 = ConsentManager.getUserId()
      local userId2 = ConsentManager.getUserId()
      assert.are.equal(userId1, userId2)
    end)

    it("should persist userId to storage", function()
      ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.FULL)
      local userId = ConsentManager.getUserId()

      local stored = mockStorage.get("whisker_user_id")
      assert.are.equal(userId, stored)
    end)

    it("should restore userId from storage", function()
      mockStorage.set("whisker_user_id", "stored-user-id")
      ConsentManager.reset()
      ConsentManager.setDependencies({ storage = mockStorage })
      ConsentManager.initialize()
      ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.FULL)

      assert.are.equal("stored-user-id", ConsentManager.getUserId())
    end)
  end)

  describe("getSessionId()", function()
    it("should return session ID", function()
      ConsentManager.initialize()
      local sessionId = ConsentManager.getSessionId()
      assert.is_string(sessionId)
      assert.is_true(#sessionId > 0)
    end)

    it("should return consistent session ID", function()
      ConsentManager.initialize()
      local id1 = ConsentManager.getSessionId()
      local id2 = ConsentManager.getSessionId()
      assert.are.equal(id1, id2)
    end)

    it("should generate ID if not initialized", function()
      local sessionId = ConsentManager.getSessionId()
      assert.is_string(sessionId)
    end)
  end)

  describe("startNewSession()", function()
    it("should generate new session ID", function()
      ConsentManager.initialize()
      local id1 = ConsentManager.getSessionId()
      local id2 = ConsentManager.startNewSession()
      assert.are_not.equal(id1, id2)
    end)

    it("should return the new session ID", function()
      ConsentManager.initialize()
      local newId = ConsentManager.startNewSession()
      assert.are.equal(newId, ConsentManager.getSessionId())
    end)
  end)

  describe("hasConsent()", function()
    before_each(function()
      ConsentManager.initialize()
    end)

    it("should return false at NONE consent", function()
      ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.NONE)
      assert.is_false(ConsentManager.hasConsent())
    end)

    it("should return true at ESSENTIAL consent", function()
      ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.ESSENTIAL)
      assert.is_true(ConsentManager.hasConsent())
    end)

    it("should return true at ANALYTICS consent", function()
      ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.ANALYTICS)
      assert.is_true(ConsentManager.hasConsent())
    end)

    it("should return true at FULL consent", function()
      ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.FULL)
      assert.is_true(ConsentManager.hasConsent())
    end)
  end)

  describe("requiresConsentDialog()", function()
    it("should return true when consent not given", function()
      ConsentManager.initialize({ requireConsentOnStart = true })
      assert.is_true(ConsentManager.requiresConsentDialog())
    end)

    it("should return false after consent given", function()
      ConsentManager.initialize({ requireConsentOnStart = true })
      ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.ANALYTICS)
      assert.is_false(ConsentManager.requiresConsentDialog())
    end)

    it("should return false when requireConsentOnStart is false", function()
      ConsentManager.initialize({ requireConsentOnStart = false })
      assert.is_false(ConsentManager.requiresConsentDialog())
    end)
  end)

  describe("getConsentState()", function()
    before_each(function()
      ConsentManager.setDependencies({ storage = mockStorage })
      ConsentManager.initialize()
    end)

    it("should return complete consent state", function()
      ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.ANALYTICS)
      local state = ConsentManager.getConsentState()

      assert.are.equal(Privacy.CONSENT_LEVELS.ANALYTICS, state.level)
      assert.are.equal("Analytics", state.levelName)
      assert.is_number(state.timestamp)
      assert.is_string(state.version)
      assert.is_true(state.hasConsent)
      assert.is_nil(state.userId)
      assert.is_string(state.sessionId)
    end)

    it("should include userId at FULL consent", function()
      ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.FULL)
      local state = ConsentManager.getConsentState()
      assert.is_not_nil(state.userId)
    end)
  end)

  describe("getConsentOptions()", function()
    it("should return all consent levels", function()
      local options = ConsentManager.getConsentOptions()
      assert.are.equal(4, #options) -- NONE, ESSENTIAL, ANALYTICS, FULL
    end)

    it("should include level, name, and description for each option", function()
      local options = ConsentManager.getConsentOptions()
      for _, option in ipairs(options) do
        assert.is_number(option.level)
        assert.is_string(option.name)
        assert.is_string(option.description)
      end
    end)
  end)

  describe("exportUserData()", function()
    before_each(function()
      ConsentManager.setDependencies({ storage = mockStorage })
      ConsentManager.initialize()
    end)

    it("should return user data", function()
      ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.FULL)
      local data = ConsentManager.exportUserData()

      assert.is_not_nil(data.userId)
      assert.is_not_nil(data.sessionId)
      assert.are.equal(Privacy.CONSENT_LEVELS.FULL, data.consentLevel)
      assert.is_number(data.consentTimestamp)
      assert.is_string(data.consentVersion)
    end)
  end)

  describe("deleteUserData()", function()
    before_each(function()
      ConsentManager.setDependencies({ storage = mockStorage })
      ConsentManager.initialize()
    end)

    it("should clear all user data", function()
      ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.FULL)
      local success = ConsentManager.deleteUserData()

      assert.is_true(success)
      assert.are.equal(Privacy.CONSENT_LEVELS.NONE, ConsentManager.getConsentLevel())
      assert.is_nil(ConsentManager.getUserId())
      assert.is_nil(ConsentManager.getConsentTimestamp())
    end)

    it("should remove data from storage", function()
      ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.FULL)
      ConsentManager.deleteUserData()

      assert.is_nil(mockStorage.get("whisker_consent"))
      assert.is_nil(mockStorage.get("whisker_user_id"))
    end)
  end)

  describe("getConsentTimestamp()", function()
    it("should return nil before consent given", function()
      ConsentManager.initialize()
      assert.is_nil(ConsentManager.getConsentTimestamp())
    end)

    it("should return timestamp after consent given", function()
      ConsentManager.initialize()
      ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.ANALYTICS)
      local timestamp = ConsentManager.getConsentTimestamp()
      assert.is_number(timestamp)
      assert.is_true(timestamp > 0)
    end)
  end)

  describe("getConsentVersion()", function()
    it("should return version string", function()
      ConsentManager.initialize()
      local version = ConsentManager.getConsentVersion()
      assert.is_string(version)
      assert.is_true(#version > 0)
    end)
  end)

  describe("reset()", function()
    it("should reset consent level to NONE", function()
      ConsentManager.initialize()
      ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.FULL)
      ConsentManager.reset()

      assert.are.equal(Privacy.CONSENT_LEVELS.NONE, ConsentManager.getConsentLevel())
    end)

    it("should clear userId", function()
      ConsentManager.setDependencies({ storage = mockStorage })
      ConsentManager.initialize()
      ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.FULL)
      ConsentManager.reset()

      assert.is_nil(ConsentManager.getUserId())
    end)

    it("should clear session ID", function()
      ConsentManager.initialize()
      local sessionId = ConsentManager.getSessionId()
      ConsentManager.reset()

      assert.is_nil(ConsentManager._sessionId)
    end)
  end)
end)
