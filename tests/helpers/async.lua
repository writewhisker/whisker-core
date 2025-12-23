--- Async Test Helpers
-- Support for asynchronous test operations
-- @module tests.helpers.async
-- @author Whisker Core Team
-- @license MIT

local Async = {}

--- Waits for a condition to become true with timeout
-- Useful for testing async operations or eventual consistency
-- @param condition function Function that returns true when condition is met
-- @param timeout number Maximum time to wait in seconds (default 5)
-- @param interval number Check interval in seconds (default 0.1)
-- @return boolean success True if condition met before timeout
function Async.wait_for(condition, timeout, interval)
  timeout = timeout or 5
  interval = interval or 0.1

  local elapsed = 0

  while elapsed < timeout do
    if condition() then
      return true
    end

    -- Sleep for interval
    local start = os.clock()
    while os.clock() - start < interval do
      -- Busy wait (Lua doesn't have sleep in standard lib)
    end

    elapsed = elapsed + interval
  end

  return false
end

--- Creates a promise-like deferred object for async testing
-- @return table deferred Object with resolve, reject, and state methods
function Async.create_deferred()
  local deferred = {
    state = "pending",
    value = nil,
    error = nil,
  }

  function deferred:resolve(value)
    if self.state == "pending" then
      self.state = "resolved"
      self.value = value
    end
  end

  function deferred:reject(err)
    if self.state == "pending" then
      self.state = "rejected"
      self.error = err
    end
  end

  function deferred:is_pending()
    return self.state == "pending"
  end

  function deferred:is_resolved()
    return self.state == "resolved"
  end

  function deferred:is_rejected()
    return self.state == "rejected"
  end

  function deferred:get_value()
    return self.value
  end

  function deferred:get_error()
    return self.error
  end

  return deferred
end

--- Run a function with a timeout
-- @param fn function The function to run
-- @param timeout number Maximum execution time in seconds
-- @return boolean success True if completed within timeout
-- @return any result The function result or error message
function Async.with_timeout(fn, timeout)
  timeout = timeout or 5

  local deferred = Async.create_deferred()
  local start = os.clock()

  -- Run function in protected call
  local co = coroutine.create(function()
    local ok, result = pcall(fn)
    if ok then
      deferred:resolve(result)
    else
      deferred:reject(result)
    end
  end)

  -- Resume coroutine and check timeout
  while deferred:is_pending() and (os.clock() - start) < timeout do
    local status = coroutine.status(co)
    if status == "suspended" then
      coroutine.resume(co)
    elseif status == "dead" then
      break
    end
  end

  if deferred:is_pending() then
    return false, "Timeout after " .. timeout .. " seconds"
  elseif deferred:is_rejected() then
    return false, deferred:get_error()
  else
    return true, deferred:get_value()
  end
end

--- Create a spy function that tracks calls
-- @return table spy Spy object with call tracking
function Async.create_spy()
  local spy = {
    calls = {},
    call_count = 0,
  }

  function spy:call(...)
    self.call_count = self.call_count + 1
    table.insert(self.calls, {...})
    return self
  end

  function spy:was_called()
    return self.call_count > 0
  end

  function spy:was_called_times(n)
    return self.call_count == n
  end

  function spy:get_call(n)
    return self.calls[n]
  end

  function spy:reset()
    self.calls = {}
    self.call_count = 0
  end

  -- Make the spy callable
  setmetatable(spy, {
    __call = function(self, ...)
      return self:call(...)
    end
  })

  return spy
end

--- Wait for an event to be emitted
-- @param events EventBus The event bus to listen on
-- @param event_name string The event name to wait for
-- @param timeout number Maximum wait time in seconds (default 5)
-- @return boolean received True if event was received
-- @return table|nil data The event data, or nil if timed out
function Async.wait_for_event(events, event_name, timeout)
  timeout = timeout or 5

  local received = false
  local event_data = nil

  local unsub = events:on(event_name, function(data)
    received = true
    event_data = data
  end)

  local success = Async.wait_for(function()
    return received
  end, timeout)

  unsub()

  return success, event_data
end

return Async
