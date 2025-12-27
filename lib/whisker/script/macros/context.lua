-- Whisker Macro Context
-- Execution context for macro handlers
-- Provides access to variables, state, output, and hooks
--
-- lib/whisker/script/macros/context.lua

local MacroContext = {}
MacroContext.__index = MacroContext

-- Dependencies for DI pattern
MacroContext._dependencies = { "event_bus", "game_state" }

-- Context flags
MacroContext.FLAG = {
    RENDERING = "rendering",      -- Currently rendering content
    EXECUTING = "executing",      -- Currently executing script
    EVALUATING = "evaluating",    -- Evaluating expression
    TRANSITIONING = "transitioning", -- Passage transition in progress
}

--- Create a new MacroContext via DI container
-- @param deps table Dependencies from container
-- @return MacroContext instance
function MacroContext.create(deps)
    return MacroContext.new(deps)
end

--- Create a new MacroContext
-- @param deps table Optional dependencies
-- @return MacroContext instance
function MacroContext.new(deps)
    deps = deps or {}
    local self = setmetatable({}, MacroContext)

    self._event_bus = deps.event_bus
    self._game_state = deps.game_state
    self._story = deps.story
    self._registry = deps.registry
    self._interpreter = deps.interpreter

    -- Execution state
    self._variables = {}
    self._temp_variables = {}
    self._output = {}
    self._hooks = {}
    self._flags = {}
    self._stack = {}      -- Macro call stack
    self._depth = 0       -- Nesting depth

    -- Current execution context
    self._current_passage = nil
    self._current_macro = nil
    self._current_args = nil

    -- Configuration
    self._config = {
        max_depth = 100,           -- Maximum macro nesting
        max_output_size = 1000000, -- Maximum output buffer size
        strict_mode = false,       -- Error on undefined variables
        trace_enabled = false,     -- Enable execution tracing
    }

    -- Trace log
    self._trace = {}

    return self
end

-- ============================================================================
-- Lifecycle Methods
-- ============================================================================

--- Push a new execution frame onto the stack
-- @param macro_name string The macro being executed
-- @param args table The arguments
-- @return boolean, string Success or error if max depth exceeded
function MacroContext:push(macro_name, args)
    self._depth = self._depth + 1

    if self._depth > self._config.max_depth then
        self._depth = self._depth - 1
        return false, "Maximum macro nesting depth exceeded"
    end

    table.insert(self._stack, {
        macro = macro_name,
        args = args,
        temp_vars = {},
        output_start = #self._output,
        started_at = os.time(),
    })

    self._current_macro = macro_name
    self._current_args = args

    if self._config.trace_enabled then
        table.insert(self._trace, {
            type = "push",
            macro = macro_name,
            depth = self._depth,
            time = os.time(),
        })
    end

    self:_emit_event("MACRO_STARTED", {
        name = macro_name,
        depth = self._depth,
    })

    return true, nil
end

--- Pop the current execution frame
-- @return table|nil The popped frame
function MacroContext:pop()
    if self._depth == 0 then
        return nil
    end

    local frame = table.remove(self._stack)
    self._depth = self._depth - 1

    -- Clean up temp variables from this frame
    for name in pairs(frame.temp_vars) do
        self._temp_variables[name] = nil
    end

    -- Update current context
    if self._depth > 0 then
        local parent = self._stack[self._depth]
        self._current_macro = parent.macro
        self._current_args = parent.args
    else
        self._current_macro = nil
        self._current_args = nil
    end

    if self._config.trace_enabled then
        table.insert(self._trace, {
            type = "pop",
            macro = frame.macro,
            depth = self._depth + 1,
            time = os.time(),
        })
    end

    self:_emit_event("MACRO_COMPLETED", {
        name = frame.macro,
        depth = self._depth + 1,
    })

    return frame
end

--- Get current execution depth
-- @return number
function MacroContext:get_depth()
    return self._depth
end

