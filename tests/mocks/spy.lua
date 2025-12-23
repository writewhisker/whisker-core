--- Spy Utilities
-- Utility functions for creating spies and stubs
-- @module tests.mocks.spy
-- @author Whisker Core Team

local Spy = {}

--- Create a spy function
-- @param fn function|nil Optional function to wrap
-- @return function The spy function
-- @return table The call tracker
function Spy.create(fn)
  local tracker = {
    calls = {},
    call_count = 0,
  }

  local spy_fn = function(...)
    local args = {...}
    local result

    if fn then
      result = {fn(...)}
    end

    tracker.call_count = tracker.call_count + 1
    table.insert(tracker.calls, {
      args = args,
      result = result,
      timestamp = os.time(),
    })

    if result then
      return table.unpack(result)
    end
  end

  return spy_fn, tracker
end

--- Create a stub that returns a specific value
-- @param value any The value to return
-- @return function The stub function
-- @return table The call tracker
function Spy.stub(value)
  return Spy.create(function()
    return value
  end)
end

--- Create a stub that returns different values on each call
-- @param values table Array of values to return in sequence
-- @return function The stub function
-- @return table The call tracker
function Spy.sequence(values)
  local index = 0
  return Spy.create(function()
    index = index + 1
    return values[index]
  end)
end

--- Create a stub that throws an error
-- @param message string The error message
-- @return function The stub function
-- @return table The call tracker
function Spy.throws(message)
  return Spy.create(function()
    error(message)
  end)
end

--- Create a spy on an object method
-- @param obj table The object
-- @param method string The method name
-- @return table The call tracker
function Spy.on(obj, method)
  local original = obj[method]
  local spy_fn, tracker = Spy.create(original)

  tracker.restore = function()
    obj[method] = original
  end

  obj[method] = spy_fn

  return tracker
end

--- Assert spy was called
-- @param tracker table The call tracker
-- @param times number|nil Expected call count (optional)
function Spy.assert_called(tracker, times)
  if times then
    assert(tracker.call_count == times,
      string.format("Expected %d calls, got %d", times, tracker.call_count))
  else
    assert(tracker.call_count > 0, "Expected spy to be called")
  end
end

--- Assert spy was not called
-- @param tracker table The call tracker
function Spy.assert_not_called(tracker)
  assert(tracker.call_count == 0,
    string.format("Expected spy not to be called, but was called %d times", tracker.call_count))
end

--- Assert spy was called with specific arguments
-- @param tracker table The call tracker
-- @param ... any The expected arguments
function Spy.assert_called_with(tracker, ...)
  local expected = {...}

  for _, call in ipairs(tracker.calls) do
    local match = true
    for i, arg in ipairs(expected) do
      if call.args[i] ~= arg then
        match = false
        break
      end
    end
    if match then
      return true
    end
  end

  error("Spy was not called with expected arguments")
end

return Spy
