-- src/core/engine.lua
-- Story engine with navigation (75% complete - missing visual/audio)

local Engine = {}
Engine.__index = Engine

-- Dependencies for DI pattern
Engine._dependencies = {"story_factory", "game_state_factory", "lua_interpreter_factory", "event_bus", "control_flow_factory", "modules_runtime_factory"}

-- Cached factories for backward compatibility (lazy loaded)
local _story_factory_cache = nil
local _game_state_factory_cache = nil
local _interpreter_factory_cache = nil
local _control_flow_cache = nil
local _modules_runtime_cache = nil

--- Get the story factory (supports both DI and backward compatibility)
local function get_story_factory(deps)
  if deps and deps.story_factory then
    return deps.story_factory
  end
  if not _story_factory_cache then
    local StoryFactory = require("whisker.core.factories.story_factory")
    _story_factory_cache = StoryFactory.new()
  end
  return _story_factory_cache
end

--- Get the game state factory
local function get_game_state_factory(deps)
  if deps and deps.game_state_factory then
    return deps.game_state_factory
  end
  if not _game_state_factory_cache then
    local GameStateFactory = require("whisker.core.factories.game_state_factory")
    _game_state_factory_cache = GameStateFactory.new()
  end
  return _game_state_factory_cache
end

--- Get the lua interpreter factory
local function get_interpreter_factory(deps)
  if deps and deps.lua_interpreter_factory then
    return deps.lua_interpreter_factory
  end
  if not _interpreter_factory_cache then
    local InterpreterFactory = require("whisker.core.factories.lua_interpreter_factory")
    _interpreter_factory_cache = InterpreterFactory.new()
  end
  return _interpreter_factory_cache
end

--- Get the control flow factory (lazy loaded for backward compatibility)
local function get_control_flow_factory(deps)
  if deps and deps.control_flow_factory then
    return deps.control_flow_factory
  end
  if not _control_flow_cache then
    local ControlFlowFactory = require("whisker.core.factories.control_flow_factory")
    _control_flow_cache = ControlFlowFactory.new()
  end
  return _control_flow_cache
end

--- Get or create the modules runtime
-- @param game_state table The game state instance
-- @return ModulesRuntime
local function get_modules_runtime(game_state)
  if not _modules_runtime_cache then
    local ModulesRuntime = require("whisker.core.modules_runtime")
    _modules_runtime_cache = ModulesRuntime.new(game_state)
  end
  return _modules_runtime_cache
end

--- Create a new Engine instance via DI container
-- @param deps table Dependencies from container
-- @return function Factory function that creates Engine instances
function Engine.create(deps)
  local story_factory = get_story_factory(deps)
  local game_state_factory = get_game_state_factory(deps)
  local interpreter_factory = get_interpreter_factory(deps)
  local event_bus = deps and deps.event_bus or nil
  -- Return a factory function
  return function(story, game_state, config)
    return Engine.new(story, game_state, config, {
      story_factory = story_factory,
      game_state_factory = game_state_factory,
      lua_interpreter_factory = interpreter_factory,
      event_bus = event_bus
    })
  end
end

function Engine.new(story, game_state, config, deps)
    deps = deps or {}

    local instance = {
        config = config or {},
        current_story = nil,
        game_state = game_state,
        interpreter = nil,
        current_content = nil,
        is_running = false,
        performance_stats = {
            story_start_time = nil,
            passages_visited = 0,
            choices_made = 0
        },
        -- WLS 1.0: Tunnel call stack for -> Target -> syntax
        tunnel_stack = {},
        -- WLS 1.0: Modules runtime for FUNCTION/NAMESPACE
        modules_runtime = nil,
        -- Store factories for DI
        _story_factory = deps.story_factory,
        _game_state_factory = deps.game_state_factory,
        _interpreter_factory = deps.lua_interpreter_factory,
        _event_bus = deps.event_bus
    }

    setmetatable(instance, Engine)

    -- Get factories (use injected or fallback)
    local story_factory = get_story_factory(deps)
    local game_state_factory = get_game_state_factory(deps)
    local interpreter_factory = get_interpreter_factory(deps)

    -- Ensure story has proper metatable (handles deserialized stories)
    if story and type(story) == "table" then
        local Story = require("whisker.core.story")
        -- Check if story has Story metatable
        if getmetatable(story) ~= Story then
            -- Restore metatable if missing using factory
            instance.current_story = story_factory:restore_metatable(story)
        else
            instance.current_story = story
        end
    else
        instance.current_story = story
    end

    -- Initialize game state if not provided
    if not instance.game_state then
        instance.game_state = game_state_factory:create()
    end

    -- Initialize interpreter
    if not instance.interpreter then
        instance.interpreter = interpreter_factory:create()
    end

    -- Initialize modules runtime
    instance.modules_runtime = get_modules_runtime(instance.game_state)

    return instance
