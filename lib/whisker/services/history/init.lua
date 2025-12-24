--- HistoryService
-- Navigation history tracking service
-- @module whisker.services.history
-- @author Whisker Core Team
-- @license MIT

local HistoryService = {}
HistoryService.__index = HistoryService

HistoryService.name = "history_service"
HistoryService.version = "2.2.0"

-- Dependencies for DI pattern
HistoryService._dependencies = {"event_bus", "state", "logger"}

--- Create a new HistoryService instance via DI container
-- @param deps table Dependencies from container (event_bus, state, logger)
-- @return function Factory function that creates HistoryService instances
function HistoryService.create(deps)
  return function(config)
    return HistoryService.new(config, deps)
  end
end

--- Create a new history service instance
-- @param config_or_container table|nil Configuration options or legacy container
-- @param deps table|nil Dependencies from container
-- @return HistoryService
function HistoryService.new(config_or_container, deps)
  local self = {
    _stack = {},
    _max_size = 100,
    _events = nil,
    _state = nil,
    _logger = nil,
    _subscriptions = {},
    _initialized = false
  }

  -- Handle backward compatibility with container parameter
  if config_or_container and type(config_or_container.has) == "function" then
    -- Legacy container-based initialization
    local container = config_or_container
    self._events = container:has("events") and container:resolve("events") or nil
    self._state = container:has("state") and container:resolve("state") or nil
    self._logger = container:has("logger") and container:resolve("logger") or nil
  elseif deps then
    -- New DI pattern
    self._events = deps.event_bus
    self._state = deps.state
    self._logger = deps.logger
  end

  -- Apply config
  if type(config_or_container) == "table" and not config_or_container.has then
    if config_or_container.max_size then
      self._max_size = config_or_container.max_size
    end
  end

  local instance = setmetatable(self, { __index = HistoryService })

  -- Subscribe to navigation events
  if self._events then
    local unsub = self._events:on("passage:entered", function(data)
      instance:_on_passage_entered(data)
    end)
    table.insert(self._subscriptions, unsub)
  end

  self._initialized = true

  if self._logger then
    self._logger:debug("HistoryService initialized")
  end

  return instance
end

--- Get the service name
-- @return string The service name
function HistoryService:getName()
  return "history"
end

--- Check if the service is initialized
-- @return boolean True if initialized
function HistoryService:isInitialized()
  return self._initialized == true
end

--- Clean up event subscriptions
function HistoryService:destroy()
  if self._logger then
    self._logger:debug("HistoryService destroying")
  end

  for _, unsubscribe in ipairs(self._subscriptions) do
    if type(unsubscribe) == "function" then
      unsubscribe()
    end
  end
  self._subscriptions = {}
  self._stack = {}
  self._events = nil
  self._state = nil
  self._logger = nil
  self._initialized = false
end

--- Push a passage ID to history
-- @param passage_id string The passage ID
function HistoryService:push(passage_id)
  table.insert(self._stack, {
    passage_id = passage_id,
    timestamp = os.time()
  })

  -- Enforce max size
  while #self._stack > self._max_size do
    table.remove(self._stack, 1)
  end

  if self._logger then
    self._logger:debug("History push: " .. tostring(passage_id))
  end

  if self._events then
    self._events:emit("history:updated", {
      passage_id = passage_id,
      depth = #self._stack
    })
  end
end

--- Pop the most recent entry from history
-- @return table|nil entry The popped entry, or nil if empty
function HistoryService:pop()
  local entry = table.remove(self._stack)

  if entry and self._logger then
    self._logger:debug("History pop: " .. tostring(entry.passage_id))
  end

  return entry
end

--- Peek at the most recent entry without removing it
-- @return table|nil entry The most recent entry, or nil if empty
function HistoryService:peek()
  return self._stack[#self._stack]
end

--- Go back N steps in history
-- @param steps number Number of steps (default 1)
-- @return string|nil passage_id The target passage ID, or nil if not possible
function HistoryService:back(steps)
  steps = steps or 1

  -- Need at least steps+1 items to go back
  if #self._stack <= steps then
    return nil
  end

  -- Remove current and N-1 more
  for _ = 1, steps do
    table.remove(self._stack)
  end

  local entry = self._stack[#self._stack]

  if self._logger then
    self._logger:debug("History back " .. tostring(steps) .. " steps")
  end

  return entry and entry.passage_id or nil
end

--- Get current history depth
-- @return number depth Number of entries in history
function HistoryService:depth()
  return #self._stack
end

--- Check if can go back
-- @param steps number Number of steps (default 1)
-- @return boolean can_back True if history has enough entries
function HistoryService:can_back(steps)
  steps = steps or 1
  return #self._stack > steps
end

--- Alias for can_back(1)
-- @return boolean can_go_back True if can go back one step
function HistoryService:can_go_back()
  return self:can_back(1)
end

--- Go back one step and return the previous entry
-- @return table|nil entry The previous entry, or nil if not possible
function HistoryService:go_back()
  if #self._stack > 1 then
    table.remove(self._stack)

    if self._logger then
      self._logger:debug("History go_back")
    end

    return self._stack[#self._stack]
  end
  return nil
end

--- Get history as array
-- @return table[] history Array of {passage_id, timestamp}
function HistoryService:get_history()
  local result = {}
  for _, entry in ipairs(self._stack) do
    table.insert(result, {
      passage_id = entry.passage_id,
      timestamp = entry.timestamp
    })
  end
  return result
end

--- Alias for get_history
-- @return table[] history Array of history entries
function HistoryService:get_all()
  return self:get_history()
end

--- Clear all history
function HistoryService:clear()
  self._stack = {}

  if self._logger then
    self._logger:debug("History cleared")
  end

  if self._events then
    self._events:emit("history:cleared", {
      timestamp = os.time()
    })
  end
end

--- Set the maximum history size
-- @param size number Maximum number of entries to keep
function HistoryService:set_max_size(size)
  self._max_size = size
  -- Trim if necessary
  while #self._stack > self._max_size do
    table.remove(self._stack, 1)
  end

  if self._logger then
    self._logger:debug("History max_size set to: " .. tostring(size))
  end
end

--- Internal: Handle passage entered event
-- @param data table Event data with passage info
function HistoryService:_on_passage_entered(data)
  if data and data.passage and data.passage.id then
    self:push(data.passage.id)
  elseif data and data.passage_id then
    self:push(data.passage_id)
  end
end

return HistoryService
