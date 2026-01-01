--- WLS 1.0 Expression Validators
-- Validates expressions: empty expressions, unclosed blocks, operator issues
-- @module whisker.validators.expressions

local M = {}

local error_codes = require("whisker.validators.error_codes")

--- Create a validation issue
local function create_issue(code, context, extra)
  local def = error_codes.get_error_code(code)
  if not def then
    return nil
  end

  local issue = {
    id = (extra and extra.id) or (def.name .. '_' .. os.time()),
    code = code,
    severity = def.severity,
    category = def.category,
    message = error_codes.format_message(code, context),
    description = def.description,
    context = context,
    fixable = (extra and extra.fixable) or false,
  }

  if extra then
    for k, v in pairs(extra) do
      if k ~= 'id' and k ~= 'fixable' then
        issue[k] = v
      end
    end
  end

  return issue
end

--- Valid operators in WLS expressions
local VALID_OPERATORS = {
  -- Comparison
  ['=='] = true, ['!='] = true, ['~='] = true,
  ['<'] = true, ['>'] = true, ['<='] = true, ['>='] = true,
  -- Arithmetic
  ['+'] = true, ['-'] = true, ['*'] = true, ['/'] = true, ['%'] = true,
  -- Logical
  ['and'] = true, ['or'] = true, ['not'] = true,
  -- Assignment
  ['='] = true,
}

--- Check for empty expressions in content
-- @param content string The content to check
-- @param passage_id string The passage ID
-- @param passage_title string The passage title
-- @return table Array of issues
local function check_empty_expressions(content, passage_id, passage_title)
  local issues = {}

  if not content then
    return issues
  end

  -- Check for empty ${} interpolations
  if content:match('%${%s*}') then
    table.insert(issues, create_issue('WLS-EXP-001', {}, {
      id = 'empty_expr_' .. passage_id,
      passageId = passage_id,
      passageTitle = passage_title,
    }))
  end

  -- Check for empty {} condition blocks (but not {/})
  for match in content:gmatch('{([^}/]*)}') do
    if match:match('^%s*$') then
      table.insert(issues, create_issue('WLS-EXP-001', {}, {
        id = 'empty_cond_' .. passage_id,
        passageId = passage_id,
        passageTitle = passage_title,
      }))
      break
    end
  end

  return issues
end

