-- lib/whisker/debug/stepper.lua
-- WLS 1.0.0 GAP-057: Step Commands
-- Provides controlled execution stepping (continue, step over, step into, step out)

local Stepper = {}
Stepper.__index = Stepper

-- Step modes
Stepper.MODE_CONTINUE = "continue"
Stepper.MODE_STEP_OVER = "step_over"
Stepper.MODE_STEP_INTO = "step_into"
Stepper.MODE_STEP_OUT = "step_out"

-- Execution states
Stepper.STATE_RUNNING = "running"
Stepper.STATE_PAUSED = "paused"
Stepper.STATE_STOPPED = "stopped"

--- Create a new Stepper instance
-- @param engine table Engine instance to control
-- @return Stepper instance
function Stepper.new(engine)
    local self = setmetatable({}, Stepper)
    self.engine = engine
    self.state = Stepper.STATE_STOPPED
    self.mode = Stepper.MODE_CONTINUE
    self.step_depth = 0
    self.step_file = nil
    self.step_line = nil
    self.on_pause = nil  -- Callback when paused: function(reason, info)
    self.on_log = nil    -- Callback for logging: function(message)
    return self
end

--- Start execution
function Stepper:start()
    self.state = Stepper.STATE_RUNNING
    self.mode = Stepper.MODE_CONTINUE
end

--- Pause execution
function Stepper:pause()
    self.state = Stepper.STATE_PAUSED
end

--- Resume execution (without changing mode)
function Stepper:resume()
    self.state = Stepper.STATE_RUNNING
end

--- Stop execution completely
function Stepper:stop()
    self.state = Stepper.STATE_STOPPED
end

--- Continue execution until next breakpoint
function Stepper:continue()
    self.mode = Stepper.MODE_CONTINUE
    self.state = Stepper.STATE_RUNNING
end

--- Step over: execute current line and stop at next line at same level
function Stepper:step_over()
    self.mode = Stepper.MODE_STEP_OVER
    self.step_depth = self:get_current_depth()
    self.state = Stepper.STATE_RUNNING
end

--- Step into: enter functions/passages and stop at first line
function Stepper:step_into()
    self.mode = Stepper.MODE_STEP_INTO
    self.state = Stepper.STATE_RUNNING
end

--- Step out: continue until returning from current context
function Stepper:step_out()
    self.mode = Stepper.MODE_STEP_OUT
    self.step_depth = self:get_current_depth() - 1
    if self.step_depth < 0 then
        self.step_depth = 0
    end
    self.state = Stepper.STATE_RUNNING
end

--- Step back: use undo system to return to previous state
-- @return boolean success
function Stepper:step_back()
    -- Use engine's game_state undo capability if available
    if self.engine and self.engine.game_state and self.engine.game_state.can_undo then
        if self.engine.game_state:can_undo() then
            self.engine.game_state:undo()
            self:pause()
            if self.on_pause then
                self.on_pause("step_back", {
                    reason = "step_back"
                })
            end
            return true
        end
    end
    return false
end

--- Get current execution depth (tunnel stack + call depth)
-- @return number Current depth
function Stepper:get_current_depth()
    local depth = 0

    -- Add tunnel stack depth if available
    if self.engine then
        if self.engine.tunnel_stack then
            depth = depth + #self.engine.tunnel_stack
        elseif self.engine.game_state and self.engine.game_state.tunnel_stack then
            depth = depth + #self.engine.game_state.tunnel_stack
        end

        -- Add interpreter call stack depth if available
        if self.engine.interpreter and self.engine.interpreter.call_stack then
            depth = depth + #self.engine.interpreter.call_stack
        elseif self.engine.lua_interpreter and self.engine.lua_interpreter.call_stack then
            depth = depth + #self.engine.lua_interpreter.call_stack
        end
    end

    return depth
end

