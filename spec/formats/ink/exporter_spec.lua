-- spec/formats/ink/exporter_spec.lua
-- Tests for Whisker to Ink export

describe("Exporter", function()
  local Exporter

  before_each(function()
    -- Clear cached modules
    for k in pairs(package.loaded) do
      if k:match("^whisker%.formats%.ink%.exporter") or
         k:match("^whisker%.formats%.ink%.generators") then
        package.loaded[k] = nil
      end
    end

    Exporter = require("whisker.formats.ink.exporter")
  end)

  describe("module metadata", function()
    it("should have _whisker metadata", function()
      assert.is_table(Exporter._whisker)
      assert.are.equal("InkExporter", Exporter._whisker.name)
    end)

    it("should have capability", function()
      assert.are.equal("formats.ink.exporter", Exporter._whisker.capability)
    end)
  end)

  describe("new", function()
    it("should create a new instance", function()
      local exporter = Exporter.new()
      assert.is_table(exporter)
    end)

    it("should use default ink version", function()
      local exporter = Exporter.new()
      assert.are.equal(20, exporter.ink_version)
    end)

    it("should accept custom ink version", function()
      local exporter = Exporter.new({ ink_version = 21 })
      assert.are.equal(21, exporter.ink_version)
    end)
  end)

  describe("export", function()
    local exporter

    before_each(function()
      exporter = Exporter.new()
    end)

    it("should return nil for nil story", function()
      local result, err = exporter:export(nil)
      assert.is_nil(result)
      assert.is_string(err)
    end)

    it("should export minimal story", function()
      local story = {
        start = "start",
        passages = {
          start = { id = "start", content = "Hello World" }
        }
      }

      local result = exporter:export(story)

      assert.is_table(result)
      assert.are.equal(20, result.inkVersion)
      assert.is_table(result.root)
    end)

    it("should include inkVersion", function()
      local story = {
        passages = {
          start = { id = "start" }
        }
      }

      local result = exporter:export(story)
      assert.are.equal(20, result.inkVersion)
    end)

    it("should create root container", function()
      local story = {
        start = "start",
        passages = {
          start = { id = "start", content = "Test" }
        }
      }

      local result = exporter:export(story)
      assert.is_table(result.root)
    end)

    it("should add divert to start passage", function()
      local story = {
        start = "intro",
        passages = {
          intro = { id = "intro", content = "Welcome" }
        }
      }

      local result = exporter:export(story)

      -- First element should be divert to intro
      assert.is_table(result.root[1])
      assert.are.equal("intro", result.root[1]["->"])
    end)

    it("should include done marker", function()
      local story = {
        passages = {
          start = { id = "start" }
        }
      }

      local result = exporter:export(story)

      -- Should have "done" somewhere in root
      local has_done = false
      for _, item in ipairs(result.root) do
        if item == "done" then
          has_done = true
          break
        end
      end
      assert.is_true(has_done)
    end)

    it("should export multiple passages as named containers", function()
      local story = {
        start = "first",
        passages = {
          first = { id = "first", content = "First" },
          second = { id = "second", content = "Second" }
        }
      }

      local result = exporter:export(story)

      assert.is_table(result.root.first)
      assert.is_table(result.root.second)
    end)
  end)

  describe("stitch handling", function()
    local exporter

    before_each(function()
      exporter = Exporter.new()
    end)

    it("should nest stitches under parent knot", function()
      local story = {
        start = "chapter",
        passages = {
          chapter = { id = "chapter", content = "Chapter" },
          ["chapter.intro"] = { id = "chapter.intro", content = "Intro" }
        }
      }

      local result = exporter:export(story)

      -- chapter should exist as named container
      assert.is_table(result.root.chapter)

      -- intro should be nested under chapter
      assert.is_table(result.root.chapter.intro)
    end)

    it("should not create top-level entry for stitches", function()
      local story = {
        start = "knot",
        passages = {
          knot = { id = "knot" },
          ["knot.stitch"] = { id = "knot.stitch" }
        }
      }

      local result = exporter:export(story)

      -- Should not have "knot.stitch" at root level
      assert.is_nil(result.root["knot.stitch"])
    end)
  end)

  describe("list definitions", function()
    local exporter

    before_each(function()
      exporter = Exporter.new()
    end)

    it("should not include listDefs when no lists", function()
      local story = {
        passages = { start = { id = "start" } },
        variables = {
          count = { name = "count", type = "integer", default = 0 }
        }
      }

      local result = exporter:export(story)
      assert.is_nil(result.listDefs)
    end)

    it("should include listDefs for list variables", function()
      local story = {
        passages = { start = { id = "start" } },
        variables = {
          colors = {
            name = "colors",
            type = "list",
            items = { "red", "green", "blue" }
          }
        }
      }

      local result = exporter:export(story)

      assert.is_table(result.listDefs)
      assert.is_table(result.listDefs.colors)
      assert.are.equal(1, result.listDefs.colors.red)
      assert.are.equal(2, result.listDefs.colors.green)
      assert.are.equal(3, result.listDefs.colors.blue)
    end)
  end)

  describe("validate", function()
    local exporter

    before_each(function()
      exporter = Exporter.new()
    end)

    it("should return false for nil story", function()
      local valid, errors = exporter:validate(nil)
      assert.is_false(valid)
      assert.is_table(errors)
    end)

    it("should return false for story without passages", function()
      local valid, errors = exporter:validate({ passages = {} })
      assert.is_false(valid)
    end)

    it("should return true for valid story", function()
      local valid = exporter:validate({
        passages = { start = { id = "start" } }
      })
      assert.is_true(valid)
    end)
  end)

  describe("ink version", function()
    local exporter

    before_each(function()
      exporter = Exporter.new()
    end)

    it("should get ink version", function()
      assert.are.equal(20, exporter:get_ink_version())
    end)

    it("should set ink version", function()
      exporter:set_ink_version(21)
      assert.are.equal(21, exporter:get_ink_version())
    end)
  end)
end)

