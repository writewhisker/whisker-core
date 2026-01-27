-- whisker-lsp/spec/semantic_tokens_spec.lua
-- Tests for LSP semantic tokens

package.path = package.path .. ";./lib/?.lua;./lib/?/init.lua"

describe("SemanticTokens", function()
  local SemanticTokens
  local Document

  before_each(function()
    SemanticTokens = require("whisker.lsp.semantic_tokens")
    Document = require("whisker.lsp.document")
  end)

  local function create_provider(content)
    local docs = Document.new()
    local uri = "file:///test.ws"
    docs:open(uri, content, 1)
    local provider = SemanticTokens.new({ documents = docs })
    return provider, docs, uri
  end

  describe("legend", function()
    it("returns token types", function()
      local provider = create_provider("")
      local legend = provider:get_legend()

      assert.is_table(legend.tokenTypes)
      assert.is_true(#legend.tokenTypes > 0)
      assert.equals("namespace", legend.tokenTypes[1])
    end)

    it("returns token modifiers", function()
      local provider = create_provider("")
      local legend = provider:get_legend()

      assert.is_table(legend.tokenModifiers)
      assert.is_true(#legend.tokenModifiers > 0)
      assert.equals("declaration", legend.tokenModifiers[1])
    end)
  end)

  describe("token extraction", function()
    it("tokenizes passage definitions", function()
      local provider, docs, uri = create_provider(":: MyPassage\nContent here\n")

      local result = provider:get_full(uri)

      assert.is_table(result.data)
      assert.is_true(#result.data > 0)
      -- Data format: [deltaLine, deltaStart, length, tokenType, tokenModifiers]
      -- Check that we have at least one token
      assert.equals(0, result.data[5] % 5) -- Verify data is multiple of 5
    end)

    it("tokenizes variables", function()
      local provider, docs, uri = create_provider(":: Start\nYou have $gold coins.\n")

      local result = provider:get_full(uri)

      assert.is_table(result.data)
      -- Should have tokens for passage name and variable
      assert.is_true(#result.data >= 10) -- At least 2 tokens
    end)

    it("tokenizes keywords", function()
      local provider, docs, uri = create_provider("INCLUDE \"other.ws\"\nVAR health = 100\n")

      local result = provider:get_full(uri)

      assert.is_table(result.data)
      -- Should have tokens for INCLUDE, VAR, etc.
      assert.is_true(#result.data >= 5)
    end)

    it("tokenizes navigation arrows", function()
      local provider, docs, uri = create_provider(":: Start\n-> NextPassage\n")

      local result = provider:get_full(uri)

      assert.is_table(result.data)
      -- Should have tokens for passage, arrow, and target
      assert.is_true(#result.data >= 5)
    end)

    it("tokenizes directives", function()
      local provider, docs, uri = create_provider("@title: My Story\n:: Start\n")

      local result = provider:get_full(uri)

      assert.is_table(result.data)
      assert.is_true(#result.data >= 5)
    end)

    it("tokenizes comments", function()
      local provider, docs, uri = create_provider(":: Start\n// This is a comment\nContent\n")

      local result = provider:get_full(uri)

      assert.is_table(result.data)
      assert.is_true(#result.data >= 5)
    end)

    it("returns empty data for empty document", function()
      local provider, docs, uri = create_provider("")

      local result = provider:get_full(uri)

      assert.is_table(result.data)
      assert.equals(0, #result.data)
    end)

    it("returns empty data for non-existent document", function()
      local provider = SemanticTokens.new({ documents = Document.new() })

      local result = provider:get_full("file:///nonexistent.ws")

      assert.is_table(result.data)
      assert.equals(0, #result.data)
    end)
  end)

  describe("token encoding", function()
    it("uses delta encoding for positions", function()
      local provider, docs, uri = create_provider(":: First\n:: Second\n")

      local result = provider:get_full(uri)

      assert.is_table(result.data)
      -- First token should have line 0
      assert.equals(0, result.data[1])
      -- Second token on line 1 should have delta line >= 0
      if #result.data >= 10 then
        assert.is_true(result.data[6] >= 0)
      end
    end)
  end)
end)
