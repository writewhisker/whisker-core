-- lib/whisker/script/lexer/init.lua
-- Whisker Script lexer module entry point

local M = {}

--- Tokenize source code
-- @param source string Source code to tokenize
-- @return table TokenStream
function M:tokenize(source)
  error("whisker.script.lexer:tokenize() not implemented")
end

--- Reset lexer state
function M:reset()
  error("whisker.script.lexer:reset() not implemented")
end

--- Create a new lexer instance
-- @return table New lexer instance
function M.new()
  local instance = setmetatable({}, { __index = M })
  return instance
end

--- Module metadata
M._whisker = {
  name = "script.lexer",
  version = "0.1.0",
  description = "Whisker Script tokenizer",
  depends = {},
  capability = "script.lexer"
}

return M
