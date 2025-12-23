--- IFocusManager Interface
-- Interface for managing focus in accessible UI components
-- @module whisker.interfaces.focus_manager
-- @author Whisker Core Team
-- @license MIT

local IFocusManager = {}

--- Set focus to an element
-- @param element any The element to focus
-- @param options table|nil Focus options {preventScroll: boolean}
-- @return boolean True if focus was successfully set
function IFocusManager:focus(element, options)
  error("IFocusManager:focus must be implemented")
end

--- Get the currently focused element
-- @return any|nil The focused element or nil
function IFocusManager:get_focused_element()
  error("IFocusManager:get_focused_element must be implemented")
end

--- Save the current focus for later restoration
-- @param key string Unique identifier for this focus save point
function IFocusManager:save_focus(key)
  error("IFocusManager:save_focus must be implemented")
end

--- Restore focus to a previously saved element
-- @param key string The identifier used when saving focus
-- @return boolean True if focus was restored
function IFocusManager:restore_focus(key)
  error("IFocusManager:restore_focus must be implemented")
end

--- Enable focus trapping within a container
-- @param container any The container element to trap focus within
function IFocusManager:trap_focus(container)
  error("IFocusManager:trap_focus must be implemented")
end

--- Release focus trap
function IFocusManager:release_focus_trap()
  error("IFocusManager:release_focus_trap must be implemented")
end

--- Check if focus is currently trapped
-- @return boolean True if focus is trapped
function IFocusManager:is_focus_trapped()
  error("IFocusManager:is_focus_trapped must be implemented")
end

--- Get all focusable elements within a container
-- @param container any The container element
-- @return table Array of focusable elements
function IFocusManager:get_focusable_elements(container)
  error("IFocusManager:get_focusable_elements must be implemented")
end

--- Move focus to the first focusable element in a container
-- @param container any The container element
-- @return boolean True if focus was moved
function IFocusManager:focus_first(container)
  error("IFocusManager:focus_first must be implemented")
end

--- Move focus to the last focusable element in a container
-- @param container any The container element
-- @return boolean True if focus was moved
function IFocusManager:focus_last(container)
  error("IFocusManager:focus_last must be implemented")
end

--- Move focus to the next focusable element
-- @return boolean True if focus was moved
function IFocusManager:focus_next()
  error("IFocusManager:focus_next must be implemented")
end

--- Move focus to the previous focusable element
-- @return boolean True if focus was moved
function IFocusManager:focus_previous()
  error("IFocusManager:focus_previous must be implemented")
end

return IFocusManager
