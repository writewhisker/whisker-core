--- Analytics Collector for whisker-core
-- Event collection pipeline with queuing and batching
-- @module whisker.analytics.collector
-- @author Whisker Core Team
-- @license MIT

local Collector = {}
Collector.__index = Collector
Collector.VERSION = "1.0.0"

--- Configuration defaults
Collector._config = {
  enabled = true,
  batchSize = 50,              -- Events per batch
  flushInterval = 30000,       -- Flush interval in ms (30 seconds)
  maxQueueSize = 1000,         -- Max queued events
  maxRetries = 3,              -- Max retry attempts per batch
  retryBackoff = 2,            -- Backoff multiplier (exponential)
  initialRetryDelay = 1000,    -- Initial retry delay in ms
  persistQueue = false,        -- Whether to persist queue to disk
  queuePersistPath = "analytics_queue.json"
}

--- Dependencies (injected at runtime)
Collector._deps = {
  event_builder = nil,
  event_taxonomy = nil,
  privacy_filter = nil,
  backend_registry = nil
}

--- State
Collector._queue = {}          -- Event queue
Collector._flushTimer = nil    -- Timer for periodic flush
Collector._processing = false  -- Whether currently processing
Collector._lastFlushTime = 0   -- Timestamp of last flush
Collector._initialized = false

--- Collection statistics
Collector._stats = {
  eventsTracked = 0,
  eventsQueued = 0,
  eventsExported = 0,
  eventsFiltered = 0,
  eventsFailed = 0,
  batchesExported = 0,
  batchesFailed = 0
}

--- Timer callbacks (platform-specific, injectable)
Collector._timers = {
  setTimeout = nil,
  setInterval = nil,
  clearInterval = nil
}

--- Deep copy a table
-- @param tbl table The table to copy
-- @return table The copied table
local function deep_copy(tbl)
  if type(tbl) ~= "table" then
    return tbl
  end
  local copy = {}
  for key, value in pairs(tbl) do
    if type(value) == "table" then
      copy[key] = deep_copy(value)
    else
      copy[key] = value
    end
  end
  return copy
end

--- Get current timestamp in milliseconds
-- @return number Timestamp
local function get_timestamp()
  return os.time() * 1000
end

--- Initialize the collector
-- @param config table Configuration options
function Collector.initialize(config)
  config = config or {}

  -- Merge configuration
  for key, value in pairs(config) do
    if Collector._config[key] ~= nil then
      Collector._config[key] = value
    end
  end

  -- Load persisted queue if enabled
  if Collector._config.persistQueue then
    Collector._loadPersistedQueue()
  end

  -- Start periodic flush timer
  Collector._startFlushTimer()

  Collector._initialized = true
  Collector._lastFlushTime = get_timestamp()
end

--- Set dependencies
-- @param deps table Dependencies to inject
function Collector.setDependencies(deps)
  if deps.event_builder then
    Collector._deps.event_builder = deps.event_builder
  end
  if deps.event_taxonomy then
    Collector._deps.event_taxonomy = deps.event_taxonomy
  end
  if deps.privacy_filter then
    Collector._deps.privacy_filter = deps.privacy_filter
  end
  if deps.backend_registry then
    Collector._deps.backend_registry = deps.backend_registry
  end
end

--- Set timer functions (platform-specific)
-- @param timers table Timer functions
function Collector.setTimers(timers)
  if timers.setTimeout then
    Collector._timers.setTimeout = timers.setTimeout
  end
  if timers.setInterval then
    Collector._timers.setInterval = timers.setInterval
  end
  if timers.clearInterval then
    Collector._timers.clearInterval = timers.clearInterval
  end
end

--- Shutdown the collector
function Collector.shutdown()
  -- Stop flush timer
  Collector._stopFlushTimer()

  -- Flush remaining events synchronously
  Collector.flushSync()

  -- Persist queue if enabled
  if Collector._config.persistQueue then
    Collector._persistQueue()
  end

  Collector._initialized = false
end

