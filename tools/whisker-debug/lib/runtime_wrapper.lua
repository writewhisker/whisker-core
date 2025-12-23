-- whisker-debug/lib/runtime_wrapper.lua
-- Instrumented whisker runtime with breakpoint support

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
local StackFrameManager = try_require("lib.stack_frame_manager", "whisker-debug.lib.stack_frame_manager")

-- Fallback interfaces
if not interfaces then
  interfaces = {
    StopReason = {
      STEP = "step",
      BREAKPOINT = "breakpoint",
      PAUSE = "pause"
    },
    StepMode = {
      INTO = "into",
      OVER = "over",
      OUT = "out"
    }
  }
end

local RuntimeWrapper = {}
RuntimeWrapper.__index = RuntimeWrapper

---Create a new RuntimeWrapper
---@param story_file string The story file path
---@return table
function RuntimeWrapper.new(story_file)
  local self = setmetatable({}, RuntimeWrapper)
  self.story_file = story_file
  self.runtime = nil
  self.breakpoint_manager = nil
  self.stack_manager = StackFrameManager.new()
  self.paused = false
  self.ended = false
  self.step_mode = nil
  self.step_depth = nil
  self.passage_locations = {}
  self.current_passage = nil
  self.state = {}

  -- Callbacks
  self.on_pause_callback = nil
  self.on_continue_callback = nil
  self.on_end_callback = nil
  self.on_output_callback = nil

  return self
end

---Load and parse the story file
---@return boolean success
---@return string|nil error
function RuntimeWrapper:load_story()
  -- Try to read the file
  local file, err = io.open(self.story_file, "r")
  if not file then
    return false, "Cannot open file: " .. tostring(err)
  end

  local content = file:read("*a")
  file:close()

  -- Parse to find passage locations
  self:parse_passage_locations(content)

  -- Try to load whisker runtime
  local ok, runtime_module = pcall(require, "whisker.runtime")
  if ok then
    self.runtime = runtime_module.new()
    local load_ok, load_err = self.runtime:load_file(self.story_file)
    if not load_ok then
      return false, "Failed to load story: " .. tostring(load_err)
    end
  else
    -- Fallback: simulate runtime for debugging purposes
    self.runtime = self:create_mock_runtime(content)
  end

  return true, nil
end

---Parse passage locations from story content
---@param content string The story content
function RuntimeWrapper:parse_passage_locations(content)
  local line_num = 1
  local format = self:detect_format()

  for line in content:gmatch("([^\n]*)\n?") do
    local passage_name = nil

    if format == "ink" then
      -- Match Ink passage: === PassageName ===
      passage_name = line:match("^%s*===+%s*([%w_]+)%s*===+")
    elseif format == "twee" then
      -- Match Twee passage: :: PassageName
      passage_name = line:match("^::%s*([^%[%{]+)")
      if passage_name then
        passage_name = passage_name:match("^%s*(.-)%s*$")  -- trim
      end
    elseif format == "wscript" then
      -- Match WhiskerScript passage: passage "PassageName"
      passage_name = line:match('^%s*passage%s+"([^"]+)"')
    end

    if passage_name then
      self.passage_locations[passage_name] = {
        file = self.story_file,
        line = line_num
      }
    end

    line_num = line_num + 1
  end
end

---Detect story format from file extension
---@return string Format: "ink", "twee", or "wscript"
function RuntimeWrapper:detect_format()
  local ext = self.story_file:match("%.([^%.]+)$")
  if ext == "ink" then
    return "ink"
  elseif ext == "twee" or ext == "tw" then
    return "twee"
  elseif ext == "wscript" then
    return "wscript"
  end
  return "ink"  -- default
end

---Create a mock runtime for testing without whisker-core
---@param content string The story content
---@return table
function RuntimeWrapper:create_mock_runtime(content)
  local mock = {}

  mock.passages = {}
  mock.current = nil
  mock.state = {}

  -- Parse passages
  for name, _ in pairs(self.passage_locations) do
    mock.passages[name] = {name = name, content = "", choices = {}}
  end

  mock.goto_passage = function(_, name)
    mock.current = name
    return true
  end

  mock.get_state = function()
    return mock.state
  end

  mock.get_current_passage = function()
    return mock.current and {name = mock.current} or nil
  end

  mock.get_choices = function()
    return {}
  end

  mock.choose = function(_, index)
    return true
  end

  mock.start = function()
    mock.current = "Start"
  end

  return mock
end

---Set the breakpoint manager
---@param manager table BreakpointManager instance
function RuntimeWrapper:set_breakpoint_manager(manager)
  self.breakpoint_manager = manager
end

---Wrap the runtime with instrumentation
function RuntimeWrapper:wrap()
  if not self.runtime then return end

  local original_goto = self.runtime.goto_passage

  self.runtime.goto_passage = function(rt, passage_name)
    -- Track in call stack
    local location = self.passage_locations[passage_name]
    self.stack_manager:push_frame(passage_name, location)
    self.current_passage = passage_name

    -- Check breakpoint
    if location and self.breakpoint_manager then
      local state = self:get_state()
      local should_break, log_message = self.breakpoint_manager:should_break(
        location.file, location.line, state
      )

      if log_message and self.on_output_callback then
        self.on_output_callback(log_message)
      end

      if should_break then
        self:pause(interfaces.StopReason.BREAKPOINT, {
          passage = passage_name,
          file = location.file,
          line = location.line
        })
      end
    end

    -- Check step mode
    if self.step_mode then
      self:check_step_stop(passage_name)
    end

    return original_goto(rt, passage_name)
  end
