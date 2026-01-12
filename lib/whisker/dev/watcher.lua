--- File System Watcher for Development
-- Monitors file system changes and emits events for hot reload
-- @module whisker.dev.watcher
-- @author Whisker Development Team
-- @license MIT

local lfs = require("lfs")
local EventSystem = require("whisker.core.event_system")

local Watcher = {}
Watcher.__index = Watcher

--- Default file patterns to watch
local DEFAULT_PATTERNS = {
  "%.lua$",
  "%.json$",
  "%.md$",
  "%.html$",
  "%.css$",
  "%.js$",
  "%.twee$"
}

--- Default patterns to ignore
local DEFAULT_IGNORE = {
  "/%.git/",
  "/node_modules/",
  "/%.whisker%-cache/",
  "%.DS_Store$",
  "%.swp$",
  "%.tmp$",
  "~$"
}

--- Create a new file watcher
-- @param config Configuration table
-- @param config.paths Array of paths to watch
-- @param config.patterns File patterns to watch (optional)
-- @param config.ignore Patterns to ignore (optional)
-- @param config.debounce Debounce delay in seconds (default: 0.1)
-- @param config.recursive Watch directories recursively (default: true)
-- @return Watcher instance
function Watcher.new(config)
  config = config or {}
  
  local self = setmetatable({}, Watcher)
  
  self.paths = config.paths or {lfs.currentdir()}
  self.patterns = config.patterns or DEFAULT_PATTERNS
  self.ignore = config.ignore or DEFAULT_IGNORE
  self.debounce = config.debounce or 0.1
  self.recursive = config.recursive ~= false
  
  -- File state tracking
  self.file_states = {}  -- {path = {mtime, size}}
  self.watching = false
  
  -- Debounce tracking
  self.pending_changes = {}  -- {path = {type, timestamp}}
  
  -- Event system
  self.events = EventSystem.new()
  
  -- Initialize file states
  self:_scan_files()
  
  return self
end

--- Start watching for file changes
-- @return boolean success
function Watcher:start()
  if self.watching then
    return false
  end
  
  self.watching = true
  self.last_check = os.clock()
  
  return true
end

--- Stop watching for file changes
function Watcher:stop()
  self.watching = false
  self.pending_changes = {}
end

--- Check if watcher is active
-- @return boolean
function Watcher:is_watching()
  return self.watching
end

--- Add a path to watch
-- @param path Path to watch
function Watcher:add_path(path)
  -- Check if path already being watched
  for _, existing in ipairs(self.paths) do
    if existing == path then
      return
    end
  end
  
  table.insert(self.paths, path)
  
  -- Scan new path
  if self.recursive then
    self:_scan_directory(path)
  else
    self:_scan_files_in_directory(path)
  end
end

--- Remove a path from watching
-- @param path Path to remove
function Watcher:remove_path(path)
  for i, existing in ipairs(self.paths) do
    if existing == path then
      table.remove(self.paths, i)
      return
    end
  end
end

--- Poll for file system changes
-- Call this regularly to check for changes
function Watcher:tick()
  if not self.watching then
    return
  end
  
  local now = os.clock()
  
  -- Check files for changes
  self:_check_for_changes()
  
  -- Process pending debounced changes
  self:_process_pending_changes(now)
  
  self.last_check = now
end

--- Register event handler
-- @param event Event name ("file_created", "file_modified", "file_deleted")
-- @param callback Callback function(data)
function Watcher:on(event, callback)
  -- Wrap callback to extract data from event object
  local wrapper = function(event_obj)
    callback(event_obj.data)
  end
  self.events:on(event, wrapper)
end

--- Scan all files in watched paths
function Watcher:_scan_files()
  self.file_states = {}
  
  for _, path in ipairs(self.paths) do
    local attr = lfs.attributes(path)
    
    if attr then
      if attr.mode == "directory" then
        if self.recursive then
          self:_scan_directory(path)
        else
          self:_scan_files_in_directory(path)
        end
      elseif attr.mode == "file" then
        if self:_should_watch(path) then
          self:_record_file_state(path, attr)
        end
      end
    end
  end
end

