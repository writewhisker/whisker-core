-- lib/whisker/core/engine.lua
-- WLS 2.0 Engine with Hook Integration

local HookManager = require("lib.whisker.wls2.hook_manager")
local Renderer = require("lib.whisker.core.renderer")
local LuaInterpreter = require("lib.whisker.core.lua_interpreter")
local GameState = require("lib.whisker.core.game_state")
local Choice = require("lib.whisker.core.choice")

local Engine = {}
Engine.__index = Engine

-- Helper function for Lua version compatible code loading with environment
-- Lua 5.2+ uses load(chunk, chunkname, mode, env)
-- Lua 5.1/LuaJIT uses loadstring + setfenv
local function load_with_env(code, chunkname, env)
  if setfenv then
    -- Lua 5.1/LuaJIT path
    local func, err = loadstring(code, chunkname)
    if func then
      setfenv(func, env)
    end
    return func, err
  else
    -- Lua 5.2+ path
    return load(code, chunkname, "t", env)
  end
end

--- Create a new Engine instance
-- Supports multiple call patterns:
-- 1. Engine.new(story, game_state) - story object and game state
-- 2. Engine.new(story, config) - story object and config table
-- 3. Engine.new({interpreter=..., game_state=...}) - config object with interpreter/game_state
-- @param story_or_config table - Story object OR config table with interpreter/game_state
-- @param config_or_game_state table - Configuration options OR GameState object (optional)
-- @return Engine instance
function Engine.new(story_or_config, config_or_game_state)
  local self = setmetatable({}, Engine)

  -- Detect if first argument is a config object with interpreter/game_state
  if story_or_config and story_or_config.interpreter ~= nil then
    -- Config object pattern: Engine.new({interpreter=..., game_state=...})
    self.config = story_or_config
    self.game_state = story_or_config.game_state
    self.lua_interpreter = story_or_config.interpreter
    self.story = nil
  else
    -- Standard patterns: Engine.new(story, game_state) or Engine.new(story, config)
    self.story = story_or_config

    -- Detect if second argument is a GameState or config
    -- GameState has methods like set_current_passage, get_visit_count
    if config_or_game_state and type(config_or_game_state.set_current_passage) == "function" then
      -- It's a GameState object
      self.game_state = config_or_game_state
      self.config = {}
    else
      -- It's a config table
      self.config = config_or_game_state or {}
      self.game_state = self.config.game_state
    end

    -- WLS 1.0 GAP-009: Initialize game_state for tunnel stack support if not provided
    if not self.game_state then
      self.game_state = GameState.new()
      if self.story then
        self.game_state:initialize(self.story)
      end
    end

    -- Initialize Lua interpreter with hook API (unless provided in config)
    self.lua_interpreter = self.config.interpreter or LuaInterpreter.new(self)
  end

  self.state = {}
  self.history = {}
  self.current_passage = nil

  -- Initialize hook system
  self.hook_manager = HookManager.new()

  -- Pass hook_manager to renderer
  self.renderer = Renderer.new(
    self.lua_interpreter,
    self.config.platform or "plain",
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
    self.config.platform or "plain",
    self.hook_manager
  )

  return true
end

--- Start the story by navigating to the initial passage
-- @return string|nil rendered - Rendered initial passage content
-- @return string|nil error - Error message if failed
function Engine:start_story()
  if not self.story then
    return nil, "No story loaded"
  end

  -- Get starting passage (try common conventions)
  local start_result = self.story:get_start_passage()
  local passage_id

  if type(start_result) == "string" then
    passage_id = start_result
  elseif type(start_result) == "table" and start_result.id then
    passage_id = start_result.id
  else
    -- Try fallback passage names
    local fallback_passage = self.story:get_passage("start")
      or self.story:get_passage("Start")
    if fallback_passage then
      passage_id = fallback_passage.id or "start"
    end
  end

  if not passage_id then
    return nil, "No starting passage found"
  end

  return self:navigate_to_passage(passage_id)
end

