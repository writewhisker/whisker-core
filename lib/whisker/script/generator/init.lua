-- lib/whisker/script/generator/init.lua
-- Whisker Script code generator module entry point

local emitter_module = require("whisker.script.generator.emitter")
local Emitter = emitter_module.Emitter

local M = {}

-- ============================================
-- CodeGenerator Class
-- ============================================

local CodeGenerator = {}
CodeGenerator.__index = CodeGenerator

--- Create a new code generator
-- @return CodeGenerator
function CodeGenerator.new()
  return setmetatable({
    emitter = Emitter.new(),
    diagnostics = {},
  }, CodeGenerator)
end

--- Generate Story IR from annotated AST
-- @param ast table Annotated AST
-- @return Story Generated story object
function CodeGenerator:generate(ast)
  self.diagnostics = {}

  if not ast then
    return nil
  end

  local story = self.emitter:emit(ast)
  return story
end

--- Generate Story IR with source map
-- @param ast table Annotated AST
-- @return table { story: Story, sourcemap: SourceMap }
function CodeGenerator:generate_with_sourcemap(ast)
  local story = self:generate(ast)

  -- Source map will be implemented in Stage 23
  local sourcemap = nil

  return {
    story = story,
    sourcemap = sourcemap
  }
end

--- Get diagnostics from generation
-- @return table Array of diagnostics
function CodeGenerator:get_diagnostics()
  return self.diagnostics
end

M.CodeGenerator = CodeGenerator

--- Convenience function to create generator
-- @return CodeGenerator
function M.new()
  return CodeGenerator.new()
end

--- Module metadata
M._whisker = {
  name = "script.generator",
  version = "0.1.0",
  description = "Whisker Script code generator",
  depends = {
    "script.semantic",
    "script.generator.emitter"
  },
  capability = "script.generator"
}

return M
