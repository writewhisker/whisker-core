--- SugarCube core macro translation to WhiskerScript AST
-- Implements: set, unset, if, elseif, else, link, button, goto
--
-- lib/whisker/twine/formats/sugarcube/macro_core.lua

local MacroCore = {}

local ASTBuilder = require('whisker.twine.ast_builder')
local ExprParser = require('whisker.twine.formats.sugarcube.expression_parser')

--- Translator function map
MacroCore.translators = {}

--------------------------------------------------------------------------------
-- Main Translation Entry Point
--------------------------------------------------------------------------------

--- Translate SugarCube macro to WhiskerScript AST
---@param macro_name string Macro name (lowercase)
---@param args table Parsed arguments
---@param body string|nil Content between opening and closing tags
---@param handler table Handler instance for recursive parsing
---@return table AST node
function MacroCore.translate(macro_name, args, body, handler)
  local translator = MacroCore.translators[macro_name]

  if translator then
    return translator(args, body, handler)
  else
    return ASTBuilder.create_warning(
      "Unsupported SugarCube macro: " .. macro_name,
      { macro = macro_name, args = args }
    )
  end
end

--------------------------------------------------------------------------------
-- Variable Macros
--------------------------------------------------------------------------------

--- Translate <<set $var to value>> or <<set $var = value>>
MacroCore.translators["set"] = function(args, body, handler)
  if #args < 1 then
    return ASTBuilder.create_error("set macro requires expression")
  end

  local expr_text = args[1].value or args[1]

  -- Handle multiple assignments: $a to 1, $b to 2
  if type(expr_text) == "string" and expr_text:find(",") then
    local nodes = {}
    for assignment in expr_text:gmatch("[^,]+") do
      local node = MacroCore._parse_single_assignment(assignment:match("^%s*(.-)%s*$"))
      if node then
        table.insert(nodes, node)
      end
    end
    if #nodes == 1 then
      return nodes[1]
    elseif #nodes > 1 then
      return { type = "block", statements = nodes }
    end
  end

  return MacroCore._parse_single_assignment(expr_text)
end

--- Parse a single assignment expression
---@param expr_text string Assignment expression
---@return table AST node
function MacroCore._parse_single_assignment(expr_text)
  if not expr_text or expr_text == "" then
    return ASTBuilder.create_error("Empty assignment expression")
  end

  -- Parse assignment: $var to value OR $var = value
  local var_name, value_expr = expr_text:match("^%$([%w_]+)%s+to%s+(.+)$")
  if not var_name then
    var_name, value_expr = expr_text:match("^_([%w_]+)%s+to%s+(.+)$")
  end
  if not var_name then
    var_name, value_expr = expr_text:match("^%$([%w_]+)%s*=%s*(.+)$")
  end
  if not var_name then
    var_name, value_expr = expr_text:match("^_([%w_]+)%s*=%s*(.+)$")
  end

  -- Compound assignment: $var += value
  if not var_name then
    var_name, value_expr = expr_text:match("^%$([%w_]+)%s*%+=%s*(.+)$")
    if var_name then
      value_expr = "$" .. var_name .. " + (" .. value_expr .. ")"
    end
  end

  -- Compound assignment: $var -= value
  if not var_name then
    var_name, value_expr = expr_text:match("^%$([%w_]+)%s*%-=%s*(.+)$")
    if var_name then
      value_expr = "$" .. var_name .. " - (" .. value_expr .. ")"
    end
  end

  -- Compound assignment: $var *= value
  if not var_name then
    var_name, value_expr = expr_text:match("^%$([%w_]+)%s*%*=%s*(.+)$")
    if var_name then
      value_expr = "$" .. var_name .. " * (" .. value_expr .. ")"
    end
  end

  -- Compound assignment: $var /= value
  if not var_name then
    var_name, value_expr = expr_text:match("^%$([%w_]+)%s*/=%s*(.+)$")
    if var_name then
      value_expr = "$" .. var_name .. " / (" .. value_expr .. ")"
    end
  end

  -- Increment: $var++
  if not var_name then
    var_name = expr_text:match("^%$([%w_]+)%s*%+%+%s*$")
    if var_name then
      value_expr = "$" .. var_name .. " + 1"
    end
  end

  -- Decrement: $var--
  if not var_name then
    var_name = expr_text:match("^%$([%w_]+)%s*%-%-?%s*$")
    if var_name then
      value_expr = "$" .. var_name .. " - 1"
    end
  end

  if not var_name then
    return ASTBuilder.create_error("Invalid set syntax: " .. tostring(expr_text))
  end

  -- Parse value expression
  local value_ast = ExprParser.parse(value_expr)

  return ASTBuilder.create_assignment(var_name, value_ast)
