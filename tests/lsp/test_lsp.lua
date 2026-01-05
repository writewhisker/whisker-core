--- LSP Module Tests
-- Tests for the Language Server Protocol implementation
-- @module tests.lsp.test_lsp

local helper = require("tests.test_helper")
local LSP = require("whisker.lsp")

describe("LSP Module", function()
  describe("Server", function()
    local server

    before_each(function()
      server = LSP.create_server()
    end)

    it("should create server instance", function()
      assert.is_not_nil(server)
    end)

    it("should return capabilities on initialize", function()
      local result = server:initialize({
        capabilities = {},
        rootUri = "file:///test",
      })

      assert.is_not_nil(result)
      assert.is_not_nil(result.capabilities)
      assert.is_not_nil(result.serverInfo)
      assert.equals("whisker-lsp", result.serverInfo.name)
    end)

    it("should handle textDocument/didOpen", function()
      server:initialize({})

      server:did_open({
        textDocument = {
          uri = "file:///test.wls",
          text = ":: Start\nHello world!",
          version = 1,
        },
      })

      local doc = server:get_documents():get("file:///test.wls")
      assert.is_not_nil(doc)
      assert.equals(":: Start\nHello world!", doc.content)
    end)

    it("should handle textDocument/didChange", function()
      server:initialize({})

      server:did_open({
        textDocument = { uri = "file:///test.wls", text = "Old content", version = 1 },
      })

      server:did_change({
        textDocument = { uri = "file:///test.wls", version = 2 },
        contentChanges = { { text = "New content" } },
      })

      local doc = server:get_documents():get("file:///test.wls")
      assert.equals("New content", doc.content)
      assert.equals(2, doc.version)
    end)

    it("should handle textDocument/didClose", function()
      server:initialize({})

      server:did_open({
        textDocument = { uri = "file:///test.wls", text = "Content", version = 1 },
      })

      server:did_close({
        textDocument = { uri = "file:///test.wls" },
      })

      local doc = server:get_documents():get("file:///test.wls")
      assert.is_nil(doc)
    end)

    it("should handle shutdown", function()
      server:initialize({})
      local result = server:shutdown()
      assert.is_nil(result)
    end)

    it("should handle JSON-RPC messages", function()
      local response = server:handle_message({
        jsonrpc = "2.0",
        id = 1,
        method = "initialize",
        params = { capabilities = {} },
      })

      assert.equals("2.0", response.jsonrpc)
      assert.equals(1, response.id)
      assert.is_not_nil(response.result)
      assert.is_not_nil(response.result.capabilities)
    end)

    it("should return error for unknown method", function()
      server:initialize({})

      local response = server:handle_message({
        jsonrpc = "2.0",
        id = 1,
        method = "unknownMethod",
        params = {},
      })

      assert.is_not_nil(response.error)
      assert.equals(-32601, response.error.code)
    end)
  end)

  describe("Document Manager", function()
    local documents

    before_each(function()
      documents = LSP.Document.new()
    end)

    it("should open documents", function()
      documents:open("file:///test.wls", "Hello world!", 1)

      local doc = documents:get("file:///test.wls")
      assert.is_not_nil(doc)
      assert.equals("Hello world!", doc.content)
      assert.equals(1, doc.version)
    end)

    it("should get lines", function()
      documents:open("file:///test.wls", "Line 1\nLine 2\nLine 3", 1)

      local lines = documents:get_lines("file:///test.wls")
      assert.equals(3, #lines)
      assert.equals("Line 1", lines[1])
      assert.equals("Line 2", lines[2])
      assert.equals("Line 3", lines[3])
    end)

    it("should get single line", function()
      documents:open("file:///test.wls", "Line 1\nLine 2\nLine 3", 1)

      local line = documents:get_line("file:///test.wls", 1)
      assert.equals("Line 2", line)
    end)

    it("should get word at position", function()
      documents:open("file:///test.wls", "Hello $variable world", 1)

      local word, start_char, end_char = documents:get_word_at("file:///test.wls", 0, 8)
      assert.equals("$variable", word)
      assert.equals(6, start_char)
      assert.equals(15, end_char)
    end)

    it("should get text before position", function()
      documents:open("file:///test.wls", "Hello world", 1)

      local text = documents:get_text_before("file:///test.wls", 0, 5)
      assert.equals("Hello", text)
    end)

    it("should convert position to offset", function()
      documents:open("file:///test.wls", "Line 1\nLine 2\nLine 3", 1)

      local offset = documents:position_to_offset("file:///test.wls", 1, 2)
      assert.equals(9, offset) -- "Line 1\n" (7) + "Li" (2) = 9
    end)

    it("should convert offset to position", function()
      documents:open("file:///test.wls", "Line 1\nLine 2\nLine 3", 1)

      local line, char = documents:offset_to_position("file:///test.wls", 9)
      assert.equals(1, line)
      assert.equals(2, char)
    end)
  end)

  describe("Completion Provider", function()
    local server

    before_each(function()
      server = LSP.create_server()
      server:initialize({})
    end)

    it("should provide passage completions after ->", function()
      server:did_open({
        textDocument = {
          uri = "file:///test.wls",
          text = ":: Start\nHello -> \n\n:: End\nGoodbye",
          version = 1,
        },
      })

      local result = server:completion({
        textDocument = { uri = "file:///test.wls" },
        position = { line = 1, character = 9 },
      })

      assert.is_not_nil(result)
      assert.is_not_nil(result.items)

      -- Should include special targets
      local has_end = false
      for _, item in ipairs(result.items) do
        if item.label == "END" then has_end = true end
      end
      assert.is_true(has_end)
    end)

    it("should provide variable completions after $", function()
      server:did_open({
        textDocument = {
          uri = "file:///test.wls",
          text = "VAR score = 0\n:: Start\nYou have $",
          version = 1,
        },
      })

      local result = server:completion({
        textDocument = { uri = "file:///test.wls" },
        position = { line = 2, character = 10 },
      })

      assert.is_not_nil(result.items)

      local has_score = false
      for _, item in ipairs(result.items) do
        if item.label == "score" then has_score = true end
      end
      assert.is_true(has_score)
    end)

    it("should provide default completions", function()
      server:did_open({
        textDocument = {
          uri = "file:///test.wls",
          text = "",
          version = 1,
        },
      })

      local result = server:completion({
        textDocument = { uri = "file:///test.wls" },
        position = { line = 0, character = 0 },
      })

      assert.is_not_nil(result.items)
      assert.is_true(#result.items > 0)
    end)
  end)

  describe("Hover Provider", function()
    local server

    before_each(function()
      server = LSP.create_server()
      server:initialize({})
    end)

    it("should provide hover for variables", function()
      server:did_open({
        textDocument = {
          uri = "file:///test.wls",
          text = "VAR score = 100\n:: Start\nYou have $score points",
          version = 1,
        },
      })

      local result = server:hover({
        textDocument = { uri = "file:///test.wls" },
        position = { line = 2, character = 11 },
      })

      assert.is_not_nil(result)
      assert.is_not_nil(result.contents)
      assert.is_true(result.contents.value:find("score") ~= nil)
    end)

    it("should provide hover for passages", function()
      server:did_open({
        textDocument = {
          uri = "file:///test.wls",
          text = ":: Start\nHello -> End\n\n:: End\nGoodbye",
          version = 1,
        },
      })

      local result = server:hover({
        textDocument = { uri = "file:///test.wls" },
        position = { line = 1, character = 10 },
      })

      assert.is_not_nil(result)
      assert.is_not_nil(result.contents)
    end)
  end)

  describe("Navigation Provider", function()
    local server

    before_each(function()
      server = LSP.create_server()
      server:initialize({})
    end)

    it("should find passage definition", function()
      server:did_open({
        textDocument = {
          uri = "file:///test.wls",
          text = ":: Start\nHello -> End\n\n:: End\nGoodbye",
          version = 1,
        },
      })

      local result = server:definition({
        textDocument = { uri = "file:///test.wls" },
        position = { line = 1, character = 10 },
      })

      assert.is_not_nil(result)
      assert.equals(3, result.range.start.line) -- :: End is on line 4 (0-indexed: 3)
    end)

    it("should find variable definition", function()
      server:did_open({
        textDocument = {
          uri = "file:///test.wls",
          text = "VAR score = 100\n:: Start\nYou have $score points",
          version = 1,
        },
      })

      local result = server:definition({
        textDocument = { uri = "file:///test.wls" },
        position = { line = 2, character = 11 },
      })

      assert.is_not_nil(result)
      assert.equals(0, result.range.start.line)
    end)

    it("should find references to passage", function()
      server:did_open({
        textDocument = {
          uri = "file:///test.wls",
          text = ":: Start\n+ [Go] -> End\n+ [Also] -> End\n\n:: End\nDone",
          version = 1,
        },
      })

      local result = server:references({
        textDocument = { uri = "file:///test.wls" },
        position = { line = 4, character = 4 },
      })

      assert.is_not_nil(result)
      assert.is_true(#result >= 3) -- Definition + 2 references
    end)
  end)

  describe("Symbols Provider", function()
    local server

    before_each(function()
      server = LSP.create_server()
      server:initialize({})
    end)

    it("should provide document symbols", function()
      server:did_open({
        textDocument = {
          uri = "file:///test.wls",
          text = "VAR health = 100\n\n:: Start\nHello\n+ [Choice] -> End\n\n:: End\nGoodbye",
          version = 1,
        },
      })

      local result = server:document_symbol({
        textDocument = { uri = "file:///test.wls" },
      })

      assert.is_not_nil(result)
      assert.is_true(#result >= 2) -- At least 2 passages
    end)

    it("should provide folding ranges", function()
      server:did_open({
        textDocument = {
          uri = "file:///test.wls",
          text = ":: Start\nLine 1\nLine 2\nLine 3\n\n:: End\nDone",
          version = 1,
        },
      })

      local result = server:folding_range({
        textDocument = { uri = "file:///test.wls" },
      })

      assert.is_not_nil(result)
      assert.is_true(#result >= 1)
    end)
  end)

  describe("Diagnostics Provider", function()
    local server
    local published_diagnostics = {}

    before_each(function()
      published_diagnostics = {}
      server = LSP.create_server({
        on_notification = function(method, params)
          if method == "textDocument/publishDiagnostics" then
            published_diagnostics[params.uri] = params.diagnostics
          end
        end,
      })
      server:initialize({})
    end)

    it("should detect broken links", function()
      server:did_open({
        textDocument = {
          uri = "file:///test.wls",
          text = ":: Start\nHello -> NonExistent\n",
          version = 1,
        },
      })

      local diags = published_diagnostics["file:///test.wls"]
      assert.is_not_nil(diags)
      assert.is_true(#diags > 0)

      local has_broken_link = false
      for _, d in ipairs(diags) do
        if d.message:find("Broken link") then
          has_broken_link = true
          break
        end
      end
      assert.is_true(has_broken_link)
    end)

    it("should detect unbalanced braces", function()
      server:did_open({
        textDocument = {
          uri = "file:///test.wls",
          text = ":: Start\n{if condition\nNo closing brace",
          version = 1,
        },
      })

      local diags = published_diagnostics["file:///test.wls"]
      assert.is_not_nil(diags)

      local has_brace_error = false
      for _, d in ipairs(diags) do
        if d.message:find("brace") then
          has_brace_error = true
          break
        end
      end
      assert.is_true(has_brace_error)
    end)

    it("should detect duplicate passages", function()
      server:did_open({
        textDocument = {
          uri = "file:///test.wls",
          text = ":: Start\nHello\n\n:: Start\nDuplicate!",
          version = 1,
        },
      })

      local diags = published_diagnostics["file:///test.wls"]
      assert.is_not_nil(diags)

      local has_duplicate = false
      for _, d in ipairs(diags) do
        if d.message:find("Duplicate") then
          has_duplicate = true
          break
        end
      end
      assert.is_true(has_duplicate)
    end)

    it("should warn about undefined variables", function()
      server:did_open({
        textDocument = {
          uri = "file:///test.wls",
          text = ":: Start\nYou have $undefined_var points",
          version = 1,
        },
      })

      local diags = published_diagnostics["file:///test.wls"]
      assert.is_not_nil(diags)

      local has_undefined = false
      for _, d in ipairs(diags) do
        if d.message:find("may not be defined") then
          has_undefined = true
          break
        end
      end
      assert.is_true(has_undefined)
    end)

    it("should not warn about defined variables", function()
      server:did_open({
        textDocument = {
          uri = "file:///test.wls",
          text = "VAR score = 100\n:: Start\nYou have $score points",
          version = 1,
        },
      })

      local diags = published_diagnostics["file:///test.wls"]

      local has_score_warning = false
      if diags then
        for _, d in ipairs(diags) do
          if d.message:find("score") and d.message:find("may not be defined") then
            has_score_warning = true
            break
          end
        end
      end
      assert.is_false(has_score_warning)
    end)
  end)
end)
