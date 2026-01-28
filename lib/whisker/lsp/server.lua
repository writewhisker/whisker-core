--- LSP Server
-- Main Language Server Protocol implementation for WLS 1.0
-- @module whisker.lsp.server
-- @author Whisker Core Team
-- @license MIT

local Server = {}
Server.__index = Server
Server._dependencies = {}

-- Load LSP submodules
local Document = require("whisker.lsp.document")
local Completion = require("whisker.lsp.completion")
local Hover = require("whisker.lsp.hover")
local Navigation = require("whisker.lsp.navigation")
local Symbols = require("whisker.lsp.symbols")
local Diagnostics = require("whisker.lsp.diagnostics")
local CodeActions = require("whisker.lsp.code_actions")
local SemanticTokens = require("whisker.lsp.semantic_tokens")
local Rename = require("whisker.lsp.rename")

-- Create semantic tokens legend for capability registration
local function create_semantic_tokens_legend()
  return {
    tokenTypes = SemanticTokens.TOKEN_TYPES,
    tokenModifiers = SemanticTokens.TOKEN_MODIFIERS
  }
end

--- Server capabilities
local DEFAULT_CAPABILITIES = {
  textDocumentSync = {
    openClose = true,
    change = 2, -- Incremental
    save = { includeText = true },
  },
  completionProvider = {
    triggerCharacters = { "$", "-", ">", "[", ".", ":" },
    resolveProvider = false,
  },
  hoverProvider = true,
  definitionProvider = true,
  referencesProvider = true,
  documentSymbolProvider = true,
  foldingRangeProvider = true,
  workspaceSymbolProvider = false,
  codeActionProvider = {
    codeActionKinds = {
      "quickfix",
      "refactor",
      "refactor.extract",
      "source"
    }
  },
  semanticTokensProvider = {
    legend = create_semantic_tokens_legend(),
    full = true,
    range = false
  },
  renameProvider = {
    prepareProvider = true
  }
}

--- Create a new LSP server
-- @param options table Server options
-- @return Server Server instance
function Server.new(options)
  options = options or {}
  local self = setmetatable({}, Server)

  self._initialized = false
  self._shutdown = false
  self._capabilities = options.capabilities or DEFAULT_CAPABILITIES

  -- Document manager
  self._documents = Document.new()

  -- Providers
  self._completion = Completion.new({ documents = self._documents })
  self._hover = Hover.new({ documents = self._documents })
  self._navigation = Navigation.new({ documents = self._documents })
  self._symbols = Symbols.new({ documents = self._documents })
  self._diagnostics = Diagnostics.new({ documents = self._documents })
  self._code_actions = CodeActions.new({ documents = self._documents })
  self._semantic_tokens = SemanticTokens.new({ documents = self._documents })
  self._rename = Rename.new({
    documents = self._documents,
    navigation = self._navigation
  })

  -- Parser reference (set via set_parser)
  self._parser = nil

  -- Callbacks for sending responses
  self._on_notification = options.on_notification or function() end
  self._on_response = options.on_response or function() end

  return self
end

--- Set the parser for document analysis
-- @param parser table Parser instance with parse(content) method
function Server:set_parser(parser)
  self._parser = parser
  self._completion:set_parser(parser)
  self._hover:set_parser(parser)
  self._navigation:set_parser(parser)
  self._symbols:set_parser(parser)
  self._diagnostics:set_parser(parser)
  self._code_actions:set_parser(parser)
  self._semantic_tokens:set_parser(parser)
  self._rename:set_parser(parser)
end

--- Get server capabilities
-- @return table Server capabilities
function Server:get_capabilities()
  return self._capabilities
end

--- Handle initialize request
-- @param params table Initialize params
-- @return table Initialize result
function Server:initialize(params)
  self._initialized = true
  self._client_capabilities = params.capabilities or {}
  self._root_uri = params.rootUri
  self._root_path = params.rootPath

  return {
    capabilities = self._capabilities,
    serverInfo = {
      name = "whisker-lsp",
      version = "1.0.0",
    },
  }
end

--- Handle initialized notification
function Server:initialized()
  -- Server is now fully initialized
end

--- Handle shutdown request
-- @return nil
function Server:shutdown()
  self._shutdown = true
  return nil
end

--- Handle exit notification
-- @return boolean Should exit
function Server:exit()
  return true
end

--- Handle textDocument/didOpen notification
-- @param params table Open params
function Server:did_open(params)
  local doc = params.textDocument
  self._documents:open(doc.uri, doc.text, doc.version)

  -- Validate document
  self:_validate_document(doc.uri)
end

--- Handle textDocument/didChange notification
-- @param params table Change params
function Server:did_change(params)
  local doc = params.textDocument
  local changes = params.contentChanges

  -- Handle full sync or incremental
  if changes and #changes > 0 then
    -- Use the last full content change
    for i = #changes, 1, -1 do
      if not changes[i].range then
        self._documents:update(doc.uri, changes[i].text, doc.version)
        break
      end
    end
  end

  -- Validate document
  self:_validate_document(doc.uri)
end

--- Handle textDocument/didClose notification
-- @param params table Close params
function Server:did_close(params)
  local doc = params.textDocument
  self._documents:close(doc.uri)

  -- Clear diagnostics
  self._on_notification("textDocument/publishDiagnostics", {
    uri = doc.uri,
    diagnostics = {},
  })
end

