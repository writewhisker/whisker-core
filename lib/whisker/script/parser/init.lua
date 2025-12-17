-- lib/whisker/script/parser/init.lua
-- Whisker Script parser module entry point

local M = {}

--- Parse token stream to AST
-- @param tokens table TokenStream to parse
-- @return table AST
function M:parse(tokens)
  error("whisker.script.parser:parse() not implemented")
end

--- Set custom error handler
-- @param handler function Error handler callback
function M:set_error_handler(handler)
  error("whisker.script.parser:set_error_handler() not implemented")
end

--- Create a new parser instance
-- @return table New parser instance
function M.new()
  local instance = setmetatable({}, { __index = M })
  return instance
end

--- Module metadata
M._whisker = {
  name = "script.parser",
  version = "0.1.0",
  description = "Whisker Script parser",
  depends = { "script.lexer" },
  capability = "script.parser"
}

return M
