--- Mock State
-- Mock implementation of IState interface
-- @module tests.mocks.mock_state
-- @author Whisker Core Team

local MockBase = require("tests.mocks.mock_base")

local MockState = setmetatable({}, {__index = MockBase})
MockState.__index = MockState

--- Create a new mock state
-- @param initial_data table|nil Initial state data
-- @return MockState A new mock state instance
function MockState.new(initial_data)
  local self = setmetatable(MockBase.new(), MockState)
  self._data = initial_data or {}
  return self
end

function MockState:get(key)
  self:_record_call("get", {key}, self._data[key])
  return self._data[key]
end

function MockState:set(key, value)
  self:_record_call("set", {key, value})
  self._data[key] = value
end

function MockState:has(key)
  local result = self._data[key] ~= nil
  self:_record_call("has", {key}, result)
  return result
end

function MockState:delete(key)
  local existed = self._data[key] ~= nil
  self:_record_call("delete", {key}, existed)
  self._data[key] = nil
  return existed
end

function MockState:clear()
  self:_record_call("clear", {})
  self._data = {}
end

function MockState:snapshot()
  local snap = {}
  for k, v in pairs(self._data) do
    snap[k] = v
  end
  self:_record_call("snapshot", {}, snap)
  return snap
end

function MockState:restore(snapshot)
  self:_record_call("restore", {snapshot})
  self._data = {}
  for k, v in pairs(snapshot) do
    self._data[k] = v
  end
end

function MockState:keys()
  local result = {}
  for k in pairs(self._data) do
    table.insert(result, k)
  end
  self:_record_call("keys", {}, result)
  return result
end

--- Get the internal data (for testing)
-- @return table The internal data
function MockState:get_data()
  return self._data
end

return MockState
