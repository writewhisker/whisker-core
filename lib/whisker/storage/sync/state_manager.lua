--- Sync State Manager - Manages sync state persistence and tracking
-- Handles device ID generation, pending operations queue, version vectors,
-- sync statistics, and error tracking
--
-- @module whisker.storage.sync.state_manager
-- @author Whisker Team
-- @license MIT

local SyncStateManager = {}
SyncStateManager.__index = SyncStateManager

--- Sync status constants
SyncStateManager.Status = {
  IDLE = "idle",
  SYNCING = "syncing",
  ERROR = "error"
}

--- Default sync state structure
local DEFAULT_STATE = {
  device_id = nil,
  last_sync_time = 0,
  version_vector = {},
  pending_operations = {},
  sync_status = "idle",
  last_error = nil,
  stats = {
    total_syncs = 0,
    last_sync_duration_ms = 0,
    conflicts_resolved = 0,
    bandwidth_sent_bytes = 0,
    bandwidth_received_bytes = 0
  }
}

--- Create a new SyncStateManager
-- @param storage_service Instance of StorageService for persisting state
-- @return SyncStateManager
function SyncStateManager.new(storage_service)
  local self = setmetatable({}, SyncStateManager)
  
  self._storage = storage_service
  self._state_key = "_whisker_sync_state"
  self._state = nil
  
  -- Load existing state or create default
  self:_load_or_create_state()
  
  return self
end

--- Load existing state or create default state
function SyncStateManager:_load_or_create_state()
  -- Try to load existing state
  local saved_state, err = self._storage.backend:load(self._state_key)
  
  if saved_state then
    self._state = saved_state
  else
    -- Create default state
    self._state = self:_deep_copy(DEFAULT_STATE)
    
    -- Generate device ID if not exists
    if not self._state.device_id then
      self._state.device_id = self:_generate_uuid()
    end
    
    -- Save initial state
    self:_persist_state()
  end
end

--- Deep copy a table
-- @param orig table Original table
-- @return table Copied table
function SyncStateManager:_deep_copy(orig)
  local copy
  if type(orig) == 'table' then
    copy = {}
    for k, v in next, orig, nil do
      copy[self:_deep_copy(k)] = self:_deep_copy(v)
    end
  else
    copy = orig
  end
  return copy
end

--- Generate UUID v4
-- @return string UUID
function SyncStateManager:_generate_uuid()
  local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
  local uuid = string.gsub(template, '[xy]', function(c)
    local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
    return string.format('%x', v)
  end)
  return uuid
end

--- Persist state to storage
-- @return boolean success
-- @return string|nil error
function SyncStateManager:_persist_state()
  return self._storage.backend:save(self._state_key, self._state, {})
end

--- Load sync state
-- @return table Sync state
function SyncStateManager:load_state()
  return self:_deep_copy(self._state)
end

--- Save sync state
-- @param state table Sync state to save
-- @return boolean success
-- @return string|nil error
function SyncStateManager:save_state(state)
  self._state = self:_deep_copy(state)
  return self:_persist_state()
end

--- Get device ID
-- @return string Device ID
function SyncStateManager:get_device_id()
  if not self._state.device_id then
    self._state.device_id = self:_generate_uuid()
    self:_persist_state()
  end
  return self._state.device_id
end

--- Update last sync time
-- @param timestamp number Unix timestamp
-- @return boolean success
function SyncStateManager:update_last_sync_time(timestamp)
  self._state.last_sync_time = timestamp
  return self:_persist_state()
end

--- Get last sync time
-- @return number Unix timestamp
function SyncStateManager:get_last_sync_time()
  return self._state.last_sync_time
end

--- Update version vector for a device
-- @param device_id string Device ID
-- @param version number Version number
-- @return boolean success
function SyncStateManager:update_version_vector(device_id, version)
  self._state.version_vector[device_id] = version
  return self:_persist_state()
end

--- Get version vector
-- @return table Version vector {device_id = version}
function SyncStateManager:get_version_vector()
  return self:_deep_copy(self._state.version_vector)
end

--- Get version for a specific device
-- @param device_id string Device ID
-- @return number Version (0 if not found)
function SyncStateManager:get_device_version(device_id)
  return self._state.version_vector[device_id] or 0
end

--- Set sync status
-- @param status string Status (idle, syncing, error)
-- @return boolean success
function SyncStateManager:set_sync_status(status)
  self._state.sync_status = status
  return self:_persist_state()
end

--- Get sync status
-- @return string Status
function SyncStateManager:get_sync_status()
  return self._state.sync_status
end

--- Add pending operation to queue
-- @param operation table Operation to queue
-- @return boolean success
function SyncStateManager:queue_operation(operation)
  table.insert(self._state.pending_operations, operation)
  return self:_persist_state()
end

--- Get pending operations
-- @return table[] Array of pending operations
function SyncStateManager:get_pending_operations()
  return self:_deep_copy(self._state.pending_operations)
end

