-- lib/whisker/debug/dap_server.lua
-- WLS 1.0.0 GAP-055: Debug Adapter Protocol (DAP) Server
-- Implements the DAP protocol for VS Code debugging integration

local Debugger = require("lib.whisker.debug.debugger")

local DAPServer = {}
DAPServer.__index = DAPServer

-- DAP message types
local REQUEST = "request"
local RESPONSE = "response"
local EVENT = "event"

--- Create a new DAP server instance
-- @param options table Options:
--   debugger: Debugger instance (optional, will create one if not provided)
--   input: function Input source for reading messages
--   output: function Output sink for sending messages
-- @return DAPServer instance
function DAPServer.new(options)
    options = options or {}
    local self = setmetatable({}, DAPServer)

    self.debugger = options.debugger or Debugger.new()
    self.input = options.input
    self.output = options.output
    self.seq = 0
    self.initialized = false
    self.running = false

    -- Queue for outgoing events
    self.event_queue = {}

    -- Wire up debugger callbacks
    self.debugger.on_stopped = function(reason, details)
        self:send_event("stopped", {
            reason = reason,
            threadId = details.threadId or 1,
            allThreadsStopped = true
        })
    end

    self.debugger.on_output = function(category, output)
        self:send_event("output", {
            category = category,
            output = output .. "\n"
        })
    end

    self.debugger.on_terminated = function()
        self:send_event("terminated", {})
    end

    return self
end

--- Handle an incoming DAP message
-- @param message table Parsed DAP message
-- @return table|nil Response message
function DAPServer:handle_message(message)
    local msg_type = message.type

    if msg_type == REQUEST then
        return self:handle_request(message)
    end

    return nil
end

--- Handle a DAP request
-- @param request table Request message
-- @return table Response message
function DAPServer:handle_request(request)
    local command = request.command
    local args = request.arguments or {}

    if command == "initialize" then
        return self:initialize(request, args)
    elseif command == "launch" then
        return self:launch(request, args)
    elseif command == "attach" then
        return self:attach(request, args)
    elseif command == "disconnect" then
        return self:disconnect(request, args)
    elseif command == "setBreakpoints" then
        return self:set_breakpoints(request, args)
    elseif command == "setFunctionBreakpoints" then
        return self:set_function_breakpoints(request, args)
    elseif command == "configurationDone" then
        return self:configuration_done(request, args)
    elseif command == "threads" then
        return self:threads(request, args)
    elseif command == "stackTrace" then
        return self:stack_trace(request, args)
    elseif command == "scopes" then
        return self:scopes(request, args)
    elseif command == "variables" then
        return self:variables(request, args)
    elseif command == "continue" then
        return self:continue_request(request, args)
    elseif command == "next" then
        return self:next_request(request, args)
    elseif command == "stepIn" then
        return self:step_in(request, args)
    elseif command == "stepOut" then
        return self:step_out(request, args)
    elseif command == "stepBack" then
        return self:step_back(request, args)
    elseif command == "pause" then
        return self:pause_request(request, args)
    elseif command == "evaluate" then
        return self:evaluate_request(request, args)
    elseif command == "setVariable" then
        return self:set_variable(request, args)
    elseif command == "restart" then
        return self:restart(request, args)
    elseif command == "source" then
        return self:source_request(request, args)
    end

    return self:error_response(request, "Unknown command: " .. command)
end

--- Initialize request - returns capabilities
-- @param request table Request message
-- @param args table Request arguments
-- @return table Response message
function DAPServer:initialize(request, args)
    self.initialized = true

    -- Send initialized event after response
    table.insert(self.event_queue, { "initialized", {} })

    return self:success_response(request, {
        supportsConfigurationDoneRequest = true,
        supportsFunctionBreakpoints = true,
        supportsConditionalBreakpoints = true,
        supportsHitConditionalBreakpoints = true,
        supportsEvaluateForHovers = true,
        supportsStepBack = true,
        supportsSetVariable = true,
        supportsRestartRequest = true,
        supportsModulesRequest = false,
        supportsLogPoints = true,
        supportsTerminateRequest = true,
        supportsDataBreakpoints = false,
        supportsCompletionsRequest = false,
        supportsCancelRequest = false,
        supportsBreakpointLocationsRequest = false,
        supportsSteppingGranularity = false,
        supportsInstructionBreakpoints = false,
        supportsExceptionFilterOptions = false
    })
end

