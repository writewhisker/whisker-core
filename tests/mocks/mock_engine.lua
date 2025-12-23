--- Mock Engine
-- Mock implementation of IEngine interface
-- @module tests.mocks.mock_engine
-- @author Whisker Core Team

local MockBase = require("tests.mocks.mock_base")

local MockEngine = setmetatable({}, {__index = MockBase})
MockEngine.__index = MockEngine

--- Create a new mock engine
-- @return MockEngine A new mock engine instance
function MockEngine.new()
  local self = setmetatable(MockBase.new(), MockEngine)
  self._story = nil
  self._current_passage = nil
  self._started = false
  self._ended = false
  self._state = {}
  return self
end

function MockEngine:load(story)
  self:_record_call("load", {story})
  self._story = story
  self._started = false
  self._ended = false
  return true
end

function MockEngine:start(passage_id)
  self:_record_call("start", {passage_id})
  if not self._story then
    return false, "No story loaded"
  end

  self._started = true
  self._ended = false

  -- Find start passage
  local start_id = passage_id or self._story.start_passage or self._story.start

  if self._story.passages then
    for _, passage in ipairs(self._story.passages) do
      if passage.id == start_id then
        self._current_passage = passage
        return true
      end
    end
  end

  return false, "Start passage not found"
end

function MockEngine:get_current_passage()
  self:_record_call("get_current_passage", {}, self._current_passage)
  return self._current_passage
end

function MockEngine:get_available_choices()
  local choices = {}
  if self._current_passage and self._current_passage.choices then
    for _, choice in ipairs(self._current_passage.choices) do
      table.insert(choices, choice)
    end
  end
  self:_record_call("get_available_choices", {}, choices)
  return choices
end

function MockEngine:make_choice(choice_index)
  self:_record_call("make_choice", {choice_index})

  local choices = self:get_available_choices()
  local choice = choices[choice_index]

  if not choice then
    return false, "Invalid choice index"
  end

  -- Navigate to target passage
  return self:go_to_passage(choice.target)
end

function MockEngine:go_to_passage(passage_id)
  self:_record_call("go_to_passage", {passage_id})

  if not self._story or not self._story.passages then
    return false, "No story loaded"
  end

  for _, passage in ipairs(self._story.passages) do
    if passage.id == passage_id then
      self._current_passage = passage

      -- Check if this is an ending (no choices)
      if not passage.choices or #passage.choices == 0 then
        self._ended = true
      end

      return true
    end
  end

  return false, "Passage not found: " .. passage_id
end

function MockEngine:has_ended()
  self:_record_call("has_ended", {}, self._ended)
  return self._ended
end

function MockEngine:reset()
  self:_record_call("reset", {})
  self._current_passage = nil
  self._started = false
  self._ended = false
  self._state = {}
end

function MockEngine:get_story()
  self:_record_call("get_story", {}, self._story)
  return self._story
end

function MockEngine:is_loaded()
  local result = self._story ~= nil
  self:_record_call("is_loaded", {}, result)
  return result
end

function MockEngine:get_state()
  self:_record_call("get_state", {}, self._state)
  return self._state
end

function MockEngine:set_state(state)
  self:_record_call("set_state", {state})
  self._state = state
end

return MockEngine
