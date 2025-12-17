-- whisker/services/history/init.lua
-- History service for navigation tracking and undo support
-- Integrates with State snapshots for complete state restoration

local History = {}
History.__index = History

-- Module metadata for container auto-registration
History._whisker = {
  name = "History",
  version = "2.0.0",
  description = "History service for navigation tracking and undo",
  depends = {},
  capability = "services.history"
}

-- Deep copy helper
local function deep_copy(original)
  if type(original) ~= "table" then
    return original
  end
  local copy = {}
  for k, v in pairs(original) do
    if type(v) == "table" then
      copy[k] = deep_copy(v)
    else
      copy[k] = v
    end
  end
  return copy
end

-- Create a new History instance
-- @param options table|nil - Optional configuration
-- @return History
function History.new(options)
  options = options or {}
  local instance = {
    _stack = {},
    _max_entries = options.max_entries or 100,
    _state_service = options.state or nil,
    _event_emitter = options.event_emitter or nil
  }
  setmetatable(instance, History)
  return instance
end

-- Set the state service for snapshot integration
function History:set_state_service(state)
  self._state_service = state
end

-- Get the state service
function History:get_state_service()
  return self._state_service
end

-- Set the event emitter
function History:set_event_emitter(emitter)
  self._event_emitter = emitter
end

-- Get the event emitter
function History:get_event_emitter()
  return self._event_emitter
end

-- Internal: emit an event if emitter is set
local function emit_event(self, event_name, data)
  if self._event_emitter and self._event_emitter.emit then
    self._event_emitter:emit(event_name, data)
  end
end

-- Push a new entry onto the history stack
-- @param passage_id string - Passage being entered
-- @param metadata table|nil - Optional additional data
function History:push(passage_id, metadata)
  local entry = {
    passage_id = passage_id,
    timestamp = os.time(),
    metadata = metadata or {}
  }

  -- Capture state snapshot if state service is available
  if self._state_service and self._state_service.snapshot then
    entry.state_snapshot = self._state_service:snapshot()
  end

  table.insert(self._stack, entry)

  -- Trim to max entries
  while #self._stack > self._max_entries do
    table.remove(self._stack, 1)
  end

  emit_event(self, "history:pushed", {
    entry = entry,
    stack_size = #self._stack
  })
end

-- Pop the most recent entry from the history stack
-- @return table|nil - The popped entry or nil if empty
function History:pop()
  if #self._stack == 0 then
    return nil
  end

  local entry = table.remove(self._stack)

  emit_event(self, "history:popped", {
    entry = entry,
    stack_size = #self._stack
  })

  return entry
end

-- Peek at the most recent entry without removing it
-- @return table|nil - The most recent entry or nil if empty
function History:peek()
  if #self._stack == 0 then
    return nil
  end
  return self._stack[#self._stack]
end

-- Go back to the previous passage, restoring state
-- @return table|nil, string|nil - Entry and nil, or nil and error message
function History:back()
  if #self._stack < 2 then
    return nil, "No previous entry to go back to"
  end

  -- Pop current entry
  local current = table.remove(self._stack)

  -- Peek at previous (now current) entry
  local previous = self._stack[#self._stack]

  -- Restore state if snapshot available
  if previous.state_snapshot and self._state_service and self._state_service.restore then
    self._state_service:restore(previous.state_snapshot)
  end

  emit_event(self, "history:back", {
    from = current,
    to = previous,
    stack_size = #self._stack
  })

  return previous, nil
end

-- Check if back navigation is available
-- @return boolean
function History:can_go_back()
  return #self._stack >= 2
end

-- Get the current stack size
-- @return number
function History:size()
  return #self._stack
end

-- Check if history is empty
-- @return boolean
function History:is_empty()
  return #self._stack == 0
end

-- Clear all history entries
function History:clear()
  local old_size = #self._stack
  self._stack = {}

  if old_size > 0 then
    emit_event(self, "history:cleared", {
      cleared_count = old_size
    })
  end
end

-- Get all entries (for serialization/debugging)
-- @return table - Copy of the history stack
function History:get_all()
  return deep_copy(self._stack)
end

-- Get entry at specific index (1-based, 1 = oldest)
-- @param index number - 1-based index
-- @return table|nil
function History:get(index)
  return self._stack[index]
end

-- Get the most recent N entries
-- @param n number - Number of entries to get
-- @return table - Array of entries (most recent first)
function History:get_recent(n)
  local result = {}
  local start_idx = math.max(1, #self._stack - n + 1)
  for i = #self._stack, start_idx, -1 do
    table.insert(result, deep_copy(self._stack[i]))
  end
  return result
end

-- Handler for passage:entered events (for auto-tracking)
-- @param event_data table - Event data with passage info
function History:on_passage_entered(event_data)
  if event_data and event_data.passage_id then
    self:push(event_data.passage_id, event_data)
  elseif event_data and event_data.passage and event_data.passage.id then
    self:push(event_data.passage.id, event_data)
  end
end

-- Serialization
function History:serialize()
  return {
    stack = deep_copy(self._stack),
    max_entries = self._max_entries
  }
end

-- Deserialization
function History:deserialize(data)
  if data and data.stack then
    self._stack = deep_copy(data.stack)
  end
  if data and data.max_entries then
    self._max_entries = data.max_entries
  end
end

return History