--- Get current call stack
-- @return table Array of frame info
function MacroContext:get_stack()
    local result = {}
    for i, frame in ipairs(self._stack) do
        table.insert(result, {
            level = i,
            macro = frame.macro,
            started_at = frame.started_at,
        })
    end
    return result
end

-- ============================================================================
-- Variable Access
-- ============================================================================

--- Get a variable value
-- @param name string The variable name
-- @return any The value (may be nil)
function MacroContext:get(name)
    -- Check temp variables first
    if self._temp_variables[name] ~= nil then
        return self._temp_variables[name]
    end

    -- Check context variables
    if self._variables[name] ~= nil then
        return self._variables[name]
    end

    -- Check game state
    if self._game_state and self._game_state.get then
        return self._game_state:get(name)
    end

    -- Strict mode check
    if self._config.strict_mode then
        self:_emit_event("UNDEFINED_VARIABLE", { name = name })
    end

    return nil
end

--- Set a variable value
-- @param name string The variable name
-- @param value any The value
-- @param options table Optional: temp, scope
function MacroContext:set(name, value, options)
    options = options or {}

    local old_value = self:get(name)

    if options.temp or options.scope == "temp" then
        -- Temporary variable (scoped to current frame)
        self._temp_variables[name] = value
        if self._depth > 0 then
            self._stack[self._depth].temp_vars[name] = true
        end
    elseif self._game_state and self._game_state.set then
        -- Persist to game state
        self._game_state:set(name, value)
    else
        -- Store locally
        self._variables[name] = value
    end

    self:_emit_event("VARIABLE_CHANGED", {
        name = name,
        old_value = old_value,
        new_value = value,
        scope = options.temp and "temp" or "global",
    })
end

--- Delete a variable
-- @param name string The variable name
function MacroContext:delete(name)
    self._temp_variables[name] = nil
    self._variables[name] = nil

    if self._game_state and self._game_state.delete then
        self._game_state:delete(name)
    end
end

--- Check if variable exists
-- @param name string The variable name
-- @return boolean
function MacroContext:has(name)
    if self._temp_variables[name] ~= nil then
        return true
    end
    if self._variables[name] ~= nil then
        return true
    end
    if self._game_state and self._game_state.has then
        return self._game_state:has(name)
    end
    return false
end

--- Get all variable names
-- @return table Array of names
function MacroContext:get_variable_names()
    local names = {}
    local seen = {}

    -- Temp variables
    for name in pairs(self._temp_variables) do
        if not seen[name] then
            table.insert(names, name)
            seen[name] = true
        end
    end

    -- Context variables
    for name in pairs(self._variables) do
        if not seen[name] then
            table.insert(names, name)
            seen[name] = true
        end
    end

    -- Game state variables
    if self._game_state and self._game_state.get_variable_names then
        for _, name in ipairs(self._game_state:get_variable_names()) do
            if not seen[name] then
                table.insert(names, name)
                seen[name] = true
            end
        end
    end

    table.sort(names)
    return names
end

-- ============================================================================
-- Output Management
-- ============================================================================

--- Write content to output buffer
-- @param content string|table The content to write
function MacroContext:write(content)
    if content == nil then
        return
    end

    if type(content) == "table" then
        -- Handle structured output
        table.insert(self._output, content)
    else
        -- Handle string content
        table.insert(self._output, tostring(content))
    end

    -- Check output size limit
    local total_size = 0
    for _, item in ipairs(self._output) do
        if type(item) == "string" then
            total_size = total_size + #item
        end
    end

    if total_size > self._config.max_output_size then
        self:_emit_event("OUTPUT_OVERFLOW", {
            size = total_size,
            limit = self._config.max_output_size,
        })
    end
end

--- Write a line to output (with newline)
-- @param content string The content
function MacroContext:writeln(content)
    self:write(content)
    self:write("\n")
end

--- Get all output as string
-- @return string
function MacroContext:get_output()
    local result = {}
    for _, item in ipairs(self._output) do
        if type(item) == "string" then
            table.insert(result, item)
        elseif type(item) == "table" and item.render then
            table.insert(result, item:render())
        else
            table.insert(result, tostring(item))
        end
    end
    return table.concat(result)
