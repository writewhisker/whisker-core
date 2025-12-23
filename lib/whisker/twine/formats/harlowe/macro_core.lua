--- Harlowe core macro translation to WhiskerScript AST
-- Implements: set, put, if, else-if, else, link, link-goto, goto
--
-- lib/whisker/twine/formats/harlowe/macro_core.lua

local MacroCore = {}

-- Path to ASTBuilder relative to this module
local ASTBuilder = require('whisker.twine.ast_builder')

--- Translate Harlowe macro to WhiskerScript AST
---@param macro_name string Macro name (e.g., "set", "if")
---@param args table Array of parsed arguments
---@param hook_content string|nil Content in attached [hook]
---@return table AST node
function MacroCore.translate(macro_name, args, hook_content)
  local translator = MacroCore.translators[macro_name:lower()]

  if translator then
    return translator(args, hook_content)
  else
    -- Unsupported macro - return warning node
    return MacroCore._unsupported_macro(macro_name, args, hook_content)
  end
end

--- Translator function map
MacroCore.translators = {}

--- Translate (set: $var to value)
MacroCore.translators["set"] = function(args, hook_content)
  if #args < 1 then
    return MacroCore._error_node("set requires at least 1 argument")
  end

  -- The first arg contains the full expression "$var to value"
  local full_expr = args[1].value
  if args[1].type ~= "expression" then
    full_expr = tostring(args[1].value)
  end

  -- Parse "$var to value" pattern
  local var_name, value_str = full_expr:match("^%$([%w_]+)%s+to%s+(.+)$")

  if not var_name then
    -- Try parsing with structured args: $var, to, value
    if #args >= 3 and args[2].type == "expression" and args[2].value == "to" then
      var_name = args[1].value
      if type(var_name) == "string" and var_name:sub(1, 1) == "$" then
        var_name = var_name:sub(2)
      end
      value_str = args[3].value
    else
      return MacroCore._error_node("set requires: $variable to value")
    end
  end

  -- Build assignment AST
  local value_node
  if type(value_str) == "string" then
    value_node = MacroCore._parse_expression(value_str)
  else
    value_node = MacroCore._build_expression({ type = "expression", value = tostring(value_str) })
  end

  return ASTBuilder.create_assignment(var_name, value_node)
end

--- Translate (put: value into $var)
MacroCore.translators["put"] = function(args, hook_content)
  if #args < 1 then
    return MacroCore._error_node("put requires at least 1 argument")
  end

  -- Parse "value into $var" pattern
  local full_expr = args[1].value
  if args[1].type ~= "expression" then
    full_expr = tostring(args[1].value)
  end

  local value_str, var_name = full_expr:match("^(.+)%s+into%s+%$([%w_]+)$")

  if not var_name then
    -- Try structured args
    if #args >= 3 and args[2].type == "expression" and args[2].value == "into" then
      value_str = args[1].value
      var_name = args[3].value
      if type(var_name) == "string" and var_name:sub(1, 1) == "$" then
        var_name = var_name:sub(2)
      end
    else
      return MacroCore._error_node("put requires: value into $variable")
    end
  end

  local value_node = MacroCore._parse_expression(value_str)
  return ASTBuilder.create_assignment(var_name, value_node)
end

--- Translate (if: condition)[hook]
MacroCore.translators["if"] = function(args, hook_content)
  if #args < 1 then
    return MacroCore._error_node("if requires condition argument")
  end

  local condition = MacroCore._build_condition(args[1])
  local body = hook_content and MacroCore._parse_hook_content(hook_content) or {}

  return ASTBuilder.create_conditional(condition, body)
end

--- Translate (else-if: condition)[hook]
MacroCore.translators["else-if"] = function(args, hook_content)
  if #args < 1 then
    return MacroCore._error_node("else-if requires condition argument")
  end

  local condition = MacroCore._build_condition(args[1])
  local body = hook_content and MacroCore._parse_hook_content(hook_content) or {}

  return ASTBuilder.create_elsif(condition, body)
end

--- Translate (else:)[hook]
MacroCore.translators["else"] = function(args, hook_content)
  local body = hook_content and MacroCore._parse_hook_content(hook_content) or {}
  return ASTBuilder.create_else(body)
end