end

--- Translate <<unset $var>>
MacroCore.translators["unset"] = function(args, body, handler)
  if #args < 1 then
    return ASTBuilder.create_error("unset macro requires variable name")
  end

  local expr = args[1].value or args[1]

  -- Handle multiple unsets
  if type(expr) == "string" and expr:find(",") then
    local nodes = {}
    for var_expr in expr:gmatch("[^,]+") do
      var_expr = var_expr:match("^%s*(.-)%s*$")
      local var_name = var_expr:match("^%$([%w_]+)$") or var_expr:match("^_([%w_]+)$")
      if var_name then
        table.insert(nodes, {
          type = "unset",
          variable = var_name
        })
      end
    end
    if #nodes == 1 then
      return nodes[1]
    elseif #nodes > 1 then
      return { type = "block", statements = nodes }
    end
  end

  local var_name = expr:match("^%$([%w_]+)$") or expr:match("^_([%w_]+)$")

  if not var_name then
    return ASTBuilder.create_error("unset requires variable: " .. tostring(expr))
  end

  return {
    type = "unset",
    variable = var_name
  }
end

--------------------------------------------------------------------------------
-- Conditional Macros
--------------------------------------------------------------------------------

--- Translate <<if condition>> body <</if>>
MacroCore.translators["if"] = function(args, body, handler)
  if #args < 1 then
    return ASTBuilder.create_error("if macro requires condition")
  end

  local condition_expr = args[1].value or args[1]
  local condition = ExprParser.parse_condition(condition_expr)

  -- Parse body (may contain elseif/else)
  local then_body, elsif_clauses, else_body = MacroCore._parse_conditional_body(body, handler)

  local node = ASTBuilder.create_conditional(condition, then_body)

  -- Add elsif clauses
  if #elsif_clauses > 0 then
    node.elsif_clauses = elsif_clauses
  end

  -- Add else clause
  if else_body and #else_body > 0 then
    node.else_body = else_body
  end

  return node
end

--- Parse conditional body to extract elseif/else clauses
---@param body string|nil Macro body content
---@param handler table Handler for recursive parsing
---@return table, table, table then_body, elsif_clauses, else_body
function MacroCore._parse_conditional_body(body, handler)
  if not body or body == "" then
    return {}, {}, {}
  end

  local then_content = ""
  local elsif_clauses = {}
  local else_content = ""

  local current_mode = "then"
  local current_condition = nil
  local pos = 1
  local in_nested = 0

  while pos <= #body do
    -- Check for nested <<if>>
    if body:sub(pos, pos + 3) == "<<if" then
      in_nested = in_nested + 1
      if current_mode == "then" then
        then_content = then_content .. body:sub(pos, pos + 3)
      elseif current_mode == "elsif" then
        -- Accumulate to current elsif
      else
        else_content = else_content .. body:sub(pos, pos + 3)
      end
      pos = pos + 4
    elseif body:sub(pos, pos + 6) == "<</if>>" then
      if in_nested > 0 then
        in_nested = in_nested - 1
        if current_mode == "then" then
          then_content = then_content .. body:sub(pos, pos + 6)
        else
          else_content = else_content .. body:sub(pos, pos + 6)
        end
      end
      pos = pos + 7
    elseif in_nested == 0 and body:sub(pos, pos + 8) == "<<elseif " then
      -- Save previous content
      if current_mode == "elsif" and current_condition then
        local parsed_body = handler:_parse_body_content(then_content)
        table.insert(elsif_clauses, {
          condition = current_condition,
          body = parsed_body
        })
        then_content = ""
      end

      -- Extract elseif condition
      local close_pos = body:find(">>", pos + 8)
      if close_pos then
        local cond_text = body:sub(pos + 9, close_pos - 1)
        current_condition = ExprParser.parse_condition(cond_text)
        current_mode = "elsif"
        pos = close_pos + 2
      else
        pos = pos + 1
      end
    elseif in_nested == 0 and body:sub(pos, pos + 7) == "<<else>>" then
      -- Save elsif content if any
      if current_mode == "elsif" and current_condition then
        local parsed_body = handler:_parse_body_content(then_content)
        table.insert(elsif_clauses, {
          condition = current_condition,
          body = parsed_body
        })
        then_content = ""
      end

      current_mode = "else"
      pos = pos + 8
    else
      local char = body:sub(pos, pos)
      if current_mode == "then" then
        then_content = then_content .. char
      elseif current_mode == "elsif" then
        then_content = then_content .. char
      else
        else_content = else_content .. char
      end
      pos = pos + 1
    end
  end

  -- Final handling
  if current_mode == "elsif" and current_condition then
    local parsed_body = handler:_parse_body_content(then_content)
    table.insert(elsif_clauses, {
      condition = current_condition,
      body = parsed_body
    })
    then_content = ""
  end

  -- Parse bodies
  local parsed_then = handler:_parse_body_content(then_content)
  local parsed_else = handler:_parse_body_content(else_content)

  return parsed_then, elsif_clauses, parsed_else
