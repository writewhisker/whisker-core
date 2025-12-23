-- whisker-lsp/lib/lsp_server.lua
-- Main LSP server implementation

local Transport = require("lib.transport")
local DocumentManager = require("lib.document_manager")
local interfaces = require("lib.interfaces")

local LspServer = {}
LspServer.__index = LspServer

--- Create a new LSP server
--- @param config table? Server configuration
--- @return table LspServer instance
function LspServer.new(config)
  local self = setmetatable({}, LspServer)

  self.config = config or {}
  self.transport = Transport.new()
  self.document_manager = DocumentManager.new()

  -- Request handlers
  self.handlers = {}

  -- Notification handlers
  self.notification_handlers = {}

  -- Providers
  self.providers = {
    completion = nil,
    diagnostics = nil,
    hover = nil,
    definition = nil,
    symbols = nil
  }

  -- State
  self.initialized = false
  self.shutdown_requested = false
  self.request_id = 0

  -- Register core handlers
  self:register_core_handlers()

  return self
end

--- Register core LSP handlers
function LspServer:register_core_handlers()
  -- Initialize request
  self.handlers["initialize"] = function(params)
    return self:handle_initialize(params)
  end

  -- Shutdown request
  self.handlers["shutdown"] = function(params)
    return self:handle_shutdown(params)
  end

  -- Initialized notification
  self.notification_handlers["initialized"] = function(params)
    self:handle_initialized(params)
  end

  -- Exit notification
  self.notification_handlers["exit"] = function(params)
    self:handle_exit(params)
  end

  -- Document lifecycle
  self.notification_handlers["textDocument/didOpen"] = function(params)
    self:handle_did_open(params)
  end

  self.notification_handlers["textDocument/didChange"] = function(params)
    self:handle_did_change(params)
  end

  self.notification_handlers["textDocument/didClose"] = function(params)
    self:handle_did_close(params)
  end

  self.notification_handlers["textDocument/didSave"] = function(params)
    self:handle_did_save(params)
  end

  -- Requests
  self.handlers["textDocument/completion"] = function(params)
    return self:handle_completion(params)
  end

  self.handlers["textDocument/hover"] = function(params)
    return self:handle_hover(params)
  end

  self.handlers["textDocument/definition"] = function(params)
    return self:handle_definition(params)
  end

  self.handlers["textDocument/documentSymbol"] = function(params)
    return self:handle_document_symbol(params)
  end
end

--- Run the server main loop
function LspServer:run()
  while not self.transport:is_closed() do
    local msg = self.transport:read_message()
    if not msg then
      break
    end

    self:dispatch(msg)

    if self.shutdown_requested then
      break
    end
  end
end

--- Dispatch a message to appropriate handler
--- @param msg table LSP message
function LspServer:dispatch(msg)
  if msg.method then
    if msg.id then
      -- Request
      self:handle_request(msg)
    else
      -- Notification
      self:handle_notification(msg)
    end
  elseif msg.id then
    -- Response to our request (not common for LSP server)
    self:handle_response(msg)
  end
end

--- Handle a request message
--- @param msg table Request message
function LspServer:handle_request(msg)
  local handler = self.handlers[msg.method]

  if handler then
    local ok, result = pcall(handler, msg.params)
    if ok then
      self:send_response(msg.id, result)
    else
      self:send_error(msg.id, -32603, "Internal error: " .. tostring(result))
    end
  else
    self:send_error(msg.id, -32601, "Method not found: " .. msg.method)
  end
end

--- Handle a notification message
--- @param msg table Notification message
function LspServer:handle_notification(msg)
  local handler = self.notification_handlers[msg.method]
  if handler then
    local ok, err = pcall(handler, msg.params)
    if not ok then
      self:log_message(interfaces.MessageType.Error, "Notification error: " .. tostring(err))
    end
  end
end

--- Handle a response message
--- @param msg table Response message
function LspServer:handle_response(msg)
  -- Not typically needed for LSP server
end

--- Send a response
--- @param id number|string Request ID
--- @param result any Result value
function LspServer:send_response(id, result)
  self.transport:write_message({
    jsonrpc = "2.0",
    id = id,
    result = result
  })
end

--- Send an error response
--- @param id number|string Request ID
--- @param code number Error code
--- @param message string Error message
function LspServer:send_error(id, code, message)
  self.transport:write_message({
    jsonrpc = "2.0",
    id = id,
    error = {
      code = code,
      message = message
    }
  })
