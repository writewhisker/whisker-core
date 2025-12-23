--- Ink Exporter Tests
-- @module tests.unit.export.ink.ink_exporter_spec

describe("InkExporter", function()
  local InkExporter
  local exporter

  before_each(function()
    package.loaded["whisker.export.ink.ink_exporter"] = nil
    package.loaded["whisker.export.ink.mapper"] = nil
    package.loaded["whisker.export.ink.schema"] = nil
    package.loaded["whisker.export.utils"] = nil
    InkExporter = require("whisker.export.ink.ink_exporter")
    exporter = InkExporter.new()
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
    end)

    it("rejects story with Lua code", function()
      local story = {
        passages = {{
          name = "start",
          text = "Hello",
          lua_code = "print('test')"
        }}
      }
      local can, err = exporter:can_export(story)
      assert.is_false(can)
      assert.truthy(err:match("Lua code"))
    end)
  end)

  describe("export", function()
    it("generates valid JSON structure", function()
      local story = {
        title = "Test Story",
        passages = {
          { name = "start", text = "Beginning", choices = {} }
        }
      }

      local bundle = exporter:export(story, {})

      assert.is_string(bundle.content)
      assert.truthy(bundle.content:match("inkVersion"))
      assert.truthy(bundle.content:match("root"))
    end)

    it("includes story passages", function()
      local story = {
        passages = {
          { name = "start", text = "Hello World" },
          { name = "ending", text = "The End" }
        }
      }

      local bundle = exporter:export(story, {})

      assert.truthy(bundle.content:match("start"))
      assert.truthy(bundle.content:match("ending"))
    end)

    it("creates manifest in bundle", function()
      local story = {
        title = "Test",
        passages = {{ name = "start", text = "Hello" }}
      }

      local bundle = exporter:export(story, {})

      assert.is_table(bundle.manifest)
      assert.equals("ink", bundle.manifest.format)
    end)

    it("supports pretty option", function()
      local story = {
        passages = {{ name = "start", text = "Hello" }}
      }

      local compact_bundle = exporter:export(story, { pretty = false })
      local pretty_bundle = exporter:export(story, { pretty = true })

      -- Pretty version should be longer due to whitespace
      assert.is_true(#pretty_bundle.content > #compact_bundle.content)
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

    it("fails bundle with empty content", function()
      local bundle = { content = "" }
      local result = exporter:validate(bundle)

      assert.is_false(result.valid)
    end)

    it("fails bundle with invalid JSON", function()
      local bundle = { content = "not json" }
      local result = exporter:validate(bundle)

      assert.is_false(result.valid)
    end)
  end)

  describe("metadata", function()
    it("returns correct format", function()
      local meta = exporter:metadata()
      assert.equals("ink", meta.format)
    end)

    it("returns correct file extension", function()
      local meta = exporter:metadata()
      assert.equals(".json", meta.file_extension)
    end)
  end)
end)

describe("InkMapper", function()
  local InkMapper

  before_each(function()
    package.loaded["whisker.export.ink.mapper"] = nil
    InkMapper = require("whisker.export.ink.mapper")
  end)

  describe("map_story", function()
    it("creates ink structure", function()
      local story = {
        passages = {{ name = "start", text = "Hello" }}
      }

      local ink = InkMapper.map_story(story)

      assert.equals(20, ink.inkVersion)
      assert.is_table(ink.root)
      assert.is_table(ink.start)
    end)

    it("uses custom start passage", function()
      local story = {
        start_passage = "intro",
        passages = {
          { name = "intro", text = "Welcome" },
          { name = "start", text = "Default start" }
        }
      }

      local ink = InkMapper.map_story(story)

      -- Root should divert to intro
      assert.truthy(ink.root[1][2] == "intro")
    end)
  end)

  describe("sanitize_name", function()
    it("replaces spaces with underscores", function()
      assert.equals("my_passage", InkMapper.sanitize_name("my passage"))
    end)

    it("handles special characters", function()
      assert.equals("passage_1_", InkMapper.sanitize_name("passage-1!"))
    end)

    it("prefixes names starting with numbers", function()
      assert.equals("_123", InkMapper.sanitize_name("123"))
    end)

    it("lowercases names", function()
      assert.equals("mypassage", InkMapper.sanitize_name("MyPassage"))
    end)

    it("handles nil", function()
      assert.equals("unnamed", InkMapper.sanitize_name(nil))
    end)
  end)

  describe("check_compatibility", function()
    it("returns compatible for simple story", function()
      local story = {
        passages = {{ name = "start", text = "Hello" }}
      }

      local result = InkMapper.check_compatibility(story)

      assert.is_true(result.compatible)
      assert.equals(0, #result.issues)
    end)

    it("returns issues for Lua code", function()
      local story = {
        passages = {{
          name = "start",
          lua_code = "x = 1"
        }}
      }

      local result = InkMapper.check_compatibility(story)

      assert.is_false(result.compatible)
      assert.is_true(#result.issues > 0)
    end)

    it("warns about whisker-specific tags", function()
      local story = {
        passages = {{
          name = "start",
          text = "Hello",
          tags = { "whisker-only", "normal" }
        }}
      }

      local result = InkMapper.check_compatibility(story)

      -- Should be compatible but have warning
      assert.is_true(result.compatible)
      assert.is_true(#result.issues > 0)
    end)
  end)
end)

describe("InkSchema", function()
  local InkSchema

  before_each(function()
    package.loaded["whisker.export.ink.schema"] = nil
    InkSchema = require("whisker.export.ink.schema")
  end)

  describe("validate", function()
    it("passes valid ink structure", function()
      local ink = {
        inkVersion = 20,
        root = { "done" },
      }

      local errors = InkSchema.validate(ink)

      local error_count = 0
      for _, err in ipairs(errors) do
        if err.severity == "error" then
          error_count = error_count + 1
        end
      end
      assert.equals(0, error_count)
    end)

    it("fails missing inkVersion", function()
      local ink = {
        root = {}
      }

      local errors = InkSchema.validate(ink)

      assert.is_true(#errors > 0)
    end)

    it("fails missing root", function()
      local ink = {
        inkVersion = 20
      }

      local errors = InkSchema.validate(ink)

      assert.is_true(#errors > 0)
    end)

    it("warns about old inkVersion", function()
      local ink = {
        inkVersion = 18,
        root = {}
      }

      local errors = InkSchema.validate(ink)

      local has_warning = false
      for _, err in ipairs(errors) do
        if err.severity == "warning" then
          has_warning = true
        end
      end
      assert.is_true(has_warning)
    end)
  end)

  describe("is_valid", function()
    it("returns true for valid structure", function()
      local ink = {
        inkVersion = 20,
        root = {}
      }
      assert.is_true(InkSchema.is_valid(ink))
    end)

    it("returns false for invalid structure", function()
      local ink = {}
      assert.is_false(InkSchema.is_valid(ink))
    end)
  end)
end)
