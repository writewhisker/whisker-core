-- lib/whisker/script/lexer/lexer.lua
-- Core lexer implementation for Whisker Script

local tokens_module = require("whisker.script.lexer.tokens")
local scanner_module = require("whisker.script.lexer.scanner")
local stream_module = require("whisker.script.lexer.stream")
local source_module = require("whisker.script.source")
local errors_module = require("whisker.script.lexer.errors")
local codes_module = require("whisker.script.errors.codes")

local TokenType = tokens_module.TokenType
local Token = tokens_module.Token
local Scanner = scanner_module.Scanner
local TokenStream = stream_module.TokenStream
local SourceSpan = source_module.SourceSpan
local SourceFile = source_module.SourceFile
local ErrorCollector = errors_module.ErrorCollector
local ErrorCodes = codes_module.Lexer

local M = {}

--- Lexer class
-- Tokenizes Whisker Script source into a token stream
local Lexer = {}
Lexer.__index = Lexer

--- Create a new lexer
-- @param source string Source text to tokenize
-- @param options table Optional: { max_errors, file_path }
-- @return Lexer
function Lexer.new(source, options)
  options = options or {}

  local source_file = SourceFile.new(options.file_path or "<source>", source or "")

  local self = setmetatable({
    scanner = Scanner.new(source),
    source = source or "",
    source_file = source_file,
    tokens = {},
    error_collector = ErrorCollector.new({
      max_errors = options.max_errors or 100,
      source_file = source_file,
    }),
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
  self.error_collector:clear()

  while true do
    -- Check error limit before continuing
    if self.error_collector:limit_reached() then
      -- Add EOF and stop
      table.insert(self.tokens, self:make_token(TokenType.EOF))
      break
    end

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

  -- Handle comments (// style)
  if self.scanner:peek() == '/' and self.scanner:peek(1) == '/' then
    return self:comment()
  end

  -- Handle # style comments
  if self.scanner:peek() == '#' then
    return self:hash_comment()
  end

  -- Get next character for dispatch
  local char = self.scanner:peek()

  -- Mark position for token
  local start_pos = self.scanner:get_position()

  -- Structural tokens (Stage 6)

  -- Passage declaration ::
  if char == ':' and self.scanner:peek(1) == ':' then
    return self:passage_decl()
  end

  -- Colon (single)
  if char == ':' then
    self.scanner:advance()
    return Token.new(TokenType.COLON, ":", nil, start_pos)
  end

  -- Divert -> or Tunnel ->->
  if char == '-' and self.scanner:peek(1) == '>' then
    return self:divert_or_tunnel()
  end

  -- Thread <-
  if char == '<' and self.scanner:peek(1) == '-' then
    return self:thread()
  end

  -- Comparison operators with <
  if char == '<' then
    return self:less_than_operator()
  end

  -- Comparison operators with >
  if char == '>' and self.scanner:peek(1) == '>' then
    return self:include()
  end

  if char == '>' then
    return self:greater_than_operator()
  end

  -- Metadata @@
  if char == '@' and self.scanner:peek(1) == '@' then
    return self:metadata()
  end

  -- Assignment ~ (at line start or in context)
  if char == '~' then
    self.scanner:advance()
    return Token.new(TokenType.ASSIGN, "~", nil, start_pos)
  end

  -- Choice + (context-sensitive)
  if char == '+' then
    return self:plus_or_choice()
  end

  -- Minus - (for operators or dash)
  if char == '-' then
    return self:minus_operator()
  end

  -- Identifier or keyword
  if scanner_module.is_identifier_start(char) then
    return self:identifier_or_keyword()
  end

  -- Number literal
  if scanner_module.is_digit(char) then
    return self:number()
  end

  -- String literal (only double quotes - single quotes are apostrophes in narrative text)
  if char == '"' then
    return self:string()
  end

  -- Variable reference
  if char == '$' then
    return self:variable()
  end

  -- Assignment and comparison operators
  if char == '=' then
    return self:equals_operator()
  end

  if char == '!' then
    return self:bang_operator()
  end

  -- Arithmetic operators
  if char == '*' then
    return self:star_operator()
  end

  if char == '/' then
    self.scanner:advance()
    if self.scanner:peek() == '=' then
      self.scanner:advance()
      return Token.new(TokenType.SLASH_EQ, "/=", nil, start_pos)
    end
    return Token.new(TokenType.SLASH, "/", nil, start_pos)
  end

  if char == '%' then
    self.scanner:advance()
    return Token.new(TokenType.PERCENT, "%", nil, start_pos)
  end

  -- Single character tokens
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
    return Token.new(single_char_tokens[char], char, nil, start_pos)
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

-- Structural Token Handlers (Stage 6)

--- Tokenize passage declaration ::
-- @return Token
function Lexer:passage_decl()
  local start_pos = self.scanner:get_position()
  self.scanner:advance()  -- :
  self.scanner:advance()  -- :
  return Token.new(TokenType.PASSAGE_DECL, "::", nil, start_pos)
end

--- Tokenize divert -> or tunnel ->->
-- @return Token
function Lexer:divert_or_tunnel()
  local start_pos = self.scanner:get_position()
  self.scanner:advance()  -- -
  self.scanner:advance()  -- >

  -- Check for tunnel ->->
  if self.scanner:peek() == '-' and self.scanner:peek(1) == '>' then
    self.scanner:advance()  -- -
    self.scanner:advance()  -- >
    return Token.new(TokenType.TUNNEL, "->->", nil, start_pos)
  end

  return Token.new(TokenType.DIVERT, "->", nil, start_pos)
end

--- Tokenize thread <-
-- @return Token
function Lexer:thread()
  local start_pos = self.scanner:get_position()
  self.scanner:advance()  -- <
  self.scanner:advance()  -- -
  return Token.new(TokenType.THREAD, "<-", nil, start_pos)
end

--- Tokenize metadata @@
-- @return Token
function Lexer:metadata()
  local start_pos = self.scanner:get_position()
  self.scanner:advance()  -- @
  self.scanner:advance()  -- @
  return Token.new(TokenType.METADATA, "@@", nil, start_pos)
end

--- Tokenize include >>
-- @return Token
function Lexer:include()
  local start_pos = self.scanner:get_position()
  self.scanner:advance()  -- >
  self.scanner:advance()  -- >
  return Token.new(TokenType.INCLUDE, ">>", nil, start_pos)
end

--- Tokenize + as CHOICE or PLUS based on context
-- @return Token
function Lexer:plus_or_choice()
  local start_pos = self.scanner:get_position()
  self.scanner:advance()  -- +

  -- Check for compound assignment +=
  if self.scanner:peek() == '=' then
    self.scanner:advance()
    return Token.new(TokenType.PLUS_EQ, "+=", nil, start_pos)
  end

  -- At effective line start (after indentation), + is CHOICE
  -- This is a heuristic - parser may need to refine
  -- For now, check if previous non-whitespace token was INDENT, NEWLINE, or start
  return Token.new(TokenType.PLUS, "+", nil, start_pos)
end

--- Tokenize - operators (MINUS, MINUS_EQ, DASH)
-- @return Token
function Lexer:minus_operator()
  local start_pos = self.scanner:get_position()
  self.scanner:advance()  -- -

  -- Check for compound assignment -=
  if self.scanner:peek() == '=' then
    self.scanner:advance()
    return Token.new(TokenType.MINUS_EQ, "-=", nil, start_pos)
  end

  return Token.new(TokenType.MINUS, "-", nil, start_pos)
end

--- Tokenize < operators (LT, LT_EQ)
-- @return Token
function Lexer:less_than_operator()
  local start_pos = self.scanner:get_position()
  self.scanner:advance()  -- <

  if self.scanner:peek() == '=' then
    self.scanner:advance()
    return Token.new(TokenType.LT_EQ, "<=", nil, start_pos)
  end

  return Token.new(TokenType.LT, "<", nil, start_pos)
end

--- Tokenize > operators (GT, GT_EQ)
-- @return Token
function Lexer:greater_than_operator()
  local start_pos = self.scanner:get_position()
  self.scanner:advance()  -- >

  if self.scanner:peek() == '=' then
    self.scanner:advance()
    return Token.new(TokenType.GT_EQ, ">=", nil, start_pos)
  end

  return Token.new(TokenType.GT, ">", nil, start_pos)
end

--- Tokenize = operators (EQ, EQ_EQ)
-- @return Token
function Lexer:equals_operator()
  local start_pos = self.scanner:get_position()
  self.scanner:advance()  -- =

  if self.scanner:peek() == '=' then
    self.scanner:advance()
    return Token.new(TokenType.EQ_EQ, "==", nil, start_pos)
  end

  return Token.new(TokenType.EQ, "=", nil, start_pos)
end

--- Tokenize ! operators (NOT, BANG_EQ)
-- @return Token
function Lexer:bang_operator()
  local start_pos = self.scanner:get_position()
  self.scanner:advance()  -- !

  if self.scanner:peek() == '=' then
    self.scanner:advance()
    return Token.new(TokenType.BANG_EQ, "!=", nil, start_pos)
  end

  return Token.new(TokenType.NOT, "!", nil, start_pos)
end

--- Tokenize * operators (STAR, STAR_EQ)
-- @return Token
function Lexer:star_operator()
  local start_pos = self.scanner:get_position()
  self.scanner:advance()  -- *

  if self.scanner:peek() == '=' then
    self.scanner:advance()
    return Token.new(TokenType.STAR_EQ, "*=", nil, start_pos)
  end

  return Token.new(TokenType.STAR, "*", nil, start_pos)
end

--- Tokenize # style comment
-- @return Token
function Lexer:hash_comment()
  local start_pos = self.scanner:get_position()
  self.scanner:advance()  -- #

  local content = self.scanner:match_while(function(c)
    return not scanner_module.is_newline(c)
  end)

  return Token.new(TokenType.COMMENT, "#" .. content, content, start_pos)
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

--- Create an error token with enhanced diagnostics
-- @param code string Error code (from ErrorCodes)
-- @param message string Human-readable message
-- @param start_pos SourcePosition Position where error occurred
-- @param options table Optional: { suggestion, lexeme, end_pos }
-- @return Token
function Lexer:error_token_enhanced(code, message, start_pos, options)
  start_pos = start_pos or self.scanner:get_position()
  options = options or {}

  local lexer_error = errors_module.LexerError.new(code, message, start_pos, {
    suggestion = options.suggestion,
    lexeme = options.lexeme,
    end_pos = options.end_pos,
  })

  self.error_collector:add(lexer_error)

  local token = Token.new(TokenType.ERROR, options.lexeme or "", {
    code = code,
    message = message,
    error = lexer_error,
  }, start_pos)

  return token
end

--- Create an error token (simplified, for backwards compatibility)
-- @param message string Error message
-- @param start_pos SourcePosition Position where error occurred
-- @return Token
function Lexer:error_token(message, start_pos)
  start_pos = start_pos or self.scanner:get_position()

  -- Detect error type from message
  local code = ErrorCodes.UNEXPECTED_CHARACTER
  local lexeme = ""

  if message:match("Unterminated string") then
    code = ErrorCodes.UNTERMINATED_STRING
  elseif message:match("Expected identifier after") then
    code = ErrorCodes.INVALID_VARIABLE_NAME
  elseif message:match("Unexpected character") then
    code = ErrorCodes.UNEXPECTED_CHARACTER
    lexeme = message:match("Unexpected character: (.+)") or ""
  end

  -- Get suggestion from error codes
  local suggestion = codes_module.get_suggestion(code)

  return self:error_token_enhanced(code, message, start_pos, {
    lexeme = lexeme,
    suggestion = suggestion
  })
end

--- Get accumulated errors
-- @return table Array of LexerError objects
function Lexer:get_errors()
  return self.error_collector:get_errors()
end

--- Check if lexer has errors
-- @return boolean
function Lexer:has_errors()
  return self.error_collector:has_errors()
end

--- Get error count
-- @return number
function Lexer:error_count()
  return self.error_collector:count()
end

--- Format all errors with source context
-- @return string Formatted error report
function Lexer:format_errors()
  return self.error_collector:format_all()
end

--- Reset lexer state
function Lexer:reset()
  self.scanner = Scanner.new(self.source)
  self.tokens = {}
  self.error_collector:clear()
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
  depends = {
    "script.lexer.tokens",
    "script.lexer.scanner",
    "script.lexer.stream",
    "script.lexer.errors",
    "script.errors.codes"
  },
  capability = "script.lexer.lexer"
}

return M
