--- Mock Plugin
-- Mock implementation of IPlugin interface
-- @module tests.mocks.mock_plugin
-- @author Whisker Core Team

local MockBase = require("tests.mocks.mock_base")

local MockPlugin = setmetatable({}, {__index = MockBase})
MockPlugin.__index = MockPlugin

--- Create a new mock plugin
-- @param options table|nil Plugin options
-- @return MockPlugin A new mock plugin instance
function MockPlugin.new(options)
  options = options or {}

  local self = setmetatable(MockBase.new(), MockPlugin)
  self._name = options.name or "mock_plugin"
  self._version = options.version or "1.0.0"
  self._enabled = options.enabled ~= false
  self._initialized = false
  self._hooks = options.hooks or {}
  self._services = options.services or {}
  self._dependencies = options.dependencies or {}
  self._container = nil
  return self
end

function MockPlugin:get_name()
  self:_record_call("get_name", {}, self._name)
  return self._name
end

function MockPlugin:get_version()
  self:_record_call("get_version", {}, self._version)
  return self._version
end

function MockPlugin:init(container)
  self:_record_call("init", {container})
  self._container = container
  self._initialized = true
  return true
end

function MockPlugin:destroy()
  self:_record_call("destroy", {})
  self._initialized = false
  self._container = nil
end

function MockPlugin:get_hooks()
  self:_record_call("get_hooks", {}, self._hooks)
  return self._hooks
end

function MockPlugin:get_services()
  self:_record_call("get_services", {}, self._services)
  return self._services
end

function MockPlugin:get_dependencies()
  self:_record_call("get_dependencies", {}, self._dependencies)
  return self._dependencies
end

function MockPlugin:is_enabled()
  self:_record_call("is_enabled", {}, self._enabled)
  return self._enabled
end

function MockPlugin:enable()
  self:_record_call("enable", {})
  self._enabled = true
end

function MockPlugin:disable()
  self:_record_call("disable", {})
  self._enabled = false
end

--- Check if plugin is initialized (for testing)
-- @return boolean True if initialized
function MockPlugin:is_initialized()
  return self._initialized
end

--- Add a hook (for testing)
-- @param event string The event name
-- @param handler function The handler function
function MockPlugin:add_hook(event, handler)
  self._hooks[event] = handler
end

--- Add a service (for testing)
-- @param name string The service name
-- @param factory function The service factory
function MockPlugin:add_service(name, factory)
  self._services[name] = factory
end

return MockPlugin
