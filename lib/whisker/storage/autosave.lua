--- Autosave System
-- Automatic story saving with debouncing, retry logic, and conflict detection
--
-- @module whisker.storage.autosave
-- @author Whisker Team
-- @license MIT
-- @usage
-- local Autosave = require("whisker.storage.autosave")
-- local autosaver = Autosave.new({ storage = storage, interval = 30 })

local Autosave = {}
Autosave.__index = Autosave

--- Autosave states
Autosave.State = {
  IDLE = "idle",
  SAVING = "saving",
  SAVED = "saved",
  ERROR = "error",
  PAUSED = "paused"
}

--- Create new autosave manager
-- @param options table Configuration
-- @param options.storage table Storage service instance
-- @param options.interval number Autosave interval in seconds (default: 30)
-- @param options.max_retries number Maximum retry attempts (default: 3)
-- @param options.debounce number Debounce time in seconds (default: 2)
-- @param options.on_save function Callback(success, error, story_id)
-- @param options.on_conflict function Callback(story_id, local_story, remote_story)
-- @return Autosave New autosave manager
function Autosave.new(options)
  assert(options.storage, "Storage service required")
  
  local self = setmetatable({}, Autosave)
  self.storage = options.storage
  self.interval = options.interval or 30
  self.max_retries = options.max_retries or 3
  self.debounce = options.debounce or 2
  self.on_save = options.on_save
  self.on_conflict = options.on_conflict
  
  -- Track dirty stories
  self.dirty = {}  -- {story_id = {data, last_modified, retries}}
  
  -- Track save states
  self.states = {}  -- {story_id = state}
  
  -- Track timers
  self.timers = {}  -- {story_id = {debounce_timer, interval_timer}}
  
  -- Overall state
  self.running = false
  self.paused = false
  
  return self
end

--- Mark story as dirty (needs autosave)
-- @param story_id string Story ID
-- @param story table Story data
function Autosave:mark_dirty(story_id, story)
  self.dirty[story_id] = {
    data = story,
    last_modified = os.time(),
    retries = 0
  }
  
  self.states[story_id] = Autosave.State.IDLE
  
  -- Reset debounce timer
  if not self.paused then
    self:schedule_debounced_save(story_id)
  end
end

--- Schedule a debounced save
-- Delays save to avoid excessive writes during rapid edits
-- @param story_id string Story ID
function Autosave:schedule_debounced_save(story_id)
  -- Clear existing debounce timer
  if self.timers[story_id] and self.timers[story_id].debounce_timer then
    -- In a real implementation, you'd cancel the timer here
    -- For this example, we'll use a timestamp-based approach
  end
  
  -- Set new debounce timer
  if not self.timers[story_id] then
    self.timers[story_id] = {}
  end
  
  self.timers[story_id].debounce_time = os.time() + self.debounce
end

--- Save a story immediately
-- @param story_id string Story ID
-- @param force boolean Force save even if not dirty
-- @return boolean success
-- @return string|nil error
function Autosave:save_now(story_id, force)
  if not force and not self.dirty[story_id] then
    return true, "Story not dirty"
  end
  
  local dirty_entry = self.dirty[story_id]
  if not dirty_entry then
    return false, "Story not found in autosave queue"
  end
  
  self.states[story_id] = Autosave.State.SAVING
  
  -- Save to storage
  local success, err = self.storage:save_story(story_id, dirty_entry.data)
  
  if success then
    -- Save succeeded
    self.dirty[story_id] = nil
    self.states[story_id] = Autosave.State.SAVED
    
    -- Call callback
    if self.on_save then
      self.on_save(true, nil, story_id)
    end
    
    return true
  else
    -- Save failed - retry logic
    dirty_entry.retries = dirty_entry.retries + 1
    
    if dirty_entry.retries >= self.max_retries then
      -- Max retries reached
      self.states[story_id] = Autosave.State.ERROR
      
      if self.on_save then
        self.on_save(false, string.format("Max retries reached: %s", err), story_id)
      end
      
      return false, err
    else
      -- Retry later
      self.states[story_id] = Autosave.State.IDLE
      return false, string.format("Save failed (will retry): %s", err)
    end
  end
end

--- Start autosave system
function Autosave:start()
  self.running = true
  self.paused = false
end

--- Stop autosave system
function Autosave:stop()
  self.running = false
end

--- Pause autosave
-- Stops automatic saves but keeps tracking dirty stories
function Autosave:pause()
  self.paused = true
