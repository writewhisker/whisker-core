-- whisker-debug/lib/breakpoint_manager.lua
-- Breakpoint storage and verification

local M = {}

local BreakpointManager = {}
BreakpointManager.__index = BreakpointManager

---Create a new BreakpointManager
---@return table
function BreakpointManager.new()
  local self = setmetatable({}, BreakpointManager)
  self.breakpoints = {} -- file -> {line -> breakpoint_info}
  self.hit_counts = {}  -- file:line -> hit count
  return self
end

---Set breakpoints for a file
---@param file string The file path
---@param lines number[] The line numbers
---@param breakpoint_objects table[] The breakpoint specifications
---@return table[] Verified breakpoints
function BreakpointManager:set_breakpoints(file, lines, breakpoint_objects)
  -- Clear existing breakpoints for this file
  self.breakpoints[file] = {}

  local verified = {}
  for i, line in ipairs(lines) do
    local bp = breakpoint_objects[i] or {}

    self.breakpoints[file][line] = {
      line = line,
      condition = bp.condition,
      hitCondition = bp.hitCondition,
      logMessage = bp.logMessage,
      enabled = true
    }

    -- Reset hit count
    local key = file .. ":" .. line
    self.hit_counts[key] = 0

    table.insert(verified, {
      verified = true,
      line = line,
      id = i
    })
  end

  return verified
end

---Check if a breakpoint exists at location
---@param file string The file path
---@param line number The line number
---@return boolean
function BreakpointManager:has_breakpoint(file, line)
  if not self.breakpoints[file] then
    return false
  end

  local bp = self.breakpoints[file][line]
  return bp ~= nil and bp.enabled
end

---Get breakpoint info at location
---@param file string The file path
---@param line number The line number
---@return table|nil
function BreakpointManager:get_breakpoint(file, line)
  if not self.breakpoints[file] then
    return nil
  end

  return self.breakpoints[file][line]
end

---Get condition for a breakpoint
---@param file string The file path
---@param line number The line number
---@return string|nil
function BreakpointManager:get_condition(file, line)
  local bp = self:get_breakpoint(file, line)
  return bp and bp.condition
end

---Check if conditional breakpoint should trigger
---@param file string The file path
---@param line number The line number
---@param state table The current story state
---@return boolean
function BreakpointManager:check_condition(file, line, state)
  local condition = self:get_condition(file, line)
  if not condition then
    return true  -- No condition, always break
  end

  -- Try to evaluate condition in story state context
  local func, err = load("return " .. condition, "breakpoint_condition", "t", state)
  if not func then
    -- Invalid condition syntax, don't break
    return false
  end

  local ok, result = pcall(func)
  return ok and result == true
end

---Check if hit count condition is met
---@param file string The file path
---@param line number The line number
---@return boolean
function BreakpointManager:check_hit_count(file, line)
  local bp = self:get_breakpoint(file, line)
  if not bp or not bp.hitCondition then
    return true  -- No hit condition, always break
  end

  local key = file .. ":" .. line
  self.hit_counts[key] = (self.hit_counts[key] or 0) + 1
  local hits = self.hit_counts[key]

  -- Parse hit condition (e.g., ">= 5", "== 3", "> 10")
  local op, value = bp.hitCondition:match("([<>=!]+)%s*(%d+)")
  if not op or not value then
    -- Try simple number (break on Nth hit)
    value = tonumber(bp.hitCondition)
    if value then
      return hits == value
    end
    return true
  end

  value = tonumber(value)
  if not value then return true end

  if op == ">=" then return hits >= value end
  if op == ">" then return hits > value end
  if op == "==" then return hits == value end
  if op == "<=" then return hits <= value end
  if op == "<" then return hits < value end
  if op == "!=" or op == "~=" then return hits ~= value end

  return true
end

---Check if breakpoint should trigger (all conditions)
---@param file string The file path
---@param line number The line number
---@param state table The current story state
---@return boolean should_break
---@return string|nil log_message
function BreakpointManager:should_break(file, line, state)
  local bp = self:get_breakpoint(file, line)
  if not bp or not bp.enabled then
    return false, nil
  end

  -- Check hit count first (always increment)
  if not self:check_hit_count(file, line) then
    return false, nil
  end

  -- Check condition
  if not self:check_condition(file, line, state) then
    return false, nil
  end

  -- Check if it's a logpoint
  if bp.logMessage then
    local message = self:format_log_message(bp.logMessage, state)
    return false, message  -- Don't break, just log
  end

  return true, nil
end

---Format log message with variable interpolation
---@param template string The log message template
---@param state table The current story state
---@return string
function BreakpointManager:format_log_message(template, state)
  -- Replace {varname} with actual values
  return template:gsub("{([%w_]+)}", function(var)
    local value = state[var]
    if value ~= nil then
      return tostring(value)
    end
    return "{" .. var .. "}"
  end)
end

---Clear all breakpoints for a file
---@param file string The file path
function BreakpointManager:clear_breakpoints(file)
  self.breakpoints[file] = nil
end

---Clear all breakpoints
function BreakpointManager:clear_all()
  self.breakpoints = {}
  self.hit_counts = {}
end

---Enable/disable a breakpoint
---@param file string The file path
---@param line number The line number
---@param enabled boolean Whether to enable
function BreakpointManager:set_enabled(file, line, enabled)
  local bp = self:get_breakpoint(file, line)
  if bp then
    bp.enabled = enabled
  end
end

---Get all breakpoints for a file
---@param file string The file path
---@return table[] Breakpoints
function BreakpointManager:get_breakpoints_for_file(file)
  local result = {}
  if self.breakpoints[file] then
    for line, bp in pairs(self.breakpoints[file]) do
      table.insert(result, {
        line = line,
        condition = bp.condition,
        hitCondition = bp.hitCondition,
        logMessage = bp.logMessage,
        enabled = bp.enabled
      })
    end
  end
  -- Sort by line number
  table.sort(result, function(a, b) return a.line < b.line end)
  return result
end

M.new = BreakpointManager.new

return M
