-- lib/whisker/core/engine.lua
-- WLS 2.0 Engine with Hook Integration

local HookManager = require("lib.whisker.wls2.hook_manager")
local Renderer = require("lib.whisker.core.renderer")
local LuaInterpreter = require("lib.whisker.core.lua_interpreter")
local GameState = require("lib.whisker.core.game_state")

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

  -- WLS 1.0 GAP-009: Initialize game_state for tunnel stack support
  self.game_state = GameState.new()
  if story then
    self.game_state:initialize(story)
  end

  -- Initialize hook system
  self.hook_manager = HookManager.new()

  -- Initialize Lua interpreter with hook API
  self.lua_interpreter = LuaInterpreter.new(self)

  -- Pass hook_manager to renderer
  self.renderer = Renderer.new(
    self.lua_interpreter,
    config and config.platform or "plain",
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

  -- WLS 1.0 GAP-009: Initialize game_state for tunnel stack support
  self.game_state = GameState.new()
  if story then
    self.game_state:initialize(story)
  end

  -- Initialize hook system
  self.hook_manager = HookManager.new()

  -- Initialize Lua interpreter with hook API
  self.lua_interpreter = LuaInterpreter.new(self)

  -- Pass hook_manager to renderer
  self.renderer = Renderer.new(
    self.lua_interpreter,
    config and config.platform or "plain",
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

  -- Update game_state current passage
  if self.game_state then
    self.game_state:set_current_passage(passage_id)
  end

  -- Render passage (this will register new hooks)
  local rendered = self.renderer:render_passage(passage, self.state, passage_id)

  return rendered
end

-- ============================================================================
-- WLS 1.0 GAP-009: Tunnel Navigation
-- ============================================================================

--- Execute a tunnel call (-> Target ->)
-- Pushes the return address onto the tunnel stack and navigates to target
-- @param target_passage string - Target passage name
-- @return string|nil rendered_content - Rendered target passage content
-- @return string|nil error - Error message if failed
function Engine:tunnel_call(target_passage)
  if not self.current_passage then
    return nil, "No current passage for tunnel call"
  end

  if not self.game_state then
    return nil, "Game state not initialized for tunnel operations"
  end

  -- Push return address
  local success, err = self.game_state:tunnel_push(
    self.current_passage.id,
    nil  -- Could track position for inline tunnels
  )

  if not success then
    return nil, err
  end

  -- Navigate to target
  return self:navigate_to_passage(target_passage)
end

--- Execute a tunnel return (<-)
-- Pops the return address from the tunnel stack and navigates back
-- @return string|nil rendered_content - Rendered return passage content
-- @return string|nil error - Error message if failed
function Engine:tunnel_return()
  if not self.game_state then
    return nil, "Game state not initialized for tunnel operations"
  end

  -- Pop return address
  local return_info, err = self.game_state:tunnel_pop()

  if not return_info then
    -- Empty stack - handle based on config
    local empty_behavior = self.config and self.config.tunnel_empty_behavior or "error"

    if empty_behavior == "error" then
      return nil, err
    elseif empty_behavior == "restart" then
      -- Navigate to start passage
      local start_passage = self.story and self.story.start_passage_name
      if start_passage then
        return self:navigate_to_passage(start_passage)
      end
      return nil, "No start passage defined for restart behavior"
    else
      -- Default: stay on current passage (re-render it)
      if self.current_passage then
        return self.renderer:render_passage(
          self.current_passage,
          self.state,
          self.current_passage.id
        )
      end
      return nil, "No current passage to stay on"
    end
  end

  -- Navigate back to return passage
  return self:navigate_to_passage(return_info.passage_id)
end

--- Process passage content for tunnel operations
-- Checks if content ends with tunnel call or return
-- @param content string - Rendered passage content
-- @return string content - Content without tunnel operation
-- @return table|nil navigation - { type, target } if tunnel operation found
function Engine:process_tunnel_operations(content)
  -- Check for tunnel call at end of content: -> Target ->
  local text_before_call, tunnel_target = content:match("^(.-)%s*%->%s*([%w_]+)%s*%->%s*$")
  if tunnel_target then
    return text_before_call or "", { type = "tunnel_call", target = tunnel_target }
  end

  -- Check for tunnel return at end of content: <-
  local text_before_return = content:match("^(.-)%s*<%-+%s*$")
  if text_before_return then
    return text_before_return, { type = "tunnel_return" }
  end

  return content, nil
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
  elseif operation == "clear" then
    -- GAP-019: Clear hook content to empty string (different from hide)
    success, err = self.hook_manager:clear_hook(hook_id)
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
-- WLS 1.0 GAP-031: Also processes gather points after choice execution
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

  -- Track choice depth for gather point processing (GAP-031)
  local choice_depth = choice.depth or 1

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

  -- If no navigation, check for gather points at same depth (GAP-031)
  local gather_content = self:execute_gather_after_choice(self.current_passage, choice_depth)

  -- Return re-rendered current passage with gather content
  local rendered = self.renderer:rerender_passage(
    self.current_passage,
    self.state,
    self.current_passage.id
  )

  -- Append gather content if present
  if gather_content and gather_content ~= "" then
    rendered = rendered .. "\n" .. gather_content
  end

  return rendered
end

-- ============================================================================
-- WLS 1.0 GAP-031: Gather Point Execution
-- ============================================================================

--- Execute gather points after a choice at a specific depth
-- Gathers collect flow after choices at the same depth level
-- @param passage table - The current passage with gathers
-- @param choice_depth number - The depth of the choice that was selected
-- @return string - Rendered gather content
function Engine:execute_gather_after_choice(passage, choice_depth)
  if not passage or not passage.gathers then
    return ""
  end

  local gathers = passage.gathers
  local gather_content = {}

  -- Find gathers at matching depth and execute them
  for _, gather in ipairs(gathers) do
    if gather.depth == choice_depth then
      -- Process gather content through control flow if available
      local content = gather.content
      if self.control_flow then
        content = self.control_flow:process(content)
      end

      -- Render the gather content
      local rendered = self.renderer:evaluate_expressions(content, self.state)
      rendered = self.renderer:apply_formatting(rendered)

      table.insert(gather_content, rendered)

      -- After processing gather at this depth, continue to lower depth gathers
      if choice_depth > 1 then
        local lower_gather = self:execute_gather_after_choice(passage, choice_depth - 1)
        if lower_gather and lower_gather ~= "" then
          table.insert(gather_content, lower_gather)
        end
      end

      -- Only execute the first matching gather at each depth
      break
    end
  end

  return table.concat(gather_content, "\n")
end

--- Get gathers organized by depth
-- @param passage table - Passage with gathers
-- @return table - Map of depth -> array of gathers
function Engine:get_gathers_by_depth(passage)
  if not passage or not passage.gathers then
    return {}
  end

  local by_depth = {}
  for _, gather in ipairs(passage.gathers) do
    local depth = gather.depth or 1
    if not by_depth[depth] then
      by_depth[depth] = {}
    end
    table.insert(by_depth[depth], gather)
  end

  return by_depth
end

--- Serialize engine state for saving
-- @return table state_data - Serialized state
function Engine:serialize_state()
  return {
    state = self.state,
    current_passage = self.current_passage and self.current_passage.id or nil,
    history = self.history,
    hooks = self.hook_manager:serialize(),
    -- WLS 1.0 GAP-013: Include game_state which contains tunnel stack
    game_state = self.game_state and self.game_state:serialize() or nil
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

  -- WLS 1.0 GAP-013: Restore game_state which contains tunnel stack
  if data.game_state and self.game_state then
    self.game_state:deserialize(data.game_state)
  end

  if data.current_passage then
    return self:navigate_to_passage(data.current_passage, true)
  end
end

return Engine