--- Check for unclosed conditional blocks
-- @param content string The content to check
-- @param passage_id string The passage ID
-- @param passage_title string The passage title
-- @return table Array of issues
local function check_unclosed_blocks(content, passage_id, passage_title)
  local issues = {}

  if not content then
    return issues
  end

  -- Count opening { and closing {/}
  -- This is a simplified check - proper parsing would be more accurate
  local depth = 0
  local i = 1
  while i <= #content do
    -- Check for {/} closing
    if content:sub(i, i + 2) == '{/}' then
      depth = depth - 1
      i = i + 3
    -- Check for opening { followed by $ or identifier (condition)
    elseif content:sub(i, i) == '{' then
      local rest = content:sub(i + 1)
      -- Check if it's a condition block (starts with $, !, or identifier)
      if rest:match('^%s*[%$!a-zA-Z_]') then
        depth = depth + 1
      end
      i = i + 1
    else
      i = i + 1
    end
  end

  if depth > 0 then
    table.insert(issues, create_issue('WLS-EXP-002', {}, {
      id = 'unclosed_block_' .. passage_id,
      passageId = passage_id,
      passageTitle = passage_title,
    }))
  end

  return issues
end

--- Check for assignment in condition (= instead of ==)
-- @param expr string The expression to check
-- @param context_info table Context information
-- @return table|nil Issue if found
local function check_assignment_in_condition(expr, context_info)
  if not expr then
    return nil
  end

  -- Look for single = that's not part of ==, !=, <=, >=
  -- This pattern finds = not preceded or followed by =, !, <, >
  local cleaned = expr:gsub('==', '  ')
  cleaned = cleaned:gsub('!=', '  ')
  cleaned = cleaned:gsub('~=', '  ')
  cleaned = cleaned:gsub('<=', '  ')
  cleaned = cleaned:gsub('>=', '  ')

  if cleaned:match('[^=!<>]=[^=]') or cleaned:match('^=[^=]') then
    return create_issue('WLS-EXP-003', {}, {
      id = 'assign_in_cond_' .. (context_info.passageId or 'unknown'),
      passageId = context_info.passageId,
      passageTitle = context_info.passageTitle,
    })
  end

  return nil
end

--- Check for missing operands
-- @param expr string The expression to check
-- @param context_info table Context information
-- @return table|nil Issue if found
local function check_missing_operands(expr, context_info)
  if not expr then
    return nil
  end

  -- Check for operators at start/end or double operators
  local patterns = {
    '^%s*[+*/%^]',           -- Operator at start (except -)
    '[+%-%*/%%^]%s*$',       -- Operator at end
    '[+%-%*/%%^]%s*[+%-%*/%%^]', -- Double operators
  }

  for _, pattern in ipairs(patterns) do
    if expr:match(pattern) then
      return create_issue('WLS-EXP-004', {}, {
        id = 'missing_operand_' .. (context_info.passageId or 'unknown'),
        passageId = context_info.passageId,
        passageTitle = context_info.passageTitle,
      })
    end
  end

  return nil
end

--- Check for invalid operators
-- @param expr string The expression to check
-- @param context_info table Context information
-- @return table|nil Issue if found
local function check_invalid_operators(expr, context_info)
  if not expr then
    return nil
  end

  -- Common mistakes
  local invalid_patterns = {
    { pattern = '&&', expected = 'and' },
    { pattern = '||', expected = 'or' },
    { pattern = '===', expected = '==' },
    { pattern = '!==', expected = '~=' },
  }

  for _, inv in ipairs(invalid_patterns) do
    if expr:find(inv.pattern, 1, true) then
      return create_issue('WLS-EXP-005', {
        operator = inv.pattern,
      }, {
        id = 'invalid_op_' .. (context_info.passageId or 'unknown'),
        passageId = context_info.passageId,
        passageTitle = context_info.passageTitle,
        suggestion = 'Use "' .. inv.expected .. '" instead',
      })
    end
  end

  return nil
end

--- Check for unmatched parentheses
-- @param expr string The expression to check
-- @param context_info table Context information
-- @return table|nil Issue if found
local function check_unmatched_parens(expr, context_info)
  if not expr then
    return nil
  end

  local depth = 0
  for i = 1, #expr do
    local c = expr:sub(i, i)
    if c == '(' then
      depth = depth + 1
    elseif c == ')' then
      depth = depth - 1
      if depth < 0 then
        return create_issue('WLS-EXP-006', {}, {
          id = 'unmatched_paren_' .. (context_info.passageId or 'unknown'),
          passageId = context_info.passageId,
          passageTitle = context_info.passageTitle,
        })
      end
    end
  end

  if depth > 0 then
    return create_issue('WLS-EXP-006', {}, {
      id = 'unmatched_paren_' .. (context_info.passageId or 'unknown'),
      passageId = context_info.passageId,
      passageTitle = context_info.passageTitle,
    })
  end

  return nil
end

--- Check for incomplete expressions
-- @param expr string The expression to check
-- @param context_info table Context information
-- @return table|nil Issue if found
local function check_incomplete_expression(expr, context_info)
  if not expr then
    return nil
  end

  -- Check for trailing comparison operators without right operand
  if expr:match('[=!<>]%s*$') then
    return create_issue('WLS-EXP-007', {}, {
      id = 'incomplete_expr_' .. (context_info.passageId or 'unknown'),
      passageId = context_info.passageId,
      passageTitle = context_info.passageTitle,
    })
  end

  return nil
end

--- Validate expressions in story
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate(story)
  local issues = {}

  if not story.passages then
    return issues
  end

  for passage_id, passage in pairs(story.passages) do
    local context_info = {
      passageId = passage_id,
      passageTitle = passage.title,
    }

    -- Check content for expression issues
    if passage.content then
      -- Empty expressions
      for _, issue in ipairs(check_empty_expressions(passage.content, passage_id, passage.title)) do
        table.insert(issues, issue)
      end

      -- Unclosed blocks
      for _, issue in ipairs(check_unclosed_blocks(passage.content, passage_id, passage.title)) do
        table.insert(issues, issue)
      end
    end

    -- Check choice conditions
    if passage.choices then
      for _, choice in ipairs(passage.choices) do
        if choice.condition then
          -- Assignment in condition (warning)
          local issue = check_assignment_in_condition(choice.condition, context_info)
          if issue then
            table.insert(issues, issue)
          end

          -- Missing operands
          issue = check_missing_operands(choice.condition, context_info)
          if issue then
            table.insert(issues, issue)
          end

          -- Invalid operators
          issue = check_invalid_operators(choice.condition, context_info)
          if issue then
            table.insert(issues, issue)
          end

          -- Unmatched parentheses
          issue = check_unmatched_parens(choice.condition, context_info)
          if issue then
            table.insert(issues, issue)
          end

          -- Incomplete expression
          issue = check_incomplete_expression(choice.condition, context_info)
          if issue then
            table.insert(issues, issue)
          end
        end
      end
    end
  end

  return issues
end

return M
