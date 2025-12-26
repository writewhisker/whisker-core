--- Macro Parser
-- Parse and validate Harlowe/SugarCube macros
-- @module whisker.format.parsers.macro_parser
-- @author Whisker Core Team
-- @license MIT

local M = {}
M._dependencies = {}

-- Macro definitions for validation
M.HARLOWE_MACROS = {
  set = {args = {"variable", "value"}, category = "data"},
  put = {args = {"value", "variable"}, category = "data"},
  ["if"] = {args = {"condition"}, has_hook = true, category = "control"},
  unless = {args = {"condition"}, has_hook = true, category = "control"},
  ["else"] = {args = {}, category = "control"},
  ["elseif"] = {args = {"condition"}, category = "control"},
  ["for"] = {args = {"variable", "collection"}, has_hook = true, category = "control"},
  print = {args = {"expression"}, category = "output"},
  display = {args = {"passage_name"}, category = "output"},
  link = {args = {"text", "passage?"}, has_hook = true, category = "link"},
  ["link-goto"] = {args = {"text", "passage"}, category = "link"},
  ["link-reveal"] = {args = {"text"}, has_hook = true, category = "link"},
  ["link-repeat"] = {args = {"text"}, has_hook = true, category = "link"},
  live = {args = {"duration"}, has_hook = true, category = "timing"},
  stop = {args = {}, category = "timing"},
  ["goto"] = {args = {"passage"}, category = "navigation"},
  undo = {args = {}, category = "navigation"},
  a = {args = {"...values"}, category = "data", returns = "array"},
  dm = {args = {"...pairs"}, category = "data", returns = "datamap"},
  ds = {args = {"...values"}, category = "data", returns = "dataset"},
  enchant = {args = {"selector", "changer"}, category = "dom"},
  click = {args = {"selector"}, has_hook = true, category = "event"},
  mouseover = {args = {"selector"}, has_hook = true, category = "event"},
  css = {args = {"property", "value"}, category = "style", returns = "changer"},
  ["text-style"] = {args = {"style"}, category = "style", returns = "changer"},
}

M.SUGARCUBE_MACROS = {
  set = {args = {"expression"}, category = "data"},
  unset = {args = {"variable"}, category = "data"},
  run = {args = {"expression"}, category = "data"},
  ["if"] = {args = {"condition"}, has_close = true, category = "control"},
  ["elseif"] = {args = {"condition"}, category = "control"},
  ["else"] = {args = {}, category = "control"},
  ["for"] = {args = {"...args"}, has_close = true, category = "control"},
  ["break"] = {args = {}, category = "control"},
  ["continue"] = {args = {}, category = "control"},
  switch = {args = {"value"}, has_close = true, category = "control"},
  case = {args = {"...values"}, category = "control"},
  default = {args = {}, category = "control"},
  print = {args = {"expression"}, category = "output"},
  link = {args = {"text", "passage?", "setter?"}, category = "link"},
  ["link-append"] = {args = {"text", "setter?"}, has_close = true, category = "link"},
  ["link-prepend"] = {args = {"text", "setter?"}, has_close = true, category = "link"},
  ["link-replace"] = {args = {"text", "setter?"}, has_close = true, category = "link"},
  ["goto"] = {args = {"passage"}, category = "navigation"},
  include = {args = {"passage"}, category = "navigation"},
  widget = {args = {"name"}, has_close = true, category = "widget"},
  script = {args = {}, has_close = true, category = "code"},
  timed = {args = {"delay"}, has_close = true, category = "timing"},
  ["repeat"] = {args = {"delay"}, has_close = true, category = "timing"},
  stop = {args = {}, category = "timing"},
}

--- Extract macros from Harlowe content
-- @param content string Passage content
-- @return table Array of macro instances
function M.extract_harlowe_macros(content)
  local macros = {}

  -- Pattern for (macro-name: args)
  for full, name, args in content:gmatch("(%(([%w%-]+):%s*([^%)]*)%))") do
    table.insert(macros, {
      raw = full,
      name = name:lower(),
      args_raw = args,
      args = M.parse_args(args),
      position = content:find(full, 1, true),
    })
  end

  -- Pattern for (macro-name) without args
  for full, name in content:gmatch("(%(([%w%-]+)%))")  do
    if not full:match(":") then
      table.insert(macros, {
        raw = full,
        name = name:lower(),
        args_raw = "",
        args = {},
        position = content:find(full, 1, true),
      })
    end
  end

  return macros
end

