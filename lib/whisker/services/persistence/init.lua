--- PersistenceService
-- Save/load functionality for game state
-- @module whisker.services.persistence
-- @author Whisker Core Team
-- @license MIT

local PersistenceService = {}
PersistenceService.__index = PersistenceService

PersistenceService.name = "persistence_service"
PersistenceService.version = "2.2.0"

-- Dependencies for DI pattern
PersistenceService._dependencies = {"state", "event_bus", "serializer", "file_storage", "logger"}

--- Create a new PersistenceService instance via DI container
-- @param deps table Dependencies from container
-- @return function Factory function that creates PersistenceService instances
function PersistenceService.create(deps)
  return function(config)
    return PersistenceService.new(config, deps)
  end
end

--- Create a new persistence service instance
-- @param config_or_container table|nil Configuration options or legacy container
-- @param deps table|nil Dependencies from container
-- @return PersistenceService
function PersistenceService.new(config_or_container, deps)
  local self = {
    _state = nil,
    _serializer = nil,
    _events = nil,
    _platform = nil,
    _logger = nil,
    _storage = {},  -- In-memory fallback when no platform storage
    _metadata = {},
    _initialized = false
  }

  -- Handle backward compatibility with container parameter
  if config_or_container and type(config_or_container.has) == "function" then
    -- Legacy container-based initialization
    local container = config_or_container
    self._state = container:has("state") and container:resolve("state") or nil
    self._serializer = container:has("serializer") and container:resolve("serializer") or nil
    self._events = container:has("events") and container:resolve("events") or nil
    self._platform = container:has("platform") and container:resolve("platform") or nil
    self._logger = container:has("logger") and container:resolve("logger") or nil
  elseif deps then
    -- New DI pattern
    self._state = deps.state
    self._serializer = deps.serializer
    self._events = deps.event_bus
    self._platform = deps.file_storage or deps.platform
    self._logger = deps.logger
  end

  self._initialized = true

  if self._logger then
    self._logger:debug("PersistenceService initialized")
  end

  return setmetatable(self, { __index = PersistenceService })
end

--- Get the service name
-- @return string The service name
function PersistenceService:getName()
  return "persistence"
end

--- Check if the service is initialized
-- @return boolean True if initialized
function PersistenceService:isInitialized()
  return self._initialized == true
end

--- Save current state to a slot
-- @param slot string Save slot identifier
-- @param metadata table|nil Optional metadata (description, etc.)
-- @return boolean success True if saved successfully
function PersistenceService:save(slot, metadata)
  if not self._state then
    error("PersistenceService requires IState implementation")
  end

  if self._logger then
    self._logger:debug("Saving to slot: " .. tostring(slot))
  end

  local snapshot = self._state:snapshot()

  -- Add metadata
  local save_data = {
    version = PersistenceService.version,
    timestamp = os.time(),
    slot = slot,
    state = snapshot,
    metadata = metadata or {},
  }

  local serialized
  if self._serializer then
    serialized = self._serializer:serialize(save_data)
  else
    -- Fallback: store directly
    serialized = save_data
  end

  -- Use platform storage if available, otherwise use in-memory
  if self._platform and self._platform.save then
    local success = self._platform:save("whisker_save_" .. slot, serialized)

    if success then
      if self._logger then
        self._logger:debug("Save successful: " .. tostring(slot))
      end

      if self._events then
        self._events:emit("save:created", {
          slot = slot,
          timestamp = save_data.timestamp,
          metadata = metadata
        })
      end
    end

    return success
  else
    -- Store in-memory
    self._storage[slot] = serialized
    self._metadata[slot] = {
      timestamp = save_data.timestamp,
      metadata = metadata
    }

    if self._logger then
      self._logger:debug("Save to memory: " .. tostring(slot))
    end

    if self._events then
      self._events:emit("save:created", {
        slot = slot,
        data = serialized,
        timestamp = save_data.timestamp,
        metadata = metadata
      })
    end
    return true
  end
end

