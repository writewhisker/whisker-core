-- lib/whisker/script/generator/init.lua
-- Whisker Script code generator module entry point

local M = {}

--- Generate Story IR from annotated AST
-- @param ast table Annotated AST
-- @return table Story object
function M:generate(ast)
  error("whisker.script.generator:generate() not implemented")
end

--- Generate Story IR with source map
-- @param ast table Annotated AST
-- @return table { story: Story, sourcemap: SourceMap }
function M:generate_with_sourcemap(ast)
  error("whisker.script.generator:generate_with_sourcemap() not implemented")
end

--- Create a new generator instance
-- @return table New generator instance
function M.new()
  local instance = setmetatable({}, { __index = M })
  return instance
end

--- Module metadata
M._whisker = {
  name = "script.generator",
  version = "0.1.0",
  description = "Whisker Script code generator",
  depends = { "script.semantic" },
  capability = "script.generator"
}

return M
