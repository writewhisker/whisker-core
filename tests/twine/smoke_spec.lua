--- Smoke tests for Twine integration
-- Quick validation that basic functionality works
--
-- tests/twine/smoke_spec.lua

describe("Smoke Tests", function()
  local TwineParser
  local TwineExporter

  before_each(function()
    package.loaded['whisker.twine.parser'] = nil
    package.loaded['whisker.twine.export.exporter'] = nil
    TwineParser = require('whisker.twine.parser')
    TwineExporter = require('whisker.twine.export.exporter')
  end)

  describe("Parser", function()
    it("parses minimal Harlowe", function()
      local html = [[
<tw-storydata name="Test" format="Harlowe" ifid="TEST-UUID">
  <tw-passagedata pid="1" name="Start" tags="">Hello</tw-passagedata>
</tw-storydata>
]]

      local story = TwineParser.parse(html)

      assert.is_not_nil(story)
      assert.equals(1, #story.passages)
    end)

    it("parses minimal SugarCube", function()
      local html = [[
<tw-storydata name="Test" format="SugarCube" ifid="TEST-UUID">
  <tw-passagedata pid="1" name="Start" tags="">Hello</tw-passagedata>
</tw-storydata>
]]

      local story = TwineParser.parse(html)

      assert.is_not_nil(story)
    end)

    it("parses minimal Chapbook", function()
      local html = [[
<tw-storydata name="Test" format="Chapbook" ifid="TEST-UUID">
  <tw-passagedata pid="1" name="Start" tags="">Hello</tw-passagedata>
</tw-storydata>
]]

      local story = TwineParser.parse(html)

      assert.is_not_nil(story)
    end)

    it("parses minimal Snowman", function()
      local html = [[
<tw-storydata name="Test" format="Snowman" ifid="TEST-UUID">
  <tw-passagedata pid="1" name="Start" tags="">Hello</tw-passagedata>
</tw-storydata>
]]

      local story = TwineParser.parse(html)

      assert.is_not_nil(story)
    end)

    it("detects format correctly", function()
      local html = [[<tw-storydata format="SugarCube"></tw-storydata>]]
      local format = TwineParser.detect_format(html)

      assert.equals("sugarcube", format)
    end)

    it("validates Twine HTML", function()
      assert.is_true(TwineParser.is_twine_html("<tw-storydata>"))
      assert.is_false(TwineParser.is_twine_html("<html>"))
    end)
  end)

  describe("Exporter", function()
    it("exports minimal story to Harlowe", function()
      local story = {
        metadata = { name = "Test" },
        passages = {
          { name = "Start", text = "Hello world" }
        }
      }

      local html = TwineExporter.export(story, "harlowe")

      assert.is_not_nil(html)
      assert.is_true(html:find("<tw%-storydata") ~= nil)
    end)

    it("exports minimal story to SugarCube", function()
      local story = {
        metadata = { name = "Test" },
        passages = {
          { name = "Start", text = "Hello world" }
        }
      }

      local html = TwineExporter.export(story, "sugarcube")

      assert.is_not_nil(html)
      assert.is_true(html:find('format="SugarCube"') ~= nil)
    end)

    it("exports minimal story to Chapbook", function()
      local story = {
        metadata = { name = "Test" },
        passages = {
          { name = "Start", text = "Hello world" }
        }
      }

      local html = TwineExporter.export(story, "chapbook")

      assert.is_not_nil(html)
      assert.is_true(html:find('format="Chapbook"') ~= nil)
    end)

    it("exports minimal story to Snowman", function()
      local story = {
        metadata = { name = "Test" },
        passages = {
          { name = "Start", text = "Hello world" }
        }
      }

      local html = TwineExporter.export(story, "snowman")

      assert.is_not_nil(html)
      assert.is_true(html:find('format="Snowman"') ~= nil)
    end)

    it("lists supported formats", function()
      local formats = TwineExporter.get_supported_formats()

      assert.is_true(#formats >= 4)

      local has_harlowe = false
      local has_sugarcube = false
      for _, f in ipairs(formats) do
        if f == "harlowe" then has_harlowe = true end
        if f == "sugarcube" then has_sugarcube = true end
      end

      assert.is_true(has_harlowe)
      assert.is_true(has_sugarcube)
    end)

    it("validates format support", function()
      assert.is_true(TwineExporter.is_format_supported("harlowe"))
      assert.is_true(TwineExporter.is_format_supported("sugarcube"))
      assert.is_true(TwineExporter.is_format_supported("chapbook"))
      assert.is_true(TwineExporter.is_format_supported("snowman"))
      assert.is_false(TwineExporter.is_format_supported("unknown"))
    end)
  end)

  describe("Format Handlers", function()
    it("loads Harlowe handler", function()
      local handler = require('whisker.twine.formats.harlowe.handler')
      assert.is_not_nil(handler)
      assert.is_not_nil(handler.new)
    end)

    it("loads SugarCube handler", function()
      local handler = require('whisker.twine.formats.sugarcube.handler')
      assert.is_not_nil(handler)
      assert.is_not_nil(handler.new)
    end)

    it("loads Chapbook handler", function()
      local handler = require('whisker.twine.formats.chapbook.handler')
      assert.is_not_nil(handler)
      assert.is_not_nil(handler.new)
    end)

    it("loads Snowman handler", function()
      local handler = require('whisker.twine.formats.snowman.handler')
      assert.is_not_nil(handler)
      assert.is_not_nil(handler.new)
    end)
  end)

  describe("Round-Trip", function()
    it("basic round-trip works", function()
      local html = [[
<tw-storydata name="Test" format="Harlowe" ifid="TEST-UUID" startnode="1">
  <tw-passagedata pid="1" name="Start" tags="">Hello world</tw-passagedata>
</tw-storydata>
]]

      local story1 = TwineParser.parse(html)
      assert.is_not_nil(story1)

      local exported = TwineExporter.export(story1, "harlowe")
      assert.is_not_nil(exported)

      local story2 = TwineParser.parse(exported)
      assert.is_not_nil(story2)

      assert.equals(#story1.passages, #story2.passages)
    end)
  end)
end)
