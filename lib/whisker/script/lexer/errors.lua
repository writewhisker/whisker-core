-- lib/whisker/script/lexer/errors.lua
-- Lexer error handling and recovery

local source_module = require("whisker.script.source")
local codes_module = require("whisker.script.errors.codes")

local SourceFile = source_module.SourceFile
local SourceSpan = source_module.SourceSpan
local ErrorCodes = codes_module.Lexer
local Severity = codes_module.Severity

local M = {}

--- LexerError class
-- Represents a lexer error with full diagnostic information
local LexerError = {}
LexerError.__index = LexerError

--- Create a new lexer error
-- @param code string Error code (e.g., "WSK0001")
-- @param message string Human-readable message
-- @param position SourcePosition Where the error occurred
-- @param options table Optional: { suggestion, end_pos, context, lexeme }
-- @return LexerError
function LexerError.new(code, message, position, options)
  options = options or {}

  local self = setmetatable({
    code = code,
    message = message,
    position = position,
    end_pos = options.end_pos or position,
    suggestion = options.suggestion,
    context = options.context,
    lexeme = options.lexeme or "",
    severity = codes_module.get_severity(code),
  }, LexerError)

  return self
end

--- Create a LexerError from an error code with automatic message
-- @param code string Error code
-- @param position SourcePosition Position in source
-- @param ... string Arguments for message substitution
-- @return LexerError
function LexerError.from_code(code, position, ...)
  local message = codes_module.format_message(code, ...)
  local suggestion = codes_module.get_suggestion(code)

  return LexerError.new(code, message, position, {
    suggestion = suggestion,
  })
end

--- Get the span of this error
-- @return SourceSpan
function LexerError:get_span()
  return SourceSpan.new(self.position, self.end_pos)
end

--- Format error as a simple string
-- @return string
function LexerError:__tostring()
  local loc = string.format("%d:%d", self.position.line, self.position.column)
  return string.format("[%s] %s at %s", self.code, self.message, loc)
end

--- Format error with full diagnostic output
-- @param source_file SourceFile Source file for context
-- @return string Formatted diagnostic
function LexerError:format(source_file)
  local lines = {}

  -- Error header
  table.insert(lines, string.format("Error [%s]: %s", self.code, self.message))
  table.insert(lines, "")

  -- Source snippet
  if source_file then
    local snippet = source_module.format_source_snippet(
      source_file,
      self:get_span(),
      self.lexeme ~= "" and ("this character: " .. self.lexeme) or nil
    )
    table.insert(lines, snippet)
  else
    table.insert(lines, string.format("  --> <source>:%d:%d",
      self.position.line, self.position.column))
  end

  -- Suggestion
  if self.suggestion then
    table.insert(lines, "")
    table.insert(lines, "   = help: " .. self.suggestion)
  end

  return table.concat(lines, "\n")
end

M.LexerError = LexerError

--- ErrorCollector class
-- Collects errors during lexing with configurable limits
local ErrorCollector = {}
ErrorCollector.__index = ErrorCollector

--- Create a new error collector
-- @param options table Optional: { max_errors, source_file }
-- @return ErrorCollector
function ErrorCollector.new(options)
  options = options or {}

  return setmetatable({
    errors = {},
    max_errors = options.max_errors or 100,
    source_file = options.source_file,
    _limit_reached = false,
  }, ErrorCollector)
end

--- Add an error
-- @param error LexerError Error to add
-- @return boolean True if more errors can be collected
function ErrorCollector:add(error)
  if self._limit_reached then
    return false
  end

  table.insert(self.errors, error)

  if #self.errors >= self.max_errors then
    self._limit_reached = true
    -- Add a "too many errors" error
    local last = self.errors[#self.errors]
    table.insert(self.errors, LexerError.from_code(
      ErrorCodes.TOO_MANY_ERRORS,
      last.position
    ))
    return false
  end

  return true
end

--- Create and add an error from components
-- @param code string Error code
-- @param message string Error message
-- @param position SourcePosition Position in source
-- @param options table Optional error options
-- @return boolean True if more errors can be collected
function ErrorCollector:report(code, message, position, options)
  local error = LexerError.new(code, message, position, options)
  return self:add(error)
end

--- Create and add an error from an error code
-- @param code string Error code
-- @param position SourcePosition Position in source
-- @param ... string Arguments for message substitution
-- @return boolean True if more errors can be collected
function ErrorCollector:report_code(code, position, ...)
  local error = LexerError.from_code(code, position, ...)
  return self:add(error)
end

--- Check if error limit has been reached
-- @return boolean
function ErrorCollector:limit_reached()
  return self._limit_reached
end

--- Get all collected errors
-- @return table Array of LexerError
function ErrorCollector:get_errors()
  return self.errors
end

--- Check if any errors were collected
-- @return boolean
function ErrorCollector:has_errors()
  return #self.errors > 0
end

--- Get error count
-- @return number
function ErrorCollector:count()
  return #self.errors
end

--- Clear all errors
function ErrorCollector:clear()
  self.errors = {}
  self._limit_reached = false
end

--- Set the source file for formatting
-- @param source_file SourceFile
function ErrorCollector:set_source_file(source_file)
  self.source_file = source_file
end

--- Format all errors
-- @return string Formatted error report
function ErrorCollector:format_all()
  local formatted = {}

  for i, err in ipairs(self.errors) do
    if i > 1 then
      table.insert(formatted, "")
    end
    table.insert(formatted, err:format(self.source_file))
  end

  return table.concat(formatted, "\n")
end

M.ErrorCollector = ErrorCollector

--- Convenience constructors for common errors
M.errors = {
  unexpected_character = function(char, position)
    return LexerError.from_code(ErrorCodes.UNEXPECTED_CHARACTER, position, char)
  end,

  unterminated_string = function(position, options)
    local err = LexerError.from_code(ErrorCodes.UNTERMINATED_STRING, position)
    if options then
      err.end_pos = options.end_pos or err.end_pos
      err.context = options.context
    end
    return err
  end,

  invalid_number = function(number_text, position)
    return LexerError.from_code(ErrorCodes.INVALID_NUMBER_FORMAT, position, number_text)
  end,

  invalid_escape = function(escape_char, position)
    return LexerError.from_code(ErrorCodes.INVALID_ESCAPE_SEQUENCE, position, escape_char)
  end,

  unexpected_eof = function(position, context)
    local ctx = context and (" " .. context) or ""
    return LexerError.from_code(ErrorCodes.UNEXPECTED_END_OF_INPUT, position, ctx)
  end,

  invalid_variable_name = function(position)
    return LexerError.from_code(ErrorCodes.INVALID_VARIABLE_NAME, position)
  end,
}

--- Module metadata
M._whisker = {
  name = "script.lexer.errors",
  version = "0.1.0",
  description = "Lexer error handling for Whisker Script",
  depends = { "script.source", "script.errors.codes" },
  capability = "script.lexer.errors"
}

return M
