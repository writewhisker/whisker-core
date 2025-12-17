-- spec/formats/ink/roundtrip_spec.lua
-- Round-trip integrity tests for Ink conversion

describe("Compare", function()
  local Compare

  before_each(function()
    for k in pairs(package.loaded) do
      if k:match("^whisker%.formats%.ink%.compare") then
        package.loaded[k] = nil
      end
    end

    Compare = require("whisker.formats.ink.compare")
  end)

  describe("module metadata", function()
    it("should have _whisker metadata", function()
      assert.is_table(Compare._whisker)
      assert.are.equal("StoryCompare", Compare._whisker.name)
    end)

    it("should have capability", function()
      assert.are.equal("formats.ink.compare", Compare._whisker.capability)
    end)
  end)

  describe("new", function()
    it("should create a new instance", function()
      local cmp = Compare.new()
      assert.is_table(cmp)
    end)
  end)

  describe("compare", function()
    local cmp

    before_each(function()
      cmp = Compare.new()
    end)

    it("should return true for identical stories", function()
      local story = {
        start = "start",
        passages = {
          start = { id = "start", content = "Hello" }
        },
        variables = {}
      }

      local match, diffs = cmp:compare(story, story)
      assert.is_true(match)
      assert.are.equal(0, #diffs)
    end)

    it("should detect missing passages", function()
      local original = {
        passages = {
          start = { id = "start" },
          other = { id = "other" }
        }
      }
      local converted = {
        passages = {
          start = { id = "start" }
        }
      }

      local match, diffs = cmp:compare(original, converted)
      assert.is_false(match)
      assert.are.equal(1, #diffs)
      assert.are.equal("missing_passage", diffs[1].type)
    end)

    it("should detect extra passages", function()
      local original = {
        passages = {
          start = { id = "start" }
        }
      }
      local converted = {
        passages = {
          start = { id = "start" },
          extra = { id = "extra" }
        }
      }

      local match, diffs = cmp:compare(original, converted)
      assert.is_false(match)
      assert.are.equal("extra_passage", diffs[1].type)
    end)

    it("should detect content mismatch", function()
      local original = {
        passages = {
          start = { id = "start", content = "Hello" }
        }
      }
      local converted = {
        passages = {
          start = { id = "start", content = "Goodbye" }
        }
      }

      local match, diffs = cmp:compare(original, converted)
      assert.is_false(match)
      assert.are.equal("content_mismatch", diffs[1].type)
    end)

    it("should detect missing variables", function()
      local original = {
        passages = {},
        variables = {
          health = { name = "health", type = "integer", default = 100 }
        }
      }
      local converted = {
        passages = {},
        variables = {}
      }

      local match, diffs = cmp:compare(original, converted)
      assert.is_false(match)
      assert.are.equal("missing_variable", diffs[1].type)
    end)

    it("should detect variable type mismatch", function()
      local original = {
        passages = {},
        variables = {
          val = { name = "val", type = "integer", default = 10 }
        }
      }
      local converted = {
        passages = {},
        variables = {
          val = { name = "val", type = "string", default = "10" }
        }
      }

      local match, diffs = cmp:compare(original, converted)
      assert.is_false(match)
      assert.are.equal("variable_type_mismatch", diffs[1].type)
    end)

    it("should detect start passage mismatch", function()
      local original = { start = "intro", passages = {} }
      local converted = { start = "start", passages = {} }

      local match, diffs = cmp:compare(original, converted)
      assert.is_false(match)
      assert.are.equal("start_mismatch", diffs[1].type)
    end)
  end)

  describe("_normalize_content", function()
    local cmp

    before_each(function()
      cmp = Compare.new()
    end)

    it("should handle nil", function()
      assert.are.equal("", cmp:_normalize_content(nil))
    end)

    it("should normalize whitespace", function()
      assert.are.equal("hello world", cmp:_normalize_content("  hello   world  "))
    end)

    it("should join table content", function()
      assert.are.equal("line1\nline2", cmp:_normalize_content({ "line1", "line2" }))
    end)
  end)

  describe("get_differences_by_type", function()
    local cmp

    before_each(function()
      cmp = Compare.new()
    end)

    it("should filter differences by type", function()
      cmp:compare(
        { passages = { a = { id = "a" }, b = { id = "b" } } },
        { passages = {} }
      )

      local missing = cmp:get_differences_by_type("missing_passage")
      assert.are.equal(2, #missing)
    end)
  end)

  describe("generate_report", function()
    local cmp

    before_each(function()
      cmp = Compare.new()
    end)

    it("should generate report for equivalent stories", function()
      cmp:compare({ passages = {} }, { passages = {} })
      local report = cmp:generate_report()

      assert.truthy(report:match("equivalent"))
    end)

    it("should generate report with differences", function()
      cmp:compare(
        { passages = { a = { id = "a" } } },
        { passages = {} }
      )
      local report = cmp:generate_report()

      assert.truthy(report:match("1 difference"))
      assert.truthy(report:match("missing_passage"))
    end)
  end)
end)

describe("Round-trip conversion", function()
  local Converter, Exporter, Compare

  before_each(function()
    for k in pairs(package.loaded) do
      if k:match("^whisker%.formats%.ink") then
        package.loaded[k] = nil
      end
    end

    Converter = require("whisker.formats.ink.converter")
    Exporter = require("whisker.formats.ink.exporter")
    Compare = require("whisker.formats.ink.compare")
  end)

  describe("simple stories", function()
    it("should preserve minimal story structure", function()
      -- Create a minimal whisker story
      local original = {
        start = "start",
        passages = {
          start = { id = "start", content = "Hello, World!" }
        },
        variables = {}
      }

      -- Export to Ink JSON
      local exporter = Exporter.new()
      local ink_json = exporter:export(original)

      -- Verify export produced valid structure
      assert.is_table(ink_json)
      assert.are.equal(20, ink_json.inkVersion)
      assert.is_table(ink_json.root)
    end)

    it("should preserve multiple passages", function()
      local original = {
        start = "intro",
        passages = {
          intro = { id = "intro", content = "Welcome" },
          middle = { id = "middle", content = "The journey continues" },
          ending = { id = "ending", content = "The end" }
        },
        variables = {}
      }

      local exporter = Exporter.new()
      local ink_json = exporter:export(original)

      -- Check all passages exist as named containers
      assert.is_table(ink_json.root.intro)
      assert.is_table(ink_json.root.middle)
      assert.is_table(ink_json.root.ending)
    end)

    it("should preserve passage hierarchy", function()
      local original = {
        start = "chapter",
        passages = {
          chapter = { id = "chapter", content = "Chapter 1" },
          ["chapter.intro"] = { id = "chapter.intro", content = "Introduction" },
          ["chapter.body"] = { id = "chapter.body", content = "Main content" }
        },
        variables = {}
      }

      local exporter = Exporter.new()
      local ink_json = exporter:export(original)

      -- Knot should exist
      assert.is_table(ink_json.root.chapter)

      -- Stitches should be nested
      assert.is_table(ink_json.root.chapter.intro)
      assert.is_table(ink_json.root.chapter.body)
    end)
  end)

  describe("variables", function()
    it("should preserve variable declarations", function()
      local original = {
        start = "start",
        passages = {
          start = { id = "start", content = "Test" }
        },
        variables = {
          health = { name = "health", type = "integer", default = 100 },
          name = { name = "name", type = "string", default = "Hero" },
          has_key = { name = "has_key", type = "boolean", default = false }
        }
      }

      local exporter = Exporter.new()
      local ink_json = exporter:export(original)

      -- Story should export without error
      assert.is_table(ink_json)
      assert.are.equal(20, ink_json.inkVersion)
    end)

    it("should preserve list variables", function()
      local original = {
        start = "start",
        passages = { start = { id = "start" } },
        variables = {
          colors = {
            name = "colors",
            type = "list",
            items = { "red", "green", "blue" }
          }
        }
      }

      local exporter = Exporter.new()
      local ink_json = exporter:export(original)

      assert.is_table(ink_json.listDefs)
      assert.is_table(ink_json.listDefs.colors)
    end)
  end)

  describe("fidelity metrics", function()
    it("should track conversion statistics", function()
      local original = {
        start = "start",
        passages = {
          start = { id = "start", content = "Test" },
          other = { id = "other", content = "Other" }
        },
        variables = {
          x = { name = "x", type = "integer", default = 0 }
        }
      }

      local exporter = Exporter.new()
      local valid, errors = exporter:validate(original)

      assert.is_true(valid)
      assert.is_nil(errors)
    end)
  end)
end)

describe("Conversion fidelity", function()
  local Exporter

  before_each(function()
    for k in pairs(package.loaded) do
      if k:match("^whisker%.formats%.ink") then
        package.loaded[k] = nil
      end
    end

    Exporter = require("whisker.formats.ink.exporter")
  end)

  it("should preserve text content exactly", function()
    local story = {
      start = "start",
      passages = {
        start = { id = "start", content = "This is exact text!" }
      }
    }

    local exporter = Exporter.new()
    local ink_json = exporter:export(story)

    -- Find the text in the exported container
    local container = ink_json.root.start
    assert.is_table(container)

    -- First element should be the text with ^ prefix
    assert.are.equal("^This is exact text!", container[1])
  end)

  it("should export valid ink version", function()
    local story = {
      passages = { start = { id = "start" } }
    }

    local exporter = Exporter.new()
    local ink_json = exporter:export(story)

    assert.are.equal(20, ink_json.inkVersion)
  end)

  it("should include root done marker", function()
    local story = {
      passages = { start = { id = "start" } }
    }

    local exporter = Exporter.new()
    local ink_json = exporter:export(story)

    local has_done = false
    for _, item in ipairs(ink_json.root) do
      if item == "done" then
        has_done = true
        break
      end
    end
    assert.is_true(has_done)
  end)
end)
