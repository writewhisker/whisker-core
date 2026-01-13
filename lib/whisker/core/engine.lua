-- lib/whisker/core/engine.lua
-- WLS 2.0 Engine with Hook Integration

local HookManager = require("lib.whisker.wls2.hook_manager")
local Renderer = require("lib.whisker.core.renderer")
local LuaInterpreter = require("lib.whisker.core.lua_interpreter")

local Engine = {}
Engine.__index = Engine

--- Create a new Engine instance
-- @param story table - Story object
-- @param config table - Configuration options
-- @return Engine instance
function Engine.new(story, config)
  local self = setmetatable({}, Engine)
  
  self.story = story
  self.config = config or {}
  self.state = {}
  self.history = {}
  self.current_passage = nil
  
  -- Initialize hook system
  self.hook_manager = HookManager.new()
  
  -- Initialize Lua interpreter with hook API
  self.lua_interpreter = LuaInterpreter.new(self)
  
  -- Pass hook_manager to renderer
  self.renderer = Renderer.new(
    self.lua_interpreter, 
    config.platform or "plain",
    self.hook_manager
  )
  
  return self
end

--- Initialize engine with story and config
-- @param story table - Story object
-- @param config table - Configuration options
-- @return boolean success
function Engine:init(story, config)
  self.story = story
  self.config = config or {}
  self.state = {}
  self.history = {}
  self.current_passage = nil
  
  -- Initialize hook system
  self.hook_manager = HookManager.new()
  
  -- Initialize Lua interpreter with hook API
  self.lua_interpreter = LuaInterpreter.new(self)
  
  -- Pass hook_manager to renderer
  self.renderer = Renderer.new(
    self.lua_interpreter, 
    config.platform or "plain",
    self.hook_manager
  )
  
  return true
end

--- Clear hooks when leaving a passage and navigate to new passage
-- @param passage_id string - Target passage identifier
-- @param skip_history boolean - Skip adding to history if true
-- @return string rendered_content - Rendered passage text
-- @return string|nil error - Error message if navigation failed
function Engine:navigate_to_passage(passage_id, skip_history)
  -- Clean up previous passage hooks
  if self.current_passage then
    self.hook_manager:clear_passage_hooks(self.current_passage.id)
  end
  
  -- Store previous passage in history
  if not skip_history and self.current_passage then
    table.insert(self.history, {
      passage_id = self.current_passage.id,
      state = self:serialize_state()
    })
  end
  
  -- Load new passage
  local passage = self.story:get_passage(passage_id)
  if not passage then
    return nil, "Passage not found: " .. passage_id
  end
  
  self.current_passage = passage
  
  -- Render passage (this will register new hooks)
  local rendered = self.renderer:render_passage(passage, self.state, passage_id)
  
  return rendered
end

--- Execute a hook operation and return updated content
-- @param operation string - Operation type (replace, append, prepend, show, hide)
-- @param target string - Hook name (without passage prefix)
-- @param content string - Content for operation (optional for show/hide)
-- @return string|nil rendered_text - Updated passage content
-- @return string|nil error - Error message if failed
function Engine:execute_hook_operation(operation, target, content)
  if not self.current_passage then
    return nil, "No current passage"
  end
  
  -- Build full hook ID
  local hook_id = self.current_passage.id .. "_" .. target
  
  -- Validate hook exists
  local hook = self.hook_manager:get_hook(hook_id)
  if not hook then
    return nil, "Hook not found: " .. target
  end
  
  -- Execute operation
  local success, err
  
  if operation == "replace" then
    success, err = self.hook_manager:replace_hook(hook_id, content)
  elseif operation == "append" then
    success, err = self.hook_manager:append_hook(hook_id, content)
  elseif operation == "prepend" then
    success, err = self.hook_manager:prepend_hook(hook_id, content)
  elseif operation == "show" then
    success, err = self.hook_manager:show_hook(hook_id)
  elseif operation == "hide" then
    success, err = self.hook_manager:hide_hook(hook_id)
  else
    return nil, "Unknown operation: " .. operation
  end
  
  if not success then
    return nil, err
  end
  
  -- Re-render passage with updated hooks
  local rendered = self.renderer:rerender_passage(
    self.current_passage, 
    self.state, 
    self.current_passage.id
  )
  
  return rendered
end

--- Parse hook operations from choice content
-- @param choice_text string - Raw choice content
-- @return table operations - Array of {operation, target, content}
function Engine:parse_hook_operations(choice_text)
  local operations = {}
  
  -- Pattern: @operation: target { content }
  -- Example: @replace: status { Updated! }
  for operation, target, content in choice_text:gmatch("@(%w+):%s*(%w+)%s*{([^}]*)}") do
    table.insert(operations, {
      operation = operation,
      target = target,
      content = content
    })
  end
  
  return operations
end

--- Execute choice and handle hook operations
-- @param choice_index number - Index of choice selected
-- @return string|nil result - New passage content or error
-- @return string|nil error - Error message if failed
function Engine:execute_choice(choice_index)
  if not self.current_passage then
    return nil, "No current passage"
  end
  
  local choices = self.current_passage:get_choices()
  local choice = choices[choice_index]
  
  if not choice then
    return nil, "Invalid choice index"
  end
  
  -- Parse and execute hook operations in choice
  local operations = self:parse_hook_operations(choice.text)
  
  for _, op in ipairs(operations) do
    local rendered, err = self:execute_hook_operation(
      op.operation,
      op.target,
      op.content
    )
    
    if err then
      return nil, err
    end
  end
  
  -- Navigate to target passage if specified
  if choice.target then
    return self:navigate_to_passage(choice.target)
  end
  
  -- If no navigation, return re-rendered current passage
  return self.renderer:rerender_passage(
    self.current_passage,
    self.state,
    self.current_passage.id
  )
end

--- Serialize engine state for saving
-- @return table state_data - Serialized state
function Engine:serialize_state()
  return {
    state = self.state,
    current_passage = self.current_passage and self.current_passage.id or nil,
    history = self.history,
    hooks = self.hook_manager:serialize()
  }
end

--- Deserialize engine state for loading
-- @param data table - State data to restore
-- @return string|nil rendered - Rendered content if navigation occurred
-- @return string|nil error - Error message if failed
function Engine:deserialize_state(data)
  self.state = data.state or {}
  self.history = data.history or {}
  
  if data.hooks then
    self.hook_manager:deserialize(data.hooks)
  end
  
  if data.current_passage then
    return self:navigate_to_passage(data.current_passage, true)
  end
end

return Engine
