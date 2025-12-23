--- SugarCube advanced macro translation
-- Implements: widget, script, run, for, switch, nobr, print, timed
--
-- lib/whisker/twine/formats/sugarcube/macro_advanced.lua

local MacroAdvanced = {}

local ASTBuilder = require('whisker.twine.ast_builder')
local ExprParser = require('whisker.twine.formats.sugarcube.expression_parser')
local JSTranslator = require('whisker.twine.formats.sugarcube.js_translator')

--------------------------------------------------------------------------------
-- Registration
--------------------------------------------------------------------------------

--- Register advanced translators in the translators table
---@param translators table Translator table to extend
function MacroAdvanced.register_translators(translators)
  translators["widget"] = MacroAdvanced.translate_widget
  translators["script"] = MacroAdvanced.translate_script
  translators["run"] = MacroAdvanced.translate_run
  translators["for"] = MacroAdvanced.translate_for
  translators["switch"] = MacroAdvanced.translate_switch
  translators["nobr"] = MacroAdvanced.translate_nobr
  translators["-"] = MacroAdvanced.translate_print_shorthand
  translators["="] = MacroAdvanced.translate_print_encoded
  translators["timed"] = MacroAdvanced.translate_timed
  translators["repeat"] = MacroAdvanced.translate_repeat
  translators["stop"] = MacroAdvanced.translate_stop
  translators["capture"] = MacroAdvanced.translate_capture
  translators["type"] = MacroAdvanced.translate_type
end

--------------------------------------------------------------------------------
-- Widget Macro
--------------------------------------------------------------------------------

--- Translate <<widget "name">> body <</widget>>
---@param args table Macro arguments
---@param body string|nil Macro body
---@param handler table Handler for recursive parsing
---@return table AST node
function MacroAdvanced.translate_widget(args, body, handler)
  if #args < 1 then
    return ASTBuilder.create_error("widget macro requires name argument")
  end

  local widget_name = args[1].value or args[1]

  -- Parse widget body
  local widget_body = {}
  if body and body ~= "" and handler then
    widget_body = handler:_parse_body_content(body)
  end

  return {
    type = "widget_definition",
    name = widget_name,
    body = widget_body,
    note = "Widget definitions should be in passages tagged 'widget'"
  }
end

--------------------------------------------------------------------------------
-- Script Macros
--------------------------------------------------------------------------------

--- Translate <<script>> JavaScript code <</script>>
---@param args table Macro arguments
---@param body string|nil Macro body (JavaScript code)
---@param handler table Handler for recursive parsing
---@return table AST node
function MacroAdvanced.translate_script(args, body, handler)
  if not body or body == "" then
    return ASTBuilder.create_error("script macro requires code body")
  end

  -- Attempt to translate JavaScript to Lua
  local lua_code, warnings = JSTranslator.translate_block(body)

  if lua_code then
    return {
      type = "script_block",
      language = "lua",
      code = lua_code,
      warnings = warnings,
      original_js = body
    }
  else
    return {
      type = "warning",
      message = "Unable to translate JavaScript code block to Lua",
      original_js = body,
      suggestion = "Consider rewriting as <<set>> or WhiskerScript",
      warnings = warnings
    }
  end
end

--- Translate <<run expression>>
---@param args table Macro arguments
---@param body string|nil Macro body (unused)
---@param handler table Handler for recursive parsing
---@return table AST node
function MacroAdvanced.translate_run(args, body, handler)
  if #args < 1 then
    return ASTBuilder.create_error("run macro requires expression")
  end

  local js_expr = args[1].value or args[1]

  -- Attempt to translate JavaScript expression
  local lua_expr, warnings = JSTranslator.translate_expression(js_expr)

  if lua_expr then
    return {
      type = "run_expression",
      expression = lua_expr,
      warnings = warnings,
      original_js = js_expr
    }
  else
    return {
      type = "warning",
      message = "Unable to translate JavaScript expression",
      original_js = js_expr,
      warnings = warnings
    }
  end
end

--------------------------------------------------------------------------------
-- For Loop Macro
--------------------------------------------------------------------------------

--- Translate <<for>> loops (multiple syntax forms)
---@param args table Macro arguments
---@param body string|nil Loop body
---@param handler table Handler for recursive parsing
---@return table AST node
function MacroAdvanced.translate_for(args, body, handler)
  if #args < 1 then
    return ASTBuilder.create_error("for macro requires loop specification")
  end

  local loop_spec = args[1].value or args[1]

  -- Parse loop type
  local loop_ast = MacroAdvanced._parse_for_loop(loop_spec, body, handler)

  if loop_ast then
    return loop_ast
  else
    return ASTBuilder.create_error("Invalid for loop syntax: " .. tostring(loop_spec))
  end
