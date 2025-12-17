-- lib/whisker/script/interfaces.lua
-- Interface definitions for the Whisker Script compiler pipeline

local M = {}

--- IScriptCompiler: Main compiler interface
-- The primary entry point for compiling Whisker Script source code.
-- Coordinates all compiler phases and produces Story objects.
M.IScriptCompiler = {
  -- compile(source: string, options?: table) -> CompileResult
  -- Full compilation pipeline: tokenize -> parse -> analyze -> generate
  -- Returns: { story: Story, diagnostics: Diagnostic[], sourcemap?: SourceMap }
  compile = function(self, source, options) end,

  -- parse_only(source: string) -> AST
  -- Tokenize and parse without semantic analysis or code generation
  -- Useful for syntax checking and tooling
  parse_only = function(self, source) end,

  -- validate(source: string) -> Diagnostic[]
  -- Full validation without code generation
  -- Returns all errors and warnings
  validate = function(self, source) end,

  -- get_tokens(source: string) -> TokenStream
  -- Tokenize only, for syntax highlighting and tooling
  get_tokens = function(self, source) end,
}

--- ILexer: Tokenizer interface
-- Converts source text into a stream of tokens with position information.
-- Handles whitespace significance, indentation, and error recovery.
M.ILexer = {
  -- tokenize(source: string) -> TokenStream
  -- Converts source text to a stream of tokens
  -- Error tokens are produced for invalid input rather than throwing
  tokenize = function(self, source) end,

  -- reset() -> void
  -- Resets lexer internal state for reuse
  reset = function(self) end,
}

--- IParser: Parser interface
-- Builds an Abstract Syntax Tree from a token stream.
-- Implements error recovery to report multiple errors per parse.
M.IParser = {
  -- parse(tokens: TokenStream) -> AST
  -- Builds AST from token stream
  -- AST nodes preserve source positions
  parse = function(self, tokens) end,

  -- set_error_handler(handler: function) -> void
  -- Set custom error handling callback
  -- handler(error: ParseError) -> void
  set_error_handler = function(self, handler) end,
}

--- ISemanticAnalyzer: Semantic analysis interface
-- Validates AST for semantic correctness, builds symbol tables,
-- resolves references, and annotates the AST.
M.ISemanticAnalyzer = {
  -- analyze(ast: AST) -> AnnotatedAST
  -- Performs semantic analysis and returns annotated AST
  -- Accumulates errors rather than throwing
  analyze = function(self, ast) end,

  -- get_symbols() -> SymbolTable
  -- Returns the symbol table built during analysis
  get_symbols = function(self) end,

  -- get_diagnostics() -> Diagnostic[]
  -- Returns accumulated diagnostics (errors, warnings, hints)
  get_diagnostics = function(self) end,
}

--- ICodeGenerator: Code generation interface
-- Transforms annotated AST into Whisker's internal Story representation.
-- Optionally produces source maps for debugging.
M.ICodeGenerator = {
  -- generate(ast: AnnotatedAST) -> Story
  -- Transforms AST into Story IR
  generate = function(self, ast) end,

  -- generate_with_sourcemap(ast: AnnotatedAST) -> { story: Story, sourcemap: SourceMap }
  -- Generates Story IR with source position mappings
  generate_with_sourcemap = function(self, ast) end,
}

--- IErrorReporter: Error reporting interface
-- Formats and outputs compilation errors in various formats.
-- Provides context snippets and fix suggestions.
M.IErrorReporter = {
  -- report(error: CompileError) -> void
  -- Report a single error
  report = function(self, error) end,

  -- report_all(errors: CompileError[]) -> void
  -- Report multiple errors
  report_all = function(self, errors) end,

  -- format(error: CompileError, source: string) -> string
  -- Format error with source context snippet
  format = function(self, error, source) end,

  -- set_format(format: string) -> void
  -- Set output format: "text", "json", "annotated"
  set_format = function(self, format) end,
}

--- Module metadata
M._whisker = {
  name = "script.interfaces",
  version = "0.1.0",
  description = "Interface definitions for Whisker Script compiler",
  depends = {},
  capability = "script.interfaces"
}

return M
