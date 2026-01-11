--- Storage Service - Main storage API
-- Provides a unified interface for story storage with backend abstraction,
-- caching, and event system
--
-- @module whisker.storage
-- @author Whisker Team
-- @license MIT
-- @usage
-- local Storage = require("whisker.storage")
-- local storage = Storage.new({ backend = "sqlite", path = "stories.db" })
-- storage:initialize()

local Backend = require("whisker.storage.interfaces.backend")

local Storage = {}
Storage.__index = Storage

--- Storage event types
Storage.Events = {
  STORY_SAVED = "story_saved",
  STORY_LOADED = "story_loaded",
  STORY_DELETED = "story_deleted",
  STORY_CREATED = "story_created",
  STORY_UPDATED = "story_updated",
  METADATA_UPDATED = "metadata_updated",
  STORAGE_CLEARED = "storage_cleared",
  STORAGE_ERROR = "storage_error"
}

--- Create new storage service
-- @param options table Configuration options
-- @param options.backend string Backend type: "sqlite", "filesystem", or custom backend instance
-- @param options.path string Path for backend
-- @param options.cache_size number Maximum cached stories (default: 100)
-- @param options.enable_events boolean Enable event system (default: true)
-- @return Storage New storage instance
-- @usage
-- local storage = Storage.new({
--   backend = "sqlite",
--   path = "stories.db",
--   cache_size = 50
-- })
function Storage.new(options)
  options = options or {}
  
  local self = setmetatable({}, Storage)
  
  -- Initialize backend
  if type(options.backend) == "string" then
    -- Load built-in backend
    local backend_name = options.backend
    local backend_module
    
    if backend_name == "sqlite" then
      backend_module = require("whisker.storage.backends.sqlite")
    elseif backend_name == "filesystem" then
      backend_module = require("whisker.storage.backends.filesystem")
    else
      error(string.format("Unknown backend type: %s", backend_name))
    end
    
    local backend_impl = backend_module.new(options)
    self.backend = Backend.new(backend_impl)
  else
    -- Use custom backend instance
    self.backend = options.backend
  end
  
  -- Cache configuration
  self.cache_size = options.cache_size or 100
  self.cache = {}
  self.cache_order = {}  -- LRU tracking
  
  -- Event system
  self.enable_events = options.enable_events ~= false
  self.event_listeners = {}
  
  -- Statistics
  self.stats = {
    saves = 0,
    loads = 0,
    deletes = 0,
    cache_hits = 0,
    cache_misses = 0
  }
  
  return self
end

--- Initialize the storage service
-- @return boolean success
-- @return string|nil error
function Storage:initialize()
  return self.backend:initialize()
end

--- Register event listener
-- @param event string Event name from Storage.Events
-- @param callback function Callback function(event_data)
-- @usage
-- storage:on(Storage.Events.STORY_SAVED, function(data)
--   print("Story saved:", data.id)
-- end)
function Storage:on(event, callback)
  if not self.enable_events then
    return
  end
  
  if not self.event_listeners[event] then
    self.event_listeners[event] = {}
  end
  
  table.insert(self.event_listeners[event], callback)
end

--- Emit event to listeners
-- @param event string Event name
-- @param data table Event data
function Storage:emit(event, data)
  if not self.enable_events then
    return
  end
  
  local listeners = self.event_listeners[event]
  if listeners then
    for _, callback in ipairs(listeners) do
      local success, err = pcall(callback, data)
      if not success then
        print(string.format("Event listener error: %s", err))
      end
    end
  end
end

--- Add to cache with LRU eviction
-- @param key string Story ID
-- @param data table Story data
function Storage:cache_put(key, data)
  -- If already in cache, move to front
  for i, cached_key in ipairs(self.cache_order) do
    if cached_key == key then
      table.remove(self.cache_order, i)
      break
    end
  end
  
  -- Add to front
  table.insert(self.cache_order, 1, key)
  self.cache[key] = data
  
  -- Evict if over limit
  if #self.cache_order > self.cache_size then
    local evict_key = table.remove(self.cache_order)
    self.cache[evict_key] = nil
  end
