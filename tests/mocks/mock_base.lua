--- Mock Base
-- Base class for mock objects with spy/stub capabilities
-- @module tests.mocks.mock_base
-- @author Whisker Core Team

local MockBase = {}
MockBase.__index = MockBase

--- Create a new mock base
-- @return MockBase A new mock base instance
function MockBase.new()
  local self = setmetatable({}, MockBase)
  self._calls = {}
  self._stubs = {}
  return self
end

--- Record a method call
-- @param method string The method name
-- @param args table The arguments passed
-- @param result any The return value
function MockBase:_record_call(method, args, result)
  self._calls[method] = self._calls[method] or {}
  table.insert(self._calls[method], {
    args = args,
    result = result,
    timestamp = os.time(),
  })
end

--- Get calls for a method
-- @param method string The method name
-- @return table Array of call records
function MockBase:get_calls(method)
  return self._calls[method] or {}
end

--- Get call count for a method
-- @param method string The method name
-- @return number The number of times the method was called
function MockBase:call_count(method)
  return #(self._calls[method] or {})
end

--- Check if a method was called
-- @param method string The method name
-- @return boolean True if the method was called
function MockBase:was_called(method)
  return self:call_count(method) > 0
end

--- Check if a method was called with specific arguments
-- @param method string The method name
-- @param ... any The expected arguments
-- @return boolean True if called with those arguments
function MockBase:was_called_with(method, ...)
  local expected = {...}
  local calls = self:get_calls(method)

  for _, call in ipairs(calls) do
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

  return false
end

--- Stub a method to return a specific value
-- @param method string The method name
-- @param value any The value to return
function MockBase:stub(method, value)
  self._stubs[method] = value
end

--- Get stub value for a method
-- @param method string The method name
-- @return any The stubbed value, or nil
function MockBase:get_stub(method)
  return self._stubs[method]
end

--- Reset all call records
function MockBase:reset()
  self._calls = {}
end

--- Reset all stubs
function MockBase:reset_stubs()
  self._stubs = {}
end

--- Reset everything
function MockBase:reset_all()
  self:reset()
  self:reset_stubs()
end

return MockBase