end

--- Resume autosave
function Autosave:resume()
  self.paused = false
  
  -- Trigger saves for all dirty stories
  for story_id in pairs(self.dirty) do
    self:schedule_debounced_save(story_id)
  end
end

--- Process autosaves (call this periodically)
-- In a real implementation, this would be called by a timer
function Autosave:process()
  if not self.running or self.paused then
    return
  end
  
  local current_time = os.time()
  
  for story_id, dirty_entry in pairs(self.dirty) do
    -- Check if debounce period has passed
    local timer = self.timers[story_id]
    if timer and timer.debounce_time and current_time >= timer.debounce_time then
      -- Time to save
      self:save_now(story_id)
      
      -- Clear debounce timer
      timer.debounce_time = nil
    end
    
    -- Check if interval has passed since last modification
    if current_time - dirty_entry.last_modified >= self.interval then
      -- Force save after interval
      if self.states[story_id] ~= Autosave.State.SAVING then
        self:save_now(story_id)
      end
    end
  end
end

--- Get autosave state for a story
-- @param story_id string Story ID
-- @return string state State (idle, saving, saved, error, paused)
function Autosave:get_state(story_id)
  return self.states[story_id] or Autosave.State.IDLE
end

--- Check if story is dirty
-- @param story_id string Story ID
-- @return boolean is_dirty
function Autosave:is_dirty(story_id)
  return self.dirty[story_id] ~= nil
end

--- Clear dirty status
-- @param story_id string Story ID
function Autosave:clear_dirty(story_id)
  self.dirty[story_id] = nil
  self.states[story_id] = Autosave.State.SAVED
end

--- Get list of dirty stories
-- @return table dirty_stories Array of story IDs
function Autosave:get_dirty_stories()
  local list = {}
  for story_id in pairs(self.dirty) do
    table.insert(list, story_id)
  end
  return list
end

--- Save all dirty stories
-- @return number saved Count of successfully saved stories
-- @return number failed Count of failed saves
function Autosave:save_all()
  local saved = 0
  local failed = 0
  
  for story_id in pairs(self.dirty) do
    local success = self:save_now(story_id)
    if success then
      saved = saved + 1
    else
      failed = failed + 1
    end
  end
  
  return saved, failed
end

--- Get statistics
-- @return table stats Autosave statistics
function Autosave:get_stats()
  local stats = {
    running = self.running,
    paused = self.paused,
    dirty_count = 0,
    states = {
      idle = 0,
      saving = 0,
      saved = 0,
      error = 0
    }
  }
  
  for _ in pairs(self.dirty) do
    stats.dirty_count = stats.dirty_count + 1
  end
  
  for _, state in pairs(self.states) do
    stats.states[state] = (stats.states[state] or 0) + 1
  end
  
  return stats
end

--- Detect conflict between local and remote versions
-- @param story_id string Story ID
-- @param local_story table Local story data
-- @return boolean has_conflict
-- @return table|nil remote_story Remote story if conflict exists
function Autosave:detect_conflict(story_id, local_story)
  -- Load current version from storage
  local remote_story, err = self.storage:load_story(story_id, { skip_cache = true })
  
  if not remote_story then
    -- No remote version, no conflict
    return false, nil
  end
  
  -- Check if remote was modified after local
  local local_modified = local_story.metadata and local_story.metadata.modified
  local remote_modified = remote_story.metadata and remote_story.metadata.modified
  
  if remote_modified and local_modified and remote_modified > local_modified then
    -- Remote is newer, potential conflict
    return true, remote_story
  end
  
  -- Compare content (simple check)
  local local_content = self:serialize_story(local_story)
  local remote_content = self:serialize_story(remote_story)
  
  if local_content ~= remote_content then
    return true, remote_story
  end
  
  return false, nil
end

--- Serialize story for comparison
-- @param story table Story data
-- @return string serialized
function Autosave:serialize_story(story)
  local json = require("cjson")
  return json.encode(story)
end

--- Handle autosave conflict
-- @param story_id string Story ID
-- @param local_story table Local version
-- @param remote_story table Remote version
-- @return string resolution Resolution action: "use_local", "use_remote", "merge"
function Autosave:resolve_conflict(story_id, local_story, remote_story)
  if self.on_conflict then
    -- User-defined conflict handler
    return self.on_conflict(story_id, local_story, remote_story)
  else
    -- Default: use local (last-write-wins)
    return "use_local"
  end
end

return Autosave
