-- lib/whisker/script/lexer/tokens.lua
-- Token type definitions for the Whisker Script lexer

local M = {}

--- Token type enum
-- All token types used by the Whisker Script lexer
local TokenType = {
  -- Structural tokens
  PASSAGE_DECL = "PASSAGE_DECL",   -- ::
  CHOICE = "CHOICE",               -- +
  DIVERT = "DIVERT",               -- ->
  TUNNEL = "TUNNEL",               -- ->->
  THREAD = "THREAD",               -- <-
  ASSIGN = "ASSIGN",               -- ~
  METADATA = "METADATA",           -- @@
  INCLUDE = "INCLUDE",             -- >>

  -- Delimiters
  LBRACE = "LBRACE",               -- {
  RBRACE = "RBRACE",               -- }
  LBRACKET = "LBRACKET",           -- [
  RBRACKET = "RBRACKET",           -- ]
  LPAREN = "LPAREN",               -- (
  RPAREN = "RPAREN",               -- )
  COLON = "COLON",                 -- :
  PIPE = "PIPE",                   -- |
  COMMA = "COMMA",                 -- ,
  DASH = "DASH",                   -- -
  DOT = "DOT",                     -- .

  -- Assignment operators
  EQ = "EQ",                       -- =
  PLUS_EQ = "PLUS_EQ",             -- +=
  MINUS_EQ = "MINUS_EQ",           -- -=
  STAR_EQ = "STAR_EQ",             -- *=
  SLASH_EQ = "SLASH_EQ",           -- /=

  -- Comparison operators
  EQ_EQ = "EQ_EQ",                 -- ==
  BANG_EQ = "BANG_EQ",             -- !=
  LT = "LT",                       -- <
  GT = "GT",                       -- >
  LT_EQ = "LT_EQ",                 -- <=
  GT_EQ = "GT_EQ",                 -- >=

  -- Arithmetic operators
  PLUS = "PLUS",                   -- +
  MINUS = "MINUS",                 -- -
  STAR = "STAR",                   -- *
  SLASH = "SLASH",                 -- /
  PERCENT = "PERCENT",             -- %

  -- Logical operators (keywords)
  AND = "AND",                     -- and
  OR = "OR",                       -- or
  NOT = "NOT",                     -- not

  -- Literals
  TRUE = "TRUE",                   -- true
  FALSE = "FALSE",                 -- false
  NULL = "NULL",                   -- null
  NUMBER = "NUMBER",               -- numeric literal
  STRING = "STRING",               -- string literal

  -- Identifiers and variables
  IDENTIFIER = "IDENTIFIER",       -- passage/function names
  VARIABLE = "VARIABLE",           -- $variable

  -- Narrative content
  TEXT = "TEXT",                   -- narrative text

  -- Keywords
  ELSE = "ELSE",                   -- else
  INCLUDE_KW = "INCLUDE_KW",       -- include
  IMPORT_KW = "IMPORT_KW",         -- import
  AS = "AS",                       -- as
  IF = "IF",                       -- if
  ELIF = "ELIF",                   -- elif

  -- Synthetic tokens
  NEWLINE = "NEWLINE",             -- end of line
  INDENT = "INDENT",               -- increased indentation
  DEDENT = "DEDENT",               -- decreased indentation
  COMMENT = "COMMENT",             -- // comment
  EOF = "EOF",                     -- end of file
  ERROR = "ERROR",                 -- lexer error
}

-- Freeze the TokenType table to catch typos
setmetatable(TokenType, {
  __index = function(_, key)
    error("Unknown token type: " .. tostring(key))
  end,
  __newindex = function()
    error("Cannot modify TokenType enum")
  end
})

M.TokenType = TokenType

