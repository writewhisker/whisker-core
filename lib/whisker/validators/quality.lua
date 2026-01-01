--- WLS 1.0 Quality Validators
-- Validates story quality metrics: branching, complexity, length, nesting
-- @module whisker.validators.quality

local M = {}

local error_codes = require("whisker.validators.error_codes")

--- Default thresholds for quality checks
M.THRESHOLDS = {
  min_branching_factor = 1.5,       -- Minimum average choices per passage
  max_complexity = 100,              -- Maximum story complexity score
  max_passage_words = 1000,          -- Maximum words per passage
  max_nesting_depth = 5,             -- Maximum conditional nesting depth
  max_variable_count = 50,           -- Maximum variables in story
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

--- Count words in text
-- @param text string The text to count words in
-- @return number Word count
local function count_words(text)
  if not text or text == '' then
    return 0
  end

  local count = 0
  for _ in text:gmatch('%S+') do
    count = count + 1
  end
  return count
end

--- Calculate nesting depth of conditionals in content
-- @param content string The content to analyze
-- @return number Maximum nesting depth
local function calculate_nesting_depth(content)
  if not content then
    return 0
  end

  local max_depth = 0
  local current_depth = 0
  local i = 1

  while i <= #content do
    -- Check for {/} closing
    if content:sub(i, i + 2) == '{/}' then
      current_depth = math.max(0, current_depth - 1)
      i = i + 3
    -- Check for opening { that looks like a conditional
    elseif content:sub(i, i) == '{' then
      local rest = content:sub(i + 1)
      -- Check if it's a condition block (starts with $, !, or identifier)
      if rest:match('^%s*[%$!a-zA-Z_]') and not rest:match('^%s*do%s') then
        current_depth = current_depth + 1
        max_depth = math.max(max_depth, current_depth)
      end
      i = i + 1
    else
      i = i + 1
    end
  end

  return max_depth
end

--- Validate branching factor
-- @param story table The story to validate
-- @param threshold number Minimum branching factor
-- @return table Array of validation issues
function M.validate_branching(story, threshold)
  local issues = {}
  threshold = threshold or M.THRESHOLDS.min_branching_factor

  if not story.passages then
    return issues
  end

  local passage_count = 0
  local total_choices = 0

  for _, passage in pairs(story.passages) do
    passage_count = passage_count + 1
    if passage.choices then
      total_choices = total_choices + #passage.choices
    end
  end

  if passage_count > 0 then
    local branching_factor = total_choices / passage_count
    if branching_factor < threshold then
      table.insert(issues, create_issue('WLS-QUA-001', {
        value = string.format('%.2f', branching_factor),
      }, {
        id = 'low_branching',
        threshold = threshold,
        actual = branching_factor,
      }))
    end
  end

  return issues
end

--- Validate story complexity
-- Complexity is calculated as: passages * avg_choices * (1 + variable_count/10)
-- @param story table The story to validate
-- @param threshold number Maximum complexity score
-- @return table Array of validation issues
function M.validate_complexity(story, threshold)
  local issues = {}
  threshold = threshold or M.THRESHOLDS.max_complexity

  if not story.passages then
    return issues
  end

  local passage_count = 0
  local total_choices = 0
  local variable_count = 0

  for _, _ in pairs(story.passages) do
    passage_count = passage_count + 1
  end

  for _, passage in pairs(story.passages) do
    if passage.choices then
      total_choices = total_choices + #passage.choices
    end
  end

  if story.variables then
    for _, _ in pairs(story.variables) do
      variable_count = variable_count + 1
    end
  end

  if passage_count > 0 then
    local avg_choices = total_choices / passage_count
    local complexity = passage_count * avg_choices * (1 + variable_count / 10)

    if complexity > threshold then
      table.insert(issues, create_issue('WLS-QUA-002', {}, {
        id = 'high_complexity',
        threshold = threshold,
        actual = complexity,
      }))
    end
  end

  return issues
end

--- Validate passage length
-- @param story table The story to validate
-- @param threshold number Maximum words per passage
-- @return table Array of validation issues
function M.validate_passage_length(story, threshold)
  local issues = {}
  threshold = threshold or M.THRESHOLDS.max_passage_words

  if not story.passages then
    return issues
  end

  for passage_id, passage in pairs(story.passages) do
    local word_count = count_words(passage.content)
    if word_count > threshold then
      table.insert(issues, create_issue('WLS-QUA-003', {
        passageName = passage.title or passage_id,
        wordCount = word_count,
      }, {
        id = 'long_passage_' .. passage_id,
        passageId = passage_id,
        passageTitle = passage.title,
        wordCount = word_count,
        threshold = threshold,
      }))
    end
  end

  return issues
end

--- Validate conditional nesting depth
-- @param story table The story to validate
-- @param threshold number Maximum nesting depth
-- @return table Array of validation issues
function M.validate_nesting(story, threshold)
  local issues = {}
  threshold = threshold or M.THRESHOLDS.max_nesting_depth

  if not story.passages then
    return issues
  end

  for passage_id, passage in pairs(story.passages) do
    local depth = calculate_nesting_depth(passage.content)
    if depth > threshold then
      table.insert(issues, create_issue('WLS-QUA-004', {
        depth = depth,
      }, {
        id = 'deep_nesting_' .. passage_id,
        passageId = passage_id,
        passageTitle = passage.title,
        depth = depth,
        threshold = threshold,
      }))
    end
  end

  return issues
end

--- Validate variable count
-- @param story table The story to validate
-- @param threshold number Maximum variable count
-- @return table Array of validation issues
function M.validate_variable_count(story, threshold)
  local issues = {}
  threshold = threshold or M.THRESHOLDS.max_variable_count

  if not story.variables then
    return issues
  end

  local count = 0
  for _, _ in pairs(story.variables) do
    count = count + 1
  end

  if count > threshold then
    table.insert(issues, create_issue('WLS-QUA-005', {
      count = count,
    }, {
      id = 'many_variables',
      count = count,
      threshold = threshold,
    }))
  end

  return issues
end

--- Run all quality validators
-- @param story table The story to validate
-- @param options table Optional thresholds
-- @return table Array of validation issues
function M.validate(story, options)
  options = options or {}
  local all_issues = {}

  -- Note: Quality checks are informational and optional
  -- Only run if thresholds are configured or defaults are desired

  local validators = {
    { func = M.validate_branching, threshold = options.min_branching_factor },
    { func = M.validate_complexity, threshold = options.max_complexity },
    { func = M.validate_passage_length, threshold = options.max_passage_words },
    { func = M.validate_nesting, threshold = options.max_nesting_depth },
    { func = M.validate_variable_count, threshold = options.max_variable_count },
  }

  for _, validator in ipairs(validators) do
    local issues = validator.func(story, validator.threshold)
    for _, issue in ipairs(issues) do
      table.insert(all_issues, issue)
    end
  end

  return all_issues
end

return M
