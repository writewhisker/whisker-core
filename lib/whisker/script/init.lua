-- lib/whisker/script/init.lua
-- Whisker Script language compiler entry point

local M = {
  _NAME = "whisker.script",
  _VERSION = "0.1.0",
  _DESCRIPTION = "Whisker Script language compiler",
  _DEPENDENCIES = { "whisker.kernel", "whisker.core" }
}

-- Lazy-loaded submodules
local lexer, parser, semantic, generator, errors

--- Initialize module with container
-- @param container DI container instance
function M.init(container)
  if container and container.register then
    container:register("format.whisker", M, {
      implements = "IFormat",
      capability = "format.whisker"
    })
    container:register("compiler.whisker", M, {
      implements = "IScriptCompiler"
    })
  end
end

--- Get the interfaces module
-- @return table Interface definitions
function M.interfaces()
  return require("whisker.script.interfaces")
end

--- Get the lexer module
-- @return table Lexer module
function M.get_lexer()
  if not lexer then
    lexer = require("whisker.script.lexer")
  end
  return lexer
end

--- Get the parser module
-- @return table Parser module
function M.get_parser()
  if not parser then
    parser = require("whisker.script.parser")
  end
  return parser
end

--- Get the semantic analyzer module
-- @return table Semantic analyzer module
function M.get_semantic()
  if not semantic then
    semantic = require("whisker.script.semantic")
  end
  return semantic
end

--- Get the code generator module
-- @return table Code generator module
function M.get_generator()
  if not generator then
    generator = require("whisker.script.generator")
  end
  return generator
end

--- Get the error reporter module
-- @return table Error reporter module
function M.get_errors()
  if not errors then
    errors = require("whisker.script.errors")
  end
  return errors
end

-- IScriptCompiler implementation (stubs)

--- Compile Whisker Script source to Story
-- @param source string Source code
-- @param options table Optional compilation options
-- @return table CompileResult with story, diagnostics, sourcemap
function M:compile(source, options)
  error("whisker.script:compile() not implemented")
end

--- Parse source without code generation
-- @param source string Source code
-- @return table AST
function M:parse_only(source)
  error("whisker.script:parse_only() not implemented")
end

--- Validate source and return diagnostics
-- @param source string Source code
-- @return table Array of Diagnostic objects
function M:validate(source)
  error("whisker.script:validate() not implemented")
end

--- Tokenize source for tooling
-- @param source string Source code
-- @return table TokenStream
function M:get_tokens(source)
  error("whisker.script:get_tokens() not implemented")
end

-- IFormat implementation (stubs)

--- Import Whisker Script source
-- @param source string Source code
-- @return table Story object
function M:import(source)
  local result = self:compile(source)
  return result.story
end

--- Export Story to Whisker Script
-- @param story table Story object
-- @return string Whisker Script source
function M:export(story)
  error("whisker.script:export() not implemented")
end

--- Module metadata
M._whisker = {
  name = "whisker.script",
  version = M._VERSION,
  description = M._DESCRIPTION,
  depends = M._DEPENDENCIES,
  capability = "format.whisker"
}

return M
