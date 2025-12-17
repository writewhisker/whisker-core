-- lib/whisker/script/init.lua
-- Whisker Script language compiler entry point

local M = {
  _NAME = "whisker.script",
  _VERSION = "1.0.0",
  _DESCRIPTION = "Whisker Script language compiler",
  _DEPENDENCIES = { "whisker.kernel", "whisker.core" }
}

-- Lazy-loaded submodules
local lexer_module, parser_module, semantic_module, generator_module, errors_module
local format_module, writer_module

-- ============================================
-- Compiler Class
-- ============================================

local Compiler = {}
Compiler.__index = Compiler

--- Create a new Compiler instance
-- @param options table Options { source_file: string, event_emitter: table }
-- @return Compiler
function Compiler.new(options)
  options = options or {}
  return setmetatable({
    source_file = options.source_file or "input.wsk",
    event_emitter = options.event_emitter,
  }, Compiler)
end

--- Compile Whisker Script source to Story
-- @param source string Source code
-- @param options table Optional compilation options
-- @return table CompileResult with story, diagnostics, sourcemap
function Compiler:compile(source, options)
  options = options or {}
  local diagnostics = {}
  local source_file = options.source_file or self.source_file

  -- Emit compile start event
  if self.event_emitter then
    self.event_emitter:emit("script:compile:start", { source = source })
  end

  -- Phase 1: Tokenize
  local lexer_mod = M.get_lexer()
  local lex = lexer_mod.Lexer.new(source, { file_path = source_file })
  local tokens = lex:tokenize()

  -- Collect lexer errors
  local lexer_errors = lex:get_errors()
  for _, err in ipairs(lexer_errors) do
    table.insert(diagnostics, {
      severity = "error",
      code = err.code or "WSK0001",
      message = err.message,
      position = err.position,
    })
  end

  -- Emit tokenize complete event
  if self.event_emitter then
    self.event_emitter:emit("script:tokenize:complete", {
      tokens = tokens,
      errors = lexer_errors
    })
  end

  -- Phase 2: Parse
  local parser_mod = M.get_parser()
  local parse = parser_mod.Parser.new(tokens, { source = source })
  local ast = parse:parse()

  -- Collect parser errors
  local parser_errors = parse:get_errors()
  for _, err in ipairs(parser_errors) do
    table.insert(diagnostics, {
      severity = "error",
      code = err.code or "WSK0010",
      message = err.message,
      position = err.position,
    })
  end

  -- Emit parse complete event
  if self.event_emitter then
    self.event_emitter:emit("script:parse:complete", {
      ast = ast,
      errors = parser_errors
    })
  end

  -- If there are syntax errors, stop here
  if #parser_errors > 0 then
    return {
      story = nil,
      diagnostics = diagnostics,
      sourcemap = nil,
    }
  end

  -- Phase 3: Semantic Analysis
  local semantic_mod = M.get_semantic()
  local analyzer = semantic_mod.SemanticAnalyzer.new()
  local annotated_ast, symbols = analyzer:analyze(ast)

  -- Collect semantic errors
  local semantic_errors = analyzer:get_errors()
  for _, err in ipairs(semantic_errors) do
    table.insert(diagnostics, {
      severity = err.severity or "error",
      code = err.code or "WSK0040",
      message = err.message,
      position = err.position,
      suggestion = err.suggestion,
    })
  end

  -- Emit analyze complete event
  if self.event_emitter then
    self.event_emitter:emit("script:analyze:complete", {
      ast = annotated_ast,
      symbols = symbols,
      errors = semantic_errors
    })
  end

  -- Check for critical semantic errors
  local has_critical_errors = false
  for _, diag in ipairs(diagnostics) do
    if diag.severity == "error" then
      has_critical_errors = true
      break
    end
  end

  if has_critical_errors then
    return {
      story = nil,
      diagnostics = diagnostics,
      sourcemap = nil,
    }
  end

  -- Phase 4: Code Generation
  local generator_mod = M.get_generator()
  local gen = generator_mod.CodeGenerator.new({
    source_file = source_file
  })

  local result
  if options.include_sourcemap then
    result = gen:generate_with_sourcemap(annotated_ast or ast, {
      source_file = source_file
    })
  else
    local story = gen:generate(annotated_ast or ast)
    result = { story = story, sourcemap = nil }
  end

  -- Emit generate complete event
  if self.event_emitter then
    self.event_emitter:emit("script:generate:complete", {
      story = result.story
    })
  end

  -- Emit compile complete event
  if self.event_emitter then
    self.event_emitter:emit("script:compile:complete", {
      story = result.story,
      diagnostics = diagnostics
    })
  end

  return {
    story = result.story,
    diagnostics = diagnostics,
    sourcemap = result.sourcemap,
  }
end

