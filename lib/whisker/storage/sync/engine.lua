--- Storage Sync Engine
-- Orchestrates synchronization between local and remote storage
--
-- @module whisker.storage.sync.engine
-- @author Whisker Team
-- @license MIT
-- @usage
-- local SyncEngine = require("whisker.storage.sync.engine")
-- local engine = SyncEngine.new(config)
-- engine:start_sync()

local Protocol = require("whisker.storage.sync.protocol")

local SyncEngine = {}
SyncEngine.__index = SyncEngine

--- Sync status values
SyncEngine.Status = {
  IDLE = "idle",
  SYNCING = "syncing",
  ERROR = "error"
}

--- Create new sync engine
-- @param config table Configuration
--   - storage: StorageService instance
--   - transport: Transport adapter (HTTP, WebSocket, etc.)
--   - device_id: Unique device identifier
--   - sync_interval: Auto-sync interval in milliseconds (default 60000)
--   - conflict_resolver: Function(conflict) -> resolution
-- @return SyncEngine instance
function SyncEngine.new(config)
  local self = setmetatable({}, SyncEngine)
  
  self._config = config or {}
  self._storage = config.storage
  self._transport = config.transport
  self._device_id = config.device_id or "device-" .. os.time()
  self._sync_interval = config.sync_interval or 60000 -- 1 minute
  self._conflict_resolver = config.conflict_resolver
  
  -- State
  self._status = SyncEngine.Status.IDLE
  self._running = false
  self._sync_timer = nil
  self._last_sync_time = 0
  self._sync_version = 0
  
  -- Event listeners
  self._listeners = {}
  
  return self
end

--- Start auto-sync
function SyncEngine:start_sync()
  if self._running then
    return
  end
  
  self._running = true
  self:_emit("sync_started", {})
  
  -- Perform initial sync
  self:sync_now()
  
  -- Schedule periodic sync
  self:_schedule_next_sync()
end

--- Stop auto-sync
function SyncEngine:stop_sync()
  if not self._running then
    return
  end
  
  self._running = false
  
  if self._sync_timer then
    -- Note: Lua doesn't have built-in timers, would need platform-specific implementation
    -- For now, this is a placeholder
    self._sync_timer = nil
  end
  
  self:_emit("sync_stopped", {})
end

--- Force immediate sync
-- @return boolean success True if sync completed successfully
-- @return string|nil error Error message if sync failed
function SyncEngine:sync_now()
  if self._status == SyncEngine.Status.SYNCING then
    return false, "Sync already in progress"
  end
  
  self._status = SyncEngine.Status.SYNCING
  self:_emit("sync_progress", {current = 0, total = 100, operation = "starting"})
  
  local success, err = pcall(function()
    -- Step 1: Fetch remote operations
    self:_emit("sync_progress", {current = 10, total = 100, operation = "fetching_remote"})
    local remote_ops = self:_fetch_remote_operations()
    
    -- Step 2: Get local operations
    self:_emit("sync_progress", {current = 30, total = 100, operation = "collecting_local"})
    local local_ops = self:_get_local_operations()
    
    -- Step 3: Detect conflicts
    self:_emit("sync_progress", {current = 50, total = 100, operation = "detecting_conflicts"})
    local conflicts = Protocol.detect_conflicts(local_ops, remote_ops)
    
    -- Step 4: Resolve conflicts
    if #conflicts > 0 then
      self:_emit("sync_progress", {current = 60, total = 100, operation = "resolving_conflicts"})
      self:_resolve_conflicts(conflicts)
    end
    
    -- Step 5: Apply remote operations
    self:_emit("sync_progress", {current = 70, total = 100, operation = "applying_remote"})
    local applied_count = self:_apply_remote_operations(remote_ops)
    
    -- Step 6: Push local operations
    self:_emit("sync_progress", {current = 85, total = 100, operation = "pushing_local"})
    self:_push_local_operations(local_ops)
    
    -- Step 7: Update sync state
    self:_emit("sync_progress", {current = 95, total = 100, operation = "updating_state"})
    self._last_sync_time = os.time()
    self._sync_version = self._sync_version + 1
    
    -- Complete
    self:_emit("sync_progress", {current = 100, total = 100, operation = "complete"})
    self:_emit("sync_completed", {
      operations_applied = applied_count,
      conflicts_resolved = #conflicts,
      timestamp = self._last_sync_time
    })
  end)
  
  if success then
    self._status = SyncEngine.Status.IDLE
    return true
  else
    self._status = SyncEngine.Status.ERROR
    self:_emit("sync_failed", {error = err, retry_count = 0})
    return false, tostring(err)
  end
end

--- Get sync status
-- @return string Current status (idle, syncing, error)
function SyncEngine:get_sync_status()
  return self._status
end

--- Get last sync time
-- @return number Unix timestamp of last successful sync
function SyncEngine:get_last_sync_time()
  return self._last_sync_time
end

