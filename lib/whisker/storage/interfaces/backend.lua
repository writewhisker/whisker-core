--- Storage backend interface
-- All storage implementations must conform to this interface.
-- This module defines the contract that all storage backends must implement.
--
-- @module whisker.storage.interfaces.backend
-- @author Whisker Team
-- @license MIT
-- @usage
-- local Backend = require("whisker.storage.interfaces.backend")
-- 
-- -- Implement a custom backend
-- local MyBackend = {}
-- function MyBackend:save(key, data, metadata) 
--   -- implementation
-- end
-- -- ... implement other methods
-- 
-- -- Validate implementation
-- local backend = Backend.new(MyBackend)

local Backend = {}
Backend.__index = Backend

--- Required methods that all backends must implement
Backend.REQUIRED_METHODS = {
  "initialize",
  "save",
  "load",
  "delete",
  "list",
  "exists",
  "get_metadata",
  "update_metadata",
  "export",
  "import_data",
  "get_storage_usage",
  "clear"
}

--- Optional methods for extended functionality
Backend.OPTIONAL_METHODS = {
  "save_preference",
  "load_preference",
  "delete_preference",
  "list_preferences",
  "add_to_sync_queue",
  "get_sync_queue",
  "remove_from_sync_queue",
  "clear_sync_queue",
  "save_github_token",
  "load_github_token",
  "delete_github_token"
}

--- Create a new backend instance with validation
-- @param implementation table Implementation of backend methods
-- @return Backend Validated backend instance
-- @usage
-- local backend = Backend.new({
--   initialize = function(self) end,
--   save = function(self, key, data, metadata) end,
--   -- ... other required methods
-- })
function Backend.new(implementation)
  assert(type(implementation) == "table", "Backend implementation must be a table")
  
  local self = setmetatable({}, Backend)
  self._impl = implementation
  
  -- Validate that all required methods are implemented
  for _, method in ipairs(Backend.REQUIRED_METHODS) do
    if type(implementation[method]) ~= "function" then
      error(string.format(
        "Backend must implement %s() method",
        method
      ))
    end
  end
  
  return self
end

--- Check if backend implements an optional method
-- @param method_name string Name of the method to check
-- @return boolean True if method is implemented
function Backend:has_method(method_name)
  return type(self._impl[method_name]) == "function"
end

--- Initialize the storage backend
-- This method should be called before any other operations.
-- @return boolean success True if initialization succeeded
-- @return string|nil error Error message if failed
function Backend:initialize()
  return self._impl:initialize()
end

--- Save a story to storage
-- @param key string Unique identifier for the story
-- @param data table Story data to save
-- @param metadata table Optional metadata (title, tags, etc.)
-- @return boolean success True if save succeeded
-- @return string|nil error Error message if failed
-- @usage
-- local success, err = backend:save("story-1", story_data, {
--   title = "My Story",
--   tags = {"adventure", "fantasy"}
-- })
function Backend:save(key, data, metadata)
  assert(type(key) == "string" and key ~= "", "Key must be a non-empty string")
  assert(type(data) == "table", "Data must be a table")
  
  return self._impl:save(key, data, metadata or {})
end

--- Load a story from storage
-- @param key string Unique identifier for the story
-- @return table|nil data Story data if found, nil otherwise
-- @return string|nil error Error message if failed
-- @usage
-- local story, err = backend:load("story-1")
-- if story then
--   print("Loaded:", story.title)
-- end
function Backend:load(key)
  assert(type(key) == "string" and key ~= "", "Key must be a non-empty string")
  
  return self._impl:load(key)
end

--- Delete a story from storage
-- @param key string Unique identifier for the story
-- @return boolean success True if deletion succeeded
-- @return string|nil error Error message if failed
function Backend:delete(key)
  assert(type(key) == "string" and key ~= "", "Key must be a non-empty string")
  
  return self._impl:delete(key)
end

--- List all stories in storage
-- @param filter table Optional filter criteria
-- @param filter.tags table Filter by tags
-- @param filter.limit number Maximum number of results
-- @param filter.offset number Offset for pagination
-- @return table[] Array of metadata for all stories
-- @return string|nil error Error message if failed
-- @usage
-- local stories, err = backend:list({
--   tags = {"fantasy"},
--   limit = 10
-- })
function Backend:list(filter)
  return self._impl:list(filter or {})
end

--- Check if a story exists in storage
-- @param key string Unique identifier for the story
-- @return boolean exists True if story exists
-- @return string|nil error Error message if failed
function Backend:exists(key)
  assert(type(key) == "string" and key ~= "", "Key must be a non-empty string")
  
  return self._impl:exists(key)
end

--- Get metadata for a story
-- Metadata includes: id, title, createdAt, updatedAt, size, tags
-- @param key string Unique identifier for the story
-- @return table|nil metadata Story metadata if found
-- @return string|nil error Error message if failed
-- @usage
-- local meta = backend:get_metadata("story-1")
-- print("Created:", meta.created_at)
function Backend:get_metadata(key)
  assert(type(key) == "string" and key ~= "", "Key must be a non-empty string")
  
  return self._impl:get_metadata(key)
end

--- Update metadata for a story
-- @param key string Unique identifier for the story
-- @param metadata table Metadata fields to update
-- @return boolean success True if update succeeded
-- @return string|nil error Error message if failed
-- @usage
-- backend:update_metadata("story-1", {
--   title = "New Title",
--   tags = {"updated"}
-- })
function Backend:update_metadata(key, metadata)
  assert(type(key) == "string" and key ~= "", "Key must be a non-empty string")
  assert(type(metadata) == "table", "Metadata must be a table")
  
  return self._impl:update_metadata(key, metadata)
