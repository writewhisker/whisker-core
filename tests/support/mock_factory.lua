-- tests/support/mock_factory.lua
-- Mock factory for generating mocks from interfaces
-- Provides call tracking, stubbing, and verification

local MockFactory = {}

-- Create a mock from an interface definition
-- @param interface table - Interface with _required and method signatures
-- @return table - Mock object with tracking and verification
function MockFactory.from_interface(interface)
  local mock = {
    _calls = {},
    _stubs = {},
    _interface = interface,
  }

  -- Create mock methods for all required members
  local required = interface._required or {}
  for _, method_name in ipairs(required) do
    local signature = interface[method_name]
    -- Only create function mocks for function signatures
    if type(signature) == "string" and signature:match("^function") then
      mock[method_name] = function(self, ...)
        local args = {...}
        table.insert(self._calls, {
          method = method_name,
          args = args,
          timestamp = os.time(),
        })

        -- Return stubbed value if configured
        local stub = self._stubs[method_name]
        if stub then
          if stub.returns_fn then
            return stub.returns_fn(...)
          end
          return stub.returns_value
        end

        -- Default returns based on signature
        if signature:match("-> boolean") then
          return false
        elseif signature:match("-> table") then
          return {}
        elseif signature:match("-> string") then
          return ""
        elseif signature:match("-> number") then
          return 0
        end

        return nil
      end
    else
      -- Non-function member (e.g., string property)
      mock[method_name] = nil
    end
  end

  -- Add when() for stubbing
  function mock:when(method_name)
    local stub_builder = {
      _mock = self,
      _method = method_name,
    }

    function stub_builder:returns(value)
      self._mock._stubs[self._method] = { returns_value = value }
      return self._mock
    end

    function stub_builder:returns_fn(fn)
      self._mock._stubs[self._method] = { returns_fn = fn }
      return self._mock
    end

    return stub_builder
  end

  -- Add verify() for verification
  function mock:verify(method_name)
    local verifier = {
      _mock = self,
      _method = method_name,
    }

    -- Get calls for this method
    function verifier:_get_calls()
      local method_calls = {}
      for _, call in ipairs(self._mock._calls) do
        if call.method == self._method then
          table.insert(method_calls, call)
        end
      end
      return method_calls
    end

    -- Verify call count
    function verifier:called(times)
      local calls = self:_get_calls()
      local actual = #calls
      if times ~= actual then
        error(string.format(
          "Expected %s to be called %d time(s), but was called %d time(s)",
          self._method, times, actual
        ), 2)
      end
      return true
    end

    -- Verify at least N calls
    function verifier:called_at_least(times)
      local calls = self:_get_calls()
      local actual = #calls
      if actual < times then
        error(string.format(
          "Expected %s to be called at least %d time(s), but was called %d time(s)",
          self._method, times, actual
        ), 2)
      end
      return true
    end

    -- Verify called with specific arguments
    function verifier:called_with(...)
      local expected_args = {...}
      local calls = self:_get_calls()

      for _, call in ipairs(calls) do
        local match = true
        for i, expected in ipairs(expected_args) do
          if call.args[i] ~= expected then
            match = false
            break
          end
        end
        if match then
          return true
        end
      end

      error(string.format(
        "Expected %s to be called with specified arguments, but no matching call found",
        self._method
      ), 2)
    end

    -- Verify never called
    function verifier:never_called()
      return self:called(0)
    end

    return verifier
  end

  -- Get all calls (for debugging)
  function mock:get_calls(method_name)
    if method_name then
      local method_calls = {}
      for _, call in ipairs(self._calls) do
        if call.method == method_name then
          table.insert(method_calls, call)
        end
      end
      return method_calls
    end
    return self._calls
  end

  -- Get call count
  function mock:call_count(method_name)
    if method_name then
      return #self:get_calls(method_name)
    end
    return #self._calls
  end

  -- Reset all calls and stubs
  function mock:reset()
    self._calls = {}
    self._stubs = {}
  end

  -- Reset only calls (keep stubs)
  function mock:reset_calls()
    self._calls = {}
  end

  return mock
end

-- Create a simple spy that wraps an existing object
-- @param obj table - Object to spy on
-- @param methods table - Array of method names to spy on (optional, spies all if nil)
-- @return table - Spy wrapper with call tracking
function MockFactory.spy(obj, methods)
  local spy = {
    _target = obj,
    _calls = {},
  }

  -- Determine which methods to spy on
  local method_list = methods or {}
  if #method_list == 0 then
    for key, value in pairs(obj) do
      if type(value) == "function" then
        table.insert(method_list, key)
      end
    end
  end

  -- Wrap each method
  for _, method_name in ipairs(method_list) do
    local original = obj[method_name]
    if type(original) == "function" then
      spy[method_name] = function(self, ...)
        local args = {...}
        table.insert(self._calls, {
          method = method_name,
          args = args,
          timestamp = os.time(),
        })
        return original(self._target, ...)
      end
    end
  end

  -- Add verification (same as mock)
  spy.verify = MockFactory.from_interface({ _required = {} }).verify
  spy.get_calls = MockFactory.from_interface({ _required = {} }).get_calls
  spy.call_count = MockFactory.from_interface({ _required = {} }).call_count
  spy.reset_calls = MockFactory.from_interface({ _required = {} }).reset_calls

  return spy
end

-- Create a stub function that tracks calls
-- @param return_value any - Value to return when called
-- @return function, table - Stub function and call tracker
function MockFactory.stub(return_value)
  local tracker = {
    calls = {},
    return_value = return_value,
  }

  local fn = function(...)
    local args = {...}
    table.insert(tracker.calls, {
      args = args,
      timestamp = os.time(),
    })
    return tracker.return_value
  end

  return fn, tracker
end

return MockFactory
