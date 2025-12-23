--- Privacy Filter for whisker-core Analytics
-- Consent-aware event filtering and PII removal
-- @module whisker.analytics.privacy_filter
-- @author Whisker Core Team
-- @license MIT

local PrivacyFilter = {}
PrivacyFilter.__index = PrivacyFilter
PrivacyFilter.VERSION = "1.0.0"

local Privacy = require("whisker.analytics.privacy")

--- Dependencies (injected at runtime)
PrivacyFilter._deps = {
  consent_manager = nil
}

--- Session state
PrivacyFilter._currentSessionId = nil

--- Essential event whitelist (ESSENTIAL consent level)
PrivacyFilter.ESSENTIAL_EVENTS = {
  ["error.script"] = true,
  ["error.resource"] = true,
  ["error.state"] = true,
  ["save.create"] = true,
  ["save.load"] = true
}

--- PII field patterns (fields that may contain PII)
PrivacyFilter.PII_FIELDS = {
  "userName",
  "userEmail",
  "userId",
  "ipAddress",
  "deviceId",
  "location",
  "gpsCoordinates",
  "saveName",
  "feedbackText",
  "customData"
}

--- Essential metadata fields per event type
PrivacyFilter.ESSENTIAL_METADATA = {
  ["error.script"] = {
    "errorType",
    "errorMessage",
    "stackTrace",
    "passageId",
    "scriptLine",
    "severity"
  },
  ["error.resource"] = {
    "resourceType",
    "resourceUrl",
    "errorCode",
    "retryCount"
  },
  ["error.state"] = {
    "errorType",
    "attemptedPassage",
    "currentPassage",
    "recoveryAction"
  },
  ["save.create"] = {
    "saveId",
    "currentPassage",
    "autoSave"
  },
  ["save.load"] = {
    "saveId",
    "loadedPassage"
  }
}

--- Allowed categories at ANALYTICS level
PrivacyFilter.ANALYTICS_CATEGORIES = {
  "story",
  "passage",
  "choice",
  "save",
  "error"
}

--- Set dependencies
-- @param deps table Dependencies to inject
function PrivacyFilter.setDependencies(deps)
  if deps.consent_manager then
    PrivacyFilter._deps.consent_manager = deps.consent_manager
  end
end

--- Get current consent level
-- @return number Consent level
local function getConsentLevel()
  if PrivacyFilter._deps.consent_manager and PrivacyFilter._deps.consent_manager.getConsentLevel then
    return PrivacyFilter._deps.consent_manager.getConsentLevel()
  end
  return Privacy.CONSENT_LEVELS.NONE -- Default to no tracking
end

--- Check if table contains a value
-- @param tbl table The table to search
-- @param value any The value to find
-- @return boolean True if found
local function table_contains(tbl, value)
  for _, v in ipairs(tbl) do
    if v == value then
      return true
    end
  end
  return false
end

--- Deep copy a table
-- @param tbl table The table to copy
-- @return table The copied table
local function deep_copy(tbl)
  if type(tbl) ~= "table" then
    return tbl
  end
  local copy = {}
  for key, value in pairs(tbl) do
    if type(value) == "table" then
      copy[key] = deep_copy(value)
    else
      copy[key] = value
    end
  end
  return copy
end

--- Simple hash function (for anonymization, not cryptographic)
-- @param str string String to hash
-- @return string Hash string
local function simple_hash(str)
  local hash = 0
  for i = 1, #str do
    hash = (hash * 31 + string.byte(str, i)) % 1000000
  end
  return tostring(hash)
end

--- Generate UUID v4
-- @return string UUID string
local function generate_uuid()
  local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
  return string.gsub(template, "[xy]", function(c)
    local v = (c == "x") and math.random(0, 0xf) or math.random(8, 0xb)
    return string.format("%x", v)
  end)
end