--- Load state from a slot
-- @param slot string Save slot identifier
-- @return boolean success True if loaded successfully
function PersistenceService:load(slot)
  if not self._state then
    error("PersistenceService requires IState implementation")
  end

  if self._logger then
    self._logger:debug("Loading from slot: " .. tostring(slot))
  end

  local serialized

  if self._platform and self._platform.load then
    serialized = self._platform:load("whisker_save_" .. slot)
  else
    serialized = self._storage[slot]
  end

  if not serialized then
    if self._logger then
      self._logger:debug("Slot not found: " .. tostring(slot))
    end
    return false
  end

  local save_data
  if self._serializer and type(serialized) == "string" then
    save_data = self._serializer:deserialize(serialized)
  else
    save_data = serialized
  end

  -- Validate save data
  if not save_data or not save_data.state then
    error("Invalid save data: missing state")
  end

  -- Restore state
  self._state:restore(save_data.state)

  if self._logger then
    self._logger:debug("Load successful: " .. tostring(slot))
  end

  if self._events then
    self._events:emit("save:loaded", {
      slot = slot,
      timestamp = save_data.timestamp,
      metadata = save_data.metadata
    })
  end

  return true
end

--- Delete a save slot
-- @param slot string Save slot identifier
-- @return boolean success True if deleted
function PersistenceService:delete(slot)
  if self._logger then
    self._logger:debug("Deleting slot: " .. tostring(slot))
  end

  local existed = false

  if self._platform and self._platform.delete then
    existed = self._platform:delete("whisker_save_" .. slot)
  else
    existed = self._storage[slot] ~= nil
    self._storage[slot] = nil
    self._metadata[slot] = nil
  end

  if existed then
    if self._logger then
      self._logger:debug("Deleted slot: " .. tostring(slot))
    end

    if self._events then
      self._events:emit("save:deleted", {
        slot = slot,
        timestamp = os.time()
      })
    end
  end

  return existed
end

--- Check if a save slot exists
-- @param slot string Save slot identifier
-- @return boolean exists True if the slot exists
function PersistenceService:exists(slot)
  if self._platform and self._platform.exists then
    return self._platform:exists("whisker_save_" .. slot)
  else
    return self._storage[slot] ~= nil
  end
end

--- List all save slots
-- @return table[] saves Array of save metadata
function PersistenceService:list_saves()
  local result = {}

  if self._platform and self._platform.list then
    -- Get from platform storage
    local saves = self._platform:list("whisker_save_")
    for _, key in ipairs(saves or {}) do
      local slot = key:gsub("^whisker_save_", "")
      table.insert(result, {
        slot = slot,
        timestamp = nil,  -- Would need to load to get timestamp
      })
    end
  else
    -- Get from in-memory storage
    for slot, meta in pairs(self._metadata) do
      table.insert(result, {
        slot = slot,
        timestamp = meta.timestamp,
        metadata = meta.metadata
      })
    end
  end

  -- Sort by slot name
  table.sort(result, function(a, b) return a.slot < b.slot end)

  return result
end

--- Get metadata for a save slot
-- @param slot string Save slot identifier
-- @return table|nil metadata The save metadata
function PersistenceService:get_metadata(slot)
  if self._metadata[slot] then
    return self._metadata[slot].metadata
  end
  return nil
end

--- Quick save to default slot
-- @return boolean success True if saved
function PersistenceService:quick_save()
  if self._logger then
    self._logger:debug("Quick save")
  end
  return self:save("quicksave", { type = "quicksave" })
end

--- Quick load from default slot
-- @return boolean success True if loaded
function PersistenceService:quick_load()
  if self._logger then
    self._logger:debug("Quick load")
  end
  return self:load("quicksave")
end

--- Auto save to numbered slot
-- @param max_slots number Maximum number of auto-save slots (default 3)
-- @return boolean success True if saved
function PersistenceService:auto_save(max_slots)
  max_slots = max_slots or 3

  -- Find next slot number
  local highest = 0
  for _, save in ipairs(self:list_saves()) do
    local num = tonumber(save.slot:match("^autosave_(%d+)$"))
    if num and num > highest then
      highest = num
    end
  end

  local next_slot = (highest % max_slots) + 1

  if self._logger then
    self._logger:debug("Auto save to slot: autosave_" .. tostring(next_slot))
  end

  return self:save("autosave_" .. next_slot, { type = "autosave" })
end

--- Destroy the service and cleanup
function PersistenceService:destroy()
  if self._logger then
    self._logger:debug("PersistenceService destroying")
  end

  self._storage = {}
  self._metadata = {}
  self._state = nil
  self._serializer = nil
  self._events = nil
  self._platform = nil
  self._logger = nil
  self._initialized = false
end

return PersistenceService
