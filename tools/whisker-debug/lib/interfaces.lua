-- whisker-debug/lib/interfaces.lua
-- Interface definitions for Debug Adapter Protocol implementation

local M = {}

--------------------------------------------------------------------------------
-- DAP Constants
--------------------------------------------------------------------------------

-- Stop reasons
M.StopReason = {
  STEP = "step",
  BREAKPOINT = "breakpoint",
  EXCEPTION = "exception",
  PAUSE = "pause",
  ENTRY = "entry",
  GOTO = "goto",
  FUNCTION_BREAKPOINT = "function breakpoint",
  DATA_BREAKPOINT = "data breakpoint"
}

-- Thread states
M.ThreadState = {
  RUNNING = "running",
  STOPPED = "stopped",
  EXITED = "exited"
}

-- Step modes
M.StepMode = {
  INTO = "into",
  OVER = "over",
  OUT = "out"
}

-- Variable presentation hints
M.VariableKind = {
  PROPERTY = "property",
  METHOD = "method",
  CLASS = "class",
  DATA = "data",
  EVENT = "event",
  BASE_CLASS = "baseClass",
  INNER_CLASS = "innerClass",
  INTERFACE = "interface",
  MOST_DERIVED_CLASS = "mostDerivedClass",
  VIRTUAL = "virtual"
}

--------------------------------------------------------------------------------
-- IBreakpointManager Interface
--------------------------------------------------------------------------------

---@class IBreakpointManager
---Interface for managing breakpoints
M.IBreakpointManager = {
  ---Set breakpoints for a file
  ---@param uri string The file URI
  ---@param breakpoints table[] Array of breakpoint specifications
  ---@return table[] Verified breakpoints
  set_breakpoints = function(self, uri, breakpoints) end,

  ---Check if a breakpoint exists at location
  ---@param uri string The file URI
  ---@param line number The line number
  ---@return table|nil Breakpoint info or nil
  get_breakpoint = function(self, uri, line) end,

  ---Check if any breakpoint exists at location
  ---@param uri string The file URI
  ---@param line number The line number
  ---@return boolean
  has_breakpoint = function(self, uri, line) end,

  ---Clear all breakpoints for a file
  ---@param uri string The file URI
  clear_breakpoints = function(self, uri) end,

  ---Clear all breakpoints
  clear_all = function(self) end,

  ---Check if conditional breakpoint should trigger
  ---@param breakpoint table The breakpoint info
  ---@param state table The current story state
  ---@return boolean
  check_condition = function(self, breakpoint, state) end,

  ---Check if hit count condition is met
  ---@param breakpoint table The breakpoint info
  ---@return boolean
  check_hit_count = function(self, breakpoint) end,

  ---Verify breakpoint line against AST
  ---@param uri string The file URI
  ---@param line number The requested line
  ---@return table Verification result {verified, line, message}
  verify_breakpoint = function(self, uri, line) end
}

--------------------------------------------------------------------------------
-- IRuntimeWrapper Interface
--------------------------------------------------------------------------------

---@class IRuntimeWrapper
---Interface for instrumented runtime
M.IRuntimeWrapper = {
  ---Wrap a whisker-core runtime for debugging
  ---@param runtime table The runtime instance
  wrap = function(self, runtime) end,

  ---Load and parse a story file
  ---@param path string The file path
  ---@return boolean success
  ---@return string|nil error
  load_story = function(self, path) end,

  ---Start story execution
  start = function(self) end,

  ---Pause execution
  ---@param reason string The stop reason
  ---@param data table Additional data
  pause = function(self, reason, data) end,

  ---Resume execution
  continue = function(self) end,

  ---Execute step into
  step_into = function(self) end,

  ---Execute step over
  step_over = function(self) end,

  ---Execute step out
  step_out = function(self) end,

  ---Get current state
  ---@return table
  get_state = function(self) end,

  ---Get current passage
  ---@return table|nil
  get_current_passage = function(self) end,

  ---Get available choices
  ---@return table[]
  get_choices = function(self) end,

  ---Make a choice
  ---@param index number The choice index
  choose = function(self, index) end,

  ---Check if execution is paused
  ---@return boolean
  is_paused = function(self) end,

  ---Check if story has ended
  ---@return boolean
  is_ended = function(self) end,

  ---Set breakpoint manager reference
  ---@param manager IBreakpointManager
  set_breakpoint_manager = function(self, manager) end,

  ---Register pause callback
  ---@param callback function
  on_pause = function(self, callback) end,

  ---Register continue callback
  ---@param callback function
  on_continue = function(self, callback) end,

  ---Register end callback
  ---@param callback function
  on_end = function(self, callback) end
}

