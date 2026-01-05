--- PWA Exporter Tests
-- Tests for the PWA export functionality
-- @module tests.export.test_pwa_exporter

local PWAExporter = require("whisker.export.pwa.pwa_exporter")

describe("PWA Exporter", function()
  local function create_basic_story()
    return {
      name = "Test Story",
      title = "Test Story",
      author = "Test Author",
      description = "A test interactive story",
      start_passage = "Start",
      passages = {
        {
          name = "Start",
          text = "Welcome to the test story!\n\nThis is an adventure.",
          choices = {
            { text = "Begin", target = "Next" },
          },
        },
        {
          name = "Next",
          text = "This is the second passage.",
          choices = {
            { text = "Continue", target = "End" },
          },
        },
        {
          name = "End",
          text = "The End!",
          choices = {},
        },
      },
    }
  end

  local function create_complex_story()
    return {
      name = "Complex PWA Story",
      author = "Tester",
      description = "A complex interactive story for PWA testing",
      start = "Start",
      passages = {
        {
          name = "Start",
          text = "You are at a crossroads. Which way do you go?",
          choices = {
            { text = "Go left", target = "Left" },
            { text = "Go right", target = "Right" },
          },
        },
        {
          name = "Left",
          text = "You went left!",
          choices = {
            { text = "Return", target = "Start" },
          },
        },
        {
          name = "Right",
          text = "You went right!",
          choices = {
            { text = "Return", target = "Start" },
          },
        },
      },
    }
  end

  describe("initialization", function()
    it("should create a new exporter", function()
      local exporter = PWAExporter.new()
      assert.is_not_nil(exporter)
    end)

    it("should provide metadata", function()
      local exporter = PWAExporter.new()
      local meta = exporter:metadata()
      assert.equals("pwa", meta.format)
      assert.equals(".zip", meta.file_extension)
      assert.is_not_nil(meta.description)
    end)
  end)

  describe("can_export", function()
    it("should return true for valid story", function()
      local exporter = PWAExporter.new()
      local story = create_basic_story()
      local can, err = exporter:can_export(story)
      assert.is_true(can)
      assert.is_nil(err)
    end)

    it("should return false for nil story", function()
      local exporter = PWAExporter.new()
      local can, err = exporter:can_export(nil)
      assert.is_false(can)
      assert.is_not_nil(err)
    end)

    it("should return false for story without passages", function()
      local exporter = PWAExporter.new()
      local can, err = exporter:can_export({ name = "Empty" })
      assert.is_false(can)
      assert.is_not_nil(err)
    end)
  end)

  describe("export", function()
    it("should export basic story", function()
      local exporter = PWAExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)
      assert.is_not_nil(result)
      assert.is_not_nil(result.content)
      assert.is_not_nil(result.files)
    end)

    it("should generate all required files", function()
      local exporter = PWAExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)

      assert.is_not_nil(result.files["index.html"])
      assert.is_not_nil(result.files["manifest.json"])
      assert.is_not_nil(result.files["sw.js"])
      assert.is_not_nil(result.files["offline.html"])
    end)

    it("should generate icon placeholders", function()
      local exporter = PWAExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)

      assert.is_not_nil(result.files["icons/icon-192.png"])
      assert.is_not_nil(result.files["icons/icon-512.png"])
    end)
  end)

  describe("index.html generation", function()
    it("should include PWA meta tags", function()
      local exporter = PWAExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)
      local html = result.files["index.html"]

      assert.is_true(html:match('rel="manifest"') ~= nil)
      assert.is_true(html:match('apple%-mobile%-web%-app%-capable') ~= nil)
      assert.is_true(html:match('theme%-color') ~= nil)
    end)

    it("should include story data", function()
      local exporter = PWAExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)
      local html = result.files["index.html"]

      assert.is_true(html:match("WHISKER_STORY_DATA") ~= nil)
    end)

    it("should include service worker registration", function()
      local exporter = PWAExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)
      local html = result.files["index.html"]

      assert.is_true(html:match("serviceWorker") ~= nil)
      assert.is_true(html:match("sw%.js") ~= nil)
    end)

    it("should include runtime code", function()
      local exporter = PWAExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)
      local html = result.files["index.html"]

      assert.is_true(html:match("whiskerRuntime") ~= nil or html:match("showPassage") ~= nil)
    end)

    it("should escape HTML in title", function()
      local exporter = PWAExporter.new()
      local story = create_basic_story()
      story.name = "Test <script>Story"
      local result = exporter:export(story)
      local html = result.files["index.html"]

      assert.is_true(html:match("&lt;script&gt;") ~= nil)
    end)
  end)

  describe("manifest.json generation", function()
    it("should be valid JSON", function()
      local exporter = PWAExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)
      local manifest = result.files["manifest.json"]

      -- Check it starts and ends as JSON object
      assert.is_true(manifest:match("^{") ~= nil)
      assert.is_true(manifest:match("}$") ~= nil)
    end)

    it("should include required fields", function()
      local exporter = PWAExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)
      local manifest = result.files["manifest.json"]

      assert.is_true(manifest:match('"name"') ~= nil)
      assert.is_true(manifest:match('"short_name"') ~= nil)
      assert.is_true(manifest:match('"start_url"') ~= nil)
      assert.is_true(manifest:match('"display"') ~= nil)
      assert.is_true(manifest:match('"icons"') ~= nil)
    end)

    it("should include theme color", function()
      local exporter = PWAExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { theme_color = "#ff0000" })
      local manifest = result.files["manifest.json"]

      assert.is_true(manifest:match("#ff0000") ~= nil)
    end)

    it("should respect display option", function()
      local exporter = PWAExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { display = "fullscreen" })
      local manifest = result.files["manifest.json"]

      assert.is_true(manifest:match('"fullscreen"') ~= nil)
    end)
  end)

  describe("service worker generation", function()
    it("should include cache name", function()
      local exporter = PWAExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)
      local sw = result.files["sw.js"]

      assert.is_true(sw:match("CACHE_NAME") ~= nil)
      assert.is_true(sw:match("whisker%-story%-") ~= nil)
    end)

    it("should include install event", function()
      local exporter = PWAExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)
      local sw = result.files["sw.js"]

      assert.is_true(sw:match("addEventListener%('install'") ~= nil)
    end)

    it("should include fetch event", function()
      local exporter = PWAExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)
      local sw = result.files["sw.js"]

      assert.is_true(sw:match("addEventListener%('fetch'") ~= nil)
    end)

    it("should include activate event", function()
      local exporter = PWAExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)
      local sw = result.files["sw.js"]

      assert.is_true(sw:match("addEventListener%('activate'") ~= nil)
    end)

    it("should include cache version from options", function()
      local exporter = PWAExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { cache_version = "test-v1" })
      local sw = result.files["sw.js"]

      assert.is_true(sw:match("test%-v1") ~= nil)
    end)
  end)

  describe("offline page generation", function()
    it("should include title", function()
      local exporter = PWAExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)
      local offline = result.files["offline.html"]

      assert.is_true(offline:match("Test Story") ~= nil)
      assert.is_true(offline:match("Offline") ~= nil)
    end)

    it("should include retry button", function()
      local exporter = PWAExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)
      local offline = result.files["offline.html"]

      assert.is_true(offline:match("Retry") ~= nil)
      assert.is_true(offline:match("reload") ~= nil)
    end)
  end)

  describe("export options", function()
    it("should respect app_name option", function()
      local exporter = PWAExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { app_name = "Custom App Name" })

      assert.equals("Custom App Name", result.manifest.app_name)
      assert.is_true(result.files["index.html"]:match("Custom App Name") ~= nil)
    end)

    it("should respect short_name option", function()
      local exporter = PWAExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { short_name = "ShortApp" })

      assert.equals("ShortApp", result.manifest.short_name)
    end)

    it("should truncate short_name to 12 chars if not provided", function()
      local exporter = PWAExporter.new()
      local story = { name = "A Very Long Story Title Indeed", passages = {{ name = "Start", text = "" }} }
      local result = exporter:export(story)

      assert.is_true(#result.manifest.short_name <= 12)
    end)

    it("should use default theme color", function()
      local exporter = PWAExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)

      assert.equals("#3498db", result.manifest.theme_color)
    end)

    it("should respect custom theme color", function()
      local exporter = PWAExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { theme_color = "#123456" })

      assert.equals("#123456", result.manifest.theme_color)
    end)
  end)

  describe("manifest", function()
    it("should include format in manifest", function()
      local exporter = PWAExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)

      assert.equals("pwa", result.manifest.format)
    end)

    it("should include passage count", function()
      local exporter = PWAExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)

      assert.equals(3, result.manifest.passage_count)
    end)

    it("should include filename", function()
      local exporter = PWAExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)

      assert.is_not_nil(result.manifest.filename)
      assert.is_true(result.manifest.filename:match("%.zip$") ~= nil)
    end)
  end)

  describe("validation", function()
    it("should validate valid bundle", function()
      local exporter = PWAExporter.new()
      local story = create_basic_story()
      local bundle = exporter:export(story)
      local validation = exporter:validate(bundle)

      assert.is_true(validation.valid)
      assert.equals(0, #validation.errors)
    end)

    it("should reject empty bundle", function()
      local exporter = PWAExporter.new()
      local validation = exporter:validate({ content = "", files = {} })

      assert.is_false(validation.valid)
    end)

    it("should report missing files", function()
      local exporter = PWAExporter.new()
      local validation = exporter:validate({
        content = "test",
        files = { ["index.html"] = "test" }
      })

      assert.is_false(validation.valid)
      assert.is_true(#validation.errors > 0)
    end)

    it("should report missing manifest link", function()
      local exporter = PWAExporter.new()
      local validation = exporter:validate({
        content = "<!DOCTYPE html><html></html>",
        files = {
          ["index.html"] = "<!DOCTYPE html><html></html>",
          ["manifest.json"] = "{}",
          ["sw.js"] = "",
          ["offline.html"] = "",
        }
      })

      assert.is_false(validation.valid)
    end)
  end)

  describe("size estimation", function()
    it("should estimate export size", function()
      local exporter = PWAExporter.new()
      local story = create_basic_story()
      local size = exporter:estimate_size(story)

      assert.is_true(size > 0)
    end)

    it("should estimate larger size for more passages", function()
      local exporter = PWAExporter.new()
      local small_story = create_basic_story()
      local large_story = {
        name = "Large",
        passages = {},
      }
      for i = 1, 50 do
        table.insert(large_story.passages, { name = "Passage" .. i, text = "Content" })
      end

      local small_size = exporter:estimate_size(small_story)
      local large_size = exporter:estimate_size(large_story)

      assert.is_true(large_size > small_size)
    end)
  end)

  describe("edge cases", function()
    it("should handle story with no start passage", function()
      local exporter = PWAExporter.new()
      local story = {
        name = "No Start",
        passages = {
          { name = "One", text = "First", choices = {} },
          { name = "Two", text = "Second", choices = {} },
        },
      }
      local result = exporter:export(story)

      assert.is_not_nil(result)
      assert.is_not_nil(result.warnings)
      assert.is_true(#result.warnings > 0)
    end)

    it("should handle story with special characters in name", function()
      local exporter = PWAExporter.new()
      local story = {
        name = "Test <Story> & 'Quotes'",
        passages = {
          { name = "Start", text = "Test", choices = {} },
        },
        start_passage = "Start",
      }
      local result = exporter:export(story)

      assert.is_not_nil(result)
      assert.is_not_nil(result.files["index.html"])
    end)

    it("should handle empty passage content", function()
      local exporter = PWAExporter.new()
      local story = {
        name = "Empty Content",
        passages = {
          { name = "Start", text = "", choices = {} },
        },
      }
      local result = exporter:export(story)

      assert.is_not_nil(result)
    end)
  end)
end)
