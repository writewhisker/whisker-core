-- whisker/formats/ink/engine.lua
-- InkEngine IEngine implementation
-- Runtime engine wrapping tinta for Ink story execution

local InkEngine = {}
InkEngine.__index = InkEngine

-- Module metadata for container auto-registration
InkEngine._whisker = {
  name = "InkEngine",
  version = "1.0.0",
  description = "Ink story runtime engine implementing IEngine",
  depends = {},
  implements = "IEngine",
  capability = "engine.ink"
}

-- Create a new InkEngine instance
-- @param options table|nil - Optional configuration
-- @return InkEngine
function InkEngine.new(options)
  options = options or {}
  local instance = {
    _story = nil,           -- InkStory wrapper
    _tinta_story = nil,     -- tinta Story instance
    _started = false,
    _current_text = "",
    _current_tags = {},
    _event_emitter = options.event_emitter
  }
  setmetatable(instance, InkEngine)
  return instance
end

-- Load a story into the engine
-- @param story InkStory|table - InkStory wrapper or story data
function InkEngine:load(story)
  -- Accept either InkStory wrapper or raw story data
  local InkStory = require("whisker.formats.ink.story")

  if getmetatable(story) == InkStory then
    self._story = story
  elseif type(story) == "table" then
    -- Check if it's story data (has inkVersion)
    if story.inkVersion then
      self._story = InkStory.new(story)
    else
      error("Invalid story data: missing inkVersion")
    end
  else
    error("Invalid story: expected InkStory or table, got " .. type(story))
  end

  -- Reset state
  self._tinta_story = nil
  self._started = false
  self._current_text = ""
  self._current_tags = {}

  -- Emit load event
  self:_emit("ink.engine.loaded", {
    ink_version = self._story:get_ink_version()
  })
end

-- Get the underlying tinta Story (creates if needed)
-- @return Story - tinta Story instance
function InkEngine:_get_tinta_story()
  if not self._tinta_story then
    if not self._story then
      error("No story loaded")
    end
    self._tinta_story = self._story:get_tinta_story()
  end
  return self._tinta_story
end

-- Start or restart the story from the beginning
function InkEngine:start()
  if not self._story then
    error("No story loaded")
  end

  -- Create fresh tinta story
  local tinta = require("whisker.vendor.tinta")
  self._tinta_story = tinta.create_story(self._story:get_data())

  -- Process initial content
  if self._tinta_story:canContinue() then
    self:_continue_internal()
  end

  self._started = true

  -- Emit start event
  self:_emit("ink.engine.started", {})
end

-- Internal continue that accumulates text until a stopping point
function InkEngine:_continue_internal()
  local ts = self:_get_tinta_story()
  local text_parts = {}
  local tags = {}

  -- Continue until we can't
  while ts:canContinue() do
    local line = ts:Continue()
    if line and line ~= "" then
      table.insert(text_parts, line)
    end

    -- Collect tags from this line
    local line_tags = ts:currentTags()
    if line_tags then
      for _, tag in ipairs(line_tags) do
        table.insert(tags, tag)
      end
    end
  end

  self._current_text = table.concat(text_parts)
  self._current_tags = tags
end

-- Check if the story can continue (has more content or choices)
-- @return boolean
function InkEngine:can_continue()
  if not self._started then
    return false
  end

  local ts = self:_get_tinta_story()

  -- Can continue if there's more text to read OR if there are choices
  return ts:canContinue() or #ts:currentChoices() > 0
end

-- Continue the story to the next stopping point
-- @return string - The text output from continuing
function InkEngine:continue()
  if not self._started then
    error("Story not started")
  end

  local ts = self:_get_tinta_story()

  if not ts:canContinue() then
    if #ts:currentChoices() > 0 then
      -- At a choice point, return current text
      return self._current_text
    end
    error("Cannot continue: story has ended")
  end

  self:_continue_internal()

  -- Emit continue event
  self:_emit("ink.engine.continued", {
    text = self._current_text,
    tags = self._current_tags
  })

  return self._current_text
