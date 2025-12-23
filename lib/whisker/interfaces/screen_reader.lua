--- IScreenReaderAdapter Interface
-- Interface for screen reader integration
-- @module whisker.interfaces.screen_reader
-- @author Whisker Core Team
-- @license MIT

local IScreenReaderAdapter = {}

--- Announce a message to screen readers via live region
-- @param message string The message to announce
-- @param priority string "polite" (waits for current speech) or "assertive" (interrupts)
function IScreenReaderAdapter:announce(message, priority)
  error("IScreenReaderAdapter:announce must be implemented")
end

--- Clear all pending announcements
function IScreenReaderAdapter:clear_announcements()
  error("IScreenReaderAdapter:clear_announcements must be implemented")
end

--- Get the current live region element
-- @param priority string "polite" or "assertive"
-- @return element The live region DOM element (or equivalent)
function IScreenReaderAdapter:get_live_region(priority)
  error("IScreenReaderAdapter:get_live_region must be implemented")
end

--- Create live regions in the DOM
-- Creates both polite and assertive live region containers
function IScreenReaderAdapter:create_live_regions()
  error("IScreenReaderAdapter:create_live_regions must be implemented")
end

--- Announce passage change
-- @param passage_title string The new passage title
-- @param choice_count number|nil Number of available choices
function IScreenReaderAdapter:announce_passage_change(passage_title, choice_count)
  error("IScreenReaderAdapter:announce_passage_change must be implemented")
end

--- Announce choice selection
-- @param choice_text string The selected choice text
function IScreenReaderAdapter:announce_choice_selection(choice_text)
  error("IScreenReaderAdapter:announce_choice_selection must be implemented")
end

--- Announce an error
-- @param error_message string The error message
function IScreenReaderAdapter:announce_error(error_message)
  error("IScreenReaderAdapter:announce_error must be implemented")
end

--- Announce loading state
-- @param is_loading boolean True if loading started, false if complete
function IScreenReaderAdapter:announce_loading(is_loading)
  error("IScreenReaderAdapter:announce_loading must be implemented")
end

return IScreenReaderAdapter
