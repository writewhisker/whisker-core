--- WLS 1.0 Variable Validators
-- Validates variable usage: undefined, unused, invalid names
-- @module whisker.validators.variables

local M = {}

local error_codes = require("whisker.validators.error_codes")

--- Lua reserved keywords
local LUA_KEYWORDS = {
  ['and'] = true, ['break'] = true, ['do'] = true, ['else'] = true,
  ['elseif'] = true, ['end'] = true, ['false'] = true, ['for'] = true,
  ['function'] = true, ['if'] = true, ['in'] = true, ['local'] = true,
  ['nil'] = true, ['not'] = true, ['or'] = true, ['repeat'] = true,
  ['return'] = true, ['then'] = true, ['true'] = true, ['until'] = true,
  ['while'] = true,
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

--- Extract variable names from code
-- @param code string The code to analyze
-- @return table Set of variable names
local function extract_variables(code)
  local variables = {}

  if not code then
    return variables
  end

  -- Match word patterns (variable-like identifiers)
  for var_name in code:gmatch('[a-zA-Z_][a-zA-Z0-9_]*') do
    if not LUA_KEYWORDS[var_name] then
      variables[var_name] = true
    end
  end

  return variables
end

--- Extract script blocks from content
-- Finds {do ...} blocks in passage content
-- @param content string The content to analyze
-- @return table Array of script strings
local function extract_scripts(content)
  local scripts = {}

  if not content then
    return scripts
  end

  -- Match {do ...} blocks
  for script in content:gmatch("{%s*do%s+([^}]+)}") do
    table.insert(scripts, script)
  end

  return scripts
end

--- Extract variable references from content
-- Finds $varname patterns in passage content
-- @param content string The content to analyze
-- @return table Set of variable names
local function extract_var_refs(content)
  local variables = {}

  if not content then
    return variables
  end

  -- Match $varname patterns (simple interpolation)
  for var_name in content:gmatch("%$([a-zA-Z_][a-zA-Z0-9_]*)") do
    if not LUA_KEYWORDS[var_name] then
      variables[var_name] = true
    end
  end

  return variables
end

--- Validate undefined variables
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_undefined(story)
  local issues = {}

  if not story.passages then
    return issues
  end

  -- Collect defined variables
  local defined = {}
  if story.variables then
    for name, _ in pairs(story.variables) do
      defined[name] = true
    end
  end

  -- Collect referenced variables per passage
  for passage_id, passage in pairs(story.passages) do
    local referenced = {}

    -- Check onEnterScript
    if passage.onEnterScript then
      for var_name, _ in pairs(extract_variables(passage.onEnterScript)) do
        referenced[var_name] = {
          passageId = passage_id,
          passageTitle = passage.title,
          context = 'passage onEnter script',
        }
      end
    end

    -- Check {do ...} script blocks in content
    if passage.content then
      for _, script in ipairs(extract_scripts(passage.content)) do
        for var_name, _ in pairs(extract_variables(script)) do
          referenced[var_name] = {
            passageId = passage_id,
            passageTitle = passage.title,
            context = 'passage script block',
          }
        end
      end

      -- Check $varname references in content
      for var_name, _ in pairs(extract_var_refs(passage.content)) do
        referenced[var_name] = {
          passageId = passage_id,
          passageTitle = passage.title,
          context = 'passage content',
        }
      end
    end

    -- Check choice conditions and actions
    if passage.choices then
      for _, choice in ipairs(passage.choices) do
        if choice.condition then
          for var_name, _ in pairs(extract_variables(choice.condition)) do
            referenced[var_name] = {
              passageId = passage_id,
              passageTitle = passage.title,
              context = 'choice "' .. (choice.text or '') .. '" condition',
            }
          end
        end

        if choice.action then
          for var_name, _ in pairs(extract_variables(choice.action)) do
            referenced[var_name] = {
              passageId = passage_id,
              passageTitle = passage.title,
              context = 'choice "' .. (choice.text or '') .. '" action',
            }
          end
        end
      end
    end

    -- Check for undefined
    for var_name, ref in pairs(referenced) do
      if not defined[var_name] then
        table.insert(issues, create_issue('WLS-VAR-001', {
          variableName = var_name,
        }, {
          id = 'undefined_var_' .. var_name .. '_' .. passage_id,
          passageId = ref.passageId,
          passageTitle = ref.passageTitle,
          variableName = var_name,
          fixable = true,
          fixDescription = 'Add variable "' .. var_name .. '" to story definitions',
        }))
      end
    end
  end

  return issues
end

--- Validate unused variables
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_unused(story)
  local issues = {}

  if not story.variables or not story.passages then
    return issues
  end

  -- Collect referenced variables
  local referenced = {}

  for _, passage in pairs(story.passages) do
    -- Check onEnterScript
    if passage.onEnterScript then
      for var_name, _ in pairs(extract_variables(passage.onEnterScript)) do
        referenced[var_name] = true
      end
    end

    -- Check {do ...} script blocks in content
    if passage.content then
      for _, script in ipairs(extract_scripts(passage.content)) do
        for var_name, _ in pairs(extract_variables(script)) do
          referenced[var_name] = true
        end
      end

      -- Check $varname references in content
      for var_name, _ in pairs(extract_var_refs(passage.content)) do
        referenced[var_name] = true
      end
    end

    -- Check choice conditions and actions
    if passage.choices then
      for _, choice in ipairs(passage.choices) do
        if choice.condition then
          for var_name, _ in pairs(extract_variables(choice.condition)) do
            referenced[var_name] = true
          end
        end

        if choice.action then
          for var_name, _ in pairs(extract_variables(choice.action)) do
            referenced[var_name] = true
          end
        end
      end
    end
  end

  -- Find unused (skip invalid variables)
  for var_name, var_data in pairs(story.variables) do
    -- Skip invalid variables (they have their own error)
    local is_invalid = type(var_data) == "table" and var_data.invalid
    if not is_invalid and not referenced[var_name] then
      table.insert(issues, create_issue('WLS-VAR-002', {
        variableName = var_name,
      }, {
        id = 'unused_var_' .. var_name,
        variableName = var_name,
        fixable = true,
        fixDescription = 'Remove variable "' .. var_name .. '" from story definitions',
      }))
    end
  end

  return issues
end

--- Validate variable names
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_names(story)
  local issues = {}

  if not story.variables then
    return issues
  end

  for var_name, var_data in pairs(story.variables) do
    -- Check if marked as invalid by parser, or name pattern is invalid
    local is_marked_invalid = type(var_data) == "table" and var_data.invalid
    local is_pattern_invalid = not var_name:match('^[a-zA-Z_][a-zA-Z0-9_]*$')

    if is_marked_invalid or is_pattern_invalid then
      table.insert(issues, create_issue('WLS-VAR-003', {
        variableName = var_name,
      }, {
        id = 'invalid_var_name_' .. var_name,
        variableName = var_name,
      }))
    end
  end

  return issues
end

--- Validate reserved variable prefixes
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_reserved_prefix(story)
  local issues = {}

  if not story.variables then
    return issues
  end

  for var_name, _ in pairs(story.variables) do
    -- Check for reserved prefixes: whisker_ or __
    if var_name:match('^whisker_') or var_name:match('^__') then
      table.insert(issues, create_issue('WLS-VAR-004', {
        variableName = var_name,
      }, {
        id = 'reserved_prefix_' .. var_name,
        variableName = var_name,
      }))
    end
  end

  return issues
end

--- Validate temp variable shadowing story variables
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_shadowing(story)
  local issues = {}

  if not story.variables or not story.passages then
    return issues
  end

  -- Get story variable names
  local story_vars = {}
  for var_name, _ in pairs(story.variables) do
    story_vars[var_name] = true
  end

  -- Check for temp variables that shadow story variables
  for passage_id, passage in pairs(story.passages) do
    -- Check content for _varname patterns
    if passage.content then
      for temp_name in passage.content:gmatch('_([a-zA-Z_][a-zA-Z0-9_]*)') do
        if story_vars[temp_name] then
          table.insert(issues, create_issue('WLS-VAR-005', {
            variableName = temp_name,
          }, {
            id = 'shadow_' .. temp_name .. '_' .. passage_id,
            variableName = temp_name,
            passageId = passage_id,
            passageTitle = passage.title,
          }))
        end
      end
    end
  end

  return issues
end

--- Validate lone dollar signs
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_lone_dollar(story)
  local issues = {}

  if not story.passages then
    return issues
  end

  for passage_id, passage in pairs(story.passages) do
    if passage.content then
      -- Look for $ not followed by a valid variable name character
      -- Pattern: $ followed by non-alphanumeric/underscore or end of string
      local i = 1
      while i <= #passage.content do
        if passage.content:sub(i, i) == '$' then
          local next_char = passage.content:sub(i + 1, i + 1)
          if next_char == '' or not next_char:match('[a-zA-Z_]') then
            table.insert(issues, create_issue('WLS-VAR-006', {}, {
              id = 'lone_dollar_' .. passage_id .. '_' .. i,
              passageId = passage_id,
              passageTitle = passage.title,
              position = i,
            }))
            break -- Only report once per passage
          end
        end
        i = i + 1
      end
    end
  end

  return issues
end

--- Validate unclosed interpolations
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_unclosed_interpolation(story)
  local issues = {}

  if not story.passages then
    return issues
  end

  for passage_id, passage in pairs(story.passages) do
    if passage.content then
      -- Look for ${ without matching }
      local i = 1
      while i <= #passage.content - 1 do
        if passage.content:sub(i, i + 1) == '${' then
          -- Find closing }
          local depth = 1
          local j = i + 2
          while j <= #passage.content and depth > 0 do
            local c = passage.content:sub(j, j)
            if c == '{' then
              depth = depth + 1
            elseif c == '}' then
              depth = depth - 1
            end
            j = j + 1
          end

          if depth > 0 then
            table.insert(issues, create_issue('WLS-VAR-007', {}, {
              id = 'unclosed_interp_' .. passage_id,
              passageId = passage_id,
              passageTitle = passage.title,
            }))
            break -- Only report once per passage
          end

          i = j
        else
          i = i + 1
        end
      end
    end
  end

  return issues
