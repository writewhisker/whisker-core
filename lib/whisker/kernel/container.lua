-- whisker/kernel/container.lua
-- Dependency Injection Container
-- Manages component registration, lifecycle, and dependency resolution

local Container = {}
Container.__index = Container

-- Error codes for container
Container.errors = {
  COMPONENT_NOT_FOUND = "C001",
  COMPONENT_EXISTS = "C002",
  CIRCULAR_DEPENDENCY = "C003",
  INTERFACE_MISMATCH = "C004",
  INVALID_FACTORY = "C005",
}

-- Create a new container instance
function Container.new(options)
  options = options or {}
  return setmetatable({
    _registrations = {},
    _instances = {},
    _interfaces = options.interfaces,  -- Optional interfaces module for validation
    _capabilities = options.capabilities,  -- Optional capabilities module
    _resolving = {},  -- Stack for circular dependency detection
  }, Container)
end

-- Register a component with the container
-- @param name string - Component identifier
-- @param factory function|table - Factory function or module table
-- @param options table - Registration options:
--   singleton: boolean - Reuse single instance (default false)
--   implements: string - Interface name to validate against
--   depends: table - Array of dependency names
--   capability: string - Register as capability when resolved
--   init: string - Method name to call after creation
--   destroy: string - Method name to call on container:destroy()
function Container:register(name, factory, options)
  if self._registrations[name] then
    error(string.format("[%s] Component already registered: %s",
      Container.errors.COMPONENT_EXISTS, name), 2)
  end

  options = options or {}

  -- Validate factory
  if factory == nil then
    error(string.format("[%s] Factory cannot be nil for: %s",
      Container.errors.INVALID_FACTORY, name), 2)
  end

  -- Wrap non-function factories (modules) in identity function
  local factory_fn = type(factory) == "function" and factory or function() return factory end

  self._registrations[name] = {
    factory = factory_fn,
    singleton = options.singleton or false,
    implements = options.implements,
    depends = options.depends or {},
    capability = options.capability,
    init = options.init,
    destroy = options.destroy,
  }

  return self
end

-- Resolve a component by name
-- @param name string - Component identifier
-- @param args table - Optional arguments to pass to factory
-- @return any - The resolved component instance
function Container:resolve(name, args)
  local reg = self._registrations[name]
  if not reg then
    error(string.format("[%s] Unknown component: %s",
      Container.errors.COMPONENT_NOT_FOUND, name), 2)
  end

  -- Check for circular dependency
  if self._resolving[name] then
    local cycle = {}
    for n in pairs(self._resolving) do table.insert(cycle, n) end
    table.insert(cycle, name)
    error(string.format("[%s] Circular dependency detected: %s",
      Container.errors.CIRCULAR_DEPENDENCY, table.concat(cycle, " -> ")), 2)
  end

  -- Return cached singleton if available
  if reg.singleton and self._instances[name] then
    return self._instances[name]
  end

  -- Mark as resolving for circular detection
  self._resolving[name] = true

  -- Resolve dependencies
  local deps = {}
  for _, dep_name in ipairs(reg.depends) do
    deps[dep_name] = self:resolve(dep_name)
  end

  -- Create instance
  local instance = reg.factory(deps, args)

  -- Clear resolving flag
  self._resolving[name] = nil

  -- Validate interface if specified
  if reg.implements and self._interfaces then
    local interface = self._interfaces.get(reg.implements)
    if interface then
      local valid, errors = self._interfaces.validate(instance, interface)
      if not valid then
        error(string.format("[%s] Component '%s' does not implement %s: %s",
          Container.errors.INTERFACE_MISMATCH, name, reg.implements,
          table.concat(errors, ", ")), 2)
      end
    end
  end

  -- Call init method if specified
  if reg.init and type(instance[reg.init]) == "function" then
    instance[reg.init](instance, self)
  end

  -- Register capability if specified
  if reg.capability and self._capabilities then
    self._capabilities:register(reg.capability, true)
  end

  -- Cache singleton
  if reg.singleton then
    self._instances[name] = instance
  end

  return instance
end

-- Check if a component is registered
function Container:has(name)
  return self._registrations[name] ~= nil
end

-- Get registration info (for debugging)
function Container:get_registration(name)
  return self._registrations[name]
end

-- Resolve by interface name (first matching component)
function Container:resolve_interface(interface_name)
  for name, reg in pairs(self._registrations) do
    if reg.implements == interface_name then
      return self:resolve(name)
    end
  end
  error(string.format("[%s] No component implements: %s",
    Container.errors.COMPONENT_NOT_FOUND, interface_name), 2)
end

-- Resolve all components implementing an interface
function Container:resolve_all(interface_name)
  local results = {}
  for name, reg in pairs(self._registrations) do
    if reg.implements == interface_name then
      table.insert(results, self:resolve(name))
    end
  end
  return results
end

-- List all registered component names
function Container:list()
  local names = {}
  for name in pairs(self._registrations) do
    table.insert(names, name)
  end
  table.sort(names)
  return names
end

-- Destroy container and call destroy methods on singletons
function Container:destroy()
  for name, instance in pairs(self._instances) do
    local reg = self._registrations[name]
    if reg and reg.destroy and type(instance[reg.destroy]) == "function" then
      instance[reg.destroy](instance)
    end
  end
  self._instances = {}
end

-- Clear all registrations and instances
function Container:clear()
  self:destroy()
  self._registrations = {}
  self._resolving = {}
end

return Container
