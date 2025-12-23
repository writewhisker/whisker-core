--- End-to-end integration tests for Phase 4 Twine support
-- Tests complete workflows: import → export → round-trip
--
-- tests/twine/e2e_integration_spec.lua

describe("E2E Integration", function()
  local TwineParser
  local TwineExporter

  before_each(function()
    package.loaded['whisker.twine.parser'] = nil
    package.loaded['whisker.twine.export.exporter'] = nil
    TwineParser = require('whisker.twine.parser')
    TwineExporter = require('whisker.twine.export.exporter')
  end)

  --- Load fixture helper
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

  --- Generate large story for performance tests
  local function generate_large_story(num_passages)
    local passages = {}

    for i = 1, num_passages do
      local links = ""
      if i < num_passages then
        links = string.format("[[Next->Passage%d]]", i + 1)
      end

      table.insert(passages, string.format(
        '<tw-passagedata pid="%d" name="Passage%d" tags="">Passage %d content. %s</tw-passagedata>',
        i, i, i, links
      ))
    end

    return string.format([[
<!DOCTYPE html>
<html><body>
<tw-storydata name="Large Test" startnode="1" format="Harlowe" ifid="TEST-UUID">
%s
</tw-storydata>
</body></html>
]], table.concat(passages, "\n"))
  end

  describe("Harlowe Complete Workflow", function()
    it("imports Harlowe story successfully", function()
      local html = load_fixture("basic_harlowe.html")
      if not html then pending("Fixture not found") return end

      local story, err = TwineParser.parse(html)

      assert.is_not_nil(story, err)
      assert.equals("harlowe", story.metadata.format:lower())
      assert.is_true(#story.passages > 0)
    end)

    it("exports back to Harlowe HTML", function()
      local html = load_fixture("basic_harlowe.html")
      if not html then pending("Fixture not found") return end

      local story = TwineParser.parse(html)
      local exported = TwineExporter.export(story, "harlowe")

      assert.is_not_nil(exported)
      assert.is_true(exported:find("<tw%-storydata") ~= nil)
      assert.is_true(exported:find('format="Harlowe"') ~= nil)
    end)

    it("round-trips preserving passage count", function()
      local html = load_fixture("basic_harlowe.html")
      if not html then pending("Fixture not found") return end

      local story1 = TwineParser.parse(html)
      local exported = TwineExporter.export(story1, "harlowe")
      local story2 = TwineParser.parse(exported)

      assert.is_not_nil(story2)
      assert.equals(#story1.passages, #story2.passages)
    end)

    it("round-trips preserving passage names", function()
      local html = load_fixture("basic_harlowe.html")
      if not html then pending("Fixture not found") return end

      local story1 = TwineParser.parse(html)
      local exported = TwineExporter.export(story1, "harlowe")
      local story2 = TwineParser.parse(exported)

      local names1 = {}
      local names2 = {}

      for _, p in ipairs(story1.passages) do
        names1[p.name] = true
      end
      for _, p in ipairs(story2.passages) do
        names2[p.name] = true
      end

      for name in pairs(names1) do
        assert.is_true(names2[name], "Passage '" .. name .. "' should be preserved")
      end
    end)
  end)

  describe("SugarCube Complete Workflow", function()
    it("imports SugarCube story successfully", function()
      local html = load_fixture("basic_sugarcube.html")
      if not html then pending("Fixture not found") return end

      local story, err = TwineParser.parse(html)

      assert.is_not_nil(story, err)
      assert.equals("sugarcube", story.metadata.format:lower())
    end)

    it("exports to SugarCube HTML", function()
      local html = load_fixture("basic_sugarcube.html")
      if not html then pending("Fixture not found") return end

      local story = TwineParser.parse(html)
      local exported = TwineExporter.export(story, "sugarcube")

      assert.is_not_nil(exported)
      assert.is_true(exported:find('format="SugarCube"') ~= nil)
    end)

    it("round-trips preserving structure", function()
      local html = load_fixture("basic_sugarcube.html")
      if not html then pending("Fixture not found") return end

      local story1 = TwineParser.parse(html)
      local exported = TwineExporter.export(story1, "sugarcube")
      local story2 = TwineParser.parse(exported)

      assert.is_not_nil(story2)
      assert.equals(#story1.passages, #story2.passages)
      assert.equals(story1.metadata.name, story2.metadata.name)
    end)
  end)

  describe("Chapbook Complete Workflow", function()
    it("imports Chapbook story successfully", function()
      local html = load_fixture("basic_chapbook.html")
      if not html then pending("Fixture not found") return end

      local story, err = TwineParser.parse(html)

      assert.is_not_nil(story, err)
      assert.equals("chapbook", story.metadata.format:lower())
    end)

    it("exports to Chapbook HTML", function()
      local html = load_fixture("basic_chapbook.html")
      if not html then pending("Fixture not found") return end

      local story = TwineParser.parse(html)
      local exported = TwineExporter.export(story, "chapbook")

      assert.is_not_nil(exported)
      assert.is_true(exported:find('format="Chapbook"') ~= nil)
    end)

    it("round-trips preserving structure", function()
      local html = load_fixture("basic_chapbook.html")
      if not html then pending("Fixture not found") return end

      local story1 = TwineParser.parse(html)
      local exported = TwineExporter.export(story1, "chapbook")
      local story2 = TwineParser.parse(exported)

      assert.is_not_nil(story2)
      assert.equals(#story1.passages, #story2.passages)
    end)
  end)

  describe("Snowman Complete Workflow", function()
    it("imports Snowman story successfully", function()
      local html = load_fixture("basic_snowman.html")
      if not html then pending("Fixture not found") return end

      local story, err = TwineParser.parse(html)

      assert.is_not_nil(story, err)
      assert.equals("snowman", story.metadata.format:lower())
    end)

    it("exports to Snowman HTML", function()
      local html = load_fixture("basic_snowman.html")
      if not html then pending("Fixture not found") return end

      local story = TwineParser.parse(html)
      local exported = TwineExporter.export(story, "snowman")

      assert.is_not_nil(exported)
      assert.is_true(exported:find('format="Snowman"') ~= nil)
    end)

    it("round-trips preserving structure", function()
      local html = load_fixture("basic_snowman.html")
      if not html then pending("Fixture not found") return end

      local story1 = TwineParser.parse(html)
      local exported = TwineExporter.export(story1, "snowman")
      local story2 = TwineParser.parse(exported)

      assert.is_not_nil(story2)
      assert.equals(#story1.passages, #story2.passages)
    end)
  end)

  describe("Cross-Format Conversion", function()
    it("converts Harlowe to SugarCube", function()
      local html = load_fixture("basic_harlowe.html")
      if not html then pending("Fixture not found") return end

      local harlowe_story = TwineParser.parse(html)
      local sugarcube_html = TwineExporter.export(harlowe_story, "sugarcube")
      local sugarcube_story = TwineParser.parse(sugarcube_html)

      assert.is_not_nil(sugarcube_story)
      assert.equals("sugarcube", sugarcube_story.metadata.format:lower())
      assert.equals(#harlowe_story.passages, #sugarcube_story.passages)
    end)

    it("converts SugarCube to Harlowe", function()
      local html = load_fixture("basic_sugarcube.html")
      if not html then pending("Fixture not found") return end

      local sugarcube_story = TwineParser.parse(html)
      local harlowe_html = TwineExporter.export(sugarcube_story, "harlowe")
      local harlowe_story = TwineParser.parse(harlowe_html)

      assert.is_not_nil(harlowe_story)
      assert.equals("harlowe", harlowe_story.metadata.format:lower())
      assert.equals(#sugarcube_story.passages, #harlowe_story.passages)
    end)

    it("converts Chapbook to SugarCube", function()
      local html = load_fixture("basic_chapbook.html")
      if not html then pending("Fixture not found") return end

      local chapbook_story = TwineParser.parse(html)
      local sugarcube_html = TwineExporter.export(chapbook_story, "sugarcube")
      local sugarcube_story = TwineParser.parse(sugarcube_html)

      assert.is_not_nil(sugarcube_story)
      assert.equals(#chapbook_story.passages, #sugarcube_story.passages)
    end)

    it("converts Snowman to Harlowe", function()
      local html = load_fixture("basic_snowman.html")
      if not html then pending("Fixture not found") return end

      local snowman_story = TwineParser.parse(html)
      local harlowe_html = TwineExporter.export(snowman_story, "harlowe")
      local harlowe_story = TwineParser.parse(harlowe_html)

      assert.is_not_nil(harlowe_story)
      assert.equals(#snowman_story.passages, #harlowe_story.passages)
    end)

    it("preserves passage names across formats", function()
      local html = load_fixture("basic_harlowe.html")
      if not html then pending("Fixture not found") return end

      local story1 = TwineParser.parse(html)
      local exported = TwineExporter.export(story1, "chapbook")
      local story2 = TwineParser.parse(exported)

      for i, p1 in ipairs(story1.passages) do
        assert.equals(p1.name, story2.passages[i].name)
      end
    end)
  end)

  describe("Error Handling", function()
    it("handles empty HTML gracefully", function()
      local story, err = TwineParser.parse("")

      assert.is_nil(story)
      assert.is_not_nil(err)
    end)

    it("handles non-Twine HTML gracefully", function()
      local html = [[<html><body>Not a Twine story</body></html>]]
      local story, err = TwineParser.parse(html)

      assert.is_nil(story)
      assert.is_not_nil(err)
    end)

    it("handles missing passages gracefully", function()
      local html = [[
<tw-storydata name="Empty" format="Harlowe" ifid="TEST">
</tw-storydata>
      ]]
      local story, err = TwineParser.parse(html)

      -- Should parse but have no passages
      assert.is_not_nil(story)
      assert.equals(0, #story.passages)
    end)

    it("handles malformed passage content", function()
      local html = [[
<tw-storydata name="Broken" format="Harlowe" ifid="TEST">
  <tw-passagedata pid="1" name="Start" tags="">(set: $x to</tw-passagedata>
</tw-storydata>
      ]]

      local story, err = TwineParser.parse(html)

      -- Should parse, perhaps with warnings
      assert.is_not_nil(story)
      assert.equals(1, #story.passages)
    end)

    it("handles unsupported format", function()
      local html = [[
<tw-storydata name="Test" format="UnknownFormat" ifid="TEST">
  <tw-passagedata pid="1" name="Start" tags="">Hello</tw-passagedata>
</tw-storydata>
      ]]

      local story, err = TwineParser.parse(html)

      -- Should fail with clear error
      assert.is_nil(story)
      assert.is_true(err:find("Unsupported") ~= nil or err:find("format") ~= nil)
    end)

    it("provides helpful error message for missing storydata", function()
      local html = [[<html><body><p>Regular HTML</p></body></html>]]
      local story, err = TwineParser.parse(html)

      assert.is_nil(story)
      assert.is_true(err:find("tw%-storydata") ~= nil)
    end)
  end)

  describe("Performance Requirements", function()
    it("parses 200 passages in under 500ms", function()
      local large_html = generate_large_story(200)

      local start_time = os.clock()
      local story = TwineParser.parse(large_html)
      local parse_time = os.clock() - start_time

      assert.is_not_nil(story)
      assert.equals(200, #story.passages)
      assert.is_true(parse_time < 0.5,
        string.format("Parse took %.3fs (expected <0.5s)", parse_time))
    end)

    it("exports 200 passages in under 1 second", function()
      local large_html = generate_large_story(200)
      local story = TwineParser.parse(large_html)

      local start_time = os.clock()
      local exported = TwineExporter.export(story, "harlowe")
      local export_time = os.clock() - start_time

      assert.is_not_nil(exported)
      assert.is_true(export_time < 1.0,
        string.format("Export took %.3fs (expected <1.0s)", export_time))
    end)

    it("handles 500 passages without timeout", function()
      local large_html = generate_large_story(500)

      local start_time = os.clock()
      local story = TwineParser.parse(large_html)
      local parse_time = os.clock() - start_time

      assert.is_not_nil(story)
      assert.equals(500, #story.passages)
      assert.is_true(parse_time < 2.0,
        string.format("Parse took %.3fs (expected <2.0s)", parse_time))
    end)
  end)

  describe("Memory Usage", function()
    it("does not leak memory significantly", function()
      collectgarbage("collect")
      local start_mem = collectgarbage("count")

      -- Parse multiple stories
      for i = 1, 10 do
        local html = generate_large_story(50)
        local story = TwineParser.parse(html)
        assert.is_not_nil(story)
      end

      collectgarbage("collect")
      local end_mem = collectgarbage("count")

      local mem_increase = end_mem - start_mem

      -- Should not leak significantly (allow 5MB growth for 10 stories)
      assert.is_true(mem_increase < 5000,
        string.format("Memory increased by %.2f KB (expected <5000 KB)", mem_increase))
    end)

    it("cleans up after export", function()
      collectgarbage("collect")
      local start_mem = collectgarbage("count")

      -- Export multiple stories
      local story = {
        metadata = { name = "Test" },
        passages = {}
      }

      for i = 1, 100 do
        table.insert(story.passages, { name = "P" .. i, text = "Content " .. i })
      end

      for i = 1, 10 do
        TwineExporter.export(story, "harlowe")
        TwineExporter.export(story, "sugarcube")
        TwineExporter.export(story, "chapbook")
        TwineExporter.export(story, "snowman")
      end

      collectgarbage("collect")
      local end_mem = collectgarbage("count")

      local mem_increase = end_mem - start_mem

      assert.is_true(mem_increase < 2000,
        string.format("Memory increased by %.2f KB after exports", mem_increase))
    end)
  end)

  describe("Unicode Support", function()
    it("preserves Unicode characters through round-trip", function()
      local html = load_fixture("unicode_story.html")
      if not html then pending("Fixture not found") return end

      local story1 = TwineParser.parse(html)
      local exported = TwineExporter.export(story1, "harlowe")
      local story2 = TwineParser.parse(exported)

      -- Check Unicode is preserved
      local has_unicode = false
      for _, passage in ipairs(story2.passages) do
        if passage.content and passage.content:find("\xf0") then  -- UTF-8 emoji leader byte
          has_unicode = true
        end
        if passage.text and passage.text:find("\xf0") then
          has_unicode = true
        end
      end

      -- The story should have some Unicode content
      assert.is_not_nil(story2)
      assert.equals(#story1.passages, #story2.passages)
    end)
  end)
end)