--- Check if we should pause at a given location
-- @param file string Source file
-- @param line number Line number
-- @param event_type string Event type (passage_enter, content_line, function_enter)
-- @return boolean Whether to pause
function Stepper:should_pause_at(file, line, event_type)
    if self.state ~= Stepper.STATE_RUNNING then
        return false
    end

    if self.mode == Stepper.MODE_CONTINUE then
        return false  -- Only pause at breakpoints
    end

    local current_depth = self:get_current_depth()

    if self.mode == Stepper.MODE_STEP_INTO then
        -- Pause at any new line
        return true
    end

    if self.mode == Stepper.MODE_STEP_OVER then
        -- Pause at same or lower depth
        return current_depth <= self.step_depth
    end

    if self.mode == Stepper.MODE_STEP_OUT then
        -- Pause when we're back at target depth
        return current_depth <= self.step_depth
    end

    return false
end

--- Handle passage entry event
-- @param passage table Passage object with file, location, name
-- @return boolean Whether execution was paused
function Stepper:on_passage_enter(passage)
    local file = passage.file or passage.source_file or "unknown"
    local line = (passage.location and passage.location.line) or 1
    local name = passage.name or passage.id or "unknown"

    if self:should_pause_at(file, line, "passage_enter") then
        self:pause()
        if self.on_pause then
            self.on_pause("step", {
                reason = "step",
                file = file,
                line = line,
                passage = name
            })
        end
        return true
    end
    return false
end

--- Handle content line event
-- @param file string Source file
-- @param line number Line number
-- @return boolean Whether execution was paused
function Stepper:on_content_line(file, line)
    if self:should_pause_at(file, line, "content_line") then
        self:pause()
        if self.on_pause then
            self.on_pause("step", {
                reason = "step",
                file = file,
                line = line
            })
        end
        return true
    end
    return false
end

--- Handle function entry event
-- @param func_name string Function name
-- @param file string Source file
-- @param line number Line number
-- @return boolean Whether execution was paused
function Stepper:on_function_enter(func_name, file, line)
    if self:should_pause_at(file, line, "function_enter") then
        self:pause()
        if self.on_pause then
            self.on_pause("step", {
                reason = "step",
                file = file,
                line = line,
                func = func_name
            })
        end
        return true
    end
    return false
end

--- Handle function return event
-- @param func_name string Function name
-- @return boolean Whether execution was paused
function Stepper:on_function_return(func_name)
    if self.mode == Stepper.MODE_STEP_OUT then
        local current_depth = self:get_current_depth()
        if current_depth <= self.step_depth then
            self:pause()
            if self.on_pause then
                self.on_pause("step", {
                    reason = "step_out",
                    func = func_name
                })
            end
            return true
        end
    end
    return false
end

--- Check if currently paused
-- @return boolean
function Stepper:is_paused()
    return self.state == Stepper.STATE_PAUSED
end

--- Check if currently running
-- @return boolean
function Stepper:is_running()
    return self.state == Stepper.STATE_RUNNING
end

--- Check if stopped
-- @return boolean
function Stepper:is_stopped()
    return self.state == Stepper.STATE_STOPPED
end

--- Get current state
-- @return string State constant
function Stepper:get_state()
    return self.state
end

--- Get current mode
-- @return string Mode constant
function Stepper:get_mode()
    return self.mode
end

--- Set the pause callback
-- @param callback function(reason, info) Callback function
function Stepper:set_on_pause(callback)
    self.on_pause = callback
end

--- Set the log callback
-- @param callback function(message) Callback function
function Stepper:set_on_log(callback)
    self.on_log = callback
end

--- Log a message if callback is set
-- @param message string Message to log
function Stepper:log(message)
    if self.on_log then
        self.on_log(message)
    end
end

--- Serialize stepper state
-- @return table Serialized data
function Stepper:serialize()
    return {
        state = self.state,
        mode = self.mode,
        step_depth = self.step_depth,
        step_file = self.step_file,
        step_line = self.step_line
    }
end

--- Deserialize stepper state
-- @param data table Serialized data
function Stepper:deserialize(data)
    if not data then return end
    self.state = data.state or Stepper.STATE_STOPPED
    self.mode = data.mode or Stepper.MODE_CONTINUE
    self.step_depth = data.step_depth or 0
    self.step_file = data.step_file
    self.step_line = data.step_line
end

return Stepper