--- Launch request - start debugging a story
-- @param request table Request message
-- @param args table Arguments { program, stopOnEntry }
-- @return table Response message
function DAPServer:launch(request, args)
    local program = args.program
    local stop_on_entry = args.stopOnEntry or false

    -- Load story
    local success, err = self.debugger:load_story(program)
    if not success then
        return self:error_response(request, err or "Failed to load story")
    end

    self.running = true

    -- Start debugging
    self.debugger:start(stop_on_entry)

    if stop_on_entry then
        -- Stopped event will be sent by debugger callback
    else
        self.debugger:run()
    end

    return self:success_response(request)
end

--- Attach request - attach to running story
-- @param request table Request message
-- @param args table Arguments
-- @return table Response message
function DAPServer:attach(request, args)
    -- For attach, we assume the story is already loaded
    self.running = true
    self.debugger:start(true)  -- Stop on attach

    return self:success_response(request)
end

--- Disconnect request - end debug session
-- @param request table Request message
-- @param args table Arguments
-- @return table Response message
function DAPServer:disconnect(request, args)
    self.running = false
    self.debugger:reset()

    return self:success_response(request)
end

--- Set breakpoints request
-- @param request table Request message
-- @param args table Arguments { source, breakpoints }
-- @return table Response message
function DAPServer:set_breakpoints(request, args)
    local source = args.source
    local breakpoints = args.breakpoints or {}
    local path = source.path

    -- Clear existing breakpoints for this file
    self.debugger:clear_file_breakpoints(path)

    local results = {}
    for _, bp in ipairs(breakpoints) do
        local result = self.debugger:set_breakpoint(
            path,
            bp.line,
            bp.condition
        )

        -- Handle hit condition
        if bp.hitCondition then
            local full_bp = self.debugger.breakpoints:get(result.id)
            if full_bp then
                full_bp.hit_condition = bp.hitCondition
            end
        end

        -- Handle log message (logpoint)
        if bp.logMessage then
            local full_bp = self.debugger.breakpoints:get(result.id)
            if full_bp then
                full_bp.log_message = bp.logMessage
                full_bp.type = "logpoint"
            end
        end

        table.insert(results, {
            verified = result.verified,
            line = result.line,
            id = result.id
        })
    end

    return self:success_response(request, {
        breakpoints = results
    })
end

--- Set function/passage breakpoints
-- @param request table Request message
-- @param args table Arguments { breakpoints }
-- @return table Response message
function DAPServer:set_function_breakpoints(request, args)
    local breakpoints = args.breakpoints or {}

    local results = {}
    for _, bp in ipairs(breakpoints) do
        local result = self.debugger:set_passage_breakpoint(
            bp.name,
            bp.condition
        )

        table.insert(results, {
            verified = result.verified,
            id = result.id
        })
    end

    return self:success_response(request, {
        breakpoints = results
    })
end

--- Configuration done request
-- @param request table Request message
-- @param args table Arguments
-- @return table Response message
function DAPServer:configuration_done(request, args)
    return self:success_response(request)
end

--- Threads request
-- @param request table Request message
-- @param args table Arguments
-- @return table Response message
function DAPServer:threads(request, args)
    local threads = self.debugger:get_threads()
    return self:success_response(request, {
        threads = threads
    })
end

--- Stack trace request
-- @param request table Request message
-- @param args table Arguments { threadId, startFrame, levels }
-- @return table Response message
function DAPServer:stack_trace(request, args)
    local frames = self.debugger:get_stack_trace()
    local stack_frames = {}

    for i, frame in ipairs(frames) do
        table.insert(stack_frames, {
            id = i,
            name = frame.name,
            source = { path = frame.file },
            line = frame.line,
            column = frame.column or 1
        })
    end

    return self:success_response(request, {
        stackFrames = stack_frames,
        totalFrames = #stack_frames
    })
end

--- Scopes request
-- @param request table Request message
-- @param args table Arguments { frameId }
-- @return table Response message
function DAPServer:scopes(request, args)
    local frame_id = args.frameId
    local scopes = self.debugger:get_scopes(frame_id)

    return self:success_response(request, {
        scopes = scopes
    })
end

--- Variables request
-- @param request table Request message
-- @param args table Arguments { variablesReference }
-- @return table Response message
function DAPServer:variables(request, args)
    local scope_ref = args.variablesReference
    local vars = self.debugger:get_variables(scope_ref)
    local variables = {}

    for name, info in pairs(vars) do
        table.insert(variables, {
            name = name,
            value = tostring(info.value),
            type = info.type,
            variablesReference = info.has_children and info.ref or 0
        })
    end

    return self:success_response(request, {
        variables = variables
    })
end

--- Continue request
-- @param request table Request message
-- @param args table Arguments { threadId }
-- @return table Response message
function DAPServer:continue_request(request, args)
    self.debugger:continue()
    return self:success_response(request, {
        allThreadsContinued = true
    })
end

