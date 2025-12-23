--- Privacy constants and utilities for whisker-core Analytics
-- @module whisker.analytics.privacy
-- @author Whisker Core Team
-- @license MIT

local Privacy = {}
Privacy.__index = Privacy
Privacy.VERSION = "1.0.0"

--- Consent levels
Privacy.CONSENT_LEVELS = {
  NONE = 0,        -- No tracking whatsoever
  ESSENTIAL = 1,   -- Only critical technical events
  ANALYTICS = 2,   -- Behavioral analytics without user identification
  FULL = 3         -- Complete analytics with cross-session tracking
}

--- Human-readable consent level names
Privacy.CONSENT_LEVEL_NAMES = {
  [0] = "None",
  [1] = "Essential",
  [2] = "Analytics",
  [3] = "Full"
}

--- Consent level descriptions (for UI)
Privacy.CONSENT_LEVEL_DESCRIPTIONS = {
  [0] = "No analytics tracking. The story will function normally but no data will be collected.",

  [1] = "Only critical technical information needed for error recovery and save system reliability. " ..
        "No behavioral analytics or user identification.",

  [2] = "Anonymous behavioral analytics to help improve the story. " ..
        "Tracks passage views, choices, and completion rates without identifying you across sessions. " ..
        "No personally identifiable information is collected.",

  [3] = "Complete analytics including cross-session tracking to provide the best experience. " ..
        "Enables features like A/B testing and personalized recommendations. " ..
        "You can review and delete your data at any time."
}

--- Get description for consent level
-- @param level number The consent level
-- @return string The description
function Privacy.getConsentLevelDescription(level)
  return Privacy.CONSENT_LEVEL_DESCRIPTIONS[level] or "Unknown consent level"
end

--- Get name for consent level
-- @param level number The consent level
-- @return string The level name
function Privacy.getConsentLevelName(level)
  return Privacy.CONSENT_LEVEL_NAMES[level] or "Unknown"
end

--- Check if consent level is valid
-- @param level number The consent level to check
-- @return boolean True if valid
function Privacy.isValidConsentLevel(level)
  return type(level) == "number" and
         level >= Privacy.CONSENT_LEVELS.NONE and
         level <= Privacy.CONSENT_LEVELS.FULL
end

--- Get all consent levels
-- @return table Array of {level, name, description} objects
function Privacy.getAllConsentLevels()
  local levels = {}
  for i = Privacy.CONSENT_LEVELS.NONE, Privacy.CONSENT_LEVELS.FULL do
    table.insert(levels, {
      level = i,
      name = Privacy.CONSENT_LEVEL_NAMES[i],
      description = Privacy.CONSENT_LEVEL_DESCRIPTIONS[i]
    })
  end
  return levels
end

return Privacy
