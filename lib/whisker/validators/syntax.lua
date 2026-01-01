--- WLS 1.0 Syntax Validators
-- Validates syntax: parse errors, unmatched braces, Lua keyword balance
-- @module whisker.validators.syntax

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

--- Check for unmatched braces in content
-- @param content string The content to check
-- @return boolean, string True if balanced, false with error message if not
local function check_braces_balance(content)
  if not content then
    return true, nil
  end

  local depth = 0
  local in_string = false
  local string_char = nil

  for i = 1, #content do
    local c = content:sub(i, i)

    -- Track string state
    if not in_string and (c == '"' or c == "'") then
      in_string = true
      string_char = c
    elseif in_string and c == string_char then
      -- Check for escape
      if i > 1 and content:sub(i - 1, i - 1) ~= '\\' then
        in_string = false
        string_char = nil
      end
    end

    -- Count braces outside strings
    if not in_string then
      if c == '{' then
        depth = depth + 1
      elseif c == '}' then
        depth = depth - 1
        if depth < 0 then
          return false, 'Extra closing brace at position ' .. i
        end
      end
    end
  end

  if depth > 0 then
    return false, 'Missing ' .. depth .. ' closing brace(s)'
  end

  return true, nil
end

--- Lua keywords that need balancing
local LUA_OPENERS = {
  ['function'] = 'end',
  ['if'] = 'end',
  ['for'] = 'end',
  ['while'] = 'end',
  ['do'] = 'end',
  ['repeat'] = 'until',
}

--- Check for unmatched Lua keywords
-- @param script string The script to check
-- @return boolean, string True if balanced, false with error message if not
local function check_lua_keywords(script)
  if not script then
    return true, nil
  end

  -- Stack to track openers
  local stack = {}

  -- Simple tokenization (won't handle all edge cases but covers common ones)
  for word in script:gmatch('[a-zA-Z_][a-zA-Z0-9_]*') do
    if LUA_OPENERS[word] then
      table.insert(stack, { opener = word, closer = LUA_OPENERS[word] })
    elseif word == 'end' or word == 'until' then
      if #stack == 0 then
        return false, 'Unexpected "' .. word .. '"'
      end
      local expected = stack[#stack]
      if expected.closer ~= word then
        return false, 'Expected "' .. expected.closer .. '" but found "' .. word .. '"'
      end
      table.remove(stack)
    elseif word == 'then' or word == 'else' or word == 'elseif' then
      -- These don't change the stack
    end
  end

  if #stack > 0 then
    local unclosed = {}
    for _, item in ipairs(stack) do
      table.insert(unclosed, item.opener)
    end
    return false, 'Unclosed: ' .. table.concat(unclosed, ', ')
  end

  return true, nil
end

--- Validate syntax errors from parser
-- @param story table The story to validate (may contain parse_errors)
-- @return table Array of validation issues
function M.validate_parse_errors(story)
  local issues = {}

  -- Check if story has parse errors attached
  if story.parse_errors then
    for _, err in ipairs(story.parse_errors) do
      local passage_name = err.passage or 'unknown'
      table.insert(issues, create_issue('WLS-SYN-001', {
        passageName = passage_name,
      }, {
        id = 'syntax_error_' .. passage_name,
        passageId = err.passageId,
        passageTitle = passage_name,
        line = err.line,
        column = err.column,
        errorMessage = err.message,
      }))
    end
  end

  return issues
end

--- Validate brace balance in stylesheets
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_stylesheets(story)
  local issues = {}

  if not story.stylesheets then
    return issues
  end

  for i, stylesheet in ipairs(story.stylesheets) do
    local balanced, err = check_braces_balance(stylesheet.content or stylesheet)
    if not balanced then
      table.insert(issues, create_issue('WLS-SYN-002', {}, {
        id = 'unmatched_braces_stylesheet_' .. i,
        stylesheetIndex = i,
        errorMessage = err,
      }))
    end
  end

  return issues
end

--- Validate Lua keyword balance in scripts
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_scripts_keywords(story)
  local issues = {}

  -- Check global scripts
  if story.scripts then
    for i, script in ipairs(story.scripts) do
      local script_content = type(script) == 'table' and script.content or script
      local balanced, err = check_lua_keywords(script_content)
      if not balanced then
        table.insert(issues, create_issue('WLS-SYN-003', {}, {
          id = 'unmatched_keywords_script_' .. i,
          scriptIndex = i,
          errorMessage = err,
        }))
      end
    end
  end

  -- Check passage onEnterScripts
  if story.passages then
    for passage_id, passage in pairs(story.passages) do
      if passage.onEnterScript then
        local balanced, err = check_lua_keywords(passage.onEnterScript)
        if not balanced then
          table.insert(issues, create_issue('WLS-SYN-003', {}, {
            id = 'unmatched_keywords_' .. passage_id,
            passageId = passage_id,
            passageTitle = passage.title,
            errorMessage = err,
          }))
        end
      end
    end
  end

  return issues
end

--- Run all syntax validators
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate(story)
  local all_issues = {}

  local validators = {
    M.validate_parse_errors,
    M.validate_stylesheets,
    M.validate_scripts_keywords,
  }

  for _, validator in ipairs(validators) do
    local issues = validator(story)
    for _, issue in ipairs(issues) do
      table.insert(all_issues, issue)
    end
  end

  return all_issues
end

return M
