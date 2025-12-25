--- Input Normalizer
--- Unifies mouse, touch, and keyboard input into consistent semantic events.
---
--- This module provides a platform-agnostic input handling layer that converts
--- raw input events from different sources (mouse clicks, touch taps, keyboard)
--- into normalized semantic events that the game engine can consume.
---
--- Semantic events:
---   - select: User wants to choose/activate something (mouse click, tap, Enter key)
---   - context_menu: User wants context menu (right-click, long-press)
---   - navigate: User wants to move focus (arrow keys, swipe)
---   - scroll: User wants to scroll content (scroll wheel, vertical swipe)
---   - cancel: User wants to cancel/go back (Escape key, back button)
---
--- Usage:
---   local normalizer = InputNormalizer.new()
---   normalizer:on("select", function(data) print("Selected at", data.x, data.y) end)
---   -- Platform code calls these:
---   normalizer:on_mouse_click(x, y, "left")
---   normalizer:on_touch_tap(x, y)
---
--- @module whisker.platform.input.input_normalizer
--- @author Whisker Core Team
--- @license MIT

local InputNormalizer = {}
InputNormalizer._dependencies = {}
InputNormalizer.__index = InputNormalizer

--- Semantic event types
InputNormalizer.EVENT = {
  SELECT = "select",           -- Choose/activate (click, tap, Enter)
  CONTEXT_MENU = "context_menu", -- Right-click, long-press
  NAVIGATE = "navigate",       -- Move focus (arrows, swipe)
  SCROLL = "scroll",           -- Scroll content
  CANCEL = "cancel",           -- Cancel/back (Escape)
  TEXT_INPUT = "text_input",   -- Text character input
}

--- Navigation directions
InputNormalizer.DIRECTION = {
  UP = "up",
  DOWN = "down",
  LEFT = "left",
  RIGHT = "right",
  FORWARD = "forward",
  BACK = "back",
}

--- Input sources
InputNormalizer.SOURCE = {
  MOUSE = "mouse",
  TOUCH = "touch",
  KEYBOARD = "keyboard",
  GAMEPAD = "gamepad",
}

--- Create a new InputNormalizer instance
--- @param config table|nil Configuration options
--- @return InputNormalizer
function InputNormalizer.new(config, deps)
  deps = deps or {}
  local self = setmetatable({}, InputNormalizer)

  config = config or {}

  -- Event listeners (event_type -> array of callbacks)
  self._listeners = {}

  -- Current focus (for keyboard navigation)
  self._focus_index = 0
  self._max_focus = 0

  return self
end

--- Register event listener
--- @param event_type string Event type (from EVENT constants)
--- @param callback function Callback function(data)
--- @return function Unsubscribe function
function InputNormalizer:on(event_type, callback)
  if not self._listeners[event_type] then
    self._listeners[event_type] = {}
  end
  table.insert(self._listeners[event_type], callback)

  -- Return unsubscribe function
  return function()
    self:off(event_type, callback)
  end
end

--- Unregister event listener
--- @param event_type string Event type
--- @param callback function Callback to remove
function InputNormalizer:off(event_type, callback)
  local listeners = self._listeners[event_type]
  if not listeners then
    return
  end

  for i = #listeners, 1, -1 do
    if listeners[i] == callback then
      table.remove(listeners, i)
    end
  end
end

--- Trigger normalized event
--- @param event_type string Event type
--- @param data table Event data
function InputNormalizer:trigger(event_type, data)
  local listeners = self._listeners[event_type]
  if not listeners then
    return
  end

  for _, callback in ipairs(listeners) do
    local ok, err = pcall(callback, data)
    if not ok then
      -- Log error but continue with other listeners
      print("InputNormalizer: Error in listener:", err)
    end
  end
end

-- ============================================================
-- Mouse Input Handlers
-- ============================================================

--- Handle mouse click
--- @param x number X coordinate
--- @param y number Y coordinate
--- @param button string Button name ("left", "right", "middle")
function InputNormalizer:on_mouse_click(x, y, button)
  if button == "left" then
    self:trigger(InputNormalizer.EVENT.SELECT, {
      x = x,
      y = y,
      source = InputNormalizer.SOURCE.MOUSE,
    })
  elseif button == "right" then
    self:trigger(InputNormalizer.EVENT.CONTEXT_MENU, {
      x = x,
      y = y,
      source = InputNormalizer.SOURCE.MOUSE,
    })
  end
