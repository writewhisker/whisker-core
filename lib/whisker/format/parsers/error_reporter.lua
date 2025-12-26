--- Error Reporter
-- Syntax error detection and reporting for parsers
-- @module whisker.format.parsers.error_reporter
-- @author Whisker Core Team
-- @license MIT

local M = {}
M._dependencies = {}

--- Create an error report
-- @param content string Full content being parsed
-- @return table Error reporter instance
function M.new(content)
  local self = setmetatable({}, {__index = M})
  self._content = content
  self._lines = {}
  self._errors = {}
  self._warnings = {}

  -- Split into lines for position lookup
  local line_num = 1
  local pos = 1
  for line in (content .. "\n"):gmatch("([^\n]*)\n") do
    self._lines[line_num] = {
      content = line,
      start = pos,
      ["end"] = pos + #line
    }
    pos = pos + #line + 1
    line_num = line_num + 1
  end

  return self
end

--- Get line number for position
-- @param pos number Character position
-- @return number Line number
function M:get_line_number(pos)
  for num, line in ipairs(self._lines) do
    if pos >= line.start and pos <= line["end"] then
      return num
    end
  end
  return #self._lines
end

--- Get column number for position
-- @param pos number Character position
-- @return number Column number
function M:get_column(pos)
  local line_num = self:get_line_number(pos)
  local line = self._lines[line_num]
  if line then
    return pos - line.start + 1
  end
  return 1
end

--- Add an error
-- @param message string Error message
-- @param pos number Position in content
-- @param length number Length of error region
function M:add_error(message, pos, length)
  local line_num = self:get_line_number(pos)
  local column = self:get_column(pos)

  table.insert(self._errors, {
    type = "error",
    message = message,
    line = line_num,
    column = column,
    position = pos,
    length = length or 1,
    context = self._lines[line_num] and self._lines[line_num].content or ""
  })
end

--- Add a warning
-- @param message string Warning message
-- @param pos number Position in content
-- @param length number Length of warning region
function M:add_warning(message, pos, length)
  local line_num = self:get_line_number(pos)
  local column = self:get_column(pos)

  table.insert(self._warnings, {
    type = "warning",
    message = message,
    line = line_num,
    column = column,
    position = pos,
    length = length or 1,
    context = self._lines[line_num] and self._lines[line_num].content or ""
  })
end

--- Check for common syntax errors
function M:check_common_errors()
  local content = self._content

  -- Unclosed parentheses in macros
  local paren_depth = 0
  local paren_start = nil
  for i = 1, #content do
    local c = content:sub(i, i)
    if c == "(" then
      if paren_depth == 0 then paren_start = i end
      paren_depth = paren_depth + 1
    elseif c == ")" then
      paren_depth = paren_depth - 1
      if paren_depth < 0 then
        self:add_error("Unexpected closing parenthesis", i)
        paren_depth = 0
      end
    end
  end
  if paren_depth > 0 and paren_start then
    self:add_error("Unclosed parenthesis", paren_start)
  end

  -- Unclosed brackets
  local bracket_depth = 0
  local bracket_start = nil
  for i = 1, #content do
    local c = content:sub(i, i)
    if c == "[" then
      if bracket_depth == 0 then bracket_start = i end
      bracket_depth = bracket_depth + 1
    elseif c == "]" then
      bracket_depth = bracket_depth - 1
      if bracket_depth < 0 then
        self:add_error("Unexpected closing bracket", i)
        bracket_depth = 0
      end
    end
  end
  if bracket_depth > 0 and bracket_start then
    self:add_error("Unclosed bracket", bracket_start)
  end

  -- Unclosed angle brackets (for SugarCube macros)
  local angle_depth = 0
  local angle_start = nil
  local in_macro = false
  for i = 1, #content - 1 do
    local c2 = content:sub(i, i + 1)
    if c2 == "<<" then
      if angle_depth == 0 then angle_start = i end
      angle_depth = angle_depth + 1
      in_macro = true
    elseif c2 == ">>" then
      if in_macro then
        angle_depth = angle_depth - 1
        if angle_depth <= 0 then
          in_macro = false
          angle_depth = 0
        end
      end
    end
  end
  if angle_depth > 0 and angle_start then
    self:add_error("Unclosed SugarCube macro", angle_start)
  end

  -- Unclosed strings
  local in_string = false
  local string_char = nil
  local string_start = nil
  for i = 1, #content do
    local c = content:sub(i, i)
    local prev = i > 1 and content:sub(i-1, i-1) or ""

    if not in_string and (c == '"' or c == "'") then
      in_string = true
      string_char = c
      string_start = i
    elseif in_string and c == string_char and prev ~= "\\" then
      in_string = false
    elseif in_string and c == "\n" then
      self:add_error("Unclosed string", string_start)
      in_string = false
    end
  end
  if in_string and string_start then
    self:add_error("Unclosed string at end of content", string_start)
  end

  -- Invalid macro names (Harlowe)
  for pos, name in content:gmatch("()%(([^:%s%(%)]+):") do
    if name:match("[^%w%-_]") then
      self:add_warning("Unusual characters in macro name: " .. name, pos)
    end
  end

  -- Empty macros
  for pos in content:gmatch("()%(%s*%)") do
    self:add_warning("Empty macro", pos)
  end

  -- Unbalanced hooks (Harlowe)
  local hook_depth = 0
  local hook_start = nil
  local in_link = false
  for i = 1, #content do
    local c = content:sub(i, i)
    local c2 = content:sub(i, i + 1)
    if c2 == "[[" then
      in_link = true
    elseif c2 == "]]" then
      in_link = false
    elseif c == "[" and not in_link then
      if hook_depth == 0 then hook_start = i end
      hook_depth = hook_depth + 1
    elseif c == "]" and not in_link then
      hook_depth = hook_depth - 1
    end
  end
  if hook_depth > 0 and hook_start then
    self:add_warning("Possibly unclosed hook", hook_start)
  end
end

--- Format error for display
-- @param error table Error object
-- @return string Formatted error message
function M:format_error(err)
  local msg = string.format(
    "%s:%d:%d: %s: %s",
    "story", err.line, err.column, err.type, err.message
  )

  if err.context and #err.context > 0 then
    msg = msg .. "\n  " .. err.context
    msg = msg .. "\n  " .. string.rep(" ", err.column - 1) .. "^"
  end

  return msg
end

--- Get all errors and warnings
-- @return table Results with errors and warnings
function M:get_results()
  return {
    errors = self._errors,
    warnings = self._warnings,
    has_errors = #self._errors > 0,
    has_warnings = #self._warnings > 0
  }
end

--- Format all errors for display
-- @return string Formatted error messages
function M:format_all()
  local lines = {}
  for _, err in ipairs(self._errors) do
    table.insert(lines, self:format_error(err))
  end
  for _, warn in ipairs(self._warnings) do
    table.insert(lines, self:format_error(warn))
  end
  return table.concat(lines, "\n")
end

return M
