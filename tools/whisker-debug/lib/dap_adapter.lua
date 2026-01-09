-- whisker-debug/lib/dap_adapter.lua
-- Debug Adapter Protocol message handler

local M = {}

-- Try to load modules from various paths
local function try_require(...)
  for _, name in ipairs({...}) do
    local ok, mod = pcall(require, name)
    if ok then return mod end
  end
  return nil
end

local interfaces = try_require("lib.interfaces", "whisker-debug.lib.interfaces")
local BreakpointManager = try_require("lib.breakpoint_manager", "whisker-debug.lib.breakpoint_manager")
local RuntimeWrapper = try_require("lib.runtime_wrapper", "whisker-debug.lib.runtime_wrapper")
local VariableSerializer = try_require("lib.variable_serializer", "whisker-debug.lib.variable_serializer")

-- Try to load JSON library
local json
local ok, cjson = pcall(require, "cjson")
if ok then
  json = cjson
else
  -- Try dkjson
  ok, json = pcall(require, "dkjson")
  if not ok then
    -- Use LSP json if available
    ok, json = pcall(require, "whisker-lsp.lib.json")
  end
end

local DAPAdapter = {}
DAPAdapter.__index = DAPAdapter

---Create a new DAP adapter
---@param transport string|nil "stdio" (default) or "tcp"
---@param port number|nil TCP port (required if transport is "tcp")
---@return table
function DAPAdapter.new(transport, port)
  local self = setmetatable({}, DAPAdapter)
  self.sequence = 1
  self.request_seq = 0
  self.breakpoint_manager = BreakpointManager.new()
  self.variable_serializer = VariableSerializer.new()
  self.runtime = nil
  self.initialized = false
  self.configuration_done = false
  self.paused = false
  self.continue_signal = nil

  -- Transport configuration
  self.transport = transport or "stdio"
  self.tcp_port = port
  self.socket = nil
  self.client = nil

  return self
end

---Main message loop
function DAPAdapter:run()
  if self.transport == "tcp" then
    self:run_tcp()
  else
    self:run_stdio()
  end
end

---Run in stdio mode (default)
function DAPAdapter:run_stdio()
  while true do
    local msg = self:read_message_stdio()
    if not msg then break end
    self:handle_message(msg)
  end
end

---Run in TCP mode
function DAPAdapter:run_tcp()
  -- Try to load LuaSocket
  local ok, socket = pcall(require, "socket")
  if not ok then
    io.stderr:write("Error: TCP mode requires LuaSocket. Install with: luarocks install luasocket\n")
    os.exit(1)
  end

  -- Create TCP server
  local server, err = socket.tcp()
  if not server then
    io.stderr:write("Error creating TCP socket: " .. tostring(err) .. "\n")
    os.exit(1)
  end

  server:setoption("reuseaddr", true)

  local ok, err = server:bind("127.0.0.1", self.tcp_port)
  if not ok then
    io.stderr:write("Error binding to port " .. self.tcp_port .. ": " .. tostring(err) .. "\n")
    os.exit(1)
  end

  server:listen(1)
  io.stderr:write("Debug adapter listening on port " .. self.tcp_port .. "\n")
  io.stderr:write("Waiting for client connection...\n")

  self.socket = server

  -- Accept client connections (one at a time)
  while true do
    local client, err = server:accept()
    if client then
      io.stderr:write("Client connected\n")
      self.client = client
      client:settimeout(nil) -- Blocking mode

      -- Handle this client session
      local ok, err = pcall(function()
        self:handle_tcp_client()
      end)

      if not ok then
        io.stderr:write("Client session error: " .. tostring(err) .. "\n")
      end

      client:close()
      self.client = nil
      io.stderr:write("Client disconnected\n")

      -- Reset state for next client
      self.sequence = 1
      self.initialized = false
      self.configuration_done = false
    else
      io.stderr:write("Accept error: " .. tostring(err) .. "\n")
      break
    end
  end

  server:close()
end

---Handle TCP client session
function DAPAdapter:handle_tcp_client()
  while true do
    local msg = self:read_message_tcp()
    if not msg then break end
    self:handle_message(msg)
  end
end

