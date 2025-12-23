-- lib/whisker/script/i18n_tags.lua
-- Parser for i18n tags in Whisker Script (@@t and @@p)
-- Stage 7: Whisker Script i18n Integration

local M = {}

-- Module version
M._VERSION = "1.0.0"

--- Parse i18n tag (@@t or @@p)
-- @param text string Raw tag text
-- @return table AST node or nil
function M.parse(text)
  if not text or text == "" then
    return nil
  end

  -- Match @@t or @@p followed by key and optional arguments
  local tag, key, argsText = text:match("^@@([tp])%s+([%w%.]+)%s*(.*)")

  if not tag then
    -- Check if it starts with @@ but has invalid format
    if text:match("^@@[tp]") then
      -- Has @@t or @@p but missing key
      error("Translation key required after @@" .. (text:match("^@@([tp])") or "t"))
    end
    return nil
  end

  -- Parse arguments
  local args = M.parseArgs(argsText)

  if tag == "t" then
    return {
      type = "i18n_translate",
      key = key,
      args = args,
      raw = text
    }
  elseif tag == "p" then
    -- Validate that 'count' argument exists
    if not args.count then
      error("@@p requires 'count' argument: " .. text)
    end

    return {
      type = "i18n_plural",
      key = key,
      count = args.count,
      args = args,
      raw = text
    }
  end
end

--- Parse argument list (var=value var2=value2)
-- @param argsText string Argument text
-- @return table Key-value pairs
function M.parseArgs(argsText)
  local args = {}

  if not argsText or argsText == "" then
    return args
  end

  -- Match var=value pairs (allowing dotted values like player.name)
  for varName, value in argsText:gmatch("(%w+)=([%w%.]+)") do
    args[varName] = {
      name = varName,
      expression = value
    }
  end

  return args
end

--- Validate i18n tag
-- @param node table AST node
-- @param context table Parser context (optional)
-- @return boolean, string Success, error message
function M.validate(node, context)
  if not node then
    return false, "Node is nil"
  end

  -- Check key format
  if not node.key or not node.key:match("^[%w%.]+$") then
    return false, "Invalid translation key: " .. (node.key or "nil")
  end

  -- Validate variable expressions
  for varName, arg in pairs(node.args or {}) do
    -- Check if expression is valid (alphanumeric with dots)
    if not arg.expression:match("^[%w%.]+$") then
      return false, "Invalid expression for " .. varName .. ": " .. arg.expression
    end
  end

  return true
end

--- Check if text starts with an i18n tag
-- @param text string Text to check
-- @return boolean
function M.isI18nTag(text)
  if not text then
    return false
  end
  return text:match("^@@[tp]%s") ~= nil
end

--- Get tag type from text
-- @param text string Text to check
-- @return string|nil "t", "p", or nil
function M.getTagType(text)
  if not text then
    return nil
  end
  return text:match("^@@([tp])%s")
end

--- Count arguments in a node
-- @param node table AST node
-- @return number
function M.countArgs(node)
  if not node or not node.args then
    return 0
  end

  local count = 0
  for _ in pairs(node.args) do
    count = count + 1
  end
  return count
end

--- Get argument names from a node
-- @param node table AST node
-- @return table Array of argument names
function M.getArgNames(node)
  local names = {}
  if node and node.args then
    for name, _ in pairs(node.args) do
      table.insert(names, name)
    end
    table.sort(names)
  end
  return names
end

return M
