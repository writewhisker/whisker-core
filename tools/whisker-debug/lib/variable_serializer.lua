-- whisker-debug/lib/variable_serializer.lua
-- Converts Lua values to DAP variable format

local M = {}

-- Try to load interfaces from various paths
local interfaces
local ok
ok, interfaces = pcall(require, "lib.interfaces")
if not ok then
  ok, interfaces = pcall(require, "whisker-debug.lib.interfaces")
  if not ok then
    -- Fallback: define minimal constants
    interfaces = {
      ScopeRanges = {
        GLOBALS_START = 1000,
        GLOBALS_END = 1999,
        LOCALS_START = 2000,
        LOCALS_END = 2999,
        TEMPS_START = 3000,
        TEMPS_END = 3999,
        CONTAINERS_START = 10000
      }
    }
  end
end

local VariableSerializer = {}
VariableSerializer.__index = VariableSerializer

---Create a new VariableSerializer
---@return table
function VariableSerializer.new()
  local self = setmetatable({}, VariableSerializer)
  self.containers = {}
  self.next_ref = interfaces.ScopeRanges.CONTAINERS_START
  return self
end

---Serialize a Lua value to DAP variable format
---@param name string The variable name
---@param value any The Lua value
---@return table DAP variable
function VariableSerializer:serialize(name, value)
  local var = {
    name = tostring(name),
    value = self:format_value(value),
    type = type(value),
    variablesReference = 0
  }

  if type(value) == "table" then
    var.variablesReference = self:register_container(value)
    var.namedVariables = self:count_named(value)
    var.indexedVariables = self:count_indexed(value)
  end

  return var
end

---Get child variables for a container
---@param reference number The variables reference
---@return table[] Child variables
function VariableSerializer:get_variables(reference)
  local container = self.containers[reference]
  if not container then
    return {}
  end

  local variables = {}

  -- Handle array-like tables
  for i, v in ipairs(container) do
    table.insert(variables, self:serialize("[" .. i .. "]", v))
  end

  -- Handle named keys (skip numeric keys already handled)
  local seen = {}
  for i = 1, #container do
    seen[i] = true
  end

  local named = {}
  for k, v in pairs(container) do
    if not seen[k] then
      table.insert(named, {key = k, value = v})
    end
  end

  -- Sort named keys
  table.sort(named, function(a, b)
    return tostring(a.key) < tostring(b.key)
  end)

  for _, item in ipairs(named) do
    table.insert(variables, self:serialize(tostring(item.key), item.value))
  end

  return variables
end

---Register a container and get a reference
---@param container table The container value
---@return number Reference ID
function VariableSerializer:register_container(container)
  -- Check if already registered
  for ref, c in pairs(self.containers) do
    if c == container then
      return ref
    end
  end

  local ref = self.next_ref
  self.next_ref = self.next_ref + 1
  self.containers[ref] = container

  return ref
end

---Get the container for a reference
---@param reference number The reference ID
---@return table|nil The container
function VariableSerializer:get_container(reference)
  return self.containers[reference]
end

---Format a value for display
---@param value any The value
---@return string
function VariableSerializer:format_value(value)
  local t = type(value)

  if t == "nil" then
    return "nil"
  elseif t == "boolean" then
    return tostring(value)
  elseif t == "number" then
    return tostring(value)
  elseif t == "string" then
    -- Escape and quote string
    local escaped = value:gsub("\\", "\\\\")
                        :gsub("\"", "\\\"")
                        :gsub("\n", "\\n")
                        :gsub("\r", "\\r")
                        :gsub("\t", "\\t")
    return '"' .. escaped .. '"'
  elseif t == "table" then
    local count = self:table_length(value)
    return string.format("table[%d]", count)
  elseif t == "function" then
    return "function"
  elseif t == "userdata" then
    return "userdata"
  elseif t == "thread" then
    return "thread"
  else
    return tostring(value)
  end
end

---Evaluate an expression in a given context
---@param expression string The expression to evaluate
---@param context table The evaluation context (variables)
---@return boolean success
---@return any result_or_error
function VariableSerializer:evaluate(expression, context)
  -- Create sandboxed environment
  local env = setmetatable({}, {__index = context})

  -- Compile expression
  local func, err = load("return " .. expression, "eval", "t", env)
  if not func then
    -- Try as statement
    func, err = load(expression, "eval", "t", env)
    if not func then
      return false, "Syntax error: " .. tostring(err)
    end
  end

  -- Execute
  local ok, result = pcall(func)
  if not ok then
    return false, "Runtime error: " .. tostring(result)
  end

  return true, result
end

---Serialize evaluation result
---@param expression string The original expression
---@param success boolean Whether evaluation succeeded
---@param result any The result or error
---@return table DAP evaluate response
function VariableSerializer:serialize_eval_result(expression, success, result)
  if not success then
    return {
      result = tostring(result),
      type = "error",
      variablesReference = 0
    }
  end

  local var = self:serialize("result", result)
  return {
    result = var.value,
    type = var.type,
    variablesReference = var.variablesReference,
    namedVariables = var.namedVariables,
    indexedVariables = var.indexedVariables
  }
end

---Clear all registered containers
function VariableSerializer:clear()
  self.containers = {}
  self.next_ref = interfaces.ScopeRanges.CONTAINERS_START
end

---Count table length
---@param t table
---@return number
function VariableSerializer:table_length(t)
  local count = 0
  for _ in pairs(t) do
    count = count + 1
  end
  return count
end

---Count named (non-integer) keys
---@param t table
---@return number
function VariableSerializer:count_named(t)
  local count = 0
  for k in pairs(t) do
    if type(k) ~= "number" or k ~= math.floor(k) or k < 1 then
      count = count + 1
    end
  end
  return count
end

---Count indexed (integer) keys
---@param t table
---@return number
function VariableSerializer:count_indexed(t)
  return #t
end

M.new = VariableSerializer.new

return M
