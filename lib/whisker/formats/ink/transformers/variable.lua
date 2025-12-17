-- whisker/formats/ink/transformers/variable.lua
-- Variable transformer for Ink to Whisker conversion
-- Converts Ink variables to whisker-core Variable format

local VariableTransformer = {}
VariableTransformer.__index = VariableTransformer

-- Module metadata
VariableTransformer._whisker = {
  name = "VariableTransformer",
  version = "1.0.0",
  description = "Transforms Ink variables to whisker-core format",
  depends = {},
  capability = "formats.ink.transformers.variable"
}

-- Create a new VariableTransformer instance
function VariableTransformer.new()
  local instance = {}
  setmetatable(instance, VariableTransformer)
  return instance
end

-- Transform an Ink variable to whisker format
-- @param name string - Variable name
-- @param value any - Variable value
-- @param options table|nil - Conversion options
-- @return table - Typed variable definition
function VariableTransformer:transform(name, value, options)
  options = options or {}

  local var_type = self:_detect_type(value)
  local default_value = self:_convert_value(value, var_type)

  return {
    name = name,
    type = var_type,
    default = default_value,
    metadata = options.preserve_ink_paths and { source = "ink" } or nil
  }
end

-- Detect the variable type from its value
-- @param value any - The variable value
-- @return string - The detected type
function VariableTransformer:_detect_type(value)
  if value == nil then
    return "nil"
  end

  local lua_type = type(value)

  if lua_type == "number" then
    -- Check if it's an integer or float
    if value == math.floor(value) then
      return "integer"
    else
      return "float"
    end
  elseif lua_type == "string" then
    return "string"
  elseif lua_type == "boolean" then
    return "boolean"
  elseif lua_type == "table" then
    -- Could be a list, divert reference, or complex value
    if value.value ~= nil then
      -- Wrapped value (tinta format)
      return self:_detect_type(value.value)
    elseif value.listName then
      return "list"
    else
      return "table"
    end
  end

  return "unknown"
end

-- Convert value to appropriate format
-- @param value any - The original value
-- @param var_type string - The detected type
-- @return any - The converted value
function VariableTransformer:_convert_value(value, var_type)
  if value == nil then
    return nil
  end

  -- Handle wrapped values
  if type(value) == "table" and value.value ~= nil then
    return self:_convert_value(value.value, var_type)
  end

  if var_type == "list" then
    return self:_convert_list(value)
  end

  return value
end

-- Convert an Ink list value
-- @param value table - The list value
-- @return table - Converted list
function VariableTransformer:_convert_list(value)
  if type(value) ~= "table" then
    return {}
  end

  -- Ink lists have a specific structure
  local result = {
    list_name = value.listName,
    items = {}
  }

  if value.content then
    for item_name, item_value in pairs(value.content) do
      table.insert(result.items, {
        name = item_name,
        value = item_value
      })
    end
  end

  return result
end

-- Transform all variables from an InkStory
-- @param ink_story InkStory - The Ink story
-- @param options table|nil - Conversion options
-- @return table - Map of variable name to typed definition
function VariableTransformer:transform_all(ink_story, options)
  options = options or {}

  local variables = ink_story:get_global_variables()
  local result = {}

  for name, var_info in pairs(variables) do
    result[name] = self:transform(name, var_info.value, options)
  end

  return result
end

return VariableTransformer
