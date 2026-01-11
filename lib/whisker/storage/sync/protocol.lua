--- Storage Sync Protocol
-- Defines data structures and algorithms for cross-device synchronization
--
-- @module whisker.storage.sync.protocol
-- @author Whisker Team
-- @license MIT
-- @usage
-- local Protocol = require("whisker.storage.sync.protocol")
-- local op = Protocol.create_operation("UPDATE", "story-1", data)

local OT = require("whisker.collaboration.ot")

local Protocol = {}

--- Operation types for sync
Protocol.OperationType = {
  CREATE = "create",
  UPDATE = "update",
  DELETE = "delete",
  METADATA_UPDATE = "metadata_update"
}

--- Conflict resolution strategies
Protocol.ConflictStrategy = {
  LAST_WRITE_WINS = "last_write_wins",
  MANUAL = "manual",
  AUTO_MERGE = "auto_merge",
  KEEP_BOTH = "keep_both"
}

--- Create a sync operation
-- @param op_type string Operation type (CREATE, UPDATE, DELETE, METADATA_UPDATE)
-- @param story_id string Story identifier
-- @param data table Story data or metadata
-- @param metadata table Optional metadata (device_id, timestamp, etc.)
-- @return table SyncOperation
function Protocol.create_operation(op_type, story_id, data, metadata)
  metadata = metadata or {}
  
  return {
    id = Protocol._generate_operation_id(),
    type = op_type,
    story_id = story_id,
    data = data,
    metadata = metadata,
    timestamp = os.time(),
    device_id = metadata.device_id or "unknown"
  }
end

--- Generate unique operation ID
-- @return string UUID-like identifier
function Protocol._generate_operation_id()
  -- Simple UUID v4 implementation
  local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
  return string.gsub(template, '[xy]', function(c)
    local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
    return string.format('%x', v)
  end)
end

--- Detect conflicts between local and remote operations
-- @param local_ops table Array of local operations
-- @param remote_ops table Array of remote operations
-- @return table Array of SyncConflict objects
function Protocol.detect_conflicts(local_ops, remote_ops)
  local conflicts = {}
  
  -- Build story operation map
  local local_map = {}
  for _, op in ipairs(local_ops) do
    if not local_map[op.story_id] then
      local_map[op.story_id] = {}
    end
    table.insert(local_map[op.story_id], op)
  end
  
  local remote_map = {}
  for _, op in ipairs(remote_ops) do
    if not remote_map[op.story_id] then
      remote_map[op.story_id] = {}
    end
    table.insert(remote_map[op.story_id], op)
  end
  
  -- Find conflicting stories
  for story_id, local_story_ops in pairs(local_map) do
    local remote_story_ops = remote_map[story_id]
    
    if remote_story_ops then
      -- Both modified the same story
      local conflict = Protocol._create_conflict(
        story_id,
        local_story_ops,
        remote_story_ops
      )
      
      if conflict then
        table.insert(conflicts, conflict)
      end
    end
  end
  
  return conflicts
end

