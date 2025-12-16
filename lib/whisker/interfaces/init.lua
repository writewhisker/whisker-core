-- whisker/interfaces/init.lua
-- Interface registry and validation utilities
-- Enables interface-based type checking for dependency injection

local Interfaces = {
  _VERSION = "0.1.0",
  _registered = {}
}

-- Register an interface definition
function Interfaces.register(interface)
  if not interface._name then
    error("Interface must have a _name field")
  end
  Interfaces._registered[interface._name] = interface
  return interface
end

-- Get a registered interface by name
function Interfaces.get(name)
  return Interfaces._registered[name]
end

-- Check if an object implements an interface
-- Returns true if all required methods/properties exist
function Interfaces.implements(obj, interface)
  if obj == nil then return false end
  if interface == nil then return false end

  -- Check required methods
  local required = interface._required or {}
  for _, method_name in ipairs(required) do
    if obj[method_name] == nil then
      return false
    end
    -- If interface specifies it should be a function, verify
    if type(interface[method_name]) == "string" and
       interface[method_name]:match("^function") and
       type(obj[method_name]) ~= "function" then
      return false
    end
  end

  return true
end

-- Validate an object against an interface
-- Returns success, list of missing/invalid members
function Interfaces.validate(obj, interface)
  local errors = {}

  if obj == nil then
    return false, {"Object is nil"}
  end

  if interface == nil then
    return false, {"Interface is nil"}
  end

  -- Check required methods
  local required = interface._required or {}
  for _, method_name in ipairs(required) do
    if obj[method_name] == nil then
      table.insert(errors, string.format("Missing required member: %s", method_name))
    elseif type(interface[method_name]) == "string" and
           interface[method_name]:match("^function") and
           type(obj[method_name]) ~= "function" then
      table.insert(errors, string.format("Member '%s' must be a function", method_name))
    end
  end

  return #errors == 0, errors
end

-- Create a stub implementation of an interface (useful for testing)
function Interfaces.stub(interface)
  local stub = {}
  local required = interface._required or {}
  for _, method_name in ipairs(required) do
    if type(interface[method_name]) == "string" and
       interface[method_name]:match("^function") then
      stub[method_name] = function() end
    else
      stub[method_name] = nil
    end
  end
  return stub
end

-- List all registered interfaces
function Interfaces.list()
  local names = {}
  for name in pairs(Interfaces._registered) do
    table.insert(names, name)
  end
  table.sort(names)
  return names
end

return Interfaces
