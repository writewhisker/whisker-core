-- whisker/kernel/events.lua
-- Lightweight event bus for module communication
-- Provides pub/sub messaging with namespaced events

local Events = {}
Events.__index = Events

-- Create a new event bus instance
function Events.new(options)
  options = options or {}
  return setmetatable({
    _listeners = {},
    _debug = options.debug or false,
    _debug_handler = options.debug_handler,
  }, Events)
end

-- Subscribe to an event
-- @param event string - Event name (e.g., "passage:entered")
-- @param callback function - Handler function(data)
-- @param options table - Optional: priority (number), once (boolean)
-- @return function - Unsubscribe function for convenience
function Events:on(event, callback, options)
  options = options or {}

  if not self._listeners[event] then
    self._listeners[event] = {}
  end

  local listener = {
    callback = callback,
    priority = options.priority or 0,
    once = options.once or false,
  }

  table.insert(self._listeners[event], listener)

  -- Sort by priority (higher first)
  table.sort(self._listeners[event], function(a, b)
    return a.priority > b.priority
  end)

  -- Return unsubscribe function
  return function()
    self:off(event, callback)
  end
end

-- Subscribe to an event for a single emission only
-- @param event string - Event name
-- @param callback function - Handler function(data)
-- @param options table - Optional: priority (number)
-- @return function - Unsubscribe function
function Events:once(event, callback, options)
  options = options or {}
  options.once = true
  return self:on(event, callback, options)
end

-- Unsubscribe from an event
-- @param event string - Event name
-- @param callback function - The handler to remove (optional, removes all if nil)
function Events:off(event, callback)
  if not self._listeners[event] then return end

  if callback == nil then
    -- Remove all listeners for this event
    self._listeners[event] = nil
    return
  end

  -- Remove specific callback
  for i = #self._listeners[event], 1, -1 do
    if self._listeners[event][i].callback == callback then
      table.remove(self._listeners[event], i)
    end
  end

  -- Clean up empty listener arrays
  if #self._listeners[event] == 0 then
    self._listeners[event] = nil
  end
end

-- Emit an event to all subscribers
-- @param event string - Event name
-- @param data any - Data to pass to handlers
function Events:emit(event, data)
  -- Debug logging
  if self._debug then
    if self._debug_handler then
      self._debug_handler(event, data)
    else
      print(string.format("[EVENT] %s", event))
    end
  end

  -- Direct listeners
  self:_notify(event, data)

  -- Wildcard listeners (e.g., "passage:*" matches "passage:entered")
  local namespace = event:match("^([^:]+):")
  if namespace then
    self:_notify(namespace .. ":*", data, event)
  end

  -- Global wildcard listeners
  self:_notify("*", data, event)
end

-- Internal: notify listeners for a specific event key
function Events:_notify(event_key, data, original_event)
  if not self._listeners[event_key] then return end

  local to_remove = {}

  for i, listener in ipairs(self._listeners[event_key]) do
    -- Pass original event name for wildcard handlers
    if original_event then
      listener.callback(data, original_event)
    else
      listener.callback(data)
    end

    if listener.once then
      table.insert(to_remove, i)
    end
  end

  -- Remove once listeners (iterate in reverse to preserve indices)
  for i = #to_remove, 1, -1 do
    table.remove(self._listeners[event_key], to_remove[i])
  end

  -- Clean up empty listener arrays
  if self._listeners[event_key] and #self._listeners[event_key] == 0 then
    self._listeners[event_key] = nil
  end
end

-- Check if an event has any listeners
-- @param event string - Event name
-- @return boolean
function Events:has_listeners(event)
  return self._listeners[event] ~= nil and #self._listeners[event] > 0
end

-- Get count of listeners for an event
-- @param event string - Event name (optional, returns total if nil)
-- @return number
function Events:listener_count(event)
  if event then
    return self._listeners[event] and #self._listeners[event] or 0
  end

  -- Total count
  local count = 0
  for _, listeners in pairs(self._listeners) do
    count = count + #listeners
  end
  return count
end

-- List all events with listeners
-- @return table - Array of event names
function Events:list_events()
  local events = {}
  for event in pairs(self._listeners) do
    table.insert(events, event)
  end
  table.sort(events)
  return events
end

-- Enable or disable debug mode
-- @param enabled boolean
-- @param handler function - Optional custom debug handler(event, data)
function Events:set_debug(enabled, handler)
  self._debug = enabled
  self._debug_handler = handler
end

-- Clear all listeners
function Events:clear()
  self._listeners = {}
end

return Events
