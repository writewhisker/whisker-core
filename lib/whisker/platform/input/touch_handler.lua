--- Touch Input Handler
--- Recognizes touch gestures and converts them to semantic events.
---
--- Supports:
---   - Tap: Quick touch and release
---   - Long-press: Touch and hold for configurable duration
---   - Swipe: Directional drag gesture (left, right, up, down)
---   - Pinch: Two-finger zoom gesture (optional)
---
--- Usage:
---   local handler = TouchHandler.new({
---     on_gesture = function(type, data) ... end,
---     long_press_duration = 500,
---     swipe_threshold = 50,
---   })
---
---   -- Platform code calls these when touch events occur:
---   handler:on_touch_start(x, y, timestamp)
---   handler:on_touch_move(x, y, timestamp)
---   handler:on_touch_end(x, y, timestamp)
---
--- @module whisker.platform.input.touch_handler
--- @author Whisker Core Team
--- @license MIT

local TouchHandler = {}
TouchHandler.__index = TouchHandler

--- Gesture types
TouchHandler.GESTURE = {
  TAP = "tap",
  LONG_PRESS = "long_press",
  SWIPE = "swipe",
  PINCH = "pinch",
}

--- Swipe directions
TouchHandler.DIRECTION = {
  LEFT = "left",
  RIGHT = "right",
  UP = "up",
  DOWN = "down",
}

--- Create a new TouchHandler instance
--- @param config table|nil Configuration options
---   config.on_gesture function: Callback for gesture events
---   config.long_press_duration number: Long-press delay in ms (default: 500)
---   config.swipe_threshold number: Min swipe distance in pixels (default: 50)
---   config.tap_timeout number: Max tap duration in ms (default: 300)
---   config.move_tolerance number: Max movement for tap in pixels (default: 10)
--- @return TouchHandler
function TouchHandler.new(config)
  local self = setmetatable({}, TouchHandler)

  config = config or {}

  -- Configuration
  self.on_gesture = config.on_gesture or function() end
  self.long_press_duration = config.long_press_duration or 500  -- ms
  self.swipe_threshold = config.swipe_threshold or 50            -- pixels
  self.tap_timeout = config.tap_timeout or 300                   -- ms
  self.move_tolerance = config.move_tolerance or 10              -- pixels

  -- State tracking
  self.touch_start = nil
  self.touch_timer = nil
  self.is_long_press = false
  self.has_moved = false

  -- Platform-specific timer functions (set by platform code)
  self.set_timeout_fn = config.set_timeout or nil
  self.cancel_timeout_fn = config.cancel_timeout or nil

  return self
end

--- Handle touch start event
--- @param x number X coordinate
--- @param y number Y coordinate
--- @param timestamp number Event timestamp in ms
--- @param touch_id any|nil Optional touch identifier for multi-touch
function TouchHandler:on_touch_start(x, y, timestamp, touch_id)
  self.touch_start = {
    x = x,
    y = y,
    time = timestamp or self:_get_time(),
    id = touch_id,
  }
  self.is_long_press = false
  self.has_moved = false

  -- Start long-press timer
  if self.set_timeout_fn then
    self.touch_timer = self.set_timeout_fn(self.long_press_duration, function()
      if self.touch_start and not self.has_moved then
        self.is_long_press = true
        self:_trigger_gesture(TouchHandler.GESTURE.LONG_PRESS, {
          x = self.touch_start.x,
          y = self.touch_start.y,
        })
      end
    end)
  end
end

--- Handle touch move event
--- @param x number X coordinate
--- @param y number Y coordinate
--- @param timestamp number Event timestamp in ms
--- @param touch_id any|nil Optional touch identifier
function TouchHandler:on_touch_move(x, y, timestamp, touch_id)
  if not self.touch_start then
    return
  end

  -- Check if touch ID matches (for multi-touch)
  if touch_id and self.touch_start.id and touch_id ~= self.touch_start.id then
    return
  end

  local dx = x - self.touch_start.x
  local dy = y - self.touch_start.y
  local distance = math.sqrt(dx * dx + dy * dy)

  -- If moved beyond tolerance, cancel potential tap/long-press
  if distance > self.move_tolerance then
    self.has_moved = true

    -- Cancel long-press timer
    if self.touch_timer and self.cancel_timeout_fn then
      self.cancel_timeout_fn(self.touch_timer)
      self.touch_timer = nil
    end
  end
