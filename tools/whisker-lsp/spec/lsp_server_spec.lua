-- whisker-lsp/spec/lsp_server_spec.lua
-- Tests for LSP server core

package.path = package.path .. ";./tools/whisker-lsp/?.lua;./tools/whisker-lsp/?/init.lua"

describe("LspServer", function()
  local LspServer
  local interfaces

  before_each(function()
    LspServer = require("lib.lsp_server")
    interfaces = require("lib.interfaces")
  end)

  describe("initialization", function()
    it("creates server with default config", function()
      local server = LspServer.new()
      assert.is_not_nil(server)
      assert.is_not_nil(server.document_manager)
      assert.is_false(server.initialized)
    end)

    it("creates server with custom config", function()
      local server = LspServer.new({ debounce_ms = 500 })
      assert.is_not_nil(server)
    end)
  end)

  describe("handle_initialize", function()
    it("returns server capabilities", function()
      local server = LspServer.new()

      local result = server:handle_initialize({
        capabilities = {},
        rootUri = "file:///workspace"
      })

      assert.is_not_nil(result.capabilities)
      assert.is_not_nil(result.serverInfo)
      assert.equals("whisker-lsp", result.serverInfo.name)
    end)

    it("includes completion capabilities", function()
      local server = LspServer.new()

      local result = server:handle_initialize({ capabilities = {} })

      assert.is_not_nil(result.capabilities.completionProvider)
      assert.is_table(result.capabilities.completionProvider.triggerCharacters)
    end)

    it("includes hover capability", function()
      local server = LspServer.new()

      local result = server:handle_initialize({ capabilities = {} })

      assert.is_true(result.capabilities.hoverProvider)
    end)

    it("includes definition capability", function()
      local server = LspServer.new()

      local result = server:handle_initialize({ capabilities = {} })

      assert.is_true(result.capabilities.definitionProvider)
    end)

    it("uses incremental text sync", function()
      local server = LspServer.new()

      local result = server:handle_initialize({ capabilities = {} })

      assert.equals(
        interfaces.TextDocumentSyncKind.Incremental,
        result.capabilities.textDocumentSync.change
      )
    end)
  end)

  describe("handle_shutdown", function()
    it("sets shutdown flag", function()
      local server = LspServer.new()

      local result = server:handle_shutdown({})

      assert.is_nil(result)  -- null response
      assert.is_true(server.shutdown_requested)
    end)
  end)

  describe("document lifecycle", function()
    it("opens document on didOpen", function()
      local server = LspServer.new()

      server:handle_did_open({
        textDocument = {
          uri = "file:///test.ink",
          languageId = "ink",
          version = 1,
          text = "hello world"
        }
      })

      local dm = server:get_document_manager()
      assert.is_true(dm:is_open("file:///test.ink"))
      assert.equals("hello world", dm:get_text("file:///test.ink"))
    end)

    it("updates document on didChange", function()
      local server = LspServer.new()

      server:handle_did_open({
        textDocument = {
          uri = "file:///test.ink",
          languageId = "ink",
          version = 1,
          text = "hello world"
        }
      })

      server:handle_did_change({
        textDocument = { uri = "file:///test.ink", version = 2 },
        contentChanges = { { text = "goodbye world" } }
      })

      local dm = server:get_document_manager()
      assert.equals("goodbye world", dm:get_text("file:///test.ink"))
      assert.equals(2, dm:get_version("file:///test.ink"))
    end)

    it("closes document on didClose", function()
      local server = LspServer.new()

      server:handle_did_open({
        textDocument = {
          uri = "file:///test.ink",
          languageId = "ink",
          version = 1,
          text = "hello"
        }
      })

      server:handle_did_close({
        textDocument = { uri = "file:///test.ink" }
      })

      local dm = server:get_document_manager()
      assert.is_false(dm:is_open("file:///test.ink"))
    end)
  end)

  describe("providers", function()
    it("registers completion provider", function()
      local server = LspServer.new()

      local provider = {
        get_completions = function() return { items = {} } end,
        resolve_completion = function(item) return item end
      }

      server:register_provider("completion", provider)
      assert.equals(provider, server.providers.completion)
    end)

    it("returns empty completion when no provider", function()
      local server = LspServer.new()

      local result = server:handle_completion({
        textDocument = { uri = "file:///test.ink" },
        position = { line = 0, character = 0 }
      })

      assert.is_false(result.isIncomplete)
      assert.equals(0, #result.items)
    end)

    it("returns nil hover when no provider", function()
      local server = LspServer.new()

      local result = server:handle_hover({
        textDocument = { uri = "file:///test.ink" },
        position = { line = 0, character = 0 }
      })

      assert.is_nil(result)
    end)

    it("returns nil definition when no provider", function()
      local server = LspServer.new()

      local result = server:handle_definition({
        textDocument = { uri = "file:///test.ink" },
        position = { line = 0, character = 0 }
      })

      assert.is_nil(result)
    end)

    it("returns empty symbols when no provider", function()
      local server = LspServer.new()

      local result = server:handle_document_symbol({
        textDocument = { uri = "file:///test.ink" }
      })

      assert.equals(0, #result)
    end)
  end)
end)