end

--- Get from cache
-- @param key string Story ID
-- @return table|nil data Cached data or nil
function Storage:cache_get(key)
  local data = self.cache[key]
  
  if data then
    self.stats.cache_hits = self.stats.cache_hits + 1
  else
    self.stats.cache_misses = self.stats.cache_misses + 1
  end
  
  return data
end

--- Invalidate cache entry
-- @param key string Story ID
function Storage:cache_invalidate(key)
  self.cache[key] = nil
  
  for i, cached_key in ipairs(self.cache_order) do
    if cached_key == key then
      table.remove(self.cache_order, i)
      break
    end
  end
end

--- Clear entire cache
function Storage:cache_clear()
  self.cache = {}
  self.cache_order = {}
end

--- Save a story
-- @param key string Story ID
-- @param data table Story data
-- @param options table Optional save options
-- @param options.metadata table Metadata (title, tags, etc.)
-- @param options.skip_cache boolean Skip cache update
-- @return boolean success
-- @return string|nil error
-- @usage
-- local success, err = storage:save_story("story-1", story_data, {
--   metadata = { tags = {"fantasy", "adventure"} }
-- })
function Storage:save_story(key, data, options)
  options = options or {}
  
  -- Check if story already exists
  local is_new = not self.backend:exists(key)
  
  -- Save to backend
  local success, err = self.backend:save(key, data, options.metadata or {})
  
  if not success then
    self:emit(Storage.Events.STORAGE_ERROR, {
      operation = "save",
      key = key,
      error = err
    })
    return false, err
  end
  
  -- Update cache
  if not options.skip_cache then
    self:cache_put(key, data)
  end
  
  -- Update stats
  self.stats.saves = self.stats.saves + 1
  
  -- Emit events
  self:emit(Storage.Events.STORY_SAVED, {
    id = key,
    data = data,
    is_new = is_new
  })
  
  if is_new then
    self:emit(Storage.Events.STORY_CREATED, { id = key })
  else
    self:emit(Storage.Events.STORY_UPDATED, { id = key })
  end
  
  return true
end

--- Load a story
-- @param key string Story ID
-- @param options table Optional load options
-- @param options.skip_cache boolean Skip cache lookup
-- @return table|nil data Story data
-- @return string|nil error
function Storage:load_story(key, options)
  options = options or {}
  
  -- Check cache first
  if not options.skip_cache then
    local cached = self:cache_get(key)
    if cached then
      self:emit(Storage.Events.STORY_LOADED, {
        id = key,
        from_cache = true
      })
      return cached
    end
  end
  
  -- Load from backend
  local data, err = self.backend:load(key)
  
  if not data then
    self:emit(Storage.Events.STORAGE_ERROR, {
      operation = "load",
      key = key,
      error = err
    })
    return nil, err
  end
  
  -- Update cache
  self:cache_put(key, data)
  
  -- Update stats
  self.stats.loads = self.stats.loads + 1
  
  -- Emit event
  self:emit(Storage.Events.STORY_LOADED, {
    id = key,
    from_cache = false
  })
  
  return data
end

--- Delete a story
-- @param key string Story ID
-- @return boolean success
-- @return string|nil error
function Storage:delete_story(key)
  local success, err = self.backend:delete(key)
  
  if not success then
    self:emit(Storage.Events.STORAGE_ERROR, {
      operation = "delete",
      key = key,
      error = err
    })
    return false, err
  end
  
  -- Invalidate cache
  self:cache_invalidate(key)
  
  -- Update stats
  self.stats.deletes = self.stats.deletes + 1
  
  -- Emit event
  self:emit(Storage.Events.STORY_DELETED, { id = key })
  
  return true
end

--- List all stories
-- @param filter table Optional filter options
-- @param filter.tags table Filter by tags
-- @param filter.limit number Maximum results
-- @param filter.offset number Offset for pagination
-- @return table[] Array of story metadata
-- @return string|nil error
function Storage:list_stories(filter)
  return self.backend:list(filter)
end

--- Check if story exists
-- @param key string Story ID
-- @return boolean exists
function Storage:has_story(key)
  return self.backend:exists(key)
