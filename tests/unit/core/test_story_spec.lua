--- Story Unit Tests
-- Comprehensive unit tests for the Story module
-- @module tests.unit.core.test_story_spec
-- @author Whisker Core Team

describe("Story", function()
  local Story, Passage, Choice

  before_each(function()
    Story = require("whisker.core.story")
    Passage = require("whisker.core.passage")
    Choice = require("whisker.core.choice")
  end)

  describe("initialization", function()
    it("creates empty story with defaults", function()
      local story = Story.new()

      assert.is_not_nil(story)
      assert.is_table(story.metadata)
      assert.is_table(story.variables)
      assert.is_table(story.passages)
    end)

    it("creates story with options", function()
      local story = Story.new({
        title = "Test Story",
        author = "Test Author",
        version = "2.0.0"
      })

      assert.equals("Test Story", story.metadata.name)
      assert.equals("Test Author", story.metadata.author)
    end)

    it("accepts name option as alias for title", function()
      local story = Story.new({ name = "Named Story" })

      assert.equals("Named Story", story.metadata.name)
    end)
  end)

  describe("passage management", function()
    local story

    before_each(function()
      story = Story.new()
    end)

    it("adds passage", function()
      local passage = Passage.new({ id = "test", name = "Test" })
      story:add_passage(passage)

      assert.equals(passage, story:get_passage("test"))
    end)

    it("throws error when adding passage without id", function()
      assert.has_error(function()
        story:add_passage({ name = "No ID" })
      end)
    end)

    it("gets all passages", function()
      story:add_passage(Passage.new({ id = "p1", name = "P1" }))
      story:add_passage(Passage.new({ id = "p2", name = "P2" }))
      story:add_passage(Passage.new({ id = "p3", name = "P3" }))

      local all = story:get_all_passages()
      assert.equals(3, #all)
    end)

    it("removes passage by id", function()
      local passage = Passage.new({ id = "remove_me", name = "Remove" })
      story:add_passage(passage)
      story:remove_passage("remove_me")

      assert.is_nil(story:get_passage("remove_me"))
    end)
  end)

  describe("start passage management", function()
    local story

    before_each(function()
      story = Story.new()
    end)

    it("sets start passage", function()
      local passage = Passage.new({ id = "start", name = "Start" })
      story:add_passage(passage)
      story:set_start_passage("start")

      assert.equals("start", story.start_passage)
    end)

    it("throws error when setting nonexistent start passage", function()
      assert.has_error(function()
        story:set_start_passage("nonexistent")
      end)
    end)

    it("gets start passage", function()
      local passage = Passage.new({ id = "begin", name = "Begin" })
      story:add_passage(passage)
      story:set_start_passage("begin")

      assert.equals("begin", story:get_start_passage())
    end)
  end)

  describe("variable management", function()
    local story

    before_each(function()
      story = Story.new()
    end)

    it("sets and gets variables", function()
      story:set_variable("player_name", "Alice")

      assert.equals("Alice", story:get_variable("player_name"))
    end)

    it("returns nil for nonexistent variable", function()
      assert.is_nil(story:get_variable("nonexistent"))
    end)

    it("stores different variable types", function()
      story:set_variable("string", "text")
      story:set_variable("number", 42)
      story:set_variable("boolean", true)
      story:set_variable("table", { a = 1 })

      assert.equals("text", story:get_variable("string"))
      assert.equals(42, story:get_variable("number"))
      assert.equals(true, story:get_variable("boolean"))
      assert.same({ a = 1 }, story:get_variable("table"))
    end)
  end)

  describe("validation", function()
    local story

    before_each(function()
      story = Story.new({ title = "Valid Story" })
    end)

    it("valid story passes validation", function()
      local passage = Passage.new({ id = "start", name = "Start" })
      story:add_passage(passage)
      story:set_start_passage("start")

      local valid, err = story:validate()

      assert.is_true(valid)
      assert.is_nil(err)
    end)

    it("fails without story name", function()
      local story2 = Story.new()
      local passage = Passage.new({ id = "start", name = "Start" })
      story2:add_passage(passage)
      story2:set_start_passage("start")

      local valid, err = story2:validate()

      assert.is_false(valid)
      assert.is_string(err)
    end)

    it("fails without start passage", function()
      local passage = Passage.new({ id = "p1", name = "P1" })
      story:add_passage(passage)

      local valid, err = story:validate()

      assert.is_false(valid)
      assert.is_string(err)
    end)
  end)

  describe("serialization", function()
    local story

    before_each(function()
      story = Story.new({ title = "Test Story" })
    end)

    it("serialize returns complete data", function()
      story:set_variable("var1", "value1")
      local passage = Passage.new({ id = "p1", name = "P1" })
      story:add_passage(passage)

      local data = story:serialize()

      assert.is_table(data.metadata)
      assert.is_table(data.variables)
      assert.is_table(data.passages)
    end)

    it("serialize and deserialize round-trip", function()
      story:set_variable("test", "value")
      local passage = Passage.new({ id = "p1", name = "P1" })
      story:add_passage(passage)
      story:set_start_passage("p1")

      local data = story:serialize()
      local new_story = Story.new()
      new_story:deserialize(data)

      assert.equals("Test Story", new_story.metadata.name)
      assert.equals("value", new_story:get_variable("test"))
      assert.is_not_nil(new_story:get_passage("p1"))
    end)
  end)

  describe("from_table factory method", function()
    it("creates story from plain table", function()
      local data = {
        metadata = { name = "From Table" },
        variables = { var1 = "value1" },
        passages = {}
      }

      local story = Story.from_table(data)

      assert.is_not_nil(story)
      assert.equals("From Table", story.metadata.name)
    end)

    it("returns nil for nil input", function()
      local story = Story.from_table(nil)

      assert.is_nil(story)
    end)
  end)
end)