---Read Content-Length delimited message from stdin
---@return table|nil Parsed message or nil on EOF
function DAPAdapter:read_message_stdio()
  local headers = {}

  while true do
    local line = io.read("*l")
    if not line then return nil end
    if line == "" or line == "\r" then break end

    -- Remove trailing CR if present
    line = line:gsub("\r$", "")

    local key, value = line:match("^([^:]+):%s*(.+)$")
    if key then
      headers[key:lower()] = value
    end
  end

  local length = tonumber(headers["content-length"])
  if not length then return nil end

  local body = io.read(length)
  if not body then return nil end

  local ok, msg = pcall(json.decode, body)
  if not ok then
    io.stderr:write("Failed to parse JSON: " .. tostring(msg) .. "\n")
    return nil
  end

  return msg
end

---Read Content-Length delimited message from TCP socket
---@return table|nil Parsed message or nil on disconnect
function DAPAdapter:read_message_tcp()
  if not self.client then return nil end

  local headers = {}

  -- Read headers
  while true do
    local line, err = self.client:receive("*l")
    if not line then
      if err == "closed" then return nil end
      io.stderr:write("TCP receive error: " .. tostring(err) .. "\n")
      return nil
    end

    -- Remove trailing CR if present
    line = line:gsub("\r$", "")

    if line == "" then break end

    local key, value = line:match("^([^:]+):%s*(.+)$")
    if key then
      headers[key:lower()] = value
    end
  end

  local length = tonumber(headers["content-length"])
  if not length then return nil end

  -- Read body
  local body, err = self.client:receive(length)
  if not body then
    io.stderr:write("TCP receive error: " .. tostring(err) .. "\n")
    return nil
  end

  local ok, msg = pcall(json.decode, body)
  if not ok then
    io.stderr:write("Failed to parse JSON: " .. tostring(msg) .. "\n")
    return nil
  end

  return msg
end

