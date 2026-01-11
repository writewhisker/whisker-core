--- SQLite storage backend
-- High-performance storage backend using SQLite database
--
-- @module whisker.storage.backends.sqlite
-- @author Whisker Team
-- @license MIT
-- @usage
-- local SQLiteBackend = require("whisker.storage.backends.sqlite")
-- local backend = SQLiteBackend.new({ path = "stories.db" })
-- backend:initialize()

local sqlite3 = require("lsqlite3")
local json = require("cjson")

local SQLiteBackend = {}
SQLiteBackend.__index = SQLiteBackend

--- Database schema version
SQLiteBackend.SCHEMA_VERSION = 2

--- SQL statements for table creation
local SCHEMA = {
  -- Main stories table
  stories = [[
    CREATE TABLE IF NOT EXISTS stories (
      id TEXT PRIMARY KEY NOT NULL,
      data_blob TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ]],
  
  -- Metadata table
  metadata = [[
    CREATE TABLE IF NOT EXISTS metadata (
      id TEXT PRIMARY KEY NOT NULL,
      story_id TEXT NOT NULL,
      title TEXT,
      tags TEXT,
      size INTEGER,
      FOREIGN KEY (story_id) REFERENCES stories(id) ON DELETE CASCADE
    )
  ]],
  
  -- Preferences table (optional)
  preferences = [[
    CREATE TABLE IF NOT EXISTS preferences (
      key TEXT PRIMARY KEY NOT NULL,
      value TEXT NOT NULL,
      scope TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ]],
  
  -- Sync queue table (optional)
  sync_queue = [[
    CREATE TABLE IF NOT EXISTS sync_queue (
      id TEXT PRIMARY KEY NOT NULL,
      story_id TEXT NOT NULL,
      action TEXT NOT NULL,
      data TEXT,
      timestamp INTEGER NOT NULL
    )
  ]],
  
  -- GitHub token table (optional)
  github_token = [[
    CREATE TABLE IF NOT EXISTS github_token (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      token_data TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ]],
  
  -- Schema version table
  schema_version = [[
    CREATE TABLE IF NOT EXISTS schema_version (
      version INTEGER PRIMARY KEY NOT NULL
    )
  ]]
}

--- Indexes for performance
local INDEXES = {
  [[CREATE INDEX IF NOT EXISTS idx_stories_updated ON stories(updated_at DESC)]],
  [[CREATE INDEX IF NOT EXISTS idx_metadata_story ON metadata(story_id)]],
  [[CREATE INDEX IF NOT EXISTS idx_metadata_title ON metadata(title)]],
  [[CREATE INDEX IF NOT EXISTS idx_sync_queue_story ON sync_queue(story_id)]],
  [[CREATE INDEX IF NOT EXISTS idx_sync_queue_timestamp ON sync_queue(timestamp)]]
}

--- Create new SQLite backend instance
-- @param options table Configuration options
-- @param options.path string Path to SQLite database file (default: ":memory:")
-- @param options.timeout number Busy timeout in milliseconds (default: 5000)
-- @return SQLiteBackend New backend instance
-- @usage
-- local backend = SQLiteBackend.new({ path = "stories.db" })
function SQLiteBackend.new(options)
  options = options or {}
  
  local self = setmetatable({}, SQLiteBackend)
  self.path = options.path or ":memory:"
  self.timeout = options.timeout or 5000
  self.db = nil
  
  return self
end

--- Initialize the database
-- Creates tables and indexes if they don't exist
-- @return boolean success True if initialization succeeded
-- @return string|nil error Error message if failed
function SQLiteBackend:initialize()
  -- Open database
  local db, err_code, err_msg = sqlite3.open(self.path)
  
  if not db then
    return false, string.format("Failed to open database: %s (%d)", err_msg or "unknown", err_code or 0)
  end
  
  self.db = db
  
  -- Set busy timeout
  self.db:busy_timeout(self.timeout)
  
  -- Enable foreign keys
  self.db:exec("PRAGMA foreign_keys = ON")
  
  -- Create tables
  for name, sql in pairs(SCHEMA) do
    local result = self.db:exec(sql)
    if result ~= sqlite3.OK then
      return false, string.format("Failed to create table %s: %s", name, self.db:errmsg())
    end
  end
  
  -- Create indexes
  for _, sql in ipairs(INDEXES) do
    local result = self.db:exec(sql)
    if result ~= sqlite3.OK then
      return false, string.format("Failed to create index: %s", self.db:errmsg())
    end
  end
  
  -- Check/update schema version
  local version = self:get_schema_version()
  if version < SQLiteBackend.SCHEMA_VERSION then
    self:migrate_schema(version, SQLiteBackend.SCHEMA_VERSION)
  end
  
  return true
end

--- Get current schema version
-- @return number version Current schema version
function SQLiteBackend:get_schema_version()
  local stmt = self.db:prepare("SELECT version FROM schema_version LIMIT 1")
  if not stmt then
    -- Initialize version
    self.db:exec(string.format("INSERT INTO schema_version (version) VALUES (%d)", SQLiteBackend.SCHEMA_VERSION))
    return SQLiteBackend.SCHEMA_VERSION
  end
  
  local version = 0
  if stmt:step() == sqlite3.ROW then
    version = stmt:get_value(0)
  end
  stmt:finalize()
  
  return version or 0
end

--- Migrate schema from old version to new version
-- @param from_version number Old version
-- @param to_version number New version
-- @return boolean success True if migration succeeded
function SQLiteBackend:migrate_schema(from_version, to_version)
  -- Placeholder for future migrations
  self.db:exec(string.format("UPDATE schema_version SET version = %d", to_version))
  return true
end

--- Save a story to storage
-- @param key string Story ID
-- @param data table Story data
-- @param metadata table Optional metadata
-- @return boolean success True if save succeeded
-- @return string|nil error Error message if failed
function SQLiteBackend:save(key, data, metadata)
  if not self.db then
    return false, "Database not initialized"
  end
  
  -- Serialize data to JSON
  local data_json = json.encode(data)
  local now = os.time()
  
  -- Check if story exists to preserve created_at
  local created_at = now
  local existing_stmt = self.db:prepare("SELECT created_at FROM stories WHERE id = ?")
  existing_stmt:bind_values(key)
  if existing_stmt:step() == sqlite3.ROW then
    created_at = existing_stmt:get_value(0)
  end
  existing_stmt:finalize()
  
  -- Begin transaction
  self.db:exec("BEGIN TRANSACTION")
  
  -- Insert or replace story
  local stmt = self.db:prepare([[
    INSERT OR REPLACE INTO stories (id, data_blob, created_at, updated_at)
    VALUES (?, ?, ?, ?)
  ]])
  
  stmt:bind_values(key, data_json, created_at, now)
  local result = stmt:step()
  stmt:finalize()
  
  if result ~= sqlite3.DONE then
    self.db:exec("ROLLBACK")
    return false, string.format("Failed to save story: %s", self.db:errmsg())
  end
  
  -- Save metadata
  local title = (data.metadata and data.metadata.title) or (data.title) or "Untitled"
  local tags_json = json.encode(metadata.tags or {})
  local size = #data_json
  
  local meta_stmt = self.db:prepare([[
    INSERT OR REPLACE INTO metadata (id, story_id, title, tags, size)
    VALUES (?, ?, ?, ?, ?)
  ]])
  
  meta_stmt:bind_values(key, key, title, tags_json, size)
  result = meta_stmt:step()
  meta_stmt:finalize()
  
  if result ~= sqlite3.DONE then
    self.db:exec("ROLLBACK")
    return false, string.format("Failed to save metadata: %s", self.db:errmsg())
  end
  
  -- Commit transaction
  self.db:exec("COMMIT")
  
  return true
end

--- Load a story from storage
-- @param key string Story ID
-- @return table|nil data Story data if found
-- @return string|nil error Error message if failed
function SQLiteBackend:load(key)
  if not self.db then
    return nil, "Database not initialized"
  end
  
  local stmt = self.db:prepare("SELECT data_blob FROM stories WHERE id = ?")
  if not stmt then
    return nil, string.format("Failed to prepare statement: %s", self.db:errmsg())
  end
  
  stmt:bind_values(key)
  
  local data = nil
  if stmt:step() == sqlite3.ROW then
    local data_json = stmt:get_value(0)
    local success, decoded = pcall(json.decode, data_json)
    if success then
      data = decoded
    else
      stmt:finalize()
      return nil, "Failed to decode story data"
    end
  end
  
  stmt:finalize()
  
  if not data then
    return nil, "Story not found"
  end
  
  return data
end

--- Delete a story from storage
-- @param key string Story ID
-- @return boolean success True if deletion succeeded
-- @return string|nil error Error message if failed
function SQLiteBackend:delete(key)
  if not self.db then
    return false, "Database not initialized"
  end
  
  -- Check if story exists
  if not self:exists(key) then
    return false, "Story not found"
  end
  
  -- Begin transaction
  self.db:exec("BEGIN TRANSACTION")
  
  -- Delete story (metadata will cascade)
  local stmt = self.db:prepare("DELETE FROM stories WHERE id = ?")
  stmt:bind_values(key)
  local result = stmt:step()
  stmt:finalize()
  
  if result ~= sqlite3.DONE then
    self.db:exec("ROLLBACK")
    return false, string.format("Failed to delete story: %s", self.db:errmsg())
  end
  
  -- Commit transaction
  self.db:exec("COMMIT")
  
  return true
end

--- List all stories in storage
-- @param filter table Optional filter options
-- @param filter.tags table Filter by tags
-- @param filter.limit number Maximum results
-- @param filter.offset number Offset for pagination
-- @return table[] Array of story metadata
-- @return string|nil error Error message if failed
function SQLiteBackend:list(filter)
  if not self.db then
    return {}, "Database not initialized"
  end
  
  filter = filter or {}
  
  -- Build query
  local query = [[
    SELECT m.id, m.title, m.tags, m.size, s.created_at, s.updated_at
    FROM metadata m
    JOIN stories s ON m.story_id = s.id
    ORDER BY s.updated_at DESC
  ]]
  
  if filter.limit then
    query = query .. string.format(" LIMIT %d", filter.limit)
  end
  
  if filter.offset then
    query = query .. string.format(" OFFSET %d", filter.offset)
  end
  
  local stmt = self.db:prepare(query)
  if not stmt then
    return {}, string.format("Failed to prepare statement: %s", self.db:errmsg())
  end
  
  local results = {}
  
  while stmt:step() == sqlite3.ROW do
    local tags_json = stmt:get_value(2)
    local tags = {}
    if tags_json and tags_json ~= "" then
      local success, decoded = pcall(json.decode, tags_json)
      if success then
        tags = decoded
      end
    end
    
    local metadata = {
      id = stmt:get_value(0),
      title = stmt:get_value(1),
      tags = tags,
      size = stmt:get_value(3),
      created_at = stmt:get_value(4),
      updated_at = stmt:get_value(5)
    }
    
    -- Filter by tags if specified
    if filter.tags and #filter.tags > 0 then
      local has_tag = false
      for _, filter_tag in ipairs(filter.tags) do
        for _, story_tag in ipairs(tags) do
          if story_tag == filter_tag then
            has_tag = true
            break
          end
        end
        if has_tag then break end
      end
      
      if has_tag then
        table.insert(results, metadata)
      end
    else
      table.insert(results, metadata)
    end
  end
  
  stmt:finalize()
  
  return results
end

--- Check if a story exists
-- @param key string Story ID
-- @return boolean exists True if story exists
-- @return string|nil error Error message if failed
function SQLiteBackend:exists(key)
  if not self.db then
    return false, "Database not initialized"
  end
  
  local stmt = self.db:prepare("SELECT 1 FROM stories WHERE id = ? LIMIT 1")
  stmt:bind_values(key)
  
  local exists = stmt:step() == sqlite3.ROW
  stmt:finalize()
  
  return exists
end

--- Get metadata for a story
-- @param key string Story ID
-- @return table|nil metadata Story metadata if found
-- @return string|nil error Error message if failed
function SQLiteBackend:get_metadata(key)
  if not self.db then
    return nil, "Database not initialized"
  end
  
  local stmt = self.db:prepare([[
    SELECT m.id, m.title, m.tags, m.size, s.created_at, s.updated_at
    FROM metadata m
    JOIN stories s ON m.story_id = s.id
    WHERE m.id = ?
  ]])
  
  stmt:bind_values(key)
  
  local metadata = nil
  if stmt:step() == sqlite3.ROW then
    local tags_json = stmt:get_value(2)
    local tags = {}
    if tags_json and tags_json ~= "" then
      local success, decoded = pcall(json.decode, tags_json)
      if success then
        tags = decoded
      end
    end
    
    metadata = {
      id = stmt:get_value(0),
      title = stmt:get_value(1),
      tags = tags,
      size = stmt:get_value(3),
      created_at = stmt:get_value(4),
      updated_at = stmt:get_value(5)
    }
  end
  
  stmt:finalize()
  
  if not metadata then
    return nil, "Story not found"
  end
  
  return metadata
end

--- Update metadata for a story
-- @param key string Story ID
-- @param metadata table Metadata fields to update
-- @return boolean success True if update succeeded
-- @return string|nil error Error message if failed
function SQLiteBackend:update_metadata(key, metadata)
  if not self.db then
    return false, "Database not initialized"
  end
  
  if not self:exists(key) then
    return false, "Story not found"
  end
  
  -- Build update query dynamically
  local updates = {}
  local values = {}
  
  if metadata.title then
    table.insert(updates, "title = ?")
    table.insert(values, metadata.title)
  end
  
  if metadata.tags then
    table.insert(updates, "tags = ?")
    table.insert(values, json.encode(metadata.tags))
  end
  
  if #updates == 0 then
    return true  -- Nothing to update
  end
  
  table.insert(values, key)
  
  local query = string.format(
    "UPDATE metadata SET %s WHERE id = ?",
    table.concat(updates, ", ")
  )
  
  local stmt = self.db:prepare(query)
  stmt:bind_values(table.unpack(values))
  
  local result = stmt:step()
  stmt:finalize()
  
  if result ~= sqlite3.DONE then
    return false, string.format("Failed to update metadata: %s", self.db:errmsg())
  end
  
  -- Update story's updated_at timestamp
  self.db:exec(string.format(
    "UPDATE stories SET updated_at = %d WHERE id = '%s'",
    os.time(), key
  ))
  
  return true
end

--- Export a story to JSON
-- @param key string Story ID
-- @return string|nil json JSON string of story
-- @return string|nil error Error message if failed
function SQLiteBackend:export(key)
  local data, err = self:load(key)
  if not data then
    return nil, err
  end
  
  return json.encode(data)
end

--- Import a story from JSON
-- @param data string JSON string or table
-- @return string|nil key Story ID of imported story
-- @return string|nil error Error message if failed
function SQLiteBackend:import_data(data)
  local story_data
  
  if type(data) == "string" then
    local success, decoded = pcall(json.decode, data)
    if not success then
      return nil, "Failed to decode JSON"
    end
    story_data = decoded
  else
    story_data = data
  end
  
  -- Generate or extract ID
  local key = story_data.id or string.format("imported-%d", os.time())
  
  -- Save story
  local success, err = self:save(key, story_data, {})
  if not success then
    return nil, err
  end
  
  return key
end

--- Get total storage usage in bytes
-- @return number bytes Total bytes used
-- @return string|nil error Error message if failed
function SQLiteBackend:get_storage_usage()
  if not self.db then
    return 0, "Database not initialized"
  end
  
  local stmt = self.db:prepare("SELECT SUM(size) FROM metadata")
  
  local total = 0
  if stmt:step() == sqlite3.ROW then
    total = stmt:get_value(0) or 0
  end
  
  stmt:finalize()
  
  return total
end

--- Clear all storage
-- @return boolean success True if clear succeeded
-- @return string|nil error Error message if failed
function SQLiteBackend:clear()
  if not self.db then
    return false, "Database not initialized"
  end
  
  self.db:exec("BEGIN TRANSACTION")
  
  local tables = {"stories", "metadata", "preferences", "sync_queue", "github_token"}
  
  for _, table_name in ipairs(tables) do
    local result = self.db:exec(string.format("DELETE FROM %s", table_name))
    if result ~= sqlite3.OK then
      self.db:exec("ROLLBACK")
      return false, string.format("Failed to clear table %s: %s", table_name, self.db:errmsg())
    end
  end
  
  self.db:exec("COMMIT")
  
  return true
end

--- Optional: Save a preference
-- @param key string Preference key
-- @param entry table Preference entry
-- @return boolean success
-- @return string|nil error
function SQLiteBackend:save_preference(key, entry)
  if not self.db then
    return false, "Database not initialized"
  end
  
  local now = os.time()
  local value_json = json.encode(entry.value)
  
  local stmt = self.db:prepare([[
    INSERT OR REPLACE INTO preferences (key, value, scope, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?)
  ]])
  
  stmt:bind_values(key, value_json, entry.scope or "user", now, now)
  local result = stmt:step()
  stmt:finalize()
  
  return result == sqlite3.DONE
end

--- Optional: Load a preference
-- @param key string Preference key
-- @return table|nil entry Preference entry
-- @return string|nil error
function SQLiteBackend:load_preference(key)
  if not self.db then
    return nil, "Database not initialized"
  end
  
  local stmt = self.db:prepare("SELECT value, scope FROM preferences WHERE key = ?")
  stmt:bind_values(key)
  
  local entry = nil
  if stmt:step() == sqlite3.ROW then
    local value_json = stmt:get_value(0)
    local scope = stmt:get_value(1)
    
    local success, value = pcall(json.decode, value_json)
    if success then
      entry = {
        value = value,
        scope = scope
      }
    end
  end
  
  stmt:finalize()
  
  return entry
end

--- Optional: Delete a preference
-- @param key string Preference key
-- @return boolean success
function SQLiteBackend:delete_preference(key)
  if not self.db then
    return false
  end
  
  local stmt = self.db:prepare("DELETE FROM preferences WHERE key = ?")
  stmt:bind_values(key)
  local result = stmt:step()
  stmt:finalize()
  
  return result == sqlite3.DONE
end

--- Optional: List preference keys
-- @param prefix string Optional prefix filter
-- @return table keys Array of keys
function SQLiteBackend:list_preferences(prefix)
  if not self.db then
    return {}
  end
  
  local query = "SELECT key FROM preferences"
  if prefix then
    query = query .. string.format(" WHERE key LIKE '%s%%'", prefix)
  end
  
  local stmt = self.db:prepare(query)
  local keys = {}
  
  while stmt:step() == sqlite3.ROW do
    table.insert(keys, stmt:get_value(0))
  end
  
  stmt:finalize()
  
  return keys
end

--- Close database connection
function SQLiteBackend:close()
  if self.db then
    self.db:close()
    self.db = nil
  end
end

return SQLiteBackend
