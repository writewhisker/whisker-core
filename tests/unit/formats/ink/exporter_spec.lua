--- Ink Exporter Tests
-- Tests for InkExporter Whisker→Ink conversion
-- @module tests.unit.formats.ink.exporter_spec

describe("InkExporter", function()
  local InkExporter
  local json

  before_each(function()
    package.loaded["whisker.formats.ink.exporter"] = nil
    InkExporter = require("whisker.formats.ink.exporter")

    -- Try to load cjson for validation
    local ok, cjson = pcall(require, "cjson")
    if ok then
      json = cjson
    else
      -- Fallback to dkjson
      ok, json = pcall(require, "dkjson")
    end
  end)

  describe("can_export", function()
    it("returns false for nil story", function()
      local can, reason = InkExporter.can_export(nil)

      assert.is_false(can)
      assert.is_string(reason)
    end)

    it("returns false for story with no passages", function()
      local story = {
        passages = {},
      }

      local can, reason = InkExporter.can_export(story)

      assert.is_false(can)
      assert.truthy(reason:match("no passages"))
    end)

    it("returns true for valid story", function()
      local story = {
        passages = {
          { id = "start", content = "Hello" },
        },
      }

      local can, reason = InkExporter.can_export(story)

      assert.is_true(can)
      assert.is_nil(reason)
    end)

    it("returns false for whisker-only features", function()
      local story = {
        passages = {
          {
            id = "start",
            content = "Hello",
            metadata = { whisker_only = true },
          },
        },
      }

      local can, reason = InkExporter.can_export(story)

      assert.is_false(can)
      assert.truthy(reason:match("Whisker%-only"))
    end)
  end)

  describe("export", function()
    it("exports simple story to JSON", function()
      local story = {
        passages = {
          { id = "start", content = "Hello, world!" },
        },
        start = "start",
      }

      local result, err = InkExporter.export(story)

      assert.is_string(result)
      assert.is_nil(err)
    end)

    it("produces valid JSON", function()
      if not json then
        pending("JSON library not available")
        return
      end

      local story = {
        passages = {
          { id = "start", content = "Test" },
        },
        start = "start",
      }

      local result = InkExporter.export(story)

      local ok, parsed = pcall(json.decode, result)
      assert.is_true(ok)
      assert.is_table(parsed)
    end)

    it("includes inkVersion", function()
      if not json then
        pending("JSON library not available")
        return
      end

      local story = {
        passages = {
          { id = "start", content = "Test" },
        },
        start = "start",
      }

      local result = InkExporter.export(story)
      local parsed = json.decode(result)

      assert.equals(21, parsed.inkVersion)
    end)

    it("includes root array", function()
      if not json then
        pending("JSON library not available")
        return
      end

      local story = {
        passages = {
          { id = "start", content = "Test" },
        },
        start = "start",
      }

      local result = InkExporter.export(story)
      local parsed = json.decode(result)

      assert.is_table(parsed.root)
    end)

    it("exports passage content", function()
      if not json then
        pending("JSON library not available")
        return
      end

      local story = {
        passages = {
          { id = "start", content = "Hello, world!" },
        },
        start = "start",
      }

      local result = InkExporter.export(story)

      assert.truthy(result:match("Hello"))
    end)

    it("exports multiple passages", function()
      if not json then
        pending("JSON library not available")
        return
      end

      local story = {
        passages = {
          { id = "start", content = "Start" },
          { id = "middle", content = "Middle" },
          { id = "end", content = "End" },
        },
        start = "start",
      }

      local result = InkExporter.export(story)
      local parsed = json.decode(result)

      assert.is_table(parsed.root)
    end)

    it("fails for unexportable story", function()
      local story = {
        passages = {
          {
            id = "start",
            content = "Test",
            metadata = { whisker_only = true },
          },
        },
      }

      local result, err = InkExporter.export(story)

      assert.is_nil(result)
      assert.is_string(err)
    end)
  end)

  describe("create_empty", function()
    it("returns valid Ink structure", function()
      local ink = InkExporter.create_empty()

      assert.is_table(ink)
      assert.equals(21, ink.inkVersion)
      assert.is_table(ink.root)
      assert.is_table(ink.listDefs)
    end)
  end)

  describe("validate_structure", function()
    it("returns true for valid structure", function()
      local ink = {
        inkVersion = 21,
        root = { "done" },
        listDefs = {},
      }

      local valid, err = InkExporter.validate_structure(ink)

      assert.is_true(valid)
      assert.is_nil(err)
    end)

    it("returns false for missing inkVersion", function()
      local ink = {
        root = { "done" },
      }

      local valid, err = InkExporter.validate_structure(ink)

      assert.is_false(valid)
      assert.truthy(err:match("inkVersion"))
    end)

    it("returns false for missing root", function()
      local ink = {
        inkVersion = 21,
      }

      local valid, err = InkExporter.validate_structure(ink)

      assert.is_false(valid)
      assert.truthy(err:match("root"))
    end)

    it("returns false for non-table input", function()
      local valid, err = InkExporter.validate_structure("string")

      assert.is_false(valid)
    end)
  end)
end)
