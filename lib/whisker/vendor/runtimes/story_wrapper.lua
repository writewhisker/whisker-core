--- Story Wrapper
-- Wraps a tinta story object with a consistent API
-- Implements IStoryWrapper interface for dependency injection
-- @module whisker.vendor.runtimes.story_wrapper
-- @author Whisker Core Team
-- @license MIT

local StoryWrapper = {}
StoryWrapper._dependencies = {}
StoryWrapper.__index = StoryWrapper

--- Create a new StoryWrapper instance
-- @param raw_story table The raw tinta story object
-- @param ink_data table The original Ink data
-- @param json_codec table|nil Optional JSON codec for serialization
-- @return StoryWrapper
function StoryWrapper.new(raw_story, ink_data, json_codec)
  local self = setmetatable({}, StoryWrapper)

  self._story = raw_story
  self._ink_data = ink_data
  self._json_codec = json_codec

  -- Access the state directly
  self.state = raw_story.state

  return self
end

--- Check if the story can continue
-- @return boolean True if there is more content
function StoryWrapper:canContinue()
  return self._story:canContinue()
end

--- Continue the story and get next text
-- @return string The next line of text
function StoryWrapper:Continue()
  return self._story:Continue()
end

--- Get current text (after Continue was called)
-- @return string Current text content
function StoryWrapper:currentText()
  return self._story:currentText() or ""
end

--- Get current tags (after Continue was called)
-- @return table Array of tag strings
function StoryWrapper:currentTags()
  return self._story:currentTags() or {}
end

--- Get available choices
-- @return table Array of choice objects with text, tags properties
function StoryWrapper:currentChoices()
  return self._story:currentChoices() or {}
end

--- Make a choice by index (1-based in Lua)
-- @param index number The choice index
function StoryWrapper:ChooseChoiceIndex(index)
  self._story:ChooseChoiceIndex(index)
end

--- Navigate to a specific path
-- @param path string The story path (e.g., "knot.stitch")
-- @param reset_callstack boolean|nil Whether to reset the callstack
function StoryWrapper:ChoosePathString(path, reset_callstack)
  if reset_callstack == nil then
    reset_callstack = true
  end
  self._story:ChoosePathString(path, reset_callstack)
end

--- Get the story state for save/load
-- @return table The story state object
function StoryWrapper:get_state()
  return self._story.state
end

--- Save story state to serializable table
-- @return table Serializable state data
function StoryWrapper:save()
  return self._story.state:save()
end

--- Load story state from saved data
-- @param state_data table The state data to restore
function StoryWrapper:load(state_data)
  self._story.state:load(state_data)
end

--- Reset the story to initial state
function StoryWrapper:ResetState()
  self._story:ResetState()
end

--- Bind an external function
-- @param name string Function name
-- @param fn function The function to call
-- @param lookahead_safe boolean Whether function is safe during lookahead
function StoryWrapper:BindExternalFunction(name, fn, lookahead_safe)
  -- Wrap function to convert arguments
  local wrapped = function(args)
    return fn(table.unpack(args))
  end
  self._story:BindExternalFunction(name, wrapped, lookahead_safe)
end

--- Unbind an external function
-- @param name string Function name
function StoryWrapper:UnbindExternalFunction(name)
  self._story:UnbindExternalFunction(name)
end

--- Observe variable changes
-- @param name string Variable name or "*" for all
-- @param callback function Callback(name, value)
function StoryWrapper:ObserveVariable(name, callback)
  self._story:ObserveVariable(name, callback)
end

--- Remove a variable observer
-- @param callback function The callback to remove
-- @param name string|nil Variable name
function StoryWrapper:RemoveVariableObserver(callback, name)
  self._story:RemoveVariableObserver(callback, name)
end

--- Get current flow name
-- @return string Current flow name
function StoryWrapper:currentFlowName()
  return self._story:currentFlowName() or "DEFAULT"
end

--- Switch to a different flow
-- @param flow_name string Flow name
function StoryWrapper:SwitchFlow(flow_name)
  self._story:SwitchFlow(flow_name)
end

--- Remove a flow
-- @param flow_name string Flow name
function StoryWrapper:RemoveFlow(flow_name)
  self._story:RemoveFlow(flow_name)
end

--- Get all alive flow names
-- @return table Array of flow names
function StoryWrapper:aliveFlowNames()
  return self._story:aliveFlowNames() or {}
end

--- Check if a function exists
-- @param name string Function name
-- @return boolean True if exists
function StoryWrapper:HasFunction(name)
  return self._story:HasFunction(name)
end

--- Evaluate an Ink function
-- @param function_name string Function name
-- @param args table Array of arguments
-- @return any Return value
-- @return string Text output
function StoryWrapper:EvaluateFunction(function_name, args)
  return self._story:EvaluateFunction(function_name, args)
end

--- Get the variables state
-- @return table Variables state object
function StoryWrapper:get_variables_state()
  return self._story.state.variablesState
end

--- Get a variable value by name
-- @param name string Variable name
-- @return any Variable value
function StoryWrapper:GetVariable(name)
  return self._story.state.variablesState:GetVariableWithName(name)
end

--- Set a variable value
-- @param name string Variable name
-- @param value any Variable value
function StoryWrapper:SetVariable(name, value)
  self._story.state.variablesState:SetVariable(name, value)
end

--- Get the raw tinta story object (for advanced usage)
-- @return table The underlying tinta story
function StoryWrapper:get_raw_story()
  return self._story
end

--- Get the original Ink data
-- @return table The Ink JSON data
function StoryWrapper:get_ink_data()
  return self._ink_data
end

return StoryWrapper