end

--- Handle touch end event
--- @param x number X coordinate
--- @param y number Y coordinate
--- @param timestamp number Event timestamp in ms
--- @param touch_id any|nil Optional touch identifier
function TouchHandler:on_touch_end(x, y, timestamp, touch_id)
  if not self.touch_start then
    return
  end

  -- Check if touch ID matches
  if touch_id and self.touch_start.id and touch_id ~= self.touch_start.id then
    return
  end

  -- Cancel long-press timer
  if self.touch_timer and self.cancel_timeout_fn then
    self.cancel_timeout_fn(self.touch_timer)
    self.touch_timer = nil
  end

  -- Don't process if long-press already triggered
  if self.is_long_press then
    self:_reset()
    return
  end

  local dx = x - self.touch_start.x
  local dy = y - self.touch_start.y
  local distance = math.sqrt(dx * dx + dy * dy)
  local duration = (timestamp or self:_get_time()) - self.touch_start.time

  -- Check for swipe gesture
  if distance >= self.swipe_threshold then
    local direction = self:_get_swipe_direction(dx, dy)
    self:_trigger_gesture(TouchHandler.GESTURE.SWIPE, {
      direction = direction,
      distance = distance,
      velocity = distance / (duration or 1),
      start_x = self.touch_start.x,
      start_y = self.touch_start.y,
      end_x = x,
      end_y = y,
    })
  elseif not self.has_moved and duration <= self.tap_timeout then
    -- Simple tap
    self:_trigger_gesture(TouchHandler.GESTURE.TAP, {
      x = x,
      y = y,
    })
  end

  self:_reset()
end

--- Handle touch cancel event (e.g., system gesture interrupted)
--- @param touch_id any|nil Optional touch identifier
function TouchHandler:on_touch_cancel(touch_id)
  if self.touch_timer and self.cancel_timeout_fn then
    self.cancel_timeout_fn(self.touch_timer)
    self.touch_timer = nil
  end
  self:_reset()
end

--- Determine swipe direction from delta
--- @param dx number X delta
--- @param dy number Y delta
--- @return string Direction ("left", "right", "up", "down")
function TouchHandler:_get_swipe_direction(dx, dy)
  local abs_dx = math.abs(dx)
  local abs_dy = math.abs(dy)

  if abs_dx > abs_dy then
    return dx > 0 and TouchHandler.DIRECTION.RIGHT or TouchHandler.DIRECTION.LEFT
  else
    return dy > 0 and TouchHandler.DIRECTION.DOWN or TouchHandler.DIRECTION.UP
  end
end

--- Trigger gesture event
--- @param gesture_type string Gesture type
--- @param data table Gesture data
function TouchHandler:_trigger_gesture(gesture_type, data)
  if self.on_gesture then
    self.on_gesture(gesture_type, data)
  end
end

--- Reset touch state
function TouchHandler:_reset()
  self.touch_start = nil
  self.is_long_press = false
  self.has_moved = false
end

--- Get current timestamp (fallback if not provided)
--- @return number Timestamp in ms
function TouchHandler:_get_time()
  -- Platform-specific time function, or fallback
  if os and os.clock then
    return os.clock() * 1000
  end
  return 0
end

--- Update configuration
--- @param config table New configuration values
function TouchHandler:configure(config)
  if config.on_gesture then
    self.on_gesture = config.on_gesture
  end
  if config.long_press_duration then
    self.long_press_duration = config.long_press_duration
  end
  if config.swipe_threshold then
    self.swipe_threshold = config.swipe_threshold
  end
  if config.tap_timeout then
    self.tap_timeout = config.tap_timeout
  end
  if config.move_tolerance then
    self.move_tolerance = config.move_tolerance
  end
  if config.set_timeout then
    self.set_timeout_fn = config.set_timeout
  end
  if config.cancel_timeout then
    self.cancel_timeout_fn = config.cancel_timeout
  end
end

return TouchHandler
