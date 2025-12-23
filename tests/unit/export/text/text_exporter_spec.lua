--- Text Exporter Tests
-- @module tests.unit.export.text.text_exporter_spec

describe("TextExporter", function()
  local TextExporter
  local exporter

  before_each(function()
    package.loaded["whisker.export.text.text_exporter"] = nil
    package.loaded["whisker.export.utils"] = nil
    TextExporter = require("whisker.export.text.text_exporter")
    exporter = TextExporter.new()
  end)

  describe("new", function()
    it("creates a new exporter instance", function()
      assert.is_table(exporter)
    end)
  end)

  describe("can_export", function()
    it("accepts valid story", function()
      local story = {
        passages = {{ name = "start", text = "Hello" }}
      }
      local can, err = exporter:can_export(story)
      assert.is_true(can)
      assert.is_nil(err)
    end)

    it("rejects nil story", function()
      local can, err = exporter:can_export(nil)
      assert.is_false(can)
      assert.equals("No story provided", err)
    end)

    it("rejects story with no passages", function()
      local story = { passages = {} }
      local can, err = exporter:can_export(story)
      assert.is_false(can)
    end)
  end)

  describe("export", function()
    it("includes story title", function()
      local story = {
        title = "Test Story",
        passages = {
          { name = "start", text = "Beginning" }
        }
      }

      local bundle = exporter:export(story, {})

      assert.truthy(bundle.content:match("Test Story"))
    end)

    it("includes author", function()
      local story = {
        title = "Test",
        author = "Jane Doe",
        passages = {
          { name = "start", text = "Hello" }
        }
      }

      local bundle = exporter:export(story, {})

      assert.truthy(bundle.content:match("by Jane Doe"))
    end)

    it("formats passages", function()
      local story = {
        passages = {
          { name = "start", text = "Beginning of story" }
        }
      }

      local bundle = exporter:export(story, {})

      assert.truthy(bundle.content:match("%[1%] start"))
      assert.truthy(bundle.content:match("Beginning of story"))
    end)

    it("formats choices", function()
      local story = {
        passages = {
          {
            name = "start",
            text = "Choose",
            choices = {
              { text = "Option A", target = "a" },
              { text = "Option B", target = "b" },
            }
          }
        }
      }

      local bundle = exporter:export(story, {})

      assert.truthy(bundle.content:match("Option A"))
      assert.truthy(bundle.content:match("Option B"))
      assert.truthy(bundle.content:match("%-> %[a%]"))
    end)

    it("indicates end of story branch", function()
      local story = {
        passages = {
          { name = "ending", text = "The End", choices = {} }
        }
      }

      local bundle = exporter:export(story, {})

      assert.truthy(bundle.content:match("End of story branch"))
    end)

    it("includes passage count", function()
      local story = {
        passages = {
          { name = "start", text = "A" },
          { name = "middle", text = "B" },
          { name = "end", text = "C" },
        }
      }

      local bundle = exporter:export(story, {})

      assert.truthy(bundle.content:match("Total passages: 3"))
    end)

    it("includes timestamp", function()
      local story = {
        passages = {{ name = "start", text = "Test" }}
      }

      local bundle = exporter:export(story, {})

      assert.truthy(bundle.content:match("Generated:"))
    end)

    it("creates manifest", function()
      local story = {
        title = "Test",
        passages = {{ name = "start", text = "Hello" }}
      }

      local bundle = exporter:export(story, {})

      assert.is_table(bundle.manifest)
      assert.equals("text", bundle.manifest.format)
    end)

    it("respects include_metadata option", function()
      local story = {
        title = "Test Story",
        passages = {{ name = "start", text = "Hello" }}
      }

      local bundle = exporter:export(story, { include_metadata = false })

      assert.falsy(bundle.content:match("Test Story"))
      assert.falsy(bundle.content:match("Total passages"))
    end)

    it("respects include_choices option", function()
      local story = {
        passages = {{
          name = "start",
          text = "Test",
          choices = {{ text = "Go", target = "next" }}
        }}
      }

      local bundle = exporter:export(story, { include_choices = false })

      assert.falsy(bundle.content:match("Choices:"))
    end)
  end)

  describe("validate", function()
    it("passes valid bundle", function()
      local story = {
        passages = {{ name = "start", text = "Hello" }}
      }

      local bundle = exporter:export(story, {})
      local result = exporter:validate(bundle)

      assert.is_true(result.valid)
    end)

    it("fails bundle with no content", function()
      local bundle = {}
      local result = exporter:validate(bundle)

      assert.is_false(result.valid)
    end)

    it("fails bundle with empty content", function()
      local bundle = { content = "" }
      local result = exporter:validate(bundle)

      assert.is_false(result.valid)
    end)
  end)

  describe("metadata", function()
    it("returns correct format", function()
      local meta = exporter:metadata()
      assert.equals("text", meta.format)
    end)

    it("returns correct file extension", function()
      local meta = exporter:metadata()
      assert.equals(".txt", meta.file_extension)
    end)
  end)

  describe("word_wrap", function()
    it("wraps long lines", function()
      local text = "This is a very long line that should be wrapped to multiple lines"
      local wrapped = exporter:word_wrap(text, 20)

      for _, line in ipairs(wrapped) do
        assert.is_true(#line <= 20)
      end
    end)

    it("preserves short lines", function()
      local text = "Short"
      local wrapped = exporter:word_wrap(text, 20)

      assert.equals(1, #wrapped)
      assert.equals("Short", wrapped[1])
    end)

    it("handles empty text", function()
      local wrapped = exporter:word_wrap("", 20)
      assert.equals(1, #wrapped)
    end)
  end)

  describe("format_passage", function()
    it("includes passage name", function()
      local passage = { name = "test_passage", text = "Content" }
      local formatted = exporter:format_passage(passage, 1, {})

      assert.truthy(formatted:match("test_passage"))
    end)

    it("includes passage index", function()
      local passage = { name = "start", text = "Content" }
      local formatted = exporter:format_passage(passage, 5, {})

      assert.truthy(formatted:match("%[5%]"))
    end)

    it("includes tags", function()
      local passage = {
        name = "start",
        text = "Content",
        tags = { "important", "scene" }
      }
      local formatted = exporter:format_passage(passage, 1, {})

      assert.truthy(formatted:match("Tags:"))
      assert.truthy(formatted:match("important"))
      assert.truthy(formatted:match("scene"))
    end)

    it("marks conditional choices", function()
      local passage = {
        name = "start",
        text = "Choose",
        choices = {
          { text = "Secret", target = "secret", condition = "has_key" }
        }
      }
      local formatted = exporter:format_passage(passage, 1, {})

      assert.truthy(formatted:match("%(conditional%)"))
    end)
  end)
end)
