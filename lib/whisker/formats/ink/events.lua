-- whisker/formats/ink/events.lua
-- Ink event definitions and utilities
-- Defines all Ink-specific events and their payload structures

local InkEvents = {}

-- Module metadata
InkEvents._whisker = {
  name = "InkEvents",
  version = "1.0.0",
  description = "Ink event definitions and utilities",
  depends = {},
  capability = "formats.ink.events"
}

-- Event names
InkEvents.STORY_LOADED = "ink.story.loaded"
InkEvents.STORY_STARTED = "ink.engine.started"
InkEvents.STORY_CONTINUED = "ink.engine.continued"
InkEvents.STORY_ENDED = "ink.story.ended"
InkEvents.CHOICE_MADE = "ink.choice.made"
InkEvents.VARIABLE_CHANGED = "ink.variable.changed"
InkEvents.STATE_RESTORED = "ink.state.restored"
InkEvents.EXTERNAL_CALLED = "ink.external.called"
InkEvents.ERROR = "ink.error"

-- All event names for documentation and iteration
InkEvents.ALL = {
  InkEvents.STORY_LOADED,
  InkEvents.STORY_STARTED,
  InkEvents.STORY_CONTINUED,
  InkEvents.STORY_ENDED,
  InkEvents.CHOICE_MADE,
  InkEvents.VARIABLE_CHANGED,
  InkEvents.STATE_RESTORED,
  InkEvents.EXTERNAL_CALLED,
  InkEvents.ERROR,
}

-- Event payload builders
-- These ensure consistent event payloads

-- Story loaded event payload
-- @param ink_version number - Ink format version
-- @param story InkStory - The loaded story (optional)
-- @return table
function InkEvents.story_loaded(ink_version, story)
  return {
    event = InkEvents.STORY_LOADED,
    ink_version = ink_version,
    story = story
  }
end

-- Story started event payload
-- @param engine InkEngine - The engine (optional)
-- @return table
function InkEvents.story_started(engine)
  return {
    event = InkEvents.STORY_STARTED,
    engine = engine
  }
end

-- Story continued event payload
-- @param text string - The text output
-- @param tags table - Array of tags
-- @param can_continue boolean - Whether story can continue
-- @return table
function InkEvents.story_continued(text, tags, can_continue)
  return {
    event = InkEvents.STORY_CONTINUED,
    text = text,
    tags = tags or {},
    can_continue = can_continue
  }
end

-- Story ended event payload
-- @param text string - Final text
-- @return table
function InkEvents.story_ended(text)
  return {
    event = InkEvents.STORY_ENDED,
    text = text
  }
end

-- Choice made event payload
-- @param index number - 1-based choice index
-- @param text string - Choice text
-- @param path string - Choice path (optional)
-- @return table
function InkEvents.choice_made(index, text, path)
  return {
    event = InkEvents.CHOICE_MADE,
    index = index,
    text = text,
    path = path
  }
end

-- Variable changed event payload
-- @param key string - Variable name
-- @param old_value any - Previous value
-- @param new_value any - New value
-- @return table
function InkEvents.variable_changed(key, old_value, new_value)
  return {
    event = InkEvents.VARIABLE_CHANGED,
    key = key,
    old_value = old_value,
    new_value = new_value
  }
end

-- State restored event payload
-- @return table
function InkEvents.state_restored()
  return {
    event = InkEvents.STATE_RESTORED
  }
end

-- External function called event payload
-- @param name string - Function name
-- @param args table - Function arguments
-- @param result any - Function result (optional)
-- @return table
function InkEvents.external_called(name, args, result)
  return {
    event = InkEvents.EXTERNAL_CALLED,
    name = name,
    args = args or {},
    result = result
  }
end

-- Error event payload
-- @param message string - Error message
-- @param source string - Error source (optional)
-- @return table
function InkEvents.error(message, source)
  return {
    event = InkEvents.ERROR,
    message = message,
    source = source
  }
end

-- Check if an event name is a valid Ink event
-- @param event_name string
-- @return boolean
function InkEvents.is_ink_event(event_name)
  for _, name in ipairs(InkEvents.ALL) do
    if name == event_name then
      return true
    end
  end
  return false
end

-- Get namespace for Ink events
-- @return string
function InkEvents.get_namespace()
  return "ink"
end

return InkEvents
