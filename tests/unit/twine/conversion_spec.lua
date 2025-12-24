--- Format conversion tests
-- Tests Twine import, export, and round-trip conversion
--
-- tests/unit/twine/conversion_spec.lua

describe("Twine Conversion", function()
  local TwineParser
  local TwineExporter

  before_each(function()
    package.loaded['whisker.twine.parser'] = nil
    package.loaded['whisker.twine.export.exporter'] = nil
    TwineParser = require('whisker.twine.parser')
    TwineExporter = require('whisker.twine.export.exporter')
  end)

  --- Load fixture file
  local function load_fixture(filename)
    local path = "tests/twine/fixtures/" .. filename
    local file = io.open(path, "r")
    if not file then
      return nil
    end
    local content = file:read("*all")
    file:close()
    return content
  end

  describe("TwineParser", function()
    describe("format detection", function()
      it("detects valid Twine HTML", function()
        local html = [[<tw-storydata name="Test" format="Harlowe"></tw-storydata>]]
        assert.is_true(TwineParser.is_twine_html(html))
      end)

      it("rejects non-Twine HTML", function()
        local html = [[<html><body>Not a Twine story</body></html>]]
        assert.is_false(TwineParser.is_twine_html(html))
      end)

      it("detects format from HTML", function()
        local html = [[<tw-storydata format="SugarCube"></tw-storydata>]]
        assert.equals("sugarcube", TwineParser.detect_format(html))
      end)
    end)

    describe("basic parsing", function()
      it("parses minimal story", function()
        local html = [[
<tw-storydata name="Test" startnode="1" format="Harlowe" ifid="TEST-UUID">
  <tw-passagedata pid="1" name="Start" tags="">Hello world</tw-passagedata>
</tw-storydata>
        ]]

        local story, err = TwineParser.parse(html)

        assert.is_not_nil(story, err)
        assert.equals("Test", story.metadata.name)
        assert.equals(1, #story.passages)
        assert.equals("Start", story.passages[1].name)
      end)

      it("parses multiple passages", function()
        local html = [[
<tw-storydata name="Multi" startnode="1" format="Harlowe" ifid="TEST-UUID">
  <tw-passagedata pid="1" name="Start" tags="">First</tw-passagedata>
  <tw-passagedata pid="2" name="Middle" tags="">Second</tw-passagedata>
  <tw-passagedata pid="3" name="End" tags="">Third</tw-passagedata>
</tw-storydata>
        ]]

        local story = TwineParser.parse(html)

        assert.equals(3, #story.passages)
      end)

      it("parses passage tags", function()
        local html = [[
<tw-storydata name="Tagged" format="Harlowe" ifid="TEST">
  <tw-passagedata pid="1" name="Start" tags="widget init">Content</tw-passagedata>
</tw-storydata>
        ]]

        local story = TwineParser.parse(html)

        assert.equals(2, #story.passages[1].tags)
        assert.equals("widget", story.passages[1].tags[1])
      end)

      it("unescapes HTML entities in content", function()
        local html = [[
<tw-storydata name="Escaped" format="Harlowe" ifid="TEST">
  <tw-passagedata pid="1" name="Start" tags="">&lt;&lt;set $x to 5&gt;&gt;</tw-passagedata>
</tw-storydata>
        ]]

        local story = TwineParser.parse(html)

        assert.is_true(story.passages[1].content:find("<<set") ~= nil)
      end)

      it("extracts CSS", function()
        local html = [[
<tw-storydata name="Styled" format="Harlowe" ifid="TEST">
  <style role="stylesheet" type="text/twine-css">body { color: red; }</style>
  <tw-passagedata pid="1" name="Start" tags="">Content</tw-passagedata>
</tw-storydata>
        ]]

        local story = TwineParser.parse(html)

        assert.is_true(story.css:find("color: red") ~= nil)
      end)

      it("extracts JavaScript", function()
        local html = [[
<tw-storydata name="Scripted" format="Harlowe" ifid="TEST">
  <script role="script" type="text/twine-javascript">window.setup = {};</script>
  <tw-passagedata pid="1" name="Start" tags="">Content</tw-passagedata>
</tw-storydata>
        ]]

        local story = TwineParser.parse(html)

        assert.is_true(story.javascript:find("window.setup") ~= nil)
      end)
    end)

    describe("error handling", function()
      it("returns error for empty HTML", function()
        local story, err = TwineParser.parse("")

        assert.is_nil(story)
        assert.is_not_nil(err)
      end)

      it("returns error for non-Twine HTML", function()
        local html = [[<html><body>Not Twine</body></html>]]
        local story, err = TwineParser.parse(html)

        assert.is_nil(story)
        assert.is_true(err:find("tw%-storydata") ~= nil)
      end)
    end)
  end)

  describe("fixture parsing", function()
    it("parses Harlowe fixture", function()
      local html = load_fixture("basic_harlowe.html")
      if not html then pending("Fixture not found") return end

      local story, err = TwineParser.parse(html)

      assert.is_not_nil(story, err)
      assert.equals("harlowe", story.metadata.format:lower())
      assert.is_true(#story.passages > 0)
    end)

    it("parses SugarCube fixture", function()
      local html = load_fixture("basic_sugarcube.html")
      if not html then pending("Fixture not found") return end

      local story, err = TwineParser.parse(html)

      assert.is_not_nil(story, err)
      assert.equals("sugarcube", story.metadata.format:lower())
    end)

    it("parses Chapbook fixture", function()
      local html = load_fixture("basic_chapbook.html")
      if not html then pending("Fixture not found") return end

      local story, err = TwineParser.parse(html)

      assert.is_not_nil(story, err)
      assert.equals("chapbook", story.metadata.format:lower())
    end)

    it("parses Snowman fixture", function()
      local html = load_fixture("basic_snowman.html")
      if not html then pending("Fixture not found") return end

      local story, err = TwineParser.parse(html)

      assert.is_not_nil(story, err)
      assert.equals("snowman", story.metadata.format:lower())
    end)

    it("parses Unicode fixture", function()
      local html = load_fixture("unicode_story.html")
      if not html then pending("Fixture not found") return end

      local story, err = TwineParser.parse(html)

      assert.is_not_nil(story, err)

      -- Check Unicode is preserved
      local has_unicode = false
      for _, passage in ipairs(story.passages) do
        if passage.content and passage.content:find("🎮") then
          has_unicode = true
        end
      end
      assert.is_true(has_unicode, "Unicode should be preserved")
    end)
  end)

  describe("round-trip conversion", function()
    it("preserves passage count after round-trip", function()
      local html = [[
<tw-storydata name="Test" startnode="1" format="Harlowe" ifid="TEST-UUID">
  <tw-passagedata pid="1" name="Start" tags="">First</tw-passagedata>
  <tw-passagedata pid="2" name="Middle" tags="">Second</tw-passagedata>
  <tw-passagedata pid="3" name="End" tags="">Third</tw-passagedata>
</tw-storydata>
      ]]

      -- Import
      local story1 = TwineParser.parse(html)
      assert.is_not_nil(story1)

      -- Export
      local exported = TwineExporter.export(story1, "harlowe")
      assert.is_not_nil(exported)

      -- Re-import
      local story2 = TwineParser.parse(exported)
      assert.is_not_nil(story2)

      -- Compare
      assert.equals(#story1.passages, #story2.passages)
    end)

    it("preserves passage names after round-trip", function()
      local html = [[
<tw-storydata name="Test" startnode="1" format="Harlowe" ifid="TEST-UUID">
  <tw-passagedata pid="1" name="Start" tags="">First</tw-passagedata>
  <tw-passagedata pid="2" name="Custom Name" tags="">Second</tw-passagedata>
</tw-storydata>
      ]]

      local story1 = TwineParser.parse(html)
      local exported = TwineExporter.export(story1, "harlowe")
      local story2 = TwineParser.parse(exported)

      local names1 = {}
      local names2 = {}

      for _, p in ipairs(story1.passages) do
        table.insert(names1, p.name)
      end
      for _, p in ipairs(story2.passages) do
        table.insert(names2, p.name)
      end

      table.sort(names1)
      table.sort(names2)

      assert.are.same(names1, names2)
    end)

    it("preserves story name after round-trip", function()
      local html = [[
<tw-storydata name="My Adventure" startnode="1" format="Harlowe" ifid="TEST-UUID">
  <tw-passagedata pid="1" name="Start" tags="">Content</tw-passagedata>
</tw-storydata>
      ]]

      local story1 = TwineParser.parse(html)
      local exported = TwineExporter.export(story1, "harlowe")
      local story2 = TwineParser.parse(exported)

      assert.equals(story1.metadata.name, story2.metadata.name)
    end)
  end)

  describe("format-specific parsing", function()
    describe("Harlowe", function()
      it("parses set macro", function()
        local html = [[
<tw-storydata name="Test" format="Harlowe" ifid="TEST">
  <tw-passagedata pid="1" name="Start" tags="">(set: $gold to 100)</tw-passagedata>
</tw-storydata>
        ]]

        local story = TwineParser.parse(html)
        local ast = story.passages[1].ast

        local found_assignment = false
        for _, node in ipairs(ast) do
          if node.type == "assignment" then
            found_assignment = true
          end
        end

        assert.is_true(found_assignment, "Should find assignment node")
      end)

      it("parses if macro with hook", function()
        local html = [[
<tw-storydata name="Test" format="Harlowe" ifid="TEST">
  <tw-passagedata pid="1" name="Start" tags="">(if: $gold > 50)[Rich!]</tw-passagedata>
</tw-storydata>
        ]]

        local story = TwineParser.parse(html)
        local ast = story.passages[1].ast

        local found_conditional = false
        for _, node in ipairs(ast) do
          if node.type == "conditional" then
            found_conditional = true
          end
        end

        assert.is_true(found_conditional, "Should find conditional node")
      end)
    end)

    describe("SugarCube", function()
      it("parses set macro", function()
        local html = [[
<tw-storydata name="Test" format="SugarCube" ifid="TEST">
  <tw-passagedata pid="1" name="Start" tags="">&lt;&lt;set $gold to 100&gt;&gt;</tw-passagedata>
</tw-storydata>
        ]]

        local story = TwineParser.parse(html)
        local ast = story.passages[1].ast

        local found_assignment = false
        for _, node in ipairs(ast) do
          if node.type == "assignment" then
            found_assignment = true
          end
        end

        assert.is_true(found_assignment, "Should find assignment node")
      end)
    end)

    describe("Chapbook", function()
      it("parses variable assignment", function()
        local html = [[
<tw-storydata name="Test" format="Chapbook" ifid="TEST">
  <tw-passagedata pid="1" name="Start" tags="">gold: 100</tw-passagedata>
</tw-storydata>
        ]]

        local story = TwineParser.parse(html)
        local ast = story.passages[1].ast

        local found_assignment = false
        for _, node in ipairs(ast) do
          if node.type == "assignment" then
            found_assignment = true
          end
        end

        assert.is_true(found_assignment, "Should find assignment node")
      end)
    end)

    describe("Snowman", function()
      it("parses template expression", function()
        local html = [[
<tw-storydata name="Test" format="Snowman" ifid="TEST">
  <tw-passagedata pid="1" name="Start" tags="">&lt;%= s.gold %&gt;</tw-passagedata>
</tw-storydata>
        ]]

        local story = TwineParser.parse(html)
        local ast = story.passages[1].ast

        local found_print = false
        for _, node in ipairs(ast) do
          if node.type == "print" then
            found_print = true
          end
        end

        assert.is_true(found_print, "Should find print node")
      end)
    end)
  end)

  describe("performance", function()
    it("parses large story efficiently", function()
      -- Generate large story
      local passages = {}
      for i = 1, 100 do
        table.insert(passages, string.format(
          '<tw-passagedata pid="%d" name="Passage%d" tags="">Content %d</tw-passagedata>',
          i, i, i
        ))
      end

      local html = string.format([[
<tw-storydata name="Large" startnode="1" format="Harlowe" ifid="TEST">
%s
</tw-storydata>
      ]], table.concat(passages, "\n"))

      local start_time = os.clock()
      local story = TwineParser.parse(html)
      local parse_time = os.clock() - start_time

      assert.is_not_nil(story)
      assert.equals(100, #story.passages)
      assert.is_true(parse_time < 1.0, string.format("Parse took %.2fs (expected <1s)", parse_time))
    end)
  end)
end)
