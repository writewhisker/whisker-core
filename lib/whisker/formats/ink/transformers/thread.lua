-- whisker/formats/ink/transformers/thread.lua
-- Thread transformer for Ink to Whisker conversion
-- Converts Ink threads to content aggregation pattern

local ThreadTransformer = {}
ThreadTransformer.__index = ThreadTransformer

-- Module metadata
ThreadTransformer._whisker = {
  name = "ThreadTransformer",
  version = "1.0.0",
  description = "Transforms Ink threads to whisker content aggregation",
  depends = {},
  capability = "formats.ink.transformers.thread"
}

-- Create a new ThreadTransformer instance
function ThreadTransformer.new()
  local instance = {}
  setmetatable(instance, ThreadTransformer)
  return instance
end

-- Transform a thread to whisker format
-- @param thread_data table - The thread data
-- @param parent_path string - The parent passage path
-- @param options table|nil - Conversion options
-- @return table - Transformed thread info
function ThreadTransformer:transform(thread_data, parent_path, options)
  options = options or {}

  local target = self:_extract_target(thread_data)

  return {
    target = target,
    is_thread = true,
    parent = parent_path,
    metadata = {
      type = "thread",
      ink_source = parent_path,
      gathers_content = true
    }
  }
end

-- Extract target path from thread divert
-- @param thread_data table - The thread data
-- @return string|nil - The target path
function ThreadTransformer:_extract_target(thread_data)
  if type(thread_data) ~= "table" then
    return nil
  end

  -- Thread target can be in different places
  if thread_data["<-"] then
    return thread_data["<-"]
  end

  if thread_data.thread then
    return thread_data.thread
  end

  if thread_data.target then
    return thread_data.target
  end

  return nil
end

-- Check if an item is a thread start
-- @param item table - The item to check
-- @return boolean
function ThreadTransformer:is_thread_start(item)
  if type(item) ~= "table" then
    return false
  end

  return item["<-"] ~= nil or item.thread ~= nil
end

-- Find thread starts in a container
-- @param container table - The container to search
-- @return table - Array of thread info
function ThreadTransformer:find_threads(container)
  local threads = {}

  if type(container) ~= "table" then
    return threads
  end

  self:_find_threads_recursive(container, threads)

  return threads
end

-- Recursively find thread starts
function ThreadTransformer:_find_threads_recursive(container, threads)
  if type(container) ~= "table" then
    return
  end

  for i, item in ipairs(container) do
    if type(item) == "table" then
      if self:is_thread_start(item) then
        table.insert(threads, item)
      else
        self:_find_threads_recursive(item, threads)
      end
    end
  end
end

-- Create passage metadata for thread support
-- @param is_threaded boolean - Whether this passage uses threads
-- @param thread_targets table - Array of thread target paths
-- @return table - Metadata for passage
function ThreadTransformer:create_passage_metadata(is_threaded, thread_targets)
  return {
    is_threaded = is_threaded,
    thread_targets = thread_targets or {},
    execution_mode = is_threaded and "parallel" or "sequential"
  }
end

return ThreadTransformer
