--- WLS 2.0 Timed Content Manager
-- Manages delayed and scheduled content delivery for narrative timing.
--
-- @module whisker.wls2.timed_content
-- @author Whisker Team
-- @license MIT

local M = {}

-- Dependencies for DI pattern
M._dependencies = {}

--- Timer event types
M.EVENTS = {
  CREATED = "timerCreated",
  FIRED = "timerFired",
  CANCELED = "timerCanceled",
  PAUSED = "timerPaused",
  RESUMED = "timerResumed",
}

--- Generate a unique timer ID
local function generate_id(prefix)
  prefix = prefix or "timer"
  return string.format("%s_%d_%d", prefix, os.time(), math.random(10000, 99999))
end

--- Parse a time string to milliseconds
-- @tparam string time_str Time string like "500ms", "2s", "1000"
-- @treturn number Duration in milliseconds
function M.parse_time_string(time_str)
  time_str = time_str:match("^%s*(.-)%s*$")  -- Trim

  local num, unit = time_str:match("^(%d+%.?%d*)(%a*)$")
  if not num then
    error("Invalid time format: " .. time_str)
  end

  local ms = tonumber(num)
  if unit == "s" then
    ms = ms * 1000
  elseif unit ~= "" and unit ~= "ms" then
    error("Invalid time unit: " .. unit)
  end

  return ms
end

--- Timed Content Manager class
-- @type TimedContentManager
local TimedContentManager = {}
TimedContentManager.__index = TimedContentManager

--- Create a new TimedContentManager
-- @tparam[opt] table deps Injected dependencies (unused, for DI compatibility)
-- @treturn TimedContentManager New manager instance
function M.new(deps)
  -- deps parameter for DI compatibility (currently unused)
  local self = setmetatable({}, TimedContentManager)

  self.blocks = {}
  self.paused = false
  self.pause_time = 0
  self.next_id = 1
  self.listeners = {}
  self.current_time = 0

  return self
end

--- Add an event listener
-- @tparam function callback Listener function(event, block)
function TimedContentManager:on(callback)
  table.insert(self.listeners, callback)
end

--- Remove an event listener
-- @tparam function callback Listener to remove
function TimedContentManager:off(callback)
  for i, listener in ipairs(self.listeners) do
    if listener == callback then
      table.remove(self.listeners, i)
      return
    end
  end
end

--- Emit an event to all listeners
-- @tparam string event Event name
-- @tparam table block Timer block involved
function TimedContentManager:emit(event, block)
  for _, listener in ipairs(self.listeners) do
    listener(event, block)
  end
end

--- Schedule content to be displayed after a delay
-- @tparam number delay Delay in milliseconds
-- @tparam table content Content nodes to display
-- @tparam[opt] table options Scheduling options
-- @treturn string Timer ID
function TimedContentManager:schedule(delay, content, options)
  options = options or {}

  local id = options.id or ("timer_" .. self.next_id)
  self.next_id = self.next_id + 1

  local block = {
    id = id,
    delay = delay,
    content = content,
    start_time = self.current_time,
    is_repeat = options.is_repeat or false,
    fire_count = 0,
    max_fires = options.max_fires or 0,  -- 0 = unlimited
    on_fire = options.on_fire,
    active = true,
  }

  self.blocks[id] = block
  self:emit(M.EVENTS.CREATED, block)

  return id
end

--- Schedule repeating content
-- @tparam number interval Interval in milliseconds
-- @tparam table content Content nodes to display
-- @tparam[opt] table options Scheduling options
-- @treturn string Timer ID
function TimedContentManager:schedule_repeat(interval, content, options)
  options = options or {}
  options.is_repeat = true
  return self:schedule(interval, content, options)
end

--- Cancel a scheduled timer
-- @tparam string timer_id Timer ID to cancel
function TimedContentManager:cancel(timer_id)
  local block = self.blocks[timer_id]
  if block then
    block.active = false
    self:emit(M.EVENTS.CANCELED, block)
    self.blocks[timer_id] = nil
  end
end

--- Cancel all timers
function TimedContentManager:cancel_all()
  for id in pairs(self.blocks) do
    self:cancel(id)
  end
end

--- Pause all timers
function TimedContentManager:pause()
  if not self.paused then
    self.paused = true
    self.pause_time = self.current_time
    for _, block in pairs(self.blocks) do
      self:emit(M.EVENTS.PAUSED, block)
    end
  end
end

--- Resume all timers
function TimedContentManager:resume()
  if self.paused then
    local pause_duration = self.current_time - self.pause_time

    -- Adjust start times for all active timers
    for _, block in pairs(self.blocks) do
      if block.active then
        block.start_time = block.start_time + pause_duration
      end
      self:emit(M.EVENTS.RESUMED, block)
    end

    self.paused = false
  end
end

--- Check if manager is paused
-- @treturn boolean True if paused
function TimedContentManager:is_paused()
  return self.paused
end

--- Update the manager with elapsed time
-- @tparam number delta_ms Milliseconds since last update
-- @treturn table Array of fired content
function TimedContentManager:update(delta_ms)
  if self.paused then
    return {}
  end

  self.current_time = self.current_time + delta_ms
  local fired_content = {}

  for id, block in pairs(self.blocks) do
    if block.active then
      local elapsed = self.current_time - block.start_time

      if elapsed >= block.delay then
        -- Timer fired
        block.fire_count = block.fire_count + 1

        -- Add content to fired list
        for _, content in ipairs(block.content) do
          table.insert(fired_content, content)
        end

        -- Call callback if present
        if block.on_fire then
          block.on_fire(block)
        end

        self:emit(M.EVENTS.FIRED, block)

        if block.is_repeat then
          -- Check max fires
          if block.max_fires > 0 and block.fire_count >= block.max_fires then
            block.active = false
            self.blocks[id] = nil
          else
            -- Reset for next fire
            block.start_time = self.current_time
          end
        else
          -- One-shot timer, remove it
          block.active = false
          self.blocks[id] = nil
        end
      end
    end
  end

  return fired_content
end

--- Get a timer block by ID
-- @tparam string timer_id Timer ID
-- @treturn table|nil Timer block or nil
function TimedContentManager:get_timer(timer_id)
  return self.blocks[timer_id]
end

--- Get all active timers
-- @treturn table Array of active timer blocks
function TimedContentManager:get_active_timers()
  local active = {}
  for _, block in pairs(self.blocks) do
    if block.active then
      table.insert(active, block)
    end
  end
  return active
end

--- Get remaining time for a timer
-- @tparam string timer_id Timer ID
-- @treturn number|nil Remaining milliseconds or nil
function TimedContentManager:get_remaining(timer_id)
  local block = self.blocks[timer_id]
  if block and block.active then
    local elapsed = self.current_time - block.start_time
    return math.max(0, block.delay - elapsed)
  end
  return nil
end

--- Reset the manager
function TimedContentManager:reset()
  self.blocks = {}
  self.paused = false
  self.pause_time = 0
  self.current_time = 0
end

return M