end

---Start story execution
function RuntimeWrapper:start()
  if self.runtime and self.runtime.start then
    self:wrap()
    self.runtime:start()
  end
end

---Pause execution
---@param reason string The stop reason
---@param data table Additional data
function RuntimeWrapper:pause(reason, data)
  self.paused = true

  if self.on_pause_callback then
    self.on_pause_callback(reason, data)
  end
end

---Resume execution
function RuntimeWrapper:continue()
  self.paused = false
  self.step_mode = nil
  self.step_depth = nil

  if self.on_continue_callback then
    self.on_continue_callback()
  end
end

---Execute step into
function RuntimeWrapper:step_into()
  self.step_mode = interfaces.StepMode.INTO
  self.step_depth = self.stack_manager:get_depth()
  self.paused = false
end

---Execute step over
function RuntimeWrapper:step_over()
  self.step_mode = interfaces.StepMode.OVER
  self.step_depth = self.stack_manager:get_depth()
  self.paused = false
end

---Execute step out
function RuntimeWrapper:step_out()
  self.step_mode = interfaces.StepMode.OUT
  self.step_depth = self.stack_manager:get_depth() - 1
  self.paused = false
end

---Check if we should stop for step command
---@param passage_name string Current passage
function RuntimeWrapper:check_step_stop(passage_name)
  local current_depth = self.stack_manager:get_depth()

  local should_stop = false

  if self.step_mode == interfaces.StepMode.INTO then
    -- Always stop on next passage
    should_stop = true
  elseif self.step_mode == interfaces.StepMode.OVER then
    -- Stop if at same or lower depth
    should_stop = current_depth <= self.step_depth
  elseif self.step_mode == interfaces.StepMode.OUT then
    -- Stop if at lower depth
    should_stop = current_depth <= self.step_depth
  end

  if should_stop then
    local location = self.passage_locations[passage_name]
    self:pause(interfaces.StopReason.STEP, {
      passage = passage_name,
      file = location and location.file or self.story_file,
      line = location and location.line or 0
    })
  end
end

---Get current state
---@return table
function RuntimeWrapper:get_state()
  if self.runtime and self.runtime.get_state then
    return self.runtime:get_state() or self.state
  end
  return self.state
end

---Get current passage
---@return table|nil
function RuntimeWrapper:get_current_passage()
  if self.runtime and self.runtime.get_current_passage then
    return self.runtime:get_current_passage()
  end
  return self.current_passage and {name = self.current_passage} or nil
end

---Get available choices
---@return table[]
function RuntimeWrapper:get_choices()
  if self.runtime and self.runtime.get_choices then
    return self.runtime:get_choices() or {}
  end
  return {}
end

---Make a choice
---@param index number The choice index
function RuntimeWrapper:choose(index)
  if self.runtime and self.runtime.choose then
    self.runtime:choose(index)
  end
end

---Evaluate an expression in story context
---@param expression string The expression
---@param frame_id number|nil The frame ID for context
---@return boolean success
---@return any result_or_error
function RuntimeWrapper:evaluate(expression, frame_id)
  local context = self:get_state()

  -- Add frame-specific context if available
  if frame_id then
    local frame = self.stack_manager:get_frame(frame_id)
    if frame then
      local locals = frame.locals or {}
      local temps = frame.temps or {}
      for k, v in pairs(locals) do context[k] = v end
      for k, v in pairs(temps) do context[k] = v end
    end
  end

  local func, err = load("return " .. expression, "eval", "t", context)
  if not func then
    -- Try as statement
    func, err = load(expression, "eval", "t", context)
    if not func then
      return false, err
    end
  end

  return pcall(func)
end

---Check if execution is paused
---@return boolean
function RuntimeWrapper:is_paused()
  return self.paused
end

---Check if story has ended
---@return boolean
function RuntimeWrapper:is_ended()
  return self.ended
end

---Get the stack frame manager
---@return table
function RuntimeWrapper:get_stack_manager()
  return self.stack_manager
end

---Get passage location info
---@param passage_name string
---@return table|nil
function RuntimeWrapper:get_passage_location(passage_name)
  return self.passage_locations[passage_name]
end

---Register pause callback
---@param callback function
function RuntimeWrapper:on_pause(callback)
  self.on_pause_callback = callback
end

---Register continue callback
---@param callback function
function RuntimeWrapper:on_continue(callback)
  self.on_continue_callback = callback
end

---Register end callback
---@param callback function
function RuntimeWrapper:on_end(callback)
  self.on_end_callback = callback
end

---Register output callback
---@param callback function
function RuntimeWrapper:on_output(callback)
  self.on_output_callback = callback
end

---Stop the runtime
function RuntimeWrapper:stop()
  self.ended = true
  if self.on_end_callback then
    self.on_end_callback()
  end
end

M.new = RuntimeWrapper.new

return M