--- Translate (link: "text")[hook]
MacroCore.translators["link"] = function(args, hook_content)
  if #args < 1 then
    return MacroCore._error_node("link requires text argument")
  end

  local link_text = MacroCore._get_string_value(args[1])
  local body = hook_content and MacroCore._parse_hook_content(hook_content) or {}

  return ASTBuilder.create_choice(link_text, body, nil)
end

--- Translate (link-goto: "text", "destination")
MacroCore.translators["link-goto"] = function(args, hook_content)
  if #args < 2 then
    return MacroCore._error_node("link-goto requires text and destination arguments")
  end

  local link_text = MacroCore._get_string_value(args[1])
  local destination = MacroCore._get_string_value(args[2])

  return ASTBuilder.create_choice(link_text, {}, destination)
end

--- Translate (goto: "destination")
MacroCore.translators["goto"] = function(args, hook_content)
  if #args < 1 then
    return MacroCore._error_node("goto requires destination argument")
  end

  local destination = MacroCore._get_string_value(args[1])
  return ASTBuilder.create_goto(destination)
end

--- Translate (unless: condition)[hook]
MacroCore.translators["unless"] = function(args, hook_content)
  if #args < 1 then
    return MacroCore._error_node("unless requires condition argument")
  end

  local condition = MacroCore._build_condition(args[1])
  local negated_condition = ASTBuilder.create_unary_op("not", condition)
  local body = hook_content and MacroCore._parse_hook_content(hook_content) or {}

  return ASTBuilder.create_conditional(negated_condition, body)
end

--- Translate (print: expression)
MacroCore.translators["print"] = function(args, hook_content)
  if #args < 1 then
    return MacroCore._error_node("print requires expression argument")
  end

  local expr = MacroCore._build_expression(args[1])
  return {
    type = "print",
    expression = expr
  }
end

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------

--- Build expression AST from parsed value
---@param value_arg table { type, value }
---@return table Expression AST node
function MacroCore._build_expression(value_arg)
  if value_arg.type == "number" then
    return ASTBuilder.create_literal("number", value_arg.value)
  elseif value_arg.type == "string" then
    return ASTBuilder.create_literal("string", value_arg.value)
  elseif value_arg.type == "boolean" then
    return ASTBuilder.create_literal("boolean", value_arg.value)
  elseif value_arg.type == "variable" then
    return ASTBuilder.create_variable_ref(value_arg.value)
  elseif value_arg.type == "expression" then
    return MacroCore._parse_expression(value_arg.value)
  else
    return ASTBuilder.create_literal("nil", nil)
  end
end

--- Build condition AST from parsed value
-- Handles Harlowe comparison operators: is, is not, >, <, >=, <=
function MacroCore._build_condition(value_arg)
  if value_arg.type == "expression" then
    return MacroCore._parse_condition_expression(value_arg.value)
  elseif value_arg.type == "variable" then
    return ASTBuilder.create_variable_ref(value_arg.value)
  elseif value_arg.type == "boolean" then
    return ASTBuilder.create_literal("boolean", value_arg.value)
  else
    return MacroCore._error_node("Invalid condition type")
  end
end

