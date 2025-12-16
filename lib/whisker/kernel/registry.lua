-- whisker/kernel/registry.lua
-- Module registration and lookup
-- Zero external dependencies (errors passed in)

local Registry = {}
Registry.__index = Registry

-- Create a new registry instance
function Registry.new(errors)
  local self = setmetatable({}, Registry)
  self._modules = {}
  self._errors = errors
  return self
end

-- Register a module by name
-- Supports namespaced names like "format.json"
function Registry:register(name, module)
  if type(name) ~= "string" or name == "" then
    self._errors.throw(
      self._errors.codes.INVALID_MODULE,
      "Module name must be a non-empty string"
    )
  end

  if self._modules[name] then
    self._errors.throw(
      self._errors.codes.MODULE_ALREADY_REGISTERED,
      string.format("Module '%s' is already registered", name)
    )
  end

  if module == nil then
    self._errors.throw(
      self._errors.codes.INVALID_MODULE,
      string.format("Module '%s' cannot be nil", name)
    )
  end

  self._modules[name] = module
  return true
end

-- Unregister a module by name
function Registry:unregister(name)
  if not self._modules[name] then
    return false
  end
  self._modules[name] = nil
  return true
end

-- Get a module by name
-- Returns nil if not found (does not throw)
function Registry:get(name)
  return self._modules[name]
end

-- Check if a module is registered
function Registry:has(name)
  return self._modules[name] ~= nil
end

-- Get all registered module names
function Registry:list()
  local names = {}
  for name in pairs(self._modules) do
    table.insert(names, name)
  end
  table.sort(names)
  return names
end

-- Get count of registered modules
function Registry:count()
  local count = 0
  for _ in pairs(self._modules) do
    count = count + 1
  end
  return count
end

-- Clear all registered modules
function Registry:clear()
  self._modules = {}
end

return Registry
