-- spec/formats/ink/choice_exporter_spec.lua
-- Tests for choice and navigation export

describe("ChoiceGenerator", function()
  local ChoiceGenerator

  before_each(function()
    -- Clear cached modules
    for k in pairs(package.loaded) do
      if k:match("^whisker%.formats%.ink%.generators%.choice") then
        package.loaded[k] = nil
      end
    end

    ChoiceGenerator = require("whisker.formats.ink.generators.choice")
  end)

  describe("module metadata", function()
    it("should have _whisker metadata", function()
      assert.is_table(ChoiceGenerator._whisker)
      assert.are.equal("ChoiceGenerator", ChoiceGenerator._whisker.name)
    end)

    it("should have capability", function()
      assert.are.equal("formats.ink.generators.choice", ChoiceGenerator._whisker.capability)
    end)
  end)

  describe("FLAGS", function()
    it("should define flag constants", function()
      assert.are.equal(1, ChoiceGenerator.FLAGS.HAS_CONDITION)
      assert.are.equal(2, ChoiceGenerator.FLAGS.HAS_START_CONTENT)
      assert.are.equal(4, ChoiceGenerator.FLAGS.HAS_CHOICE_ONLY_CONTENT)
      assert.are.equal(8, ChoiceGenerator.FLAGS.INVISIBLE_DEFAULT)
      assert.are.equal(16, ChoiceGenerator.FLAGS.ONCE_ONLY)
    end)
  end)

  describe("new", function()
    it("should create a new instance", function()
      local gen = ChoiceGenerator.new()
      assert.is_table(gen)
    end)
  end)

  describe("generate", function()
    local gen

    before_each(function()
      gen = ChoiceGenerator.new()
    end)

    it("should generate choice point", function()
      local choice = { text = "Go north", target = "north" }
      local result = gen:generate(choice)

      assert.is_table(result)
      assert.truthy(#result > 0)
    end)

    it("should include choice text in ev block", function()
      local choice = { text = "Choose me", target = "dest" }
      local result = gen:generate(choice)

      assert.are.equal("ev", result[1])
      assert.are.equal("/ev", result[3])
    end)

    it("should create choice point object", function()
      local choice = { text = "Test", target = "target" }
      local result = gen:generate(choice)

      -- Last element should be choice point
      local cp = result[#result]
      assert.is_table(cp)
      assert.are.equal("target", cp["*"])
    end)
  end)

  describe("generate_block", function()
    local gen

    before_each(function()
      gen = ChoiceGenerator.new()
    end)

    it("should generate multiple choices", function()
      local choices = {
        { text = "Option 1", target = "opt1" },
        { text = "Option 2", target = "opt2" }
      }

      local result = gen:generate_block(choices)
      assert.is_table(result)
      assert.truthy(#result > 0)
    end)
  end)

  describe("_calculate_flags", function()
    local gen

    before_each(function()
      gen = ChoiceGenerator.new()
    end)

    it("should set ONCE_ONLY for non-sticky choice", function()
      local choice = { text = "Test" }
      local flags = gen:_calculate_flags(choice)

      -- ONCE_ONLY = 16, HAS_START_CONTENT = 2, total = 18
      assert.are.equal(18, flags)
    end)

    it("should not set ONCE_ONLY for sticky choice", function()
      local choice = { text = "Test", sticky = true }
      local flags = gen:_calculate_flags(choice)

      -- Should not include ONCE_ONLY (16)
      assert.are.equal(2, flags) -- Only HAS_START_CONTENT
    end)

    it("should set HAS_START_CONTENT when text present", function()
      local choice = { text = "Has text", sticky = true }
      local flags = gen:_calculate_flags(choice)

      assert.truthy(flags >= 2)
    end)

    it("should set HAS_CHOICE_ONLY_CONTENT when choice_text present", function()
      local choice = { choice_text = "Choice only", sticky = true }
      local flags = gen:_calculate_flags(choice)

      assert.are.equal(4, flags)
    end)

    it("should set HAS_CONDITION when condition present", function()
      local choice = { condition = "has_key", sticky = true }
      local flags = gen:_calculate_flags(choice)

      assert.are.equal(1, flags)
    end)

    it("should set INVISIBLE_DEFAULT for fallback", function()
      local choice = { fallback = true, sticky = true }
      local flags = gen:_calculate_flags(choice)

      assert.are.equal(8, flags)
    end)

    it("should combine multiple flags", function()
      local choice = {
        text = "Text",
        condition = "cond",
        fallback = true,
        sticky = true
      }
      local flags = gen:_calculate_flags(choice)

      -- HAS_CONDITION (1) + HAS_START_CONTENT (2) + INVISIBLE_DEFAULT (8) = 11
      assert.are.equal(11, flags)
    end)
  end)

  describe("is_sticky", function()
    local gen

    before_each(function()
      gen = ChoiceGenerator.new()
    end)

    it("should return true for sticky choice", function()
      assert.is_true(gen:is_sticky({ sticky = true }))
    end)

    it("should return false for non-sticky choice", function()
      assert.is_false(gen:is_sticky({ sticky = false }))
      assert.is_false(gen:is_sticky({}))
    end)
  end)

  describe("is_fallback", function()
    local gen

    before_each(function()
      gen = ChoiceGenerator.new()
    end)

    it("should return true for fallback choice", function()
      assert.is_true(gen:is_fallback({ fallback = true }))
    end)

    it("should return false for non-fallback choice", function()
      assert.is_false(gen:is_fallback({ fallback = false }))
      assert.is_false(gen:is_fallback({}))
    end)
  end)

  describe("generate_content", function()
    local gen

    before_each(function()
      gen = ChoiceGenerator.new()
    end)

    it("should generate empty content for choice without content", function()
      local result = gen:generate_content({})
      assert.are.same({}, result)
    end)

    it("should add text content with prefix", function()
      local result = gen:generate_content({ content = "After choice" })
      assert.are.equal("^After choice", result[1])
      assert.are.equal("\n", result[2])
    end)
  end)
end)

describe("DivertGenerator", function()
  local DivertGenerator

  before_each(function()
    for k in pairs(package.loaded) do
      if k:match("^whisker%.formats%.ink%.generators%.divert") then
        package.loaded[k] = nil
      end
    end

    DivertGenerator = require("whisker.formats.ink.generators.divert")
  end)

  describe("module metadata", function()
    it("should have _whisker metadata", function()
      assert.is_table(DivertGenerator._whisker)
      assert.are.equal("DivertGenerator", DivertGenerator._whisker.name)
    end)

    it("should have capability", function()
      assert.are.equal("formats.ink.generators.divert", DivertGenerator._whisker.capability)
    end)
  end)

  describe("constants", function()
    it("should define DONE", function()
      assert.are.equal("done", DivertGenerator.DONE)
    end)

    it("should define END", function()
      assert.are.equal("end", DivertGenerator.END)
    end)
  end)

  describe("new", function()
    it("should create a new instance", function()
      local gen = DivertGenerator.new()
      assert.is_table(gen)
    end)
  end)

  describe("generate", function()
    local gen

    before_each(function()
      gen = DivertGenerator.new()
    end)

    it("should generate divert to target", function()
      local result = gen:generate("my_knot")
      assert.is_table(result)
      assert.are.equal("my_knot", result["->"])
    end)

    it("should default to done for nil target", function()
      local result = gen:generate(nil)
      assert.are.equal("done", result["->"])
    end)

    it("should normalize special targets", function()
      local result = gen:generate("DONE")
      assert.are.equal("done", result["->"])

      result = gen:generate("END")
      assert.are.equal("end", result["->"])
    end)
  end)

  describe("generate_tunnel", function()
    local gen

    before_each(function()
      gen = DivertGenerator.new()
    end)

    it("should generate tunnel divert", function()
      local result = gen:generate_tunnel("tunnel_knot")
      assert.are.equal("tunnel_knot", result["->t->"])
    end)
  end)

  describe("generate_thread", function()
    local gen

    before_each(function()
      gen = DivertGenerator.new()
    end)

    it("should generate thread start", function()
      local result = gen:generate_thread("thread_knot")
      assert.are.equal("thread_knot", result["<-"])
    end)
  end)

  describe("generate_tunnel_return", function()
    local gen

    before_each(function()
      gen = DivertGenerator.new()
    end)

    it("should generate tunnel return marker", function()
      local result = gen:generate_tunnel_return()
      assert.is_true(result["->->"])
    end)
  end)

  describe("is_special_target", function()
    local gen

    before_each(function()
      gen = DivertGenerator.new()
    end)

    it("should return true for done", function()
      assert.is_true(gen:is_special_target("done"))
      assert.is_true(gen:is_special_target("DONE"))
    end)

    it("should return true for end", function()
      assert.is_true(gen:is_special_target("end"))
      assert.is_true(gen:is_special_target("END"))
    end)

    it("should return false for regular targets", function()
      assert.is_false(gen:is_special_target("my_knot"))
      assert.is_false(gen:is_special_target("chapter.intro"))
    end)

    it("should return false for nil", function()
      assert.is_false(gen:is_special_target(nil))
    end)
  end)

  describe("from_link", function()
    local gen

    before_each(function()
      gen = DivertGenerator.new()
    end)

    it("should handle string link", function()
      local result = gen:from_link("target_knot")
      assert.are.equal("target_knot", result["->"])
    end)

    it("should handle table link with target", function()
      local result = gen:from_link({ target = "other_knot" })
      assert.are.equal("other_knot", result["->"])
    end)

    it("should handle table link with passage", function()
      local result = gen:from_link({ passage = "passage_id" })
      assert.are.equal("passage_id", result["->"])
    end)

    it("should handle table link with path", function()
      local result = gen:from_link({ path = "path.to.target" })
      assert.are.equal("path.to.target", result["->"])
    end)
  end)

  describe("generate_conditional", function()
    local gen

    before_each(function()
      gen = DivertGenerator.new()
    end)

    it("should generate conditional divert", function()
      local result = gen:generate_conditional("target", "has_key")

      assert.are.equal("ev", result[1])
      assert.is_table(result[2])
      assert.are.equal("has_key", result[2]["VAR?"])
      assert.are.equal("/ev", result[3])

      local divert = result[4]
      assert.are.equal("target", divert["->"])
      assert.is_true(divert.c)
    end)
  end)
end)

describe("Exporter with choices", function()
  local Exporter

  before_each(function()
    for k in pairs(package.loaded) do
      if k:match("^whisker%.formats%.ink") then
        package.loaded[k] = nil
      end
    end

    Exporter = require("whisker.formats.ink.exporter")
  end)

  it("should export story with choices", function()
    local story = {
      start = "start",
      passages = {
        start = {
          id = "start",
          content = "What do you do?",
          choices = {
            { text = "Go left", target = "left" },
            { text = "Go right", target = "right" }
          }
        },
        left = { id = "left", content = "You went left" },
        right = { id = "right", content = "You went right" }
      }
    }

    local exporter = Exporter.new()
    local result = exporter:export(story)

    assert.is_table(result)
    assert.is_table(result.root.start)
    assert.is_table(result.root.left)
    assert.is_table(result.root.right)
  end)
end)
