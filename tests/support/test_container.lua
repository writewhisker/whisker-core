-- tests/support/test_container.lua
-- Test container for isolated DI in tests
-- Wraps production container with test-friendly API

local Container = require("whisker.kernel.container")
local MockFactory = require("tests.support.mock_factory")

local TestContainer = {}
TestContainer.__index = TestContainer

-- Create a new test container
-- @param options table - Optional: interfaces, capabilities
-- @return TestContainer
function TestContainer.new(options)
  options = options or {}
  local self = setmetatable({
    _container = Container.new(options),
    _mocks = {},
    _interfaces = options.interfaces,
  }, TestContainer)
  return self
end

-- Register a mock for an interface
-- @param name string - Component name
-- @param interface table - Interface definition to mock
-- @param options table - Optional: singleton (default true for mocks)
-- @return table - The mock object for configuration
function TestContainer:mock(name, interface, options)
  options = options or {}

  local mock = MockFactory.from_interface(interface)
  self._mocks[name] = mock

  -- Register mock with container (singletons by default for predictable testing)
  self._container:register(name, mock, {
    singleton = options.singleton ~= false,
    implements = interface._name,
  })

  return mock
end

-- Get a mock for verification
-- @param name string - Component name
-- @return table - The mock object
function TestContainer:get_mock(name)
  return self._mocks[name]
end

-- Register a real component (delegates to container)
-- @param name string - Component name
-- @param factory function|table - Factory or module
-- @param options table - Registration options
-- @return TestContainer - For chaining
function TestContainer:register(name, factory, options)
  self._container:register(name, factory, options)
  return self
end

-- Resolve a component (delegates to container)
-- @param name string - Component name
-- @param args table - Optional arguments
-- @return any - Resolved component
function TestContainer:resolve(name, args)
  return self._container:resolve(name, args)
end

-- Check if component is registered (delegates to container)
-- @param name string - Component name
-- @return boolean
function TestContainer:has(name)
  return self._container:has(name)
end

-- List registered components (delegates to container)
-- @return table - Array of component names
function TestContainer:list()
  return self._container:list()
end

-- List registered mocks
-- @return table - Array of mock names
function TestContainer:list_mocks()
  local names = {}
  for name in pairs(self._mocks) do
    table.insert(names, name)
  end
  table.sort(names)
  return names
end

-- Reset all mocks (clears calls and stubs)
function TestContainer:reset_mocks()
  for _, mock in pairs(self._mocks) do
    mock:reset()
  end
end

-- Reset mock calls only (keeps stubs)
function TestContainer:reset_mock_calls()
  for _, mock in pairs(self._mocks) do
    mock:reset_calls()
  end
end

-- Reset entire container (clears registrations, instances, and mocks)
function TestContainer:reset()
  self._container:clear()
  self._mocks = {}
end

-- Verify all mocks had no unexpected calls
-- Useful for strict verification in tests
-- @param expected table - Map of name -> expected call counts
function TestContainer:verify_no_extra_calls(expected)
  expected = expected or {}
  for name, mock in pairs(self._mocks) do
    local expected_count = expected[name] or 0
    local actual_count = mock:call_count()
    if actual_count > expected_count then
      error(string.format(
        "Mock '%s' had %d unexpected call(s) (expected %d, got %d)",
        name, actual_count - expected_count, expected_count, actual_count
      ), 2)
    end
  end
end

-- Configure a mock with fluent interface
-- @param name string - Mock name
-- @return table - Configuration builder
function TestContainer:configure(name)
  local mock = self._mocks[name]
  if not mock then
    error(string.format("No mock registered with name: %s", name), 2)
  end

  local builder = {
    _mock = mock,
    _container = self,
  }

  function builder:when(method_name)
    return self._mock:when(method_name)
  end

  function builder:done()
    return self._container
  end

  return builder
end

-- Shorthand for creating container with common mocks
-- @param mock_configs table - Map of name -> interface
-- @return TestContainer
function TestContainer.with_mocks(mock_configs, options)
  local container = TestContainer.new(options)
  for name, interface in pairs(mock_configs) do
    container:mock(name, interface)
  end
  return container
end

return TestContainer
