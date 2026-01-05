--- Whisker Language Server Protocol (LSP) Module
-- Provides LSP server for IDE integration with WLS 1.0
-- @module whisker.lsp
-- @author Whisker Core Team
-- @license MIT

local M = {}
M._dependencies = {}

-- Export submodules
M.Server = require("whisker.lsp.server")
M.Document = require("whisker.lsp.document")
M.Completion = require("whisker.lsp.completion")
M.Hover = require("whisker.lsp.hover")
M.Navigation = require("whisker.lsp.navigation")
M.Symbols = require("whisker.lsp.symbols")
M.Diagnostics = require("whisker.lsp.diagnostics")

--- Create a new LSP server instance
-- @param options table Server options
-- @return Server The server instance
function M.create_server(options)
  return M.Server.new(options)
end

--- LSP Message Types
M.MessageType = {
  ERROR = 1,
  WARNING = 2,
  INFO = 3,
  LOG = 4,
}

--- LSP Diagnostic Severity
M.DiagnosticSeverity = {
  ERROR = 1,
  WARNING = 2,
  INFO = 3,
  HINT = 4,
}

--- LSP Completion Item Kind
M.CompletionItemKind = {
  TEXT = 1,
  METHOD = 2,
  FUNCTION = 3,
  CONSTRUCTOR = 4,
  FIELD = 5,
  VARIABLE = 6,
  CLASS = 7,
  INTERFACE = 8,
  MODULE = 9,
  PROPERTY = 10,
  UNIT = 11,
  VALUE = 12,
  ENUM = 13,
  KEYWORD = 14,
  SNIPPET = 15,
  COLOR = 16,
  FILE = 17,
  REFERENCE = 18,
  FOLDER = 19,
  ENUM_MEMBER = 20,
  CONSTANT = 21,
  STRUCT = 22,
  EVENT = 23,
  OPERATOR = 24,
  TYPE_PARAMETER = 25,
}

--- LSP Symbol Kind
M.SymbolKind = {
  FILE = 1,
  MODULE = 2,
  NAMESPACE = 3,
  PACKAGE = 4,
  CLASS = 5,
  METHOD = 6,
  PROPERTY = 7,
  FIELD = 8,
  CONSTRUCTOR = 9,
  ENUM = 10,
  INTERFACE = 11,
  FUNCTION = 12,
  VARIABLE = 13,
  CONSTANT = 14,
  STRING = 15,
  NUMBER = 16,
  BOOLEAN = 17,
  ARRAY = 18,
  OBJECT = 19,
  KEY = 20,
  NULL = 21,
  ENUM_MEMBER = 22,
  STRUCT = 23,
  EVENT = 24,
  OPERATOR = 25,
  TYPE_PARAMETER = 26,
}

return M