end

--- Handle mouse scroll
--- @param delta_x number Horizontal scroll amount
--- @param delta_y number Vertical scroll amount
function InputNormalizer:on_mouse_scroll(delta_x, delta_y)
  local direction
  if math.abs(delta_y) > math.abs(delta_x) then
    direction = delta_y > 0 and InputNormalizer.DIRECTION.UP or InputNormalizer.DIRECTION.DOWN
  else
    direction = delta_x > 0 and InputNormalizer.DIRECTION.LEFT or InputNormalizer.DIRECTION.RIGHT
  end

  self:trigger(InputNormalizer.EVENT.SCROLL, {
    delta_x = delta_x,
    delta_y = delta_y,
    direction = direction,
    source = InputNormalizer.SOURCE.MOUSE,
  })
end

-- ============================================================
-- Touch Input Handlers
-- ============================================================

--- Handle touch tap
--- @param x number X coordinate
--- @param y number Y coordinate
function InputNormalizer:on_touch_tap(x, y)
  self:trigger(InputNormalizer.EVENT.SELECT, {
    x = x,
    y = y,
    source = InputNormalizer.SOURCE.TOUCH,
  })
end

--- Handle touch long-press
--- @param x number X coordinate
--- @param y number Y coordinate
function InputNormalizer:on_touch_long_press(x, y)
  self:trigger(InputNormalizer.EVENT.CONTEXT_MENU, {
    x = x,
    y = y,
    source = InputNormalizer.SOURCE.TOUCH,
  })
end

--- Handle swipe gesture
--- @param direction string Swipe direction ("left", "right", "up", "down")
--- @param distance number Swipe distance in pixels
function InputNormalizer:on_swipe(direction, distance)
  -- Horizontal swipes map to navigation
  if direction == "left" then
    self:trigger(InputNormalizer.EVENT.NAVIGATE, {
      direction = InputNormalizer.DIRECTION.FORWARD,
      source = InputNormalizer.SOURCE.TOUCH,
    })
  elseif direction == "right" then
    self:trigger(InputNormalizer.EVENT.NAVIGATE, {
      direction = InputNormalizer.DIRECTION.BACK,
      source = InputNormalizer.SOURCE.TOUCH,
    })
  -- Vertical swipes map to scroll
  elseif direction == "up" then
    self:trigger(InputNormalizer.EVENT.SCROLL, {
      direction = InputNormalizer.DIRECTION.UP,
      distance = distance,
      source = InputNormalizer.SOURCE.TOUCH,
    })
  elseif direction == "down" then
    self:trigger(InputNormalizer.EVENT.SCROLL, {
      direction = InputNormalizer.DIRECTION.DOWN,
      distance = distance,
      source = InputNormalizer.SOURCE.TOUCH,
    })
  end
end

-- ============================================================
-- Keyboard Input Handlers
-- ============================================================

