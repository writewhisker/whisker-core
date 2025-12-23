--- Chapbook modifier parser
-- Parses [if], [unless], [after], [continue], etc.
--
-- lib/whisker/twine/formats/chapbook/modifier_parser.lua

local ModifierParser = {}

local ASTBuilder = require('whisker.twine.ast_builder')
local ExprParser = require('whisker.twine.formats.chapbook.expression_parser')

--------------------------------------------------------------------------------
-- Main Parsing Entry Point
--------------------------------------------------------------------------------

--- Parse modifier and affected content
---@param lines table All passage lines
---@param start_index number Line index of modifier
---@return table, number AST node and number of lines consumed
function ModifierParser.parse_modifier(lines, start_index)
  local modifier_line = lines[start_index]

  -- Extract modifier and arguments
  local modifier_content = modifier_line:match("^%[(.+)%]$")

  if not modifier_content then
    return ASTBuilder.create_error("Invalid modifier syntax"), 1
  end

  -- Parse modifier type and args
  local mod_type, mod_args = modifier_content:match("^([%w]+)%s*(.*)$")

  if not mod_type then
    return ASTBuilder.create_error("Invalid modifier: " .. modifier_content), 1
  end

  mod_type = mod_type:lower()

  -- Collect content lines (until next modifier or blank line)
  local content_lines = {}
  local consumed = 1

  for i = start_index + 1, #lines do
    local line = lines[i]

    -- Stop at next modifier or blank line
    if line:match("^%[.+%]$") or line:match("^%s*$") then
      break
    end

    table.insert(content_lines, line)
    consumed = consumed + 1
  end

  local content_text = table.concat(content_lines, "\n")

  -- Translate based on modifier type
  if mod_type == "if" then
    return ModifierParser._translate_if(mod_args, content_text), consumed
  elseif mod_type == "unless" then
    return ModifierParser._translate_unless(mod_args, content_text), consumed
  elseif mod_type == "after" then
    return ModifierParser._translate_after(mod_args, content_text), consumed
  elseif mod_type == "continue" then
    return ModifierParser._translate_continue(content_text), consumed
  elseif mod_type == "align" then
    return ModifierParser._translate_align(mod_args, content_text), consumed
  elseif mod_type == "note" then
    return ModifierParser._translate_note(content_text), consumed
  elseif mod_type == "append" then
    return ModifierParser._translate_append(mod_args, content_text), consumed
  elseif mod_type == "css" then
    return ModifierParser._translate_css(mod_args, content_text), consumed
  else
    return {
      type = "warning",
      message = "Unsupported Chapbook modifier: " .. mod_type,
      content = content_text
    }, consumed
  end
end

--------------------------------------------------------------------------------
-- Modifier Translators
--------------------------------------------------------------------------------

--- Translate [if condition]
---@param condition string Condition expression
---@param content string Content text
---@return table AST node
function ModifierParser._translate_if(condition, content)
  -- Check for inline else: [if x; else]
  local cond_part = condition
  local has_else = false

  if condition:find(";%s*else%s*$") then
    cond_part = condition:match("^(.-)%s*;%s*else%s*$")
    has_else = true
  end

  local condition_ast = ExprParser.parse_condition(cond_part)
  local body = { ASTBuilder.create_text(content) }

  local node = ASTBuilder.create_conditional(condition_ast, body)

  if has_else then
    node.has_else_hint = true
  end

  return node
end

--- Translate [unless condition]
---@param condition string Condition expression
---@param content string Content text
---@return table AST node
function ModifierParser._translate_unless(condition, content)
  -- Unless is "if not condition"
  local condition_ast = ExprParser.parse_condition(condition)
  local negated = ASTBuilder.create_unary_op("not", condition_ast)
  local body = { ASTBuilder.create_text(content) }

  return ASTBuilder.create_conditional(negated, body)
end

--- Translate [after delay]
---@param delay string Delay specification (e.g., "2s", "1000ms")
---@param content string Content text
---@return table AST node
function ModifierParser._translate_after(delay, content)
  local seconds = ModifierParser._parse_delay(delay)

  return {
    type = "delayed_content",
    delay = seconds,
    body = { ASTBuilder.create_text(content) },
    warning = "Delayed content displays immediately in text mode"
  }
end

--- Translate [continue]
---@param content string Content text
---@return table AST node
function ModifierParser._translate_continue(content)
  return {
    type = "continue_prompt",
    body = { ASTBuilder.create_text(content) },
    note = "Requires user interaction to proceed"
  }
end

--- Translate [align direction]
---@param direction string Alignment direction (center, right, left)
---@param content string Content text
---@return table AST node
function ModifierParser._translate_align(direction, content)
  return {
    type = "aligned_text",
    alignment = direction:lower():match("^%s*(.-)%s*$"),
    body = { ASTBuilder.create_text(content) }
  }
end

--- Translate [note]
---@param content string Content text
---@return table AST node
function ModifierParser._translate_note(content)
  return {
    type = "note",
    body = { ASTBuilder.create_text(content) }
  }
end

--- Translate [append]
---@param target string Target element
---@param content string Content text
---@return table AST node
function ModifierParser._translate_append(target, content)
  return {
    type = "append_content",
    target = target:match("^%s*(.-)%s*$"),
    body = { ASTBuilder.create_text(content) },
    warning = "Append may not work in text mode"
  }
end

--- Translate [css]
---@param selector string CSS selector or empty
---@param content string CSS content
---@return table AST node
function ModifierParser._translate_css(selector, content)
  return {
    type = "css_block",
    selector = selector:match("^%s*(.-)%s*$"),
    content = content,
    warning = "CSS styling not applicable in text mode"
  }
end

--------------------------------------------------------------------------------
-- Utility Functions
--------------------------------------------------------------------------------

--- Parse delay string to seconds
---@param delay_str string Delay string like "2s" or "500ms"
---@return number Seconds
function ModifierParser._parse_delay(delay_str)
  if not delay_str or delay_str == "" then
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

return ModifierParser
