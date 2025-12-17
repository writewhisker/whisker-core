-- lib/whisker/script/source.lua
-- Source position and span tracking for error reporting

local M = {}

--- SourcePosition class
-- Tracks a position within source code (line, column, offset)
local SourcePosition = {}
SourcePosition.__index = SourcePosition

--- Create a new source position
-- @param line number Line number (1-indexed)
-- @param column number Column number (1-indexed)
-- @param offset number Byte offset from start of source (0-indexed)
-- @return SourcePosition
function SourcePosition.new(line, column, offset)
  return setmetatable({
    line = line or 1,
    column = column or 1,
    offset = offset or 0
  }, SourcePosition)
end

--- Clone this position
-- @return SourcePosition A copy of this position
function SourcePosition:clone()
  return SourcePosition.new(self.line, self.column, self.offset)
end

--- Advance position by one character
-- @param char string The character being advanced over
-- @return SourcePosition New position after advancement
function SourcePosition:advance(char)
  local new = self:clone()
  new.offset = new.offset + 1
  if char == '\n' then
    new.line = new.line + 1
    new.column = 1
  elseif char == '\t' then
    -- Tabs advance to next 8-column boundary
    new.column = new.column + (8 - ((new.column - 1) % 8))
  else
    new.column = new.column + 1
  end
  return new
end

--- Advance position for a newline
-- @return SourcePosition New position at start of next line
function SourcePosition:advance_line()
  return self:advance('\n')
end

--- String representation
-- @return string "line:column"
function SourcePosition:__tostring()
  return string.format("%d:%d", self.line, self.column)
end

--- Equality comparison
-- @param other SourcePosition
-- @return boolean
function SourcePosition:__eq(other)
  return self.line == other.line
     and self.column == other.column
     and self.offset == other.offset
end

M.SourcePosition = SourcePosition

--- SourceSpan class
-- Represents a range of source code from start to end position
local SourceSpan = {}
SourceSpan.__index = SourceSpan

--- Create a new source span
-- @param start_pos SourcePosition Start position
-- @param end_pos SourcePosition End position
-- @return SourceSpan
function SourceSpan.new(start_pos, end_pos)
  return setmetatable({
    start = start_pos,
    end_pos = end_pos or start_pos:clone()
  }, SourceSpan)
end

--- Convenience constructor from two positions
-- @param start_pos SourcePosition
-- @param end_pos SourcePosition
-- @return SourceSpan
function SourceSpan.from_positions(start_pos, end_pos)
  return SourceSpan.new(start_pos, end_pos)
end

--- Merge two spans into one covering both
-- @param other SourceSpan
-- @return SourceSpan Span covering both inputs
function SourceSpan:merge(other)
  local start_pos, end_pos

  -- Find earliest start
  if self.start.offset <= other.start.offset then
    start_pos = self.start:clone()
  else
    start_pos = other.start:clone()
  end

  -- Find latest end
  if self.end_pos.offset >= other.end_pos.offset then
    end_pos = self.end_pos:clone()
  else
    end_pos = other.end_pos:clone()
  end

  return SourceSpan.new(start_pos, end_pos)
end

--- Check if span contains a position
-- @param position SourcePosition
-- @return boolean
function SourceSpan:contains(position)
  return position.offset >= self.start.offset
     and position.offset <= self.end_pos.offset
end

--- Get the length of the span in bytes
-- @return number
function SourceSpan:length()
  return self.end_pos.offset - self.start.offset
end

--- String representation
-- @return string "start-end"
function SourceSpan:__tostring()
  return string.format("%s-%s", tostring(self.start), tostring(self.end_pos))
end

M.SourceSpan = SourceSpan

--- SourceLocation class
-- Associates a span with a file path
local SourceLocation = {}
SourceLocation.__index = SourceLocation

--- Create a new source location
-- @param path string File path
-- @param span SourceSpan Source span
-- @return SourceLocation
function SourceLocation.new(path, span)
  return setmetatable({
    path = path or "<unknown>",
    span = span
  }, SourceLocation)
end

--- String representation
-- @return string "path:line:column"
function SourceLocation:__tostring()
  if self.span then
    return string.format("%s:%s", self.path, tostring(self.span.start))
  end
  return self.path