--- Make a choice by index (1-based) - alias for execute_choice
-- @param choice_index number - Index of choice (1-based)
-- @return string|nil result - New passage content or nil on error
-- @return string|nil error - Error message if failed
function Engine:make_choice(choice_index)
  return self:execute_choice(choice_index)
end

--- Load a story into the engine
-- @param story table - Story object to load
function Engine:load_story(story)
  -- Try to restore Story metatable if loading plain table
  local Story = require("lib.whisker.story.story")
  if story and type(Story.from_table) == "function" and not getmetatable(story) then
    story = Story.from_table(story)
  end

  self.story = story
  self.current_story = story  -- Alias for backwards compatibility
  self.current_passage = nil
  self.history = {}
  self.state = {}
  if self.game_state and self.game_state.initialize then
    self.game_state:initialize(story)
  end
end

--- Get filtered choices for current passage
-- Filters out once-only choices that have been selected and choices with false conditions
-- @return table filtered_choices - Array of visible choices
function Engine:get_filtered_choices()
  if not self.current_passage then
    return {}
  end

  local choices = {}
  if self.current_passage.get_choices then
    choices = self.current_passage:get_choices()
  elseif self.current_passage.choices then
    choices = self.current_passage.choices
  end

  -- If no explicit choices, try to parse inline choices from passage content
  if #choices == 0 then
    local content = self.current_passage.content or (self.current_passage.get_content and self.current_passage:get_content())
    if content then
      choices = self:parse_choices_from_content(content)
    end
  end

  -- Filter out once-only choices that have been selected and choices with false conditions
  if self.game_state then
    local filtered_choices = {}
    for _, choice in ipairs(choices) do
      local choice_id = choice.id or (choice.get_id and choice:get_id())
      local is_once_only = false

      -- Check if once-only using various methods
      if choice.choice_type then
        is_once_only = choice.choice_type == "once"
      elseif type(choice.is_once_only) == "function" then
        is_once_only = choice:is_once_only()
      elseif choice.once_only then
        is_once_only = choice.once_only
      end

      -- Check if choice was selected
      local was_selected = false
      if choice_id then
        if type(self.game_state.is_choice_selected) == "function" then
          was_selected = self.game_state:is_choice_selected(choice_id)
        elseif self.game_state.selected_choices then
          was_selected = self.game_state.selected_choices[choice_id] == true
        end
      end

      -- Skip once-only choices that have been selected
      if is_once_only and was_selected then
        goto continue
      end

      -- Check choice condition if present
      local choice_condition = choice.condition or (type(choice.get_condition) == "function" and choice:get_condition())
      if choice_condition and choice_condition ~= "" then
        local condition_result = self:evaluate_condition(choice_condition, self.game_state)
        if not condition_result then
          goto continue
        end
      end

      table.insert(filtered_choices, choice)

      ::continue::
    end
    return filtered_choices
  end

  return choices
end

--- Get current passage content and choices
-- @return table result - {passage, choices, content} or nil
function Engine:get_current_content()
  if not self.current_passage then
    return nil
  end

  local choices = self:get_filtered_choices()

  -- Use cached rendered content if available (from navigate_to_passage)
  -- Otherwise render now
  local rendered_content = self._last_rendered_content
  if not rendered_content then
    local raw_content = self.current_passage.content or (self.current_passage.get_content and self.current_passage:get_content())
    if raw_content then
      rendered_content = self:render_passage_content(self.current_passage)
      self._last_rendered_content = rendered_content
    end
  end

  return {
    passage = self.current_passage,
    choices = choices,
    content = rendered_content
  }
end