--- Apply privacy filter to event
-- @param event table The event to filter
-- @return table|nil Filtered event, or nil if event should be discarded
function PrivacyFilter.apply(event)
  local consentLevel = getConsentLevel()

  if consentLevel == Privacy.CONSENT_LEVELS.NONE then
    return nil
  end

  if consentLevel == Privacy.CONSENT_LEVELS.ESSENTIAL then
    return PrivacyFilter._filterEssential(event)
  end

  if consentLevel == Privacy.CONSENT_LEVELS.ANALYTICS then
    return PrivacyFilter._filterAnalytics(event)
  end

  if consentLevel == Privacy.CONSENT_LEVELS.FULL then
    return PrivacyFilter._filterFull(event)
  end

  -- Unknown consent level, default to discard
  return nil
end

--- Copy base event fields (without metadata)
-- @param event table The event to copy
-- @return table Copied base event
function PrivacyFilter._copyEventBase(event)
  return {
    category = event.category,
    action = event.action,
    timestamp = event.timestamp,
    sessionId = event.sessionId,
    sessionStart = event.sessionStart,
    storyId = event.storyId,
    storyVersion = event.storyVersion,
    storyTitle = event.storyTitle
  }
end

--- Filter for ESSENTIAL consent level
-- @param event table The event to filter
-- @return table|nil Filtered event
function PrivacyFilter._filterEssential(event)
  local eventType = event.category .. "." .. event.action

  -- Check if event is in essential whitelist
  if not PrivacyFilter.ESSENTIAL_EVENTS[eventType] then
    return nil
  end

  -- Strip all non-essential metadata
  local filteredEvent = PrivacyFilter._copyEventBase(event)
  filteredEvent.metadata = PrivacyFilter._stripNonEssentialMetadata(
    event.metadata,
    eventType
  )

  -- Remove user ID
  filteredEvent.userId = nil

  return filteredEvent
end

--- Filter for ANALYTICS consent level
-- @param event table The event to filter
-- @return table|nil Filtered event
function PrivacyFilter._filterAnalytics(event)
  -- Check if category is allowed
  if not table_contains(PrivacyFilter.ANALYTICS_CATEGORIES, event.category) then
    return nil
  end

  -- Copy event
  local filteredEvent = PrivacyFilter._copyEventBase(event)

  -- Remove PII from metadata
  filteredEvent.metadata = PrivacyFilter._removePII(event.metadata)

  -- Remove persistent user ID
  filteredEvent.userId = nil

  -- Use session-scoped ID
  filteredEvent.sessionId = PrivacyFilter._getSessionScopedId()

  return filteredEvent
end

--- Filter for FULL consent level
-- @param event table The event to filter
-- @return table Filtered event (all events allowed)
function PrivacyFilter._filterFull(event)
  local filteredEvent = PrivacyFilter._copyEventBase(event)
  filteredEvent.metadata = deep_copy(event.metadata or {})

  -- Add persistent user ID
  if PrivacyFilter._deps.consent_manager and PrivacyFilter._deps.consent_manager.getUserId then
    filteredEvent.userId = PrivacyFilter._deps.consent_manager.getUserId()
  end

  return filteredEvent
end

--- Strip non-essential metadata for ESSENTIAL tier
-- @param metadata table The metadata to strip
-- @param eventType string The event type
-- @return table Stripped metadata
function PrivacyFilter._stripNonEssentialMetadata(metadata, eventType)
  if not metadata then
    return {}
  end

  local fields = PrivacyFilter.ESSENTIAL_METADATA[eventType] or {}
  local stripped = {}

  for _, field in ipairs(fields) do
    if metadata[field] ~= nil then
      stripped[field] = metadata[field]
    end
  end

  return stripped
end

--- Remove PII from metadata
-- @param metadata table The metadata to clean
-- @return table Cleaned metadata
function PrivacyFilter._removePII(metadata)
  if not metadata then
    return {}
  end

  local cleaned = deep_copy(metadata)

  -- Anonymize save names first (before removal)
  if cleaned.saveName then
    cleaned.saveName = PrivacyFilter._anonymizeSaveName(cleaned.saveName)
  end

  -- Redact feedback text (keep field but redact content)
  if metadata.feedbackText then
    cleaned.feedbackText = "[redacted]"
  end

  -- Remove known PII fields (except saveName and feedbackText which we handle specially)
  for _, field in ipairs(PrivacyFilter.PII_FIELDS) do
    if field ~= "saveName" and field ~= "feedbackText" then
      cleaned[field] = nil
    end
  end

  return cleaned
