--- Ink Story Engine
-- Engine for executing Ink stories using tinta runtime
-- @module whisker.formats.ink.engine
-- @author Whisker Core Team
-- @license MIT

local InkEngine = {}
InkEngine.__index = InkEngine

--- Dependencies injected via container
InkEngine._dependencies = { "events", "state", "logger" }

--- Create a new InkEngine instance
-- @param deps table Dependencies from container
-- @return InkEngine
function InkEngine.new(deps)
  local self = setmetatable({}, InkEngine)

  self.events = deps.events
  self.state = deps.state
  self.log = deps.logger

  self._story = nil
  self._loaded = false
  self._started = false
  self._ended = false
  self._external_functions = {}
  self._variable_observers = {}
  self._state_bridge = nil

  return self
end

--- Load Ink JSON into the engine
-- @param json_text string The Ink JSON to load
-- @return boolean Success
-- @return string|nil Error message
function InkEngine:load(json_text)
  if self._loaded then
    return nil, "Story already loaded. Call reset() first."
  end

  local tinta = require("whisker.vendor.tinta")
  local json = require("cjson")

  local ok, parsed = pcall(json.decode, json_text)
  if not ok then
    return nil, "Failed to parse Ink JSON: " .. tostring(parsed)
  end

  local ok2, story = pcall(tinta.create_story, parsed)
  if not ok2 then
    return nil, "Failed to create Ink story: " .. tostring(story)
  end

  self._story = story
  self._loaded = true
  self._started = false
  self._ended = false

  -- Setup state bridge for variable synchronization
  self:_setup_state_bridge()

  -- Emit loaded event
  if self.events then
    self.events:emit("ink:loaded", {
      metadata = {
        inkVersion = parsed.inkVersion,
        hasVariables = parsed.root ~= nil,
      },
    })
  end

  return true
end

--- Start the story
-- @param knot_name string|nil Optional starting knot
-- @return boolean Success
function InkEngine:start(knot_name)
  if not self._loaded then
    return false, "No story loaded"
  end

  if self._started then
    return false, "Story already started"
  end

  if knot_name then
    self._story:ChoosePathString(knot_name)
  end

  self._started = true

  if self.events then
    self.events:emit("ink:started", {
      knot = knot_name,
    })
  end

  return true
end

--- Check if story can continue
-- @return boolean
function InkEngine:can_continue()
  if not self._loaded or not self._started then
    return false
  end
  return self._story:canContinue()
end

--- Continue the story and get the next line
-- @return string|nil Text content
-- @return table|nil Tags
function InkEngine:continue()
  if not self:can_continue() then
    return nil, nil
  end

  local text = self._story:Continue()
  local tags = self._story:currentTags()

  if self.events then
    self.events:emit("ink:continued", {
      text = text,
      tags = tags,
    })
  end

  return text, tags
end

--- Continue maximally and get all text until choices or end
-- @return string Combined text
-- @return table All tags encountered
function InkEngine:continue_maximally()
  local all_text = {}
  local all_tags = {}

  while self:can_continue() do
    local text, tags = self:continue()
    if text then
      table.insert(all_text, text)
    end
    if tags then
      for _, tag in ipairs(tags) do
        table.insert(all_tags, tag)
      end
    end
  end

  return table.concat(all_text), all_tags
end

--- Get current text (after Continue)
-- @return string
function InkEngine:get_current_text()
  if not self._loaded then
    return ""
  end
  return self._story:currentText() or ""
end

--- Get current tags
-- @return table
function InkEngine:get_current_tags()
  if not self._loaded then
    return {}
  end
  return self._story:currentTags() or {}
end

--- Get available choices
-- @return table Array of choice objects
function InkEngine:get_choices()
  if not self._loaded or not self._started then
    return {}
  end

  local raw_choices = self._story:currentChoices() or {}
  local choices = {}

  for i, choice in ipairs(raw_choices) do
    table.insert(choices, {
      index = i,
      text = choice.text,
      tags = choice.tags or {},
      original = choice,
    })
  end

  if self.events and #choices > 0 then
    self.events:emit("ink:choices_available", {
      count = #choices,
      choices = choices,
    })
  end

  return choices
end

--- Make a choice by index (1-based)
-- @param index number The choice index
-- @return boolean Success
function InkEngine:make_choice(index)
  if not self._loaded or not self._started then
    return false, "Story not ready"
  end

  local choices = self._story:currentChoices()
  if not choices or #choices == 0 then
    return false, "No choices available"
  end

  if index < 1 or index > #choices then
    return false, "Invalid choice index"
  end

  self._story:ChooseChoiceIndex(index)

  if self.events then
    self.events:emit("ink:choice_made", {
      index = index,
      text = choices[index].text,
    })
  end

  return true
end

--- Check if story has ended
-- @return boolean
function InkEngine:has_ended()
  if not self._loaded then
    return false
  end
  return not self._story:canContinue() and #(self._story:currentChoices() or {}) == 0
end

--- Get a variable value
-- @param name string Variable name
-- @return any Variable value
function InkEngine:get_variable(name)
  if not self._loaded then
    return nil
  end
  return self._story.state.variablesState:GetVariableWithName(name)
end

