-- whisker/core/variable.lua
-- Variable data structure for typed story variables
-- Represents a single variable with type information and validation

local Variable = {}
Variable.__index = Variable

-- Module metadata for container auto-registration
Variable._whisker = {
  name = "Variable",
  version = "2.0.0",
  description = "Variable data structure for typed story variables",
  depends = {},
  capability = "core.variable"
}

-- Supported variable types
Variable.TYPES = {
  string = "string",
  number = "number",
  boolean = "boolean",
  table = "table"
}

-- Create a new Variable instance
-- @param name_or_options string|table - Variable name or options table
-- @param var_type string - Optional type (when first arg is string)
-- @param default any - Optional default value (when first arg is string)
-- @return Variable
function Variable.new(name_or_options, var_type, default)
  local options = {}
  if type(name_or_options) == "table" then
    options = name_or_options
  else
    options.name = name_or_options
    options.type = var_type
    options.default = default
  end

  local instance = {
    name = options.name or "",
    var_type = options.type or options.var_type or "string",
    default = options.default,
    description = options.description or nil,
    metadata = options.metadata or {}
  }

  -- Auto-detect type from default if not specified
  if instance.default ~= nil and instance.var_type == "string" then
    local detected = type(instance.default)
    if Variable.TYPES[detected] then
      instance.var_type = detected
    end
  end

  setmetatable(instance, Variable)
  return instance
end

-- Get the variable name
function Variable:get_name()
  return self.name
end

-- Set the variable name
function Variable:set_name(name)
  self.name = name
end

-- Get the variable type
function Variable:get_type()
  return self.var_type
end

-- Set the variable type
function Variable:set_type(var_type)
  if Variable.TYPES[var_type] then
    self.var_type = var_type
  end
end

-- Get the default value
function Variable:get_default()
  return self.default
end

-- Set the default value
function Variable:set_default(value)
  self.default = value
end

-- Get the description
function Variable:get_description()
  return self.description
end

-- Set the description
function Variable:set_description(description)
  self.description = description
end

-- Validate a value against the variable's type
function Variable:validate_value(value)
  if value == nil then
    return true -- nil is always valid (represents unset)
  end

  local value_type = type(value)
  if self.var_type == value_type then
    return true
  end

  return false, string.format("Expected %s, got %s", self.var_type, value_type)
end

-- Check if a value is valid for this variable
function Variable:is_valid(value)
  local valid, _ = self:validate_value(value)
  return valid
end

-- Metadata management
function Variable:set_metadata(key, value)
  self.metadata[key] = value
end

function Variable:get_metadata(key, default)
  local value = self.metadata[key]
  if value ~= nil then
    return value
  end
  return default
end

function Variable:has_metadata(key)
  return self.metadata[key] ~= nil
end

function Variable:delete_metadata(key)
  if self.metadata[key] ~= nil then
    self.metadata[key] = nil
    return true
  end
  return false
end

function Variable:clear_metadata()
  self.metadata = {}
end

function Variable:get_all_metadata()
  local copy = {}
  for k, v in pairs(self.metadata) do
    copy[k] = v
  end
  return copy
end

-- Validation
function Variable:validate()
  if not self.name or self.name == "" then
    return false, "Variable name is required"
  end

  if not Variable.TYPES[self.var_type] then
    return false, "Invalid variable type: " .. tostring(self.var_type)
  end

  -- Validate default value matches type if provided
  if self.default ~= nil then
    local valid, err = self:validate_value(self.default)
    if not valid then
      return false, "Default value: " .. err
    end
  end

  return true
end

-- Serialization - returns plain table representation
function Variable:serialize()
  return {
    name = self.name,
    type = self.var_type,
    default = self.default,
    description = self.description,
    metadata = self.metadata
  }
end

-- Deserialization - restores from plain table
function Variable:deserialize(data)
  self.name = data.name or ""
  self.var_type = data.type or data.var_type or "string"
  self.default = data.default
  self.description = data.description
  self.metadata = data.metadata or {}
end

-- Static method to restore metatable to a plain table
function Variable.restore_metatable(data)
  if not data or type(data) ~= "table" then
    return nil
  end

  -- If already has Variable metatable, return as-is
  if getmetatable(data) == Variable then
    return data
  end

  -- Set the Variable metatable
  setmetatable(data, Variable)

  -- Normalize type field name
  data.var_type = data.var_type or data.type or "string"

  return data
end

-- Static method to create from plain table
function Variable.from_table(data)
  if not data then
    return nil
  end

  return Variable.new({
    name = data.name,
    type = data.type or data.var_type,
    default = data.default,
    description = data.description,
    metadata = data.metadata
  })
end

-- Static method to check if a table is a typed variable format
function Variable.is_typed_format(data)
  if type(data) ~= "table" then
    return false
  end
  return data.type ~= nil and data.default ~= nil
end

-- Static method to create from simple value (auto-detect type)
function Variable.from_value(name, value)
  local var_type = type(value)
  if not Variable.TYPES[var_type] then
    var_type = "string"
  end

  return Variable.new({
    name = name,
    type = var_type,
    default = value
  })
end

return Variable