--- Keyword lookup table
local keywords = {
  ["and"] = TokenType.AND,
  ["or"] = TokenType.OR,
  ["not"] = TokenType.NOT,
  ["true"] = TokenType.TRUE,
  ["false"] = TokenType.FALSE,
  ["null"] = TokenType.NULL,
  ["else"] = TokenType.ELSE,
  ["include"] = TokenType.INCLUDE_KW,
  ["import"] = TokenType.IMPORT_KW,
  ["as"] = TokenType.AS,
  ["if"] = TokenType.IF,
  ["elif"] = TokenType.ELIF,
}

--- Operator token types (for classification)
local operators = {
  [TokenType.EQ] = true,
  [TokenType.PLUS_EQ] = true,
  [TokenType.MINUS_EQ] = true,
  [TokenType.STAR_EQ] = true,
  [TokenType.SLASH_EQ] = true,
  [TokenType.EQ_EQ] = true,
  [TokenType.BANG_EQ] = true,
  [TokenType.LT] = true,
  [TokenType.GT] = true,
  [TokenType.LT_EQ] = true,
  [TokenType.GT_EQ] = true,
  [TokenType.PLUS] = true,
  [TokenType.MINUS] = true,
  [TokenType.STAR] = true,
  [TokenType.SLASH] = true,
  [TokenType.PERCENT] = true,
  [TokenType.AND] = true,
  [TokenType.OR] = true,
  [TokenType.NOT] = true,
}

--- Literal token types (for classification)
local literals = {
  [TokenType.TRUE] = true,
  [TokenType.FALSE] = true,
  [TokenType.NULL] = true,
  [TokenType.NUMBER] = true,
  [TokenType.STRING] = true,
}

--- Token class
local Token = {}
Token.__index = Token

--- Create a new token
-- @param type string Token type from TokenType enum
-- @param lexeme string Source text that produced this token
-- @param literal any Parsed value (for literals) or nil
-- @param position table Position {line, column, offset} or nil
-- @return table Token instance
function Token.new(type, lexeme, literal, position)
  -- Validate token type exists (will error if not found due to metatable)
  local _ = TokenType[type]

  return setmetatable({
    type = type,
    lexeme = lexeme or "",
    literal = literal,
    pos = position or { line = 1, column = 1, offset = 0 }
  }, Token)
end

--- String representation of token
-- @return string Human-readable token description
function Token:__tostring()
  local pos_str = ""
  if self.pos then
    pos_str = string.format("%d:%d", self.pos.line or 0, self.pos.column or 0)
  end
  return string.format("Token(%s, %q, %s)", self.type, self.lexeme, pos_str)
end

--- Check if token is of a given type
-- @param token_type string Token type to check
-- @return boolean
function Token:is(token_type)
  return self.type == token_type
end

M.Token = Token

--- Check if a lexeme is a keyword
-- @param lexeme string The identifier to check
-- @return string|nil TokenType if keyword, nil otherwise
function M.is_keyword(lexeme)
  return keywords[lexeme]
end

--- Check if a token type is an operator
-- @param token_type string The token type to check
-- @return boolean
function M.is_operator(token_type)
  return operators[token_type] == true
end

--- Check if a token type is a literal
-- @param token_type string The token type to check
-- @return boolean
function M.is_literal(token_type)
  return literals[token_type] == true
end

--- Check if a token type is a structural token
-- @param token_type string The token type to check
-- @return boolean
function M.is_structural(token_type)
  return token_type == TokenType.PASSAGE_DECL
      or token_type == TokenType.CHOICE
      or token_type == TokenType.DIVERT
      or token_type == TokenType.TUNNEL
      or token_type == TokenType.THREAD
      or token_type == TokenType.ASSIGN
      or token_type == TokenType.METADATA
      or token_type == TokenType.INCLUDE
end

--- Get all keywords as a table
-- @return table Keyword lookup table
function M.get_keywords()
  local result = {}
  for k, v in pairs(keywords) do
    result[k] = v
  end
  return result
end

--- Module metadata
M._whisker = {
  name = "script.lexer.tokens",
  version = "0.1.0",
  description = "Token type definitions for Whisker Script",
  depends = {},
  capability = "script.lexer.tokens"
}

return M
