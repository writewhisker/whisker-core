-- whisker-lsp/spec/document_manager_spec.lua
-- Tests for document manager

package.path = package.path .. ";./tools/whisker-lsp/?.lua;./tools/whisker-lsp/?/init.lua"

describe("DocumentManager", function()
  local DocumentManager

  before_each(function()
    DocumentManager = require("lib.document_manager")
  end)

  describe("open/close", function()
    it("opens a document", function()
      local dm = DocumentManager.new()
      local result = dm:open("file:///test.ink", "hello world", 1)
      assert.is_true(result)
      assert.is_true(dm:is_open("file:///test.ink"))
    end)

    it("closes a document", function()
      local dm = DocumentManager.new()
      dm:open("file:///test.ink", "hello world", 1)
      local result = dm:close("file:///test.ink")
      assert.is_true(result)
      assert.is_false(dm:is_open("file:///test.ink"))
    end)

    it("returns false when closing non-existent document", function()
      local dm = DocumentManager.new()
      local result = dm:close("file:///nonexistent.ink")
      assert.is_false(result)
    end)
  end)

  describe("get_text", function()
    it("returns document text", function()
      local dm = DocumentManager.new()
      dm:open("file:///test.ink", "hello world", 1)
      assert.equals("hello world", dm:get_text("file:///test.ink"))
    end)

    it("returns nil for non-existent document", function()
      local dm = DocumentManager.new()
      assert.is_nil(dm:get_text("file:///nonexistent.ink"))
    end)
  end)

  describe("get_version", function()
    it("returns document version", function()
      local dm = DocumentManager.new()
      dm:open("file:///test.ink", "hello", 5)
      assert.equals(5, dm:get_version("file:///test.ink"))
    end)
  end)

  describe("apply_changes (full sync)", function()
    it("replaces entire document", function()
      local dm = DocumentManager.new()
      dm:open("file:///test.ink", "original", 1)

      dm:apply_changes("file:///test.ink", {
        { text = "replaced" }
      }, 2)

      assert.equals("replaced", dm:get_text("file:///test.ink"))
      assert.equals(2, dm:get_version("file:///test.ink"))
    end)
  end)

  describe("apply_changes (incremental)", function()
    it("inserts text at position", function()
      local dm = DocumentManager.new()
      dm:open("file:///test.ink", "hello world", 1)

      dm:apply_changes("file:///test.ink", {
        {
          range = {
            start = { line = 0, character = 5 },
            ["end"] = { line = 0, character = 5 }
          },
          text = " beautiful"
        }
      }, 2)

      assert.equals("hello beautiful world", dm:get_text("file:///test.ink"))
    end)

    it("deletes text in range", function()
      local dm = DocumentManager.new()
      dm:open("file:///test.ink", "hello world", 1)

      dm:apply_changes("file:///test.ink", {
        {
          range = {
            start = { line = 0, character = 5 },
            ["end"] = { line = 0, character = 11 }
          },
          text = ""
        }
      }, 2)

      assert.equals("hello", dm:get_text("file:///test.ink"))
    end)

    it("replaces text in range", function()
      local dm = DocumentManager.new()
      dm:open("file:///test.ink", "hello world", 1)

      dm:apply_changes("file:///test.ink", {
        {
          range = {
            start = { line = 0, character = 6 },
            ["end"] = { line = 0, character = 11 }
          },
          text = "there"
        }
      }, 2)

      assert.equals("hello there", dm:get_text("file:///test.ink"))
    end)

    it("handles multiline documents", function()
      local dm = DocumentManager.new()
      dm:open("file:///test.ink", "line1\nline2\nline3", 1)

      dm:apply_changes("file:///test.ink", {
        {
          range = {
            start = { line = 1, character = 0 },
            ["end"] = { line = 1, character = 5 }
          },
          text = "REPLACED"
        }
      }, 2)

      assert.equals("line1\nREPLACED\nline3", dm:get_text("file:///test.ink"))
    end)
  end)

  describe("get_line", function()
    it("returns line by index", function()
      local dm = DocumentManager.new()
      dm:open("file:///test.ink", "line0\nline1\nline2", 1)

      assert.equals("line0", dm:get_line("file:///test.ink", 0))
      assert.equals("line1", dm:get_line("file:///test.ink", 1))
      assert.equals("line2", dm:get_line("file:///test.ink", 2))
    end)

    it("returns nil for non-existent document", function()
      local dm = DocumentManager.new()
      assert.is_nil(dm:get_line("file:///nonexistent.ink", 0))
    end)
  end)

  describe("get_all_uris", function()
    it("returns all open document URIs", function()
      local dm = DocumentManager.new()
      dm:open("file:///a.ink", "a", 1)
      dm:open("file:///b.ink", "b", 1)

      local uris = dm:get_all_uris()
      assert.equals(2, #uris)
    end)
  end)

  describe("detect_language", function()
    it("detects ink files", function()
      local dm = DocumentManager.new()
      assert.equals("ink", dm:detect_language("file:///test.ink"))
    end)

    it("detects wscript files", function()
      local dm = DocumentManager.new()
      assert.equals("wscript", dm:detect_language("file:///test.wscript"))
    end)

    it("detects twee files", function()
      local dm = DocumentManager.new()
      assert.equals("twee", dm:detect_language("file:///test.twee"))
    end)

    it("defaults to whisker for unknown", function()
      local dm = DocumentManager.new()
      assert.equals("whisker", dm:detect_language("file:///test.txt"))
    end)
  end)

  describe("get_word_at_position", function()
    it("finds word at position", function()
      local dm = DocumentManager.new()
      dm:open("file:///test.ink", "hello world", 1)

      local word, start_char, end_char = dm:get_word_at_position("file:///test.ink", 0, 2)
      assert.equals("hello", word)
      assert.equals(0, start_char)
      assert.equals(5, end_char)
    end)

    it("finds word with underscores", function()
      local dm = DocumentManager.new()
      dm:open("file:///test.ink", "hello_world test", 1)

      local word = dm:get_word_at_position("file:///test.ink", 0, 6)
      assert.equals("hello_world", word)
    end)
  end)
end)