end

--- Anonymize save name
-- @param saveName string The save name
-- @return string Anonymized name
function PrivacyFilter._anonymizeSaveName(saveName)
  return "Save_" .. simple_hash(saveName)
end

--- Get session-scoped ID
-- @return string Session ID
function PrivacyFilter._getSessionScopedId()
  if not PrivacyFilter._currentSessionId then
    PrivacyFilter._currentSessionId = generate_uuid()
  end
  return PrivacyFilter._currentSessionId
end

--- Start new session (generates new session-scoped ID)
function PrivacyFilter.startNewSession()
  PrivacyFilter._currentSessionId = generate_uuid()
  return PrivacyFilter._currentSessionId
end

--- Apply consent change retroactively to queued events
-- @param queue table Array of events
-- @param newConsentLevel number New consent level
-- @return table Filtered queue
function PrivacyFilter.applyConsentChangeToQueue(queue, newConsentLevel)
  local filteredQueue = {}

  -- Store original consent manager state
  local originalConsentManager = PrivacyFilter._deps.consent_manager

  -- Create temporary consent manager with override
  PrivacyFilter._deps.consent_manager = {
    getConsentLevel = function()
      return newConsentLevel
    end,
    getUserId = originalConsentManager and originalConsentManager.getUserId or function() return nil end
  }

  for _, event in ipairs(queue) do
    local filteredEvent = PrivacyFilter.apply(event)
    if filteredEvent then
      table.insert(filteredQueue, filteredEvent)
    end
  end

  -- Restore original consent manager
  PrivacyFilter._deps.consent_manager = originalConsentManager

  return filteredQueue
end

--- Validate event for privacy compliance
-- @param event table The event to validate
-- @param consentLevel number The consent level
-- @return boolean True if compliant
-- @return table Array of violations
function PrivacyFilter.validateCompliance(event, consentLevel)
  local violations = {}

  -- Check for PII at lower consent levels
  if consentLevel < Privacy.CONSENT_LEVELS.FULL then
    if event.userId then
      table.insert(violations, "Persistent userId present at consent level " .. consentLevel)
    end

    for _, field in ipairs(PrivacyFilter.PII_FIELDS) do
      if event.metadata and event.metadata[field] then
        table.insert(violations, "PII field '" .. field .. "' present at consent level " .. consentLevel)
      end
    end
  end

  -- Check event is allowed at consent level
  if consentLevel == Privacy.CONSENT_LEVELS.ESSENTIAL then
    local eventType = event.category .. "." .. event.action
    if not PrivacyFilter.ESSENTIAL_EVENTS[eventType] then
      table.insert(violations, "Non-essential event '" .. eventType .. "' at ESSENTIAL consent level")
    end
  end

  if consentLevel == Privacy.CONSENT_LEVELS.ANALYTICS then
    if not table_contains(PrivacyFilter.ANALYTICS_CATEGORIES, event.category) then
      table.insert(violations, "Category '" .. event.category .. "' not allowed at ANALYTICS consent level")
    end
  end

  return #violations == 0, violations
end

--- Check if event would be allowed at consent level
-- @param category string Event category
-- @param action string Event action
-- @param consentLevel number Consent level
-- @return boolean True if allowed
function PrivacyFilter.isEventAllowed(category, action, consentLevel)
  if consentLevel == Privacy.CONSENT_LEVELS.NONE then
    return false
  end

  if consentLevel == Privacy.CONSENT_LEVELS.ESSENTIAL then
    local eventType = category .. "." .. action
    return PrivacyFilter.ESSENTIAL_EVENTS[eventType] == true
  end

  if consentLevel == Privacy.CONSENT_LEVELS.ANALYTICS then
    return table_contains(PrivacyFilter.ANALYTICS_CATEGORIES, category)
  end

  -- FULL allows everything
  return true
end

--- Reset filter state (for testing)
function PrivacyFilter.reset()
  PrivacyFilter._currentSessionId = nil
  PrivacyFilter._deps.consent_manager = nil
end

return PrivacyFilter