--- Scan directory recursively
-- @param directory Directory path
function Watcher:_scan_directory(directory)
  -- Scan files in this directory
  self:_scan_files_in_directory(directory)
  
  -- Recursively scan subdirectories
  for entry in lfs.dir(directory) do
    if entry ~= "." and entry ~= ".." then
      local path = directory .. "/" .. entry
      local attr = lfs.attributes(path)
      
      if attr and attr.mode == "directory" then
        -- Check if directory should be ignored
        if not self:_should_ignore(path) then
          self:_scan_directory(path)
        end
      end
    end
  end
end

--- Scan files in a single directory (non-recursive)
-- @param directory Directory path
function Watcher:_scan_files_in_directory(directory)
  for entry in lfs.dir(directory) do
    if entry ~= "." and entry ~= ".." then
      local path = directory .. "/" .. entry
      local attr = lfs.attributes(path)
      
      if attr and attr.mode == "file" then
        if self:_should_watch(path) then
          self:_record_file_state(path, attr)
        end
      end
    end
  end
end

--- Record file state
-- @param path File path
-- @param attr File attributes
function Watcher:_record_file_state(path, attr)
  self.file_states[path] = {
    mtime = attr.modification,
    size = attr.size
  }
end

--- Check for file changes
function Watcher:_check_for_changes()
  -- Check existing files for modifications
  for path, state in pairs(self.file_states) do
    local attr = lfs.attributes(path)
    
    if not attr then
      -- File was deleted
      self:_queue_change(path, "file_deleted")
      self.file_states[path] = nil
    elseif attr.modification > state.mtime or attr.size ~= state.size then
      -- File was modified
      self:_queue_change(path, "file_modified")
      self:_record_file_state(path, attr)
    end
  end
  
  -- Check for new files
  for _, watch_path in ipairs(self.paths) do
    local attr = lfs.attributes(watch_path)
    if attr and attr.mode == "directory" then
      self:_check_directory_for_new_files(watch_path)
    end
  end
end

--- Check directory for new files
-- @param directory Directory path
function Watcher:_check_directory_for_new_files(directory)
  for entry in lfs.dir(directory) do
    if entry ~= "." and entry ~= ".." then
      local path = directory .. "/" .. entry
      local attr = lfs.attributes(path)
      
      if attr then
        if attr.mode == "file" and self:_should_watch(path) then
          if not self.file_states[path] then
            -- New file
            self:_queue_change(path, "file_created")
            self:_record_file_state(path, attr)
          end
        elseif attr.mode == "directory" and self.recursive then
          if not self:_should_ignore(path) then
            self:_check_directory_for_new_files(path)
          end
        end
      end
    end
  end
end

--- Queue a change for debouncing
-- @param path File path
-- @param change_type Change type
function Watcher:_queue_change(path, change_type)
  self.pending_changes[path] = {
    type = change_type,
    timestamp = os.clock()
  }
end

--- Process pending debounced changes
-- @param now Current timestamp
function Watcher:_process_pending_changes(now)
  for path, change in pairs(self.pending_changes) do
    -- Check if debounce period has elapsed
    if now - change.timestamp >= self.debounce then
      -- Emit event
      self.events:emit(change.type, {
        path = path,
        timestamp = os.time()
      })
      
      -- Remove from pending
      self.pending_changes[path] = nil
    end
  end
end

--- Check if file should be watched
-- @param path File path
-- @return boolean
function Watcher:_should_watch(path)
  -- Check ignore patterns first
  if self:_should_ignore(path) then
    return false
  end
  
  -- Check if matches any watch pattern
  for _, pattern in ipairs(self.patterns) do
    if path:match(pattern) then
      return true
    end
  end
  
  return false
end

--- Check if path should be ignored
-- @param path File path
-- @return boolean
function Watcher:_should_ignore(path)
  for _, pattern in ipairs(self.ignore) do
    if path:match(pattern) then
      return true
    end
  end
  
  return false
end

--- Get list of watched files
-- @return array of file paths
function Watcher:get_watched_files()
  local files = {}
  for path, _ in pairs(self.file_states) do
    table.insert(files, path)
  end
  return files
end

--- Get file count
-- @return number
function Watcher:get_file_count()
  local count = 0
  for _, _ in pairs(self.file_states) do
    count = count + 1
  end
  return count
end

return Watcher
