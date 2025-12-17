-- lib/whisker/script/lexer/scanner.lua
-- Character-level scanner for the Whisker Script lexer

local source_module = require("whisker.script.source")
local SourcePosition = source_module.SourcePosition

local M = {}

--- Scanner class
-- Provides character-level navigation with position tracking
local Scanner = {}
Scanner.__index = Scanner

--- Create a new scanner
-- @param source string Source text to scan
-- @return Scanner
function Scanner.new(source)
  return setmetatable({
    source = source or "",
    pos = SourcePosition.new(1, 1, 0),
    marks = {}  -- Stack for nested marks
  }, Scanner)
end

--- Check if at end of source
-- @return boolean
function Scanner:at_end()
  return self.pos.offset >= #self.source
end

--- Peek at character at current position + offset
-- @param offset number Offset from current position (default 0)
-- @return string|nil Character or nil if past end
function Scanner:peek(offset)
  offset = offset or 0
  local idx = self.pos.offset + offset + 1  -- Lua 1-indexed
  if idx < 1 or idx > #self.source then
    return nil
  end
  return self.source:sub(idx, idx)
end

--- Get current character (convenience for peek(0))
-- @return string|nil
function Scanner:current()
  return self:peek(0)
end

--- Advance to next character
-- @return string|nil The consumed character or nil if at end
function Scanner:advance()
  if self:at_end() then
    return nil
  end
  local char = self:peek()
  self.pos = self.pos:advance(char)
  return char
end

--- Match single character and advance if it matches
-- @param expected string Expected character
-- @return boolean True if matched and advanced
function Scanner:match(expected)
  if self:at_end() then
    return false
  end
  if self:peek() ~= expected then
    return false
  end
  self:advance()
  return true
end

--- Match a multi-character string
-- @param str string String to match
-- @return boolean True if entire string matched and advanced
function Scanner:match_string(str)
  -- Check if we have enough characters
  if self.pos.offset + #str > #self.source then
    return false
  end

  -- Check each character
  for i = 1, #str do
    if self:peek(i - 1) ~= str:sub(i, i) then
      return false
    end
  end

  -- Advance past the matched string
  for _ = 1, #str do
    self:advance()
  end

  return true
end

--- Match while predicate is true
-- @param predicate function(char) -> boolean
-- @return string Matched characters
function Scanner:match_while(predicate)
  local chars = {}
  while not self:at_end() do
    local char = self:peek()
    if not predicate(char) then
      break
    end
    table.insert(chars, char)
    self:advance()
  end
  return table.concat(chars)
end

--- Get current position
-- @return SourcePosition
function Scanner:get_position()
  return self.pos:clone()
end

--- Mark current position for potential backtracking
function Scanner:mark()
  table.insert(self.marks, self.pos:clone())
end

--- Reset to most recent mark
function Scanner:reset_to_mark()
  assert(#self.marks > 0, "No mark to reset to")
  self.pos = table.remove(self.marks)
end

--- Pop mark without resetting (commit to current path)
function Scanner:pop_mark()
  assert(#self.marks > 0, "No mark to pop")
  table.remove(self.marks)
end

--- Get lexeme text from most recent mark to current position
-- @return string
function Scanner:get_lexeme_since_mark()
  assert(#self.marks > 0, "No mark to get lexeme from")
  local mark = self.marks[#self.marks]
  return self.source:sub(mark.offset + 1, self.pos.offset)
end

--- Skip whitespace (not newlines)
function Scanner:skip_whitespace()
  while not self:at_end() do
    local char = self:peek()
    if char == ' ' or char == '\t' then
      self:advance()
    else
      break
    end
  end
end

--- Skip to end of line
function Scanner:skip_to_eol()
  while not self:at_end() and self:peek() ~= '\n' do
    self:advance()
  end
end

M.Scanner = Scanner

-- Character classification functions

--- Check if character is alphabetic or underscore
-- @param char string|nil
-- @return boolean
function M.is_alpha(char)
  if not char then return false end
  return (char >= 'a' and char <= 'z')
      or (char >= 'A' and char <= 'Z')
      or char == '_'
end

--- Check if character is a digit
-- @param char string|nil
-- @return boolean
function M.is_digit(char)
  if not char then return false end
  return char >= '0' and char <= '9'
end

--- Check if character is alphanumeric (alpha or digit)
-- @param char string|nil
-- @return boolean
function M.is_alphanumeric(char)
  return M.is_alpha(char) or M.is_digit(char)
end

--- Check if character is whitespace (not newline)
-- @param char string|nil
-- @return boolean
function M.is_whitespace(char)
  if not char then return false end
  return char == ' ' or char == '\t'
end

--- Check if character is a newline
-- @param char string|nil
-- @return boolean
function M.is_newline(char)
  if not char then return false end
  return char == '\n' or char == '\r'
end

--- Check if character is valid identifier start
-- @param char string|nil
-- @return boolean
function M.is_identifier_start(char)
  return M.is_alpha(char)
end

--- Check if character is valid identifier continuation
-- @param char string|nil
-- @return boolean
function M.is_identifier_char(char)
  return M.is_alphanumeric(char)
end

--- Module metadata
M._whisker = {
  name = "script.lexer.scanner",
  version = "0.1.0",
  description = "Character-level scanner for Whisker Script lexer",
  depends = { "script.source" },
  capability = "script.lexer.scanner"
}

return M
