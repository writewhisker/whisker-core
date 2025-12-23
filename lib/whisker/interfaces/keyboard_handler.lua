--- IKeyboardHandler Interface
-- Interface for keyboard navigation in UI components
-- @module whisker.interfaces.keyboard_handler
-- @author Whisker Core Team
-- @license MIT

local IKeyboardHandler = {}

--- Handle a keyboard event
-- @param event table The keyboard event {key, shift, ctrl, alt, meta}
-- @return boolean True if the event was handled
function IKeyboardHandler:handle_key_event(event)
  error("IKeyboardHandler:handle_key_event must be implemented")
end

--- Get the list of handled keys
-- @return table Array of key names this handler responds to
function IKeyboardHandler:get_handled_keys()
  error("IKeyboardHandler:get_handled_keys must be implemented")
end

--- Check if keyboard navigation is enabled
-- @return boolean True if keyboard navigation is active
function IKeyboardHandler:is_enabled()
  error("IKeyboardHandler:is_enabled must be implemented")
end

--- Enable keyboard navigation
function IKeyboardHandler:enable()
  error("IKeyboardHandler:enable must be implemented")
end

--- Disable keyboard navigation
function IKeyboardHandler:disable()
  error("IKeyboardHandler:disable must be implemented")
end

--- Get current keyboard navigation mode
-- @return string Navigation mode (e.g., "browse", "focus", "edit")
function IKeyboardHandler:get_mode()
  error("IKeyboardHandler:get_mode must be implemented")
end

--- Set keyboard navigation mode
-- @param mode string Navigation mode to set
function IKeyboardHandler:set_mode(mode)
  error("IKeyboardHandler:set_mode must be implemented")
end

return IKeyboardHandler
