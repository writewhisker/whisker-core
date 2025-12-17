-- lib/whisker/script/lexer/stream.lua
-- Token stream for parser consumption

local M = {}

--- TokenStream class
-- Provides sequential access to tokens with lookahead
local TokenStream = {}
TokenStream.__index = TokenStream

--- Create a new token stream
-- @param tokens table Array of Token objects
-- @return TokenStream
function TokenStream.new(tokens)
  return setmetatable({
    tokens = tokens or {},
    cursor = 1
  }, TokenStream)
end

--- Check if at end of stream (EOF token reached)
-- @return boolean
function TokenStream:at_end()
  local token = self:peek()
  return token and token.type == "EOF"
end

--- Peek at token at current position + offset
-- @param offset number Offset from cursor (default 0)
-- @return Token
function TokenStream:peek(offset)
  offset = offset or 0
  local idx = self.cursor + offset
  if idx < 1 then
    return nil
  end
  if idx > #self.tokens then
    -- Return last token (should be EOF) if past end
    return self.tokens[#self.tokens]
  end
  return self.tokens[idx]
end

--- Get current token (convenience for peek(0))
-- @return Token
function TokenStream:current()
  return self:peek(0)
end

--- Advance to next token and return the consumed token
-- @return Token The token that was consumed
function TokenStream:advance()
  local token = self:peek()
  if self.cursor <= #self.tokens then
    self.cursor = self.cursor + 1
  end
  return token
end

--- Match token type and advance if it matches
-- @param token_type string Expected token type
-- @return Token|nil The matched token or nil if no match
function TokenStream:match(token_type)
  local token = self:peek()
  if token and token.type == token_type then
    return self:advance()
  end
  return nil
end

--- Match any of the given token types
-- @param ... string Token types to match
-- @return Token|nil The matched token or nil if no match
function TokenStream:match_any(...)
  local token = self:peek()
  if not token then return nil end

  for _, token_type in ipairs({...}) do
    if token.type == token_type then
      return self:advance()
    end
  end
  return nil
end

--- Expect a token type, returning token or raising error info
-- @param token_type string Expected token type
-- @param message string Error message if not found
-- @return Token|nil, table|nil Token if matched, or (nil, error_info)
function TokenStream:expect(token_type, message)
  local token = self:peek()
  if token and token.type == token_type then
    return self:advance(), nil
  end

  local error_info = {
    expected = token_type,
    found = token and token.type or "EOF",
    message = message or ("Expected " .. token_type),
    position = token and token.pos or nil
  }
  return nil, error_info
end

--- Check if current token is of given type without consuming
-- @param token_type string Token type to check
-- @return boolean
function TokenStream:check(token_type)
  local token = self:peek()
  return token and token.type == token_type
end

--- Check if current token is any of the given types
-- @param ... string Token types to check
-- @return boolean
function TokenStream:check_any(...)
  local token = self:peek()
  if not token then return false end

  for _, token_type in ipairs({...}) do
    if token.type == token_type then
      return true
    end
  end
  return false
end

--- Get remaining token count
-- @return number
function TokenStream:remaining()
  return math.max(0, #self.tokens - self.cursor + 1)
end

--- Get all tokens (for debugging)
-- @return table Array of tokens
function TokenStream:get_all_tokens()
  return self.tokens
end

M.TokenStream = TokenStream

--- Module metadata
M._whisker = {
  name = "script.lexer.stream",
  version = "0.1.0",
  description = "Token stream for Whisker Script parser",
  depends = { "script.lexer.tokens" },
  capability = "script.lexer.stream"
}

return M