---Write message to client (stdio or TCP)
---@param msg table The message to send
function DAPAdapter:write_message(msg)
  msg.seq = self.sequence
  self.sequence = self.sequence + 1

  local body = json.encode(msg)
  local data = string.format("Content-Length: %d\r\n\r\n%s", #body, body)

  if self.transport == "tcp" and self.client then
    local ok, err = self.client:send(data)
    if not ok then
      io.stderr:write("TCP send error: " .. tostring(err) .. "\n")
    end
  else
    io.write(data)
    io.flush()
  end
end

---Send response to client
---@param request table The original request
---@param success boolean Whether request succeeded
---@param body table|nil Response body
function DAPAdapter:send_response(request, success, body)
  self:write_message({
    type = "response",
    request_seq = request.seq,
    success = success,
    command = request.command,
    body = body or {}
  })
end

---Send error response
---@param request table The original request
---@param message string Error message
function DAPAdapter:send_error(request, message)
  self:write_message({
    type = "response",
    request_seq = request.seq,
    success = false,
    command = request.command,
    message = message
  })
end

---Send event to client
---@param event string Event name
---@param body table|nil Event body
function DAPAdapter:send_event(event, body)
  self:write_message({
    type = "event",
    event = event,
    body = body or {}
  })
end

---Handle incoming message
---@param msg table The DAP message
function DAPAdapter:handle_message(msg)
  if msg.type ~= "request" then
    return
  end

  local command = msg.command
  local handler = self["handle_" .. command]

  if handler then
    local ok, err = pcall(function()
      handler(self, msg)
    end)

    if not ok then
      io.stderr:write("Error handling " .. command .. ": " .. tostring(err) .. "\n")
      self:send_error(msg, tostring(err))
    end
  else
    -- Unknown command - send success with empty body
    self:send_response(msg, true)
  end
end

---Handle initialize request
---@param request table
function DAPAdapter:handle_initialize(request)
  self.initialized = true

  self:send_response(request, true, interfaces.Capabilities)
  self:send_event("initialized")
end

---Handle launch request
---@param request table
function DAPAdapter:handle_launch(request)
  local args = request.arguments or {}
  local program = args.program

  if not program then
    self:send_error(request, "No program specified")
    return
  end

  -- Create runtime wrapper
  self.runtime = RuntimeWrapper.new(program)
  self.runtime:set_breakpoint_manager(self.breakpoint_manager)

  -- Set up callbacks
  self.runtime:on_pause(function(reason, data)
    self:on_runtime_pause(reason, data)
  end)

  self.runtime:on_end(function()
    self:send_event("terminated")
  end)

  self.runtime:on_output(function(message)
    self:send_event("output", {
      category = "console",
      output = message .. "\n"
    })
  end)

  -- Load story
  local ok, err = self.runtime:load_story()
  if not ok then
    self:send_error(request, "Failed to load story: " .. tostring(err))
    return
  end

  -- Check for stopOnEntry
  if args.stopOnEntry then
    self.runtime:step_into()  -- Will stop on first passage
  end

  self:send_response(request, true)
end

---Handle attach request
---@param request table
function DAPAdapter:handle_attach(request)
  self:send_error(request, "Attach is not supported")
end

---Handle setBreakpoints request
---@param request table
function DAPAdapter:handle_setBreakpoints(request)
  local args = request.arguments or {}
  local source = args.source or {}
  local path = source.path or ""
  local breakpoints = args.breakpoints or {}

  -- Extract line numbers
  local lines = {}
  for _, bp in ipairs(breakpoints) do
    table.insert(lines, bp.line)
  end

  -- Set breakpoints
  local verified = self.breakpoint_manager:set_breakpoints(path, lines, breakpoints)

  self:send_response(request, true, {
    breakpoints = verified
  })
end

---Handle setFunctionBreakpoints request
---@param request table
function DAPAdapter:handle_setFunctionBreakpoints(request)
  -- Not supported, return empty
  self:send_response(request, true, {
    breakpoints = {}
  })
end

---Handle setExceptionBreakpoints request
---@param request table
function DAPAdapter:handle_setExceptionBreakpoints(request)
  self:send_response(request, true)
end

---Handle configurationDone request
---@param request table
function DAPAdapter:handle_configurationDone(request)
  self.configuration_done = true
  self:send_response(request, true)

  -- Start runtime if ready
  if self.runtime then
    self.runtime:start()

    -- If not paused, story is running
    if not self.runtime:is_paused() then
      -- Story may have ended immediately
      if self.runtime:is_ended() then
        self:send_event("terminated")
      end
    end
  end
end

---Handle threads request
---@param request table
function DAPAdapter:handle_threads(request)
  self:send_response(request, true, {
    threads = {
      {id = 1, name = "Story Thread"}
    }
  })
end

---Handle stackTrace request
---@param request table
function DAPAdapter:handle_stackTrace(request)
  if not self.runtime then
    self:send_response(request, true, {stackFrames = {}, totalFrames = 0})
    return
  end

  local stack_manager = self.runtime:get_stack_manager()
  local frames = stack_manager:get_stack_trace()

  self:send_response(request, true, {
    stackFrames = frames,
    totalFrames = #frames
  })
end

---Handle scopes request
---@param request table
function DAPAdapter:handle_scopes(request)
  local args = request.arguments or {}
  local frame_id = args.frameId or 1

  self:send_response(request, true, {
    scopes = {
      {
        name = "Globals",
        variablesReference = interfaces.ScopeRanges.GLOBALS_START + frame_id,
        expensive = false
      },
      {
        name = "Locals",
        variablesReference = interfaces.ScopeRanges.LOCALS_START + frame_id,
        expensive = false
      },
      {
        name = "Temps",
        variablesReference = interfaces.ScopeRanges.TEMPS_START + frame_id,
        expensive = false
      }
    }
  })
end

---Handle variables request
---@param request table
function DAPAdapter:handle_variables(request)
  local args = request.arguments or {}
  local ref = args.variablesReference

  if not self.runtime then
    self:send_response(request, true, {variables = {}})
    return
  end

  local variables = {}

  if ref >= interfaces.ScopeRanges.CONTAINERS_START then
    -- Nested container
    variables = self.variable_serializer:get_variables(ref)
  elseif ref >= interfaces.ScopeRanges.TEMPS_START then
    -- Temps scope
    local frame_id = ref - interfaces.ScopeRanges.TEMPS_START
    local stack_manager = self.runtime:get_stack_manager()
    local temps = stack_manager:get_frame_temps(frame_id)
    for k, v in pairs(temps) do
      table.insert(variables, self.variable_serializer:serialize(k, v))
    end
  elseif ref >= interfaces.ScopeRanges.LOCALS_START then
    -- Locals scope
    local frame_id = ref - interfaces.ScopeRanges.LOCALS_START
    local stack_manager = self.runtime:get_stack_manager()
    local locals = stack_manager:get_frame_locals(frame_id)
    for k, v in pairs(locals) do
      table.insert(variables, self.variable_serializer:serialize(k, v))
    end
  elseif ref >= interfaces.ScopeRanges.GLOBALS_START then
    -- Globals scope
    local state = self.runtime:get_state()
    for k, v in pairs(state) do
      -- Skip internal keys
      if type(k) == "string" and not k:match("^_") then
        table.insert(variables, self.variable_serializer:serialize(k, v))
      end
    end
  end

  -- Sort variables by name
  table.sort(variables, function(a, b)
    return a.name < b.name
  end)

  self:send_response(request, true, {variables = variables})
end

---Handle continue request
---@param request table
function DAPAdapter:handle_continue(request)
  self:send_response(request, true, {allThreadsContinued = true})

  if self.runtime then
    self.runtime:continue()
  end

  if self.continue_signal then
    self.continue_signal()
  end
end

---Handle next request (step over)
---@param request table
function DAPAdapter:handle_next(request)
  self:send_response(request, true)

  if self.runtime then
    self.runtime:step_over()
  end

  if self.continue_signal then
    self.continue_signal()
  end
end

---Handle stepIn request
---@param request table
function DAPAdapter:handle_stepIn(request)
  self:send_response(request, true)

  if self.runtime then
    self.runtime:step_into()
  end

  if self.continue_signal then
    self.continue_signal()
  end
end

---Handle stepOut request
---@param request table
function DAPAdapter:handle_stepOut(request)
  self:send_response(request, true)

  if self.runtime then
    self.runtime:step_out()
  end

  if self.continue_signal then
    self.continue_signal()
  end
end

---Handle pause request
---@param request table
function DAPAdapter:handle_pause(request)
  self:send_response(request, true)

  if self.runtime then
    self.runtime:pause(interfaces.StopReason.PAUSE, {})
  end
end

---Handle evaluate request
---@param request table
function DAPAdapter:handle_evaluate(request)
  local args = request.arguments or {}
  local expression = args.expression
  local frame_id = args.frameId
  local context = args.context or "watch"

  if not expression or expression == "" then
    self:send_error(request, "Expression required")
    return
  end

  if not self.runtime then
    self:send_error(request, "No active debug session")
    return
  end

  local ok, result = self.runtime:evaluate(expression, frame_id)
  local response = self.variable_serializer:serialize_eval_result(expression, ok, result)

  self:send_response(request, true, response)
end

---Handle completions request
---@param request table
function DAPAdapter:handle_completions(request)
  local args = request.arguments or {}
  local text = args.text or ""

  -- Provide simple completions from state
  local targets = {}

  if self.runtime then
    local state = self.runtime:get_state()
    for k in pairs(state) do
      if type(k) == "string" and k:find(text, 1, true) == 1 then
        table.insert(targets, {
          label = k,
          type = "variable"
        })
      end
    end
  end

  self:send_response(request, true, {targets = targets})
end

---Handle disconnect request
---@param request table
function DAPAdapter:handle_disconnect(request)
  self:send_response(request, true)

  if self.runtime then
    self.runtime:stop()
  end

  -- Exit after sending response
  os.exit(0)
end

---Handle terminate request
---@param request table
function DAPAdapter:handle_terminate(request)
  self:send_response(request, true)

  if self.runtime then
    self.runtime:stop()
  end

  self:send_event("terminated")
end

---Handle source request
---@param request table
function DAPAdapter:handle_source(request)
  local args = request.arguments or {}
  local source = args.source or {}
  local path = source.path

  if not path then
    self:send_error(request, "Source path required")
    return
  end

  local file = io.open(path, "r")
  if not file then
    self:send_error(request, "Cannot read source file")
    return
  end

  local content = file:read("*a")
  file:close()

  self:send_response(request, true, {content = content})
end

---Handle breakpointLocations request
---@param request table
function DAPAdapter:handle_breakpointLocations(request)
  local args = request.arguments or {}
  local source = args.source or {}
  local path = source.path
  local line = args.line

  -- Return valid breakpoint locations
  -- For now, just return the requested line
  local locations = {}
  if line then
    table.insert(locations, {line = line, column = 1})
  end

  self:send_response(request, true, {breakpoints = locations})
end

---Called when runtime pauses
---@param reason string Stop reason
---@param data table Additional data
function DAPAdapter:on_runtime_pause(reason, data)
  self.paused = true

  self:send_event("stopped", {
    reason = reason,
    threadId = 1,
    allThreadsStopped = true,
    description = data.passage and ("Stopped at " .. data.passage) or nil
  })

  -- Wait for continue
  self:wait_for_continue()
end

---Wait for continue signal
function DAPAdapter:wait_for_continue()
  local resumed = false
  self.continue_signal = function()
    resumed = true
  end

  while not resumed do
    local msg = self:read_message()
    if msg then
      self:handle_message(msg)
    else
      -- EOF, exit
      break
    end
  end

  self.continue_signal = nil
  self.paused = false
end

M.new = DAPAdapter.new

return M
