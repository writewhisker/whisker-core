--- JavaScript to Lua translator for Snowman templates
-- Focused on Snowman-specific patterns (s object, story API)
--
-- lib/whisker/twine/formats/snowman/js_translator.lua

local JSTranslator = {}

local ASTBuilder = require('whisker.twine.ast_builder')

--------------------------------------------------------------------------------
-- Block Translation
--------------------------------------------------------------------------------

--- Translate JavaScript code block to Lua
---@param js_code string JavaScript code
---@return string|nil, table Lua code and warnings, or nil if untranslatable
function JSTranslator.translate_block(js_code)
  if not js_code or js_code == "" then
    return nil, { "Empty JavaScript block" }
  end

  local warnings = {}
  local lua_lines = {}

  -- Split into lines
  for line in js_code:gmatch("[^\n]+") do
    local lua_line, warning = JSTranslator._translate_line(line)

    if lua_line then
      table.insert(lua_lines, lua_line)
    end

    if warning then
      table.insert(warnings, warning)
    end
  end

  if #lua_lines > 0 then
    return table.concat(lua_lines, "\n"), warnings
  else
    return nil, warnings
  end
end

--------------------------------------------------------------------------------
-- Expression Translation
--------------------------------------------------------------------------------

--- Translate JavaScript expression to Lua
---@param js_expr string JavaScript expression
---@return string|nil, table Lua expression and warnings
function JSTranslator.translate_expression(js_expr)
  if not js_expr then
    return nil, { "Empty expression" }
  end

  local warnings = {}
  js_expr = js_expr:match("^%s*(.-)%s*$") -- Trim

  -- String literal
  if js_expr:match('^".*"$') or js_expr:match("^'.*'$") then
    return js_expr, warnings
  end

  -- Number
  if js_expr:match("^%-?%d+%.?%d*$") then
    return js_expr, warnings
  end

  -- Boolean
  if js_expr == "true" or js_expr == "false" then
    return js_expr, warnings
  end

  -- passage.name, passage.visits
  if js_expr == "passage.name" then
    return "current_passage_name", warnings
  end
  if js_expr == "passage.visits" then
    return "current_passage_visits", warnings
  end

  -- Array access: s.items[0] (check BEFORE general s. access)
  local arr, index = js_expr:match("^s%.([%w_]+)%[(%d+)%]$")
  if arr and index then
    -- Lua is 1-indexed, JavaScript is 0-indexed
    local lua_index = tonumber(index) + 1
    table.insert(warnings, "Converted 0-indexed array access to 1-indexed")
    return arr .. "[" .. lua_index .. "]", warnings
  end

  -- s.variable -> variable (simple variable, no dots after)
  local var_name = js_expr:match("^s%.([%w_]+)$")
  if var_name then
    table.insert(warnings, "Translated s." .. var_name .. " to variable " .. var_name)
    return var_name, warnings
  end

  -- s.obj.prop -> obj.prop (property chain)
  local obj_access = js_expr:match("^s%.(.+)$")
  if obj_access then
    table.insert(warnings, "Translated s." .. obj_access .. " to " .. obj_access)
    return obj_access, warnings
  end

  -- Unable to translate
  return nil, { "Unable to translate expression: " .. js_expr }
end

--------------------------------------------------------------------------------
-- Line Translation
--------------------------------------------------------------------------------

--- Translate single JavaScript line to Lua
---@param line string JavaScript line
---@return string|nil, string|nil Lua line and warning
function JSTranslator._translate_line(line)
  line = line:match("^%s*(.-)%s*$") -- Trim

  -- Empty lines
  if line == "" then
    return "", nil
  end

  -- Comments
  if line:match("^//") then
    return "-- " .. line:sub(3), nil
  end
  if line:match("^/%*") or line:match("^%*") or line:match("^%*/") then
    return "-- " .. line, nil
  end

  -- Initialization: s.variable = s.variable || defaultValue (check BEFORE general assignment)
  local var_name, value = line:match("^s%.([%w_]+)%s*=%s*s%.%1%s*||%s*(.-)%s*;?$")

  if var_name and value then
    -- Translate to: variable = variable or defaultValue
    local lua_value = JSTranslator.translate_expression(value)
    return var_name .. " = " .. var_name .. " or " .. (lua_value or value), nil
  end

  -- Variable assignment: s.variable = value;
  var_name, value = line:match("^s%.([%w_]+)%s*=%s*(.-)%s*;?$")

  if var_name and value then
    -- Translate value
    local lua_value = JSTranslator.translate_expression(value)
    if lua_value then
      return var_name .. " = " .. lua_value, nil
    else
      return var_name .. " = " .. value, "Unable to fully translate value"
    end
  end

  -- Compound assignment: s.variable += value;
  var_name, value = line:match("^s%.([%w_]+)%s*%+=%s*(.-)%s*;?$")
  if var_name and value then
    local lua_value = JSTranslator.translate_expression(value) or value
    return var_name .. " = " .. var_name .. " + " .. lua_value, nil
  end

  -- Compound assignment: s.variable -= value;
  var_name, value = line:match("^s%.([%w_]+)%s*%-=%s*(.-)%s*;?$")
  if var_name and value then
    local lua_value = JSTranslator.translate_expression(value) or value
    return var_name .. " = " .. var_name .. " - " .. lua_value, nil
  end

  -- If statement: if (condition) {
  local condition = line:match("^if%s*%((.-)%)%s*{?$")

  if condition then
    local lua_cond = JSTranslator._translate_condition(condition)
    return "if " .. lua_cond .. " then", nil
  end

  -- Else if: } else if (condition) {
  condition = line:match("^}?%s*else%s+if%s*%((.-)%)%s*{?$")
  if condition then
    local lua_cond = JSTranslator._translate_condition(condition)
    return "elseif " .. lua_cond .. " then", nil
  end

  -- Else: } else {
  if line:match("^}?%s*else%s*{?$") then
    return "else", nil
  end

  -- Closing brace
  if line == "}" or line == "};" then
    return "end", nil
  end

  -- window.story.show('PassageName')
  local quote, passage_name = line:match("^window%.story%.show%s*%((['\"])(.-)%1%)%s*;?$")

  if passage_name then
    return 'goto("' .. passage_name .. '")', nil
  end

  -- story.show('PassageName') - without window prefix
  quote, passage_name = line:match("^story%.show%s*%((['\"])(.-)%1%)%s*;?$")

  if passage_name then
    return 'goto("' .. passage_name .. '")', nil
  end

  -- Unable to translate
  return nil, "Unable to translate line: " .. line
end

--------------------------------------------------------------------------------
-- Condition Translation
--------------------------------------------------------------------------------

--- Translate JavaScript condition to Lua
---@param js_cond string JavaScript condition
---@return string Lua condition
function JSTranslator._translate_condition(js_cond)
  local lua_cond = js_cond

  -- Replace s.variable with variable
  lua_cond = lua_cond:gsub("s%.([%w_]+)", "%1")

  -- Replace === with ==
  lua_cond = lua_cond:gsub("===", "==")
  lua_cond = lua_cond:gsub("!==", "~=")
  lua_cond = lua_cond:gsub("!=", "~=")

  -- Replace && with and
  lua_cond = lua_cond:gsub("&&", " and ")

  -- Replace || with or
  lua_cond = lua_cond:gsub("||", " or ")

  -- Replace ! with not (but not !=)
  lua_cond = lua_cond:gsub("!([%w_%(])", "not %1")

  return lua_cond
end

return JSTranslator
