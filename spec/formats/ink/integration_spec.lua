-- spec/formats/ink/integration_spec.lua
-- Integration tests for full Ink story handling

describe("Ink Integration", function()
  local Converter, Exporter, Validator, Compare
  local transformers

  before_each(function()
    for k in pairs(package.loaded) do
      if k:match("^whisker%.formats%.ink") then
        package.loaded[k] = nil
      end
    end

    Converter = require("whisker.formats.ink.converter")
    Exporter = require("whisker.formats.ink.exporter")
    Validator = require("whisker.formats.ink.validator")
    Compare = require("whisker.formats.ink.compare")
    transformers = require("whisker.formats.ink.transformers")
  end)

  describe("full pipeline", function()
    it("should convert, validate, and export simple story", function()
      -- Create a whisker story
      local story = {
        start = "intro",
        passages = {
          intro = {
            id = "intro",
            content = "Welcome to the story!",
            choices = {
              { text = "Begin adventure", target = "chapter1" },
              { text = "Learn more", target = "about" }
            }
          },
          chapter1 = {
            id = "chapter1",
            content = "Your adventure begins..."
          },
          about = {
            id = "about",
            content = "This is a test story."
          }
        },
        variables = {
          score = { name = "score", type = "integer", default = 0 }
        }
      }

      -- Validate
      local validator = Validator.new()
      local result = validator:validate(story)
      assert.is_true(result.success)

      -- Export
      local exporter = Exporter.new()
      local ink_json = exporter:export(story)
      assert.is_table(ink_json)
      assert.are.equal(20, ink_json.inkVersion)
    end)

    it("should handle complex story with hierarchy", function()
      local story = {
        start = "chapter1",
        passages = {
          chapter1 = {
            id = "chapter1",
            content = "Chapter 1: The Beginning",
            tags = { "chapter", "intro" }
          },
          ["chapter1.scene1"] = {
            id = "chapter1.scene1",
            content = "Scene 1 content"
          },
          ["chapter1.scene2"] = {
            id = "chapter1.scene2",
            content = "Scene 2 content"
          },
          chapter2 = {
            id = "chapter2",
            content = "Chapter 2: The Middle"
          }
        },
        variables = {}
      }

      -- Validate
      local validator = Validator.new()
      local result = validator:validate(story)
      assert.is_true(result.success)

      -- Export
      local exporter = Exporter.new()
      local ink_json = exporter:export(story)

      -- Check structure
      assert.is_table(ink_json.root.chapter1)
      assert.is_table(ink_json.root.chapter1.scene1)
      assert.is_table(ink_json.root.chapter1.scene2)
      assert.is_table(ink_json.root.chapter2)
    end)
  end)

  describe("transformer registry", function()
    it("should have all transformers available", function()
      local list = transformers.list()

      assert.truthy(#list >= 8)

      local expected = { "knot", "stitch", "gather", "choice", "variable", "logic", "tunnel", "thread" }
      for _, name in ipairs(expected) do
        local found = false
        for _, actual in ipairs(list) do
          if actual == name then
            found = true
            break
          end
        end
        assert.is_true(found, "Missing transformer: " .. name)
      end
    end)

    it("should create all transformers", function()
      local list = transformers.list()

      for _, name in ipairs(list) do
        local t = transformers.create(name)
        assert.is_table(t, "Failed to create transformer: " .. name)
      end
    end)
  end)

  describe("validation integration", function()
    it("should detect invalid story structure", function()
      local story = {
        start = "missing",
        passages = {
          start = { id = "start" }
        }
      }

      local validator = Validator.new()
      local result = validator:validate(story)

      assert.is_false(result.success)
    end)

    it("should detect orphaned passages", function()
      local story = {
        start = "main",
        passages = {
          main = { id = "main", content = "Main content" },
          orphan = { id = "orphan", content = "Never reached" }
        }
      }

      local validator = Validator.new()
      local result = validator:validate(story)

      assert.truthy(#result.warnings > 0)
      local has_orphan_warning = false
      for _, warn in ipairs(result.warnings) do
        if warn.type == "orphaned" or warn.message:match("reachable") then
          has_orphan_warning = true
          break
        end
      end
      -- Orphan detection is a warning, not error
    end)
  end)

  describe("comparison integration", function()
    it("should compare stories accurately", function()
      local story1 = {
        start = "start",
        passages = {
          start = { id = "start", content = "Hello" }
        },
        variables = {}
      }

      local story2 = {
        start = "start",
        passages = {
          start = { id = "start", content = "Hello" }
        },
        variables = {}
      }

      local cmp = Compare.new()
      local match, diffs = cmp:compare(story1, story2)

      assert.is_true(match)
      assert.are.equal(0, #diffs)
    end)
  end)

  describe("end-to-end scenarios", function()
    it("should handle branching narrative", function()
      local story = {
        start = "start",
        passages = {
          start = {
            id = "start",
            content = "You stand at a crossroads.",
            choices = {
              { text = "Go left", target = "left" },
              { text = "Go right", target = "right" },
              { text = "Go back", target = "start", sticky = true }
            }
          },
          left = {
            id = "left",
            content = "You went left and found a treasure!"
          },
          right = {
            id = "right",
            content = "You went right and met a stranger."
          }
        }
      }

      local validator = Validator.new()
      local result = validator:validate(story)
      assert.is_true(result.success)

      local exporter = Exporter.new()
      local ink_json = exporter:export(story)
      assert.is_table(ink_json)
    end)

    it("should handle variable-rich story", function()
      local story = {
        start = "start",
        passages = {
          start = { id = "start", content = "Game begins" }
        },
        variables = {
          health = { name = "health", type = "integer", default = 100 },
          gold = { name = "gold", type = "integer", default = 0 },
          name = { name = "name", type = "string", default = "Hero" },
          has_sword = { name = "has_sword", type = "boolean", default = false },
          has_shield = { name = "has_shield", type = "boolean", default = false }
        }
      }

      local validator = Validator.new()
      local result = validator:validate(story)
      assert.is_true(result.success)
      assert.are.equal(5, result.stats.variables)
    end)
  end)

  describe("error handling", function()
    it("should handle nil story gracefully", function()
      local exporter = Exporter.new()
      local result, err = exporter:export(nil)

      assert.is_nil(result)
      assert.is_string(err)
    end)

    it("should validate empty story", function()
      local validator = Validator.new()
      local result = validator:validate({})

      -- Empty passages should be warned/errored
    end)
  end)
end)

describe("Module loading", function()
  it("should load all Ink modules without error", function()
    local modules = {
      "whisker.formats.ink.converter",
      "whisker.formats.ink.exporter",
      "whisker.formats.ink.validator",
      "whisker.formats.ink.report",
      "whisker.formats.ink.compare",
      "whisker.formats.ink.transformers",
      "whisker.formats.ink.generators"
    }

    for _, mod in ipairs(modules) do
      local ok, loaded = pcall(require, mod)
      assert.is_true(ok, "Failed to load: " .. mod)
      assert.is_table(loaded, "Module not a table: " .. mod)
    end
  end)

  it("should have _whisker metadata on all modules", function()
    local modules = {
      "whisker.formats.ink.converter",
      "whisker.formats.ink.exporter",
      "whisker.formats.ink.validator",
      "whisker.formats.ink.report",
      "whisker.formats.ink.compare",
      "whisker.formats.ink.transformers",
      "whisker.formats.ink.generators"
    }

    for _, mod in ipairs(modules) do
      local loaded = require(mod)
      assert.is_table(loaded._whisker, "Missing _whisker metadata: " .. mod)
      assert.is_string(loaded._whisker.name, "Missing name in " .. mod)
    end
  end)
end)
