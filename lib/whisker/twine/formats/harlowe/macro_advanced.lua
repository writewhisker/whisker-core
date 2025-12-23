--- Harlowe advanced macro translation
-- Implements: for, live, event, a, dm, named hooks, possessive syntax
--
-- lib/whisker/twine/formats/harlowe/macro_advanced.lua

local MacroAdvanced = {}

local ASTBuilder = require('whisker.twine.ast_builder')
local MacroCore = require('whisker.twine.formats.harlowe.macro_core')

--------------------------------------------------------------------------------
-- Translator Registration
--------------------------------------------------------------------------------

--- Register advanced macro translators
---@param translators table The translators table to add to
function MacroAdvanced.register_translators(translators)
  translators["for"] = MacroAdvanced.translate_for
  translators["live"] = MacroAdvanced.translate_live
  translators["event"] = MacroAdvanced.translate_event
  translators["a"] = MacroAdvanced.translate_array
  translators["dm"] = MacroAdvanced.translate_datamap
  translators["ds"] = MacroAdvanced.translate_dataset
  translators["replace"] = MacroAdvanced.translate_replace
  translators["append"] = MacroAdvanced.translate_append
  translators["prepend"] = MacroAdvanced.translate_prepend
  translators["show"] = MacroAdvanced.translate_show
  translators["hide"] = MacroAdvanced.translate_hide
  translators["either"] = MacroAdvanced.translate_either
  translators["random"] = MacroAdvanced.translate_random
  translators["range"] = MacroAdvanced.translate_range
end

--------------------------------------------------------------------------------
-- Loop Macros
--------------------------------------------------------------------------------

--- Translate (for: each _var, ...$array)[body]
---@param args table Parsed arguments
---@param hook_content string|nil Hook content
---@return table AST node
function MacroAdvanced.translate_for(args, hook_content)
  if #args < 1 then
    return MacroAdvanced._error("for requires: each _var, ...$collection")
  end

  -- Parse the expression which should be "each _var, ...$collection"
  local expr = args[1].value
  if type(expr) ~= "string" then
    expr = tostring(expr)
  end

  -- Try to parse "each _var, ...$collection" pattern
  local var_name, collection_name = expr:match("^each%s+_([%w_]+)%s*,%s*%.%.%.%$([%w_]+)$")

  if not var_name then
    -- Try alternate pattern: "each _var, _index, ...$collection"
    local var, idx, coll = expr:match("^each%s+_([%w_]+)%s*,%s*_([%w_]+)%s*,%s*%.%.%.%$([%w_]+)$")
    if var then
      var_name = var
      collection_name = coll
      -- Note: we could store idx for indexed iteration, but simplify for now
    end
  end

  if not var_name then
    -- Check if args are passed separately
    if #args >= 2 then
      local each_expr = args[1].value
      local spread_expr = args[2].value

      var_name = tostring(each_expr):match("each%s+_([%w_]+)")
      collection_name = tostring(spread_expr):match("%.%.%.%$([%w_]+)")
    end
  end

  if not var_name then
    return MacroAdvanced._error("for requires 'each _variable' syntax")
  end

  if not collection_name then
    return MacroAdvanced._error("for requires '...$collection' spread syntax")
  end

  -- Build AST
  local body = hook_content and MacroAdvanced._parse_hook(hook_content) or {}

  return ASTBuilder.create_for_loop(
    var_name,
    ASTBuilder.create_variable_ref(collection_name),
    body
  )
end

--------------------------------------------------------------------------------
-- Live/Timed Macros
--------------------------------------------------------------------------------

--- Translate (live: interval)[body]
---@param args table Parsed arguments
---@param hook_content string|nil Hook content
---@return table AST node
function MacroAdvanced.translate_live(args, hook_content)
  if #args < 1 then
    return MacroAdvanced._error("live requires interval argument (e.g., 1s, 500ms)")
  end

  local interval_str = args[1].value
  if type(interval_str) ~= "string" then
    interval_str = tostring(interval_str)
  end

  local seconds = MacroAdvanced._parse_time_interval(interval_str)
  local body = hook_content and MacroAdvanced._parse_hook(hook_content) or {}

  return ASTBuilder.create_live_update(seconds, body)
