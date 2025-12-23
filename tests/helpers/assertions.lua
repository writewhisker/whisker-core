--- Custom Assertions
-- Domain-specific assertions for whisker-core testing
-- @module tests.helpers.assertions
-- @author Whisker Core Team

local Assertions = {}

--- Assert that an object implements an interface
-- @param obj table The object to check
-- @param interface table The interface definition
-- @param message string|nil Optional failure message
function Assertions.implements(obj, interface, message)
  message = message or "Object does not implement interface"

  assert(type(obj) == "table", message .. ": object is not a table")

  for name, _ in pairs(interface) do
    if type(interface[name]) == "function" and name ~= "__index" then
      assert(obj[name] ~= nil, message .. ": missing method '" .. name .. "'")
      assert(type(obj[name]) == "function", message .. ": '" .. name .. "' is not a function")
    end
  end
end

--- Assert that an event was emitted
-- @param events EventBus The event bus
-- @param event_name string The expected event name
-- @param predicate function|nil Optional predicate to check event data
function Assertions.emits(events, event_name, predicate)
  local received = false
  local received_data = nil

  local unsub = events:on(event_name, function(data)
    received = true
    received_data = data
  end)

  -- Return a function that triggers the action and checks
  return function(action)
    action()
    unsub()

    assert(received, "Event '" .. event_name .. "' was not emitted")

    if predicate then
      assert(predicate(received_data), "Event data did not match predicate")
    end

    return received_data
  end
end

--- Assert that a passage is valid
-- @param passage table The passage to validate
function Assertions.valid_passage(passage)
  assert(passage ~= nil, "Passage is nil")
  assert(type(passage) == "table", "Passage is not a table")
  assert(passage.id ~= nil, "Passage missing id")
  assert(type(passage.id) == "string", "Passage id is not a string")
end

--- Assert that a story is valid
-- @param story table The story to validate
function Assertions.valid_story(story)
  assert(story ~= nil, "Story is nil")
  assert(type(story) == "table", "Story is not a table")
  assert(story.metadata ~= nil, "Story missing metadata")
end

--- Assert that a choice is valid
-- @param choice table The choice to validate
function Assertions.valid_choice(choice)
  assert(choice ~= nil, "Choice is nil")
  assert(type(choice) == "table", "Choice is not a table")
  assert(choice.text ~= nil or choice.target ~= nil, "Choice missing text or target")
end

--- Assert approximate equality for numbers
-- @param actual number The actual value
-- @param expected number The expected value
-- @param tolerance number The allowed difference (default 0.0001)
function Assertions.approx_equals(actual, expected, tolerance)
  tolerance = tolerance or 0.0001
  local diff = math.abs(actual - expected)
  assert(diff <= tolerance,
    string.format("Expected %s to be approximately %s (tolerance: %s, diff: %s)",
      tostring(actual), tostring(expected), tostring(tolerance), tostring(diff)))
end

--- Assert that a table contains a key
-- @param tbl table The table to check
-- @param key any The key to look for
function Assertions.has_key(tbl, key)
  assert(type(tbl) == "table", "Expected table, got " .. type(tbl))
  assert(tbl[key] ~= nil, "Table does not contain key '" .. tostring(key) .. "'")
end

--- Assert that a table contains a value
-- @param tbl table The table to check
-- @param value any The value to look for
function Assertions.contains(tbl, value)
  assert(type(tbl) == "table", "Expected table, got " .. type(tbl))

  for _, v in pairs(tbl) do
    if v == value then
      return true
    end
  end

  assert(false, "Table does not contain value '" .. tostring(value) .. "'")
end

--- Assert that a function throws an error
-- @param fn function The function to call
-- @param pattern string|nil Optional pattern to match in error message
function Assertions.throws(fn, pattern)
  local ok, err = pcall(fn)
  assert(not ok, "Expected function to throw an error")

  if pattern then
    assert(string.find(tostring(err), pattern),
      "Error '" .. tostring(err) .. "' did not match pattern '" .. pattern .. "'")
  end
end

--- Assert that a function does not throw
-- @param fn function The function to call
function Assertions.does_not_throw(fn)
  local ok, err = pcall(fn)
  assert(ok, "Expected function not to throw, but got: " .. tostring(err))
end

return Assertions
