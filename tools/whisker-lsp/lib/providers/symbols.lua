-- whisker-lsp/lib/providers/symbols.lua
-- Document symbols provider (for outline view)

local interfaces = require("lib.interfaces")

local SymbolProvider = {}
SymbolProvider.__index = SymbolProvider

--- Create a new symbol provider
--- @param document_manager table DocumentManager instance
--- @param parser_integration table ParserIntegration instance
--- @return table SymbolProvider instance
function SymbolProvider.new(document_manager, parser_integration)
  local self = setmetatable({}, SymbolProvider)
  self.document_manager = document_manager
  self.parser = parser_integration
  return self
end

--- Get document symbols
--- @param uri string Document URI
--- @return table Array of document symbols
function SymbolProvider:get_symbols(uri)
  local symbols = {}

  -- Get passages
  local passages = self.parser:get_passages(uri)
  for _, passage in ipairs(passages) do
    symbols[#symbols + 1] = {
      name = passage.name,
      kind = interfaces.SymbolKind.Function,
      range = {
        start = { line = passage.line, character = 0 },
        ["end"] = { line = passage.line, character = #passage.name + 6 }  -- "=== Name ==="
      },
      selectionRange = {
        start = { line = passage.line, character = 4 },  -- After "=== "
        ["end"] = { line = passage.line, character = 4 + #passage.name }
      },
      detail = passage.tags and #passage.tags > 0
        and table.concat(passage.tags, ", ")
        or nil
    }
  end

  -- Get variables
  local variables = self.parser:get_variables(uri)
  for _, var in ipairs(variables) do
    symbols[#symbols + 1] = {
      name = var.name,
      kind = interfaces.SymbolKind.Variable,
      range = {
        start = { line = var.line, character = var.column or 0 },
        ["end"] = { line = var.line, character = (var.column or 0) + #var.name }
      },
      selectionRange = {
        start = { line = var.line, character = var.column or 0 },
        ["end"] = { line = var.line, character = (var.column or 0) + #var.name }
      },
      detail = var.type
    }
  end

  return symbols
end

return SymbolProvider
