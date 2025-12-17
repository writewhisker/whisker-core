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

--- Parser error codes (WSK01xx)
M.Parser = {
  EXPECTED_PASSAGE_DECL = "WSK0100",
  EXPECTED_PASSAGE_NAME = "WSK0101",
  EXPECTED_CLOSING_BRACKET = "WSK0102",
  EXPECTED_CLOSING_PAREN = "WSK0103",
  EXPECTED_CLOSING_BRACE = "WSK0104",
  EXPECTED_EXPRESSION = "WSK0105",
  EXPECTED_STATEMENT = "WSK0106",
  EXPECTED_IDENTIFIER = "WSK0107",
  EXPECTED_NEWLINE = "WSK0108",
  UNEXPECTED_TOKEN = "WSK0109",
  UNEXPECTED_INDENT = "WSK0110",
  EXPECTED_DIVERT_TARGET = "WSK0111",
  EXPECTED_CHOICE_TEXT = "WSK0112",
  EXPECTED_CONDITION = "WSK0113",
  INVALID_ASSIGNMENT_TARGET = "WSK0114",
  TOO_MANY_PARSER_ERRORS = "WSK0115",
}

--- Semantic error codes (WSK02xx)
M.Semantic = {
  -- Reference resolution errors
  UNDEFINED_PASSAGE = "WSK0200",
  UNDEFINED_VARIABLE = "WSK0201",
  UNDEFINED_FUNCTION = "WSK0202",

  -- Duplicate definition errors
  DUPLICATE_PASSAGE = "WSK0210",
  DUPLICATE_VARIABLE = "WSK0211",

  -- Variable usage errors
  UNINITIALIZED_VARIABLE = "WSK0220",

  -- Function errors
  WRONG_ARGUMENT_COUNT = "WSK0230",

  -- Control flow errors
  TUNNEL_RETURN_OUTSIDE_PASSAGE = "WSK0240",

  -- Warnings
  UNREACHABLE_PASSAGE = "WSK0250",
  UNUSED_VARIABLE = "WSK0251",
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

  -- Parser errors
  [M.Parser.EXPECTED_PASSAGE_DECL] = {
    message = "Expected passage declaration (::)",
    severity = M.Severity.ERROR,
    suggestion = "Start a passage with ':: PassageName'",
  },
  [M.Parser.EXPECTED_PASSAGE_NAME] = {
    message = "Expected passage name after '::'",
    severity = M.Severity.ERROR,
    suggestion = "Provide a name for the passage, e.g., ':: MyPassage'",
  },
  [M.Parser.EXPECTED_CLOSING_BRACKET] = {
    message = "Expected closing bracket ']'",
    severity = M.Severity.ERROR,
    suggestion = "Add ']' to close the bracket",
  },
  [M.Parser.EXPECTED_CLOSING_PAREN] = {
    message = "Expected closing parenthesis ')'",
    severity = M.Severity.ERROR,
    suggestion = "Add ')' to close the parenthesis",
  },
  [M.Parser.EXPECTED_CLOSING_BRACE] = {
    message = "Expected closing brace '}'",
    severity = M.Severity.ERROR,
    suggestion = "Add '}' to close the brace",
  },
  [M.Parser.EXPECTED_EXPRESSION] = {
    message = "Expected expression",
    severity = M.Severity.ERROR,
    suggestion = "Provide a value, variable, or expression",
  },
  [M.Parser.EXPECTED_STATEMENT] = {
    message = "Expected statement",
    severity = M.Severity.ERROR,
    suggestion = "Expected text, choice, assignment, or control flow",
  },
  [M.Parser.EXPECTED_IDENTIFIER] = {
    message = "Expected identifier",
    severity = M.Severity.ERROR,
    suggestion = "Provide a valid name (letters, numbers, underscores)",
  },
  [M.Parser.EXPECTED_NEWLINE] = {
    message = "Expected newline",
    severity = M.Severity.ERROR,
    suggestion = "Add a line break here",
  },
  [M.Parser.UNEXPECTED_TOKEN] = {
    message = "Unexpected token '%1'",
    severity = M.Severity.ERROR,
    suggestion = "Check for syntax errors near this location",
  },
  [M.Parser.UNEXPECTED_INDENT] = {
    message = "Unexpected indentation",
    severity = M.Severity.ERROR,
    suggestion = "Check your indentation levels",
  },
  [M.Parser.EXPECTED_DIVERT_TARGET] = {
    message = "Expected passage name after '->'",
    severity = M.Severity.ERROR,
    suggestion = "Provide the target passage name, e.g., '-> NextPassage'",
  },
  [M.Parser.EXPECTED_CHOICE_TEXT] = {
    message = "Expected choice text after '+'",
    severity = M.Severity.ERROR,
    suggestion = "Add the text for this choice option",
  },
  [M.Parser.EXPECTED_CONDITION] = {
    message = "Expected condition expression",
    severity = M.Severity.ERROR,
    suggestion = "Provide a condition, e.g., '$variable > 5'",
  },
  [M.Parser.INVALID_ASSIGNMENT_TARGET] = {
    message = "Invalid assignment target",
    severity = M.Severity.ERROR,
    suggestion = "Can only assign to variables ($name)",
  },
  [M.Parser.TOO_MANY_PARSER_ERRORS] = {
    message = "Too many parser errors, stopping",
    severity = M.Severity.ERROR,
    suggestion = "Fix the errors above and try again",
  },

  -- Semantic errors
  [M.Semantic.UNDEFINED_PASSAGE] = {
    message = "Undefined passage '%1'",
    severity = M.Severity.ERROR,
    suggestion = "Check the passage name for typos, or create a passage with this name",
  },
  [M.Semantic.UNDEFINED_VARIABLE] = {
    message = "Undefined variable '$%1'",
    severity = M.Severity.ERROR,
    suggestion = "Make sure this variable is defined before use",
  },
  [M.Semantic.UNDEFINED_FUNCTION] = {
    message = "Unknown function '%1'",
    severity = M.Severity.ERROR,
    suggestion = "Check the function name for typos",
  },
  [M.Semantic.DUPLICATE_PASSAGE] = {
    message = "Duplicate passage '%1' (first defined at line %2)",
    severity = M.Severity.ERROR,
    suggestion = "Rename one of the passages to avoid conflicts",
  },
  [M.Semantic.DUPLICATE_VARIABLE] = {
    message = "Variable '$%1' already defined at line %2",
    severity = M.Severity.ERROR,
    suggestion = "Use a different variable name or reuse the existing one",
  },
  [M.Semantic.UNINITIALIZED_VARIABLE] = {
    message = "Variable '$%1' may be used before initialization",
    severity = M.Severity.WARNING,
    suggestion = "Assign a value to this variable before reading it",
  },
  [M.Semantic.WRONG_ARGUMENT_COUNT] = {
    message = "Function '%1' expects %2 argument(s) but got %3",
    severity = M.Severity.ERROR,
    suggestion = "Check the function documentation for correct usage",
  },
  [M.Semantic.TUNNEL_RETURN_OUTSIDE_PASSAGE] = {
    message = "Tunnel return (->->) outside of passage",
    severity = M.Severity.ERROR,
    suggestion = "Tunnel returns can only be used inside a passage body",
  },
  [M.Semantic.UNREACHABLE_PASSAGE] = {
    message = "Passage '%1' is never referenced",
    severity = M.Severity.WARNING,
    suggestion = "Add a divert to this passage or remove it if unused",
  },
  [M.Semantic.UNUSED_VARIABLE] = {
    message = "Variable '$%1' is defined but never used",
    severity = M.Severity.WARNING,
    suggestion = "Remove this variable or use it somewhere in your story",
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