--- Next (step over) request
-- @param request table Request message
-- @param args table Arguments { threadId }
-- @return table Response message
function DAPServer:next_request(request, args)
    self.debugger:next()
    return self:success_response(request)
end

--- Step in request
-- @param request table Request message
-- @param args table Arguments { threadId }
-- @return table Response message
function DAPServer:step_in(request, args)
    self.debugger:step_in()
    return self:success_response(request)
end

--- Step out request
-- @param request table Request message
-- @param args table Arguments { threadId }
-- @return table Response message
function DAPServer:step_out(request, args)
    self.debugger:step_out()
    return self:success_response(request)
end

--- Step back request
-- @param request table Request message
-- @param args table Arguments { threadId }
-- @return table Response message
function DAPServer:step_back(request, args)
    local success = self.debugger:step_back()
    if not success then
        return self:error_response(request, "Cannot step back: no history available")
    end
    return self:success_response(request)
end

--- Pause request
-- @param request table Request message
-- @param args table Arguments { threadId }
-- @return table Response message
function DAPServer:pause_request(request, args)
    self.debugger:pause()
    return self:success_response(request)
end

--- Evaluate request
-- @param request table Request message
-- @param args table Arguments { expression, frameId, context }
-- @return table Response message
function DAPServer:evaluate_request(request, args)
    local expression = args.expression
    local frame_id = args.frameId

    local success, result = self.debugger:evaluate(expression, frame_id)

    if not success then
        return self:error_response(request, tostring(result))
    end

    local var_ref = 0
    if type(result) == "table" then
        var_ref = self.debugger:create_variable_ref("table", frame_id)
        self.debugger.variable_refs[var_ref].value = result
    end

    return self:success_response(request, {
        result = tostring(result),
        type = type(result),
        variablesReference = var_ref
    })
end

--- Set variable request
-- @param request table Request message
-- @param args table Arguments { variablesReference, name, value }
-- @return table Response message
function DAPServer:set_variable(request, args)
    local scope_ref = args.variablesReference
    local name = args.name
    local value_str = args.value

    -- Parse value
    local value
    local func = load("return " .. value_str)
    if func then
        local success, result = pcall(func)
        if success then
            value = result
        else
            value = value_str
        end
    else
        value = value_str
    end

    local success = self.debugger:set_variable(name, value, scope_ref)
    if not success then
        return self:error_response(request, "Cannot set variable")
    end

    return self:success_response(request, {
        value = tostring(value),
        type = type(value),
        variablesReference = 0
    })
end

--- Restart request
-- @param request table Request message
-- @param args table Arguments
-- @return table Response message
function DAPServer:restart(request, args)
    self.debugger:reset()

    -- Re-launch with same settings
    if self.debugger.source_path then
        self.debugger:load_story(self.debugger.source_path)
        self.debugger:start(false)
    end

    return self:success_response(request)
end

--- Source request - get source code
-- @param request table Request message
-- @param args table Arguments { source, sourceReference }
-- @return table Response message
function DAPServer:source_request(request, args)
    -- For now, return empty - source is loaded from file
    return self:success_response(request, {
        content = ""
    })
end

--- Create a success response
-- @param request table Original request
-- @param body table|nil Response body
-- @return table Response message
function DAPServer:success_response(request, body)
    self.seq = self.seq + 1
    return {
        seq = self.seq,
        type = RESPONSE,
        request_seq = request.seq,
        success = true,
        command = request.command,
        body = body
    }
end

--- Create an error response
-- @param request table Original request
-- @param message string Error message
-- @return table Response message
function DAPServer:error_response(request, message)
    self.seq = self.seq + 1
    return {
        seq = self.seq,
        type = RESPONSE,
        request_seq = request.seq,
        success = false,
        command = request.command,
        message = message
    }
end

--- Send an event
-- @param event string Event name
-- @param body table Event body
-- @return table Event message
function DAPServer:send_event(event, body)
    self.seq = self.seq + 1
    local msg = {
        seq = self.seq,
        type = EVENT,
        event = event,
        body = body
    }

    if self.output then
        self.output(msg)
    end

    return msg
end

--- Process queued events (call after response)
function DAPServer:process_event_queue()
    for _, ev in ipairs(self.event_queue) do
        self:send_event(ev[1], ev[2])
    end
    self.event_queue = {}
end

--- Run the DAP server main loop
function DAPServer:run()
    self.running = true

    while self.running do
        -- Read message from input
        if self.input then
            local message = self.input()
            if message then
                local response = self:handle_message(message)
                if response and self.output then
                    self.output(response)
                end
                self:process_event_queue()
            end
        else
            break
        end
    end
end

--- Stop the DAP server
function DAPServer:stop()
    self.running = false
end

return DAPServer
