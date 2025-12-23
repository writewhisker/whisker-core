--- Chapbook insert parser
-- Parses {variable} and {expression} inserts
--
-- lib/whisker/twine/formats/chapbook/insert_parser.lua

local InsertParser = {}

local ASTBuilder = require('whisker.twine.ast_builder')
local ExprParser = require('whisker.twine.formats.chapbook.expression_parser')

--------------------------------------------------------------------------------
-- Line Parsing
--------------------------------------------------------------------------------

--- Parse line containing inserts
---@param line string Line with potential {inserts}
---@return table AST node with text and interpolated expressions
function InsertParser.parse_line_with_inserts(line)
  local parts = {}
  local pos = 1

  while pos <= #line do
    -- Find next insert
    local insert_start = line:find("{", pos, true)

    if not insert_start then
      -- No more inserts, add remaining text
      local remaining = line:sub(pos)
      if remaining ~= "" then
        table.insert(parts, ASTBuilder.create_text(remaining))
      end
      break
    end

    -- Add text before insert
    if insert_start > pos then
      table.insert(parts, ASTBuilder.create_text(line:sub(pos, insert_start - 1)))
    end

    -- Find closing }
    local insert_end = InsertParser._find_closing_brace(line, insert_start + 1)

    if not insert_end then
      -- Malformed insert, treat as text
      table.insert(parts, ASTBuilder.create_text(line:sub(insert_start)))
      break
    end

    -- Parse insert content
    local insert_content = line:sub(insert_start + 1, insert_end - 1)
    local insert_ast = InsertParser._parse_insert(insert_content)
    table.insert(parts, insert_ast)

    pos = insert_end + 1
  end

  -- If only one part, return it directly
  if #parts == 1 then
    return parts[1]
  elseif #parts == 0 then
    return ASTBuilder.create_text("")
  end

  -- Multiple parts: create interpolated text node
  return {
    type = "interpolated_text",
    parts = parts
  }
end

--- Find closing brace, handling nested braces
---@param line string Line to search
---@param start_pos number Position after opening {
---@return number|nil Position of closing }
function InsertParser._find_closing_brace(line, start_pos)
  local depth = 1

  for i = start_pos, #line do
    local char = line:sub(i, i)
    if char == "{" then
      depth = depth + 1
    elseif char == "}" then
      depth = depth - 1
      if depth == 0 then
        return i
      end
    end
  end

  return nil
end

--------------------------------------------------------------------------------
-- Insert Parsing
--------------------------------------------------------------------------------

--- Parse single insert: variable, expression, or function call
---@param content string Insert content
---@return table AST node
function InsertParser._parse_insert(content)
  content = content:match("^%s*(.-)%s*$") -- Trim

  -- Check for default value: {varName, default: value}
  local var_name, default_value = content:match("^([%w_%.]+)%s*,%s*default:%s*(.+)$")

  if var_name and default_value then
    return {
      type = "insert_with_default",
      variable = var_name,
      default = ExprParser.parse(default_value)
    }
  end

  -- Check for function call: {functionName(args)}
  local func_name, func_args = content:match("^([%w_]+)%((.*)%)$")

  if func_name then
    return InsertParser._parse_function_call(func_name, func_args)
  end

  -- Simple variable or expression
  local expr = ExprParser.parse(content)

  return {
    type = "insert",
    expression = expr
  }
end

--------------------------------------------------------------------------------
-- Function Call Parsing
--------------------------------------------------------------------------------

--- Parse function call in insert
---@param func_name string Function name
---@param args_str string Arguments string
---@return table AST node
function InsertParser._parse_function_call(func_name, args_str)
  -- Built-in Chapbook functions
  if func_name == "random" then
    -- random(min, max)
    local min_str, max_str = args_str:match("^([^,]+),%s*(.+)$")
    if min_str and max_str then
      return {
        type = "random_range",
        min = ExprParser.parse(min_str:match("^%s*(.-)%s*$")),
        max = ExprParser.parse(max_str:match("^%s*(.-)%s*$"))
      }
    end
  elseif func_name == "either" then
    -- either(a, b, c) - random choice
    local choices = {}
    for choice in args_str:gmatch("[^,]+") do
      table.insert(choices, ExprParser.parse(choice:match("^%s*(.-)%s*$")))
    end

    return {
      type = "random_choice",
      choices = choices
    }
  elseif func_name == "uppercase" then
    return {
      type = "text_transform",
      transform = "uppercase",
      value = ExprParser.parse(args_str:match("^%s*(.-)%s*$"))
    }
  elseif func_name == "lowercase" then
    return {
      type = "text_transform",
      transform = "lowercase",
      value = ExprParser.parse(args_str:match("^%s*(.-)%s*$"))
    }
  elseif func_name == "capitalcase" then
    return {
      type = "text_transform",
      transform = "capitalize",
      value = ExprParser.parse(args_str:match("^%s*(.-)%s*$"))
    }
  end

  -- Unknown function
  return {
    type = "function_call",
    function_name = func_name,
    arguments = args_str,
    warning = "Custom function calls may not be supported"
  }
end

return InsertParser