--- Add event listener
-- @param event string Event name
-- @param callback function Callback function
function SyncEngine:on(event, callback)
  if not self._listeners[event] then
    self._listeners[event] = {}
  end
  table.insert(self._listeners[event], callback)
end

--- Remove event listener
-- @param event string Event name
-- @param callback function Callback function to remove
function SyncEngine:off(event, callback)
  if not self._listeners[event] then
    return
  end
  
  for i, cb in ipairs(self._listeners[event]) do
    if cb == callback then
      table.remove(self._listeners[event], i)
      break
    end
  end
end

--- Emit event to listeners
-- @param event string Event name
-- @param data table Event data
function SyncEngine:_emit(event, data)
  if not self._listeners[event] then
    return
  end
  
  for _, callback in ipairs(self._listeners[event]) do
    local success, err = pcall(callback, data)
    if not success then
      print(string.format("Error in event listener for '%s': %s", event, err))
    end
  end
end

--- Schedule next sync
function SyncEngine:_schedule_next_sync()
  if not self._running then
    return
  end
  
  -- Note: This is a simplified implementation
  -- In production, would use platform-specific timers (libuv, ev, etc.)
  -- For now, just mark that we should sync again
  self._sync_timer = os.time() + (self._sync_interval / 1000)
end

--- Fetch remote operations since last sync
-- @return table Array of remote operations
function SyncEngine:_fetch_remote_operations()
  if not self._transport then
    return {}
  end
  
  local result = self._transport:fetch_operations(
    self._device_id,
    self._sync_version
  )
  
  return result.operations or {}
end

--- Get local operations since last sync
-- @return table Array of local operations
function SyncEngine:_get_local_operations()
  if not self._storage then
    return {}
  end
  
  -- Get all stories from storage
  local stories = self._storage:list() or {}
  local operations = {}
  
  -- Create operations for each story
  for _, story_info in ipairs(stories) do
    local story_id = story_info.id or story_info.key
    local story_data = self._storage:load(story_id)
    
    if story_data then
      local op = Protocol.create_operation(
        Protocol.OperationType.UPDATE,
        story_id,
        story_data,
        {device_id = self._device_id}
      )
      table.insert(operations, op)
    end
  end
  
  return operations
end

--- Resolve conflicts
-- @param conflicts table Array of conflict objects
function SyncEngine:_resolve_conflicts(conflicts)
  for _, conflict in ipairs(conflicts) do
    local strategy = Protocol.ConflictStrategy.LAST_WRITE_WINS
    local resolver = self._conflict_resolver
    
    if resolver then
      strategy = Protocol.ConflictStrategy.MANUAL
    end
    
    local resolution = Protocol.resolve_conflict(conflict, strategy, resolver)
    
    self:_emit("conflict_detected", {
      conflict = conflict,
      resolution = resolution,
      auto_resolved = strategy ~= Protocol.ConflictStrategy.MANUAL
    })
    
    -- Apply resolution
    if resolution.winner == "local" then
      -- Keep local version, nothing to do
    elseif resolution.winner == "remote" then
      -- Use remote version
      self._storage:save(conflict.story_id, resolution.data)
    elseif resolution.winner == "merged" then
      -- Use merged version
      self._storage:save(conflict.story_id, resolution.data)
    elseif resolution.winner == "both" then
      -- Save both versions with different IDs
      self._storage:save(resolution.local_copy.story_id, resolution.local_copy.data)
      self._storage:save(resolution.remote_copy.story_id, resolution.remote_copy.data)
    else
      -- Custom or unknown winner type - use the data if provided
      if resolution.data then
        self._storage:save(conflict.story_id, resolution.data)
      end
    end
  end
end

--- Apply remote operations to local storage
-- @param operations table Array of remote operations
-- @return number Count of operations applied
function SyncEngine:_apply_remote_operations(operations)
  local applied = 0
  
  for _, op in ipairs(operations) do
    repeat
      -- Skip operations from this device
      if op.device_id == self._device_id then
        break
      end

      if op.type == Protocol.OperationType.CREATE or
         op.type == Protocol.OperationType.UPDATE then
        self._storage:save(op.story_id, op.data)
        applied = applied + 1
      elseif op.type == Protocol.OperationType.DELETE then
        self._storage:delete(op.story_id)
        applied = applied + 1
      elseif op.type == Protocol.OperationType.METADATA_UPDATE then
        -- Update metadata only
        local story = self._storage:load(op.story_id)
        if story then
          story.metadata = op.data
          self._storage:save(op.story_id, story)
          applied = applied + 1
        end
      end
    until true
  end
  
  return applied
end

--- Push local operations to remote
-- @param operations table Array of local operations
-- @return boolean success True if push succeeded
function SyncEngine:_push_local_operations(operations)
  if not self._transport then
    return false
  end
  
  if #operations == 0 then
    return true
  end
  
  local result = self._transport:push_operations(self._device_id, operations)
  
  if result.success then
    return true
  else
    -- Handle conflicts returned by server
    if result.conflicts then
      self:_resolve_conflicts(result.conflicts)
    end
    return false
  end
end

return SyncEngine