end

--- Get output as array of items
-- @return table
function MacroContext:get_output_items()
    return self._output
end

--- Clear output buffer
function MacroContext:clear_output()
    self._output = {}
end

--- Get output from current frame only
-- @return table Array of output items
function MacroContext:get_frame_output()
    if self._depth == 0 then
        return self._output
    end

    local frame = self._stack[self._depth]
    local result = {}
    for i = frame.output_start + 1, #self._output do
        table.insert(result, self._output[i])
    end
    return result
end

-- ============================================================================
-- Passage and Story Access
-- ============================================================================

--- Set current passage
-- @param passage table|string Passage object or name
function MacroContext:set_passage(passage)
    self._current_passage = passage
end

--- Get current passage
-- @return table|nil
function MacroContext:get_passage()
    return self._current_passage
end

--- Get passage by name
-- @param name string The passage name
-- @return table|nil
function MacroContext:get_passage_by_name(name)
    if self._story and self._story.get_passage then
        return self._story:get_passage(name)
    end
    return nil
end

--- Navigate to a passage
-- @param target string The target passage name
-- @param options table Optional navigation options
function MacroContext:goto_passage(target, options)
    options = options or {}

    self:set_flag(MacroContext.FLAG.TRANSITIONING, true)

    self:_emit_event("PASSAGE_NAVIGATE", {
        from = self._current_passage and self._current_passage.name,
        to = target,
        options = options,
    })
end

--- Get the story object
-- @return table|nil
function MacroContext:get_story()
    return self._story
end

-- ============================================================================
-- Hooks (Named References)
-- ============================================================================

--- Define a hook (named content reference)
-- @param name string The hook name
-- @param content any The content
function MacroContext:define_hook(name, content)
    self._hooks[name] = {
        content = content,
        defined_at = os.time(),
        modified = false,
    }
end

--- Get hook content
-- @param name string The hook name
-- @return any|nil
function MacroContext:get_hook(name)
    local hook = self._hooks[name]
    return hook and hook.content
end

--- Modify hook content
-- @param name string The hook name
-- @param modifier function Function to modify content
function MacroContext:modify_hook(name, modifier)
    local hook = self._hooks[name]
    if hook then
        hook.content = modifier(hook.content)
        hook.modified = true
    end
end

--- Append to hook
-- @param name string The hook name
-- @param content any The content to append
function MacroContext:append_hook(name, content)
    local hook = self._hooks[name]
    if hook then
        if type(hook.content) == "string" then
            hook.content = hook.content .. tostring(content)
        elseif type(hook.content) == "table" then
            table.insert(hook.content, content)
        end
        hook.modified = true
    end
end

--- Replace hook content
-- @param name string The hook name
-- @param content any The new content
function MacroContext:replace_hook(name, content)
    local hook = self._hooks[name]
    if hook then
        hook.content = content
        hook.modified = true
    end
end

--- Clear hook content
-- @param name string The hook name
function MacroContext:clear_hook(name)
    local hook = self._hooks[name]
    if hook then
        hook.content = ""
        hook.modified = true
    end
end

--- Check if hook exists
-- @param name string The hook name
-- @return boolean
function MacroContext:has_hook(name)
    return self._hooks[name] ~= nil
end

--- Get all hook names
-- @return table Array of names
function MacroContext:get_hook_names()
    local names = {}
    for name in pairs(self._hooks) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

-- ============================================================================
-- Flags and State
-- ============================================================================

--- Set a context flag
-- @param flag string The flag name
-- @param value boolean The value (defaults to true)
function MacroContext:set_flag(flag, value)
    if value == nil then
        value = true
    end
    self._flags[flag] = value
end

--- Get a flag value
-- @param flag string The flag name
-- @return boolean
function MacroContext:get_flag(flag)
    return self._flags[flag] == true
end

--- Clear a flag
-- @param flag string The flag name
function MacroContext:clear_flag(flag)
    self._flags[flag] = nil
