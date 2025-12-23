-- whisker-lsp/lib/interfaces.lua
-- Interface definitions for LSP server components

local M = {}

--- @class IDocumentManager
--- Interface for managing open documents
--- @field open fun(self: IDocumentManager, uri: string, text: string, version: number): boolean
--- @field close fun(self: IDocumentManager, uri: string): boolean
--- @field get_text fun(self: IDocumentManager, uri: string): string|nil
--- @field get_version fun(self: IDocumentManager, uri: string): number|nil
--- @field apply_changes fun(self: IDocumentManager, uri: string, changes: table, version: number): boolean
--- @field get_all_uris fun(self: IDocumentManager): table
M.IDocumentManager = {
  _interface = "IDocumentManager",

  validate = function(impl)
    local required = {"open", "close", "get_text", "get_version", "apply_changes", "get_all_uris"}
    for _, method in ipairs(required) do
      if type(impl[method]) ~= "function" then
        return false, "Missing method: " .. method
      end
    end
    return true
  end
}

--- @class IParserIntegration
--- Interface for parser integration layer
--- @field parse fun(self: IParserIntegration, uri: string, text: string, format: string): table
--- @field get_ast fun(self: IParserIntegration, uri: string): table|nil
--- @field invalidate fun(self: IParserIntegration, uri: string): boolean
--- @field get_passages fun(self: IParserIntegration, uri: string): table
--- @field get_variables fun(self: IParserIntegration, uri: string): table
--- @field find_node_at_position fun(self: IParserIntegration, uri: string, line: number, col: number): table|nil
M.IParserIntegration = {
  _interface = "IParserIntegration",

  validate = function(impl)
    local required = {"parse", "get_ast", "invalidate", "get_passages", "get_variables", "find_node_at_position"}
    for _, method in ipairs(required) do
      if type(impl[method]) ~= "function" then
        return false, "Missing method: " .. method
      end
    end
    return true
  end
}

--- @class ICompletionProvider
--- Interface for completion providers
--- @field get_completions fun(self: ICompletionProvider, params: table): table
--- @field resolve_completion fun(self: ICompletionProvider, item: table): table
M.ICompletionProvider = {
  _interface = "ICompletionProvider",

  validate = function(impl)
    local required = {"get_completions", "resolve_completion"}
    for _, method in ipairs(required) do
      if type(impl[method]) ~= "function" then
        return false, "Missing method: " .. method
      end
    end
    return true
  end
}

--- @class IDiagnosticsProvider
--- Interface for diagnostics providers
--- @field get_diagnostics fun(self: IDiagnosticsProvider, uri: string): table
--- @field supports_format fun(self: IDiagnosticsProvider, format: string): boolean
M.IDiagnosticsProvider = {
  _interface = "IDiagnosticsProvider",

  validate = function(impl)
    local required = {"get_diagnostics", "supports_format"}
    for _, method in ipairs(required) do
      if type(impl[method]) ~= "function" then
        return false, "Missing method: " .. method
      end
    end
    return true
  end
}

--- @class IHoverProvider
--- Interface for hover documentation providers
--- @field get_hover fun(self: IHoverProvider, params: table): table|nil
M.IHoverProvider = {
  _interface = "IHoverProvider",

  validate = function(impl)
    local required = {"get_hover"}
    for _, method in ipairs(required) do
      if type(impl[method]) ~= "function" then
        return false, "Missing method: " .. method
      end
    end
    return true
  end
}

--- @class IDefinitionProvider
--- Interface for go-to-definition providers
--- @field get_definition fun(self: IDefinitionProvider, params: table): table|nil
M.IDefinitionProvider = {
  _interface = "IDefinitionProvider",

  validate = function(impl)
    local required = {"get_definition"}
    for _, method in ipairs(required) do
      if type(impl[method]) ~= "function" then
        return false, "Missing method: " .. method
      end
    end
    return true
  end
}

--- @class ISymbolProvider
--- Interface for document symbol providers
--- @field get_symbols fun(self: ISymbolProvider, uri: string): table
M.ISymbolProvider = {
  _interface = "ISymbolProvider",

  validate = function(impl)
    local required = {"get_symbols"}
    for _, method in ipairs(required) do
      if type(impl[method]) ~= "function" then
        return false, "Missing method: " .. method
      end
    end
    return true
  end
}

--- @class ITransport
--- Interface for LSP transport layer
--- @field read_message fun(self: ITransport): table|nil
--- @field write_message fun(self: ITransport, msg: table): boolean
--- @field close fun(self: ITransport): nil
M.ITransport = {
  _interface = "ITransport",

  validate = function(impl)
    local required = {"read_message", "write_message", "close"}
    for _, method in ipairs(required) do
      if type(impl[method]) ~= "function" then
        return false, "Missing method: " .. method
      end
    end
    return true
  end
}

--- LSP message types
M.MessageType = {
  Error = 1,
  Warning = 2,
  Info = 3,
  Log = 4
}

--- LSP diagnostic severity
M.DiagnosticSeverity = {
  Error = 1,
  Warning = 2,
  Information = 3,
  Hint = 4
}

--- LSP completion item kinds
M.CompletionItemKind = {
  Text = 1,
  Method = 2,
  Function = 3,
  Constructor = 4,
  Field = 5,
  Variable = 6,
  Class = 7,
  Interface = 8,
  Module = 9,
  Property = 10,
  Unit = 11,
  Value = 12,
  Enum = 13,
  Keyword = 14,
  Snippet = 15,
  Color = 16,
  File = 17,
  Reference = 18,
  Folder = 19,
  EnumMember = 20,
  Constant = 21,
  Struct = 22,
  Event = 23,
  Operator = 24,
  TypeParameter = 25
}

--- LSP symbol kinds
M.SymbolKind = {
  File = 1,
  Module = 2,
  Namespace = 3,
  Package = 4,
  Class = 5,
  Method = 6,
  Property = 7,
  Field = 8,
  Constructor = 9,
  Enum = 10,
  Interface = 11,
  Function = 12,
  Variable = 13,
  Constant = 14,
  String = 15,
  Number = 16,
  Boolean = 17,
  Array = 18,
  Object = 19,
  Key = 20,
  Null = 21,
  EnumMember = 22,
  Struct = 23,
  Event = 24,
  Operator = 25,
  TypeParameter = 26
}

--- LSP text document sync kind
M.TextDocumentSyncKind = {
  None = 0,
  Full = 1,
  Incremental = 2
}

return M
