--- SugarCube expression parser
-- Handles JavaScript-like expressions: variables, operators, property access
--
-- lib/whisker/twine/formats/sugarcube/expression_parser.lua

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

  -- Variable: $var or _var
  local var_match = expr_text:match("^%$([%w_]+)$") or expr_text:match("^_([%w_]+)$")
  if var_match then
    return ASTBuilder.create_variable_ref(var_match)
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
  elseif expr_text == "null" or expr_text == "undefined" then
    return ASTBuilder.create_literal("nil", nil)
  end

  -- Array literal: [item1, item2]
  if expr_text:match("^%[.-%]$") then
    return ExpressionParser._parse_array(expr_text)
  end

  -- Property access: $obj.prop
  local obj_var, prop = expr_text:match("^%$([%w_]+)%.([%w_]+)$")
  if obj_var and prop then
    return ASTBuilder.create_property_access(
      ASTBuilder.create_variable_ref(obj_var),
      prop
    )
  end

  -- Array access: $arr[0]
  local arr_var, index = expr_text:match("^%$([%w_]+)%[(%d+)%]$")
  if arr_var and index then
    return ASTBuilder.create_array_access(
      ASTBuilder.create_variable_ref(arr_var),
      ASTBuilder.create_literal("number", tonumber(index) + 1) -- Lua is 1-indexed
    )
  end

  -- Binary operations (check in order of precedence)
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

--- Parse condition expression
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

  -- Logical operators: and, or, &&, ||
  local left, op, right = ExpressionParser._split_logical_op(cond_text)
  if left and op and right then
    return ASTBuilder.create_logical_op(
      op,
      ExpressionParser.parse_condition(left),
      ExpressionParser.parse_condition(right)
    )
  end

  -- Comparison operators
  left, op, right = ExpressionParser._split_comparison_op(cond_text)
  if left and op and right then
    return ASTBuilder.create_binary_op(
      op,
      ExpressionParser.parse(left),
      ExpressionParser.parse(right)
    )
  end

  -- Not operator: not x, !x
  local inner = cond_text:match("^not%s+(.+)$") or cond_text:match("^!%s*(.+)$")
  if inner then
    return ASTBuilder.create_unary_op("not", ExpressionParser.parse_condition(inner))
  end

  -- Parenthesized expression
  if cond_text:match("^%(.*%)$") then
    local inner_cond = cond_text:sub(2, -2)
    return ExpressionParser.parse_condition(inner_cond)
  end

  -- Simple expression as boolean
  return ExpressionParser.parse(cond_text)
end

--------------------------------------------------------------------------------
-- Binary Operator Splitting
--------------------------------------------------------------------------------

--- Split expression by binary operator (lowest precedence first)
---@param expr string Expression to split
---@return string|nil, string|nil, string|nil Left, operator, right
function ExpressionParser._split_binary_op(expr)
  -- Handle parentheses by only splitting at top level
  local depth = 0
  local in_string = false
  local string_char = nil

  -- Try + and - (lowest precedence)
  for _, op in ipairs({"+", "-"}) do
    depth = 0
    in_string = false

    for i = #expr, 1, -1 do
      local char = expr:sub(i, i)
      local prev = i > 1 and expr:sub(i - 1, i - 1) or ""

      -- Handle strings
      if (char == '"' or char == "'") and prev ~= "\\" then
        if not in_string then
          in_string = true
          string_char = char
        elseif char == string_char then
          in_string = false
          string_char = nil
        end
      elseif not in_string then
        if char == ")" or char == "]" then
          depth = depth + 1
        elseif char == "(" or char == "[" then
          depth = depth - 1
        elseif depth == 0 and char == op then
          -- Check it's not part of a comparison operator
          local prev2 = i > 1 and expr:sub(i - 1, i - 1) or ""
          if prev2 ~= ">" and prev2 ~= "<" and prev2 ~= "=" and prev2 ~= "!" then
            local left = expr:sub(1, i - 1):match("^%s*(.-)%s*$")
            local right = expr:sub(i + 1):match("^%s*(.-)%s*$")
            if left ~= "" and right ~= "" then
              return left, op, right
            end
          end
        end
      end
    end
  end

  -- Try * and /
  for _, op in ipairs({"*", "/"}) do
    depth = 0
    in_string = false

    for i = #expr, 1, -1 do
      local char = expr:sub(i, i)
      local prev = i > 1 and expr:sub(i - 1, i - 1) or ""

      if (char == '"' or char == "'") and prev ~= "\\" then
        if not in_string then
          in_string = true
          string_char = char
        elseif char == string_char then
          in_string = false
        end
      elseif not in_string then
        if char == ")" or char == "]" then
          depth = depth + 1
        elseif char == "(" or char == "[" then
          depth = depth - 1
        elseif depth == 0 and char == op then
          local left = expr:sub(1, i - 1):match("^%s*(.-)%s*$")
          local right = expr:sub(i + 1):match("^%s*(.-)%s*$")
          if left ~= "" and right ~= "" then
            return left, op, right
          end
        end
      end
    end
  end

  return nil, nil, nil