end

--- Translate (event: when condition)[body]
---@param args table Parsed arguments
---@param hook_content string|nil Hook content
---@return table AST node
function MacroAdvanced.translate_event(args, hook_content)
  if #args < 1 then
    return MacroAdvanced._error("event requires: when condition")
  end

  -- Parse "when condition" pattern
  local expr = args[1].value
  if type(expr) ~= "string" then
    expr = tostring(expr)
  end

  local condition_str = expr:match("^when%s+(.+)$")

  if not condition_str then
    -- Check for separate when keyword and condition args
    if #args >= 2 and tostring(args[1].value):lower() == "when" then
      condition_str = args[2].value
    else
      return MacroAdvanced._error("event requires 'when' keyword")
    end
  end

  local condition = MacroCore._parse_condition_expression(condition_str)
  local body = hook_content and MacroAdvanced._parse_hook(hook_content) or {}

  return ASTBuilder.create_event_listener(condition, body)
end

--------------------------------------------------------------------------------
-- Data Structure Macros
--------------------------------------------------------------------------------

--- Translate (a: item1, item2, ...) - array creation
---@param args table Parsed arguments
---@param hook_content string|nil Hook content (unused for arrays)
---@return table AST node
function MacroAdvanced.translate_array(args, hook_content)
  local items = {}

  for _, arg in ipairs(args) do
    table.insert(items, MacroAdvanced._build_expression(arg))
  end

  return ASTBuilder.create_array_literal(items)
end

--- Translate (dm: key1, value1, key2, value2, ...)
---@param args table Parsed arguments
---@param hook_content string|nil Hook content (unused for datamaps)
---@return table AST node
function MacroAdvanced.translate_datamap(args, hook_content)
  if #args % 2 ~= 0 then
    return MacroAdvanced._error("dm requires even number of arguments (key-value pairs)")
  end

  local pairs = {}

  for i = 1, #args, 2 do
    local key = MacroAdvanced._get_string_value(args[i])
    local value = MacroAdvanced._build_expression(args[i + 1])

    table.insert(pairs, { key = key, value = value })
  end

  return ASTBuilder.create_table_literal(pairs)
end

--- Translate (ds: item1, item2, ...) - dataset (set) creation
---@param args table Parsed arguments
---@param hook_content string|nil Hook content (unused for datasets)
---@return table AST node
function MacroAdvanced.translate_dataset(args, hook_content)
  -- Datasets are similar to arrays but with unique values
  -- For now, treat as an array with a flag
  local items = {}

  for _, arg in ipairs(args) do
    table.insert(items, MacroAdvanced._build_expression(arg))
  end

  return {
    type = "dataset_literal",
    items = items,
    -- Note: runtime should enforce uniqueness
    unique = true
  }
end

--- Translate (range: start, end)
---@param args table Parsed arguments
---@param hook_content string|nil Hook content (unused)
---@return table AST node
function MacroAdvanced.translate_range(args, hook_content)
  if #args < 2 then
    return MacroAdvanced._error("range requires start and end arguments")
  end

  return {
    type = "range",
    start_value = MacroAdvanced._build_expression(args[1]),
    end_value = MacroAdvanced._build_expression(args[2])
  }
end

--------------------------------------------------------------------------------
-- Named Hook Macros
--------------------------------------------------------------------------------

--- Translate (replace: ?hookName)[new content]
---@param args table Parsed arguments
---@param hook_content string|nil Hook content
---@return table AST node
function MacroAdvanced.translate_replace(args, hook_content)
  if #args < 1 then
    return MacroAdvanced._error("replace requires hook name (?hookName)")
  end

  local hook_ref = tostring(args[1].value)
  local hook_name = MacroAdvanced._parse_hook_reference(hook_ref)
  local new_content = hook_content and MacroAdvanced._parse_hook(hook_content) or {}

  return ASTBuilder.create_hook_update("replace", hook_name, new_content)
end