--- Clear hooks when leaving a passage and navigate to new passage
-- @param passage_id string - Target passage identifier
-- @param skip_history boolean - Skip adding to history if true
-- @return table|string result - Structured result {passage, choices} if game_state, else rendered text
-- @return string|nil error - Error message if navigation failed
function Engine:navigate_to_passage(passage_id, skip_history)
  -- Clear cached rendered content from previous passage
  self._last_rendered_content = nil

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
    return nil, "Passage not found: " .. tostring(passage_id)
  end

  self.current_passage = passage

  -- Update game state if present
  if self.game_state then
    self.game_state:set_current_passage(passage_id)
  end

  -- If we have game_state, return structured result for test compatibility
  if self.game_state then
    -- Render content to process text alternatives and other dynamic features
    local rendered_content = self:render_passage_content(passage)

    -- Cache the rendered content so get_current_content doesn't re-render
    self._last_rendered_content = rendered_content

    return {
      passage = passage,
      passage_id = passage_id,
      choices = passage:get_choices(),
      content = rendered_content
    }
  end

  -- Legacy mode: render passage and return string
  return self.renderer:render_passage(passage, self.state, passage_id)
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

--- Parse inline choices from passage content
-- Format: + [choice text] -> target (once-only)
--         * [choice text] -> target (sticky)
-- @param content string - Passage content
-- @return table choices - Array of Choice objects
function Engine:parse_choices_from_content(content)
  local choices = {}

  -- Match choice lines: + [...] -> target or * [...] -> target
  -- The [...] part can contain hook operations like @replace: hook { content }
  for marker, choice_text, target in content:gmatch("\n?([%+%*])%s*%[([^%]]+)%]%s*%->%s*(%S+)") do
    local choice_type = marker == "+" and "once" or "sticky"

    -- Extract display text (text after last hook operation, or all text if no operations)
    local display_text = choice_text
    local operations_end = choice_text:find("[^}]+$")
    if operations_end then
      local text_part = choice_text:sub(operations_end)
      -- Remove leading @... {...} patterns to get display text
      text_part = text_part:gsub("^%s*@%w+:%s*%w+%s*{[^}]*}%s*", "")
      if text_part and text_part:match("%S") then
        display_text = text_part:match("^%s*(.-)%s*$")
      end
    end

    -- Create a Choice object
    local choice = Choice.new({
      text = choice_text,  -- Keep full text with hook operations
      target = target,
      choice_type = choice_type
    })

    table.insert(choices, choice)
  end

  return choices
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

  -- Get filtered choices (same filtering as get_current_content)
  local choices = self:get_filtered_choices()
  local choice = choices[choice_index]

  if not choice then
    return nil, "Invalid choice index"
  end

  -- Track choice depth for gather point processing (GAP-031)
  local choice_depth = choice.depth or 1

  -- Track once-only choice selection
  local choice_id = choice.id
  if not choice_id and type(choice.get_id) == "function" then
    choice_id = choice:get_id()
  end

  local is_once_only = false
  if choice.choice_type then
    is_once_only = choice.choice_type == "once"
  elseif type(choice.is_once_only) == "function" then
    is_once_only = choice:is_once_only()
  end

  -- Mark once-only choice as selected in game_state
  if is_once_only and choice_id and self.game_state then
    if type(self.game_state.mark_choice_selected) == "function" then
      self.game_state:mark_choice_selected(choice_id)
    else
      -- Fallback: store in game_state directly
      self.game_state.selected_choices = self.game_state.selected_choices or {}
      self.game_state.selected_choices[choice_id] = true
    end
  end

  -- Execute choice action if present
  local choice_action = choice.action or (type(choice.get_action) == "function" and choice:get_action())
  if choice_action and choice_action ~= "" and self.lua_interpreter then
    local context = { engine = self, story = self.story }
    self.lua_interpreter:execute_code(choice_action, self.game_state, context)
  end

  -- Parse and execute hook operations in choice
  local operations = self:parse_hook_operations(choice.text)

  for _, op in ipairs(operations) do
    -- Trim whitespace from content parsed from { } syntax
    local content = op.content
    if content and type(content) == "string" then
      content = content:match("^%s*(.-)%s*$") or content
    end

    local _, err = self:execute_hook_operation(
      op.operation,
      op.target,
      content
    )

    if err then
      return nil, err
    end
  end

  -- Get the target passage ID - check both .target and :get_target() methods
  local target_id = choice.target
  if not target_id and type(choice.get_target) == "function" then
    target_id = choice:get_target()
  end

  -- Handle special targets
  if target_id == "END" then
    -- End the story
    self.current_passage = nil
    if self.game_state then
      return {
        ended = true,
        choices = {}
      }
    end
    return nil
  elseif target_id == "RESTART" then
    -- Restart the story from beginning
    if self.game_state then
      self.game_state:reset()
    end
    self.history = {}
    self.state = {}
    return self:start_story()
  elseif target_id == "BACK" then
    -- Go back to previous passage in history
    if #self.history > 0 then
      local prev = table.remove(self.history)
      return self:navigate_to_passage(prev.passage_id, true)  -- Skip adding to history
    else
      -- No history, stay on current passage
      if self.game_state then
        return {
          passage = self.current_passage,
          choices = self.current_passage:get_choices()
        }
      end
      return nil
    end
  end

  -- Navigate to target passage if specified
  if target_id then
    -- If hook operations were applied and we're navigating to the same passage,
    -- don't do a full navigation (which would clear hooks) - just re-render
    local current_id = self.current_passage and self.current_passage.id
    if #operations > 0 and target_id == current_id then
      -- Re-render current passage with updated hooks
      if self.game_state then
        local rendered = self.renderer:rerender_passage(
          self.current_passage,
          self.game_state,
          current_id
        )
        return {
          passage = self.current_passage,
          choices = self:get_filtered_choices(),
          content = rendered
        }
      else
        return self.renderer:rerender_passage(
          self.current_passage,
          self.state,
          current_id
        )
      end
    end
    return self:navigate_to_passage(target_id)
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

  -- If we have game_state, return structured result
  if self.game_state then
    return {
      passage = self.current_passage,
      choices = self.current_passage:get_choices(),
      content = rendered
    }
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