--- Track an event
-- @param category string Event category
-- @param action string Event action
-- @param metadata table Event metadata
-- @return boolean Success
-- @return string|nil Error message
function Collector.trackEvent(category, action, metadata)
  if not Collector._config.enabled then
    return false, "Analytics disabled"
  end

  Collector._stats.eventsTracked = Collector._stats.eventsTracked + 1

  -- Build event
  local event, errors
  if Collector._deps.event_builder then
    event, errors = Collector._deps.event_builder.buildEvent(category, action, metadata)
    if not event then
      return false, errors and table.concat(errors, ", ") or "Invalid event"
    end
  else
    -- Fallback: create basic event structure
    event = {
      category = category,
      action = action,
      timestamp = get_timestamp(),
      sessionId = "unknown",
      storyId = "unknown",
      metadata = metadata or {}
    }
  end

  -- Apply privacy filter if available
  if Collector._deps.privacy_filter then
    event = Collector._deps.privacy_filter.apply(event)
    if not event then
      -- Event was filtered out due to consent level
      Collector._stats.eventsFiltered = Collector._stats.eventsFiltered + 1
      return true -- Success, just filtered
    end
  end

  -- Add to queue
  return Collector._enqueue(event)
end

--- Add event to queue
-- @param event table The event to queue
-- @return boolean Success
function Collector._enqueue(event)
  -- Check queue size limit
  if #Collector._queue >= Collector._config.maxQueueSize then
    -- Drop oldest event
    table.remove(Collector._queue, 1)
    Collector._stats.eventsFailed = Collector._stats.eventsFailed + 1
  end

  -- Add to queue
  table.insert(Collector._queue, event)
  Collector._stats.eventsQueued = Collector._stats.eventsQueued + 1

  -- Check if batch size reached
  if #Collector._queue >= Collector._config.batchSize then
    Collector._triggerFlush("batch_size_reached")
  end

  return true
end