end

--- Split by logical operator
---@param expr string Expression to split
---@return string|nil, string|nil, string|nil Left, operator, right
function ExpressionParser._split_logical_op(expr)
  -- Try 'and' / '&&'
  local patterns = {
    { pat = "%s+and%s+", op = "and" },
    { pat = "%s*&&%s*", op = "and" },
    { pat = "%s+or%s+", op = "or" },
    { pat = "%s*||%s*", op = "or" }
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

--- Split by comparison operator
---@param expr string Expression to split
---@return string|nil, string|nil, string|nil Left, operator, right
function ExpressionParser._split_comparison_op(expr)
  -- SugarCube aliases (check before standard operators)
  local aliases = {
    { pattern = "%s+is%s+", op = "==" },
    { pattern = "%s+eq%s+", op = "==" },
    { pattern = "%s+neq%s+", op = "!=" },
    { pattern = "%s+gt%s+", op = ">" },
    { pattern = "%s+gte%s+", op = ">=" },
    { pattern = "%s+lt%s+", op = "<" },
    { pattern = "%s+lte%s+", op = "<=" }
  }

  for _, alias in ipairs(aliases) do
    local start_pos, end_pos = expr:find(alias.pattern)
    if start_pos then
      local left = expr:sub(1, start_pos - 1):match("^%s*(.-)%s*$")
      local right = expr:sub(end_pos + 1):match("^%s*(.-)%s*$")
      if left ~= "" and right ~= "" then
        return left, alias.op, right
      end
    end
  end

  -- Standard operators (order matters: check >= before >)
  local operators = { "===", "!==", ">=", "<=", "==", "!=", ">", "<" }

  for _, op in ipairs(operators) do
    local escaped_op = op:gsub("([><=!])", "%%%1")
    local start_pos, end_pos = expr:find("%s*" .. escaped_op .. "%s*")
    if start_pos then
      local left = expr:sub(1, start_pos - 1):match("^%s*(.-)%s*$")
      local right = expr:sub(end_pos + 1):match("^%s*(.-)%s*$")
      if left ~= "" and right ~= "" then
        -- Normalize === to == and !== to !=
        local norm_op = op
        if op == "===" then norm_op = "==" end
        if op == "!==" then norm_op = "!=" end
        return left, norm_op, right
      end
    end
  end

  return nil, nil, nil
end

--------------------------------------------------------------------------------
-- Array Parsing
--------------------------------------------------------------------------------

--- Parse array literal: [1, 2, 3]
---@param expr string Array expression
---@return table AST node
function ExpressionParser._parse_array(expr)
  local content = expr:sub(2, -2) -- Remove [ ]

  if content:match("^%s*$") then
    return ASTBuilder.create_array_literal({})
  end

  local items = {}
  local current = ""
  local depth = 0
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
    elseif char == "[" or char == "(" then
      depth = depth + 1
      current = current .. char
    elseif char == "]" or char == ")" then
      depth = depth - 1
      current = current .. char
    elseif char == "," and depth == 0 then
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