--- Render passage content with variable interpolation and conditional processing
-- @param passage table - Passage object to render
-- @return string rendered - Rendered content text
function Engine:render_passage_content(passage)
  if not passage then
    return ""
  end

  local content = passage.content or passage:get_content()
  if not content then
    return ""
  end

  -- Get game state for variable access
  local state = self.game_state or self.state

  -- Handle escape sequences - temporarily replace with placeholders
  -- Use string.char(1) (SOH) as delimiter for Lua 5.1/LuaJIT compatibility
  -- Null bytes (\0) cause issues with pattern matching in older Lua versions
  local SOH = string.char(1)
  local ESCAPE_DOLLAR = SOH .. "ESC_DOLLAR" .. SOH
  local ESCAPE_BRACE_OPEN = SOH .. "ESC_BRACE_O" .. SOH
  local ESCAPE_BRACE_CLOSE = SOH .. "ESC_BRACE_C" .. SOH

  content = content:gsub("\\%$", ESCAPE_DOLLAR)
  content = content:gsub("\\{", ESCAPE_BRACE_OPEN)
  content = content:gsub("\\}", ESCAPE_BRACE_CLOSE)

  -- Process text alternatives: {| a | b | c} (sequence), {&| a | b | c} (cycle), {~| a | b | c} (random)
  content = self:process_text_alternatives(content, state)

  -- Process inline conditionals: {cond: true_text | false_text}
  content = self:process_inline_conditionals(content, state)

  -- Process conditional blocks: { condition }...{/} or { condition }...{else}...{/}
  content = self:process_conditionals(content, state)

  -- Process variable interpolation ($var and ${expr})
  content = self:interpolate_variables(content, state)

  -- Restore escape sequences
  content = content:gsub(ESCAPE_DOLLAR, "$")
  content = content:gsub(ESCAPE_BRACE_OPEN, "{")
  content = content:gsub(ESCAPE_BRACE_CLOSE, "}")

  return content
end

