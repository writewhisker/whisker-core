-- whisker-debug/lib/stack_frame_manager.lua
-- Manages passage call stack for stack traces

local M = {}

local StackFrameManager = {}
StackFrameManager.__index = StackFrameManager

---Create a new StackFrameManager
---@return table
function StackFrameManager.new()
  local self = setmetatable({}, StackFrameManager)
  self.frames = {}
  self.next_id = 1
  return self
end

---Push a new frame onto the stack
---@param passage string The passage name
---@param source table The source location {path, line}
---@return number Frame ID
function StackFrameManager:push_frame(passage, source)
  local frame = {
    id = self.next_id,
    passage = passage,
    source = source or {},
    line = source and source.line or 0,
    locals = {},
    temps = {}
  }

  self.next_id = self.next_id + 1
  table.insert(self.frames, frame)

  return frame.id
end

---Pop the top frame from the stack
---@return table|nil The popped frame
function StackFrameManager:pop_frame()
  if #self.frames == 0 then
    return nil
  end
  return table.remove(self.frames)
end

---Get all stack frames in DAP format
---@return table[] Stack frames (newest first)
function StackFrameManager:get_stack_trace()
  local dap_frames = {}

  -- Reverse order: most recent frame first
  for i = #self.frames, 1, -1 do
    local frame = self.frames[i]
    local source_name = frame.source.path

    if source_name then
      source_name = source_name:match("([^/\\]+)$") or source_name
    else
      source_name = "<unknown>"
    end

    table.insert(dap_frames, {
      id = frame.id,
      name = frame.passage,
      source = {
        name = source_name,
        path = frame.source.path or ""
      },
      line = frame.line,
      column = 1,
      endLine = frame.line,
      endColumn = 1
    })
  end

  return dap_frames
end

---Get a specific frame by ID
---@param id number The frame ID
---@return table|nil The frame
function StackFrameManager:get_frame(id)
  for _, frame in ipairs(self.frames) do
    if frame.id == id then
      return frame
    end
  end
  return nil
end

---Get current stack depth
---@return number
function StackFrameManager:get_depth()
  return #self.frames
end

---Clear all frames
function StackFrameManager:clear()
  self.frames = {}
  self.next_id = 1
end

---Update the current frame's line
---@param line number The current line
function StackFrameManager:update_current_line(line)
  if #self.frames > 0 then
    self.frames[#self.frames].line = line
  end
end

---Get the current (top) frame
---@return table|nil
function StackFrameManager:get_current_frame()
  if #self.frames == 0 then
    return nil
  end
  return self.frames[#self.frames]
end

---Set local variables for current frame
---@param locals table The local variables
function StackFrameManager:set_locals(locals)
  if #self.frames > 0 then
    self.frames[#self.frames].locals = locals or {}
  end
end

---Set temp variables for current frame
---@param temps table The temp variables
function StackFrameManager:set_temps(temps)
  if #self.frames > 0 then
    self.frames[#self.frames].temps = temps or {}
  end
end

---Get locals for a specific frame
---@param frame_id number The frame ID
---@return table
function StackFrameManager:get_frame_locals(frame_id)
  local frame = self:get_frame(frame_id)
  return frame and frame.locals or {}
end

---Get temps for a specific frame
---@param frame_id number The frame ID
---@return table
function StackFrameManager:get_frame_temps(frame_id)
  local frame = self:get_frame(frame_id)
  return frame and frame.temps or {}
end

M.new = StackFrameManager.new

return M
