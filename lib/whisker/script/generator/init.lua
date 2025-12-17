-- lib/whisker/script/generator/init.lua
-- Whisker Script code generator module entry point

local emitter_module = require("whisker.script.generator.emitter")
local Emitter = emitter_module.Emitter

local sourcemap_module = require("whisker.script.generator.sourcemap")
local SourceMap = sourcemap_module.SourceMap

local M = {}

-- ============================================
-- CodeGenerator Class
-- ============================================

local CodeGenerator = {}
CodeGenerator.__index = CodeGenerator

--- Create a new code generator
-- @param options table Options { source_file: string }
-- @return CodeGenerator
function CodeGenerator.new(options)
  options = options or {}
  local self = setmetatable({
    source_file = options.source_file or "input.wsk",
    diagnostics = {},
  }, CodeGenerator)

  -- Expose emitter for direct expression testing
  self.emitter = Emitter.new({
    source_file = self.source_file
  })

  return self
end

--- Generate Story IR from annotated AST
-- @param ast table Annotated AST
-- @return Story Generated story object
function CodeGenerator:generate(ast)
  self.diagnostics = {}

  if not ast then
    return nil
  end

  local emitter = Emitter.new({
    source_file = self.source_file
  })

  local story = emitter:emit(ast)
  return story
end

--- Generate Story IR with source map
-- @param ast table Annotated AST
-- @param options table Options { source_file: string }
-- @return table { story: Story, sourcemap: SourceMap }
function CodeGenerator:generate_with_sourcemap(ast, options)
  self.diagnostics = {}
  options = options or {}

  if not ast then
    return { story = nil, sourcemap = nil }
  end

  local source_file = options.source_file or self.source_file

  -- Create source map
  local source_map = SourceMap.new({
    source_file = source_file,
    file = "generated.lua"
  })

  -- Create emitter with source map
  local emitter = Emitter.new({
    source_map = source_map,
    source_file = source_file
  })

  local story = emitter:emit(ast)

  return {
    story = story,
    sourcemap = source_map
  }
end

--- Get diagnostics from generation
-- @return table Array of diagnostics
function CodeGenerator:get_diagnostics()
  return self.diagnostics
end

M.CodeGenerator = CodeGenerator

-- Re-export SourceMap for convenience
M.SourceMap = SourceMap

--- Convenience function to create generator
-- @param options table Options
-- @return CodeGenerator
function M.new(options)
  return CodeGenerator.new(options)
end

--- Module metadata
M._whisker = {
  name = "script.generator",
  version = "0.1.0",
  description = "Whisker Script code generator",
  depends = {
    "script.semantic",
    "script.generator.emitter",
    "script.generator.sourcemap"
  },
  capability = "script.generator"
}

return M
