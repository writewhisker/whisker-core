-- whisker-lsp/spec/interfaces_spec.lua
-- Tests for LSP interface definitions

-- Add tools/whisker-lsp to path for local testing
package.path = package.path .. ";./tools/whisker-lsp/?.lua;./tools/whisker-lsp/?/init.lua"

describe("LSP Interfaces", function()
  local interfaces

  before_each(function()
    interfaces = require("lib.interfaces")
  end)

  describe("IDocumentManager", function()
    it("validates complete implementation", function()
      local impl = {
        open = function() end,
        close = function() end,
        get_text = function() end,
        get_version = function() end,
        apply_changes = function() end,
        get_all_uris = function() end
      }
      local valid, err = interfaces.IDocumentManager.validate(impl)
      assert.is_true(valid)
      assert.is_nil(err)
    end)

    it("rejects incomplete implementation", function()
      local impl = {
        open = function() end,
        close = function() end
      }
      local valid, err = interfaces.IDocumentManager.validate(impl)
      assert.is_false(valid)
      assert.matches("Missing method:", err)
    end)
  end)

  describe("IParserIntegration", function()
    it("validates complete implementation", function()
      local impl = {
        parse = function() end,
        get_ast = function() end,
        invalidate = function() end,
        get_passages = function() end,
        get_variables = function() end,
        find_node_at_position = function() end
      }
      local valid, err = interfaces.IParserIntegration.validate(impl)
      assert.is_true(valid)
      assert.is_nil(err)
    end)
  end)

  describe("ICompletionProvider", function()
    it("validates complete implementation", function()
      local impl = {
        get_completions = function() end,
        resolve_completion = function() end
      }
      local valid, err = interfaces.ICompletionProvider.validate(impl)
      assert.is_true(valid)
    end)
  end)

  describe("IDiagnosticsProvider", function()
    it("validates complete implementation", function()
      local impl = {
        get_diagnostics = function() end,
        supports_format = function() end
      }
      local valid, err = interfaces.IDiagnosticsProvider.validate(impl)
      assert.is_true(valid)
    end)
  end)

  describe("IHoverProvider", function()
    it("validates complete implementation", function()
      local impl = {
        get_hover = function() end
      }
      local valid, err = interfaces.IHoverProvider.validate(impl)
      assert.is_true(valid)
    end)
  end)

  describe("IDefinitionProvider", function()
    it("validates complete implementation", function()
      local impl = {
        get_definition = function() end
      }
      local valid, err = interfaces.IDefinitionProvider.validate(impl)
      assert.is_true(valid)
    end)
  end)

  describe("ISymbolProvider", function()
    it("validates complete implementation", function()
      local impl = {
        get_symbols = function() end
      }
      local valid, err = interfaces.ISymbolProvider.validate(impl)
      assert.is_true(valid)
    end)
  end)

  describe("ITransport", function()
    it("validates complete implementation", function()
      local impl = {
        read_message = function() end,
        write_message = function() end,
        close = function() end
      }
      local valid, err = interfaces.ITransport.validate(impl)
      assert.is_true(valid)
    end)
  end)

  describe("Constants", function()
    it("defines MessageType enum", function()
      assert.equals(1, interfaces.MessageType.Error)
      assert.equals(2, interfaces.MessageType.Warning)
      assert.equals(3, interfaces.MessageType.Info)
      assert.equals(4, interfaces.MessageType.Log)
    end)

    it("defines DiagnosticSeverity enum", function()
      assert.equals(1, interfaces.DiagnosticSeverity.Error)
      assert.equals(2, interfaces.DiagnosticSeverity.Warning)
      assert.equals(3, interfaces.DiagnosticSeverity.Information)
      assert.equals(4, interfaces.DiagnosticSeverity.Hint)
    end)

    it("defines CompletionItemKind enum", function()
      assert.equals(1, interfaces.CompletionItemKind.Text)
      assert.equals(6, interfaces.CompletionItemKind.Variable)
      assert.equals(15, interfaces.CompletionItemKind.Snippet)
    end)

    it("defines SymbolKind enum", function()
      assert.equals(1, interfaces.SymbolKind.File)
      assert.equals(12, interfaces.SymbolKind.Function)
      assert.equals(13, interfaces.SymbolKind.Variable)
    end)

    it("defines TextDocumentSyncKind enum", function()
      assert.equals(0, interfaces.TextDocumentSyncKind.None)
      assert.equals(1, interfaces.TextDocumentSyncKind.Full)
      assert.equals(2, interfaces.TextDocumentSyncKind.Incremental)
    end)
  end)
end)