--- Set a variable value
-- @param name string Variable name
-- @param value any Variable value
function InkEngine:set_variable(name, value)
  if not self._loaded then
    return
  end

  local old_value = self:get_variable(name)
  self._story.state.variablesState:SetVariable(name, value)

  if self.events then
    self.events:emit("ink:variable_changed", {
      name = name,
      old_value = old_value,
      value = value,
    })
  end
end

--- Get all variable names
-- @return table Array of variable names
function InkEngine:get_variable_names()
  if not self._loaded then
    return {}
  end

  local names = {}
  local vars_state = self._story.state.variablesState
  if vars_state and vars_state._globalVariables then
    for name, _ in pairs(vars_state._globalVariables) do
      table.insert(names, name)
    end
  end
  return names
end

--- Observe a variable for changes
-- @param name string Variable name or "*" for all
-- @param callback function Callback(name, old_value, new_value)
-- @return function Unsubscribe function
function InkEngine:observe_variable(name, callback)
  if not self._loaded then
    return function() end
  end

  if name == "*" then
    -- Observe all variables
    self._variable_observers[callback] = true
    self._story:ObserveVariable("*", callback)
    return function()
      self._variable_observers[callback] = nil
    end
  else
    self._story:ObserveVariable(name, callback)
    return function()
      self._story:RemoveVariableObserver(callback, name)
    end
  end
end

--- Bind an external function
-- @param name string Function name
-- @param fn function The function
-- @param lookahead_safe boolean Whether safe for lookahead
function InkEngine:bind_external_function(name, fn, lookahead_safe)
  if not self._loaded then
    self._external_functions[name] = { fn = fn, lookahead_safe = lookahead_safe }
    return
  end

  -- Wrap function to convert arguments
  local wrapped = function(args)
    return fn(table.unpack(args))
  end

  self._story:BindExternalFunction(name, wrapped, lookahead_safe)
end

--- Unbind an external function
-- @param name string Function name
function InkEngine:unbind_external_function(name)
  if self._loaded then
    self._story:UnbindExternalFunction(name)
  end
  self._external_functions[name] = nil
end

--- Navigate to a specific path
-- @param path string The path (e.g., "knot.stitch")
-- @param reset_callstack boolean Whether to reset callstack
function InkEngine:go_to_path(path, reset_callstack)
  if not self._loaded then
    return false, "No story loaded"
  end

  reset_callstack = reset_callstack ~= false

  self._story:ChoosePathString(path, reset_callstack)

  if self.events then
    self.events:emit("ink:path_changed", {
      path = path,
    })
  end

  return true
end

--- Evaluate an Ink function
-- @param function_name string Function name
-- @param ... any Arguments
-- @return any Return value
-- @return string Text output
function InkEngine:evaluate_function(function_name, ...)
  if not self._loaded then
    return nil, ""
  end

  local args = { ... }
  return self._story:EvaluateFunction(function_name, args)
end

--- Check if a knot/function exists
-- @param name string The name
-- @return boolean
function InkEngine:has_function(name)
  if not self._loaded then
    return false
  end
  return self._story:HasFunction(name)
end

--- Save engine state
-- @return table Serializable state
function InkEngine:save_state()
  if not self._loaded then
    return nil, "No story loaded"
  end

  return self._story.state:save()
end

--- Restore engine state
-- @param state table The state to restore
function InkEngine:restore_state(state)
  if not self._loaded then
    return false, "No story loaded"
  end

  self._story.state:load(state)

  if self.events then
    self.events:emit("ink:state_restored", {})
  end

  return true
end

--- Reset the engine
function InkEngine:reset()
  if self._loaded then
    self._story:ResetState()
  end

  self._started = false
  self._ended = false

  if self.events then
    self.events:emit("ink:reset", {})
  end
end

--- Get current flow name
-- @return string
function InkEngine:get_current_flow()
  if not self._loaded then
    return "DEFAULT"
  end
  return self._story:currentFlowName() or "DEFAULT"
end

--- Switch to a different flow
-- @param flow_name string Flow name
function InkEngine:switch_flow(flow_name)
  if not self._loaded then
    return false
  end

  self._story:SwitchFlow(flow_name)

  if self.events then
    self.events:emit("ink:flow_switched", {
      flow = flow_name,
    })
  end

  return true
end

--- Remove a flow
-- @param flow_name string Flow name
function InkEngine:remove_flow(flow_name)
  if not self._loaded then
    return false
  end

  self._story:RemoveFlow(flow_name)
  return true
end

--- Get all alive flow names
-- @return table
function InkEngine:get_alive_flows()
  if not self._loaded then
    return {}
  end
  return self._story:aliveFlowNames() or {}
end

--- Setup state bridge for Whisker state integration
-- @private
function InkEngine:_setup_state_bridge()
  if not self.state then
    return
  end

  local StateBridge = require("whisker.formats.ink.state_bridge")
  self._state_bridge = StateBridge.new(self, self.state, self.events)
  self._state_bridge:sync_all()
end

--- Get the raw tinta story (for advanced usage)
-- @return Story
function InkEngine:get_raw_story()
  return self._story
end

--- Check if engine is loaded
-- @return boolean
function InkEngine:is_loaded()
  return self._loaded
end

--- Check if engine is started
-- @return boolean
function InkEngine:is_started()
  return self._started
end

return InkEngine
