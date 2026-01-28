--- Filesystem storage backend
-- Simple file-based storage backend using JSON files
--
-- @module whisker.storage.backends.filesystem
-- @author Whisker Team
-- @license MIT

local lfs = require("lfs")
local JsonCodec = require("whisker.vendor.codecs.json_codec")

local FilesystemBackend = {}
FilesystemBackend.__index = FilesystemBackend

--- Dependencies for DI pattern
FilesystemBackend._dependencies = { "json_codec" }

--- Create new filesystem backend
-- @param options table Configuration options
-- @param options.path string Root directory for storage (default: "./whisker_storage")
-- @param deps table Dependencies from container (optional)
-- @return FilesystemBackend New backend instance
function FilesystemBackend.new(options, deps)
  options = options or {}
  deps = deps or {}

  local self = setmetatable({}, FilesystemBackend)
  self.root = options.path or "./whisker_storage"
  self.stories_dir = self.root .. "/stories"
  self.metadata_dir = self.root .. "/metadata"
  self.index_file = self.root .. "/.index.json"
  self.index = {}

  -- Use injected json_codec or create new one
  self.json = deps.json_codec or JsonCodec.new()

  return self
end

--- Ensure directory exists
-- @param path string Directory path
-- @return boolean success
local function ensure_dir(path)
  local attr = lfs.attributes(path)
  if not attr then
    return lfs.mkdir(path)
  elseif attr.mode ~= "directory" then
    return false
  end
  return true
end

--- Write file atomically (write to temp, then rename)
-- @param path string File path
-- @param content string File content
-- @return boolean success
local function atomic_write(path, content)
  local temp_path = path .. ".tmp"
  
  local file, err = io.open(temp_path, "w")
  if not file then
    return false, "Failed to open file: " .. tostring(err)
  end
  
  file:write(content)
  file:close()
  
  -- Rename temp file to actual file (atomic on POSIX)
  os.remove(path)  -- Remove if exists
  os.rename(temp_path, path)
  
  return true
end