end

--- Validate temp variables used across passages
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_temp_cross_passage(story)
  local issues = {}

  if not story.passages then
    return issues
  end

  -- Track where temp variables are defined (first occurrence)
  local temp_defined_in = {}

  for passage_id, passage in pairs(story.passages) do
    if passage.content then
      -- Look for temp variable assignments: _varname =
      for temp_name in passage.content:gmatch('_([a-zA-Z_][a-zA-Z0-9_]*)%s*=') do
        if not temp_defined_in[temp_name] then
          temp_defined_in[temp_name] = passage_id
        end
      end
    end

    -- Check choice actions
    if passage.choices then
      for _, choice in ipairs(passage.choices) do
        if choice.action then
          for temp_name in choice.action:gmatch('_([a-zA-Z_][a-zA-Z0-9_]*)%s*=') do
            if not temp_defined_in[temp_name] then
              temp_defined_in[temp_name] = passage_id
            end
          end
        end
      end
    end
  end

  -- Now check for usage in other passages
  for passage_id, passage in pairs(story.passages) do
    if passage.content then
      -- Look for temp variable usage (not assignment)
      for temp_name in passage.content:gmatch('_([a-zA-Z_][a-zA-Z0-9_]*)') do
        local defined_in = temp_defined_in[temp_name]
        if defined_in and defined_in ~= passage_id then
          -- Check if this is an assignment (which is OK, it's a new temp)
          if not passage.content:match('_' .. temp_name .. '%s*=') then
            table.insert(issues, create_issue('WLS-VAR-008', {
              variableName = '_' .. temp_name,
            }, {
              id = 'temp_cross_' .. temp_name .. '_' .. passage_id,
              variableName = '_' .. temp_name,
              passageId = passage_id,
              passageTitle = passage.title,
              definedIn = defined_in,
            }))
          end
        end
      end
    end
  end

  return issues
end

--- Run all variable validators
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate(story)
  local all_issues = {}

  local validators = {
    M.validate_names,
    M.validate_undefined,
    M.validate_unused,
    M.validate_reserved_prefix,
    M.validate_shadowing,
    M.validate_lone_dollar,
    M.validate_unclosed_interpolation,
    M.validate_temp_cross_passage,
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
