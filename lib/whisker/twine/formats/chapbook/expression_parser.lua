--- Chapbook expression parser
-- Simplified compared to SugarCube (no $ prefix, simpler syntax)
--
-- lib/whisker/twine/formats/chapbook/expression_parser.lua

local ExpressionParser = {}

local ASTBuilder = require('whisker.twine.ast_builder')

--------------------------------------------------------------------------------
-- Expression Parsing
--------------------------------------------------------------------------------

--- Parse expression to AST
---@param expr_text string Expression text
---@return table AST node
function ExpressionParser.parse(expr_text)
  if not expr_text then
    return ASTBuilder.create_literal("nil", nil)
  end

  expr_text = expr_text:match("^%s*(.-)%s*$") -- Trim

  if expr_text == "" then
    return ASTBuilder.create_literal("nil", nil)
  end

  -- Number
  if expr_text:match("^%-?%d+%.?%d*$") then
    return ASTBuilder.create_literal("number", tonumber(expr_text))
  end

  -- String (double or single quotes)
  local string_val = expr_text:match('^"(.*)"$') or expr_text:match("^'(.*)'$")
  if string_val then
    return ASTBuilder.create_literal("string", string_val)
  end

  -- Boolean
  if expr_text == "true" then
    return ASTBuilder.create_literal("boolean", true)
  elseif expr_text == "false" then
    return ASTBuilder.create_literal("boolean", false)
  end

  -- Array: ['item1', 'item2']
  if expr_text:match("^%[.-%]$") then
    return ExpressionParser._parse_array(expr_text)
  end

  -- Variable (no prefix in Chapbook)
  if expr_text:match("^[%w_]+$") then
    return ASTBuilder.create_variable_ref(expr_text)
  end

  -- Property access: obj.prop
  local obj, prop = expr_text:match("^([%w_]+)%.([%w_]+)$")
  if obj and prop then
    return ASTBuilder.create_property_access(
      ASTBuilder.create_variable_ref(obj),
      prop
    )
  end

  -- Binary operation
  local left, op, right = ExpressionParser._split_binary_op(expr_text)
  if left and op and right then
    return ASTBuilder.create_binary_op(
      op,
      ExpressionParser.parse(left),
      ExpressionParser.parse(right)
    )
  end

  -- Fallback: raw expression
  return ASTBuilder.create_raw_expression(expr_text)
end

--------------------------------------------------------------------------------
-- Condition Parsing
--------------------------------------------------------------------------------

--- Parse condition expression (for modifiers)
---@param cond_text string Condition text
---@return table AST node
function ExpressionParser.parse_condition(cond_text)
  if not cond_text then
    return ASTBuilder.create_literal("boolean", true)
  end

  cond_text = cond_text:match("^%s*(.-)%s*$") -- Trim

  if cond_text == "" then
    return ASTBuilder.create_literal("boolean", true)
  end

  -- Logical operators: and, or
  local left, op, right = ExpressionParser._split_logical_op(cond_text)
  if left and op and right then
    return ASTBuilder.create_logical_op(
      op,
      ExpressionParser.parse_condition(left),
      ExpressionParser.parse_condition(right)
    )
  end

  -- Comparison operators
  for _, op_info in ipairs({
    { pattern = ">=", op = ">=" },
    { pattern = "<=", op = "<=" },
    { pattern = "==", op = "==" },
    { pattern = "!=", op = "!=" },
    { pattern = ">", op = ">" },
    { pattern = "<", op = "<" }
  }) do
    local escaped = op_info.pattern:gsub("([><=!])", "%%%1")
    local start_pos = cond_text:find("%s*" .. escaped .. "%s*")
    if start_pos then
      local left_part = cond_text:sub(1, start_pos - 1):match("^%s*(.-)%s*$")
      local right_part = cond_text:sub(start_pos + #op_info.pattern):match("^%s*(.-)%s*$")
      if left_part ~= "" and right_part ~= "" then
        return ASTBuilder.create_binary_op(
          op_info.op,
          ExpressionParser.parse(left_part),
          ExpressionParser.parse(right_part)
        )
      end
    end
  end

  -- Not operator
  local inner = cond_text:match("^not%s+(.+)$")
  if inner then
    return ASTBuilder.create_unary_op("not", ExpressionParser.parse_condition(inner))
  end

  -- Simple variable as boolean
  return ExpressionParser.parse(cond_text)
end

--------------------------------------------------------------------------------
-- Binary Operator Splitting
--------------------------------------------------------------------------------

--- Split by binary operator
---@param expr string Expression to split
---@return string|nil, string|nil, string|nil Left, operator, right
function ExpressionParser._split_binary_op(expr)
  local operators = { "+", "-", "*", "/" }

  for _, op in ipairs(operators) do
    local pattern
    if op == "+" then
      pattern = "%+"
    elseif op == "*" then
      pattern = "%*"
    else
      pattern = op
    end

    -- Find last occurrence to handle left-to-right evaluation
    local last_pos = nil
    local pos = 1
    while true do
      local found = expr:find("%s*" .. pattern .. "%s*", pos)
      if not found then break end
      last_pos = found
      pos = found + 1
    end

    if last_pos then
      local left = expr:sub(1, last_pos - 1):match("^%s*(.-)%s*$")
      local right = expr:sub(last_pos + 1):match("^%s*(.-)%s*$")
      if left ~= "" and right ~= "" then
        return left, op, right
      end
    end
  end

  return nil, nil, nil
end

--- Split by logical operator
---@param expr string Expression to split
---@return string|nil, string|nil, string|nil Left, operator, right
function ExpressionParser._split_logical_op(expr)
  local patterns = {
    { pat = "%s+and%s+", op = "and" },
    { pat = "%s+or%s+", op = "or" }
  }

  for _, p in ipairs(patterns) do
    local start_pos, end_pos = expr:find(p.pat)
    if start_pos then
      local left = expr:sub(1, start_pos - 1):match("^%s*(.-)%s*$")
      local right = expr:sub(end_pos + 1):match("^%s*(.-)%s*$")
      if left ~= "" and right ~= "" then
        return left, p.op, right
      end
    end
  end

  return nil, nil, nil
end

--------------------------------------------------------------------------------
-- Array Parsing
--------------------------------------------------------------------------------

--- Parse array literal: [1, 2, 3] or ['a', 'b']
---@param expr string Array expression
---@return table AST node
function ExpressionParser._parse_array(expr)
  local content = expr:sub(2, -2) -- Remove [ ]

  if content:match("^%s*$") then
    return ASTBuilder.create_array_literal({})
  end

  local items = {}
  local current = ""
  local in_string = false
  local string_char = nil

  for i = 1, #content do
    local char = content:sub(i, i)
    local prev = i > 1 and content:sub(i - 1, i - 1) or ""

    if (char == '"' or char == "'") and prev ~= "\\" then
      if not in_string then
        in_string = true
        string_char = char
      elseif char == string_char then
        in_string = false
        string_char = nil
      end
      current = current .. char
    elseif in_string then
      current = current .. char
    elseif char == "," then
      local item = current:match("^%s*(.-)%s*$")
      if item ~= "" then
        table.insert(items, ExpressionParser.parse(item))
      end
      current = ""
    else
      current = current .. char
    end
  end

  -- Add final item
  local item = current:match("^%s*(.-)%s*$")
  if item ~= "" then
    table.insert(items, ExpressionParser.parse(item))
  end

  return ASTBuilder.create_array_literal(items)
end

return ExpressionParser