end

--- Parse for loop specification
---@param spec string Loop specification
---@param body string|nil Loop body
---@param handler table Handler for recursive parsing
---@return table|nil AST node
function MacroAdvanced._parse_for_loop(spec, body, handler)
  -- C-style: $i = 0; $i < 10; $i++
  local init, condition, increment = spec:match("^(.-)%s*;%s*(.-)%s*;%s*(.-)$")

  if init and condition and increment then
    return MacroAdvanced._translate_c_style_for(init, condition, increment, body, handler)
  end

  -- Range loop with key/value: $key, $value range $object
  local key_var, value_var, collection = spec:match("^%$([%w_]+)%s*,%s*%$([%w_]+)%s+range%s+(.+)$")
  if key_var and value_var and collection then
    return MacroAdvanced._translate_pairs_for(key_var, value_var, collection, body, handler)
  end

  -- Range loop: $item range $collection
  local item_var, collection2 = spec:match("^%$([%w_]+)%s+range%s+(.+)$")
  if item_var and collection2 then
    return MacroAdvanced._translate_range_for(item_var, collection2, body, handler)
  end

  -- Temporary variable range: _item range $collection
  item_var, collection2 = spec:match("^_([%w_]+)%s+range%s+(.+)$")
  if item_var and collection2 then
    return MacroAdvanced._translate_range_for(item_var, collection2, body, handler)
  end

  return nil
end

--- Translate C-style for loop
---@param init string Initialization
---@param condition string Condition
---@param increment string Increment
---@param body string Loop body
---@param handler table Handler
---@return table AST node
function MacroAdvanced._translate_c_style_for(init, condition, increment, body, handler)
  -- Parse init: $i = 0 or $i to 0
  local var_name = init:match("^%$([%w_]+)%s*[=to]+%s*")
  local start_value = init:match("[=to]+%s*(.+)$")

  if not var_name or not start_value then
    return ASTBuilder.create_error("Invalid for loop init: " .. init)
  end

  -- Parse condition: $i < 10
  local end_value = condition:match("%$" .. var_name .. "%s*<%s*(.+)$")
  if not end_value then
    -- Try <= for inclusive
    end_value = condition:match("%$" .. var_name .. "%s*<=%s*(.+)$")
    if end_value then
      -- Adjust for inclusive range
      end_value = "(" .. end_value .. ") + 1"
    end
  end

  if not end_value then
    return ASTBuilder.create_error("Invalid for loop condition: " .. condition)
  end

  -- Parse body
  local loop_body = {}
  if body and handler then
    loop_body = handler:_parse_body_content(body)
  end

  return {
    type = "for_range",
    variable = var_name,
    start_value = ExprParser.parse(start_value),
    end_value = ExprParser.parse(end_value),
    body = loop_body
  }
end

--- Translate range-based for loop
---@param item_var string Loop variable name
---@param collection string Collection expression
---@param body string Loop body
---@param handler table Handler
---@return table AST node
function MacroAdvanced._translate_range_for(item_var, collection, body, handler)
  local collection_ast = ExprParser.parse(collection)
  local loop_body = {}
  if body and handler then
    loop_body = handler:_parse_body_content(body)
  end

  return ASTBuilder.create_for_loop(item_var, collection_ast, loop_body)
end

--- Translate pairs iteration for loop
---@param key_var string Key variable name
---@param value_var string Value variable name
---@param collection string Collection expression
---@param body string Loop body
---@param handler table Handler
---@return table AST node
function MacroAdvanced._translate_pairs_for(key_var, value_var, collection, body, handler)
  local collection_ast = ExprParser.parse(collection)
  local loop_body = {}
  if body and handler then
    loop_body = handler:_parse_body_content(body)
  end

  return {
    type = "for_pairs",
    key_variable = key_var,
    value_variable = value_var,
    collection = collection_ast,
    body = loop_body
  }
end

--------------------------------------------------------------------------------
-- Switch/Case Macro
--------------------------------------------------------------------------------

