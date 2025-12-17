-- lib/whisker/script/lexer/init.lua
-- Whisker Script lexer module entry point

local lexer_module = require("whisker.script.lexer.lexer")
local stream_module = require("whisker.script.lexer.stream")
local tokens_module = require("whisker.script.lexer.tokens")
local scanner_module = require("whisker.script.lexer.scanner")
local errors_module = require("whisker.script.lexer.errors")

local M = {}

-- Re-export submodules
M.Lexer = lexer_module.Lexer
M.TokenStream = stream_module.TokenStream
M.TokenType = tokens_module.TokenType
M.Token = tokens_module.Token
M.Scanner = scanner_module.Scanner
M.LexerError = errors_module.LexerError
M.ErrorCollector = errors_module.ErrorCollector

-- Re-export token helpers
M.is_keyword = tokens_module.is_keyword
M.is_operator = tokens_module.is_operator
M.is_literal = tokens_module.is_literal
M.is_structural = tokens_module.is_structural

-- Re-export error helpers
M.errors = errors_module.errors

--- Create a new lexer instance
-- @param source string Source code to tokenize
-- @param options table Optional: { max_errors, file_path }
-- @return Lexer New lexer instance
function M.new(source, options)
  return lexer_module.Lexer.new(source, options)
end

--- Tokenize source code (convenience function)
-- @param source string Source code to tokenize
-- @param options table Optional lexer options
-- @return TokenStream
function M.tokenize(source, options)
  local lexer = lexer_module.Lexer.new(source, options)
  return lexer:tokenize()
end

--- Tokenize and return both stream and errors
-- @param source string Source code to tokenize
-- @param options table Optional lexer options
-- @return TokenStream, table (errors)
function M.tokenize_with_errors(source, options)
  local lexer = lexer_module.Lexer.new(source, options)
  local stream = lexer:tokenize()
  return stream, lexer:get_errors()
end

--- Module metadata
M._whisker = {
  name = "script.lexer",
  version = "0.1.0",
  description = "Whisker Script tokenizer",
  depends = {
    "script.lexer.tokens",
    "script.lexer.scanner",
    "script.lexer.stream",
    "script.lexer.lexer",
    "script.lexer.errors"
  },
  capability = "script.lexer"
}

return M