end

--- Export a story to a portable format (JSON string)
-- @param key string Unique identifier for the story
-- @return string|nil json JSON string of the story
-- @return string|nil error Error message if failed
function Backend:export(key)
  assert(type(key) == "string" and key ~= "", "Key must be a non-empty string")
  
  return self._impl:export(key)
end

--- Import a story from a portable format
-- @param data string JSON string or table to import
-- @return string|nil key Key of the imported story
-- @return string|nil error Error message if failed
function Backend:import_data(data)
  assert(data ~= nil, "Data must not be nil")
  
  return self._impl:import_data(data)
end

--- Get total storage usage in bytes
-- @return number bytes Total bytes used
-- @return string|nil error Error message if failed
function Backend:get_storage_usage()
  return self._impl:get_storage_usage()
end

--- Clear all storage (WARNING: destructive operation)
-- @return boolean success True if clear succeeded
-- @return string|nil error Error message if failed
function Backend:clear()
  return self._impl:clear()
end

-- Optional methods (only available if backend implements them)

--- Save a preference (optional)
-- @param key string Preference key
-- @param entry table Preference entry with value and metadata
-- @return boolean success True if save succeeded
-- @return string|nil error Error message if failed
function Backend:save_preference(key, entry)
  if not self:has_method("save_preference") then
    return false, "Backend does not support preferences"
  end
  
  assert(type(key) == "string" and key ~= "", "Key must be a non-empty string")
  assert(type(entry) == "table", "Entry must be a table")
  
  return self._impl:save_preference(key, entry)
end

--- Load a preference (optional)
-- @param key string Preference key
-- @return table|nil entry Preference entry if found
-- @return string|nil error Error message if failed
function Backend:load_preference(key)
  if not self:has_method("load_preference") then
    return nil, "Backend does not support preferences"
  end
  
  assert(type(key) == "string" and key ~= "", "Key must be a non-empty string")
  
  return self._impl:load_preference(key)
end

--- Delete a preference (optional)
-- @param key string Preference key
-- @return boolean success True if deletion succeeded
-- @return string|nil error Error message if failed
function Backend:delete_preference(key)
  if not self:has_method("delete_preference") then
    return false, "Backend does not support preferences"
  end
  
  assert(type(key) == "string" and key ~= "", "Key must be a non-empty string")
  
  return self._impl:delete_preference(key)
end

--- List all preference keys (optional)
-- @param prefix string Optional prefix filter
-- @return table keys Array of preference keys
-- @return string|nil error Error message if failed
function Backend:list_preferences(prefix)
  if not self:has_method("list_preferences") then
    return {}, "Backend does not support preferences"
  end
  
  return self._impl:list_preferences(prefix)
end

--- Add entry to sync queue (optional)
-- @param entry table Sync queue entry
-- @return boolean success True if add succeeded
-- @return string|nil error Error message if failed
function Backend:add_to_sync_queue(entry)
  if not self:has_method("add_to_sync_queue") then
    return false, "Backend does not support sync queue"
  end
  
  assert(type(entry) == "table", "Entry must be a table")
  
  return self._impl:add_to_sync_queue(entry)
end

--- Get all sync queue entries (optional)
-- @return table entries Array of sync queue entries
-- @return string|nil error Error message if failed
function Backend:get_sync_queue()
  if not self:has_method("get_sync_queue") then
    return {}, "Backend does not support sync queue"
  end
  
  return self._impl:get_sync_queue()
end

--- Remove entry from sync queue (optional)
-- @param id string Entry ID to remove
-- @return boolean success True if removal succeeded
-- @return string|nil error Error message if failed
function Backend:remove_from_sync_queue(id)
  if not self:has_method("remove_from_sync_queue") then
    return false, "Backend does not support sync queue"
  end
  
  assert(type(id) == "string" and id ~= "", "ID must be a non-empty string")
  
  return self._impl:remove_from_sync_queue(id)
end

--- Clear entire sync queue (optional)
-- @return boolean success True if clear succeeded
-- @return string|nil error Error message if failed
function Backend:clear_sync_queue()
  if not self:has_method("clear_sync_queue") then
    return false, "Backend does not support sync queue"
  end
  
  return self._impl:clear_sync_queue()
end

--- Save GitHub authentication token (optional)
-- @param token table GitHub token data
-- @return boolean success True if save succeeded
-- @return string|nil error Error message if failed
function Backend:save_github_token(token)
  if not self:has_method("save_github_token") then
    return false, "Backend does not support GitHub tokens"
  end
  
  assert(type(token) == "table", "Token must be a table")
  
  return self._impl:save_github_token(token)
end

--- Load GitHub authentication token (optional)
-- @return table|nil token GitHub token data if found
-- @return string|nil error Error message if failed
function Backend:load_github_token()
  if not self:has_method("load_github_token") then
    return nil, "Backend does not support GitHub tokens"
  end
  
  return self._impl:load_github_token()
end

--- Delete GitHub authentication token (optional)
-- @return boolean success True if deletion succeeded
-- @return string|nil error Error message if failed
function Backend:delete_github_token()
  if not self:has_method("delete_github_token") then
    return false, "Backend does not support GitHub tokens"
  end
  
  return self._impl:delete_github_token()
end

return Backend