--- Handle key press
--- @param key string Key name (e.g., "Enter", "Escape", "ArrowUp")
--- @param modifiers table|nil Modifier keys (shift, ctrl, alt, meta)
function InputNormalizer:on_key_press(key, modifiers)
  modifiers = modifiers or {}

  -- Selection keys
  if key == "Enter" or key == "Return" or key == " " or key == "Space" then
    self:trigger(InputNormalizer.EVENT.SELECT, {
      source = InputNormalizer.SOURCE.KEYBOARD,
    })

  -- Cancel/back
  elseif key == "Escape" then
    self:trigger(InputNormalizer.EVENT.CANCEL, {
      source = InputNormalizer.SOURCE.KEYBOARD,
    })

  -- Navigation
  elseif key == "ArrowUp" or key == "Up" then
    self:trigger(InputNormalizer.EVENT.NAVIGATE, {
      direction = InputNormalizer.DIRECTION.UP,
      source = InputNormalizer.SOURCE.KEYBOARD,
    })
  elseif key == "ArrowDown" or key == "Down" then
    self:trigger(InputNormalizer.EVENT.NAVIGATE, {
      direction = InputNormalizer.DIRECTION.DOWN,
      source = InputNormalizer.SOURCE.KEYBOARD,
    })
  elseif key == "ArrowLeft" or key == "Left" then
    self:trigger(InputNormalizer.EVENT.NAVIGATE, {
      direction = InputNormalizer.DIRECTION.LEFT,
      source = InputNormalizer.SOURCE.KEYBOARD,
    })
  elseif key == "ArrowRight" or key == "Right" then
    self:trigger(InputNormalizer.EVENT.NAVIGATE, {
      direction = InputNormalizer.DIRECTION.RIGHT,
      source = InputNormalizer.SOURCE.KEYBOARD,
    })

  -- Tab navigation
  elseif key == "Tab" then
    local direction = modifiers.shift and InputNormalizer.DIRECTION.BACK or InputNormalizer.DIRECTION.FORWARD
    self:trigger(InputNormalizer.EVENT.NAVIGATE, {
      direction = direction,
      source = InputNormalizer.SOURCE.KEYBOARD,
    })

  -- Page navigation
  elseif key == "PageUp" then
    self:trigger(InputNormalizer.EVENT.SCROLL, {
      direction = InputNormalizer.DIRECTION.UP,
      page = true,
      source = InputNormalizer.SOURCE.KEYBOARD,
    })
  elseif key == "PageDown" then
    self:trigger(InputNormalizer.EVENT.SCROLL, {
      direction = InputNormalizer.DIRECTION.DOWN,
      page = true,
      source = InputNormalizer.SOURCE.KEYBOARD,
    })

  -- Home/End
  elseif key == "Home" then
    self:trigger(InputNormalizer.EVENT.NAVIGATE, {
      direction = InputNormalizer.DIRECTION.UP,
      to_start = true,
      source = InputNormalizer.SOURCE.KEYBOARD,
    })
  elseif key == "End" then
    self:trigger(InputNormalizer.EVENT.NAVIGATE, {
      direction = InputNormalizer.DIRECTION.DOWN,
      to_end = true,
      source = InputNormalizer.SOURCE.KEYBOARD,
    })
  end
end

--- Handle text input
--- @param text string Input text
function InputNormalizer:on_text_input(text)
  self:trigger(InputNormalizer.EVENT.TEXT_INPUT, {
    text = text,
    source = InputNormalizer.SOURCE.KEYBOARD,
  })
end

-- ============================================================
-- Gamepad Input Handlers
-- ============================================================

--- Handle gamepad button press
--- @param button string Button name (e.g., "A", "B", "Start")
function InputNormalizer:on_gamepad_button(button)
  -- A/X = select, B = cancel
  if button == "A" or button == "Cross" then
    self:trigger(InputNormalizer.EVENT.SELECT, {
      source = InputNormalizer.SOURCE.GAMEPAD,
    })
  elseif button == "B" or button == "Circle" then
    self:trigger(InputNormalizer.EVENT.CANCEL, {
      source = InputNormalizer.SOURCE.GAMEPAD,
    })
  elseif button == "Start" then
    self:trigger(InputNormalizer.EVENT.CONTEXT_MENU, {
      source = InputNormalizer.SOURCE.GAMEPAD,
    })
  end
end

--- Handle gamepad D-pad/stick
--- @param direction string Direction ("up", "down", "left", "right")
function InputNormalizer:on_gamepad_direction(direction)
  self:trigger(InputNormalizer.EVENT.NAVIGATE, {
    direction = direction,
    source = InputNormalizer.SOURCE.GAMEPAD,
  })
end

-- ============================================================
-- Focus Management
-- ============================================================

--- Set the maximum focusable item count
--- @param max number Maximum index
function InputNormalizer:set_focus_max(max)
  self._max_focus = max
  if self._focus_index > max then
    self._focus_index = max
  end
end

--- Get current focus index
--- @return number Focus index
function InputNormalizer:get_focus_index()
  return self._focus_index
end

--- Set focus index
--- @param index number New focus index
function InputNormalizer:set_focus_index(index)
  if index >= 0 and index <= self._max_focus then
    self._focus_index = index
  end
end

--- Move focus in direction
--- @param direction string Direction
--- @return number New focus index
function InputNormalizer:move_focus(direction)
  if direction == InputNormalizer.DIRECTION.UP or direction == InputNormalizer.DIRECTION.BACK then
    self._focus_index = math.max(0, self._focus_index - 1)
  elseif direction == InputNormalizer.DIRECTION.DOWN or direction == InputNormalizer.DIRECTION.FORWARD then
    self._focus_index = math.min(self._max_focus, self._focus_index + 1)
  end
  return self._focus_index
end

--- Remove all event listeners
function InputNormalizer:clear()
  self._listeners = {}
end

return InputNormalizer
