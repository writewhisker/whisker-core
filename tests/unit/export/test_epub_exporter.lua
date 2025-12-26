-- Unit Tests for EPUB Exporter
local EpubExporter = require("whisker.export.epub_exporter")

describe("EPUB Exporter", function()
  local exporter

  before_each(function()
    exporter = EpubExporter.new()
  end)

  describe("metadata", function()
    it("should return correct metadata", function()
      local meta = exporter:metadata()

      assert.equals("epub", meta.format)
      assert.equals(".epub", meta.file_extension)
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

  describe("escape_xml", function()
    it("should escape ampersand", function()
      local result = exporter:escape_xml("Tom & Jerry")
      assert.equals("Tom &amp; Jerry", result)
    end)

    it("should escape angle brackets", function()
      local result = exporter:escape_xml("<tag>")
      assert.equals("&lt;tag&gt;", result)
    end)

    it("should escape quotes", function()
      local result = exporter:escape_xml('Say "hello"')
      assert.equals("Say &quot;hello&quot;", result)
    end)

    it("should handle nil", function()
      local result = exporter:escape_xml(nil)
      assert.equals("", result)
    end)
  end)

  describe("generate_uuid", function()
    it("should generate valid UUID format", function()
      local uuid = exporter:generate_uuid()

      assert.matches("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-4%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$", uuid)
    end)

    it("should generate unique UUIDs", function()
      local uuid1 = exporter:generate_uuid()
      local uuid2 = exporter:generate_uuid()

      assert.not_equals(uuid1, uuid2)
    end)
  end)

  describe("make_filename", function()
    it("should create lowercase filename", function()
      local filename = exporter:make_filename("Start Here")
      assert.equals("start_here.xhtml", filename)
    end)

    it("should remove special characters", function()
      local filename = exporter:make_filename("Start's Beginning!")
      assert.equals("starts_beginning.xhtml", filename)
    end)
  end)

  describe("convert_content", function()
    it("should strip Harlowe macros", function()
      local content = exporter:convert_content("(set: $x to 5)\nHello", "harlowe", {})

      assert.not_matches("%(set:", content)
      assert.matches("Hello", content)
    end)

    it("should strip SugarCube macros", function()
      local content = exporter:convert_content("<<set $x to 5>>\nHello", "sugarcube", {})

      assert.not_matches("<<set", content)
      assert.matches("Hello", content)
    end)

    it("should convert Harlowe links to XHTML", function()
      local content = exporter:convert_content("[[Go->Target]]", "harlowe", {})

      assert.matches('<a href="target.xhtml">Go</a>', content)
    end)

    it("should convert SugarCube links to XHTML", function()
      local content = exporter:convert_content("[[Go|Target]]", "sugarcube", {})

      assert.matches('<a href="target.xhtml">Go</a>', content)
    end)

    it("should wrap text in paragraphs", function()
      local content = exporter:convert_content("Hello world", "harlowe", {})

      assert.matches("<p>Hello world</p>", content)
    end)
  end)

  describe("generate_container", function()
    it("should generate valid container.xml", function()
      local container = exporter:generate_container()

      assert.matches("<?xml version", container)
      assert.matches("urn:oasis:names:tc:opendocument:xmlns:container", container)
      assert.matches("OEBPS/content.opf", container)
    end)
  end)

  describe("generate_opf", function()
    it("should generate valid content.opf", function()
      local story = {
        name = "Test Story",
        author = "Test Author",
        passages = {{name = "Start", content = "Hello", tags = {}}}
      }
      local uuid = "12345678-1234-4123-8123-123456789abc"

      local opf = exporter:generate_opf(story, uuid)

      assert.matches("<?xml version", opf)
      assert.matches("http://www.idpf.org/2007/opf", opf)
      assert.matches("Test Story", opf)
      assert.matches("Test Author", opf)
      -- UUID contains dashes which are special in Lua patterns, use find instead
      assert.is_not_nil(opf:find(uuid, 1, true))
      assert.matches("start.xhtml", opf)
    end)

    it("should include nav item in manifest", function()
      local story = {
        name = "Test",
        passages = {{name = "Start", content = "Hello", tags = {}}}
      }

      local opf = exporter:generate_opf(story, "test-uuid")

      assert.matches('id="nav"', opf)
      assert.matches('href="nav.xhtml"', opf)
    end)
  end)

  describe("generate_nav", function()
    it("should generate valid nav.xhtml", function()
      local story = {
        name = "Test Story",
        passages = {
          {name = "Start", content = "Hello", tags = {}},
          {name = "End", content = "Goodbye", tags = {}}
        }
      }

      local nav = exporter:generate_nav(story)

      assert.matches("<?xml version", nav)
      assert.matches("Table of Contents", nav)
      assert.matches('href="start.xhtml"', nav)
      assert.matches('href="end.xhtml"', nav)
      assert.matches(">Start<", nav)
      assert.matches(">End<", nav)
    end)
  end)

  describe("generate_passage_xhtml", function()
    it("should generate valid XHTML for passage", function()
      local passage = {name = "Start", content = "Hello world", tags = {}}
      local story = {format = "harlowe", passages = {passage}}

      local xhtml = exporter:generate_passage_xhtml(passage, story)

      assert.matches("<?xml version", xhtml)
      assert.matches("<h1>Start</h1>", xhtml)
      assert.matches("<p>Hello world</p>", xhtml)
    end)
  end)

  describe("export", function()
    it("should export story to EPUB structure", function()
      local story = {
        name = "My Story",
        format = "harlowe",
        passages = {
          {name = "Start", content = "Welcome!", tags = {}},
          {name = "End", content = "Goodbye!", tags = {}}
        }
      }

      local bundle = exporter:export(story)

      assert.is_nil(bundle.content)  -- EPUB is multi-file
      assert.is_not_nil(bundle.files)
      assert.is_not_nil(bundle.manifest)
    end)

    it("should include mimetype file", function()
      local story = {
        name = "Test",
        passages = {{name = "Start", content = "Hello", tags = {}}}
      }

      local bundle = exporter:export(story)

      assert.equals("application/epub+zip", bundle.files["mimetype"])
    end)

    it("should include container.xml", function()
      local story = {
        name = "Test",
        passages = {{name = "Start", content = "Hello", tags = {}}}
      }

      local bundle = exporter:export(story)

      assert.is_not_nil(bundle.files["META-INF/container.xml"])
    end)

    it("should include content.opf", function()
      local story = {
        name = "Test",
        passages = {{name = "Start", content = "Hello", tags = {}}}
      }

      local bundle = exporter:export(story)

      assert.is_not_nil(bundle.files["OEBPS/content.opf"])
    end)

    it("should include nav.xhtml", function()
      local story = {
        name = "Test",
        passages = {{name = "Start", content = "Hello", tags = {}}}
      }

      local bundle = exporter:export(story)

      assert.is_not_nil(bundle.files["OEBPS/nav.xhtml"])
    end)

    it("should include passage files", function()
      local story = {
        name = "Test",
        passages = {
          {name = "Start", content = "Hello", tags = {}},
          {name = "End", content = "Goodbye", tags = {}}
        }
      }

      local bundle = exporter:export(story)

      assert.is_not_nil(bundle.files["OEBPS/start.xhtml"])
      assert.is_not_nil(bundle.files["OEBPS/end.xhtml"])
    end)

    it("should include manifest with UUID", function()
      local story = {
        name = "Test",
        passages = {{name = "Start", content = "Hello", tags = {}}}
      }

      local bundle = exporter:export(story)

      assert.equals("epub", bundle.manifest.format)
      assert.equals("Test", bundle.manifest.story_name)
      assert.equals(1, bundle.manifest.passage_count)
      assert.is_not_nil(bundle.manifest.uuid)
    end)
  end)

  describe("validate", function()
    it("should validate valid bundle", function()
      local bundle = {
        files = {
          ["mimetype"] = "application/epub+zip",
          ["META-INF/container.xml"] = "<container>...</container>",
          ["OEBPS/content.opf"] = "<package>...</package>",
          ["OEBPS/nav.xhtml"] = "<html>...</html>"
        }
      }

      local result = exporter:validate(bundle)

      assert.is_true(result.valid)
      assert.equals(0, #result.errors)
    end)

    it("should fail for missing files", function()
      local bundle = {files = {}}

      local result = exporter:validate(bundle)

      assert.is_false(result.valid)
      assert.is_true(#result.errors > 0)
    end)

    it("should fail for nil files", function()
      local bundle = {}

      local result = exporter:validate(bundle)

      assert.is_false(result.valid)
    end)

    it("should report missing required files", function()
      local bundle = {
        files = {
          ["mimetype"] = "application/epub+zip"
        }
      }

      local result = exporter:validate(bundle)

      assert.is_false(result.valid)
      -- Should have errors for missing container.xml, content.opf, nav.xhtml
      assert.is_true(#result.errors >= 3)
    end)
  end)

end)
