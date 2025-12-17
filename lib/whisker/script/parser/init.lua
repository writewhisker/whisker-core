-- lib/whisker/script/parser/init.lua
-- Whisker Script parser with error recovery

local tokens_module = require("whisker.script.lexer.tokens")
local ast_module = require("whisker.script.parser.ast")
local recovery_module = require("whisker.script.parser.recovery")
local codes_module = require("whisker.script.errors.codes")
local source_module = require("whisker.script.source")

local TokenType = tokens_module.TokenType
local Node = ast_module.Node
local ErrorCodes = codes_module.Parser
local SourceFile = source_module.SourceFile

local M = {}

-- ============================================
-- Parser Class
-- ============================================

local Parser = {}
Parser.__index = Parser

--- Create a new parser
-- @param tokens TokenStream Token stream to parse
-- @param options table Optional: { max_errors, source, file_path }
-- @return Parser
function Parser.new(tokens, options)
  options = options or {}

  local source = options.source or ""
  local source_file = SourceFile.new(options.file_path or "<source>", source)

  return setmetatable({
    tokens = tokens,
    source = source,
    source_file = source_file,
    errors = {},
    max_errors = options.max_errors or 100,
    panic_mode = false,
    context = {
      in_passage = false,
      in_choice = false,
      in_expression = false,
      in_conditional = false,
      nesting_depth = 0,
    },
    error_handler = nil,
  }, Parser)
end

-- ============================================
-- Token Stream Interaction
-- ============================================

--- Peek at current token without consuming
-- @param offset number Optional offset from current position
-- @return Token
function Parser:peek(offset)
  return self.tokens:peek(offset or 0)
end

--- Get the current token
-- @return Token
function Parser:current()
  return self:peek(0)
end

--- Get the previous token (last consumed)
-- @return Token
function Parser:previous()
  return self.tokens:peek(-1)
end

--- Advance to next token and return the consumed token
-- @return Token
function Parser:advance()
  if not self:is_at_end() then
    return self.tokens:advance()
  end
  return self:peek()
end

--- Check if at end of token stream
-- @return boolean
function Parser:is_at_end()
  return self.tokens:at_end()
end

--- Check if current token matches type without consuming
-- @param token_type string Token type to check
-- @return boolean
function Parser:check(token_type)
  if self:is_at_end() then return false end
  return self:peek().type == token_type
end

--- Check if current token matches any of the given types
-- @param ... string Token types to check
-- @return boolean
function Parser:check_any(...)
  for _, token_type in ipairs({...}) do
    if self:check(token_type) then
      return true
    end
  end
  return false
end

--- Consume token if it matches, return token or nil
-- @param token_type string Expected token type
-- @return Token|nil
function Parser:match(token_type)
  if self:check(token_type) then
    return self:advance()
  end
  return nil
end

--- Consume token if it matches any of the given types
-- @param ... string Token types to match
-- @return Token|nil
function Parser:match_any(...)
  for _, token_type in ipairs({...}) do
    if self:check(token_type) then
      return self:advance()
    end
  end
  return nil
end

--- Expect a token type, consume it or report error
-- @param token_type string Expected token type
-- @param message string Error message if not found
-- @return Token|nil Token if matched, nil on error
function Parser:expect(token_type, message)
  if self:check(token_type) then
    return self:advance()
  end
  self:error_at_current(message or ("Expected " .. token_type))
  return nil
end

--- Skip tokens of a specific type (useful for newlines)
-- @param token_type string Token type to skip
-- @return number Count of tokens skipped
function Parser:skip(token_type)
  local count = 0
  while self:check(token_type) do
    self:advance()
    count = count + 1
  end
  return count
end

--- Skip newlines and comments
-- @return number Count of tokens skipped
function Parser:skip_whitespace()
  local count = 0
  while self:check_any(TokenType.NEWLINE, TokenType.COMMENT) do
    self:advance()
    count = count + 1
  end
  return count
end

-- ============================================
-- Error Handling
-- ============================================

--- Create a parser error
-- @param code string Error code
-- @param message string Error message
-- @param token Token Token where error occurred
-- @param suggestion string Optional suggestion
-- @return table ParserError
local function create_error(code, message, token, suggestion)
  return {
    code = code,
    message = message,
    token = token,
    position = token and token.pos or nil,
    suggestion = suggestion or codes_module.get_suggestion(code),
    severity = codes_module.get_severity(code),
  }
end

