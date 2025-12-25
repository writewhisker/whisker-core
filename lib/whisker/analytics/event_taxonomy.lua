--- Event Taxonomy for whisker-core Analytics
-- Defines all trackable events and provides validation
-- @module whisker.analytics.event_taxonomy
-- @author Whisker Core Team
-- @license MIT

local EventTaxonomy = {}
EventTaxonomy._dependencies = {}
EventTaxonomy.__index = EventTaxonomy
EventTaxonomy.VERSION = "1.0.0"

--- Core event categories and their allowed actions
EventTaxonomy.CATEGORIES = {
  story = {
    "start",
    "resume",
    "complete",
    "abandon",
    "restart"
  },

  passage = {
    "view",
    "exit",
    "reread"
  },

  choice = {
    "presented",
    "selected",
    "hover"
  },

  save = {
    "create",
    "load",
    "delete",
    "autosave"
  },

  error = {
    "script",
    "resource",
    "state"
  },

  user = {
    "consent_change",
    "setting_change",
    "feedback"
  },

  test = {
    "exposure",
    "conversion"
  }
}

--- Metadata schemas for each event type
-- Types: string, number, boolean, table, any
-- Suffix "?" indicates optional field
EventTaxonomy.METADATA_SCHEMAS = {
  ["story.start"] = {
    isFirstLaunch = "boolean",
    restoreFromSave = "boolean",
    initialPassage = "string"
  },

  ["story.resume"] = {
    lastSessionTime = "number?",
    resumePassage = "string",
    totalSessions = "number?"
  },

  ["story.complete"] = {
    completionPassage = "string",
    totalPlaytime = "number?",
    totalSessions = "number?",
    choicesMade = "number?",
    endingReached = "string?"
  },

  ["story.abandon"] = {
    lastPassage = "string",
    totalPlaytime = "number?",
    estimatedProgress = "number?",
    sessionsSinceLastProgress = "number?"
  },

  ["story.restart"] = {
    previousProgress = "number?",
    previousPlaytime = "number?",
    restartReason = "string?"
  },

  ["passage.view"] = {
    passageId = "string",
    passageName = "string?",
    wordCount = "number?",
    previousPassage = "string?",
    transitionType = "string?",
    estimatedReadTime = "number?"
  },

  ["passage.exit"] = {
    passageId = "string",
    timeOnPassage = "number?",
    wordsPerMinute = "number?",
    exitVia = "string?",
    choiceSelected = "string?"
  },

  ["passage.reread"] = {
    passageId = "string",
    previousVisits = "number?",
    timeSinceLastVisit = "number?",
    visitPath = "table?"
  },

  ["choice.presented"] = {
    passageId = "string",
    choiceIds = "table?",
    choiceCount = "number",
    choiceTexts = "table?",
    conditionalChoices = "table?",
    displayStyle = "string?"
  },

  ["choice.selected"] = {
    passageId = "string",
    choiceId = "string",
    choiceText = "string?",
    choiceIndex = "number?",
    timeToDecide = "number?",
    totalChoicesPresented = "number?",
    destinationPassage = "string?"
  },

  ["choice.hover"] = {
    passageId = "string",
    choiceId = "string",
    hoverDuration = "number?",
    hoverSequence = "number?"
  },

  ["save.create"] = {
    saveId = "string",
    saveName = "string?",
    currentPassage = "string",
    playtime = "number?",
    saveSlot = "number?",
    autoSave = "boolean?"
  },

  ["save.load"] = {
    saveId = "string",
    saveName = "string?",
    saveTimestamp = "number?",
    loadedPassage = "string",
    timeSinceSave = "number?"
  },

  ["save.delete"] = {
    saveId = "string",
    saveName = "string?",
    saveAge = "number?"
  },

  ["save.autosave"] = {
    currentPassage = "string",
    trigger = "string?",
    previousAutosaveAge = "number?"
  },

  ["error.script"] = {
    errorType = "string",
    errorMessage = "string",
    stackTrace = "string?",
    passageId = "string?",
    scriptLine = "number?",
    severity = "string"
  },

  ["error.resource"] = {
    resourceType = "string",
    resourceUrl = "string?",
    errorCode = "number?",
    retryCount = "number?"
  },

  ["error.state"] = {
    errorType = "string",
    attemptedPassage = "string?",
    currentPassage = "string?",
    recoveryAction = "string?"
  },

  ["user.consent_change"] = {
    previousLevel = "number",
    newLevel = "number",
    consentVersion = "string?",
    changedVia = "string?"
  },

  ["user.setting_change"] = {
    settingName = "string",
    previousValue = "any?",
    newValue = "any",
    settingCategory = "string?"
  },

  ["user.feedback"] = {
    feedbackType = "string",
    feedbackText = "string?",
    currentPassage = "string?",
    rating = "number?"
  },

  ["test.exposure"] = {
    testId = "string",
    variantId = "string",
    assignmentMethod = "string?",
    testDescription = "string?"
  },

  ["test.conversion"] = {
    testId = "string",
    variantId = "string",
    conversionType = "string",
    timeToConversion = "number?",
    value = "number?"
  }
}