end

--------------------------------------------------------------------------------
-- Link/Button Macros
--------------------------------------------------------------------------------

--- Translate <<link "text">> body <</link>> or <<link "text" "passage">>
MacroCore.translators["link"] = function(args, body, handler)
  if #args < 1 then
    return ASTBuilder.create_error("link macro requires text argument")
  end

  local link_text = args[1].value or args[1]
  local destination = nil

  if #args >= 2 then
    destination = args[2].value or args[2]
  end

  -- Parse body
  local link_body = {}
  if body and body ~= "" and handler then
    link_body = handler:_parse_body_content(body)
  end

  return ASTBuilder.create_choice(link_text, link_body, destination)
end

--- Translate <<button "text">> body <</button>>
-- Same as link, just different styling
MacroCore.translators["button"] = function(args, body, handler)
  local result = MacroCore.translators["link"](args, body, handler)
  if result.type == "choice" then
    result.style = "button"
  end
  return result
end

--------------------------------------------------------------------------------
-- Navigation Macros
--------------------------------------------------------------------------------

--- Translate <<goto "destination">> or <<goto [[destination]]>>
MacroCore.translators["goto"] = function(args, body, handler)
  if #args < 1 then
    return ASTBuilder.create_error("goto macro requires destination")
  end

  local dest = args[1].value or args[1]

  -- Handle [[passage]] syntax
  local bracket_dest = dest:match("^%[%[(.+)%]%]$")
  if bracket_dest then
    dest = bracket_dest
  end

  return ASTBuilder.create_goto(dest)
end

--------------------------------------------------------------------------------
-- Utility Macros
--------------------------------------------------------------------------------

--- Translate <<silently>> body <</silently>>
-- Executes code without output
MacroCore.translators["silently"] = function(args, body, handler)
  if not body or body == "" then
    return { type = "noop" }
  end

  local silent_body = {}
  if handler then
    silent_body = handler:_parse_body_content(body)
  end

  return {
    type = "silent_block",
    body = silent_body
  }
end

--- Translate <<display "passage">> - include another passage
MacroCore.translators["display"] = function(args, body, handler)
  if #args < 1 then
    return ASTBuilder.create_error("display macro requires passage name")
  end

  local passage_name = args[1].value or args[1]

  -- Handle [[passage]] syntax
  local bracket_name = passage_name:match("^%[%[(.+)%]%]$")
  if bracket_name then
    passage_name = bracket_name
  end

  return {
    type = "include",
    passage = passage_name
  }
end

--- Translate <<include "passage">> - same as display
MacroCore.translators["include"] = MacroCore.translators["display"]

--------------------------------------------------------------------------------
-- Output Macros (basic versions - advanced in macro_advanced.lua)
--------------------------------------------------------------------------------

--- Translate <<print $var>>
MacroCore.translators["print"] = function(args, body, handler)
  if #args < 1 then
    return ASTBuilder.create_error("print macro requires expression")
  end

  local expr = ExprParser.parse(args[1].value or args[1])

  return {
    type = "print",
    expression = expr,
    html_encode = false
  }
end

return MacroCore
