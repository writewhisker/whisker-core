-- Unit Tests for Markdown Exporter
local MarkdownExporter = require("whisker.export.markdown_exporter")

describe("Markdown Exporter", function()
  local exporter

  before_each(function()
    exporter = MarkdownExporter.new()
  end)

  describe("metadata", function()
    it("should return correct metadata", function()
      local meta = exporter:metadata()

      assert.equals("markdown", meta.format)
      assert.equals(".md", meta.file_extension)
    end)
  end)

  describe("can_export", function()
    it("should return true for valid story", function()
      local story = {
        name = "Test",
        passages = {{name = "Start", content = "Hello", tags = {}}}
      }

      local can, err = exporter:can_export(story)

      assert.is_true(can)
      assert.is_nil(err)
    end)

    it("should return false for nil story", function()
      local can, err = exporter:can_export(nil)

      assert.is_false(can)
      assert.equals("No story provided", err)
    end)

    it("should return false for empty passages", function()
      local story = {name = "Test", passages = {}}

      local can, err = exporter:can_export(story)

      assert.is_false(can)
      assert.equals("Story has no passages", err)
    end)
  end)

  describe("export", function()
    it("should export story to Markdown", function()
      local story = {
        name = "My Story",
        format = "harlowe",
        passages = {
          {name = "Start", content = "Welcome!", tags = {}},
          {name = "End", content = "Goodbye!", tags = {}}
        }
      }

      local bundle = exporter:export(story)

      assert.is_not_nil(bundle.content)
      assert.matches("# My Story", bundle.content)
      assert.matches("## Start", bundle.content)
      assert.matches("## End", bundle.content)
      assert.matches("Welcome!", bundle.content)
      assert.matches("Goodbye!", bundle.content)
    end)

    it("should include table of contents", function()
      local story = {
        name = "Test",
        passages = {
          {name = "Start", content = "Hello", tags = {}},
          {name = "Middle", content = "World", tags = {}}
        }
      }

      local bundle = exporter:export(story)

      assert.matches("## Table of Contents", bundle.content)
      assert.matches("%[Start%]%(#start%)", bundle.content)
      assert.matches("%[Middle%]%(#middle%)", bundle.content)
    end)

    it("should include metadata section", function()
      local story = {
        name = "Test Story",
        format = "harlowe",
        passages = {{name = "Start", content = "Hello", tags = {}}}
      }

      local bundle = exporter:export(story)

      assert.matches("title: Test Story", bundle.content)
      assert.matches("format: harlowe", bundle.content)
    end)

    it("should convert Harlowe links", function()
      local story = {
        name = "Test",
        format = "harlowe",
        passages = {{name = "Start", content = "[[Go->Target]]", tags = {}}}
      }

      local bundle = exporter:export(story)

      assert.matches("%[Go%]%(#target%)", bundle.content)
    end)

    it("should convert SugarCube links", function()
      local story = {
        name = "Test",
        format = "sugarcube",
        passages = {{name = "Start", content = "[[Go|Target]]", tags = {}}}
      }

      local bundle = exporter:export(story)

      assert.matches("%[Go%]%(#target%)", bundle.content)
    end)

    it("should strip Harlowe macros", function()
      local story = {
        name = "Test",
        format = "harlowe",
        passages = {{name = "Start", content = "(set: $x to 5)\nHello", tags = {}}}
      }

      local bundle = exporter:export(story)

      assert.not_matches("%(set:", bundle.content)
      assert.matches("Hello", bundle.content)
    end)

    it("should strip SugarCube macros", function()
      local story = {
        name = "Test",
        format = "sugarcube",
        passages = {{name = "Start", content = "<<set $x to 5>>\nHello", tags = {}}}
      }

      local bundle = exporter:export(story)

      assert.not_matches("<<set", bundle.content)
      assert.matches("Hello", bundle.content)
    end)

    it("should include passage tags", function()
      local story = {
        name = "Test",
        passages = {{name = "Start", content = "Hello", tags = {"important", "intro"}}}
      }

      local bundle = exporter:export(story)

      assert.matches("Tags: important, intro", bundle.content)
    end)
  end)

  describe("make_anchor", function()
    it("should create lowercase anchor", function()
      local anchor = exporter:make_anchor("Start Here")
      assert.equals("start-here", anchor)
    end)

    it("should remove special characters", function()
      local anchor = exporter:make_anchor("Start's Beginning!")
      assert.equals("starts-beginning", anchor)
    end)
  end)

  describe("validate", function()
    it("should validate valid bundle", function()
      local bundle = {content = "# Test\n\nHello"}

      local result = exporter:validate(bundle)

      assert.is_true(result.valid)
      assert.equals(0, #result.errors)
    end)

    it("should fail for empty content", function()
      local bundle = {content = ""}

      local result = exporter:validate(bundle)

      assert.is_false(result.valid)
      assert.equals(1, #result.errors)
    end)
  end)

end)