end

-- Get the current text output
-- @return string
function InkEngine:get_current_text()
  return self._current_text
end

-- Get the current tags
-- @return table - Array of tag strings
function InkEngine:get_current_tags()
  return self._current_tags
end

-- Get current passage (creates a pseudo-passage from current state)
-- @return table - Passage-like object
function InkEngine:get_current_passage()
  if not self._started then
    return nil
  end

  -- Create a passage-like object from current state
  return {
    id = "ink_current",
    content = self._current_text,
    tags = self._current_tags
  }
end

-- Get available choices for current position
-- @return table - Array of Choice-like objects
function InkEngine:get_available_choices()
  if not self._started then
    return {}
  end

  local ts = self:_get_tinta_story()
  local ink_choices = ts:currentChoices()

  -- Use choice adapter if available
  if not self._choice_adapter then
    local ChoiceAdapter = require("whisker.formats.ink.choice_adapter")
    self._choice_adapter = ChoiceAdapter.new()
  end

  return self._choice_adapter:adapt_all(ink_choices)
end

-- Get choices as whisker-core Choice objects
-- @return table - Array of Choice objects
function InkEngine:get_choices_as_objects()
  local adapted = self:get_available_choices()
  local Choice = require("whisker.core.choice")
  local choices = {}

  for _, c in ipairs(adapted) do
    table.insert(choices, Choice.new({
      id = c.id,
      text = c.text,
      target = c.target,
      metadata = c.metadata
    }))
  end

  return choices
end

-- Make a choice by index
-- @param index number - 1-based index of choice to make
-- @return table - New current passage-like object
function InkEngine:make_choice(index)
  if not self._started then
    error("Story not started")
  end

  local ts = self:_get_tinta_story()
  local choices = ts:currentChoices()

  if index < 1 or index > #choices then
    error("Invalid choice index: " .. index)
  end

  -- tinta uses 0-based indices internally but our array is 1-based
  ts:ChooseChoiceIndex(index - 1)

  -- Emit choice event
  self:_emit("ink.choice.made", {
    index = index,
    text = choices[index].text
  })

  -- Continue after making choice
  if ts:canContinue() then
    self:_continue_internal()
  end

  return self:get_current_passage()
end

-- Check if story has ended
-- @return boolean
function InkEngine:has_ended()
  if not self._started then
    return false
  end

  local ts = self:_get_tinta_story()
  return not ts:canContinue() and #ts:currentChoices() == 0
end

-- Reset the engine state
function InkEngine:reset()
  if self._story then
    self._tinta_story = nil
    self._started = false
    self._current_text = ""
    self._current_tags = {}
  end
end

-- Set event emitter for notifications
-- @param emitter table - Event emitter with emit method
function InkEngine:set_event_emitter(emitter)
  self._event_emitter = emitter
end

-- Internal: emit an event if emitter is set
function InkEngine:_emit(event_name, data)
  if self._event_emitter and self._event_emitter.emit then
    self._event_emitter:emit(event_name, data)
  end
end

-- Get the loaded InkStory wrapper
-- @return InkStory|nil
function InkEngine:get_story()
  return self._story
end

-- Check if a story is loaded
-- @return boolean
function InkEngine:is_loaded()
  return self._story ~= nil
end

-- Check if the story has been started
-- @return boolean
function InkEngine:is_started()
  return self._started
end

-- Get the state manager for this engine
-- @return InkState
function InkEngine:get_state()
  if not self._state then
    local InkState = require("whisker.formats.ink.state")
    self._state = InkState.new(self)
    if self._event_emitter then
      self._state:set_event_emitter(self._event_emitter)
    end
  end
  return self._state
end

-- Set state (for IEngine optional interface compliance)
-- @param state table - State snapshot to restore
function InkEngine:set_state(state)
  local ink_state = self:get_state()
  ink_state:restore(state)
end

return InkEngine
