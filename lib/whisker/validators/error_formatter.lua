--- WLS 1.0 Error Formatter
-- Provides rich error messages with source context
-- WLS 1.0 Gap 6: Developer Experience
-- @module whisker.validators.error_formatter

local M = {}

--- Default formatting options
M.DEFAULT_OPTIONS = {
  context_lines_before = 2,
  context_lines_after = 0,
  include_suggestion = true,
  include_doc_link = true,
  doc_base_url = 'https://wls.whisker.dev/errors',
  use_colors = false,
}

--- ANSI color codes for terminal output
local COLORS = {
  reset = '\27[0m',
  red = '\27[31m',
  yellow = '\27[33m',
  blue = '\27[34m',
  cyan = '\27[36m',
  gray = '\27[90m',
  bold = '\27[1m',
}

--- Get severity color
-- @param severity string The severity level
-- @param use_colors boolean Whether to use colors
-- @return string The color code
local function get_severity_color(severity, use_colors)
  if not use_colors then return '' end
  if severity == 'error' then return COLORS.red
  elseif severity == 'warning' then return COLORS.yellow
  elseif severity == 'info' then return COLORS.blue
  else return ''
  end
end

--- Split source into lines
-- @param source string The source content
-- @return table Array of lines
local function get_source_lines(source)
  local lines = {}
  for line in (source .. '\n'):gmatch('([^\n]*)\n') do
    table.insert(lines, line)
  end
  return lines
end

--- Generate caret indicator
-- @param column number The column position
-- @param length number The error length (default 1)
-- @return string The caret indicator
local function generate_caret(column, length)
  length = length or 1
  local spaces = string.rep(' ', math.max(0, column - 1))
  local carets = string.rep('^', math.max(1, length))
  return spaces .. carets
end

--- Format line number with padding
-- @param line_num number The line number
-- @param max_line_num number The maximum line number
-- @return string Padded line number
local function format_line_number(line_num, max_line_num)
  local max_digits = #tostring(max_line_num)
  return string.format('%' .. max_digits .. 'd', line_num)
end

