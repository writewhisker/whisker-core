-- lib/whisker/debug/debugger.lua
-- WLS 1.0.0 GAP-055: Debug Runtime
-- Provides controlled story execution, pause/resume, state inspection

local Breakpoints = require("lib.whisker.debug.breakpoints")
local Stepper = require("lib.whisker.debug.stepper")

local Debugger = {}
Debugger.__index = Debugger

--- Create a new Debugger instance
-- @param options table Options:
--   engine: table - Engine instance (optional, can be set later)
--   game_state: table - GameState instance (optional)
-- @return Debugger instance
function Debugger.new(options)
    options = options or {}
    local self = setmetatable({}, Debugger)

    self.engine = options.engine
    self.game_state = options.game_state
    self.breakpoints = Breakpoints.new()
    self.stepper = Stepper.new(self.engine)

    -- Variable references for DAP scopes
    self.variable_refs = {}
    self.next_ref = 1

    -- Stack frames
    self.stack_frames = {}

    -- Debug configuration
    self.stop_on_entry = false
    self.source_path = nil

    -- Callbacks
    self.on_stopped = nil   -- function(reason, details)
    self.on_output = nil    -- function(category, output)
    self.on_terminated = nil -- function()

    -- Wire up stepper callbacks
    self.stepper:set_on_pause(function(reason, info)
        if self.on_stopped then
            self.on_stopped(reason, info)
        end
    end)

    return self
end

--- Set the engine instance
-- @param engine table Engine instance
function Debugger:set_engine(engine)
    self.engine = engine
    self.stepper.engine = engine
end

--- Set the game state instance
-- @param game_state table GameState instance
function Debugger:set_game_state(game_state)
    self.game_state = game_state
end

--- Load a story file for debugging
-- @param path string Path to story file
-- @return boolean success
-- @return string|nil error message
function Debugger:load_story(path)
    self.source_path = path

    -- Attempt to load the story through the engine
    if self.engine and self.engine.load_story then
        local success, err = self.engine:load_story(path)
        if not success then
            return false, err
        end
    end

    return true
end

--- Start debugging session
-- @param stop_on_entry boolean Whether to stop at the first line
function Debugger:start(stop_on_entry)
    self.stop_on_entry = stop_on_entry or false
    self.stepper:start()

    if self.stop_on_entry then
        self.stepper:pause()
        if self.on_stopped then
            self.on_stopped("entry", { threadId = 1 })
        end
    end
end

--- Run execution until pause
function Debugger:run()
    self.stepper:continue()
    self:run_until_pause()
end

--- Pause execution
function Debugger:pause()
    self.stepper:pause()
    if self.on_stopped then
        self.on_stopped("pause", { threadId = 1 })
    end
end

--- Continue execution
function Debugger:continue()
    self.stepper:continue()
    self:run_until_pause()
end

--- Step to next line (step over)
function Debugger:next()
    self.stepper:step_over()
    self:run_until_pause()
end

--- Step into
function Debugger:step_in()
    self.stepper:step_into()
    self:run_until_pause()
end

--- Step out
function Debugger:step_out()
    self.stepper:step_out()
    self:run_until_pause()
end

--- Step back (reverse)
-- @return boolean success
function Debugger:step_back()
    -- Try using debugger's game_state first (more direct)
    if self.game_state and self.game_state.can_undo then
        if self.game_state:can_undo() then
            self.game_state:undo()
            self.stepper:pause()
            if self.on_stopped then
                self.on_stopped("step_back", { threadId = 1 })
            end
            return true
        end
    end

    -- Fall back to stepper's step_back (uses engine.game_state)
    local success = self.stepper:step_back()
    if success and self.on_stopped then
        self.on_stopped("step_back", { threadId = 1 })
    end
    return success
end

--- Run until a pause condition occurs
function Debugger:run_until_pause()
    while self.stepper:is_running() do
        -- Execute one unit of work
        local more = self:execute_step()
        if not more then
            self.stepper:stop()
            if self.on_terminated then
                self.on_terminated()
            end
            break
        end

        -- Check if we should pause
        if self.stepper:is_paused() then
            break
        end
    end
end

--- Execute a single step of the story
-- @return boolean Whether there is more to execute
function Debugger:execute_step()
    if not self.engine then
        return false
    end

    -- Use engine's step method if available
    if self.engine.step then
        return self.engine:step()
    end

    -- Otherwise, basic execution
    return false
end

--- Set a breakpoint
-- @param file string Source file path
-- @param line number Line number
-- @param condition string|nil Optional condition expression
-- @return table Breakpoint result { verified, line, id }
function Debugger:set_breakpoint(file, line, condition)
    local bp = self.breakpoints:add({
        type = Breakpoints.TYPE_LINE,
        file = file,
        line = line,
        condition = condition
    })

    return {
        verified = bp.verified,
        line = bp.line,
        id = bp.id
    }
