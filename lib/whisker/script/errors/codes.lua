-- lib/whisker/script/errors/codes.lua
-- Error code definitions for Whisker Script compiler

local M = {}

--- Error severity levels
M.Severity = {
  ERROR = "error",
  WARNING = "warning",
  HINT = "hint",
}

--- Lexer error codes (WSK00xx)
M.Lexer = {
  UNEXPECTED_CHARACTER = "WSK0001",
  UNTERMINATED_STRING = "WSK0002",
  INVALID_NUMBER_FORMAT = "WSK0003",
  INVALID_ESCAPE_SEQUENCE = "WSK0004",
  UNEXPECTED_END_OF_INPUT = "WSK0005",
  INVALID_VARIABLE_NAME = "WSK0006",
  TOO_MANY_ERRORS = "WSK0007",
}

--- Parser error codes (WSK01xx - reserved for future stages)
M.Parser = {
  -- Reserved for Stage 09+
}

--- Semantic error codes (WSK02xx - reserved for future stages)
M.Semantic = {
  -- Reserved for Stage 20+
}

--- Generator error codes (WSK03xx - reserved for future stages)
M.Generator = {
  -- Reserved for Stage 22+
}

--- Error message templates
-- Use %1, %2, etc. for substitutions
M.Messages = {
  -- Lexer errors
  [M.Lexer.UNEXPECTED_CHARACTER] = {
    message = "Unexpected character '%1'",
    severity = M.Severity.ERROR,
    suggestion = "Remove this character or check for typos",
  },
  [M.Lexer.UNTERMINATED_STRING] = {
    message = "Unterminated string",
    severity = M.Severity.ERROR,
    suggestion = "Add a closing quote to complete the string",
  },
  [M.Lexer.INVALID_NUMBER_FORMAT] = {
    message = "Invalid number format: '%1'",
    severity = M.Severity.ERROR,
    suggestion = "Check the number format (e.g., 123, 3.14, 1e10)",
  },
  [M.Lexer.INVALID_ESCAPE_SEQUENCE] = {
    message = "Invalid escape sequence '\\%1'",
    severity = M.Severity.ERROR,
    suggestion = "Valid escapes: \\n (newline), \\t (tab), \\\\ (backslash), \\\" (quote)",
  },
  [M.Lexer.UNEXPECTED_END_OF_INPUT] = {
    message = "Unexpected end of input%1",
    severity = M.Severity.ERROR,
    suggestion = "Check for unclosed strings, brackets, or incomplete expressions",
  },
  [M.Lexer.INVALID_VARIABLE_NAME] = {
    message = "Invalid variable name after '$'",
    severity = M.Severity.ERROR,
    suggestion = "Variable names must start with a letter or underscore",
  },
  [M.Lexer.TOO_MANY_ERRORS] = {
    message = "Too many errors, stopping lexer",
    severity = M.Severity.ERROR,
    suggestion = "Fix the errors above and try again",
  },
}

--- Format an error message with substitutions
-- @param code string Error code
-- @param ... string Substitution values
-- @return string Formatted message
function M.format_message(code, ...)
  local template = M.Messages[code]
  if not template then
    return "Unknown error: " .. code
  end

  local message = template.message
  local args = {...}

  for i, arg in ipairs(args) do
    message = message:gsub("%%" .. i, tostring(arg or ""))
  end

  -- Remove unreplaced placeholders
  message = message:gsub("%%%d+", "")

  return message
end

--- Get suggestion for an error code
-- @param code string Error code
-- @return string|nil Suggestion text
function M.get_suggestion(code)
  local template = M.Messages[code]
  return template and template.suggestion
end

--- Get severity for an error code
-- @param code string Error code
-- @return string Severity level
function M.get_severity(code)
  local template = M.Messages[code]
  return template and template.severity or M.Severity.ERROR
end

--- Module metadata
M._whisker = {
  name = "script.errors.codes",
  version = "0.1.0",
  description = "Error code definitions for Whisker Script",
  depends = {},
  capability = "script.errors.codes"
}

return M