end

function Engine:load_story(story)
    -- Get factories
    local story_factory = self._story_factory or get_story_factory()
    local game_state_factory = self._game_state_factory or get_game_state_factory()
    local interpreter_factory = self._interpreter_factory or get_interpreter_factory()

    -- Ensure story has proper metatable (handles deserialized stories)
    if story and type(story) == "table" then
        local Story = require("whisker.core.story")
        -- Check if story has Story metatable
        if getmetatable(story) ~= Story then
            -- Restore metatable if missing using factory
            self.current_story = story_factory:restore_metatable(story)
        else
            self.current_story = story
        end
    else
        self.current_story = story
    end

    -- Initialize game state if not provided
    if not self.game_state then
        self.game_state = game_state_factory:create()
    end

    -- Initialize interpreter if not provided
    if not self.interpreter then
        self.interpreter = interpreter_factory:create()
    end

    -- Initialize modules runtime if not set
    if not self.modules_runtime then
        self.modules_runtime = get_modules_runtime(self.game_state)
    end

    return true
end

function Engine:start_story(starting_passage_id)
    if not self.current_story then
        error("No story loaded")
    end

    -- Initialize game state
    self.game_state:initialize(self.current_story)

    -- Load functions from story into modules runtime
    if self.modules_runtime and self.current_story.functions then
        self.modules_runtime:load_from_story(self.current_story)
    end

    -- Determine starting passage
    local start_passage
    if starting_passage_id then
        start_passage = starting_passage_id
    elseif self.current_story and self.current_story.get_start_passage then
        start_passage = self.current_story:get_start_passage()
    else
        -- Fallback: try to get from start_passage field directly
        start_passage = self.current_story.start_passage
    end

    if not start_passage then
        error("No starting passage found")
    end

    -- Track start time
    self.performance_stats.story_start_time = os.time()
    self.is_running = true

    -- Navigate to first passage
    return self:navigate_to_passage(start_passage)
end

function Engine:navigate_to_passage(passage_id)
    if not self.is_running then
        error("Story is not running")
    end

    -- Get passage
    local passage = self.current_story:get_passage(passage_id)
    if not passage then
        error("Passage not found: " .. tostring(passage_id))
    end

    -- Execute passage entry hook
    if passage.on_enter_script then
        self:execute_passage_code(passage.on_enter_script, "on_enter")
    end

    -- Update game state
    self.game_state:set_current_passage(passage_id)
    self.performance_stats.passages_visited = self.performance_stats.passages_visited + 1

    -- Render passage content
    local rendered_content = self:render_passage_content(passage)

    -- Get available choices
    local available_choices = self:get_available_choices(passage)

    -- Store current content
    self.current_content = {
        passage_id = passage_id,
        passage = passage,
        content = rendered_content,
        choices = available_choices,
        can_undo = self.game_state:can_undo(),
        metadata = {
            visit_count = self.game_state:get_visit_count(passage_id),
            is_first_visit = self.game_state:get_visit_count(passage_id) == 1
        }
    }

    return self.current_content
end

-- WLS 1.0 Special Targets
local SPECIAL_TARGETS = {
    END = "END",
    BACK = "BACK",
    RESTART = "RESTART"
}

function Engine:make_choice(choice_index)
    if not self.current_content or not self.current_content.choices then
        error("No choices available")
    end

    local choices = self.current_content.choices
    if choice_index < 1 or choice_index > #choices then
        error("Invalid choice index: " .. tostring(choice_index))
    end

    local choice = choices[choice_index]

    -- Execute choice action if present
    if choice:has_action() then
        self:execute_passage_code(choice:get_action(), "choice_action")
    end

    -- WLS 1.0: Mark once-only choices as selected
    if choice:is_once_only() then
        self.game_state:mark_choice_selected(choice.id)
    end

    -- Track choice made
    self.performance_stats.choices_made = self.performance_stats.choices_made + 1

    -- WLS 1.0: Handle special targets
    local target = choice:get_target()

    if target == SPECIAL_TARGETS.END then
        -- End the story
        self.story_ended = true
        return {
            text = "",
            choices = {},
            ended = true
        }
    elseif target == SPECIAL_TARGETS.BACK then
        -- Go back in history
        if self.game_state:can_undo() then
            self.game_state:undo()
            local passage_id = self.game_state:get_current_passage()
            if passage_id then
                return self:navigate_to_passage(passage_id)
            end
        end
        -- If can't go back, stay on current passage
        return self.current_content
    elseif target == SPECIAL_TARGETS.RESTART then
        -- Restart the story
        self.game_state:reset()
        return self:start_story()
    else
        -- Normal navigation
        return self:navigate_to_passage(target)
    end
