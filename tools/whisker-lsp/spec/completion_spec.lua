-- whisker-lsp/spec/completion_spec.lua
-- Tests for completion provider

package.path = package.path .. ";./tools/whisker-lsp/?.lua;./tools/whisker-lsp/?/init.lua"

describe("CompletionProvider", function()
  local CompletionProvider
  local DocumentManager
  local ParserIntegration

  before_each(function()
    CompletionProvider = require("lib.providers.completion")
    DocumentManager = require("lib.document_manager")
    ParserIntegration = require("lib.parser_integration")
  end)

  local function create_provider()
    local dm = DocumentManager.new()
    local parser = ParserIntegration.new()
    return CompletionProvider.new(dm, parser), dm, parser
  end

  describe("context detection", function()
    it("detects divert context", function()
      local provider = create_provider()

      local context = provider:detect_context("-> ", "-> Passage")
      assert.equals("divert", context.type)
      assert.equals("", context.prefix)

      context = provider:detect_context("-> Pas", "-> Passage")
      assert.equals("divert", context.type)
      assert.equals("Pas", context.prefix)
    end)

    it("detects variable context", function()
      local provider = create_provider()

      local context = provider:detect_context("{", "{var}")
      assert.equals("variable", context.type)
      assert.equals("", context.prefix)

      context = provider:detect_context("{player", "{player_health}")
      assert.equals("variable", context.type)
      assert.equals("player", context.prefix)
    end)

    it("detects macro context", function()
      local provider = create_provider()

      local context = provider:detect_context("<<", "<<if>>")
      assert.equals("macro", context.type)
      assert.equals("", context.prefix)

      context = provider:detect_context("<<se", "<<set>>")
      assert.equals("macro", context.type)
      assert.equals("se", context.prefix)
    end)

    it("detects choice target context", function()
      local provider = create_provider()

      local context = provider:detect_context("* [Go north] -> ", "* [Go north] -> NorthPath")
      assert.equals("choice_target", context.type)
      assert.equals("", context.prefix)
    end)

    it("detects general context", function()
      local provider = create_provider()

      local context = provider:detect_context("Hello", "Hello world")
      assert.equals("general", context.type)
    end)
  end)

  describe("passage completions", function()
    it("returns passage names", function()
      local provider, dm, parser = create_provider()

      dm:open("file:///test.ink", "=== Start ===\nHello\n\n=== End ===\nBye", 1)
      parser:parse("file:///test.ink", dm:get_text("file:///test.ink"), "ink")

      local result = provider:get_completions({
        textDocument = { uri = "file:///test.ink" },
        position = { line = 1, character = 5 }
      })

      -- Line "Hello" doesn't trigger divert, but let's check with a divert
      dm:close("file:///test.ink")
      dm:open("file:///test.ink", "=== Start ===\n-> ", 1)
      parser:parse("file:///test.ink", dm:get_text("file:///test.ink"), "ink")

      result = provider:get_completions({
        textDocument = { uri = "file:///test.ink" },
        position = { line = 1, character = 3 }
      })

      -- Should include Start passage and special passages (END, DONE)
      assert.is_table(result.items)
    end)

    it("filters by prefix", function()
      local provider, dm, parser = create_provider()

      dm:open("file:///test.ink", "=== Start ===\n=== Setup ===\n=== End ===\n-> S", 1)
      parser:parse("file:///test.ink", dm:get_text("file:///test.ink"), "ink")

      local result = provider:get_completions({
        textDocument = { uri = "file:///test.ink" },
        position = { line = 3, character = 4 }
      })

      -- Should only include passages starting with "S"
      for _, item in ipairs(result.items) do
        assert.matches("^S", item.label)
      end
    end)

    it("includes special passages", function()
      local provider, dm, parser = create_provider()

      dm:open("file:///test.ink", "-> E", 1)
      parser:parse("file:///test.ink", dm:get_text("file:///test.ink"), "ink")

      local result = provider:get_completions({
        textDocument = { uri = "file:///test.ink" },
        position = { line = 0, character = 4 }
      })

      local has_end = false
      for _, item in ipairs(result.items) do
        if item.label == "END" then
          has_end = true
          break
        end
      end
      assert.is_true(has_end)
    end)
  end)

  describe("variable completions", function()
    it("returns variable names", function()
      local provider, dm, parser = create_provider()

      dm:open("file:///test.ink", "~ health = 100\n~ gold = 50\n{", 1)
      parser:parse("file:///test.ink", dm:get_text("file:///test.ink"), "ink")

      local result = provider:get_completions({
        textDocument = { uri = "file:///test.ink" },
        position = { line = 2, character = 1 }
      })

      assert.is_table(result.items)
      -- Should include health and gold
    end)
  end)

  describe("macro completions", function()
    it("returns macro names", function()
      local provider, dm, parser = create_provider()

      dm:open("file:///test.ink", "<<", 1)
      parser:parse("file:///test.ink", dm:get_text("file:///test.ink"), "ink")

      local result = provider:get_completions({
        textDocument = { uri = "file:///test.ink" },
        position = { line = 0, character = 2 }
      })

      assert.is_table(result.items)
      assert.is_true(#result.items > 0)

      -- Should include common macros
      local has_if = false
      for _, item in ipairs(result.items) do
        if item.label == "if" then
          has_if = true
          break
        end
      end
      assert.is_true(has_if)
    end)

    it("filters macros by prefix", function()
      local provider, dm, parser = create_provider()

      dm:open("file:///test.ink", "<<se", 1)
      parser:parse("file:///test.ink", dm:get_text("file:///test.ink"), "ink")

      local result = provider:get_completions({
        textDocument = { uri = "file:///test.ink" },
        position = { line = 0, character = 4 }
      })

      -- Should only include "set"
      for _, item in ipairs(result.items) do
        assert.matches("^se", item.label)
      end
    end)
  end)

  describe("general completions", function()
    it("returns keyword snippets", function()
      local provider, dm, parser = create_provider()

      dm:open("file:///test.ink", "pas", 1)
      parser:parse("file:///test.ink", dm:get_text("file:///test.ink"), "ink")

      local result = provider:get_completions({
        textDocument = { uri = "file:///test.ink" },
        position = { line = 0, character = 3 }
      })

      local has_passage = false
      for _, item in ipairs(result.items) do
        if item.label == "passage" then
          has_passage = true
          break
        end
      end
      assert.is_true(has_passage)
    end)
  end)

  describe("prefix matching", function()
    it("matches case-insensitively", function()
      local provider = create_provider()

      assert.is_true(provider:matches_prefix("Hello", "hel"))
      assert.is_true(provider:matches_prefix("Hello", "HEL"))
      assert.is_true(provider:matches_prefix("Hello", ""))
      assert.is_false(provider:matches_prefix("Hello", "bye"))
    end)
  end)

  describe("resolve_completion", function()
    it("returns the item unchanged", function()
      local provider = create_provider()

      local item = { label = "test", kind = 1 }
      local resolved = provider:resolve_completion(item)

      assert.equals("test", resolved.label)
      assert.equals(1, resolved.kind)
    end)
  end)
end)