--- Translate <<switch $var>> <<case>> <<default>> <</switch>>
---@param args table Macro arguments
---@param body string|nil Switch body
---@param handler table Handler for recursive parsing
---@return table AST node
function MacroAdvanced.translate_switch(args, body, handler)
  if #args < 1 then
    return ASTBuilder.create_error("switch macro requires variable/expression")
  end

  local switch_expr = ExprParser.parse(args[1].value or args[1])

  -- Parse cases from body
  local cases, default_case = MacroAdvanced._parse_switch_body(body, handler)

  return {
    type = "switch",
    expression = switch_expr,
    cases = cases,
    default_case = default_case
  }
end

--- Parse switch body to extract cases
---@param body string Switch body
---@param handler table Handler for parsing
---@return table, table|nil Cases and default case
function MacroAdvanced._parse_switch_body(body, handler)
  if not body or body == "" then
    return {}, nil
  end

  local cases = {}
  local default_case = nil
  local current_values = nil
  local current_content = ""

  local pos = 1
  while pos <= #body do
    -- Check for <<case values>>
    if body:sub(pos, pos + 6) == "<<case " then
      -- Save previous case
      if current_values then
        local case_body = {}
        if handler and current_content ~= "" then
          case_body = handler:_parse_body_content(current_content)
        end
        table.insert(cases, {
          values = current_values,
          body = case_body
        })
      end

      -- Parse case values
      local close_pos = body:find(">>", pos + 6)
      if close_pos then
        local case_args = body:sub(pos + 7, close_pos - 1)

        -- Split multiple case values by space (quoted strings stay together)
        current_values = MacroAdvanced._parse_case_values(case_args)
        current_content = ""
        pos = close_pos + 2
      else
        pos = pos + 1
      end
    elseif body:sub(pos, pos + 10) == "<<default>>" then
      -- Save previous case
      if current_values then
        local case_body = {}
        if handler and current_content ~= "" then
          case_body = handler:_parse_body_content(current_content)
        end
        table.insert(cases, {
          values = current_values,
          body = case_body
        })
        current_values = nil
      end

      current_content = ""
      pos = pos + 11

      -- Everything after default is the default case
      local remaining = body:sub(pos)
      if handler and remaining ~= "" then
        default_case = handler:_parse_body_content(remaining)
      end
      break
    else
      current_content = current_content .. body:sub(pos, pos)
      pos = pos + 1
    end
  end

  -- Save final case if not default
  if current_values then
    local case_body = {}
    if handler and current_content ~= "" then
      case_body = handler:_parse_body_content(current_content)
    end
    table.insert(cases, {
      values = current_values,
      body = case_body
    })
  end

  return cases, default_case
end

--- Parse case values (handles quoted strings and multiple values)
---@param args_str string Case arguments
---@return table Array of AST nodes
function MacroAdvanced._parse_case_values(args_str)
  local values = {}
  local current = ""
  local in_string = false
  local string_char = nil

  for i = 1, #args_str do
    local char = args_str:sub(i, i)

    if (char == '"' or char == "'") and not in_string then
      in_string = true
      string_char = char
      current = current .. char
    elseif char == string_char and in_string then
      in_string = false
      string_char = nil
      current = current .. char
    elseif char == " " and not in_string then
      local trimmed = current:match("^%s*(.-)%s*$")
      if trimmed ~= "" then
        table.insert(values, ExprParser.parse(trimmed))
      end
      current = ""
    else
      current = current .. char
    end
  end

  -- Final value
  local trimmed = current:match("^%s*(.-)%s*$")
  if trimmed ~= "" then
    table.insert(values, ExprParser.parse(trimmed))
  end

  return values
end

--------------------------------------------------------------------------------
-- Whitespace Control
--------------------------------------------------------------------------------