end

-- ============================================================================
-- WLS 1.0: Tunnel Support
-- ============================================================================

--- Call a tunnel (push return location and navigate to target)
--- @param target_passage_id string The tunnel target passage
--- @param return_position number Position in content to resume from (optional)
--- @return table The rendered content from the tunnel passage
function Engine:call_tunnel(target_passage_id, return_position)
    if not self.is_running then
        error("Story is not running")
    end

    -- Save current passage and local variables
    local current_passage_id = self.game_state:get_current_passage()

    -- Collect local/temporary variables (those starting with _)
    local local_vars = {}
    local all_vars = self.game_state:get_all_variables()
    for name, value in pairs(all_vars) do
        if name:sub(1, 1) == "_" then
            local_vars[name] = value
        end
    end

    -- Push return frame to stack
    table.insert(self.tunnel_stack, {
        return_passage_id = current_passage_id,
        return_position = return_position or 0,
        local_variables = local_vars
    })

    -- Navigate to tunnel target
    return self:navigate_to_passage(target_passage_id)
end

--- Return from a tunnel (pop stack and navigate back)
--- @return table|nil The rendered content from the return passage, or nil if not in tunnel
function Engine:return_from_tunnel()
    if #self.tunnel_stack == 0 then
        -- Not in a tunnel - this is an error (WLS-FLW-011: orphan_tunnel_return)
        return nil
    end

    -- Pop the return frame
    local frame = table.remove(self.tunnel_stack)

    -- Restore local variables
    for name, value in pairs(frame.local_variables) do
        self.game_state:set(name, value)
    end

    -- Navigate back to the return passage
    return self:navigate_to_passage(frame.return_passage_id)
end

--- Check if currently in a tunnel
--- @return boolean True if in a tunnel
function Engine:is_in_tunnel()
    return #self.tunnel_stack > 0
end

--- Get current tunnel depth
--- @return number The depth of nested tunnel calls
function Engine:get_tunnel_depth()
    return #self.tunnel_stack
end

--- Get the tunnel stack (for save/restore)
--- @return table The tunnel stack
function Engine:get_tunnel_stack()
    return self.tunnel_stack
end

--- Restore tunnel stack (for save/restore)
--- @param stack table The tunnel stack to restore
function Engine:set_tunnel_stack(stack)
    self.tunnel_stack = stack or {}
end

function Engine:render_passage_content(passage)
    local content = passage:get_content()
    local control_flow_factory = get_control_flow_factory(self._control_flow_factory)

    -- Build WLS 1.0 context for expression evaluation
    local context = {
        story = self.current_story,
        engine = self,
        passage_id = passage.id or passage.name or "unknown"
    }

    -- 1. Process escaped characters first (protect them)
    local escapes = {}
    local escape_count = 0
    content = content:gsub("\\([%$%{%}|:])", function(char)
        escape_count = escape_count + 1
        local placeholder = "\0ESC" .. escape_count .. "\0"
        escapes[placeholder] = char
        return placeholder
    end)

    -- 2. WLS 1.0: Control flow (conditionals and alternatives)
    local control_flow = control_flow_factory:create(self.interpreter, self.game_state, context)
    content = control_flow:process(content)

    -- 3. WLS 1.0: ${expression} - full expression interpolation
    content = content:gsub("%${([^}]+)}", function(expr)
        expr = expr:match("^%s*(.-)%s*$") -- Trim whitespace

        local success, result = self.interpreter:evaluate_expression(expr, self.game_state, context)
        if success then
            return tostring(result)
        else
            return "${ERROR: " .. tostring(result) .. "}"
        end
    end)

    -- 4. WLS 1.0: $varName - simple variable interpolation
    content = content:gsub("%$([%a_][%w_]*)", function(var_name)
        local value = self.game_state:get(var_name)
        if value ~= nil then
            return tostring(value)
        else
            return "$" .. var_name -- Keep as-is if undefined
        end
    end)

    -- 5. Legacy: {{expression}} - deprecated but still supported
    content = content:gsub("{{%s*([^#/%s].-)}}", function(code)
        -- Skip template keywords
        if code:match("^%s*else%s*$") or code:match("^%s*each%s") then
            return "{{" .. code .. "}}"
        end

        local success, result = self.interpreter:evaluate_expression(code, self.game_state, context)
        if success then
            return tostring(result)
        else
            return "{{ERROR: " .. tostring(result) .. "}}"
        end
    end)

    -- 6. Restore escaped characters
    for placeholder, char in pairs(escapes) do
        content = content:gsub(placeholder, char)
    end

    return content