--- Parse Harlowe condition expression
-- Converts: "$x is 5" -> WhiskerScript: "x == 5"
function MacroCore._parse_condition_expression(expr)
  if type(expr) ~= "string" then
    return ASTBuilder.create_raw_expression(tostring(expr))
  end

  expr = expr:match("^%s*(.-)%s*$") -- trim

  -- Handle "is not" operator (must check before "is")
  local left, right = expr:match("^(.-)%s+is%s+not%s+(.+)$")
  if left and right then
    return ASTBuilder.create_binary_op(
      "!=",
      MacroCore._parse_expression(left),
      MacroCore._parse_expression(right)
    )
  end

  -- Handle "is" operator
  left, right = expr:match("^(.-)%s+is%s+(.+)$")
  if left and right then
    return ASTBuilder.create_binary_op(
      "==",
      MacroCore._parse_expression(left),
      MacroCore._parse_expression(right)
    )
  end

  -- Handle "contains" operator
  left, right = expr:match("^(.-)%s+contains%s+(.+)$")
  if left and right then
    return {
      type = "contains",
      collection = MacroCore._parse_expression(left),
      item = MacroCore._parse_expression(right)
    }
  end

  -- Handle "is in" operator
  left, right = expr:match("^(.-)%s+is%s+in%s+(.+)$")
  if left and right then
    return {
      type = "contains",
      collection = MacroCore._parse_expression(right),
      item = MacroCore._parse_expression(left)
    }
  end

  -- Handle >=, <=, >, < (in order of specificity)
  for _, op in ipairs({ ">=", "<=", ">", "<" }) do
    local escaped_op = op:gsub("([><])", "%%%1")
    local pattern = "^(.-)%s*" .. escaped_op .. "%s*(.+)$"
    left, right = expr:match(pattern)
    if left and right then
      return ASTBuilder.create_binary_op(
        op,
        MacroCore._parse_expression(left),
        MacroCore._parse_expression(right)
      )
    end
  end

  -- Handle "and", "or"
  left, right = expr:match("^(.-)%s+and%s+(.+)$")
  if left and right then
    return ASTBuilder.create_logical_op(
      "and",
      MacroCore._parse_condition_expression(left),
      MacroCore._parse_condition_expression(right)
    )
  end

  left, right = expr:match("^(.-)%s+or%s+(.+)$")
  if left and right then
    return ASTBuilder.create_logical_op(
      "or",
      MacroCore._parse_condition_expression(left),
      MacroCore._parse_condition_expression(right)
    )
  end

  -- Handle "not" prefix
  local operand = expr:match("^not%s+(.+)$")
  if operand then
    return ASTBuilder.create_unary_op("not", MacroCore._parse_condition_expression(operand))
  end

  -- Simple variable or value
  return MacroCore._parse_expression(expr)
end

--- Parse expression (handles variables, literals, arithmetic)
function MacroCore._parse_expression(expr)
  if type(expr) ~= "string" then
    return ASTBuilder.create_raw_expression(tostring(expr))
  end

  expr = expr:match("^%s*(.-)%s*$") -- Trim

  -- Variable
  if expr:match("^%$[%w_]+$") then
    return ASTBuilder.create_variable_ref(expr:sub(2))
  end

  -- Temporary variable (Harlowe uses _ prefix)
  if expr:match("^_[%w_]+$") then
    return ASTBuilder.create_variable_ref(expr:sub(2))
  end

  -- Number
  if expr:match("^%-?%d+%.?%d*$") then
    return ASTBuilder.create_literal("number", tonumber(expr))
  end

  -- String
  if expr:match('^".*"$') or expr:match("^'.*'$") then
    return ASTBuilder.create_literal("string", expr:sub(2, -2))
  end

  -- Boolean
  if expr == "true" then
    return ASTBuilder.create_literal("boolean", true)
  elseif expr == "false" then
    return ASTBuilder.create_literal("boolean", false)
  end

  -- Arithmetic operations: +, -, *, /
  for _, op in ipairs({ "+", "-", "*", "/" }) do
    local escaped_op = op == "+" and "%+" or (op == "*" and "%*" or op)
    local pattern = "^(.-)%s*" .. escaped_op .. "%s*(.+)$"
    local left, right = expr:match(pattern)
    if left and right then
      return ASTBuilder.create_binary_op(
        op,
        MacroCore._parse_expression(left),
        MacroCore._parse_expression(right)
      )
    end
  end

  -- Unknown - return as raw expression
  return ASTBuilder.create_raw_expression(expr)
end

--- Parse hook content (may contain nested macros/text)
function MacroCore._parse_hook_content(content)
  -- For now, return as text node
  -- Full implementation would recursively parse macros within hook
  return { ASTBuilder.create_text(content) }
end

--- Get string value from argument
function MacroCore._get_string_value(arg)
  if arg.type == "string" then
    return arg.value
  elseif arg.type == "variable" then
    -- Return variable reference
    return "${" .. arg.value .. "}"
  else
    return tostring(arg.value)
  end
end

--- Create error AST node
function MacroCore._error_node(message)
  return ASTBuilder.create_error(message)
end

--- Create unsupported macro warning node
function MacroCore._unsupported_macro(macro_name, args, hook_content)
  return ASTBuilder.create_warning(
    "Unsupported Harlowe macro: " .. macro_name,
    {
      macro = macro_name,
      args = args,
      hook = hook_content
    }
  )
end

return MacroCore
