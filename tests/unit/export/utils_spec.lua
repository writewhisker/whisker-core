--- Export Utils Tests
-- @module tests.unit.export.utils_spec

describe("ExportUtils", function()
  local ExportUtils

  before_each(function()
    package.loaded["whisker.export.utils"] = nil
    ExportUtils = require("whisker.export.utils")
  end)

  describe("timestamp", function()
    it("returns ISO 8601 formatted timestamp", function()
      local ts = ExportUtils.timestamp()
      assert.is_string(ts)
      -- Format: YYYY-MM-DDTHH:MM:SSZ
      assert.truthy(ts:match("^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$"))
    end)
  end)

  describe("escape_html", function()
    it("escapes angle brackets", function()
      assert.equals("&lt;div&gt;", ExportUtils.escape_html("<div>"))
    end)

    it("escapes ampersand", function()
      assert.equals("&amp;amp;", ExportUtils.escape_html("&amp;"))
    end)

    it("escapes quotes", function()
      assert.equals("&quot;quote&quot;", ExportUtils.escape_html('"quote"'))
      assert.equals("&#39;single&#39;", ExportUtils.escape_html("'single'"))
    end)

    it("handles nil input", function()
      assert.equals("", ExportUtils.escape_html(nil))
    end)

    it("handles numbers", function()
      assert.equals("42", ExportUtils.escape_html(42))
    end)

    it("escapes multiple special characters", function()
      local input = '<script>alert("XSS")</script>'
      local expected = "&lt;script&gt;alert(&quot;XSS&quot;)&lt;/script&gt;"
      assert.equals(expected, ExportUtils.escape_html(input))
    end)
  end)

  describe("escape_json", function()
    it("escapes double quotes", function()
      assert.equals('\\"', ExportUtils.escape_json('"'))
    end)

    it("escapes backslashes", function()
      assert.equals("\\\\", ExportUtils.escape_json("\\"))
    end)

    it("escapes newlines", function()
      assert.equals("\\n", ExportUtils.escape_json("\n"))
    end)

    it("escapes carriage returns", function()
      assert.equals("\\r", ExportUtils.escape_json("\r"))
    end)

    it("escapes tabs", function()
      assert.equals("\\t", ExportUtils.escape_json("\t"))
    end)

    it("handles nil input", function()
      assert.equals("", ExportUtils.escape_json(nil))
    end)

    it("handles complex strings", function()
      local input = 'Line 1\nLine 2\t"quoted"'
      local expected = 'Line 1\\nLine 2\\t\\"quoted\\"'
      assert.equals(expected, ExportUtils.escape_json(input))
    end)
  end)

  describe("get_extension", function()
    it("returns .html for html format", function()
      assert.equals(".html", ExportUtils.get_extension("html"))
    end)

    it("returns .json for ink format", function()
      assert.equals(".json", ExportUtils.get_extension("ink"))
    end)

    it("returns .txt for text format", function()
      assert.equals(".txt", ExportUtils.get_extension("text"))
    end)

    it("returns .export for unknown format", function()
      assert.equals(".export", ExportUtils.get_extension("unknown"))
    end)
  end)

  describe("create_manifest", function()
    it("creates valid manifest", function()
      local story = {
        title = "Test Story",
        passages = {{}, {}, {}},
      }

      local manifest = ExportUtils.create_manifest("html", story, {})

      assert.equals("html", manifest.format)
      assert.equals("Test Story", manifest.story_title)
      assert.equals(3, manifest.passage_count)
      assert.equals("1.0.0", manifest.version)
      assert.is_string(manifest.created_at)
    end)

    it("handles missing title", function()
      local story = { passages = {} }
      local manifest = ExportUtils.create_manifest("html", story, {})
      assert.equals("Untitled", manifest.story_title)
    end)

    it("handles missing passages", function()
      local story = { title = "Test" }
      local manifest = ExportUtils.create_manifest("html", story, {})
      assert.equals(0, manifest.passage_count)
    end)

    it("includes options", function()
      local options = { minify = true, template = "custom" }
      local manifest = ExportUtils.create_manifest("html", {}, options)
      assert.equals(true, manifest.options.minify)
      assert.equals("custom", manifest.options.template)
    end)
  end)

  describe("dirname", function()
    it("extracts directory from path", function()
      assert.equals("/foo/bar/", ExportUtils.dirname("/foo/bar/baz.txt"))
    end)

    it("returns ./ for filename only", function()
      assert.equals("./", ExportUtils.dirname("file.txt"))
    end)
  end)

  describe("basename", function()
    it("extracts filename from path", function()
      assert.equals("baz.txt", ExportUtils.basename("/foo/bar/baz.txt"))
    end)

    it("returns input for filename only", function()
      assert.equals("file.txt", ExportUtils.basename("file.txt"))
    end)
  end)

  describe("stem", function()
    it("removes extension from filename", function()
      assert.equals("file", ExportUtils.stem("file.txt"))
    end)

    it("handles paths", function()
      assert.equals("file", ExportUtils.stem("/foo/bar/file.txt"))
    end)

    it("handles multiple dots", function()
      assert.equals("file.test", ExportUtils.stem("file.test.txt"))
    end)

    it("handles no extension", function()
      assert.equals("file", ExportUtils.stem("file"))
    end)
  end)

  describe("get_mime_type", function()
    it("returns correct type for css", function()
      assert.equals("text/css", ExportUtils.get_mime_type("css"))
    end)

    it("returns correct type for js", function()
      assert.equals("application/javascript", ExportUtils.get_mime_type("js"))
    end)

    it("returns correct type for images", function()
      assert.equals("image/png", ExportUtils.get_mime_type("png"))
      assert.equals("image/jpeg", ExportUtils.get_mime_type("jpg"))
      assert.equals("image/gif", ExportUtils.get_mime_type("gif"))
      assert.equals("image/svg+xml", ExportUtils.get_mime_type("svg"))
    end)

    it("handles extension with dot", function()
      assert.equals("text/css", ExportUtils.get_mime_type(".css"))
    end)

    it("returns octet-stream for unknown", function()
      assert.equals("application/octet-stream", ExportUtils.get_mime_type("xyz"))
    end)
  end)

  describe("base64_encode", function()
    it("encodes simple string", function()
      assert.equals("SGVsbG8=", ExportUtils.base64_encode("Hello"))
    end)

    it("encodes string with padding", function()
      assert.equals("YQ==", ExportUtils.base64_encode("a"))
      assert.equals("YWI=", ExportUtils.base64_encode("ab"))
      assert.equals("YWJj", ExportUtils.base64_encode("abc"))
    end)

    it("encodes empty string", function()
      assert.equals("", ExportUtils.base64_encode(""))
    end)
  end)
end)