--- Create conflict object
-- @param story_id string Story identifier
-- @param local_ops table Local operations
-- @param remote_ops table Remote operations
-- @return table SyncConflict or nil if no conflict
function Protocol._create_conflict(story_id, local_ops, remote_ops)
  -- Check if operations are truly conflicting
  local local_latest = local_ops[#local_ops]
  local remote_latest = remote_ops[#remote_ops]
  
  -- If both modified at same time (concurrent), it's a conflict
  local time_diff = math.abs(local_latest.timestamp - remote_latest.timestamp)
  
  if time_diff < 5 then -- Within 5 seconds = concurrent
    return {
      story_id = story_id,
      local_operations = local_ops,
      remote_operations = remote_ops,
      local_version = local_latest,
      remote_version = remote_latest,
      conflict_type = Protocol._determine_conflict_type(local_latest, remote_latest)
    }
  end
  
  return nil
end

--- Determine type of conflict
-- @param local_op table Local operation
-- @param remote_op table Remote operation
-- @return string Conflict type
function Protocol._determine_conflict_type(local_op, remote_op)
  if local_op.type == Protocol.OperationType.UPDATE and 
     remote_op.type == Protocol.OperationType.UPDATE then
    return "concurrent_update"
  elseif local_op.type == Protocol.OperationType.DELETE and
         remote_op.type == Protocol.OperationType.UPDATE then
    return "delete_update_conflict"
  elseif local_op.type == Protocol.OperationType.UPDATE and
         remote_op.type == Protocol.OperationType.DELETE then
    return "update_delete_conflict"
  else
    return "unknown"
  end
end

--- Resolve a conflict using specified strategy
-- @param conflict table SyncConflict object
-- @param strategy string Resolution strategy
-- @param resolver_fn function Optional custom resolver function
-- @return table Resolved data
function Protocol.resolve_conflict(conflict, strategy, resolver_fn)
  if strategy == Protocol.ConflictStrategy.LAST_WRITE_WINS then
    return Protocol._resolve_last_write_wins(conflict)
  elseif strategy == Protocol.ConflictStrategy.AUTO_MERGE then
    return Protocol._resolve_auto_merge(conflict)
  elseif strategy == Protocol.ConflictStrategy.KEEP_BOTH then
    return Protocol._resolve_keep_both(conflict)
  elseif strategy == Protocol.ConflictStrategy.MANUAL then
    if resolver_fn then
      return resolver_fn(conflict)
    else
      error("Manual strategy requires resolver_fn")
    end
  else
    error("Unknown conflict strategy: " .. tostring(strategy))
  end
end

--- Resolve using last-write-wins strategy
-- @param conflict table SyncConflict
-- @return table Resolved data
function Protocol._resolve_last_write_wins(conflict)
  local local_time = conflict.local_version.timestamp
  local remote_time = conflict.remote_version.timestamp
  
  if local_time >= remote_time then
    return {
      winner = "local",
      data = conflict.local_version.data,
      operation = conflict.local_version
    }
  else
    return {
      winner = "remote",
      data = conflict.remote_version.data,
      operation = conflict.remote_version
    }
  end
end

--- Resolve using auto-merge strategy (uses OT if applicable)
-- @param conflict table SyncConflict
-- @return table Merged data
function Protocol._resolve_auto_merge(conflict)
  local local_data = conflict.local_version.data
  local remote_data = conflict.remote_version.data
  
  -- Try to merge non-conflicting fields
  local merged = {}
  
  -- Start with local data
  for k, v in pairs(local_data) do
    merged[k] = v
  end
  
  -- Merge remote data (non-conflicting fields)
  for k, v in pairs(remote_data) do
    if merged[k] == nil then
      -- New field from remote
      merged[k] = v
    elseif type(merged[k]) == "table" and type(v) == "table" then
      -- Recursively merge tables
      merged[k] = Protocol._merge_tables(merged[k], v)
    elseif merged[k] == v then
      -- Same value, no conflict
      merged[k] = v
    else
      -- Conflict on this field, use last-write-wins
      if conflict.remote_version.timestamp > conflict.local_version.timestamp then
        merged[k] = v
      end
    end
  end
  
  return {
    winner = "merged",
    data = merged,
    operation = {
      type = Protocol.OperationType.UPDATE,
      story_id = conflict.story_id,
      data = merged,
      timestamp = math.max(conflict.local_version.timestamp, conflict.remote_version.timestamp),
      device_id = "merged"
    }
  }
end

--- Merge two tables recursively
-- @param t1 table First table
-- @param t2 table Second table
-- @return table Merged table
function Protocol._merge_tables(t1, t2)
  local result = {}
  
  for k, v in pairs(t1) do
    result[k] = v
  end
  
  for k, v in pairs(t2) do
    if result[k] == nil then
      result[k] = v
    elseif type(result[k]) == "table" and type(v) == "table" then
      result[k] = Protocol._merge_tables(result[k], v)
    end
  end
  
  return result
end

--- Resolve by keeping both versions
-- @param conflict table SyncConflict
-- @return table Both versions with renamed IDs
function Protocol._resolve_keep_both(conflict)
  local local_copy = {
    story_id = conflict.story_id .. "-local-" .. os.time(),
    data = conflict.local_version.data,
    metadata = {original_id = conflict.story_id, source = "local"}
  }
  
  local remote_copy = {
    story_id = conflict.story_id .. "-remote-" .. os.time(),
    data = conflict.remote_version.data,
    metadata = {original_id = conflict.story_id, source = "remote"}
  }
  
  return {
    winner = "both",
    local_copy = local_copy,
    remote_copy = remote_copy
  }
end

--- Generate delta between two states
-- @param old_state table Previous state
-- @param new_state table New state
-- @return table Array of delta operations
function Protocol.generate_delta(old_state, new_state)
  local delta = {}
  
  -- Check for created stories
  for story_id, new_data in pairs(new_state) do
    if not old_state[story_id] then
      table.insert(delta, Protocol.create_operation(
        Protocol.OperationType.CREATE,
        story_id,
        new_data
      ))
    end
  end
  
  -- Check for updated or deleted stories
  for story_id, old_data in pairs(old_state) do
    local new_data = new_state[story_id]
    
    if not new_data then
      -- Story deleted
      table.insert(delta, Protocol.create_operation(
        Protocol.OperationType.DELETE,
        story_id,
        nil
      ))
    elseif not Protocol._deep_equal(old_data, new_data) then
      -- Story updated
      table.insert(delta, Protocol.create_operation(
        Protocol.OperationType.UPDATE,
        story_id,
        new_data
      ))
    end
  end
  
  return delta
end

--- Deep equality check
-- @param t1 table First table
-- @param t2 table Second table
-- @return boolean True if deeply equal
function Protocol._deep_equal(t1, t2)
  if type(t1) ~= type(t2) then return false end
  if type(t1) ~= "table" then return t1 == t2 end
  
  -- Check all keys in t1
  for k, v in pairs(t1) do
    if not Protocol._deep_equal(v, t2[k]) then
      return false
    end
  end
  
  -- Check all keys in t2
  for k, v in pairs(t2) do
    if t1[k] == nil then
      return false
    end
  end
  
  return true
end

--- Apply delta operations to current state
-- @param current_state table Current state
-- @param delta_ops table Array of delta operations
-- @return table New state after applying delta
function Protocol.apply_delta(current_state, delta_ops)
  local new_state = {}
  
  -- Copy current state
  for k, v in pairs(current_state) do
    new_state[k] = v
  end
  
  -- Apply each operation
  for _, op in ipairs(delta_ops) do
    if op.type == Protocol.OperationType.CREATE or
       op.type == Protocol.OperationType.UPDATE then
      new_state[op.story_id] = op.data
    elseif op.type == Protocol.OperationType.DELETE then
      new_state[op.story_id] = nil
    elseif op.type == Protocol.OperationType.METADATA_UPDATE then
      if new_state[op.story_id] then
        new_state[op.story_id].metadata = op.data
      end
    end
  end
  
  return new_state
end

--- Create version vector for causality tracking
-- @return table Version vector {device_id -> version}
function Protocol.create_version_vector()
  return {}
end

--- Update version vector
-- @param vector table Version vector
-- @param device_id string Device identifier
-- @param version number New version for device
-- @return table Updated version vector
function Protocol.update_version_vector(vector, device_id, version)
  vector[device_id] = version
  return vector
end

--- Compare version vectors for causality
-- @param v1 table First version vector
-- @param v2 table Second version vector
-- @return string "before", "after", "concurrent", or "equal"
function Protocol.compare_version_vectors(v1, v2)
  local v1_less_or_equal = true
  local v2_less_or_equal = true
  
  -- Check all devices
  local all_devices = {}
  for device_id in pairs(v1) do all_devices[device_id] = true end
  for device_id in pairs(v2) do all_devices[device_id] = true end
  
  for device_id in pairs(all_devices) do
    local v1_version = v1[device_id] or 0
    local v2_version = v2[device_id] or 0
    
    if v1_version > v2_version then
      v1_less_or_equal = false  -- v1 has a higher version, so v1 is NOT <= v2
    elseif v2_version > v1_version then
      v2_less_or_equal = false  -- v2 has a higher version, so v2 is NOT <= v1
    end
  end
  
  if v1_less_or_equal and v2_less_or_equal then
    return "equal"
  elseif v1_less_or_equal then
    return "before"  -- v1 <= v2 but not equal, so v1 before v2
  elseif v2_less_or_equal then
    return "after"   -- v2 <= v1 but not equal, so v1 after v2
  else
    return "concurrent"
  end
end

return Protocol