--------------------------------------------------------------------------------
-- IStackFrameManager Interface
--------------------------------------------------------------------------------

---@class IStackFrameManager
---Interface for managing call stack
M.IStackFrameManager = {
  ---Push a new frame onto the stack
  ---@param passage string The passage name
  ---@param source table The source location {path, line}
  ---@return number Frame ID
  push_frame = function(self, passage, source) end,

  ---Pop the top frame from the stack
  ---@return table|nil The popped frame
  pop_frame = function(self) end,

  ---Get all stack frames in DAP format
  ---@return table[] Stack frames
  get_stack_trace = function(self) end,

  ---Get a specific frame by ID
  ---@param id number The frame ID
  ---@return table|nil The frame
  get_frame = function(self, id) end,

  ---Get current stack depth
  ---@return number
  get_depth = function(self) end,

  ---Clear all frames
  clear = function(self) end,

  ---Update the current frame's line
  ---@param line number The current line
  update_current_line = function(self, line) end
}

--------------------------------------------------------------------------------
-- IVariableSerializer Interface
--------------------------------------------------------------------------------

---@class IVariableSerializer
---Interface for serializing variables to DAP format
M.IVariableSerializer = {
  ---Serialize a Lua value to DAP variable format
  ---@param name string The variable name
  ---@param value any The Lua value
  ---@return table DAP variable
  serialize = function(self, name, value) end,

  ---Get child variables for a container
  ---@param reference number The variables reference
  ---@return table[] Child variables
  get_variables = function(self, reference) end,

  ---Register a container and get a reference
  ---@param container table The container value
  ---@return number Reference ID
  register_container = function(self, container) end,

  ---Get the container for a reference
  ---@param reference number The reference ID
  ---@return table|nil The container
  get_container = function(self, reference) end,

  ---Evaluate an expression
  ---@param expression string The expression to evaluate
  ---@param frame table The stack frame context
  ---@return table Result {value, type, variablesReference}
  evaluate = function(self, expression, frame) end,

  ---Clear all registered containers
  clear = function(self) end
}

--------------------------------------------------------------------------------
-- IDAPAdapter Interface
--------------------------------------------------------------------------------

