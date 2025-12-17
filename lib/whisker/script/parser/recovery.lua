-- lib/whisker/script/parser/recovery.lua
-- Error recovery strategies for the Whisker Script parser

local tokens_module = require("whisker.script.lexer.tokens")
local TokenType = tokens_module.TokenType

local M = {}

--- Synchronization points for error recovery
-- These tokens indicate the start of a new construct where we can safely resume parsing
M.sync_tokens = {
  [TokenType.PASSAGE_DECL] = true,   -- :: starts a new passage
  [TokenType.PLUS] = true,           -- + starts a choice (at line start)
  [TokenType.ASSIGN] = true,         -- ~ starts an assignment
  [TokenType.DIVERT] = true,         -- -> is a divert
  [TokenType.NEWLINE] = true,        -- Newline can reset state
  [TokenType.DEDENT] = true,         -- Dedent exits a block
  [TokenType.EOF] = true,            -- End of file
}

--- Statement-level synchronization points
-- Used when recovering from errors within statements
M.statement_sync = {
  [TokenType.NEWLINE] = true,
  [TokenType.PASSAGE_DECL] = true,
  [TokenType.PLUS] = true,
  [TokenType.ASSIGN] = true,
  [TokenType.DIVERT] = true,
  [TokenType.DEDENT] = true,
  [TokenType.EOF] = true,
}

--- Expression-level synchronization points
-- Used when recovering from errors within expressions
M.expression_sync = {
  [TokenType.NEWLINE] = true,
  [TokenType.RPAREN] = true,
  [TokenType.RBRACKET] = true,
  [TokenType.RBRACE] = true,
  [TokenType.COMMA] = true,
  [TokenType.EOF] = true,
}

--- Block-level synchronization points
-- Used when recovering from errors in block structures
M.block_sync = {
  [TokenType.PASSAGE_DECL] = true,
  [TokenType.DEDENT] = true,
  [TokenType.EOF] = true,
}

--- Check if a token type is a synchronization point
-- @param token_type string Token type to check
-- @param sync_set table Set of sync tokens to check against
-- @return boolean
function M.is_sync_point(token_type, sync_set)
  sync_set = sync_set or M.sync_tokens
  return sync_set[token_type] == true
end

--- Determine the best recovery strategy for a given context
-- @param context table Parser context (in_passage, in_choice, etc.)
-- @return table Synchronization set to use
function M.get_recovery_set(context)
  if context.in_expression then
    return M.expression_sync
  elseif context.in_choice then
    return M.statement_sync
  elseif context.in_passage then
    return M.statement_sync
  else
    return M.block_sync
  end
end

--- Calculate how many tokens to skip for recovery
-- Useful for providing better error messages
-- @param tokens TokenStream Token stream
-- @param sync_set table Synchronization set
-- @return number Number of tokens until sync point
function M.distance_to_sync(tokens, sync_set)
  sync_set = sync_set or M.sync_tokens
  local count = 0
  local offset = 0

  while true do
    local token = tokens:peek(offset)
    if not token or sync_set[token.type] then
      return count
    end
    count = count + 1
    offset = offset + 1
    if count > 100 then  -- Safety limit
      return count
    end
  end
end

--- Module metadata
M._whisker = {
  name = "script.parser.recovery",
  version = "0.1.0",
  description = "Error recovery strategies for Whisker Script parser",
  depends = { "script.lexer.tokens" },
  capability = "script.parser.recovery"
}

return M
