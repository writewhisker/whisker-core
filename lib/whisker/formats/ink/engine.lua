--- Ink Story Engine
-- Engine for executing Ink stories using tinta runtime
-- @module whisker.formats.ink.engine
-- @author Whisker Core Team
-- @license MIT

local InkEngine = {}
InkEngine.__index = InkEngine

--- Dependencies injected via container
-- ink_runtime and json_codec are the vendor abstractions
InkEngine._dependencies = { "events", "state", "logger", "ink_runtime", "json_codec" }

--- Create a new InkEngine instance
-- @param deps table Dependencies from container
-- @return InkEngine
function InkEngine.new(deps)
  local self = setmetatable({}, InkEngine)

  deps = deps or {}
  self.events = deps.events
  self.state = deps.state
  self.log = deps.logger

  -- Vendor dependencies (lazy-loaded if not injected)
  self._ink_runtime = deps.ink_runtime
  self._json_codec = deps.json_codec

  self._story = nil
  self._loaded = false
  self._started = false
  self._ended = false
  self._external_functions = {}
  self._variable_observers = {}
  self._state_bridge = nil

  return self
end

--- Create InkEngine via container pattern
-- @param container table DI container
-- @return InkEngine
function InkEngine.create(container)
  local deps = {}
  if container and container.has then
    if container:has("events") then
      deps.events = container:resolve("events")
    end
    if container:has("state") then
      deps.state = container:resolve("state")
    end
    if container:has("logger") then
      deps.logger = container:resolve("logger")
    end
    if container:has("ink_runtime") then
      deps.ink_runtime = container:resolve("ink_runtime")
    end
    if container:has("json_codec") then
      deps.json_codec = container:resolve("json_codec")
    end
  end
  return InkEngine.new(deps)
end

--- Get or lazy-load the JSON codec
-- @private
-- @return IJsonCodec
function InkEngine:_get_json_codec()
  if not self._json_codec then
    local JsonCodec = require("whisker.vendor.codecs.json_codec")
    self._json_codec = JsonCodec.new()
  end
  return self._json_codec
end

--- Get or lazy-load the Ink runtime
-- @private
-- @return IInkRuntime
function InkEngine:_get_ink_runtime()
  if not self._ink_runtime then
    local InkRuntime = require("whisker.vendor.runtimes.ink_runtime")
    self._ink_runtime = InkRuntime.new({
      json_codec = self:_get_json_codec(),
      logger = self.log,
    })
  end
  return self._ink_runtime
end

--- Load Ink JSON into the engine
-- @param json_text string The Ink JSON to load
-- @return boolean Success
-- @return string|nil Error message
function InkEngine:load(json_text)
  if self._loaded then
    return nil, "Story already loaded. Call reset() first."
  end

  -- Use injected or lazy-loaded runtime
  local ink_runtime = self:_get_ink_runtime()

  -- Create story using the runtime abstraction
  local story_wrapper, err = ink_runtime:create_story(json_text)
  if err then
    return nil, err
  end

  -- Get the ink data for metadata
  local ink_data = story_wrapper:get_ink_data()

  self._story = story_wrapper
  self._loaded = true
  self._started = false
  self._ended = false

  -- Setup state bridge for variable synchronization
  self:_setup_state_bridge()

  -- Emit loaded event
  if self.events then
    self.events:emit("ink:loaded", {
      metadata = {
        inkVersion = ink_data.inkVersion,
        hasVariables = ink_data.root ~= nil,
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
  -- Use wrapper method if available, fallback to direct state access
  if self._story.GetVariable then
    return self._story:GetVariable(name)
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

  -- Use wrapper method if available, fallback to direct state access
  if self._story.SetVariable then
    self._story:SetVariable(name, value)
  else
    self._story.state.variablesState:SetVariable(name, value)
  end

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
  -- Use wrapper method if available, fallback to direct state access
  local vars_state
  if self._story.get_variables_state then
    vars_state = self._story:get_variables_state()
  else
    vars_state = self._story.state.variablesState
  end
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

  -- Use wrapper method if available, fallback to direct state access
  if self._story.save then
    return self._story:save()
  end
  return self._story.state:save()
end

--- Restore engine state
-- @param state table The state to restore
function InkEngine:restore_state(state)
  if not self._loaded then
    return false, "No story loaded"
  end

  -- Use wrapper method if available, fallback to direct state access
  if self._story.load then
    self._story:load(state)
  else
    self._story.state:load(state)
  end

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
-- @return Story The raw tinta story or wrapper
function InkEngine:get_raw_story()
  -- If we have a wrapper, return the underlying raw story
  if self._story and self._story.get_raw_story then
    return self._story:get_raw_story()
  end
  return self._story
end

--- Get the story wrapper (if using injected runtime)
-- @return StoryWrapper|nil The story wrapper
function InkEngine:get_story_wrapper()
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