--- Report error at a specific token
-- @param token Token Token where error occurred
-- @param message string Error message
-- @param code string Optional error code
-- @return nil
function Parser:error_at(token, message, code)
  -- Suppress cascading errors in panic mode
  if self.panic_mode then
    return nil
  end

  self.panic_mode = true
  code = code or ErrorCodes.UNEXPECTED_TOKEN

  local error = create_error(code, message, token)
  table.insert(self.errors, error)

  -- Check error limit
  if #self.errors >= self.max_errors then
    local limit_error = create_error(
      ErrorCodes.TOO_MANY_PARSER_ERRORS,
      "Too many parser errors, stopping",
      token
    )
    table.insert(self.errors, limit_error)
  end

  -- Call error handler if set
  if self.error_handler then
    self.error_handler(error)
  end

  return nil
end

--- Report error at current token
-- @param message string Error message
-- @param code string Optional error code
-- @return nil
function Parser:error_at_current(message, code)
  return self:error_at(self:peek(), message, code)
end

--- Report error at previous (last consumed) token
-- @param message string Error message
-- @param code string Optional error code
-- @return nil
function Parser:error_at_previous(message, code)
  return self:error_at(self:previous(), message, code)
end

--- Get accumulated errors
-- @return table Array of parser errors
function Parser:get_errors()
  return self.errors
end

--- Check if parser has errors
-- @return boolean
function Parser:has_errors()
  return #self.errors > 0
end

--- Check if error limit reached
-- @return boolean
function Parser:error_limit_reached()
  return #self.errors >= self.max_errors
end

--- Set error handler callback
-- @param handler function Callback function(error)
function Parser:set_error_handler(handler)
  self.error_handler = handler
end

-- ============================================
-- Error Recovery
-- ============================================

--- Synchronize parser state after an error
-- Advances tokens until a synchronization point is reached
function Parser:synchronize()
  self.panic_mode = false

  while not self:is_at_end() do
    -- Check if previous token was a natural statement end
    local prev = self:previous()
    if prev and prev.type == TokenType.NEWLINE then
      return
    end

    -- Check for synchronization points
    local current = self:peek()
    if recovery_module.is_sync_point(current.type) then
      return
    end

    self:advance()
  end
end

--- Synchronize to statement boundary
function Parser:synchronize_statement()
  self.panic_mode = false

  while not self:is_at_end() do
    if recovery_module.is_sync_point(self:peek().type, recovery_module.statement_sync) then
      return
    end
    self:advance()
  end
end

--- Synchronize to block boundary
function Parser:synchronize_block()
  self.panic_mode = false

  while not self:is_at_end() do
    if recovery_module.is_sync_point(self:peek().type, recovery_module.block_sync) then
      return
    end
    self:advance()
  end
end

-- ============================================
-- Context Management
-- ============================================

--- Enter a parsing context
-- @param context_name string Context name (in_passage, in_choice, etc.)
function Parser:enter_context(context_name)
  self.context[context_name] = true
  self.context.nesting_depth = self.context.nesting_depth + 1
end

--- Leave a parsing context
-- @param context_name string Context name
function Parser:leave_context(context_name)
  self.context[context_name] = false
  self.context.nesting_depth = math.max(0, self.context.nesting_depth - 1)
end

--- Check if in a specific context
-- @param context_name string Context name
-- @return boolean
function Parser:in_context(context_name)
  return self.context[context_name] == true
end

--- Get current nesting depth
-- @return number
function Parser:get_nesting_depth()
  return self.context.nesting_depth
end

-- ============================================
-- Main Parse Method
-- ============================================

--- Parse token stream to AST
-- @return table ScriptNode AST
function Parser:parse()
  local grammar = require("whisker.script.parser.grammar")
  return grammar.parse_script(self)
end

M.Parser = Parser

-- ============================================
-- Module Exports
-- ============================================

--- Create a new parser from a token stream
-- @param tokens TokenStream
-- @param options table Optional parser options
-- @return Parser
function M.new(tokens, options)
  return Parser.new(tokens, options)
end

--- Parse source directly (convenience function)
-- @param source string Source code
-- @param options table Optional parser options
-- @return table AST, table errors
function M.parse(source, options)
  local lexer = require("whisker.script.lexer")
  local tokens = lexer.tokenize(source)
  options = options or {}
  options.source = source

  local parser = Parser.new(tokens, options)
  local ast = parser:parse()
  return ast, parser:get_errors()
end

--- Module metadata
M._whisker = {
  name = "script.parser",
  version = "0.1.0",
  description = "Whisker Script parser with error recovery",
  depends = {
    "script.lexer.tokens",
    "script.parser.ast",
    "script.parser.recovery",
    "script.parser.grammar",
    "script.errors.codes"
  },
  capability = "script.parser"
}

return M
