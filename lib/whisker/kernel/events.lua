--- Event Bus
-- Pub/sub event system with wildcard pattern matching
-- @module whisker.kernel.events
-- @author Whisker Core Team
-- @license MIT

local EventBus = {}
EventBus._dependencies = {}
EventBus.__index = EventBus

--- Create a new event bus instance
-- @return EventBus A new event bus
function EventBus.new(deps)
  deps = deps or {}
  local self = setmetatable({}, EventBus)
  self._handlers = {}
  self._wildcard_handlers = {}
  self._once_handlers = {}
  return self
end

--- Subscribe to an event
-- @param event string The event name (supports * wildcard)
-- @param handler function The handler function
-- @return function Unsubscribe function
function EventBus:on(event, handler)
  if type(handler) ~= "function" then
    error("Handler must be a function")
  end

  if event:find("*") then
    -- Wildcard handler
    local pattern = "^" .. event:gsub("%*", ".*") .. "$"
    self._wildcard_handlers[pattern] = self._wildcard_handlers[pattern] or {}
    table.insert(self._wildcard_handlers[pattern], handler)
  else
    -- Exact handler
    self._handlers[event] = self._handlers[event] or {}
    table.insert(self._handlers[event], handler)
  end

  -- Return unsubscribe function
  return function()
    self:off(event, handler)
  end
end

--- Subscribe to an event once
-- @param event string The event name
-- @param handler function The handler function
-- @return function Unsubscribe function
function EventBus:once(event, handler)
  self._once_handlers[handler] = true
  return self:on(event, handler)
end

--- Unsubscribe from an event
-- @param event string The event name
-- @param handler function The handler to remove
function EventBus:off(event, handler)
  if event:find("*") then
    local pattern = "^" .. event:gsub("%*", ".*") .. "$"
    local handlers = self._wildcard_handlers[pattern]
    if handlers then
      for i, h in ipairs(handlers) do
        if h == handler then
          table.remove(handlers, i)
          break
        end
      end
    end
  else
    local handlers = self._handlers[event]
    if handlers then
      for i, h in ipairs(handlers) do
        if h == handler then
          table.remove(handlers, i)
          break
        end
      end
    end
  end
  self._once_handlers[handler] = nil
end

--- Emit an event
-- @param event string The event name
-- @param data table|nil Event data
-- @return table Result with canceled flag and handler results
function EventBus:emit(event, data)
  data = data or {}
  data.event_name = event

  -- Record to history if enabled
  if self._history_enabled then
    table.insert(self._history, {
      event = event,
      data = data,
      timestamp = os.time()
    })

    -- Trim to max size
    while #self._history > self._history_max do
      table.remove(self._history, 1)
    end
  end

  local result = {
    canceled = false,
    cancelled = false,
    results = {},
  }

  local handlers_to_call = {}
  local handlers_to_remove = {}

  -- Collect exact handlers
  if self._handlers[event] then
    for _, handler in ipairs(self._handlers[event]) do
      table.insert(handlers_to_call, handler)
    end
  end

  -- Collect wildcard handlers
  for pattern, handlers in pairs(self._wildcard_handlers) do
    if event:match(pattern) then
      for _, handler in ipairs(handlers) do
        table.insert(handlers_to_call, handler)
      end
    end
  end

  -- Call handlers
  for _, handler in ipairs(handlers_to_call) do
    local ok, handler_result = pcall(handler, data)

    if ok then
      table.insert(result.results, handler_result)
    end

    -- Check for once handlers
    if self._once_handlers[handler] then
      table.insert(handlers_to_remove, {event = event, handler = handler})
    end

    -- Check for cancellation
    if data.cancel then
      result.canceled = true
      result.cancelled = true
      break
    end
  end

  -- Remove once handlers
  for _, item in ipairs(handlers_to_remove) do
    self:off(item.event, item.handler)
  end

  return result
end

--- Remove all handlers for an event
-- @param event string|nil The event name, or nil to clear all
function EventBus:clear(event)
  if event then
    if event:find("*") then
      local pattern = "^" .. event:gsub("%*", ".*") .. "$"
      self._wildcard_handlers[pattern] = nil
    else
      self._handlers[event] = nil
    end
  else
    self._handlers = {}
    self._wildcard_handlers = {}
    self._once_handlers = {}
  end
end

--- Get handler count for an event
-- @param event string The event name
-- @return number The number of handlers
function EventBus:count(event)
  local count = 0

  if self._handlers[event] then
    count = count + #self._handlers[event]
  end

  for pattern, handlers in pairs(self._wildcard_handlers) do
    if event:match(pattern) then
      count = count + #handlers
    end
  end

  return count
end

--- Create a namespaced event bus
-- All events are prefixed with the namespace
-- @param prefix string The namespace prefix
-- @return table A namespaced event interface
function EventBus:namespace(prefix)
  local ns = {}
  local bus = self

  function ns:on(event_name, handler)
    return bus:on(prefix .. ":" .. event_name, handler)
  end

  function ns:once(event_name, handler)
    return bus:once(prefix .. ":" .. event_name, handler)
  end

  function ns:emit(event_name, data)
    return bus:emit(prefix .. ":" .. event_name, data)
  end

  function ns:off(event_name, handler)
    return bus:off(prefix .. ":" .. event_name, handler)
  end

  return ns
end

--- Enable event history tracking
-- @param max_size number Maximum history entries (default 100)
function EventBus:enable_history(max_size)
  self._history_enabled = true
  self._history = {}
  self._history_max = max_size or 100
end

--- Disable event history tracking
function EventBus:disable_history()
  self._history_enabled = false
  self._history = nil
end

--- Get event history
-- @param filter string|nil Optional pattern to filter events
-- @return table Array of history entries {event, data, timestamp}
function EventBus:get_history(filter)
  if not self._history_enabled or not self._history then
    return {}
  end

  if not filter then
    -- Return copy of full history
    local copy = {}
    for i, entry in ipairs(self._history) do
      copy[i] = entry
    end
    return copy
  end

  -- Filter by pattern
  local pattern = "^" .. filter:gsub("%*", ".*") .. "$"
  local filtered = {}
  for _, entry in ipairs(self._history) do
    if entry.event:match(pattern) then
      table.insert(filtered, entry)
    end
  end

  return filtered
end

--- Clear event history
function EventBus:clear_history()
  if self._history_enabled then
    self._history = {}
  end
end

return EventBus