--- Remove pending operation by index
-- @param index number Index of operation to remove
-- @return boolean success
function SyncStateManager:remove_pending_operation(index)
  if index > 0 and index <= #self._state.pending_operations then
    table.remove(self._state.pending_operations, index)
    return self:_persist_state()
  end
  return false
end

--- Remove pending operation by matching operation
-- @param operation table Operation to remove
-- @return boolean success
function SyncStateManager:remove_pending_operation_by_match(operation)
  for i, pending_op in ipairs(self._state.pending_operations) do
    if pending_op.type == operation.type and 
       pending_op.story_id == operation.story_id and
       pending_op.timestamp == operation.timestamp then
      return self:remove_pending_operation(i)
    end
  end
  return false
end

--- Clear all pending operations
-- @return boolean success
function SyncStateManager:clear_pending_operations()
  self._state.pending_operations = {}
  return self:_persist_state()
end

--- Get count of pending operations
-- @return number Count
function SyncStateManager:get_pending_count()
  return #self._state.pending_operations
end

--- Record sync completion
-- @param duration_ms number Sync duration in milliseconds
-- @param operations_count number Number of operations synced
-- @param conflicts_count number Number of conflicts resolved
-- @return boolean success
function SyncStateManager:record_sync(duration_ms, operations_count, conflicts_count)
  self._state.stats.total_syncs = self._state.stats.total_syncs + 1
  self._state.stats.last_sync_duration_ms = duration_ms
  self._state.stats.conflicts_resolved = self._state.stats.conflicts_resolved + (conflicts_count or 0)
  
  return self:_persist_state()
end

--- Record bandwidth usage
-- @param sent_bytes number Bytes sent
-- @param received_bytes number Bytes received
-- @return boolean success
function SyncStateManager:record_bandwidth(sent_bytes, received_bytes)
  self._state.stats.bandwidth_sent_bytes = self._state.stats.bandwidth_sent_bytes + (sent_bytes or 0)
  self._state.stats.bandwidth_received_bytes = self._state.stats.bandwidth_received_bytes + (received_bytes or 0)
  
  return self:_persist_state()
end

--- Get sync statistics
-- @return table Statistics
function SyncStateManager:get_stats()
  return self:_deep_copy(self._state.stats)
end

--- Reset statistics
-- @return boolean success
function SyncStateManager:reset_stats()
  self._state.stats = {
    total_syncs = 0,
    last_sync_duration_ms = 0,
    conflicts_resolved = 0,
    bandwidth_sent_bytes = 0,
    bandwidth_received_bytes = 0
  }
  return self:_persist_state()
end

--- Record sync error
-- @param error_message string Error message
-- @return boolean success
function SyncStateManager:record_error(error_message)
  self._state.last_error = {
    message = error_message,
    timestamp = os.time()
  }
  self._state.sync_status = SyncStateManager.Status.ERROR
  
  return self:_persist_state()
end

--- Clear error
-- @return boolean success
function SyncStateManager:clear_error()
  self._state.last_error = nil
  if self._state.sync_status == SyncStateManager.Status.ERROR then
    self._state.sync_status = SyncStateManager.Status.IDLE
  end
  
  return self:_persist_state()
end

--- Get last error
-- @return table|nil Error {message, timestamp} or nil
function SyncStateManager:get_last_error()
  if self._state.last_error then
    return self:_deep_copy(self._state.last_error)
  end
  return nil
end

--- Reset all state (except device ID)
-- @return boolean success
function SyncStateManager:reset()
  local device_id = self._state.device_id
  
  self._state = self:_deep_copy(DEFAULT_STATE)
  self._state.device_id = device_id
  
  return self:_persist_state()
end

--- Get full state for debugging
-- @return table Complete state
function SyncStateManager:get_full_state()
  return self:_deep_copy(self._state)
end

--- Update multiple version vector entries at once
-- @param version_vector table Map of {device_id = version}
-- @return boolean success
function SyncStateManager:update_version_vector_batch(version_vector)
  for device_id, version in pairs(version_vector) do
    self._state.version_vector[device_id] = version
  end
  return self:_persist_state()
end

--- Add multiple pending operations
-- @param operations table[] Array of operations
-- @return boolean success
function SyncStateManager:queue_operations_batch(operations)
  for _, operation in ipairs(operations) do
    table.insert(self._state.pending_operations, operation)
  end
  return self:_persist_state()
end

--- Check if currently syncing
-- @return boolean True if syncing
function SyncStateManager:is_syncing()
  return self._state.sync_status == SyncStateManager.Status.SYNCING
end

--- Check if in error state
-- @return boolean True if error
function SyncStateManager:has_error()
  return self._state.sync_status == SyncStateManager.Status.ERROR
end

--- Get time since last sync
-- @return number Seconds since last sync
function SyncStateManager:get_time_since_last_sync()
  if self._state.last_sync_time == 0 then
    return -1  -- Never synced
  end
  return os.time() - self._state.last_sync_time
end

return SyncStateManager
