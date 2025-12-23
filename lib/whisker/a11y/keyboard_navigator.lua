--- Keyboard Navigator
-- Handles keyboard navigation for accessible UI
-- @module whisker.a11y.keyboard_navigator
-- @author Whisker Core Team
-- @license MIT

local KeyboardNavigator = {}
KeyboardNavigator.__index = KeyboardNavigator

-- Dependencies
KeyboardNavigator._dependencies = {"event_bus", "logger", "focus_manager"}

-- Key codes and names
local KEY_CODES = {
  TAB = 9,
  ENTER = 13,
  ESCAPE = 27,
  SPACE = 32,
  END = 35,
  HOME = 36,
  LEFT = 37,
  UP = 38,
  RIGHT = 39,
  DOWN = 40,
}

local KEY_NAMES = {
  [9] = "Tab",
  [13] = "Enter",
  [27] = "Escape",
  [32] = "Space",
  [35] = "End",
  [36] = "Home",
  [37] = "ArrowLeft",
  [38] = "ArrowUp",
  [39] = "ArrowRight",
  [40] = "ArrowDown",
}

--- Create a new KeyboardNavigator
-- @param deps table Dependency container
-- @return KeyboardNavigator The new navigator instance
function KeyboardNavigator.new(deps)
  local self = setmetatable({}, KeyboardNavigator)

  self.events = deps and deps.event_bus
  self.log = deps and deps.logger
  self.focus_manager = deps and deps.focus_manager

  -- Navigation state
  self._enabled = true
  self._mode = "browse" -- "browse" or "focus"
  self._handlers = {}

  -- Choice navigation state
  self._current_choice_index = 0
  self._choice_list = {}

  -- Register default handlers
  self:_register_default_handlers()

  return self
end

--- Factory method for DI container
-- @param deps table Dependencies
-- @return KeyboardNavigator
function KeyboardNavigator.create(deps)
  return KeyboardNavigator.new(deps)
end

