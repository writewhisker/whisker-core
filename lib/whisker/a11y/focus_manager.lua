--- Focus Manager
-- Manages keyboard focus for accessibility
-- @module whisker.a11y.focus_manager
-- @author Whisker Core Team
-- @license MIT

local FocusManager = {}
FocusManager.__index = FocusManager

-- Dependencies
FocusManager._dependencies = {"event_bus", "logger"}

-- Focusable element selectors (for DOM environments)
local FOCUSABLE_SELECTORS = {
  "button:not([disabled])",
  "a[href]",
  "input:not([disabled])",
  "select:not([disabled])",
  "textarea:not([disabled])",
  "[tabindex]:not([tabindex='-1'])",
  "[contenteditable]",
}

--- Create a new FocusManager
-- @param deps table Dependency container with event_bus and logger
-- @return FocusManager The new manager instance
function FocusManager.new(deps)
  local self = setmetatable({}, FocusManager)

  self.events = deps and deps.event_bus
  self.log = deps and deps.logger

  -- Focus state
  self._saved_focus = {}
  self._focus_trap_container = nil
  self._focused_element = nil

  return self
end

--- Factory method for DI container
-- @param deps table Dependencies
-- @return FocusManager
function FocusManager.create(deps)
  return FocusManager.new(deps)
end

--- Set focus to an element
-- @param element any The element to focus
-- @param options table|nil Focus options {preventScroll: boolean}
-- @return boolean True if focus was successfully set
function FocusManager:focus(element, options)
  if not element then
    return false
  end

  options = options or {}

  -- For DOM-based elements
  if element.focus then
    if options.preventScroll then
      element:focus({preventScroll = true})
    else
      element:focus()
    end
    self._focused_element = element

    if self.events then
      self.events:emit("a11y.focus_change", {element = element})
    end

    return true
  end

  return false
end

--- Get the currently focused element
-- @return any|nil The focused element or nil
function FocusManager:get_focused_element()
  return self._focused_element
end

--- Save the current focus for later restoration
-- @param key string Unique identifier for this focus save point
function FocusManager:save_focus(key)
  if not key then
    key = "default"
  end

  self._saved_focus[key] = self._focused_element

  if self.log then
    self.log:debug("Focus saved with key: %s", key)
  end
end

--- Restore focus to a previously saved element
-- @param key string The identifier used when saving focus
-- @return boolean True if focus was restored
function FocusManager:restore_focus(key)
  if not key then
    key = "default"
  end

  local element = self._saved_focus[key]
  if element then
    self._saved_focus[key] = nil
    return self:focus(element)
  end

  return false
end

--- Enable focus trapping within a container
-- @param container any The container element to trap focus within
function FocusManager:trap_focus(container)
  if not container then
    return
  end

  self._focus_trap_container = container

  -- Focus the first focusable element
  self:focus_first(container)

  if self.events then
    self.events:emit("a11y.focus_trap_enabled", {container = container})
  end

  if self.log then
    self.log:debug("Focus trap enabled")
  end
end

--- Release focus trap
function FocusManager:release_focus_trap()
  self._focus_trap_container = nil

  if self.events then
    self.events:emit("a11y.focus_trap_released")
  end

  if self.log then
    self.log:debug("Focus trap released")
  end
end

--- Check if focus is currently trapped
-- @return boolean True if focus is trapped
function FocusManager:is_focus_trapped()
  return self._focus_trap_container ~= nil
end

--- Get all focusable elements within a container
-- @param container any The container element
-- @return table Array of focusable elements
function FocusManager:get_focusable_elements(container)
  if not container then
    return {}
  end

  -- For DOM environments with querySelectorAll
  if container.querySelectorAll then
    local selector = table.concat(FOCUSABLE_SELECTORS, ", ")
    local elements = container:querySelectorAll(selector)
    -- Convert NodeList to array
    local result = {}
    for i = 0, elements.length - 1 do
      table.insert(result, elements[i])
    end
    return result
  end

  -- For Lua-based UI systems, get children with focusable flag
  if container.get_focusable_children then
    return container:get_focusable_children()
  end

  return {}
end

--- Move focus to the first focusable element in a container
-- @param container any The container element
-- @return boolean True if focus was moved
function FocusManager:focus_first(container)
  local focusable = self:get_focusable_elements(container)
  if #focusable > 0 then
    return self:focus(focusable[1])
  end
  return false
end

--- Move focus to the last focusable element in a container
-- @param container any The container element
-- @return boolean True if focus was moved
function FocusManager:focus_last(container)
  local focusable = self:get_focusable_elements(container)
  if #focusable > 0 then
    return self:focus(focusable[#focusable])
  end
  return false
end

--- Move focus to the next focusable element
-- @return boolean True if focus was moved
function FocusManager:focus_next()
  local container = self._focus_trap_container
  if not container then
    return false
  end

  local focusable = self:get_focusable_elements(container)
  local current_index = self:_find_index(focusable, self._focused_element)

  if current_index then
    local next_index = current_index + 1
    if next_index > #focusable then
      next_index = 1 -- Wrap to first element
    end
    return self:focus(focusable[next_index])
  end

  return self:focus_first(container)
end

--- Move focus to the previous focusable element
-- @return boolean True if focus was moved
function FocusManager:focus_previous()
  local container = self._focus_trap_container
  if not container then
    return false
  end

  local focusable = self:get_focusable_elements(container)
  local current_index = self:_find_index(focusable, self._focused_element)

  if current_index then
    local prev_index = current_index - 1
    if prev_index < 1 then
      prev_index = #focusable -- Wrap to last element
    end
    return self:focus(focusable[prev_index])
  end

  return self:focus_last(container)
end

--- Find index of element in array
-- @param arr table The array to search
-- @param element any The element to find
-- @return number|nil The index or nil if not found
function FocusManager:_find_index(arr, element)
  for i, el in ipairs(arr) do
    if el == element then
      return i
    end
  end
  return nil
end

--- Handle Tab key for focus management
-- @param shift_key boolean True if Shift is held
-- @return boolean True if handled
function FocusManager:handle_tab(shift_key)
  if not self:is_focus_trapped() then
    return false
  end

  if shift_key then
    return self:focus_previous()
  else
    return self:focus_next()
  end
end

--- Get the focusable selector string
-- @return string CSS selector for focusable elements
function FocusManager:get_focusable_selector()
  return table.concat(FOCUSABLE_SELECTORS, ", ")
end

return FocusManager