--- Translate (append: ?hookName)[additional content]
---@param args table Parsed arguments
---@param hook_content string|nil Hook content
---@return table AST node
function MacroAdvanced.translate_append(args, hook_content)
  if #args < 1 then
    return MacroAdvanced._error("append requires hook name")
  end

  local hook_ref = tostring(args[1].value)
  local hook_name = MacroAdvanced._parse_hook_reference(hook_ref)
  local new_content = hook_content and MacroAdvanced._parse_hook(hook_content) or {}

  return ASTBuilder.create_hook_update("append", hook_name, new_content)
end

--- Translate (prepend: ?hookName)[content]
---@param args table Parsed arguments
---@param hook_content string|nil Hook content
---@return table AST node
function MacroAdvanced.translate_prepend(args, hook_content)
  if #args < 1 then
    return MacroAdvanced._error("prepend requires hook name")
  end

  local hook_ref = tostring(args[1].value)
  local hook_name = MacroAdvanced._parse_hook_reference(hook_ref)
  local new_content = hook_content and MacroAdvanced._parse_hook(hook_content) or {}

  return ASTBuilder.create_hook_update("prepend", hook_name, new_content)
end

--- Translate (show: ?hookName)
---@param args table Parsed arguments
---@param hook_content string|nil Hook content (unused)
---@return table AST node
function MacroAdvanced.translate_show(args, hook_content)
  if #args < 1 then
    return MacroAdvanced._error("show requires hook name")
  end

  local hook_ref = tostring(args[1].value)
  local hook_name = MacroAdvanced._parse_hook_reference(hook_ref)

  return {
    type = "hook_visibility",
    operation = "show",
    hook_name = hook_name
  }
end

--- Translate (hide: ?hookName)
---@param args table Parsed arguments
---@param hook_content string|nil Hook content (unused)
---@return table AST node
function MacroAdvanced.translate_hide(args, hook_content)
  if #args < 1 then
    return MacroAdvanced._error("hide requires hook name")
  end

  local hook_ref = tostring(args[1].value)
  local hook_name = MacroAdvanced._parse_hook_reference(hook_ref)

  return {
    type = "hook_visibility",
    operation = "hide",
    hook_name = hook_name
  }
end

--------------------------------------------------------------------------------
-- Random/Choice Macros
--------------------------------------------------------------------------------

--- Translate (either: ...$array) - random choice from array
---@param args table Parsed arguments
---@param hook_content string|nil Hook content (unused)
---@return table AST node
function MacroAdvanced.translate_either(args, hook_content)
  if #args < 1 then
    return MacroAdvanced._error("either requires at least one argument")
  end

  -- Check for spread syntax: ...$array
  local first_arg = tostring(args[1].value)
  local collection_name = first_arg:match("^%.%.%.%$([%w_]+)$")

  if collection_name then
    return ASTBuilder.create_random_choice(ASTBuilder.create_variable_ref(collection_name))
  end

  -- Otherwise, treat all args as individual choices
  local items = {}
  for _, arg in ipairs(args) do
    table.insert(items, MacroAdvanced._build_expression(arg))
  end

  return ASTBuilder.create_random_choice(ASTBuilder.create_array_literal(items))
end

--- Translate (random: min, max) - random number
---@param args table Parsed arguments
---@param hook_content string|nil Hook content (unused)
---@return table AST node
function MacroAdvanced.translate_random(args, hook_content)
  if #args < 2 then
    return MacroAdvanced._error("random requires min and max arguments")
  end

  return {
    type = "random_number",
    min = MacroAdvanced._build_expression(args[1]),
    max = MacroAdvanced._build_expression(args[2])
  }
end

--------------------------------------------------------------------------------
-- Possessive Syntax Parsing
--------------------------------------------------------------------------------