end

--- Set a passage breakpoint
-- @param passage_name string Passage name
-- @param condition string|nil Optional condition expression
-- @return table Breakpoint result
function Debugger:set_passage_breakpoint(passage_name, condition)
    local bp = self.breakpoints:add({
        type = Breakpoints.TYPE_PASSAGE,
        passage = passage_name,
        condition = condition
    })

    return {
        verified = bp.verified,
        id = bp.id,
        passage = passage_name
    }
end

--- Remove a breakpoint
-- @param id number Breakpoint ID
-- @return boolean success
function Debugger:remove_breakpoint(id)
    return self.breakpoints:remove(id)
end

--- Clear all breakpoints for a file
-- @param file string File path
function Debugger:clear_file_breakpoints(file)
    self.breakpoints:clear_file(file)
end

--- Check breakpoint at location
-- @param file string File path
-- @param line number Line number
-- @return boolean Whether breakpoint was hit
function Debugger:check_breakpoint(file, line)
    local context = {
        interpreter = self.engine and self.engine.lua_interpreter,
        game_state = self.game_state
    }

    local result = self.breakpoints:check_line(file, line, context)

    if result then
        if result.type == "break" then
            self.stepper:pause()
            if self.on_stopped then
                self.on_stopped("breakpoint", {
                    threadId = 1,
                    breakpointId = result.breakpoint.id
                })
            end
            return true
        elseif result.type == "log" then
            if self.on_output then
                self.on_output("console", result.message)
            end
        end
    end

    return false
end

--- Check passage breakpoint
-- @param passage_name string Passage name
-- @return boolean Whether breakpoint was hit
function Debugger:check_passage_breakpoint(passage_name)
    local context = {
        interpreter = self.engine and self.engine.lua_interpreter,
        game_state = self.game_state
    }

    local result = self.breakpoints:check_passage(passage_name, context)

    if result and result.type == "break" then
        self.stepper:pause()
        if self.on_stopped then
            self.on_stopped("breakpoint", {
                threadId = 1,
                breakpointId = result.breakpoint.id,
                passage = passage_name
            })
        end
        return true
    end

    return false
end

--- Get stack trace
-- @return table Array of stack frames
function Debugger:get_stack_trace()
    local frames = {}

    -- Current passage frame
    local current_passage = nil
    if self.game_state then
        current_passage = self.game_state:get_current_passage()
    elseif self.engine and self.engine.current_passage then
        current_passage = self.engine.current_passage
    end

    if current_passage then
        local passage = nil
        if self.engine and self.engine.story and self.engine.story.get_passage then
            passage = self.engine.story:get_passage(current_passage)
        end

        table.insert(frames, {
            name = current_passage,
            file = passage and passage.source_file or self.source_path or "story.wlk",
            line = passage and passage.location and passage.location.line or 1,
            column = 1
        })
    end

    -- Tunnel stack frames (if available)
    local tunnel_stack = nil
    if self.game_state and self.game_state.tunnel_stack then
        tunnel_stack = self.game_state.tunnel_stack
    elseif self.engine and self.engine.tunnel_stack then
        tunnel_stack = self.engine.tunnel_stack
    end

    if tunnel_stack then
        for i = #tunnel_stack, 1, -1 do
            local entry = tunnel_stack[i]
            table.insert(frames, {
                name = entry.passage_id or "tunnel",
                file = self.source_path or "story.wlk",
                line = entry.position or 1,
                column = 1
            })
        end
    end

    return frames
end

--- Get scopes for a frame
-- @param frame_id number Frame ID (1-based)
-- @return table Array of scopes
function Debugger:get_scopes(frame_id)
    local scopes = {}

    -- Local scope (temp variables)
    local local_ref = self:create_variable_ref("local", frame_id)
    table.insert(scopes, {
        name = "Local",
        variablesReference = local_ref,
        expensive = false
    })

    -- Global/Story scope
    local global_ref = self:create_variable_ref("global", frame_id)
    table.insert(scopes, {
        name = "Story Variables",
        variablesReference = global_ref,
        expensive = false
    })

    -- Collections scope
    local collections_ref = self:create_variable_ref("collections", frame_id)
    table.insert(scopes, {
        name = "Collections",
        variablesReference = collections_ref,
        expensive = false
    })

    return scopes
end

--- Create a variable reference for DAP
-- @param scope_type string Scope type (local, global, collections)
-- @param frame_id number Frame ID
-- @return number Variable reference ID
function Debugger:create_variable_ref(scope_type, frame_id)
    local ref = self.next_ref
    self.next_ref = self.next_ref + 1

    self.variable_refs[ref] = {
        type = scope_type,
        frame_id = frame_id
    }

    return ref
