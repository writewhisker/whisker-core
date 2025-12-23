--- Passage Unit Tests
-- Comprehensive unit tests for the Passage module
-- @module tests.unit.core.test_passage_spec
-- @author Whisker Core Team

describe("Passage", function()
  local Passage, Choice

  before_each(function()
    Passage = require("whisker.core.passage")
    Choice = require("whisker.core.choice")
  end)

  describe("initialization", function()
    it("creates passage with required fields", function()
      local passage = Passage.new({ id = "test", name = "Test" })

      assert.is_not_nil(passage)
      assert.equals("test", passage.id)
      assert.equals("Test", passage.name)
    end)

    it("creates passage with all fields", function()
      local passage = Passage.new({
        id = "full",
        name = "Full Passage",
        content = "Some content"
      })

      assert.equals("full", passage.id)
      assert.equals("Full Passage", passage.name)
      assert.equals("Some content", passage.content)
    end)

    it("initializes empty collections", function()
      local passage = Passage.new({ id = "test", name = "Test" })

      assert.is_table(passage.choices)
      assert.is_table(passage.tags)
      assert.equals(0, #passage.choices)
    end)
  end)

  describe("content management", function()
    local passage

    before_each(function()
      passage = Passage.new({ id = "test", name = "Test" })
    end)

    it("sets content", function()
      passage:set_content("New content")

      assert.equals("New content", passage.content)
    end)

    it("gets content", function()
      passage.content = "Test content"

      assert.equals("Test content", passage:get_content())
    end)

    it("handles empty content", function()
      -- Passage defaults to empty string content
      assert.equals("", passage.content)
      passage:set_content("")
      assert.equals("", passage.content)
    end)
  end)

  describe("choice management", function()
    local passage

    before_each(function()
      passage = Passage.new({ id = "test", name = "Test" })
    end)

    it("adds choice", function()
      local choice = Choice.new({ text = "Go", target = "next" })
      passage:add_choice(choice)

      assert.equals(1, #passage.choices)
      assert.equals(choice, passage.choices[1])
    end)

    it("adds multiple choices", function()
      passage:add_choice(Choice.new({ text = "A", target = "a" }))
      passage:add_choice(Choice.new({ text = "B", target = "b" }))
      passage:add_choice(Choice.new({ text = "C", target = "c" }))

      assert.equals(3, #passage.choices)
    end)

    it("removes choice by index", function()
      passage:add_choice(Choice.new({ text = "A", target = "a" }))
      passage:add_choice(Choice.new({ text = "B", target = "b" }))

      passage:remove_choice(1)

      assert.equals(1, #passage.choices)
      assert.equals("B", passage.choices[1].text)
    end)

    it("gets choice by index", function()
      local choice = Choice.new({ text = "Test", target = "target" })
      passage:add_choice(choice)

      local retrieved = passage:get_choice(1)

      assert.equals(choice, retrieved)
    end)
  end)

  describe("tag management", function()
    local passage

    before_each(function()
      passage = Passage.new({ id = "test", name = "Test" })
    end)

    it("adds tag", function()
      passage:add_tag("important")

      assert.is_true(passage:has_tag("important"))
    end)

    it("removes tag", function()
      passage:add_tag("remove_me")
      passage:remove_tag("remove_me")

      assert.is_false(passage:has_tag("remove_me"))
    end)

    it("gets all tags", function()
      passage:add_tag("a")
      passage:add_tag("b")
      passage:add_tag("c")

      local tags = passage:get_tags()

      assert.equals(3, #tags)
    end)
  end)

  describe("metadata", function()
    local passage

    before_each(function()
      passage = Passage.new({ id = "test", name = "Test" })
    end)

    it("sets and gets metadata", function()
      passage:set_metadata("key", "value")

      assert.equals("value", passage:get_metadata("key"))
    end)

    it("returns nil for nonexistent metadata", function()
      assert.is_nil(passage:get_metadata("nonexistent"))
    end)
  end)

  describe("validation", function()
    it("valid passage passes validation", function()
      local passage = Passage.new({ id = "valid", name = "Valid" })

      local valid, err = passage:validate()

      assert.is_true(valid)
      assert.is_nil(err)
    end)

    it("fails without id", function()
      local passage = Passage.new({ name = "No ID" })
      passage.id = nil

      local valid, err = passage:validate()

      assert.is_false(valid)
      assert.is_string(err)
    end)
  end)

  describe("serialization", function()
    it("serializes passage data", function()
      local passage = Passage.new({
        id = "test",
        name = "Test",
        content = "Content"
      })
      passage:add_tag("tag1")
      passage:add_choice(Choice.new({ text = "Go", target = "next" }))

      local data = passage:serialize()

      assert.equals("test", data.id)
      assert.equals("Test", data.name)
      assert.equals("Content", data.content)
      assert.is_table(data.tags)
      assert.is_table(data.choices)
    end)

    it("deserializes passage data", function()
      local data = {
        id = "restored",
        name = "Restored",
        content = "Restored content",
        tags = { "tag1" },
        choices = {}
      }

      local passage = Passage.new({ id = "temp", name = "Temp" })
      passage:deserialize(data)

      assert.equals("restored", passage.id)
      assert.equals("Restored", passage.name)
    end)
  end)

  describe("from_table factory", function()
    it("creates passage from table", function()
      local data = {
        id = "from_table",
        name = "From Table",
        content = "Content"
      }

      local passage = Passage.from_table(data)

      assert.is_not_nil(passage)
      assert.equals("from_table", passage.id)
    end)

    it("returns nil for nil input", function()
      local passage = Passage.from_table(nil)

      assert.is_nil(passage)
    end)
  end)
end)
