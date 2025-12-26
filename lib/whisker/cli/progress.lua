--- CLI Progress Bar
-- Progress indicator for batch operations
-- @module whisker.cli.progress
-- @author Whisker Core Team
-- @license MIT

local M = {}
M._dependencies = {"console"}

--- Create a new progress bar
-- @param deps table Dependencies (console)
-- @param total number Total items to process
-- @param options table|nil Options {width, show_eta}
-- @return Progress Progress instance
function M.new(deps, total, options)
  local self = setmetatable({}, {__index = M})
  self._console = deps.console or {
    write = function(_, text) io.write(text) end,
    print = function(_, text) print(text) end
  }
  self._total = total
  self._current = 0
  self._start_time = os.time()
  self._width = options and options.width or 40
  self._show_eta = (options == nil) or (options.show_eta ~= false)
  self._items = {}
  return self
end

--- Update progress to specific value
-- @param current number Current progress value
-- @param message string|nil Optional message
function M:update(current, message)
  self._current = current
  if message then
    table.insert(self._items, {
      index = current,
      message = message,
      time = os.time()
    })
  end

  self:render()
end

--- Increment progress by one
-- @param message string|nil Optional message
function M:increment(message)
  self:update(self._current + 1, message)
end

--- Render the progress bar
function M:render()
  local percent = self._total > 0 and self._current / self._total or 0
  local filled = math.floor(percent * self._width)
  local empty = self._width - filled

  local bar = string.rep("=", filled) .. string.rep("-", empty)
  local pct_str = string.format("%3d%%", math.floor(percent * 100))

  local eta_str = ""
  if self._show_eta and self._current > 0 and self._current < self._total then
    local elapsed = os.time() - self._start_time
    if elapsed > 0 then
      local remaining = (elapsed / self._current) * (self._total - self._current)
      eta_str = string.format(" ETA: %ds", math.ceil(remaining))
    end
  end

  local status = string.format(
    "\r[%s] %s (%d/%d)%s",
    bar, pct_str, self._current, self._total, eta_str
  )

  self._console:write(status)
end

--- Finish progress (set to 100%)
-- @param message string|nil Optional completion message
function M:finish(message)
  self._current = self._total
  self:render()
  self._console:print("")  -- New line
  if message then
    self._console:print(message)
  end
end

--- Get elapsed time in seconds
-- @return number Elapsed seconds
function M:get_elapsed()
  return os.time() - self._start_time
end

--- Get current progress percentage
-- @return number Percentage (0-100)
function M:get_percentage()
  if self._total == 0 then return 0 end
  return math.floor((self._current / self._total) * 100)
end

--- Check if progress is complete
-- @return boolean True if complete
function M:is_complete()
  return self._current >= self._total
end

return M