end

M.SourceLocation = SourceLocation

--- SourceFile class
-- Represents a source file with content and line access
local SourceFile = {}
SourceFile.__index = SourceFile

--- Create a new source file
-- @param path string File path
-- @param content string File content
-- @return SourceFile
function SourceFile.new(path, content)
  local self = setmetatable({
    path = path or "<unknown>",
    content = content or "",
    _lines = nil  -- Lazy-loaded line array
  }, SourceFile)
  return self
end

--- Get array of lines (lazy-loaded)
-- @return table Array of line strings
function SourceFile:_get_lines()
  if self._lines then
    return self._lines
  end

  self._lines = {}
  local start = 1
  while start <= #self.content do
    local newline_pos = self.content:find('\n', start, true)
    if newline_pos then
      table.insert(self._lines, self.content:sub(start, newline_pos - 1))
      start = newline_pos + 1
    else
      -- Last line without trailing newline
      table.insert(self._lines, self.content:sub(start))
      break
    end
  end

  -- Handle trailing newline (adds empty line)
  if #self.content > 0 and self.content:sub(-1) == '\n' then
    table.insert(self._lines, "")
  end

  return self._lines
end

--- Get a specific line by number
-- @param line_number number Line number (1-indexed)
-- @return string|nil Line content or nil if out of range
function SourceFile:get_line(line_number)
  local lines = self:_get_lines()
  if line_number < 1 or line_number > #lines then
    return nil
  end
  return lines[line_number]
end

--- Get surrounding context lines
-- @param position SourcePosition Position to get context for
-- @param context_lines number Number of lines before/after to include
-- @return table Array of {line_number, content} pairs
function SourceFile:get_context(position, context_lines)
  context_lines = context_lines or 2
  local lines = self:_get_lines()
  local result = {}

  local start_line = math.max(1, position.line - context_lines)
  local end_line = math.min(#lines, position.line + context_lines)

  for i = start_line, end_line do
    table.insert(result, { line_number = i, content = lines[i] })
  end

  return result
end

--- Get total number of lines
-- @return number
function SourceFile:line_count()
  return #self:_get_lines()
end

M.SourceFile = SourceFile

--- Format a source snippet for error reporting
-- Produces Rust-style error output with line numbers and underlining
-- @param source_file SourceFile Source file
-- @param span SourceSpan Span to highlight
-- @param message string Message to display under highlight
-- @return string Formatted snippet
function M.format_source_snippet(source_file, span, message)
  local lines = {}
  local line_num = span.start.line
  local line = source_file:get_line(line_num)

  if not line then
    return string.format("  --> %s:%d:%d\n   | <line not available>",
      source_file.path, span.start.line, span.start.column)
  end

  -- Calculate gutter width for line numbers
  local gutter_width = #tostring(line_num) + 1

  -- Location header
  table.insert(lines, string.format(
    "  --> %s:%d:%d",
    source_file.path, span.start.line, span.start.column
  ))

  -- Empty gutter line
  table.insert(lines, string.rep(" ", gutter_width) .. " |")

  -- Source line with line number
  table.insert(lines, string.format(
    "%" .. gutter_width .. "d | %s",
    line_num, line
  ))

  -- Underline calculation
  local underline_start = span.start.column
  local underline_length = 1

  -- If span is on same line, calculate length
  if span.end_pos.line == span.start.line then
    underline_length = math.max(1, span.end_pos.column - span.start.column)
  else
    -- Span extends to end of line
    underline_length = math.max(1, #line - span.start.column + 1)
  end

  -- Build underline with message
  local prefix = string.rep(" ", gutter_width) .. " | "
  local spacing = string.rep(" ", underline_start - 1)
  local carets = string.rep("^", underline_length)

  if message and #message > 0 then
    table.insert(lines, prefix .. spacing .. carets .. " " .. message)
  else
    table.insert(lines, prefix .. spacing .. carets)
  end

  return table.concat(lines, "\n")
end

--- Module metadata
M._whisker = {
  name = "script.source",
  version = "0.1.0",
  description = "Source position and span tracking for Whisker Script",
  depends = {},
  capability = "script.source"
}

return M
