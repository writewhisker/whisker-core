--- DI Container
-- Dependency injection container for managing service lifecycles
-- @module whisker.kernel.container
-- @author Whisker Core Team
-- @license MIT

local Container = {}
Container._dependencies = {}
Container.__index = Container

--- Create a new container instance
-- @return Container A new container
function Container.new(deps)
  deps = deps or {}
  local self = setmetatable({}, Container)
  self._registrations = {}
  self._singletons = {}
  self._resolving = {}
  self._destroy_callbacks = {}
  self._registration_order = {}
  return self
end

--- Register a service
-- @param name string The service name
-- @param factory function|table The factory function or module table
-- @param options table|nil Registration options
-- @param options.singleton boolean Whether to create only one instance
-- @param options.implements string Interface this service implements
-- @param options.override boolean Whether to override existing registration
function Container:register(name, factory, options)
  options = options or {}

  if self._registrations[name] and not options.override then
    error("Service '" .. name .. "' is already registered")
  end

  self._registrations[name] = {
    factory = factory,
    singleton = options.singleton or false,
    implements = options.implements,
    depends = options.depends,
    options = options,
  }

  -- Track registration order for destroy_all
  if not options.override then
    table.insert(self._registration_order, name)
  end

  -- Clear singleton if overriding
  if options.override then
    self._singletons[name] = nil
  end
end

--- Resolve a service by name
-- @param name string The service name
-- @return any The resolved service instance
function Container:resolve(name)
  local registration = self._registrations[name]

  if not registration then
    error("Service '" .. name .. "' is not registered")
  end

  -- Check for circular dependencies
  if self._resolving[name] then
    error("Circular dependency detected for service '" .. name .. "'")
  end

  -- Return singleton if available
  if registration.singleton and self._singletons[name] then
    return self._singletons[name]
  end

  -- Mark as resolving
  self._resolving[name] = true

  local instance
  local factory = registration.factory

  if type(factory) == "function" then
    instance = factory(self)
  elseif type(factory) == "table" then
    if factory.new then
      instance = factory.new(self)
    else
      instance = factory
    end
  else
    error("Invalid factory for service '" .. name .. "'")
  end

  -- Unmark as resolving
  self._resolving[name] = nil

  -- Store singleton
  if registration.singleton then
    self._singletons[name] = instance
  end

  return instance
end

--- Check if a service is registered
-- @param name string The service name
-- @return boolean True if registered
function Container:has(name)
  return self._registrations[name] ~= nil
end

--- Unregister a service
-- @param name string The service name
function Container:unregister(name)
  self._registrations[name] = nil
  self._singletons[name] = nil
end

--- Get all registered service names
-- @return table Array of service names
function Container:get_names()
  local names = {}
  for name in pairs(self._registrations) do
    table.insert(names, name)
  end
  return names
end

--- Clear all registrations and singletons
function Container:clear()
  self._registrations = {}
  self._singletons = {}
  self._resolving = {}
  self._destroy_callbacks = {}
  self._registration_order = {}
end

--- Create a child container
-- @return Container A new container with this as parent
function Container:create_child()
  local child = Container.new()
  child._parent = self

  -- Override resolve to check parent
  local original_resolve = child.resolve
  function child:resolve(name)
    if self._registrations[name] then
      return original_resolve(self, name)
    elseif self._parent then
      return self._parent:resolve(name)
    else
      error("Service '" .. name .. "' is not registered")
    end
  end

  -- Override has to check parent
  local original_has = child.has
  function child:has(name)
    if original_has(self, name) then
      return true
    elseif self._parent then
      return self._parent:has(name)
    end
    return false
  end

  return child
end

--- Register a service with lazy loading
-- Module is not loaded until first resolve
-- @param name string The service name
-- @param module_path string Module path to require
-- @param options table|nil Registration options
function Container:register_lazy(name, module_path, options)
  options = options or {}
  options.lazy = true
  options.module_path = module_path

  self:register(name, function(container)
    local module = require(module_path)
    if module.new then
      return module.new(container)
    end
    return module
  end, options)
end

--- Resolve a service with its dependencies
-- Ensures dependencies are resolved first
-- @param name string The service name
-- @param resolving table|nil Internal tracking for cycle detection
-- @return any The resolved service instance
function Container:resolve_with_deps(name, resolving)
  resolving = resolving or {}

  -- Check for circular dependencies
  if resolving[name] then
    local cycle = {}
    for k in pairs(resolving) do
      table.insert(cycle, k)
    end
    table.insert(cycle, name)
    error("Circular dependency detected: " .. table.concat(cycle, " -> "))
  end

  local registration = self._registrations[name]
  if not registration then
    error("Service '" .. name .. "' is not registered")
  end

  -- Mark as resolving
  resolving[name] = true

  -- Resolve dependencies first
  if registration.depends then
    for _, dep_name in ipairs(registration.depends) do
      if not self:has(dep_name) then
        error("Missing dependency: " .. dep_name .. " (required by " .. name .. ")")
      end
      self:resolve_with_deps(dep_name, resolving)
    end
  end

  -- Now resolve the service itself
  local instance = self:resolve(name)

  resolving[name] = nil
  return instance
end

--- Register a destruction callback for a service
-- Called when the service is destroyed
-- @param name string The service name
-- @param callback function Cleanup function to call
function Container:on_destroy(name, callback)
  if not self._destroy_callbacks[name] then
    self._destroy_callbacks[name] = {}
  end
  table.insert(self._destroy_callbacks[name], callback)
end

--- Destroy a service and run cleanup callbacks
-- @param name string The service name
function Container:destroy(name)
  -- Run destruction callbacks
  if self._destroy_callbacks[name] then
    for _, callback in ipairs(self._destroy_callbacks[name]) do
      pcall(callback)  -- Don't let cleanup errors propagate
    end
    self._destroy_callbacks[name] = nil
  end

  -- Remove singleton instance
  self._singletons[name] = nil
end

--- Destroy all services in reverse registration order
function Container:destroy_all()
  -- Destroy in reverse order
  for i = #self._registration_order, 1, -1 do
    local name = self._registration_order[i]
    self:destroy(name)
  end
end

--- List all registered service names (sorted)
-- @return table Array of service names
function Container:list_services()
  local names = {}
  for name in pairs(self._registrations) do
    table.insert(names, name)
  end
  table.sort(names)
  return names
end

return Container