end

function Engine:get_available_choices(passage)
    local available = {}

    -- Build WLS 1.0 context for condition evaluation
    local context = {
        story = self.current_story,
        engine = self
    }

    for _, choice in ipairs(passage:get_choices()) do
        local is_available = true

        -- WLS 1.0: Skip once-only choices that have already been selected
        if choice:is_once_only() and self.game_state:is_choice_selected(choice.id) then
            is_available = false
        end

        -- Check if choice condition is met
        if is_available and choice:has_condition() then
            local success, result = self.interpreter:evaluate_condition(
                choice:get_condition(),
                self.game_state,
                context
            )

            if success then
                is_available = result
            else
                -- If condition evaluation fails, hide the choice
                is_available = false
            end
        end

        if is_available then
            table.insert(available, choice)
        end
    end

    return available
end

function Engine:execute_passage_code(code, context_name)
    if not code or code == "" then
        return true, nil
    end

    -- Build WLS 1.0 context with engine reference
    local context = {
        story = self.current_story,
        engine = self,
        _pending_navigation = nil,
        _pending_back = nil,
        _pending_choice = nil
    }

    local success, result, details = self.interpreter:execute_code(code, self.game_state, context)

    if not success then
        -- Log error but don't crash
        print("Error in " .. context_name .. ": " .. tostring(result))
        return false, result
    end

    -- Handle deferred navigation from whisker.passage.go()
    if context._pending_navigation then
        -- Store for caller to handle after script execution
        self._pending_navigation = context._pending_navigation
    end

    -- Handle deferred back from whisker.history.back()
    if context._pending_back then
        self._pending_back = context._pending_back
    end

    -- Handle deferred choice from whisker.choice.select()
    if context._pending_choice then
        self._pending_choice = context._pending_choice
    end

    return true, result
end

function Engine:undo()
    if not self.game_state:can_undo() then
        return false, "No undo available"
    end

    local snapshot = self.game_state:undo()

    if snapshot and snapshot.current_passage then
        return self:navigate_to_passage(snapshot.current_passage)
    end

    return false, "Undo failed"
end

function Engine:restart()
    if not self.current_story then
        return false, "No story loaded"
    end

    self.game_state:reset()
    return self:start_story()
end

function Engine:get_current_content()
    return self.current_content
end

function Engine:get_game_state()
    return self.game_state
end

function Engine:get_all_variables()
    return self.game_state:get_all_variables()
end

function Engine:get_performance_stats()
    return self.performance_stats
end

function Engine:is_story_running()
    return self.is_running
end

function Engine:stop_story()
    self.is_running = false
    self.current_content = nil
end

-- ============================================================================
-- WLS 1.0: Module Functions Support
-- ============================================================================

--- Get the modules runtime
--- @return ModulesRuntime
function Engine:get_modules_runtime()
    return self.modules_runtime
end

--- Call a defined function
--- @param name string The function name (may be namespace-qualified)
--- @param args table Array of argument values
--- @return any The function result
function Engine:call_function(name, args)
    if not self.modules_runtime then
        error("Modules runtime not initialized")
    end
    return self.modules_runtime:call_function(name, args)
end

--- Check if a function exists
--- @param name string The function name
--- @return boolean
function Engine:has_function(name)
    if not self.modules_runtime then
        return false
    end
    return self.modules_runtime:has_function(name)
end

--- Define a function dynamically
--- @param name string The function name
--- @param params table Array of parameter names
--- @param body string The function body
--- @return string The qualified function name
function Engine:define_function(name, params, body)
    if not self.modules_runtime then
        error("Modules runtime not initialized")
    end
    return self.modules_runtime:define_function(name, params, body)
end

--- Enter a namespace scope
--- @param name string The namespace name
function Engine:enter_namespace(name)
    if not self.modules_runtime then
        error("Modules runtime not initialized")
    end
    self.modules_runtime:enter_namespace(name)
end

--- Exit the current namespace scope
--- @return string|nil The exited namespace name
function Engine:exit_namespace()
    if not self.modules_runtime then
        return nil
    end
    return self.modules_runtime:exit_namespace()
end

--- Get current namespace
--- @return string The current namespace path
function Engine:current_namespace()
    if not self.modules_runtime then
        return ""
    end
    return self.modules_runtime:current_namespace()
end

return Engine