describe("PassageGenerator", function()
  local PassageGenerator

  before_each(function()
    for k in pairs(package.loaded) do
      if k:match("^whisker%.formats%.ink%.generators") then
        package.loaded[k] = nil
      end
    end

    PassageGenerator = require("whisker.formats.ink.generators.passage")
  end)

  describe("module metadata", function()
    it("should have _whisker metadata", function()
      assert.is_table(PassageGenerator._whisker)
      assert.are.equal("PassageGenerator", PassageGenerator._whisker.name)
    end)
  end)

  describe("new", function()
    it("should create a new instance", function()
      local gen = PassageGenerator.new()
      assert.is_table(gen)
    end)
  end)

  describe("generate", function()
    local gen

    before_each(function()
      gen = PassageGenerator.new()
    end)

    it("should generate container for passage", function()
      local passage = { id = "test", content = "Hello" }
      local result = gen:generate(passage)

      assert.is_table(result)
    end)

    it("should add text with ^ prefix", function()
      local passage = { id = "test", content = "Hello" }
      local result = gen:generate(passage)

      assert.are.equal("^Hello", result[1])
    end)

    it("should add newline after text", function()
      local passage = { id = "test", content = "Hello" }
      local result = gen:generate(passage)

      assert.are.equal("\n", result[2])
    end)

    it("should add end marker for simple passage", function()
      local passage = { id = "test", content = "End" }
      local result = gen:generate(passage)

      local has_end = false
      for _, item in ipairs(result) do
        if item == "end" then
          has_end = true
          break
        end
      end
      assert.is_true(has_end)
    end)

    it("should handle text field", function()
      local passage = { id = "test", text = "From text field" }
      local result = gen:generate(passage)

      assert.are.equal("^From text field", result[1])
    end)
  end)

  describe("is_knot", function()
    local gen

    before_each(function()
      gen = PassageGenerator.new()
    end)

    it("should return true for simple ID", function()
      assert.is_true(gen:is_knot({ id = "chapter" }))
    end)

    it("should return false for dotted ID", function()
      assert.is_false(gen:is_knot({ id = "chapter.intro" }))
    end)

    it("should return true for metadata type knot", function()
      assert.is_true(gen:is_knot({
        id = "test",
        metadata = { type = "knot" }
      }))
    end)

    it("should return false when metadata has parent", function()
      assert.is_false(gen:is_knot({
        id = "test",
        metadata = { parent = "chapter" }
      }))
    end)
  end)

  describe("get_knot_name", function()
    local gen

    before_each(function()
      gen = PassageGenerator.new()
    end)

    it("should return ID for simple passage", function()
      assert.are.equal("chapter", gen:get_knot_name({ id = "chapter" }))
    end)

    it("should return first part for dotted ID", function()
      assert.are.equal("chapter", gen:get_knot_name({ id = "chapter.intro" }))
    end)

    it("should return unnamed for missing ID", function()
      assert.are.equal("unnamed", gen:get_knot_name({}))
    end)
  end)

  describe("get_stitch_name", function()
    local gen

    before_each(function()
      gen = PassageGenerator.new()
    end)

    it("should return nil for simple ID", function()
      assert.is_nil(gen:get_stitch_name({ id = "chapter" }))
    end)

    it("should return second part for dotted ID", function()
      assert.are.equal("intro", gen:get_stitch_name({ id = "chapter.intro" }))
    end)

    it("should handle multiple dots", function()
      assert.are.equal("intro.part1", gen:get_stitch_name({ id = "chapter.intro.part1" }))
    end)
  end)

  describe("generate_metadata", function()
    local gen

    before_each(function()
      gen = PassageGenerator.new()
    end)

    it("should return nil for no tags", function()
      assert.is_nil(gen:generate_metadata({ id = "test" }))
    end)

    it("should add tags with # prefix", function()
      local result = gen:generate_metadata({
        id = "test",
        tags = { "speaker:narrator", "mood:happy" }
      })

      assert.is_table(result)
      assert.are.equal("#speaker:narrator", result[1])
      assert.are.equal("#mood:happy", result[2])
    end)
  end)
end)

describe("Generators registry", function()
  local generators

  before_each(function()
    for k in pairs(package.loaded) do
      if k:match("^whisker%.formats%.ink%.generators") then
        package.loaded[k] = nil
      end
    end

    generators = require("whisker.formats.ink.generators")
  end)

  describe("module metadata", function()
    it("should have _whisker metadata", function()
      assert.is_table(generators._whisker)
      assert.are.equal("InkGenerators", generators._whisker.name)
    end)
  end)

  describe("list", function()
    it("should return generator names", function()
      local list = generators.list()
      assert.is_table(list)
      assert.truthy(#list > 0)
    end)

    it("should include passage generator", function()
      local list = generators.list()
      local has_passage = false
      for _, name in ipairs(list) do
        if name == "passage" then
          has_passage = true
          break
        end
      end
      assert.is_true(has_passage)
    end)
  end)

  describe("create", function()
    it("should create passage generator", function()
      local gen = generators.create("passage")
      assert.is_table(gen)
      assert.is_function(gen.generate)
    end)

    it("should return nil for unknown generator", function()
      assert.is_nil(generators.create("nonexistent"))
    end)
  end)
end)