---@class IDAPAdapter
---Interface for DAP protocol adapter
M.IDAPAdapter = {
  ---Initialize the adapter
  ---@param args table Initialize arguments
  ---@return table Capabilities
  initialize = function(self, args) end,

  ---Launch a debug session
  ---@param args table Launch arguments
  ---@return boolean success
  launch = function(self, args) end,

  ---Set breakpoints for a source
  ---@param args table SetBreakpoints arguments
  ---@return table[] Verified breakpoints
  set_breakpoints = function(self, args) end,

  ---Handle configuration done
  configuration_done = function(self) end,

  ---Continue execution
  ---@param args table Continue arguments
  continue = function(self, args) end,

  ---Step into next statement
  ---@param args table Step arguments
  step_in = function(self, args) end,

  ---Step out of current scope
  ---@param args table Step arguments
  step_out = function(self, args) end,

  ---Step over current statement
  ---@param args table Step arguments
  next = function(self, args) end,

  ---Pause execution
  ---@param args table Pause arguments
  pause = function(self, args) end,

  ---Get threads
  ---@return table[] Threads
  threads = function(self) end,

  ---Get stack trace
  ---@param args table StackTrace arguments
  ---@return table[] Stack frames
  stack_trace = function(self, args) end,

  ---Get scopes for a frame
  ---@param args table Scopes arguments
  ---@return table[] Scopes
  scopes = function(self, args) end,

  ---Get variables
  ---@param args table Variables arguments
  ---@return table[] Variables
  variables = function(self, args) end,

  ---Evaluate expression
  ---@param args table Evaluate arguments
  ---@return table Result
  evaluate = function(self, args) end,

  ---Disconnect from session
  ---@param args table Disconnect arguments
  disconnect = function(self, args) end,

  ---Terminate session
  ---@param args table Terminate arguments
  terminate = function(self, args) end,

  ---Handle incoming message
  ---@param message table DAP message
  handle_message = function(self, message) end,

  ---Send response to client
  ---@param request table The original request
  ---@param body table The response body
  send_response = function(self, request, body) end,

  ---Send event to client
  ---@param event string The event name
  ---@param body table The event body
  send_event = function(self, event, body) end,

  ---Send error response
  ---@param request table The original request
  ---@param message string The error message
  send_error = function(self, request, message) end
}

--------------------------------------------------------------------------------
-- DAP Message Types
--------------------------------------------------------------------------------

---@class DAPRequest
---@field seq number Sequence number
---@field type string Always "request"
---@field command string The command name
---@field arguments table|nil Command arguments

---@class DAPResponse
---@field seq number Sequence number
---@field type string Always "response"
---@field request_seq number The request sequence number
---@field success boolean Whether request succeeded
---@field command string The command name
---@field message string|nil Error message if failed
---@field body table|nil Response body

---@class DAPEvent
---@field seq number Sequence number
---@field type string Always "event"
---@field event string The event name
---@field body table|nil Event body

--------------------------------------------------------------------------------
-- DAP Capability Flags
--------------------------------------------------------------------------------

M.Capabilities = {
  supportsConfigurationDoneRequest = true,
  supportsFunctionBreakpoints = false,
  supportsConditionalBreakpoints = true,
  supportsHitConditionalBreakpoints = true,
  supportsEvaluateForHovers = true,
  supportsStepBack = false,
  supportsSetVariable = true,
  supportsRestartFrame = false,
  supportsGotoTargetsRequest = false,
  supportsStepInTargetsRequest = false,
  supportsCompletionsRequest = true,
  supportsModulesRequest = false,
  supportsExceptionOptions = false,
  supportsValueFormattingOptions = false,
  supportsExceptionInfoRequest = false,
  supportTerminateDebuggee = true,
  supportsDelayedStackTraceLoading = false,
  supportsLoadedSourcesRequest = false,
  supportsLogPoints = true,
  supportsTerminateThreadsRequest = false,
  supportsSetExpression = false,
  supportsTerminateRequest = true,
  supportsDataBreakpoints = false,
  supportsReadMemoryRequest = false,
  supportsDisassembleRequest = false,
  supportsCancelRequest = false,
  supportsBreakpointLocationsRequest = true,
  supportsClipboardContext = false,
  supportsSteppingGranularity = false,
  supportsInstructionBreakpoints = false,
  supportsExceptionFilterOptions = false
}

--------------------------------------------------------------------------------
-- Scope Reference Ranges
--------------------------------------------------------------------------------

-- Variable reference ranges for different scopes
M.ScopeRanges = {
  GLOBALS_START = 1000,
  GLOBALS_END = 1999,
  LOCALS_START = 2000,
  LOCALS_END = 2999,
  TEMPS_START = 3000,
  TEMPS_END = 3999,
  CONTAINERS_START = 10000
}

return M
