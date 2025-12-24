--- Twine exporter unit tests
-- Tests Twine HTML export functionality
--
-- tests/unit/twine/export/exporter_spec.lua

describe("TwineExporter", function()
  local TwineExporter
  local IFIDGenerator
  local PassageSerializer
  local HTMLGenerator
  local StoryDataBuilder

  before_each(function()
    package.loaded['whisker.twine.export.exporter'] = nil
    package.loaded['whisker.twine.export.story_data_builder'] = nil
    package.loaded['whisker.twine.export.passage_serializer'] = nil
    package.loaded['whisker.twine.export.html_generator'] = nil
    package.loaded['whisker.twine.util.ifid_generator'] = nil
    TwineExporter = require('whisker.twine.export.exporter')
    IFIDGenerator = require('whisker.twine.util.ifid_generator')
    PassageSerializer = require('whisker.twine.export.passage_serializer')
    HTMLGenerator = require('whisker.twine.export.html_generator')
    StoryDataBuilder = require('whisker.twine.export.story_data_builder')
  end)

  describe("IFIDGenerator", function()
    it("generates valid UUID v4", function()
      local ifid = IFIDGenerator.generate()

      assert.is_not_nil(ifid)
      assert.equals(36, #ifid)  -- UUID length with dashes
      assert.is_true(IFIDGenerator.validate(ifid))
    end)

    it("generates unique IFIDs", function()
      local ifid1 = IFIDGenerator.generate()
      local ifid2 = IFIDGenerator.generate()

      assert.are_not.equal(ifid1, ifid2)
    end)

    it("validates correct IFID format", function()
      assert.is_true(IFIDGenerator.validate("12345678-1234-4234-8234-123456789ABC"))
      assert.is_true(IFIDGenerator.validate("12345678-1234-4234-9234-123456789ABC"))
      assert.is_true(IFIDGenerator.validate("12345678-1234-4234-A234-123456789ABC"))
      assert.is_true(IFIDGenerator.validate("12345678-1234-4234-B234-123456789ABC"))
    end)

    it("rejects invalid IFID formats", function()
      assert.is_false(IFIDGenerator.validate(nil))
      assert.is_false(IFIDGenerator.validate(""))
      assert.is_false(IFIDGenerator.validate("not-a-uuid"))
      assert.is_false(IFIDGenerator.validate("12345678-1234-3234-8234-123456789ABC")) -- Version 3, not 4
      assert.is_false(IFIDGenerator.validate("12345678-1234-4234-7234-123456789ABC")) -- Y must be 8-B
    end)
  end)

  describe("StoryDataBuilder", function()
    it("builds story data structure", function()
      local metadata = { name = "Test" }
      local passages = {}
      local css = "body {}"
      local js = "alert('hi')"

      local data = StoryDataBuilder.build(metadata, passages, css, js)

      assert.equals("Test", data.metadata.name)
      assert.equals("body {}", data.css)
      assert.equals("alert('hi')", data.javascript)
    end)

    it("builds attribute string", function()
      local metadata = {
        name = "Test Story",
        startnode = 1,
        creator = "whisker-core",
        creator_version = "1.0.0",
        ifid = "12345678-1234-4234-8234-123456789ABC",
        zoom = 1.0,
        format = "Harlowe",
        format_version = "3.3.8",
        options = "",
        hidden = true
      }

      local attrs = StoryDataBuilder.build_attributes(metadata)

      assert.is_true(attrs:find('name="Test Story"') ~= nil)
      assert.is_true(attrs:find('startnode="1"') ~= nil)
      assert.is_true(attrs:find('format="Harlowe"') ~= nil)
      assert.is_true(attrs:find("hidden") ~= nil)
    end)

    it("escapes special characters in attributes", function()
      local metadata = {
        name = 'Test "Story" & <More>',
        startnode = 1,
        creator = "test",
        creator_version = "1.0",
        ifid = "12345678-1234-4234-8234-123456789ABC",
        zoom = 1,
        format = "Harlowe",
        format_version = "3.0",
        options = "",
        hidden = false
      }

      local attrs = StoryDataBuilder.build_attributes(metadata)

      assert.is_true(attrs:find("&quot;") ~= nil)
      assert.is_true(attrs:find("&amp;") ~= nil)
      assert.is_true(attrs:find("&lt;") ~= nil)
      assert.is_true(attrs:find("&gt;") ~= nil)
    end)
  end)

  describe("PassageSerializer", function()
    it("serializes passage with position", function()
      local passage = { name = "Start", text = "Hello" }
      local serialized = PassageSerializer.serialize(passage, "harlowe", 1)

      assert.equals(1, serialized.pid)
      assert.equals("Start", serialized.name)
      assert.equals("Hello", serialized.content)
      assert.is_not_nil(serialized.position)
      assert.is_not_nil(serialized.size)
    end)

    it("calculates grid positions", function()
      local passage1 = PassageSerializer.serialize({ name = "P1", text = "" }, "harlowe", 1)
      local passage2 = PassageSerializer.serialize({ name = "P2", text = "" }, "harlowe", 2)
      local passage6 = PassageSerializer.serialize({ name = "P6", text = "" }, "harlowe", 6)

      -- First row
      assert.equals(100, passage1.position.x)
      assert.equals(100, passage1.position.y)
      assert.equals(300, passage2.position.x)
      assert.equals(100, passage2.position.y)

      -- Second row (after 5 passages)
      assert.equals(100, passage6.position.x)
      assert.equals(250, passage6.position.y)
    end)

    it("preserves passage tags", function()
      local passage = { name = "Start", text = "Hello", tags = { "important", "test" } }
      local serialized = PassageSerializer.serialize(passage, "harlowe", 1)

      assert.equals(2, #serialized.tags)
      assert.equals("important", serialized.tags[1])
    end)

    it("uses text content when available", function()
      local passage = { name = "Start", text = "Plain text content" }
      local serialized = PassageSerializer.serialize(passage, "harlowe", 1)

      assert.equals("Plain text content", serialized.content)
    end)

    it("generates default name if missing", function()
      local passage = { text = "Content" }
      local serialized = PassageSerializer.serialize(passage, "harlowe", 3)

      assert.equals("Passage 3", serialized.name)
    end)
  end)

  describe("HTMLGenerator", function()
    it("generates valid HTML structure", function()
      local story_data = {
        metadata = {
          name = "Test Story",
          startnode = 1,
          creator = "whisker-core",
          creator_version = "1.0.0",
          ifid = "12345678-1234-4234-8234-123456789ABC",
          zoom = 1,
          format = "Harlowe",
          format_version = "3.3.8",
          options = "",
          hidden = true
        },
        passages = {
          {
            pid = 1,
            name = "Start",
            tags = {},
            position = { x = 100, y = 100 },
            size = { width = 100, height = 100 },
            content = "Welcome!"
          }
        },
        css = "",
        javascript = ""
      }

      local html = HTMLGenerator.generate(story_data, "harlowe", {})

      assert.is_true(html:find("<!DOCTYPE html>") ~= nil)
      assert.is_true(html:find("<html>") ~= nil)
      assert.is_true(html:find("<tw%-storydata") ~= nil)
      assert.is_true(html:find("<tw%-passagedata") ~= nil)
      assert.is_true(html:find("</html>") ~= nil)
    end)

    it("includes CSS when provided", function()
      local story_data = {
        metadata = {
          name = "Test",
          startnode = 1,
          creator = "test",
          creator_version = "1.0",
          ifid = "12345678-1234-4234-8234-123456789ABC",
          zoom = 1,
          format = "Harlowe",
          format_version = "3.0",
          options = "",
          hidden = true
        },
        passages = {},
        css = "body { color: red; }",
        javascript = ""
      }

      local html = HTMLGenerator.generate(story_data, "harlowe", {})

      assert.is_true(html:find("color: red") ~= nil)
      assert.is_true(html:find("text/twine%-css") ~= nil)
    end)

    it("includes JavaScript when provided", function()
      local story_data = {
        metadata = {
          name = "Test",
          startnode = 1,
          creator = "test",
          creator_version = "1.0",
          ifid = "12345678-1234-4234-8234-123456789ABC",
          zoom = 1,
          format = "Harlowe",
          format_version = "3.0",
          options = "",
          hidden = true
        },
        passages = {},
        css = "",
        javascript = "console.log('hello');"
      }

      local html = HTMLGenerator.generate(story_data, "harlowe", {})

      assert.is_true(html:find("console%.log") ~= nil)
      assert.is_true(html:find("text/twine%-javascript") ~= nil)
    end)

    it("escapes passage content", function()
      local story_data = {
        metadata = {
          name = "Test",
          startnode = 1,
          creator = "test",
          creator_version = "1.0",
          ifid = "12345678-1234-4234-8234-123456789ABC",
          zoom = 1,
          format = "Harlowe",
          format_version = "3.0",
          options = "",
          hidden = true
        },
        passages = {
          {
            pid = 1,
            name = "Start",
            tags = {},
            position = { x = 100, y = 100 },
            size = { width = 100, height = 100 },
            content = "This has <html> & entities"
          }
        },
        css = "",
        javascript = ""
      }

      local html = HTMLGenerator.generate(story_data, "harlowe", {})

      assert.is_true(html:find("&lt;html&gt;") ~= nil)
      assert.is_true(html:find("&amp;") ~= nil)
    end)
  end)

  describe("TwineExporter.export", function()
    it("exports simple story to HTML", function()
      local story = {
        metadata = {
          name = "Test Story",
          ifid = "12345678-1234-4234-8234-123456789ABC"
        },
        passages = {
          {
            name = "Start",
            text = "Welcome to the story.",
            tags = {}
          },
          {
            name = "Second",
            text = "This is the second passage.",
            tags = { "test" }
          }
        },
        css = "",
        javascript = ""
      }

      local html = TwineExporter.export(story, "harlowe")

      assert.is_not_nil(html)
      assert.is_true(html:find("Test Story") ~= nil)
      assert.is_true(html:find("<tw%-storydata") ~= nil)
      assert.is_true(html:find('pid="1"') ~= nil)
      assert.is_true(html:find('name="Start"') ~= nil)
    end)

    it("exports story with CSS", function()
      local story = {
        metadata = { name = "Styled Story" },
        passages = { { name = "Start", text = "Content" } },
        css = "body { color: red; }"
      }

      local html = TwineExporter.export(story, "sugarcube")

      assert.is_true(html:find("color: red") ~= nil)
      assert.is_true(html:find("text/twine%-css") ~= nil)
    end)

    it("exports story with JavaScript", function()
      local story = {
        metadata = { name = "Interactive Story" },
        passages = { { name = "Start", text = "Content" } },
        javascript = "window.setup = {};"
      }

      local html = TwineExporter.export(story, "sugarcube")

      assert.is_true(html:find("window%.setup") ~= nil)
      assert.is_true(html:find("text/twine%-javascript") ~= nil)
    end)

    it("generates IFID if not provided", function()
      local story = {
        metadata = { name = "No IFID Story" },
        passages = { { name = "Start", text = "Content" } }
      }

      local html = TwineExporter.export(story, "harlowe")

      -- Should contain a valid IFID pattern
      assert.is_true(html:find('ifid="[%w%-]+"') ~= nil)
    end)

    it("finds Start passage for startnode", function()
      local story = {
        metadata = { name = "Test" },
        passages = {
          { name = "Intro", text = "Not start" },
          { name = "Start", text = "This is start" },
          { name = "End", text = "The end" }
        }
      }

      local html = TwineExporter.export(story, "harlowe")

      -- startnode should be 2 (the Start passage)
      assert.is_true(html:find('startnode="2"') ~= nil)
    end)

    it("defaults startnode to 1 if no Start passage", function()
      local story = {
        metadata = { name = "Test" },
        passages = {
          { name = "Beginning", text = "Start here" },
          { name = "End", text = "The end" }
        }
      }

      local html = TwineExporter.export(story, "harlowe")

      assert.is_true(html:find('startnode="1"') ~= nil)
    end)

    it("uses correct format names", function()
      local story = {
        metadata = { name = "Test" },
        passages = { { name = "Start", text = "" } }
      }

      local harlowe_html = TwineExporter.export(story, "harlowe")
      local sugarcube_html = TwineExporter.export(story, "sugarcube")
      local chapbook_html = TwineExporter.export(story, "chapbook")
      local snowman_html = TwineExporter.export(story, "snowman")

      assert.is_true(harlowe_html:find('format="Harlowe"') ~= nil)
      assert.is_true(sugarcube_html:find('format="SugarCube"') ~= nil)
      assert.is_true(chapbook_html:find('format="Chapbook"') ~= nil)
      assert.is_true(snowman_html:find('format="Snowman"') ~= nil)
    end)

    it("rejects unsupported formats", function()
      local story = {
        metadata = { name = "Test" },
        passages = { { name = "Start", text = "" } }
      }

      local html, err = TwineExporter.export(story, "unknown_format")

      assert.is_nil(html)
      assert.is_true(err:find("Unsupported") ~= nil)
    end)

    it("rejects empty stories", function()
      local story = {
        metadata = { name = "Empty" },
        passages = {}
      }

      local html, err = TwineExporter.export(story, "harlowe")

      assert.is_nil(html)
      assert.is_true(err:find("at least one passage") ~= nil)
    end)

    it("handles missing metadata gracefully", function()
      local story = {
        passages = { { name = "Start", text = "Content" } }
      }

      local html = TwineExporter.export(story, "harlowe")

      assert.is_not_nil(html)
      assert.is_true(html:find("Untitled Story") ~= nil)
    end)
  end)

  describe("format utilities", function()
    it("lists supported formats", function()
      local formats = TwineExporter.get_supported_formats()

      assert.equals(4, #formats)
      assert.is_true(TwineExporter.is_format_supported("harlowe"))
      assert.is_true(TwineExporter.is_format_supported("Harlowe"))
      assert.is_true(TwineExporter.is_format_supported("SUGARCUBE"))
      assert.is_false(TwineExporter.is_format_supported("invalid"))
    end)
  end)
end)
