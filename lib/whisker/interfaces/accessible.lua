--- IAccessible Interface
-- Interface for accessibility-enabled UI components
-- @module whisker.interfaces.accessible
-- @author Whisker Core Team
-- @license MIT

local IAccessible = {}

--- Get the accessible name for this component
-- @return string The accessible name (announced by screen readers)
function IAccessible:get_accessible_name()
  error("IAccessible:get_accessible_name must be implemented")
end

--- Get the accessible role for this component
-- @return string The ARIA role (e.g., "button", "listbox", "dialog")
function IAccessible:get_role()
  error("IAccessible:get_role must be implemented")
end

--- Get the accessible description for this component
-- @return string|nil Optional description providing more context
function IAccessible:get_accessible_description()
  error("IAccessible:get_accessible_description must be implemented")
end

--- Check if this component is focusable
-- @return boolean True if the component can receive keyboard focus
function IAccessible:is_focusable()
  error("IAccessible:is_focusable must be implemented")
end

--- Check if this component is currently disabled
-- @return boolean True if the component is disabled
function IAccessible:is_disabled()
  error("IAccessible:is_disabled must be implemented")
end

--- Get the current state of this component
-- @return table State flags (e.g., {selected=true, expanded=false})
function IAccessible:get_state()
  error("IAccessible:get_state must be implemented")
end

--- Get ARIA attributes for this component
-- @return table Key-value pairs of ARIA attributes
function IAccessible:get_aria_attributes()
  error("IAccessible:get_aria_attributes must be implemented")
end

--- Get keyboard shortcuts for this component
-- @return table Array of {key, description} pairs
function IAccessible:get_keyboard_shortcuts()
  error("IAccessible:get_keyboard_shortcuts must be implemented")
end

--- Announce a message to screen readers
-- @param message string The message to announce
-- @param priority string "polite" or "assertive"
function IAccessible:announce(message, priority)
  error("IAccessible:announce must be implemented")
end

return IAccessible