--- Registry for custom event types
EventTaxonomy._customEvents = {}

--- Check if a table contains a value
-- @param tbl table The table to search
-- @param value any The value to find
-- @return boolean True if found
local function table_contains(tbl, value)
  if not tbl then return false end
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

--- Create a new EventTaxonomy instance
-- @return EventTaxonomy A new instance
function EventTaxonomy.new(deps)
  deps = deps or {}
  local self = setmetatable({}, EventTaxonomy)
  self._customEvents = {}
  return self
end

--- Define a custom event type
-- @param definition table Event definition with category, actions, and optional metadataSchema
-- @return boolean Success
-- @return string|nil Error message if failed
function EventTaxonomy.defineCustomEvent(definition)
  -- Validate definition
  if type(definition) ~= "table" then
    return false, "Event definition must be a table"
  end

  if type(definition.category) ~= "string" then
    return false, "Event category must be a string"
  end

  if type(definition.actions) ~= "table" or #definition.actions == 0 then
    return false, "Event actions must be a non-empty table"
  end

  local category = definition.category

  -- Check if category exists
  if not EventTaxonomy.CATEGORIES[category] then
    EventTaxonomy.CATEGORIES[category] = {}
  end

  -- Add actions to category
  for _, action in ipairs(definition.actions) do
    if not table_contains(EventTaxonomy.CATEGORIES[category], action) then
      table.insert(EventTaxonomy.CATEGORIES[category], action)
    end

    -- Register metadata schema if provided
    if definition.metadataSchema then
      local eventType = category .. "." .. action
      EventTaxonomy.METADATA_SCHEMAS[eventType] = deep_copy(definition.metadataSchema)
    end
  end

  EventTaxonomy._customEvents[category] = definition
  return true
end

--- Validate an event structure
-- @param event table The event to validate
-- @return boolean True if valid
-- @return table Array of error messages if invalid
function EventTaxonomy.validateEvent(event)
  local errors = {}

  -- Required fields
  if type(event.category) ~= "string" then
    table.insert(errors, "Missing or invalid 'category' field")
  end

  if type(event.action) ~= "string" then
    table.insert(errors, "Missing or invalid 'action' field")
  end

  if type(event.timestamp) ~= "number" then
    table.insert(errors, "Missing or invalid 'timestamp' field")
  end

  if type(event.sessionId) ~= "string" then
    table.insert(errors, "Missing or invalid 'sessionId' field")
  end

  if type(event.storyId) ~= "string" then
    table.insert(errors, "Missing or invalid 'storyId' field")
  end

  -- Validate category exists
  if event.category and not EventTaxonomy.CATEGORIES[event.category] then
    table.insert(errors, "Unknown event category: " .. tostring(event.category))
  end

  -- Validate action exists in category
  if event.category and event.action then
    local actions = EventTaxonomy.CATEGORIES[event.category]
    if actions and not table_contains(actions, event.action) then
      table.insert(errors, "Unknown action '" .. tostring(event.action) .. "' for category '" .. tostring(event.category) .. "'")
    end
  end

  -- Validate metadata schema if defined
  if event.category and event.action then
    local eventType = event.category .. "." .. event.action
    local schema = EventTaxonomy.METADATA_SCHEMAS[eventType]

    if schema then
      local metadataErrors = EventTaxonomy._validateMetadata(event.metadata or {}, schema, eventType)
      for _, err in ipairs(metadataErrors) do
        table.insert(errors, err)
      end
    end
  end

  return #errors == 0, errors