end

--- Check if currently in a specific state
-- @param flag string The flag to check
-- @return boolean
function MacroContext:is_in(flag)
    return self:get_flag(flag)
end

-- ============================================================================
-- Macro Execution Support
-- ============================================================================

--- Execute another macro from within a macro
-- @param name string The macro name
-- @param args table The arguments
-- @return any, string Result and optional error
function MacroContext:call(name, args)
    if not self._registry then
        return nil, "No macro registry available"
    end
    return self._registry:execute(name, self, args)
end

--- Evaluate an expression
-- @param expr string|table The expression
-- @return any, string Result and optional error
function MacroContext:eval(expr)
    if self._interpreter then
        return self._interpreter:evaluate(expr, self)
    end

    -- Simple evaluation for basic expressions
    if type(expr) == "string" then
        -- Variable reference
        if expr:match("^%$?[%w_]+$") then
            local name = expr:gsub("^%$", "")
            return self:get(name), nil
        end
    end

    return expr, nil
end

--- Create a changer (Harlowe-style content modifier)
-- @param name string The changer type
-- @param fn function The changer function
-- @return table Changer object
function MacroContext:create_changer(name, fn)
    return {
        _is_changer = true,
        name = name,
        apply = fn,
        combine = function(self, other)
            return {
                _is_changer = true,
                name = self.name .. "+" .. other.name,
                apply = function(_, content, ctx)
                    local result = self:apply(content, ctx)
                    return other:apply(result, ctx)
                end,
            }
        end,
    }
end

-- ============================================================================
-- Configuration
-- ============================================================================

--- Configure context
-- @param config table Configuration options
function MacroContext:configure(config)
    for k, v in pairs(config) do
        if self._config[k] ~= nil then
            self._config[k] = v
        end
    end
end

--- Get configuration value
-- @param key string The config key
-- @return any
function MacroContext:get_config(key)
    return self._config[key]
end

--- Enable strict mode
function MacroContext:enable_strict_mode()
    self._config.strict_mode = true
end

--- Enable tracing
function MacroContext:enable_tracing()
    self._config.trace_enabled = true
end

--- Get execution trace
-- @return table
function MacroContext:get_trace()
    return self._trace
end

--- Clear execution trace
function MacroContext:clear_trace()
    self._trace = {}
end

-- ============================================================================
-- Cloning and Reset
-- ============================================================================

--- Create a child context (inherits parent state)
-- @return MacroContext
function MacroContext:child()
    local child = MacroContext.new({
        event_bus = self._event_bus,
        game_state = self._game_state,
        story = self._story,
        registry = self._registry,
        interpreter = self._interpreter,
    })

    -- Inherit configuration
    for k, v in pairs(self._config) do
        child._config[k] = v
    end

    -- Inherit variables (copy reference to same game state)
    -- but local variables get a shallow copy
    for k, v in pairs(self._variables) do
        child._variables[k] = v
    end

    -- Inherit flags
    for k, v in pairs(self._flags) do
        child._flags[k] = v
    end

    return child
end

--- Reset context state
-- @param options table What to reset (variables, output, hooks, flags)
function MacroContext:reset(options)
    options = options or { all = true }

    if options.all or options.variables then
        self._variables = {}
        self._temp_variables = {}
    end

    if options.all or options.output then
        self._output = {}
    end

    if options.all or options.hooks then
        self._hooks = {}
    end

    if options.all or options.flags then
        self._flags = {}
    end

    if options.all or options.stack then
        self._stack = {}
        self._depth = 0
        self._current_macro = nil
        self._current_args = nil
    end

    if options.all or options.trace then
        self._trace = {}
    end
end

-- ============================================================================
-- Internal Helpers
-- ============================================================================

--- Emit an event
-- @param event_type string The event type
-- @param data table Event data
function MacroContext:_emit_event(event_type, data)
    if self._event_bus then
        self._event_bus:emit(event_type, data)
    end
end

return MacroContext