end

--- Send a notification
--- @param method string Notification method
--- @param params table? Notification params
function LspServer:send_notification(method, params)
  self.transport:write_message({
    jsonrpc = "2.0",
    method = method,
    params = params or {}
  })
end

--- Send a request
--- @param method string Request method
--- @param params table? Request params
--- @return number Request ID
function LspServer:send_request(method, params)
  self.request_id = self.request_id + 1
  self.transport:write_message({
    jsonrpc = "2.0",
    id = self.request_id,
    method = method,
    params = params or {}
  })
  return self.request_id
end

--- Log a message to client
--- @param type number Message type (from interfaces.MessageType)
--- @param message string Message text
function LspServer:log_message(type, message)
  self:send_notification("window/logMessage", {
    type = type,
    message = message
  })
end

--- Publish diagnostics
--- @param uri string Document URI
--- @param diagnostics table Array of diagnostics
function LspServer:publish_diagnostics(uri, diagnostics)
  self:send_notification("textDocument/publishDiagnostics", {
    uri = uri,
    diagnostics = diagnostics
  })
end

-- Handler implementations

function LspServer:handle_initialize(params)
  self.client_capabilities = params.capabilities or {}
  self.root_uri = params.rootUri
  self.root_path = params.rootPath

  local capabilities = {
    textDocumentSync = {
      openClose = true,
      change = interfaces.TextDocumentSyncKind.Incremental,
      save = { includeText = false }
    },
    completionProvider = {
      triggerCharacters = { "-", ">", "{", "<", ":" },
      resolveProvider = false
    },
    hoverProvider = true,
    definitionProvider = true,
    documentSymbolProvider = true
  }

  return {
    capabilities = capabilities,
    serverInfo = {
      name = "whisker-lsp",
      version = "0.1.0"
    }
  }
end

function LspServer:handle_initialized(params)
  self.initialized = true
  self:log_message(interfaces.MessageType.Info, "whisker-lsp initialized")
end

function LspServer:handle_shutdown(params)
  self.shutdown_requested = true
  return nil  -- null response for shutdown
end

function LspServer:handle_exit(params)
  self.transport:close()
  os.exit(self.shutdown_requested and 0 or 1)
end

function LspServer:handle_did_open(params)
  local doc = params.textDocument
  self.document_manager:open(doc.uri, doc.text, doc.version, doc.languageId)

  -- Trigger initial diagnostics
  self:update_diagnostics(doc.uri)
end

function LspServer:handle_did_change(params)
  local uri = params.textDocument.uri
  local version = params.textDocument.version
  local changes = params.contentChanges

  self.document_manager:apply_changes(uri, changes, version)

  -- Trigger diagnostics update
  self:update_diagnostics(uri)
end

function LspServer:handle_did_close(params)
  local uri = params.textDocument.uri
  self.document_manager:close(uri)

  -- Clear diagnostics
  self:publish_diagnostics(uri, {})
end

function LspServer:handle_did_save(params)
  local uri = params.textDocument.uri
  -- Could trigger additional validation on save
  self:update_diagnostics(uri)
end

function LspServer:handle_completion(params)
  if not self.providers.completion then
    return { isIncomplete = false, items = {} }
  end
  return self.providers.completion:get_completions(params)
end

function LspServer:handle_hover(params)
  if not self.providers.hover then
    return nil
  end
  return self.providers.hover:get_hover(params)
end

function LspServer:handle_definition(params)
  if not self.providers.definition then
    return nil
  end
  return self.providers.definition:get_definition(params)
end

function LspServer:handle_document_symbol(params)
  if not self.providers.symbols then
    return {}
  end
  return self.providers.symbols:get_symbols(params.textDocument.uri)
end

--- Update diagnostics for a document
--- @param uri string Document URI
function LspServer:update_diagnostics(uri)
  if self.providers.diagnostics then
    local diagnostics = self.providers.diagnostics:get_diagnostics(uri)
    self:publish_diagnostics(uri, diagnostics)
  end
end

--- Register a provider
--- @param type string Provider type ("completion", "diagnostics", "hover", "definition", "symbols")
--- @param provider table Provider instance
function LspServer:register_provider(type, provider)
  self.providers[type] = provider
end

--- Get document manager
--- @return table DocumentManager instance
function LspServer:get_document_manager()
  return self.document_manager
end

return LspServer
