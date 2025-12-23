--- Event Builder for whisker-core Analytics
-- Utilities for creating well-formed analytics events
-- @module whisker.analytics.event_builder
-- @author Whisker Core Team
-- @license MIT

local EventBuilder = {}
EventBuilder.__index = EventBuilder
EventBuilder.VERSION = "1.0.0"

--- Dependencies (injected at runtime)
EventBuilder._deps = {
  event_taxonomy = nil,
  consent_manager = nil,
  session_manager = nil,
  story_context = nil
}

--- Configuration
EventBuilder._config = {
  storyId = "unknown",
  storyVersion = "1.0.0",
  storyTitle = "Unknown Story"
}

--- Session state
EventBuilder._session = {
  id = nil,
  startTime = nil
}

--- Generate a UUID v4
-- @return string A new UUID
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
  -- os.time() returns seconds, multiply by 1000 for milliseconds
  return os.time() * 1000
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

--- Initialize the event builder
-- @param config table Configuration options
function EventBuilder.initialize(config)
  config = config or {}

  if config.storyId then
    EventBuilder._config.storyId = config.storyId
  end
  if config.storyVersion then
    EventBuilder._config.storyVersion = config.storyVersion
  end
  if config.storyTitle then
    EventBuilder._config.storyTitle = config.storyTitle
  end

  -- Initialize session
  EventBuilder._session.id = generate_uuid()
  EventBuilder._session.startTime = get_timestamp()
end

--- Set dependencies
-- @param deps table Dependencies to inject
function EventBuilder.setDependencies(deps)
  if deps.event_taxonomy then
    EventBuilder._deps.event_taxonomy = deps.event_taxonomy
  end
  if deps.consent_manager then
    EventBuilder._deps.consent_manager = deps.consent_manager
  end
  if deps.session_manager then
    EventBuilder._deps.session_manager = deps.session_manager
  end
  if deps.story_context then
    EventBuilder._deps.story_context = deps.story_context
  end
end

--- Get the current session ID
-- @return string Session ID
function EventBuilder.getSessionId()
  if EventBuilder._session.id == nil then
    EventBuilder._session.id = generate_uuid()
    EventBuilder._session.startTime = get_timestamp()
  end
  return EventBuilder._session.id
end

--- Get the session start time
-- @return number Session start timestamp
function EventBuilder.getSessionStartTime()
  if EventBuilder._session.startTime == nil then
    EventBuilder._session.startTime = get_timestamp()
  end
  return EventBuilder._session.startTime
end

--- Start a new session
-- @return string The new session ID
function EventBuilder.startNewSession()
  EventBuilder._session.id = generate_uuid()
  EventBuilder._session.startTime = get_timestamp()
  return EventBuilder._session.id
end

--- Get the current consent level
-- @return number Consent level (0-3)
function EventBuilder.getConsentLevel()
  if EventBuilder._deps.consent_manager and EventBuilder._deps.consent_manager.getConsentLevel then
    return EventBuilder._deps.consent_manager.getConsentLevel()
  end
  return 2 -- Default to ANALYTICS level
end

--- Get user ID (only available at FULL consent level)
-- @return string|nil User ID or nil
function EventBuilder.getUserId()
  local consentLevel = EventBuilder.getConsentLevel()
  if consentLevel >= 3 then -- FULL consent
    if EventBuilder._deps.consent_manager and EventBuilder._deps.consent_manager.getUserId then
      return EventBuilder._deps.consent_manager.getUserId()
    end
  end
  return nil
end

--- Create base event structure with common fields
-- @param category string Event category
-- @param action string Event action
-- @param metadata table|nil Event-specific metadata
-- @return table The event object
function EventBuilder.createBaseEvent(category, action, metadata)
  local event = {
    category = category,
    action = action,
    timestamp = get_timestamp(),
    sessionId = EventBuilder.getSessionId(),
    sessionStart = EventBuilder.getSessionStartTime(),
    storyId = EventBuilder._config.storyId,
    storyVersion = EventBuilder._config.storyVersion,
    storyTitle = EventBuilder._config.storyTitle,
    metadata = metadata and deep_copy(metadata) or {}
  }

  -- Add userId only if FULL consent
  local userId = EventBuilder.getUserId()
  if userId then
    event.userId = userId
  end

  return event
end

--- Build and validate an event
-- @param category string Event category
-- @param action string Event action
-- @param metadata table|nil Event-specific metadata
-- @return table|nil The event object, or nil if invalid
-- @return table|nil Array of error messages if invalid
function EventBuilder.buildEvent(category, action, metadata)
  local event = EventBuilder.createBaseEvent(category, action, metadata)

  -- Validate if taxonomy is available
  if EventBuilder._deps.event_taxonomy then
    local isValid, errors = EventBuilder._deps.event_taxonomy.validateEvent(event)
    if not isValid then
      return nil, errors
    end
  end

  return event, nil
end

--- Build event without validation (for performance)
-- @param category string Event category
-- @param action string Event action
-- @param metadata table|nil Event-specific metadata
-- @return table The event object
function EventBuilder.buildEventFast(category, action, metadata)
  return EventBuilder.createBaseEvent(category, action, metadata)
end

-- Convenience builders for common events

--- Create a story.start event
-- @param metadata table|nil Additional metadata
-- @return table The event
function EventBuilder.storyStart(metadata)
  local meta = metadata or {}
  meta.isFirstLaunch = meta.isFirstLaunch or false
  meta.restoreFromSave = meta.restoreFromSave or false
  return EventBuilder.createBaseEvent("story", "start", meta)