--- Extract macros from SugarCube content
-- @param content string Passage content
-- @return table Array of macro instances
function M.extract_sugarcube_macros(content)
  local macros = {}

  -- Pattern for <<macro-name args>>
  for full, name, args in content:gmatch("(<<([%w%-]+)%s*(.-)>>)") do
    table.insert(macros, {
      raw = full,
      name = name:lower(),
      args_raw = args,
      args = M.parse_args(args),
      position = content:find(full, 1, true),
    })
  end

  -- Pattern for <</macro-name>> (closing tags)
  for full, name in content:gmatch("(<</([%w%-]+)>>)") do
    table.insert(macros, {
      raw = full,
      name = "/" .. name:lower(),
      args_raw = "",
      args = {},
      position = content:find(full, 1, true),
      is_close = true,
    })
  end

  return macros
end

--- Parse macro arguments
-- @param args_str string Raw argument string
-- @return table Array of parsed arguments
function M.parse_args(args_str)
  local args = {}
  local depth = 0
  local current = ""
  local in_string = false
  local string_char = nil

  for i = 1, #args_str do
    local c = args_str:sub(i, i)

    if not in_string then
      if c == '"' or c == "'" then
        in_string = true
        string_char = c
        current = current .. c
      elseif c == "(" or c == "[" or c == "{" then
        depth = depth + 1
        current = current .. c
      elseif c == ")" or c == "]" or c == "}" then
        depth = depth - 1
        current = current .. c
      elseif c == "," and depth == 0 then
        local trimmed = current:match("^%s*(.-)%s*$")
        if trimmed ~= "" then
          table.insert(args, trimmed)
        end
        current = ""
      else
        current = current .. c
      end
    else
      current = current .. c
      if c == string_char and args_str:sub(i-1, i-1) ~= "\\" then
        in_string = false
        string_char = nil
      end
    end
  end

  local trimmed = current:match("^%s*(.-)%s*$")
  if trimmed ~= "" then
    table.insert(args, trimmed)
  end

  return args
end

--- Validate Harlowe macro usage
-- @param macro table Parsed macro
-- @return boolean, string Valid and error message
function M.validate_harlowe_macro(macro)
  local def = M.HARLOWE_MACROS[macro.name]

  if not def then
    return true, nil  -- Unknown macros are allowed (might be custom)
  end

  -- Check required args (those without ?)
  local required = 0
  for _, arg in ipairs(def.args) do
    if not arg:match("%?$") and not arg:match("^%.%.%.") then
      required = required + 1
    end
  end

  if #macro.args < required then
    return false, string.format(
      "Macro '%s' requires at least %d argument(s), got %d",
      macro.name, required, #macro.args
    )
  end

  return true, nil
end

--- Validate SugarCube macro usage
-- @param macro table Parsed macro
-- @return boolean, string Valid and error message
function M.validate_sugarcube_macro(macro)
  -- Skip closing tags
  if macro.is_close then
    return true, nil
  end

  local def = M.SUGARCUBE_MACROS[macro.name]

  if not def then
    return true, nil  -- Unknown macros are allowed (might be custom/widgets)
  end

  -- Check required args (those without ?)
  local required = 0
  for _, arg in ipairs(def.args) do
    if not arg:match("%?$") and not arg:match("^%.%.%.") then
      required = required + 1
    end
  end

  if #macro.args < required then
    return false, string.format(
      "Macro '%s' requires at least %d argument(s), got %d",
      macro.name, required, #macro.args
    )
  end

  return true, nil
end

--- Extract all macros with validation for Harlowe
-- @param content string Passage content
-- @return table Macros with validation results
function M.analyze_harlowe(content)
  local macros = M.extract_harlowe_macros(content)
  local results = {
    macros = macros,
    errors = {},
    warnings = {},
    stats = {
      total = #macros,
      by_category = {},
    }
  }

  for _, macro in ipairs(macros) do
    local valid, err = M.validate_harlowe_macro(macro)
    if not valid then
      table.insert(results.errors, {
        macro = macro.name,
        position = macro.position,
        message = err
      })
    end

    -- Track stats
    local def = M.HARLOWE_MACROS[macro.name]
    if def then
      local cat = def.category
      results.stats.by_category[cat] = (results.stats.by_category[cat] or 0) + 1
    end
  end

  return results
end

--- Extract all macros with validation for SugarCube
-- @param content string Passage content
-- @return table Macros with validation results
function M.analyze_sugarcube(content)
  local macros = M.extract_sugarcube_macros(content)
  local results = {
    macros = macros,
    errors = {},
    warnings = {},
    stats = {
      total = #macros,
      by_category = {},
    }
  }

  for _, macro in ipairs(macros) do
    local valid, err = M.validate_sugarcube_macro(macro)
    if not valid then
      table.insert(results.errors, {
        macro = macro.name,
        position = macro.position,
        message = err
      })
    end

    -- Track stats
    local def = M.SUGARCUBE_MACROS[macro.name]
    if def and not macro.is_close then
      local cat = def.category
      results.stats.by_category[cat] = (results.stats.by_category[cat] or 0) + 1
    end
  end

  return results
end

return M
