-- whisker/formats/ink/generators/variable.lua
-- Generates Ink variable declarations from whisker variables

local VariableGenerator = {}
VariableGenerator.__index = VariableGenerator

-- Module metadata
VariableGenerator._whisker = {
  name = "VariableGenerator",
  version = "1.0.0",
  description = "Generates Ink variable declarations from whisker variables",
  depends = {},
  capability = "formats.ink.generators.variable"
}

-- Create a new VariableGenerator instance
function VariableGenerator.new()
  local instance = {}
  setmetatable(instance, VariableGenerator)
  return instance
end

-- Generate a variable reference
-- @param name string - Variable name
-- @return table - Variable reference structure
function VariableGenerator:generate_reference(name)
  return { ["VAR?"] = name }
end

-- Generate a variable assignment
-- @param name string - Variable name
-- @param value any - Value to assign
-- @param operator string|nil - Assignment operator (default "=")
-- @return table - Assignment structure
function VariableGenerator:generate_assignment(name, value, operator)
  operator = operator or "="

  local result = {}

  -- Start evaluation
  table.insert(result, "ev")

  -- Add value
  local converted = self:_convert_value(value)
  table.insert(result, converted)

  -- End evaluation
  table.insert(result, "/ev")

  -- Variable assignment command
  local assign_op = self:_get_assign_op(operator)
  table.insert(result, { ["VAR="] = name, ["re"] = assign_op ~= "=" })

  return result
end

-- Generate compound assignment (+=, -=, etc.)
-- @param name string - Variable name
-- @param value any - Value to apply
-- @param operator string - Compound operator (+=, -=, *=, /=)
-- @return table - Compound assignment structure
function VariableGenerator:generate_compound_assignment(name, value, operator)
  local result = {}

  -- Start evaluation
  table.insert(result, "ev")

  -- Get current value
  table.insert(result, { ["VAR?"] = name })

  -- Add the value
  local converted = self:_convert_value(value)
  table.insert(result, converted)

  -- Add the operator
  local op = operator:sub(1, 1) -- Get first char: + from +=, etc.
  table.insert(result, op)

  -- End evaluation
  table.insert(result, "/ev")

  -- Reassign
  table.insert(result, { ["VAR="] = name, ["re"] = true })

  return result
end

-- Convert a value for Ink JSON
-- @param value any - Value to convert
-- @return any - Converted value
function VariableGenerator:_convert_value(value)
  local t = type(value)

  if t == "string" then
    return { ["^"] = value }
  elseif t == "number" then
    return value
  elseif t == "boolean" then
    return value
  elseif t == "nil" then
    return 0
  elseif t == "table" then
    -- Handle wrapped values
    if value.value ~= nil then
      return self:_convert_value(value.value)
    end
    -- Handle list values
    if value.list then
      return { list = value.list }
    end
    return value
  end

  return value
end

-- Get assignment operator type
-- @param operator string - The assignment operator
-- @return string - Normalized operator
function VariableGenerator:_get_assign_op(operator)
  if operator == "+=" or operator == "-=" or operator == "*=" or operator == "/=" then
    return operator:sub(1, 1)
  end
  return "="
end

-- Generate variable declaration for global variables section
-- @param variable table - Variable definition
-- @return table - Declaration structure
function VariableGenerator:generate_declaration(variable)
  local name = variable.name or "unnamed"
  local default = variable.default

  if default == nil then
    -- Set type-appropriate defaults
    if variable.type == "string" then
      default = ""
    elseif variable.type == "boolean" then
      default = false
    elseif variable.type == "list" then
      default = {}
    else
      default = 0
    end
  end

  return {
    name = name,
    value = self:_convert_value(default)
  }
end

-- Generate all variable declarations from story
-- @param variables table - Map of variable definitions
-- @return table - Map of declarations for globals section
function VariableGenerator:generate_all_declarations(variables)
  local declarations = {}

  for name, variable in pairs(variables) do
    local decl = self:generate_declaration(variable)
    declarations[decl.name] = decl.value
  end

  return declarations
end

return VariableGenerator