--- Flush events to export backends (async)
-- @param reason string Reason for flush
function Collector.flush(reason)
  if Collector._processing then
    return
  end

  if #Collector._queue == 0 then
    return
  end

  Collector._processing = true
  Collector._lastFlushTime = get_timestamp()

  -- Create batch from queue
  local batchSize = math.min(#Collector._queue, Collector._config.batchSize)
  local batch = {}
  for i = 1, batchSize do
    table.insert(batch, Collector._queue[i])
  end

  -- Export batch
  Collector._exportBatch(batch, function(success, error)
    Collector._processing = false

    if success then
      -- Remove exported events from queue
      for i = 1, #batch do
        table.remove(Collector._queue, 1)
      end

      Collector._stats.eventsExported = Collector._stats.eventsExported + #batch
      Collector._stats.batchesExported = Collector._stats.batchesExported + 1

      -- Persist queue if enabled
      if Collector._config.persistQueue then
        Collector._persistQueue()
      end

      -- If more events in queue, schedule another flush
      if #Collector._queue > 0 then
        Collector._triggerFlush("remaining_events")
      end
    else
      Collector._stats.batchesFailed = Collector._stats.batchesFailed + 1
    end
  end)
end

--- Flush events synchronously (for shutdown)
function Collector.flushSync()
  if #Collector._queue == 0 then
    return
  end

  -- Create batch from queue
  local batch = {}
  for i = 1, #Collector._queue do
    table.insert(batch, Collector._queue[i])
  end

  -- Get backends
  local backends = {}
  if Collector._deps.backend_registry then
    backends = Collector._deps.backend_registry.getActiveBackends()
  end

  if #backends == 0 then
    return
  end

  -- Export synchronously to each backend
  for _, backend in ipairs(backends) do
    -- Call exportBatch with callback that does nothing (sync simulation)
    if backend.exportBatch then
      backend.exportBatch(batch, function() end)
    end
  end

  -- Clear queue
  Collector._queue = {}
  Collector._stats.eventsExported = Collector._stats.eventsExported + #batch
  Collector._stats.batchesExported = Collector._stats.batchesExported + 1
end

--- Export batch to backends
-- @param batch table Events to export
-- @param callback function Callback(success, error)
-- @param retryCount number Current retry count
function Collector._exportBatch(batch, callback, retryCount)
  retryCount = retryCount or 0

  local backends = {}
  if Collector._deps.backend_registry then
    backends = Collector._deps.backend_registry.getActiveBackends()
  end

  if #backends == 0 then
    -- No backends configured, consider success (events remain in queue)
    callback(true)
    return
  end

  -- Export to all backends
  local totalBackends = #backends
  local completedBackends = 0
  local anySuccess = false
  local lastError = nil

  for _, backend in ipairs(backends) do
    if backend.exportBatch then
      backend.exportBatch(batch, function(success, error)
        completedBackends = completedBackends + 1

        if success then
          anySuccess = true
        else
          lastError = error
        end

        -- When all backends complete
        if completedBackends >= totalBackends then
          if anySuccess then
            callback(true)
          elseif retryCount < Collector._config.maxRetries then
            -- Retry with exponential backoff
            local delay = Collector._config.initialRetryDelay *
                          (Collector._config.retryBackoff ^ retryCount)

            if Collector._timers.setTimeout then
              Collector._timers.setTimeout(function()
                Collector._exportBatch(batch, callback, retryCount + 1)
              end, delay)
            else
              -- No timer available, retry immediately
              Collector._exportBatch(batch, callback, retryCount + 1)
            end
          else
            -- Max retries exceeded
            Collector._stats.eventsFailed = Collector._stats.eventsFailed + #batch
            callback(false, lastError)
          end
        end
      end)
    else
      completedBackends = completedBackends + 1
    end
  end

  -- Handle case where no backends have exportBatch
  if completedBackends >= totalBackends then
    callback(true)
  end
end

--- Trigger flush (async)
-- @param reason string Reason for flush
function Collector._triggerFlush(reason)
  if Collector._processing then
    return
  end

  -- Use setTimeout if available, otherwise flush directly
  if Collector._timers.setTimeout then
    Collector._timers.setTimeout(function()
      Collector.flush(reason)
    end, 0)
  else
    Collector.flush(reason)
  end
end

--- Start periodic flush timer
function Collector._startFlushTimer()
  if Collector._flushTimer then
    return
  end

  if Collector._timers.setInterval then
    Collector._flushTimer = Collector._timers.setInterval(function()
      if #Collector._queue > 0 then
        Collector._triggerFlush("flush_interval")
      end
    end, Collector._config.flushInterval)
  end
end

--- Stop flush timer
function Collector._stopFlushTimer()
  if Collector._flushTimer then
    if Collector._timers.clearInterval then
      Collector._timers.clearInterval(Collector._flushTimer)
    end
    Collector._flushTimer = nil
  end
end

--- Persist queue to disk
function Collector._persistQueue()
  if #Collector._queue == 0 then
    return
  end

  local success, json = pcall(require, "whisker.utils.json")
  if not success then
    return
  end

  local file = io.open(Collector._config.queuePersistPath, "w")
  if file then
    file:write(json.encode(Collector._queue))
    file:close()
  end
end

--- Load persisted queue from disk
function Collector._loadPersistedQueue()
  local success, json = pcall(require, "whisker.utils.json")
  if not success then
    return
  end

  local file = io.open(Collector._config.queuePersistPath, "r")
  if file then
    local content = file:read("*all")
    file:close()

    local ok, queue = pcall(json.decode, content)
    if ok and type(queue) == "table" then
      Collector._queue = queue
      os.remove(Collector._config.queuePersistPath)
    end
  end
end

--- Get current queue size
-- @return number Queue size
function Collector.getQueueSize()
  return #Collector._queue
end

--- Get collector statistics
-- @return table Statistics
function Collector.getStats()
  return {
    eventsTracked = Collector._stats.eventsTracked,
    eventsQueued = Collector._stats.eventsQueued,
    eventsExported = Collector._stats.eventsExported,
    eventsFiltered = Collector._stats.eventsFiltered,
    eventsFailed = Collector._stats.eventsFailed,
    batchesExported = Collector._stats.batchesExported,
    batchesFailed = Collector._stats.batchesFailed,
    queueSize = #Collector._queue,
    queueLimit = Collector._config.maxQueueSize,
    processing = Collector._processing
  }
end

--- Get configuration
-- @return table Current configuration
function Collector.getConfig()
  return deep_copy(Collector._config)
end

--- Check if collector is enabled
-- @return boolean Enabled status
function Collector.isEnabled()
  return Collector._config.enabled
end

--- Enable or disable collector
-- @param enabled boolean Enable status
function Collector.setEnabled(enabled)
  Collector._config.enabled = enabled
end

--- Reset collector state (for testing)
function Collector.reset()
  Collector._queue = {}
  Collector._processing = false
  Collector._lastFlushTime = 0
  Collector._initialized = false
  Collector._flushTimer = nil
  Collector._stats = {
    eventsTracked = 0,
    eventsQueued = 0,
    eventsExported = 0,
    eventsFiltered = 0,
    eventsFailed = 0,
    batchesExported = 0,
    batchesFailed = 0
  }
  Collector._config = {
    enabled = true,
    batchSize = 50,
    flushInterval = 30000,
    maxQueueSize = 1000,
    maxRetries = 3,
    retryBackoff = 2,
    initialRetryDelay = 1000,
    persistQueue = false,
    queuePersistPath = "analytics_queue.json"
  }
end

return Collector