--- Process text alternatives: {| a | b | c }, {&| a | b | c }, {~| a | b | c }, {!| a | b | c }
-- {|...} = sequence (advances, sticks at last)
-- {&|...} = cycle (wraps around)
-- {~|...} = random (picks randomly each time)
-- {!|...} = once-only (each option shown once, then empty)
-- @param content string - Content with text alternatives
-- @param state table - Game state for variable access
-- @return string processed - Content with alternatives evaluated
function Engine:process_text_alternatives(content, state)
  local result = content

  -- Initialize text alternatives state if needed
  self.text_alternatives_state = self.text_alternatives_state or {}
  local alt_index = 0

  -- Process sequence alternatives {| a | b | c }
  result = result:gsub("{|([^}]+)}", function(options_str)
    alt_index = alt_index + 1
    local key = "seq_" .. alt_index

    -- Parse options (split by |)
    local options = {}
    for opt in options_str:gmatch("[^|]+") do
      local trimmed = opt:match("^%s*(.-)%s*$")
      if trimmed and #trimmed > 0 then
        table.insert(options, trimmed)
      end
    end

    if #options == 0 then return "" end

    -- Get current index for this sequence
    local idx = self.text_alternatives_state[key] or 1
    local selected = options[idx]

    -- Advance for next render (stick at last)
    if idx < #options then
      self.text_alternatives_state[key] = idx + 1
    end

    return selected or ""
  end)

  -- Process cycle alternatives {&| a | b | c }
  result = result:gsub("{&|([^}]+)}", function(options_str)
    alt_index = alt_index + 1
    local key = "cycle_" .. alt_index

    local options = {}
    for opt in options_str:gmatch("[^|]+") do
      local trimmed = opt:match("^%s*(.-)%s*$")
      if trimmed and #trimmed > 0 then
        table.insert(options, trimmed)
      end
    end

    if #options == 0 then return "" end

    local idx = self.text_alternatives_state[key] or 1
    local selected = options[idx]

    -- Cycle to next (wrap around)
    self.text_alternatives_state[key] = (idx % #options) + 1

    return selected or ""
  end)

  -- Process random alternatives {~| a | b | c }
  result = result:gsub("{~|([^}]+)}", function(options_str)
    local options = {}
    for opt in options_str:gmatch("[^|]+") do
      local trimmed = opt:match("^%s*(.-)%s*$")
      if trimmed and #trimmed > 0 then
        table.insert(options, trimmed)
      end
    end

    if #options == 0 then return "" end

    return options[math.random(1, #options)]
  end)

  -- Process once-only alternatives {!| a | b | c }
  result = result:gsub("{!|([^}]+)}", function(options_str)
    alt_index = alt_index + 1
    local key = "once_" .. alt_index

    local options = {}
    for opt in options_str:gmatch("[^|]+") do
      local trimmed = opt:match("^%s*(.-)%s*$")
      if trimmed and #trimmed > 0 then
        table.insert(options, trimmed)
      end
    end

    if #options == 0 then return "" end

    -- Get current index for this once-only sequence
    local idx = self.text_alternatives_state[key] or 1

    -- If exhausted, return empty string
    if idx > #options then
      return ""
    end

    local selected = options[idx]

    -- Advance for next render (continue past end to exhaust)
    self.text_alternatives_state[key] = idx + 1

    return selected or ""
  end)

  return result
end

--- Process inline conditionals: {condition: true_text | false_text}
-- @param content string - Content with inline conditionals
-- @param state table - Game state for variable access
-- @return string processed - Content with inline conditionals evaluated
function Engine:process_inline_conditionals(content, state)
  local result = content

  -- Pattern: {condition: true_text | false_text}
  -- The condition can be $var or an expression
  result = result:gsub("{([^:}]+):%s*([^|]+)%s*|%s*([^}]+)}", function(condition, true_text, false_text)
    local cond_result = self:evaluate_condition(condition, state)
    if cond_result then
      return true_text:match("^%s*(.-)%s*$")  -- Trim whitespace
    else
      return false_text:match("^%s*(.-)%s*$")
    end
  end)

  return result
end

--- Process conditional blocks in content
-- Uses stack-based matching to properly handle nested conditionals
-- @param content string - Raw content with conditionals
-- @param state table - Game state for variable access
-- @return string processed - Content with conditionals evaluated
function Engine:process_conditionals(content, state)
  local result = content

  -- Process { condition }...{elif}...{else}...{/} blocks
  local changed = true
  local iterations = 0
  local max_iterations = 100

  while changed and iterations < max_iterations do
    changed = false
    iterations = iterations + 1

    -- Find and process the innermost conditional block using stack-based matching
    local new_result = self:process_innermost_conditional(result, state)

    if new_result ~= result then
      result = new_result
      changed = true
    end
  end

  return result
end

--- Find and process the innermost conditional block
-- Uses stack-based matching to properly handle nested conditionals
-- @param content string - Content with conditionals
-- @param state table - Game state for variable access
-- @return string processed - Content with one conditional evaluated
function Engine:process_innermost_conditional(content, state)
  local pos = 1
  local stack = {}  -- Stack of {start_pos, condition, body_start}

  while pos <= #content do
    -- Look for next { character
    local brace_pos = content:find("{", pos, true)
    if not brace_pos then
      break
    end

    -- Check what follows the brace
    local after_brace = content:sub(brace_pos + 1)

    -- Skip ${...} (variable interpolation) - check if preceded by $
    if brace_pos > 1 and content:sub(brace_pos - 1, brace_pos - 1) == "$" then
      local close_pos = content:find("}", brace_pos + 1, true)
      if close_pos then
        pos = close_pos + 1
      else
        pos = brace_pos + 1
      end
    -- Skip empty braces {}
    elseif after_brace:match("^%s*}") then
      pos = brace_pos + 2
    -- Skip text alternatives {|, {&|, {~|, {!|
    elseif after_brace:match("^|") or after_brace:match("^&|") or after_brace:match("^~|") or after_brace:match("^!|") then
      local close_pos = content:find("}", brace_pos + 1, true)
      if close_pos then
        pos = close_pos + 1
      else
        pos = brace_pos + 1
      end
    -- Check for closing tag {/}
    elseif after_brace:match("^%s*/%s*}") then
      local close_end = content:find("}", brace_pos + 1, true)
      if close_end and #stack > 0 then
        -- Pop from stack and process this block
        local block = table.remove(stack)
        local body = content:sub(block.body_start, brace_pos - 1)

        -- Process this conditional block
        local replacement = self:evaluate_conditional_block(block.condition, body, state)

        -- Replace in content
        local before = content:sub(1, block.start_pos - 1)
        local after = content:sub(close_end + 1)
        return before .. replacement .. after
      end
      pos = (close_end or brace_pos) + 1
    -- Skip {else} tag (handled in evaluate_conditional_block)
    elseif after_brace:match("^%s*else%s*}") then
      local close_pos = content:find("}", brace_pos + 1, true)
      pos = (close_pos or brace_pos) + 1
    -- Skip {elif condition} tag (handled in evaluate_conditional_block)
    elseif after_brace:match("^elif%s+") then
      local close_pos = content:find("}", brace_pos + 1, true)
      pos = (close_pos or brace_pos) + 1
    else
      -- Check if this looks like a condition (has a closing } soon)
      local close_pos = content:find("}", brace_pos + 1, true)
      if close_pos then
        local inner = content:sub(brace_pos + 1, close_pos - 1)
        -- Skip if it contains : followed by | (inline conditional like {cond: a | b})
        if inner:match(":.*|") then
          pos = close_pos + 1
        else
          -- This is an opening conditional tag { condition }
          local condition = inner:match("^%s*(.-)%s*$")
          -- Skip empty conditions, {/}, {else}, {elif}
          if condition and #condition > 0
             and not condition:match("^/$")
             and not condition:match("^else$")
             and not condition:match("^elif") then
            table.insert(stack, {
              start_pos = brace_pos,
              condition = condition,
              body_start = close_pos + 1
            })
          end
          pos = close_pos + 1
        end
      else
        pos = brace_pos + 1
      end
    end
  end

  return content
end

--- Evaluate a single conditional block with its body
-- @param condition string - The condition to evaluate
-- @param body string - The body content (may contain {else} and {elif})
-- @param state table - Game state for variable access
-- @return string result - The selected branch content
function Engine:evaluate_conditional_block(condition, body, state)
  -- Parse the body into branches at the TOP LEVEL only (nesting depth 0)
  -- {elif cond} and {else} only count when not inside a nested conditional
  local branches = {}
  local current_content = ""
  local pos = 1
  local depth = 0

  while pos <= #body do
    local brace_pos = body:find("{", pos, true)
    if not brace_pos then
      -- No more braces, add rest to current content
      current_content = current_content .. body:sub(pos)
      break
    end

    -- Add content up to this brace
    current_content = current_content .. body:sub(pos, brace_pos - 1)

    local after_brace = body:sub(brace_pos + 1)
    local close_pos = body:find("}", brace_pos + 1, true)

    if not close_pos then
      -- No closing brace, add rest and break
      current_content = current_content .. body:sub(brace_pos)
      break
    end

    local inner = body:sub(brace_pos + 1, close_pos - 1)

    -- Check for {/} - closing tag
    if inner:match("^%s*/%s*$") then
      if depth > 0 then
        depth = depth - 1
        current_content = current_content .. body:sub(brace_pos, close_pos)
      else
        -- Unexpected {/} at depth 0, include it
        current_content = current_content .. body:sub(brace_pos, close_pos)
      end
      pos = close_pos + 1
    -- Check for {else} at depth 0
    elseif inner:match("^%s*else%s*$") and depth == 0 then
      -- Save current branch
      if #branches == 0 then
        table.insert(branches, {condition = condition, content = current_content})
      else
        branches[#branches].content = current_content
      end
      -- Start else branch (nil condition means else)
      table.insert(branches, {condition = nil, content = ""})
      current_content = ""
      pos = close_pos + 1
    -- Check for {elif condition} at depth 0
    elseif inner:match("^%s*elif%s+") and depth == 0 then
      local elif_cond = inner:match("^%s*elif%s+(.-)%s*$")
      -- Save current branch
      if #branches == 0 then
        table.insert(branches, {condition = condition, content = current_content})
      else
        branches[#branches].content = current_content
      end
      -- Start elif branch
      table.insert(branches, {condition = elif_cond, content = ""})
      current_content = ""
      pos = close_pos + 1
    -- Check for opening conditional (increases depth)
    elseif not inner:match("^|") and not inner:match("^&|") and not inner:match("^~|") and not inner:match("^!|")
           and not inner:match(":.*|") and not inner:match("^%s*$") then
      -- This is a nested opening conditional
      depth = depth + 1
      current_content = current_content .. body:sub(brace_pos, close_pos)
      pos = close_pos + 1
    else
      -- Some other brace construct, include it
      current_content = current_content .. body:sub(brace_pos, close_pos)
      pos = close_pos + 1
    end
  end

  -- Save final branch content
  if #branches == 0 then
    table.insert(branches, {condition = condition, content = current_content})
  else
    branches[#branches].content = current_content
  end

  -- Evaluate branches in order
  for _, branch in ipairs(branches) do
    if branch.condition == nil then
      -- This is the else branch - return it
      return branch.content
    end

    local cond_result = self:evaluate_condition(branch.condition, state)
    if cond_result then
      return branch.content
    end
  end

  -- No branch matched and no else clause
  return ""
end

--- Evaluate a condition expression
-- @param condition string - Condition expression
-- @param state table - Game state for variable access
-- @return boolean result - True if condition is met
function Engine:evaluate_condition(condition, state)
  -- Handle $variable syntax
  local lua_expr = condition

  -- Replace $var with state lookup
  lua_expr = lua_expr:gsub("%$([%w_]+)", function(var_name)
    local val = nil
    if state and type(state.get) == "function" then
      val = state:get(var_name)
    elseif state then
      val = state[var_name]
    end

    if val == nil then
      return "nil"
    elseif type(val) == "string" then
      return string.format("%q", val)
    elseif type(val) == "boolean" then
      return tostring(val)
    else
      return tostring(val)
    end
  end)

  -- Create environment with whisker.state
  local env = {
    whisker = {
      state = {
        get = function(key)
          if state and type(state.get) == "function" then
            return state:get(key)
          elseif state then
            return state[key]
          end
          return nil
        end
      }
    }
  }

  -- Add standard Lua functions
  env.string = string
  env.math = math
  env.tonumber = tonumber
  env.tostring = tostring
  env.type = type

  -- Add metatable for direct variable access (bare names like "gold >= 100")
  setmetatable(env, {
    __index = function(_, key)
      -- Look up variable from game state
      if state and type(state.get) == "function" then
        local val = state:get(key)
        if val ~= nil then return val end
      elseif state and state[key] ~= nil then
        return state[key]
      end
      -- Fall back to global environment for standard functions
      return _G[key]
    end
  })

  -- Evaluate expression (use helper for Lua 5.1/LuaJIT compatibility)
  local func, err = load_with_env("return " .. lua_expr, "condition", env)
  if not func then
    return false
  end

  local success, result = pcall(func)
  if not success then
    return false
  end

  return result and true or false
end

--- Interpolate variables in content
-- @param content string - Content with variable references
-- @param state table - Game state for variable access
-- @return string interpolated - Content with variables replaced
function Engine:interpolate_variables(content, state)
  local result = content

  -- Replace ${expr} expressions
  result = result:gsub("%${([^}]+)}", function(expr)
    local env = {
      whisker = {
        state = {
          get = function(key)
            if state and type(state.get) == "function" then
              return state:get(key)
            elseif state then
              return state[key]
            end
            return nil
          end
        }
      }
    }
    env.string = string
    env.math = math
    env.tonumber = tonumber
    env.tostring = tostring

    -- Add random and pick functions
    env.random = function(a, b)
      if b then
        return math.random(a, b)
      else
        return math.random(1, a)
      end
    end

    env.pick = function(...)
      local args = {...}
      if #args == 0 then return nil end
      return args[math.random(1, #args)]
    end

    local func, load_err = load_with_env("return " .. expr, "interpolate", env)
    if func then
      local success, eval_result = pcall(func)
      if success and eval_result ~= nil then
        return tostring(eval_result)
      end
    end
    return ""
  end)

  -- Replace $var references (keep undefined variables as-is)
  result = result:gsub("%$([%w_]+)", function(var_name)
    local val = nil
    if state and type(state.get) == "function" then
      val = state:get(var_name)
    elseif state then
      val = state[var_name]
    end
    if val ~= nil then
      return tostring(val)
    end
    -- Keep undefined variable as-is
    return "$" .. var_name
  end)

  -- Replace legacy {{expr}} expressions (double curly braces)
  result = result:gsub("{{([^}]+)}}", function(expr)
    local env = {
      whisker = {
        state = {
          get = function(key)
            if state and type(state.get) == "function" then
              return state:get(key)
            elseif state then
              return state[key]
            end
            return nil
          end
        }
      }
    }
    env.string = string
    env.math = math
    env.tonumber = tonumber
    env.tostring = tostring

    local func, load_err = load_with_env("return " .. expr, "interpolate_legacy", env)
    if func then
      local success, eval_result = pcall(func)
      if success and eval_result ~= nil then
        return tostring(eval_result)
      end
    end
    return "{{" .. expr .. "}}"
  end)

  return result
end

--- Deserialize engine state for loading
-- @param data table - State data to restore
-- @return string|nil rendered - Rendered content if navigation occurred
-- @return string|nil error - Error message if failed
function Engine:deserialize_state(data)
  self.state = data.state or {}
  self.history = data.history or {}

  -- WLS 1.0 GAP-013: Restore game_state which contains tunnel stack
  if data.game_state and self.game_state then
    self.game_state:deserialize(data.game_state)
  end

  -- Restore current passage directly (without re-registering hooks)
  if data.current_passage and self.story then
    local passage = self.story:get_passage(data.current_passage)
    if passage then
      self.current_passage = passage
      if self.game_state then
        self.game_state:set_current_passage(data.current_passage)
      end
    end
  end

  -- Restore hooks AFTER setting current_passage (don't navigate, which would clear hooks)
  if data.hooks then
    self.hook_manager:deserialize(data.hooks)
  end
end

return Engine