--- Translate <<nobr>> content <</nobr>>
---@param args table Macro arguments
---@param body string|nil Content body
---@param handler table Handler for recursive parsing
---@return table AST node
function MacroAdvanced.translate_nobr(args, body, handler)
  if not body then
    return { type = "noop" }
  end

  -- Remove line breaks from body
  local stripped = body:gsub("\n", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")

  -- Parse stripped content
  local content_body = {}
  if handler and stripped ~= "" then
    content_body = handler:_parse_body_content(stripped)
  end

  return {
    type = "nobr_block",
    body = content_body
  }
end

--------------------------------------------------------------------------------
-- Output Macros
--------------------------------------------------------------------------------

--- Translate <<- $var>> (shorthand for print)
---@param args table Macro arguments
---@param body string|nil Macro body (unused)
---@param handler table Handler
---@return table AST node
function MacroAdvanced.translate_print_shorthand(args, body, handler)
  if #args < 1 then
    return ASTBuilder.create_error("- macro requires expression")
  end

  local expr = ExprParser.parse(args[1].value or args[1])

  return {
    type = "print",
    expression = expr,
    html_encode = false
  }
end

--- Translate <<= $var>> (HTML-encoded print)
---@param args table Macro arguments
---@param body string|nil Macro body (unused)
---@param handler table Handler
---@return table AST node
function MacroAdvanced.translate_print_encoded(args, body, handler)
  if #args < 1 then
    return ASTBuilder.create_error("= macro requires expression")
  end

  local expr = ExprParser.parse(args[1].value or args[1])

  return {
    type = "print",
    expression = expr,
    html_encode = true
  }
end

--------------------------------------------------------------------------------
-- Timing Macros
--------------------------------------------------------------------------------

--- Translate <<timed delay>> content <</timed>>
---@param args table Macro arguments
---@param body string|nil Content body
---@param handler table Handler for recursive parsing
---@return table AST node
function MacroAdvanced.translate_timed(args, body, handler)
  if #args < 1 then
    return ASTBuilder.create_error("timed macro requires delay argument")
  end

  local delay = MacroAdvanced._parse_delay(args[1].value or args[1])

  local timed_body = {}
  if body and handler then
    timed_body = handler:_parse_body_content(body)
  end

  return {
    type = "timed_content",
    delay = delay,
    body = timed_body,
    warning = "Timed content displays immediately in text mode"
  }
end

--- Translate <<repeat delay>> content <</repeat>>
---@param args table Macro arguments
---@param body string|nil Content body
---@param handler table Handler for recursive parsing
---@return table AST node
function MacroAdvanced.translate_repeat(args, body, handler)
  if #args < 1 then
    return ASTBuilder.create_error("repeat macro requires interval argument")
  end

  local interval = MacroAdvanced._parse_delay(args[1].value or args[1])

  local repeat_body = {}
  if body and handler then
    repeat_body = handler:_parse_body_content(body)
  end

  return {
    type = "repeat_content",
    interval = interval,
    body = repeat_body,
    warning = "Repeat content executes once in text mode"
  }
end

--- Translate <<stop>>
---@param args table Macro arguments
---@param body string|nil Macro body (unused)
---@param handler table Handler
---@return table AST node
function MacroAdvanced.translate_stop(args, body, handler)
  return {
    type = "stop_repeat"
  }
end

--- Parse delay string to seconds
---@param delay_str string Delay string like "2s" or "500ms"
---@return number Seconds
function MacroAdvanced._parse_delay(delay_str)
  if type(delay_str) ~= "string" then
    return 0
  end

  local num, unit = delay_str:match("^(%d+%.?%d*)(%a*)$")

  if not num then
    return 0
  end

  num = tonumber(num) or 0

  if unit == "s" or unit == "" then
    return num
  elseif unit == "ms" then
    return num / 1000
  else
    return num
  end
end

--------------------------------------------------------------------------------
-- Capture Macro
--------------------------------------------------------------------------------

--- Translate <<capture variables>> content <</capture>>
---@param args table Macro arguments
---@param body string|nil Content body
---@param handler table Handler for recursive parsing
---@return table AST node
function MacroAdvanced.translate_capture(args, body, handler)
  -- Capture creates local copies of variables
  local variables = {}
  for _, arg in ipairs(args) do
    local var = (arg.value or arg):match("^%$?([%w_]+)$")
    if var then
      table.insert(variables, var)
    end
  end

  local capture_body = {}
  if body and handler then
    capture_body = handler:_parse_body_content(body)
  end

  return {
    type = "capture_block",
    variables = variables,
    body = capture_body
  }
end

--------------------------------------------------------------------------------
-- Type Macro
--------------------------------------------------------------------------------

--- Translate <<type speed>> content <</type>>
---@param args table Macro arguments
---@param body string|nil Content body
---@param handler table Handler for recursive parsing
---@return table AST node
function MacroAdvanced.translate_type(args, body, handler)
  local speed = 40 -- Default typing speed (ms per char)
  if #args >= 1 then
    speed = tonumber(args[1].value or args[1]) or 40
  end

  local type_body = {}
  if body and handler then
    type_body = handler:_parse_body_content(body)
  end

  return {
    type = "typewriter_effect",
    speed = speed,
    body = type_body,
    warning = "Typewriter effect displays immediately in text mode"
  }
end

return MacroAdvanced