--- Parse possessive syntax: $array's 1st, $map's key
---@param expr string Expression with 's
---@return table|nil AST node or nil if not possessive
function MacroAdvanced.parse_possessive(expr)
  if type(expr) ~= "string" then
    return nil
  end

  local var_part, property = expr:match("^%$([%w_]+)'s%s+(.+)$")

  if not var_part then
    return nil
  end

  property = property:match("^%s*(.-)%s*$") -- trim

  -- Handle special properties
  if property == "length" then
    return ASTBuilder.create_length_of(ASTBuilder.create_variable_ref(var_part))
  elseif property == "keys" then
    return {
      type = "datamap_keys",
      target = ASTBuilder.create_variable_ref(var_part)
    }
  elseif property == "values" then
    return {
      type = "datamap_values",
      target = ASTBuilder.create_variable_ref(var_part)
    }
  elseif property == "last" then
    -- Last element of array
    return {
      type = "array_last",
      target = ASTBuilder.create_variable_ref(var_part)
    }
  elseif property:match("^%d+%a+$") then
    -- Ordinal access: 1st, 2nd, 3rd, 4th, etc.
    local index = MacroAdvanced._parse_ordinal(property)
    return ASTBuilder.create_array_access(
      ASTBuilder.create_variable_ref(var_part),
      ASTBuilder.create_literal("number", index - 1) -- Convert to 0-indexed
    )
  else
    -- Property access: $map's keyName
    return ASTBuilder.create_property_access(
      ASTBuilder.create_variable_ref(var_part),
      property
    )
  end
end

--- Parse ordinal (1st -> 1, 2nd -> 2, etc.)
---@param ordinal_str string Ordinal string like "1st", "2nd", "3rd"
---@return number The numeric value
function MacroAdvanced._parse_ordinal(ordinal_str)
  local num = ordinal_str:match("^(%d+)")
  return tonumber(num) or 1
end

--------------------------------------------------------------------------------
-- Enhanced Expression Parsing
--------------------------------------------------------------------------------

--- Enhanced expression parsing with possessive support
---@param expr string Expression to parse
---@return table AST node
function MacroAdvanced.parse_expression(expr)
  if type(expr) ~= "string" then
    return ASTBuilder.create_raw_expression(tostring(expr))
  end

  -- Check for possessive syntax
  if expr:match("%$[%w_]+'s") then
    local possessive = MacroAdvanced.parse_possessive(expr)
    if possessive then
      return possessive
    end
  end

  -- Fall back to core expression parsing
  return MacroCore._parse_expression(expr)
end

--------------------------------------------------------------------------------
-- Time Interval Parsing
--------------------------------------------------------------------------------

--- Parse time interval (e.g., "1s", "500ms")
---@param interval_str string Time interval string
---@return number Seconds
function MacroAdvanced._parse_time_interval(interval_str)
  local num, unit = interval_str:match("^(%d+%.?%d*)(%a+)$")

  if not num then
    return 1.0 -- Default to 1 second
  end

  num = tonumber(num)

  if unit == "s" then
    return num
  elseif unit == "ms" then
    return num / 1000
  elseif unit == "m" then
    return num * 60
  else
    return num -- Assume seconds
  end
end

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------

--- Parse hook reference (?hookName -> "hookName")
---@param ref_str string Hook reference with ? prefix
---@return string Hook name without prefix
function MacroAdvanced._parse_hook_reference(ref_str)
  return ref_str:match("^%?([%w_]+)$") or ref_str
end

--- Build expression from parsed argument
---@param arg table Parsed argument
---@return table AST node
function MacroAdvanced._build_expression(arg)
  if arg.type == "number" then
    return ASTBuilder.create_literal("number", arg.value)
  elseif arg.type == "string" then
    return ASTBuilder.create_literal("string", arg.value)
  elseif arg.type == "boolean" then
    return ASTBuilder.create_literal("boolean", arg.value)
  elseif arg.type == "variable" then
    return ASTBuilder.create_variable_ref(arg.value)
  elseif arg.type == "expression" then
    return MacroAdvanced.parse_expression(arg.value)
  else
    return ASTBuilder.create_literal("nil", nil)
  end
end

--- Parse hook content
---@param content string Hook content
---@return table[] Array of AST nodes
function MacroAdvanced._parse_hook(content)
  -- Simplified: return as text
  -- Full implementation would recursively parse
  return { ASTBuilder.create_text(content) }
end

--- Get string value from argument
---@param arg table Parsed argument
---@return string String value
function MacroAdvanced._get_string_value(arg)
  if arg.type == "string" then
    return arg.value
  else
    return tostring(arg.value)
  end
end

--- Create error node
---@param message string Error message
---@return table Error AST node
function MacroAdvanced._error(message)
  return ASTBuilder.create_error(message)
end

return MacroAdvanced