--- Format a single validation issue with source context
-- @param issue table The validation issue
-- @param source string The source content
-- @param options table Formatting options (optional)
-- @return string Formatted error message
function M.format_error(issue, source, options)
  options = options or {}
  local opts = {}
  for k, v in pairs(M.DEFAULT_OPTIONS) do opts[k] = v end
  for k, v in pairs(options) do opts[k] = v end

  local lines = {}
  local source_lines = get_source_lines(source)

  local color = opts.use_colors and get_severity_color(issue.severity, true) or ''
  local reset = opts.use_colors and COLORS.reset or ''
  local gray = opts.use_colors and COLORS.gray or ''
  local cyan = opts.use_colors and COLORS.cyan or ''

  -- Header: error code, message, location
  local error_code = issue.code or 'WLS-ERR'
  local line = issue.line or 1
  local column = issue.column or 1

  table.insert(lines, string.format('%s%s: %s at line %d, column %d%s',
    color, error_code, issue.message, line, column, reset))
  table.insert(lines, '')

  -- Source context
  local start_line = math.max(1, line - opts.context_lines_before)
  local end_line = math.min(#source_lines, line + opts.context_lines_after)
  local max_line_num = end_line

  for i = start_line, end_line do
    local line_content = source_lines[i] or ''
    local line_num_str = format_line_number(i, max_line_num)
    local prefix = i == line and (color .. '>' .. reset) or ' '
    table.insert(lines, string.format('%s%s %s |%s %s',
      gray, prefix, line_num_str, reset, line_content))

    -- Add caret indicator on the error line
    if i == line then
      local padding = string.rep(' ', #line_num_str + 4) -- account for prefix and "| "
      local caret = generate_caret(column, issue.length)
      table.insert(lines, padding .. color .. caret .. reset)

      -- Add explanation if available
      if issue.details then
        table.insert(lines, padding .. color .. issue.details .. reset)
      end
    end
  end

  table.insert(lines, '')

  -- Suggestion
  if opts.include_suggestion and issue.suggestion then
    table.insert(lines, cyan .. 'Suggestion: ' .. issue.suggestion .. reset)
  end

  -- Documentation link
  if opts.include_doc_link and issue.code then
    table.insert(lines, gray .. 'See: ' .. opts.doc_base_url .. '/' .. issue.code .. reset)
  end

  return table.concat(lines, '\n')
end

--- Format multiple validation issues
-- @param issues table Array of validation issues
-- @param source string The source content
-- @param options table Formatting options (optional)
-- @return string Formatted error messages
function M.format_errors(issues, source, options)
  if #issues == 0 then
    return ''
  end

  local formatted = {}
  for _, issue in ipairs(issues) do
    table.insert(formatted, M.format_error(issue, source, options))
  end

  local summary = M.format_summary(issues, options)
  return table.concat(formatted, '\n\n') .. '\n\n' .. summary
end

--- Format error summary
-- @param issues table Array of validation issues
-- @param options table Formatting options (optional)
-- @return string Summary string
function M.format_summary(issues, options)
  options = options or {}
  local opts = {}
  for k, v in pairs(M.DEFAULT_OPTIONS) do opts[k] = v end
  for k, v in pairs(options) do opts[k] = v end

  local errors = 0
  local warnings = 0
  local infos = 0

  for _, issue in ipairs(issues) do
    if issue.severity == 'error' then errors = errors + 1
    elseif issue.severity == 'warning' then warnings = warnings + 1
    elseif issue.severity == 'info' then infos = infos + 1
    end
  end

  local parts = {}

  if errors > 0 then
    local c = opts.use_colors and COLORS.red or ''
    local r = opts.use_colors and COLORS.reset or ''
    table.insert(parts, string.format('%s%d error%s%s', c, errors, errors ~= 1 and 's' or '', r))
  end

  if warnings > 0 then
    local c = opts.use_colors and COLORS.yellow or ''
    local r = opts.use_colors and COLORS.reset or ''
    table.insert(parts, string.format('%s%d warning%s%s', c, warnings, warnings ~= 1 and 's' or '', r))
  end

  if infos > 0 then
    local c = opts.use_colors and COLORS.blue or ''
    local r = opts.use_colors and COLORS.reset or ''
    table.insert(parts, string.format('%s%d info%s', c, infos, r))
  end

  if #parts == 0 then
    return 'No issues found.'
  end

  return 'Found ' .. table.concat(parts, ', ') .. '.'
end

--- Format error as JSON for tool integration
-- @param issue table The validation issue
-- @param source string The source content
-- @param options table Formatting options (optional)
-- @return table JSON-compatible table
function M.format_error_as_json(issue, source, options)
  options = options or {}
  local opts = {}
  for k, v in pairs(M.DEFAULT_OPTIONS) do opts[k] = v end
  for k, v in pairs(options) do opts[k] = v end

  local source_lines = get_source_lines(source)
  local line = issue.line or 1

  local start_line = math.max(1, line - opts.context_lines_before)
  local end_line = math.min(#source_lines, line + opts.context_lines_after)
  local context_lines = {}
  for i = start_line, end_line do
    table.insert(context_lines, source_lines[i] or '')
  end
  local context = table.concat(context_lines, '\n')

  return {
    code = issue.code,
    message = issue.message,
    severity = issue.severity,
    location = {
      line = issue.line,
      column = issue.column,
      length = issue.length,
      passageName = issue.passage_name,
    },
    context = context,
    suggestion = issue.suggestion,
    docUrl = opts.include_doc_link and issue.code
      and (opts.doc_base_url .. '/' .. issue.code) or nil,
  }
end

--- Calculate Levenshtein distance between two strings
-- @param a string First string
-- @param b string Second string
-- @return number The edit distance
local function levenshtein_distance(a, b)
  local la, lb = #a, #b
  local matrix = {}

  for i = 0, lb do
    matrix[i] = { [0] = i }
  end

  for j = 0, la do
    matrix[0][j] = j
  end

  for i = 1, lb do
    for j = 1, la do
      if b:sub(i, i) == a:sub(j, j) then
        matrix[i][j] = matrix[i - 1][j - 1]
      else
        matrix[i][j] = math.min(
          matrix[i - 1][j - 1] + 1, -- substitution
          matrix[i][j - 1] + 1,     -- insertion
          matrix[i - 1][j] + 1      -- deletion
        )
      end
    end
  end

  return matrix[lb][la]
end

--- Suggest similar names for typos
-- @param input string The input string
-- @param candidates table Array of candidate strings
-- @param max_distance number Maximum edit distance (default 3)
-- @return string|nil The best match or nil if none found
function M.suggest_similar(input, candidates, max_distance)
  max_distance = max_distance or 3
  local best_match = nil
  local best_distance = max_distance + 1

  for _, candidate in ipairs(candidates) do
    local distance = levenshtein_distance(input:lower(), candidate:lower())
    if distance < best_distance then
      best_distance = distance
      best_match = candidate
    end
  end

  return best_distance <= max_distance and best_match or nil
end

return M
