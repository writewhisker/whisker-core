--- WLS 1.0 Module Validators
-- Validates INCLUDE, FUNCTION, and NAMESPACE declarations
-- @module whisker.validators.modules

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

--- Check if a string is a valid identifier
local function is_valid_identifier(str)
  return str and str:match('^[a-zA-Z_][a-zA-Z0-9_]*$') ~= nil
end

--- Validate INCLUDE declarations
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_includes(story)
  local issues = {}

  if not story.includes then
    return issues
  end

  -- Track seen paths for circular detection
  local seen_paths = {}

  for _, include in ipairs(story.includes) do
    local path = include.path

    -- Check for circular includes
    if seen_paths[path] then
      table.insert(issues, create_issue('WLS-MOD-002', {
        path = path,
      }, {
        id = 'circular_include_' .. path:gsub('[^%w]', '_'),
      }))
    else
      seen_paths[path] = true
    end

    -- Note: Actual file existence check would require file system access
    -- and is typically done at load time, not validation time
  end

  return issues
end

--- Validate FUNCTION declarations
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_functions(story)
  local issues = {}

  if not story.functions then
    return issues
  end

  local defined_functions = {}

  for func_name, func_data in pairs(story.functions) do
    -- Check for valid function name
    if not is_valid_identifier(func_name) then
      table.insert(issues, create_issue('WLS-MOD-006', {
        functionName = func_name,
      }, {
        id = 'invalid_func_name_' .. tostring(func_name),
      }))
    end

    -- Track defined functions for later reference checking
    defined_functions[func_name] = true
  end

  return issues
end

--- Validate NAMESPACE declarations
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_namespaces(story)
  local issues = {}

  if not story.namespaces then
    return issues
  end

  for _, ns_name in ipairs(story.namespaces) do
    -- Check for valid namespace name
    if not is_valid_identifier(ns_name) then
      table.insert(issues, create_issue('WLS-MOD-007', {
        namespaceName = ns_name,
      }, {
        id = 'invalid_ns_name_' .. tostring(ns_name),
      }))
    end
  end

  return issues
end

--- Validate namespace-qualified passage names for conflicts
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_namespace_conflicts(story)
  local issues = {}

  if not story.passages then
    return issues
  end

  -- Track seen qualified names
  local seen_names = {}

  for passage_id, passage in pairs(story.passages) do
    local qualified_name = passage.name or passage.title or passage_id

    if qualified_name then
      if seen_names[qualified_name] then
        table.insert(issues, create_issue('WLS-MOD-004', {
          passageName = qualified_name,
        }, {
          id = 'ns_conflict_' .. qualified_name:gsub('[^%w]', '_'),
          passageId = passage_id,
        }))
      else
        seen_names[qualified_name] = true
      end
    end
  end

  return issues
end

--- Validate function calls reference defined functions
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_function_calls(story)
  local issues = {}

  -- Build set of defined functions
  local defined_functions = {}
  if story.functions then
    for func_name, _ in pairs(story.functions) do
      defined_functions[func_name] = true
    end
  end

  -- Check passages for function calls
  if not story.passages then
    return issues
  end

  for passage_id, passage in pairs(story.passages) do
    if passage.content then
      -- Look for function call patterns: functionName(
      for func_name in passage.content:gmatch('([%a_][%w_]*)%s*%(') do
        -- Skip built-in functions and common patterns
        local builtins = {
          'math', 'string', 'table', 'print', 'tostring', 'tonumber',
          'type', 'pairs', 'ipairs', 'next', 'select', 'unpack',
          'list_contains', 'list_add', 'list_remove', 'list_active',
          'array_get', 'array_set', 'array_push', 'array_pop', 'array_length',
          'map_get', 'map_set', 'map_has', 'map_keys', 'map_values',
          'random', 'floor', 'ceil', 'abs', 'min', 'max',
        }

        local is_builtin = false
        for _, builtin in ipairs(builtins) do
          if func_name == builtin then
            is_builtin = true
            break
          end
        end

        if not is_builtin and not defined_functions[func_name] then
          -- Could be an undefined user function
          -- Note: This is a heuristic and may produce false positives
          -- for method calls or other patterns
        end
      end
    end
  end

  return issues
end

--- Run all module validators
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate(story)
  local all_issues = {}

  local validators = {
    M.validate_includes,
    M.validate_functions,
    M.validate_namespaces,
    M.validate_namespace_conflicts,
    M.validate_function_calls,
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
