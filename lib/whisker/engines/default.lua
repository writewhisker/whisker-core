-- whisker/engines/default.lua
-- Default runtime engine implementing IEngine
-- Uses injected services for state management and condition evaluation

local DefaultEngine = {}
DefaultEngine.__index = DefaultEngine

-- Module metadata for container auto-registration
DefaultEngine._whisker = {
  name = "DefaultEngine",
  version = "2.0.0",
  description = "Default runtime engine implementing IEngine",
  depends = {},
  implements = "IEngine",
  capability = "engines.default"
}

-- Create a new DefaultEngine instance
-- @param options table - Optional configuration
-- @return DefaultEngine
function DefaultEngine.new(options)
  options = options or {}
  local instance = {
    -- Injected services (can be set via options or set_* methods)
    _state = options.state or nil,
    _condition_evaluator = options.condition_evaluator or nil,
    _event_emitter = options.event_emitter or nil,
    _code_executor = options.code_executor or nil,

    -- Engine state
    _story = nil,
    _current_passage = nil,
    _available_choices = {},
    _is_running = false
  }
  setmetatable(instance, DefaultEngine)
  return instance
end

-- Inject state service
function DefaultEngine:set_state(state)
  self._state = state
end

-- Inject condition evaluator
function DefaultEngine:set_condition_evaluator(evaluator)
  self._condition_evaluator = evaluator
end

-- Inject event emitter
function DefaultEngine:set_event_emitter(emitter)
  self._event_emitter = emitter
end

-- Inject code executor (for on_enter_script, choice actions)
function DefaultEngine:set_code_executor(executor)
  self._code_executor = executor
end

-- Internal: emit an event if emitter is set
local function emit_event(self, event_name, data)
  if self._event_emitter and self._event_emitter.emit then
    self._event_emitter:emit(event_name, data)
  end
end

-- Internal: evaluate a condition if evaluator is set
local function evaluate_condition(self, condition, context)
  if not self._condition_evaluator then
    -- Without evaluator, assume all conditions pass
    return true
  end
  if self._condition_evaluator.evaluate then
    return self._condition_evaluator:evaluate(condition, context)
  end
  return true
end

-- Internal: execute code if executor is set
local function execute_code(self, code, context)
  if not self._code_executor then
    return true, nil
  end
  if self._code_executor.execute then
    return self._code_executor:execute(code, context)
  end
  return true, nil
end

-- Load a story into the engine
-- @param story table - Story object to load
function DefaultEngine:load(story)
  self._story = story
  self._current_passage = nil
  self._available_choices = {}
  self._is_running = false

  emit_event(self, "engine:story_loaded", {
    story = story
  })
end

-- Start or restart the story from the beginning
function DefaultEngine:start()
  if not self._story then
    error("No story loaded")
  end

  -- Clear state if available
  if self._state then
    self._state:clear()
  end

  -- Get start passage
  local start_id
  if self._story.get_start_passage then
    start_id = self._story:get_start_passage()
  else
    start_id = self._story.start_passage or self._story.start
  end

  if not start_id then
    error("No start passage defined")
  end

  self._is_running = true

  emit_event(self, "engine:started", {
    story = self._story,
    start_passage = start_id
  })

  -- Navigate to start passage
  self:_enter_passage(start_id)
end

-- Internal: enter a passage
function DefaultEngine:_enter_passage(passage_id)
  -- Get passage from story
  local passage
  if self._story.get_passage then
    passage = self._story:get_passage(passage_id)
  else
    passage = self._story.passages and self._story.passages[passage_id]
  end

  if not passage then
    error("Passage not found: " .. tostring(passage_id))
  end

  -- Store as current passage
  self._current_passage = passage

  -- Track visit in state if available
  if self._state then
    local visit_key = "_visited_" .. passage_id
    local visit_count = self._state:get(visit_key) or 0
    self._state:set(visit_key, visit_count + 1)
    self._state:set("_current_passage", passage_id)
  end

  -- Execute on_enter_script if present
  if passage.on_enter_script then
    execute_code(self, passage.on_enter_script, {
      passage = passage,
      state = self._state
    })
  end

  -- Calculate available choices
  self:_update_available_choices()

  -- Emit passage entered event
  emit_event(self, "passage:entered", {
    passage = passage,
    passage_id = passage_id
  })

  return passage
end

-- Internal: update available choices based on conditions
function DefaultEngine:_update_available_choices()
  self._available_choices = {}

  if not self._current_passage then
    return
  end

  -- Get choices from passage
  local choices
  if self._current_passage.get_choices then
    choices = self._current_passage:get_choices()
  else
    choices = self._current_passage.choices or {}
  end

  -- Filter by conditions
  for _, choice in ipairs(choices) do
    local is_available = true

    -- Check condition if present
    local condition
    if choice.get_condition then
      condition = choice:get_condition()
    else
      condition = choice.condition
    end

    if condition and condition ~= "" then
      is_available = evaluate_condition(self, condition, {
        choice = choice,
        passage = self._current_passage,
        state = self._state
      })
    end

    if is_available then
      table.insert(self._available_choices, choice)
    end
  end
end

-- Get the current passage
-- @return table - Current passage object
function DefaultEngine:get_current_passage()
  return self._current_passage
end

-- Get available choices for current passage
-- @return table - Array of available Choice objects
function DefaultEngine:get_available_choices()
  return self._available_choices
end

-- Make a choice by index
-- @param index number - 1-based index of choice to make
-- @return table - New current passage after choice
function DefaultEngine:make_choice(index)
  if not self._is_running then
    error("Engine is not running")
  end

  if type(index) ~= "number" or index < 1 or index > #self._available_choices then
    error("Invalid choice index: " .. tostring(index))
  end

  local choice = self._available_choices[index]

  -- Execute choice action if present
  local action
  if choice.get_action then
    action = choice:get_action()
  else
    action = choice.action
  end

  if action and action ~= "" then
    execute_code(self, action, {
      choice = choice,
      passage = self._current_passage,
      state = self._state
    })
  end

  -- Get target passage
  local target
  if choice.get_target then
    target = choice:get_target()
  else
    target = choice.target or choice.target_passage
  end

  if not target then
    error("Choice has no target passage")
  end

  -- Emit choice made event
  emit_event(self, "choice:made", {
    choice = choice,
    index = index,
    from_passage = self._current_passage,
    target = target
  })

  -- Navigate to target passage
  return self:_enter_passage(target)
end

-- Check if the story can continue (not at an ending)
-- @return boolean - True if choices available
function DefaultEngine:can_continue()
  return self._is_running and #self._available_choices > 0
end

-- Reset the engine (optional IEngine method)
function DefaultEngine:reset()
  self._current_passage = nil
  self._available_choices = {}
  self._is_running = false

  if self._state then
    self._state:clear()
  end

  emit_event(self, "engine:reset", {})
end

-- Get current state (optional IEngine method)
function DefaultEngine:get_state()
  return self._state
end

-- Set state service (optional IEngine method)
function DefaultEngine:set_state_service(state)
  self._state = state
end

return DefaultEngine
