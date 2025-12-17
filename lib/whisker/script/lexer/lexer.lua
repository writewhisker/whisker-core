-- lib/whisker/script/lexer/lexer.lua
-- Core lexer implementation for Whisker Script

local tokens_module = require("whisker.script.lexer.tokens")
local scanner_module = require("whisker.script.lexer.scanner")
local stream_module = require("whisker.script.lexer.stream")
local source_module = require("whisker.script.source")

local TokenType = tokens_module.TokenType
local Token = tokens_module.Token
local Scanner = scanner_module.Scanner
local TokenStream = stream_module.TokenStream
local SourceSpan = source_module.SourceSpan

local M = {}

--- Lexer class
-- Tokenizes Whisker Script source into a token stream
local Lexer = {}
Lexer.__index = Lexer

--- Create a new lexer
-- @param source string Source text to tokenize
-- @return Lexer
function Lexer.new(source)
  local self = setmetatable({
    scanner = Scanner.new(source),
    source = source or "",
    tokens = {},
    errors = {},
    indent_stack = { 0 },  -- Stack of indentation levels
    at_line_start = true,  -- Track if we're at start of line
    pending_tokens = {},   -- Tokens to emit before next scan
  }, Lexer)
  return self
end

--- Tokenize entire source and return token stream
-- @return TokenStream
function Lexer:tokenize()
  self.tokens = {}
  self.errors = {}

  while true do
    local token = self:next_token()
    table.insert(self.tokens, token)
    if token.type == TokenType.EOF then
      break
    end
  end

  return TokenStream.new(self.tokens)
end

--- Get next token
-- @return Token
function Lexer:next_token()
  -- Emit any pending tokens first (from indentation changes)
  if #self.pending_tokens > 0 then
    return table.remove(self.pending_tokens, 1)
  end

  -- Handle indentation at line start
  if self.at_line_start then
    local indent_tokens = self:handle_line_start()
    if #indent_tokens > 0 then
      -- Queue all but first, return first
      for i = 2, #indent_tokens do
        table.insert(self.pending_tokens, indent_tokens[i])
      end
      return indent_tokens[1]
    end
  end

  -- Skip whitespace (not at line start)
  self:skip_whitespace()

  -- Check for end of file
  if self.scanner:at_end() then
    -- Emit remaining DEDENTs
    local dedents = self:emit_remaining_dedents()
    if #dedents > 0 then
      for i = 2, #dedents do
        table.insert(self.pending_tokens, dedents[i])
      end
      -- Queue EOF after dedents
      table.insert(self.pending_tokens, self:make_token(TokenType.EOF))
      return dedents[1]
    end
    return self:make_token(TokenType.EOF)
  end

  -- Handle newline
  if scanner_module.is_newline(self.scanner:peek()) then
    return self:newline()
  end

  -- Handle comments
  if self.scanner:peek() == '/' and self.scanner:peek(1) == '/' then
    return self:comment()
  end

  -- Get next character for dispatch
  local char = self.scanner:peek()

  -- Mark position for token
  self.scanner:mark()
  local start_pos = self.scanner:get_position()

  -- This stage implements basic token recognition
  -- Full structural/expression tokens are in stages 6-7
  -- For now, just recognize basic patterns

  -- Identifier or keyword
  if scanner_module.is_identifier_start(char) then
    return self:identifier_or_keyword()
  end

  -- Number literal
  if scanner_module.is_digit(char) then
    return self:number()
  end

  -- String literal
  if char == '"' or char == "'" then
    return self:string()
  end

  -- Variable reference
  if char == '$' then
    return self:variable()
  end

  -- Single character tokens (basic set for core lexer)
  -- Full structural tokens will be added in Stage 6
  local single_char_tokens = {
    ['{'] = TokenType.LBRACE,
    ['}'] = TokenType.RBRACE,
    ['['] = TokenType.LBRACKET,
    [']'] = TokenType.RBRACKET,
    ['('] = TokenType.LPAREN,
    [')'] = TokenType.RPAREN,
    [','] = TokenType.COMMA,
    ['|'] = TokenType.PIPE,
    ['.'] = TokenType.DOT,
  }

  if single_char_tokens[char] then
    self.scanner:advance()
    return self:make_token_with_span(single_char_tokens[char], start_pos)
  end

  -- Unknown character - create error token
  self.scanner:advance()
  return self:error_token("Unexpected character: " .. char, start_pos)
