--- WLS 1.0 Script Validators
-- Validates scripts: empty scripts, syntax errors, unsafe functions
-- @module whisker.validators.scripts

local M = {}

local error_codes = require("whisker.validators.error_codes")
local compat = require("whisker.compat")

--- Default thresholds
M.THRESHOLDS = {
  max_script_size = 32 * 1024, -- 32KB
}

--- Potentially unsafe functions in sandboxed environments
M.UNSAFE_FUNCTIONS = {
  'loadfile', 'loadstring', 'load', 'dofile',
  'os.execute', 'os.exit', 'os.remove', 'os.rename', 'os.setenv',
  'io.open', 'io.close', 'io.read', 'io.write', 'io.popen',
  'io.input', 'io.output', 'io.lines', 'io.flush',
  'debug.debug', 'debug.getfenv', 'debug.setfenv',
  'debug.getinfo', 'debug.getlocal', 'debug.setlocal',
  'debug.getmetatable', 'debug.setmetatable',
  'debug.getupvalue', 'debug.setupvalue',
  'debug.traceback', 'debug.sethook', 'debug.gethook',
  'rawget', 'rawset', 'rawequal',
  'getfenv', 'setfenv',
  'require', 'package.loadlib',
}

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

--- Format bytes as human readable
local function format_size(bytes)
  if bytes < 1024 then
    return bytes .. ' B'
  elseif bytes < 1024 * 1024 then
    return string.format('%.1f KB', bytes / 1024)
  else
    return string.format('%.1f MB', bytes / (1024 * 1024))
  end
end

--- Check if script is empty or whitespace only
-- @param script string The script to check
-- @return boolean True if empty
local function is_empty_script(script)
  if not script then
    return true
  end
  return script:match('^%s*$') ~= nil
end

--- Check for syntax errors using loadstring/load
-- @param script string The script to check
-- @return boolean, string True if valid, or false with error message
local function check_syntax(script)
  if not script or script == '' then
    return true, nil
  end

  -- Use loadstring/load to check syntax (Lua 5.1-5.4 compatible)
  local func, err = compat.loadstring(script)
  if not func then
    -- Clean up error message
    local clean_err = err
    if clean_err then
      clean_err = clean_err:gsub('^%[string ".*"%]:', '')
    end
    return false, clean_err
  end

  return true, nil
end

--- Find unsafe function calls in script
-- @param script string The script to analyze
-- @return table Array of unsafe function names found
local function find_unsafe_functions(script)
  if not script then
    return {}
  end

  local found = {}

  for _, func_name in ipairs(M.UNSAFE_FUNCTIONS) do
    -- Escape dots for pattern matching
    local pattern = func_name:gsub('%.', '%%.')
    -- Look for function call pattern
    if script:match(pattern .. '%s*%(') or script:match(pattern .. '%s*%"') then
      table.insert(found, func_name)
    end
  end

  return found
end

--- Validate empty scripts
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_empty_scripts(story)
  local issues = {}

  -- Check global scripts
  if story.scripts then
    for i, script in ipairs(story.scripts) do
      local script_content = type(script) == 'table' and script.content or script
      if is_empty_script(script_content) then
        table.insert(issues, create_issue('WLS-SCR-001', {}, {
          id = 'empty_script_' .. i,
          scriptIndex = i,
          fixable = true,
          fixDescription = 'Remove empty script',
        }))
      end
    end
  end

  -- Check passage onEnterScripts
  if story.passages then
    for passage_id, passage in pairs(story.passages) do
      if is_empty_script(passage.onEnterScript) and passage.onEnterScript ~= nil then
        table.insert(issues, create_issue('WLS-SCR-001', {}, {
          id = 'empty_script_' .. passage_id,
          passageId = passage_id,
          passageTitle = passage.title,
          fixable = true,
          fixDescription = 'Remove empty onEnter script',
        }))
      end
    end
  end

  return issues
end

--- Validate script syntax
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_script_syntax(story)
  local issues = {}

  -- Check global scripts
  if story.scripts then
    for i, script in ipairs(story.scripts) do
      local script_content = type(script) == 'table' and script.content or script
      local valid, err = check_syntax(script_content)
      if not valid then
        table.insert(issues, create_issue('WLS-SCR-002', {}, {
          id = 'script_syntax_' .. i,
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
        local valid, err = check_syntax(passage.onEnterScript)
        if not valid then
          table.insert(issues, create_issue('WLS-SCR-002', {}, {
            id = 'script_syntax_' .. passage_id,
            passageId = passage_id,
            passageTitle = passage.title,
            errorMessage = err,
          }))
        end
      end
    end
  end

  -- Check choice actions (these are typically expressions, not full Lua)
  -- We skip syntax checking for these as they may use WLS expression syntax

  return issues
end

--- Validate unsafe function usage
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_unsafe_functions(story)
  local issues = {}

  -- Check global scripts
  if story.scripts then
    for i, script in ipairs(story.scripts) do
      local script_content = type(script) == 'table' and script.content or script
      local unsafe = find_unsafe_functions(script_content)
      for _, func_name in ipairs(unsafe) do
        table.insert(issues, create_issue('WLS-SCR-003', {
          ['function'] = func_name,
        }, {
          id = 'unsafe_func_' .. i .. '_' .. func_name:gsub('%.', '_'),
          scriptIndex = i,
          functionName = func_name,
        }))
      end
    end
  end

  -- Check passage onEnterScripts
  if story.passages then
    for passage_id, passage in pairs(story.passages) do
      if passage.onEnterScript then
        local unsafe = find_unsafe_functions(passage.onEnterScript)
        for _, func_name in ipairs(unsafe) do
          table.insert(issues, create_issue('WLS-SCR-003', {
            ['function'] = func_name,
          }, {
            id = 'unsafe_func_' .. passage_id .. '_' .. func_name:gsub('%.', '_'),
            passageId = passage_id,
            passageTitle = passage.title,
            functionName = func_name,
          }))
        end
      end
    end
  end

  return issues
end

--- Validate script sizes
-- @param story table The story to validate
-- @param threshold number Maximum script size in bytes
-- @return table Array of validation issues
function M.validate_script_sizes(story, threshold)
  local issues = {}
  threshold = threshold or M.THRESHOLDS.max_script_size

  -- Check global scripts
  if story.scripts then
    for i, script in ipairs(story.scripts) do
      local script_content = type(script) == 'table' and script.content or script
      local size = #(script_content or '')
      if size > threshold then
        table.insert(issues, create_issue('WLS-SCR-004', {
          size = format_size(size),
        }, {
          id = 'large_script_' .. i,
          scriptIndex = i,
          size = size,
          threshold = threshold,
        }))
      end
    end
  end

  -- Check passage onEnterScripts
  if story.passages then
    for passage_id, passage in pairs(story.passages) do
      if passage.onEnterScript then
        local size = #passage.onEnterScript
        if size > threshold then
          table.insert(issues, create_issue('WLS-SCR-004', {
            size = format_size(size),
          }, {
            id = 'large_script_' .. passage_id,
            passageId = passage_id,
            passageTitle = passage.title,
            size = size,
            threshold = threshold,
          }))
        end
      end
    end
  end

  return issues
end

--- Run all script validators
-- @param story table The story to validate
-- @param options table Optional thresholds
-- @return table Array of validation issues
function M.validate(story, options)
  options = options or {}
  local all_issues = {}

  local validators = {
    M.validate_empty_scripts,
    M.validate_script_syntax,
    M.validate_unsafe_functions,
    function(s) return M.validate_script_sizes(s, options.max_script_size) end,
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
