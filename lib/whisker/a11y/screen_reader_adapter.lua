--- Screen Reader Adapter
-- Provides screen reader integration via ARIA live regions
-- @module whisker.a11y.screen_reader_adapter
-- @author Whisker Core Team
-- @license MIT

local ScreenReaderAdapter = {}
ScreenReaderAdapter.__index = ScreenReaderAdapter

-- Dependencies
ScreenReaderAdapter._dependencies = {"event_bus", "logger"}

--- Create a new ScreenReaderAdapter
-- @param deps table Dependency container with event_bus and logger
-- @return ScreenReaderAdapter The new adapter instance
function ScreenReaderAdapter.new(deps)
  local self = setmetatable({}, ScreenReaderAdapter)

  self.events = deps and deps.event_bus
  self.log = deps and deps.logger

  -- Announcement queue for deduplication
  self._announcement_queue = {}
  self._last_announcement_time = 0
  self._debounce_ms = 100

  -- Live region configuration
  self._live_regions = {
    polite = nil,
    assertive = nil,
  }

  return self
end

--- Factory method for DI container
-- @param deps table Dependencies
-- @return ScreenReaderAdapter
function ScreenReaderAdapter.create(deps)
  return ScreenReaderAdapter.new(deps)
end

--- Initialize live regions
-- This should be called when the UI is ready
-- @param polite_element any The polite live region element
-- @param assertive_element any The assertive live region element
function ScreenReaderAdapter:init_live_regions(polite_element, assertive_element)
  self._live_regions.polite = polite_element
  self._live_regions.assertive = assertive_element
end

--- Announce a message to screen readers
-- @param message string The message to announce
-- @param priority string "polite" or "assertive" (default: "polite")
function ScreenReaderAdapter:announce(message, priority)
  priority = priority or "polite"

  if not message or message == "" then
    return
  end

  -- Debounce rapid announcements
  local current_time = os.clock() * 1000
  if current_time - self._last_announcement_time < self._debounce_ms then
    -- Queue the announcement
    table.insert(self._announcement_queue, {
      message = message,
      priority = priority,
    })
    return
  end

  self._last_announcement_time = current_time
  self:_send_announcement(message, priority)
end

--- Internal method to send announcement to live region
-- @param message string The message
-- @param priority string The priority level
function ScreenReaderAdapter:_send_announcement(message, priority)
  local region = self._live_regions[priority]
  if region then
    -- For DOM-based environments, set the textContent
    -- This will be adapted per platform
    if region.set_text then
      region:set_text(message)
    elseif type(region) == "table" and region.textContent ~= nil then
      region.textContent = message
    end
  end

  -- Emit event for logging/testing
  if self.events then
    self.events:emit("a11y.announcement", {
      message = message,
      priority = priority,
    })
  end

  if self.log then
    self.log:debug("Screen reader announcement: [%s] %s", priority, message)
  end
end

--- Clear all pending announcements
function ScreenReaderAdapter:clear_announcements()
  self._announcement_queue = {}

  -- Clear live region contents
  for _, region in pairs(self._live_regions) do
    if region then
      if region.set_text then
        region:set_text("")
      elseif type(region) == "table" and region.textContent ~= nil then
        region.textContent = ""
      end
    end
  end
end

--- Get the live region element for a priority
-- @param priority string "polite" or "assertive"
-- @return any The live region element
function ScreenReaderAdapter:get_live_region(priority)
  return self._live_regions[priority or "polite"]
end

--- Announce passage change
-- @param passage_title string The new passage title
-- @param choice_count number|nil Number of available choices
function ScreenReaderAdapter:announce_passage_change(passage_title, choice_count)
  local message

  if choice_count and choice_count > 0 then
    if choice_count == 1 then
      message = string.format("New passage: %s. 1 choice available.", passage_title)
    else
      message = string.format("New passage: %s. %d choices available.", passage_title, choice_count)
    end
  else
    message = string.format("New passage: %s.", passage_title)
  end

  self:announce(message, "polite")
end

--- Announce choice selection
-- @param choice_text string The selected choice text
function ScreenReaderAdapter:announce_choice_selection(choice_text)
  self:announce(string.format("Selected: %s", choice_text), "polite")
end

--- Announce an error
-- @param error_message string The error message
function ScreenReaderAdapter:announce_error(error_message)
  self:announce(string.format("Error: %s", error_message), "assertive")
end

--- Announce loading state
-- @param is_loading boolean True if loading started, false if complete
function ScreenReaderAdapter:announce_loading(is_loading)
  if is_loading then
    self:announce("Loading...", "polite")
  else
    self:announce("Loading complete.", "polite")
  end
end

--- Process queued announcements
-- Should be called periodically or after debounce timeout
function ScreenReaderAdapter:process_queue()
  if #self._announcement_queue == 0 then
    return
  end

  -- Get the most recent announcement (skip duplicates)
  local announcement = self._announcement_queue[#self._announcement_queue]
  self._announcement_queue = {}

  if announcement then
    self:_send_announcement(announcement.message, announcement.priority)
  end
end

--- Get HTML for live regions
-- Returns HTML to be inserted into the page
-- @return string HTML for live regions
function ScreenReaderAdapter:get_live_region_html()
  return [[
<div id="a11y-announcements" class="sr-only">
  <div id="announcements-polite" aria-live="polite" aria-atomic="true"></div>
  <div id="announcements-assertive" aria-live="assertive" aria-atomic="true"></div>
</div>
]]
end

return ScreenReaderAdapter
