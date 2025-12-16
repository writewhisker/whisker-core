-- tests/support/test_fixtures.lua
-- Tests for fixtures and helpers

describe("Fixtures", function()
  local Fixtures

  before_each(function()
    package.loaded["tests.support.fixtures"] = nil
    Fixtures = require("tests.support.fixtures")
  end)

  describe("load_story", function()
    it("should load simple story", function()
      local story = Fixtures.load_story("simple")
      assert.are.equal("Simple Test Story", story.name)
      assert.are.equal("start", story.start)
      assert.is_not_nil(story.passages.start)
    end)

    it("should load complex branching story", function()
      local story = Fixtures.load_story("complex_branching")
      assert.are.equal("Complex Branching Story", story.name)
      assert.is_not_nil(story.variables)
      assert.is_not_nil(story.variables.has_key)
    end)

    it("should load variables heavy story", function()
      local story = Fixtures.load_story("variables_heavy")
      assert.are.equal("Variable-Heavy Story", story.name)
      assert.is_not_nil(story.variables.health)
      assert.are.equal(100, story.variables.health.default)
    end)
  end)

  describe("load_edge_case", function()
    it("should load empty passages fixture", function()
      local story = Fixtures.load_edge_case("empty_passages")
      assert.are.equal("Empty Passages Edge Case", story.name)
      assert.are.equal("", story.passages.empty.content)
    end)

    it("should load circular links fixture", function()
      local story = Fixtures.load_edge_case("circular_links")
      assert.are.equal("Circular Links Edge Case", story.name)
      assert.is_not_nil(story.passages.room_a)
      assert.is_not_nil(story.passages.room_b)
      assert.is_not_nil(story.passages.room_c)
    end)
  end)

  describe("exists", function()
    it("should return true for existing fixture", function()
      assert.is_true(Fixtures.exists("stories/simple.json"))
    end)

    it("should return false for non-existent fixture", function()
      assert.is_false(Fixtures.exists("stories/nonexistent.json"))
    end)
  end)

  describe("load_raw", function()
    it("should return raw JSON string", function()
      local raw = Fixtures.load_raw("stories/simple.json")
      assert.is_string(raw)
      assert.is_truthy(raw:match('"name"'))
    end)
  end)
end)

describe("Helpers", function()
  local Helpers
  local Fixtures

  before_each(function()
    package.loaded["tests.support.helpers"] = nil
    package.loaded["tests.support.fixtures"] = nil
    Helpers = require("tests.support.helpers")
    Fixtures = require("tests.support.fixtures")
  end)

  describe("assert_story_valid", function()
    it("should pass for valid story", function()
      local story = Fixtures.load_story("simple")
      Helpers.assert_story_valid(story)
    end)

    it("should pass for complex story", function()
      local story = Fixtures.load_story("complex_branching")
      Helpers.assert_story_valid(story)
    end)
  end)

  describe("assert_passage", function()
    it("should validate passage properties", function()
      local story = Fixtures.load_story("simple")
      Helpers.assert_passage(story.passages.start, {
        id = "start",
        title = "The Beginning",
        choice_count = 2
      })
    end)
  end)

  describe("assert_choice", function()
    it("should validate choice properties", function()
      local story = Fixtures.load_story("simple")
      local choice = story.passages.start.choices[1]
      Helpers.assert_choice(choice, {
        id = "go_left",
        target = "left_path"
      })
    end)
  end)

  describe("make_story", function()
    it("should create a basic story", function()
      local story = Helpers.make_story({ name = "Test" })
      assert.are.equal("Test", story.name)
      assert.is_not_nil(story.passages.start)
    end)

    it("should use defaults", function()
      local story = Helpers.make_story()
      assert.are.equal("Test Story", story.name)
      assert.are.equal("2.0", story.version)
    end)
  end)

  describe("make_passage", function()
    it("should create a passage", function()
      local passage = Helpers.make_passage("test_id", { title = "Test" })
      assert.are.equal("test_id", passage.id)
      assert.are.equal("Test", passage.title)
    end)
  end)

  describe("make_choice", function()
    it("should create a choice", function()
      local choice = Helpers.make_choice("target_id", { text = "Click me" })
      assert.are.equal("target_id", choice.target)
      assert.are.equal("Click me", choice.text)
    end)
  end)

  describe("tables_equal", function()
    it("should return true for equal tables", function()
      local t1 = { a = 1, b = { c = 2 } }
      local t2 = { a = 1, b = { c = 2 } }
      assert.is_true(Helpers.tables_equal(t1, t2))
    end)

    it("should return false for different tables", function()
      local t1 = { a = 1 }
      local t2 = { a = 2 }
      assert.is_false(Helpers.tables_equal(t1, t2))
    end)
  end)
end)