end

--- Get story metadata
-- @param key string Story ID
-- @return table|nil metadata
-- @return string|nil error
function Storage:get_metadata(key)
  return self.backend:get_metadata(key)
end

--- Update story metadata
-- @param key string Story ID
-- @param metadata table Metadata to update
-- @return boolean success
-- @return string|nil error
function Storage:update_metadata(key, metadata)
  local success, err = self.backend:update_metadata(key, metadata)
  
  if success then
    -- Invalidate cache since metadata might be part of story data
    self:cache_invalidate(key)
    
    self:emit(Storage.Events.METADATA_UPDATED, {
      id = key,
      metadata = metadata
    })
  end
  
  return success, err
end

--- Export story to JSON string
-- @param key string Story ID
-- @return string|nil json
-- @return string|nil error
function Storage:export_story(key)
  return self.backend:export(key)
end

--- Import story from JSON
-- @param data string|table JSON string or table
-- @return string|nil key Story ID
-- @return string|nil error
function Storage:import_story(data)
  local key, err = self.backend:import_data(data)
  
  if key then
    self:emit(Storage.Events.STORY_CREATED, { id = key })
  end
  
  return key, err
end

--- Get storage usage statistics
-- @return table stats Storage statistics
-- @usage
-- local stats = storage:get_statistics()
-- print("Total saves:", stats.saves)
-- print("Cache hit rate:", stats.cache_hit_rate)
function Storage:get_statistics()
  local total_size = self.backend:get_storage_usage()
  
  local cache_requests = self.stats.cache_hits + self.stats.cache_misses
  local cache_hit_rate = 0
  if cache_requests > 0 then
    cache_hit_rate = self.stats.cache_hits / cache_requests
  end
  
  return {
    saves = self.stats.saves,
    loads = self.stats.loads,
    deletes = self.stats.deletes,
    cache_hits = self.stats.cache_hits,
    cache_misses = self.stats.cache_misses,
    cache_hit_rate = cache_hit_rate,
    cache_size = #self.cache_order,
    cache_max_size = self.cache_size,
    total_size_bytes = total_size
  }
end

--- Clear all storage
-- WARNING: This will delete all stories!
-- @return boolean success
-- @return string|nil error
function Storage:clear()
  -- Clear cache first
  self:cache_clear()
  
  -- Clear backend
  local success, err = self.backend:clear()
  
  if success then
    self:emit(Storage.Events.STORAGE_CLEARED, {})
  else
    self:emit(Storage.Events.STORAGE_ERROR, {
      operation = "clear",
      error = err
    })
  end
  
  return success, err
end

--- Batch save multiple stories
-- More efficient than individual saves
-- @param stories table Map of {id = data}
-- @return number count Number of stories saved
-- @return table errors Map of {id = error} for failed saves
function Storage:batch_save(stories)
  local count = 0
  local errors = {}
  
  for key, data in pairs(stories) do
    local success, err = self:save_story(key, data)
    if success then
      count = count + 1
    else
      errors[key] = err
    end
  end
  
  return count, errors
end

--- Batch load multiple stories
-- @param keys table Array of story IDs
-- @return table stories Map of {id = data} for loaded stories
-- @return table errors Map of {id = error} for failed loads
function Storage:batch_load(keys)
  local stories = {}
  local errors = {}
  
  for _, key in ipairs(keys) do
    local data, err = self:load_story(key)
    if data then
      stories[key] = data
    else
      errors[key] = err
    end
  end
  
  return stories, errors
end

--- Preload connected stories for faster navigation
-- Useful for story player to preload adjacent passages
-- @param key string Story ID
-- @param depth number Depth of connections to preload (default: 1)
-- @return number count Number of stories preloaded
function Storage:preload_connected(key, depth)
  depth = depth or 1
  
  -- This is a placeholder - actual implementation would need
  -- to analyze story connections and preload linked stories
  -- For now, just ensure the main story is cached
  
  local data = self:load_story(key)
  if not data then
    return 0
  end
  
  return 1
end

return Storage
