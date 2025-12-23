--- Consent Manager for whisker-core Analytics
-- Manages user consent preferences and persistence
-- @module whisker.analytics.consent_manager
-- @author Whisker Core Team
-- @license MIT

local ConsentManager = {}
ConsentManager.__index = ConsentManager
ConsentManager.VERSION = "1.0.0"

local Privacy = require("whisker.analytics.privacy")

--- State
ConsentManager._consentLevel = Privacy.CONSENT_LEVELS.NONE
ConsentManager._userId = nil
ConsentManager._sessionId = nil
ConsentManager._consentTimestamp = nil
ConsentManager._consentVersion = "1.0.0"
ConsentManager._initialized = false

--- Dependencies
ConsentManager._deps = {
  storage = nil,
  event_builder = nil
}

--- Configuration
ConsentManager._config = {
  storageKey = "whisker_consent",
  userIdStorageKey = "whisker_user_id",
  requireConsentOnStart = true,
  defaultConsentLevel = Privacy.CONSENT_LEVELS.NONE
}

--- Generate UUID v4
-- @return string UUID
local function generate_uuid()
  local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
  return string.gsub(template, "[xy]", function(c)
    local v = (c == "x") and math.random(0, 0xf) or math.random(8, 0xb)
    return string.format("%x", v)
  end)
end

--- Get current timestamp in milliseconds
-- @return number Timestamp
local function get_timestamp()
  return os.time() * 1000
end

--- Set dependencies
-- @param deps table Dependencies to inject
function ConsentManager.setDependencies(deps)
  if deps.storage then
    ConsentManager._deps.storage = deps.storage
  end
  if deps.event_builder then
    ConsentManager._deps.event_builder = deps.event_builder
  end
end

--- Initialize consent manager
-- @param config table Configuration options
function ConsentManager.initialize(config)
  config = config or {}

  -- Merge configuration
  for key, value in pairs(config) do
    if ConsentManager._config[key] ~= nil then
      ConsentManager._config[key] = value
    end
  end

  -- Load persisted consent
  ConsentManager._loadConsent()

  -- Generate or load user ID
  ConsentManager._initializeUserId()

  -- Generate session ID
  ConsentManager._sessionId = generate_uuid()

  ConsentManager._initialized = true
end

--- Get current consent level
-- @return number Consent level
function ConsentManager.getConsentLevel()
  return ConsentManager._consentLevel
end

--- Set consent level
-- @param level number The consent level to set
-- @param source string Optional source of the change (e.g., "initial_dialog", "settings")
-- @return boolean Success
-- @return string|nil Error message
function ConsentManager.setConsentLevel(level, source)
  if not Privacy.isValidConsentLevel(level) then
    return false, "Invalid consent level: " .. tostring(level)
  end

  local previousLevel = ConsentManager._consentLevel
  ConsentManager._consentLevel = level
  ConsentManager._consentTimestamp = get_timestamp()

  -- Persist consent
  ConsentManager._saveConsent()

  -- Handle user ID based on consent level
  if level < Privacy.CONSENT_LEVELS.FULL then
    -- Clear persistent user ID at lower consent levels
    ConsentManager._clearUserId()
  else
    -- Ensure user ID exists for FULL consent
    ConsentManager._initializeUserId()
  end

  -- Track consent change event (only if we have an event builder and consent allows)
  if ConsentManager._deps.event_builder and level >= Privacy.CONSENT_LEVELS.ESSENTIAL then
    -- Note: The actual tracking would happen through the collector
    -- This is just for recording the change internally
  end

  return true
end

--- Get user ID (only available at FULL consent)
-- @return string|nil User ID or nil if not at FULL consent
function ConsentManager.getUserId()
  if ConsentManager._consentLevel >= Privacy.CONSENT_LEVELS.FULL then
    return ConsentManager._userId
  end
  return nil
end

--- Get session ID
-- @return string Session ID
function ConsentManager.getSessionId()
  if not ConsentManager._sessionId then
    ConsentManager._sessionId = generate_uuid()
  end
  return ConsentManager._sessionId
end

--- Start new session
-- @return string New session ID
function ConsentManager.startNewSession()
  ConsentManager._sessionId = generate_uuid()
  return ConsentManager._sessionId
end

--- Get consent timestamp
-- @return number|nil Timestamp when consent was given
function ConsentManager.getConsentTimestamp()
  return ConsentManager._consentTimestamp