end

--- Handle indentation at start of line
-- @return table Array of INDENT/DEDENT tokens
function Lexer:handle_line_start()
  self.at_line_start = false

  -- Skip blank lines
  while scanner_module.is_newline(self.scanner:peek()) do
    self.scanner:advance()
  end

  if self.scanner:at_end() then
    return {}
  end

  -- Count leading spaces
  local indent = 0
  local start_pos = self.scanner:get_position()

  while self.scanner:peek() == ' ' do
    self.scanner:advance()
    indent = indent + 1
  end

  -- Handle tabs (count as 1 indent unit each)
  while self.scanner:peek() == '\t' do
    self.scanner:advance()
    indent = indent + 1
  end

  -- Skip lines that are only whitespace or comments
  if scanner_module.is_newline(self.scanner:peek()) or self.scanner:at_end() then
    self.at_line_start = true
    return {}
  end

  if self.scanner:peek() == '/' and self.scanner:peek(1) == '/' then
    -- Comment line - don't change indentation
    return {}
  end

  local tokens = {}
  local current_indent = self.indent_stack[#self.indent_stack] or 0

  if indent > current_indent then
    -- Increased indentation
    table.insert(self.indent_stack, indent)
    table.insert(tokens, Token.new(TokenType.INDENT, "", nil, start_pos))
  elseif indent < current_indent then
    -- Decreased indentation - emit DEDENTs
    while #self.indent_stack > 1 and self.indent_stack[#self.indent_stack] > indent do
      table.remove(self.indent_stack)
      table.insert(tokens, Token.new(TokenType.DEDENT, "", nil, start_pos))
    end
  end

  return tokens
end

--- Emit remaining DEDENT tokens at end of file
-- @return table Array of DEDENT tokens
function Lexer:emit_remaining_dedents()
  local tokens = {}
  local pos = self.scanner:get_position()

  while #self.indent_stack > 1 do
    table.remove(self.indent_stack)
    table.insert(tokens, Token.new(TokenType.DEDENT, "", nil, pos))
  end

  return tokens
end

--- Skip whitespace (not newlines)
function Lexer:skip_whitespace()
  while scanner_module.is_whitespace(self.scanner:peek()) do
    self.scanner:advance()
  end
end

--- Tokenize newline
-- @return Token
function Lexer:newline()
  local start_pos = self.scanner:get_position()
  self.scanner:advance()

  -- Handle CRLF
  if self.scanner:peek() == '\n' then
    self.scanner:advance()
  end

  self.at_line_start = true
  return Token.new(TokenType.NEWLINE, "\\n", nil, start_pos)
end

--- Tokenize comment
-- @return Token
function Lexer:comment()
  local start_pos = self.scanner:get_position()
  self.scanner:advance()  -- /
  self.scanner:advance()  -- /

  local content = self.scanner:match_while(function(c)
    return not scanner_module.is_newline(c)
  end)

  return Token.new(TokenType.COMMENT, "//" .. content, content, start_pos)
end

--- Tokenize identifier or keyword
-- @return Token
function Lexer:identifier_or_keyword()
  local start_pos = self.scanner:get_position()

  local name = self.scanner:match_while(scanner_module.is_identifier_char)

  -- Check if it's a keyword
  local keyword_type = tokens_module.is_keyword(name)
  if keyword_type then
    return Token.new(keyword_type, name, nil, start_pos)
  end

  return Token.new(TokenType.IDENTIFIER, name, name, start_pos)
end

--- Tokenize number literal
-- @return Token
function Lexer:number()
  local start_pos = self.scanner:get_position()

  local num_str = self.scanner:match_while(scanner_module.is_digit)

  -- Check for decimal
  if self.scanner:peek() == '.' and scanner_module.is_digit(self.scanner:peek(1)) then
    self.scanner:advance()  -- .
    num_str = num_str .. '.' .. self.scanner:match_while(scanner_module.is_digit)
  end

  local value = tonumber(num_str)
  return Token.new(TokenType.NUMBER, num_str, value, start_pos)
end

--- Tokenize string literal
-- @return Token
function Lexer:string()
  local start_pos = self.scanner:get_position()
  local quote = self.scanner:advance()  -- Opening quote

  local chars = {}
  while not self.scanner:at_end() do
    local char = self.scanner:peek()

    if char == quote then
      self.scanner:advance()  -- Closing quote
      local lexeme = quote .. table.concat(chars) .. quote
      return Token.new(TokenType.STRING, lexeme, table.concat(chars), start_pos)
    end

    if char == '\\' then
      self.scanner:advance()
      local escaped = self.scanner:advance()
      if escaped == 'n' then
        table.insert(chars, '\n')
      elseif escaped == 't' then
        table.insert(chars, '\t')
      elseif escaped == '\\' then
        table.insert(chars, '\\')
      elseif escaped == quote then
        table.insert(chars, quote)
      else
        table.insert(chars, escaped or '')
      end
    elseif scanner_module.is_newline(char) then
      -- Unterminated string at newline
      return self:error_token("Unterminated string", start_pos)
    else
      table.insert(chars, self.scanner:advance())
    end
  end

  -- Unterminated string at EOF
  return self:error_token("Unterminated string", start_pos)
end

--- Tokenize variable reference ($name)
-- @return Token
function Lexer:variable()
  local start_pos = self.scanner:get_position()
  self.scanner:advance()  -- $

  if not scanner_module.is_identifier_start(self.scanner:peek()) then
    return self:error_token("Expected identifier after $", start_pos)
  end

  local name = self.scanner:match_while(scanner_module.is_identifier_char)
  return Token.new(TokenType.VARIABLE, "$" .. name, name, start_pos)
end

--- Create a token at current position
-- @param token_type string
-- @return Token
function Lexer:make_token(token_type)
  return Token.new(token_type, "", nil, self.scanner:get_position())
end

--- Create a token with explicit span
-- @param token_type string
-- @param start_pos SourcePosition
-- @return Token
function Lexer:make_token_with_span(token_type, start_pos)
  local lexeme = self.source:sub(start_pos.offset + 1, self.scanner:get_position().offset)
  return Token.new(token_type, lexeme, nil, start_pos)
end

--- Create an error token
-- @param message string
-- @param start_pos SourcePosition
-- @return Token
function Lexer:error_token(message, start_pos)
  start_pos = start_pos or self.scanner:get_position()
  local token = Token.new(TokenType.ERROR, message, { message = message }, start_pos)
  table.insert(self.errors, {
    message = message,
    position = start_pos
  })
  return token
end

--- Get accumulated errors
-- @return table Array of error objects
function Lexer:get_errors()
  return self.errors
end

--- Reset lexer state
function Lexer:reset()
  self.scanner = Scanner.new(self.source)
  self.tokens = {}
  self.errors = {}
  self.indent_stack = { 0 }
  self.at_line_start = true
  self.pending_tokens = {}
end

M.Lexer = Lexer

--- Module metadata
M._whisker = {
  name = "script.lexer.lexer",
  version = "0.1.0",
  description = "Core lexer for Whisker Script",
  depends = { "script.lexer.tokens", "script.lexer.scanner", "script.lexer.stream" },
  capability = "script.lexer.lexer"
}

return M