end

--- Get variables for a scope reference
-- @param scope_ref number Variable reference ID
-- @return table Map of variable name -> { value, type, has_children, ref }
function Debugger:get_variables(scope_ref)
    local ref_info = self.variable_refs[scope_ref]
    if not ref_info then
        return {}
    end

    local vars = {}

    if ref_info.type == "local" then
        -- Temporary variables
        if self.game_state and self.game_state.temp_variables then
            for name, value in pairs(self.game_state.temp_variables) do
                vars[name] = self:make_variable_info(value)
            end
        end

    elseif ref_info.type == "global" then
        -- Story variables
        if self.game_state then
            local all_vars = self.game_state:get_all_variables()
            for name, value in pairs(all_vars or {}) do
                vars[name] = self:make_variable_info(value)
            end
        end

    elseif ref_info.type == "collections" then
        -- Lists, arrays, maps
        if self.game_state then
            if self.game_state.lists then
                for name, list in pairs(self.game_state.lists) do
                    vars["LIST:" .. name] = self:make_variable_info(list)
                end
            end
            if self.game_state.arrays then
                for name, arr in pairs(self.game_state.arrays) do
                    vars["ARRAY:" .. name] = self:make_variable_info(arr)
                end
            end
            if self.game_state.maps then
                for name, map in pairs(self.game_state.maps) do
                    vars["MAP:" .. name] = self:make_variable_info(map)
                end
            end
        end

    elseif ref_info.type == "table" and ref_info.value then
        -- Expand table contents
        for k, v in pairs(ref_info.value) do
            vars[tostring(k)] = self:make_variable_info(v)
        end
    end

    return vars
end

--- Create variable info structure
-- @param value any Variable value
-- @return table { value, type, has_children, ref }
function Debugger:make_variable_info(value)
    local info = {
        value = value,
        type = type(value),
        has_children = false,
        ref = 0
    }

    if type(value) == "table" then
        info.has_children = true
        -- Create reference for expansion
        local ref = self.next_ref
        self.next_ref = self.next_ref + 1
        self.variable_refs[ref] = {
            type = "table",
            value = value
        }
        info.ref = ref
    end

    return info
end

--- Evaluate an expression
-- @param expression string Expression to evaluate
-- @param frame_id number Frame ID for context
-- @return boolean success
-- @return any result or error message
function Debugger:evaluate(expression, frame_id)
    local context = self.game_state

    -- Try interpreter evaluation first
    if self.engine and self.engine.lua_interpreter then
        local pcall_ok, eval_success, result = pcall(function()
            local s, r = self.engine.lua_interpreter:evaluate_expression(expression, context)
            return s, r
        end)
        if pcall_ok and eval_success then
            return true, result
        end
    end

    -- Try direct Lua evaluation
    local func, err = load("return " .. expression)
    if func then
        local success, result = pcall(func)
        if success then
            return true, result
        else
            return false, result
        end
    end

    return false, err
end

--- Set a variable value
-- @param name string Variable name
-- @param value any New value
-- @param scope_ref number Scope reference
-- @return boolean success
function Debugger:set_variable(name, value, scope_ref)
    if not self.game_state then
        return false
    end

    local ref_info = self.variable_refs[scope_ref]
    if not ref_info then
        return false
    end

    if ref_info.type == "local" then
        self.game_state:set_temp(name, value)
        return true
    elseif ref_info.type == "global" then
        self.game_state:set(name, value)
        return true
    end

    return false
end

--- Get thread information
-- @return table Array of thread info
function Debugger:get_threads()
    -- Whisker is single-threaded, but DAP requires at least one thread
    return {
        {
            id = 1,
            name = "Main Story"
        }
    }
end

--- Check if debugger is paused
-- @return boolean
function Debugger:is_paused()
    return self.stepper:is_paused()
end

--- Check if debugger is running
-- @return boolean
function Debugger:is_running()
    return self.stepper:is_running()
end

--- Get all breakpoints
-- @return table Array of breakpoints
function Debugger:get_breakpoints()
    return self.breakpoints:get_all()
end

--- Serialize debugger state
-- @return table Serialized data
function Debugger:serialize()
    return {
        breakpoints = self.breakpoints:serialize(),
        stepper = self.stepper:serialize(),
        source_path = self.source_path
    }
end

--- Deserialize debugger state
-- @param data table Serialized data
function Debugger:deserialize(data)
    if not data then return end
    self.breakpoints:deserialize(data.breakpoints)
    self.stepper:deserialize(data.stepper)
    self.source_path = data.source_path
end

--- Reset the debugger
function Debugger:reset()
    self.stepper:stop()
    self.breakpoints:reset_hit_counts()
    self.variable_refs = {}
    self.next_ref = 1
    self.stack_frames = {}
end

return Debugger
