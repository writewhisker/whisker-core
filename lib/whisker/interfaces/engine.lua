--- IEngine Interface
-- Interface for story execution engines
-- @module whisker.interfaces.engine
-- @author Whisker Core Team
-- @license MIT

local IEngine = {}

--- Load a story into the engine
-- @param story Story The story to load
-- @return boolean True if loading succeeded
-- @return string|nil Error message if loading failed
function IEngine:load(story)
  error("IEngine:load must be implemented")
end

--- Start the story from the beginning or specified passage
-- @param passage_id string|nil Optional starting passage ID
-- @return boolean True if start succeeded
function IEngine:start(passage_id)
  error("IEngine:start must be implemented")
end

--- Get the current passage
-- @return Passage The current passage, or nil if not started
function IEngine:get_current_passage()
  error("IEngine:get_current_passage must be implemented")
end

--- Get available choices for the current passage
-- @return table Array of available Choice objects
function IEngine:get_available_choices()
  error("IEngine:get_available_choices must be implemented")
end

--- Make a choice by index
-- @param choice_index number The 1-based index of the choice
-- @return boolean True if the choice was made successfully
-- @return string|nil Error message if choice failed
function IEngine:make_choice(choice_index)
  error("IEngine:make_choice must be implemented")
end

--- Navigate to a specific passage
-- @param passage_id string The passage ID to navigate to
-- @return boolean True if navigation succeeded
-- @return string|nil Error message if navigation failed
function IEngine:go_to_passage(passage_id)
  error("IEngine:go_to_passage must be implemented")
end

--- Check if the story has ended
-- @return boolean True if the story has ended
function IEngine:has_ended()
  error("IEngine:has_ended must be implemented")
end

--- Reset the engine state
function IEngine:reset()
  error("IEngine:reset must be implemented")
end

--- Get the loaded story
-- @return Story The loaded story, or nil
function IEngine:get_story()
  error("IEngine:get_story must be implemented")
end

--- Check if a story is loaded
-- @return boolean True if a story is loaded
function IEngine:is_loaded()
  error("IEngine:is_loaded must be implemented")
end

--- Get engine state for serialization
-- @return table The engine state
function IEngine:get_state()
  error("IEngine:get_state must be implemented")
end

--- Restore engine state from serialization
-- @param state table The state to restore
function IEngine:set_state(state)
  error("IEngine:set_state must be implemented")
end

return IEngine
