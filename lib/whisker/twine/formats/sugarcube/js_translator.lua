--- JavaScript to Lua translator for SugarCube <<script>> blocks
-- Handles common patterns, generates warnings for unsupported features
--
-- lib/whisker/twine/formats/sugarcube/js_translator.lua

local JSTranslator = {}

--------------------------------------------------------------------------------
-- Block Translation
--------------------------------------------------------------------------------

--- Translate JavaScript block to Lua
---@param js_code string JavaScript code block
---@return string|nil, table Lua code and warnings array
function JSTranslator.translate_block(js_code)
  if not js_code or js_code == "" then
    return nil, { "Empty JavaScript block" }
  end

  local warnings = {}
  local lua_lines = {}

  -- Split by lines
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

  -- State.variables.$var -> variable name
  local var_name = js_expr:match("State%.variables%.([%w_]+)")
  if var_name then
    table.insert(warnings, "Translated State.variables to whisker variable")
    return var_name, warnings
  end

  -- Math.random() -> math.random()
  if js_expr:find("Math%.random%(%)") then
    local translated = js_expr:gsub("Math%.random%(%)", "math.random()")
    table.insert(warnings, "Translated Math.random to Lua math.random")
    return translated, warnings
  end

  -- Math.floor(x) -> math.floor(x)
  if js_expr:find("Math%.floor") then
    local translated = js_expr:gsub("Math%.floor", "math.floor")
    table.insert(warnings, "Translated Math.floor to Lua")
    return translated, warnings
  end

  -- Math.ceil(x) -> math.ceil(x)
  if js_expr:find("Math%.ceil") then
    local translated = js_expr:gsub("Math%.ceil", "math.ceil")
    table.insert(warnings, "Translated Math.ceil to Lua")
    return translated, warnings
  end

  -- Math.round(x) -> math.floor(x + 0.5)
  if js_expr:find("Math%.round") then
    local translated = js_expr:gsub("Math%.round%((.-)%)", "math.floor(%1 + 0.5)")
    table.insert(warnings, "Translated Math.round to Lua math.floor")
    return translated, warnings
  end

  -- Math.abs(x) -> math.abs(x)
  if js_expr:find("Math%.abs") then
    local translated = js_expr:gsub("Math%.abs", "math.abs")
    table.insert(warnings, "Translated Math.abs to Lua")
    return translated, warnings
  end

  -- Math.min/max
  if js_expr:find("Math%.min") then
    local translated = js_expr:gsub("Math%.min", "math.min")
    table.insert(warnings, "Translated Math.min to Lua")
    return translated, warnings
  end
  if js_expr:find("Math%.max") then
    local translated = js_expr:gsub("Math%.max", "math.max")
    table.insert(warnings, "Translated Math.max to Lua")
    return translated, warnings
  end

  -- Simple values pass through
  if js_expr:match("^%-?%d+%.?%d*$") then
    return js_expr, warnings
  end
  if js_expr:match("^['\"].*['\"]$") then
    return js_expr, warnings
  end
  if js_expr == "true" or js_expr == "false" then
    return js_expr, warnings
  end

  -- $variable -> variable
  local var = js_expr:match("^%$([%w_]+)$")
  if var then
    return var, warnings
  end

  return nil, { "Unable to translate JavaScript expression: " .. js_expr }
end

--------------------------------------------------------------------------------
-- Line Translation
--------------------------------------------------------------------------------

--- Translate single JavaScript line to Lua
---@param line string JavaScript line
---@return string|nil, string|nil Lua line and warning
function JSTranslator._translate_line(line)
  line = line:match("^%s*(.-)%s*$") -- Trim

  -- Empty lines and comments
  if line == "" then
    return "", nil
  end
  if line:match("^//") then
    return "-- " .. line:sub(3), nil
  end
  if line:match("^/%*") or line:match("^%*") or line:match("^%*/") then
    return "-- " .. line, nil
  end

  -- Variable declaration: var x = value;
  local var_name, value = line:match("^var%s+([%w_]+)%s*=%s*(.-)%s*;?$")
  if var_name and value then
    local lua_value, _ = JSTranslator.translate_expression(value)
    return "local " .. var_name .. " = " .. (lua_value or value), nil
  end

  -- Let/const declaration: let x = value;
  var_name, value = line:match("^let%s+([%w_]+)%s*=%s*(.-)%s*;?$")
  if var_name and value then
    local lua_value, _ = JSTranslator.translate_expression(value)
    return "local " .. var_name .. " = " .. (lua_value or value), nil
  end
  var_name, value = line:match("^const%s+([%w_]+)%s*=%s*(.-)%s*;?$")
  if var_name and value then
    local lua_value, _ = JSTranslator.translate_expression(value)
    return "local " .. var_name .. " = " .. (lua_value or value), nil
  end

  -- State.variables.$x = value;
  var_name, value = line:match("^State%.variables%.([%w_]+)%s*=%s*(.-)%s*;?$")
  if var_name and value then
    local lua_value = JSTranslator.translate_expression(value) or value
    return var_name .. " = " .. lua_value, nil
  end

  -- State.variables.$x += value;
  var_name, value = line:match("^State%.variables%.([%w_]+)%s*%+=%s*(.-)%s*;?$")
  if var_name and value then
    local lua_value = JSTranslator.translate_expression(value) or value
    return var_name .. " = " .. var_name .. " + " .. lua_value, nil
  end

  -- State.variables.$x -= value;
  var_name, value = line:match("^State%.variables%.([%w_]+)%s*%-=%s*(.-)%s*;?$")
  if var_name and value then
    local lua_value = JSTranslator.translate_expression(value) or value
    return var_name .. " = " .. var_name .. " - " .. lua_value, nil
  end

  -- $x = value; (SugarCube shorthand)
  var_name, value = line:match("^%$([%w_]+)%s*=%s*(.-)%s*;?$")
  if var_name and value then
    local lua_value = JSTranslator.translate_expression(value) or value
    return var_name .. " = " .. lua_value, nil
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
  if line == "}" then
    return "end", nil
  end
  if line == "};" then
    return "end", nil
  end

  -- Return statement
  value = line:match("^return%s+(.-)%s*;?$")
  if value then
    local lua_value = JSTranslator.translate_expression(value) or value
    return "return " .. lua_value, nil
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

  -- Replace State.variables.$x with x
  lua_cond = lua_cond:gsub("State%.variables%.([%w_]+)", "%1")

  -- Replace $x with x
  lua_cond = lua_cond:gsub("%$([%w_]+)", "%1")

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