end

--- Validate metadata against schema
-- @param metadata table The metadata to validate
-- @param schema table The schema to validate against
-- @param eventType string The event type for error messages
-- @return table Array of error messages
function EventTaxonomy._validateMetadata(metadata, schema, eventType)
  local errors = {}

  for field, expectedType in pairs(schema) do
    local isOptional = expectedType:sub(-1) == "?"
    local typeWithoutOptional = isOptional and expectedType:sub(1, -2) or expectedType
    local actualValue = metadata[field]

    if actualValue == nil then
      if not isOptional then
        table.insert(errors, string.format(
          "Missing required metadata field '%s' for event '%s'",
          field,
          eventType
        ))
      end
    else
      local actualType = type(actualValue)
      if typeWithoutOptional ~= "any" and actualType ~= typeWithoutOptional then
        table.insert(errors, string.format(
          "Invalid type for metadata field '%s' in event '%s': expected %s, got %s",
          field,
          eventType,
          typeWithoutOptional,
          actualType
        ))
      end
    end
  end

  return errors
end

--- Get all registered event types
-- @return table Array of event type strings (category.action)
function EventTaxonomy.getEventTypes()
  local types = {}

  for category, actions in pairs(EventTaxonomy.CATEGORIES) do
    for _, action in ipairs(actions) do
      table.insert(types, category .. "." .. action)
    end
  end

  table.sort(types)
  return types
end

--- Get metadata schema for event type
-- @param eventType string The event type (category.action)
-- @return table|nil The schema, or nil if not defined
function EventTaxonomy.getMetadataSchema(eventType)
  return EventTaxonomy.METADATA_SCHEMAS[eventType]
end

--- Check if event type exists
-- @param category string The event category
-- @param action string The event action
-- @return boolean True if event type exists
function EventTaxonomy.eventTypeExists(category, action)
  local actions = EventTaxonomy.CATEGORIES[category]
  if not actions then
    return false
  end
  return table_contains(actions, action)
end

--- Get all categories
-- @return table Array of category names
function EventTaxonomy.getCategories()
  local categories = {}
  for category in pairs(EventTaxonomy.CATEGORIES) do
    table.insert(categories, category)
  end
  table.sort(categories)
  return categories
end

--- Get actions for a category
-- @param category string The category name
-- @return table Array of action names
function EventTaxonomy.getActions(category)
  local actions = EventTaxonomy.CATEGORIES[category]
  if actions then
    local copy = {}
    for _, action in ipairs(actions) do
      table.insert(copy, action)
    end
    return copy
  end
  return {}
end

--- Reset custom events (for testing)
function EventTaxonomy.resetCustomEvents()
  -- Remove custom categories
  for category in pairs(EventTaxonomy._customEvents) do
    -- Check if it's not a core category
    local coreCategories = {"story", "passage", "choice", "save", "error", "user", "test"}
    if not table_contains(coreCategories, category) then
      EventTaxonomy.CATEGORIES[category] = nil
    end
  end
  EventTaxonomy._customEvents = {}
end

return EventTaxonomy
