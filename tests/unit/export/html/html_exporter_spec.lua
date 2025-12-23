--- HTML Exporter Tests
-- @module tests.unit.export.html.html_exporter_spec

describe("HTMLExporter", function()
  local HTMLExporter
  local exporter

  before_each(function()
    package.loaded["whisker.export.html.html_exporter"] = nil
    package.loaded["whisker.export.html.runtime"] = nil
    package.loaded["whisker.export.utils"] = nil
    HTMLExporter = require("whisker.export.html.html_exporter")
    exporter = HTMLExporter.new()
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
      assert.equals("Story has no passages", err)
    end)

    it("rejects story with nil passages", function()
      local story = {}
      local can, err = exporter:can_export(story)
      assert.is_false(can)
    end)
  end)

  describe("export", function()
    it("generates valid HTML structure", function()
      local story = {
        title = "Test Story",
        passages = {
          { name = "start", text = "Beginning", choices = {} }
        }
      }

      local bundle = exporter:export(story, {})

      assert.is_string(bundle.content)
      assert.truthy(bundle.content:match("<!DOCTYPE html>"))
      assert.truthy(bundle.content:match("<html"))
      assert.truthy(bundle.content:match("<head"))
      assert.truthy(bundle.content:match("<body"))
    end)

    it("includes story title in HTML", function()
      local story = {
        title = "My Amazing Story",
        passages = {
          { name = "start", text = "Hello", choices = {} }
        }
      }

      local bundle = exporter:export(story, {})

      assert.truthy(bundle.content:match("<title>My Amazing Story</title>"))
      assert.truthy(bundle.content:match("<h1>My Amazing Story</h1>"))
    end)

    it("includes author when provided", function()
      local story = {
        title = "Test",
        author = "Jane Doe",
        passages = {
          { name = "start", text = "Hello", choices = {} }
        }
      }

      local bundle = exporter:export(story, {})

      assert.truthy(bundle.content:match("by Jane Doe"))
    end)

    it("embeds story data as JSON", function()
      local story = {
        title = "Test",
        passages = {
          { name = "start", text = "Hello World", choices = {} }
        }
      }

      local bundle = exporter:export(story, {})

      assert.truthy(bundle.content:match("WHISKER_STORY_DATA"))
      assert.truthy(bundle.content:match('"title":"Test"'))
      assert.truthy(bundle.content:match('"name":"start"'))
    end)

    it("embeds JavaScript runtime", function()
      local story = {
        passages = {
          { name = "start", text = "Test", choices = {} }
        }
      }

      local bundle = exporter:export(story, {})

      assert.truthy(bundle.content:match("<script>"))
      assert.truthy(bundle.content:match("whiskerRuntime"))
      assert.truthy(bundle.content:match("showPassage"))
    end)

    it("escapes HTML in story title for display", function()
      local story = {
        title = "<script>alert('xss')</script>",
        passages = {
          { name = "start", text = "Safe", choices = {} }
        }
      }

      local bundle = exporter:export(story, {})

      -- Title tag and h1 should have escaped HTML
      assert.truthy(bundle.content:match("<title>&lt;script&gt;"))
      assert.truthy(bundle.content:match("<h1>&lt;script&gt;"))
    end)

    it("serializes passages with choices", function()
      local story = {
        passages = {
          {
            name = "start",
            text = "You are at a crossroads.",
            choices = {
              { text = "Go left", target = "left" },
              { text = "Go right", target = "right" },
            }
          },
          { name = "left", text = "You went left.", choices = {} },
          { name = "right", text = "You went right.", choices = {} },
        }
      }

      local bundle = exporter:export(story, {})

      assert.truthy(bundle.content:match('"text":"Go left"'))
      assert.truthy(bundle.content:match('"target":"left"'))
      assert.truthy(bundle.content:match('"text":"Go right"'))
      assert.truthy(bundle.content:match('"target":"right"'))
    end)

    it("creates manifest in bundle", function()
      local story = {
        title = "Test",
        passages = {{ name = "start", text = "Hello", choices = {} }}
      }

      local bundle = exporter:export(story, {})

      assert.is_table(bundle.manifest)
      assert.equals("html", bundle.manifest.format)
      assert.equals("Test", bundle.manifest.story_title)
      assert.equals(1, bundle.manifest.passage_count)
    end)

    it("creates empty assets array", function()
      local story = {
        passages = {{ name = "start", text = "Hello", choices = {} }}
      }

      local bundle = exporter:export(story, {})

      assert.is_table(bundle.assets)
      assert.equals(0, #bundle.assets)
    end)

    it("supports minify option", function()
      local story = {
        passages = {{ name = "start", text = "Hello", choices = {} }}
      }

      local normal_bundle = exporter:export(story, { minify = false })
      local minified_bundle = exporter:export(story, { minify = true })

      -- Minified should be shorter
      assert.is_true(#minified_bundle.content < #normal_bundle.content)
    end)

    it("uses minimal runtime when specified", function()
      local story = {
        passages = {{ name = "start", text = "Hello", choices = {} }}
      }

      local normal_bundle = exporter:export(story, { minimal = false })
      local minimal_bundle = exporter:export(story, { minimal = true })

      -- Minimal should be shorter
      assert.is_true(#minimal_bundle.content < #normal_bundle.content)
    end)
  end)

  describe("validate", function()
    it("passes valid bundle", function()
      local story = {
        passages = {{ name = "start", text = "Hello", choices = {} }}
      }

      local bundle = exporter:export(story, {})
      local result = exporter:validate(bundle)

      assert.is_true(result.valid)
      assert.equals(0, #result.errors)
    end)

    it("fails bundle with empty content", function()
      local bundle = { content = "" }
      local result = exporter:validate(bundle)

      assert.is_false(result.valid)
      assert.is_true(#result.errors > 0)
    end)

    it("fails bundle without HTML tag", function()
      local bundle = { content = "<div>Not HTML</div>" }
      local result = exporter:validate(bundle)

      assert.is_false(result.valid)
    end)

    it("fails bundle without script", function()
      local bundle = { content = "<!DOCTYPE html><html><head></head><body></body></html>" }
      local result = exporter:validate(bundle)

      assert.is_false(result.valid)
    end)

    it("fails bundle without story data", function()
      local bundle = { content = "<!DOCTYPE html><html><head></head><body><script></script></body></html>" }
      local result = exporter:validate(bundle)

      assert.is_false(result.valid)
    end)

    it("warns about missing DOCTYPE", function()
      local bundle = {
        content = '<html><head></head><body><script>var WHISKER_STORY_DATA = {};</script></body></html>'
      }
      local result = exporter:validate(bundle)

      -- Should have a warning about DOCTYPE
      assert.is_true(#result.warnings > 0)
    end)
  end)

  describe("metadata", function()
    it("returns correct format", function()
      local meta = exporter:metadata()
      assert.equals("html", meta.format)
    end)

    it("returns correct file extension", function()
      local meta = exporter:metadata()
      assert.equals(".html", meta.file_extension)
    end)

    it("includes version", function()
      local meta = exporter:metadata()
      assert.is_string(meta.version)
    end)

    it("includes description", function()
      local meta = exporter:metadata()
      assert.is_string(meta.description)
    end)
  end)

  describe("to_json", function()
    it("serializes strings", function()
      local json = exporter:to_json("hello")
      assert.equals('"hello"', json)
    end)

    it("serializes numbers", function()
      assert.equals("42", exporter:to_json(42))
      assert.equals("3.14", exporter:to_json(3.14))
    end)

    it("serializes booleans", function()
      assert.equals("true", exporter:to_json(true))
      assert.equals("false", exporter:to_json(false))
    end)

    it("serializes nil", function()
      assert.equals("null", exporter:to_json(nil))
    end)

    it("serializes arrays", function()
      local json = exporter:to_json({1, 2, 3})
      assert.equals("[1,2,3]", json)
    end)

    it("serializes objects", function()
      local json = exporter:to_json({a = 1, b = 2})
      -- Keys should be sorted
      assert.truthy(json:match('"a":1'))
      assert.truthy(json:match('"b":2'))
    end)

    it("serializes nested structures", function()
      local json = exporter:to_json({
        name = "test",
        items = {1, 2, 3},
      })
      assert.truthy(json:match('"name":"test"'))
      assert.truthy(json:match('"items":%[1,2,3%]'))
    end)

    it("escapes special characters in strings", function()
      local json = exporter:to_json('Line 1\nLine 2\t"quoted"')
      assert.truthy(json:match("\\n"))
      assert.truthy(json:match("\\t"))
      assert.truthy(json:match('\\"'))
    end)
  end)
end)