--- Parse source without code generation
-- @param source string Source code
-- @return table { ast: AST, diagnostics: array }
function Compiler:parse_only(source)
  local diagnostics = {}

  -- Tokenize
  local lexer_mod = M.get_lexer()
  local lex = lexer_mod.Lexer.new(source)
  local tokens = lex:tokenize()

  for _, err in ipairs(lex:get_errors()) do
    table.insert(diagnostics, {
      severity = "error",
      code = err.code or "WSK0001",
      message = err.message,
      position = err.position,
    })
  end

  -- Parse
  local parser_mod = M.get_parser()
  local parse = parser_mod.Parser.new(tokens, { source = source })
  local ast = parse:parse()

  for _, err in ipairs(parse:get_errors()) do
    table.insert(diagnostics, {
      severity = "error",
      code = err.code or "WSK0010",
      message = err.message,
      position = err.position,
    })
  end

  return {
    ast = ast,
    diagnostics = diagnostics,
  }
end

--- Validate source and return diagnostics without generating code
-- @param source string Source code
-- @return table Array of Diagnostic objects
function Compiler:validate(source)
  local result = self:compile(source)
  return result.diagnostics
end

--- Tokenize source for tooling
-- @param source string Source code
-- @return table TokenStream
function Compiler:get_tokens(source)
  local lexer_mod = M.get_lexer()
  local lex = lexer_mod.Lexer.new(source)
  return lex:tokenize()
end

M.Compiler = Compiler

-- ============================================
-- Module Functions
-- ============================================

--- Initialize module with container
-- @param container DI container instance
function M.init(container)
  if container and container.register then
    -- Register format handler
    local format_mod = M.get_format()
    container:register("format.whisker", format_mod.WhiskerScriptFormat, {
      implements = "IFormat",
      capability = "format.whisker"
    })

    -- Register compiler
    container:register("compiler.whisker", Compiler, {
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
  if not lexer_module then
    lexer_module = require("whisker.script.lexer")
  end
  return lexer_module
end

--- Get the parser module
-- @return table Parser module
function M.get_parser()
  if not parser_module then
    parser_module = require("whisker.script.parser")
  end
  return parser_module
end

--- Get the semantic analyzer module
-- @return table Semantic analyzer module
function M.get_semantic()
  if not semantic_module then
    semantic_module = require("whisker.script.semantic")
  end
  return semantic_module
end

--- Get the code generator module
-- @return table Code generator module
function M.get_generator()
  if not generator_module then
    generator_module = require("whisker.script.generator")
  end
  return generator_module
end

--- Get the error reporter module
-- @return table Error reporter module
function M.get_errors()
  if not errors_module then
    errors_module = require("whisker.script.errors")
  end
  return errors_module
end

--- Get the format handler module
-- @return table Format handler module
function M.get_format()
  if not format_module then
    format_module = require("whisker.script.format")
  end
  return format_module
end

--- Get the writer module
-- @return table Writer module
function M.get_writer()
  if not writer_module then
    writer_module = require("whisker.script.writer")
  end
  return writer_module
end

-- ============================================
-- IFormat convenience methods on module
-- ============================================

--- Check if source can be imported as Whisker Script
-- @param source string Source to check
-- @return boolean
function M.can_import(source)
  local fmt = M.get_format()
  local handler = fmt.WhiskerScriptFormat.new()
  return handler:can_import(source)
end

--- Import Whisker Script source
-- @param source string Source code
-- @return table Story object
function M.import(source)
  local fmt = M.get_format()
  local handler = fmt.WhiskerScriptFormat.new()
  return handler:import(source)
end

--- Check if story can be exported
-- @param story table Story object
-- @return boolean
function M.can_export(story)
  local fmt = M.get_format()
  local handler = fmt.WhiskerScriptFormat.new()
  return handler:can_export(story)
end

--- Export Story to Whisker Script
-- @param story table Story object
-- @return string Whisker Script source
function M.export(story)
  local fmt = M.get_format()
  local handler = fmt.WhiskerScriptFormat.new()
  return handler:export(story)
end

-- ============================================
-- IScriptCompiler convenience methods on module
-- ============================================

--- Compile Whisker Script source to Story
-- @param source string Source code
-- @param options table Optional compilation options
-- @return table CompileResult with story, diagnostics, sourcemap
function M.compile(source, options)
  local compiler = Compiler.new()
  return compiler:compile(source, options)
end

--- Parse source without code generation
-- @param source string Source code
-- @return table { ast: AST, diagnostics: array }
function M.parse_only(source)
  local compiler = Compiler.new()
  return compiler:parse_only(source)
end

--- Validate source and return diagnostics
-- @param source string Source code
-- @return table Array of Diagnostic objects
function M.validate(source)
  local compiler = Compiler.new()
  return compiler:validate(source)
end

--- Tokenize source for tooling
-- @param source string Source code
-- @return table TokenStream
function M.get_tokens(source)
  local compiler = Compiler.new()
  return compiler:get_tokens(source)
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