--- Read file content
-- @param path string File path
-- @return string|nil content File content or nil
local function read_file(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end
  
  local content = file:read("*all")
  file:close()
  
  return content
end

--- Initialize the filesystem backend
-- @return boolean success
-- @return string|nil error
function FilesystemBackend:initialize()
  -- Create directories
  local ok = ensure_dir(self.root)
  if not ok then
    return false, "Failed to create root directory: " .. self.root
  end
  
  ok = ensure_dir(self.stories_dir)
  if not ok then
    return false, "Failed to create stories directory: " .. self.stories_dir
  end
  
  ok = ensure_dir(self.metadata_dir)
  if not ok then
    return false, "Failed to create metadata directory: " .. self.metadata_dir
  end
  
  -- Load or create index
  local index_content = read_file(self.index_file)
  if index_content then
    local success, decoded = pcall(function() return self.json:decode(index_content) end)
    if success then
      self.index = decoded
    else
      self.index = {}
    end
  else
    self.index = {}
    self:save_index()
  end
  
  return true
end

--- Save index to disk
-- @return boolean success
function FilesystemBackend:save_index()
  local index_json = self.json:encode(self.index)
  return atomic_write(self.index_file, index_json)
end

--- Get story file path
-- @param key string Story ID
-- @return string path File path
function FilesystemBackend:get_story_path(key)
  return string.format("%s/%s.json", self.stories_dir, key)
end

--- Get metadata file path
-- @param key string Story ID
-- @return string path File path
function FilesystemBackend:get_metadata_path(key)
  return string.format("%s/%s.meta.json", self.metadata_dir, key)
end

--- Save a story to storage
-- @param key string Story ID
-- @param data table Story data
-- @param metadata table Optional metadata
-- @return boolean success
-- @return string|nil error
function FilesystemBackend:save(key, data, metadata)
  -- Serialize story data
  local data_json = self.json:encode(data)
  local story_path = self:get_story_path(key)
  
  local success, err = atomic_write(story_path, data_json)
  if not success then
    return false, err
  end
  
  -- Create or update metadata
  local now = os.time()
  local created_at = now
  
  if self.index[key] then
    created_at = self.index[key].created_at
  end
  
  local meta = {
    id = key,
    title = (data.metadata and data.metadata.title) or data.title or "Untitled",
    tags = metadata.tags or {},
    size = #data_json,
    created_at = created_at,
    updated_at = now
  }
  
  -- Save metadata file
  local meta_json = self.json:encode(meta)
  local meta_path = self:get_metadata_path(key)
  success, err = atomic_write(meta_path, meta_json)
  if not success then
    return false, err
  end
  
  -- Update index
  self.index[key] = meta
  self:save_index()
  
  return true
end

--- Load a story from storage
-- @param key string Story ID
-- @return table|nil data Story data
-- @return string|nil error
function FilesystemBackend:load(key)
  local story_path = self:get_story_path(key)
  local content = read_file(story_path)
  
  if not content then
    return nil, "Story not found"
  end
  
  local success, data = pcall(function() return self.json:decode(content) end)
  if not success then
    return nil, "Failed to decode story data"
  end
  
  return data
end

--- Delete a story from storage
-- @param key string Story ID
-- @return boolean success
-- @return string|nil error
function FilesystemBackend:delete(key)
  if not self:exists(key) then
    return false, "Story not found"
  end
  
  -- Delete story file
  local story_path = self:get_story_path(key)
  os.remove(story_path)
  
  -- Delete metadata file
  local meta_path = self:get_metadata_path(key)
  os.remove(meta_path)
  
  -- Remove from index
  self.index[key] = nil
  self:save_index()
  
  return true
end

--- List all stories in storage
-- @param filter table Optional filter options
-- @return table[] Array of story metadata
-- @return string|nil error
function FilesystemBackend:list(filter)
  filter = filter or {}
  
  local results = {}
  
  for key, meta in pairs(self.index) do
    -- Filter by tags if specified
    if filter.tags and #filter.tags > 0 then
      local has_tag = false
      for _, filter_tag in ipairs(filter.tags) do
        for _, story_tag in ipairs(meta.tags or {}) do
          if story_tag == filter_tag then
            has_tag = true
            break
          end
        end
        if has_tag then break end
      end
      
      if has_tag then
        table.insert(results, meta)
      end
    else
      table.insert(results, meta)
    end
  end
  
  -- Sort by updated_at descending
  table.sort(results, function(a, b)
    return (a.updated_at or 0) > (b.updated_at or 0)
  end)
  
  -- Apply limit and offset
  if filter.limit or filter.offset then
    local offset = filter.offset or 0
    local limit = filter.limit or #results
    
    local filtered = {}
    for i = offset + 1, math.min(offset + limit, #results) do
      table.insert(filtered, results[i])
    end
    results = filtered
  end
  
  return results
end

--- Check if a story exists
-- @param key string Story ID
-- @return boolean exists
function FilesystemBackend:exists(key)
  return self.index[key] ~= nil
end

--- Get metadata for a story
-- @param key string Story ID
-- @return table|nil metadata
-- @return string|nil error
function FilesystemBackend:get_metadata(key)
  if not self:exists(key) then
    return nil, "Story not found"
  end
  
  return self.index[key]
end

--- Update metadata for a story
-- @param key string Story ID
-- @param metadata table Metadata to update
-- @return boolean success
-- @return string|nil error
function FilesystemBackend:update_metadata(key, metadata)
  if not self:exists(key) then
    return false, "Story not found"
  end
  
  -- Update index
  if metadata.title then
    self.index[key].title = metadata.title
  end
  
  if metadata.tags then
    self.index[key].tags = metadata.tags
  end
  
  self.index[key].updated_at = os.time()
  
  -- Save updated metadata file
  local meta_json = self.json:encode(self.index[key])
  local meta_path = self:get_metadata_path(key)
  atomic_write(meta_path, meta_json)
  
  -- Save index
  self:save_index()
  
  return true
end

--- Export a story to JSON
-- @param key string Story ID
-- @return string|nil json
-- @return string|nil error
function FilesystemBackend:export(key)
  local data, err = self:load(key)
  if not data then
    return nil, err
  end
  
  return self.json:encode(data)
end

--- Import a story from JSON
-- @param data string|table JSON or table
-- @return string|nil key Story ID
-- @return string|nil error
function FilesystemBackend:import_data(data)
  local story_data
  
  if type(data) == "string" then
    local success, decoded = pcall(function() return self.json:decode(data) end)
    if not success then
      return nil, "Failed to decode JSON"
    end
    story_data = decoded
  else
    story_data = data
  end
  
  local key = story_data.id or string.format("imported-%d", os.time())
  
  local success, err = self:save(key, story_data, {})
  if not success then
    return nil, err
  end
  
  return key
end

--- Get total storage usage in bytes
-- @return number bytes
function FilesystemBackend:get_storage_usage()
  local total = 0
  
  for _, meta in pairs(self.index) do
    total = total + (meta.size or 0)
  end
  
  return total
end

--- Clear all storage
-- @return boolean success
-- @return string|nil error
function FilesystemBackend:clear()
  -- Delete all story files
  for key in pairs(self.index) do
    local story_path = self:get_story_path(key)
    os.remove(story_path)
    
    local meta_path = self:get_metadata_path(key)
    os.remove(meta_path)
  end
  
  -- Clear index
  self.index = {}
  self:save_index()
  
  return true
end

--- Rebuild index from filesystem
-- Useful if index gets corrupted
-- @return number count Number of stories found
function FilesystemBackend:rebuild_index()
  self.index = {}
  
  local count = 0
  
  -- Iterate through metadata directory
  for file in lfs.dir(self.metadata_dir) do
    if file:match("%.meta%.json$") then
      local key = file:gsub("%.meta%.json$", "")
      local meta_path = self:get_metadata_path(key)
      local content = read_file(meta_path)
      
      if content then
        local success, meta = pcall(function() return self.json:decode(content) end)
        if success then
          self.index[key] = meta
          count = count + 1
        end
      end
    end
  end
  
  self:save_index()
  
  return count
end

return FilesystemBackend