--- Handle textDocument/didSave notification
-- @param params table Save params
function Server:did_save(params)
  local doc = params.textDocument

  -- Re-validate on save if text was included
  if params.text then
    self._documents:update(doc.uri, params.text)
  end
  self:_validate_document(doc.uri)
end

--- Handle textDocument/completion request
-- @param params table Completion params
-- @return table Completion result
function Server:completion(params)
  local uri = params.textDocument.uri
  local position = params.position

  return self._completion:get_completions(uri, position.line, position.character)
end

--- Handle textDocument/hover request
-- @param params table Hover params
-- @return table|nil Hover result
function Server:hover(params)
  local uri = params.textDocument.uri
  local position = params.position

  return self._hover:get_hover(uri, position.line, position.character)
end

--- Handle textDocument/definition request
-- @param params table Definition params
-- @return table|nil Definition result
function Server:definition(params)
  local uri = params.textDocument.uri
  local position = params.position

  return self._navigation:get_definition(uri, position.line, position.character)
end

--- Handle textDocument/references request
-- @param params table References params
-- @return table References result
function Server:references(params)
  local uri = params.textDocument.uri
  local position = params.position

  return self._navigation:get_references(uri, position.line, position.character)
end

--- Handle textDocument/documentSymbol request
-- @param params table Document symbol params
-- @return table Document symbols
function Server:document_symbol(params)
  local uri = params.textDocument.uri

  return self._symbols:get_symbols(uri)
end

--- Handle textDocument/foldingRange request
-- @param params table Folding range params
-- @return table Folding ranges
function Server:folding_range(params)
  local uri = params.textDocument.uri

  return self._symbols:get_folding_ranges(uri)
end

--- Handle textDocument/codeAction request
-- @param params table Code action params
-- @return table Array of code actions
function Server:code_action(params)
  local uri = params.textDocument.uri
  local range = params.range
  local context = params.context or {}

  return self._code_actions:get_actions(uri, range, context)
end

--- Handle textDocument/semanticTokens/full request
-- @param params table Semantic tokens params
-- @return table Semantic tokens result
function Server:semantic_tokens_full(params)
  local uri = params.textDocument.uri

  return self._semantic_tokens:get_full(uri)
end

--- Handle textDocument/prepareRename request
-- @param params table Prepare rename params
-- @return table|nil Prepare rename result
function Server:prepare_rename(params)
  local uri = params.textDocument.uri
  local position = params.position

  return self._rename:prepare_rename(uri, position.line, position.character)
end

--- Handle textDocument/rename request
-- @param params table Rename params
-- @return table|nil Workspace edit
function Server:rename(params)
  local uri = params.textDocument.uri
  local position = params.position
  local new_name = params.newName

  return self._rename:do_rename(uri, position.line, position.character, new_name)
end

--- Validate a document and publish diagnostics
-- @param uri string Document URI
function Server:_validate_document(uri)
  local diagnostics = self._diagnostics:validate(uri)

  self._on_notification("textDocument/publishDiagnostics", {
    uri = uri,
    diagnostics = diagnostics,
  })
end

--- Handle incoming JSON-RPC message
-- @param message table JSON-RPC message
-- @return table|nil Response message
function Server:handle_message(message)
  local method = message.method
  local params = message.params or {}
  local id = message.id

  -- Notification (no id)
  if not id then
    return self:_handle_notification(method, params)
  end

  -- Request (has id)
  local result, err = self:_handle_request(method, params)

  if err then
    return {
      jsonrpc = "2.0",
      id = id,
      error = {
        code = err.code or -32603,
        message = err.message or "Internal error",
      },
    }
  end

  return {
    jsonrpc = "2.0",
    id = id,
    result = result,
  }
end

--- Handle notification
-- @param method string Method name
-- @param params table Parameters
-- @return nil
function Server:_handle_notification(method, params)
  if method == "initialized" then
    self:initialized()
  elseif method == "exit" then
    self:exit()
  elseif method == "textDocument/didOpen" then
    self:did_open(params)
  elseif method == "textDocument/didChange" then
    self:did_change(params)
  elseif method == "textDocument/didClose" then
    self:did_close(params)
  elseif method == "textDocument/didSave" then
    self:did_save(params)
  end

  return nil
end

--- Handle request
-- @param method string Method name
-- @param params table Parameters
-- @return any result
-- @return table|nil error
function Server:_handle_request(method, params)
  if method == "initialize" then
    return self:initialize(params)
  elseif method == "shutdown" then
    return self:shutdown()
  elseif method == "textDocument/completion" then
    return self:completion(params)
  elseif method == "textDocument/hover" then
    return self:hover(params)
  elseif method == "textDocument/definition" then
    return self:definition(params)
  elseif method == "textDocument/references" then
    return self:references(params)
  elseif method == "textDocument/documentSymbol" then
    return self:document_symbol(params)
  elseif method == "textDocument/foldingRange" then
    return self:folding_range(params)
  elseif method == "textDocument/codeAction" then
    return self:code_action(params)
  elseif method == "textDocument/semanticTokens/full" then
    return self:semantic_tokens_full(params)
  elseif method == "textDocument/prepareRename" then
    return self:prepare_rename(params)
  elseif method == "textDocument/rename" then
    return self:rename(params)
  else
    return nil, { code = -32601, message = "Method not found: " .. method }
  end
end

--- Get document manager
-- @return Document Document manager
function Server:get_documents()
  return self._documents
end

return Server
