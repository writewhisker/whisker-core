-- lib/whisker/script/lexer/init.lua
-- Whisker Script lexer module entry point

local lexer_module = require("whisker.script.lexer.lexer")
local stream_module = require("whisker.script.lexer.stream")
local tokens_module = require("whisker.script.lexer.tokens")
local scanner_module = require("whisker.script.lexer.scanner")

local M = {}

-- Re-export submodules
M.Lexer = lexer_module.Lexer
M.TokenStream = stream_module.TokenStream
M.TokenType = tokens_module.TokenType
M.Token = tokens_module.Token
M.Scanner = scanner_module.Scanner

-- Re-export token helpers
M.is_keyword = tokens_module.is_keyword
M.is_operator = tokens_module.is_operator
M.is_literal = tokens_module.is_literal
M.is_structural = tokens_module.is_structural

--- Create a new lexer instance
-- @param source string Source code to tokenize
-- @return Lexer New lexer instance
function M.new(source)
  return lexer_module.Lexer.new(source)
end

--- Tokenize source code (convenience function)
-- @param source string Source code to tokenize
-- @return TokenStream
function M.tokenize(source)
  local lexer = lexer_module.Lexer.new(source)
  return lexer:tokenize()
end

--- Module metadata
M._whisker = {
  name = "script.lexer",
  version = "0.1.0",
  description = "Whisker Script tokenizer",
  depends = { "script.lexer.tokens", "script.lexer.scanner", "script.lexer.stream", "script.lexer.lexer" },
  capability = "script.lexer"
}

return M