end

--- Get consent version
-- @return string Consent version
function ConsentManager.getConsentVersion()
  return ConsentManager._consentVersion
end

--- Check if consent has been given
-- @return boolean True if any consent level above NONE
function ConsentManager.hasConsent()
  return ConsentManager._consentLevel > Privacy.CONSENT_LEVELS.NONE
end

--- Check if requires initial consent dialog
-- @return boolean True if should show dialog
function ConsentManager.requiresConsentDialog()
  return ConsentManager._config.requireConsentOnStart and
         ConsentManager._consentTimestamp == nil
end

--- Get consent state
-- @return table Consent state object
function ConsentManager.getConsentState()
  return {
    level = ConsentManager._consentLevel,
    levelName = Privacy.getConsentLevelName(ConsentManager._consentLevel),
    timestamp = ConsentManager._consentTimestamp,
    version = ConsentManager._consentVersion,
    hasConsent = ConsentManager.hasConsent(),
    userId = ConsentManager.getUserId(),
    sessionId = ConsentManager.getSessionId()
  }
end

--- Get all consent level options (for UI)
-- @return table Array of consent level options
function ConsentManager.getConsentOptions()
  return Privacy.getAllConsentLevels()
end

--- Export user data
-- @return table User's analytics data
function ConsentManager.exportUserData()
  return {
    userId = ConsentManager._userId,
    sessionId = ConsentManager._sessionId,
    consentLevel = ConsentManager._consentLevel,
    consentTimestamp = ConsentManager._consentTimestamp,
    consentVersion = ConsentManager._consentVersion
  }
end

--- Delete user data
-- @return boolean Success
function ConsentManager.deleteUserData()
  -- Clear all user data
  ConsentManager._userId = nil
  ConsentManager._consentLevel = Privacy.CONSENT_LEVELS.NONE
  ConsentManager._consentTimestamp = nil

  -- Clear persisted data
  if ConsentManager._deps.storage then
    ConsentManager._deps.storage.remove(ConsentManager._config.storageKey)
    ConsentManager._deps.storage.remove(ConsentManager._config.userIdStorageKey)
  end

  return true
end

--- Load consent from storage
function ConsentManager._loadConsent()
  if not ConsentManager._deps.storage then
    return
  end

  local data = ConsentManager._deps.storage.get(ConsentManager._config.storageKey)
  if data and type(data) == "table" then
    if Privacy.isValidConsentLevel(data.level) then
      ConsentManager._consentLevel = data.level
    end
    ConsentManager._consentTimestamp = data.timestamp
    ConsentManager._consentVersion = data.version or ConsentManager._consentVersion
  end
end

--- Save consent to storage
function ConsentManager._saveConsent()
  if not ConsentManager._deps.storage then
    return
  end

  local data = {
    level = ConsentManager._consentLevel,
    timestamp = ConsentManager._consentTimestamp,
    version = ConsentManager._consentVersion
  }

  ConsentManager._deps.storage.set(ConsentManager._config.storageKey, data)
end

--- Initialize user ID
function ConsentManager._initializeUserId()
  if ConsentManager._userId then
    return
  end

  -- Try to load from storage
  if ConsentManager._deps.storage then
    local storedId = ConsentManager._deps.storage.get(ConsentManager._config.userIdStorageKey)
    if storedId and type(storedId) == "string" then
      ConsentManager._userId = storedId
      return
    end
  end

  -- Generate new user ID
  ConsentManager._userId = generate_uuid()

  -- Persist user ID
  if ConsentManager._deps.storage then
    ConsentManager._deps.storage.set(ConsentManager._config.userIdStorageKey, ConsentManager._userId)
  end
end

--- Clear user ID
function ConsentManager._clearUserId()
  ConsentManager._userId = nil

  if ConsentManager._deps.storage then
    ConsentManager._deps.storage.remove(ConsentManager._config.userIdStorageKey)
  end
end

--- Reset consent manager (for testing)
function ConsentManager.reset()
  ConsentManager._consentLevel = Privacy.CONSENT_LEVELS.NONE
  ConsentManager._userId = nil
  ConsentManager._sessionId = nil
  ConsentManager._consentTimestamp = nil
  ConsentManager._initialized = false
  ConsentManager._deps.storage = nil
  ConsentManager._deps.event_builder = nil
end

return ConsentManager