--- Register default keyboard handlers
function KeyboardNavigator:_register_default_handlers()
  -- Tab navigation
  self:register_handler("Tab", function(event)
    if self.focus_manager then
      return self.focus_manager:handle_tab(event.shift)
    end
    return false
  end)

  -- Escape to close dialogs/modals
  self:register_handler("Escape", function(event)
    if self.events then
      self.events:emit("a11y.escape_pressed")
    end
    return true
  end)

  -- Enter/Space to activate
  self:register_handler("Enter", function(event)
    if self.events then
      self.events:emit("a11y.activate")
    end
    return true
  end)

  self:register_handler("Space", function(event)
    if self.events then
      self.events:emit("a11y.activate")
    end
    return true
  end)

  -- Arrow key navigation for choices
  self:register_handler("ArrowDown", function(event)
    return self:_navigate_choice(1)
  end)

  self:register_handler("ArrowUp", function(event)
    return self:_navigate_choice(-1)
  end)

  self:register_handler("ArrowRight", function(event)
    return self:_navigate_choice(1)
  end)

  self:register_handler("ArrowLeft", function(event)
    return self:_navigate_choice(-1)
  end)

  -- Home/End for first/last choice
  self:register_handler("Home", function(event)
    return self:_navigate_to_choice(1)
  end)

  self:register_handler("End", function(event)
    return self:_navigate_to_choice(#self._choice_list)
  end)
end

--- Register a keyboard handler
-- @param key string The key name (e.g., "Tab", "Enter")
-- @param handler function The handler function(event) -> boolean
function KeyboardNavigator:register_handler(key, handler)
  if not self._handlers[key] then
    self._handlers[key] = {}
  end
  table.insert(self._handlers[key], handler)
end

--- Handle a keyboard event
-- @param event table The keyboard event {key, keyCode, shift, ctrl, alt, meta}
-- @return boolean True if the event was handled
function KeyboardNavigator:handle_key_event(event)
  if not self._enabled then
    return false
  end

  -- Normalize key name
  local key = event.key
  if not key and event.keyCode then
    key = KEY_NAMES[event.keyCode]
  end

  if not key then
    return false
  end

  -- Get handlers for this key
  local handlers = self._handlers[key]
  if not handlers then
    return false
  end

  -- Execute handlers in order until one returns true
  for _, handler in ipairs(handlers) do
    if handler(event) then
      if self.log then
        self.log:debug("Keyboard event handled: %s", key)
      end
      return true
    end
  end

  return false
end

--- Get the list of handled keys
-- @return table Array of key names
function KeyboardNavigator:get_handled_keys()
  local keys = {}
  for key, _ in pairs(self._handlers) do
    table.insert(keys, key)
  end
  return keys
end

--- Check if keyboard navigation is enabled
-- @return boolean True if enabled
function KeyboardNavigator:is_enabled()
  return self._enabled
end

--- Enable keyboard navigation
function KeyboardNavigator:enable()
  self._enabled = true
  if self.events then
    self.events:emit("a11y.keyboard_enabled")
  end
end

--- Disable keyboard navigation
function KeyboardNavigator:disable()
  self._enabled = false
  if self.events then
    self.events:emit("a11y.keyboard_disabled")
  end
end

--- Get current navigation mode
-- @return string "browse" or "focus"
function KeyboardNavigator:get_mode()
  return self._mode
end

--- Set navigation mode
-- @param mode string "browse" or "focus"
function KeyboardNavigator:set_mode(mode)
  if mode ~= "browse" and mode ~= "focus" then
    return
  end

  self._mode = mode

  if self.events then
    self.events:emit("a11y.mode_changed", {mode = mode})
  end
end

--- Set the choice list for arrow key navigation
-- @param choices table Array of choice elements
function KeyboardNavigator:set_choices(choices)
  self._choice_list = choices or {}
  self._current_choice_index = 0

  -- Focus first choice if available
  if #self._choice_list > 0 then
    self:_navigate_to_choice(1)
  end
end

--- Navigate to a specific choice by delta
-- @param delta number +1 for next, -1 for previous
-- @return boolean True if navigation occurred
function KeyboardNavigator:_navigate_choice(delta)
  if #self._choice_list == 0 then
    return false
  end

  local new_index = self._current_choice_index + delta

  -- Wrap around
  if new_index < 1 then
    new_index = #self._choice_list
  elseif new_index > #self._choice_list then
    new_index = 1
  end

  return self:_navigate_to_choice(new_index)
end

--- Navigate to a specific choice index
-- @param index number The choice index (1-based)
-- @return boolean True if navigation occurred
function KeyboardNavigator:_navigate_to_choice(index)
  if index < 1 or index > #self._choice_list then
    return false
  end

  self._current_choice_index = index
  local choice = self._choice_list[index]

  -- Focus the choice element
  if self.focus_manager and choice then
    self.focus_manager:focus(choice)
  end

  -- Emit navigation event
  if self.events then
    self.events:emit("a11y.choice_focused", {
      index = index,
      choice = choice,
      total = #self._choice_list,
    })
  end

  return true
end

--- Get the current choice index
-- @return number The current index (0 if none selected)
function KeyboardNavigator:get_current_choice_index()
  return self._current_choice_index
end

--- Create keyboard event from DOM event or raw data
-- @param raw table Raw event data
-- @return table Normalized keyboard event
function KeyboardNavigator.create_event(raw)
  return {
    key = raw.key,
    keyCode = raw.keyCode,
    shift = raw.shiftKey or raw.shift or false,
    ctrl = raw.ctrlKey or raw.ctrl or false,
    alt = raw.altKey or raw.alt or false,
    meta = raw.metaKey or raw.meta or false,
  }
end

--- Get key code for a key name
-- @param name string The key name
-- @return number|nil The key code
function KeyboardNavigator.get_key_code(name)
  for code, key_name in pairs(KEY_NAMES) do
    if key_name == name then
      return code
    end
  end
  return nil
end

return KeyboardNavigator
