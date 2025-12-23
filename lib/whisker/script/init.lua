-- Whisker Script Module
-- Entry point for the Whisker Script language implementation
--
-- lib/whisker/script/init.lua

local lexer_module = require("whisker.script.lexer")
local Parser = require("whisker.script.parser")
local Compiler = require("whisker.script.compiler")
local AST = require("whisker.script.ast")
local Errors = require("whisker.script.errors")

-- i18n integration (lazy loaded)
local _i18nTags
local _textParser
local _i18nCompiler

--------------------------------------------------------------------------------
-- Module Definition
--------------------------------------------------------------------------------

local Script = {}

--- Module version
Script.VERSION = "1.0.0"

--- Module dependencies (for DI container)
Script._dependencies = {}

--------------------------------------------------------------------------------
-- Exports
--------------------------------------------------------------------------------

-- Core components
Script.Lexer = lexer_module.Lexer
Script.Token = lexer_module.Token
Script.Parser = Parser
Script.Compiler = Compiler
Script.AST = AST
Script.Errors = Errors

-- Character helpers
Script.is_alpha = lexer_module.is_alpha
Script.is_digit = lexer_module.is_digit
Script.is_alphanumeric = lexer_module.is_alphanumeric
Script.is_whitespace = lexer_module.is_whitespace

--------------------------------------------------------------------------------
-- Convenience Functions
--------------------------------------------------------------------------------

--- Compile Whisker Script source to Lua code
---@param source string Whisker Script source code
---@param filename string|nil Optional filename for error messages
---@param options table|nil Compilation options {optimize: boolean}
---@return string|nil lua_code, table|nil errors
function Script.compile(source, filename, options)
  options = options or {}
  filename = filename or "<input>"

  -- Lex
  local lexer = Script.Lexer.new(source, filename)
  local tokens = lexer:tokenize()

  -- Check for lexer errors
  local errors = {}
  for _, token in ipairs(tokens) do
    if token.type == "ERROR" then
      table.insert(errors, {
        message = token.value,
        line = token.line,
        column = token.column
      })
    end
  end

  if #errors > 0 then
    return nil, errors
  end

  -- Parse
  local parser = Script.Parser.new(tokens, filename)
  local ast = parser:parse_with_recovery()

  -- Collect parse errors
  for _, err in ipairs(ast.errors or {}) do
    table.insert(errors, err)
  end

  if #errors > 0 then
    return nil, errors
  end

  -- Validate
  local validation_errors = Script.Errors.validate(ast)
  for _, err in ipairs(validation_errors) do
    table.insert(errors, err)
  end

  if #errors > 0 then
    return nil, errors
  end

  -- Compile
  local compiler = Script.Compiler.new()

  if options.optimize then
    ast = compiler:optimize(ast)
  end

  local lua_code = compiler:compile(ast)

  return lua_code, nil
end

--- Parse Whisker Script source to AST
---@param source string Whisker Script source code
---@param filename string|nil Optional filename for error messages
---@return table|nil ast, table|nil errors
function Script.parse(source, filename)
  filename = filename or "<input>"

  -- Lex
  local lexer = Script.Lexer.new(source, filename)
  local tokens = lexer:tokenize()

  -- Check for lexer errors
  local errors = {}
  for _, token in ipairs(tokens) do
    if token.type == "ERROR" then
      table.insert(errors, {
        message = token.value,
        line = token.line,
        column = token.column
      })
    end
  end

  if #errors > 0 then
    return nil, errors
  end

  -- Parse
  local parser = Script.Parser.new(tokens, filename)
  local ast = parser:parse_with_recovery()

  -- Collect parse errors
  for _, err in ipairs(ast.errors or {}) do
    table.insert(errors, err)
  end

  if #errors > 0 then
    return nil, errors
  end

  return ast, nil
end

--- Tokenize Whisker Script source
---@param source string Whisker Script source code
---@param filename string|nil Optional filename for error messages
---@return table tokens, table errors
function Script.tokenize(source, filename)
  local lexer = Script.Lexer.new(source, filename or "<input>")
  local tokens = lexer:tokenize()

  local errors = {}
  for _, token in ipairs(tokens) do
    if token.type == "ERROR" then
      table.insert(errors, {
        message = token.value,
        line = token.line,
        column = token.column
      })
    end
  end

  return tokens, errors
end

--- Validate a program AST
---@param ast table Program AST
---@return boolean valid, table errors
function Script.validate(ast)
  local errors = Script.Errors.validate(ast)
  return #errors == 0, errors
end

--- Format error messages for display
---@param errors table Array of error objects
---@param source string Source code
---@param filename string|nil Filename
---@return string Formatted error messages
function Script.format_errors(errors, source, filename)
  local lines = {}
  for _, err in ipairs(errors) do
    table.insert(lines, Script.Errors.format_error(err, source, filename))
  end
  return table.concat(lines, "\n\n")
end

--------------------------------------------------------------------------------
-- i18n Integration
--------------------------------------------------------------------------------

--- Get i18n tags parser (lazy loaded)
---@return table I18nTags module
function Script.getI18nTags()
  if not _i18nTags then
    _i18nTags = require("whisker.script.i18n_tags")
  end
  return _i18nTags
end

--- Get text parser (lazy loaded)
---@return table TextParser module
function Script.getTextParser()
  if not _textParser then
    _textParser = require("whisker.script.text_parser")
  end
  return _textParser
end

--- Get i18n compiler (lazy loaded)
---@return table I18nCompiler module
function Script.getI18nCompiler()
  if not _i18nCompiler then
    _i18nCompiler = require("whisker.script.i18n_compiler")
  end
  return _i18nCompiler
end

--- Parse i18n tag (@@t or @@p)
---@param text string Raw tag text
---@return table|nil AST node or nil
function Script.parseI18nTag(text)
  return Script.getI18nTags().parse(text)
end

--- Parse text that may contain i18n tags
---@param text string Text to parse
---@return table AST node (text_block)
function Script.parseI18nText(text)
  return Script.getTextParser().parse(text)
end

--- Compile i18n AST node to Lua code
---@param node table AST node
---@param context table|nil Compiler context
---@return string Lua code
function Script.compileI18n(node, context)
  return Script.getI18nCompiler().compile(node, context)
end

--- Check if text contains i18n tags
---@param text string Text to check
---@return boolean
function Script.hasI18nTags(text)
  return Script.getTextParser().hasI18nTags(text)
end

--- Extract translation keys from text
---@param text string Text to analyze
---@return table Array of translation keys
function Script.extractI18nKeys(text)
  return Script.getTextParser().extractKeys(text)
end

--------------------------------------------------------------------------------
-- Module Export
--------------------------------------------------------------------------------

return Script