end

--- Create a story.resume event
-- @param metadata table|nil Additional metadata
-- @return table The event
function EventBuilder.storyResume(metadata)
  return EventBuilder.createBaseEvent("story", "resume", metadata)
end

--- Create a story.complete event
-- @param metadata table|nil Additional metadata
-- @return table The event
function EventBuilder.storyComplete(metadata)
  return EventBuilder.createBaseEvent("story", "complete", metadata)
end

--- Create a story.abandon event
-- @param metadata table|nil Additional metadata
-- @return table The event
function EventBuilder.storyAbandon(metadata)
  return EventBuilder.createBaseEvent("story", "abandon", metadata)
end

--- Create a story.restart event
-- @param metadata table|nil Additional metadata
-- @return table The event
function EventBuilder.storyRestart(metadata)
  return EventBuilder.createBaseEvent("story", "restart", metadata)
end

--- Create a passage.view event
-- @param passageId string The passage ID
-- @param passageName string|nil The passage name
-- @param metadata table|nil Additional metadata
-- @return table The event
function EventBuilder.passageView(passageId, passageName, metadata)
  local meta = metadata or {}
  meta.passageId = passageId
  meta.passageName = passageName
  return EventBuilder.createBaseEvent("passage", "view", meta)
end

--- Create a passage.exit event
-- @param passageId string The passage ID
-- @param timeOnPassage number|nil Time spent on passage in ms
-- @param metadata table|nil Additional metadata
-- @return table The event
function EventBuilder.passageExit(passageId, timeOnPassage, metadata)
  local meta = metadata or {}
  meta.passageId = passageId
  meta.timeOnPassage = timeOnPassage
  return EventBuilder.createBaseEvent("passage", "exit", meta)
end

--- Create a choice.presented event
-- @param passageId string The passage ID
-- @param choiceCount number Number of choices
-- @param metadata table|nil Additional metadata
-- @return table The event
function EventBuilder.choicePresented(passageId, choiceCount, metadata)
  local meta = metadata or {}
  meta.passageId = passageId
  meta.choiceCount = choiceCount
  return EventBuilder.createBaseEvent("choice", "presented", meta)
end

--- Create a choice.selected event
-- @param passageId string The passage ID
-- @param choiceId string The selected choice ID
-- @param metadata table|nil Additional metadata
-- @return table The event
function EventBuilder.choiceSelected(passageId, choiceId, metadata)
  local meta = metadata or {}
  meta.passageId = passageId
  meta.choiceId = choiceId
  return EventBuilder.createBaseEvent("choice", "selected", meta)
end

--- Create a save.create event
-- @param saveId string The save ID
-- @param currentPassage string Current passage ID
-- @param metadata table|nil Additional metadata
-- @return table The event
function EventBuilder.saveCreate(saveId, currentPassage, metadata)
  local meta = metadata or {}
  meta.saveId = saveId
  meta.currentPassage = currentPassage
  return EventBuilder.createBaseEvent("save", "create", meta)
end

--- Create a save.load event
-- @param saveId string The save ID
-- @param loadedPassage string Loaded passage ID
-- @param metadata table|nil Additional metadata
-- @return table The event
function EventBuilder.saveLoad(saveId, loadedPassage, metadata)
  local meta = metadata or {}
  meta.saveId = saveId
  meta.loadedPassage = loadedPassage
  return EventBuilder.createBaseEvent("save", "load", meta)
end

--- Create an error.script event
-- @param errorType string Error type
-- @param errorMessage string Error message
-- @param severity string Severity level
-- @param metadata table|nil Additional metadata
-- @return table The event
function EventBuilder.errorScript(errorType, errorMessage, severity, metadata)
  local meta = metadata or {}
  meta.errorType = errorType
  meta.errorMessage = errorMessage
  meta.severity = severity or "error"
  return EventBuilder.createBaseEvent("error", "script", meta)
end

--- Create a user.consent_change event
-- @param previousLevel number Previous consent level
-- @param newLevel number New consent level
-- @param metadata table|nil Additional metadata
-- @return table The event
function EventBuilder.consentChange(previousLevel, newLevel, metadata)
  local meta = metadata or {}
  meta.previousLevel = previousLevel
  meta.newLevel = newLevel
  return EventBuilder.createBaseEvent("user", "consent_change", meta)
end

--- Create a test.exposure event
-- @param testId string Test ID
-- @param variantId string Variant ID
-- @param metadata table|nil Additional metadata
-- @return table The event
function EventBuilder.testExposure(testId, variantId, metadata)
  local meta = metadata or {}
  meta.testId = testId
  meta.variantId = variantId
  return EventBuilder.createBaseEvent("test", "exposure", meta)
end

--- Create a test.conversion event
-- @param testId string Test ID
-- @param variantId string Variant ID
-- @param conversionType string Type of conversion
-- @param metadata table|nil Additional metadata
-- @return table The event
function EventBuilder.testConversion(testId, variantId, conversionType, metadata)
  local meta = metadata or {}
  meta.testId = testId
  meta.variantId = variantId
  meta.conversionType = conversionType
  return EventBuilder.createBaseEvent("test", "conversion", meta)
end

--- Reset the event builder (for testing)
function EventBuilder.reset()
  EventBuilder._session.id = nil
  EventBuilder._session.startTime = nil
  EventBuilder._config.storyId = "unknown"
  EventBuilder._config.storyVersion = "1.0.0"
  EventBuilder._config.storyTitle = "Unknown Story"
end

return EventBuilder
